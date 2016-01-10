/*
-- start new sequence
-- drop sequence v5_concept;
DECLARE
 ex NUMBER;
BEGIN
  SELECT MAX(concept_id)+1 INTO ex FROM concept WHERE concept_id<500000000; -- Last valid below HOI concept_id
  BEGIN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXCEPTION
      WHEN OTHERS THEN NULL;
  END;
END;
*/

update concept set concept_name = 'OMOP Standardized Vocabularies' where concept_id = 44819096;

-- Add new Unit for building Drug Strength
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (9693, 'index of reactivity', 'Unit', 'UCUM', 'Unit', 'S', '{ir}', '1-Dec-2014', '31-Dec-99', null);

commit;

-- Change relationships for FDB vocabularies
update relationship set defines_ancestry=0 where relationship_id = 'Inferred class of';
update relationship set is_hierarchical=3 where relationship_id in ('ETC - RxNorm', 'RxNorm - ETC', 'Has FDA-appr ind', 'Has off-label ind', 'Has CI', 'Is FDA-appr ind of', 'Is off-label ind of', 'Is CI of');
update concept_relationship set valid_end_date = '10-Dec-2015', invalid_reason = 'D' where relationship_id = 'Inferred class of';




------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remove invalid ICD10 codes
delete 
from concept_relationship r 
where exists (
  select 1 from concept c1 where r.concept_id_1=c1.concept_id and c1.vocabulary_id='ICD10CM' and c1.concept_class_id='ICD10 code'
)
;

update concept set 
  'Invalid ICD10 Concept, do not use' as concept_name, 
  vocabulary_id='ICD10', 
  concept_code=concept_id, -- so they can't even find them anymore by concept_code
  '1-July-2015' as valid_end_date, 
  'D' as invalid_reason
where vocabulary_id='ICD10CM' 
and concept_class_id='ICD10 code'
;
