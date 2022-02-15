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
* Authors: Christian Reich, Timur Vakhitov, Eduard Korchmar
* Date: 2022
**************************************************************************/

--1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'RxNorm Extension',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_RXNORM'
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'RxNorm',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_RXNORM',
	pAppendVocabulary		=> TRUE
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Insert into concept_stage
--3.1. Create table for Precise Ingredients that must change class to Ingredients
DROP TABLE IF EXISTS pi_promotion;
CREATE UNLOGGED TABLE pi_promotion AS
SELECT r1.rxcui2 AS component_rxcui,
	r1.rxcui1 AS pi_rxcui,
	r2.rxcui1 AS i_rxcui
FROM sources.rxnrel r1
JOIN sources.rxnrel r2 ON r2.rxcui2 = r1.rxcui2
	AND r2.rela = 'has_ingredient'
WHERE r1.rela = 'has_precise_ingredient'
	AND
	--All three are active
	NOT EXISTS (
		SELECT 1
		FROM sources.rxnatomarchive arch
		WHERE arch.rxcui IN (
				r1.rxcui2,
				r1.rxcui1,
				r2.rxcui1
				)
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
		);
CREATE INDEX idx_pi_promotion ON pi_promotion (pi_rxcui);
CREATE INDEX idx_complex_promotion ON pi_promotion (component_rxcui,i_rxcui);
ANALYZE pi_promotion;

--3.2. Get drugs, components, forms and ingredients
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
SELECT vocabulary_pack.CutConceptName(rx.str),
	'RxNorm',
	'Drug',
	--Use Ingredient concept class for promoting Precise Ingredients
	CASE 
		WHEN l_pro.pi_rxcui IS NOT NULL
			THEN 'Ingredient'
		ELSE
			--use RxNorm tty as for Concept Classes
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
				END
		END,
	--only Ingredients, drug components, drug forms, drugs and packs are standard concepts
	CASE 
		WHEN l_pro.pi_rxcui IS NOT NULL
			THEN 'S'
		ELSE CASE tty
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
				END
		END,
	--the code used in RxNorm
	rx.rxcui,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm'
		),
	CASE 
		WHEN l_arch.rxcui IS NOT NULL
			THEN (
					SELECT latest_update - 1
					FROM vocabulary
					WHERE vocabulary_id = 'RxNorm'
					)
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date,
	CASE 
		WHEN l_arch.rxcui IS NOT NULL
			THEN 'U'
		ELSE NULL
		END
