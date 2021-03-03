Update of ICD10

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- SNOMED must be loaded first
- Working directory dev_icd10

* Manual tables are available here https://drive.google.com/drive/folders/1S6bEzFjn85M50V0f4jMhvgG6uuIhfJOD?usp=sharing

1. Go to http://apps.who.int/classifications/apps/icd/ClassificationDownload/DLArea/Download.aspx and download latest ICD-10 version (e.g. ICD-10 2016 version)
2. Unzip the file icdClaMLYYYYens.xml and rename to icdClaML.xml
3. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('ICD10',TO_DATE('20161201','YYYYMMDD'),'2016 Release');
4. Insert concept_manual.csv and concept_relationship_manual.csv into eponymous tables in dev_icd10 (already exist in schema)
5. Run manual_work/manual_mapping_qa.sql to check whether existing mannual_mapping meets the logic of ICD10CM mapping
6. Run load_stage.sql for the first time as a test
7. Run mapping_refresh_qa.sql and edit concept_relationship_manual table in case the deprecation of SNOMED concepts (all changes in concept_relationship_manual table should be reflected in the folder 'manual_work', e.g. manual_work_MMYY.sql, as well as backup of concept_relationship_manual should be created in dev_icd10 schema before any changes,e.g. concept_relationship_manual_backup_ddmmyy)
8. Run load_stage.sql 
9. Run generic_update: devv5.GenericUpdate();
10. Run QA script:
 * https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql



**csv format:**
* delimiter: ','
* encoding: 'UTF8'
* header: ON
* decimal symbol: '.'
* quote escape: NONE
* quote always: TRUE
* NULL string: empty
