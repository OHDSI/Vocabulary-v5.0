-----------
-- Create source tables
-- This scripts performs the following:
-- 1. Create temporary tables for small variants (ending in _small) created by Koios, load them, modify them and test them 
-- 2. Create temporary tables for small variants (ending in _large) created manually, load them, modify them and test them 

-- APL 2.0
-- Authors: CReich, LLA 
-- (c) OHDSI
------------

--TODO: Check constraints and indexes

DROP TABLE IF EXISTS concept_small;
CREATE TABLE concept_small
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
    constraint idx_pk_cs
        primary key (concept_code, vocabulary_id)
);

DROP TABLE IF EXISTS relationship_small;
CREATE TABLE relationship_small 
(
    concept_id_1     integer,
    concept_id_2     integer,
    concept_code_1   varchar(255) not null,
    concept_code_2   varchar(255) not null,
    vocabulary_id_1  varchar(20)  not null,
    vocabulary_id_2  varchar(20)  not null,
    relationship_id  varchar(20)  not null,
    valid_start_date date         not null,
    valid_end_date   date         not null,
    invalid_reason   varchar(1),
    constraint idx_pk_crs
        primary key (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id)
);

DROP TABLE IF EXISTS synonym_small;
CREATE TABLE concept_synonym_stage
(
    synonym_concept_id    integer,
    synonym_name          varchar(1000) not null,
    synonym_concept_code  varchar(50)   not null,
    synonym_vocabulary_id varchar(20)   not null,
    language_concept_id   integer       not null,
    constraint idx_pk_css
        primary key (synonym_vocabulary_id, synonym_name, synonym_concept_code, language_concept_id)
);

DROP TABLE IF EXISTS concept_large;
CREATE TABLE concept_large
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
    constraint idx_pk_clarge
        primary key (concept_code, vocabulary_id)
);

DROP TABLE IF EXISTS relationship_large;
CREATE TABLE relationship_large
(
    concept_id_1     integer,
    concept_id_2     integer,
    concept_code_1   varchar(255) not null,
    concept_code_2   varchar(255) not null,
    vocabulary_id_1  varchar(20)  not null,
    vocabulary_id_2  varchar(20)  not null,
    relationship_id  varchar(20)  not null,
    valid_start_date date         not null,
    valid_end_date   date         not null,
    invalid_reason   varchar(1)
);



--Add indexes
CREATE INDEX idx_csmall_concept_id ON concept_small USING btree (concept_id);
CREATE INDEX idx_rs ON relationship_small USING btree (concept_code_2);
CREATE INDEX idx_clarge_concept_id ON concept_large USING btree (concept_id);
