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
values ('Original maps to', 'Original but remapped Non-standard to Standard map (OMOP)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'Original but remapped Non-standard to Standard map (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Original but remapped Standard to Non-standard map (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Original mapped from', 'Original but remapped Standard to Non-standard map (OMOP)', 0, 0, 'Original maps to', (select concept_id from concept where concept_name = 'Original but remapped Standard to Non-standard map (OMOP)'));
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

-- Add ICD9Proc classes and concepts and rename above ICD9CM concepts
update concept set concept_name = '3-digit billing code' where concept_name = '3-digit billing ICD9CM code';
update concept set concept_name = '4-digit billing code' where concept_name = '4-digit billing ICD9CM code';
update concept set concept_name = '5-digit billing code' where concept_name = '5-digit billing ICD9CM code';
update concept set concept_name = '4-digit billing E code' where concept_name = '4-digit billing ICD9CM E code';
update concept set concept_name = '5-digit billing E code' where concept_name = '5-digit billing ICD9CM E code';
update concept set concept_name = '3-digit billing V code' where concept_name = '3-digit billing ICD9CM V code';
update concept set concept_name = '4-digit billing V code' where concept_name = '4-digit billing ICD9CM V code';
update concept set concept_name = '5-digit billing V code' where concept_name = '5-digit billing ICD9CM V code';
update concept set concept_name = '3-digit non-billing code' where concept_name = '3-digit non-billing ICD9CM code';
update concept set concept_name = '4-digit non-billing code' where concept_name = '4-digit non-billing ICD9CM code';
update concept set concept_name = '3-digit non-billing V code' where concept_name = '3-digit non-billing ICD9CM V code';
update concept set concept_name = '3-digit non-billing E code' where concept_name = '3-digit non-billing ICD9CM E code';
update concept set concept_name = '4-digit non-billing E code' where concept_name = '4-digit non-billing ICD9CM E code';
update concept_class set concept_class_name = '3-digit billing code' where concept_class_name = '3-digit billing ICD9CM code';
update concept_class set concept_class_name = '4-digit billing code' where concept_class_name = '4-digit billing ICD9CM code';
update concept_class set concept_class_name = '5-digit billing code' where concept_class_name = '5-digit billing ICD9CM code';
update concept_class set concept_class_name = '4-digit billing E code' where concept_class_name = '4-digit billing ICD9CM E code';
update concept_class set concept_class_name = '5-digit billing E code' where concept_class_name = '5-digit billing ICD9CM E code';
update concept_class set concept_class_name = '3-digit billing V code' where concept_class_name = '3-digit billing ICD9CM V code';
update concept_class set concept_class_name = '4-digit billing V code' where concept_class_name = '4-digit billing ICD9CM V code';
update concept_class set concept_class_name = '5-digit billing V code' where concept_class_name = '5-digit billing ICD9CM V code';
update concept_class set concept_class_name = '3-digit non-billing code' where concept_class_name = '3-digit non-billing ICD9CM code';
update concept_class set concept_class_name = '4-digit non-billing code' where concept_class_name = '4-digit non-billing ICD9CM code';
update concept_class set concept_class_name = '3-digit non-billing V code' where concept_class_name = '3-digit non-billing ICD9CM V code';
update concept_class set concept_class_name = '3-digit non-billing E code' where concept_class_name = '3-digit non-billing ICD9CM E code';
update concept_class set concept_class_name = '4-digit non-billing E code' where concept_class_name = '4-digit non-billing ICD9CM E code';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '2-digit non-billing code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('2-dig nonbill code', '2-digit non-billing code', (select concept_id from concept where concept_name = '2-digit non-billing code'));

-- Add additional mapping relationships for de-coordinating h/o, fh/o, need for vaccination, etc.
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Non-standard to operator concept map (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Maps to operator', 'Non-standard to operator concept map (OMOP)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'Non-standard to operator concept map (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Operator concept to non-standard map (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Operator mapped from', 'Operator concept to non-standard map (OMOP)', 0, 0, 'Maps to operator', (select concept_id from concept where concept_name = 'Operator concept to non-standard map (OMOP)'));
update relationship -- The reverse wasn't in at the time of writing
set reverse_relationship_id = 'Operator mapped from' where relationship_id = 'Maps to operator';
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Non-standard to value_as_number map (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Maps to number', 'Non-standard to value_as_number map (OMOP)', 0, 0, 'Is a', (select concept_id from concept where concept_name = 'Non-standard to value_as_number map (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Value_as_number to non-standard map (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Number mapped from', 'Value_as_number to non-standard map (OMOP)', 0, 0, 'Maps to number', (select concept_id from concept where concept_name = 'Value_as_number to non-standard map (OMOP)'));
update relationship -- The reverse wasn't in at the time of writing
set reverse_relationship_id = 'Number mapped from' where relationship_id = 'Maps to number';

-- Make ETC relationships hierarchical, they connect clinical/branded drugs to class directly. Should be 2, really.
update relationship set is_hierarchical=1 where relationship_id in ('ETC - RxNorm', 'RxNorm - ETC');

-- Undeprecate relationships ICD9P - SNOMED eq (most of them killed in April 2014 release)
update concept_relationship r set
  valid_end_date = '31-Dec-2099',
  invalid_reason = null
where r.relationship_id='ICD9P - SNOMED eq'
and exists (
  select 1 from (
    select distinct 
      concept_id_1,
      first_value(concept_id_2) over (partition by concept_id_1 order by valid_end_date desc) as concept_id_2,
      relationship_id
    from concept_relationship
    where relationship_id='ICD9P - SNOMED eq'
  ) youngest
  where youngest.concept_id_1=r.concept_id_1
  and youngest.concept_id_2=r.concept_id_2 
  and youngest.relationship_id=r.relationship_id
)
;

-- Remove ICD10 duplicates and create replacement relationships
insert into concept_relationship
select distinct
  first_value(e.concept_id) over (partition by e.concept_code order by e.concept_id desc) as concept_id_1,
  first_value(e.concept_id) over (partition by e.concept_code order by e.concept_id) as concept_id_2,
  'Concept replaced by' as relationship_id,
  '12-Feb-2015' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from concept e
join (
  select concept_code, count(8) from concept where vocabulary_id='ICD10' and invalid_reason is null group by concept_code having count(8)=2
) d on d.concept_code=e.concept_code 
where e.vocabulary_id='ICD10'
;

insert into concept_relationship
select distinct
  first_value(e.concept_id) over (partition by e.concept_code order by e.concept_id) as concept_id_1,
  first_value(e.concept_id) over (partition by e.concept_code order by e.concept_id desc) as concept_id_2,
  'Concept replaces' as relationship_id,
  '12-Feb-2015' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from concept e
join (
  select concept_code, count(8) from concept where vocabulary_id='ICD10' and invalid_reason is null group by concept_code having count(8)=2
) d on d.concept_code=e.concept_code 
where e.vocabulary_id='ICD10'
;

update concept c set 
  concept_name = 'Duplicate of ICD10 Concept, do not use, use replacement Concept from CONCEPT_RELATIONSHIP table instead',
  concept_code = concept_id,
  valid_end_date = '11-Feb-2015',
  invalid_reason = 'U'
where c.vocabulary_id='ICD10'
and exists (
  select 1 from (
    select distinct
      first_value(e.concept_id) over (partition by e.concept_code order by e.concept_id desc) as concept_id
    from concept e
    join (
      select concept_code, count(8) from concept where vocabulary_id='ICD10' and invalid_reason is null group by concept_code having count(8)=2
    ) d on d.concept_code=e.concept_code 
    where e.vocabulary_id='ICD10'
  ) f
  where f.concept_id=c.concept_id
)
;

-- ICD10 Hierarchy concept classes
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'ICD10 Hierarchy', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('ICD10 Hierarchy', 'ICD10 Hierarchy', (select concept_id from concept where concept_name = 'ICD10 Hierarchy'));

-- Charlie Bailey's redeclaration of Measurement Types
update concept set concept_name = 'From physical examination' where concept_id = '44818701'; -- was 'Vital sign'
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Derived value', 'Meas Type', 'Meas Type', 'Meas Type', 'S', 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);

-- Remove ICD10 dotless duplicates and create replacement relationships
insert into concept_relationship
select distinct
  dotless.concept_id as concept_id_1,
  withdot.concept_id as concept_id_2,
  'Concept replaced by' as relationship_id,
  '12-Feb-2015' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from v5dev.concept dotless
join v5dev.concept withdot on dotless.concept_code=translate(withdot.concept_code, '1.', '1') and dotless.vocabulary_id=withdot.vocabulary_id and dotless.concept_code!=withdot.concept_code
where dotless.vocabulary_id='ICD10' 
and length(dotless.concept_code) between 4 and 7 
and instr(dotless.concept_code, '.')=0 and instr(dotless.concept_code, '-')=0
;

insert into concept_relationship
select distinct
  withdot.concept_id as concept_id_1,
  dotless.concept_id as concept_id_2,
  'Concept replaces' as relationship_id,
  '12-Feb-2015' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from v5dev.concept dotless
join v5dev.concept withdot on dotless.concept_code=translate(withdot.concept_code, '1.', '1') and dotless.vocabulary_id=withdot.vocabulary_id and dotless.concept_code!=withdot.concept_code
where dotless.vocabulary_id='ICD10' 
and length(dotless.concept_code) between 4 and 7 
and instr(dotless.concept_code, '.')=0 and instr(dotless.concept_code, '-')=0
;

-- deprecate those and set to 'U' and 'D' if there are withdot-alternatives
update concept dotless set 
  dotless.concept_name = 'Duplicate of ICD10 Concept, do not use, use replacement Concept from CONCEPT_RELATIONSHIP table instead',
  dotless.valid_end_date = '11-Feb-2015',
  dotless.invalid_reason = 'U'
where dotless.vocabulary_id='ICD10' 
and exists (
  select 1 from v5dev.concept withdot where dotless.concept_code=translate(withdot.concept_code, '1.', '1') and dotless.vocabulary_id=withdot.vocabulary_id and dotless.concept_code!=withdot.concept_code
)
and length(dotless.concept_code) between 4 and 7 
and instr(dotless.concept_code, '.')=0 and instr(dotless.concept_code, '-')=0
;

update concept dotless set 
  dotless.concept_name = 'Duplicate of ICD10 Concept, do not use, use replacement Concept from CONCEPT_RELATIONSHIP table instead',
  dotless.valid_end_date = '11-Feb-2015',
  dotless.invalid_reason = 'D'
where dotless.vocabulary_id='ICD10' 
and not exists (
  select 1 from v5dev.concept withdot where dotless.concept_code=translate(withdot.concept_code, '1.', '1') and dotless.vocabulary_id=withdot.vocabulary_id and dotless.concept_code!=withdot.concept_code
)
and length(dotless.concept_code) between 4 and 7 
and instr(dotless.concept_code, '.')=0 and instr(dotless.concept_code, '-')=0
;

-- turn those that are not ICD10 into ICD10CM
update concept c set vocabulary_id='ICD10CM'
where c.vocabulary_id='ICD10' and c.invalid_reason is null
and not exists (
  select 1 from dev_christian.manual_icd10 m where m.concept_code=c.concept_code 
)
;

-- update those that are truly ICD10
update concept c set 
  (c.concept_name, c.concept_class_id, c.valid_start_date, c.valid_end_date, invalid_reason) = 
  (
    select m.concept_name, m.concept_class_id, m.valid_start_date, m.valid_end_date, m.invalid_reason
    from dev_christian.manual_icd10 m where m.concept_code=c.concept_code
  )
where c.vocabulary_id='ICD10'
and exists (
  select 1 from dev_christian.manual_icd10 m where m.concept_code=c.concept_code
);

-- Add the missing ones
insert into concept
select 
  v5_concept.nextval as concept_id,
  m.concept_name,
  'Condition' as domain_id,
  'ICD10' as vocabulary_id,
  m.concept_class_id,
  m.standard_concept,
  m.concept_code,
  m.valid_start_date,
  m.valid_end_date,
  m.invalid_reason
from dev_christian.manual_icd10 m
join (
  select distinct concept_code from dev_christian.manual_icd10 
  minus
  select concept_code from concept where vocabulary_id='ICD10'
) f on f.concept_code=m.concept_code
;

-- Fix missing concept_class_id in MedDRA from old v4
update concept meddra set 
  meddra.concept_class_id = (
    select 
      case om.concept_class
        when 'High Level Group Term' then 'HLGT'
        when 'Preferred Term' then 'PT'
        when 'High Level Term' then 'HLT'
        when 'System Organ Class' then 'SOC'
        when 'Lowest Level Term' then 'LLT'
      end as concept_class_id
    from dev.concept om
    where om.vocabulary_id=15
    and om.concept_id=meddra.concept_id
  )
where meddra.vocabulary_id='MedDRA'
;

-- Deprecate LLT-PT duplicates and remove concept_codes from MedDRA. Keep the PT. Create replaced by records in the concept_relationship table
insert into concept_relationship
select distinct
  llt.concept_id as concept_id_1,
  pt.concept_id as concept_id_2,
  'Concept replaced by' as relationship_id,
  '12-Feb-2015' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from dev.concept llt
join dev.concept pt on llt.concept_code=pt.concept_code and pt.vocabulary_id=llt.vocabulary_id
where llt.vocabulary_id=15
and llt.concept_class='Lowest Level Term'
and pt.concept_class='Preferred Term'
;

insert into concept_relationship
select distinct
  pt.concept_id as concept_id_1,
  llt.concept_id as concept_id_2,
  'Concept replaces' as relationship_id,
  '12-Feb-2015' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from dev.concept llt
join dev.concept pt on llt.concept_code=pt.concept_code and pt.vocabulary_id=llt.vocabulary_id
where llt.vocabulary_id=15
and llt.concept_class='Lowest Level Term'
and pt.concept_class='Preferred Term'
;

update concept llt set 
  llt.concept_name = 'MedDRA LLT duplicate of PT Concept, do not use, use PT Concept indicatd by the CONCEPT_RELATIONSHIP table instead',
  llt.concept_code = llt.concept_id,
  llt.valid_end_date = '11-Feb-2015',
  llt.invalid_reason = 'U'
where llt.vocabulary_id='MedDRA' 
and llt.concept_class_id='LLT'
and exists (
  select 1
  from (
    select concept_code, count(8)
    from concept 
    where vocabulary_id='MedDRA'
    group by concept_code having count(8)>1
  ) d 
  where d.concept_code=llt.concept_code
)
;

-- de-standardize the deprecated MedDRA concepts
update concept set
  standard_concept = null
where concept_name = 'MedDRA LLT duplicate of PT Concept, do not use, use PT Concept indicatd by the CONCEPT_RELATIONSHIP table instead'
;

-- Addition of 4-digit nonbilling V code. 
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '4-digit non-billing V code', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('4-dig nonbill V code', '4-digit non-billing V code', (select concept_id from concept where concept_name = '4-digit non-billing V code'));

-- Deprecate all concept_relationship records of relationship_id = 'Maps to' which violate the following rules:
-- - concept in concept_id_1 != 'C'
-- - concept in concept_id_2 has not standard_concept = 'S' (has 'C' or null instead)
-- - concept in concept_id_2 has invalid_reason is null

update concept_relationship set 
  valid_end_date = '1-Mar-2015',
  invalid_reason='D'
where relationship_id = 'Maps to'
and invalid_reason is null
and concept_id_1 in (
    select concept_id from v5dev.concept
    where standard_concept = 'C'
);

update concept_relationship set 
  valid_end_date = '1-Mar-2015',
  invalid_reason='D'
where relationship_id = 'Mapped from'
and invalid_reason is null
and concept_id_2 in (
    select concept_id from v5dev.concept
    where standard_concept = 'C'
);

update concept_relationship set 
  valid_end_date = '1-Mar-2015',
  invalid_reason='D'
where relationship_id = 'Maps to'
and invalid_reason is null
and concept_id_2 in (
    select concept_id from v5dev.concept
    where nvl(standard_concept, 'X') <> 'S'
);

update concept_relationship set 
  valid_end_date = '1-Mar-2015',
  invalid_reason='D'
where relationship_id = 'Mapped from'
and invalid_reason is null
and concept_id_1 in (
    select concept_id from v5dev.concept
    where nvl(standard_concept, 'X') <> 'S'
);

update concept_relationship set 
  valid_end_date = '1-Mar-2015',
  invalid_reason='D'
where relationship_id = 'Maps to'
and invalid_reason is null
and concept_id_2 in (
    select concept_id from v5dev.concept
    where invalid_reason is not null
);

update concept_relationship set 
  valid_end_date = '1-Mar-2015',
  invalid_reason='D'
where relationship_id = 'Mapped from'
and invalid_reason is null
and concept_id_1 in (
    select concept_id from v5dev.concept
    where invalid_reason is not null
);

-- Add ABMS specialties
-- Add the new vocabulary ABMS
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Provider Specialty (American Board of Medical Specialties)', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);	
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id)
values ('ABMS', 'Provider Specialty (American Board of Medical Specialties)', 'http://www.abms.org/member-boards/specialty-subspecialty-certificates', '', (select concept_id from concept where concept_name = 'Provider Specialty (American Board of Medical Specialties)'));

-- ABMS specialty concepts
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Adolescent Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Adult Congenital Heart Disease', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Advanced Heart Failure and Transplant Cardiology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Aerospace Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Anesthesiology Critical Care Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Blood Banking/Transfusion Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Brain Injury Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Cardiovascular Disease', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Child Abuse Pediatrics', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Child and Adolescent Psychiatry', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Clinical Biochemical Genetics', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Clinical Cardiac Electrophysiology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Clinical Cytogenetics', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Clinical Genetics (MD)', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Clinical Informatics', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Clinical Molecular Genetics', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Clinical Neurophysiology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Complex General Surgical Oncology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Congenital Cardiac Surgery', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Cytopathology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Dermatopathology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Developmental-Behavioral Pediatrics', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Diagnostic Radiology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Emergency Medical Services', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Endocrinology, Diabetes and Metabolism', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Epilepsy', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Female Pelvic Medicine and Reconstructive Surgery', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Female Pelvic Medicine and Reconstructive Surgery', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Forensic Psychiatry', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Geriatric Psychiatry', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Hospice and Pallative Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Internal Medicine - Critical Care Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Interventional Cardiology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Maternal and Fetal Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Medical Biochemical Genetics', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Medical Genetics and Genomics', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Medical Physics', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Medical Toxicology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Molecular Genetic Pathology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Neonatal-Perinatal Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Neurodevelopmental Disabilities', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Neurology with Special Qualification in Child Neurology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Neuromuscular Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Neuropathology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Neuroradiology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Neurotology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Nuclear Radiology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Orthopaedic Sports Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pathology - Anatomic', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pathology - Chemical', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pathology - Clinical', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pathology - Forensic', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pathology - Hematology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pathology - Medical Microbiology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pathology - Molecular Genetic', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pathology - Pediatric', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pathology-Anatomic/Pathology-Clinical', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Anesthesiology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Cardiology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Critical Care Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Dermatology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Emergency Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Endocrinology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Gastroenterology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Hematology-Oncology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Infectious Diseases', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Nephrology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Otolaryngology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Pulmonology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Radiology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Rehabilitation Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Rheumatology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Surgery', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Transplant Hepatology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pediatric Urology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Plastic Surgery Within the Head and Neck', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Psychosomatic Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Public Health and General Preventive Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Radiology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Reproductive Endocrinology/Infertility', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Sleep Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Sports Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Surgical Critical Care', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Thoracic and Cardiac Surgery', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Transplant Hepatology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Undersea and Hyperbaric Medicine', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Vascular and Interventional Radiology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Vascular Neurology', 'Provider Specialty', 'ABMS', 'Specialty', 'S', 'OMOP generated', '01-Jan-1970', '31-Dec-2099', null);

-- Add various type concepts 
-- Condition Types
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim header - 1st position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim header - 2nd position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim header - 3rd position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim header - 4th position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim header - 5th position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim header - 6th position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim header - 7th position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim header - 8th position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 1st position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 2nd position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 3rd position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 4th position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 5th position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 6th position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 7th position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 8th position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 9th position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 10th position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 11th position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 12th position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 13th position', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
-- Procedure Types
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail – 2nd position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail – 3rd position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 4th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 5th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 6th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 7th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 8th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 9th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 10th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 11th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 12th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 13th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 14th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 15th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 16th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 17th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 18th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 19th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 20th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 21th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 22th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 23th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 24th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 25th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 26th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 27th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 28th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 29th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 30th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 31th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 32th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 33th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 34th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 35th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 36th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 37th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 38th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 39th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 40th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 41th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 42th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 43th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 44th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Outpatient detail - 45th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 1st position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 2nd position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 3rd position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 4th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 5th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 6th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 7th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 8th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 9th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 10th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 11th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 12th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval,'Carrier claim detail - 13th position', 'Procedure Type', 'Procedure Type', 'Procedure Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

-- Add domain concepts 
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (56, 'Person', 'Metadata', 'Domain', 'Domain', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (57, 'Care site', 'Metadata', 'Domain', 'Domain', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

-- Add SNOMED UK units
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'component', 'Unit', 'SNOMED', 'Qualifier Value', null, '10368211000001101', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'mega u/ml', 'Unit', 'SNOMED', 'Qualifier Value', null, '10368511000001103', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'g/dose', 'Unit', 'SNOMED', 'Qualifier Value', null, '10691711000001108', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'mg/dose', 'Unit', 'SNOMED', 'Qualifier Value', null, '10691811000001100', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'microgram/dose', 'Unit', 'SNOMED', 'Qualifier Value', null, '10691911000001105', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'unit/dose', 'Unit', 'SNOMED', 'Qualifier Value', null, '10692011000001103', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'application', 'Unit', 'SNOMED', 'Qualifier Value', null, '10692211000001108', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'g/application', 'Unit', 'SNOMED', 'Qualifier Value', null, '10692311000001100', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'mg/application', 'Unit', 'SNOMED', 'Qualifier Value', null, '10692411000001107', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'tuberculin units/ML', 'Unit', 'SNOMED', 'Qualifier Value', null, '10692511000001106', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'cigarette', 'Unit', 'SNOMED', 'Qualifier Value', null, '10692611000001105', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'gram/gram', 'Unit', 'SNOMED', 'Qualifier Value', null, '10692711000001101', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'month supply', 'Unit', 'SNOMED', 'Qualifier Value', null, '10692811000001109', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'week supply', 'Unit', 'SNOMED', 'Qualifier Value', null, '10692911000001104', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'SQ-T', 'Unit', 'SNOMED', 'Qualifier Value', null, '10693011000001107', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'HEP', 'Unit', 'SNOMED', 'Qualifier Value', null, '10693111000001108', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Cell', 'Unit', 'SNOMED', 'Qualifier Value', null, '10693211000001102', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'cell/microliter', 'Unit', 'SNOMED', 'Qualifier Value', null, '10693311000001105', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'insert', 'Unit', 'SNOMED', 'Qualifier Value', null, '10693411000001103', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'film', 'Unit', 'SNOMED', 'Qualifier Value', null, '10693511000001104', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'drop', 'Unit', 'SNOMED', 'Qualifier Value', null, '10693611000001100', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'unit/drop', 'Unit', 'SNOMED', 'Qualifier Value', null, '10693711000001109', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'no value', 'Unit', 'SNOMED', 'Qualifier Value', null, '3314211000001106', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '%w/w', 'Unit', 'SNOMED', 'Qualifier Value', null, '3314511000001109', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '%v/w', 'Unit', 'SNOMED', 'Qualifier Value', null, '3314611000001108', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'ml/l', 'Unit', 'SNOMED', 'Qualifier Value', null, '3315911000001103', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'molar', 'Unit', 'SNOMED', 'Qualifier Value', null, '3316111000001107', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'obsolete-mM', 'Unit', 'SNOMED', 'Qualifier Value', null, '3316211000001101', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'mmol/ml', 'Unit', 'SNOMED', 'Qualifier Value', null, '3316311000001109', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'unit', 'Unit', 'SNOMED', 'Qualifier Value', null, '3316411000001102', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'baguette', 'Unit', 'SNOMED', 'Qualifier Value', null, '3316811000001100', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'carton', 'Unit', 'SNOMED', 'Qualifier Value', null, '3317011000001109', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'cartridge', 'Unit', 'SNOMED', 'Qualifier Value', null, '3317111000001105', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'cycle', 'Unit', 'SNOMED', 'Qualifier Value', null, '3317211000001104', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'cylinder', 'Unit', 'SNOMED', 'Qualifier Value', null, '3317311000001107', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'dose', 'Unit', 'SNOMED', 'Qualifier Value', null, '3317411000001100', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'lancet', 'Unit', 'SNOMED', 'Qualifier Value', null, '3317611000001102', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'loaf', 'Unit', 'SNOMED', 'Qualifier Value', null, '3317711000001106', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'multipack', 'Unit', 'SNOMED', 'Qualifier Value', null, '3317911000001108', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'nebule', 'Unit', 'SNOMED', 'Qualifier Value', null, '3318011000001105', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'needle', 'Unit', 'SNOMED', 'Qualifier Value', null, '3318111000001106', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'pack', 'Unit', 'SNOMED', 'Qualifier Value', null, '3318211000001100', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'pastille', 'Unit', 'SNOMED', 'Qualifier Value', null, '3318311000001108', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'pessary', 'Unit', 'SNOMED', 'Qualifier Value', null, '3318511000001102', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'pre-filled disposable injection', 'Unit', 'SNOMED', 'Qualifier Value', null, '3318611000001103', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'device', 'Unit', 'SNOMED', 'Qualifier Value', null, '3318711000001107', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'roll', 'Unit', 'SNOMED', 'Qualifier Value', null, '3318811000001104', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'sachet', 'Unit', 'SNOMED', 'Qualifier Value', null, '3318911000001109', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'stocking', 'Unit', 'SNOMED', 'Qualifier Value', null, '3319011000001100', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'strip', 'Unit', 'SNOMED', 'Qualifier Value', null, '3319111000001104', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'syringe', 'Unit', 'SNOMED', 'Qualifier Value', null, '3319311000001102', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'unit dose', 'Unit', 'SNOMED', 'Qualifier Value', null, '3319711000001103', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'catheter', 'Unit', 'SNOMED', 'Qualifier Value', null, '3319911000001101', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'dressing', 'Unit', 'SNOMED', 'Qualifier Value', null, '3320111000001103', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'suture', 'Unit', 'SNOMED', 'Qualifier Value', null, '3320311000001101', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'truss', 'Unit', 'SNOMED', 'Qualifier Value', null, '3320411000001108', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'plaster', 'Unit', 'SNOMED', 'Qualifier Value', null, '3320711000001102', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'applicator', 'Unit', 'SNOMED', 'Qualifier Value', null, '3321011000001108', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'pot', 'Unit', 'SNOMED', 'Qualifier Value', null, '3321111000001109', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'pizza base', 'Unit', 'SNOMED', 'Qualifier Value', null, '3321311000001106', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'piece', 'Unit', 'SNOMED', 'Qualifier Value', null, '3321411000001104', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'glove', 'Unit', 'SNOMED', 'Qualifier Value', null, '3321511000001100', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'pillule', 'Unit', 'SNOMED', 'Qualifier Value', null, '4027311000001102', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'actuation', 'Unit', 'SNOMED', 'Qualifier Value', null, '4034511000001102', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'spoonful', 'Unit', 'SNOMED', 'Qualifier Value', null, '4034811000001104', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'enema', 'Unit', 'SNOMED', 'Qualifier Value', null, '700476008', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'mg/square cm', 'Unit', 'SNOMED', 'Qualifier Value', null, '8083511000001107', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'container', 'Unit', 'SNOMED', 'Qualifier Value', null, '8084111000001101', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'microliter/g', 'Unit', 'SNOMED', 'Qualifier Value', null, '8088511000001103', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'larva', 'Unit', 'SNOMED', 'Qualifier Value', null, '8090511000001102', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'kBq/ml', 'Unit', 'SNOMED', 'Qualifier Value', null, '8090811000001104', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'generator', 'Unit', 'SNOMED', 'Qualifier Value', null, '8091011000001101', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'system', 'Unit', 'SNOMED', 'Qualifier Value', null, '8091311000001103', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'bandage', 'Unit', 'SNOMED', 'Qualifier Value', null, '8091811000001107', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'straw', 'Unit', 'SNOMED', 'Qualifier Value', null, '8091911000001102', '01-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '%v/v', 'Unit', 'SNOMED', 'Qualifier Value', null, '3314311000001103', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, '%w/v', 'Unit', 'SNOMED', 'Qualifier Value', null, '3314411000001105', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'g/ml', 'Unit', 'SNOMED', 'Qualifier Value', null, '3314711000001104', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'iu/g', 'Unit', 'SNOMED', 'Qualifier Value', null, '3314811000001107', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'iu/mg', 'Unit', 'SNOMED', 'Qualifier Value', null, '3314911000001102', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'kg/l', 'Unit', 'SNOMED', 'Qualifier Value', null, '3315011000001102', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'mega u', 'Unit', 'SNOMED', 'Qualifier Value', null, '3315111000001101', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'mg/16 hours', 'Unit', 'SNOMED', 'Qualifier Value', null, '3315211000001107', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'mg/72 hours', 'Unit', 'SNOMED', 'Qualifier Value', null, '3315311000001104', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'mg/g', 'Unit', 'SNOMED', 'Qualifier Value', null, '3315411000001106', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'mg/kg', 'Unit', 'SNOMED', 'Qualifier Value', null, '3315511000001105', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'mg/mg', 'Unit', 'SNOMED', 'Qualifier Value', null, '3315611000001109', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'microgram/72 hours', 'Unit', 'SNOMED', 'Qualifier Value', null, '3315711000001100', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'ml/kg', 'Unit', 'SNOMED', 'Qualifier Value', null, '3315811000001108', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'ml/ml', 'Unit', 'SNOMED', 'Qualifier Value', null, '3316011000001106', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'unit/gram', 'Unit', 'SNOMED', 'Qualifier Value', null, '3316511000001103', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'unit/mg', 'Unit', 'SNOMED', 'Qualifier Value', null, '3316611000001104', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'ampoule', 'Unit', 'SNOMED', 'Qualifier Value', null, '3316711000001108', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'capsule', 'Unit', 'SNOMED', 'Qualifier Value', null, '3316911000001105', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'enema', 'Unit', 'SNOMED', 'Qualifier Value', null, '3317511000001101', '01-Jan-1970', '30-Sep-2014', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'lozenge', 'Unit', 'SNOMED', 'Qualifier Value', null, '3317811000001103', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'patch', 'Unit', 'SNOMED', 'Qualifier Value', null, '3318411000001101', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'suppository', 'Unit', 'SNOMED', 'Qualifier Value', null, '3319211000001105', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'tablet', 'Unit', 'SNOMED', 'Qualifier Value', null, '3319411000001109', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'tube', 'Unit', 'SNOMED', 'Qualifier Value', null, '3319511000001108', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'vial', 'Unit', 'SNOMED', 'Qualifier Value', null, '3319611000001107', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'microgram/actuation', 'Unit', 'SNOMED', 'Qualifier Value', null, '3319811000001106', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'mg/actuation', 'Unit', 'SNOMED', 'Qualifier Value', null, '3320011000001104', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'swab', 'Unit', 'SNOMED', 'Qualifier Value', null, '3320211000001109', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'bag', 'Unit', 'SNOMED', 'Qualifier Value', null, '3320511000001107', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'bottle', 'Unit', 'SNOMED', 'Qualifier Value', null, '3320611000001106', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'disc', 'Unit', 'SNOMED', 'Qualifier Value', null, '3320811000001105', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'blister', 'Unit', 'SNOMED', 'Qualifier Value', null, '3320911000001100', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'bar', 'Unit', 'SNOMED', 'Qualifier Value', null, '3321211000001103', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'dual dose sachet', 'Unit', 'SNOMED', 'Qualifier Value', null, '3314111000001100', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'g/actuation', 'Unit', 'SNOMED', 'Qualifier Value', null, '3989311000001105', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'unit/actuation', 'Unit', 'SNOMED', 'Qualifier Value', null, '3989211000001102', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'micrograms/square cm', 'Unit', 'SNOMED', 'Qualifier Value', null, '3990011000001103', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'kit', 'Unit', 'SNOMED', 'Qualifier Value', null, '4027211000001105', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'component', 'Unit', 'SNOMED', 'Qualifier Value', null, '10204911000001107', '01-Jan-1970', '05-Jun-2006', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'micromol/ml', 'Unit', 'SNOMED', 'Qualifier Value', null, '8082911000001107', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'microliter/ml', 'Unit', 'SNOMED', 'Qualifier Value', null, '8083011000001104', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'nanoliter/ml', 'Unit', 'SNOMED', 'Qualifier Value', null, '8083111000001103', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'unit/square cm', 'Unit', 'SNOMED', 'Qualifier Value', null, '8083611000001106', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'can', 'Unit', 'SNOMED', 'Qualifier Value', null, '8083911000001100', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'ml/gram', 'Unit', 'SNOMED', 'Qualifier Value', null, '8088611000001104', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'GBq', 'Unit', 'SNOMED', 'Qualifier Value', null, '8090611000001103', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'GBq/ml', 'Unit', 'SNOMED', 'Qualifier Value', null, '8090711000001107', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'MBq/ml', 'Unit', 'SNOMED', 'Qualifier Value', null, '8090911000001109', '01-Jan-1970', '31-Oct-2008', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'mol/l', 'Unit', 'SNOMED', 'Qualifier Value', null, '10368311000001109', '01-Jan-1970', '30-Sep-2007', 'U');
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'cup', 'Unit', 'SNOMED', 'Qualifier Value', null, '11005411000001103', '01-Jan-1970', '31-Oct-2008', 'U');

-- Add update relationship for deprecated ones
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (45756913, 45757027, 'SNOMED replaces', '06-JUN-06', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4124446, 45757037, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4084455, 45756989, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4084456, 45756988, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4245255, 45756998, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4244976, 45756990, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4288408, 45757001, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4255054, 45757014, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4255055, 45757015, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4255056, 45757024, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4246815, 45757023, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4235089, 45756993, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4235090, 45756991, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4246828, 45756992, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4246829, 45756994, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4252057, 45756995, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4252058, 45756996, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4246830, 45756997, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4246831, 45756999, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4246832, 45757000, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4186050, 45757005, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4186261, 45757028, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4188673, 45757003, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4218803, 45757013, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4166715, 45757030, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4170093, 45757025, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4303660, 45757035, 'SNOMED replaces', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4169284, 45757029, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4305388, 45757012, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4304416, 45757004, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4306003, 45757034, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4167221, 45757036, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4167886, 45757026, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4302500, 45757002, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4305548, 45757018, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4304572, 45757031, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4306671, 45757009, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4168344, 45757033, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4224069, 45757016, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4137363, 45757020, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4144440, 45757022, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4142114, 45757019, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4323501, 45757021, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4176018, 45757038, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4176621, 45757006, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4181295, 45757017, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4178323, 45757011, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4180120, 45757032, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4178796, 45757008, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4326331, 45757010, 'SNOMED replaces', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (45756978, 45757007, 'SNOMED replaces', '01-OCT-14', '31-Dec-2099', null);

insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (45756913, 45757027, 'SNOMED replaced by', '06-JUN-06', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4124446, 45757037, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4084455, 45756989, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4084456, 45756988, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4245255, 45756998, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4244976, 45756990, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4288408, 45757001, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4255054, 45757014, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4255055, 45757015, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4255056, 45757024, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4246815, 45757023, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4235089, 45756993, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4235090, 45756991, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4246828, 45756992, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4246829, 45756994, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4252057, 45756995, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4252058, 45756996, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4246830, 45756997, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4246831, 45756999, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4246832, 45757000, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4186050, 45757005, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4186261, 45757028, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4188673, 45757003, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4218803, 45757013, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4166715, 45757030, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4170093, 45757025, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4303660, 45757035, 'SNOMED replaced by', '01-OCT-07', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4169284, 45757029, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4305388, 45757012, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4304416, 45757004, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4306003, 45757034, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4167221, 45757036, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4167886, 45757026, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4302500, 45757002, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4305548, 45757018, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4304572, 45757031, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4306671, 45757009, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4168344, 45757033, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4224069, 45757016, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4137363, 45757020, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4144440, 45757022, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4142114, 45757019, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4323501, 45757021, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4176018, 45757038, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4176621, 45757006, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4181295, 45757017, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4178323, 45757011, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4180120, 45757032, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4178796, 45757008, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4326331, 45757010, 'SNOMED replaced by', '01-NOV-08', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (45756978, 45757007, 'SNOMED replaced by', '01-OCT-14', '31-Dec-2099', null);

-- Change Gender to OMOP Gender
update concept set concept_name='OMOP Gender' where concept_id = 44819108;
update vocabulary set vocabulary_name='OMOP Gender' where vocabulary_concept_id=44819108;

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