FROM sources.rxnconso rx
LEFT JOIN LATERAL(SELECT p.pi_rxcui FROM pi_promotion p WHERE p.pi_rxcui = rx.rxcui LIMIT 1) l_pro ON TRUE
LEFT JOIN LATERAL(SELECT arch.rxcui FROM sources.rxnatomarchive arch WHERE arch.rxcui = rx.rxcui
		AND arch.sab = 'RXNORM'
		AND arch.tty IN (
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
		AND arch.rxcui <> arch.merged_to_rxcui LIMIT 1) l_arch ON TRUE
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

--Packs share rxcuis with Clinical Drugs and Branded Drugs, therefore use code as concept_code
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
SELECT vocabulary_pack.CutConceptName(str),
	'RxNorm',
	'Drug',
	--use RxNorm tty as for Concept Classes
	CASE tty
		WHEN 'BPCK'
			THEN 'Branded Pack'
		WHEN 'GPCK'
			THEN 'Clinical Pack'
		END,
	'S',
	--cannot use rxcui here
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

--Add MIN (Multiple Ingredients) as alive concepts [AVOF-3122]
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
SELECT DISTINCT ON (rxcui) vocabulary_pack.CutConceptName(str) AS concept_name,
	'RxNorm' AS vocabulary_id,
	'Drug' AS domain_id,
	'Multiple Ingredients' AS concept_class_id,
	NULL AS standard_concept,
	rxcui AS concept_code,
	TO_TIMESTAMP(created_timestamp, 'mm/dd/yyyy hh:mm:ss pm')::DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.rxnatomarchive
WHERE tty = 'MIN'
	AND sab = 'RXNORM'
ORDER BY rxcui,
	TO_TIMESTAMP(created_timestamp, 'mm/dd/yyyy hh:mm:ss pm');

--4. Add synonyms - for all classes except the packs (they use code as concept_code)
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT rxcui,
	vocabulary_pack.CutConceptSynonymName(rx.str),
	'RxNorm',
	4180186 --English
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

--Add synonyms for packs
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT code,
	vocabulary_pack.CutConceptSynonymName(rx.str),
	'RxNorm',
	4180186 --English
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
SELECT COALESCE(p2.pi_rxcui, s0.rxcui2) AS concept_code_1, --!! The RxNorm source files have the direction the opposite than OMOP
	s0.rxcui1 AS concept_code_2,
	'RxNorm' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	CASE 
		WHEN l_pro.pi_rxcui IS NOT NULL
			THEN 'RxNorm has ing'
		WHEN s0.rela = 'has_precise_ingredient'
			THEN 'Has precise ing'
		WHEN s0.rela = 'has_tradename'
			THEN 'Has tradename'
		WHEN s0.rela = 'has_dose_form'
			THEN 'RxNorm has dose form'
		WHEN s0.rela = 'has_form'
			THEN 'Has form' --links Ingredients to Precise Ingredients
		WHEN s0.rela = 'has_ingredient'
			THEN 'RxNorm has ing'
		WHEN s0.rela = 'constitutes'
			THEN 'Constitutes'
		WHEN s0.rela = 'contains'
			THEN 'Contains'
		WHEN s0.rela = 'reformulated_to'
			THEN 'Reformulated in'
		WHEN s0.rela = 'inverse_isa'
			THEN 'RxNorm inverse is a'
		WHEN s0.rela = 'has_quantified_form'
			THEN 'Has quantified form' --links extended release tablets to 12 HR extended release tablets
		WHEN s0.rela = 'quantified_form_of'
			THEN 'Quantified form of'
		WHEN s0.rela = 'consists_of'
			THEN 'Consists of'
		WHEN s0.rela = 'ingredient_of'
			THEN 'RxNorm ing of'
		WHEN s0.rela = 'precise_ingredient_of'
			THEN 'Precise ing of'
		WHEN s0.rela = 'dose_form_of'
			THEN 'RxNorm dose form of'
		WHEN s0.rela = 'isa'
			THEN 'RxNorm is a'
		WHEN s0.rela = 'contained_in'
			THEN 'Contained in'
		WHEN s0.rela = 'form_of'
			THEN 'Form of'
		WHEN s0.rela = 'reformulation_of'
			THEN 'Reformulation of'
		WHEN s0.rela = 'tradename_of'
			THEN 'Tradename of'
		WHEN s0.rela = 'doseformgroup_of'
			THEN 'Dose form group of'
		WHEN s0.rela = 'has_doseformgroup'
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
	SELECT rxn.rxcui1,
		rxn.rxcui2,
		rxn.rela
	FROM sources.rxnrel rxn
	WHERE rxn.sab = 'RXNORM'
		AND EXISTS (
			SELECT 1
			FROM concept
			WHERE vocabulary_id = 'RxNorm'
				AND concept_code = rxn.rxcui1
			
			UNION ALL
			
			SELECT 1
			FROM concept_stage
			WHERE vocabulary_id = 'RxNorm'
				AND concept_code = rxn.rxcui1
			)
		AND EXISTS (
			SELECT 1
			FROM concept
			WHERE vocabulary_id = 'RxNorm'
				AND concept_code = rxn.rxcui2
			
			UNION ALL
			
			SELECT 1
			FROM concept_stage
			WHERE vocabulary_id = 'RxNorm'
				AND concept_code = rxn.rxcui2
			)
		--Mid-2020 release added seeminggly useless nonsensical relationships between dead and alive concepts that need additional investigation
		--[AVOF-2522]
		AND rxn.rela NOT IN (
			'has_part',
			'has_ingredients',
			'part_of',
			'ingredients_of'
			)
	) AS s0
--Update link to Ingredient where relation is replaced by the precise ingredients
LEFT JOIN pi_promotion p2 ON p2.component_rxcui = s0.rxcui1
	AND s0.rela = 'ingredient_of' /*RxNorm ing of*/
	AND p2.i_rxcui = s0.rxcui2
LEFT JOIN LATERAL(SELECT p.pi_rxcui FROM pi_promotion p WHERE p.pi_rxcui = s0.rxcui1 LIMIT 1) l_pro ON TRUE
--Exclude the old link to ingredient
WHERE NOT EXISTS (
		SELECT 1
		FROM pi_promotion p_int
		WHERE p_int.i_rxcui = s0.rxcui1
			AND p_int.component_rxcui = s0.rxcui2
		)
	--Exclude reverse link for promoted precise ingredients
	AND NOT EXISTS (
		SELECT 1
		FROM pi_promotion p_int2
		WHERE p_int2.pi_rxcui = COALESCE(p2.pi_rxcui, s0.rxcui2)
			AND p_int2.component_rxcui = s0.rxcui1
			AND s0.rela = 'precise_ingredient_of' /*Precise ing of*/
		);

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

