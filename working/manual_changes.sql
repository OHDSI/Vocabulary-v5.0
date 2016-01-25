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

update concept set concept_name = 'OMOP Standardized Vocabularies' where concept_id = 44819096;

-- Add new Unit for building Drug Strength
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (9693, 'index of reactivity', 'Unit', 'UCUM', 'Unit', 'S', '{ir}', '1-Dec-2014', '31-Dec-99', null);


select * from concept_class where concept_class_id like 'Branded%';
select * from concept where concept_id=44819004;

-- add boxed drug concept_class_id values
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (200, 'Quantified Branded Drug Box', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Quant Branded Box', 'Quantified Clinical Drug Box', (select concept_id from concept where concept_name = 'Quantified Branded Drug Box'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Quantified Clinical Drug Box', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Quant Clinical Box', 'Quantified Clinical Drug Box', (select concept_id from concept where concept_name = 'Quantified Clinical Drug Box'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Branded Drug Box', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Branded Drug Box', 'Branded Drug Box', (select concept_id from concept where concept_name = 'Branded Drug Box'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Clinical Drug Box', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Clinical Drug Box', 'Clinical Drug Box', (select concept_id from concept where concept_name = 'Clinical Drug Box'));

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Disease Analyzer France (IMS)', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id)
values ('DA_France', 'Disease Analyzer France', 'IMS proprietary', '20151215', (select concept_id from concept where concept_name = 'Disease Analyzer France (IMS)'));

-- Add relationships for Brand Name so they don't short circuit RxNorm ancestry through Brand Name
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has brand name (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has brand name', 'Has brand name (OMOP)', 1, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has brand name (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Brand name of (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Brand name of', 'Brand name of (OMOP)', 1, 0, 'Has brand name', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Brand name of (OMOP)'));
update relationship set reverse_relationship_id='Brand name of' where relationship_id='Has brand name';

-- Add relationship to boxed drugs
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Is available in a prepackaged box (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Available as box', 'Is available in a prepackaged box (OMOP)', 1, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Is available in a prepackaged box (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Prepackaged box of (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Box of', 'Prepackaged box of (OMOP)', 1, 0, 'Available as box', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Prepackaged box of (OMOP)'));
update relationship set reverse_relationship_id='Box of' where relationship_id='Available as box';

-- Add relationship between Ingredients
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Is standard ingredient of ingredient (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Is standard ing of', 'Is standard ingredient of ingredient (OMOP)', 0, 1, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Is standard ingredient of ingredient (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has standard ingredient (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has standard ing', 'Has standard ingredient (OMOP)', 0, 0, 'Is standard ing of', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has standard ingredient (OMOP)'));
update relationship set reverse_relationship_id='Has standard ing' where relationship_id='Is standard ing of';

-- Add relationship between Brand Names
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Is standard Brand Name of (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Is standard brand of', 'Is standard Brand Name of (OMOP)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Is standard Brand Name of (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has standard Brand Name (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has standard brand', 'Has standard Brand Name (OMOP)', 0, 0, 'Is standard ing of', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has standard Brand Name (OMOP)'));
update relationship set reverse_relationship_id='Has standard brand' where relationship_id='Is standard brand of';

-- Add relationship between Dose Forms
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Is standard Dose Form of (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Is standard form of', 'Is standard Dose Form of (OMOP)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Is standard Dose Form of (OMOP)'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has standard Dose Form (OMOP)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has standard form', 'Has standard Dose Form (OMOP)', 0, 0, 'Is standard form of', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has standard Dose Form (OMOP)'));
update relationship set reverse_relationship_id='Has standard form' where relationship_id='Is standard form of';

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
