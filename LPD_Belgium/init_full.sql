INSERT INTO drug_concept_stage --devices
SELECT d.prd_name,
	'LPD_Belgium' AS vocabulary_id,
	'Device' AS concept_class_id,
	NULL AS source_concept_class_id,
	'S' AS standard_concept,
	d.prd_id AS concept_code,
	NULL AS possible_excipient,
	'Device' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM source_data d
JOIN devices_mapped m ON m.prd_name = d.prd_name;


INSERT INTO drug_concept_stage --drugs
SELECT d.prd_name,
	'LPD_Belgium' AS vocabulary_id,
	'Drug Product' AS concept_class_id,
	NULL AS source_concept_class_id,
	'S' AS standard_concept,
	d.prd_id AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM source_data d
WHERE prd_name NOT IN (
		SELECT prd_name
		FROM devices_mapped
		);


DROP SEQUENCE IF EXISTS conc_stage_seq;
CREATE sequence conc_stage_seq MINVALUE 100 MAXVALUE 1000000 START
	WITH 100 INCREMENT BY 1 CACHE 20;

INSERT INTO drug_concept_stage --bn
SELECT NAME,
	'LPD_Belgium' AS vocabulary_id,
	'Brand Name' AS concept_class_id,
	NULL AS source_concept_class_id,
	NULL AS standard_concept,
	'OMOP' || nextval('conc_stage_seq') AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT DISTINCT coalesce(mast_prd_name, concept_name) AS NAME
	FROM brands_mapped
	) AS s0;

INSERT INTO drug_concept_stage --in
SELECT TRIM(NAME),
	'LPD_Belgium' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	NULL AS source_concept_class_id,
	'S' AS standard_concept,
	'OMOP' || nextval('conc_stage_seq') AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT DISTINCT concept_name AS NAME
	FROM products_to_ingreds
	) AS s0;

INSERT INTO drug_concept_stage
WITH units AS --units
	(
		SELECT UNIT_NAME1 AS NAME
		FROM source_data d
		
		UNION
		
		SELECT UNIT_NAME2 AS NAME
		FROM source_data d
		
		UNION
		
		SELECT UNIT_NAME3 AS NAME
		FROM source_data d
		)
SELECT NAME,
	'LPD_Belgium' AS vocabulary_id,
	'Unit' AS concept_class_id,
	NULL AS source_concept_class_id,
	NULL AS standard_concept,
	NAME AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM units
WHERE NAME IS NOT NULL;

INSERT INTO drug_concept_stage
VALUES (
	'actuat',
	'LPD_Belgium',
	'Unit',
	NULL,
	NULL,
	'actuat',
	NULL,
	'Drug',
	CURRENT_DATE,
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
	);

INSERT INTO drug_concept_stage --dose form
SELECT DISTINCT drug_form,
	'LPD_Belgium' AS vocabulary_id,
	'Dose Form' AS concept_class_id,
	NULL AS source_concept_class_id,
	NULL AS standard_concept,
	CONCAT (
		'g',
		gal_id
		),
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM source_data
WHERE gal_id NOT IN (
		'-1',
		'28993'
		);-- unknown or IUD

INSERT INTO internal_relationship_stage --ingreds
SELECT d.prd_id,
	c.concept_code
FROM source_data d
JOIN products_to_ingreds p ON d.prd_name = p.prd_name
JOIN drug_concept_stage c ON c.concept_name = p.concept_name
	AND concept_class_id = 'Ingredient'
