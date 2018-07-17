DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Brand Name'
			AND lower(concept_name) IN (
				SELECT lower(concept_name)
				FROM concept
				WHERE concept_class_id = 'Ingredient'
					AND invalid_reason IS NULL
				)
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Brand Name'
			AND lower(concept_name) IN (
				SELECT lower(concept_name)
				FROM concept
				WHERE concept_class_id = 'Ingredient'
					AND invalid_reason IS NULL
				)
		);

DELETE
FROM drug_concept_stage
WHERE concept_class_id = 'Brand Name'
	AND lower(concept_name) IN (
		SELECT lower(concept_name)
		FROM concept
		WHERE concept_class_id = 'Ingredient'
			AND invalid_reason IS NULL
		);

DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Supplier'
			AND lower(concept_name) LIKE 'imported%'
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Supplier'
			AND lower(concept_name) LIKE 'imported%'
		);

DELETE
FROM drug_concept_stage
WHERE concept_class_id = 'Supplier'
	AND lower(concept_name) LIKE 'imported%';


INSERT INTO relationship_to_concept
SELECT DISTINCT dcs.concept_code,
	dcs.vocabulary_id,
	c.concept_id,
	rank() OVER (
		PARTITION BY dcs.concept_code ORDER BY c.concept_id
		),
	NULL::FLOAT
FROM Drug_concept_stage dcs
JOIN concept c ON lower(c.concept_name) = lower(dcs.concept_name)
	AND c.concept_class_id = dcs.concept_class_id
	AND c.invalid_reason IS NULL
	AND c.vocabulary_id LIKE 'Rx%'
WHERE dcs.concept_code IN (
		SELECT concept_code_1
		FROM relationship_to_concept
		JOIN concept c ON concept_id = concept_id_2
		WHERE c.invalid_reason IS NOT NULL
		)
	AND c.vocabulary_id LIKE 'Rx%'
	AND c.invalid_reason IS NULL;

INSERT INTO relationship_to_concept
SELECT DISTINCT dcs.concept_code,
	dcs.vocabulary_id,
	x.concept_id,
	rank() OVER (
		PARTITION BY dcs.concept_code ORDER BY x.concept_id
		),
	NULL::FLOAT
FROM drug_concept_stage dcs
JOIN relationship_to_concept ON dcs.concept_code = concept_code_1
JOIN concept c ON c.concept_id = concept_id_2
JOIN dev_rxe.suppl_for_Dima ss ON ss.CONCEPT_CODE_1 = c.concept_code
JOIN concept x ON ss.CONCEPT_CODE_2 = x.concept_code
WHERE c.invalid_reason IS NOT NULL
	AND x.invalid_reason IS NULL;

DELETE
FROM relationship_to_concept
WHERE (
		concept_code_1,
		concept_id_2
		) IN (
		SELECT a.concept_code_1,
			c.concept_id
		FROM relationship_to_concept a
		JOIN concept c ON concept_id = concept_id_2
		JOIN dev_rxe.suppl_for_Dima ss ON ss.CONCEPT_CODE_1 = c.concept_code
		JOIN concept x ON ss.CONCEPT_CODE_2 = x.concept_code
		WHERE c.invalid_reason IS NOT NULL
			AND x.invalid_reason IS NULL
		);

DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_name IN (
				'Aserbine',
				'Atopiclair',
				'Avomine',
				'Clintec',
				'Optrex',
				'Ovex',
				'Rapiscan',
				'TISSEEL Ready to use'
				)
		);

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT concept_code_1
		FROM relationship_to_concept
		JOIN concept c ON c.concept_id = concept_id_2
		WHERE c.invalid_reason IS NOT NULL
		)
	AND concept_class_id = 'Brand Name';

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 NOT IN (
		SELECT concept_code
		FROM drug_concept_stage
		);

DELETE
FROM relationship_to_concept
WHERE concept_code_1 NOT IN (
		SELECT concept_code
		FROM drug_concept_stage
		);

DELETE
FROM relationship_to_concept
WHERE (
		concept_code_1,
		concept_id_2
		) IN (
		SELECT concept_code_1,
			concept_id_2
		FROM relationship_to_concept
		JOIN concept c ON c.concept_id = concept_id_2
		WHERE c.invalid_reason IS NOT NULL
		)
	AND concept_code_1 IN (
		SELECT concept_code_1
		FROM relationship_to_concept
		JOIN concept c ON c.concept_id = concept_id_2
		WHERE c.invalid_reason IS NULL
		);

UPDATE relationship_to_concept
SET concept_id_2 = 1505346
WHERE concept_id_2 = 36878682;

UPDATE relationship_to_concept
SET concept_id_2 = 19089602
WHERE concept_id_2 = 36879088;

UPDATE relationship_to_concept
SET concept_id_2 = 1352213
WHERE concept_id_2 = 40799096;

DELETE
FROM relationship_to_concept
WHERE (
		concept_code_1,
		concept_id_2
		) IN (
		SELECT concept_code_1,
			concept_id_2
		FROM relationship_to_concept
		JOIN concept c ON c.concept_id = concept_id_2
		WHERE c.invalid_reason = 'D'
		);

