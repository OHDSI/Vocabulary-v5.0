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
	pVocabularyName			=> 'RxNorm',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_RXNORM'
);
END $_$;

-- 2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Insert into concept_stage
-- Get drugs, components, forms and ingredients
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
SELECT SUBSTR(str, 1, 255),
	'RxNorm',
	'Drug',
	-- use RxNorm tty as for Concept Classes
	CASE tty
		WHEN 'IN'
			THEN 'Ingredient'
		WHEN 'DF'
			THEN 'Dose Form'
		WHEN 'SCDC'
			THEN 'Clinical Drug Comp'
		WHEN 'SCDF'
			THEN 'Clinical Drug Form'
		WHEN 'SCD'
			THEN 'Clinical Drug'
		WHEN 'BN'
			THEN 'Brand Name'
		WHEN 'SBDC'
			THEN 'Branded Drug Comp'
		WHEN 'SBDF'
			THEN 'Branded Drug Form'
		WHEN 'SBD'
			THEN 'Branded Drug'
		WHEN 'PIN'
			THEN 'Precise Ingredient'
		WHEN 'DFG'
			THEN 'Dose Form Group'
		WHEN 'SCDG'
			THEN 'Clinical Dose Group'
		WHEN 'SBDG'
			THEN 'Branded Dose Group'
		END,
	-- only Ingredients, drug components, drug forms, drugs and packs are standard concepts
	CASE tty
		WHEN 'PIN'
			THEN NULL
		WHEN 'DFG'
			THEN 'C'
		WHEN 'SCDG'
			THEN 'C'
		WHEN 'SBDG'
			THEN 'C'
		WHEN 'DF'
			THEN NULL
		WHEN 'BN'
			THEN NULL
		ELSE 'S'
		END,
	-- the code used in RxNorm
	rxcui,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm'
		),
	CASE 
		WHEN EXISTS (
				SELECT 1
				FROM sources.rxnatomarchive arch
				WHERE arch.rxcui = rx.rxcui
					AND sab = 'RXNORM'
					AND tty IN (
						'IN',
						'DF',
						'SCDC',
						'SCDF',
						'SCD',
						'BN',
						'SBDC',
						'SBDF',
						'SBD',
						'PIN',
						'DFG',
						'SCDG',
						'SBDG'
						)
					AND rxcui <> merged_to_rxcui
				)
			THEN (
					SELECT latest_update - 1
					FROM vocabulary
					WHERE vocabulary_id = 'RxNorm'
					)
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date,
	CASE 
		WHEN EXISTS (
				SELECT 1
				FROM sources.rxnatomarchive arch
				WHERE arch.rxcui = rx.rxcui
					AND sab = 'RXNORM'
					AND tty IN (
						'IN',
						'DF',
						'SCDC',
						'SCDF',
						'SCD',
						'BN',
						'SBDC',
						'SBDF',
						'SBD',
						'PIN',
						'DFG',
						'SCDG',
						'SBDG'
						)
					AND rxcui <> merged_to_rxcui
				)
			THEN 'U'
		ELSE NULL
		END
FROM sources.rxnconso rx
WHERE sab = 'RXNORM'
	AND tty IN (
		'IN',
		'DF',
		'SCDC',
		'SCDF',
		'SCD',
		'BN',
		'SBDC',
		'SBDF',
		'SBD',
		'PIN',
		'DFG',
		'SCDG',
		'SBDG'
		);

-- Packs share rxcuis with Clinical Drugs and Branded Drugs, therefore use code as concept_code
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
SELECT SUBSTR(str, 1, 255),
	'RxNorm',
	'Drug',
	-- use RxNorm tty as for Concept Classes
	CASE tty
		WHEN 'BPCK'
			THEN 'Branded Pack'
		WHEN 'GPCK'
			THEN 'Clinical Pack'
		END,
	'S',
	-- Cannot use rxcui here
	code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm'
		),
	CASE 
		WHEN EXISTS (
				SELECT 1
				FROM sources.rxnatomarchive arch
				WHERE arch.rxcui = rx.rxcui
					AND sab = 'RXNORM'
					AND tty IN (
						'IN',
						'DF',
						'SCDC',
						'SCDF',
						'SCD',
						'BN',
						'SBDC',
						'SBDF',
						'SBD',
						'PIN',
						'DFG',
						'SCDG',
						'SBDG'
						)
					AND rxcui <> merged_to_rxcui
				)
			THEN (
					SELECT latest_update - 1
					FROM vocabulary
					WHERE vocabulary_id = 'RxNorm'
					)
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date,
	CASE 
		WHEN EXISTS (
				SELECT 1
				FROM sources.rxnatomarchive arch
				WHERE arch.rxcui = rx.code
					AND sab = 'RXNORM'
					AND tty IN (
						'IN',
						'DF',
						'SCDC',
						'SCDF',
						'SCD',
						'BN',
						'SBDC',
						'SBDF',
						'SBD',
						'PIN',
						'DFG',
						'SCDG',
						'SBDG'
						)
					AND rxcui <> merged_to_rxcui
				)
			THEN 'U'
		ELSE NULL
		END
FROM sources.rxnconso rx
WHERE rx.sab = 'RXNORM'
	AND rx.tty IN (
		'BPCK',
		'GPCK'
		);

--4. Add synonyms - for all classes except the packs (they use code as concept_code)
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT rxcui,
	SUBSTR(rx.str, 1, 1000),
	'RxNorm',
	4180186 -- English
FROM sources.rxnconso rx
JOIN concept_stage c ON c.concept_code = rx.rxcui
	AND c.concept_class_id NOT IN (
		'Clinical Pack',
		'Branded Pack'
		)
	AND c.vocabulary_id = 'RxNorm'
WHERE rx.sab = 'RXNORM'
	AND rx.tty IN (
		'IN',
		'DF',
		'SCDC',
		'SCDF',
		'SCD',
		'BN',
		'SBDC',
		'SBDF',
		'SBD',
		'PIN',
		'DFG',
		'SCDG',
		'SBDG',
		'SY'
		)
	AND c.vocabulary_id = 'RxNorm';

-- Add synonyms for packs
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT code,
	SUBSTR(rx.str, 1, 1000),
	'RxNorm',
	4180186 -- English
FROM sources.rxnconso rx
JOIN concept_stage c ON c.concept_code = rx.code
	AND c.concept_class_id IN (
		'Clinical Pack',
		'Branded Pack'
		)
	AND c.vocabulary_id = 'RxNorm'
WHERE rx.sab = 'RXNORM'
	AND rx.tty IN (
		'BPCK',
		'GPCK',
		'SY'
		);

--5. Add inner-RxNorm relationships
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
SELECT rxcui2 AS concept_code_1, -- !! The RxNorm source files have the direction the opposite than OMOP
	rxcui1 AS concept_code_2,
	'RxNorm' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	CASE -- 
		WHEN rela = 'has_precise_ingredient'
			THEN 'Has precise ing'
		WHEN rela = 'has_tradename'
			THEN 'Has tradename'
		WHEN rela = 'has_dose_form'
			THEN 'RxNorm has dose form'
		WHEN rela = 'has_form'
			THEN 'Has form' -- links Ingredients to Precise Ingredients
		WHEN rela = 'has_ingredient'
			THEN 'RxNorm has ing'
		WHEN rela = 'constitutes'
			THEN 'Constitutes'
		WHEN rela = 'contains'
			THEN 'Contains'
		WHEN rela = 'reformulated_to'
			THEN 'Reformulated in'
		WHEN rela = 'inverse_isa'
			THEN 'RxNorm inverse is a'
		WHEN rela = 'has_quantified_form'
			THEN 'Has quantified form' -- links extended release tablets to 12 HR extended release tablets
		WHEN rela = 'quantified_form_of'
			THEN 'Quantified form of'
		WHEN rela = 'consists_of'
			THEN 'Consists of'
		WHEN rela = 'ingredient_of'
			THEN 'RxNorm ing of'
		WHEN rela = 'precise_ingredient_of'
			THEN 'Precise ing of'
		WHEN rela = 'dose_form_of'
			THEN 'RxNorm dose form of'
		WHEN rela = 'isa'
			THEN 'RxNorm is a'
		WHEN rela = 'contained_in'
			THEN 'Contained in'
		WHEN rela = 'form_of'
			THEN 'Form of'
		WHEN rela = 'reformulation_of'
			THEN 'Reformulation of'
		WHEN rela = 'tradename_of'
			THEN 'Tradename of'
		WHEN rela = 'doseformgroup_of'
			THEN 'Dose form group of'
		WHEN rela = 'has_doseformgroup'
			THEN 'Has dose form group'
		ELSE 'non-existing'
		END AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT rxcui1,
		rxcui2,
		rela
	FROM sources.rxnrel
	WHERE sab = 'RXNORM'
		AND rxcui1 IS NOT NULL
		AND rxcui2 IS NOT NULL
		AND EXISTS (
			SELECT 1
			FROM concept
			WHERE vocabulary_id = 'RxNorm'
				AND concept_code = rxcui1
			
			UNION ALL
			
			SELECT 1
			FROM concept_stage
			WHERE vocabulary_id = 'RxNorm'
				AND concept_code = rxcui1
			)
		AND EXISTS (
			SELECT 1
			FROM concept
			WHERE vocabulary_id = 'RxNorm'
				AND concept_code = rxcui2
			
			UNION ALL
			
			SELECT 1
			FROM concept_stage
			WHERE vocabulary_id = 'RxNorm'
				AND concept_code = rxcui2
			)
	) AS s0;

