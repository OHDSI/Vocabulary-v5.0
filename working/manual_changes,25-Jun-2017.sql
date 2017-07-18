-- Add vocabulary for MMI
select * from vocabulary_conversion order by 1 desc;

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(581367, 'Modernizing Medicine (MMI)', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id)
  values('MMI', 'Modernizing Medicine (MMI)', 'MMI proprietary', null, (select concept_id from concept where concept_name='Modernizing Medicine (MMI)'));
insert into vocabulary_conversion (vocabulary_id_v4, vocabulary_id_v5, omop_req, click_default, available, url, click_disabled, latest_update)
  values(86, 'MMI', null, null, null, null, null, '28-Apr-2017');

-- Add Condition Type for test condition
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(5086, 'Condition tested for by diagnostic procedure', 'Type Concept', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

-- Add Global Assessment for IMS
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(5087, 'Physician Global Assessment', 'Observation', 'MMI', 'Survey', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

-- Add Itch NRS
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(581368, 'Itch Numeric Rating Scale', 'Observation', 'MMI', 'Survey', 'S', 'Itch NRS', '1-Jan-1970', '31-Dec-2099', null);

-- Add TBSA
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(581369, 'Total Body Surface Area affected', 'Observation', 'MMI', 'Survey', 'S', 'TBSA', '1-Jan-1970', '31-Dec-2099', null);
  
-- Add MMI composite
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(581370, 'MMI Psoriasis Disease Severity Score', 'Observation', 'MMI', 'Survey', 'S', 'MMI composite', '1-Jan-1970', '31-Dec-2099', null);

-- Add Document Types
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'LOINC Document Type', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values('LOINC Document Type', 'LOINC Document Type', (select concept_id from concept where concept_name='LOINC Document Type'));

-- Add Drug Type for orders
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Physician administered drug (identified from EHR order)', 'Type Concept', 'Drug Type', 'Drug Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

-- Add Condition Type for Specimen Type
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'OMOP Specimen Type', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id)
  values('Specimen Type', 'OMOP Specimen Type', 'OMOP generated', null, (select concept_id from concept where concept_name='OMOP Specimen Type' and concept_class_id='Vocabulary'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'OMOP Specimen Type', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values('Specimen Type', 'OMOP Specimen Type', (select concept_id from concept where concept_name='OMOP Specimen Type' and concept_class_id='Concept Class'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'EHR Detail', 'Type Concept', 'Specimen Type', 'Specimen Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

-- Add additional places of service
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Inpatient Critical Care Facility', 'Place of Service', 'Place of Service', 'Place of Service', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Outpatient Critical Care Facility', 'Place of Service', 'Place of Service', 'Place of Service', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Emergency Room Critical Care Facility', 'Place of Service', 'Place of Service', 'Place of Service', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Inpatient Intensive Care Facility', 'Place of Service', 'Place of Service', 'Place of Service', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Inpatient Cardiac Care Facility', 'Place of Service', 'Place of Service', 'Place of Service', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Inpatient Nursery', 'Place of Service', 'Place of Service', 'Place of Service', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Observation Room', 'Place of Service', 'Place of Service', 'Place of Service', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

-- Remove Multilex links from participating in the concept_ancestor constructor
update relationship set defines_ancestry=0 where relationship_id like 'Multilex ing of';

-- Add telemedicine
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'Interactive Telemedicine Service', 'Place of Service', 'Place of Service', 'Place of Service', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
commit;
