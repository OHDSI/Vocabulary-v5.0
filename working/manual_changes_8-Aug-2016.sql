-- Add THIN Gemscript Class
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Gemscript THIN', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('Gemscript THIN', 'Encrypted Gemscript for the THIN database', (select concept_id from concept where concept_name = 'Gemscript THIN'));

-- Add Measurement Type for ordering
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Test ordered through EHR', 'Type Concept', 'Meas Type', 'Meas Type', 'S', 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);

-- Add parenteral to Route
update concept set domain_id='Route' where concept_id=40491411;

-- Add concept_classes for dm+d
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Actual Medicinal Product', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('AMP', 'Actual Medicinal Product', (select concept_id from concept where concept_name = 'Actual Medicinal Product'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Actual Medicinal Product Pack', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('AMPP', 'Actual Medicinal Product Pack', (select concept_id from concept where concept_name = 'Actual Medicinal Product Pack'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Virtual Medicinal Product', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('VMP', 'Virtual Medicinal Product', (select concept_id from concept where concept_name = 'Virtual Medicinal Product'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Virtual Medicinal Product Pack', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('VMPP', 'Virtual Medicinal Product Pack', (select concept_id from concept where concept_name = 'Virtual Medicinal Product Pack'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'dm+d Dose Form', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('Form', 'dm+d Dose Form', (select concept_id from concept where concept_name = 'dm+d Dose Form'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Virtual Therapeutic Moiety', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('VTM', 'Virtual Therapeutic Moiety', (select concept_id from concept where concept_name = 'Virtual Therapeutic Moiety'));

-- Add Precise ingredient Class
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Precise Ingredient', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('Precise Ingredient', 'Precise Ingredient', (select concept_id from concept where concept_name = 'Precise Ingredient'));

-- Add Dose Form Group Class
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Dose Form Group', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('Dose Form Group', 'Dose Form Group', (select concept_id from concept where concept_name = 'Dose Form Group'));

-- Add Clinical Dose Group Class
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Semantic Clinical Dose Group', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('Clinical Dose Group', 'Semantic Clinical Dose Group', (select concept_id from concept where concept_name = 'Semantic Clinical Dose Group'));

-- Add Branded Dose Group Class
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Semantic Branded Dose Group', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('Branded Dose Group', 'Semantic Branded Dose Group', (select concept_id from concept where concept_name = 'Semantic Branded Dose Group'));

-- Add Relationships Has dose form group and Dose form group of
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Dose form group of (RxNorm)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Dose form group of', 'Dose form group of (RxNorm)', 1, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Dose form group of (RxNorm)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Has dose form group (RxNorm)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Has dose form group', 'Has dose form group (RxNorm)', 1, 0, 'Has marketed form', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has dose form group (RxNorm)'));
update relationship set reverse_relationship_id='Has dose form group' where relationship_id='Dose form group of';

commit;

