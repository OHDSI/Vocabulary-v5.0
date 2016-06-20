Update of ICD10PCS

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory ICD10PCS.

1. Run create_source_tables.sql
2. Download the latest file from https://www.cms.gov/Medicare/Coding/ICD10/YYYY-ICD-10-PCS-and-GEMs.html, file name YYYY-PCS-Long-Abbrev-Titles.zip
3. Exctract icd10pcs_codes_YYYY.txt and rename to icd10pcs.txt
4. Load file into ICD10PCS. Use the control files of the same name.
5. Change pVocabularyDate according file creation date
6. Run load_stage.sql
7. Run generic_update.sql (from working directory)

 