WHERE d.prd_name NOT IN (
		SELECT prd_name
		FROM devices_mapped
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 = 'OMOP3380918'
	AND concept_code_1 IN (
		'10541251',
		'10541252'
		);

INSERT INTO internal_relationship_stage --brands
SELECT d.prd_id,
	c.concept_code
FROM source_data d
JOIN brands_mapped p ON d.prd_name = p.prd_name
JOIN drug_concept_stage c ON c.concept_name = p.concept_name
	AND concept_class_id = 'Brand Name'
WHERE d.prd_name NOT IN (
		SELECT prd_name
		FROM devices_mapped
		);

INSERT INTO internal_relationship_stage --dose forms
SELECT DISTINCT d.prd_id,
	CONCAT (
		'g',
		d.gal_id
		)
FROM source_data d
WHERE d.prd_name NOT IN (
		SELECT prd_name
		FROM devices_mapped
		)
	AND d.gal_id NOT IN (
		'-1',
		'28993'
		);

INSERT INTO drug_concept_stage --in
SELECT MANUFACTURER_NAME,
	'LPD_Belgium' AS vocabulary_id,
	'Supplier' AS concept_class_id,
	NULL AS source_concept_class_id,
	'S' AS standard_concept,
	'OMOP' || nextval('conc_stage_seq') AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT DISTINCT MANUFACTURER_NAME
	FROM supplier_mapped
	) AS s0;

INSERT INTO internal_relationship_stage --suppliers
SELECT DISTINCT d.prd_id,
	c.concept_code
FROM source_data d
JOIN drug_concept_stage c ON c.concept_class_id = 'Supplier'
	AND c.concept_name = d.manufacturer_name
WHERE d.prd_name NOT IN (
		SELECT prd_name
		FROM devices_mapped
		)
	AND d.gal_id != '-1';

DELETE
FROM drug_concept_stage
WHERE concept_class_id = 'Unit'
	AND concept_code = 'unknown';

INSERT INTO ds_stage
WITH a AS (
		SELECT prd_name
		FROM products_to_ingreds
		GROUP BY prd_name
		HAVING count(concept_id) = 1
		),
	SIMPLE AS (
		SELECT d.*
		FROM source_data d
		JOIN a ON a.prd_name = d.prd_name
		WHERE (
				d.prd_dosage != '0'
				OR d.prd_dosage2 != '0'
				OR d.prd_dosage3 != '0'
				)
			AND d.unit_name1 NOT LIKE '%!%%' ESCAPE '!'
			AND (
				d.unit_name1 NOT LIKE '%/%'
				OR unit_name1 = '% v/v'
				)
			AND d.prd_name NOT IN (
				SELECT *
				FROM devices_mapped
				)
		),
	percents AS (
		SELECT d.*
		FROM source_data d
		JOIN a ON a.prd_name = d.prd_name
		WHERE (
				d.prd_dosage != '0'
				OR d.prd_dosage2 != '0'
				OR d.prd_dosage3 != '0'
				)
			AND d.unit_name1 = '%'
			AND d.prd_name NOT IN (
				SELECT *
				FROM devices_mapped
				)
		),
	transderm AS (
		SELECT d.*
		FROM source_data d
		JOIN a ON a.prd_name = d.prd_name
		WHERE (
				d.prd_dosage != '0'
				OR d.prd_dosage2 != '0'
				OR d.prd_dosage3 != '0'
				)
			AND d.unit_name1 LIKE 'm_g/%h'
			AND d.prd_name NOT IN (
				SELECT *
				FROM devices_mapped
				)
		)
SELECT c1.concept_code AS drug_concept_code,
	c2.concept_code AS ingredient_concept_code,
	NULL::INT AS box_size,
	replace(SIMPLE.prd_dosage, ',', '.')::FLOAT AS amount_value,
	SIMPLE.unit_name1 AS amount_unit,
	NULL AS numerator_value,
	NULL AS numerator_unit,
	NULL AS denominator_value,
	NULL AS denominator_unit
FROM SIMPLE
JOIN drug_concept_stage c1 ON SIMPLE.prd_name = c1.concept_name
	AND concept_class_id = 'Drug Product'
JOIN products_to_ingreds p ON p.prd_name = SIMPLE.prd_name
JOIN drug_concept_stage c2 ON p.concept_name = c2.concept_name

UNION