--check for non-existing relationships
ALTER TABLE concept_relationship_stage ADD CONSTRAINT tmp_constraint_relid FOREIGN KEY (relationship_id) REFERENCES relationship (relationship_id);
ALTER TABLE concept_relationship_stage DROP CONSTRAINT tmp_constraint_relid;

--Rename "RxNorm has ing" to "Has brand name" if concept_code_2 has the concept_class_id='Brand Name' and reverse
UPDATE concept_relationship_stage crs_m
SET RELATIONSHIP_ID = 'Has brand name'
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		LEFT JOIN concept_stage cs ON cs.concept_code = crs.concept_code_2
			AND cs.vocabulary_id = crs.vocabulary_id_2
			AND cs.concept_class_id = 'Brand Name'
		LEFT JOIN concept c ON c.concept_code = crs.concept_code_2
			AND c.vocabulary_id = crs.vocabulary_id_2
			AND c.concept_class_id = 'Brand Name'
		WHERE crs.invalid_reason IS NULL
			AND crs.relationship_id = 'RxNorm has ing'
			AND COALESCE(cs.concept_code, c.concept_code) IS NOT NULL
			AND crs_m.concept_code_1 = crs.concept_code_1
			AND crs_m.vocabulary_id_1 = crs.vocabulary_id_1
			AND crs_m.concept_code_2 = crs.concept_code_2
			AND crs_m.vocabulary_id_2 = crs.vocabulary_id_2
			AND crs_m.relationship_id = crs.relationship_id
		);

--reverse
UPDATE concept_relationship_stage crs_m
SET RELATIONSHIP_ID = 'Brand name of'
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		LEFT JOIN concept_stage cs ON cs.concept_code = crs.concept_code_1
			AND cs.vocabulary_id = crs.vocabulary_id_1
			AND cs.concept_class_id = 'Brand Name'
		LEFT JOIN concept c ON c.concept_code = crs.concept_code_1
			AND c.vocabulary_id = crs.vocabulary_id_1
			AND c.concept_class_id = 'Brand Name'
		WHERE crs.invalid_reason IS NULL
			AND crs.relationship_id = 'RxNorm ing of'
			AND COALESCE(cs.concept_code, c.concept_code) IS NOT NULL
			AND crs_m.concept_code_1 = crs.concept_code_1
			AND crs_m.vocabulary_id_1 = crs.vocabulary_id_1
			AND crs_m.concept_code_2 = crs.concept_code_2
			AND crs_m.vocabulary_id_2 = crs.vocabulary_id_2
			AND crs_m.relationship_id = crs.relationship_id
		);

-- Add missing relationships between Branded Packs and their Brand Names
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
WITH pb AS (
		SELECT *
		FROM (
			SELECT pack_code,
				pack_brand,
				brand_code,
				brand_name
			FROM (
				-- The brand names are either listed as tty PSN (prescribing name) or SY (synonym). If they are not listed they don't exist
				SELECT p.rxcui AS pack_code,
					coalesce(b.str, s.str) AS pack_brand
				FROM sources.rxnconso p
				LEFT JOIN sources.rxnconso b ON p.rxcui = b.rxcui
					AND b.sab = 'RXNORM'
					AND b.tty = 'PSN'
				LEFT JOIN sources.rxnconso s ON p.rxcui = s.rxcui
					AND s.sab = 'RXNORM'
					AND s.tty = 'SY'
				WHERE p.sab = 'RXNORM'
					AND p.tty = 'BPCK'
				) AS s0
			JOIN (
				SELECT concept_code AS brand_code,
					concept_name AS brand_name
				FROM concept_stage
				WHERE vocabulary_id = 'RxNorm'
					AND concept_class_id = 'Brand Name'
				) AS s1 ON REPLACE(pack_brand, '-', ' ') ILIKE '%' || REPLACE(brand_name, '-', ' ') || '%'
			) AS s2
		-- apply the slow regexp only to the ones preselected by instr
		WHERE LOWER(REPLACE(pack_brand, '-', ' ')) ~ ('(^|\s|\W)' || LOWER(REPLACE(brand_name, '-', ' ')) || '($|\s|\W)')
		)
SELECT DISTINCT pack_code AS concept_code_1,
	brand_code AS concept_code_2,
	'RxNorm' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'Has brand name' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM pb p
