-- Always keep the two sequences on top of the manual_changes.sql. The first one is for really important ones concept_id<1000, 
-- and the other one is for filling in holes, currently in the 5000 range

/*
-- start new sequence for important concepts. Do not use unless justified!!!
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
-- start new sequence in a hole of 10000:
drop sequence v5_concept;
DECLARE
 ex NUMBER;
BEGIN
  SELECT MAX(concept_id)+1 INTO ex FROM concept WHERE concept_id>=571191 and concept_id<581479; 
  BEGIN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXCEPTION
      WHEN OTHERS THEN NULL;
  END;
END;
*/

-- Add vocabulary for MMI
select * from vocabulary_conversion order by 1 desc;

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Modernizing Medicine (MMI)', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id)
  values('MMI', 'Modernizing Medicine (MMI)', 'MMI proprietary', null, (select concept_id from concept where concept_name='Modernizing Medicine (MMI)'));
insert into vocabulary_conversion (vocabulary_id_v4, vocabulary_id_v5, omop_req, click_default, available, url, click_disabled, latest_update)
  values(86, 'MMI', null, null, null, null, null, '28-Apr-2017');

-- Add Condition Type for test condition
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(5086, 'Condition tested for by diagnostic procedure', 'Type Concept', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

-- Add Global Assessment for IMS
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(5087, 'Physician Global Assessment', 'Observation', 'MMI', 'Survey', 'S', 'OMOP generated', '28-Apr-1970', '31-Dec-2099', null);

-- Add Itch NRS
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Itch Numeric Rating Scale', 'Observation', 'MMI', 'Survey', 'S', 'Itch NRS', '28-Apr-1970', '31-Dec-2099', null);

-- Add TBSA
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Total Body Surface Area affected', 'Observation', 'MMI', 'Survey', 'S', 'TBSA', '28-Apr-1970', '31-Dec-2099', null);
  
-- Add TBSA
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'MMI Psoriasis Disease Severity Score', 'Observation', 'MMI', 'Survey', 'S', 'MMI composite', '28-Apr-1970', '31-Dec-2099', null);

commit;
