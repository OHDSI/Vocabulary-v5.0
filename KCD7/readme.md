Update of KCD7

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory KCD7.
- ICD10, SNOMED must be loaded first.

1. Run create_source_tables.sql
2. Get the latest data file, load into sources.kcd7
3. Run load_stage.sql
4. Run generic_update: devv5.GenericUpdate();