SELECT c1.concept_code AS drug_concept_code,
	c2.concept_code AS ingredient_concept_code,
	NULL AS box_size,
	NULL AS amount_value,
	NULL AS amount_unit,
	10 * (replace(percents.prd_dosage, ',', '.')::FLOAT) AS numerator_value,
	'mg' AS denominator_unit, --mg
	1::FLOAT AS numerator_value,
	'ml' AS denominator_unit --ml
FROM percents
JOIN drug_concept_stage c1 ON percents.prd_name = c1.concept_name
	AND concept_class_id = 'Drug Product'
JOIN products_to_ingreds p ON p.prd_name = percents.prd_name
JOIN drug_concept_stage c2 ON p.concept_name = c2.concept_name

UNION

SELECT c1.concept_code AS drug_concept_code,
	c2.concept_code AS ingredient_concept_code,
	NULL AS box_size,
	replace(transderm.prd_dosage, ',', '.')::FLOAT AS amount_value,
	CASE 
		WHEN transderm.unit_id LIKE 'mg%'
			THEN 'mg' --mg
		ELSE 'mcg' --mcg
		END AS amount_unit,
	NULL AS numerator_value,
	NULL AS denominator_unit,
	NULL AS numerator_value,
	NULL AS denominator_unit
FROM transderm
JOIN drug_concept_stage c1 ON transderm.prd_name = c1.concept_name
	AND concept_class_id = 'Drug Product'
JOIN products_to_ingreds p ON p.prd_name = transderm.prd_name
JOIN drug_concept_stage c2 ON p.concept_name = c2.concept_name;

INSERT INTO relationship_to_concept --ingredients
SELECT DISTINCT d.concept_code,
	'LPD_Belgium' AS vocabulary_id,
	c.concept_id,
	c.precedence,
	NULL::FLOAT AS conversion_factor
FROM ingred_mapped c
JOIN drug_concept_stage d ON d.concept_class_id = 'Ingredient'
	AND d.concept_name = c.concept_name;

INSERT INTO relationship_to_concept --brands
SELECT DISTINCT d.concept_code,
	'LPD_Belgium' AS vocabulary_id,
	c.concept_id,
	NULL::INT,
	NULL::FLOAT
FROM brands_mapped c
JOIN drug_concept_stage d ON d.concept_class_id = 'Brand Name'
	AND coalesce(c.mast_prd_name, c.concept_name) = d.concept_name;

INSERT INTO relationship_to_concept --units
SELECT DISTINCT d.concept_code,
	'LPD_Belgium' AS vocabulary_id,
	c.concept_id,
	c.precedence,
	c.conversion_factor
FROM drug_concept_stage d
JOIN units_mapped c ON d.concept_class_id = 'Unit'
	AND d.concept_name = c.unit_name;

INSERT INTO relationship_to_concept --forms
SELECT DISTINCT d.concept_code,
	'LPD_Belgium' AS vocabulary_id,
	c.concept_id,
	c.precedence,
	NULL::FLOAT
FROM drug_concept_stage d
JOIN forms_mapped c ON d.concept_class_id = 'Dose Form'
	AND d.concept_name = c.drug_form;

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (
		SELECT d.concept_code
		FROM concept c
		JOIN drug_concept_stage d ON d.concept_name = c.concept_name
		WHERE concept_id IN (
				19136048,
				36878798,
				19049024,
				1036525,
				19125390,
				1394027,
				19066891,
				19010961,
				42899013,
				42899196,
				19043395,
				36878798
				)
		);

INSERT INTO relationship_to_concept
SELECT DISTINCT d.concept_code,
	'LPD_Belgium' AS vocabulary_id,
	c.concept_id,
	NULL::INT,
	NULL::FLOAT
FROM drug_concept_stage d
JOIN supplier_mapped c ON d.concept_class_id = 'Supplier'
	AND d.concept_name = c.manufacturer_name
WHERE c.concept_name IS NOT NULL;

