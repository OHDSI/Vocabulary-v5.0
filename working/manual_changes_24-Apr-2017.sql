-- Add counseling to ICD9CM code mappings
-- Counseling for victim of child abuse
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (44835510, 4054939, 'Maps to', trunc(sysdate), '31-Dec-2099', null); -- Abuse counseling
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (44835510, 4054939, 'Mapped from', trunc(sysdate), '31-Dec-2099', null);

-- Counseling for parent (guardian)-foster child problem
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (44820467, 4259351, 'Maps to', trunc(sysdate), '31-Dec-2099', null); -- 	Caretaking/parenting skills education, guidance, and counseling
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (44820467, 4259351, 'Mapped from', trunc(sysdate), '31-Dec-2099', null);
-- Counseling for parent-adopted child problem
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (44823863, 4259351, 'Maps to', trunc(sysdate), '31-Dec-2099', null); -- Caretaking/parenting skills education, guidance, and counseling
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (44823863, 4259351, 'Mapped from', trunc(sysdate), '31-Dec-2099', null);
-- Counseling for parent-child problem, unspecified
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (44828582, 4259351, 'Maps to', trunc(sysdate), '31-Dec-2099', null); -- Caretaking/parenting skills education, guidance, and counseling
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (44828582, 4259351, 'Mapped from', trunc(sysdate), '31-Dec-2099', null);
-- Counseling for perpetrator of spousal and partner abuse
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (44828583, 4054939, 'Maps to', trunc(sysdate), '31-Dec-2099', null); -- Abuse counseling
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (44828583, 4054939, 'Mapped from', trunc(sysdate), '31-Dec-2099', null);
-- Counseling for perpetrator of physical/sexual abuse
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (44833141, 4054939, 'Maps to', trunc(sysdate), '31-Dec-2099', null); -- Abuse counseling
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (44833141, 4054939, 'Mapped from', trunc(sysdate), '31-Dec-2099', null);
-- Counseling for parent-biological child problem
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (44836687, 4259351, 'Maps to', trunc(sysdate), '31-Dec-2099', null); -- Caretaking/parenting skills education, guidance, and counseling
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (44836687, 4259351, 'Mapped from', trunc(sysdate), '31-Dec-2099', null);

-- Change language code in Synonym
update concept_synonym set language_concept_id=4180186;

-- Fix MedDRA-SNOMED for rhabdomyelosis for Erica Voss
-- Fixed but code lost.

-- Add mixed ER/inpation Visit Concept
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Emergency Room and Inpatient Visit', 'Visit', 'Visit', 'Visit', 'S', 'ERIP', '01-JAN-1970', '31-DEC-2099', null);