--Add missing relationships between Branded Packs and their Brand Names
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
				--The brand names are either listed as tty PSN (prescribing name) or SY (synonym). If they are not listed they don't exist
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
		--apply the slow regexp only to the ones preselected by instr
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
--kick out those duplicates where one is part of antoher brand name (like 'Demulen' in 'Demulen 1/50', or those that cannot be part of each other.
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

--Remove shortcut 'RxNorm has ing' relationship between 'Clinical Drug', 'Quant Clinical Drug', 'Clinical Pack' and 'Ingredient'
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

--and same for reverse
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
--Mapping table between SNOMED to RxNorm. SNOMED is both an intermediary between RxNorm AND DM+D, AND a source code

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
JOIN vocabulary v ON v.vocabulary_id = 'RxNorm' --for getting the latest_update
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
	cr.valid_start_date,
	cr.relationship_id
FROM apigrabber.GetRxNormByStatus('active') api --live grabbing
JOIN concept c ON c.concept_code = api.rxcode
	AND c.invalid_reason = 'U'
	AND c.vocabulary_id = 'RxNorm'
JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
	AND cr.invalid_reason IS NULL
	AND cr.relationship_id = 'Concept replaced by'
JOIN concept c2 ON c2.concept_id = cr.concept_id_2

UNION ALL

--Same situation, the concepts are deprecated, but in the base tables we have them with 'U' [AVOF-1183]
(
	WITH rx AS (
			SELECT c.concept_code AS concept_code_1,
				c2.concept_code AS concept_code_2,
				cr.valid_start_date,
				cr.relationship_id,
				cr.concept_id_1,
				cr.concept_id_2
			FROM concept c
			JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
				AND cr.relationship_id = 'Concept replaced by'
				AND cr.invalid_reason IS NULL
			JOIN concept c2 ON c2.concept_id = cr.concept_id_2
			LEFT JOIN concept_stage cs ON cs.concept_code = c.concept_code
			WHERE EXISTS (
					--there must be at least one record with rxcui = merged_to_rxcui...
					SELECT 1
					FROM sources.rxnatomarchive arch
					WHERE arch.rxcui = arch.merged_to_rxcui
						AND arch.rxcui = c.concept_code
						AND arch.sab = 'RXNORM'
						AND arch.tty IN (
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
					)
				AND NOT EXISTS (
					--...and there should be no records rxcui <> merged_to_rxcui
					SELECT 1
					FROM sources.rxnatomarchive arch
					WHERE arch.rxcui <> arch.merged_to_rxcui
						AND arch.rxcui = c.concept_code
						AND arch.sab = 'RXNORM'
						AND arch.tty IN (
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
					)
				AND c.invalid_reason = 'U'
				AND c.vocabulary_id = 'RxNorm'
				AND c2.vocabulary_id = 'RxNorm'
				AND cs.concept_code IS NULL --missing from concept_stage (rxnconso)
			)
	SELECT rx.concept_code_1,
		rx.concept_code_2,
		rx.valid_start_date,
		rx.relationship_id
	FROM rx
	
	UNION ALL
	--Kill 'Maps to' as well
	SELECT rx.concept_code_1,
		rx.concept_code_2,
		r.valid_start_date,
		r.relationship_id
	FROM rx
	JOIN concept_relationship r ON r.concept_id_1 = rx.concept_id_1
		AND r.concept_id_2 = rx.concept_id_2
		AND r.relationship_id = 'Maps to'
		AND r.invalid_reason IS NULL
	);

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
	AND crs.relationship_id = wr.relationship_id;

--7.3.2 insert new D-replacements
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
	'RxNorm' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	wr.relationship_id,
	wr.valid_start_date,
	(
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm'
		) AS valid_end_date,
	'D' AS invalid_reason
FROM wrong_replacements wr
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = wr.concept_code_1
			AND crs.concept_code_2 = wr.concept_code_2
			AND crs.relationship_id = wr.relationship_id
		);

DROP TABLE wrong_replacements;

--7.3.3 special fix for code=1000589 (RxNorm bug, concept is U but should be alive)
--set concept alive
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	domain_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date
	)
SELECT 'autologous cultured chondrocytes' AS concept_name,
	'RxNorm' AS vocabulary_id,
	'Drug' AS domain_id,
	'Ingredient' AS concept_class_id,
	'S' AS standard_concept,
	'1000589' AS concept_code,
	TO_DATE('20100905', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
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
	valid_end_date
	)
SELECT crs.concept_code_1,
	crs.concept_code_2,
	crs.vocabulary_id_1,
	crs.vocabulary_id_2,
	'Maps to' AS relationship_id,
	crs.valid_start_date,
	crs.valid_end_date
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
WHERE
	--Check if the PI was promoted
	NOT EXISTS (
		SELECT 1
		FROM pi_promotion p_int
		WHERE p_int.pi_rxcui = crs.concept_code_1
			AND p_int.i_rxcui = crs.concept_code_2
		)
	AND crs.relationship_id = 'Form of'
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

--7.6 Make sure we explicitly deprecate old Precise Ingredient to Ingredient relationship, or AddFreshMapsTo grabs them from basic tables
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
SELECT cpi.concept_code AS concept_code_1,
	ci.concept_code AS concept_code_2,
	cpi.vocabulary_id AS vocabulary_id_1,
	ci.vocabulary_id AS vocabulary_id_2,
	r.relationship_id AS relationship_id,
	r.valid_start_date,
	(
		SELECT GREATEST(r.valid_start_date, latest_update - 1) --if we want to kill fresh (valid_start_date=latest_update) rels, then we should use the GREATEST function otherwise we get an error 'valid_end_date < valid_start_date' in generic_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm'
		) AS valid_end_date,
	'D' AS invalid_reason
FROM concept ci
JOIN concept_relationship r ON r.concept_id_2 = ci.concept_id
	AND r.relationship_id = 'Maps to'
	AND r.invalid_reason IS NULL
JOIN concept cpi ON cpi.concept_id = r.concept_id_1
	AND cpi.concept_class_id = 'Precise Ingredient'
WHERE ci.concept_class_id = 'Ingredient'
	AND EXISTS (
		SELECT 1
		FROM pi_promotion p_int
		WHERE p_int.pi_rxcui = cpi.concept_code
			AND p_int.i_rxcui = ci.concept_code
		);

--7.7 Add manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--8. Add 'Maps to' from MIN to Ingredient
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT cs_min.concept_code AS concept_code_1,
	CASE 
		WHEN cs.concept_class_id = 'Ingredient'
			THEN cs.concept_code
		ELSE cs1.concept_code
		END AS concept_code_2,
	'RxNorm' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	cs_min.valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM sources.rxnrel rel
JOIN concept_stage cs_min ON cs_min.concept_code = rel.rxcui2
	AND cs_min.concept_class_id = 'Multiple Ingredients'
JOIN concept_stage cs ON cs.concept_code = rel.rxcui1
	AND cs.concept_class_id IN (
		'Precise Ingredient',
		'Ingredient'
		)
LEFT JOIN concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
	AND crs.vocabulary_id_1 = 'RxNorm'
	AND relationship_id = 'Maps to'
	AND crs.invalid_reason IS NULL
	AND crs.concept_code_1 <> crs.concept_code_2
	AND crs.vocabulary_id_2 = 'RxNorm'
LEFT JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_2
	AND cs1.concept_class_id = 'Ingredient'
WHERE rel.sab = 'RXNORM'
	AND rel.rela = 'has_part';

ANALYZE concept_stage;
ANALYZE concept_relationship_stage;

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

--13. Create mapping to self for fresh concepts
ANALYZE concept_relationship_stage;
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
SELECT concept_code AS concept_code_1,
	concept_code AS concept_code_2,
	c.vocabulary_id AS vocabulary_id_1,
	c.vocabulary_id AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept_stage c,
	vocabulary v
WHERE c.vocabulary_id = v.vocabulary_id
	AND c.standard_concept = 'S'
	AND NOT EXISTS --only new mapping we don't already have
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

--14. Turn "Clinical Drug" to "Quant Clinical Drug" and "Branded Drug" to "Quant Branded Drug"
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

--15. Create pack_content_stage table
INSERT INTO pack_content_stage
SELECT DISTINCT pc.pack_code AS pack_concept_code,
	'RxNorm' AS pack_vocabulary_id,
	cont.concept_code AS drug_concept_code,
	'RxNorm' AS drug_vocabulary_id,
	pc.amount::INT2, --of drug units in the pack
	NULL::INT2 AS box_size --number of the overall combinations units
FROM (
	SELECT pack_code,
		--Parse the number at the beginning of each drug string as the amount
		SUBSTRING(pack_name, '^[0-9]+') AS amount,
		--Parse the number in parentheses on the second position of the drug string as the quantity factor of a quantified drug (usually not listed in the concept table), not used right now
		TRANSLATE(SUBSTRING(pack_name, '\([0-9]+ [A-Za-z]+\)'), 'a()', 'a') AS quant,
		--Don't parse the drug name, because it will be found through instr() with the known name of the component (see below)
		pack_name AS drug
	FROM (
		SELECT DISTINCT pack_code,
			--This is the sequence to split the concept_name of the packs by the semicolon, which replaces the parentheses plus slash (see below)
			TRIM(UNNEST(regexp_matches(pack_name, '[^;]+', 'g'))) AS pack_name
		FROM (
			--This takes a Pack name, replaces the sequence ') / ' with a semicolon for splitting, and removes the word Pack and everything thereafter (the brand name usually)
			SELECT rxcui AS pack_code,
				REGEXP_REPLACE(REPLACE(REPLACE(str, ') / ', ';'), '{', ''), '\) } Pack( \[.+\])?', '','g') AS pack_name
			FROM sources.rxnconso
			WHERE sab = 'RXNORM'
				AND tty LIKE '%PCK' --Clinical (=Generic) or Branded Pack
			) AS s0
		) AS s1
	) AS pc
--match by name with the component drug obtained through the 'Contains' relationship
JOIN (
	SELECT concept_code_1,
		concept_code_2,
		concept_code,
		concept_name
	FROM concept_relationship_stage r
	JOIN concept_stage ON concept_code = r.concept_code_2
	WHERE r.relationship_id = 'Contains'
		AND r.invalid_reason IS NULL
	) cont ON cont.concept_code_1 = pc.pack_code
	AND pc.drug LIKE '%' || cont.concept_name || '%'; --this is where the component name is fit into the parsed drug name from the Pack string

--16. Create RxNorm's concept code ancestor
DROP TABLE IF EXISTS rxnorm_ancestor;
CREATE UNLOGGED TABLE rxnorm_ancestor AS
WITH RECURSIVE hierarchy_concepts(ancestor_concept_code, ancestor_vocabulary_id, descendant_concept_code, descendant_vocabulary_id, root_ancestor_concept_code, root_ancestor_vocabulary_id, full_path) AS (
	SELECT ancestor_concept_code,
		ancestor_vocabulary_id,
		descendant_concept_code,
		descendant_vocabulary_id,
		ancestor_concept_code AS root_ancestor_concept_code,
		ancestor_vocabulary_id AS root_ancestor_vocabulary_id,
		ARRAY [ROW (descendant_concept_code, descendant_vocabulary_id)] AS full_path
	FROM concepts
		
	UNION ALL
		
	SELECT c.ancestor_concept_code,
		c.ancestor_vocabulary_id,
		c.descendant_concept_code,
		c.descendant_vocabulary_id,
		root_ancestor_concept_code,
		root_ancestor_vocabulary_id,
		hc.full_path || ROW(c.descendant_concept_code, c.descendant_vocabulary_id) AS full_path
	FROM concepts c
	JOIN hierarchy_concepts hc ON hc.descendant_concept_code = c.ancestor_concept_code
		AND hc.descendant_vocabulary_id = c.ancestor_vocabulary_id
	WHERE ROW(c.descendant_concept_code, c.descendant_vocabulary_id) <> ALL (full_path)
	),
concepts AS (
		SELECT crs.concept_code_1 AS ancestor_concept_code,
			crs.vocabulary_id_1 AS ancestor_vocabulary_id,
			crs.concept_code_2 AS descendant_concept_code,
			crs.vocabulary_id_2 AS descendant_vocabulary_id
		FROM concept_relationship_stage crs
		JOIN relationship s ON s.relationship_id = crs.relationship_id
			AND s.defines_ancestry = 1
		JOIN concept_stage c1 ON c1.concept_code = crs.concept_code_1
			AND c1.vocabulary_id = crs.vocabulary_id_1
			AND c1.invalid_reason IS NULL
			AND c1.vocabulary_id = 'RxNorm'
		JOIN concept_stage c2 ON c2.concept_code = crs.concept_code_2
			AND c1.vocabulary_id = crs.vocabulary_id_2
			AND c2.invalid_reason IS NULL
			AND c2.vocabulary_id = 'RxNorm'
		WHERE crs.invalid_reason IS NULL
		)
SELECT DISTINCT hc.root_ancestor_concept_code AS ancestor_concept_code,
	hc.root_ancestor_vocabulary_id AS ancestor_vocabulary_id,
	hc.descendant_concept_code,
	hc.descendant_vocabulary_id
FROM hierarchy_concepts hc
JOIN concept_stage cs1 ON cs1.concept_code = hc.root_ancestor_concept_code
	AND cs1.standard_concept IS NOT NULL
JOIN concept_stage cs2 ON cs2.concept_code = hc.descendant_concept_code
	AND cs2.standard_concept IS NOT NULL

UNION ALL

SELECT cs.concept_code,
	cs.vocabulary_id,
	cs.concept_code,
	cs.vocabulary_id
FROM concept_stage cs
WHERE cs.vocabulary_id = 'RxNorm'
	AND cs.invalid_reason IS NULL
	AND cs.standard_concept IS NOT NULL;

CREATE INDEX idx_descendant_rxancestor ON rxnorm_ancestor (descendant_concept_code);
ANALYZE rxnorm_ancestor;

--17. Prepare list of concepts stemming from new precise ingredients and thus missing proper CDF as parent:
DROP TABLE IF EXISTS precise_affected;
CREATE UNLOGGED TABLE precise_affected as
SELECT s.concept_code AS drug_concept_code,
	cdf.concept_code AS outdated_form_code
FROM concept_stage s
JOIN rxnorm_ancestor ca1 ON ca1.descendant_concept_code = s.concept_code
	AND ca1.descendant_vocabulary_id = s.vocabulary_id
JOIN concept_stage cdf ON cdf.concept_code = ca1.ancestor_concept_code
	AND cdf.vocabulary_id = ca1.ancestor_vocabulary_id
	AND cdf.concept_class_id IN (
		'Clinical Drug Form',
		'Branded Drug Form'
		)
WHERE s.concept_class_id <> 'Branded Drug Form' --Separate case
	AND EXISTS (
		SELECT 1
		FROM rxnorm_ancestor ca_int
		JOIN pi_promotion p_int ON p_int.component_rxcui = ca_int.ancestor_concept_code
		WHERE ca_int.descendant_concept_code = s.concept_code
		);

--18. Create list of true new ingredients for these concepts
DROP TABLE IF EXISTS cdf_portrait;
CREATE UNLOGGED TABLE cdf_portrait AS
--ONLY CDF
SELECT s2.drug_concept_code,
	s2.outdated_form_code,
	s2.df_concept_code,
	s2.ingredient_string,
	'OMOP' || s2.new_cdf_code AS new_cdf_code,
	MAX(s2.new_cdf_code) OVER () AS max_cdf_code --this field is required for the code below (to continue the OMOP sequence)
FROM (
	SELECT s1.drug_concept_code,
		s1.outdated_form_code,
		s1.df_concept_code,
		s1.ingredient_string,
		DENSE_RANK() OVER (
			ORDER BY s1.df_concept_code,
				s1.ingredient_string
			) + l.max_omop_concept_code AS new_cdf_code
	FROM (
		SELECT s0.drug_concept_code,
			s0.outdated_form_code,
			s0.df_concept_code,
			ARRAY_AGG(s0.true_ingredient_code) AS ingredient_string
		FROM (
			SELECT DISTINCT ON (
					a.drug_concept_code,
					a.outdated_form_code,
					f.concept_code,
					s.concept_code
					) a.drug_concept_code,
				a.outdated_form_code,
				f.concept_code AS df_concept_code,
				COALESCE(i.pi_rxcui, s.concept_code) AS true_ingredient_code
			FROM precise_affected a
			JOIN concept_stage x ON x.concept_code = a.outdated_form_code
				AND x.concept_class_id = 'Clinical Drug Form'
			--Original ingredient related to the form
			JOIN concept_relationship_stage ri ON ri.concept_code_1 = a.outdated_form_code
				AND ri.vocabulary_id_1 = 'RxNorm'
				AND ri.invalid_reason IS NULL
			JOIN concept_stage s ON s.concept_code = ri.concept_code_2
				AND s.concept_class_id = 'Ingredient'
			--Cross-reference PI promotion to replace old ingredients with new
			JOIN rxnorm_ancestor ra ON ra.descendant_concept_code = a.drug_concept_code
			LEFT JOIN pi_promotion i ON i.i_rxcui = s.concept_code
				AND ra.ancestor_concept_code = i.component_rxcui
			--Add Dose Form
			JOIN concept_relationship_stage rf ON rf.concept_code_1 = a.outdated_form_code
				AND rf.vocabulary_id_1 = 'RxNorm'
				AND rf.invalid_reason IS NULL
			JOIN concept_stage f ON f.concept_code = rf.concept_code_2
				AND f.vocabulary_id = rf.vocabulary_id_2
				AND f.concept_class_id = 'Dose Form'
			ORDER BY a.drug_concept_code,
				a.outdated_form_code,
				f.concept_code,
				s.concept_code,
				i.pi_rxcui
			) s0
		GROUP BY s0.drug_concept_code,
			s0.outdated_form_code,
			s0.df_concept_code
		) s1
	CROSS JOIN LATERAL(SELECT MAX(REPLACE(concept_code, 'OMOP', '')::INT4) AS max_omop_concept_code FROM concept WHERE concept_code LIKE 'OMOP%'
			AND concept_code NOT LIKE '% %' --Last valid value of the OMOP123-type codes
		) l
	) s2;

--19. Create portrait of missing BDFs
DROP TABLE IF EXISTS bdf_portrait;
CREATE UNLOGGED TABLE bdf_portrait as
SELECT pa.drug_concept_code,
	pa.outdated_form_code,
	cp.new_cdf_code,
	crs.concept_code_2 AS bn_code,
	'OMOP' || DENSE_RANK() OVER (
		ORDER BY pa.outdated_form_code,
			cp.new_cdf_code,
			crs.concept_code_2
		) + cp.max_cdf_code AS new_bdf_code
FROM precise_affected pa
JOIN concept_stage bdf ON bdf.concept_code = pa.outdated_form_code
	AND bdf.concept_class_id = 'Branded Drug Form'
JOIN rxnorm_ancestor ra ON ra.descendant_concept_code = pa.drug_concept_code
--CDF are always part of the equation:
JOIN cdf_portrait cp ON cp.drug_concept_code = pa.drug_concept_code
	AND cp.outdated_form_code = ra.ancestor_concept_code
--Get Brand Name
JOIN concept_relationship_stage crs ON crs.concept_code_1 = pa.outdated_form_code
	AND crs.vocabulary_id_1 = 'RxNorm'
	AND crs.relationship_id = 'Has brand name'
	AND crs.vocabulary_id_2 = 'RxNorm'
	AND crs.invalid_reason IS NULL
WHERE
	--Assert existence of direct link, not just shared ancestry
	EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = pa.outdated_form_code
			AND crs_int.vocabulary_id_1 = 'RxNorm'
			AND crs_int.concept_code_2 = cp.outdated_form_code
			AND crs_int.vocabulary_id_2 = 'RxNorm'
			AND crs_int.invalid_reason IS NULL
		);

