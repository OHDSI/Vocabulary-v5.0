/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the License);
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an AS IS BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov
* Date: 2017
**************************************************************************/

--Main DDL

DROP TABLE IF EXISTS concept CASCADE;
CREATE TABLE concept (
	concept_id int4 NOT NULL,
	concept_name VARCHAR (255) NOT NULL,
	domain_id VARCHAR (20) NOT NULL,
	vocabulary_id VARCHAR (20) NOT NULL,
	concept_class_id VARCHAR (20) NOT NULL,
	standard_concept VARCHAR (1),
	concept_code VARCHAR (50) NOT NULL,
	valid_start_date DATE NOT NULL,
	valid_end_date DATE NOT NULL,
	invalid_reason VARCHAR (1)
);

DROP TABLE IF EXISTS concept_relationship CASCADE;
CREATE TABLE concept_relationship (
	concept_id_1 int4 NOT NULL,
	concept_id_2 int4 NOT NULL,
	relationship_id VARCHAR (20) NOT NULL,
	valid_start_date DATE NOT NULL,
	valid_end_date DATE NOT NULL,
	invalid_reason VARCHAR (1)
);

DROP TABLE IF EXISTS concept_synonym CASCADE;
CREATE TABLE concept_synonym (
	concept_id int4 NOT NULL,
	concept_synonym_name VARCHAR (1000) NOT NULL,
	language_concept_id int4 NOT NULL
);

DROP TABLE IF EXISTS concept_ancestor CASCADE;
CREATE TABLE concept_ancestor (
	ancestor_concept_id int4 NOT NULL,
	descendant_concept_id int4 NOT NULL,
	min_levels_of_separation int4 NOT NULL,
	max_levels_of_separation int4 NOT NULL
);

DROP TABLE IF EXISTS relationship CASCADE;
CREATE TABLE relationship (
	relationship_id VARCHAR (20) NOT NULL,
	relationship_name VARCHAR (255) NOT NULL UNIQUE,
	is_hierarchical int NOT NULL,
	defines_ancestry int2 NOT NULL,
	reverse_relationship_id VARCHAR (20) NOT NULL,
	relationship_concept_id int4 NOT NULL
);

DROP TABLE IF EXISTS vocabulary CASCADE;
CREATE TABLE vocabulary (
	vocabulary_id VARCHAR (20) NOT NULL,
	vocabulary_name VARCHAR (255) NOT NULL,
	vocabulary_reference VARCHAR (255) NOT NULL,
	vocabulary_version VARCHAR (255),
	vocabulary_concept_id int4 NOT NULL
);

DROP TABLE IF EXISTS vocabulary_conversion CASCADE;
CREATE TABLE vocabulary_conversion (
	vocabulary_id_v4 int4 PRIMARY KEY,
	vocabulary_id_v5 VARCHAR (20),
	omop_req VARCHAR (1),
	click_default VARCHAR (1),
	available VARCHAR (25),
	url VARCHAR (256),
	click_disabled VARCHAR (1),
	latest_update DATE
);

DROP TABLE IF EXISTS relationship_conversion CASCADE;
CREATE TABLE relationship_conversion (
	relationship_id int2 NOT NULL,
	relationship_id_new  VARCHAR (20) NOT NULL
);

DROP TABLE IF EXISTS concept_class_conversion CASCADE;
CREATE TABLE concept_class_conversion
(
  concept_class      VARCHAR (50) NOT NULL,
  concept_class_id_new  VARCHAR (20) NOT NULL
);

DROP TABLE IF EXISTS concept_class CASCADE;
CREATE TABLE concept_class (
	concept_class_id VARCHAR (20) NOT NULL,
	concept_class_name VARCHAR (255) NOT NULL,
	concept_class_concept_id int4 NOT NULL
);

DROP TABLE IF EXISTS domain CASCADE;
CREATE TABLE domain (
	domain_id VARCHAR (20) NOT NULL,
	domain_name VARCHAR (255) NOT NULL,
	domain_concept_id int4 NOT NULL
);

DROP TABLE IF EXISTS drug_strength CASCADE;
CREATE TABLE drug_strength (
	drug_concept_id int4 NOT NULL,
	ingredient_concept_id int4 NOT NULL,
	amount_value FLOAT,
	amount_unit_concept_id int4,
	numerator_value FLOAT,
	numerator_unit_concept_id int4,
	denominator_value FLOAT,
	denominator_unit_concept_id int4,
	box_size int4,
	valid_start_date DATE NOT NULL,
	valid_end_date DATE NOT NULL,
	invalid_reason VARCHAR (1)
);