-- kick out those duplicates where one is part of antoher brand name (like 'Demulen' in 'Demulen 1/50', or those that cannot be part of each other.
WHERE NOT EXISTS (
		SELECT 1
		FROM pb q
		WHERE q.brand_code != p.brand_code
			AND p.pack_code = q.pack_code
			AND (
				devv5.INSTR(q.brand_name, p.brand_name) > 0
				OR devv5.INSTR(q.brand_name, p.brand_name) = 0
				AND devv5.INSTR(p.brand_name, q.brand_name) = 0
				)
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = pack_code
			AND crs.concept_code_2 = brand_code
			AND crs.relationship_id = 'Has brand name'
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_2 = pack_code
			AND crs.concept_code_1 = brand_code
			AND crs.relationship_id = 'Brand name of'
		);

-- Remove shortcut 'RxNorm has ing' relationship between 'Clinical Drug', 'Quant Clinical Drug', 'Clinical Pack' and 'Ingredient'
DELETE
FROM concept_relationship_stage r
WHERE EXISTS (
		SELECT 1
		FROM concept_stage d
		WHERE r.concept_code_1 = d.concept_code
			AND r.vocabulary_id_1 = d.vocabulary_id
			AND d.concept_class_id IN (
				'Clinical Drug',
				'Quant Clinical Drug',
				'Clinical Pack'
				)
		)
	AND EXISTS (
		SELECT 1
		FROM concept_stage d
		WHERE r.concept_code_2 = d.concept_code
			AND r.vocabulary_id_2 = d.vocabulary_id
			AND d.concept_class_id = 'Ingredient'
		)
	AND relationship_id = 'RxNorm has ing';

-- and same for reverse
DELETE
FROM concept_relationship_stage r
WHERE EXISTS (
		SELECT 1
		FROM concept_stage d
		WHERE r.concept_code_2 = d.concept_code
			AND r.vocabulary_id_1 = d.vocabulary_id
			AND d.concept_class_id IN (
				'Clinical Drug',
				'Quant Clinical Drug',
				'Clinical Pack'
				)
		)
	AND EXISTS (
		SELECT 1
		FROM concept_stage d
		WHERE r.concept_code_1 = d.concept_code
			AND r.vocabulary_id_2 = d.vocabulary_id
			AND d.concept_class_id = 'Ingredient'
		)
	AND relationship_id = 'RxNorm ing of';

--Rename 'Has tradename' to 'Has brand name'  where concept_id_1='Ingredient' and concept_id_2='Brand Name'
UPDATE concept_relationship_stage crs_m
SET relationship_id = 'Has brand name'
WHERE EXISTS (
		SELECT r.ctid
		FROM concept_relationship_stage r
		WHERE r.relationship_id = 'Has tradename'
			AND EXISTS (
				SELECT 1
				FROM concept_stage cs
				WHERE cs.concept_code = r.concept_code_1
					AND cs.vocabulary_id = r.vocabulary_id_1
					AND cs.concept_class_id = 'Ingredient'
				
				UNION ALL
				
				SELECT 1
				FROM concept c
				WHERE c.concept_code = r.concept_code_1
					AND c.vocabulary_id = r.vocabulary_id_1
					AND c.concept_class_id = 'Ingredient'
				)
			AND EXISTS (
				SELECT 1
				FROM concept_stage cs
				WHERE cs.concept_code = r.concept_code_2
					AND cs.vocabulary_id = r.vocabulary_id_2
					AND cs.concept_class_id = 'Brand Name'
				
				UNION ALL
				
				SELECT 1
				FROM concept c
				WHERE c.concept_code = r.concept_code_2
					AND c.vocabulary_id = r.vocabulary_id_2
					AND c.concept_class_id = 'Brand Name'
				)
			AND crs_m.concept_code_1 = r.concept_code_1
			AND crs_m.vocabulary_id_1 = r.vocabulary_id_1
			AND crs_m.concept_code_2 = r.concept_code_2
			AND crs_m.vocabulary_id_2 = r.vocabulary_id_2
			AND crs_m.relationship_id = r.relationship_id
		);

--and same for reverse
UPDATE concept_relationship_stage crs_m
SET relationship_id = 'Brand name of'
WHERE EXISTS (
		SELECT r.ctid
		FROM concept_relationship_stage r
		WHERE r.relationship_id = 'Tradename of'
			AND EXISTS (
				SELECT 1
				FROM concept_stage cs
				WHERE cs.concept_code = r.concept_code_1
					AND cs.vocabulary_id = r.vocabulary_id_1
					AND cs.concept_class_id = 'Brand Name'
				
				UNION ALL
				
				SELECT 1
				FROM concept c
				WHERE c.concept_code = r.concept_code_1
					AND c.vocabulary_id = r.vocabulary_id_1
					AND c.concept_class_id = 'Brand Name'
				)
			AND EXISTS (
				SELECT 1
				FROM concept_stage cs
				WHERE cs.concept_code = r.concept_code_2
					AND cs.vocabulary_id = r.vocabulary_id_2
					AND cs.concept_class_id = 'Ingredient'
				
				UNION ALL
				
				SELECT 1
				FROM concept c
				WHERE c.concept_code = r.concept_code_2
					AND c.vocabulary_id = r.vocabulary_id_2
					AND c.concept_class_id = 'Ingredient'
				)
			AND crs_m.concept_code_1 = r.concept_code_1
			AND crs_m.vocabulary_id_1 = r.vocabulary_id_1
			AND crs_m.concept_code_2 = r.concept_code_2
			AND crs_m.vocabulary_id_2 = r.vocabulary_id_2
			AND crs_m.relationship_id = r.relationship_id
		);

--6. Add cross-link and mapping table between SNOMED and RxNorm
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
SELECT DISTINCT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'SNOMED' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'SNOMED - RxNorm eq' AS relationship_id,
	d.valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept d
JOIN sources.rxnconso r ON r.code = d.concept_code
	AND r.sab = 'SNOMEDCT_US'
	AND r.code != 'NOCODE'
JOIN concept e ON r.rxcui = e.concept_code
	AND e.vocabulary_id = 'RxNorm'
	AND e.invalid_reason IS NULL
WHERE d.vocabulary_id = 'SNOMED'
	AND d.invalid_reason IS NULL
-- Mapping table between SNOMED to RxNorm. SNOMED is both an intermediary between RxNorm AND DM+D, AND a source code

UNION ALL

SELECT DISTINCT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'SNOMED' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	d.valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept d
JOIN sources.rxnconso r ON r.code = d.concept_code
	AND r.sab = 'SNOMEDCT_US'
	AND r.code != 'NOCODE'
JOIN concept e ON r.rxcui = e.concept_code
	AND e.vocabulary_id = 'RxNorm'
	AND e.invalid_reason IS NULL
WHERE d.vocabulary_id = 'SNOMED'
	AND d.invalid_reason IS NULL
	AND d.concept_class_id NOT IN (
		'Dose Form',
		'Brand Name'
		);

--7. Add upgrade relationships (concept_code_2 shouldn't exists in rxnsat with atn = 'RXN_QUALITATIVE_DISTINCTION')
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
SELECT DISTINCT raa.rxcui AS concept_code_1,
	raa.merged_to_rxcui AS concept_code_2,
	'RxNorm' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'Concept replaced by' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.rxnatomarchive raa
JOIN vocabulary v ON v.vocabulary_id = 'RxNorm' -- for getting the latest_update
LEFT JOIN sources.rxnsat rxs ON rxs.rxcui = raa.merged_to_rxcui
	AND rxs.atn = 'RXN_QUALITATIVE_DISTINCTION'
	AND rxs.sab = raa.sab
WHERE raa.sab = 'RXNORM'
	AND raa.tty IN (
		'IN',
		'DF',
		'SCDC',
		'SCDF',
		'SCD',
		'BN',
		'SBDC',
		'SBDF',
		'SBD',
		'PIN',
		'DFG',
		'SCDG',
		'SBDG'
		)
	AND raa.rxcui <> raa.merged_to_rxcui
	AND rxs.rxcui IS NULL;

--7.1. Add 'Maps to' between RXN_QUALITATIVE_DISTINCTION and fresh concepts (AVOF-457)
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
SELECT raa.merged_to_rxcui AS concept_code_1,
	crs.concept_code_2 AS concept_code_2,
	'RxNorm' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_relationship_stage crs
JOIN sources.rxnatomarchive raa ON raa.sab = 'RXNORM'
	AND raa.tty IN (
		'IN',
		'DF',
		'SCDC',
		'SCDF',
		'SCD',
		'BN',
		'SBDC',
		'SBDF',
		'SBD',
		'PIN',
		'DFG',
		'SCDG',
		'SBDG'
		)
	AND raa.rxcui = crs.concept_code_1
	AND raa.merged_to_rxcui <> crs.concept_code_2
JOIN sources.rxnsat rxs ON rxs.rxcui = raa.merged_to_rxcui
	AND rxs.atn = 'RXN_QUALITATIVE_DISTINCTION'
	AND rxs.sab = raa.sab
JOIN vocabulary v ON v.vocabulary_id = 'RxNorm'
WHERE crs.relationship_id = 'Concept replaced by'
	AND crs.invalid_reason IS NULL
	AND crs.vocabulary_id_1 = 'RxNorm'
	AND crs.vocabulary_id_2 = 'RxNorm';

--7.2. Set standard_concept = NULL for all affected codes with RXN_QUALITATIVE_DISTINCTION (AVOF-457)
UPDATE concept_stage
SET standard_concept = NULL
WHERE (
		concept_code,
		vocabulary_id
		) IN (
		SELECT raa.merged_to_rxcui,
			crs.vocabulary_id_2
		FROM concept_relationship_stage crs
		JOIN sources.rxnatomarchive raa ON raa.sab = 'RXNORM'
			AND raa.tty IN (
				'IN',
				'DF',
				'SCDC',
				'SCDF',
				'SCD',
				'BN',
				'SBDC',
				'SBDF',
				'SBD',
				'PIN',
				'DFG',
				'SCDG',
				'SBDG'
				)
			AND raa.rxcui = crs.concept_code_1
			AND raa.merged_to_rxcui <> crs.concept_code_2
		JOIN sources.rxnsat rxs ON rxs.rxcui = raa.merged_to_rxcui
			AND rxs.atn = 'RXN_QUALITATIVE_DISTINCTION'
			AND rxs.sab = raa.sab
		WHERE crs.relationship_id = 'Concept replaced by'
			AND crs.invalid_reason IS NULL
			AND crs.vocabulary_id_1 = 'RxNorm'
			AND crs.vocabulary_id_2 = 'RxNorm'
		);

--7.3. Revive concepts which have status='active' in https://rxnav.nlm.nih.gov/REST/rxcuihistory/status.xml?type=active, but we have them in the concept with invalid_reason='U' (the source changed his mind)
DROP TABLE IF EXISTS wrong_replacements;
CREATE UNLOGGED TABLE wrong_replacements AS
SELECT c.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	cr.valid_start_date
FROM apigrabber.GetRxNormByStatus('active') api --live grabbing
JOIN concept c ON c.concept_code = api.rxcode
	AND c.invalid_reason = 'U'
	AND c.vocabulary_id = 'RxNorm'
JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
	AND cr.invalid_reason IS NULL
	AND cr.relationship_id = 'Concept replaced by'
JOIN concept c2 ON c2.concept_id = cr.concept_id_2;

--7.3.1 deprecate current replacements
UPDATE concept_relationship_stage crs
SET valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm'
		),
	invalid_reason = 'D'
FROM wrong_replacements wr
WHERE crs.concept_code_1 = wr.concept_code_1
	AND crs.concept_code_2 = wr.concept_code_2
	AND crs.relationship_id = 'Concept replaced by';

--7.3.1 insert new D-replacements
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
SELECT wr.concept_code_1,
	wr.concept_code_2,
	'RxNorm',
	'RxNorm',
	'Concept replaced by',
	wr.valid_start_date,
	(
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm'
		),
	'D'
FROM wrong_replacements wr
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = wr.concept_code_1
			AND crs.concept_code_2 = wr.concept_code_2
			AND crs.relationship_id = 'Concept replaced by'
		);

