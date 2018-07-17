Update of ICD10

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory ICD10.

1. Go to http://apps.who.int/classifications/apps/icd/ClassificationDownload/DLArea/Download.aspx and download latest ICD-10 version (e.g. ICD-10 2016 version)
2. Unzip the file icdClaMLYYYYens.xml and rename to icdClaML.xml
3. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('ICD10',TO_DATE('20161201','YYYYMMDD'),'2016 Release');
4. Run load_stage.sql
5. Run generic_update.sql (from working directory)

 