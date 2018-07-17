Update of OPCS4

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- SNOMED must be loaded first.
- Fresh concept_ancestor.
- Working directory OPCS4.

1. Run create_source_tables.sql
2. Download the latest Data Migration Workbench from https://isd.digital.nhs.uk/trud3/user/guest/group/0/pack/1/subpack/98/releases
3. Extract the nhs_dmwb_xxxx.zip\UKTC NHS Data Migration Maps.mdb file and rename to opcs4_data_migration.mdb
4. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('OPCS4',TO_DATE('20180614','YYYYMMDD'),'DATAMIGRATION_25.1.0_20180614000001');
5. Run load_stage.sql
6. Run generic_update.sql (from working directory)