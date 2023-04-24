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
* Authors: Alexander Davydov, Anna Ostropolets, Christian Reich, Timur Vakhitov, Oleg Zhuk
* Date: 2023
**************************************************************************/


DROP TABLE IF EXISTS drug_concept_stage CASCADE;
DROP TABLE IF EXISTS ds_stage CASCADE;
DROP TABLE IF EXISTS internal_relationship_stage CASCADE;
DROP TABLE IF EXISTS pc_stage CASCADE;
DROP TABLE IF EXISTS relationship_to_concept CASCADE;

CREATE TABLE drug_concept_stage
(
   concept_name            VARCHAR(255),
   vocabulary_id           VARCHAR(20),
   concept_class_id        VARCHAR(20),
   standard_concept        VARCHAR(1),
   concept_code            VARCHAR(255),
   possible_excipient      VARCHAR(1),
   domain_id               VARCHAR(20),
   valid_start_date        DATE,
   valid_end_date          DATE,
   invalid_reason          VARCHAR(1),
   source_concept_class_id VARCHAR(20)
);

CREATE TABLE ds_stage
(
   drug_concept_code       VARCHAR(255),
   ingredient_concept_code VARCHAR(255),
   box_size                SMALLINT,
   amount_value            NUMERIC,
   amount_unit             VARCHAR(50),
   numerator_value         NUMERIC,
   numerator_unit          VARCHAR(50),
   denominator_value       NUMERIC,
   denominator_unit        VARCHAR(50)
);

CREATE TABLE internal_relationship_stage
(
   concept_code_1 VARCHAR(255),
   concept_code_2 VARCHAR(255)
);

CREATE TABLE pc_stage
(
   pack_concept_code VARCHAR(50),
   drug_concept_code VARCHAR(50),
   amount            FLOAT,
   box_size          INT
);

CREATE TABLE relationship_to_concept
(
   concept_code_1    VARCHAR(255),
   vocabulary_id_1   VARCHAR(20),
   concept_id_2      INT,
   precedence        SMALLINT,
   conversion_factor NUMERIC
);
