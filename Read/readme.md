Update of Read

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- SNOMED, RxNorm, CVX must be loaded first
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
5. Run FULL FastRecreate (but without filling concept_ancestor):
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>false, include_deprecated_rels=>true, include_synonyms=>true);
```
6. As described in the "manual_work" folder, upload concept_manual.csv and concept_relationship_manual.csv into eponymous tables, which exist by default in the dev schema after the FastRecreate.
   If you already have manual staging tables, obligatory create backups of them (e.g. concept_relationship_manual_backup_ddmmyy, concept_manual_backup_ddmmyy)
7. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/ICD10CM/load_stage.sql) for the first time to define problems in mapping.
   Note: Load_stage generates list of the relationships that need to be checked and modified by the medical coder and after uploading this data to server load_stage continues making proper relationships using this manually created table
8. Perform manual work described in manual_work folder
9. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/ICD10CM/load_stage.sql) for the second time to refresh ICD10CM
10. Run generic_update: 
```sql
SELECT devv5.GenericUpdate();
```
11. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql)