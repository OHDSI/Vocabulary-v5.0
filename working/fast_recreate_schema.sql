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

/*
use this script to recreate main tables (concept, concept_relationship, concept_synonym) without dropping your schema
*/


declare
main_schema_name constant varchar2(100):='DEVV5';
begin 
    execute immediate 'ALTER TABLE source_to_concept_map DROP CONSTRAINT fpk_source_to_concept_map_v_1';
    execute immediate 'ALTER TABLE source_to_concept_map DROP CONSTRAINT fpk_source_to_concept_map_v_2';
    execute immediate 'drop table concept cascade constraints purge';
    execute immediate 'drop table concept_relationship purge';
    execute immediate 'drop table concept_synonym purge';
    execute immediate 'drop table vocabulary purge';
    execute immediate 'drop table relationship purge';
	execute immediate 'drop table existing_ds purge';
	execute immediate 'drop table drug_strength purge';
    execute immediate 'truncate table CONCEPT_STAGE';
    execute immediate 'truncate table concept_relationship_stage';
	execute immediate 'truncate table concept_synonym_stage';
	execute immediate 'truncate table concept_class';
	execute immediate 'truncate table domain';
	execute immediate 'truncate table vocabulary_conversion';

	execute immediate 'insert into concept_class select * from '||main_schema_name||'.concept_class';
	execute immediate 'insert into domain select * from '||main_schema_name||'.domain';
	execute immediate 'insert into vocabulary_conversion select * from '||main_schema_name||'.vocabulary_conversion';

    
    /*CTAS with NOLOGGING (faster)*/
    execute immediate 'CREATE TABLE concept NOLOGGING AS SELECT * FROM '||main_schema_name||'.concept';
    execute immediate 'CREATE TABLE concept_relationship NOLOGGING AS SELECT * FROM '||main_schema_name||'.concept_relationship';
    execute immediate 'CREATE TABLE concept_synonym NOLOGGING AS SELECT * FROM '||main_schema_name||'.concept_synonym';
    execute immediate 'CREATE TABLE vocabulary NOLOGGING AS SELECT * FROM '||main_schema_name||'.vocabulary';
    execute immediate 'CREATE TABLE relationship NOLOGGING AS SELECT * FROM '||main_schema_name||'.relationship';
	execute immediate 'CREATE TABLE existing_ds NOLOGGING AS SELECT * FROM '||main_schema_name||'.existing_ds';
	execute immediate 'CREATE TABLE drug_strength NOLOGGING AS SELECT * FROM '||main_schema_name||'.drug_strength';

    /*create indexes and constraints for main tables*/
    execute immediate 'ALTER TABLE concept ADD CONSTRAINT xpk_concept PRIMARY KEY (concept_id)';
    execute immediate 'ALTER TABLE vocabulary ADD CONSTRAINT xpk_vocabulary PRIMARY KEY (vocabulary_id)';
    execute immediate 'ALTER TABLE relationship ADD CONSTRAINT xpk_relationship PRIMARY KEY (relationship_id)';
    execute immediate 'ALTER TABLE vocabulary ADD CONSTRAINT fpk_vocabulary_concept FOREIGN KEY (vocabulary_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE concept_relationship ADD CONSTRAINT xpk_concept_relationship PRIMARY KEY (concept_id_1,concept_id_2,relationship_id)';
    execute immediate 'ALTER TABLE concept ADD CONSTRAINT fpk_concept_domain FOREIGN KEY (domain_id) REFERENCES domain (domain_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE concept ADD CONSTRAINT fpk_concept_class FOREIGN KEY (concept_class_id) REFERENCES concept_class (concept_class_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE concept ADD CONSTRAINT fpk_concept_vocabulary FOREIGN KEY (vocabulary_id) REFERENCES vocabulary (vocabulary_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_c_1 FOREIGN KEY (concept_id_1) REFERENCES concept (concept_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_c_2 FOREIGN KEY (concept_id_2) REFERENCES concept (concept_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE concept_relationship ADD CONSTRAINT fpk_concept_relationship_id FOREIGN KEY (relationship_id) REFERENCES relationship (relationship_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_concept FOREIGN KEY (relationship_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE relationship ADD CONSTRAINT fpk_relationship_reverse FOREIGN KEY (reverse_relationship_id) REFERENCES relationship (relationship_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE concept_synonym ADD CONSTRAINT fpk_concept_synonym_concept FOREIGN KEY (concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE';
	execute immediate 'ALTER TABLE concept_synonym ADD CONSTRAINT unique_synonyms UNIQUE (concept_id,concept_synonym_name,language_concept_id)';
    execute immediate 'CREATE INDEX idx_concept_code ON concept (concept_code ASC) NOLOGGING';
    execute immediate 'CREATE INDEX idx_concept_vocabluary_id ON concept (vocabulary_id ASC) NOLOGGING';
    execute immediate 'CREATE INDEX idx_concept_domain_id ON concept (domain_id ASC) NOLOGGING';
    execute immediate 'CREATE INDEX idx_concept_class_id ON concept (concept_class_id ASC) NOLOGGING';
    execute immediate 'CREATE INDEX idx_concept_relationship_id_1 ON concept_relationship (concept_id_1 ASC) NOLOGGING'; 
    execute immediate 'CREATE INDEX idx_concept_relationship_id_2 ON concept_relationship (concept_id_2 ASC) NOLOGGING'; 
    execute immediate 'CREATE INDEX idx_concept_relationship_id_3 ON concept_relationship (relationship_id ASC) NOLOGGING';     
    execute immediate 'CREATE INDEX idx_concept_synonym_id ON concept_synonym (concept_id ASC) NOLOGGING';
    execute immediate 'CREATE INDEX idx_csyn_concept_syn_name ON concept_synonym (concept_synonym_name) NOLOGGING';    

    /*enable other constraints*/
    execute immediate 'ALTER TABLE domain ADD CONSTRAINT fpk_domain_concept FOREIGN KEY (domain_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE concept_class ADD CONSTRAINT fpk_concept_class_concept FOREIGN KEY (concept_class_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE source_to_concept_map ADD CONSTRAINT fpk_source_to_concept_map_c_1 FOREIGN KEY (target_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_1 FOREIGN KEY (drug_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE';    
    execute immediate 'ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_2 FOREIGN KEY (ingredient_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_1 FOREIGN KEY (amount_unit_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_2 FOREIGN KEY (numerator_unit_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_3 FOREIGN KEY (denominator_unit_concept_id) REFERENCES concept (concept_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE source_to_concept_map ADD CONSTRAINT fpk_source_to_concept_map_v_1 FOREIGN KEY (source_vocabulary_id) REFERENCES vocabulary (vocabulary_id) ENABLE NOVALIDATE';
    execute immediate 'ALTER TABLE source_to_concept_map ADD CONSTRAINT fpk_source_to_concept_map_v_2 FOREIGN KEY (target_vocabulary_id) REFERENCES vocabulary (vocabulary_id) ENABLE NOVALIDATE';
	
	/*GATHER_TABLE_STATS*/
	DBMS_STATS.GATHER_TABLE_STATS (ownname=> USER, tabname => 'concept', estimate_percent => null, cascade => true);
	DBMS_STATS.GATHER_TABLE_STATS (ownname=> USER, tabname => 'concept_relationship', estimate_percent => null, cascade => true);
	DBMS_STATS.GATHER_TABLE_STATS (ownname=> USER, tabname => 'concept_synonym', estimate_percent => null, cascade => true);
end;