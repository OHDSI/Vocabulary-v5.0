type "01_Z_drop_temporary_tables.sql" > whole_script.sql
type "01_4_non_drug.sql" >> whole_script.sql
type "02_packs_and_homeopathy.sql" >> whole_script.sql
type "packaging_parsing.sql" >> whole_script.sql
type "pack_rebuild.sql" >> whole_script.sql
type "ds_stage.sql" >> whole_script.sql
type "list.sql" >> whole_script.sql
type "internal_relat_stage.sql" >> whole_script.sql
type "relationship_to_concept.sql" >> whole_script.sql
type "pack_content.sql" >> whole_script.sql
type "concept_synonym_stage.sql" >> whole_script.sql
type "final_sequence.sql" >> whole_script.sql


echo commit; >> whole_script.sql
