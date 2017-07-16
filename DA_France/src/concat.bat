type "01_Z_drop_temporary_tables.sql" > whole_script.sql
type "01_4_non_drug.sql" >> whole_script.sql
type "list.sql" >> whole_script.sql
type "drug_concept_stage+IRS.sql" >> whole_script.sql
type "ds_stage.sql" >> whole_script.sql
type "relationship_to_concept.sql" >> whole_script.sql
type "concept_synonym_stage.sql" >> whole_script.sql
type "final_sequence.sql" >> whole_script.sql
type "delete_pc_stage(temp).sql">> whole_script.sql

echo commit; >> whole_script.sql
