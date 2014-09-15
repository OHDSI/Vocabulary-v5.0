--drop table concept;
create table concept (
  concept_id integer not null,
  concept_name varchar(255) not null,
  domain_code varchar(20) not null,
  vocabulary_code varchar(20) not null,
  class_code varchar(20) not null,
  standard_concept varchar(1) null,
  concept_code varchar(40) not null,
  valid_start_date date not null,
  valid_end_date date not null,
  invalid_reason varchar(1) null
);
alter table concept
  add constraint xpkconcept primary key (concept_id);

--drop table concept_relationship;
create table concept_relationship (
  concept_id_1 integer not null,
  concept_id_2 integer not null,
  relationship_code varchar(20) not null,
  valid_start_date date not null,
  valid_end_date date not null,
  invalid_reason varchar(1) null
);
alter table concept_relationship
  add constraint xpkconcept_relationship primary key (concept_id_1, concept_id_2, relationship_code);

--drop table concept_ancestor;
create table concept_ancestor (
  ancestor_concept_id integer not null,
  descendant_concept_id integer not null,
  min_levels_of_separation number(3) null,
  max_levels_of_separation number(3) null
);
alter table concept_ancestor 
  add constraint xpkconcept_ancestor primary key (ancestor_concept_id, descendant_concept_id)
;

--drop table concept_synonym;
create table concept_synonym(
  synonym_concept_id integer not null,
  synonym_name varchar(1000) not null,
  language_concept_id integer not null
);
alter table concept_synonym add constraint xpksynonym primary key (synonym_concept_id)
;

--drop table source_to_concept_map;
create table source_to_concept_map(
  source_code varchar(40) not null,
  source_vocabulary_code varchar(20) not null,
  source_code_description varchar(255) null,
  target_concept_id integer not null,
  target_vocabulary_code varchar(20) not null,
  mapping_type varchar(20) null,
  valid_start_date date not null,
  valid_end_date date not null,
  invalid_reason varchar(1) null
);

--drop table relationship;
create table relationship (
  relationship_code varchar(20) not null,
  relationship_name varchar(255) null,
  is_hierarchical varchar(1) not null,
  defines_ancestry varchar(1) not null,
  reverse_relationship varchar(20) not null,
  relationship_concept_id integer not null
);
alter table relationship 
  add constraint xpkrelationship primary key (relationship_code)
;

--drop table domain;
create table domain(
  domain_code varchar(20) not null,
  domain_name varchar(255) not null,
  domain_concept_id integer not null
);
alter table domain
  add constraint xpkdomain primary key (domain_code)
;

--drop table vocabulary;
create table vocabulary (
  vocabulary_code varchar(20) not null,
  vocabulary_name varchar(255) not null,
  vocabulary_reference varchar(255),
  vocabulary_version varchar(255),
  vocabulary_concept_id integer not null
);
alter table vocabulary
  add constraint xpkvocabulary primary key (vocabulary_code)
;

--drop table class;
create table class (
  class_code varchar(20) not null,
  class_name varchar(255) not null,
  class_concept_id integer not null
);
alter table class
  add constraint xpkclass primary key (class_code)
;

-- drop table drug_strength;
create table drug_strength (
  drug_concept_id integer not null,
  ingredient_concept_id integer not null,
  amount_value decimal null,
  amount_unit varchar(60) null,
  concentration_value decimal null,
  concentration_enum_unit varchar(60) null,
  concentration_denom_unit varchar(60) null,
  valid_start_date date not null,
  valid_end_date date not null,
  invalid_reason varchar(1) null)
;
alter table drug_strength
  add constraint xpkdrug_strength primary key (drug_concept_id, ingredient_concept_id)
;

-- drop table cohort_definition;
create table cohort_definition (
  cohort_definition_id integer not null,
  cohort_definition_name varchar(255) not null,
  cohort_definition_description varchar(max) null,
  definition_type_concept_id integer not null,
  cohort_definition_syntax varchar(max) null,
  execution_date date null)
;
alter table cohort_definition
  add constraint xpkcohort_definition primary key (cohort_definition_id)
;



-- Indices
create index xsource on concept (
  vocabulary_code asc, concept_code asc
);
create index xconcept on concept (
  concept_id asc
);
create index xrelationpair on concept_relationship (
  concept_id_1 asc,
  concept_id_2 asc
);
create index xrelationship on concept_relationship (
  relationship_code asc
);
create index xall3 on concept_relationship (
  concept_id_1, concept_id_2, relationship_code
);

