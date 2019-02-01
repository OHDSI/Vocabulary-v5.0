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
	pVocabularyName			=> 'CIEL',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.concept_class_ciel LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.concept_class_ciel LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_CIEL'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Load into concept_stage
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
SELECT DISTINCT FIRST_VALUE(cn."name") OVER (
		PARTITION BY c.concept_id ORDER BY CASE 
				WHEN LENGTH(cn."name") <= 255
					THEN LENGTH(cn."name")
				ELSE 0
				END DESC,
			LENGTH(cn."name") ROWS BETWEEN UNBOUNDED PRECEDING
				AND UNBOUNDED FOLLOWING
		) AS concept_name,
	CASE ccl."name"
		WHEN 'Test'
			THEN 'Measurement'
		WHEN 'Procedure'
			THEN 'Procedure'
		WHEN 'Drug'
			THEN 'Drug'
		WHEN 'Diagnosis'
			THEN 'Condition'
		WHEN 'Finding'
			THEN 'Condition'
		WHEN 'Anatomy'
			THEN 'Spec Anatomic Site'
		WHEN 'Question'
			THEN 'Observation'
		WHEN 'LabSet'
			THEN 'Measurement'
		WHEN 'MedSet'
			THEN 'Drug'
		WHEN 'ConvSet'
			THEN 'Observation'
		WHEN 'Misc'
			THEN 'Observation'
		WHEN 'Symptom'
			THEN 'Condition'
		WHEN 'Symptom/Finding'
			THEN 'Condition'
		WHEN 'Specimen'
			THEN 'Specimen'
		WHEN 'Misc Order'
			THEN 'Observation'
		WHEN 'Workflow'
			THEN 'Observation' -- no concepts of this class in table
		WHEN 'State'
			THEN 'Observation'
		WHEN 'Program'
			THEN 'Observation'
		WHEN 'Aggregate Measurement'
			THEN 'Measurement'
		WHEN 'Indicator'
			THEN 'Observation' -- no concepts of this class in table
		WHEN 'Health Care Monitoring Topics'
			THEN 'Observation' -- no concepts of this class in table
		WHEN 'Radiology/Imaging Procedure'
			THEN 'Procedure' -- there are LOINC codes which are Measurement, but results are not connected
		WHEN 'Frequency'
			THEN 'Observation' -- this is SIG in CDM, which is not normalized today
		WHEN 'Pharmacologic Drug Class'
			THEN 'Drug'
		WHEN 'Units of Measure'
			THEN 'Unit'
		WHEN 'Organism'
			THEN 'Observation'
		WHEN 'Drug form'
			THEN 'Drug'
		WHEN 'Medical supply'
			THEN 'Device'
		END AS domain_id,
	'CIEL' AS vocabulary_id,
	CASE ccl."name" -- shorten the ones that won't fit the 20 char limit
		WHEN 'Aggregate Measurement'
			THEN 'Aggregate Meas'
		WHEN 'Health Care Monitoring Topics'
			THEN 'Monitoring' -- no concepts of this class in table
		WHEN 'Radiology/Imaging Procedure'
			THEN 'Radiology' -- there are LOINC codes which are Measurement, but results are not connected
		WHEN 'Pharmacologic Drug Class'
			THEN 'Drug Class'
		ELSE ccl."name"
		END AS concept_class_id,
	NULL AS standard_concept,
	c.concept_id AS concept_code,
	coalesce(c.date_created, TO_DATE('19700101', 'yyyymmdd')) AS valid_start_date,
	CASE c.retired
		WHEN 0
			THEN TO_DATE('20991231', 'yyyymmdd')
		ELSE (
				SELECT latest_update
				FROM vocabulary
				WHERE vocabulary_id = 'CIEL'
				)
		END AS valid_end_date,
	CASE c.retired
		WHEN 0
			THEN NULL
		ELSE 'D' -- we might change that.
		END AS invalid_reason
FROM sources.concept_ciel c
LEFT JOIN sources.concept_class_ciel ccl ON c.class_id = ccl.concept_class_id
LEFT JOIN sources.concept_name cn ON cn.concept_id = c.concept_id
	AND cn.locale = 'en';

--START TEMPORARY FIX--
--for strange reason we have 4 concepts without concept_name
UPDATE concept_stage
   SET concept_name = 'Concept ||c.concept_id'
 WHERE concept_name IS NULL;
--END TEMPORARY FIX--