--20. Generate NEW relations for synthetic DF: to Ingredients, Forms and Brand Names
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
--CDF to Ingredients (reversed for FillDrugStrength)
SELECT DISTINCT UNNEST(cp.ingredient_string) AS concept_code_1,
	cp.new_cdf_code AS concept_code_2,
	'RxNorm' AS vocabulary_id_1,
	'RxNorm Extension' AS vocabulary_id_2,
	'RxNorm ing of' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM cdf_portrait cp

UNION ALL

--CDF to Dose Form
SELECT DISTINCT cp.new_cdf_code AS concept_code_1,
	cp.df_concept_code AS concept_code_2,
	'RxNorm Extension' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'RxNorm has dose form' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM cdf_portrait cp

UNION ALL

--BDF to Brand Name
SELECT DISTINCT dp.new_bdf_code AS concept_code_1,
	dp.bn_code AS concept_code_2,
	'RxNorm Extension' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'Has brand name' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm'
		) AS valid_start_date,
	to_date('20991231', 'yyyymmdd') AS valid_end_date
FROM bdf_portrait dp

UNION ALL

--BDF to CDF (this direction for FillDrugStrength)
SELECT DISTINCT dp.new_bdf_code AS concept_code_1,
	dp.new_cdf_code AS concept_code_2,
	'RxNorm Extension' AS vocabulary_id_1,
	'RxNorm Extension' AS vocabulary_id_2,
	'Tradename of' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm'
		) AS valid_start_date,
	to_date('20991231', 'yyyymmdd') AS valid_end_date
