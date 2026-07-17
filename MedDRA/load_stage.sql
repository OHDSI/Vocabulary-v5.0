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
* Authors: Mikita Salavei, Dmitry Dymshyts, Denys Kaduk, Timur Vakhitov, Christian Reich
* Date: 2024
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'MedDRA',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.hlt_pref_comp LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.hlt_pref_comp LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_MEDDRA'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Insert into concept_stage
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	domain_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT soc_name AS concept_name,
	'MedDRA' AS vocabulary_id,
	NULL AS domain_id,
	'SOC' AS concept_class_id,
	'C' AS standard_concept,
	soc_code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MedDRA'
		),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM SOURCES.soc_term

UNION ALL

SELECT hlgt_name AS concept_name,
	'MedDRA' AS vocabulary_id,
	NULL AS domain_id,
	'HLGT' AS concept_class_id,
	'C' AS standard_concept,
	hlgt_code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MedDRA'
		),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM SOURCES.hlgt_pref_term

UNION ALL

SELECT hlt_name AS concept_name,
	'MedDRA' AS vocabulary_id,
	NULL AS domain_id,
	'HLT' AS concept_class_id,
	'C' AS standard_concept,
	hlt_code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MedDRA'
		),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM SOURCES.hlt_pref_term

UNION ALL

SELECT pt_name AS concept_name,
	'MedDRA' AS vocabulary_id,
	NULL AS domain_id,
	'PT' AS concept_class_id,
	'C' AS standard_concept,
	pt_code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MedDRA'
		),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM SOURCES.pref_term

UNION ALL

SELECT llt_name AS concept_name,
	'MedDRA' AS vocabulary_id,
	NULL AS domain_id,
	'LLT' AS concept_class_id,
	'C' AS standard_concept,
	llt_code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MedDRA'
		),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM SOURCES.low_level_term
WHERE llt_currency = 'Y'
	AND llt_code <> pt_code;

--4. Update domain_id
WITH t_domains
AS (
	--LLT level 
	SELECT llt_code AS concept_code,
		CASE 
			--pt level
			WHEN pt_name ~* 'monitoring|centesis|imaging|screen'
				THEN 'Procedure'
					--hlt level
			WHEN hlt_name ~* 'exposures|Physical examination procedures and organ system status'
				THEN 'Observation'
			WHEN hlt_name ~* 'histopathology|imaging|(?<!diagnostic |fertility.+)procedure'
				THEN 'Procedure'
			WHEN hlt_name ~* 'gene mutations and other alterations'
				THEN 'Condition'
					--hlgt level
			WHEN hlgt_name = 'Therapeutic and nontherapeutic effects (excl toxicity)'
				THEN 'Observation'
					--soc level
			WHEN soc_name ~ 'disorders|Infections|Neoplasms|Injury, poisoning and procedural complications|Pregnancy, puerperium and perinatal conditions'
				THEN 'Condition'
			WHEN soc_name ~ 'Surgical and medical procedures'
				THEN 'Procedure'
			WHEN soc_name IN (
					'Product issues',
					'Social circumstances'
					)
				THEN 'Observation'
			WHEN soc_name = 'Investigations'
				THEN 'Measurement'
			ELSE 'Undefined'
			END AS domain_id
	FROM SOURCES.md_hierarchy h
	JOIN SOURCES.low_level_term l ON l.pt_code = h.pt_code
		AND llt_currency = 'Y'
	WHERE primary_soc_fg = 'Y'
	
	UNION
	
	-- pt level
	SELECT pt_code AS concept_code,
		CASE 
			--pt level
			WHEN pt_name ~* 'monitoring|centesis|imaging|screen'
				THEN 'Procedure'
					--hlt level
			WHEN hlt_name ~* 'exposures|Physical examination procedures and organ system status'
				THEN 'Observation'
			WHEN hlt_name ~* 'histopathology|imaging|(?<!diagnostic |fertility.+)procedure'
				THEN 'Procedure'
			WHEN hlt_name ~* 'gene mutations and other alterations|syndrome'
				THEN 'Condition'
					--hlgt level
			WHEN hlgt_name = 'Therapeutic and nontherapeutic effects (excl toxicity)'
				THEN 'Observation'
					--soc level
			WHEN soc_name ~ 'disorders|Infections|Neoplasms|Injury, poisoning and procedural complications|Pregnancy, puerperium and perinatal conditions'
				THEN 'Condition'
			WHEN soc_name ~ 'Surgical and medical procedures'
				THEN 'Procedure'
			WHEN soc_name IN (
					'Product issues',
					'Social circumstances'
					)
				THEN 'Observation'
			WHEN soc_name = 'Investigations'
				THEN 'Measurement'
			ELSE 'Undefined'
			END AS domain_id
	FROM SOURCES.md_hierarchy h
	WHERE primary_soc_fg = 'Y'
	
	UNION
	
	--hlt level
	SELECT hlt_code AS concept_code,
		CASE 
			--hlt level
			WHEN hlt_name ~* 'exposures|Physical examination procedures and organ system status'
				THEN 'Observation'
			WHEN hlt_name ~* 'histopathology|imaging|(?<!diagnostic |fertility.+)procedure'
				THEN 'Procedure'
			WHEN hlt_name ~* 'gene mutations and other alterations'
				THEN 'Condition'
					--hlgt level
			WHEN hlgt_name = 'Therapeutic and nontherapeutic effects (excl toxicity)'
				THEN 'Observation'
					--soc level
			WHEN soc_name ~ 'disorders|Infections|Neoplasms|Injury, poisoning and procedural complications|Pregnancy, puerperium and perinatal conditions'
				THEN 'Condition'
			WHEN soc_name ~ 'Surgical and medical procedures'
				THEN 'Procedure'
			WHEN soc_name IN (
					'Product issues',
					'Social circumstances'
					)
				THEN 'Observation'
			WHEN soc_name = 'Investigations'
				THEN 'Measurement'
			ELSE 'Undefined'
			END AS domain_id
	FROM SOURCES.md_hierarchy h
	WHERE primary_soc_fg = 'Y'
	
	UNION
	
	--hlgt level
	SELECT hlgt_code AS concept_code,
		CASE 
			--hlgt level
			WHEN hlgt_name = 'Therapeutic and nontherapeutic effects (excl toxicity)'
				THEN 'Observation'
					--soc level
			WHEN soc_name ~ 'disorders|Infections|Neoplasms|Injury, poisoning and procedural complications|Pregnancy, puerperium and perinatal conditions'
				THEN 'Condition'
			WHEN soc_name ~ 'Surgical and medical procedures'
				THEN 'Procedure'
			WHEN soc_name IN (
					'Product issues',
					'Social circumstances'
					)
				THEN 'Observation'
			WHEN soc_name = 'Investigations'
				THEN 'Measurement'
			ELSE 'Undefined'
			END AS domain_id
	FROM SOURCES.md_hierarchy h
	WHERE primary_soc_fg = 'Y'
	
	UNION
	
	--soc level
	SELECT soc_code AS concept_code,
		CASE 
			--soc level
			WHEN soc_name ~ 'disorders|Infections|Neoplasms|Injury, poisoning and procedural complications|Pregnancy, puerperium and perinatal conditions'
				THEN 'Condition'
			WHEN soc_name ~ 'Surgical and medical procedures'
				THEN 'Procedure'
			WHEN soc_name IN (
					'Product issues',
					'Social circumstances'
					)
				THEN 'Observation'
			WHEN soc_name = 'Investigations'
				THEN 'Measurement'
			ELSE 'Undefined'
			END AS domain_id
	FROM SOURCES.md_hierarchy h
	WHERE primary_soc_fg = 'Y'
	)
