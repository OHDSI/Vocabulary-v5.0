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
* Date: 2020
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
	vocabulary_concept_id int4 NOT NULL,
	latest_update DATE, --service field (new update date for using in load_stage/functions/generic_update)
	dev_schema_name TEXT, --service field (the name of the schema where manual changes come from if the script is run in the devv5)
	vocabulary_params JSONB --service field (for storing additional params)
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
	amount_value NUMERIC,
	amount_unit_concept_id int4,
	numerator_value NUMERIC,
	numerator_unit_concept_id int4,
	denominator_value NUMERIC,
	denominator_unit_concept_id int4,
	box_size int2,
	valid_start_date DATE NOT NULL,
	valid_end_date DATE NOT NULL,
	invalid_reason VARCHAR (1)
);

DROP TABLE IF EXISTS pack_content CASCADE;
CREATE TABLE pack_content (
	pack_concept_id int4 NOT NULL,
	drug_concept_id int4 NOT NULL,
	amount int2,
	box_size int2
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
	language_concept_id int4 NOT NULL
);

DROP TABLE IF EXISTS drug_strength_stage;
CREATE TABLE drug_strength_stage (
	drug_concept_code VARCHAR (20) NOT NULL,
	vocabulary_id_1 VARCHAR (20) NOT NULL,
	ingredient_concept_code VARCHAR (20) NOT NULL,
	vocabulary_id_2 VARCHAR (20) NOT NULL,
	amount_value NUMERIC,
	amount_unit_concept_id int4,
	numerator_value NUMERIC,
	numerator_unit_concept_id int4,
	denominator_value NUMERIC,
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
	amount int2,
	box_size int2
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

DROP TABLE IF EXISTS concept_manual;
CREATE TABLE concept_manual (
	concept_name VARCHAR (255),
	domain_id VARCHAR (20),
	vocabulary_id VARCHAR (20) NOT NULL,
	concept_class_id VARCHAR (20),
	standard_concept VARCHAR (1),
	concept_code VARCHAR (50) NOT NULL,
	valid_start_date DATE,
	valid_end_date DATE,
	invalid_reason VARCHAR (1)
);

DROP TABLE IF EXISTS concept_synonym_manual;
CREATE TABLE concept_synonym_manual (
	synonym_name VARCHAR (1000) NOT NULL,
	synonym_concept_code VARCHAR (50) NOT NULL,
	synonym_vocabulary_id VARCHAR (20) NOT NULL,
	language_concept_id int4 NOT NULL
);

--Create a base table for manual relationships, it stores all manual relationships from all vocabularies
DROP TABLE IF EXISTS base_concept_relationship_manual;
CREATE TABLE base_concept_relationship_manual (
	LIKE concept_relationship_manual,
	concept_id_1 INT4 NOT NULL,
	concept_id_2 INT4 NOT NULL,
	CONSTRAINT idx_pk_base_crm PRIMARY KEY (
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id
		)
	);

--Create a base table for manual concepts, it stores all manual concepts from all vocabularies
DROP TABLE IF EXISTS base_concept_manual CASCADE;
CREATE TABLE base_concept_manual (
	LIKE concept_manual,
	concept_id INT4 NOT NULL,
	CONSTRAINT idx_pk_base_cm PRIMARY KEY (
		concept_code,
		vocabulary_id
		)
	);

--Create a base table for manual synonyms, it stores all manual synonyms from all vocabularies
DROP TABLE IF EXISTS base_concept_synonym_manual CASCADE;
CREATE TABLE base_concept_synonym_manual (
	LIKE concept_synonym_manual,
	concept_id INT4 NOT NULL,
	CONSTRAINT idx_pk_base_csm PRIMARY KEY (
		synonym_vocabulary_id,
		synonym_name,
		synonym_concept_code,
		language_concept_id
		)
	);
