/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov, Christian Reich
* Date: 2017
**************************************************************************/

-- 1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'Indication',
	pVocabularyDate			=> (SELECT latest_update FROM vocabulary_conversion WHERE vocabulary_id_v5='GCN_SEQNO'),
	pVocabularyVersion		=> (SELECT TO_CHAR(latest_update,'YYYYMMDD')||' Release' FROM vocabulary_conversion WHERE vocabulary_id_v5='GCN_SEQNO'),
	pVocabularyDevSchema	=> 'DEV_GCNSEQNO'
);
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Add Indication to concept_stage from RFMLDX0_DXID and RFMLDRHO_DXID_HIST
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT d.dxid_desc100 AS concept_name,
	'Drug' AS domain_id,
	'Indication' AS vocabulary_id,
	'Indication' AS concept_class_id,
	'C' AS standard_concept,
	d.dxid AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	CASE d.dxid_status
		WHEN '1'
			THEN CASE 
					WHEN h.fmlrepdxid IS NULL
						THEN (
								SELECT V.LATEST_UPDATE - 1
								FROM VOCABULARY V
								WHERE V.VOCABULARY_ID = 'Indication'
								)
					ELSE fmldxrepdt
					END
		WHEN '2'
			THEN (
					SELECT V.LATEST_UPDATE - 1
					FROM VOCABULARY V
					WHERE V.VOCABULARY_ID = 'Indication'
					)
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date,
	CASE d.dxid_status
		WHEN '1'
			THEN CASE 
					WHEN h.fmlrepdxid IS NULL
						THEN 'D'
					ELSE 'U'
					END
		WHEN '2'
			THEN 'D'
		ELSE NULL
		END AS invalid_reason
FROM SOURCES.rfmldx0_dxid d
LEFT JOIN SOURCES.RFMLDRH0_DXID_HIST h ON h.fmlprvdxid = d.dxid;-- find in replacement table

--4. Add synonymus
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)
SELECT synonym_concept_code,
	'Indication' AS synonym_vocabulary_id,
	synonym_name,
	4180186 AS language_concept_id -- English
FROM (
	SELECT dxid_syn_desc56 AS synonym_name,
		dxid AS synonym_concept_code
	FROM SOURCES.RFMLSYN0_DXID_SYN
	WHERE dxid_syn_status = '0'
	
	UNION
	
	SELECT dxid_syn_desc100,
		dxid
	FROM SOURCES.RFMLSYN0_DXID_SYN
	WHERE dxid_syn_status = '0'
	
	UNION
	
	SELECT dxid_desc56,
		dxid
	FROM SOURCES.rfmldx0_dxid
	
	UNION
	
	SELECT dxid_desc100,
		dxid
	FROM SOURCES.rfmldx0_dxid
	) AS s0;

--4. Load into concept_relationship_stage
 -- Upgrade relationship for concepts
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT h.fmlprvdxid AS concept_code_1,
	h.fmlrepdxid AS concept_code_2,
	'Indication' AS vocabulary_id_1,
	'Indication' AS vocabulary_id_2,
	'Concept replaced by' AS relationship_id,
	h.fmldxrepdt AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.rfmldrh0_dxid_hist h;

 -- Indication to RxNorm
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT rx.concept_code AS concept_code_1,
	m.dxid AS concept_code_2,
	'RxNorm' AS vocabulary_id_1,
	'Indication' AS vocabulary_id_2,
	CASE m.indcts_lbl
		WHEN 'L'
			THEN 'Has FDA-appr ind'
		WHEN 'U'
			THEN 'Has off-label ind'
		ELSE NULL
		END AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept rx -- RxNorm
JOIN concept_relationship r ON r.concept_id_1 = rx.concept_id
	AND r.invalid_reason IS NULL
	AND r.relationship_id = 'Mapped from'
JOIN concept g ON g.concept_id = r.concept_id_2
	AND g.vocabulary_id = 'GCN_SEQNO'
JOIN SOURCES.rindmgc0_indcts_gcnseqno_link l ON l.gcn_seqno = g.concept_code
JOIN SOURCES.rindmma2_indcts_mstr m ON m.indcts = l.indcts
WHERE m.indcts_lbl <> 'P';-- use only FDA-approved ('L') or unlabelled ('U') ones, not proxy indications

-- Contraindication to RxNorm
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT rx.concept_code AS concept_code_1,
	m.dxid AS concept_code_2,
	'RxNorm' AS vocabulary_id_1,
	'Indication' AS vocabulary_id_2,
	'Has CI' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept rx -- RxNorm
JOIN concept_relationship r ON r.concept_id_1 = rx.concept_id
	AND r.invalid_reason IS NULL
	AND r.relationship_id = 'Mapped from'
JOIN concept g ON g.concept_id = r.concept_id_2
	AND g.vocabulary_id = 'GCN_SEQNO'
JOIN SOURCES.rddcmgc0_contra_gcnseqno_link l ON l.gcn_seqno = g.concept_code
JOIN SOURCES.rddcmma1_contra_mstr m ON m.ddxcn = l.ddxcn;

-- Indication to SNOMED through ICD9CM and ICD10CM
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT rs.related_dxid AS concept_code_1,
	c.concept_code AS concept_code_2,
	'Indication' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	'Ind/CI - SNOMED' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.RFMLISR1_ICD_SEARCH rs
JOIN concept icd ON icd.concept_code = rs.search_icd_cd
	AND icd.vocabulary_id IN (
		'ICD9CM',
		'ICD10CM'
		) -- potentially restrict by fml_clin_code and fml_nav_code
JOIN concept_relationship r ON r.concept_id_1 = icd.concept_id
	AND r.invalid_reason IS NULL
	AND r.relationship_id = 'Maps to'
JOIN concept c ON c.concept_id = r.concept_id_2
	AND c.vocabulary_id = 'SNOMED'
	AND c.domain_id = 'Condition';

--5. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--6. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--7. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--8. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script