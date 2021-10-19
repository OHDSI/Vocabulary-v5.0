Update of VANDF

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed
- RxNorm in SOURCES schema
- Working directory VANDF

1. Run load_stage.sql
2. Run generic_update: devv5.GenericUpdate();