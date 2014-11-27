-- Create tables

CREATE TABLE concept (
  concept_id            INTEGER            NOT NULL,
  concept_name            VARCHAR(255)    NOT NULL,
  domain_id                VARCHAR(200)        NOT NULL,
  vocabulary_id            VARCHAR(20)        NOT NULL,
  concept_class_id        VARCHAR(20)        NOT NULL,
  standard_concept        VARCHAR(1)        NULL,
  concept_code            VARCHAR(50)        NOT NULL,
  valid_start_date        DATE            NOT NULL,
  valid_end_date        DATE            NOT NULL,
  invalid_reason        VARCHAR(1)        NULL
)
;
CREATE TABLE vocabulary (
  vocabulary_id            VARCHAR(20)        NOT NULL,
  vocabulary_name        VARCHAR(255)    NOT NULL,
  vocabulary_reference    VARCHAR(255)    NULL,
  vocabulary_version    VARCHAR(255)    NULL,
  vocabulary_concept_id    INTEGER            NOT NULL
)
;

CREATE TABLE domain (
  domain_id            VARCHAR(20)        NOT NULL,
  domain_name        VARCHAR(255)    NOT NULL,
  domain_concept_id    INTEGER            NOT NULL
)
;

CREATE TABLE concept_class (
  concept_class_id            VARCHAR(20)        NOT NULL,
  concept_class_name        VARCHAR(255)    NOT NULL,
  concept_class_concept_id    INTEGER            NOT NULL
)
;

CREATE TABLE concept_relationship (
  concept_id_1            INTEGER            NOT NULL,
  concept_id_2            INTEGER            NOT NULL,
  relationship_id        VARCHAR(20)        NOT NULL,
  valid_start_date        DATE            NOT NULL,
  valid_end_date        DATE            NOT NULL,
  invalid_reason        VARCHAR(1)        NULL)
;

CREATE TABLE relationship (
  relationship_id            VARCHAR(20)        NOT NULL,
  relationship_name            VARCHAR(255)    NOT NULL,
  is_hierarchical            VARCHAR(1)        NOT NULL,
  defines_ancestry            VARCHAR(1)        NOT NULL,
  reverse_relationship_id    VARCHAR(20)        NOT NULL,
  relationship_concept_id    INTEGER            NOT NULL
)
;

CREATE TABLE concept_synonym (
  concept_id            INTEGER            NOT NULL,
  concept_synonym_name    VARCHAR(1000)    NOT NULL,
  language_concept_id    INTEGER            NOT NULL
)
;

CREATE TABLE concept_ancestor (
  ancestor_concept_id        INTEGER        NOT NULL,
  descendant_concept_id        INTEGER        NOT NULL,
  min_levels_of_separation    INTEGER        NOT NULL,
  max_levels_of_separation    INTEGER        NOT NULL)
;

CREATE TABLE source_to_concept_map (
  source_code                VARCHAR(50)        NOT NULL,
  source_vocabulary_id        VARCHAR(20)        NOT NULL,
  source_code_description    VARCHAR(255)    NULL,
  target_concept_id            INTEGER            NOT NULL,
  target_vocabulary_id        VARCHAR(20)        NOT NULL,
  valid_start_date            DATE            NOT NULL,
  valid_end_date            DATE            NOT NULL,
  invalid_reason            VARCHAR(1)        NULL)
;

CREATE TABLE drug_strength (
  drug_concept_id                INTEGER        NOT NULL,
  ingredient_concept_id            INTEGER        NOT NULL,
  amount_value                    FLOAT        NULL,
  amount_unit_concept_id        INTEGER        NULL,
  numerator_value                FLOAT        NULL,
  numerator_unit_concept_id        INTEGER        NULL,
  denominator_unit_concept_id    INTEGER        NULL,
  valid_start_date                DATE        NOT NULL,
  valid_end_date                DATE        NOT NULL,
  invalid_reason                VARCHAR(1)    NULL)
;

CREATE TABLE CONCEPT_STAGE
(
   concept_id         INTEGER,
   concept_name       VARCHAR2 (256),
   domain_id          VARCHAR (200),
   vocabulary_id      VARCHAR (20) NOT NULL,
   concept_class_id   VARCHAR (20),
   standard_concept   VARCHAR2 (1 BYTE),
   concept_code       VARCHAR2 (40 BYTE) NOT NULL,
   VALID_START_DATE   DATE
                         DEFAULT TO_DATE ('01-Jan-1970', 'DD-MM-RRRR')
                         NOT NULL,
   VALID_END_DATE     DATE
                         DEFAULT TO_DATE ('31-Dec-2099', 'DD-MM-RRRR')
                         NOT NULL,
   invalid_reason     VARCHAR2 (1 BYTE)
);

-- Create FKs

ALTER TABLE concept ADD CONSTRAINT xpk_concept PRIMARY KEY (concept_id);
ALTER TABLE vocabulary ADD CONSTRAINT xpk_vocabulary PRIMARY KEY (vocabulary_id);
ALTER TABLE domain ADD CONSTRAINT xpk_domain PRIMARY KEY (domain_id);
ALTER TABLE concept_class ADD CONSTRAINT xpk_concept_class PRIMARY KEY (concept_class_id);
ALTER TABLE concept_relationship ADD CONSTRAINT xpk_concept_relationship PRIMARY KEY (concept_id_1,concept_id_2,relationship_id);
ALTER TABLE relationship ADD CONSTRAINT xpk_relationship PRIMARY KEY (relationship_id);
ALTER TABLE concept_ancestor ADD CONSTRAINT xpk_concept_ancestor PRIMARY KEY (ancestor_concept_id,descendant_concept_id);
ALTER TABLE source_to_concept_map ADD CONSTRAINT xpk_source_to_concept_map PRIMARY KEY (source_vocabulary_id,target_concept_id,source_code,valid_end_date);
ALTER TABLE drug_strength ADD CONSTRAINT xpk_drug_strength PRIMARY KEY (drug_concept_id, ingredient_concept_id);