--4. Create chain between CIEL and the best OMOP concept and create map
DROP TABLE IF EXISTS ciel_to_concept_map;
CREATE unlogged TABLE ciel_to_concept_map AS
	WITH recursive hierarchy_concepts AS (
			SELECT concept_name_1,
				concept_code_1,
				vocabulary_id_1,
				concept_name_2,
				concept_code_2,
				vocabulary_id_2,
				concept_name_1 AS root_concept_name_1,
				concept_code_1 AS root_concept_code_1,
				vocabulary_id_1 AS root_vocabulary_id_1,
				ARRAY [ROW (concept_code_2, vocabulary_id_2)] AS nocycle,
				ARRAY [vocabulary_id_2||'-'||concept_code_2] AS path
			FROM r
			WHERE vocabulary_id_1 = 'CIEL' --start with the CIELs
			
			UNION ALL
			
			SELECT r.concept_name_1,
				r.concept_code_1,
				r.vocabulary_id_1,
				r.concept_name_2,
				r.concept_code_2,
				r.vocabulary_id_2,
				root_concept_name_1,
				root_concept_code_1,
				root_vocabulary_id_1,
				hc.nocycle || ROW(r.concept_code_2, r.vocabulary_id_2) AS nocycle,
				hc.path || (r.vocabulary_id_2 || '-' || r.concept_code_2) AS path
			FROM r
			JOIN hierarchy_concepts hc ON hc.concept_code_2 = r.concept_code_1
				AND devv5.instr(hc.vocabulary_id_2, r.vocabulary_id_1) > 0
			-- nocycle shouldn't be necessary, but for some reason it won't do it without, even though I can't find a loop
			-- The logic is to thread them up by matching the ending concept_code to the beginning of the next relationship, and to make sure the vocabulary of the next fits into the previous one
			WHERE ROW(r.concept_code_2, r.vocabulary_id_2) <> ALL (nocycle) --excluding loops
			),
		r AS (
			-- create connections between CIEL and RxNorm/SNOMED, and then from SNOMED to RxNorm Ingredient and from RxNorm MIN to RxNorm Ingredient
			SELECT DISTINCT FIRST_VALUE(cn."name") OVER (
					PARTITION BY c.concept_id ORDER BY CASE 
							WHEN LENGTH(cn."name") <= 255
								THEN LENGTH(cn."name")
							ELSE 0
							END DESC,
						LENGTH(cn."name") ROWS BETWEEN UNBOUNDED PRECEDING
							AND UNBOUNDED FOLLOWING
					) AS concept_name_1,
				CAST(c.concept_id AS VARCHAR(40)) AS concept_code_1,
				'CIEL' AS vocabulary_id_1,
				'' AS concept_name_2,
				crt."code" AS concept_code_2,
				CASE crs."name"
					-- The name of the vocabularies is composed of the OMOP vocabulary_id, and the suffix '-c' for "chained" and the number of precedence it should be used (ordered by in a partition statement)
					WHEN 'SNOMED CT'
						THEN 'SNOMED-c1'
					WHEN 'SNOMED NP'
						THEN 'SNOMED-c2'
					WHEN 'SNOMED US'
						THEN 'SNOMED-c3'
					WHEN 'RxNORM'
						THEN 'RxNorm-c'
					WHEN 'ICD-10-WHO'
						THEN 'XICD10-c1' -- X so it will be ordered by after SNOMED
					WHEN 'ICD-10-WHO 2nd'
						THEN 'XICD10-c2'
					WHEN 'ICD-10-WHO NP'
						THEN 'XICD10-c3'
					WHEN 'ICD-10-WHO NP2'
						THEN 'XICD10-c4'
					WHEN 'NDF-RT NUI'
						THEN 'NDFRT-c'
					ELSE NULL
					END AS vocabulary_id_2
			FROM sources.concept_ciel c
			JOIN sources.concept_class_ciel ccl ON c.class_id = ccl.concept_class_id
			JOIN sources.concept_name cn ON cn.concept_id = c.concept_id
				AND cn.locale = 'en'
			JOIN sources.concept_reference_map crm ON crm.concept_id = c.concept_id
			JOIN sources.concept_reference_term crt ON crt.concept_reference_term_id = crm.concept_reference_term_id
			JOIN sources.concept_reference_source crs ON crs.concept_source_id = crt.concept_source_id
			WHERE crt.retired = 0
				AND crs."name" IN (
					'RxNORM',
					'SNOMED CT',
					'SNOMED NP',
					'ICD-10-WHO',
					'ICD-10-WHO NP',
					'ICD-10-WHO 2nd',
					'ICD-10-WHO NP2',
					'SNOMED US',
					'NDF-RT NUI'
					)
			
			UNION
			
			-- resolve RxNorm MIN to RxNorm IN (not currently in Vocabularies)
			SELECT DISTINCT first_value(rx_min.str) OVER (
					PARTITION BY rx_min.rxcui ORDER BY CASE 
							WHEN LENGTH(rx_min.str) <= 255
								THEN LENGTH(rx_min.str)
							ELSE 0
							END DESC,
						LENGTH(rx_min.str) ROWS BETWEEN UNBOUNDED PRECEDING
							AND UNBOUNDED FOLLOWING
					) AS concept_name_1,
				rx_min.rxcui AS concept_code_1,
				'RxNorm-c' AS vocabulary_id_1,
				first_value(ing.str) OVER (
					PARTITION BY ing.rxcui ORDER BY CASE 
							WHEN LENGTH(ing.str) <= 255
								THEN LENGTH(ing.str)
							ELSE 0
							END DESC,
						LENGTH(ing.str) ROWS BETWEEN UNBOUNDED PRECEDING
							AND UNBOUNDED FOLLOWING
					) AS concept_name_2,
				ing.rxcui AS concept_code_2,
				'RxNorm-c' AS vocabulary_id_2
			FROM sources.rxnconso rx_min
			JOIN sources.rxnrel r ON r.rxcui1 = rx_min.rxcui
			JOIN sources.rxnconso ing ON ing.rxcui = r.rxcui2
				AND ing.sab = 'RXNORM'
				AND ing.tty = 'IN'
			WHERE rx_min.sab = 'RXNORM'
				AND rx_min.tty = 'MIN'
			
			UNION
			
			-- add concept_relationships between SNOMED and RxNorm
			SELECT c1.concept_name AS concept_name_1,
				c1.concept_code AS concept_code_1,
				c1.vocabulary_id || '-c' AS vocabulary_id_1,
				c2.concept_name AS concept_name_2,
				c2.concept_code AS concept_code_2,
				c2.vocabulary_id || '-c' AS vocabulary_id_2
			FROM concept c1
			JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
			JOIN concept c2 ON c2.concept_id = r.concept_id_2
			WHERE r.invalid_reason IS NULL
				AND c1.vocabulary_id = 'SNOMED'
				AND c2.vocabulary_id = 'RxNorm'
				AND r.relationship_id = 'Maps to'
				AND c1.concept_id != c2.concept_id
			
			UNION
			
			-- add concept_relationships between NDFRT and RxNorm
			SELECT c1.concept_name AS concept_name_1,
				c1.concept_code AS concept_code_1,
				c1.vocabulary_id || '-c' AS vocabulary_id_1,
				c2.concept_name AS concept_name_2,
				c2.concept_code AS concept_code_2,
				c2.vocabulary_id || '-c' AS vocabulary_id_2
			FROM concept c1
			JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
			JOIN concept c2 ON c2.concept_id = r.concept_id_2
			WHERE r.invalid_reason IS NULL
				AND c1.vocabulary_id = 'NDFRT'
				AND c2.vocabulary_id = 'RxNorm'
				AND r.relationship_id = 'NDFRT - RxNorm eq'
			
			UNION
			
			-- add concept_relationships within SNOMED to decomponse multiple ingredients and map from procedure to drug
			SELECT c1.concept_name AS concept_name_1,
				c1.concept_code AS concept_code_1,
				c1.vocabulary_id || '-c' AS vocabulary_id_1,
				c2.concept_name AS concept_name_2,
				c2.concept_code AS concept_code_2,
				c2.vocabulary_id || '-c' AS vocabulary_id_2
			FROM concept c1
			JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
			JOIN concept c2 ON c2.concept_id = r.concept_id_2
			WHERE r.invalid_reason IS NULL
				AND c1.vocabulary_id = 'SNOMED'
				AND c2.vocabulary_id = 'SNOMED'
				AND r.relationship_id IN (
					'Has active ing',
					'Has dir subst'
					)
			
			UNION
			
			-- add concept_relationships within RxNorm from Ingredient to Ingredient
			SELECT c1.concept_name AS concept_name_1,
				c1.concept_code AS concept_code_1,
				c1.vocabulary_id || '-c' AS vocabulary_id_1,
				c2.concept_name AS concept_name_2,
				c2.concept_code AS concept_code_2,
				c2.vocabulary_id || '-c' AS vocabulary_id_2
			FROM concept c1
			JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
			JOIN concept c2 ON c2.concept_id = r.concept_id_2
			WHERE r.invalid_reason IS NULL
				AND c1.vocabulary_id = 'RxNorm'
				AND c2.vocabulary_id = 'RxNorm'
				AND r.relationship_id IN ('Form of')
			
			UNION
			
			-- connect deprecated RxNorm ingredients to fresh ones by first word in concept_name
			SELECT dep.concept_name AS concept_name_1,
				dep.concept_code AS concept_code_1,
				'RxNorm-c' AS vocabulary_id_1,
				fre.concept_name AS concept_name_2,
				fre.concept_code AS concept_code_2,
				'RxNorm-c' AS vocabulary_id_2
			FROM concept dep
			JOIN concept fre ON SUBSTRING(lower(dep.concept_name), '\w+') = SUBSTRING(lower(fre.concept_name), '\w+')
				AND fre.vocabulary_id = 'RxNorm'
				AND fre.concept_class_id = 'Ingredient'
				AND fre.invalid_reason IS NULL
			JOIN (
				SELECT fir,
					count(8)
				FROM (
					SELECT concept_name,
						SUBSTRING(lower(dep.concept_name), '\w+') AS fir
					FROM concept dep
					WHERE vocabulary_id = 'RxNorm'
						AND concept_class_id = 'Ingredient'
					) AS s0
				GROUP BY fir
				HAVING count(8) < 4
				) ns ON fir = SUBSTRING(lower(dep.concept_name), '\w+')
			WHERE dep.vocabulary_id = 'RxNorm'
				AND dep.concept_class_id = 'Ingredient'
				AND dep.invalid_reason = 'D'
			
			UNION
			
			-- connect SNOMED ingredients to RxNorm by first word in concept_name
			SELECT dep.concept_name AS concept_name_1,
				dep.concept_code AS concept_code_1,
				'SNOMED-c' AS vocabulary_id_1,
				fre.concept_name AS concept_name_2,
				fre.concept_code AS concept_code_2,
				'RxNorm-c' AS vocabulary_id_2
			FROM concept dep
			JOIN concept fre ON SUBSTRING(lower(dep.concept_name), '\w+') = SUBSTRING(lower(fre.concept_name), '\w+')
				AND fre.vocabulary_id = 'RxNorm'
				AND fre.concept_class_id = 'Ingredient'
				AND fre.invalid_reason IS NULL
			JOIN (
				SELECT fir,
					count(8)
				FROM (
					SELECT concept_name,
						SUBSTRING(lower(dep.concept_name), '\w+') AS fir
					FROM concept dep
					WHERE vocabulary_id = 'RxNorm'
						AND concept_class_id = 'Ingredient'
					) AS s1
				GROUP BY fir
				HAVING count(8) < 4
				) ns ON fir = SUBSTRING(lower(dep.concept_name), '\w+')
			WHERE dep.vocabulary_id = 'SNOMED'
				AND dep.domain_id = 'Drug'
				AND lower(dep.concept_name) NOT LIKE '% with %'
				AND dep.concept_name NOT LIKE '% + %'
				AND lower(dep.concept_name) NOT LIKE '% and %'
			
			UNION
			
			-- add concept_relationships between ICD10 and SNOMED 
			SELECT c1.concept_name AS concept_name_1,
				c1.concept_code AS concept_code_1,
				c1.vocabulary_id || '-c' AS vocabulary_id_1,
				c2.concept_name AS concept_name_2,
				c2.concept_code AS concept_code_2,
				c2.vocabulary_id AS vocabulary_id_2 -- SNOMED mappings are final, so no suffix
			FROM concept c1
			JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
			JOIN concept c2 ON c2.concept_id = r.concept_id_2
			WHERE r.invalid_reason IS NULL
				AND c1.vocabulary_id = 'ICD10'
				AND c2.vocabulary_id = 'SNOMED'
				AND r.relationship_id = 'Maps to'
			
			UNION
			
			-- add concept_relationships between ICD10 and SNOMED 
			SELECT c1.concept_name AS concept_name_1,
				c1.concept_code AS concept_code_1,
				c1.vocabulary_id || '-c' AS vocabulary_id_1,
				c2.concept_name AS concept_name_2,
				c2.concept_code AS concept_code_2,
				c2.vocabulary_id AS vocabulary_id_2 -- Mappings are final, so no suffix
			FROM concept c1
			JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
			JOIN concept c2 ON c2.concept_id = r.concept_id_2
			WHERE r.invalid_reason IS NULL
				AND c1.vocabulary_id = 'SNOMED'
				AND c2.vocabulary_id IN (
					'Provider Specialty',
					'CMS Place of Service'
					)
				AND r.relationship_id = 'Maps to'
			
			UNION
			
			-- add concept_relationships between SNOMED Drug classes and NDFRT
			SELECT c1.concept_name AS concept_name_1,
				c1.concept_code AS concept_code_1,
				c1.vocabulary_id || '-c' AS vocabulary_id_1,
				c2.concept_name AS concept_name_2,
				c2.concept_code AS concept_code_2,
				c2.vocabulary_id || '-c' AS vocabulary_id_2
			FROM concept c1
			JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
			JOIN concept c2 ON c2.concept_id = r.concept_id_2
			WHERE r.invalid_reason IS NULL
				AND c1.vocabulary_id = 'SNOMED'
				AND c2.vocabulary_id = 'NDFRT'
				AND c1.domain_id = 'Drug'
			
			UNION
			
			-- Mapping from SNOMED to UCUM
			SELECT c1.concept_name AS concept_name_1,
				c1.concept_code AS concept_code_1,
				c1.vocabulary_id || '-c' AS vocabulary_id_1,
				c2.concept_name AS concept_name_2,
				c2.concept_code AS concept_code_2,
				c2.vocabulary_id AS vocabulary_id_2 -- UCUM mappings are final, so no suffix
			FROM concept c1
			JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
			JOIN concept c2 ON c2.concept_id = r.concept_id_2
			WHERE r.invalid_reason IS NULL
				AND c1.vocabulary_id = 'SNOMED'
				AND c2.vocabulary_id = 'UCUM'
			
			UNION
			
			-- Add replacement mappings
			SELECT c1.concept_name AS concept_name_1,
				c1.concept_code AS concept_code_1,
				c1.vocabulary_id || '-c' AS vocabulary_id_1,
				c2.concept_name AS concept_name_2,
				c2.concept_code AS concept_code_2,
				c2.vocabulary_id || '-c' AS vocabulary_id_2
			FROM concept c1
			JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
			JOIN concept c2 ON c2.concept_id = r.concept_id_2
			WHERE r.invalid_reason IS NULL
				-- and c1.vocabulary_id in ('SNOMED', 'RxNorm', 'ICD10', 'LOINC', 'NDFRT'
				AND c1.vocabulary_id IN (
					'SNOMED',
					'ICD10',
					'RxNorm',
					'LOINC'
					)
				AND c2.vocabulary_id IN (
					'SNOMED',
					'ICD10',
					'RxNorm',
					'LOINC'
					)
				AND relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept poss_eq to',
					'Concept was_a to',
					'LOINC replaced by',
					'RxNorm replaced by'
					)
			
			UNION
			
			-- Final terminators for RxNorm Ingredients
			SELECT concept_name AS concept_name_1,
				concept_code AS concept_code_1,
				'RxNorm-c' AS vocabulary_id_1,
				concept_name AS concept_name_2,
				concept_code AS concept_code_2,
				'RxNorm' AS vocabulary_id_2 -- RxNorm ingredient mappings are final
			FROM concept
			WHERE vocabulary_id = 'RxNorm'
				AND concept_class_id = 'Ingredient'
				AND invalid_reason IS NULL
			
			UNION
			
			-- Final terminators for standard_concept SNOMEDs 
			SELECT concept_name AS concept_name_1,
				concept_code AS concept_code_1,
				'SNOMED-c' AS vocabulary_id_1, -- map from interim with suffix "-c" to blessed concept
				concept_name AS concept_name_2,
				concept_code AS concept_code_2,
				'SNOMED' AS vocabulary_id_2 -- SNOMED mappings are final
			FROM concept
			WHERE vocabulary_id = 'SNOMED'
				AND standard_concept = 'S'
				AND invalid_reason IS NULL
			
			UNION
			
			-- Final terminators for LOINC
			SELECT concept_name AS concept_name_1,
				concept_code AS concept_code_1,
				'LOINC-c' AS vocabulary_id_1, -- map from interim with suffix "-c" to blessed concept
				concept_name AS concept_name_2,
				concept_code AS concept_code_2,
				'LOINC' AS vocabulary_id_2 -- SNOMED mappings are final
			FROM concept
			WHERE vocabulary_id = 'LOINC'
				AND invalid_reason IS NULL
			)