DROP TABLE wrong_replacements;

--7.3.2 special fix for code=1000589 (RxNorm bug, concept is U but should be alive)
--set concept alive
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
SELECT 'autologous cultured chondrocytes',
	'RxNorm',
	'Drug',
	'Ingredient',
	'S',
	'1000589',
	TO_DATE('20100905', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_stage
		WHERE concept_code = '1000589'
		);

--kill replacement relationship
UPDATE concept_relationship_stage crs
SET valid_end_date = (
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm'
		),
	invalid_reason = 'D'
WHERE crs.concept_code_1 = '1000589'
	AND crs.concept_code_2 = '350141'
	AND crs.relationship_id = 'Concept replaced by';

--7.4 Delete non-existing concepts from concept_relationship_stage
DELETE
FROM concept_relationship_stage crs
WHERE (
		crs.concept_code_1,
		crs.vocabulary_id_1,
		crs.concept_code_2,
		crs.vocabulary_id_2
		) IN (
		SELECT crm.concept_code_1,
			crm.vocabulary_id_1,
			crm.concept_code_2,
			crm.vocabulary_id_2
		FROM concept_relationship_stage crm
		LEFT JOIN concept c1 ON c1.concept_code = crm.concept_code_1
			AND c1.vocabulary_id = crm.vocabulary_id_1
		LEFT JOIN concept_stage cs1 ON cs1.concept_code = crm.concept_code_1
			AND cs1.vocabulary_id = crm.vocabulary_id_1
		LEFT JOIN concept c2 ON c2.concept_code = crm.concept_code_2
			AND c2.vocabulary_id = crm.vocabulary_id_2
		LEFT JOIN concept_stage cs2 ON cs2.concept_code = crm.concept_code_2
			AND cs2.vocabulary_id = crm.vocabulary_id_2
		WHERE (
				c1.concept_code IS NULL
				AND cs1.concept_code IS NULL
				)
			OR (
				c2.concept_code IS NULL
				AND cs2.concept_code IS NULL
				)
		);

--7.5 Add 'Maps to' as part (duplicate) of the 'Form of' relationship between 'Precise Ingredient' and 'Ingredient' (AVOF-1167)
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
SELECT crs.concept_code_1,
	crs.concept_code_2,
	crs.vocabulary_id_1,
	crs.vocabulary_id_2,
	'Maps to',
	crs.valid_start_date,
	crs.valid_end_date,
	NULL
FROM concept_relationship_stage crs
JOIN concept_stage c1 ON c1.concept_code = crs.concept_code_1
	AND c1.vocabulary_id = crs.vocabulary_id_1
	AND c1.concept_class_id = 'Precise Ingredient'
	AND c1.vocabulary_id = 'RxNorm'
JOIN concept_stage c2 ON c2.concept_code = crs.concept_code_2
	AND c2.vocabulary_id = crs.vocabulary_id_2
	AND c2.concept_class_id = 'Ingredient'
	AND c2.vocabulary_id = 'RxNorm'
	AND c2.standard_concept = 'S'
WHERE crs.relationship_id = 'Form of'
	AND crs.invalid_reason IS NULL
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = crs.concept_code_1
			AND crs_int.concept_code_2 = crs.concept_code_2
			AND crs_int.vocabulary_id_1 = crs.vocabulary_id_1
			AND crs_int.vocabulary_id_2 = crs.vocabulary_id_2
			AND crs_int.relationship_id = 'Maps to'
		);

--7.6 Add manual relationships. We can't use concept_relationship_manual because it is used by ATC, NDFRT etc, so we created a new table - concept_relationship_manual_rx
--just copy the code from \working\packages\vocabulary_pack\CheckManualTable.sql and \working\packages\vocabulary_pack\ProcessManualRelationships.sql
DO $_$
DECLARE
z INT4;
BEGIN
	SELECT COUNT(*)
	INTO z
	FROM dev_rxnorm.concept_relationship_manual_rx crm
	LEFT JOIN concept c1 ON c1.concept_code = crm.concept_code_1 AND c1.vocabulary_id = crm.vocabulary_id_1
	LEFT JOIN concept_stage cs1 ON cs1.concept_code = crm.concept_code_1 AND cs1.vocabulary_id = crm.vocabulary_id_1
	LEFT JOIN concept c2 ON c2.concept_code = crm.concept_code_2 AND c2.vocabulary_id = crm.vocabulary_id_2
	LEFT JOIN concept_stage cs2 ON cs2.concept_code = crm.concept_code_2 AND cs2.vocabulary_id = crm.vocabulary_id_2
	LEFT JOIN vocabulary v1 ON v1.vocabulary_id = crm.vocabulary_id_1
	LEFT JOIN vocabulary v2 ON v2.vocabulary_id = crm.vocabulary_id_2
	LEFT JOIN relationship rl ON rl.relationship_id = crm.relationship_id
	LEFT JOIN 
	(
	 SELECT crm_int.concept_code_1,
			crm_int.vocabulary_id_1,
			crm_int.concept_code_2,
			crm_int.vocabulary_id_2,
			crm_int.relationship_id
	 FROM dev_rxnorm.concept_relationship_manual_rx crm_int
	 GROUP BY crm_int.concept_code_1,
			crm_int.vocabulary_id_1,
			crm_int.concept_code_2,
			crm_int.vocabulary_id_2,
			crm_int.relationship_id
	HAVING COUNT(*) > 1
	) c_i ON c_i.concept_code_1 = crm.concept_code_1 AND c_i.vocabulary_id_1 = crm.vocabulary_id_1 AND c_i.concept_code_2 = crm.concept_code_2 AND
	c_i.vocabulary_id_2 = crm.vocabulary_id_2 AND c_i.relationship_id = crm.relationship_id
	WHERE (c1.concept_code IS NULL
	AND cs1.concept_code IS NULL)
	OR (c2.concept_code IS NULL
	AND cs2.concept_code IS NULL)
	OR v1.vocabulary_id IS NULL
	OR v2.vocabulary_id IS NULL
	OR rl.relationship_id IS NULL
	OR crm.valid_start_date > CURRENT_DATE
	OR crm.valid_end_date < crm.valid_start_date
	OR date_trunc('day', (crm.valid_start_date)) <> crm.valid_start_date
	OR date_trunc('day', (crm.valid_end_date)) <> crm.valid_end_date
	OR (crm.invalid_reason IS NULL
	AND crm.valid_end_date <> TO_DATE('20991231', 'yyyymmdd'))
	OR c_i.concept_code_1 IS NOT NULL;

	IF z > 0 THEN
		RAISE EXCEPTION  'CheckManualTable: % error(s) found', z;
	END IF;

	--add new records
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
	SELECT *
	FROM dev_rxnorm.concept_relationship_manual_rx m
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_relationship_stage crs_int
			WHERE crs_int.concept_code_1 = m.concept_code_1
				AND crs_int.concept_code_2 = m.concept_code_2
				AND crs_int.vocabulary_id_1 = m.vocabulary_id_1
				AND crs_int.vocabulary_id_2 = m.vocabulary_id_2
				AND crs_int.relationship_id = m.relationship_id
			);

	--update existing
	UPDATE concept_relationship_stage crs
	SET valid_start_date = m.valid_start_date,
		valid_end_date = m.valid_end_date,
		invalid_reason = m.invalid_reason
	FROM dev_rxnorm.concept_relationship_manual_rx m
	WHERE crs.concept_code_1 = m.concept_code_1
		AND crs.concept_code_2 = m.concept_code_2
		AND crs.vocabulary_id_1 = m.vocabulary_id_1
		AND crs.vocabulary_id_2 = m.vocabulary_id_2
		AND crs.relationship_id = m.relationship_id
		AND (
			crs.valid_start_date <> m.valid_start_date
			OR crs.valid_end_date <> m.valid_end_date
			OR coalesce(crs.invalid_reason, 'X') <> coalesce(m.invalid_reason, 'X')
			);
