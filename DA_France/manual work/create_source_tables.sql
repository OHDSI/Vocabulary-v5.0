CREATE TABLE da_france_source 
(
  PFC           VARCHAR,
  DESCR_LABO    VARCHAR,
  DESCR_PROD    VARCHAR,
  DESCR_FORME   VARCHAR,
  DESCR_PCK     VARCHAR,
  STRG_UNIT     NUMERIC,
  STRG_MEAS     VARCHAR,
  VL_WG_UNIT    NUMERIC,
  VL_WG_MEAS    VARCHAR,
  PCK_SIZE      VARCHAR,
  NFC           VARCHAR,
  CODE_ATC      VARCHAR,
  MOLECULE      VARCHAR,
  cnt           INT
);

CREATE TABLE drug_concept_stage 
(
  concept_name              VARCHAR(255),
  vocabulary_id             VARCHAR(20),
  concept_class_id          VARCHAR(20),
  standard_concept          VARCHAR(1),
  concept_code              VARCHAR(50),
  possible_excipient        VARCHAR(1),
  domain_id                 VARCHAR(20),
  valid_start_date          DATE,
  valid_end_date            DATE,
  invalid_reason            VARCHAR(1),
  source_concept_class_id   VARCHAR(20)
);

CREATE TABLE ds_0 
(
  drug_concept_code         VARCHAR(255),
  drug_name                 VARCHAR(255),
  ingredient_concept_code   VARCHAR(255),
  amount_value              NUMERIC,
  amount_unit               VARCHAR(255),
  numerator_value           NUMERIC,
  numerator_unit            VARCHAR(255),
  denominator_value         NUMERIC,
  denominator_unit          VARCHAR(255)
);

CREATE TABLE ds_stage 
(
  drug_concept_code         VARCHAR(50),
  ingredient_concept_code   VARCHAR(50),
  box_size                  SMALLINT,
  amount_value              NUMERIC,
  amount_unit               VARCHAR(255),
  numerator_value           NUMERIC,
  numerator_unit            VARCHAR(255),
  denominator_value         NUMERIC,
  denominator_unit          VARCHAR(255)
);

CREATE TABLE internal_relationship_stage 
(
  concept_code_1   VARCHAR(50),
  concept_code_2   VARCHAR(50)
);


CREATE TABLE pc_stage 
(
  pack_concept_code   VARCHAR(50),
  drug_concept_code   VARCHAR(50),
  amount              SMALLINT,
  box_size            SMALLINT
);

CREATE TABLE relationship_to_concept 
(
  concept_code_1      VARCHAR(50),
  vocabulary_id_1     VARCHAR(50),
  concept_id_2        INT,
  precedence          SMALLINT,
  conversion_factor   NUMERIC
);

--create indexes and constraints
CREATE INDEX irs_concept_code_1 
  ON internal_relationship_stage (concept_code_1);
CREATE INDEX irs_concept_code_2 
  ON internal_relationship_stage (concept_code_2);
CREATE INDEX dcs_concept_code 
  ON drug_concept_stage (concept_code);
CREATE INDEX ds_drug_concept_code 
  ON ds_stage (drug_concept_code);
CREATE INDEX ds_ingredient_concept_code 
  ON ds_stage (ingredient_concept_code);
CREATE UNIQUE INDEX dcs_unique_concept_code 
  ON drug_concept_stage (concept_code);
CREATE INDEX irs_unique_concept_code 
  ON internal_relationship_stage (concept_code_1, concept_code_2);