--forms-guessing
INSERT INTO internal_relationship_stage
SELECT DISTINCT prd_id,
	CASE 
		WHEN prd_name LIKE '%INJECT%'
			OR prd_name LIKE '%SERINGU%'
			OR prd_name LIKE '%STYLO%'
			OR prd_name LIKE '% INJ %'
			THEN 'g29010'
		WHEN prd_name LIKE '%SOLUTION%'
			OR prd_name LIKE '%AMPOULES%'
			OR prd_name LIKE '%GOUTTES%'
			OR prd_name LIKE '%GUTT%'
			THEN 'g28919'
		WHEN prd_name LIKE '%POUR SUSPE%'
			THEN 'g29027'
		WHEN prd_name LIKE '%COMPRI%'
			OR prd_name LIKE '%TABS %'
			OR prd_name LIKE '% DRAG%'
			THEN 'g28901'
		WHEN prd_name LIKE '%POUDRE%'
			OR prd_name LIKE '% PDR %'
			THEN 'g28929'
		WHEN prd_name LIKE '%GELUL%'
			OR prd_name LIKE '%CAPS %'
			THEN 'g29033'
		WHEN prd_name LIKE '%SPRAY%'
			THEN 'g28926'
		WHEN prd_name LIKE '%CREME%'
			OR prd_name LIKE '%CREAM%'
			THEN 'g28920'
		WHEN prd_name LIKE '%LAVEMENTS%'
			OR prd_name LIKE '%LAVEMENTS%'
			THEN 'g28909'
		WHEN prd_name LIKE '%POMM%'
			THEN 'g28910'
		WHEN prd_name LIKE '%INHALAT%'
			THEN 'g28988'
		WHEN prd_name LIKE '%EFFERVESCENTS%'
			OR prd_name LIKE '%AMP%'
			THEN 'g28919'
		WHEN prd_name LIKE '% COMP%'
			OR prd_name LIKE '%TAB%'
			THEN 'g28901'
		WHEN prd_name LIKE '%PERFUS%'
			THEN 'g28987'
		WHEN prd_name LIKE '%BUCCAL%'
			THEN 'g29009'
		ELSE 'boo'
		END
