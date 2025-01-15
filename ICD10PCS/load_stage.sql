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
* Authors: Timur Vakhitov, Christian Reich, Eduard Korchmar
* Date: 2021
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ICD10PCS',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.icd10pcs LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.icd10pcs LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_ICD10PCS');
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Add all billable ICD10PCS Procedures and 3-character Hierarchical terms (number of inserted concepts has to be equal to https://www.nlm.nih.gov/research/umls/sourcereleasedocs/current/ICD10PCS/stats.html)
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
	CASE LENGTH(concept_code)
		WHEN 7
			THEN 'ICD10PCS' -- billable codes have length(concept_code) = 7
		ELSE 'ICD10PCS Hierarchy' -- non-billable codes have length(concept_code) < 7
		END AS concept_class_id,
	'S' AS standard_concept, -- non-billable Hierarchy concepts are met in patient data, that is why they are considered to be Standard as well
	concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD10PCS'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.icd10pcs;

--4. Add all the other ICD10PCS Hierarchical terms from umls.mrconso
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
	FIRST_VALUE(vocabulary_pack.CutConceptName(str)) OVER (
		PARTITION BY code ORDER BY CASE tty
				WHEN 'PT' -- Preferred term (designated preferred name)
					THEN 1
				WHEN 'HT' -- Hierarchical term
					THEN 2
				WHEN 'HS' -- Short or alternate version of hierarchical term
					THEN 3
				WHEN 'HX' -- Expanded version of short hierarchical term
					THEN 4
				WHEN 'MTH_HX' -- MTH Hierarchical term expanded 
					THEN 5
				ELSE 6
				END,
			CASE 
				WHEN LENGTH(str) <= 255
					THEN LENGTH(str)
				ELSE 0
				END DESC,
			str
		) AS concept_name,
	'ICD10PCS' AS vocabulary_id,
	'Procedure' AS domain_id,
	'ICD10PCS Hierarchy' AS concept_class_id,
	'S' AS standard_concept, -- non-billable Hierarchy concepts are met in patient data, that is why they are considered to be Standard as well
	code AS concept_code,
	(	SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD10PCS'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.mrconso mr
WHERE mr.sab = 'ICD10PCS'
	AND NOT EXISTS (
		SELECT 1
		FROM concept_stage cs
		WHERE cs.concept_code = mr.code
		);

--5. Add all synonyms from umls.mrconso to concept_synonym stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT mr.code AS concept_code,
	mr.str AS synonym_name,
	'ICD10PCS' AS vocabulary_id,
	4180186 AS language_concept_id
FROM sources.mrconso mr
LEFT JOIN concept_stage cs ON cs.concept_code = mr.code
	AND LOWER(cs.concept_name) = LOWER(mr.str)
WHERE mr.sab = 'ICD10PCS'
  	AND mr.suppress NOT IN (
		'E',
		'O',
		'Y'
		)
	AND cs.concept_code IS NULL;

--6. "Resurrect" previously deprecated concepts using the basic tables (they, being encountered in patient data, must remain Standard!)
-- Add 'Deprecated' to concept_names to show the fact of deprecation by the source (we expect codes to be deprecated each release cycle)
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
SELECT CASE 
		WHEN c.concept_name LIKE '% (Deprecated)'
			THEN c.concept_name -- to support subsequent source deprecations 
		WHEN LENGTH(c.concept_name) <= 242
			THEN c.concept_name || ' (Deprecated)' -- to get no more than 255 characters in total
		ELSE LEFT(c.concept_name, 239) || '... (Deprecated)' -- to get no more than 255 characters in total and highlight concept_names which were cut
		END AS concept_name,
	'ICD10PCS',
	'Procedure',
	CASE LENGTH(c.concept_code)
		WHEN 7
			THEN 'ICD10PCS' -- billable codes have length(concept_code) = 7
		ELSE 'ICD10PCS Hierarchy' -- non-billable codes have length(concept_code) < 7
		END AS concept_class_id,
	'S' AS standard_concept, -- resurrection as is
	c.concept_code,
	c.valid_start_date,
	(
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = c.vocabulary_id
		) AS valid_end_date, -- analogically to https://github.com/OHDSI/Vocabulary-v5.0/blob/4752f272a51761df2bda3b5c692b657c72f52027/working/generic_update.sql#L240
	NULL AS invalid_reason
FROM concept c
LEFT JOIN concept_stage s ON s.concept_code = c.concept_code
WHERE c.vocabulary_id = 'ICD10PCS'
	AND s.concept_code IS NULL
	AND c.concept_code NOT LIKE 'MTHU00000_';-- to exclude internal technical source codes

--7. Add synonyms for resurrected concepts using the concept_synonym table
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT c.concept_code,
	s.concept_synonym_name,
	'ICD10PCS' AS vocabulary_id,
	4180186 AS language_concept_id
FROM concept_synonym s
JOIN concept c ON c.concept_id = s.concept_id
	AND c.vocabulary_id = 'ICD10PCS'
	AND LOWER(c.concept_name) <> LOWER(s.concept_synonym_name)
LEFT JOIN sources.icd10pcs i ON i.concept_code = c.concept_code
WHERE i.concept_code IS NULL
	AND c.concept_code NOT LIKE 'MTHU00000_' -- to exclude internal technical source codes
ON CONFLICT DO NOTHING;

--8. Add original names of resurrected concepts using the concept table
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT c.concept_code,
	c.concept_name,
	'ICD10PCS' AS vocabulary_id,
	4180186 AS language_concept_id
FROM concept c
LEFT JOIN sources.icd10pcs i ON i.concept_code = c.concept_code
LEFT JOIN concept_synonym_stage css ON css.synonym_concept_code = c.concept_code
	AND LOWER(css.synonym_name) = LOWER(c.concept_name)
	AND c.concept_name NOT LIKE '% (Deprecated)'
WHERE c.vocabulary_id = 'ICD10PCS'
	AND i.concept_code IS NULL
	AND css.synonym_concept_code IS NULL
	AND c.concept_code NOT LIKE 'MTHU00000_';-- to exclude internal technical source codes

--9. Process manual tables for concept and relationship
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--10. Build 'Subsumes' relationships from ancestors to immediate descendants using concept code similarity; build direct ancestorship relation with the longest code
CREATE INDEX IF NOT EXISTS trgm_idx ON concept_stage USING GIN (concept_code devv5.gin_trgm_ops); -- for LIKE patterns
ANALYZE concept_stage;

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
SELECT DISTINCT ON (c2.concept_code) c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	'ICD10PCS' AS vocabulary_id_1,
	'ICD10PCS' AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD10PCS'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage c1
JOIN concept_stage c2 ON c2.concept_code LIKE c1.concept_code || '%'
	AND c1.concept_code <> c2.concept_code
--pick the most granular available ancestor
ORDER BY c2.concept_code,
	LENGTH(c1.concept_code) DESC,
	c1.concept_code;

DROP INDEX trgm_idx;

--11. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--12. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

--13. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--14. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--15. All concepts mapped to RxNorm/RxNorm Ext./CVX should be assigned with Drug domain
UPDATE concept_stage cs
SET domain_id = 'Drug'
FROM concept_relationship_stage crs
WHERE crs.vocabulary_id_2 IN (
		'RxNorm',
		'RxNorm Extension',
		'CVX'
		)
	AND crs.relationship_id = 'Maps to'
	AND crs.invalid_reason IS NULL
	AND cs.concept_class_id = 'ICD10PCS'
	AND cs.concept_code = crs.concept_code_1
	AND cs.vocabulary_id = crs.vocabulary_id_1;

SELECT admin_pack.VirtualLogIn ('dev_mkhitrun','Do_Not_Share_Your_Pass_2024!');

   DO $_$
   BEGIN
       PERFORM devv5.GenericUpdate();
   END $_$;
-- At the end, the concept_stage, concept_relationship_stage and concept_synonym_stage tables are ready to be fed into the generic_update script