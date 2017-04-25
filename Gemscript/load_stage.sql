--1 Update latest_update field to new date 
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'Gemscript',
                                          pVocabularyDate        => TRUNC(SYSDATE),
                                          pVocabularyVersion     => 'Gemscript '||SYSDATE,
                                          pVocabularyDevSchema   => 'DEV_gemscript');									  
END;
/
COMMIT;
--add Gemscript concept set, 
--dm+d variant is better 
TRUNCATE TABLE concept_stage
;
insert into concept_stage 
select
null as CONCEPT_ID,
dmd_drug_name as concept_name,  
'Drug' as domain_id,
'Gemscript' as vocabulary_id,
'Gemscript' as concept_class_id,
null as standard_concept,
gemscript_drug_code as concept_code,
(select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date ,-- TRUNC(SYSDATE)
'31-Dec-2099' as valid_end_date,
null as invalid_reason
from gemscript_dmd_map
;
commit
;
--take concepts from additional tables
--reference table from CPRD
insert into concept_stage 
select 
null as CONCEPT_ID,
PRODUCTNAME as concept_name,  
'Drug' as domain_id,
'Gemscript' as vocabulary_id,
'Gemscript' as concept_class_id,
null as standard_concept,
GEMSCRIPTCODE as concept_code,
(select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date, -- TRUNC(SYSDATE)
'31-Dec-2099' as valid_end_date,
null as invalid_reason
from gemscript_reference where GEMSCRIPTCODE not in (select concept_code from concept_stage)
;
COMMIT
;
--mappings from Urvi
insert into concept_stage 
select 
null as CONCEPT_ID,
BRAND as concept_name,  
'Drug' as domain_id,
'Gemscript' as vocabulary_id,
'Gemscript' as concept_class_id,
null as standard_concept,
GEMSCRIPT_DRUGCODE as concept_code,
(select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date, -- TRUNC(SYSDATE)
'31-Dec-2099' as valid_end_date,
null as invalid_reason
from THIN_GEMSC_DMD_0417 where GEMSCRIPT_DRUGCODE not in (select concept_code from concept_stage)
;
COMMIT
;
--Gemscript THIN concepts 
insert into concept_stage 
select 
null as CONCEPT_ID,
GENERIC as concept_name,  
'Drug' as domain_id,
'Gemscript' as vocabulary_id,
'Gemscript THIN'  as concept_class_id,
null as standard_concept,
ENCRYPTED_DRUGCODE as concept_code,
(select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date, -- TRUNC(SYSDATE)
'31-Dec-2099' as valid_end_date,
null as invalid_reason
from THIN_GEMSC_DMD_0417 
;
COMMIT
;
--CLEAN UP --in the future put the thing into insert (need to find out what those !code mean)
DELETE FROM concept_stage WHERE CONCEPT_NAME IS NULL OR regexp_like (concept_code, '\D') 
;
COMMIT
;
--build concept_relationship_stage table
 truncate table concept_relationship_stage
 ;
--Gemscript to dm+d
--new table from URVI
insert into concept_relationship_stage
select 
null as CONCEPT_ID_1, 
null as CONCEPT_ID_2,
GEMSCRIPT_DRUGCODE as concept_code_1,
DMD_CODE as concept_code_2,
'Gemscript' as vocabulary_id_1,
'dm+d' as vocabulary_id_2,
'Maps to' as relationship_id,
(select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date,
'31-Dec-2099' as valid_end_date,
null as invalid_reason
from THIN_GEMSC_DMD_0417
 ;
commit
;
--old table from Christian
insert into concept_relationship_stage
select 
null as CONCEPT_ID_1, 
null as CONCEPT_ID_2,
'Gemscript' as vocabulary_id_1,
GEMSCRIPT_DRUG_CODE as concept_code_1,
DMD_CODE as concept_code_2,
'dm+d' as vocabulary_id_2,
'Maps to' as relationship_id,
(select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date,
'31-Dec-2099' as valid_end_date,
null as invalid_reason
from gemscript_dmd_map  where  GEMSCRIPT_DRUG_CODE not in (select concept_code_1 from  concept_relationship_stage  )
;
commit
;
--mappings between THIN gemscript and Gemscript
insert into concept_relationship_stage
select 
null as CONCEPT_ID_1, 
null as CONCEPT_ID_2,
encrypted_DRUGCODE as concept_code_1,
GEMSCRIPT_DRUGCODE as concept_code_2,
'Gemscript' as vocabulary_id_1,
'Gemscript' as vocabulary_id_2,
'Maps to' as relationship_id,
(select latest_update from vocabulary where vocabulary_id = 'Gemscript') as valid_start_date,
'31-Dec-2099' as valid_end_date,
null as invalid_reason
from THIN_GEMSC_DMD_0417  
;
commit
;
-- GATHER TABLE STATS
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_stage', cascade  => true);
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_relationship_stage', cascade  => true)
;
--apply checks
-- join everything: THIN to Gemscript to dm+d to RxE
select count(*) from concept_stage th
join concept_relationship_stage tr on th.concept_code = tr.concept_code_1 and th.vocabulary_id = 'Gemscript' and th.concept_class_id = 'Gemscript THIN'
join concept_stage ge on tr.concept_code_2 = ge.concept_code-- and ge.vocabulary_id = 'Gemscript' and ge.concept_class_id = 'Gemscript'
join concept_relationship_stage gr on ge.concept_code = gr.concept_code_1 
join concept dmd on dmd.concept_code = gr.concept_code_2 and dmd.vocabulary_id = 'dm+d'
--43705
join concept_relationship rx on rx.concept_id_1 = dmd.concept_id and rx.relationship_id ='Maps to' and rx.invalid_reason is null
join concept x on x.concept_id = rx.concept_id_2 and x.vocabulary_id like 'Rx%'
--got only 20910 in the end, need to check where do we lose such a lot of things -- probably - non-drugs,
--OK generic 

;
explain plan for 
select count(*) from concept_stage th
join concept_relationship_stage tr on th.concept_code = tr.concept_code_1 and th.vocabulary_id = 'Gemscript' and th.concept_class_id = 'Gemscript THIN'
join concept_stage ge on tr.concept_code_2 = ge.concept_code and ge.vocabulary_id = 'Gemscript' and ge.concept_class_id = 'Gemscript'
join concept_relationship_stage gr on ge.concept_code = gr.concept_code_1 
;
 SELECT * FROM TABLE (dbms_xplan.display);

select count(*) from concept_relationship_stage --where concept_code_1 is null-- 237832
;
 select count(*) from concept_stage -- 238594 --now it's ok
;
 select * from THIN_GEMSC_DMD_0417;
  select count(*) from concept_stage where concept_code  is null
  ;
  update concept_stage set concept_code = regexp_substr (concept_code, '\d+')
  ;
  update concept_relationship_stage set concept_code_1 = regexp_substr (concept_code_1, '\d+')
  ;
    update concept_relationship_stage set concept_code_2 = regexp_substr (concept_code_2, '\d+')
  ;
  commit
  ;
select * from concept_stage where concept_code= '96722990'
;
select * from concept_relationship_stage where concept_code_1= '96722990'
;
