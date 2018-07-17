TRUNCATE TABLE ds_stage;

INSERT INTO ds_stage
SELECT DISTINCT drug_code AS drug_concept_code,
	coalesce(c.concept_code, a.ingredient_code) AS ingredient_concept_code,
	box_size,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
FROM strength_tmp a
LEFT JOIN (
	SELECT b.concept_code_1 AS ns_ingredient_code,
		c.concept_code
	FROM internal_relationship_stage b
	LEFT JOIN drug_concept_stage c ON c.concept_code = b.concept_code_2
		AND c.standard_concept = 'S'
	) c ON c.ns_ingredient_code = a.ingredient_code;

--
UPDATE ds_stage ds
SET numerator_value = d.numerator_value,
	numerator_unit = d.numerator_unit
FROM (
	SELECT DISTINCT a.drug_concept_code,
		a.ingredient_concept_code,
		a.box_size,
		a.amount_value,
		a.amount_unit,
		CASE 
			WHEN a.numerator_unit = b.numerator_unit
				THEN a.numerator_value + b.numerator_value
			WHEN a.numerator_unit = CONCAT (
					'm',
					b.numerator_unit
					)
				THEN a.numerator_value + 1000 * b.numerator_value
			WHEN CONCAT (
					'm',
					a.numerator_unit
					) = b.numerator_unit
				THEN 1000 * a.numerator_value + b.numerator_value
			END AS numerator_value,
		CASE 
			WHEN a.numerator_unit = b.numerator_unit
				THEN a.numerator_unit
			WHEN a.numerator_unit = CONCAT (
					'm',
					b.numerator_unit
					)
				THEN a.numerator_unit
			WHEN CONCAT (
					'm',
					a.numerator_unit
					) = b.numerator_unit
				THEN b.numerator_unit
			END AS numerator_unit,
		a.denominator_value,
		a.denominator_unit
	FROM ds_stage a
	JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code
		AND a.ingredient_concept_code = b.ingredient_concept_code
		AND (a.ctid != b.ctid)
		AND a.denominator_value = b.denominator_value
		AND a.denominator_unit = b.denominator_unit
	) d
WHERE d.drug_concept_code = ds.drug_concept_code
	AND d.ingredient_concept_code = ds.ingredient_concept_code;

--delete duplicates
DELETE
FROM ds_stage d
WHERE EXISTS (
		SELECT 1
		FROM ds_stage d_int
		WHERE d_int.drug_concept_code = d.drug_concept_code
			AND d_int.ingredient_concept_code = d.ingredient_concept_code
			AND d_int.ctid > d.ctid
		);
