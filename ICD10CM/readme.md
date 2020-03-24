Update of ICD10CM

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Schema UMLS
- SNOMED must be loaded first
- Working directory ICD10CM.

1. Run create_source_tables.sql
2. Download ICD10CM_FYYYYY_code_descriptions.zip or icd10cm_order_YYYY.txt from ftp://ftp.cdc.gov/pub/Health_Statistics/NCHS/Publications/ICD10CM/YYYY
3. Extract icd10cm_order_YYYY.txt (if needed) and rename to icd10cm.txt
4. Run in devv5 (with fresh vocabulary date and version, e.g. according "The 2018 ICD-10-CM codes are to be used from October 1, 2017 through September 30, 2018" so 20171001): 
SELECT sources.load_input_tables('ICD10CM',TO_DATE('20170428','YYYYMMDD'),'ICD10CM FY2017 code descriptions');
5. Run load_stage.sql
Note: Load_stage generates list of the relationships that need to be checked and modified by the medical coder and after uploading this data to server load_stage continues making proper relationships using this manually created table
6. Run generic_update: devv5.GenericUpdate();