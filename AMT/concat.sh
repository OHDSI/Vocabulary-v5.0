cat "SNOMED-AU_conversion.sql" > load_stage.sql
cat "00_non_drug.sql" >> load_stage.sql
cat "01_drug_concept_stage.sql" >> load_stage.sql
cat "02_ds_stage.sql" >> load_stage.sql
cat "03_internal_relationship_stage.sql" >> load_stage.sql
cat "04_pc_stage.sql" >> load_stage.sql
cat "05_relationship_to_concept.sql" >> load_stage.sql
cat "changes_after_QA.sql" >> load_stage.sql 
cat "drop_temporary_tables.sql" >> load_stage.sql 

echo "commit;" >> load_stage.sql