FROM source_data
WHERE prd_id NOT IN (
		SELECT concept_code_1
		FROM internal_relationship_stage
		WHERE concept_code_2 LIKE 'g%'
		)
	AND prd_name NOT IN (
		SELECT *
		FROM devices_mapped
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 = 'boo';

DROP TABLE IF EXISTS map_auto;
CREATE TABLE map_auto AS
	WITH unmapped AS (
			SELECT DISTINCT d.count::INT,
				d.prd_id,
				regexp_replace(d.prd_name, ' (\d+) (\d+ ?(MG|MCG|G|UI|IU))', ' \1.\2', 'g') AS fixed_name,
				c.concept_id,
				c.concept_name
			FROM source_data d
			LEFT JOIN products_to_ingreds c ON c.prd_name = d.prd_name
			WHERE prd_id NOT IN (
					SELECT drug_concept_code
					FROM ds_stage
					)
				AND d.prd_name NOT IN (
					SELECT *
					FROM devices_mapped
					)
				AND d.prd_name ~ ' \d+?(MCG|MG|G) '
				AND concept_id IS NOT NULL
				AND (ARRAY(SELECT unnest(regexp_matches(d.prd_name, '((?:\d+)\.?(?:\d+)? ?(?:MCG|MG|G|UI|IU) )', 'g')))) [3] IS NULL
			),
		list AS (
			SELECT prd_id
			FROM unmapped
			WHERE count > 1
			GROUP BY prd_id
			HAVING count(concept_id) < 3
			)

SELECT DISTINCT u.count,
	u.prd_id,
	u.fixed_name,
	--amount 1
	regexp_replace(substring(u.fixed_name, '((\d+)?\.?(\d+ ?(MG|MCG|G|UI|IU)) )'), '[A-Z ]', '', 'g')::FLOAT AS a1,
	--unit 1
	lower(substring(u.fixed_name, '(?:\d+)?\.?(?:\d+ ?(MG|MCG|G|UI|IU)) ')) AS u1,
	--amount 2
	regexp_replace((ARRAY(SELECT unnest(regexp_matches(u.fixed_name, '((?:\d+)\.?(?:\d+ ?(?:MCG|MG|G|UI|IU)))', 'g')))) [2], '[A-Z ]', '', 'g')::FLOAT AS a2,
	--unit 2
	lower(substring((ARRAY(SELECT unnest(regexp_matches(u.fixed_name, '((?:\d+)\.?(?:\d+ ?(?:MCG|MG|G|UI|IU)))', 'g')))) [2], '[A-Z]+')) AS u2,
	min(u.concept_id) OVER (PARTITION BY u.prd_id) AS i1,
	max(u.concept_id) OVER (PARTITION BY u.prd_id) AS i2
FROM unmapped u
WHERE prd_id IN (
		SELECT *
		FROM list
		);

UPDATE map_auto
SET i2 = NULL
WHERE i1 = i2;

ALTER TABLE map_auto ADD UC1 INT,
	ADD UC2 INT;

UPDATE map_auto
SET u1 = 'IU'
WHERE u1 = 'iu';

UPDATE map_auto
SET u2 = 'IU'
WHERE u2 = 'iu';

UPDATE map_auto
SET uc1 = 8504
WHERE u1 = 'g';

UPDATE map_auto
SET uc1 = 8576
WHERE u1 = 'mg';

UPDATE map_auto
SET uc1 = 9655
WHERE u1 = 'mcg';

UPDATE map_auto
SET uc1 = 8718
WHERE u1 = 'IU';

UPDATE map_auto
SET uc2 = 8504
WHERE u2 = 'g';

UPDATE map_auto
SET uc2 = 8576
WHERE u2 = 'mg';

UPDATE map_auto
SET uc2 = 9655
WHERE u2 = 'mcg';

UPDATE map_auto
SET uc2 = 8718
WHERE u2 = 'IU';

INSERT INTO ds_stage
SELECT m.PRD_ID,
	d.concept_code,
	NULL,
	A1,
	U1,
	NULL,
	NULL,
	NULL,
	NULL
FROM map_auto m
JOIN concept c ON m.i1 = c.concept_id
JOIN drug_concept_stage d ON c.concept_name = d.concept_name
	AND d.concept_class_id = 'Ingredient'
WHERE a2 IS NULL
	AND i2 IS NULL;

DROP TABLE IF EXISTS temp_dcs;
CREATE INDEX idx_c_name ON drug_concept_stage (concept_name);
analyze drug_concept_stage;

CREATE TABLE temp_dcs AS
	WITH options AS (
			SELECT COUNT,
				PRD_ID,
				I1,
				A1,
				U1,
				I2,
				A2,
				U2,
				uc1,
				uc2
			FROM map_auto m
			WHERE a2 IS NOT NULL
				AND i2 IS NOT NULL
			
			UNION
			
			SELECT COUNT,
				PRD_ID,
				I2,
				A1,
				U1,
				I1,
				A2,
				U2,
				uc1,
				uc2
			FROM map_auto m
			WHERE a2 IS NOT NULL
				AND i2 IS NOT NULL
			),
		matches AS (
			SELECT DISTINCT o.prd_id,
				d.drug_concept_id
			FROM drug_strength d
			JOIN options o ON d.ingredient_concept_id = o.i1
				AND d.amount_value = o.a1
				AND d.amount_unit_concept_id = o.uc1
				AND (
					SELECT drug_concept_id
					FROM drug_strength x
					WHERE x.ingredient_concept_id = o.i2
						AND x.amount_value = o.a2
						AND x.amount_unit_concept_id = o.uc2
						AND x.drug_concept_id = d.drug_concept_id
					) IS NOT NULL
			WHERE a2 IS NOT NULL
				AND i2 IS NOT NULL
			),
		double_trouble AS (
			SELECT d.drug_concept_id
			FROM drug_strength d
			WHERE drug_concept_id IN (
					SELECT drug_concept_id
					FROM matches
					)
			GROUP BY d.drug_concept_id
			HAVING count(DISTINCT CONCAT (
						d.ingredient_concept_id,
						' ',
						d.amount_value
						)) = 2
			)

SELECT DISTINCT m.prd_id,
	dcs.concept_code,
	ds.amount_value,
	CASE 
		WHEN ds.amount_unit_concept_id = 8504
			THEN 'g'
		WHEN ds.amount_unit_concept_id = 8576
			THEN 'mg'
		WHEN ds.amount_unit_concept_id = 9655
			THEN 'mcg'
		WHEN ds.amount_unit_concept_id = 8718
			THEN 'IU'
		ELSE NULL
		END AS amount_unit
FROM matches m
JOIN double_trouble dt ON dt.drug_concept_id = m.drug_concept_id
JOIN drug_strength ds ON m.drug_concept_id = ds.drug_concept_id
JOIN concept c ON ds.ingredient_concept_id = c.concept_id
JOIN drug_concept_stage dcs ON dcs.concept_name = c.concept_name
	AND dcs.concept_class_id = 'Ingredient';

DROP INDEX idx_c_name;

DELETE
FROM temp_dcs t
WHERE --hctz always the smallest, except for bisoprolol combinations
	prd_id IN (
		SELECT prd_id
		FROM temp_dcs
		GROUP BY prd_id
		HAVING count(concept_code) = 4
		)
	AND (
		prd_id IN (
			SELECT prd_id
			FROM temp_dcs
			WHERE concept_code = 'OMOP5301'
			)
		AND prd_id NOT IN (
			SELECT prd_id
			FROM temp_dcs
			WHERE concept_code = 'OMOP5701'
			)
		)
	AND (
		(
			concept_code = 'OMOP5301'
			AND t.amount_value > (
				SELECT amount_value
				FROM temp_dcs
				WHERE prd_id = t.prd_id
					AND concept_code != 'OMOP5301'
					AND amount_value != t.amount_value
				)
			)
		OR (
			t.amount_value < (
				SELECT amount_value
				FROM temp_dcs
				WHERE prd_id = t.prd_id
					AND concept_code = 'OMOP5301'
					AND amount_value != t.amount_value
				)
			)
		);

DELETE
FROM temp_dcs t
WHERE --caffeine < ergotamine
	prd_id IN (
		SELECT prd_id
		FROM temp_dcs
		WHERE concept_code = 'OMOP5319'
		)
	AND prd_id IN (
		SELECT prd_id
		FROM temp_dcs
		WHERE concept_code = 'OMOP4695'
		)
	AND (
		concept_code = 'OMOP5319'
		AND amount_value < (
			SELECT amount_value
			FROM temp_dcs
			WHERE prd_id = t.prd_id
				AND concept_code = 'OMOP4695'
				AND amount_value != t.amount_value
			)
		OR concept_code = 'OMOP4695'
		AND amount_value > (
			SELECT amount_value
			FROM temp_dcs
			WHERE prd_id = t.prd_id
				AND concept_code = 'OMOP5319'
				AND amount_value != t.amount_value
			)
		);

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
SELECT s.*,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL
FROM temp_dcs s
WHERE prd_id NOT IN (
		SELECT prd_id
		FROM temp_dcs
		GROUP BY prd_id
		HAVING count(concept_code) = 4
		);

DROP TABLE map_auto;

DELETE
FROM ds_stage
WHERE amount_unit = 'g'
	AND amount_value > 3
	AND drug_concept_code IN (
		SELECT prd_id
		FROM source_data
		WHERE unit_name1 = 'unknown'
		);--topical cremes

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT prd_id::VARCHAR
		FROM ds_manual
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT prd_id::VARCHAR
		FROM ds_manual
		)
	AND concept_code_2 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Ingredient'
		);

