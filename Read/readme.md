Update of Read

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- SNOMED must be loaded first
- Working directory Read.

1. Run create_source_tables.sql
2. Download Read code distrbution file
Open the site https://isd.hscic.gov.uk/trud3/user/authenticated/group/0/pack/1/subpack/21/releases.
- Download the latest release xx.
- Extract the nhs_readv2_xxxxx\V2\Unified\Keyv2.all file.
3. Download Read code to SNOMED CT mapping file
nhs_datamigration_VV.0.0_YYYYMMDD000001.zip from https://isd.hscic.gov.uk/trud3/user/authenticated/group/0/pack/9/subpack/9/releases (Subscription "NHS Data Migration"). "VV" stands for the current version number, "YYYYMMDD" for the release date.
- Download the latest release xx.
- Extract nhs_datamigration_xxxxx\Mapping Tables\Updated\Clinically Assured\rcsctmap2_uk_YYYYMMDD000001.txt

4. Load Keyv2.all and rcsctmap2_uk.txt into KEYV2 and RCSCTMAP2_UK using control files of the same name

5. Run load_stage.sql (with updated pVocabularyDate = latest update of vocabulary)
6. Run generic_update.sql (from working directory)

 