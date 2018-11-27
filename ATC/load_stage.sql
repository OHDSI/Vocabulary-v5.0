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
* Authors: Anna Ostropolets, Timur Vakhitov
* Date: 2018
**************************************************************************/

-- 1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ATC',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_ATC'
);
END $_$;

-- 2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Add ATC
--create temporary table atc_tmp_table
DROP TABLE IF EXISTS atc_tmp_table;
CREATE UNLOGGED TABLE atc_tmp_table AS
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

CREATE INDEX idx_atc_code ON atc_tmp_table (code);
CREATE INDEX idx_atc_ccode ON atc_tmp_table (concept_code);
ANALYZE atc_tmp_table;

--4. Add atc_tmp_table to concept_stage
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
FROM atc_tmp_table dv,
	vocabulary v
WHERE v.vocabulary_id = dv.vocabulary_id;

--5. Create all sorts of relationships to self, RxNorm and SNOMED
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
SELECT DISTINCT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'VA Class to ATC eq' AS relationship_id,
	'VA Class' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM atc_tmp_table d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN atc_tmp_table e ON r.rxcui = e.rxcui
	AND r.code = e.concept_code
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
WHERE d.concept_class_id LIKE 'VA Class'
	AND e.concept_class_id LIKE 'ATC%'

UNION ALL

-- Cross-link between drug class Chemical Structure AND ATC
SELECT DISTINCT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'NDFRT to ATC eq' AS relationship_id,
	'NDFRT' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM atc_tmp_table d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN atc_tmp_table e ON r.rxcui = e.rxcui
	AND r.code = e.concept_code
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
WHERE d.concept_class_id = 'Chemical Structure'
	AND e.concept_class_id IN (
		'ATC 1st',
		'ATC 2nd',
		'ATC 3rd',
		'ATC 4th'
		)

UNION ALL

-- Cross-link between drug class ATC AND Therapeutic Class
SELECT DISTINCT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'NDFRT to ATC eq' AS relationship_id,
	'NDFRT' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM atc_tmp_table d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN atc_tmp_table e ON r.rxcui = e.rxcui
	AND r.code = e.concept_code
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
WHERE d.concept_class_id LIKE 'Therapeutic Class'
	AND e.concept_class_id LIKE 'ATC%'

UNION ALL

-- Cross-link between drug class SNOMED AND ATC classes (not ATC 5th)
SELECT DISTINCT d.concept_code AS concept_code_1,
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
JOIN atc_tmp_table e ON r2.code = e.concept_code
	AND e.concept_class_id != 'ATC 5th' -- Ingredients only to RxNorm
WHERE d.vocabulary_id = 'SNOMED'
	AND d.invalid_reason IS NULL

UNION ALL

-- add ATC to RxNorm
SELECT DISTINCT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'ATC - RxNorm' AS relationship_id, -- this is one to substitute "NDFRF has ing", is hierarchical AND defines ancestry.
	'ATC' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM atc_tmp_table d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
JOIN concept e ON r.rxcui = e.concept_code
	AND e.vocabulary_id = 'RxNorm'
	AND e.invalid_reason IS NULL
WHERE d.vocabulary_id = 'ATC'
	AND d.concept_class_id = 'ATC 5th' -- there are some weird 4th level links, LIKE D11AC 'Medicated shampoos' to an RxNorm Dose Form
        AND e.concept_class_id not in ('Ingredient','Precise Ingredient')
UNION ALL

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

--6. Add new relationships
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
SELECT DISTINCT f.atc_code AS concept_code_1,
	f.concept_code AS concept_code_2,
	'ATC' AS vocabulary_id_1,
	c.vocabulary_id AS vocabulary_id_2,
	'ATC - RxNorm' AS relationship_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM dev_atc.final_assembly f --manual source table
JOIN concept c ON c.concept_id = f.concept_id
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = f.atc_code
			AND crs.vocabulary_id_1 = 'ATC'
			AND crs.concept_code_2 = c.concept_code
			AND crs.vocabulary_id_2 = c.vocabulary_id
			AND crs.relationship_id = 'ATC - RxNorm'
		);

--7. Add relationships to ingredients excluding multiple-ingredient combos
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
SELECT DISTINCT f.atc_code AS concept_code_1,
	c.concept_code AS concept_code_2,
	'ATC' AS vocabulary_id_1,
	c.vocabulary_id AS vocabulary_id_2,
	'ATC - RxNorm' AS relationship_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM dev_atc.final_assembly f
JOIN devv5.concept_ancestor ca ON ca.descendant_concept_id = f.concept_id
JOIN concept c ON c.concept_id = ca.ancestor_concept_id
	AND c.concept_class_id = 'Ingredient'
	AND c.vocabulary_id LIKE 'RxNorm%'
