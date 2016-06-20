/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov, Christian Reich
* Date: 2016
**************************************************************************/

-- Create tables
CREATE TABLE source_to_concept_map
(
   source_code               VARCHAR (50) NOT NULL,
   source_vocabulary_id      VARCHAR (20) NOT NULL,
   source_code_description   VARCHAR (255) NULL,
   target_concept_id         INTEGER NOT NULL,
   target_vocabulary_id      VARCHAR (20) NOT NULL,
   valid_start_date          DATE NOT NULL,
   valid_end_date            DATE NOT NULL,
   invalid_reason            VARCHAR (1) NULL
);

CREATE TABLE drug_strength_stage
(
   drug_concept_code             VARCHAR2 (20) NOT NULL,
   vocabulary_id_1               VARCHAR2 (20) NOT NULL,
   ingredient_concept_code       VARCHAR2 (20) NOT NULL,
   vocabulary_id_2               VARCHAR2 (20) NOT NULL,
   amount_value                  FLOAT NULL,
   amount_unit_concept_id        INTEGER NULL,
   numerator_value               FLOAT NULL,
   numerator_unit_concept_id     INTEGER NULL,
   denominator_value             FLOAT NULL,
   denominator_unit_concept_id   INTEGER NULL,
   valid_start_date              DATE NOT NULL,
   valid_end_date                DATE NOT NULL,
   invalid_reason                VARCHAR (1) NULL
)
NOLOGGING;

CREATE TABLE concept_stage
(
   concept_id         NUMBER,
   concept_name       VARCHAR2 (255),
   domain_id          VARCHAR (200),
   vocabulary_id      VARCHAR (20) NOT NULL,
   concept_class_id   VARCHAR (20),
   standard_concept   VARCHAR2 (1 BYTE),
   concept_code       VARCHAR2 (40 BYTE) NOT NULL,
   VALID_START_DATE   DATE NOT NULL,
   VALID_END_DATE     DATE NOT NULL,
   invalid_reason     VARCHAR2 (1 BYTE)
)
NOLOGGING
;

CREATE TABLE concept_relationship_stage
(
  CONCEPT_ID_1      NUMBER,
  CONCEPT_ID_2      NUMBER,
  CONCEPT_CODE_1    VARCHAR2(50 BYTE),
  CONCEPT_CODE_2    VARCHAR2(50 BYTE),
  VOCABULARY_ID_1   VARCHAR (20) NOT NULL,
  VOCABULARY_ID_2   VARCHAR (20) NOT NULL,
  RELATIONSHIP_ID   VARCHAR2(20 BYTE) NOT NULL,
  VALID_START_DATE  DATE,
  VALID_END_DATE    DATE,
  INVALID_REASON    VARCHAR2(1 BYTE)
)
NOLOGGING
;

CREATE TABLE CONCEPT_RELATIONSHIP_MANUAL
(
   CONCEPT_CODE_1     VARCHAR2 (50 BYTE) NOT NULL,
   CONCEPT_CODE_2     VARCHAR2 (50 BYTE) NOT NULL,
   VOCABULARY_ID_1    VARCHAR (20) NOT NULL,
   VOCABULARY_ID_2    VARCHAR (20) NOT NULL,
   RELATIONSHIP_ID    VARCHAR2 (20 BYTE) NOT NULL,
   VALID_START_DATE   DATE NOT NULL,
   VALID_END_DATE     DATE NOT NULL,
   INVALID_REASON     VARCHAR2 (1 BYTE)
)
NOLOGGING
;

CREATE TABLE concept_synonym_stage
(
  SYNONYM_CONCEPT_ID   NUMBER,
  SYNONYM_NAME         VARCHAR2(1000 CHAR) NOT NULL,
  SYNONYM_CONCEPT_CODE VARCHAR(50 CHAR) NOT NULL,
  SYNONYM_VOCABULARY_ID VARCHAR(20) NOT NULL,
  LANGUAGE_CONCEPT_ID  NUMBER
)
NOLOGGING
;

CREATE TABLE SNOMED_ANCESTOR
(
  ANCESTOR_CONCEPT_CODE     VARCHAR2(50 CHAR),
  DESCENDANT_CONCEPT_CODE   VARCHAR2(50 CHAR),
  MIN_LEVELS_OF_SEPARATION  NUMBER,
  MAX_LEVELS_OF_SEPARATION  NUMBER
) 
NOLOGGING
;

