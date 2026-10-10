create table dev_hpo.hpo_cde
(
    metadata_enriched         boolean     default true,
    concept_code              varchar(50) not null,
    concept_name              varchar(255),
    vocabulary_id             varchar(20) default 'HPO'::character varying,
    sty                       varchar,
    mapability                varchar,
    relationship_id           varchar(20),
    relationship_id_predicate varchar(20),
    decision                  boolean,
    confidence                double precision,
    mapping_source            character varying[],
    mapping_path              character varying[],
    mapper_id                 varchar,
    reviewer_id               varchar,
    comments                  varchar,
    valid_start_date          date,
    valid_end_date            date,
    invalid_reason            varchar,
    target_concept_id         bigint,
    target_concept_code       varchar(50),
    target_concept_name       varchar(255),
    target_concept_class      varchar(50),
    target_standard_concept   varchar(1),
    target_invalid_reason     varchar(1),
    target_domain_id          varchar(20),
    target_vocabulary_id      varchar(20)
);


grant select on dev_hpo.hpo_cde to role_read_only;



-- ============================================================
-- AUTOMATED / NON-CURATED HPO MAPPINGS
-- Used to populate CRS
-- ============================================================

DROP TABLE IF EXISTS dev_hpo.hpo_cde;

CREATE TABLE dev_hpo.hpo_cde
(
    -- General metadata
    metadata_enriched           BOOLEAN DEFAULT TRUE,

    -- Source HPO concept
    concept_code                VARCHAR(50) NOT NULL, -- HPO code
    concept_name                VARCHAR(255),         -- HPO name
    vocabulary_id               VARCHAR(20) DEFAULT 'HPO',

    -- Semantic / mapping metadata
    sty                         VARCHAR,              -- Semantic type from UMLS
    mapability                  VARCHAR,              -- OMOP mapability:
                                                       -- FoN   = Flavor of Null
                                                       -- NOmop = Non-OMOP use case
                                                       -- NULL  = Mappable

    -- OMOP relationship information
    relationship_id             VARCHAR(20),          -- OMOP relationship
    relationship_id_predicate   VARCHAR(20),          -- relationship predicate
    decision                    BOOLEAN,              -- Mapping decision
    confidence                  FLOAT,                -- Mapping confidence score

    -- Provenance
    mapping_source              VARCHAR[],             -- Origin(s) of mapping
    mapping_path                VARCHAR[],             -- Mapping chain (non-manual sources)

    -- Audit information
    mapper_id                   VARCHAR,              -- Mapper email
    reviewer_id                 VARCHAR,              -- Reviewer email
    comments                    VARCHAR,              -- Technical comments

    -- Validity dates (OMOP standard)
    valid_start_date            DATE,
    valid_end_date              DATE,
    invalid_reason              VARCHAR,

    -- Target OMOP concept
    target_concept_id           BIGINT,
    target_concept_code         VARCHAR(50),
    target_concept_name         VARCHAR(255),
    target_concept_class        VARCHAR(50),
    target_standard_concept     VARCHAR(1),
    target_invalid_reason       VARCHAR(1),
    target_domain_id            VARCHAR(20),
    target_vocabulary_id        VARCHAR(20)
);

-- ============================================================================
-- TABLE: dev_hpo.omop2obo_condition_sssom
-- Description: OMOP to OBO mappings in SSSOM format
--              Provided by HPO authors (must be requested directly)
-- ============================================================================

CREATE TABLE dev_hpo.omop2obo_condition_sssom (
    subject_id TEXT,
    subject_label TEXT,
    predicate_id TEXT,
    object_id TEXT,
    object_label TEXT,
    mapping_justification TEXT,
    confidence DOUBLE PRECISION,
    subject_match_field TEXT,
    object_match_field TEXT,
    other TEXT
);

-- ============================================================================
-- TABLE: hpo_mesh_sssom
-- Description: HPO to MeSH mappings in SSSOM format
-- Source: https://obophenotype.github.io/human-phenotype-ontology/developers/mappings/
-- ============================================================================

CREATE TABLE hpo_mesh_sssom (
    subject_id TEXT,
    predicate_id TEXT,
    object_id TEXT,
    mapping_justification TEXT,
    match_string TEXT,
    mapping_tool TEXT,
    mapping_date DATE
);


-- ============================================================================
-- TABLE: cvb_hpo_mapping
-- Description: Mapping made within Tufts University
-- Source: https://github.com/TuftsCTSI/CVB/tree/main/HPO/Mappings
-- ============================================================================


create table dev_hpo.cvb_hpo_mapping
(
    source_code_set            text,
    source_category            text,
    source_domain              text,
    source_code                text,
    source_concept_id          integer,
    source_vocabulary_id       text,
    source_description         text,
    source_description_synonym text,
    relationship_id            text,
    predicate_id               text,
    confidence                 integer,
    target_concept_id          integer,
    target_concept_name        text,
    target_vocabulary_id       text,
    target_domain_id           text,
    author_label               text,
    reviewer_label             text,
    reviewer_comments          text,
    mapping_justification      text,
    mapping_tool               text,
    mapping_tool_version       text
);



-- ============================================================================
-- TABLE: hpo_to_snomed_map
-- Description: SNOMED CT to HPO mappings created by Graham Ponting
-- Source: https://conf.spaces.snomed.org/wiki/spaces/CC/pages/131826267/Human+Phenotype+Ontology+and+SNOMED+CT
-- ============================================================================

CREATE TABLE hpo_to_snomed_map (
    hp_id TEXT,
    preferred_label TEXT,                    -- Corrected: 'Preferred_Label' to lowercase with underscore
    synonyms TEXT,
    definitions TEXT,
    match_group TEXT,                        -- Corrected: 'Match_group' to lowercase with underscore
    mapping_comment TEXT,                    -- Corrected: 'Mapping_Comment' to lowercase with underscore
    snomed_term_exp TEXT,                    -- Corrected: 'SNOMED_term_exp' to lowercase with underscore
    canonical_view TEXT,                     -- Corrected: 'canonical_view' (already lowercase)
    hp_parent_no TEXT,                       -- Corrected: 'HP_Parent_No' to lowercase with underscore
    hp_parent_term TEXT,                     -- Corrected: 'HP_Parent_Term' to lowercase with underscore
    alternative_expression TEXT              -- Corrected: 'Alternative_expression' to lowercase with underscore
);

-- ============================================================
-- HECATE MAPPING
-- Stores HPO mappings generated via OHDSI HECATE
-- Mapping done in Search Standard Concept Mode with HECATE API (python)
-- ============================================================

CREATE TABLE hpo_mapped_via_ohdsi_hecate
(
    -- Source concept information
    source_code                TEXT,
    source_code_description    TEXT,
    source_vocabulary_id       TEXT,

    -- Matching / search metadata
    matched                    TEXT,
    description                TEXT,
    search_name                TEXT,
    search_score               DOUBLE PRECISION,

    -- OMOP concept information
    concept_id                 BIGINT,
    concept_name               TEXT,
    vocabulary_id              TEXT,
    concept_code               TEXT,

    -- Free-text notes
    note                       TEXT
);