-- Finally let the connect by find a path between the CIEL concept and an OMOP stnadard_concept='S'
SELECT CASE 
		WHEN vocabulary_id_2 LIKE '%-c%'
			THEN 0
		ELSE 1
		END AS found,
	root_concept_name_1 AS concept_name_1,
	root_concept_code_1 AS concept_code_1,
	root_vocabulary_id_1 AS vocabulary_id_1,
	':' || array_to_string(path, ':') AS path,
	concept_name_2,
	concept_code_2,
	vocabulary_id_2
FROM hierarchy_concepts
-- The latter is necessary because we use suffixes in the definition of the vocabulary_id for the first relationship from the CIEL concept for the purpose of distinguishing 
-- intermediate steps from the final and then pick the best path from a possible list
WHERE vocabulary_id_2 NOT LIKE '%-c%';-- the terminating relationshp should have no suffix, indicating it is a proper standard concept.

--5. Create temporary table of CIEL concepts that have mapping to some useful vocabulary, even though if it doesn't work. This is for debugging, in the final release we won't need that
DROP TABLE IF EXISTS ciel_concept_with_map;
CREATE unlogged TABLE ciel_concept_with_map AS
SELECT DISTINCT
	--   cdt."name" as datatype_nm, 
	--   cn.concept_name_id as cnid,
	FIRST_VALUE(cn."name") OVER (
		PARTITION BY c.concept_id ORDER BY CASE 
				WHEN LENGTH(cn."name") <= 255
					THEN LENGTH(cn."name")
				ELSE 0
				END DESC,
			LENGTH(cn."name") ROWS BETWEEN UNBOUNDED PRECEDING
				AND UNBOUNDED FOLLOWING
		) AS concept_name,
	ccl."name" AS domain_id,
	CAST(c.concept_id AS VARCHAR(40)) AS concept_code,
	CASE c.retired
		WHEN 0
			THEN NULL
		ELSE 'D'
		END AS invalid_reason
