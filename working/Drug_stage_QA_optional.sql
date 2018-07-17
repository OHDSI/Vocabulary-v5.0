--these queries return not null results
--but these results are suspicious and need to be reviewed

-- drugs absent in drug_strength table
SELECT DISTINCT concept_code,
	'Drug product doesnt have drug_strength info'
FROM drug_concept_stage
WHERE concept_code NOT IN (
		SELECT drug_concept_code
		FROM ds_stage
		)
	AND concept_class_id = 'Drug Product'
	AND concept_code NOT IN (
		SELECT pack_concept_code
		FROM pc_stage
		)

UNION ALL

SELECT DISTINCT concept_code,
	'Missing relationship to Ingredient'
FROM drug_concept_stage
WHERE concept_class_id = 'Drug Product'
	AND concept_code NOT IN (
		SELECT pack_concept_code
		FROM pc_stage
		)
	AND concept_code NOT IN (
		SELECT a.concept_code
		FROM drug_concept_stage a
		JOIN internal_relationship_stage s ON s.concept_code_1 = a.concept_code
		JOIN drug_concept_stage b ON b.concept_code = s.concept_code_2
			AND a.concept_class_id = 'Drug Product'
			AND b.concept_class_id = 'Ingredient'
		)

UNION ALL

--Ingredient doesnt relate to any drug
SELECT DISTINCT a.concept_code,
	'Ingredient doesnt relate to any drug'
FROM drug_concept_stage a
LEFT JOIN internal_relationship_stage b ON a.concept_code = b.concept_code_2
WHERE a.concept_class_id = 'Ingredient'
	AND b.concept_code_1 IS NULL

UNION ALL

--getting ingredient duplicates after relationsip_to_concept
SELECT drug_concept_code,
	'ingred duplic after relationsip_to_concept'
FROM ds_stage a
JOIN relationship_to_concept b ON ingredient_concept_code = concept_code_1
	AND precedence = 1
GROUP BY drug_concept_code,
	concept_id_2
HAVING COUNT(*) > 1;

--units absent in RxNorm
SELECT *
FROM relationship_to_concept
JOIN concept n ON n.concept_id = concept_id_2
WHERE concept_class_id = 'Unit'
	AND concept_id_2 NOT IN (
		SELECT amount_unit_concept_id
		FROM drug_strength
		JOIN concept c ON c.concept_id = drug_concept_id
			AND c.vocabulary_id = 'RxNorm'
			AND amount_unit_concept_id IS NOT NULL
		
		UNION ALL
		
		SELECT numerator_unit_concept_id
		FROM drug_strength
		JOIN concept c ON c.concept_id = drug_concept_id
			AND c.vocabulary_id = 'RxNorm'
			AND numerator_unit_concept_id IS NOT NULL
		
		UNION ALL
		
		SELECT denominator_unit_concept_id
		FROM drug_strength
		JOIN concept c ON c.concept_id = drug_concept_id
			AND c.vocabulary_id = 'RxNorm'
			AND denominator_unit_concept_id IS NOT NULL
		);

--anyway need to look throught this table , mistakes here cost too much
SELECT *
FROM relationship_to_concept
JOIN concept n ON n.concept_id = concept_id_2
WHERE concept_class_id = 'Unit';

SELECT source_concept_class_id
FROM drug_concept_stage LIMIT 1;

SELECT *
FROM ds_stage
WHERE numerator_unit = '%';

-- getting ingredient duplicates after relationsip_to_concept look up table
SELECT ds.*,
	dcs.concept_name,
	dci.concept_name,
	c.concept_name
FROM ds_stage ds
JOIN relationship_to_concept b ON ingredient_concept_code = concept_code_1
	AND precedence = 1
JOIN drug_concept_stage dcs ON drug_concept_code = dcs.concept_code
JOIN drug_concept_stage dci ON ingredient_concept_code = dci.concept_code
JOIN concept c ON concept_id = concept_id_2
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN relationship_to_concept b ON ingredient_concept_code = concept_code_1
			AND precedence = 1
		GROUP BY drug_concept_code,
			concept_id_2
		HAVING COUNT(*) > 1
		);

--select * from source_table where enr = '101149'

