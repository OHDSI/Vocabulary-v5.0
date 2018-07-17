--1. Working with ds_stage

--deleting drug forms
DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE source_concept_class_id LIKE '% Form'
		);

--need to think about it
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT c2.concept_code
		FROM concept c
		JOIN drug_strength ON drug_concept_id = c.concept_id
			AND (
				c.concept_name LIKE '%Tablet%'
				OR c.concept_name LIKE '%Capsule%'
				OR c.concept_name LIKE '%Lozenge%'
				OR c.concept_name LIKE '%Pellet%'
				)
			AND c.concept_name NOT LIKE '%Solution%' -- solid forms defined by their forms 
		JOIN concept_ancestor ca ON ca.descendant_concept_id = c.concept_id
		JOIN concept c2 ON c2.concept_id = ca.ancestor_concept_id
			AND c2.vocabulary_id = 'RxNorm Extension'
			AND c2.concept_class_id != 'Ingredient'
			AND (
				c2.concept_class_id NOT LIKE 'Quant%'
				AND (
					c2.concept_class_id NOT LIKE 'Marketed%'
					AND NOT c2.concept_name ~ '^\d+'
					)
				AND c2.concept_class_id NOT LIKE '%Form%'
				)
			AND numerator_value IS NOT NULL
			AND denominator_unit_concept_id != 8505
			AND (
				c.concept_class_id LIKE 'Quant%'
				OR (
					c.concept_class_id LIKE 'Marketed%'
					AND c.concept_name ~ '^\d+'
					)
				)
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT c2.concept_code
		FROM concept c
		JOIN drug_strength ON drug_concept_id = c.concept_id
			AND (
				c.concept_name LIKE '%Tablet%'
				OR c.concept_name LIKE '%Capsule%'
				OR c.concept_name LIKE '%Lozenge%'
				OR c.concept_name LIKE '%Pellet%'
				)
			AND c.concept_name NOT LIKE '%Solution%' -- solid forms defined by their forms 
		JOIN concept_ancestor ca ON ca.descendant_concept_id = c.concept_id
		JOIN concept c2 ON c2.concept_id = ca.ancestor_concept_id
			AND c2.vocabulary_id = 'RxNorm Extension'
			AND c2.concept_class_id != 'Ingredient'
			AND (
				c2.concept_class_id NOT LIKE 'Quant%'
				AND (
					c2.concept_class_id NOT LIKE 'Marketed%'
					AND NOT c2.concept_name ~ '^\d+'
					)
				AND c2.concept_class_id NOT LIKE '%Form%'
				)
			AND numerator_value IS NOT NULL
			AND denominator_unit_concept_id != 8505
			AND (
				c.concept_class_id LIKE 'Quant%'
				OR (
					c.concept_class_id LIKE 'Marketed%'
					AND c.concept_name ~ '^\d+'
					)
				)
		);

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT c2.concept_code
		FROM concept c
		JOIN drug_strength ON drug_concept_id = c.concept_id
			AND (
				c.concept_name LIKE '%Tablet%'
				OR c.concept_name LIKE '%Capsule%'
				OR c.concept_name LIKE '%Lozenge%'
				OR c.concept_name LIKE '%Pellet%'
				)
			AND c.concept_name NOT LIKE '%Solution%' -- solid forms defined by their forms 
		JOIN concept_ancestor ca ON ca.descendant_concept_id = c.concept_id
		JOIN concept c2 ON c2.concept_id = ca.ancestor_concept_id
			AND c2.vocabulary_id = 'RxNorm Extension'
			AND c2.concept_class_id != 'Ingredient'
			AND (
				c2.concept_class_id NOT LIKE 'Quant%'
				AND (
					c2.concept_class_id NOT LIKE 'Marketed%'
					AND NOT c2.concept_name ~ '^\d+'
					)
				AND c2.concept_class_id NOT LIKE '%Form%'
				)
			AND numerator_value IS NOT NULL
			AND denominator_unit_concept_id != 8505
			AND (
				c.concept_class_id LIKE 'Quant%'
				OR (
					c.concept_class_id LIKE 'Marketed%'
					AND c.concept_name ~ '^\d+'
					)
				)
		);

UPDATE ds_stage
SET amount_value = numerator_value * COALESCE(denominator_value, 1),
	amount_unit = numerator_unit,
	numerator_value = NULL,
	numerator_unit = NULL,
	denominator_value = NULL,
	denominator_unit = NULL
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM concept
		JOIN drug_strength ON drug_concept_id = concept_id
			AND (
				concept_name LIKE '%Tablet%'
				OR concept_name LIKE '%Capsule%'
				OR concept_name LIKE '%Lozenge%'
				OR concept_name LIKE '%Pellet%'
				) -- solid forms defined by their forms 
			AND numerator_value IS NOT NULL
			AND denominator_unit_concept_id != 8505
		);

