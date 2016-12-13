truncate table INTERNAL_RELATIONSHIP_STAGE;
insert into INTERNAL_RELATIONSHIP_STAGE (CONCEPT_CODE_1, CONCEPT_CODE_2)
select distinct fo_prd_id as CONCEPT_CODE_1,CONCEPT_CODE as concept_code_2 
from drugs inner join (select CONCEPT_NAME, CONCEPT_CODE from DRUG_CONCEPT_STAGE where CONCEPT_CLASS_ID = 'Supplier')
on MANUFACTURER = CONCEPT_NAME
union
select distinct FO_PRD_ID,CONCEPT_CODE from bn join (select CONCEPT_NAME, CONCEPT_CODE from drug_concept_stage where CONCEPT_CLASS_ID = 'Brand Name')
on trim(NEW_NAME) = CONCEPT_NAME
union
select distinct fo_prd_id, concept_code from ingredients  inner join (select CONCEPT_NAME,concept_code from drug_concept_stage where CONCEPT_CLASS_ID like 'Ingredient')
on INGREDIENT = CONCEPT_NAME
union
select distinct fo_prd_id, concept_code from dose_form_test join (select CONCEPT_NAME, CONCEPT_CODE from drug_concept_stage where CONCEPT_CLASS_ID = 'Dose Form')
on dose_form=concept_name;


insert into INTERNAL_RELATIONSHIP_STAGE (CONCEPT_CODE_1, CONCEPT_CODE_2)
select a.concept_code as concept_code_1, b.concept_code as concept_code_2 from drug_concept_stage a
join 
(select prd_name, concept_code from pack_drug_product join drug_concept_stage on trim(manufacturer) = concept_name WHERE PRD_NAME NOT LIKE 'INACTIVE TABLET') b 
on a.concept_name=trim(prd_name) 
union
select distinct concept_code as concept_code_1, nfc_code as concept_code_2 from list join pack_drug_product on CONCEPT_NAME=PRD_NAME where nfc_code is not null
and CONCEPT_CLASS_ID='Drug Product' AND CONCEPT_NAME NOT LIKE 'INACTIVE TABLET';

