Update of ICD10PCS

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory ICD10PCS.

1. Run create_source_tables.sql
2. Download the latest file from https://www.cms.gov/Medicare/Coding/ICD10/YYYY-ICD-10-PCS-and-GEMs.html (e.g. https://www.cms.gov/Medicare/Coding/ICD10/2019-ICD-10-PCS-and-GEMs.html), 
file name YYYY-ICD-10-PCS-Order-File.zip (e.g. 2019-ICD-10-PCS-Order-File.zip) listed as "ICD-10-PCS Order File (Long and Abbreviated Titles)"
3. Exctract icd10pcs_order_YYYY.txt and rename to icd10pcs.txt
4. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('ICD10PCS',TO_DATE('20180101','YYYYMMDD'),'ICD10PCS 20180101'); (pVocabularyDate=YYYY-1)
5. Run load_stage.sql
6. Run generic_update.sql (from working directory)