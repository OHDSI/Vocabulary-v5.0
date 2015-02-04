-- Add units for drug_strength
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Actuation', 'Unit', 'UCUM', 'Unit', 'S', '{actuat}', '01-JAN-1970', '31-DEC-2099', null);	
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'allergenic unit', 'Unit', 'UCUM', 'Unit', 'S', '{AU}', '01-JAN-1970', '31-DEC-2099', null);	
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'bioequivalent allergenic unit', 'Unit', 'UCUM', 'Unit', 'S', '{BAU}', '01-JAN-1970', '31-DEC-2099', null);	
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'cells', 'Unit', 'UCUM', 'Unit', 'S', '{cells}', '01-JAN-1970', '31-DEC-2099', null);	
update concept set concept_name = 'pH unit' where concept_id = 8569;
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'clinical unit', 'Unit', 'UCUM', 'Unit', 'S', '{CU}', '01-JAN-1970', '31-DEC-2099', null);	
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'limit of flocculation unit', 'Unit', 'UCUM', 'Unit', 'S', '{LFU}', '01-JAN-1970', '31-DEC-2099', null);	
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'bacteria', 'Unit', 'UCUM', 'Unit', 'S', '{bacteria}', '01-JAN-1970', '31-DEC-2099', null);	
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'protein nitrogen unit', 'Unit', 'UCUM', 'Unit', 'S', '{PNU}', '01-JAN-1970', '31-DEC-2099', null);	