DROP TABLE IF EXISTS ingred_temp;
CREATE TABLE ingred_temp AS
SELECT DISTINCT concept_id,
	trim(concept_name) AS NAME
FROM ds_manual
WHERE TRIM(concept_name) NOT IN (
		SELECT trim(concept_name)
		FROM drug_concept_stage
		WHERE concept_class_id = 'Ingredient'
		);

INSERT INTO drug_concept_stage --in
SELECT TRIM(NAME),
	'LPD_Belgium' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	NULL AS source_concept_class_id,
	'S' AS standard_concept,
	'OMOP' || nextval('conc_stage_seq') AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM ingred_temp;

INSERT INTO internal_relationship_stage
SELECT DISTINCT d.prd_id,
	c.concept_code
FROM ds_manual d
JOIN drug_concept_stage c ON concept_class_id = 'Ingredient'
	AND c.concept_name = d.concept_name;

INSERT INTO relationship_to_concept --ingredients
SELECT DISTINCT d.concept_code,
	'LPD_Belgium' AS vocabulary_id,
	c.concept_id,
	NULL::INT AS precedence,
	NULL::FLOAT AS conversion_factor
FROM ingred_temp c
JOIN drug_concept_stage d ON d.concept_class_id = 'Ingredient'
	AND d.concept_name = c.NAME;

