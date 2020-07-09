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

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ICD10PCS',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.icd10pcs LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.icd10pcs LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_ICD10PCS'
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
SELECT concept_name,
	'ICD10PCS' AS vocabulary_id,
	'Procedure' AS domain_id,
	case length (concept_code) 
		when 7 then 'ICD10PCS' 
		else 'ICD10PCS Hierarchy'
	end AS concept_class_id,
	'S' AS standard_concept,
	concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD10PCS'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.icd10pcs;

--4. Add 'ICD10PCS Hierarchy' from umls.mrconso
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
SELECT DISTINCT
	-- take the best str
	FIRST_VALUE(SUBSTR(str, 1, 255)) OVER (
		PARTITION BY code ORDER BY CASE tty
				WHEN 'HT'
					THEN 1
				WHEN 'HS'
					THEN 2
				WHEN 'HX'
					THEN 3
				WHEN 'MTH_HX'
					THEN 4
				ELSE 5
				END,
			CASE 
				WHEN LENGTH(str) <= 255
					THEN LENGTH(str)
				ELSE 0
				END DESC,
			str ROWS BETWEEN UNBOUNDED PRECEDING
				AND UNBOUNDED FOLLOWING
		) AS concept_name,
	'ICD10PCS' AS vocabulary_id,
	'Procedure' AS domain_id,
	'ICD10PCS Hierarchy' AS concept_class_id,
	'S' AS standard_concept,
	code AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.mrconso
WHERE sab = 'ICD10PCS'
	AND NOT EXISTS (
		SELECT 1
		FROM concept_stage cs
		WHERE cs.concept_code = code
		);

--5. Add all synonyms to concept_synonym stage from umls.mrconso
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT code AS concept_code,
	str AS synonym_name,
	'ICD10PCS' AS vocabulary_id,
	4180186 AS language_concept_id
FROM SOURCES.mrconso
WHERE sab = 'ICD10PCS'
GROUP BY code,
	str;

--6. Use basic tables as source to include concepts that were previously deprecated: they must remain Standard for historic purposes
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
select
	case
		when c.concept_name like '% (Deprecated)' then c.concept_name
		else c.concept_name || ' (Deprecated)'
	end as concept_name,
	'ICD10PCS',
	'Procedure',
	case length (c.concept_code)
		when 7 then 'ICD10PCS'
		else 'ICD10PCS Hierarchy'
	end as concept_class_id,
	'S',
	c.concept_code,
	c.valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	null as invalid_reason	
from concept c
left join concept_stage s on
	c.concept_code = s.concept_code
where
	c.vocabulary_id = 'ICD10PCS' and
	s.concept_code is null and
	c.concept_code not like 'MTHU00000_' -- Junk concepts
;
--7. Preserve synonyms for such concepts
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
select
	c.concept_code,
	s.concept_synonym_name,
	'ICD10PCS' AS vocabulary_id,
	4180186 AS language_concept_id
from concept_synonym s
join concept c on
	c.concept_id = s.concept_id and
	c.vocabulary_id = 'ICD10PCS'
left join sources.icd10pcs i on
	i.concept_code = c.concept_code
where i.concept_code is null
;
--8. Insert all missing concept_names as synonyms
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
select
	concept_code,
	concept_name,
	'ICD10PCS' AS vocabulary_id,
	4180186 AS language_concept_id
from concept_stage
where
	(concept_code,concept_name) not in
	(
		select
			synonym_concept_code,
			synonym_name
		from concept_synonym_stage
	)
;
--9. Add "subsumes" relationship between concepts where the concept_code is direct descendant of another
CREATE INDEX IF NOT EXISTS trgm_idx ON concept_stage USING GIN (concept_code devv5.gin_trgm_ops); --for LIKE patterns
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
WHERE c2.concept_code LIKE c1.concept_code || '_'
	AND c1.concept_code <> c2.concept_code
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage r_int
		WHERE r_int.concept_code_1 = c1.concept_code
			AND r_int.concept_code_2 = c2.concept_code
			AND r_int.relationship_id = 'Subsumes'
		);

--10. Deprecate old "Subsumes" relationships that may have jumped levels
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
select
	c.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	c.vocabulary_id AS vocabulary_id_1,
	c2.vocabulary_id AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	r.valid_start_date AS valid_start_date,
	(
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = c.vocabulary_id
	) AS valid_end_date,
	'D' AS invalid_reason
from concept c
join concept_relationship r on
	c.vocabulary_id = 'ICD10PCS' and
	r.concept_id_1 = c.concept_id and
	r.relationship_id = 'Subsumes'
join concept c2 on
	c2.vocabulary_id = 'ICD10PCS' and
	r.concept_id_2 = c2.concept_id
left join concept_relationship_stage s on
	c.concept_code = s.concept_code_1 and
	c2.concept_code = s.concept_code_2 and
	s.relationship_id = 'Subsumes'
where s.relationship_id is null
;
DROP INDEX trgm_idx;

--11. Add ICD10PCS to SNOMED relations
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--12. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--13. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--14. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--15. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script