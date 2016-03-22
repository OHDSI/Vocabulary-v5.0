/*
-- start new sequence
-- drop sequence v5_concept;
DECLARE
 ex NUMBER;
BEGIN
  SELECT MAX(concept_id)+1 INTO ex FROM concept WHERE concept_id>=200 and concept_id<1000; -- Last valid value in the 500-1000 slot
  BEGIN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXCEPTION
      WHEN OTHERS THEN NULL;
  END;
END;
*/

-- Fix trailing zero problem in Race
update concept set concept_code='2.10.' where concept_id=38003583;
update concept set concept_code='2.20.' where concept_id=38003593;
update concept set concept_code='3.10.' where concept_id=38003607;

-- Remove unused domains
-- Domain
delete from concept_relationship where concept_id_1=1;
delete from concept_synonym where concept_id=1;
delete from domain where domain_id='Measurement';
delete from concept where concept_id=1;

-- Generic
delete from concept_relationship where concept_id_1=40;
delete from concept_synonym where concept_id=40;
delete from domain where domain_id='Generic';
delete from concept where concept_id=40;

-- Fixing trailing dots for the race codes
update concept set concept_code=regexp_replace(concept_code, '(.*)\.$', '\1') where vocabulary_id='Race' and regexp_like(concept_code, '.*\.$');

-- Fixing bad concept_name for associiated with
update concept set concept_name='Associated with finding (SNOMED)' where concept_id=44818792;
update concept set concept_name='Finding associated with (SNOMED)' where concept_id=44818890;
update relationship set relationship_name='Associated with finding (SNOMED)' where relationship_concept_id=44818792;
update relationship set relationship_name='Finding associated with (SNOMED)' where relationship_concept_id=44818890;

-- fix wrong order start_date and end_date
update concept set valid_start_date=valid_end_date-1 where valid_end_date<valid_start_date;

commit;



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
