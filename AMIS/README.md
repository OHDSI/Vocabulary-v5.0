AMIS upload / update

Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

Working directory dev_amis
1. Create additional to standard DDL tables (01_3_additional_ddl.sql)
2. Load source data:
	2.1 Run in DEVV5: 01_1_source_table.sql
	2.2 Run in DEVV5: SELECT sources.load_input_tables('AMIS');
3. Run concat.bat
4. Run whole_script.sql
