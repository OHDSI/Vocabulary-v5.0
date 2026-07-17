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
* Authors: Timur Vakhitov
* Date: 2022
**************************************************************************/

CREATE OR REPLACE FUNCTION devv5.FillNewDevSchema (
	include_concept_ancestor BOOLEAN DEFAULT FALSE,
	include_deprecated_rels BOOLEAN DEFAULT FALSE,
	include_synonyms BOOLEAN DEFAULT FALSE
)
RETURNS void AS
$BODY$
/*
	Use this script to fill main tables (concept, concept_relationship, concept_synonym etc) for newly created schema from devv5
	Examples:
	SELECT devv5.FillNewDevSchema(); --filling with default settings (w/o ancestor, deprecated relationships and synonyms)
	SELECT devv5.FillNewDevSchema(include_concept_ancestor=>true); --same as above, but the concept_ancestor is included
	SELECT devv5.FillNewDevSchema(include_concept_ancestor=>true,include_deprecated_rels=>true,include_synonyms=>true); --all data will be copied
*/
BEGIN
	IF CURRENT_SCHEMA = 'devv5' THEN RAISE EXCEPTION 'You cannot use this script in the DevV5!'; END IF;

	--Create stage and 'manual' tables
	DROP TABLE IF EXISTS drug_strength_stage;
	CREATE TABLE drug_strength_stage (LIKE devv5.drug_strength_stage);

	DROP TABLE IF EXISTS pack_content_stage;
	CREATE TABLE pack_content_stage (LIKE devv5.pack_content_stage);

	DROP TABLE IF EXISTS concept_stage;
	CREATE TABLE concept_stage (LIKE devv5.concept_stage);

	DROP TABLE IF EXISTS concept_relationship_stage;
	CREATE TABLE concept_relationship_stage (LIKE devv5.concept_relationship_stage);

	DROP TABLE IF EXISTS concept_synonym_stage;
	CREATE TABLE concept_synonym_stage (LIKE devv5.concept_synonym_stage);

	--processing manual tables
	DROP TABLE IF EXISTS concept_manual, concept_relationship_manual, concept_synonym_manual;
	CREATE TABLE concept_manual (LIKE devv5.concept_manual INCLUDING CONSTRAINTS);
	CREATE TABLE concept_relationship_manual (LIKE devv5.concept_relationship_manual INCLUDING CONSTRAINTS);
	CREATE TABLE concept_synonym_manual (LIKE devv5.concept_synonym_manual INCLUDING CONSTRAINTS);
	INSERT INTO concept_manual
	SELECT concept_name,
		domain_id,
		vocabulary_id,
		concept_class_id,
		standard_concept,
		concept_code,
		valid_start_date,
		valid_end_date,
		invalid_reason
	FROM devv5.base_concept_manual
	WHERE concept_id <> 0;

	INSERT INTO concept_relationship_manual
	SELECT concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
	FROM devv5.base_concept_relationship_manual
	WHERE concept_id_1 <> 0
		AND concept_id_2 <> 0;

	INSERT INTO concept_synonym_manual
	SELECT synonym_name,
		synonym_concept_code,
		synonym_vocabulary_id,
		language_concept_id
	FROM devv5.base_concept_synonym_manual
	WHERE concept_id <> 0;

	--Create copies of table
	DROP TABLE IF EXISTS concept_ancestor, concept, concept_relationship, relationship, vocabulary, vocabulary_conversion, concept_class, domain, concept_synonym, drug_strength, pack_content CASCADE;
	CREATE TABLE concept_ancestor (LIKE devv5.concept_ancestor);
	INSERT INTO concept_ancestor SELECT * FROM devv5.concept_ancestor WHERE include_concept_ancestor;
	CREATE TABLE concept (LIKE devv5.concept INCLUDING CONSTRAINTS);
	INSERT INTO concept SELECT * FROM devv5.concept;
    CREATE TABLE concept_metadata (LIKE devv5.concept_metadata INCLUDING CONSTRAINTS);
	INSERT INTO concept_metadata SELECT * FROM devv5.concept_metadata;
	CREATE TABLE concept_relationship (LIKE devv5.concept_relationship INCLUDING CONSTRAINTS);
	INSERT INTO concept_relationship SELECT * FROM devv5.concept_relationship WHERE (invalid_reason IS NULL AND NOT include_deprecated_rels) OR include_deprecated_rels;
    CREATE TABLE concept_relationship_metadata (LIKE devv5.concept_relationship_metadata INCLUDING CONSTRAINTS);
    INSERT INTO concept_relationship_metadata SELECT * FROM devv5.concept_relationship_metadata;
	CREATE TABLE relationship (LIKE devv5.relationship);
	INSERT INTO relationship SELECT * FROM devv5.relationship;
	CREATE TABLE vocabulary (LIKE devv5.vocabulary);
	INSERT INTO vocabulary SELECT * FROM devv5.vocabulary;
	CREATE TABLE vocabulary_conversion (LIKE devv5.vocabulary_conversion);
	INSERT INTO vocabulary_conversion SELECT * FROM devv5.vocabulary_conversion;
	CREATE TABLE concept_class (LIKE devv5.concept_class);
	INSERT INTO concept_class SELECT * FROM devv5.concept_class;
	CREATE TABLE domain (LIKE devv5.domain);
	INSERT INTO domain SELECT * FROM devv5.domain;
	CREATE TABLE concept_synonym (LIKE devv5.concept_synonym INCLUDING CONSTRAINTS);
	INSERT INTO concept_synonym SELECT * FROM devv5.concept_synonym WHERE include_synonyms;
	CREATE TABLE drug_strength (LIKE devv5.drug_strength);
	INSERT INTO drug_strength SELECT * FROM devv5.drug_strength;
	CREATE TABLE pack_content (LIKE devv5.pack_content);
	INSERT INTO pack_content SELECT * FROM devv5.pack_content;

	--Create PKs
	ALTER TABLE concept ADD CONSTRAINT xpk_concept PRIMARY KEY (concept_id);
	ALTER TABLE vocabulary ADD CONSTRAINT xpk_vocabulary PRIMARY KEY (vocabulary_id);
	ALTER TABLE domain ADD CONSTRAINT xpk_domain PRIMARY KEY (domain_id);
	ALTER TABLE concept_class ADD CONSTRAINT xpk_concept_class PRIMARY KEY (concept_class_id);
	ALTER TABLE concept_relationship ADD CONSTRAINT xpk_concept_relationship PRIMARY KEY (concept_id_1,concept_id_2,relationship_id);
	ALTER TABLE relationship ADD CONSTRAINT xpk_relationship PRIMARY KEY (relationship_id);
	ALTER TABLE concept_ancestor ADD CONSTRAINT xpkconcept_ancestor PRIMARY KEY (ancestor_concept_id,descendant_concept_id);
	ALTER TABLE drug_strength ADD CONSTRAINT xpk_drug_strength PRIMARY KEY (drug_concept_id, ingredient_concept_id);

	--Create external keys and UNIQUE constraints
	ALTER TABLE concept ADD CONSTRAINT fpk_concept_domain FOREIGN KEY (domain_id) REFERENCES domain (domain_id) NOT VALID;
	ALTER TABLE concept ADD CONSTRAINT fpk_concept_class FOREIGN KEY (concept_class_id) REFERENCES concept_class (concept_class_id) NOT VALID;
	ALTER TABLE concept ADD CONSTRAINT fpk_concept_vocabulary FOREIGN KEY (vocabulary_id) REFERENCES vocabulary (vocabulary_id) NOT VALID;
	ALTER TABLE vocabulary ADD CONSTRAINT fpk_vocabulary_concept FOREIGN KEY (vocabulary_concept_id) REFERENCES concept (concept_id) NOT VALID;
	ALTER TABLE domain ADD CONSTRAINT fpk_domain_concept FOREIGN KEY (domain_concept_id) REFERENCES concept (concept_id) NOT VALID;
	ALTER TABLE concept_class ADD CONSTRAINT fpk_concept_class_concept FOREIGN KEY (concept_class_concept_id) REFERENCES concept (concept_id) NOT VALID;
	ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_c_1 FOREIGN KEY (concept_id_1) REFERENCES concept (concept_id) NOT VALID;
	ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_c_2 FOREIGN KEY (concept_id_2) REFERENCES concept (concept_id) NOT VALID;
	ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_id FOREIGN KEY (relationship_id) REFERENCES relationship (relationship_id) NOT VALID;
	ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_concept FOREIGN KEY (relationship_concept_id) REFERENCES concept (concept_id) NOT VALID;
	ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_reverse FOREIGN KEY (reverse_relationship_id) REFERENCES relationship (relationship_id) NOT VALID;
	ALTER TABLE concept_synonym ADD CONSTRAINT fpk_concept_synonym_concept FOREIGN KEY (concept_id) REFERENCES concept (concept_id) NOT VALID;
	ALTER TABLE concept_synonym ADD CONSTRAINT fpk_concept_synonym_language FOREIGN KEY (language_concept_id) REFERENCES concept (concept_id) NOT VALID;
	ALTER TABLE concept_synonym ADD CONSTRAINT unique_synonyms UNIQUE (concept_id,concept_synonym_name,language_concept_id);
	ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_1 FOREIGN KEY (drug_concept_id) REFERENCES concept (concept_id) NOT VALID;
	ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_2 FOREIGN KEY (ingredient_concept_id) REFERENCES concept (concept_id) NOT VALID;
	ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_1 FOREIGN KEY (amount_unit_concept_id) REFERENCES concept (concept_id) NOT VALID;
	ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_2 FOREIGN KEY (numerator_unit_concept_id) REFERENCES concept (concept_id) NOT VALID;
	ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_3 FOREIGN KEY (denominator_unit_concept_id) REFERENCES concept (concept_id) NOT VALID;
	ALTER TABLE pack_content ADD CONSTRAINT fpk_pack_content_concept_1 FOREIGN KEY (pack_concept_id) REFERENCES concept (concept_id) NOT VALID;
	ALTER TABLE pack_content ADD CONSTRAINT fpk_pack_content_concept_2 FOREIGN KEY (drug_concept_id) REFERENCES concept (concept_id) NOT VALID;

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
	CREATE INDEX idx_pack_content_id_2 ON pack_content (drug_concept_id);
	CREATE UNIQUE INDEX u_pack_content ON pack_content (pack_concept_id, drug_concept_id, COALESCE(amount,-1));
	ALTER TABLE concept_stage ADD CONSTRAINT idx_pk_cs PRIMARY KEY (concept_code,vocabulary_id);
	CREATE INDEX idx_cs_concept_id ON concept_stage (concept_id);
	ALTER TABLE concept_relationship_stage ADD CONSTRAINT idx_pk_crs PRIMARY KEY (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id);
	ALTER TABLE concept_synonym_stage ADD CONSTRAINT idx_pk_css PRIMARY KEY (synonym_vocabulary_id,synonym_name,synonym_concept_code,language_concept_id);
	CREATE INDEX idx_concept_code_2 ON concept_relationship_stage (concept_code_2);
	CREATE INDEX idx_dss_concept_code ON drug_strength_stage (drug_concept_code);
	CREATE INDEX idx_ca_descendant ON concept_ancestor (descendant_concept_id);
	CREATE UNIQUE INDEX xpk_vocab_conversion ON vocabulary_conversion (vocabulary_id_v5);

	--Create UNIQUE constraints for manual tables
	ALTER TABLE concept_manual ADD CONSTRAINT unique_manual_concepts UNIQUE (vocabulary_id,concept_code);
	ALTER TABLE concept_relationship_manual ADD CONSTRAINT unique_manual_relationships UNIQUE (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id);
	ALTER TABLE concept_synonym_manual ADD CONSTRAINT unique_manual_synonyms UNIQUE (synonym_name,synonym_concept_code,synonym_vocabulary_id,language_concept_id);

	--Analyzing
	ANALYZE concept;
	ANALYZE concept_relationship;
	ANALYZE concept_synonym;
	ANALYZE drug_strength;
	ANALYZE pack_content;
	ANALYZE concept_ancestor;
END;
$BODY$
LANGUAGE 'plpgsql'
SET client_min_messages = error;