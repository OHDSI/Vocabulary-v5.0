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

-- concept_metadata
DROP TABLE IF EXISTS concept_metadata;

CREATE TABLE concept_metadata (
    concept_id INT NOT NULL,  
    concept_category varchar(20),
    reuse_status varchar(20),
    FOREIGN KEY (concept_id) REFERENCES concept (concept_id),
    CONSTRAINT chk_concept_category CHECK (concept_category IN ('A', 'SA', 'SC', 'M', 'J')),
    CONSTRAINT chk_reuse_status CHECK (reuse_status IN ('RF', 'RP', 'R')),
    UNIQUE (concept_id)
);

-- concept_relationship_metadata
DROP TABLE IF EXISTS concept_relationship_metadata;

CREATE TABLE concept_relationship_metadata (
    concept_id_1 INT NOT NULL,
    concept_id_2 INT NOT NULL,
    relationship_id varchar(20) NOT NULL,
    relationship_predicate_id VARCHAR(20),
    relationship_group INT,
    mapping_source VARCHAR(50),
    confidence FLOAT,
    mapping_tool VARCHAR(50),
    mapper VARCHAR(50),
    reviewer VARCHAR(50),
    FOREIGN KEY (concept_id_1, concept_id_2, relationship_id) 
        REFERENCES concept_relationship (concept_id_1, concept_id_2, relationship_id),
    CONSTRAINT chk_relationship_predicate_id 
        CHECK (relationship_predicate_id IN ('eq', 'up', 'down')),
    CONSTRAINT chk_confidence 
        CHECK (confidence >= 0 AND confidence <= 1),
    UNIQUE (concept_id_1, concept_id_2, relationship_id)
);