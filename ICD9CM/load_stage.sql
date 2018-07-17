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
		pVocabularyName			=> 'ICD9CM',
		pVocabularyDate			=> (SELECT vocabulary_date FROM sources.cms_desc_short_dx LIMIT 1),
		pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.cms_desc_short_dx LIMIT 1),
		pVocabularyDevSchema	=> 'DEV_ICD9CM'
	);
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Load into concept_stage from CMS_DESC_LONG_DX
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
	NULL AS domain_id,
	'ICD9CM' AS vocabulary_id,
	CASE 
		WHEN SUBSTR(code, 1, 1) = 'V'
			THEN length(code) || '-dig billing V code'
		WHEN SUBSTR(code, 1, 1) = 'E'
			THEN length(code) - 1 || '-dig billing E code'
		ELSE length(code) || '-dig billing code'
		END AS concept_class_id,
	NULL AS standard_concept,
	CASE -- add dots to the codes
		WHEN SUBSTR(code, 1, 1) = 'V'
			THEN REGEXP_REPLACE(code, 'V([0-9]{2})([0-9]+)', 'V\1.\2','g') -- Dot after 2 digits for V codes
		WHEN SUBSTR(code, 1, 1) = 'E'
			THEN REGEXP_REPLACE(code, 'E([0-9]{3})([0-9]+)', 'E\1.\2','g') -- Dot after 3 digits for E codes
		ELSE REGEXP_REPLACE(code, '^([0-9]{3})([0-9]+)', '\1.\2','g') -- Dot after 3 digits for normal codes
		END AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD9CM'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.CMS_DESC_LONG_DX;

--4. Add codes which are not in the CMS_DESC_LONG_DX table
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
	NULL AS domain_id,
	'ICD9CM' AS vocabulary_id,
	CASE 
		WHEN SUBSTR(code, 1, 1) = 'V'
			THEN length(replace(code, '.', '')) || '-dig nonbill V code'
		WHEN SUBSTR(code, 1, 1) = 'E'
			THEN length(replace(code, '.', '')) - 1 || '-dig nonbill E code'
		ELSE length(replace(code, '.', '')) || '-dig nonbill code'
		END AS concept_class_id,
	NULL AS standard_concept,
	code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD9CM'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.mrconso
WHERE sab = 'ICD9CM'
	AND NOT code LIKE '%-%'
	AND tty = 'HT'
	AND devv5.INSTR(code, '.') != 3 -- Dot in 3rd position in Procedure codes, in UMLS also called ICD9CM
	AND LENGTH(code) != 2 -- Procedure code
	AND code NOT IN (
		SELECT concept_code
		FROM concept_stage
		WHERE vocabulary_id = 'ICD9CM'
		)
	AND suppress = 'N';

--5. load into concept_synonym_stage name from both CMS_DESC_LONG_DX.txt and CMS_DESC_SHORT_DX
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT CASE -- add dots to the codes
		WHEN SUBSTR(code, 1, 1) = 'V'
			THEN REGEXP_REPLACE(code, 'V([0-9]{2})([0-9]+)', 'V\1.\2','g') -- Dot after 2 digits for V codes
		WHEN SUBSTR(code, 1, 1) = 'E'
			THEN REGEXP_REPLACE(code, 'E([0-9]{3})([0-9]+)', 'E\1.\2','g') -- Dot after 3 digits for E codes
		ELSE REGEXP_REPLACE(code, '^([0-9]{3})([0-9]+)', '\1.\2','g') -- Dot after 3 digits for normal codes
		END AS synonym_concept_code,
	NAME AS synonym_name,
	'ICD9CM' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
FROM (
	SELECT *
	FROM SOURCES.CMS_DESC_LONG_DX
	
	UNION
	
	SELECT code,
		name
	FROM SOURCES.CMS_DESC_SHORT_DX
	) AS s0;

--6. Add codes which are not in the cms_desc_long_dx table as a synonym
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT code AS synonym_concept_code,
	SUBSTR(str, 1, 256) AS synonym_name,
	'ICD9CM' AS vocabulary_id,
	4180186 AS language_concept_id -- English
FROM SOURCES.mrconso
WHERE sab = 'ICD9CM'
	AND NOT code LIKE '%-%'
	AND tty = 'HT'
	AND devv5.INSTR(code, '.') != 3 -- Dot in 3rd position in Procedure codes, in UMLS also called ICD9CM
	AND LENGTH(code) != 2 -- Procedure code
	AND code NOT IN (
		SELECT concept_code
		FROM concept_stage
		WHERE vocabulary_id = 'ICD9CM'
		)
	AND suppress = 'N';