FROM bdf_portrait dp;


--21. Replace relations for affected concepts
WITH replacement
AS (
	SELECT drug_concept_code,
		outdated_form_code,
		new_cdf_code AS new_code
	FROM cdf_portrait
	
	UNION ALL
	
	SELECT drug_concept_code,
		outdated_form_code,
		new_bdf_code
	FROM bdf_portrait
	),
downward_facing_update
AS (
	UPDATE concept_relationship_stage crs
	SET concept_code_2 = e.new_code,
		vocabulary_id_2 = 'RxNorm Extension'
	FROM replacement e
	WHERE crs.concept_code_1 = e.drug_concept_code
		AND crs.vocabulary_id_1 = 'RxNorm'
		AND crs.concept_code_2 = e.outdated_form_code
		AND crs.vocabulary_id_2 = 'RxNorm'
		AND crs.invalid_reason IS NULL
	)
--Upward facing update
UPDATE concept_relationship_stage crs
SET concept_code_2 = e.new_code,
	vocabulary_id_2 = 'RxNorm Extension'
FROM replacement e
WHERE crs.concept_code_1 = e.drug_concept_code
	AND crs.vocabulary_id_1 = 'RxNorm'
	AND crs.concept_code_2 = e.outdated_form_code
	AND crs.vocabulary_id_2 = 'RxNorm'
	AND crs.invalid_reason IS NULL;