END $_$;

--8. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--9. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--10. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--11. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--12. Create mapping to self for fresh concepts
ANALYZE concept_relationship_stage;
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
SELECT concept_code AS concept_code_1,
	concept_code AS concept_code_2,
	c.vocabulary_id AS vocabulary_id_1,
	c.vocabulary_id AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage c,
	vocabulary v
WHERE c.vocabulary_id = v.vocabulary_id
	AND c.standard_concept = 'S'
	AND NOT EXISTS -- only new mapping we don't already have
	(
		SELECT 1
		FROM concept_relationship_stage i
		WHERE c.concept_code = i.concept_code_1
			AND c.concept_code = i.concept_code_2
			AND c.vocabulary_id = i.vocabulary_id_1
			AND c.vocabulary_id = i.vocabulary_id_2
			AND i.relationship_id = 'Maps to'
		);
ANALYZE concept_relationship_stage;

--13. Turn "Clinical Drug" to "Quant Clinical Drug" and "Branded Drug" to "Quant Branded Drug"
UPDATE concept_stage c
SET concept_class_id = CASE 
		WHEN concept_class_id = 'Branded Drug'
			THEN 'Quant Branded Drug'
		ELSE 'Quant Clinical Drug'
		END
WHERE concept_class_id IN (
		'Branded Drug',
		'Clinical Drug'
		)
	AND EXISTS (
		SELECT 1
		FROM concept_relationship_stage r
		WHERE r.relationship_id = 'Quantified form of'
			AND r.concept_code_1 = c.concept_code
			AND r.vocabulary_id_1 = c.vocabulary_id
		);

--14. Create pack_content_stage table
INSERT INTO pack_content_stage
SELECT pc.pack_code AS pack_concept_code,
	'RxNorm' AS pack_vocabulary_id,
	cont.concept_code AS drug_concept_code,
	'RxNorm' AS drug_vocabulary_id,
	pc.amount::FLOAT, -- of drug units in the pack
	NULL AS box_size -- number of the overall combinations units
FROM (
	SELECT pack_code,
		-- Parse the number at the beginning of each drug string as the amount
		SUBSTRING(pack_name, '^[0-9]+') AS amount,
		-- Parse the number in parentheses on the second position of the drug string as the quantity factor of a quantified drug (usually not listed in the concept table), not used right now
		TRANSLATE(SUBSTRING(pack_name, '\([0-9]+ [A-Za-z]+\)'), 'a()', 'a') AS quant,
		-- Don't parse the drug name, because it will be found through instr() with the known name of the component (see below)
		pack_name AS drug
	FROM (
		SELECT DISTINCT pack_code,
			-- This is the sequence to split the concept_name of the packs by the semicolon, which replaces the parentheses plus slash (see below)
			TRIM(UNNEST(regexp_matches(pack_name, '[^;]+', 'g'))) AS pack_name
		FROM (
			-- This takes a Pack name, replaces the sequence ') / ' with a semicolon for splitting, and removes the word Pack and everything thereafter (the brand name usually)
			SELECT rxcui AS pack_code,
				REGEXP_REPLACE(REPLACE(REPLACE(str, ') / ', ';'), '{', ''), '\) } Pack( \[.+\])?', '','g') AS pack_name
			FROM sources.rxnconso
			WHERE sab = 'RXNORM'
				AND tty LIKE '%PCK' -- Clinical (=Generic) or Branded Pack
			) AS s0
		) AS s1
	) AS pc
-- match by name with the component drug obtained through the 'Contains' relationship
LEFT JOIN (
	SELECT concept_code_1,
		concept_code_2,
		concept_code,
		concept_name
	FROM concept_relationship_stage r
	JOIN concept_stage ON concept_code = r.concept_code_2
	WHERE r.relationship_id = 'Contains'
		AND r.invalid_reason IS NULL
	) cont ON cont.concept_code_1 = pc.pack_code
	AND pc.drug LIKE '%' || cont.concept_name || '%' -- this is where the component name is fit into the parsed drug name from the Pack string
GROUP BY pc.pack_code,
	cont.concept_code,
	pc.amount;

--15. Run FillDrugStrengthStage
DO $_$
BEGIN
	PERFORM dev_rxnorm.FillDrugStrengthStage();
END $_$;

--16. Run generic_update
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;

--17. After previous step disable indexes and truncate tables again
UPDATE vocabulary SET (latest_update, vocabulary_version, dev_schema_name)=
(select latest_update, vocabulary_version, dev_schema_name from vocabulary WHERE vocabulary_id = 'RxNorm')
	WHERE vocabulary_id in ('NDFRT','VA Product', 'VA Class', 'ATC');
UPDATE vocabulary SET latest_update=null, dev_schema_name=null WHERE vocabulary_id = 'RxNorm';

TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--18. Add NDFRT, VA Product, VA Class and ATC
--create temporary table drug_vocs
DROP TABLE IF EXISTS drug_vocs;
CREATE UNLOGGED TABLE drug_vocs AS
SELECT rxcui,
	code,
	concept_name,
	CASE 
		WHEN concept_class_id LIKE 'VA%'
			THEN concept_class_id
		ELSE 'NDFRT'
		END AS vocabulary_id,
	CASE concept_class_id
		WHEN 'VA Product'
			THEN NULL
		WHEN 'Dose Form'
			THEN NULL
		WHEN 'Pharma Preparation'
			THEN NULL
		ELSE 'C'
		END AS standard_concept,
	concept_code,
	concept_class_id
FROM (
	SELECT rxcui,
		code,
		CASE 
			WHEN devv5.INSTR(str, '[') > 1
				THEN SUBSTR(str, 1, devv5.INSTR(str, '[') - 1)
			WHEN devv5.INSTR(str, '[') = 1
				THEN SUBSTR(str, devv5.instr(str, ']') + 2, 256)
			ELSE SUBSTR(str, 1, 255)
			END AS concept_name,
		CASE 
			WHEN devv5.instr(str, '[') = 1
				THEN SUBSTR(str, 2, devv5.instr(str, ']') - 2)
			ELSE code
			END AS concept_code,
		CASE 
			WHEN devv5.instr(str, '[') > 1
				THEN CASE REGEXP_REPLACE(str, '([^\[]+)\[([^]]+)\]', '\2')
						WHEN 'PK'
							THEN 'PK'
						WHEN 'Dose Form'
							THEN 'Dose Form'
						WHEN 'TC'
							THEN 'Therapeutic Class'
						WHEN 'MoA'
							THEN 'Mechanism of Action'
						WHEN 'PE'
							THEN 'Physiologic Effect'
						WHEN 'VA Product'
							THEN 'VA Product'
						WHEN 'EPC'
							THEN 'Pharmacologic Class'
						WHEN 'Chemical/Ingredient'
							THEN 'Chemical Structure'
						WHEN 'Disease/Finding'
							THEN 'Ind / CI'
						END
			WHEN devv5.instr(str, '[') = 1
				THEN 'VA Class'
			ELSE 'Pharma Preparation'
			END AS concept_class_id
	FROM sources.rxnconso
	WHERE sab = 'NDFRT'
		AND tty IN (
			'FN',
			'HT',
			'MTH_RXN_RHT'
			)
		AND code != 'NOCODE'
	) AS s0
WHERE concept_class_id IS NOT NULL -- kick out "preparations", which really are the useless 1st initial of pharma preparations
-- Add ATC
UNION ALL
SELECT rxcui,
	code,
	concept_name,
	'ATC' AS vocabulary_id,
	'C' AS standard_concept,
	concept_code,
	concept_class_id
FROM (
	SELECT DISTINCT rxcui,
		code,
		SUBSTR(str, 1, 255) AS concept_name,
		code AS concept_code,
		CASE 
			WHEN LENGTH(code) = 1
				THEN 'ATC 1st'
			WHEN LENGTH(code) = 3
				THEN 'ATC 2nd'
			WHEN LENGTH(code) = 4
				THEN 'ATC 3rd'
			WHEN LENGTH(code) = 5
				THEN 'ATC 4th'
			WHEN LENGTH(code) = 7
				THEN 'ATC 5th'
			END AS concept_class_id
	FROM sources.rxnconso
	WHERE sab = 'ATC'
		AND tty IN (
			'PT',
			'IN'
			)
		AND code != 'NOCODE'
	) AS s1;