CREATE TABLE EXISTING_DS
(
   DRUG_CONCEPT_CODE         VARCHAR2 (50) NOT NULL,
   INGREDIENT_CONCEPT_CODE   VARCHAR2 (50) NOT NULL,
   VOCABULARY_ID             VARCHAR2 (20) NOT NULL,
   AMOUNT_VALUE              FLOAT,
   AMOUNT_UNIT               VARCHAR2 (255),
   NUMERATOR_VALUE           FLOAT,
   NUMERATOR_UNIT            VARCHAR2 (255),
   DENOMINATOR_VALUE         FLOAT,
   DENOMINATOR_UNIT          VARCHAR2 (255),
   DOSE_FORM_CODE            VARCHAR2 (255),
   BRAND_CODE                VARCHAR2 (255),
   BOX_SIZE                  FLOAT
);

-- Create copies of table

CREATE TABLE concept_ancestor NOLOGGING AS SELECT * FROM devv5.concept_ancestor;
CREATE TABLE concept NOLOGGING AS SELECT * FROM devv5.concept;
CREATE TABLE concept_relationship NOLOGGING AS SELECT * FROM devv5.concept_relationship;
CREATE TABLE relationship NOLOGGING AS SELECT * FROM devv5.relationship;
CREATE TABLE vocabulary NOLOGGING AS SELECT * FROM devv5.vocabulary;
CREATE TABLE vocabulary_conversion NOLOGGING AS SELECT * FROM devv5.vocabulary_conversion;
CREATE TABLE concept_class NOLOGGING AS SELECT * FROM devv5.concept_class;
CREATE TABLE domain NOLOGGING AS SELECT * FROM devv5.domain;
CREATE TABLE concept_synonym NOLOGGING AS SELECT * FROM devv5.concept_synonym;
CREATE TABLE drug_strength NOLOGGING AS SELECT * FROM devv5.drug_strength;

-- Create PKs
ALTER TABLE concept ADD CONSTRAINT xpk_concept PRIMARY KEY (concept_id);
ALTER TABLE vocabulary ADD CONSTRAINT xpk_vocabulary PRIMARY KEY (vocabulary_id);
ALTER TABLE domain ADD CONSTRAINT xpk_domain PRIMARY KEY (domain_id);
ALTER TABLE concept_class ADD CONSTRAINT xpk_concept_class PRIMARY KEY (concept_class_id);
ALTER TABLE concept_relationship ADD CONSTRAINT xpk_concept_relationship PRIMARY KEY (concept_id_1,concept_id_2,relationship_id);
ALTER TABLE relationship ADD CONSTRAINT xpk_relationship PRIMARY KEY (relationship_id);
ALTER TABLE concept_ancestor ADD CONSTRAINT xpkconcept_ancestor PRIMARY KEY (ancestor_concept_id,descendant_concept_id);
ALTER TABLE snomed_ancestor ADD CONSTRAINT xpksnomed_ancestor PRIMARY KEY (ancestor_concept_code,descendant_concept_code);
ALTER TABLE source_to_concept_map ADD CONSTRAINT xpk_source_to_concept_map PRIMARY KEY (source_vocabulary_id,target_concept_id,source_code,valid_end_date);
ALTER TABLE drug_strength ADD CONSTRAINT xpk_drug_strength PRIMARY KEY (drug_concept_id, ingredient_concept_id);

-- Create external keys