--gases
UPDATE ds_stage
SET numerator_value = '100',
	numerator_unit = '%',
	denominator_unit = amount_unit,
	denominator_value = amount_value
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM concept
		JOIN drug_strength ON drug_concept_id = concept_id
		WHERE amount_unit_concept_id = 8587
			AND concept_name LIKE '% Gas for Inhalation%'
			AND concept_class_id NOT LIKE '%Form%'
		);

UPDATE ds_stage
SET numerator_value = 100,
	numerator_unit = '%',
	denominator_unit = amount_unit,
	denominator_value = amount_value
WHERE drug_concept_code IN (
		SELECT c2.concept_code
		FROM concept c
		JOIN drug_strength ON drug_concept_id = c.concept_id
		JOIN concept_ancestor a ON c.concept_id = descendant_concept_id
		JOIN concept c2 ON c2.concept_id = ancestor_concept_id
			AND c2.vocabulary_id = 'RxNorm Extension'
			AND c2.concept_class_id LIKE '%Comp%'
		WHERE amount_unit_concept_id = 8587
			AND c.concept_name LIKE '% Gas for Inhalation%'
			AND c.concept_class_id NOT LIKE '%Form%'
		);

UPDATE ds_stage
SET numerator_value = numerator_value * 100,
	numerator_unit = '%'
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM concept
		JOIN drug_strength ON drug_concept_id = concept_id
		WHERE numerator_unit_concept_id = 8587
			AND concept_name LIKE '% Gas for Inhalation%'
			AND concept_class_id LIKE '%Form%'
		);

--2. Working with internal_relationship_stage

--additional suppl work
DROP TABLE IF EXISTS irs_suppl;
CREATE TABLE irs_suppl AS
SELECT irs.concept_code_1,
	CASE 
		WHEN s.concept_code_2 IS NOT NULL
			THEN s.concept_code_2
		ELSE irs.concept_code_2
		END AS concept_code_2
FROM internal_relationship_stage irs
LEFT JOIN suppliers_to_repl s ON s.concept_code_1 = irs.concept_code_2;

TRUNCATE TABLE internal_relationship_stage;
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT concept_code_1,
	concept_code_2
FROM irs_suppl;

--also need to delete all the unecessary suppliers
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT concept_code_1
		FROM suppliers_to_repl
		);

DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
		SELECT concept_code_1
		FROM suppliers_to_repl
		);

--BRAND NAMES
--brand names that need to be deleted
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT concept_code
		FROM eduard_bn_to_delete
		JOIN concept using (concept_id)
		);

DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
		SELECT concept_code
		FROM eduard_bn_to_delete
		JOIN concept using (concept_id)
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (
		SELECT concept_code
		FROM eduard_bn_to_delete
		JOIN concept using (concept_id)
		);

DROP TABLE IF EXISTS bn_to_repl;
CREATE TABLE bn_to_repl AS
SELECT c.concept_code AS concept_code_1,
	c.concept_name AS concept_name_1,
	c2.concept_code AS concept_code_2,
	c2.concept_name AS concept_name_2
FROM eduard_brand_replace e
JOIN concept c ON c.concept_id = e.concept_id
JOIN concept c2 ON c2.concept_id = replacement_id;


DROP TABLE IF EXISTS irs_BN;
CREATE TABLE irs_BN AS
SELECT irs.concept_code_1,
	CASE 
		WHEN b.concept_code_2 IS NOT NULL
			THEN b.concept_code_2
		ELSE irs.concept_code_2
		END AS concept_code_2
FROM internal_relationship_stage irs
LEFT JOIN bn_to_repl b ON b.concept_code_1 = irs.concept_code_2;

TRUNCATE TABLE internal_relationship_stage;
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT concept_code_1,
	concept_code_2
FROM irs_BN;

--also need to delete all the unecessary BN
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT concept_code_1
		FROM bn_to_repl
		);

DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
		SELECT concept_code_1
		FROM bn_to_repl
		);

--change BN names
UPDATE drug_concept_stage d
SET concept_name = c.concept_name_2
FROM (
	SELECT concept_name_2,
		concept_code
	FROM eduard_bn_names
	JOIN concept using (concept_id)
	) c
WHERE d.concept_code = c.concept_code;

UPDATE relationship_to_concept
SET concept_id_2 = 45776076
WHERE concept_code_1 = 'OMOP999029'
	AND precedence = '1';--Influenza A virus vaccine, A-Texas-50-2012 (H3N2)-like virus

UPDATE relationship_to_concept
SET concept_id_2 = 920458
WHERE concept_code_1 = 'OMOP1131481'
	AND precedence = 1;--Betamethasone (Betamethasone 21-Disodium Phosphate)