CREATE INDEX idx_drugvocs_code ON drug_vocs (code);
CREATE INDEX idx_drugvocs_ccode ON drug_vocs (concept_code);
ANALYZE drug_vocs;

--19. Add drug_vocs to concept_stage
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
SELECT concept_name,
	'Drug' AS domain_id,
	dv.vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM drug_vocs dv,
	vocabulary v
WHERE v.vocabulary_id = dv.vocabulary_id;

--20. Rename the top NDFRT concept
UPDATE concept_stage
SET concept_name = 'NDF-RT release ' || (
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'NDFRT'
		),
	domain_id = 'Metadata'
WHERE concept_code = 'N0000000001';

--21. Create all sorts of relationships to self, RxNorm and SNOMED
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
SELECT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'VA Class to ATC eq' AS relationship_id,
	'VA Class' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM drug_vocs d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN drug_vocs e ON r.rxcui = e.rxcui
	AND r.code = e.concept_code
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
WHERE d.concept_class_id LIKE 'VA Class'
	AND e.concept_class_id LIKE 'ATC%'
-- Cross-link between drug class Chemical Structure AND ATC

UNION

SELECT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'NDFRT to ATC eq' AS relationship_id,
	'NDFRT' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM drug_vocs d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN drug_vocs e ON r.rxcui = e.rxcui
	AND r.code = e.concept_code
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
WHERE d.concept_class_id = 'Chemical Structure'
	AND e.concept_class_id IN (
		'ATC 1st',
		'ATC 2nd',
		'ATC 3rd',
		'ATC 4th'
		)
-- Cross-link between drug class ATC AND Therapeutic Class

UNION

SELECT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'NDFRT to ATC eq' AS relationship_id,
	'NDFRT' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM drug_vocs d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN drug_vocs e ON r.rxcui = e.rxcui
	AND r.code = e.concept_code
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
WHERE d.concept_class_id LIKE 'Therapeutic Class'
	AND e.concept_class_id LIKE 'ATC%'
-- Cross-link between drug class VA Class AND Chemical Structure

UNION

SELECT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'VA Class to NDFRT eq' AS relationship_id,
	'VA Class' AS vocabulary_id_1,
	'NDFRT' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM drug_vocs d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN drug_vocs e ON r.rxcui = e.rxcui
	AND r.code = e.concept_code
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
WHERE d.concept_class_id LIKE 'VA Class'
	AND e.concept_class_id = 'Chemical Structure'
-- Cross-link between drug class VA Class AND Therapeutic Class

UNION

SELECT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'VA Class to NDFRT eq' AS relationship_id,
	'VA Class' AS vocabulary_id_1,
	'NDFRT' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM drug_vocs d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN drug_vocs e ON r.rxcui = e.rxcui
	AND r.code = e.concept_code
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
WHERE d.concept_class_id LIKE 'VA Class'
	AND e.concept_class_id = 'Therapeutic Class'
-- Cross-link between drug class Chemical Structure AND Pharmaceutical Preparation

UNION

SELECT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'Chem to Prep eq' AS relationship_id, -- this is one to substitute "NDFRT has ing", is hierarchical AND defines ancestry.
	'NDFRT' AS vocabulary_id_1,
	'NDFRT' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM drug_vocs d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN drug_vocs e ON r.rxcui = e.rxcui
	AND r.code = e.concept_code
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
WHERE d.concept_class_id LIKE 'Chemical Structure'
	AND e.concept_class_id = 'Pharma Preparation'
-- Cross-link between drug class SNOMED AND NDF-RT

UNION

SELECT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'SNOMED - NDFRT eq' AS relationship_id,
	'SNOMED' AS vocabulary_id_1,
	'NDFRT' AS vocabulary_id_2,
	d.valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept d
JOIN sources.rxnconso r ON r.code = d.concept_code
	AND r.sab = 'SNOMEDCT_US'
	AND r.code != 'NOCODE'
JOIN sources.rxnconso r2 ON r.rxcui = r2.rxcui
	AND r2.sab = 'NDFRT'
	AND r2.code != 'NOCODE'
JOIN drug_vocs e ON r2.code = e.concept_code
	AND e.vocabulary_id = 'NDFRT'
WHERE d.vocabulary_id = 'SNOMED'
	AND invalid_reason IS NULL
	-- exclude all the Pharmaceutical Preps that are duplicates for RxNorm Ingredients
	AND NOT EXISTS (
		SELECT 1
		FROM drug_vocs pp
		WHERE pp.rxcui = r.rxcui
			AND pp.concept_class_id = 'Pharma Preparation'
		)
-- Cross-link between drug class SNOMED AND VA Class

UNION

SELECT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'SNOMED - VA Class eq' AS relationship_id,
	'SNOMED' AS vocabulary_id_1,
	'VA Class' AS vocabulary_id_2,
	d.valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept d
JOIN sources.rxnconso r ON r.code = d.concept_code
	AND r.sab = 'SNOMEDCT_US'
	AND r.code != 'NOCODE'
JOIN sources.rxnconso r2 ON r.rxcui = r2.rxcui
	AND r2.sab = 'NDFRT'
	AND r2.code != 'NOCODE'
JOIN drug_vocs e ON r2.code = e.code
	AND e.vocabulary_id = 'VA Class' -- code AND concept_code are different for VA Class
WHERE d.vocabulary_id = 'SNOMED'
	AND d.invalid_reason IS NULL
-- Cross-link between drug class SNOMED AND ATC classes (not ATC 5th)

UNION

SELECT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'SNOMED - ATC eq' AS relationship_id,
	'SNOMED' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	d.valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept d
JOIN sources.rxnconso r ON r.code = d.concept_code
	AND r.sab = 'SNOMEDCT_US'
	AND r.code != 'NOCODE'
JOIN sources.rxnconso r2 ON r.rxcui = r2.rxcui
	AND r2.sab = 'ATC'
	AND r2.code != 'NOCODE'
JOIN drug_vocs e ON r2.code = e.concept_code
	AND e.concept_class_id != 'ATC 5th' -- Ingredients only to RxNorm
WHERE d.vocabulary_id = 'SNOMED'
	AND d.invalid_reason IS NULL
-- Cross-link between any NDF-RT (mostly Pharmaceutical Preps AND Chemical Structure) to RxNorm

UNION

SELECT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'NDFRT - RxNorm eq' AS relationship_id,
	'NDFRT' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM drug_vocs d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
JOIN concept e ON r.rxcui = e.concept_code
	AND e.vocabulary_id = 'RxNorm'
	AND e.invalid_reason IS NULL
WHERE d.vocabulary_id = 'NDFRT'
-- Cross-link between any NDF-RT to RxNorm by name, but exclude the ones the previous query did already

UNION

SELECT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'NDFRT - RxNorm name' AS relationship_id,
	'NDFRT' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM drug_vocs d
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
JOIN concept e ON LOWER(d.concept_name) = LOWER(e.concept_name)
	AND e.vocabulary_id = 'RxNorm'
	AND e.invalid_reason IS NULL
WHERE d.vocabulary_id = 'NDFRT'
	AND NOT EXISTS (
		SELECT 1
		FROM drug_vocs d_int
		JOIN sources.rxnconso r_int ON r_int.rxcui = d_int.rxcui
			AND r_int.code != 'NOCODE'
		JOIN concept e_int ON r_int.rxcui = e_int.concept_code
			AND e_int.vocabulary_id = 'RxNorm'
			AND e_int.invalid_reason IS NULL
		WHERE d_int.vocabulary_id = 'NDFRT'
			AND d_int.concept_code = d.concept_code
			AND e_int.concept_code = e.concept_code
		)
-- Cross-link between VA Product AND RxNorm

UNION

SELECT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'VAProd - RxNorm eq' AS relationship_id,
	'VA Product' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM drug_vocs d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
JOIN concept e ON r.rxcui = e.concept_code
	AND e.vocabulary_id = 'RxNorm'
	AND e.invalid_reason IS NULL
WHERE d.vocabulary_id = 'VA Product'
-- Mapping table between VA Product to RxNorm. VA Product is both an intermediary between RxNorm AND VA class, AND a source code

UNION

SELECT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'Maps to' AS relationship_id,
	'VA Product' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM drug_vocs d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
JOIN concept e ON r.rxcui = e.concept_code
	AND e.vocabulary_id = 'RxNorm'
	AND e.invalid_reason IS NULL
WHERE d.vocabulary_id = 'VA Product'
-- add ATC to RxNorm

