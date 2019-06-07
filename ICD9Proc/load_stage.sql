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
* Authors: Timur Vakhitov, Christian Reich, Polina Talapova, Dmitry Dymshyts
* Date: 2019
**************************************************************************/
--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
		pVocabularyName			=> 'ICD9Proc',
		pVocabularyDate			=> (SELECT vocabulary_date FROM sources.cms_desc_short_sg LIMIT 1),
		pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.cms_desc_short_sg LIMIT 1),
		pVocabularyDevSchema	=> 'DEV_ICD9PROC'
	);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Add billing ICD9Proc codes from SOURCES.CMS_DESC_LONG_SG into the CONCEPT_STAGE 
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
SELECT NAME AS concept_name,
	'Procedure' AS domain_id,
	'ICD9Proc' AS vocabulary_id,
	length(code) || '-dig billing code' AS concept_class_id,
	'S' AS standard_concept,
	REGEXP_REPLACE(code, '^([0-9]{2})([0-9]+)', '\1.\2','g') AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD9Proc'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.CMS_DESC_LONG_SG; -- 3882

--4. Add non-billable and hierarchical ICD9Proc codes from SOURCES.mrconso into the CONCEPT_STAGE 
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
SELECT SUBSTR(str, 1, 256) AS concept_name,
	'Procedure' AS domain_id,
	'ICD9Proc' AS vocabulary_id,
	length(replace(code, '.', '')) || '-dig nonbill code' AS concept_class_id,
	'S' AS standard_concept,
	code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD9Proc'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.mrconso
WHERE sab = 'ICD9CM'
	AND tty = 'HT' -- hierarchical terms
	AND (
		devv5.INSTR(code, '.') = 3
		OR -- Dot in 3rd position in Procedure codes, in UMLS also called ICD9CM
		LENGTH(code) = 2 -- Procedure code
		)
	AND code NOT IN (
		SELECT concept_code
		FROM concept_stage
		WHERE vocabulary_id LIKE 'ICD9%'
		)
	AND suppress = 'N';
	
--5. Add ICD9Proc additional names (CMS_DESC_LONG_DX and CMS_DESC_SHORT_DX) from both SOURCES.CMS_DESC_LONG_SG and SOURCES.CMS_DESC_SHORT_SG to the CONCEPT_SYNONYM_STAGE
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT REGEXP_REPLACE(code, '^([0-9]{2})([0-9]+)', '\1.\2','g') AS synonym_concept_code,
	NAME AS synonym_name,
	'ICD9Proc' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
FROM (
	SELECT *
	FROM SOURCES.CMS_DESC_LONG_SG
    	UNION
	SELECT code,
		name
	FROM SOURCES.CMS_DESC_SHORT_SG
	) AS s0;

--6. Add ICD9Proc names of non-billable and hierarchical codes to the CONCEPT_SYNONYM_STAGE
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT code AS synonym_concept_code,
	SUBSTR(str, 1, 256) AS synonym_name,
	'ICD9Proc' AS vocabulary_id,
	4180186 AS language_concept_id -- English
FROM SOURCES.mrconso
WHERE sab = 'ICD9CM'
	AND tty = 'HT'
	AND (
		devv5.INSTR(code, '.') = 3
		OR -- Dot in 3rd position in Procedure codes, in UMLS also called ICD9CM
		LENGTH(code) = 2 -- Procedure code
		)
	AND code NOT IN (
		SELECT concept_code
		FROM concept_stage
		WHERE vocabulary_id LIKE 'ICD9%'
		)
	AND suppress = 'N';