INSERT INTO ds_stage
SELECT DISTINCT d.prd_id,
	c.concept_code,
	box_size,
	CASE --amount
		WHEN denominator_value IS NOT NULL
			THEN NULL
		ELSE amount_value
		END,
	CASE 
		WHEN denominator_value IS NOT NULL
			THEN NULL
		ELSE amount_unit
		END,
	CASE --numerator
		WHEN denominator_value IS NULL
			THEN NULL
		ELSE amount_value
		END,
	CASE 
		WHEN denominator_value IS NULL
			THEN NULL
		ELSE amount_unit
		END,
	denominator_value,
	denominator_unit
FROM ds_manual d
JOIN drug_concept_stage c ON concept_class_id = 'Ingredient'
	AND c.concept_name = d.concept_name
WHERE amount_value IS NOT NULL;


UPDATE ds_stage d
SET box_size = i.new_box_size
FROM (
	SELECT substring(prd_name, '[^0-9]*(\d+)[^0-9]*$')::INT new_box_size,
		prd_id
	FROM source_data
	WHERE prd_name LIKE '% C %'
	) i
WHERE i.prd_id = d.drug_concept_code
	AND d.box_size IS NULL
	AND coalesce(d.denominator_unit, 'X') != 'actuat';


UPDATE ds_stage
SET box_size = NULL
WHERE box_size = 1;

DROP TABLE ingred_temp;

DELETE
FROM ds_stage
WHERE 0 IN (
		numerator_value,
		amount_value,
		denominator_value
		);

INSERT INTO relationship_to_concept --ingredients fix
WITH ingreds_unmapped AS (
		SELECT dcs.concept_code,
			cc.concept_id
		FROM drug_concept_stage dcs
		JOIN concept cc ON lower(cc.concept_name) = lower(dcs.concept_name)
			AND cc.concept_class_id = dcs.concept_class_id
			AND cc.vocabulary_id LIKE 'RxNorm%'
		LEFT JOIN relationship_to_concept cr ON dcs.concept_code = cr.concept_code_1
		WHERE concept_code_1 IS NULL
			AND cc.invalid_reason IS NULL
			AND dcs.concept_class_id IN ('Ingredient')
		)
SELECT DISTINCT c.concept_code,
	'LPD_Belgium' AS vocabulary_id,
	c.concept_id,
	NULL::INT AS precedence,
	NULL::FLOAT AS conversion_factor
FROM ingreds_unmapped c;

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM (
			SELECT drug_concept_code,
				ingredient_concept_code
			FROM ds_stage
			GROUP BY drug_concept_code,
				ingredient_concept_code
			HAVING COUNT(1) > 1
			) AS s0
		)
	AND ingredient_concept_code = 'OMOP3161973'
	AND amount_value = 40;