-- Add note type classes
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Kind of Note Attribute', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('Note Kind', 'Kind of Note Attribute', (select concept_id from concept where concept_name = 'Kind of Note Attribute'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Service or activity resulting in Note Attribute', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('Note Service Type', 'Service or activity resulting in Note Attribute', (select concept_id from concept where concept_name = 'Service or activity resulting in Note Attribute'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Point of Care Setting of Note Attribute', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('Note Setting', 'Point of Care Setting of Note Attribute', (select concept_id from concept where concept_name = 'Point of Care Setting of Note Attribute'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Note Subject Matter Domain Attribute', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('Note Domain', 'Note Subject Matter Domain Attribute', (select concept_id from concept where concept_name = 'Note Subject Matter Domain Attribute'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Provider Role of Note Attribute', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
  values ('Note Provider Role', 'Provider Role of Note Attribute', (select concept_id from concept where concept_name = 'Provider Role of Note Attribute'));

-- Add SNOMED relationships that they started using all of a sudden
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Has precondition (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Has precondition', 'Has precondition (SNOMED)', 1, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has precondition (SNOMED)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Precondition of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Precondition of', 'Precondition of (SNOMED)', 1, 0, 'Has precondition', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Precondition of (SNOMED)'));
update relationship set reverse_relationship_id='Precondition of' where relationship_id='Has precondition';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Has inherent location (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Has inherent loc', 'Has inherent location (SNOMED)', 1, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has inherent location (SNOMED)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Inherent location of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Inherent location of', 'Inherent location of (SNOMED)', 1, 0, 'Has inherent loc', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Inherent location of (SNOMED)'));
update relationship set reverse_relationship_id='Inherent location of' where relationship_id='Has inherent loc';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Has technique (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Has technique', 'Has technique (SNOMED)', 1, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has technique (SNOMED)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Technique of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Technique of', 'Technique of (SNOMED)', 1, 0, 'Has technique', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Technique of (SNOMED)'));
update relationship set reverse_relationship_id='Technique of' where relationship_id='Has technique';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Has relative part (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Has relative part', 'Has relative part (SNOMED)', 1, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has relative part (SNOMED)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Relative part of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Relative part of', 'Relative part of (SNOMED)', 1, 0, 'Has relative part', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Relative part of (SNOMED)'));
update relationship set reverse_relationship_id='Relative part of' where relationship_id='Has relative part';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Has process output (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Has process output', 'Has process output (SNOMED)', 1, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has process output (SNOMED)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Process output of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Process output of', 'Process output of (SNOMED)', 1, 0, 'Has process output', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Process output of (SNOMED)'));
update relationship set reverse_relationship_id='Process output of' where relationship_id='Has process output';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Has property type (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Has property type', 'Has property type (SNOMED)', 1, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has property type (SNOMED)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Property type of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Property type of', 'Property type of (SNOMED)', 1, 0, 'Has property type', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Property type of (SNOMED)'));
update relationship set reverse_relationship_id='Property type of' where relationship_id='Has property type';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Inheres in (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Inheres in', 'Inheres in (SNOMED)', 1, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Inheres in (SNOMED)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Has inherent (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Has inherent', 'Has inherent (SNOMED)', 1, 0, 'Inheres in', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has inherent (SNOMED)'));
update relationship set reverse_relationship_id='Has inherent' where relationship_id='Inheres in';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Has direct site (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Has direct site', 'Has direct site (SNOMED)', 1, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has direct site (SNOMED)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Direct site of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Direct site of', 'Direct site of (SNOMED)', 1, 0, 'Has direct site', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Direct site of (SNOMED)'));
update relationship set reverse_relationship_id='Direct site of' where relationship_id='Has direct site';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Characterizes (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Characterizes', 'Characterizes (SNOMED)', 1, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Characterizes (SNOMED)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Is characterized by (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
  values ('Is characterized by', 'Is characterized by (SNOMED)', 1, 0, 'Characterizes', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Is characterized by (SNOMED)'));
update relationship set reverse_relationship_id='Is characterized by' where relationship_id='Characterizes';

-- Add Place of Service.
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Telehealth', 'Place of Service', 'Place of Service', 'Place of Service', 'S', '02', '1-Jan-2016', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Off Campus-Outpatient Hospital', 'Place of Service', 'Place of Service', 'Place of Service', 'S', '19', '1-Jan-2016', '31-Dec-2099', null);

-- Fix duplicate ABMS record
update concept set valid_end_date='14-Mar-2017', invalid_reason='U' where concept_id=45756774;
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (45756774, 45756773, 'Concept replaced by', '15-Mar-2017', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (45756773, 45756774, 'Concept replaces', '15-Mar-2017', '31-Dec-2099', null);

-- Fix duplicate relationship records
update concept set valid_end_date='14-Mar-2017', invalid_reason='U' where concept_id=46233686;
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (46233686, 46233680, 'Concept replaced by', '15-Mar-2017', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (46233680, 46233686, 'Concept replaces', '15-Mar-2017', '31-Dec-2099', null);

update concept set valid_end_date='14-Mar-2017', invalid_reason='U' where concept_id=46233687;
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (46233687, 46233680, 'Concept replaced by', '15-Mar-2017', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values (46233680, 46233687, 'Concept replaces', '15-Mar-2017', '31-Dec-2099', null);


