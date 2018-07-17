Update of Read

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- SNOMED must be loaded first
- Working directory Read.

1. Run create_source_tables.sql
2. Download Read code distrbution file
Open the site https://isd.digital.nhs.uk/trud3/user/guest/group/0/pack/1/subpack/21/releases.
- Download the latest release xx.
- Extract the nhs_readv2_xxxxx\V2\Unified\Keyv2.all file.
3. Download Read code to SNOMED CT mapping file
nhs_datamigration_VV.0.0_YYYYMMDD000001.zip from https://isd.digital.nhs.uk/trud3/user/guest/group/0/pack/9/subpack/9/releases (Subscription "NHS Data Migration"). "VV" stands for the current version number, "YYYYMMDD" for the release date.
- Download the latest release xx.
- Extract nhs_datamigration_xxxxx\Mapping Tables\Updated\Clinically Assured\rcsctmap2_uk_YYYYMMDD000001.txt and rename to rcsctmap2_uk.txt

4. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('READ',TO_DATE('20180403','YYYYMMDD'),'NHS READV2 21.0.0 20160401000001 + DATAMIGRATION_25.0.0_20180403000001'); 
5. Run load_stage.sql
6. Run generic_update.sql (from working directory)