--delete from ds_stage where drug_concept_code in (8317575,8358514,8358515);
--insert into ds_stage values ('8358514','OMOP3163179',50,'mg',null,null,null,null,4);
--insert into ds_stage values ('8358515','OMOP3163179',50,'mg',null,null,null,null,4);
--insert into ds_stage values ('8317575','OMOP3163179',50,'mg',null,null,null,null,4);
DELETE
FROM ds_stage
WHERE 'ml' IN (
		lower(numerator_unit),
		lower(amount_unit)
		);

UPDATE relationship_to_concept a
SET conversion_factor = 1
WHERE conversion_factor IS NULL
	AND a.concept_code_1 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Unit'
		);

DELETE
FROM relationship_to_concept
WHERE (
		(
			concept_code_1,
			concept_id_2
			) IN (
			SELECT concept_code_1,
				concept_id_2
			FROM relationship_to_concept
			GROUP BY concept_code_1,
				concept_id_2
			HAVING COUNT(1) > 1
			)
		)
	AND precedence IS NULL;

--fix duplicates
DELETE
FROM internal_relationship_stage i
WHERE EXISTS (
		SELECT 1
		FROM internal_relationship_stage i_int
		WHERE i_int.concept_code_1 = i.concept_code_1
			AND i_int.concept_code_2 = i.concept_code_2
			AND i_int.ctid > i.ctid
		);

DELETE
FROM drug_concept_stage d
WHERE EXISTS (
		SELECT 1
		FROM drug_concept_stage d_int
		WHERE coalesce(d_int.concept_name, 'X') = coalesce(d.concept_name, 'X')
			AND coalesce(d_int.concept_class_id, 'X') = coalesce(d.concept_class_id, 'X')
			AND coalesce(d_int.source_concept_class_id, 'X') = coalesce(d.source_concept_class_id, 'X')
			AND coalesce(d_int.standard_concept, 'X') = coalesce(d.standard_concept, 'X')
			AND coalesce(d_int.concept_code, 'X') = coalesce(d.concept_code, 'X')
			AND coalesce(d_int.possible_excipient, 'X') = coalesce(d.possible_excipient, 'X')
			AND coalesce(d_int.domain_id, 'X') = coalesce(d.domain_id, 'X')
			AND d_int.ctid > d.ctid
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT concept_code
		FROM drug_concept_stage dcs
		JOIN (
			SELECT concept_code_1
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Supplier'
			LEFT JOIN ds_stage ON drug_concept_code = concept_code_1
			WHERE drug_concept_code IS NULL
			
			UNION
			
			SELECT concept_code_1
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
		)
	AND concept_code_2 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Supplier'
		);

DO $_$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(replace(concept_code, 'OMOP','')::int4)+1 into ex FROM concept WHERE concept_code like 'OMOP%'  and concept_code not like '% %';
	DROP SEQUENCE IF EXISTS new_vocab;
	EXECUTE 'CREATE SEQUENCE new_vocab INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END$_$;


DROP TABLE IF EXISTS code_replace;
CREATE TABLE code_replace AS
SELECT 'OMOP' || nextval('new_vocab') AS new_code,
	concept_code AS old_code
FROM (
	SELECT concept_code
	FROM drug_concept_stage
	WHERE concept_code LIKE 'OMOP%'
	GROUP BY concept_code
	ORDER BY LPAD(concept_code, 50, '0')
	) AS s0;

UPDATE drug_concept_stage a
SET concept_code = b.new_code
FROM code_replace b
WHERE a.concept_code = b.old_code;

UPDATE relationship_to_concept a
SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE ds_stage a
SET ingredient_concept_code = b.new_code
FROM code_replace b
WHERE a.ingredient_concept_code = b.old_code;

UPDATE ds_stage a
SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;

UPDATE internal_relationship_stage a
SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE internal_relationship_stage a
SET concept_code_2 = b.new_code
FROM code_replace b
WHERE a.concept_code_2 = b.old_code;

UPDATE pc_stage a
SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;

UPDATE drug_concept_stage
SET standard_concept = NULL
WHERE concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		JOIN internal_relationship_stage ON concept_code_1 = concept_code
		WHERE concept_class_id = 'Ingredient'
			AND standard_concept IS NOT NULL
		);