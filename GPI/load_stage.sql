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
	pVocabularyName			=> 'GPI',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.gpi_name LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.gpi_name LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_GPI'
);
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Load into concept_stage from ndw_v_product
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
SELECT MAX(gpi_desc) AS concept_name,
	'Drug' AS domain_id,
	'GPI' AS vocabulary_id,
	'GPI' AS concept_class_id,
	NULL AS standard_concept,
	gpi AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'GPI'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.ndw_v_product
WHERE gpi IS NOT NULL
GROUP BY gpi;

--4. Load into concept_relationship_stage name from ndw_v_product
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
WITH map AS (
		-- Get all possible chains through NDC and "Maps to" to RxNorm
		SELECT n.gpi,
			rx.concept_id AS rx_id,
			rx.concept_class_id AS rx_class
		FROM SOURCES.ndw_v_product n
		JOIN concept ndc ON ndc.concept_code = n.ndc
			AND ndc.vocabulary_id = 'NDC' -- and nvl(n.obsolete_dt, '31-Dec-2099')>ndc.valid_start_date
		JOIN concept_relationship r ON r.invalid_reason IS NULL
			AND r.concept_id_1 = ndc.concept_id
			AND r.relationship_id = 'Maps to'
		JOIN concept rx ON rx.concept_id = r.concept_id_2
			AND rx.concept_class_id IN (
				'Branded Pack',
				'Clinical Pack',
				'Branded Drug',
				'Clinical Drug',
				'Quant Branded Drug',
				'Quant Clinical Drug'
				)
			AND rx.vocabulary_id = 'RxNorm'
		WHERE n.gpi IS NOT NULL
		GROUP BY n.gpi,
			rx.concept_id,
			rx.concept_class_id
		),
	all_class AS (
		-- Count the various concept_classes of the resulting concepts, and every ancestor, to find out if it is the same thing with different level of granularity
		SELECT map.gpi,
			c.concept_id,
			c.concept_class_id
		FROM map
		JOIN concept_ancestor a ON a.descendant_concept_id = map.rx_id
		JOIN concept c ON c.concept_id = a.ancestor_concept_id
			AND c.vocabulary_id = 'RxNorm'
			AND c.concept_class_id IN (
				'Branded Pack',
				'Clinical Pack',
				'Branded Drug',
				'Clinical Drug',
				'Quant Branded Drug',
				'Quant Clinical Drug'
				)
		
		UNION
		
		SELECT gpi,
			rx_id,
			rx_class
		FROM map
		),
	clean_class AS (
		-- Pick only those where the concept_class_id count is 1 (which means unique target concept)
		SELECT gpi,
			concept_class_id,
			count(*) AS cnt
		FROM all_class
		GROUP BY gpi,
			concept_class_id
		HAVING count(*) = 1
		)
SELECT DISTINCT ac.gpi AS concept_code_1,
	-- Pick the one which is the lowest but still unique
	first_value(c.concept_code) OVER (
		PARTITION BY ac.gpi ORDER BY CASE ac.concept_class_id
				WHEN 'Branded Pack'
					THEN 1
				WHEN 'Clinical Pack'
					THEN 2
				WHEN 'Quant Branded Drug'
					THEN 3
				WHEN 'Quant Clinical Drug'
					THEN 4
				WHEN 'Branded Drug'
					THEN 5
				ELSE 6
				END
		) AS concept_code_2,
	'Maps to' AS relationship_id,
	'GPI' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'GPI'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM clean_class cc
JOIN all_class ac ON cc.gpi = ac.gpi
	AND cc.concept_class_id = ac.concept_class_id
JOIN concept c ON c.concept_id = ac.concept_id
-- exclude all those that don't merge at a single Clinical Drug, i.e. coding for different target concepts
WHERE EXISTS (
		SELECT 1
		FROM clean_class
		WHERE gpi = cc.gpi
			AND concept_class_id = 'Clinical Drug'
		);

--5. Add synonyms
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT concept_code,
	concept_name,
	'GPI',
	4180186 -- English
FROM (
	SELECT cs.concept_code,
		cs.concept_name
	FROM concept_stage cs
	
	UNION ALL
	
	SELECT cs.concept_code,
		gn.drug_string
	FROM SOURCES.gpi_name gn,
		concept_stage cs
	WHERE gn.gpi_code = cs.concept_code
	) AS s0
WHERE TRIM(concept_name) IS NOT NULL;

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