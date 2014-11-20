-- drop table concept_stage;
create table concept_stage (
  concept_id number(38) null,
  concept_name varchar2(255) null,
  domain_id varchar2(20) null,
  vocabulary_id varchar2(20) null,
  concept_class_id varchar2(20) null, 
  standard_concept varchar2(1) null,
  concept_code varchar2(50) null,
  valid_start_date date null,
  valid_end_date date null,
  invalid_reason varchar2(1) null
);

-- load using vocabulary_specific scripts. 
-- As a minimum, vocabulary_id/concept_code or concept_id have to be present. 
-- For updates, valid_start_date, valid_end_date have to have content

-- drop table concept_relationship_stage 
create table concept_relationship_stage (
  concept_id_1 number(38) null,
  concept_id_2 number(38) null,
  concept_code_1 varchar2(50) null,
  concept_code_2 varchar2(50) null,
  relationship_id varchar2(20) not null,
  valid_start_date date null,
  valid_end_date date null,
  invalid_reason varchar2(1) null
);

-- SQLLDR using vocabulary_specific scripts
-- As a minimum, the concept ids or the concept codes have to be present, as well as the relationship_id
-- For updates, the valid dates are required

commit;
exit;

