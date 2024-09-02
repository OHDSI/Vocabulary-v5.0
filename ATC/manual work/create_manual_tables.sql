--- That script creates manual tables for further work

CREATE TABLE new_adm_r
(
    class_code TEXT,
    class_name TEXT,
    old        TEXT,
    new        TEXT
);

CREATE TABLE new_atc_codes_ings_for_manual
(
    source          TEXT,
    class_code      TEXT,
    class_name      TEXT,
    relationship_id TEXT,
    ids             TEXT,
    names           TEXT
);


CREATE TABLE bdpm_atc_codes
(
    id       INTEGER,
    atc_code TEXT
);

CREATE TABLE norske_result
(
    concept_id   VARCHAR(255),
    concept_name VARCHAR(1000),
    form         TEXT,
    atc_code     TEXT,
    atc_name     VARCHAR(255),
    rx_ids       INTEGER,
    rx_names     VARCHAR(255)
);

CREATE TABLE kdc_atc
(
    concept_code     TEXT,
    concept_code_2   TEXT,
    vocabulary_id    TEXT,
    vocabulary_id_2  TEXT,
    relationship_id  TEXT,
    valid_start_date TEXT,
    valid_end_date   TEXT,
    invalid_reason   TEXT
);

CREATE TABLE atc_rxnorm_to_drop_in_sources
(
    concept_id_atc   INTEGER,
    concept_code_atc TEXT,
    concept_name     TEXT,
    drop             TEXT,
    concept_id_rx    INTEGER,
    concept_name_rx  TEXT
);

CREATE TABLE existent_atc_rxnorm_to_drop
(
    atc_code     TEXT,
    atc_name     TEXT,
    root         TEXT,
    concept_id   INTEGER,
    to_drop      TEXT,
    concept_name TEXT,
    to_check     TEXT
);

CREATE TABLE covid19_atc_rxnorm_manual
(
    concept_code_atc TEXT,
    to_drop          TEXT,
    concept_id       INTEGER,
    concept_name     TEXT
);

CREATE TABLE gcs_manual_curated
(
    concept_id    INTEGER,
    concept_name  TEXT,
    vocabulary_id TEXT,
    ings          TEXT,
    string_agg    TEXT,
    atc_code      TEXT
);

CREATE TABLE drop_maps_to
(
    source_code_atc TEXT,
    source_code_rx  TEXT
);