/*
--7. Create text for Medical Coder with new codes and mappings
SELECT c.concept_code AS concept_code_1,
	u2.scui AS concept_code_2,
	'Maps to' AS relationship_id, -- till here strawman for concept_relationship to be checked and filled out, the remaining are supportive information to be truncated in the return file
	c.concept_name AS icd9_name,
	u2.str AS snomed_str,
	sno.concept_id AS snomed_concept_id,
	sno.concept_name AS snomed_name
FROM concept_stage c
LEFT JOIN (
	-- UMLS record for ICD9 code
	SELECT DISTINCT cui,
		scui
	FROM SOURCES.mrconso
	WHERE sab = 'ICD9CM'
		AND suppress NOT IN (
			'E',
			'O',
			'Y'
			)
	) u1 ON u1.scui = concept_code -- join UMLS for code one
LEFT JOIN (
	-- UMLS record for SNOMED code of the same cui
	SELECT DISTINCT cui,
		scui,
		FIRST_VALUE(str) OVER (
			PARTITION BY scui ORDER BY CASE tty
					WHEN 'PT'
						THEN 1
					WHEN 'PTGB'
						THEN 2
					ELSE 10
					END
			) AS str
	FROM SOURCES.mrconso
	WHERE sab IN ('SNOMEDCT_US')
		AND suppress NOT IN (
			'E',
			'O',
			'Y'
			)
	) u2 ON u2.cui = u1.cui
LEFT JOIN concept sno ON sno.vocabulary_id = 'SNOMED'
	AND sno.concept_code = u2.scui -- SNOMED concept
WHERE c.vocabulary_id = 'ICD9CM'
	AND NOT EXISTS (
		SELECT 1
		FROM concept co
		WHERE co.concept_code = c.concept_code
			AND co.vocabulary_id = 'ICD9CM'
		) limit 10;-- only new codes we don't already have
*/

--8. Append resulting file from Medical Coder (in concept_relationship_stage format) to concept_relationship_stage
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--9. Add "subsumes" relationship between concepts where the concept_code is like of another
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
SELECT c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	c1.vocabulary_id AS vocabulary_id_1,
	c1.vocabulary_id AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = c1.vocabulary_id
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage c1,
	concept_stage c2
WHERE c2.concept_code LIKE c1.concept_code || '%'
	AND c1.concept_code <> c2.concept_code
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage r_int
		WHERE r_int.concept_code_1 = c1.concept_code
			AND r_int.concept_code_2 = c2.concept_code
			AND r_int.relationship_id = 'Subsumes'
		);

--10. update domain_id for ICD9CM from SNOMED
--create 1st temporary table ICD9CM_domain with direct mappings
DROP TABLE IF EXISTS filled_domain;
CREATE UNLOGGED TABLE filled_domain AS
	WITH domain_map2value AS (
			--ICD9CM have direct "Maps to value" mapping
			SELECT c1.concept_code,
				c2.domain_id
			FROM concept_relationship_stage r,
				concept_stage c1,
				concept c2
			WHERE c1.concept_code = r.concept_code_1
				AND c2.concept_code = r.concept_code_2
				AND c1.vocabulary_id = r.vocabulary_id_1
				AND c2.vocabulary_id = r.vocabulary_id_2
				AND r.vocabulary_id_1 = 'ICD9CM'
				AND r.vocabulary_id_2 = 'SNOMED'
				AND r.relationship_id = 'Maps to value'
				AND r.invalid_reason IS NULL
			)
SELECT d.concept_code,
	--some rules for domain_id
	CASE 
		WHEN d.domain_id IN (
				'Procedure',
				'Measurement'
				)
			AND EXISTS (
				SELECT 1
				FROM domain_map2value t
				WHERE t.concept_code = d.concept_code
					AND t.domain_id IN (
						'Meas Value',
						'Spec Disease Status'
						)
				)
			THEN 'Measurement'
		WHEN d.domain_id = 'Procedure'
			AND EXISTS (
				SELECT 1
				FROM domain_map2value t
				WHERE t.concept_code = d.concept_code
					AND t.domain_id = 'Condition'
				)
			THEN 'Condition'
		WHEN d.domain_id = 'Condition'
			AND EXISTS (
				SELECT 1
				FROM domain_map2value t
				WHERE t.concept_code = d.concept_code
					AND t.domain_id = 'Procedure'
				)
			THEN 'Condition'
		WHEN d.domain_id = 'Observation'
			THEN 'Observation'
		ELSE d.domain_id
		END domain_id
