update concept_stage a set concept_name = (select concept_name from complete_name b where a.concept_code = b.concept_code)
where exists (select 1 from complete_name b where a.concept_code = b.concept_code)
;
--inverse relationships
INSERT /*+ APPEND */ INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT crs.concept_code_2,
          crs.concept_code_1,
          crs.vocabulary_id_2,
          crs.vocabulary_id_1,
          r.reverse_relationship_id,
          crs.valid_start_date,
          crs.valid_end_date,
          crs.invalid_reason
     FROM concept_relationship_stage crs
          JOIN relationship r ON r.relationship_id = crs.relationship_id
    WHERE NOT EXISTS
             (                                           -- the inverse record
              SELECT 1
                FROM concept_relationship_stage i
               WHERE     crs.concept_code_1 = i.concept_code_2
                     AND crs.concept_code_2 = i.concept_code_1
                     AND crs.vocabulary_id_1 = i.vocabulary_id_2
                     AND crs.vocabulary_id_2 = i.vocabulary_id_1
                     AND r.reverse_relationship_id = i.relationship_id);
COMMIT;		

drop table concept_relationship_manual;
create table concept_relationship_manual as select * from devv5.concept_relationship_manual where rownum =0;
;
--contains deprecated concepts 
insert into concept_relationship_manual
select c1.concept_code, c2.concept_code, c1.vocabulary_id,c2.vocabulary_id, r.relationship_id, r.valid_start_date, TO_DATE ('20160802', 'yyyymmdd'), 'D' from concept_relationship r
join concept c1 on r.concept_id_1 = c1.concept_id
join concept c2 on r.concept_id_2 = c2.concept_id
where( c1.vocabulary_id ='DA_France' or c2.vocabulary_id ='DA_France' )
and not exists (select 1 from concept_relationship_stage b where c1.concept_code = b.concept_code_1 and c2.concept_code = b.concept_code_2 and r.relationship_id = b.relationship_id and vocabulary_id_1 = c1.vocabulary_id and
vocabulary_id_2 = c2.vocabulary_id
)
;

BEGIN
   DEVV5.VOCABULARY_PACK.ProcessManualRelationships;
END;
COMMIT;

--concept_stage 
delete from concept_stage where concept_code like 'OMOP%'
;
update concept_stage set standard_concept = null
;
commit
;
truncate table drug_strength_stage 
;
commit
;
