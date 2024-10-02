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
4. Run FULL FastRecreate:
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>false, include_deprecated_rels=>true, include_synonyms=>true);
```
5. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10-documentation/ICD10/load_stage.sql) for the first time to define problems in mapping
6. Perform manual work described in manual_work folder
7. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10-documentation/ICD10/load_stage.sql) for the second time to refresh ICD10
8. Run generic_update: 
```sql
SELECT devv5.GenericUpdate();
```
10. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql)
11. If no problems, enjoy!
