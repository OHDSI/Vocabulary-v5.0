UPDATE ds_stage a
SET denominator_value = i.denominator_value,
	denominator_unit = i.denominator_unit
FROM (
	SELECT DISTINCT b.denominator_value,
		b.denominator_unit,
		b.drug_concept_code
	FROM ds_stage b
	WHERE b.denominator_unit IS NOT NULL
	) i
WHERE a.drug_concept_code = i.drug_concept_code
	AND a.denominator_unit IS NULL;

--somehow we get amount +denominator
UPDATE ds_stage a
SET numerator_value = a.amount_value,
	numerator_unit = a.amount_unit,
	amount_value = NULL,
	amount_unit = NULL
WHERE a.denominator_unit IS NOT NULL
	AND numerator_unit IS NULL;

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE COALESCE(amount_value, numerator_value, 0) = 0
			-- needs to have at least one value, zeros don't count
			OR COALESCE(amount_unit, numerator_unit) IS NULL
			-- needs to have at least one unit
			OR (
				amount_value IS NOT NULL
				AND amount_unit IS NULL
				)
			-- if there is an amount record, there must be a unit
			OR (
				COALESCE(numerator_value, 0) != 0
				AND COALESCE(numerator_unit, denominator_unit) IS NULL
				)
		); -- if there is a concentration record there must be a unit in both numerator and denominator

UPDATE drug_concept_stage
SET standard_concept = 'S'
WHERE domain_id = 'Device'
	AND invalid_reason IS NULL;

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM (
			SELECT DISTINCT concept_code_1,
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
		);

UPDATE ds_stage
SET denominator_unit = 'ml'
WHERE drug_concept_code = '353113002'
	AND ingredient_concept_code = '61360007';

UPDATE ds_stage
SET denominator_unit = 'ml'
WHERE drug_concept_code = '3844411000001103'
	AND ingredient_concept_code = '61360007';

UPDATE relationship_to_concept
SET concept_id_2 = 1718061
WHERE concept_code_1 = '421958003'
	AND vocabulary_id_1 = 'dm+d';

DELETE
FROM relationship_to_concept
WHERE concept_id_2 IN (
		SELECT concept_id_2
		FROM relationship_to_concept
		JOIN drug_concept_stage s ON s.concept_code = concept_code_1
		JOIN concept c ON c.concept_id = concept_id_2
		WHERE c.standard_concept IS NULL
			AND s.concept_class_id = 'Ingredient'
		);


DROP TABLE IF EXISTS ds_stage_1;
CREATE TABLE ds_stage_1 AS
SELECT *
FROM ds_stage;

TRUNCATE TABLE ds_stage;
--updating drugs that have ingredients with 2 or more dosages that need to be sum up
INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size
	)
SELECT DISTINCT drug_concept_code,
	ingredient_concept_code,
	SUM(amount_value) OVER (
		PARTITION BY drug_concept_code,
		ingredient_concept_code,
		amount_unit
		),
	amount_unit,
	SUM(numerator_value) OVER (
		PARTITION BY drug_concept_code,
		ingredient_concept_code,
		numerator_unit
		),
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size
FROM (
	SELECT drug_concept_code,
		ingredient_concept_code,
		box_size,
		CASE 
			WHEN amount_unit = 'G'
				THEN amount_value * 1000
			WHEN amount_unit = 'MCG'
				THEN amount_value / 1000
			ELSE amount_value
			END AS amount_value, -- make amount units similar
		CASE 
			WHEN amount_unit IN (
					'G',
					'MCG'
					)
				THEN 'MG'
			ELSE amount_unit
			END AS amount_unit,
		CASE 
			WHEN numerator_unit = 'G'
				THEN numerator_value * 1000
			WHEN numerator_unit = 'MCG'
				THEN numerator_value / 1000
			ELSE numerator_value
			END AS numerator_value,
		CASE 
			WHEN numerator_unit IN (
					'G',
					'MCG'
					)
				THEN 'MG'
			ELSE numerator_unit
			END AS numerator_unit,
		denominator_value,
		denominator_unit
	FROM ds_stage_1 a
	WHERE (
			drug_concept_code,
			ingredient_concept_code
			) IN (
			SELECT drug_concept_code,
				ingredient_concept_code
			FROM ds_stage_1
			GROUP BY drug_concept_code,
				ingredient_concept_code
			HAVING COUNT(1) > 1
			)
	) AS s0;

INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size
	)
SELECT DISTINCT drug_concept_code,
	ingredient_concept_code,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size
FROM ds_stage_1
WHERE (
		drug_concept_code,
		ingredient_concept_code
		) NOT IN (
		SELECT drug_concept_code,
			ingredient_concept_code
		FROM ds_stage_1
		GROUP BY drug_concept_code,
			ingredient_concept_code
		HAVING COUNT(1) > 1
		);

DELETE
FROM ds_stage
WHERE ingredient_concept_code IS NULL;

DELETE drug_concept_stage
WHERE concept_code IN (
		SELECT pack_concept_code
		FROM pc_stage
		);

DELETE drug_concept_stage
WHERE concept_code IN (
		SELECT drug_concept_code
		FROM pc_stage
		);

DELETE internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT pack_concept_code
		FROM pc_stage
		);

DELETE internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT drug_concept_code
		FROM pc_stage
		);

DELETE ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM pc_stage
		);

TRUNCATE TABLE pc_stage;
DELETE drug_concept_stage
WHERE concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE upper(numerator_unit) IN (
				'DH',
				'C',
				'CH',
				'D',
				'TM',
				'X',
				'XMK'
				)
			AND denominator_value IS NOT NULL
		);

DELETE internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE upper(numerator_unit) IN (
				'DH',
				'C',
				'CH',
				'D',
				'TM',
				'X',
				'XMK'
				)
			AND denominator_value IS NOT NULL
		);

DELETE ds_stage
WHERE upper(numerator_unit) IN (
		'DH',
		'C',
		'CH',
		'D',
		'TM',
		'X',
		'XMK'
		)
	AND denominator_value IS NOT NULL;

DELETE drug_concept_stage
WHERE concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE upper(amount_unit) IN (
				'DH',
				'C',
				'CH',
				'D',
				'TM',
				'X',
				'XMK'
				)
		);

DELETE internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE upper(amount_unit) IN (
				'DH',
				'C',
				'CH',
				'D',
				'TM',
				'X',
				'XMK'
				)
		);

DELETE ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE upper(amount_unit) IN (
				'DH',
				'C',
				'CH',
				'D',
				'TM',
				'X',
				'XMK'
				)
		);

--PUT ALREADY UP-TO date concepts into internal_relationship_stage 
UPDATE internal_relationship_stage rr
SET concept_code_2 = i.irs2_concept_code_2
FROM (
	SELECT irs1.concept_code_1 AS irs1_concept_code_1,
		irs1.concept_code_2 AS irs1_concept_code_2,
		irs2.concept_code_2 AS irs2_concept_code_2
	FROM internal_relationship_stage irs1
	JOIN drug_concept_stage dcs1 ON dcs1.concept_code = irs1.concept_code_2
	JOIN internal_relationship_stage irs2 ON irs1.concept_code_2 = irs2.concept_code_1
	JOIN drug_concept_stage dcs2 ON dcs2.concept_code = irs2.concept_code_2
		AND dcs2.concept_class_id = dcs1.concept_ClasS_id
		AND dcs2.invalid_reason IS NULL
	WHERE dcs1.invalid_reason IS NOT NULL
	) i
WHERE i.irs1_concept_code_1 = rr.concept_code_1
	AND i.irs1_concept_code_1 = rr.concept_code_1

--fix duplicates
DELETE
FROM internal_relationship_stage i
WHERE EXISTS (
		SELECT 1
		FROM internal_relationship_stage i_int
		WHERE coalesce(i_int.concept_code_1, '-1') = coalesce(i.concept_code_1, '-1')
			AND coalesce(i_int.concept_code_2, '-1') = coalesce(i.concept_code_2, '-1')
			AND i_int.ctid > i.ctid
		);

--ML is not allowed as a dosage
DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		JOIN drug_concept_stage ON drug_concept_code = concept_code
		WHERE lower(numerator_unit) IN ('ml')
			OR lower(amount_unit) IN ('ml')
		);

--insert name equal mappings
INSERT INTO relationship_to_concept (
	concept_code_1,
	concept_id_2,
	precedence
	)