--22. Concept stage entries
WITH cdf_to_ingstr
AS (
	SELECT DISTINCT new_cdf_code,
		df_concept_code,
		ingredient_string
	FROM cdf_portrait
	),
cdf_to_ing
AS (
	SELECT new_cdf_code,
		unnest(ingredient_string) AS ing_code
	FROM cdf_to_ingstr
	),
cdf_spelled_out
AS (
	SELECT cti.new_cdf_code,
		string_agg(si.concept_name, ' / ' ORDER BY UPPER(si.concept_name) COLLATE "C") || ' ' || sf.concept_name AS new_name
	FROM cdf_to_ing cti
	JOIN cdf_to_ingstr c ON c.new_cdf_code = cti.new_cdf_code
	JOIN concept_stage si ON si.concept_code = cti.ing_code
	JOIN concept_stage sf ON sf.concept_code = c.df_concept_code
	GROUP BY cti.new_cdf_code,
		sf.concept_name
	),
bdf_spelled_out
AS (
	SELECT DISTINCT b.new_bdf_code,
		i.new_name || ' [' || cb.concept_name || ']' AS new_name
	FROM cdf_spelled_out i
	JOIN bdf_portrait b ON b.new_cdf_code = i.new_cdf_code
	JOIN concept_stage cb ON cb.concept_code = b.bn_code
	)
