/*
use this script to recreate main tables (concept, concept_relationship, concept_synonym) without dropping your schema
*/


declare
begin 
    execute immediate 'ALTER TABLE source_to_concept_map DROP CONSTRAINT fpk_source_to_concept_map_v_1';
    execute immediate 'ALTER TABLE source_to_concept_map DROP CONSTRAINT fpk_source_to_concept_map_v_2';
    execute immediate 'drop table concept cascade constraints purge';
    execute immediate 'drop table concept_relationship purge';
    execute immediate 'drop table concept_synonym purge';
    execute immediate 'drop table vocabulary purge';
    execute immediate 'drop table relationship purge';
    execute immediate 'truncate table CONCEPT_STAGE';
    execute immediate 'truncate table concept_relationship_stage';
	execute immediate 'truncate table concept_synonym_stage';
	execute immediate 'truncate table concept_class';
	execute immediate 'truncate table domain';

	insert into concept_class select * from v5dev.concept_class;
	insert into domain select * from v5dev.domain;

    
    /*CTAS with NOLOGGING (faster)*/
    execute immediate 'CREATE TABLE concept NOLOGGING AS SELECT * FROM v5dev.concept';
    execute immediate 'CREATE TABLE concept_relationship NOLOGGING AS SELECT * FROM v5dev.concept_relationship';
    execute immediate 'CREATE TABLE concept_synonym NOLOGGING AS SELECT * FROM v5dev.concept_synonym';
    execute immediate 'CREATE TABLE vocabulary NOLOGGING AS SELECT * FROM v5dev.vocabulary';
    execute immediate 'CREATE TABLE relationship NOLOGGING AS SELECT * FROM v5dev.relationship';

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