SELECT concept_code,
	concept_id,
	rank() OVER (
		PARTITION BY concept_code ORDER BY concept_id
		) AS precedence
FROM (
	SELECT DISTINCT dcs.concept_code,
		cc.concept_id
	FROM drug_concept_stage dcs
	JOIN concept cc ON lower(cc.concept_name) = lower(dcs.concept_name)
		AND cc.concept_class_id = dcs.concept_class_id
		AND cc.vocabulary_id LIKE 'RxNorm%'
	LEFT JOIN (
		SELECT *
		FROM relationship_to_concept
		JOIN concept ON concept_id = concept_id_2
			AND invalid_reason IS NULL
		) cr ON dcs.concept_code = cr.concept_code_1
	WHERE concept_code_1 IS NULL
		AND cc.invalid_reason IS NULL
		AND dcs.concept_class_id IN (
			'Ingredient',
			'Brand Name',
			'Dose Form',
			'Supplier'
			)
	) AS s0;

--PPM problem, solve it later, ppm = 0.0001 % = 1 mg/L 
DELETE
FROM ds_stage
WHERE 'ppm' IN (
		amount_unit,
		numerator_unit
		);

UPDATE relationship_to_concept
SET precedence = 1
WHERE precedence IS NULL;

--add various mappgings to Suppliers
DROP TABLE IF EXISTS rxe_man_st_0;
CREATE TABLE rxe_man_st_0 AS
SELECT concept_code_1 AS concept_code_1,
	concept_id,
	rank() OVER (
		PARTITION BY concept_code_1 ORDER BY concept_id
		) AS precedence
FROM (
	SELECT concept_code_1,
		c.concept_id
	FROM relationship_to_concept
	JOIN concept c ON concept_id_2 = concept_id
	WHERE concept_class_id = 'Supplier'
	
	UNION
	
	SELECT a.concept_code,
		c.concept_id
	FROM drug_concept_stage a
	JOIN concept c ON regexp_replace(lower(a.concept_name), ' ltd| plc| uk| \(.*\)| pharmaceuticals| pharma| gmbh| laboratories| ab| international| france| imaging', '', 'g') = regexp_replace(lower(c.concept_name), ' ltd| plc| uk| \(.*\)| pharmaceuticals| pharma| gmbh| laboratories| ab| international| france| imaging', '', 'g')
	WHERE a.concept_class_id = 'Supplier'
		AND (
			a.concept_code,
			c.concept_Id
			) NOT IN (
			SELECT concept_code_1,
				concept_id_2
			FROM relationship_to_concept
			)
		AND c.vocabulary_id LIKE 'RxNorm%'
		AND c.concept_class_id = 'Supplier'
		AND c.invalid_reason IS NULL
	) AS s0;

select count(*) from rxe_man_st_0;

DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
		SELECT concept_code_1
		FROM rxe_man_st_0
		);

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT concept_code_1,
	'dm+d',
	CONCEPT_ID,
	precedence,
	NULL
FROM rxe_man_st_0; -- RxNormExtension name equivalence

--more duplicates fixing
DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT concept_code_1
		FROM concept_stage
		JOIN concept_relationshiP_stage ON concept_code_2 = concept_code
			AND relationship_id = 'Maps to'
		WHERE lower(concept_name) IN (
				SELECT concept_name
				FROM (
					SELECT lower(concept_name) AS concept_name
					FROM concept_stage
					WHERE vocabulary_id LIKE 'Rx%'
						AND invalid_reason IS NULL
						AND concept_name NOT LIKE '%...%'
					
					UNION ALL
					
					SELECT lower(concept_name)
					FROM concept
					WHERE vocabulary_id LIKE 'Rx%'
						AND invalid_reason IS NULL
						AND concept_name NOT LIKE '%...%'
					) AS s0
				GROUP BY concept_name
				HAVING count(1) > 1
				)
			AND vocabulary_id LIKE 'Rx%'
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT concept_code_1
		FROM concept_stage
		JOIN concept_relationshiP_stage ON concept_code_2 = concept_code
			AND relationship_id = 'Maps to'
		WHERE lower(concept_name) IN (
				SELECT concept_name
				FROM (
					SELECT lower(concept_name) AS concept_name
					FROM concept_stage
					WHERE vocabulary_id LIKE 'Rx%'
						AND invalid_reason IS NULL
						AND concept_name NOT LIKE '%...%'
					
					UNION ALL
					
					SELECT lower(concept_name)
					FROM concept
					WHERE vocabulary_id LIKE 'Rx%'
						AND invalid_reason IS NULL
						AND concept_name NOT LIKE '%...%'
					) AS s0
				GROUP BY concept_name
				HAVING count(1) > 1
				)
			AND vocabulary_id LIKE 'Rx%'
		);