WHERE NOT f.atc_name ~ 'combination|agents|drugs|supplements|corticosteroids|compounds|sulfonylureas|preparations|thiazides|antacid|antiinfectives|calcium$|potassium$|sodium$|antiseptics|antibiotics|mydriatics|psycholeptic|other|diuretic|nitrates|analgesics'
	AND c.concept_name NOT IN ('Inert Ingredients') -- a component of contraceptive packs
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = f.atc_code
			AND crs.vocabulary_id_1 = 'ATC'
			AND crs.concept_code_2 = c.concept_code
			AND crs.vocabulary_id_2 = c.vocabulary_id
			AND crs.relationship_id = 'ATC - RxNorm'
		);

--8. Add relationships to ingredients for combo drugs where possible
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
SELECT atc.atc_code AS concept_code_1,
	atc.concept_code AS concept_code_2,
	'ATC' AS vocabulary_id_1,
	atc.vocabulary_id AS vocabulary_id_2,
	'ATC - RxNorm' AS relationship_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT d.atc_code,
		c.concept_code,
		c.vocabulary_id
	FROM dev_atc.dev_combo_stage d
	JOIN dev_atc.relationship_to_concept rtc ON rtc.concept_code_1 = d.ing
	JOIN concept c ON rtc.concept_id_2 = c.concept_id
	WHERE d.flag = 'ing'
		AND NOT EXISTS (
			SELECT 1
			FROM dev_atc.dev_combo_stage d2
			WHERE d.atc_code = d2.atc_code
				AND d.ing = d2.ing
				AND rtc.precedence > 1
			)
	
	UNION
	
	SELECT a.atc_code,
		c.concept_code,
		c.vocabulary_id
	FROM dev_atc.atc_1_comb a
	LEFT JOIN dev_atc.reference r ON a.atc_code = r.atc_code
	JOIN dev_atc.internal_relationship_stage i ON coalesce(concept_code, a.atc_code) = i.concept_code_1
	JOIN dev_atc.drug_concept_stage d ON d.concept_code = i.concept_code_2
		AND d.concept_class_id = 'Ingredient'
	JOIN dev_atc.relationship_to_concept rtc ON rtc.concept_code_1 = d.concept_code
	JOIN concept c ON rtc.concept_id_2 = c.concept_id
	WHERE a.atc_name ~ 'comb| and '
		AND NOT EXISTS (
			SELECT 1
			FROM dev_atc.relationship_to_concept rtc2
			WHERE rtc.concept_code_1 = rtc2.concept_code_1
				AND rtc2.precedence > 1
			)
	) atc
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = atc.atc_code
			AND crs.vocabulary_id_1 = 'ATC'
			AND crs.concept_code_2 = atc.concept_code
			AND crs.vocabulary_id_2 = atc.vocabulary_id
			AND crs.relationship_id = 'ATC - RxNorm'
		);

--9. Add manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--10. Remove ATC's duplicates (AVOF-322)
--diphtheria immunoglobulin
DELETE FROM concept_relationship_stage WHERE concept_code_1 = 'J06BB10' AND concept_code_2 = '3510' AND relationship_id = 'ATC - RxNorm';
--hydroquinine
DELETE FROM concept_relationship_stage WHERE concept_code_1 = 'M09AA01' AND concept_code_2 = '27220' AND relationship_id = 'ATC - RxNorm';

--11. Deprecate relationships between multi ingredient drugs and a single ATC 5th, because it should have either an ATC for each ingredient or an ATC that is a combination of them
--11.1. Create temporary table drug_strength_ext (same code as in concept_ancestor, but we exclude ds for ingredients (because we use count(*)>1 and ds for ingredients having count(*)=1) and only for RxNorm)
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
	JOIN devv5.concept_ancestor ca ON ca.ancestor_concept_id = an.concept_id
	JOIN concept de ON de.concept_id = ca.descendant_concept_id
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

--11.2. Do deprecation
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

--12. Add synonyms to concept_synonym stage for each of the rxcui/code combinations in atc_tmp_table
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT dv.concept_code AS synonym_concept_code,
	SUBSTR(r.str, 1, 1000) AS synonym_name,
	dv.vocabulary_id AS synonym_vocabulary_id,
	4180186 AS language_concept_id
FROM atc_tmp_table dv
JOIN sources.rxnconso r ON dv.code = r.code
	AND dv.rxcui = r.rxcui
	AND r.code != 'NOCODE'
	AND r.lat = 'ENG';

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

--17. Delete mappings between concepts that are not represented at the "latest_update" at this moment (e.g. SNOMED <-> RxNorm, but currently we are updating ATC)
--This is because we have SNOMED <-> ATC in concept_relationship_stage, but AddFreshMAPSTO adds SNOMED <-> RxNorm from concept_relationship
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

--18. Clean up
DROP TABLE atc_tmp_table;
DROP TABLE drug_strength_ext;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