UNION

SELECT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'ATC - RxNorm' AS relationship_id, -- this is one to substitute "NDFRF has ing", is hierarchical AND defines ancestry.
	'ATC' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM drug_vocs d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
JOIN concept e ON r.rxcui = e.concept_code
	AND e.vocabulary_id = 'RxNorm'
	AND e.invalid_reason IS NULL
WHERE d.vocabulary_id = 'ATC'
	AND d.concept_class_id = 'ATC 5th' -- there are some weird 4th level links, LIKE D11AC 'Medicated shampoos' to an RxNorm Dose Form
	-- DO NOT add ATC to RxNorm mapping, because of bad min/max levels of separation [AVOF-82]
	/*
   -- add ATC to RxNorm mapping. ATC is both a classification (ATC 1-4) AND a source (ATC 5th)
   UNION 
   SELECT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'Maps to' AS relationship_id, -- this is one to substitute "NDFRF has ing", is hierarchical AND defines ancestry.
                   'ATC' AS vocabulary_id_1,
                   'RxNorm' AS vocabulary_id_2,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM drug_vocs d
          JOIN sources.rxnconso r ON r.rxcui = d.rxcui AND r.code != 'NOCODE'
          JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
          JOIN concept e
             ON     r.rxcui = e.concept_code
                AND e.vocabulary_id = 'RxNorm'
                AND e.invalid_reason IS NULL
    WHERE d.vocabulary_id = 'ATC' AND d.concept_class_id = 'ATC 5th' -- there are some weird 4th level links, LIKE D11AC 'Medicated shampoos' to an RxNorm Dose Form
	*/
-- add ATC to RxNorm by name, but exclude the ones the previous query did already

UNION

SELECT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'ATC - RxNorm name' AS relationship_id, -- this is one to substitute "NDFRF has ing", is hierarchical AND defines ancestry.
	'ATC' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM drug_vocs d
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
JOIN concept e ON LOWER(d.concept_name) = LOWER(e.concept_name)
	AND e.vocabulary_id = 'RxNorm'
	AND e.invalid_reason IS NULL
WHERE d.vocabulary_id = 'ATC'
	AND d.concept_class_id = 'ATC 5th' -- there are some weird 4th level links, LIKE D11AC 'Medicated shampoos' to an RxNorm Dose Form
	AND NOT EXISTS (
		SELECT 1
		FROM drug_vocs d_int
		JOIN sources.rxnconso r_int ON r_int.rxcui = d_int.rxcui
			AND r_int.code != 'NOCODE'
		JOIN concept e_int ON r_int.rxcui = e_int.concept_code
			AND e_int.vocabulary_id = 'RxNorm'
			AND e_int.invalid_reason IS NULL
		WHERE d_int.vocabulary_id = 'ATC'
			AND d_int.concept_class_id = 'ATC 5th'
			AND d_int.concept_code = d.concept_code
			AND e_int.concept_code = e.concept_code
		)
-- NDF-RT-defined relationships

UNION

SELECT concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM (
	SELECT DISTINCT e.concept_code AS concept_code_1,
		d.concept_code AS concept_code_2,
		CASE 
			WHEN r.rel = 'PAR'
				THEN 'Subsumes'
			WHEN r.rela = 'active_metabolites_of'
				THEN 'Metabolite of'
			WHEN r.rela = 'chemical_structure_of'
				THEN 'Chem structure of'
			WHEN r.rela = 'contraindicated_with_disease'
				THEN 'CI by'
			WHEN r.rela = 'contraindicating_class_of'
				THEN 'CI chem class of'
			WHEN r.rela = 'contraindicating_mechanism_of_action_of'
				THEN 'CI MoA of'
			WHEN r.rela = 'contraindicating_physiologic_effect_of'
				THEN 'CI physiol effect by'
			WHEN r.rela = 'dose_form_of'
				THEN 'NDFRT dose form of'
			WHEN r.rela = 'effect_may_be_inhibited_by'
				THEN 'May be inhibited by'
			WHEN r.rela = 'ingredient_of'
				THEN 'NDFRT ing of'
			WHEN r.rela = 'mechanism_of_action_of'
				THEN 'MoA of'
			WHEN r.rela = 'member_of'
				THEN 'Is a'
			WHEN r.rela = 'pharmacokinetics_of'
				THEN 'PK of'
			WHEN r.rela = 'physiologic_effect_of'
				THEN 'Physiol effect by'
			WHEN r.rela = 'product_component_of'
				THEN 'Product comp of'
			WHEN r.rela = 'therapeutic_class_of'
				THEN 'Therap class of'
			WHEN r.rela = 'induced_by'
				THEN 'Induced by'
			WHEN r.rela = 'inverse_isa'
				THEN 'Subsumes'
			WHEN r.rela = 'may_be_diagnosed_by'
				THEN 'Diagnosed through'
			WHEN r.rela = 'may_be_prevented_by'
				THEN 'May be prevented by'
			WHEN r.rela = 'may_be_treated_by'
				THEN 'May be treated by'
			WHEN r.rela = 'metabolic_site_of'
				THEN 'Metabolism of'
			END AS relationship_id,
		e.vocabulary_id AS vocabulary_id_1,
		d.vocabulary_id AS vocabulary_id_2,
		v.latest_update AS valid_start_date,
		TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
		NULL AS invalid_reason
	FROM drug_vocs d
	JOIN sources.rxnconso r1 ON r1.rxcui = d.rxcui
		AND r1.code = d.code
		AND r1.code != 'NOCODE'
	JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
	JOIN sources.rxnrel r ON r.rxaui1 = r1.rxaui
	JOIN sources.rxnconso r2 ON r2.rxaui = r.rxaui2
		AND r2.code != 'NOCODE'
	JOIN drug_vocs e ON r2.code = e.code
		AND e.rxcui = r2.rxcui
	) AS s0
WHERE relationship_id IS NOT NULL

UNION

-- Hierarchy inside ATC
SELECT uppr.concept_code AS concept_code_1,
	lowr.concept_code AS concept_code_2,
	'Is a' AS relationship_id,
	'ATC' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage uppr,
	concept_stage lowr,
	vocabulary v
WHERE (
		(
			LENGTH(uppr.concept_code) IN (
				4,
				5
				)
			AND lowr.concept_code = SUBSTR(uppr.concept_code, 1, LENGTH(uppr.concept_code) - 1)
			)
		OR (
			LENGTH(uppr.concept_code) IN (
				3,
				7
				)
			AND lowr.concept_code = SUBSTR(uppr.concept_code, 1, LENGTH(uppr.concept_code) - 2)
			)
		)
	AND uppr.vocabulary_id = 'ATC'
	AND lowr.vocabulary_id = 'ATC'
	AND v.vocabulary_id = 'ATC';

--22. Add manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--23. Remove direct links to RxNorm Ingredients for all those ATC5 concepts that are ambiguous and likely are either defined as combinations or with certain Drug Forms only
ANALYZE concept_relationship_stage;
DELETE
FROM concept_relationship_stage crs
WHERE EXISTS (
		SELECT 1
		FROM concept_stage c1,
			concept c2,
			concept_relationship_stage crs_int
		WHERE c1.concept_code = crs_int.concept_code_1
			AND c1.vocabulary_id = crs_int.vocabulary_id_1
			AND c2.concept_code = crs_int.concept_code_2
			AND c2.vocabulary_id = crs_int.vocabulary_id_2
			AND c1.vocabulary_id = 'ATC'
			AND c1.concept_class_id = 'ATC 5th'
			AND c1.invalid_reason IS NULL
			AND c2.vocabulary_id = 'RxNorm'
			--AND c2.concept_class_id IN ('Ingredient','Precise Ingredient') /*AVOF-322*/
			AND crs_int.relationship_id IN (
				'ATC - RxNorm',
				'ATC - RxNorm name'
				)
			AND crs_int.invalid_reason IS NULL
			AND c1.concept_name IN (
				SELECT c_int.concept_name
				FROM concept_stage c_int
				WHERE c_int.vocabulary_id = 'ATC'
					AND c_int.concept_class_id = 'ATC 5th'
					AND c_int.invalid_reason IS NULL
					AND c_int.concept_name <> 'combinations'
				GROUP BY c_int.concept_name
				HAVING COUNT(*) > 1
				)
			AND crs_int.concept_code_1 = crs.concept_code_1
			AND crs_int.vocabulary_id_1 = crs.vocabulary_id_1
			AND crs_int.concept_code_2 = crs.concept_code_2
			AND crs_int.vocabulary_id_2 = crs.vocabulary_id_2
			AND crs_int.relationship_id = crs.relationship_id
		);