-- some tests , have features usable only in AMT vocabulary, but can be reused with the other vocabularies
SELECT *
FROM ds_stage
JOIN drug_concept_stage ON concept_code = drug_concept_code
WHERE denominator_value IS NOT NULL LIMIT 100;

SELECT *
FROM ds_stage
JOIN drug_concept_stage ON concept_code = drug_concept_code
WHERE denominator_value IS NULL
	AND concept_name ~ '\d+ Ml$'
	AND substring(concept_name, '\d+ Ml$') != '5 Ml'
	AND substring(concept_name, '\d+ Ml$') != '10 Ml' LIMIT 100;

SELECT *
FROM drug_concept_stage
WHERE domain_id IS NULL
	OR domain_id != 'Drug';

SELECT s.concept_name AS source_name,
	S.concept_class_id AS source_class,
	c.concept_name AS target_name,
	c.concept_class_id AS target_class,
	precedence,
	conversion_factor
FROM relationship_to_concept
JOIN concept c ON concept_id = concept_id_2
JOIN drug_concept_stage s ON s.concept_code = concept_code_1
WHERE s.concept_class_id = 'Ingredient'
	AND devv5.jaro_winkler(s.concept_name, c.concept_name) * 100 < 80;

SELECT *
FROM ds_stage
JOIN drug_concept_stage ON drug_concept_code = concept_code LIMIT 2000;

SELECT *
FROM ds_stage
WHERE amount_unit = '%'
	OR numerator_unit = '%'
	OR denominator_unit = '%';

SELECT DISTINCT a.concept_class_id,
	b.concept_class_id
FROM internal_relationship_stage i
JOIN drug_concept_stage a ON i.concept_code_1 = a.concept_code
JOIN drug_concept_stage b ON i.concept_code_2 = b.concept_code;

--missing relationship to Dose Form
SELECT *
FROM drug_concept_stage
WHERE concept_code NOT IN (
		SELECT a.concept_code
		FROM internal_relationship_stage i
		JOIN drug_concept_stage a ON i.concept_code_1 = a.concept_code
		JOIN drug_concept_stage b ON i.concept_code_2 = b.concept_code
		WHERE b.concept_class_id = 'Dose Form'
		)
	AND concept_class_id = 'Drug Product';

--missing relationship to Brand Name
SELECT *
FROM drug_concept_stage
WHERE concept_code NOT IN (
		SELECT DISTINCT a.concept_code
		FROM internal_relationship_stage i
		JOIN drug_concept_stage a ON i.concept_code_1 = a.concept_code
		JOIN drug_concept_stage b ON i.concept_code_2 = b.concept_code
		WHERE b.concept_class_id = 'Brand Name'
		)
	AND source_concept_class_id = 'Trade Product Pack' LIMIT 1000;

--missing relationship to Supplier
SELECT *
FROM drug_concept_stage
WHERE concept_code NOT IN (
		SELECT a.concept_code
		FROM internal_relationship_stage i
		JOIN drug_concept_stage a ON i.concept_code_1 = a.concept_code
		JOIN drug_concept_stage b ON i.concept_code_2 = b.concept_code
		WHERE b.concept_class_id = 'Supplier'
		)
	AND source_concept_class_id = 'Trade Product Pack'
	AND concept_name ~ '\(...+\)' LIMIT 1000;

SELECT *
FROM drug_concept_stage;

SELECT s.concept_name AS source_name,
	S.concept_class_id AS source_class,
	c.concept_name AS target_name,
	c.concept_class_id AS target_class,
	precedence,
	conversion_factor
FROM relationship_to_concept
JOIN concept c ON concept_id = concept_id_2
JOIN drug_concept_stage s ON s.concept_code = concept_code_1
WHERE s.concept_class_id = 'Brand Name'
	AND devv5.jaro_winkler(lower(s.concept_name), lower(c.concept_name)) * 100 < 90;

SELECT COUNT(*)
--s.concept_name as source_name, S.concept_class_id as source_class, c.concept_name as target_name, c.concept_class_id as target_class, precedence, conversion_factor
FROM relationship_to_concept
JOIN concept c ON concept_id = concept_id_2
JOIN drug_concept_stage s ON s.concept_code = concept_code_1
WHERE s.concept_class_id = 'Supplier'
	--and devv5.jaro_winkler (lower (s.concept_name), lower (c.concept_name))*100 < 90
	;