UPDATE concept_stage cs
SET domain_id = t.domain_id
FROM t_domains t
WHERE cs.concept_code = t.concept_code::VARCHAR;

--discovered that there are concepts missing from t_domains because their primary_soc_fg = 'N'
--empirically discovered that their domain = 'Condition'

UPDATE concept_stage cs
SET domain_id = 'Condition'
WHERE domain_id IS NULL;

--5. Create internal hierarchical relationships
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT soc_code AS concept_code_1,
	hlgt_code AS concept_code_2,
	'MedDRA' AS vocabulary_id_1,
	'MedDRA' AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MedDRA'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM SOURCES.soc_hlgt_comp

UNION ALL

SELECT hlgt_code AS concept_code_1,
	hlt_code AS concept_code_2,
	'MedDRA' AS vocabulary_id_1,
	'MedDRA' AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MedDRA'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM SOURCES.hlgt_hlt_comp

UNION ALL

SELECT hlt_code AS concept_code_1,
	pt_code AS concept_code_2,
	'MedDRA' AS vocabulary_id_1,
	'MedDRA' AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MedDRA'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM SOURCES.hlt_pref_comp

UNION ALL

SELECT pt_code AS concept_code_1,
	llt_code AS concept_code_2,
	'MedDRA' AS vocabulary_id_1,
	'MedDRA' AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MedDRA'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM SOURCES.low_level_term
WHERE llt_currency = 'Y'
	AND llt_code <> pt_code;

--6. Working with concept_manual table
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--7. Append result to concept_relationship_stage table
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--8. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--9. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

--10. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--11. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--12. Make all LLT and PT concepts without valid 'Maps to' links non-standard
UPDATE concept_stage cs
SET standard_concept = NULL
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = cs.concept_code
			AND crs_int.vocabulary_id_1 = cs.vocabulary_id
			AND crs_int.relationship_id LIKE 'Maps to%'
			AND crs_int.invalid_reason IS NULL
		)
	AND cs.concept_class_id IN (
		'PT',
		'LLT'
		)
	AND cs.standard_concept IS NOT NULL;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script