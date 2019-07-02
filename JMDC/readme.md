Update of JMDC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

1. Run create_source_tables.sql and additional_DDL.sql
2. Upload the source file in the JMDC table 
4. Run load_stage_1.sql
5. Manually fill *_to_map tables and re-upload them as *_mapped
6. Run load_stage_2.sql
7. Run build_RxE.sql and generic_update: devv5.GenericUpdate();
