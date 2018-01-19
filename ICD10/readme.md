Update of ICD10

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory ICD10.

1. Go to http://apps.who.int/classifications/apps/icd/ClassificationDownload/DLArea/Download.aspx and download latest ICD-10 version (e.g. ICD-10 2016 version)
2. Unzip the file and load icdClaMLYYYYens.xml using ICDCLAML.ctl
3. Run load_stage.sql (with updated pVocabularyDate = latest update date)
4. Run generic_update.sql (from working directory)

 