--close dosage drugs
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT c2.concept_code
		FROM dev_amt.amt_2 a
		JOIN concept c ON c.concept_code = a.concept_code_1
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND relationship_id IN (
				'Maps to',
				'Source - RxNorm eq'
				)
			AND cr.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT c2.concept_code
		FROM dev_amt.amt_2 a
		JOIN concept c ON c.concept_code = a.concept_code_1
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND relationship_id IN (
				'Maps to',
				'Source - RxNorm eq'
				)
			AND cr.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		);

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT c2.concept_code
		FROM dev_amt.amt_2 a
		JOIN concept c ON c.concept_code = a.concept_code_1
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND relationship_id IN (
				'Maps to',
				'Source - RxNorm eq'
				)
			AND cr.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		);

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT c2.concept_code
		FROM dev_dmd.dmd_2 a
		JOIN concept c ON c.concept_code = a.concept_code_1
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND relationship_id IN (
				'Maps to',
				'Source - RxNorm eq'
				)
			AND cr.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT c2.concept_code
		FROM dev_dmd.dmd_2 a
		JOIN concept c ON c.concept_code = a.concept_code_1
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND relationship_id IN (
				'Maps to',
				'Source - RxNorm eq'
				)
			AND cr.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		);

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT c2.concept_code
		FROM dev_dmd.dmd_2 a
		JOIN concept c ON c.concept_code = a.concept_code_1
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND relationship_id IN (
				'Maps to',
				'Source - RxNorm eq'
				)
			AND cr.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		);

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT c2.concept_code
		FROM dev_dpd.dpd_2 a
		JOIN concept c ON c.concept_code = a.concept_code_1
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND relationship_id IN (
				'Maps to',
				'Source - RxNorm eq'
				)
			AND cr.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT c2.concept_code
		FROM dev_dpd.dpd_2 a
		JOIN concept c ON c.concept_code = a.concept_code_1
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND relationship_id IN (
				'Maps to',
				'Source - RxNorm eq'
				)
			AND cr.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		);

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT c2.concept_code
		FROM dev_dpd.dpd_2 a
		JOIN concept c ON c.concept_code = a.concept_code_1
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND relationship_id IN (
				'Maps to',
				'Source - RxNorm eq'
				)
			AND cr.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		);

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT c2.concept_code
		FROM (
			SELECT concept_code_1
			FROM dev_grr.grr_2
			WHERE amount_value IS NOT NULL
			
			UNION
			
			SELECT concept_code
			FROM dev_grr.comp_grr
			) a
		JOIN concept c ON c.concept_code = a.concept_code_1
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND relationship_id IN (
				'Maps to',
				'Source - RxNorm eq'
				)
			AND cr.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT c2.concept_code
		FROM (
			SELECT concept_code_1
			FROM dev_grr.grr_2
			WHERE amount_value IS NOT NULL
			
			UNION
			
			SELECT concept_code
			FROM dev_grr.comp_grr
			) a
		JOIN concept c ON c.concept_code = a.concept_code_1
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND relationship_id IN (
				'Maps to',
				'Source - RxNorm eq'
				)
			AND cr.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		);

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT c2.concept_code
		FROM (
			SELECT concept_code_1
			FROM dev_grr.grr_2
			WHERE amount_value IS NOT NULL
			
			UNION
			
			SELECT concept_code
			FROM dev_grr.comp_grr
			) a
		JOIN concept c ON c.concept_code = a.concept_code_1
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND relationship_id IN (
				'Maps to',
				'Source - RxNorm eq'
				)
			AND cr.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (
		SELECT concept_code
		FROM concept
		JOIN eduard_bn_to_delete using (concept_id)
		);

--add Precise Ingredients
CREATE INDEX idx_irs_cc ON internal_relationship_stage (
	concept_code_1,
	concept_code_2
	);
ANALYZE internal_relationship_stage;

INSERT INTO internal_relationship_stage (
	concept_Code_1,
	concept_code_2
	)
SELECT DISTINCT dc.concept_code,
	c2.concept_code
FROM drug_concept_stage dc
JOIN concept c ON dc.concept_code = c.concept_code
	AND c.vocabulary_id LIKE 'RxNorm%'
	AND c.invalid_reason IS NULL
	AND dc.concept_class_id = 'Drug Product'
	AND dc.source_concept_class_id NOT LIKE '%Pack%'
	AND dc.concept_name NOT LIKE '%} Pack%'
JOIN drug_strength ON drug_concept_id = c.concept_id
JOIN concept c2 ON ingredient_concept_id = c2.concept_id
	AND c2.concept_class_id LIKE '%Ingredient'
WHERE NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		WHERE irs_int.concept_code_1 = dc.concept_code
			AND irs_int.concept_code_2 = c2.concept_code
		);

 --added mappings to RxNorm 
INSERT INTO relationship_to_concept (
	concept_code_1,
	concept_id_2,
	precedence
	)
SELECT DISTINCT concept_code_2,
	CASE 
		WHEN c.concept_id = 19053966
			THEN 43525530 --Humulin
		WHEN c.concept_id = 19062405
			THEN 40232311 --Tanac
		WHEN c.concept_id = 19015276
			THEN 19043688 --Salazop
		ELSE c.concept_id
		END,
	1
FROM internal_relationship_stage i
LEFT JOIN relationship_to_concept r ON i.concept_code_2 = r.concept_code_1
JOIN concept c ON i.concept_code_2 = c.concept_code
	AND vocabulary_id LIKE 'Rx%'
WHERE concept_id_2 IS NULL;

DROP INDEX idx_irs_cc;