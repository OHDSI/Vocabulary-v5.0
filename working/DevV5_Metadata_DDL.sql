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
* Authors: Aliaksei Katyshou
* Date: 2024
**************************************************************************/

CREATE TABLE concept_metadata (
    concept_id INT NOT NULL, 
    concept_type VARCHAR(20),
    CONSTRAINT chk_cm_concept_type CHECK (concept_type IN ('A', 'SA', 'SC', 'M', 'J')),
    FOREIGN KEY (concept_id) REFERENCES devv5.concept (concept_id)
);

CREATE TABLE concept_relationship_metadata (
    concept_id_1 INT NOT NULL,
    concept_id_2 INT NOT NULL,
    relationship_id VARCHAR(20) NOT NULL,
    relationship_predicate_id VARCHAR(20),
    relationship_group INT,
    mapping_source VARCHAR(50),
    confidence INT,
    mapping_tool VARCHAR(50),
    mapper VARCHAR(50),
    reviewer VARCHAR(50),
    FOREIGN KEY (concept_id_1, concept_id_2, relationship_id) REFERENCES devv5.concept_relationship (concept_id_1, concept_id_2, relationship_id)
);