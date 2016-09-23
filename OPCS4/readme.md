Update of OPCS4

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- SNOMED must be loaded first.
- Working directory OPCS4.

1. Run create_source_tables.sql
2. Download the latest Data Migration Workbench from https://isd.hscic.gov.uk/trud3/user/authenticated/group/0/pack/1/subpack/98/releases
3. Extract the nhs_dmwb_xxxx.zip\UKTC NHS Data Migration Maps.mdb file.
4. Open UKTC NHS Data Migration Maps.mdb in Microsoft Access and do the export OPCS and OPCSSCTMAP tables into txt format with default settings (but use UTF-8!)
5. Load OPCS.txt and OPCSSCTMAP.txt into OPCS and OPCSSCTMAP using control files of the same name
6. Run load_stage.sql (with updated pVocabularyDate = latest update of vocabulary)
7. Run generic_update.sql (from working directory)