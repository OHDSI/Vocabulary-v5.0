create table not_drugs_2 as (
select PRODUCT_DESC,FORM_DESC,DOSAGE,DOSAGE_ADD,VOLUME,PACKSIZE,CLAATC,PFC,MOLECULE,CD_NFC_3,ENGLISH,LB_NFC_3,DESCR_PCK,STRG_UNIT,STRG_MEAS,INVALID_REASON as concept_type 
from not_drugs --not_drugs is munual created table with concepts aren't drugs
union
select PRODUCT_DESC,FORM_DESC,DOSAGE,DOSAGE_ADD,VOLUME,PACKSIZE,CLAATC,PFC,MOLECULE,CD_NFC_3,ENGLISH,LB_NFC_3,DESCR_PCK,STRG_UNIT,STRG_MEAS,
 'Non Human Usage Products' as concept_type from ims_map.france  where english = 'Non Human Usage Products')
 ;
select PRODUCT_DESC,FORM_DESC,DOSAGE,DOSAGE_ADD,VOLUME,PACKSIZE,CLAATC,PFC,MOLECULE,CD_NFC_3,ENGLISH,LB_NFC_3,DESCR_PCK,STRG_UNIT,STRG_MEAS,INVALID_REASON from not_drugs 
;
drop table non_drug_concept_stage;
create table non_drug_concept_stage as (
select cast (CONCEPT_NAME as varchar (300)) as concept_name,VOCABULARY_ID,cast (CONCEPT_CLASS_ID as varchar (250)) as 
concept_class_id,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,VALID_START_DATE,VALID_END_DATE,INVALID_REASON, cast ('' as varchar (20)) as domain_id 
from drug_concept_stage 
 where rownum = 0)
 ;
insert into non_drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID, concept_class_id,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,VALID_START_DATE,VALID_END_DATE,INVALID_REASON, domain_id )
(select   volume||' '||case molecule 
 when 'NULL' then '' else molecule||' ' end||case dosage
  when 'NULL' then '' else dosage||' ' end||case dosage_add
  when 'NULL' then '' else dosage_add||' ' end||case form_desc when 'NULL' then '' else form_desc 
   end||case product_desc when 'NULL' then '' else ' ['||product_desc||']' end||' Box of '||packsize as concept_name, 'Da_France', concept_type, '', pfc, '', TO_DATE('2015/12/12', 'yyyy/mm/dd') as valid_start_date,
TO_DATE('2099/12/30', 'yyyy/mm/dd') as valid_end_date, '', ''
from not_drugs_2)
;
update non_drug_concept_stage  
set domain_id = 'Device' 
;
update non_drug_concept_stage
set CONCEPT_NAME = trim(CONCEPT_NAME)
;
delete from non_drug_concept_stage where concept_code is null
;
update  non_drug_concept_stage
set concept_class_id = 'Medical supply' where lower (concept_class_id) in ('supplement')
;
update  non_drug_concept_stage
set concept_class_id = 'Cosmetic' where lower (concept_class_id) in ('cosmetics')
;
update  non_drug_concept_stage
set concept_class_id = 'Nutritional supplement' where lower (concept_class_id) in ('nutrition')
;
update  non_drug_concept_stage
set concept_class_id = 'Device' where lower (concept_class_id) in ('contrast agent', 'non human usage products', 'non pharmaceutical ingredient', 'test', 'device', 'not_a_drug' )
;
update non_drug_concept_stage
set concept_name = regexp_replace (concept_name, '\s+', ' ')
;
update non_drug_concept_stage
set domain_id = 'Observation' where concept_class_id in ('Nutritional supplement' , 'Cosmetic')
;
update non_drug_concept_stage
set domain_id = 'Device' where concept_class_id in ('Nutritional supplement')
;
update non_drug_concept_stage
set concept_class_id = 'Device' where lower( concept_class_id) in ('supplement')
;
drop table non_drug_concept_stage_2;
create table non_drug_concept_stage_2 as (
select distinct CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,VALID_START_DATE,VALID_END_DATE,INVALID_REASON,DOMAIN_ID from non_drug_concept_stage)
;
DELETE
FROM NON_DRUG_CONCEPT_STAGE_2
WHERE CONCEPT_NAME = 'NUTRITIONAL SUPPLEMENTS TTES FORMES [FORTIMEL CR ALIM] Box of 1'
AND   CONCEPT_CODE = '4634911';
DELETE
FROM NON_DRUG_CONCEPT_STAGE_2
WHERE CONCEPT_NAME = 'NUTRITIONAL SUPPLEMENTS TTES FORMES [DELICAL BOIS.HP HC] Box of 1'
AND   CONCEPT_CODE = '3894113';
DELETE
FROM NON_DRUG_CONCEPT_STAGE_2
WHERE CONCEPT_NAME = 'GENERAL NUTRIENTS TS PARFUMS [RESOURCE] Box of 1'
AND   CONCEPT_CODE = '3553001';
DELETE
FROM NON_DRUG_CONCEPT_STAGE_2
WHERE CONCEPT_NAME = 'EYE OCCLUSION PATCH PANS ENF [OPTICLUDE] Box of 20'
AND   CONCEPT_CODE = '9756903';
DELETE
FROM NON_DRUG_CONCEPT_STAGE_2
WHERE CONCEPT_NAME = 'CREAMS (BASIS) TTES FORMES [DERMABLEND] Box of 1'
AND   CONCEPT_CODE = '3075617';
DELETE
FROM NON_DRUG_CONCEPT_STAGE_2
WHERE CONCEPT_NAME = 'ANTI-DANDRUFF SHAMPOO TTES FORMES [KERIUM SHAMPOOING] Box of 1'
AND   CONCEPT_CODE = '3457504';
DELETE
FROM NON_DRUG_CONCEPT_STAGE_2
WHERE CONCEPT_NAME = '200G INFANT MILKS TTES FORMES [LAXEOV] Box of 1'
AND   CONCEPT_CODE = '3112905';

;
drop table non_drug_concept_stage;
create   table non_drug_concept_stage
as
(select * from non_drug_concept_stage_2)
;
drop table non_drug_concept_stage_2 purge 
;
update non_drug_concept_stage
set concept_class_id = 'Supplement' where concept_class_id = 'Nutritional supplement'
;
UPDATE NON_DRUG_CONCEPT_STAGE
   SET CONCEPT_NAME = 'NICOTINAMIDE+ASCORBIC ACID+PYRIDOXINE+PANTOTHENIC ACID... TTES FORMES [AZINC OPTIMAL] Box of 1'
WHERE CONCEPT_CODE = '3061407';