--7. Add ICD9Proc to SNOMED manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--8. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--9. Deprecate 'Maps to' mappings to deprecated and updated concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--10. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--11. Add "Is a" relationship from ICD9Proc descendants (or their standard SNOMED equivalents) to ICD9Proc  ancestors  (or their standard SNOMED equivalents), using ICD9Proc code similarity, to the CONCEPT_RELATIONSHIP_STAGE
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
SELECT concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD9Proc'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT *
	FROM (
		SELECT DISTINCT -- several ICDs can be mapped to the same snomed and it will result in duplicated rows
			COALESCE(cr.concept_code_2, c.concept_code) AS concept_code_1,
			'Is a' AS relationship_id,
			COALESCE(pr.concept_code_2, p.concept_code) AS concept_code_2,
			COALESCE(cr.vocabulary_id_2, c.vocabulary_id) AS vocabulary_id_1,
			COALESCE(pr.vocabulary_id_2, p.vocabulary_id) AS vocabulary_id_2
		FROM concept_stage p
		LEFT JOIN concept_relationship_stage pr ON p.concept_code = pr.concept_code_1
			AND p.vocabulary_id = pr.vocabulary_id_1
			AND pr.relationship_id = 'Maps to'
			AND pr.vocabulary_id_2 = 'SNOMED'
			AND pr.invalid_reason IS NULL
		JOIN concept_stage c ON (
				c.concept_code LIKE p.concept_code || '._'
				OR c.concept_code LIKE p.concept_code || '_'
				)
		LEFT JOIN concept_relationship_stage cr ON c.concept_code = cr.concept_code_1
			AND c.vocabulary_id = cr.vocabulary_id_1
			AND cr.relationship_id = 'Maps to'
			AND cr.vocabulary_id_2 = 'SNOMED'
			AND cr.invalid_reason IS NULL
		WHERE (
				cr.concept_code_2 IS NULL
				OR pr.concept_code_2 IS NULL
				)
		) a
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_relationship_stage crs_int
			WHERE crs_int.concept_code_1 = a.concept_code_1
				AND crs_int.concept_code_2 = a.concept_code_2
				AND crs_int.relationship_id = a.relationship_id
			)
	) b;
	
--12. Build reverse relationship in the CONCEPT_RELATIONSHIP_STAGE. This is necessary for  next point
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
SELECT crs.concept_code_2,
	crs.concept_code_1,
	crs.vocabulary_id_2,
	crs.vocabulary_id_1,
	r.reverse_relationship_id,
	crs.valid_start_date,
	crs.valid_end_date,
	crs.invalid_reason
FROM concept_relationship_stage crs
JOIN relationship r ON r.relationship_id = crs.relationship_id
WHERE NOT EXISTS (
		-- the inverse record
		SELECT 1
		FROM concept_relationship_stage i
		WHERE crs.concept_code_1 = i.concept_code_2
			AND crs.concept_code_2 = i.concept_code_1
			AND crs.vocabulary_id_1 = i.vocabulary_id_2
			AND crs.vocabulary_id_2 = i.vocabulary_id_1
			AND r.reverse_relationship_id = i.relationship_id
		);

--13. Add all old relationships that do not exist in the CONCEPT_RELATIONSHIP_STAGE, using  the CONCEPT_RELATIONSHIP
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
SELECT a.concept_code,
	b.concept_code,
	a.vocabulary_id,
	b.vocabulary_id,
	relationship_id,
	r.valid_start_date,
	CURRENT_DATE,
	'D'
FROM concept a
JOIN concept_relationship r ON a.concept_id = concept_id_1
	AND r.invalid_reason IS NULL
	AND r.relationship_id NOT IN (
		'Concept replaced by',
		'Concept replaces'
		)
JOIN concept b ON b.concept_id = concept_id_2
WHERE (a.vocabulary_id = 'ICD9Proc' AND b.vocabulary_id = 'SNOMED' OR a.vocabulary_id = 'SNOMED' AND b.vocabulary_id = 'ICD9Proc')
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = a.concept_code
			AND crs_int.concept_code_2 = b.concept_code
			AND crs_int.vocabulary_id_1 = a.vocabulary_id
			AND crs_int.vocabulary_id_2 = b.vocabulary_id
			AND crs_int.relationship_id = r.relationship_id
		);

--14. Set NULL as a Standard concept value for all ICD9Proc concepts having 'Maps to' relationship to the SNOMED in the CONCEPT_STAGE
UPDATE concept_stage cs
SET standard_concept = NULL
FROM concept_relationship_stage crs
WHERE cs.concept_code = crs.concept_code_1
	AND cs.vocabulary_id = crs.vocabulary_id_1
	AND crs.relationship_id = 'Maps to'
	AND crs.invalid_reason IS NULL;