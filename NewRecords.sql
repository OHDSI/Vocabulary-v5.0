-- Add units for drug_strength
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Actuation', 'Unit', 'UCUM', 'Unit', 'S', '{actuat}', '01-JAN-1970', '31-DEC-2099', null);	
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'allergenic unit', 'Unit', 'UCUM', 'Unit', 'S', '{AU}', '01-JAN-1970', '31-DEC-2099', null);	
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'bioequivalent allergenic unit', 'Unit', 'UCUM', 'Unit', 'S', '{BAU}', '01-JAN-1970', '31-DEC-2099', null);	
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'cells', 'Unit', 'UCUM', 'Unit', 'S', '{cells}', '01-JAN-1970', '31-DEC-2099', null);	
update concept set concept_name='pH unit' where concept_id=8569;
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
values (56, 'Measurement/Procedure', 'Metadata', 'Domain', 'Domain', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into domain (domain_id, domain_name, domain_concept_id)
values ('Meas/Procedure', 'Measurement/Procedure', 56);

-- Erica's and Martijn's type concepts
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Pre-qualification time period', 'Obs Period Type', 'Obs Period Type', 'Obs Period Type', 'S', 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);	

-- Make all Metadata non-standard
update concept 
set standard_concept=null where domain_id='Metadata';

-- Abolish extra vocabulary 'LOINC Multidimensional Classification (Regenstrief Institute)'. Will become only concept class
update concept
set vocabulary_id='LOINC' where vocabulary_id='LOINC Hierarchy';
delete from vocabulary where vocabulary_id='LOINC Hierarchy';
update concept set 
  valid_end_date='1-Dec-2014',
  invalid_reason='D'
where concept_id=44819139
;

-- Add concept_class 'LOINC Class'
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'LOINC Class', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('LOINC Class', 'LOINC Class', (select concept_id from concept where concept_name='LOINC Class'));

-- LOINC concept_class_ids
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Laboratory Class', 'Metadata', 'Concept Class', 'Concept Class', null, '1', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Lab Test', 'Laboratory Class', (select concept_id from concept where concept_name='Laboratory Class'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Clinical Class', 'Metadata', 'Concept Class', 'Concept Class', null, '2', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Clinical Observation', 'Clinical Class', (select concept_id from concept where concept_name='Clinical Class'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Claims Attachments', 'Metadata', 'Concept Class', 'Concept Class', null, '3', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Claims Attachment', 'Claims Attachments', (select concept_id from concept where concept_name='Claims Attachments'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Surveys', 'Metadata', 'Concept Class', 'Concept Class', null, '4', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Survey', 'Surveys', (select concept_id from concept where concept_name='Surveys'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Answers', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Answer', 'Answers', (select concept_id from concept where concept_name='Answers'));

-- change LOINC Hierarchy concepts to 'C'
update concept 
set standard_concept='C' where concept_class_id='LOINC Hierarchy';

-- add new relationship between LOINC surveys etc. and answers
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has Answer (LOINC)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Has Answer', 'Has Answer (LOINC)', 0, 0, 'Is a', (select concept_id from concept where concept_name='Has Answer (LOINC)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Answer of (LOINC)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)
values ('Answer of', 'Answer of (LOINC)', 0, 0, 'Answer of', (select concept_id from concept where concept_name='Answer of (LOINC)'));
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id='Answer of' where relationship_id='Has Answer';
update relationship -- The reverse wasn't in at the time of writing 'Has Answer'
set reverse_relationship_id='Has Answer' where relationship_id='Answer of';

-- Add new CPT4 concpet classes
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'CPT4 Modifier', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('CTP4 Modifier', 'CPT4 Modifier', (select concept_id from concept where concept_name='CPT4 Modifier'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'CPT4 Hierarchy', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('CTP4 Hierarchy', 'CPT4 Hierarchy', (select concept_id from concept where concept_name='CPT4 Hierarchy'));

-- Add new HCPCS concept classes
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'HCPCS Modifier', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('HCPCS Modifier', 'HCPCS Modifier', (select concept_id from concept where concept_name='HCPCS Modifier'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'HCPCS Class', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('HCPCS Class', 'HCPCS Class', (select concept_id from concept where concept_name='HCPCS Class'));

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
values ('Navi Concept', 'Navigational Concept', (select concept_id from concept where concept_name='Navigational Concept'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Inactive Concept', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Inactive Concept', 'Inactive Concept', (select concept_id from concept where concept_name='Inactive Concept'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Linkage Concept', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Linkage Concept', 'Linkage Concept', (select concept_id from concept where concept_name='Linkage Concept'));

-- Fix existing SNOMED concept classes
update concept set concept_name='Situation with explicit context' where concept_id=44819051;
update concept_class set concept_class_name='Situation with explicit context' where concept_class_concept_id=44819051;

commit;
