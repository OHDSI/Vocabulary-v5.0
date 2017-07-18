--fill drug_concept_stage

insert into DRUG_concept_STAGE (CONCEPT_NAME,VOCABULARY_ID,DOMAIN_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select CONCEPT_NAME, 'DA_France','Drug', CONCEPT_CLASS_ID, 'S', CONCEPT_CODE, '', TO_DATE(sysdate, 'yyyy/mm/dd') as valid_start_date, --check start date
TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date, ''
 from (
 select * from list_temp
 union 
 select * from drug_products
 union 
 select * from unit)
;

--DEVICES (rebuild names)
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,DOMAIN_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct
substr(volume||' '||case molecule 
 when 'NULL' then '' else molecule||' ' end||case dosage
  when 'NULL' then '' else dosage||' ' end||case dosage_add
  when 'NULL' then '' else dosage_add||' ' end||case form_desc when 'NULL' then '' else form_desc 
   end||case product_desc when 'NULL' then '' else ' ['||product_desc||']' end||' Box of '||packsize , 1,255
   )
      as concept_name, 'DA_France','Device', 'Device', 'S', pfc, '', TO_DATE(sysdate, 'yyyy/mm/dd') as valid_start_date, --check start date
TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date, ''
from non_drugs;


--fill IRS
--Drug to Ingredients

insert into internal_relationship_stage
select distinct pfc, concept_code from list_temp a join ingr using (concept_name,concept_class_id)
;
--drug to Brand Name
insert into internal_relationship_stage
select distinct pfc, concept_code from list_temp a join brand using (concept_name,concept_class_id)
;
--drug to Dose Form

insert into internal_relationship_stage
select distinct pfc, concept_code
from france_1 a join france_names_translation b on a.LB_NFC_3=b.DOSE_FORM
join drug_concept_stage c on b.dose_form_name = c.concept_name and concept_class_id='Dose Form'
;
commit;