-- Create external keys

ALTER TABLE concept ADD CONSTRAINT fpk_concept_domain FOREIGN KEY (domain_id) REFERENCES domain (domain_id);
ALTER TABLE concept ADD CONSTRAINT fpk_concept_class FOREIGN KEY (concept_class_id) REFERENCES concept_class (concept_class_id);
ALTER TABLE concept ADD CONSTRAINT fpk_concept_vocabulary FOREIGN KEY (vocabulary_id) REFERENCES vocabulary (vocabulary_id);
ALTER TABLE vocabulary ADD CONSTRAINT fpk_vocabulary_concept FOREIGN KEY (vocabulary_concept_id) REFERENCES concept (concept_id);
ALTER TABLE domain ADD CONSTRAINT fpk_domain_concept FOREIGN KEY (domain_concept_id) REFERENCES concept (concept_id);
ALTER TABLE concept_class ADD CONSTRAINT fpk_concept_class_concept FOREIGN KEY (concept_class_concept_id) REFERENCES concept (concept_id);
ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_c_1 FOREIGN KEY (concept_id_1) REFERENCES concept (concept_id);
ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_c_2 FOREIGN KEY (concept_id_2) REFERENCES concept (concept_id);
ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_id FOREIGN KEY (relationship_id) REFERENCES relationship (relationship_id);
ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_concept FOREIGN KEY (relationship_concept_id) REFERENCES concept (concept_id);
ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_reverse FOREIGN KEY (reverse_relationship_id) REFERENCES relationship (relationship_id);
ALTER TABLE concept_synonym ADD CONSTRAINT fpk_concept_synonym_concept FOREIGN KEY (concept_id) REFERENCES concept (concept_id);
ALTER TABLE concept_ancestor ADD CONSTRAINT fpk_concept_ancestor_concept_1 FOREIGN KEY (ancestor_concept_id) REFERENCES concept (concept_id);
ALTER TABLE concept_ancestor ADD CONSTRAINT fpk_concept_ancestor_concept_2 FOREIGN KEY (descendant_concept_id) REFERENCES concept (concept_id);
ALTER TABLE source_to_concept_map ADD CONSTRAINT fpk_source_to_concept_map_v_1 FOREIGN KEY (source_vocabulary_id) REFERENCES vocabulary (vocabulary_id);
ALTER TABLE source_to_concept_map ADD CONSTRAINT fpk_source_to_concept_map_v_2 FOREIGN KEY (target_vocabulary_id) REFERENCES vocabulary (vocabulary_id);
ALTER TABLE source_to_concept_map ADD CONSTRAINT fpk_source_to_concept_map_c_1 FOREIGN KEY (target_concept_id) REFERENCES concept (concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_1 FOREIGN KEY (drug_concept_id) REFERENCES concept (concept_id);

-- Create indexes

CREATE INDEX idx_concept_code ON concept (concept_code ASC);
CREATE INDEX idx_concept_vocabluary_id ON concept (vocabulary_id ASC);
CREATE INDEX idx_concept_domain_id ON concept (domain_id ASC);
CREATE INDEX idx_concept_class_id ON concept (concept_class_id ASC);
CREATE INDEX idx_concept_relationship_id_1 ON concept_relationship (concept_id_1 ASC); 
CREATE INDEX idx_concept_relationship_id_2 ON concept_relationship (concept_id_2 ASC); 
CREATE INDEX idx_concept_relationship_id_3 ON concept_relationship (relationship_id ASC); 
CREATE INDEX idx_concept_synonym_id ON concept_synonym (concept_id ASC);
CREATE INDEX idx_csyn_concept_syn_name ON concept_synonym (concept_synonym_name);
CREATE INDEX idx_concept_ancestor_id_1 ON concept_ancestor (ancestor_concept_id ASC);
CREATE INDEX idx_concept_ancestor_id_2 ON concept_ancestor (descendant_concept_id ASC);
CREATE INDEX idx_source_to_concept_map_id_1 ON source_to_concept_map (source_vocabulary_id ASC);
CREATE INDEX idx_source_to_concept_map_id_2 ON source_to_concept_map (target_vocabulary_id ASC);
CREATE INDEX idx_source_to_concept_map_id_3 ON source_to_concept_map (target_concept_id ASC);
CREATE INDEX idx_source_to_concept_map_code ON source_to_concept_map (source_code ASC);
CREATE INDEX idx_drug_strength_id_1 ON drug_strength (drug_concept_id ASC);
CREATE INDEX idx_drug_strength_id_2 ON drug_strength (ingredient_concept_id ASC);
CREATE INDEX idx_cs_concept_code ON concept_stage (concept_code);
CREATE INDEX idx_cs_concept_id ON concept_stage (concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_2 FOREIGN KEY (ingredient_concept_id) REFERENCES concept (concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_1 FOREIGN KEY (amount_unit_concept_id) REFERENCES concept (concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_2 FOREIGN KEY (numerator_unit_concept_id) REFERENCES concept (concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_3 FOREIGN KEY (denominator_unit_concept_id) REFERENCES concept (concept_id);