DROP TABLE IF EXISTS pack_content CASCADE;
CREATE TABLE pack_content (
	pack_concept_id int4 NOT NULL,
	drug_concept_id int4 NOT NULL,
	amount FLOAT,
	box_size int4
);

DROP TABLE IF EXISTS concept_stage;
CREATE TABLE concept_stage (
	concept_id int4,
	concept_name VARCHAR (255),
	domain_id VARCHAR (20),
	vocabulary_id VARCHAR (20) NOT NULL,
	concept_class_id VARCHAR (20),
	standard_concept VARCHAR (1),
	concept_code VARCHAR (50) NOT NULL,
	valid_start_date DATE NOT NULL,
	valid_end_date DATE NOT NULL,
	invalid_reason VARCHAR (1)
);

DROP TABLE IF EXISTS concept_relationship_stage;
CREATE TABLE concept_relationship_stage (
	concept_id_1 int4,
	concept_id_2 int4,
	concept_code_1 VARCHAR (50) NOT NULL,
	concept_code_2 VARCHAR (50) NOT NULL,
	vocabulary_id_1 VARCHAR (20) NOT NULL,
	vocabulary_id_2 VARCHAR (20) NOT NULL,
	relationship_id VARCHAR (20) NOT NULL,
	valid_start_date DATE NOT NULL,
	valid_end_date DATE NOT NULL,
	invalid_reason VARCHAR (1)
);

DROP TABLE IF EXISTS concept_synonym_stage;
CREATE TABLE concept_synonym_stage (
	synonym_concept_id int4,
	synonym_name VARCHAR (1000) NOT NULL,
	synonym_concept_code VARCHAR (50) NOT NULL,
	synonym_vocabulary_id VARCHAR (20) NOT NULL,
	language_concept_id int4
);

DROP TABLE IF EXISTS drug_strength_stage;
CREATE TABLE drug_strength_stage (
	drug_concept_code VARCHAR (20) NOT NULL,
	vocabulary_id_1 VARCHAR (20) NOT NULL,
	ingredient_concept_code VARCHAR (20) NOT NULL,
	vocabulary_id_2 VARCHAR (20) NOT NULL,
	amount_value FLOAT,
	amount_unit_concept_id int4,
	numerator_value FLOAT,
	numerator_unit_concept_id int4,
	denominator_value FLOAT,
	denominator_unit_concept_id int4,
	valid_start_date DATE NOT NULL,
	valid_end_date DATE NOT NULL,
	invalid_reason VARCHAR (1)
);

DROP TABLE IF EXISTS pack_content_stage;
CREATE TABLE pack_content_stage (
	pack_concept_code VARCHAR (20) NOT NULL,
	pack_vocabulary_id VARCHAR (20) NOT NULL,
	drug_concept_code VARCHAR (20) NOT NULL,
	drug_vocabulary_id VARCHAR (20) NOT NULL,
	amount FLOAT,
	box_size int4
);

DROP TABLE IF EXISTS concept_relationship_manual;
CREATE TABLE concept_relationship_manual (
	concept_code_1 VARCHAR (50) NOT NULL,
	concept_code_2 VARCHAR (50) NOT NULL,
	vocabulary_id_1 VARCHAR (20) NOT NULL,
	vocabulary_id_2 VARCHAR (20) NOT NULL,
	relationship_id VARCHAR (20) NOT NULL,
	valid_start_date DATE NOT NULL,
	valid_end_date DATE NOT NULL,
	invalid_reason VARCHAR (1)
);

