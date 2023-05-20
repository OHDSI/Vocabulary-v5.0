Prerequisites:

Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
Working directory COSMIC.

1. Run create_source_tables.sql
2. Upload the source tables;
3. Run load_stage.sql
4. Run generic_update: devv5.GenericUpdate();
