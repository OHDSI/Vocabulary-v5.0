--need to add proper header later

insert into concept_stage
dmd_drug_name as concept_name, -- this is not quite correct, we need the original Gemscript names.
'Drug' as domain_id,
'Gemscript' as vocabulary_id,
'Gemscript' as concept_class_id,
null as standard_concept,
gemscript_drug_code as concept_code,
latest_update as valid_start_date -- 1-Apr-2016
'31-Dec-2099' as valid_end_date,
null as invalid_reason
from gemscript_dmd_map;

insert into concept_relationship_stage
gemscript_drug_code as concept_code_1,
'Gemscript' as vocabulary_id_1,
dmd_code as concept_code_2,
'dm+d' as vocabulary_id_2,
'Maps to' as relationship_id,
latest_update as valid_start_date -- 1-Apr-2016
'31-Dec-2099' as valid_end_date,
null as invalid_reason
from gemscript_dmd_map;

--mapping they gave us later (do these codes exist in a gemscript_dmd_map??)
 insert into concept_Stage (CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select  '', GENERICNAME,'Drug','Gemscript','Gemscript' , '', VISION_DRUGCODE,  TO_DATE ('20160401', 'yyyymmdd'), TO_DATE ('20991231', 'yyyymmdd') as valid_end_date, null as  INVALID_REASON
 from  GEMSCRIPT_DMD_MAP_2 -- mapping they give us later containing 4758 concepts
where VISION_DRUGCODE is not null
;
--THIN Gemscript codes taken from THIN_to GEMSCRIPT mapping
 insert into concept_Stage (CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select  '', GENERICNAME,'Drug','Gemscript','Gemscript THIN' , '', drugcode,  TO_DATE ('20160401', 'yyyymmdd'), TO_DATE ('20991231', 'yyyymmdd') as valid_end_date, null as  INVALID_REASON 
from  THIN_GEMSCRIPT_MAP
where VISION_DRUGCODE is not null
;
--these 4760 mapping from Gemscript to dm+d
insert into concept_relationship_stage (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_CODE_2, VOCABULARY_ID_2,RELATIONSHIP_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select VISION_DRUGCODE as concept_code_1,
'Gemscript' as vocabulary_id_1,
dmd_code as concept_code_2,
'dm+d' as vocabulary_id_2,
'Maps to' as relationship_id,
TO_DATE ('20160401', 'yyyymmdd') as valid_start_date ,-- 1-Apr-2016
TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
null as invalid_reason
from GEMSCRIPT_DMD_MAP_2 
;
--gemscript THIN to gemscript mapping
insert into concept_relationship_stage (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_CODE_2, VOCABULARY_ID_2,RELATIONSHIP_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select DRUGCODE as concept_code_1,
'Gemscript' as vocabulary_id_1,
VISION_DRUGCODE as concept_code_2,
'Gemscript' as vocabulary_id_2,
'Maps to' as relationship_id,
TO_DATE ('20160401', 'yyyymmdd') as valid_start_date ,
TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
null as invalid_reason
from THIN_GEMSCRIPT_MAP;

commit;