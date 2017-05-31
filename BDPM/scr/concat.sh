cat "01_Z_drop_temporary_tables.sql" > whole_script.sql
cat "01_4_non_drug.sql" > whole_script.sql
cat "01_sequence.sql" >> whole_script.sql
cat "list.sql" >> whole_script.sql
cat "ds_stage.sql" >> whole_script.sql
cat "internal_relat_stage.sql" >> whole_script.sql
cat "relationship_to_concept.sql" >> whole_script.sql
cat "pack_content.sql" >> whole_script.sql


echo "commit;" >> whole_script.sql