FROM sources.concept_ciel c
LEFT JOIN sources.concept_class_ciel ccl ON c.class_id = ccl.concept_class_id
LEFT JOIN sources.concept_name cn ON cn.concept_id = c.concept_id
	AND cn.locale = 'en'
LEFT JOIN sources.concept_reference_map crm ON crm.concept_id = c.concept_id
LEFT JOIN sources.concept_reference_term crt ON crt.concept_reference_term_id = crm.concept_reference_term_id
LEFT JOIN sources.concept_reference_source crs ON crs.concept_source_id = crt.concept_source_id
WHERE crs."name" IN (
		'SNOMED CT',
		'SNOMED NP',
		'ICD-10-WHO',
		'RxNORM',
		'ICD-10-WHO NP',
		'ICD-10-WHO 2nd',
		'ICD-10-WHO NP2',
		'SNOMED US',
		'NDF-RT NUI'
		);

--6. Create concept_relationship_stage records
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
SELECT DISTINCT cm.concept_code_1 AS concept_code_1,
	CASE c.domain_id
		WHEN 'Drug'
			THEN cm.concept_code_2
		ELSE first_value(cm.concept_code_2) OVER (PARTITION BY c.concept_code ORDER BY cm.path ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
		END AS concept_code_2,
	'CIEL' AS vocabulary_id_1,
	CASE c.domain_id
		WHEN 'Drug'
			THEN cm.vocabulary_id_2
		ELSE first_value(cm.vocabulary_id_2) OVER (
				PARTITION BY c.concept_code ORDER BY cm.path ROWS BETWEEN UNBOUNDED PRECEDING
						AND UNBOUNDED FOLLOWING
				)
		END AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM ciel_concept_with_map c
JOIN ciel_to_concept_map cm ON c.concept_code = cm.concept_code_1;

--7. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--8. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--9. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--10. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--11. Clean up
DROP TABLE ciel_concept_with_map;
DROP TABLE ciel_to_concept_map;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script