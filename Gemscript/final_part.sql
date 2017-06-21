
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'Gemscript',
                                          pVocabularyDate        => TRUNC(SYSDATE),
                                          pVocabularyVersion     => 'Gemscript '||SYSDATE,
                                          pVocabularyDevSchema   => 'DEV_gemscript');									  
END;
/
COMMIT;

--concept_stage
truncate table concept_stage;
;
insert into concept_stage
 select b.* from basic_concept_stage b
;
commit
;
merge into concept_stage cs using (select domain_id, gemscript_code,thin_code  from thin_need_to_map) tt on (tt.gemscript_code = cs.concept_code)
when matched then update  set cs.domain_id = tt.domain_id
;
merge into concept_stage cs using (select domain_id, gemscript_code,thin_code  from thin_need_to_map) tt on (tt.thin_code = cs.concept_code)
when matched then update  set cs.domain_id = tt.domain_id
;
update concept_stage set standard_concept = 'S' where domain_id = 'Device'
;
commit
;
--concept_relationship_stage
truncate table concept_relationship_stage
;
insert into concept_relationship_stage
select * from basic_con_rel_stage
;
commit
;
delete from concept_relationship_stage where invalid_reason ='D'
;
commit
;
--insert mappings
insert into concept_relationship_stage  (CONCEPT_ID_1,CONCEPT_ID_2,CONCEPT_CODE_1,CONCEPT_CODE_2,VOCABULARY_ID_1,VOCABULARY_ID_2,RELATIONSHIP_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select '', '', cs.concept_code, c.concept_code, cs.vocabulary_id, c.vocabulary_id, 'Maps to', TRUNC(SYSDATE), TO_DATE ('20991231', 'yyyymmdd'), ''
from best_map b
join concept_stage cs on cs.concept_code = b.Q_DCODE 
join concept c on c.concept_id = b.R_DID 
;
commit
;
--Devices mapping
insert into concept_relationship_stage  (CONCEPT_ID_1,CONCEPT_ID_2,CONCEPT_CODE_1,CONCEPT_CODE_2,VOCABULARY_ID_1,VOCABULARY_ID_2,RELATIONSHIP_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select '', '', b.concept_code, b.concept_code, b.vocabulary_id, b.vocabulary_id, 'Maps to', TRUNC(SYSDATE), TO_DATE ('20991231', 'yyyymmdd'), ''
from concept_stage b
where b.domain_id = 'Device' 
and b.concept_code not in (select concept_code_1 from concept_relationship_stage)
;
commit
;
--procedures 
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
/
COMMIT;

-- Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
/
COMMIT;

-- Add mapping from deprecated to fresh concepts, and also from non-standard to standard concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
/
COMMIT;

-- Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
/
COMMIT; 