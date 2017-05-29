--manufacturers
create table dcs_manufacturer as 
(select distinct manufacturer as concept_name,'Supplier' as concept_class_id from drug);
update dcs_manufacturer
 set concept_name=ltrim(concept_name,' ');

--Parsing drug description extracting brand names 
create table brand_name as (select regexp_substr (drug_descr, '^([A-Z]+(\s)?-?/?[A-Z]+(\s)?[A-Z]?)+') as brand_name,drug_code from drug where drug_descr not like '%degré de dilution compris entre%' and regexp_substr (drug_descr, '^([A-Z]+(\s)?-?[A-Z]+)+') is not null) ;
UPDATE BRAND_NAME   SET BRAND_NAME = 'NP100 PREMATURES AP-HP' WHERE DRUG_CODE = '60208447';
UPDATE BRAND_NAME   SET BRAND_NAME = 'NP2 ENFANTS AP-HP' WHERE DRUG_CODE = '66809426';
UPDATE BRAND_NAME  SET BRAND_NAME = 'PO 12 2 POUR CENT' WHERE DRUG_CODE = '64593595';
update brand_name 
 set brand_name=rtrim(brand_name,' ');
 --Brand name = Ingredient (RxNorm)
delete brand_name where upper(brand_name) in (select upper(concept_name) from devv5.concept where concept_Class_id='Ingredient');
 --Brand name = Ingredient (BDPM translated)
delete brand_name where lower(brand_name) in (select lower(translation) from ingr_translation_all)
;
 --Brand name = Ingredient (BDPM original)
delete brand_name where lower(brand_name) in (select lower(CONCEPT_NAME) from ingr_translation_all); 
--list for drug_concept_stage
create table dcs_bn as (
select distinct brand_name as concept_name, 'Brand Name' as concept_class_id from brand_name 
where brand_name not in (select brand_name from BRAND_NAME_EXCEPTION-- previously created table with Brand names similar to ingredients
)
and drug_code not in (select drug_code from non_drug));

--list of Dose Form (translated before)
create table list as (
select distinct translation as concept_name ,'Dose Form' as concept_class_id,'1000000000' as concept_Code from FORM_TRANSLATION --manual table
union
--Brand Names
select distinct concept_name,concept_class_id,'100000000000' from dcs_bn
union 
--manufacturers
select distinct concept_name,concept_class_id,'100000000000' from dcs_manufacturer
);

--temporary sequence 
CREATE SEQUENCE new_vocc
  MINVALUE 1
  MAXVALUE 1000000
  START WITH 1
  INCREMENT BY 1
  CACHE 100;
  --put OMOP||numbers
update list
set concept_code='OMOP'||new_vocc.nextval;
;
--Fill drug_concept_stage
--Drug Product
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select SUBSTR( d.drug_descr,1, 240) ,'BDPM', 'Drug Product', '', cast (din_7 as varchar (200)), '', 'Drug', APPROVAL_DATE, TO_DATE ('20991231', 'yyyymmdd'), ''
from drug d join packaging p on p.drug_code = d.drug_code
where d.drug_code not in( select drug_code from non_drug)
and d.drug_code not in( select drug_code from pack_st_1)
;
--Device
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select SUBSTR( d.drug_descr,1, 240) ,'BDPM', 'Device', '', cast (din_7 as varchar (200)), '', 'Device', APPROVAL_DATE, TO_DATE ('20991231', 'yyyymmdd'), ''
from drug d join packaging p on p.drug_code = d.drug_code
where d.drug_code  in( select drug_code from non_drug)
;
--Brand Names and Dose forms and manufacturers
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select concept_name,'BDPM', concept_class_id, '', CONCEPT_CODE, '', 'Drug', TO_DATE ('19700101', 'yyyymmdd'), TO_DATE ('20991231', 'yyyymmdd'), ''
from list
;
-- units 
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct CONCEPT_CODE,'BDPM', 'Unit', '', CONCEPT_CODE, '', 'Unit', TO_DATE ('19700101', 'yyyymmdd'), TO_DATE ('20991231', 'yyyymmdd'), ''
from aut_unit_all_mapped
;
-- Pack_components 
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct SUBSTR(PACK_COMPONENT_NAME,1, 240) ,'BDPM', 'Drug Product', '', PACK_COMPONENT_CODE, '', 'Drug', TO_DATE ('19700101', 'yyyymmdd'), TO_DATE ('20991231', 'yyyymmdd'), ''
from PACK_CONT_1
;
--Packs
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct SUBSTR(PACK_NAME,1, 240) ,'BDPM', 'Drug Pack', '', CONCEPT_CODE, '', 'Drug', TO_DATE ('19700101', 'yyyymmdd'), TO_DATE ('20991231', 'yyyymmdd'), ''
from PACK_CONT_1
;
--Ingredients 
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct TRANSLATION ,'BDPM', 'Ingredient', '', concept_code, '', 'Drug', TO_DATE ('19700101', 'yyyymmdd'), TO_DATE ('20991231', 'yyyymmdd'), ''
from ingr_translation_all 
;
--standard concept definition, not sure if we need this
MERGE
INTO    drug_concept_stage dcs
USING   (
select concept_name, concept_code from drug_concept_stage WHERE concept_class_id NOT IN ('Brand Name', 'Dose Form', 'Unit', 'Ingredient', 'Supplier') 
) d ON (d.concept_code=dcs.concept_code)
WHEN MATCHED THEN UPDATE
    SET dcs.standard_concept = 'S'
;
--standard concept definition, not sure if we need this
MERGE
INTO    drug_concept_stage dcs
USING   (
select concept_name, MIN(concept_code) m from drug_concept_stage WHERE concept_class_id='Ingredient' group by concept_name having count(concept_name) > 1
) d ON (d.m=dcs.concept_code)
WHEN MATCHED THEN UPDATE
    SET dcs.standard_concept = 'S'
;
UPDATE drug_concept_stage
SET standard_concept='S' WHERE concept_class_id='Ingredient' 
and concept_name not in (select concept_name from drug_concept_stage WHERE concept_class_id='Ingredient' group by concept_name having count(concept_name) > 1)
;
--drug with no din7
INSERT INTO DRUG_CONCEPT_STAGE(  CONCEPT_NAME,  VOCABULARY_ID,  CONCEPT_CLASS_ID,  STANDARD_CONCEPT,  CONCEPT_CODE,  POSSIBLE_EXCIPIENT,  DOMAIN_ID,  VALID_START_DATE,  VALID_END_DATE,  INVALID_REASON)
VALUES(  'VACCIN RABIQUE INACTIVE MERIEUX, poudre et solvant pour suspension injectable. Vaccin rabique préparé sur cellules diploïdes humaines',  'BDPM',  'Drug Product',  'S',  '60253264',  NULL, 'Drug',  TO_TIMESTAMP('1996-01-07 00:06:00.000','YYYY-MM-DD HH24:MI:SS.FF'), TO_TIMESTAMP('2099-12-31 00:00:00.000','YYYY-MM-DD HH24:MI:SS.FF'),  NULL);
commit
;
