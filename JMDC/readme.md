Update of JMDC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

1. Run create_source_tables.sql and additional_DDL.sql
2. Load the file
4. Run load_stage.sql
5. Run build_RxE.sql and generic_update: devv5.GenericUpdate();