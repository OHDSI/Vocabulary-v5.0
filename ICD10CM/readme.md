### ICD10CM upload / update

#### Prerequisites
- Basic knowledge of the [OMOP representation of the ICD10CM vocabulary](https://www.ohdsi.org/web/wiki/doku.php?id=documentation:vocabulary:icd10cm)
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Schema UMLS
- SNOMED must be loaded first
- Working directory, e.g. dev_icd10cm

#### Sequence of actions
1. Download the latest ICD-10-CM version from https://ftp.cdc.gov/pub/Health_Statistics/NCHS/Publications/ICD10CM/
2. Unzip the file ICD10CM_FYYYYY_code_descriptions.zip, extract icd10cm_order_YYYY.txt and rename to icd10cm.txt
3. Run [create_source_tables.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/ICD10CM/create_source_tables.sql)
4. Run in devv5 (with fresh vocabulary date and version, e.g. according "The 2018 ICD-10-CM codes are to be used from October 1, 2017 through September 30, 2018" so 20171001): 
```sql
SELECT sources.load_input_tables('ICD10CM',TO_DATE('20170428','YYYYMMDD'),'ICD10CM FY2017 code descriptions');
```
5. Run FULL FastRecreate:
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>false, include_deprecated_rels=>true, include_synonyms=>true);
```
6. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/ICD10CM/load_stage.sql) for the first time to define problems in mapping.
   Note: Load_stage generates list of the relationships that need to be checked and modified by the medical coder and after uploading this data to server load_stage continues making proper relationships using this manually created table
7. Perform manual work described in manual_work folder
8. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/ICD10CM/load_stage.sql) for the second time to refresh ICD10CM
9. Run generic_update: 
```sql
SELECT devv5.GenericUpdate();
```
11. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql)
12. If no problems, enjoy!