--Create PKs
ALTER TABLE concept ADD CONSTRAINT xpk_concept PRIMARY KEY (concept_id);
ALTER TABLE vocabulary ADD CONSTRAINT xpk_vocabulary PRIMARY KEY (vocabulary_id);
ALTER TABLE domain ADD CONSTRAINT xpk_domain PRIMARY KEY (domain_id);
ALTER TABLE concept_class ADD CONSTRAINT xpk_concept_class PRIMARY KEY (concept_class_id);
ALTER TABLE concept_relationship ADD CONSTRAINT xpk_concept_relationship PRIMARY KEY (concept_id_1,concept_id_2,relationship_id);
ALTER TABLE relationship ADD CONSTRAINT xpk_relationship PRIMARY KEY (relationship_id);
ALTER TABLE concept_ancestor ADD CONSTRAINT xpkconcept_ancestor PRIMARY KEY (ancestor_concept_id,descendant_concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT xpk_drug_strength PRIMARY KEY (drug_concept_id, ingredient_concept_id);

--Create external keys
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
ALTER TABLE concept_synonym ADD CONSTRAINT unique_synonyms UNIQUE (concept_id,concept_synonym_name,language_concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_1 FOREIGN KEY (drug_concept_id) REFERENCES concept (concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_2 FOREIGN KEY (ingredient_concept_id) REFERENCES concept (concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_1 FOREIGN KEY (amount_unit_concept_id) REFERENCES concept (concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_2 FOREIGN KEY (numerator_unit_concept_id) REFERENCES concept (concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_3 FOREIGN KEY (denominator_unit_concept_id) REFERENCES concept (concept_id);
ALTER TABLE pack_content ADD CONSTRAINT fpk_pack_content_concept_1 FOREIGN KEY (pack_concept_id) REFERENCES concept (concept_id);
ALTER TABLE pack_content ADD CONSTRAINT fpk_pack_content_concept_2 FOREIGN KEY (drug_concept_id) REFERENCES concept (concept_id);

--Create indexes
CREATE UNIQUE INDEX idx_unique_concept_code ON concept (vocabulary_id, concept_code) WHERE vocabulary_id NOT IN ('DRG', 'SMQ') AND concept_code <> 'OMOP generated';
/*
	We need index listed below for queries like "SELECT * FROM concept WHERE vocabulary_id='xxx'".
	Previous unique index only to support unique pairs of voabulary_id+concept_code with some exceptions
*/
CREATE INDEX idx_vocab_concept_code ON concept (vocabulary_id varchar_pattern_ops, concept_code);
CREATE INDEX idx_concept_relationship_id_2 ON concept_relationship (concept_id_2);
CREATE INDEX idx_concept_synonym_id ON concept_synonym (concept_id);
CREATE INDEX idx_csyn_concept_syn_name ON concept_synonym (concept_synonym_name);
CREATE INDEX idx_drug_strength_id_1 ON drug_strength (drug_concept_id);
CREATE INDEX idx_drug_strength_id_2 ON drug_strength (ingredient_concept_id);
CREATE INDEX idx_pack_content_id_1 ON pack_content (pack_concept_id);
CREATE INDEX idx_pack_content_id_2 ON pack_content (drug_concept_id);
CREATE UNIQUE INDEX u_pack_content ON pack_content (pack_concept_id, drug_concept_id, amount);
CREATE INDEX idx_cs_concept_code ON concept_stage (concept_code);
CREATE INDEX idx_cs_concept_id ON concept_stage (concept_id);
CREATE INDEX idx_concept_code_1 ON concept_relationship_stage (concept_code_1);
CREATE INDEX idx_concept_code_2 ON concept_relationship_stage (concept_code_2);
CREATE INDEX idx_dss_concept_code ON drug_strength_stage (drug_concept_code);
CREATE INDEX idx_ca_descendant ON concept_ancestor (descendant_concept_id);
CREATE UNIQUE INDEX xpk_vocab_conversion ON vocabulary_conversion (vocabulary_id_v5);

--Create checks
ALTER TABLE concept ADD CONSTRAINT chk_c_concept_name CHECK (concept_name <> '');
ALTER TABLE concept ADD CONSTRAINT chk_c_standard_concept CHECK (COALESCE(standard_concept,'C') in ('C','S'));
ALTER TABLE concept ADD CONSTRAINT chk_c_concept_code CHECK (concept_code <> '');
ALTER TABLE concept ADD CONSTRAINT chk_c_invalid_reason CHECK (COALESCE(invalid_reason,'D') in ('D','U'));
ALTER TABLE concept_relationship ADD CONSTRAINT chk_cr_invalid_reason CHECK (COALESCE(invalid_reason,'D')='D');
ALTER TABLE concept_synonym ADD CONSTRAINT chk_csyn_concept_synonym_name CHECK (concept_synonym_name <> '');