--24. Remove ATC's duplicates (AVOF-322)
--diphtheria immunoglobulin
DELETE FROM concept_relationship_stage WHERE concept_code_1 = 'J06BB10' AND concept_code_2 = '3510' AND relationship_id = 'ATC - RxNorm';
--hydroquinine
DELETE FROM concept_relationship_stage WHERE concept_code_1 = 'M09AA01' AND concept_code_2 = '27220' AND relationship_id = 'ATC - RxNorm';

--25. Deprecate relationships between multi ingredient drugs and a single ATC 5th, because it should have either an ATC for each ingredient or an ATC that is a combination of them
--25.1. Create temporary table drug_strength_ext (same code as in concept_ancestor, but we exclude ds for ingredients (because we use count(*)>1 and ds for ingredients having count(*)=1) and only for RxNorm)
DROP TABLE IF EXISTS drug_strength_ext;
CREATE UNLOGGED TABLE drug_strength_ext AS
SELECT *
FROM (
	WITH ingredient_unit AS (
			SELECT DISTINCT
				-- pick the most common unit for an ingredient. If there is a draw, pick always the same by sorting by unit_concept_id
				ingredient_concept_code,
				vocabulary_id,
				FIRST_VALUE(unit_concept_id) OVER (
					PARTITION BY ingredient_concept_code ORDER BY cnt DESC,
						unit_concept_id
					) AS unit_concept_id
			FROM (
				-- sum the counts coming from amount and numerator
				SELECT ingredient_concept_code,
					vocabulary_id,
					unit_concept_id,
					SUM(cnt) AS cnt
				FROM (
					-- count ingredients, their units and the frequency
					SELECT c2.concept_code AS ingredient_concept_code,
						c2.vocabulary_id,
						ds.amount_unit_concept_id AS unit_concept_id,
						COUNT(*) AS cnt
					FROM drug_strength ds
					JOIN concept c1 ON c1.concept_id = ds.drug_concept_id
						AND c1.vocabulary_id = 'RxNorm'
					JOIN concept c2 ON c2.concept_id = ds.ingredient_concept_id
						AND c2.vocabulary_id = 'RxNorm'
					WHERE ds.amount_value <> 0
					GROUP BY c2.concept_code,
						c2.vocabulary_id,
						ds.amount_unit_concept_id
					
					UNION
					
					SELECT c2.concept_code AS ingredient_concept_code,
						c2.vocabulary_id,
						ds.numerator_unit_concept_id AS unit_concept_id,
						COUNT(*) AS cnt
					FROM drug_strength ds
					JOIN concept c1 ON c1.concept_id = ds.drug_concept_id
						AND c1.vocabulary_id = 'RxNorm'
					JOIN concept c2 ON c2.concept_id = ds.ingredient_concept_id
						AND c2.vocabulary_id = 'RxNorm'
					WHERE ds.numerator_value <> 0
					GROUP BY c2.concept_code,
						c2.vocabulary_id,
						ds.numerator_unit_concept_id
					) AS s0
				GROUP BY ingredient_concept_code,
					vocabulary_id,
					unit_concept_id
				) AS s1
			)
	-- Create drug_strength for drug forms
	SELECT de.concept_code AS drug_concept_code,
		an.concept_code AS ingredient_concept_code
	FROM concept an
	JOIN rxnorm_ancestor a ON a.ancestor_concept_code = an.concept_code
		AND a.ancestor_vocabulary_id = an.vocabulary_id
	JOIN concept de ON de.concept_code = a.descendant_concept_code
		AND de.vocabulary_id = a.descendant_vocabulary_id
	JOIN ingredient_unit iu ON iu.ingredient_concept_code = an.concept_code
		AND iu.vocabulary_id = an.vocabulary_id
	WHERE an.vocabulary_id = 'RxNorm'
		AND an.concept_class_id = 'Ingredient'
		AND de.vocabulary_id = 'RxNorm'
		AND de.concept_class_id IN (
			'Clinical Drug Form',
			'Branded Drug Form'
			)
	) AS s2;

--25.2. Do deprecation
DELETE
FROM concept_relationship_stage
WHERE ctid IN (
		SELECT drug2atc.row_id
		FROM (
			SELECT drug_concept_code
			FROM (
				SELECT c1.concept_code AS drug_concept_code,
					c2.concept_code
				FROM drug_strength ds
				JOIN concept c1 ON c1.concept_id = ds.drug_concept_id
					AND c1.vocabulary_id = 'RxNorm'
				JOIN concept c2 ON c2.concept_id = ds.ingredient_concept_id
				
				UNION
				
				SELECT drug_concept_code,
					ingredient_concept_code
				FROM drug_strength_ext
				) AS s0
			GROUP BY drug_concept_code
			HAVING count(*) > 1
			) all_drugs
		JOIN (
			SELECT *
			FROM (
				SELECT crs.ctid row_id,
					crs.concept_code_2,
					count(*) OVER (PARTITION BY crs.concept_code_2) cnt_atc
				FROM concept_relationship_stage crs
				JOIN concept_stage cs ON cs.concept_code = crs.concept_code_1
					AND cs.vocabulary_id = crs.vocabulary_id_1
					AND cs.vocabulary_id = 'ATC'
					AND cs.concept_class_id = 'ATC 5th'
					AND NOT cs.concept_name ~ 'preparations|virus|antigen|-|/|organisms|insulin|etc\.|influenza|human menopausal gonadotrophin|combination|amino acids|electrolytes| and |excl\.| with |others|various'
				JOIN concept c ON c.concept_code = crs.concept_code_2
					AND c.vocabulary_id = crs.vocabulary_id_2
					AND c.vocabulary_id = 'RxNorm'
				WHERE crs.relationship_id = 'ATC - RxNorm'
					AND crs.invalid_reason IS NULL
				) AS s1
			WHERE cnt_atc = 1
			) drug2atc ON drug2atc.concept_code_2 = all_drugs.drug_concept_code
		);

--26. Add synonyms to concept_synonym stage for each of the rxcui/code combinations in drug_vocs
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT dv.concept_code AS synonym_concept_code,
	CASE 
		WHEN dv.vocabulary_id = 'VA Class'
			THEN SUBSTR(REPLACE(r.str, '[' || dv.concept_code || '] ', ''), 1, 1000)
		WHEN dv.vocabulary_id IN (
				'NDFRT',
				'VA Product'
				)
			AND devv5.INSTR(r.str, '[') <> 0
			THEN SUBSTR(r.str, 1, LEAST(devv5.INSTR(r.str, '[') - 2, 1000))
		ELSE SUBSTR(r.str, 1, 1000)
		END AS synonym_name,
	dv.vocabulary_id AS synonym_vocabulary_id,
	4180186 AS language_concept_id
FROM drug_vocs dv
JOIN sources.rxnconso r ON dv.code = r.code
	AND dv.rxcui = r.rxcui
	AND r.code != 'NOCODE'
	AND r.lat = 'ENG';

--27. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--28. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--29. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--30. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--31. Delete mappings between concepts that are not represented at the "latest_update" at this moment (e.g. SNOMED <-> RxNorm, but currently we are updating VA*, ATC etc)
--This is because we have SNOMED <-> NDFRT in concept_relationship_stage, but AddFreshMAPSTO adds SNOMED <-> RxNorm from concept_relationship
DELETE
FROM concept_relationship_stage crs_o
WHERE (
		crs_o.concept_code_1,
		crs_o.vocabulary_id_1,
		crs_o.concept_code_2,
		crs_o.vocabulary_id_2
		) IN (
		SELECT crs.concept_code_1,
			crs.vocabulary_id_1,
			crs.concept_code_2,
			crs.vocabulary_id_2
		FROM concept_relationship_stage crs
		LEFT JOIN vocabulary v1 ON v1.vocabulary_id = crs.vocabulary_id_1
			AND v1.latest_update IS NOT NULL
		LEFT JOIN vocabulary v2 ON v2.vocabulary_id = crs.vocabulary_id_2
			AND v2.latest_update IS NOT NULL
		WHERE coalesce(v1.latest_update, v2.latest_update) IS NULL
		);

--32. Clean up
DROP TABLE drug_vocs;
DROP TABLE rxnorm_ancestor;
DROP TABLE drug_strength_ext;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script