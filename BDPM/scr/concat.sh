cat "01_Z_drop_temporary_tables.sql" > whole_script.sql
cat "01_4_non_drug.sql" >> whole_script.sql
cat "02_packs_and_homeopathy.sql" >> whole_script.sql
cat "packaging_parsing.sql" >> whole_script.sql
cat "pack_rebuild.sql" >> whole_script.sql
cat "ds_stage.sql" >> whole_script.sql
cat "list.sql" >> whole_script.sql
cat "internal_relat_stage.sql" >> whole_script.sql
cat "relationship_to_concept.sql" >> whole_script.sql
cat "pack_content.sql" >> whole_script.sql
cat "concept_synonym_stage.sql" >> whole_script.sql
cat "final_sequence.sql" >> whole_script.sql


echo "commit;" >> whole_script.sql
