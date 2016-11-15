type "00_non_drug.sql" > whole_script.sql
type "01_drug_concept_stage.sql" >> whole_script.sql
type "02_ds_stage.sql" >> whole_script.sql
type "03_internal_relationship_stage.sql" >> whole_script.sql
type "04_pc_stage.sql" >> whole_script.sql
type "05_relationship_to_concept.sql" >> whole_script.sql
type "changes_after_QA.sql" >> whole_script.sql 
echo commit; >> whole_script.sql
