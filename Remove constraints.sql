-- Remove FKs

ALTER TABLE concept ADD CONSTRAINT xpk_concept;
ALTER TABLE vocabulary DROP CONSTRAINT xpk_vocabulary;
ALTER TABLE domain DROP CONSTRAINT xpk_domain;
ALTER TABLE concept_class DROP CONSTRAINT xpk_concept_class;
ALTER TABLE concept_relationship DROP CONSTRAINT xpk_concept_relationship;
ALTER TABLE relationship DROP CONSTRAINT xpk_relationship;
ALTER TABLE concept_ancestor DROP CONSTRAINT xpk_concept_ancestor;
ALTER TABLE source_to_concept_map DROP CONSTRAINT xpk_source_to_concept_map;
ALTER TABLE drug_strength DROP CONSTRAINT xpk_drug_strength;

-- Drop external keys

ALTER TABLE concept DROP CONSTRAINT fpk_concept_domain;
ALTER TABLE concept DROP CONSTRAINT fpk_concept_class;
ALTER TABLE concept DROP CONSTRAINT fpk_concept_vocabulary;
ALTER TABLE vocabulary DROP CONSTRAINT fpk_vocabulary_concept;
ALTER TABLE domain DROP CONSTRAINT fpk_domain_concept;
ALTER TABLE concept_class DROP CONSTRAINT fpk_concept_class_concept;
ALTER TABLE concept_relationship DROP CONSTRAINT fpk_concept_relationship_c_1;
ALTER TABLE concept_relationship DROP CONSTRAINT fpk_concept_relationship_c_2;
ALTER TABLE concept_relationship DROP CONSTRAINT fpk_concept_relationship_id;
ALTER TABLE relationship DROP CONSTRAINT fpk_relationship_concept;
ALTER TABLE relationship DROP CONSTRAINT fpk_relationship_reverse;
ALTER TABLE concept_synonym DROP CONSTRAINT fpk_concept_synonym_concept;
ALTER TABLE concept_ancestor DROP CONSTRAINT fpk_concept_ancestor_concept_1;
ALTER TABLE concept_ancestor DROP CONSTRAINT fpk_concept_ancestor_concept_2;
ALTER TABLE source_to_concept_map DROP CONSTRAINT fpk_source_to_concept_map_v_1;
ALTER TABLE source_to_concept_map DROP CONSTRAINT fpk_source_to_concept_map_v_2;
ALTER TABLE source_to_concept_map DROP CONSTRAINT fpk_source_to_concept_map_c_1;
ALTER TABLE drug_strength DROP CONSTRAINT fpk_drug_strength_concept_1;

-- Drop indexes

DROP INDEX idx_concept_code;
DROP INDEX idx_concept_vocabluary_id;
DROP INDEX idx_concept_domain_id;
DROP INDEX idx_concept_class_id;
DROP INDEX idx_concept_relationship_id_1;
DROP INDEX idx_concept_relationship_id_2;
DROP INDEX idx_concept_relationship_id_3;
DROP INDEX idx_concept_synonym_id;
DROP INDEX idx_csyn_concept_syn_name;
DROP INDEX idx_concept_ancestor_id_1;
DROP INDEX idx_concept_ancestor_id_2;
DROP INDEX idx_source_to_concept_map_id_1;
DROP INDEX idx_source_to_concept_map_id_2;
DROP INDEX idx_source_to_concept_map_id_3;
DROP INDEX idx_source_to_concept_map_code;
DROP INDEX idx_drug_strength_id_1;
DROP INDEX idx_drug_strength_id_2;
DROP INDEX idx_cs_concept_code;
DROP INDEX idx_cs_concept_id;
DROP INDEX idx_concept_id_1;
DROP INDEX idx_concept_id_2;
DROP INDEX idx_concept_code_1;
DROP INDEX idx_concept_code_2;
ALTER TABLE drug_strength DROP CONSTRAINT fpk_drug_strength_concept_2;
ALTER TABLE drug_strength DROP CONSTRAINT fpk_drug_strength_unit_1;
ALTER TABLE drug_strength DROP CONSTRAINT fpk_drug_strength_unit_2;
ALTER TABLE drug_strength DROP CONSTRAINT fpk_drug_strength_unit_3;