INSERT INTO concept_stage (
	concept_code,
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	valid_start_date,
	valid_end_date
	)
SELECT cdf.new_cdf_code AS concept_code,
	vocabulary_pack.CutConceptName(cdf.new_name) AS concept_name,
	'Drug' AS domain_id,
	'RxNorm Extension' AS vocabulary_id,
	'Clinical Drug Form' AS concept_class_id,
	'S' AS standard_concept,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM cdf_spelled_out cdf

UNION ALL

SELECT bdf.new_bdf_code AS concept_code,
	vocabulary_pack.CutConceptName(bdf.new_name) AS concept_name,
	'Drug' AS domain_id,
	'RxNorm Extension' AS vocabulary_id,
	'Branded Drug Form' AS concept_class_id,
	'S' AS standard_concept,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM bdf_spelled_out bdf;

--23. Run FillDrugStrengthStage
DO $_$
BEGIN
	PERFORM dev_rxnorm.FillDrugStrengthStage();
END $_$;

--24. Run QA-script (you can always re-run this QA manually: SELECT * FROM get_qa_rxnorm() ORDER BY info_level, description;)
DO $_$
BEGIN
	IF CURRENT_SCHEMA = 'dev_rxnorm' /*run only if we are inside dev_rxnorm*/ THEN
		ANALYZE concept_stage;
		ANALYZE concept_relationship_stage;
		ANALYZE drug_strength_stage;
		TRUNCATE TABLE rxn_info_sheet;
		INSERT INTO rxn_info_sheet SELECT * FROM get_qa_rxnorm();
	END IF;
END $_$;

--25. Cleanup
DROP TABLE pi_promotion;
DROP TABLE precise_affected;
DROP TABLE cdf_portrait;
DROP TABLE bdf_portrait;

--26. We need to run generic_update before small RxE clean up
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;

--27. Run RxE clean up
DO $_$
BEGIN
	PERFORM vocabulary_pack.RxECleanUP();
END $_$;

--At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script