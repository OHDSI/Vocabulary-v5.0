/**************************************************************************
* Copyright 2016 Observational Health Data Sciences AND Informatics (OHDSI)
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
* Authors: Eduard Korchmar, Dmitry Dymshyts, Timur Vakhitov
* Date: 2020
**************************************************************************/

--1. UPDATE latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ICD9ProcCN',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.icd9proccn_concept LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.icd9proccn_concept LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_ICD9PROCCN'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Create concept_stage
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	concept_code,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT COALESCE(c2.concept_name, c1.concept_name, c.english_concept_name || ' (machine translation)') AS concept_name,
	'Procedure' AS domain_id,
	'ICD9ProcCN' AS vocabulary_id,
	CASE c.concept_class_id
		WHEN '六位数扩展码主要编码'
			THEN '6-dig billing code'
		WHEN '六位数扩展码附加编码'
			THEN '6-dig billing code'
		WHEN '四位数细目编码'
			THEN '4-dig nonbill code'
		WHEN '三位数亚目编码'
			THEN '3-dig nonbill code'
		WHEN '二位数类目编码'
			THEN '2-dig nonbill code'
		WHEN '章编码'
			THEN 'ICD9Proc Chapter'
		ELSE 'Undefined'
		END AS concept_class_id,
	regexp_replace(c.concept_code, '第\d\d?章: ', '') AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD9ProcCN'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM sources.icd9proccn_concept c
LEFT JOIN concept c1 ON c1.concept_code = c.concept_code
	AND c1.vocabulary_id = 'ICD9Proc'
LEFT JOIN concept c2 ON c.concept_code = rpad(c2.concept_code, 5, 'x') || '00'
	AND c2.vocabulary_id = 'ICD9Proc' -- Generic equivalency, 6-dig code = 4-dig code + 00
WHERE c.concept_code <> 'Metadata'
	AND
	--don't include Chapters that have only one subchapter
	c.concept_code !~ ': \d\d$';

--4. Create concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT i.concept_code,
	i.concept_name AS synonym_name,
	'ICD9ProcCN' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
FROM concept_stage i

UNION ALL

SELECT regexp_replace(i.concept_code, '第\d\d?章: ', ''),
	i.concept_name AS synonym_name,
	'ICD9ProcCN' AS synonym_vocabulary_id,
	4182948 AS language_concept_id -- Chinese
FROM sources.icd9proccn_concept i
WHERE i.concept_code <> 'Metadata'
	AND
	--don't include Chapters that have only one subchapter
	i.concept_code !~ ': \d\d$';

--5. Ingest internal hierarchy from source
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT c1.concept_code AS concept_code_1,
	regexp_replace(c2.concept_code, '第\d\d?章: ', '') AS concept_code_2,
	'ICD9ProcCN' AS vocabulary_id_1,
	'ICD9ProcCN' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD9ProcCN'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM sources.icd9proccn_concept_relationship r
JOIN sources.icd9proccn_concept c1 ON c1.concept_id = r.concept_id_1
JOIN sources.icd9proccn_concept c2 ON c2.concept_id = r.concept_id_2
WHERE r.relationship_id = 'Is a'
	AND
	--don't include Chapters that have only one subchapter
	c2.concept_code !~ ': \d\d$';

--6. Map to standard procedures over ICD9Proc
CREATE INDEX IF NOT EXISTS trgm_idx ON concept_stage USING GIN (concept_code devv5.gin_trgm_ops); --for LIKE patterns
ANALYZE concept_stage;

INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
WITH icd_parents AS (
		SELECT DISTINCT cs.concept_code,
			FIRST_VALUE(c.concept_id) OVER (
				PARTITION BY cs.concept_code ORDER BY length(c.concept_code) DESC --longest matching code for best results
				) AS concept_id
		FROM concept_stage cs
		JOIN concept c ON c.vocabulary_id = 'ICD9Proc'
			AND cs.concept_code LIKE c.concept_code || '%' --allow fuzzy match uphill for this iteration
		WHERE cs.concept_code NOT LIKE '%-%'
			AND cs.concept_class_id <> 'ICD9Proc Chapter'
		)
SELECT i.concept_code AS concept_code_1,
	c.concept_code AS concept_code_2,
	'ICD9ProcCN' AS vocabulary_id_1,
	c.vocabulary_id AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD9ProcCN'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM icd_parents i
JOIN concept_relationship cr ON cr.concept_id_1 = i.concept_id
	AND cr.relationship_id = 'Maps to'
	AND cr.invalid_reason IS NULL
JOIN concept c ON c.concept_id = cr.concept_id_2;

--7. Append resulting file from Medical Coder (in concept_relationship_stage format) to concept_relationship_stage
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--8. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--9. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--10. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--11. Clean up
DROP INDEX trgm_idx;

--12. Assign domains by mapping targets
-- Commented: SNOMED domains need fixing first
/*update concept_stage s
set
	domain_id = coalesce
		(
			(
				select c.domain_id
				from concept c
				join relationship_concept_stage r on
					r.concept_code_2 = c.concept_code and
					r.vocabulary_id_2 = c.vocabulary_id and
					r.relationship_id = 'Maps to' and
					r.invalid_reason is null
				where r.concept_code_1 = s.concept_code
			),
			'Procedure'
		)*/

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script