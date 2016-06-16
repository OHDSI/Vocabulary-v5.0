truncate table INTERNAL_RELATIONSHIP_STAGE;

INSERT INTO INTERNAL_RELATIONSHIP_STAGE
-- DRUG - BN
select enr concept_code_1, bn.CONCEPT_CODE concept_code_2  from source_table st JOIN dcs_bn bn ON bn.CONCEPT_NAME = initcap(st.BRAND_NAME)

union

select stp.drug_code concept_code_1, bn.CONCEPT_CODE concept_code_2  from source_table st JOIN source_table_pack stp ON stp.enr=st.enr JOIN dcs_bn bn ON bn.CONCEPT_NAME = initcap(st.BRAND_NAME)

union

select st_5.NEW_CODE concept_code_1, bn.CONCEPT_CODE concept_code_2  from source_table st 
JOIN st_5 ON st_5.DRUG_CODE=st.enr
JOIN dcs_bn bn ON bn.CONCEPT_NAME = initcap(st.BRAND_NAME)

union

-- DRUG - FORM
--XXX form_transl_map / AUT_FORM_ALL_MAPPED
select st.enr concept_code_1, f.CONCEPT_CODE concept_code_2  from source_table st 
JOIN form_translation_all fm ON upper(fm.form) = upper(st.DFO)
JOIN dcs_form f ON upper(f.CONCEPT_NAME) = upper(fm.CONCEPT_NAME_1)
LEFT JOIN source_table_pack stp ON stp.enr=st.enr
WHERE stp.enr IS NULL

union

select stp.drug_code concept_code_1, f.CONCEPT_CODE concept_code_2
from source_table_pack stp
JOIN form_translation_all fm ON upper(fm.form) = upper(stp.DFO)
JOIN dcs_form f ON upper(f.CONCEPT_NAME) = upper(fm.CONCEPT_NAME_1)

union

select distinct s.new_code concept_code_1, f.CONCEPT_CODE concept_code_2
from st_5 s
JOIN source_table st on s.drug_code=st.enr
JOIN form_translation_all fm ON upper(fm.form) = upper(st.DFO)
JOIN dcs_form f ON upper( f.CONCEPT_NAME) = upper(fm.CONCEPT_NAME_1)

union 

select distinct s.new_code concept_code_1, fs.CONCEPT_CODE concept_code_2
from st_5 s
JOIN source_table_pack stp on s.drug_code=stp.drug_code
JOIN form_translation_all fma ON upper(fma.form) = upper(stp.DFO)
JOIN dcs_form fs ON upper(fs.CONCEPT_NAME) = upper(fma.CONCEPT_NAME_1)


union

-- DRUG - INGREDIENT
select drug_code concept_code_1, INGREDIENT_CODE concept_code_2 from STRENGTH_TMP s
JOIN drug_concept_stage d on d.concept_code=s.drug_code

union

-- DRUG - MANUFACTURER
select stp.drug_code concept_code_1, m.concept_code concept_code_2 from source_table_pack stp
JOIN dcs_manuf m ON TRIM(REGEXP_SUBSTR(ADRANTL , '[^,]+', 1, 2))=concept_name

union

select enr concept_code_1, m.concept_code concept_code_2 from source_table 
JOIN dcs_manuf m on TRIM(REGEXP_SUBSTR(ADRANTL , '[^,]+', 1, 2))=concept_name

union

select new_code concept_code_1, m.concept_code concept_code_2 from st_5 s
JOIN source_table st on s.drug_code=st.enr
JOIN dcs_manuf m on TRIM(REGEXP_SUBSTR(ADRANTL , '[^,]+', 1, 2))=concept_name

union

select new_code concept_code_1, m.concept_code concept_code_2 from st_5 s
JOIN source_table_pack stp on s.drug_code=stp.drug_Code
JOIN dcs_manuf m on TRIM(REGEXP_SUBSTR(ADRANTL , '[^,]+', 1, 2))=concept_name

union

select stp.concept_code concept_code_1, m.concept_code concept_code_2 from stp_3 stp 
JOIN source_table s on stp.enr=s.enr
JOIN dcs_manuf m on TRIM(REGEXP_SUBSTR(ADRANTL , '[^,]+', 1, 2))=concept_name

union 
--standard ingr-ingr
select distinct b.concept_code concept_code_1,a.concept_code concept_Code_2 from drug_concept_stage  a join drug_concept_stage b on a.concept_name=b.concept_name
where a.concept_name in (
select concept_name from drug_concept_stage group by concept_name having count(8)>1) and a.concept_class_id='Ingredient' and a.standard_concept='S' and b.standard_concept is null
;


-- XXX forms that correspond only to non-drugs
--select * from dcs_form f JOIN form_translation_all fm ON f.CONCEPT_NAME = fm.CONCEPT_NAME_1
--LEFT JOIN source_table st ON st.DFO=fm.form AND st.domain_id = 'Drug'
--WHERE st.domain_id IS NULL;