DROP TABLE IF EXISTS fff1;
CREATE TABLE fff1 AS
SELECT DISTINCT concept_code_1,
	'dm+d' AS vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
FROM relationship_to_concept;

TRUNCATE TABLE relationship_to_concept;

INSERT INTO relationship_to_concept
SELECT concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	rank() OVER (
		PARTITION BY concept_code_1 ORDER BY concept_id_2
		) AS precedence,
	conversion_factor
FROM fff1;

DROP TABLE IF EXISTS ds_sum;
CREATE TABLE ds_sum AS
	WITH a AS (
			SELECT DISTINCT ds.drug_concept_code,
				ds.ingredient_concept_code,
				ds.box_size,
				ds.amount_value,
				ds.amount_unit,
				ds.numerator_value,
				ds.numerator_unit,
				ds.denominator_value,
				ds.denominator_unit,
				rc.concept_id_2
			FROM ds_stage ds
			JOIN ds_stage ds2 ON ds.drug_concept_code = ds2.drug_concept_code
				AND ds.ingredient_concept_code != ds2.ingredient_concept_code
			JOIN relationship_to_concept rc ON ds.ingredient_concept_code = rc.concept_code_1
			JOIN relationship_to_concept rc2 ON ds2.ingredient_concept_code = rc2.concept_code_1
			WHERE rc.concept_id_2 = rc2.concept_id_2
			)

SELECT drug_concept_code,
	max(ingredient_concept_code) OVER (
		PARTITION BY drug_concept_code,
		concept_id_2
		) AS ingredient_concept_code,
	box_size,
	sum(amount_value) OVER (PARTITION BY drug_concept_code) AS amount_value,
	amount_unit,
	sum(numerator_value) OVER (
		PARTITION BY drug_concept_code,
		concept_id_2
		) AS numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
FROM a

UNION

SELECT drug_concept_code,
	ingredient_concept_code,
	box_size,
	NULL AS amount_value,
	NULL AS amount_unit,
	NULL AS numerator_value,
	NULL AS numerator_unit,
	NULL AS denominator_value,
	NULL AS denominator_unit
FROM a
WHERE (
		drug_concept_code,
		ingredient_concept_code
		) NOT IN (
		SELECT drug_concept_code,
			max(ingredient_concept_code)
		FROM a
		GROUP BY drug_concept_code
		);

DELETE
FROM ds_stage
WHERE (
		drug_concept_code,
		ingredient_concept_code
		) IN (
		SELECT drug_concept_code,
			ingredient_concept_code
		FROM ds_sum
		);

INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	box_size,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
	)
SELECT *
FROM ds_sum
WHERE coalesce(amount_value, numerator_value) IS NOT NULL;

--update irs after relationship_to concept found identical ingredients
DELETE
FROM internal_relationship_stage
WHERE (
		concept_code_1,
		concept_code_2
		) IN (
		SELECT concept_code_1,
			concept_code_2
		FROM (
			SELECT DISTINCT concept_code_1,
				concept_code_2,
				COUNT(concept_code_2) OVER (PARTITION BY concept_code_1) AS irs_cnt
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code = concept_code_2
				AND concept_class_id = 'Ingredient'
			) irs
		JOIN (
			SELECT DISTINCT drug_concept_code,
				COUNT(ingredient_concept_code) OVER (PARTITION BY drug_concept_code) AS ds_cnt
			FROM ds_stage
			) ds ON drug_concept_code = concept_code_1
			AND irs_cnt != ds_cnt
		)
	AND (
		concept_code_1,
		concept_code_2
		) NOT IN (
		SELECT drug_concept_code,
			ingredient_concept_code
		FROM ds_stage
		);

INSERT INTO relationship_to_concept
SELECT dcs.concept_code,
	'dm+d',
	cc.concept_id,
	rank() OVER (
		PARTITION BY dcs.concept_code ORDER BY cc.concept_id
		),
	NULL
FROM drug_concept_stage dcs
JOIN concept cc ON lower(cc.concept_name) = lower(dcs.concept_name)
	AND cc.concept_class_id = dcs.concept_class_id
	AND cc.vocabulary_id LIKE 'RxNorm%'
LEFT JOIN relationship_to_concept cr ON dcs.concept_code = cr.concept_code_1
WHERE concept_code_1 IS NULL
	AND cc.invalid_reason IS NULL
	AND dcs.concept_class_id IN (
		'Ingredient',
		'Brand Name',
		'Dose Form',
		'Supplier'
		);

UPDATE ds_stage
SET drug_concept_code = trim(drug_concept_code)
WHERE drug_concept_code <> trim(drug_concept_code);

INSERT INTO internal_relationship_stage
SELECT DISTINCT drug_concept_code,
	ingredient_concept_code
FROM ds_stage
WHERE (
		drug_concept_code,
		ingredient_concept_code
		) NOT IN (
		SELECT concept_code_1,
			concept_code_2
		FROM internal_relationship_stage
		);
