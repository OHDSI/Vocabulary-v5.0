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
* Authors: Christian Reich, Timur Vakhitov, Michael Kallfelz
* Date: 2020, 2021, 2023
**************************************************************************/

--1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CIEL',
	pVocabularyDate			=> (SELECT MAX(date_created) FROM sources.ciel_concept_name),
	pVocabularyVersion		=> (SELECT 'CIEL '||TO_CHAR(MAX(date_created),'yyyymmdd') FROM sources.ciel_concept_name),
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
SELECT DISTINCT ON (c.concept_id)
	vocabulary_pack.CutConceptName(COALESCE(cn.ciel_name, 'Concept ' || c.concept_id /*for strange reason we have 4 concepts without concept_name*/)) AS concept_name,
	CASE ccl.ciel_name
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
				-- begin change M. Kallfelz 2021-05-06 
		WHEN 'InteractSet' -- Set of drugs that interact with parent drug.
			THEN 'Drug'
				-- end change M. Kallfelz 2021-05-06
		END AS domain_id,
	'CIEL' AS vocabulary_id,
	CASE ccl.ciel_name -- shorten the ones that won't fit the 20 char limit
		WHEN 'Aggregate Measurement'
			THEN 'Aggregate Meas'
		WHEN 'Health Care Monitoring Topics'
			THEN 'Monitoring' -- no concepts of this class in table
		WHEN 'Radiology/Imaging Procedure'
			THEN 'Radiology' -- there are LOINC codes which are Measurement, but results are not connected
		WHEN 'Pharmacologic Drug Class'
			THEN 'Drug Class'
				-- begin change M. Kallfelz 2021-05-06 
		WHEN 'InteractSet' -- Set of drugs that interact with parent drug.
			THEN 'Drug Class' -- Class 'Drug Interaction' is not suitable and not in use
				-- end change M. Kallfelz 2021-05-06
		ELSE ccl.ciel_name
		END AS concept_class_id,
	NULL AS standard_concept,
	c.concept_id AS concept_code,
	COALESCE(c.date_created, TO_DATE('19700101', 'yyyymmdd')) AS valid_start_date,
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
FROM sources.ciel_concept c
LEFT JOIN sources.ciel_concept_class ccl ON ccl.concept_class_id = c.class_id
LEFT JOIN sources.ciel_concept_name cn ON cn.concept_id = c.concept_id
	AND cn.locale = 'en'
ORDER BY c.concept_id,
	cn.locale_preferred DESC,
	LENGTH(cn.ciel_name) DESC /*some concepts don't have locale_preferred*/;

--begin addition M. Kallfelz 2021-05-06

--4. Add synonyms to concept_synonym_stage by language

