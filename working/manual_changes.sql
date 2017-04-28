-- Always keep the two sequences on top of the manual_changes.sql. The first one is for really important ones concept_id<1000, 
-- and the other one is for filling in holes, currently in the 5000 range

/*
-- start new sequence
drop sequence v5_concept;
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

/*
-- start new sequence
drop sequence v5_concept;
DECLARE
 ex NUMBER;
BEGIN
  SELECT MAX(concept_id)+1 INTO ex FROM concept WHERE concept_id>=5000 and concept_id<8000; -- Last valid value in the 5000-8000 slot
  BEGIN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXCEPTION
      WHEN OTHERS THEN NULL;
  END;
END;
*/

-- Add Condition Type for test condition
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(5086, 'Condition tested for by diagnostic procedure', 'Type Concept', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

-- Add Global Assessment for IMS
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(5087, 'Physician Global Assessment', 'Observation', 'None', 'Survey', 'S', 'OMOP generated', '28-Apr-1970', '31-Dec-2099', null);

commit;