ALTER TABLE concept ADD CONSTRAINT fpk_concept_domain FOREIGN KEY (domain_id) REFERENCES domain (domain_id) ENABLE NOVALIDATE;
ALTER TABLE concept ADD CONSTRAINT fpk_concept_class FOREIGN KEY (concept_class_id) REFERENCES concept_class (concept_class_id) ENABLE NOVALIDATE;
ALTER TABLE concept ADD CONSTRAINT fpk_concept_vocabulary FOREIGN KEY (vocabulary_id) REFERENCES vocabulary (vocabulary_id) ENABLE NOVALIDATE;
ALTER TABLE vocabulary ADD CONSTRAINT fpk_vocabulary_concept FOREIGN KEY (vocabulary_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE;
ALTER TABLE domain ADD CONSTRAINT fpk_domain_concept FOREIGN KEY (domain_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE;
ALTER TABLE concept_class ADD CONSTRAINT fpk_concept_class_concept FOREIGN KEY (concept_class_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE;
ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_c_1 FOREIGN KEY (concept_id_1) REFERENCES concept (concept_id) ENABLE NOVALIDATE;
ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_c_2 FOREIGN KEY (concept_id_2) REFERENCES concept (concept_id) ENABLE NOVALIDATE;
ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_id FOREIGN KEY (relationship_id) REFERENCES relationship (relationship_id) ENABLE NOVALIDATE;
ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_concept FOREIGN KEY (relationship_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE;
ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_reverse FOREIGN KEY (reverse_relationship_id) REFERENCES relationship (relationship_id) ENABLE NOVALIDATE;
ALTER TABLE concept_synonym ADD CONSTRAINT fpk_concept_synonym_concept FOREIGN KEY (concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE;
ALTER TABLE concept_synonym ADD CONSTRAINT unique_synonyms UNIQUE (concept_id,concept_synonym_name,language_concept_id);
ALTER TABLE source_to_concept_map ADD CONSTRAINT fpk_source_to_concept_map_v_1 FOREIGN KEY (source_vocabulary_id) REFERENCES vocabulary (vocabulary_id) ENABLE NOVALIDATE;
ALTER TABLE source_to_concept_map ADD CONSTRAINT fpk_source_to_concept_map_v_2 FOREIGN KEY (target_vocabulary_id) REFERENCES vocabulary (vocabulary_id) ENABLE NOVALIDATE;
ALTER TABLE source_to_concept_map ADD CONSTRAINT fpk_source_to_concept_map_c_1 FOREIGN KEY (target_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE;
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_1 FOREIGN KEY (drug_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE;
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_2 FOREIGN KEY (ingredient_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE;
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_1 FOREIGN KEY (amount_unit_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE;
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_2 FOREIGN KEY (numerator_unit_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE;
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_3 FOREIGN KEY (denominator_unit_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE;

-- Create indexes

CREATE INDEX idx_concept_voc_code ON concept (vocabulary_id, concept_code) NOLOGGING;
CREATE INDEX idx_concept_domain_id ON concept (domain_id ASC) NOLOGGING;
CREATE INDEX idx_concept_class_id ON concept (concept_class_id ASC) NOLOGGING;
CREATE INDEX idx_concept_relationship_id_2 ON concept_relationship (concept_id_2 ASC) NOLOGGING; 
CREATE INDEX idx_concept_relationship_id_3 ON concept_relationship (relationship_id ASC) NOLOGGING; 
CREATE INDEX idx_concept_synonym_id ON concept_synonym (concept_id ASC) NOLOGGING;
CREATE INDEX idx_csyn_concept_syn_name ON concept_synonym (concept_synonym_name) NOLOGGING;
CREATE INDEX idx_source_to_concept_map_id_1 ON source_to_concept_map (source_vocabulary_id ASC);
CREATE INDEX idx_source_to_concept_map_id_2 ON source_to_concept_map (target_vocabulary_id ASC);
CREATE INDEX idx_source_to_concept_map_id_3 ON source_to_concept_map (target_concept_id ASC);
CREATE INDEX idx_source_to_concept_map_code ON source_to_concept_map (source_code ASC);
CREATE INDEX idx_drug_strength_id_1 ON drug_strength (drug_concept_id ASC);
CREATE INDEX idx_drug_strength_id_2 ON drug_strength (ingredient_concept_id ASC);
CREATE INDEX idx_cs_concept_code ON concept_stage (concept_code);
CREATE INDEX idx_cs_concept_id ON concept_stage (concept_id);
CREATE INDEX idx_concept_code_1 ON concept_relationship_stage (concept_code_1);
CREATE INDEX idx_concept_code_2 ON concept_relationship_stage (concept_code_2);

-- GATHER_TABLE_STATS
exec DBMS_STATS.GATHER_TABLE_STATS (ownname=> USER, tabname => 'concept', estimate_percent => null, degree =>4, cascade => true);
exec DBMS_STATS.GATHER_TABLE_STATS (ownname=> USER, tabname => 'concept_relationship', estimate_percent => null, degree =>4, cascade => true);
exec DBMS_STATS.GATHER_TABLE_STATS (ownname=> USER, tabname => 'concept_synonym', estimate_percent => null, degree =>4, cascade => true);