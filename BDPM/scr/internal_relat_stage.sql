--Drug to Ingredients
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select distinct drug_concept_code, ingredient_concept_code from ds_stage d
where d.drug_concept_code not in (select drug_code from non_drug)
and d.drug_concept_code not in (select PACK_COMPONENT_CODE from PACK_CONT_1)
;
--Pack Component to Ingredient
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select distinct drug_concept_code, ingredient_concept_code from ds_stage d
where d.drug_concept_code  in (select PACK_COMPONENT_CODE from PACK_CONT_1)
;
--Drug to Brand Name
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select distinct din_7, concept_code from brand_name b join drug_concept_stage d on lower ( brand_name) = lower ( concept_name ) and d.concept_class_id = 'Brand Name'
join packaging p on p.drug_code = b.drug_code
where b.drug_code not in (select drug_code from non_drug)
;
--Drug to Supplier 
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select distinct din_7, concept_code from drug b join drug_concept_stage  d on  lower ( manufacturer) = ' '||lower ( concept_name ) and d.concept_class_id = 'Supplier'
join packaging p on p.drug_code = b.drug_code
where b.drug_code not in (select drug_code from non_drug)
;
--Drug to Dose Form
--separately for packs and drugs 
--for drugs, excluding packs and non_drugs
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select distinct din_7, concept_code from drug d
join FORM_TRANSLATION on regexp_replace(form||' '||route,'  ',' ') = FORM_ROUTE
join drug_concept_stage on TRANSLATION = concept_name and  concept_class_id = 'Dose Form'
join packaging p on p.drug_code = d.drug_code
where d.drug_code not in (select drug_code from non_drug)
and d.drug_code not in (select CONCEPT_CODE from PACK_CONT_1)
;
-- Drug to Dose Form for Pack components 
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select PACK_COMPONENT_CODE,concept_code
from PF_FROM_PACK_COMP_LIST pf 
JOIN drug_concept_stage dcs on PACK_FORM=concept_name;
;
--Ingredient to Ingredient
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select * from CODE_INGRED_TO_INGRED;

--manualy defined same ingredients
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select distinct b.concept_code concept_code_1,a.concept_code concept_Code_2 from drug_concept_stage  a join drug_concept_stage b on a.concept_name=b.concept_name
where a.concept_name in (
select concept_name from drug_concept_stage group by concept_name having count(8)>1) 
and a.concept_class_id='Ingredient' and a.standard_concept='S' and b.standard_concept is null
and b.concept_code  not in (select cast (CONCEPT_CODE_2 as varchar (200)) from CODE_INGRED_TO_INGRED)
;
--drug doesn't have packaging
INSERT INTO INTERNAL_RELATIONSHIP_STAGE (  CONCEPT_CODE_1,  CONCEPT_CODE_2)
SELECT  '60253264',  concept_code from drug_concept_stage where concept_name='Injectable Solution';
INSERT INTO INTERNAL_RELATIONSHIP_STAGE (  CONCEPT_CODE_1,  CONCEPT_CODE_2)
SELECT  '60253264',  concept_code from drug_concept_stage where concept_name='VACCIN RABIQUE INACTIVE MERIEUX';
INSERT INTO INTERNAL_RELATIONSHIP_STAGE (  CONCEPT_CODE_1,  CONCEPT_CODE_2)
SELECT  '60253264',  concept_code from drug_concept_stage where concept_name='SANOFI PASTEUR';
;
