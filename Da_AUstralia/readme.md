DA_Australia readme upload / update of amt

Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_aus.

Please, note the huge gap between the refreshes for DA_Australia. This vocabulary has been refreshed manually. Previous manual work and code (incl. load_stage) stored in 'archive' directories for future refactoring.

1. Run create_source_tables.sql and additional_ddl.sql
2. Download and extract files from \manual_tables
3. Upload files to corresponding tables
4. Run load_stage.sql
5. Run generic_update: devv5.GenericUpdate();