--should be changed to mg/L when ds_stage was created
DELETE
FROM relationship_to_concept
WHERE concept_code_1 = 'ppm';

--Marketed Drugs without the dosage or Drug Form are not allowed
DELETE
FROM internal_relationship_stage
WHERE (
		concept_code_1,
		concept_code_2
		) IN (
		SELECT concept_code_1,
			concept_code_2
		FROM drug_concept_stage dcs
		JOIN (
			SELECT concept_code_1,
				concept_code_2
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Supplier'
			LEFT JOIN ds_stage ON drug_concept_code = concept_code_1
			WHERE drug_concept_code IS NULL
			
			UNION
			
			SELECT concept_code_1,
				concept_code_2
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Supplier'
			WHERE concept_code_1 NOT IN (
					SELECT concept_code_1
					FROM internal_relationship_stage
					JOIN drug_concept_stage ON concept_code_2 = concept_code
						AND concept_class_id = 'Dose Form'
					)
			) s ON s.concept_code_1 = dcs.concept_code
		WHERE dcs.concept_class_id = 'Drug Product'
			AND invalid_reason IS NULL
		);

DELETE
FROM ds_stage
WHERE drug_concept_code = '24510411000001102'
	AND ingredient_concept_code = '21143111000001109';

DELETE
FROM ds_stage
WHERE drug_concept_code = '24437911000001107'
	AND ingredient_concept_code = '21143111000001109';

DELETE
FROM ds_stage
WHERE drug_concept_code = '24437811000001102'
	AND ingredient_concept_code = '21143111000001109';

DELETE
FROM ds_stage
WHERE drug_concept_code = '24437711000001105'
	AND ingredient_concept_code = '21143111000001109';

DELETE
FROM ds_stage
WHERE drug_concept_code = '24437611000001101'
	AND ingredient_concept_code = '21143111000001109';

DELETE
FROM ds_stage
WHERE drug_concept_code = '24437511000001100'
	AND ingredient_concept_code = '21143111000001109';

DELETE
FROM ds_stage
WHERE drug_concept_code = '24437411000001104'
	AND ingredient_concept_code = '21143111000001109';

DELETE
FROM ds_stage
WHERE drug_concept_code = '24437311000001106'
	AND ingredient_concept_code = '21143111000001109';

DELETE
FROM ds_stage
WHERE drug_concept_code = '24437211000001103'
	AND ingredient_concept_code = '21143111000001109';

DELETE
FROM ds_stage
WHERE drug_concept_code = '21143711000001105'
	AND ingredient_concept_code = '21143111000001109';

DELETE
FROM ds_stage
WHERE drug_concept_code = '21143611000001101'
	AND ingredient_concept_code = '21143111000001109';

DELETE
FROM ds_stage
WHERE drug_concept_code = '21143511000001100'
	AND ingredient_concept_code = '21143111000001109';

DELETE
FROM ds_stage
WHERE drug_concept_code = '21143411000001104'
	AND ingredient_concept_code = '21143111000001109';

DELETE
FROM ds_stage
WHERE drug_concept_code = '21143311000001106'
	AND ingredient_concept_code = '21143111000001109';

DELETE
FROM ds_stage
WHERE drug_concept_code = '21143211000001103'
	AND ingredient_concept_code = '21143111000001109';

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (
		'229862008',
		'4672911000001107',
		'4245911000001102'
		);

--set Gases as a Devices --check o
UPDATE drug_concept_stage
SET domain_id = 'Device'
WHERE concept_name ~ 'Oxygen|Nitrous Oxide|Carbon Dioxide|Nitrous oxide|Air |Equanox | cylinders ';

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE domain_id = 'Device'
		);