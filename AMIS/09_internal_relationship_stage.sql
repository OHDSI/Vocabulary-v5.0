TRUNCATE TABLE internal_relationship_stage;

INSERT INTO internal_relationship_stage
-- DRUG - BN
SELECT enr concept_code_1,
	bn.concept_code concept_code_2
FROM source_table st
JOIN dcs_bn bn ON bn.concept_name = initcap(st.brand_name)

UNION

SELECT stp.drug_code concept_code_1,
	bn.concept_code concept_code_2
FROM source_table st
JOIN source_table_pack stp ON stp.enr = st.enr
JOIN dcs_bn bn ON bn.concept_name = initcap(st.brand_name)

UNION

SELECT st_5.new_code concept_code_1,
	bn.concept_code concept_code_2
FROM source_table st
JOIN st_5 ON st_5.drug_code = st.enr
JOIN dcs_bn bn ON bn.concept_name = initcap(st.brand_name)

UNION

-- DRUG - FORM
--XXX form_transl_map / AUT_FORM_ALL_MAPPED
SELECT st.enr concept_code_1,
	f.concept_code concept_code_2
FROM source_table st
JOIN form_translation_all fm ON upper(fm.form) = upper(st.dfo)
JOIN dcs_form f ON upper(f.concept_name) = upper(fm.concept_name_1)
LEFT JOIN source_table_pack stp ON stp.enr = st.enr
WHERE stp.enr IS NULL

UNION

SELECT stp.drug_code concept_code_1,
	f.concept_code concept_code_2
FROM source_table_pack stp
JOIN form_translation_all fm ON upper(fm.form) = upper(stp.dfo)
JOIN dcs_form f ON upper(f.concept_name) = upper(fm.concept_name_1)

UNION

SELECT s.new_code concept_code_1,
	f.concept_code concept_code_2
FROM st_5 s
JOIN source_table st ON s.drug_code = st.enr
JOIN form_translation_all fm ON upper(fm.form) = upper(st.dfo)
JOIN dcs_form f ON upper(f.concept_name) = upper(fm.concept_name_1)

UNION

SELECT s.new_code concept_code_1,
	fs.concept_code concept_code_2
FROM st_5 s
JOIN source_table_pack stp ON s.drug_code = stp.drug_code
JOIN form_translation_all fma ON upper(fma.form) = upper(stp.dfo)
JOIN dcs_form fs ON upper(fs.concept_name) = upper(fma.concept_name_1)

UNION

-- DRUG - INGREDIENT
SELECT drug_code concept_code_1,
	ingredient_code concept_code_2
FROM strength_tmp s
JOIN drug_concept_stage d ON d.concept_code = s.drug_code

UNION

-- DRUG - MANUFACTURER
SELECT stp.drug_code concept_code_1,
	m.concept_code concept_code_2
FROM source_table_pack stp
JOIN dcs_manuf m ON m.concept_name = TRIM((ARRAY(SELECT unnest(regexp_matches(adrantl, '[^,]+', 'g')))) [2])

UNION

SELECT enr concept_code_1,
	m.concept_code concept_code_2
FROM source_table
JOIN dcs_manuf m ON m.concept_name = TRIM((ARRAY(SELECT unnest(regexp_matches(adrantl, '[^,]+', 'g')))) [2])

UNION

SELECT new_code concept_code_1,
	m.concept_code concept_code_2
FROM st_5 s
JOIN source_table st ON s.drug_code = st.enr
JOIN dcs_manuf m ON m.concept_name = TRIM((ARRAY(SELECT unnest(regexp_matches(adrantl, '[^,]+', 'g')))) [2])

UNION

SELECT new_code concept_code_1,
	m.concept_code concept_code_2
FROM st_5 s
JOIN source_table_pack stp ON s.drug_code = stp.drug_Code
JOIN dcs_manuf m ON m.concept_name = TRIM((ARRAY(SELECT unnest(regexp_matches(adrantl, '[^,]+', 'g')))) [2])

UNION

SELECT stp.concept_code concept_code_1,
	m.concept_code concept_code_2
FROM stp_3 stp
JOIN source_table s ON stp.enr = s.enr
JOIN dcs_manuf m ON m.concept_name = TRIM((ARRAY(SELECT unnest(regexp_matches(adrantl, '[^,]+', 'g')))) [2])

UNION

--standard ingr-ingr
SELECT b.concept_code concept_code_1,
	a.concept_code concept_Code_2
FROM drug_concept_stage a
JOIN drug_concept_stage b ON a.concept_name = b.concept_name
WHERE a.concept_name IN (
		SELECT concept_name
		FROM drug_concept_stage
		GROUP BY concept_name
		HAVING count(*) > 1
		)
	AND a.concept_class_id = 'Ingredient'
	AND a.standard_concept = 'S'
	AND b.standard_concept IS NULL;


-- XXX forms that correspond only to non-drugs
--select * from dcs_form f JOIN form_translation_all fm ON f.concept_name = fm.concept_name_1
--LEFT JOIN source_table st ON st.dfo=fm.form AND st.domain_id = 'Drug'
--WHERE st.domain_id IS NULL;
