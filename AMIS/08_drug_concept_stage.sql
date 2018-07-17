--BN from drug_concept_stage
DROP TABLE IF EXISTS brand_name;
CREATE TABLE brand_name AS
SELECT DISTINCT initcap(brand_name) AS brand_name,
	'Brand Name'::VARCHAR AS concept_class_id
FROM source_table
WHERE upper(brand_name) NOT IN (
		SELECT upper(ingredient)
		FROM ingredient_translation_all
		)
	AND domain_id = 'Drug';

DELETE
FROM brand_name
WHERE brand_name IN (
		'Zink',
		'Xylometazolin',
		'Isopropylalkohol',
		'Isopropanol',
		'Vitamin E',
		'Vitamin C',
		'Citalopram',
		'Vitamin B6',
		'Vitamin B2',
		'Vitamin B12',
		'Vitamin B 12',
		'Vitamin A',
		'Trospium',
		'Tramadol',
		'Somatostatin',
		'Metformin',
		'Mianserin',
		'Mesalmin',
		'Gentamicin',
		'Belladonna',
		'Amlodipin',
		'2- Propanol',
		'5-Fluorouracil',
		'Amiodaron',
		'Apomorphin',
		'Atorvastatin',
		'Buprenorphine',
		'Amitriptylin',
		'Ambroxol',
		'Benalapril',
		'Faktor VIII',
		'Epoprostenol',
		'Meronem',
		'Magnesium',
		'Magnesiumsulfat',
		'Leucovorin',
		'Levocetirizin',
		'Levofloxacin',
		'Lactose'
		);

DELETE
FROM brand_name
WHERE brand_name LIKE '%Abnobaviscum%'
	OR brand_name LIKE '%/%'
	OR brand_name LIKE '%Glycerol%'
	OR brand_name LIKE '%Comp.%'
	OR brand_name LIKE '% Cum%'
	OR brand_name = 'Mg'
	AND brand_name NOT LIKE '%Pharma%'
	AND brand_name NOT LIKE '%Hexal%'
	AND brand_name NOT LIKE '%Mylan%'
	AND brand_name NOT LIKE '%Ratiopharm%'
	AND brand_name NOT LIKE '%Stada%'
	AND brand_name NOT LIKE '%Jubilant%'
	AND brand_name NOT LIKE '%Zentiva%'
	AND brand_name NOT LIKE '%Sandoz%'
	AND brand_name NOT LIKE '% Heumann%'
	AND brand_name NOT LIKE '%Healthcare%'
	AND brand_name NOT LIKE '% Abz%'
	AND brand_name NOT LIKE '%Axcount%'
	AND brand_name NOT LIKE '%Aristo%'
	AND brand_name NOT LIKE '%Krugmann%'
	AND brand_name NOT LIKE '%Eberth%'
	AND brand_name NOT LIKE '%Liconsa%'
	AND brand_name NOT LIKE '%Aurobindo%'
	AND brand_name NOT LIKE '%Basics%';

DROP TABLE IF EXISTS dsc_bn;
CREATE TABLE dcs_bn AS
SELECT brand_name AS concept_name,
	concept_class_id,
	'OMOP' || nextval('new_voc') AS concept_code
FROM brand_name;


--drugs for drug_concept_stage
DROP TABLE IF EXISTS dcs_drug;
CREATE TABLE dcs_drug AS
SELECT a.drug_code AS concept_code,
	'Quant Drug'::VARCHAR AS concept_class_id,
	b.drug_name AS concept_name
FROM strength_tmp a
LEFT JOIN st_5 b ON b.new_code = a.drug_code
WHERE b.new_code IS NOT NULL
	AND b.box_size IS NULL

UNION

SELECT a.drug_code AS concept_code,
	'Drug Box'::VARCHAR AS concept_class_id,
	b.drug_name AS concept_name
FROM strength_tmp a
LEFT JOIN st_5 b ON b.new_code = a.drug_code
WHERE b.new_code IS NOT NULL
	AND b.box_size IS NOT NULL

UNION

SELECT enr AS concept_code,
	'Drug Pack'::VARCHAR AS concept_class_id,
	CONCAT (
		am,
		' [Drug Pack]'
		)
FROM source_table_pack

UNION

SELECT a.drug_code AS concept_code,
	'Drug'::VARCHAR AS concept_class_id,
	CONCAT (
		st.am,
		' [Drug]'
		) AS concept_name
FROM strength_tmp a
LEFT JOIN st_5 b ON b.new_code = a.drug_code
LEFT JOIN source_table st ON st.enr = a.drug_code
WHERE b.new_code IS NULL
	AND st.enr IS NOT NULL

UNION

SELECT a.drug_code AS concept_code,
	'Drug'::VARCHAR AS concept_class_id,
	CONCAT (
		stp.am,
		' [Drug]'
		) AS concept_name
FROM strength_tmp a
LEFT JOIN st_5 b ON b.new_code = a.drug_code
LEFT JOIN source_table_pack stp ON stp.drug_code = a.drug_code
WHERE b.new_code IS NULL
	AND stp.enr IS NOT NULL;

--form for drug_concept_stage
DROP TABLE IF EXISTS forms;
CREATE TABLE forms AS
SELECT DISTINCT initcap(concept_name_1) AS concept_name,
	'Dose Form'::VARCHAR AS concept_class_id
FROM form_translation_all;

DROP TABLE IF EXISTS dcs_form;
CREATE TABLE dcs_form AS
SELECT concept_name,
	concept_class_id,
	'OMOP' || nextval('new_voc') AS concept_code
FROM forms;


--unit for drug_concept_stage
DROP TABLE IF EXISTS unit;
CREATE TABLE unit AS
SELECT amount_unit
FROM strength_tmp
WHERE amount_unit IS NOT NULL

UNION

SELECT numerator_unit
FROM strength_tmp
WHERE numerator_unit IS NOT NULL

UNION

SELECT denominator_unit
FROM strength_tmp
WHERE denominator_unit IS NOT NULL;

DROP TABLE IF EXISTS dcs_unit;
CREATE TABLE dcs_unit AS
SELECT DISTINCT amount_unit AS concept_name,
	amount_unit AS concept_code,
	'Unit'::VARCHAR AS concept_class_id
FROM unit
WHERE amount_unit IS NOT NULL;

-- manufacturer for drug_concept_stage
DROP TABLE IF EXISTS manuf;
CREATE TABLE manuf AS
SELECT DISTINCT TRIM((ARRAY(SELECT unnest(regexp_matches(adrantl, '[^,]+', 'g')))) [2]) as concept_name,
	'Manufacturer'::VARCHAR AS concept_class_id
FROM source_table;

DROP TABLE IF EXISTS dcs_manuf;
CREATE TABLE dcs_manuf AS
SELECT 'OMOP' || nextval('new_voc') AS concept_code,
	concept_name,
	concept_class_id
FROM manuf;

DROP TABLE IF EXISTS dcs_ingr;
CREATE TABLE dcs_ingr AS
SELECT DISTINCT ingredient_code AS concept_code,
	lower(translation) AS concept_name,
	'Ingredient'::VARCHAR AS concept_class_id
FROM ingredient_translation_all;

--CONCEPT-STAGE CREATION
TRUNCATE TABLE drug_concept_stage;
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	pack_size,
	domain_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT concept_name,
	'AMIS',
	concept_class_id,
	NULL,
	concept_code,
	NULL,
	NULL,
	'Drug',
	TO_DATE('20160601', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL
FROM (
	SELECT concept_name,
		concept_class_id,
		concept_code::VARCHAR(255) AS concept_code
	FROM dcs_unit
	
	UNION
	
	SELECT concept_name,
		concept_class_id,
		concept_code::VARCHAR(255) AS concept_code
	FROM dcs_form
	
	UNION
	
	SELECT concept_name,
		concept_class_id,
		concept_code::VARCHAR(255)
	FROM dcs_bn
	
	UNION
	
	SELECT concept_name,
		concept_class_id,
		concept_code::VARCHAR(255)
	FROM dcs_manuf
	
	UNION
	
	SELECT concept_name,
		concept_class_id,
		concept_code::VARCHAR(255)
	FROM dcs_drug
	
	UNION
	
	SELECT concept_name,
		concept_class_id,
		concept_code::VARCHAR(255)
	FROM dcs_ingr
	
	UNION
	
	SELECT CONCAT (
			am,
			' [Drug Pack]'
			) AS concept_name,
		'Drug Pack'::VARCHAR AS concept_class_id,
		concept_code::VARCHAR(255)
	FROM stp_2
	JOIN source_table st ON st.enr = stp_2.enr
	) AS s0;

UPDATE drug_concept_stage dcs
SET standard_concept = 'S'
WHERE concept_class_id NOT IN (
		'Brand Name',
		'Dose Form',
		'Unit',
		'Ingredient',
		'Manufacturer'
		);

UPDATE drug_concept_stage dcs
SET standard_concept = 'S'
FROM (
	SELECT concept_name,
		MIN(concept_code) m
	FROM drug_concept_stage
	WHERE concept_class_id = 'Ingredient'
	GROUP BY concept_name
	HAVING count(concept_code) > 1
	) d
WHERE d.m = dcs.concept_code;