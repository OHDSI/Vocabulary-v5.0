    -- -----------------------------------------------------------------------------
-- Create and populate from folder concept_manual_refresh tables
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS dev_cancer_modifier.concept_manual_refresh;
CREATE TABLE IF NOT EXISTS dev_cancer_modifier.concept_manual_refresh
(
    concept_name     varchar(255)
        constraint chk_cmnl_concept_name
            check ((concept_name)::text <> ''::text),
    domain_id        varchar(20),
    vocabulary_id    varchar(20) not null,
    concept_class_id varchar(20),
    standard_concept varchar(1),
    concept_code     varchar(50) not null
        constraint chk_cmnl_concept_code_cm_m
            check ((concept_code)::text <> ''::text),
    valid_start_date date,
    valid_end_date   date,
    invalid_reason   varchar(1),
    constraint unique_manual_concepts_cm_m
        unique (vocabulary_id, concept_code)
);

DROP TABLE IF EXISTS dev_cancer_modifier.concept_synonym_manual_refresh;
CREATE TABLE IF NOT EXISTS dev_cancer_modifier.concept_synonym_manual_refresh
(
    synonym_name          varchar(1000) not null
        constraint chk_csynmnl_concept_synonym_name_cm_m
            check ((synonym_name)::text <> ''::text),
    synonym_concept_code  varchar(50)   not null,
    synonym_vocabulary_id varchar(20)   not null,
    language_concept_id   integer       not null,
    constraint unique_manual_synonyms_cm_m
        unique (synonym_name, synonym_concept_code, synonym_vocabulary_id, language_concept_id)
);

DROP TABLE IF EXISTS dev_cancer_modifier.concept_relationship_manual_refresh;
CREATE TABLE IF NOT EXISTS dev_cancer_modifier.concept_relationship_manual_refresh
(

    concept_code_1   varchar(50) not null
        constraint chk_crm_concept_code_1_cm_m
            check ((concept_code_1)::text <> ''::text),
    concept_code_2   varchar(50) not null
        constraint chk_crm_concept_code_2_cm_m
            check ((concept_code_2)::text <> ''::text),
    vocabulary_id_1  varchar(20) not null,
    vocabulary_id_2  varchar(20) not null,
    relationship_id  varchar(20) not null,
    valid_start_date date        not null,
    valid_end_date   date        not null,
    invalid_reason   varchar(1)
        constraint chk_crm_invalid_reason_cm_m
            check ((COALESCE(invalid_reason, 'D'::character varying))::text = 'D'::text),
    constraint unique_manual_relationships_cm_m
        unique (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id)
);

-- -----------------------------------------------------------------------------
-- Create CDE review table for curator decisions
-- Run this DDL before loading the reviewed spreadsheet. It is IF NOT EXISTS so
-- the transformation sections below can be re-run after data is loaded.
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS dev_cancer_modifier.cancer_modifier_cde;
CREATE TABLE IF NOT EXISTS dev_cancer_modifier.cancer_modifier_cde
(
    source_concept_code       text,
    source_concept_id         integer,
    max_record                integer,
    source_concept_name       text,
    source_domain_id          text,
    action_req                text,
    source_vocabulary_id      text,
    relationship_id           text,
    relationship_id_predicate text,
    decision                  bool, -- flag to define if the decision around the mapping/de-standartization (per source code) is final
    to_destandardize          bool, -- flag to define if source concept  should be de-standardized
    to_make_precoosrinated_source_pair          bool,  -- flag to define if precoordinated pair should be created
    create_standard           bool,
    comment                   text,
    target_concept_id         INT,
    target_concept_code       text,
    target_concept_name       text,
    target_concept_class_id   text,
    target_standard_concept   text,
    target_invalid_reason     text,
    target_domain_id          text,
    target_vocabulary_id      text
);