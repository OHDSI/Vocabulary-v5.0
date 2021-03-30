### ICD10 upload/update

#### Prerequisites
- Basic knowledge of the [OMOP representation of the ICD10 vocabulary](https://www.ohdsi.org/web/wiki/doku.php?id=documentation:vocabulary:icd10)
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- SNOMED must be loaded first
- Working directory dev_icd10

#### Sequence of actions
1. Download the latest ICD-10 version (e.g. ICD-10 2016 version) on the [WHO Website](http://apps.who.int/classifications/apps/icd/ClassificationDownload/DLArea/Download.aspx) 
2. Unzip the file icdClaMLYYYYens.xml and rename to icdClaML.xml
3. Run in devv5 (with the fresh vocabulary date and version): 
```sql
SELECT sources.load_input_tables('ICD10',TO_DATE('20161201','YYYYMMDD'),'2016 Release');
```
4. Run the FastRecreate:
```sql
SELECT devv5.FastRecreateSchema(include_synonyms=>true); 
```
5. As described in the "manual_work" folder, upload concept_manual.csv and concept_relationship_manual.csv into eponymous tables, which exist by default in the dev schema after  the FastRecreate. If you already have manual staging tables, obligatory create backups of them (e.g. concept_relationship_manual_backup_ddmmyy, concept_manual_backup_ddmmyy)
6. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10-documentation/ICD10/load_stage.sql) for the first time to define problems in mapping
7. Perform manual work described in manual_work folder
8. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10-documentation/ICD10/load_stage.sql) for the second time to refresh ICD10
9. Run generic_update: 
```sql
SELECT devv5.GenericUpdate();
```
10. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql)
11. If no problems, enjoy!
