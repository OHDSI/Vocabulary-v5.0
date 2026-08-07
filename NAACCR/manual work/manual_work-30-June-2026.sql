-- As NAACCR update is done via separate python-script(s) which produce _stage tables, upload the content directly
-- to tables that structurally resemble _stage inputs.
-- The update is not intended to push the changes via manual release but as the direct injection to corresponding stage tables in order to prevent legacy-tails in manual tables that are difficult to maintain.
DROP TABLE IF EXISTS naaccr_update_concept_stage;
create table naaccr_update_concept_stage
(
    concept_id       integer,
    concept_name     varchar(255),
    domain_id        varchar(20),
    vocabulary_id    varchar(20) not null,
    concept_class_id varchar(20),
    standard_concept varchar(1),
    concept_code     varchar(50) not null,
    valid_start_date date        not null,
    valid_end_date   date        not null,
    invalid_reason   varchar(1),
    constraint idx_pk_cs_n
        primary key (concept_code, vocabulary_id)
);


DROP TABLE IF EXISTS naaccr_update_concept_relationship_stage;
create table naaccr_update_concept_relationship_stage
(
    concept_id_1     integer,
    concept_id_2     integer,
    concept_code_1   varchar(50) not null,
    concept_code_2   varchar(50) not null,
    vocabulary_id_1  varchar(20) not null,
    vocabulary_id_2  varchar(20) not null,
    relationship_id  varchar(20) not null,
    valid_start_date date        not null,
    valid_end_date   date        not null,
    invalid_reason   varchar(1),
    constraint idx_pk_crs_n
        primary key (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id)
);

DROP TABLE IF EXISTS naaccr_update_concept_synonym_stage;
create table naaccr_update_concept_synonym_stage
(
    synonym_concept_id    integer,
    synonym_name          varchar(1000) not null,
    synonym_concept_code  varchar(50)   not null,
    synonym_vocabulary_id varchar(20)   not null,
    language_concept_id   integer       not null,
    constraint idx_pk_css_n
        primary key (synonym_vocabulary_id, synonym_name, synonym_concept_code, language_concept_id)
);

