create table non_drugs as (
select PRODUCT_DESC,FORM_DESC,DOSAGE,DOSAGE_ADD,VOLUME,PACKSIZE,CLAATC,PFC,MOLECULE,CD_NFC_3,ENGLISH,LB_NFC_3,DESCR_PCK,STRG_UNIT,STRG_MEAS,  cast('' as varchar (250)) as concept_type from ims_map.france where MOLECULE
like '%BANDAGES%'
or MOLECULE like '% TEST%'
or MOLECULE like '%DEVICES%'
or MOLECULE like '%CARE PRODUCTS%'
or MOLECULE like 'CATHETERS'
or MOLECULE like 'EYE OCCLUSION PATCH'
or MOLECULE like 'INCONTINENCE COLLECTION APPLIANCES'
or  MOLECULE like '%SOAP%'
or MOLECULE like '%CREAM%'
or MOLECULE like '%HAIR%'
or MOLECULE like '%SHAMPOO%'
or MOLECULE like '%LOTION'
or MOLECULE like 'FACIAL CLEANSER'
or MOLECULE like 'LIP PROTECTANTS'
or MOLECULE like 'CLEANSING AGENTS'
or MOLECULE like '%SKIN%' 
or MOLECULE like 'TONICS'
or MOLECULE like 'TOOTHPASTES'
or MOLECULE like 'MOUTH'
or MOLECULE like '%LENS SOLUTIONS%'
or MOLECULE like '%INFANT %'
or MOLECULE like '%DISINFECTANT%'
or MOLECULE like '%ANTISEPTIC%'
or MOLECULE like 'CONDOMS'
or MOLECULE like '%COTTON WOOL%'
or MOLECULE like '%GENERAL NUTRIENTS%'
or MOLECULE like '%LUBRICANTS%'
or MOLECULE like 'INSECT REPELLENTS'
or MOLECULE like 'FOOD'
or MOLECULE like 'SLIMMING PREPARATIONS'
or MOLECULE like '%SPECIAL DIET%'
or MOLECULE like '%SWAB%'
or MOLECULE like '%WOUND%'
or LB_NFC_3 like '%NON US.HUMAIN%'
or lower(MOLECULE) like '%non medicated%'
or lower(MOLECULE) like 'non pharmaceutical%'
or MOLECULE like 'OTHERS%'
or english = 'Non Human Usage Products'
)
;
update non_drugs 
set concept_type ='Device'
where MOLECULE
like '%BANDAGES%'
or MOLECULE like '% TEST%'
or MOLECULE like '%DEVICES%'
or MOLECULE like '%CARE PRODUCTS%'
or MOLECULE like 'CATHETERS'
or MOLECULE like 'EYE OCCLUSION PATCH'
or MOLECULE like 'INCONTINENCE COLLECTION APPLIANCES'
;
update non_drugs
set concept_type='COSMETICS'
where 
  MOLECULE like '%SOAP%'
or MOLECULE like '%CREAM%'
or MOLECULE like '%HAIR%'
or MOLECULE like '%SHAMPOO%'
or MOLECULE like '%LOTION'
or MOLECULE like 'FACIAL CLEANSER'
or MOLECULE like 'LIP PROTECTANTS'
or MOLECULE like 'CLEANSING AGENTS'
or MOLECULE like '%SKIN%' 
or MOLECULE like 'TONICS'
or MOLECULE like 'TOOTHPASTES'
or MOLECULE like 'MOUTH'
;
update non_drugs
set concept_type='SUPPLEMENT'
where MOLECULE like '%LENS SOLUTIONS%'
or MOLECULE like '%INFANT %'
or MOLECULE like '%DISINFECTANT%'
or MOLECULE like '%ANTISEPTIC%'
or MOLECULE like 'CONDOMS'
or MOLECULE like '%COTTON WOOL%'
or MOLECULE like '%GENERAL NUTRIENTS%'
or MOLECULE like '%LUBRICANTS%'
or MOLECULE like 'INSECT REPELLENTS'
or MOLECULE like 'FOOD'
or MOLECULE like 'SLIMMING PREPARATIONS'
or MOLECULE like '%SPECIAL DIET%'
or MOLECULE like '%SWAB%'
or MOLECULE like '%WOUND%'
 ;

CREATE TABLE NON_DRUG_CONCEPT_STAGE
(
   CONCEPT_NAME        VARCHAR2(300 Byte),
   VOCABULARY_ID       VARCHAR2(20 Byte),
   CONCEPT_CLASS_ID    VARCHAR2(250 Byte),
   STANDARD_CONCEPT    VARCHAR2(1 Byte),
   CONCEPT_CODE        VARCHAR2(50 Byte),
   POSSIBLE_EXCIPIENT  VARCHAR2(1 Byte),
   VALID_START_DATE    DATE,
   VALID_END_DATE      DATE,
   INVALID_REASON      VARCHAR2(1 Byte),
   DOMAIN_ID           VARCHAR2(20 Byte)
)
 ;
insert into non_drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID, concept_class_id,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,VALID_START_DATE,VALID_END_DATE,INVALID_REASON, domain_id )
(select   volume||' '||case molecule 
 when 'NULL' then '' else molecule||' ' end||case dosage
  when 'NULL' then '' else dosage||' ' end||case dosage_add
  when 'NULL' then '' else dosage_add||' ' end||case form_desc when 'NULL' then '' else form_desc 
   end||case product_desc when 'NULL' then '' else ' ['||product_desc||']' end||' Box of '||packsize as concept_name, 'Da_France', concept_type, '', pfc, '', TO_DATE('2015/12/12', 'yyyy/mm/dd') as valid_start_date,
TO_DATE('2099/12/30', 'yyyy/mm/dd') as valid_end_date, '', ''
from non_drugs)
;
--updating concept_name
update non_drug_concept_stage
set CONCEPT_NAME = trim(CONCEPT_NAME)
;
update non_drug_concept_stage
set concept_name = regexp_replace (concept_name, '\s+', ' ')
;
--class definition
update  non_drug_concept_stage
set concept_class_id = 'Medical supply' where lower (concept_class_id) in ('supplement')
;
update  non_drug_concept_stage
set concept_class_id = 'Cosmetic' where lower (concept_class_id) in ('cosmetics')
;
update  non_drug_concept_stage
set concept_class_id = 'Supplement' where lower (concept_class_id) in ('nutrition')
;
update  non_drug_concept_stage
set concept_class_id = 'Device' where lower (concept_class_id) in ('contrast agent', 'non human usage products', 'non pharmaceutical ingredient', 'test', 'device' ) or concept_class_id is null
;
--domain definition
--all non-drug concepts are the devices except cosmetics
update non_drug_concept_stage  
set domain_id = 'Device' 
;
update non_drug_concept_stage
set domain_id = 'Observation' where concept_class_id in ('Cosmetic')
;
--delete duplicate columns
drop table non_drug_concept_stage_2;
create table non_drug_concept_stage_2 as (
select distinct CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,VALID_START_DATE,VALID_END_DATE,INVALID_REASON,DOMAIN_ID from non_drug_concept_stage)
;
drop table non_drug_concept_stage;
create   table non_drug_concept_stage
as
(select * from non_drug_concept_stage_2)
;
drop table non_drug_concept_stage_2 purge 
;
--cutting too long concept description
UPDATE NON_DRUG_CONCEPT_STAGE
   SET CONCEPT_NAME = 'NICOTINAMIDE+ASCORBIC ACID+PYRIDOXINE+PANTOTHENIC ACID... TTES FORMES [AZINC OPTIMAL] Box of 1'
WHERE CONCEPT_CODE = '3061407';

commit
;
