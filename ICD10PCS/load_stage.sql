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

--3. Add all billable ICD10PCS Procedures (77559) and 3-character Hierarchical terms (880) (number of concepts has to be equal to https://www.nlm.nih.gov/research/umls/sourcereleasedocs/current/ICD10PCS/stats.html)
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
		when 7 then 'ICD10PCS' -- billable codes have length(concept_code) = 7
		else 'ICD10PCS Hierarchy' -- non-billable codes have length(concept_code) < 7
	end AS concept_class_id,
	 'S' AS standard_concept, -- non-billable Hierarchy concepts are met in patient data, that is why they are considered to be Standard as well
	concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD10PCS'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.icd10pcs; -- 78 439

--4. Add all the other ICD10PCS Hierarchical terms from umls.mrconso -- why are they coming from different sources?
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
				WHEN 'HT' -- Hierarchical term
					THEN 1
				WHEN 'HS' -- Short or alternate version of hierarchical term
					THEN 2
				WHEN 'HX' -- 	Expanded version of short hierarchical term 
					THEN 3
				WHEN 'MTH_HX' -- MTH Hierarchical term expanded 
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
	'S' AS standard_concept, -- non-billable Hierarchy concepts are met in patient data, that is why they are considered to be Standard as well
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
		); -- 111060

--5. Add all synonyms from umls.mrconso to concept_synonym stage
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
	str; -- 324257

--6. "Resurrect" previously deprecated concepts using the basic tables (they, being encountered in patient data, must remain Standard!). 
-- Add 'Deprecated' to concept_name to show the fact of deprecation by the source (we expect codes to be deprecated each release cycle)
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
		when c.concept_name like '% (Deprecated)' then c.concept_name -- to support subsequent source deprecations 
		when length (c.concept_name) <= 242 then c.concept_name || ' (Deprecated)' -- to get no more than 255 characters in total
		else left (c.concept_name, 239) || '... (Deprecated)' -- to get no more than 255 characters in total and highlight concept_names which were cut
	end as concept_name,
	'ICD10PCS',
	'Procedure',
	case length (c.concept_code)
		when 7 then 'ICD10PCS' -- billable codes have length(concept_code) = 7
		else 'ICD10PCS Hierarchy' -- non-billable codes have length(concept_code) < 7
	end as concept_class_id,
  'S' AS standard_concept, -- resurrection as is
	c.concept_code,
	c.valid_start_date,
	(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = c.vocabulary_id) AS valid_end_date, -- analogically to https://github.com/OHDSI/Vocabulary-v5.0/blob/4752f272a51761df2bda3b5c692b657c72f52027/working/generic_update.sql#L240
	null as invalid_reason	
from concept c
left join concept_stage s on
	c.concept_code = s.concept_code
where
	c.vocabulary_id = 'ICD10PCS' and
	s.concept_code is null and
	c.concept_code not like 'MTHU00000_' -- to exclude internal technical source codes
; -- 4271

--7. Add synonyms for resurrected concepts using the concept_synonym table
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
where
	i.concept_code is null and
	c.concept_code not like 'MTHU00000_'  -- to exclude internal technical source codes
;-- 120860

--8. Add original names of resurrected concepts using the concept table
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
select
	c.concept_code,
	c.concept_name,
	'ICD10PCS' AS vocabulary_id,
	4180186 AS language_concept_id
from concept c
left join sources.icd10pcs i on
	i.concept_code = c.concept_code
left join concept_synonym_stage a on
	(c.concept_code,c.concept_name) = (a.synonym_concept_code,a.synonym_name)
where
	c.vocabulary_id = 'ICD10PCS' and
	i.concept_code is null and
	a.synonym_concept_code is null and
	c.concept_code not like 'MTHU00000_'  -- to exclude internal technical source codes
; -- 12 

--9. Build 'Subsumes' relationships from ancestors to immediate descendants using concept code similarity (c2.concept_code LIKE c1.concept_code || '_')
CREATE INDEX IF NOT EXISTS trgm_idx ON concept_stage USING GIN (concept_code devv5.gin_trgm_ops); -- for LIKE patterns
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
		); -- 193753

--10. Deprecate 'Subsumes' relationships for resurrected concepts to avoid possible violations of the hierarchy
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
where s.concept_code_1 is null
; -- 19395
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

-- At the end, the concept_stage, concept_relationship_stage and concept_synonym_stage tables are ready to be fed into the generic_update script