-- Add combination of Measurement and Procedure
insert into concept (concept_id,  concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (43, 'Measurement/Procedure', 'Metadata', 'Domain', 'Domain', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into domain (domain_id, domain_name, domain_concept_id)
values ('Meas/Procedure', 'Measurement/Procedure', 43);

-- Erica's and Martijn's type concepts
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pre-qualification time period', 'Obs Period Type', 'Obs Period Type', 'Obs Period Type', 'S', 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);	
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'EHR Episode Entry', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);	

-- Make all Metadata non-standard
update concept 
set standard_concept = null where domain_id = 'Metadata';

-- Abolish extra vocabulary 'LOINC Multidimensional Classification (Regenstrief Institute)'. Will become only concept class
update concept
set vocabulary_id = 'LOINC' where vocabulary_id = 'LOINC Hierarchy';
delete from vocabulary where vocabulary_id = 'LOINC Hierarchy';
update concept set 
  valid_end_date = '1-Dec-2014',
  invalid_reason = 'D'
where concept_id = 44819139
;

-- Add concept_class 'LOINC Class'
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'LOINC Class', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('LOINC Class', 'LOINC Class', (select concept_id from concept where concept_name = 'LOINC Class'));

-- LOINC concept_class_ids
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Laboratory Class', 'Metadata', 'Concept Class', 'Concept Class', null, '1', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Lab Test', 'Laboratory Class', (select concept_id from concept where concept_name = 'Laboratory Class'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Clinical Class', 'Metadata', 'Concept Class', 'Concept Class', null, '2', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Clinical Observation', 'Clinical Class', (select concept_id from concept where concept_name = 'Clinical Class'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Claims Attachments', 'Metadata', 'Concept Class', 'Concept Class', null, '3', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Claims Attachment', 'Claims Attachments', (select concept_id from concept where concept_name = 'Claims Attachments'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Surveys', 'Metadata', 'Concept Class', 'Concept Class', null, '4', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Survey', 'Surveys', (select concept_id from concept where concept_name = 'Surveys'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Answers', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Answer', 'Answers', (select concept_id from concept where concept_name = 'Answers'));

-- change LOINC Hierarchy concepts to 'C'
update concept 
set standard_concept = 'C' where concept_class_id = 'LOINC Hierarchy';

-- add new relationship between LOINC surveys etc. and answers
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has Answer (LOINC)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Has Answer', 'Has Answer (LOINC)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'Has Answer (LOINC)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Answer of (LOINC)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Answer of', 'Answer of (LOINC)', 0, 0, 'Answer of', (select concept_id from concept where concept_name = 'Answer of (LOINC)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'Answer of' where relationship_id = 'Has Answer';
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'Has Answer' where relationship_id = 'Answer of';

-- Add new CPT4 concpet classes
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'CPT4 Modifier', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('CTP4 Modifier', 'CPT4 Modifier', (select concept_id from concept where concept_name = 'CPT4 Modifier'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'CPT4 Hierarchy', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('CTP4 Hierarchy', 'CPT4 Hierarchy', (select concept_id from concept where concept_name = 'CPT4 Hierarchy'));

-- Add new HCPCS concept classes
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'HCPCS Modifier', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('HCPCS Modifier', 'HCPCS Modifier', (select concept_id from concept where concept_name = 'HCPCS Modifier'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'HCPCS Class', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('HCPCS Class', 'HCPCS Class', (select concept_id from concept where concept_name = 'HCPCS Class'));

-- Add HCPCS class concepts
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Office visits - new', 'Observation', 'HCPCS', 'HCPCS Class', 'C', 'M1A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Office visits - established', 'Observation', 'HCPCS', 'HCPCS Class', 'C', 'M1B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Hospital visit - initial', 'Observation', 'HCPCS', 'HCPCS Class', 'C', 'M2A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Hospital visit - subsequent', 'Observation', 'HCPCS', 'HCPCS Class', 'C', 'M2B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Hospital visit - critical care', 'Observation', 'HCPCS', 'HCPCS Class', 'C', 'M2C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Emergency room visit', 'Observation', 'HCPCS', 'HCPCS Class', 'C', 'M3 ', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Home visit', 'Observation', 'HCPCS', 'HCPCS Class', 'C', 'M4A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Nursing home visit', 'Observation', 'HCPCS', 'HCPCS Class', 'C', 'M4B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Specialist - pathology', 'Provider Specialty', 'HCPCS', 'HCPCS Class', 'C', 'M5A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Specialist - psychiatry', 'Provider Specialty', 'HCPCS', 'HCPCS Class', 'C', 'M5B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Specialist - opthamology', 'Provider Specialty', 'HCPCS', 'HCPCS Class', 'C', 'M5C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Specialist - other', 'Provider Specialty', 'HCPCS', 'HCPCS Class', 'C', 'M5D', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Consultations', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'M6 ', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Anesthesia', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P0 ', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure - breast', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P1A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure - colectomy', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P1B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure - cholecystectomy', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P1C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure - turp', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P1D', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure - hysterectomy', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P1E', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure - explor/decompr/excisdisc', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P1F', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure - Other', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P1G', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure, cardiovascular-CABG', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P2A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure, cardiovascular-Aneurysm repair', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P2B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major Procedure, cardiovascular-Thromboendarterectomy', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P2C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure, cardiovascualr-Coronary angioplasty (PTCA)', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P2D', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure, cardiovascular-Pacemaker insertion', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P2E', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure, cardiovascular-Other', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P2F', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure, orthopedic - Hip fracture repair', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P3A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure, orthopedic - Hip replacement', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P3B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure, orthopedic - Knee replacement', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P3C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Major procedure, orthopedic - other', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P3D', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Eye procedure - corneal transplant', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P4A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Eye procedure - cataract removal/lens insertion', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P4B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Eye procedure - retinal detachment', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P4C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Eye procedure - treatment of retinal lesions', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P4D', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Eye procedure - other', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P4E', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Ambulatory procedures - skin', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P5A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Ambulatory procedures - musculoskeletal', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P5B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Ambulatory procedures - inguinal hernia repair', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P5C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Ambulatory procedures - lithotripsy', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P5D', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Ambulatory procedures - other', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P5E', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Minor procedures - skin', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P6A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Minor procedures - musculoskeletal', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P6B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Minor procedures - other (Medicare fee schedule)', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P6C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Minor procedures - other (non-Medicare fee schedule)', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P6D', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Oncology - radiation therapy', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P7A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Oncology - other', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P7B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Endoscopy - arthroscopy', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P8A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Endoscopy - upper gastrointestinal', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P8B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Endoscopy - sigmoidoscopy', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P8C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Endoscopy - colonoscopy', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P8D', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Endoscopy - cystoscopy', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P8E', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Endoscopy - bronchoscopy', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P8F', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Endoscopy - laparoscopic cholecystectomy', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P8G', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Endoscopy - laryngoscopy', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P8H', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Endoscopy - other', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P8I', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Dialysis services (medicare fee schedule)', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P9A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Dialysis services (non-medicare fee schedule)', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'P9B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Standard imaging - chest', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I1A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Standard imaging - musculoskeletal', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I1B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Standard imaging - breast', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I1C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Standard imaging - contrast gastrointestinal', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I1D', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Standard imaging - nuclear medicine', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I1E', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Standard imaging - other', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I1F', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Advanced imaging - CAT/CT/CTA: brain/head/neck', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I2A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Advanced imaging - CAT/CT/CTA: other', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I2B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Advanced imaging - MRI/MRA: brain/head/neck', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I2C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Advanced imaging - MRI/MRA: other', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I2D', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Echography/ultrasonography - eye', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I3A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Echography/ultrasonography - abdomen/pelvis', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I3B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Echography/ultrasonography - heart', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I3C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Echography/ultrasonography - carotid arteries', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I3D', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Echography/ultrasonography - prostate, transrectal', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I3E', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Echography/ultrasonography - other', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I3F', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Imaging/procedure - heart including cardiac catheterization', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I4A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Imaging/procedure - other', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'I4B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Lab tests - routine venipuncture (non Medicare fee schedule)', 'Measurement', 'HCPCS', 'HCPCS Class', 'C', 'T1A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Lab tests - automated general profiles', 'Measurement', 'HCPCS', 'HCPCS Class', 'C', 'T1B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Lab tests - urinalysis', 'Measurement', 'HCPCS', 'HCPCS Class', 'C', 'T1C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Lab tests - blood counts', 'Measurement', 'HCPCS', 'HCPCS Class', 'C', 'T1D', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Lab tests - glucose', 'Measurement', 'HCPCS', 'HCPCS Class', 'C', 'T1E', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Lab tests - bacterial cultures', 'Measurement', 'HCPCS', 'HCPCS Class', 'C', 'T1F', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Lab tests - other (Medicare fee schedule)', 'Measurement', 'HCPCS', 'HCPCS Class', 'C', 'T1G', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Lab tests - other (non-Medicare fee schedule)', 'Measurement', 'HCPCS', 'HCPCS Class', 'C', 'T1H', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Other tests - electrocardiograms', 'Measurement', 'HCPCS', 'HCPCS Class', 'C', 'T2A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Other tests - cardiovascular stress tests', 'Measurement', 'HCPCS', 'HCPCS Class', 'C', 'T2B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Other tests - EKG monitoring', 'Measurement', 'HCPCS', 'HCPCS Class', 'C', 'T2C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Other tests - other', 'Measurement', 'HCPCS', 'HCPCS Class', 'C', 'T2D', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Medical/surgical supplies', 'Device', 'HCPCS', 'HCPCS Class', 'C', 'D1A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Hospital beds', 'Device', 'HCPCS', 'HCPCS Class', 'C', 'D1B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Oxygen and supplies', 'Device', 'HCPCS', 'HCPCS Class', 'C', 'D1C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Wheelchairs', 'Device', 'HCPCS', 'HCPCS Class', 'C', 'D1D', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Other DME', 'Device', 'HCPCS', 'HCPCS Class', 'C', 'D1E', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Prosthetic/Orthotic devices', 'Device', 'HCPCS', 'HCPCS Class', 'C', 'D1F', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Drugs Administered through DME', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'D1G', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Ambulance', 'Observation', 'HCPCS', 'HCPCS Class', 'C', 'O1A', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Chiropractic', 'Observation', 'HCPCS', 'HCPCS Class', 'C', 'O1B', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Enteral and parenteral', 'Device', 'HCPCS', 'HCPCS Class', 'C', 'O1C', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Chemotherapy', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'O1D', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Other drugs', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'O1E', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Hearing and speech services', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'O1F', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Immunizations/Vaccinations', 'Procedure', 'HCPCS', 'HCPCS Class', 'C', 'O1G', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Other - Medicare fee schedule', 'Observation', 'HCPCS', 'HCPCS Class', 'C', 'Y1 ', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Other - non-Medicare fee schedule', 'Observation', 'HCPCS', 'HCPCS Class', 'C', 'Y2 ', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Local codes', 'Observation', 'HCPCS', 'HCPCS Class', 'C', 'Z1 ', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Undefined codes', 'Observation', 'HCPCS', 'HCPCS Class', 'C', 'Z2 ', '01-JAN-1970', '31-DEC-2099', null);

-- Add new SNOMED concept classes
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Navigational Concept', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Navi Concept', 'Navigational Concept', (select concept_id from concept where concept_name = 'Navigational Concept'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Inactive Concept', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Inactive Concept', 'Inactive Concept', (select concept_id from concept where concept_name = 'Inactive Concept'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Linkage Concept', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Linkage Concept', 'Linkage Concept', (select concept_id from concept where concept_name = 'Linkage Concept'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Link Assertion', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Link Assertion', 'Link Assertion', (select concept_id from concept where concept_name = 'Link Assertion'));

-- Fix existing SNOMED concept classes
update concept set concept_name = 'Situation with explicit context' where concept_id = 44819051;
update concept_class set concept_class_name = 'Situation with explicit context' where concept_class_concept_id = 44819051;

-- Fix Rimma's PCORNet null flavors. Leave only the Hispanic ones alive
update concept set concept_name = 'Other' where concept_id = 44814649; -- rename from 'Hispanic - other'
update concept set concept_class_id = 'Undefined' where concept_id = 44814649; -- give generic concept class
update concept set concept_name = 'Unknown' where concept_id = 44814653; -- rename from 'Hispanic - unknown'
update concept set concept_class_id = 'Undefined' where concept_id = 44814653; -- give generic concept class
update concept set concept_name = 'No information' where concept_id = 44814650; -- rename from 'Hispanic - no information'
update concept set concept_class_id = 'Undefined' where concept_id = 44814650; -- give generic concept class
update concept set valid_end_date = '30-Nov-2014', invalid_reason = 'D' where concept_id in (44814688, 44814668, 44814713, 44814683, 44814662, 44814705); -- Unknown ones
update concept set valid_end_date = '30-Nov-2014', invalid_reason = 'D' where concept_id in (44814669, 44814684, 44814714, 44814663, 44814689, 44814706); -- no information ones
update concept set valid_end_date = '30-Nov-2014', invalid_reason = 'D' where concept_id in (44814667, 44814661, 44814682, 44814704, 44814712, 44814687); -- no information ones

-- Add PCORNet concpet classes and concepts that were not committed
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'DRG Type', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('DRG Type', 'DRG Type', (select concept_id from concept where concept_name = 'DRG Type'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Diagnosis Code Type', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Diagnosis Code Type', 'Diagnosis Code Type', (select concept_id from concept where concept_name = 'Diagnosis Code Type'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Diagnosis Type', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Diagnosis Type', 'Diagnosis Type', (select concept_id from concept where concept_name = 'Diagnosis Type'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Procedure Code Type', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Procedure Code Type', 'Procedure Code Type', (select concept_id from concept where concept_name = 'Procedure Code Type'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Vital Source', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Vital Source', 'Vital Source', (select concept_id from concept where concept_name = 'Vital Source'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Blood Pressure Position', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Blood Pressure Pos', 'Blood Pressure Position', (select concept_id from concept where concept_name = 'Blood Pressure Position'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819189, 'CMS-DRG', 'Observation', 'PCORNet', 'DRG Type', null, '01', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819190, 'MS-DRG', 'Observation', 'PCORNet', 'DRG Type', null, '02', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819191, 'No information', 'Observation', 'PCORNet', 'DRG Type', null, 'NI', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819192, 'Unknown', 'Observation', 'PCORNet', 'DRG Type', null, 'UN', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819193, 'Other', 'Observation', 'PCORNet', 'DRG Type', null, 'OT', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819194, 'ICD-9-CM', 'Observation', 'PCORNet', 'Diagnosis Code Type', null, '09', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819195, 'ICD-10-CM', 'Observation', 'PCORNet', 'Diagnosis Code Type', null, '10', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819196, 'ICD-11-CM', 'Observation', 'PCORNet', 'Diagnosis Code Type', null, '11', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819197, 'SNOMED CT', 'Observation', 'PCORNet', 'Diagnosis Code Type', null, 'SM', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819198, 'No information', 'Observation', 'PCORNet', 'Diagnosis Code Type', null, 'NI', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819199, 'Unknown', 'Observation', 'PCORNet', 'Diagnosis Code Type', null, 'UN', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819200, 'Other', 'Observation', 'PCORNet', 'Diagnosis Code Type', null, 'OT', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819201, 'Principal', 'Observation', 'PCORNet', 'Diagnosis Type', null, 'P', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819202, 'Secondary', 'Observation', 'PCORNet', 'Diagnosis Type', null, 'S', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819203, 'Unable to Classify', 'Observation', 'PCORNet', 'Diagnosis Type', null, 'X', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819204, 'No information', 'Observation', 'PCORNet', 'Diagnosis Type', null, 'NI', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819205, 'Unknown', 'Observation', 'PCORNet', 'Diagnosis Type', null, 'UN', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819206, 'Other', 'Observation', 'PCORNet', 'Diagnosis Type', null, 'OT', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819207, 'ICD-9-CM', 'Observation', 'PCORNet', 'Procedure Code Type', null, '09', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819208, 'ICD-10-PCS', 'Observation', 'PCORNet', 'Procedure Code Type', null, '10', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819209, 'ICD-11-PCS', 'Observation', 'PCORNet', 'Procedure Code Type', null, '11', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819210, 'CPT Category II', 'Observation', 'PCORNet', 'Procedure Code Type', null, 'C2', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819211, 'CPT Category III', 'Observation', 'PCORNet', 'Procedure Code Type', null, 'C3', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819212, 'CPT-4', 'Observation', 'PCORNet', 'Procedure Code Type', null, 'C4', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819213, 'HCPCS Level III', 'Observation', 'PCORNet', 'Procedure Code Type', null, 'H3', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819214, 'HCPCS', 'Observation', 'PCORNet', 'Procedure Code Type', null, 'HC', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819215, 'LOINC', 'Observation', 'PCORNet', 'Procedure Code Type', null, 'LC', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819216, 'NDC', 'Observation', 'PCORNet', 'Procedure Code Type', null, 'ND', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819217, 'Revenue', 'Observation', 'PCORNet', 'Procedure Code Type', null, 'RE', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819218, 'No information', 'Observation', 'PCORNet', 'Procedure Code Type', null, 'NI', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819219, 'Unknown', 'Observation', 'PCORNet', 'Procedure Code Type', null, 'UN', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819220, 'Other', 'Observation', 'PCORNet', 'Procedure Code Type', null, 'OT', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819221, 'Patient-reported', 'Observation', 'PCORNet', 'Vital Source', null, 'PR', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819222, 'Healthcare delivery setting', 'Observation', 'PCORNet', 'Vital Source', null, 'HC', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819223, 'No information', 'Observation', 'PCORNet', 'Vital Source', null, 'NI', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819224, 'Unknown', 'Observation', 'PCORNet', 'Vital Source', null, 'UN', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819225, 'Other', 'Observation', 'PCORNet', 'Vital Source', null, 'OT', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819226, 'Sitting', 'Observation', 'PCORNet', 'Blood Pressure Pos', null, '01', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819227, 'Standing', 'Observation', 'PCORNet', 'Blood Pressure Pos', null, '02', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819228, 'Supine', 'Observation', 'PCORNet', 'Blood Pressure Pos', null, '03', '01-Jan-1970', '31-Dec-1999', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819229, 'No information', 'Observation', 'PCORNet', 'Blood Pressure Pos', null, 'NI', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819230, 'Unknown', 'Observation', 'PCORNet', 'Blood Pressure Pos', null, 'UN', '01-Jan-1970', '30-Nov-2014', 'D');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (44819231, 'Other', 'Observation', 'PCORNet', 'Blood Pressure Pos', null, 'OT', '01-Jan-1970', '30-Nov-2014', 'D');

-- add new relationship between SNOMED surveys etc. and answers
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has Morphology (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Has morphology', 'Has Morphology (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'Has Morphology (SNOMED)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Morphology of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Morphology of', 'Morphology of (SNOMED)', 0, 0, 'Morphology of', (select concept_id from concept where concept_name = 'Morphology of (SNOMED)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Morphology'
set reverse_relationship_id = 'Morphology of' where relationship_id = 'Has morphology';
update relationship -- The reverse wasn't in at the time of writing 'Has Morphology'
set reverse_relationship_id = 'Has morphology' where relationship_id = 'Morphology of';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has Measured Component (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Has meas component', 'Has Measured Component (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'Has Measured Component (SNOMED)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Measured Component of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Meas component of', 'Measured Component of (SNOMED)', 0, 0, 'Has meas component', (select concept_id from concept where concept_name = 'Measured Component of (SNOMED)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Measured Component'
set reverse_relationship_id = 'Meas component of' where relationship_id = 'Has meas component';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Caused by (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Caused by', 'Caused by (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'Caused by (SNOMED)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Causes (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Causes', 'Causes (SNOMED)', 0, 0, 'Caused by', (select concept_id from concept where concept_name = 'Causes (SNOMED)'));
update relationship -- The reverse wasn't in at the time of writing 'Caused by'
set reverse_relationship_id = 'Causes' where relationship_id = 'Caused by';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has Etiology (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Has etiology', 'Has Etiology (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'Has Etiology (SNOMED)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Etiology of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Etiology of', 'Etiology of (SNOMED)', 0, 0, 'Has etiology', (select concept_id from concept where concept_name = 'Etiology of (SNOMED)'));
update relationship -- The reverse wasn't in at the time of writing 'Has etiology'
set reverse_relationship_id = 'Etiology of' where relationship_id = 'Has etiology';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has Stage (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Has stage', 'Has Stage (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'Has Stage (SNOMED)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Stage of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Stage of', 'Stage of (SNOMED)', 0, 0, 'Has stage', (select concept_id from concept where concept_name = 'Stage of (SNOMED)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Stage'
set reverse_relationship_id = 'Stage of' where relationship_id = 'Has stage';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has Extent (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Has extent', 'Has Extent (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'Has Extent (SNOMED)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Extent of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Extent of', 'Extent of (SNOMED)', 0, 0, 'Has extent', (select concept_id from concept where concept_name = 'Extent of (SNOMED)'));
update relationship -- The reverse wasn't in at the time of writing 'Has extent'
set reverse_relationship_id = 'Extent of' where relationship_id = 'Has extent';

-- Add concept_class 'Linkage Assertion'
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Linkage Assertion', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Linkage Assertion', 'Linkage Assertion', (select concept_id from concept where concept_name = 'Linkage Assertion'));

-- Consolidate Concept replaced by and Snomed replaced by
create table rby as 
select r1.concept_id_1, r1.concept_id_2, 'Concept replaced by' as relationship_id, r2.valid_start_date, r1.valid_end_date, r1.invalid_reason
from concept_relationship r1 
join concept_relationship r2 on r1.concept_id_1 = r2.concept_id_1 and r1.concept_id_2 = r2.concept_id_2 and r2.relationship_id = 'Concept replaced by'
where r1.relationship_id = 'SNOMED replaced by'
;
create table res as 
select r1.concept_id_1, r1.concept_id_2, 'Concept replaces' as relationship_id, r2.valid_start_date, r1.valid_end_date, r1.invalid_reason
from concept_relationship r1 
join concept_relationship r2 on r1.concept_id_1 = r2.concept_id_1 and r1.concept_id_2 = r2.concept_id_2 and r2.relationship_id = 'Concept replaces'
where r1.relationship_id = 'SNOMED replaces'
;
delete from concept_relationship 
where relationship_id in ('Concept replaced by', 'SNOMED replaced by')
and concept_id_1||'-'||concept_id_2 in (
  select concept_id_1||'-'||concept_id_2 from rby
)
;
delete from concept_relationship 
where relationship_id in ('Concept replaces', 'SNOMED replaces')
and concept_id_1||'-'||concept_id_2 in (
  select concept_id_1||'-'||concept_id_2 from res
)
;
insert into concept_relationship select * from rby;
insert into concept_relationship select * from res;
drop table rby purge;
drop table res purge;

-- Add new concept classes for non-billing codes in ICD9CM and ICD9Proc
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'ICD9CM non-billable code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('ICD9CM non-bill code', 'ICD9CM non-billable code', (select concept_id from concept where concept_name = 'ICD9CM non-billable code'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'ICD9Proc non-billable code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('ICD9Proc non-bill', 'ICD9Proc non-billable code', (select concept_id from concept where concept_name = 'ICD9Proc non-billable code'));

-- add new relationship RxNorm relationships
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has quantified form (RxNorm)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Has quantified form', 'Has quantified form (RxNorm)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'Has quantified form (RxNorm)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Quantified form of (RxNorm)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Quantified form of', 'Quantified form of (RxNorm)', 0, 0, 'Has quantified form', (select concept_id from concept where concept_name = 'Quantified form of (RxNorm)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'Quantified form of' where relationship_id = 'Has quantified form';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Is a (RxNorm)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('RxNorm is a', 'Is a (RxNorm)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'Is a (RxNorm)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Inverse is a (RxNorm)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('RxNorm inverse is a', 'Inverse is a (RxNorm)', 0, 0, 'RxNorm is a', (select concept_id from concept where concept_name = 'Inverse is a (RxNorm)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'RxNorm inverse is a' where relationship_id = 'RxNorm is a';

-- Add hierarchical and ancestry flags
update relationship set is_hierarchical = 1, defines_ancestry = 1 where relationship_concept_id = 45754830;
update relationship set defines_ancestry = 1 where relationship_concept_id = 45754828;

-- Include VA Product to RxNorm relationship in ancestry building
update relationship set defines_ancestry = 1 where relationship_id = 'VAProd - RxNorm eq';

-- Rename RxNorm to ATC relationships from FDB to RxNorm
update relationship set relationship_name = 'ATC to RxNorm (RxNorm)' where relationship_id = 'ATC - RxNorm';
update relationship set relationship_name = 'RxNorm to ATC (RxNorm)' where relationship_id = 'RxNorm - ATC';

-- Add missing NDF-RT relationships
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'VA Class to ATC equivalent (NDF-RT)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('VA Class to ATC eq', 'VA Class to ATC equivalent (NDF-RT)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'VA Class to ATC equivalent (NDF-RT)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'ATC to VA Class equivalent (NDF-RT)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('ATC to VA Class eq', 'ATC to VA Class equivalent (NDF-RT)', 0, 0, 'VA Class to ATC eq', (select concept_id from concept where concept_name = 'ATC to VA Class equivalent (NDF-RT)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'ATC to VA Class eq' where relationship_id = 'VA Class to ATC eq';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'NDFRT to ATC equivalent (NDF-RT)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('NDFRT to ATC eq', 'NDFRT to ATC equivalent (NDF-RT)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'NDFRT to ATC equivalent (NDF-RT)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'ATC to NDFRT equivalent (NDF-RT)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('ATC to NDFRT eq', 'ATC to NDFRT equivalent (NDF-RT)', 0, 0, 'VA Class to ATC eq', (select concept_id from concept where concept_name = 'ATC to NDFRT equivalent (NDF-RT)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'ATC to NDFRT eq' where relationship_id = 'NDFRT to ATC eq';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'VA Class to NDFRT equivalent (NDF-RT)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('VA Class to NDFRT eq', 'VA Class to NDFRT equivalent (NDF-RT)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'VA Class to NDFRT equivalent (NDF-RT)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'NDFRT to VA Class equivalent (NDF-RT)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('NDFRT to VA Class eq', 'NDFRT to VA Class equivalent (NDF-RT)', 0, 0, 'VA Class to NDFRT eq', (select concept_id from concept where concept_name = 'NDFRT to VA Class equivalent (NDF-RT)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'NDFRT to VA Class eq' where relationship_id = 'VA Class to NDFRT eq';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Chemical Structure to Pharmaceutical Preparation equivalent (NDF-RT)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Chem to Prep eq', 'Chemical Structure to Pharmaceutical Preparation equivalent (NDF-RT)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'Chemical Structure to Pharmaceutical Preparation equivalent (NDF-RT)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pharmaceutical Preparation to Chemical Structure equivalent (NDF-RT)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Prep to Chem eq', 'Pharmaceutical Preparation to Chemical Structure equivalent (NDF-RT)', 0, 0, 'Chem to Prep eq', (select concept_id from concept where concept_name = 'Pharmaceutical Preparation to Chemical Structure equivalent (NDF-RT)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'Prep to Chem eq' where relationship_id = 'Chem to Prep eq';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Chemical Structure to Pharmaceutical Preparation equivalent (NDF-RT)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Chem to Prep eq', 'Chemical Structure to Pharmaceutical Preparation equivalent (NDF-RT)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'Chemical Structure to Pharmaceutical Preparation equivalent (NDF-RT)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pharmaceutical Preparation to Chemical Structure equivalent (NDF-RT)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Prep to Chem eq', 'Pharmaceutical Preparation to Chemical Structure equivalent (NDF-RT)', 0, 0, 'Chem to Prep eq', (select concept_id from concept where concept_name = 'Pharmaceutical Preparation to Chemical Structure equivalent (NDF-RT)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'Prep to Chem eq' where relationship_id = 'Chem to Prep eq';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'SNOMED to RxNorm equivalent (RxNorm)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('SNOMED - RxNorm eq', 'SNOMED to RxNorm equivalent (RxNorm)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'SNOMED to RxNorm equivalent (RxNorm)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'RxNorm to SNOMED equivalent (RxNorm)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('RxNorm - SNOMED eq', ' RxNorm to SNOMED equivalent (RxNorm)', 0, 0, 'SNOMED - RxNorm eq', (select concept_id from concept where concept_name = 'RxNorm to SNOMED equivalent (RxNorm)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'RxNorm - SNOMED eq' where relationship_id = 'SNOMED - RxNorm eq';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'SNOMED to NDF-RT equivalent (RxNorm)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('SNOMED - NDFRT eq', 'SNOMED to NDF-RT equivalent (RxNorm)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'SNOMED to NDF-RT equivalent (RxNorm)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'NDF-RT to SNOMED equivalent (RxNorm)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('NDFRT - SNOMED eq', 'NDF-RT to SNOMED equivalent (RxNorm)', 0, 0, 'SNOMED - NDFRT eq', (select concept_id from concept where concept_name = 'NDF-RT to SNOMED equivalent (RxNorm)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'NDFRT - SNOMED eq' where relationship_id = 'SNOMED - NDFRT eq';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'SNOMED to VA Class equivalent (RxNorm)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('SNOMED - VA Class eq', 'SNOMED to VA Class equivalent (RxNorm)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'SNOMED to VA Class equivalent (RxNorm)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'VA Class to SNOMED equivalent (RxNorm)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('VA Class - SNOMED eq', 'VA Class to SNOMED equivalent (RxNorm)', 0, 0, 'SNOMED - VA Class eq', (select concept_id from concept where concept_name = 'VA Class to SNOMED equivalent (RxNorm)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'VA Class - SNOMED eq' where relationship_id = 'SNOMED - VA Class eq';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'SNOMED to ATC equivalent (RxNorm)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('SNOMED - ATC eq', 'SNOMED to ATC equivalent (RxNorm)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'SNOMED to ATC equivalent (RxNorm)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'ATC to SNOMED equivalent (RxNorm)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('ATC - SNOMED eq', 'ATC to SNOMED equivalent (RxNorm)', 0, 0, 'SNOMED - ATC eq', (select concept_id from concept where concept_name = 'ATC to SNOMED equivalent (RxNorm)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'ATC - SNOMED eq' where relationship_id = 'SNOMED - ATC eq';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has product component (NDF-RT)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Has product comp', 'Has product component (NDF-RT)', 1, 0, 'Is a', (select concept_id from concept where concept_name = 'Has product component (NDF-RT)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Product component of (NDF-RT)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Product comp of', 'Product component of (NDF-RT)', 1, 1, 'Has product comp', (select concept_id from concept where concept_name = 'Product component of (NDF-RT)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'Product comp of' where relationship_id = 'Has product comp';

-- Fix the RxNorm relationships
update relationship set is_hierarchical=1 where relationship_id='RxNorm is a';
update relationship set defines_ancestry=1 where relationship_id='Has quantified form';
update relationship set defines_ancestry=0 where relationship_id='Quantified form of';

-- fix some asymmetrical relationship-reverse relationships
update relationship set is_hierarchical=0 where relationship_id='ICD9P - SNOMED eq';
update relationship set is_hierarchical=1 where relationship_id='Is domain';

-- fix some hierarchical relationships not asigned that way and therefore creating wrong min_levels_of_separation
update relationship set is_hierarchical=1 where relationship_id='Inferred class of';
update relationship set is_hierarchical=1 where relationship_id='Has inferred class';
update relationship set is_hierarchical=1 where relationship_id='Is FDA-appr ind of';
update relationship set is_hierarchical=1 where relationship_id='Has FDA-appr ind';
update relationship set is_hierarchical=1 where relationship_id='Is off-label ind of';	
update relationship set is_hierarchical=1 where relationship_id='Has off-label ind';

-- Add SPL concept classes
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'FDA Product Type Vaccine', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Vaccine', 'Vaccine', (select concept_id from concept where concept_name = 'FDA Product Type Vaccine'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'FDA Product Type Standardized Allergenic', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Standard Allergenic', 'FDA Product Type Standardized Allergenic', (select concept_id from concept where concept_name = 'FDA Product Type Standardized Allergenic'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'FDA Product Type Human Prescription Drug', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Prescription Drug', 'FDA Product Type Human Prescription Drug', (select concept_id from concept where concept_name = 'FDA Product Type Human Prescription Drug'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'FDA Product Type Human OTC Drug', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('OTC Drug', 'FDA Product Type Human OTC Drug', (select concept_id from concept where concept_name = 'FDA Product Type Human OTC Drug'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'FDA Product Type Plasma Derivative', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Plasma Derivative', 'FDA Product Type Plasma Derivative', (select concept_id from concept where concept_name = 'FDA Product Type Plasma Derivative'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'FDA Product Type Non-Standardized Allergenic', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Non-Stand Allergenic', 'FDA Product Type Non-Standardized Allergenic', (select concept_id from concept where concept_name = 'FDA Product Type Non-Standardized Allergenic'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'FDA Product Type Cellular Therapy', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Cellular Therapy', 'FDA Product Type Cellular Therapy', (select concept_id from concept where concept_name = 'FDA Product Type Cellular Therapy'));

-- Add RxNorm concept classes
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Quantified Clinical Drug', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Quant Clinical Drug', 'Quantified Clinical Drug', (select concept_id from concept where concept_name = 'Quantified Clinical Drug'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Quantified Branded Drug', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Quant Branded Drug', 'Quantified Branded Drug', (select concept_id from concept where concept_name = 'Quantified Branded Drug'));

-- Add RxNorm special mapping to Quantified Drugs and Packs we need to re-map to Clinical/Branded Drug
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Original but remapped Non-standard to Standard map (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Original maps to', 'Original but remapped Non-standard to Standard map (OMOP)', 1, 0, 'Is a', (select concept_id from concept where concept_name = 'Original but remapped Non-standard to Standard map (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Original but remapped Standard to Non-standard map (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Original mapped from', 'Original but remapped Standard to Non-standard map (OMOP)', 1, 1, 'Has product comp', (select concept_id from concept where concept_name = 'Original but remapped Standard to Non-standard map (OMOP)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'Original mapped from' where relationship_id = 'Original maps to';

-- Add SPL to RxNorm mapping (instead of Maps to)
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'SPL to RxNorm (NLM)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('SPL - RxNorm', 'SPL to RxNorm (NLM)', 1, 0, 'Is a', (select concept_id from concept where concept_name = 'SPL to RxNorm (NLM)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'RxNorm to SPL (NLM)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('RxNorm - SPL', 'RxNorm to SPL (NLM)', 1, 1, 'Has product comp', (select concept_id from concept where concept_name = 'RxNorm to SPL (NLM)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id = 'RxNorm - SPL' where relationship_id = 'SPL - RxNorm';

select * from concept_class where concept_class_id like 'ICD9CM%';
select * from concept where concept_class_id='ICD9CM E code';
select * from concept_class where concept_class_concept_id=44819260;

update concept set invalid_reason='D', valid_end_date='3-Jan-2015' where concept_id=44819260;
update concept set invalid_reason='D', valid_end_date='3-Jan-2015' where concept_id=44819261;
update concept set invalid_reason='D', valid_end_date='3-Jan-2015' where concept_id=44819259;
update concept set invalid_reason='D', valid_end_date='3-Jan-2015' where concept_id=45754823;

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '3-digit billing ICD9CM code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('3-dig billing code', '3-digit billing ICD9CM code', (select concept_id from concept where concept_name = '3-digit billing ICD9CM code'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '4-digit billing ICD9CM code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('4-dig billing code', '4-digit billing ICD9CM code', (select concept_id from concept where concept_name = '4-digit billing ICD9CM code'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '5-digit billing ICD9CM code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('5-dig billing code', '5-digit billing ICD9CM code', (select concept_id from concept where concept_name = '5-digit billing ICD9CM code'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '4-digit billing ICD9CM E code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('4-dig billing E code', '4-digit billing ICD9CM E code', (select concept_id from concept where concept_name = '4-digit billing ICD9CM E code'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '5-digit billing ICD9CM E code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('5-dig billing E code', '5-digit billing ICD9CM E code', (select concept_id from concept where concept_name = '5-digit billing ICD9CM E code'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '3-digit billing ICD9CM V code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('3-dig billing V code', '3-digit billing ICD9CM V code', (select concept_id from concept where concept_name = '3-digit billing ICD9CM V code'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '4-digit billing ICD9CM V code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('4-dig billing V code', '4-digit billing ICD9CM V code', (select concept_id from concept where concept_name = '4-digit billing ICD9CM V code'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '5-digit billing ICD9CM V code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('5-dig billing V code', '5-digit billing ICD9CM V code', (select concept_id from concept where concept_name = '5-digit billing ICD9CM V code'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '3-digit non-billing ICD9CM code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('3-dig nonbill code', '3-digit non-billing ICD9CM code', (select concept_id from concept where concept_name = '3-digit non-billing ICD9CM code'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '4-digit non-billing ICD9CM code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('4-dig nonbill code', '4-digit non-billing ICD9CM code', (select concept_id from concept where concept_name = '4-digit non-billing ICD9CM code'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '3-digit non-billing ICD9CM V code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('3-dig nonbill V code', '3-digit non-billing ICD9CM V code', (select concept_id from concept where concept_name = '3-digit non-billing ICD9CM V code'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '3-digit non-billing ICD9CM E code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('3-dig nonbill E code', '3-digit non-billing ICD9CM E code', (select concept_id from concept where concept_name = '3-digit non-billing ICD9CM E code'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '4-digit non-billing ICD9CM E code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('4-dig nonbill E code', '4-digit non-billing ICD9CM E code', (select concept_id from concept where concept_name = '4-digit non-billing ICD9CM E code'));

commit;

-- Not done yet:
-- Change all relationships containing replaces or replaces by to these. Remove the extra relationships
update concept_relationship set relationship_id = 'Concept replaces' where relationship_id in (
  'LOINC replaces',
  'RxNorm replaces',
  'SNOMED replaces',
  'ICD9P replaces',
  'UCUM replaces'
);
update concept_relationship set relationship_id = 'Concept replaced by' where relationship_id in (
  'LOINC replaced by',
  'RxNorm replaced by',
  'SNOMED replaced by',
  'ICD9P replaced by',
  'UCUM replaced by'
);
update concept set 
  valid_end_date = '10-Jan-2015',
  invalid_reason = 'D'
where concept_id in (
  44818714, -- LOINC replaced by
  44818812, -- LOINC replaces
  44818946, -- RxNorm replaced by
  44818947, -- RxNorm replaces
  44818948, -- SNOMED replaced by
  44818949, -- SNOMED replaces
  44818971, -- ICD9P replaced by
  44818972, -- ICD9P replaces
  44818978, -- UCUM replaced by
  44818979 -- UCUM replaces
);
delete from relationship where relationship_id in (
  'LOINC replaces',
  'RxNorm replaces',
  'SNOMED replaces',
  'ICD9P replaces',
  'UCUM replaces',
  'LOINC replaced by',
  'RxNorm replaced by',
  'SNOMED replaced by',
  'ICD9P replaced by',
  'UCUM replaced by'
);

