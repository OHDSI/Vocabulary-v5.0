ALTER TABLE concept drop CONSTRAINT fpk_concept_domain ;
ALTER TABLE concept drop CONSTRAINT fpk_concept_class ;
ALTER TABLE concept drop CONSTRAINT fpk_concept_vocabulary ;
ALTER TABLE vocabulary drop CONSTRAINT fpk_vocabulary_concept ;
ALTER TABLE domain drop CONSTRAINT fpk_domain_concept ;
ALTER TABLE concept_class drop CONSTRAINT fpk_concept_class_concept ;
ALTER TABLE concept_relationship drop CONSTRAINT fpk_concept_relationship_c_1 ;
ALTER TABLE concept_relationship drop CONSTRAINT fpk_concept_relationship_c_2 ;
ALTER TABLE concept_relationship drop CONSTRAINT fpk_concept_relationship_id ;
ALTER TABLE relationship drop CONSTRAINT fpk_relationship_concept ;
ALTER TABLE relationship drop CONSTRAINT fpk_relationship_reverse ;
ALTER TABLE concept_synonym drop CONSTRAINT fpk_concept_synonym_concept ;
ALTER TABLE concept_ancestor drop CONSTRAINT fpk_concept_ancestor_concept_1 ;
ALTER TABLE concept_ancestor drop CONSTRAINT fpk_concept_ancestor_concept_2 ;
ALTER TABLE source_to_concept_map drop CONSTRAINT fpk_source_to_concept_map_v_1 ;
ALTER TABLE source_to_concept_map drop CONSTRAINT fpk_source_to_concept_map_v_2 ;
ALTER TABLE source_to_concept_map drop CONSTRAINT fpk_source_to_concept_map_c_1 ;
ALTER TABLE drug_strength drop CONSTRAINT fpk_drug_strength_concept_1 ;
ALTER TABLE drug_strength drop CONSTRAINT fpk_drug_strength_concept_2 ;
ALTER TABLE drug_strength drop CONSTRAINT fpk_drug_strength_unit_1 ;
ALTER TABLE drug_strength drop CONSTRAINT fpk_drug_strength_unit_2 ;
ALTER TABLE drug_strength drop CONSTRAINT fpk_drug_strength_unit_3 ;
ALTER TABLE cohort_definition drop CONSTRAINT fpk_cohort_definition_concept ;


ALTER TABLE concept drop CONSTRAINT xpk_concept ;
ALTER TABLE vocabulary drop CONSTRAINT xpk_vocabulary ;
ALTER TABLE domain drop CONSTRAINT xpk_domain ;
ALTER TABLE concept_class drop CONSTRAINT xpk_concept_class ;
ALTER TABLE concept_relationship drop CONSTRAINT xpk_concept_relationship ;
ALTER TABLE relationship drop CONSTRAINT xpk_relationship ;
ALTER TABLE concept_ancestor drop CONSTRAINT xpk_concept_ancestor ;
ALTER TABLE source_to_concept_map drop CONSTRAINT xpk_source_to_concept_map ;
ALTER TABLE drug_strength drop CONSTRAINT xpk_drug_strength ;
ALTER TABLE cohort_definition drop CONSTRAINT xpk_cohort_definition ;
ALTER TABLE attribute_definition drop CONSTRAINT xpk_attribute_definition ;

commit;