SELECT COUNT(*)
--s.concept_name as source_name, S.concept_class_id as source_class, c.concept_name as target_name, c.concept_class_id as target_class, precedence, conversion_factor
FROM relationship_to_concept
JOIN concept c ON concept_id = concept_id_2
JOIN drug_concept_stage s ON s.concept_code = concept_code_1
WHERE s.concept_class_id = 'Brand Name'
	--and and devv5.jaro_winkler (lower (s.concept_name), lower (c.concept_name))*100 < 90
	;

SELECT COUNT(*)
--s.concept_name as source_name, S.concept_class_id as source_class, c.concept_name as target_name, c.concept_class_id as target_class, precedence, conversion_factor
FROM relationship_to_concept
JOIN concept c ON concept_id = concept_id_2
JOIN drug_concept_stage s ON s.concept_code = concept_code_1
WHERE s.concept_class_id = 'Ingredient';

SELECT s.concept_class_id,
	COUNT(*)
FROM relationship_to_concept
JOIN concept c ON concept_id = concept_id_2
JOIN drug_concept_stage s ON s.concept_code = concept_code_1
GROUP BY s.concept_class_id;

SELECT DISTINCT b.concept_name
FROM ds_stage a
JOIN drug_concept_stage b ON a.ingredient_concept_code = concept_code
WHERE ingredient_concept_code NOT IN (
		SELECT concept_code_1
		FROM relationship_to_concept
		);

SELECT -- COUNT (*) 
	s.concept_name AS source_name,
	S.concept_class_id AS source_class,
	c.concept_name AS target_name,
	c.concept_class_id AS target_class,
	precedence,
	conversion_factor
FROM relationship_to_concept
JOIN concept c ON concept_id = concept_id_2
JOIN drug_concept_stage s ON s.concept_code = concept_code_1
WHERE s.concept_class_id = 'Unit';

SELECT *
FROM concept
WHERE vocabulary_id = 'UCUM';

SELECT b.concept_name,
	a.concept_name,
	p.*
FROM pc_stage p
JOIN drug_concept_stage a ON a.concept_code = p.drug_concept_code
JOIN drug_concept_stage b ON b.concept_code = p.pack_concept_code;

--missing relationship to Brand Name
SELECT *
FROM drug_concept_stage
WHERE concept_code NOT IN (
		SELECT a.concept_code
		FROM internal_relationship_stage i
		JOIN drug_concept_stage a ON i.concept_code_1 = a.concept_code
		JOIN drug_concept_stage b ON i.concept_code_2 = b.concept_code
		WHERE b.concept_class_id = 'Brand Name'
		)
	AND source_concept_class_id = 'Trade Product Pack' LIMIT 1000;

--missing relationship to Supplier
SELECT *
FROM drug_concept_stage
WHERE concept_code NOT IN (
		SELECT a.concept_code
		FROM internal_relationship_stage i
		JOIN drug_concept_stage a ON i.concept_code_1 = a.concept_code
		JOIN drug_concept_stage b ON i.concept_code_2 = b.concept_code
		WHERE b.concept_class_id = 'Supplier'
		)
	AND source_concept_class_id = 'Trade Product Pack' --and LENGTH ( substring  (concept_name, '(\(...+\)?)')  ) < 20
	AND concept_code IN (
		SELECT pack_concept_code
		FROM pc_stage
		) LIMIT 1000;

--missing relationship to Brand Name
SELECT *
FROM drug_concept_stage
WHERE concept_code NOT IN (
		SELECT a.concept_code
		FROM internal_relationship_stage i
		JOIN drug_concept_stage a ON i.concept_code_1 = a.concept_code
		JOIN drug_concept_stage b ON i.concept_code_2 = b.concept_code
		WHERE b.concept_class_id = 'Brand Name'
			AND a.concept_code IS NOT NULL
		)
	AND source_concept_class_id = 'Trade Product Pack'
	AND concept_code IN (
		SELECT pack_concept_code
		FROM pc_stage
		) LIMIT 1000;