FROM --simplify domain_id
	(
	SELECT concept_code,
		CASE 
			WHEN domain_id = 'Condition/Measurement'
				THEN 'Condition'
			WHEN domain_id = 'Condition/Procedure'
				THEN 'Condition'
			WHEN domain_id = 'Condition/Observation'
				THEN 'Observation'
			WHEN domain_id = 'Observation/Procedure'
				THEN 'Observation'
			WHEN domain_id = 'Measurement/Observation'
				THEN 'Observation'
			WHEN domain_id = 'Measurement/Procedure'
				THEN 'Measurement'
			ELSE domain_id
			END domain_id
	FROM (
		--ICD9CM have direct "Maps to" mapping
		SELECT concept_code,
			string_agg(domain_id, '/' ORDER BY domain_id) domain_id
		FROM (
			SELECT DISTINCT c1.concept_code,
				c2.domain_id
			FROM concept_relationship_stage r,
				concept_stage c1,
				concept c2
			WHERE c1.concept_code = r.concept_code_1
				AND c2.concept_code = r.concept_code_2
				AND c1.vocabulary_id = r.vocabulary_id_1
				AND c2.vocabulary_id = r.vocabulary_id_2
				AND r.vocabulary_id_1 = 'ICD9CM'
				AND r.vocabulary_id_2 = 'SNOMED'
				AND r.relationship_id = 'Maps to'
				AND r.invalid_reason IS NULL
			) AS s0
		GROUP BY concept_code
		) AS s1
	) AS d;

--create 2d temporary table with ALL ICD9CM domains
--if domain_id is empty we use previous and next domain_id or its combination
DROP TABLE IF EXISTS ICD9CM_domain;
CREATE UNLOGGED TABLE ICD9CM_domain AS
SELECT concept_code,
	CASE 
		WHEN domain_id IS NOT NULL
			THEN domain_id
		ELSE CASE 
				WHEN prev_domain = next_domain
					THEN prev_domain --prev and next domain are the same (and of course not null both)
				WHEN prev_domain IS NOT NULL
					AND next_domain IS NOT NULL
					THEN CASE 
							WHEN prev_domain < next_domain
								THEN prev_domain || '/' || next_domain
							ELSE next_domain || '/' || prev_domain
							END -- prev and next domain are not same and not null both, with order by name
				ELSE coalesce(prev_domain, next_domain, 'Unknown')
				END
		END domain_id
FROM (
	SELECT concept_code,
		string_agg(domain_id, '/' ORDER BY domain_id) domain_id,
		prev_domain,
		next_domain
	FROM (
		SELECT DISTINCT c1.concept_code,
			r1.domain_id,
			(
				SELECT DISTINCT LAST_VALUE(fd.domain_id) OVER (
						ORDER BY fd.concept_code ROWS BETWEEN UNBOUNDED PRECEDING
								AND UNBOUNDED FOLLOWING
						)
				FROM filled_domain fd
				WHERE fd.concept_code < c1.concept_code
					AND r1.domain_id IS NULL
				) prev_domain,
			(
				SELECT DISTINCT FIRST_VALUE(fd.domain_id) OVER (
						ORDER BY fd.concept_code ROWS BETWEEN UNBOUNDED PRECEDING
								AND UNBOUNDED FOLLOWING
						)
				FROM filled_domain fd
				WHERE fd.concept_code > c1.concept_code
					AND r1.domain_id IS NULL
				) next_domain
		FROM concept_stage c1
		LEFT JOIN filled_domain r1 ON r1.concept_code = c1.concept_code
		WHERE c1.vocabulary_id = 'ICD9CM'
		) AS s0
	GROUP BY concept_code,
		prev_domain,
		next_domain
	) AS s1;

-- INDEX was set as UNIQUE to prevent concept_code duplication
CREATE UNIQUE INDEX idx_ICD9CM_domain ON ICD9CM_domain (concept_code);

--11. simplify the list by removing Observations
UPDATE ICD9CM_domain
SET domain_id = trim('/' FROM replace('/' || domain_id || '/', '/Observation/', '/'))
WHERE '/' || domain_id || '/' LIKE '%/Observation/%'
	AND devv5.instr(domain_id, '/') <> 0;

--reducing some domain_id if his length>20
UPDATE ICD9CM_domain
SET domain_id = 'Meas/Procedure'
WHERE domain_id = 'Measurement/Procedure';

UPDATE ICD9CM_domain
SET domain_id = 'Condition/Meas'
WHERE domain_id = 'Condition/Measurement';

--Provisional removal of Spec Disease Status, will need review
UPDATE ICD9CM_domain
SET domain_id = 'Procedure'
WHERE domain_id = 'Procedure/Spec Disease Status';

-- Check that all domain_id are exists in domain table
ALTER TABLE ICD9CM_domain ADD CONSTRAINT fk_icd9cm_domain FOREIGN KEY (domain_id) REFERENCES domain (domain_id);

--12. update each domain_id with the domains field from ICD9CM_domain.
UPDATE concept_stage c
SET domain_id = rd.domain_id
FROM ICD9CM_domain rd
WHERE rd.concept_code = c.concept_code
	AND c.vocabulary_id = 'ICD9CM';

--13. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--14. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--15. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--16. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--17. Clean up
DROP TABLE ICD9CM_domain;
DROP TABLE filled_domain;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script