
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
ALTER TABLE concept_synonym ADD CONSTRAINT fpk_concept_synonym_language FOREIGN KEY (language_concept_id) REFERENCES concept (concept_id);
ALTER TABLE concept_synonym ADD CONSTRAINT unique_synonyms UNIQUE (concept_id,concept_synonym_name,language_concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_1 FOREIGN KEY (drug_concept_id) REFERENCES concept (concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_concept_2 FOREIGN KEY (ingredient_concept_id) REFERENCES concept (concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_1 FOREIGN KEY (amount_unit_concept_id) REFERENCES concept (concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_2 FOREIGN KEY (numerator_unit_concept_id) REFERENCES concept (concept_id);
ALTER TABLE drug_strength ADD CONSTRAINT fpk_drug_strength_unit_3 FOREIGN KEY (denominator_unit_concept_id) REFERENCES concept (concept_id);
ALTER TABLE pack_content ADD CONSTRAINT fpk_pack_content_concept_1 FOREIGN KEY (pack_concept_id) REFERENCES concept (concept_id);
ALTER TABLE pack_content ADD CONSTRAINT fpk_pack_content_concept_2 FOREIGN KEY (drug_concept_id) REFERENCES concept (concept_id);
ALTER TABLE concept_relationship_manual ADD CONSTRAINT unique_manual_relationships UNIQUE (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id);
ALTER TABLE concept_manual ADD CONSTRAINT unique_manual_concepts UNIQUE (vocabulary_id,concept_code);
ALTER TABLE concept_synonym_manual ADD CONSTRAINT unique_manual_synonyms UNIQUE (synonym_name,synonym_concept_code,synonym_vocabulary_id,language_concept_id);

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
CREATE INDEX idx_concept_code_2 ON concept_relationship_stage (concept_code_2);
ALTER TABLE concept_synonym_stage ADD CONSTRAINT idx_pk_css PRIMARY KEY (synonym_vocabulary_id,synonym_name,synonym_concept_code,language_concept_id);
CREATE INDEX idx_dss_concept_code ON drug_strength_stage (drug_concept_code);
CREATE INDEX idx_ca_descendant ON concept_ancestor (descendant_concept_id);
CREATE UNIQUE INDEX xpk_vocab_conversion ON vocabulary_conversion (vocabulary_id_v5);
CREATE INDEX idx_base_crm_cid1 ON base_concept_relationship_manual (concept_id_1) WHERE concept_id_1=0;
CREATE INDEX idx_base_crm_cid2 ON base_concept_relationship_manual (concept_id_2) WHERE concept_id_2=0;
CREATE INDEX idx_base_cm_cid ON base_concept_manual (concept_id) WHERE concept_id=0;
CREATE INDEX idx_base_csm_cid ON base_concept_synonym_manual (concept_id) WHERE concept_id=0;

--Create checks
ALTER TABLE concept ADD CONSTRAINT chk_c_concept_name CHECK (concept_name <> '');
ALTER TABLE concept ADD CONSTRAINT chk_c_standard_concept CHECK (COALESCE(standard_concept,'C') in ('C','S'));
ALTER TABLE concept ADD CONSTRAINT chk_c_concept_code CHECK (concept_code <> '');
ALTER TABLE concept ADD CONSTRAINT chk_c_invalid_reason CHECK (COALESCE(invalid_reason,'D') in ('D','U'));
ALTER TABLE concept_relationship ADD CONSTRAINT chk_cr_invalid_reason CHECK (COALESCE(invalid_reason,'D')='D');
ALTER TABLE concept_synonym ADD CONSTRAINT chk_csyn_concept_synonym_name CHECK (concept_synonym_name <> '');
ALTER TABLE concept_manual ADD CONSTRAINT chk_cmnl_concept_name CHECK (concept_name <> '');
ALTER TABLE concept_manual ADD CONSTRAINT chk_cmnl_concept_code CHECK (concept_code <> '');
ALTER TABLE concept_synonym_manual ADD CONSTRAINT chk_csynmnl_concept_synonym_name CHECK (synonym_name <> '');
ALTER TABLE concept_relationship_manual ADD CONSTRAINT chk_crm_invalid_reason CHECK (COALESCE(invalid_reason,'D')='D');
ALTER TABLE concept_relationship_manual ADD CONSTRAINT chk_crm_concept_code_1 CHECK (concept_code_1 <> '');
ALTER TABLE concept_relationship_manual ADD CONSTRAINT chk_crm_concept_code_2 CHECK (concept_code_2 <> '');