--SELECT DISTINCT ON (locale) * FROM ciel_concept_name
-- WHERE voided = 0;
-- am = Amharic => no OMOP language
-- bn = Bengali, Bangla => no OMOP language
-- en
-- es = Spanish, Castilian => 4182511
-- fr = French => 4180190
-- ht = Haitian => no OMOP language
-- in = Indonesian (ISO code is id!) => no OMOP language
-- it = Italian => 4182507
-- nl = Dutch => 4182503
-- om = Oromo => no OMOP language
-- pt = Portuguese => 4181536
-- ru = Russian => no OMOP language
-- rw = Kinyarwanda => no OMOP language
-- sw = Swahili => no OMOP language
-- ti = Tigrinya => no OMOP language
-- ur = Urdu => no OMOP language
-- vi = Vietnamese => no OMOP language
INSERT INTO concept_synonym_stage (
	synonym_name,
	synonym_concept_code,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT cn.ciel_name AS synonym_name,
	cn.concept_id AS synonym_concept_code,
	'CIEL' AS synonym_vocabulary_id,
	CASE cn.locale
		WHEN 'es'
			THEN 4182511
		WHEN 'fr'
			THEN 4180190
		WHEN 'it'
			THEN 4182507
		WHEN 'nl'
			THEN 4182503
		WHEN 'pt'
			THEN 4181536
		END AS language_concept_id
FROM sources.ciel_concept_name AS cn
WHERE cn.locale IN (
		'es',
		'fr',
		'it',
		'nl',
		'pt'
		) -- no other OMOP languages match the locale
	-- end addition M. Kallfelz 2021-05-06
	AND  cn.ciel_name IS NOT NULL
	 AND cn.voided = '0' 
	 AND cn.concept_name_type = 'FULLY_SPECIFIED'
  ;

--5. Create chain between CIEL and the best OMOP concept and create map
DROP TABLE IF EXISTS ciel_to_concept_map;
CREATE UNLOGGED TABLE ciel_to_concept_map AS
	WITH RECURSIVE hierarchy_concepts AS (
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
				AND devv5.INSTR(hc.vocabulary_id_2, r.vocabulary_id_1) > 0
			-- nocycle shouldn't be necessary, but for some reason it won't do it without, even though I can't find a loop
			-- The logic is to thread them up by matching the ending concept_code to the beginning of the next relationship, and to make sure the vocabulary of the next fits into the previous one
			WHERE ROW(r.concept_code_2, r.vocabulary_id_2) <> ALL (nocycle) --excluding loops
			),
		r AS (
			-- create connections between CIEL and RxNorm/SNOMED, and then from SNOMED to RxNorm Ingredient and from RxNorm MIN to RxNorm Ingredient
			SELECT COALESCE(FIRST_VALUE(cn.ciel_name) OVER (
						PARTITION BY c.concept_id ORDER BY CASE 
								WHEN LENGTH(cn.ciel_name) <= 255
									THEN LENGTH(cn.ciel_name)
								ELSE 0
								END DESC,
							LENGTH(cn.ciel_name)
						), 'Concept ' || c.concept_id /*for strange reason we have 4 concepts without concept_name*/) AS concept_name_1,
				c.concept_id::TEXT AS concept_code_1,
				'CIEL' AS vocabulary_id_1,
				'' AS concept_name_2,
				crt.ciel_code AS concept_code_2,
				CASE crs.ciel_name
					-- The name of the vocabularies is composed of the OMOP vocabulary_id, and the suffix '-c' for "chained" and the number of precedence it should be used (ordered by in a partition statement)
					WHEN 'SNOMED CT'
						THEN 'SNOMED-c1'
					WHEN 'SNOMED NP'
						THEN 'SNOMED-c2'
					WHEN 'SNOMED US'
						THEN 'SNOMED-c3'
					WHEN 'SNOMED UK'
						THEN 'SNOMED-c4'
          WHEN 'RxNORM'
						THEN 'RxNorm-c'
					WHEN 'OMOP RxNorm Extension'
						THEN 'RxNorm Extension-c'
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
-- can we add more? CPT - SNOMED UK - WHOATC - UCUM - OMOP RxNorm Extension
					ELSE NULL
					END AS vocabulary_id_2
			FROM sources.ciel_concept c
			JOIN sources.ciel_concept_name cn ON cn.concept_id = c.concept_id
				AND cn.locale = 'en'
			JOIN sources.ciel_concept_reference_map crm ON crm.concept_id = c.concept_id
			JOIN sources.ciel_concept_reference_term crt ON crt.concept_reference_term_id = crm.concept_reference_term_id
			JOIN sources.ciel_concept_reference_source crs ON crs.concept_source_id = crt.concept_source_id
			WHERE crt.retired = 0
				AND c.class_id <> 3 --exclude drugs [AVOF-3147]
				AND crs.ciel_name IN (
					'RxNORM',
					'OMOP RxNorm Extension',
					'SNOMED CT',
					'SNOMED NP',
					'SNOMED UK',
					'ICD-10-WHO',
					'ICD-10-WHO NP',
					'ICD-10-WHO 2nd',
					'ICD-10-WHO NP2',
					'SNOMED US',
					'NDF-RT NUI'
-- can we add more? CPT - SNOMED UK - WHOATC - UCUM - OMOP RxNorm Extension
					)
			
			UNION
			
			-- new logic for drugs [AVOF-3147]
			SELECT s1.ciel_name AS concept_name_1,
				s1.ciel_code AS concept_code_1,
				'CIEL' AS vocabulary_id_1,
				s1.target_name AS concept_name_2,
				s1.code AS concept_code_2,
				c.vocabulary_id || '-c' AS vocabulary_id_2
			FROM (
				SELECT s0.ciel_code,
					s0.ciel_name,
					s0.concept_map_id,
					s0.target_pr_rxcui,
					CASE 
						WHEN s0.target_pr_sab = 'SNOMEDCT_US'
							AND s0.target_sec_code IS NOT NULL
							THEN s0.target_sec_sab
						ELSE s0.target_pr_sab
						END sab,
					CASE 
						WHEN s0.target_pr_sab = 'SNOMEDCT_US'
							AND s0.target_sec_code IS NOT NULL
							THEN s0.target_sec_code
						ELSE s0.target_pr_code
						END code,
					CASE 
						WHEN s0.target_pr_sab = 'SNOMEDCT_US'
							AND s0.target_sec_code IS NOT NULL
							THEN s0.target_sec_str
						ELSE s0.target_pr_str
						END target_name
				FROM (
					SELECT c.concept_id::TEXT ciel_code,
						cn.ciel_name,
						cm.concept_map_id,
						target_primary.rxcui target_pr_rxcui,
						target_primary.code target_pr_code,
						target_primary.sab target_pr_sab,
						target_secondary.rxcui target_sec_code,
						'RXNORM' target_sec_sab,
						target_primary.str target_pr_str,
						target_secondary.str target_sec_str,
						RANK() OVER (
							PARTITION BY c.concept_id ORDER BY CASE 
									WHEN target_primary.sab = 'RXNORM'
										THEN 1
									WHEN target_secondary.rxcui IS NOT NULL
										THEN 2
									END /*priority: RXNORM (primary target), RXNORM (secondary target via SNOMED), SNOMED*/,
								TRANSLATE(LEFT(target_primary.tty, 1), 'SMIP', '1234') /*priority for primary: SCD, MIN, IN, PIN*/,
								TRANSLATE(LEFT(target_secondary.tty, 1), 'SMIP', '1234') /*priority for secondary: SCD, MIN, IN, PIN*/
							) target_rnk
					FROM sources.ciel_concept c
					JOIN sources.ciel_concept_reference_map cm ON cm.concept_id = c.concept_id
					JOIN sources.ciel_concept_reference_term ct ON ct.concept_reference_term_id = cm.concept_reference_term_id
					JOIN sources.ciel_concept_name cn ON c.concept_id = cn.concept_id
					JOIN sources.rxnconso target_primary ON target_primary.rxcui = ct.ciel_code
						AND target_primary.sab IN (
							'RXNORM',
							'SNOMEDCT_US'
							)
					/*trying to find secondary mapping via SNOMED*/
					LEFT JOIN (
						SELECT sn_to_rxcui.code snomed_code,
							rxn.rxcui,
							rxn.tty,
							rxn.str,
							rxn.suppress
						FROM sources.rxnconso sn_to_rxcui
						JOIN sources.rxnconso rxn USING (rxcui)
						WHERE sn_to_rxcui.sab = 'SNOMEDCT_US'
							AND rxn.sab = 'RXNORM'
							AND rxn.tty IN (
								'SCD',
								'IN',
								'MIN',
								'PIN'
								)
						) target_secondary ON target_secondary.snomed_code = target_primary.code
					WHERE c.class_id = 3 --only drugs
						AND target_primary.tty IN (
							'SCD',
							'IN',
							'MIN',
							'PIN',
							'PT'
							)
						AND cn.locale = 'en'
						AND cn.locale_preferred = 1
						AND ct.concept_source_id IN (
							1,
							2,
							4,
							5
							) --RxNorm+SCT
					) s0
				WHERE s0.target_rnk = 1
				) s1
			JOIN concept c ON c.concept_code = s1.code
				AND c.vocabulary_id = CASE 
					WHEN s1.sab = 'RXNORM'
						THEN 'RxNorm'
					ELSE 'SNOMED'
					END
			WHERE c.concept_id <> 4269754 --concept_id=4269754 (Immunoglobulin structure) is a child of concept 4008249 (Immunoglobulin) and is therefore ignored

			UNION

			-- resolve RxNorm MIN to RxNorm IN (not currently in Vocabularies)
			SELECT DISTINCT FIRST_VALUE(rx_min.str) OVER (
					PARTITION BY rx_min.rxcui ORDER BY CASE
							WHEN LENGTH(rx_min.str) <= 255
								THEN LENGTH(rx_min.str)
							ELSE 0
							END DESC,
						LENGTH(rx_min.str)
					) AS concept_name_1,
				rx_min.rxcui AS concept_code_1,
				'RxNorm-c' AS vocabulary_id_1,
				FIRST_VALUE(ing.str) OVER (
					PARTITION BY ing.rxcui ORDER BY CASE
							WHEN LENGTH(ing.str) <= 255
								THEN LENGTH(ing.str)
							ELSE 0
							END DESC,
						LENGTH(ing.str)
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
				AND r.relationship_id = 'Form of'
			
			UNION
			
			-- connect deprecated RxNorm ingredients to fresh ones by first word in concept_name
			SELECT dep.concept_name AS concept_name_1,
				dep.concept_code AS concept_code_1,
				'RxNorm-c' AS vocabulary_id_1,
				fre.concept_name AS concept_name_2,
				fre.concept_code AS concept_code_2,
				'RxNorm-c' AS vocabulary_id_2
			FROM concept dep
			JOIN concept fre ON SUBSTRING(LOWER(dep.concept_name), '\w+') = SUBSTRING(LOWER(fre.concept_name), '\w+')
				AND fre.vocabulary_id = 'RxNorm'
				AND fre.concept_class_id = 'Ingredient'
				AND fre.invalid_reason IS NULL
			JOIN (
				SELECT fir,
					COUNT(*)
				FROM (
					SELECT concept_name,
						SUBSTRING(LOWER(dep.concept_name), '\w+') AS fir
					FROM concept dep
					WHERE vocabulary_id = 'RxNorm'
						AND concept_class_id = 'Ingredient'
					) AS s0
				GROUP BY fir
				HAVING COUNT(*) < 4
				) ns ON fir = SUBSTRING(LOWER(dep.concept_name), '\w+')
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
			JOIN concept fre ON SUBSTRING(LOWER(dep.concept_name), '\w+') = SUBSTRING(LOWER(fre.concept_name), '\w+')
				AND fre.vocabulary_id = 'RxNorm'
				AND fre.concept_class_id = 'Ingredient'
				AND fre.invalid_reason IS NULL
			JOIN (
				SELECT fir,
					COUNT(*)
				FROM (
					SELECT concept_name,
						SUBSTRING(LOWER(dep.concept_name), '\w+') AS fir
					FROM concept dep
					WHERE vocabulary_id = 'RxNorm'
						AND concept_class_id = 'Ingredient'
					) AS s1
				GROUP BY fir
				HAVING COUNT(*) < 4
				) ns ON fir = SUBSTRING(LOWER(dep.concept_name), '\w+')
			WHERE dep.vocabulary_id = 'SNOMED'
				AND dep.domain_id = 'Drug'
				AND LOWER(dep.concept_name) NOT LIKE '% with %'
				AND dep.concept_name NOT LIKE '% + %'
				AND LOWER(dep.concept_name) NOT LIKE '% and %'
			
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
					'Concept was_a to'
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
	':' || ARRAY_TO_STRING(path, ':') AS path,
	concept_name_2,
	concept_code_2,
	vocabulary_id_2
FROM hierarchy_concepts
-- The latter is necessary because we use suffixes in the definition of the vocabulary_id for the first relationship from the CIEL concept for the purpose of distinguishing 
-- intermediate steps from the final and then pick the best path from a possible list
WHERE vocabulary_id_2 NOT LIKE '%-c%';-- the terminating relationshp should have no suffix, indicating it is a proper standard concept.

--6. Create temporary table of CIEL concepts that have mapping to some useful vocabulary, even though if it doesn't work. This is for debugging, in the final release we won't need that
DROP TABLE IF EXISTS ciel_concept_with_map;
CREATE UNLOGGED TABLE ciel_concept_with_map AS
SELECT DISTINCT COALESCE(FIRST_VALUE(cn.ciel_name) OVER (
			PARTITION BY c.concept_id ORDER BY CASE 
					WHEN LENGTH(cn.ciel_name) <= 255
						THEN LENGTH(cn.ciel_name)
					ELSE 0
					END DESC,
				LENGTH(cn.ciel_name)
			), 'Concept ' || c.concept_id /*for strange reason we have 4 concepts without concept_name*/) AS concept_name,
	ccl.ciel_name AS domain_id,
	c.concept_id::TEXT AS concept_code,
	CASE c.retired
		WHEN 0
			THEN NULL
		ELSE 'D'
		END AS invalid_reason
FROM sources.ciel_concept c
LEFT JOIN sources.ciel_concept_class ccl ON ccl.concept_class_id = c.class_id
LEFT JOIN sources.ciel_concept_name cn ON cn.concept_id = c.concept_id
	AND cn.locale = 'en'
LEFT JOIN sources.ciel_concept_reference_map crm ON crm.concept_id = c.concept_id
LEFT JOIN sources.ciel_concept_reference_term crt ON crt.concept_reference_term_id = crm.concept_reference_term_id
LEFT JOIN sources.ciel_concept_reference_source crs ON crs.concept_source_id = crt.concept_source_id
WHERE crs.ciel_name IN (
		'SNOMED CT',
		'SNOMED NP',
		'ICD-10-WHO',
		'RxNORM',
		'OMOP RxNorm Extension',
		'ICD-10-WHO NP',
		'ICD-10-WHO 2nd',
		'ICD-10-WHO NP2',
		'SNOMED US',
		'SNOMED UK',
		'NDF-RT NUI'
		);

--7. Create concept_relationship_stage records
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
		ELSE FIRST_VALUE(cm.concept_code_2) OVER (
				PARTITION BY c.concept_code ORDER BY cm.path
				)
		END AS concept_code_2,
	'CIEL' AS vocabulary_id_1,
	CASE c.domain_id
		WHEN 'Drug'
			THEN cm.vocabulary_id_2
		ELSE FIRST_VALUE(cm.vocabulary_id_2) OVER (
				PARTITION BY c.concept_code ORDER BY cm.path
				)
		END AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM ciel_concept_with_map c
JOIN ciel_to_concept_map cm ON c.concept_code = cm.concept_code_1;

--8. Add manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--9. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--10. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--11. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--12. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--13. Clean up
DROP TABLE ciel_concept_with_map;
DROP TABLE ciel_to_concept_map;

--14. Deprecate all relationships in concept_relationship that aren't exist in concept_relationship_stage
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
	( CASE
		WHEN (
     SELECT latest_update
	 	FROM vocabulary
	 	WHERE  vocabulary_id = 'CIEL' )
 	   - 1  < r.valid_start_date 
 	  THEN r.valid_start_date + 1
 	 ELSE (
     SELECT latest_update
	 	FROM vocabulary
	 	WHERE vocabulary_id = 'CIEL' )
 	   - 1  
    END
    ),
   'D'
FROM concept a
JOIN concept_relationship r ON a.concept_id = concept_id_1
	AND r.invalid_reason IS NULL
	AND r.relationship_id NOT IN (
		'Concept replaced by',
		'Concept replaces'
		)
JOIN concept b ON b.concept_id = concept_id_2
WHERE 'CIEL' IN (
		a.vocabulary_id,
		b.vocabulary_id
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = a.concept_code
			AND crs_int.concept_code_2 = b.concept_code
			AND crs_int.vocabulary_id_1 = a.vocabulary_id
			AND crs_int.vocabulary_id_2 = b.vocabulary_id
			AND crs_int.relationship_id = r.relationship_id
		);

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
-- Before generic update, go through stage table QA checks with functions qa_ddl and check_stage_tables
