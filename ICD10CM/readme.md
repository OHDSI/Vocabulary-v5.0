### ICD10CM upload / update ###

#### Prerequisites: #### 
* Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
* Schema UMLS
* SNOMED must be loaded first
* Working directory, e.g. dev_icd10cm

#### Sequence of actions ####
* Run create_source_tables.sql
* Download ICD10CM_FYYYYY_code_descriptions.zip or icd10cm_order_YYYY.txt from ftp://ftp.cdc.gov/pub/Health_Statistics/NCHS/Publications/ICD10CM/YYYY
* Extract icd10cm_order_YYYY.txt (if needed) and rename to icd10cm.txt
* Perform actions described in the folder of 'manual_work'
* Run in devv5 (with fresh vocabulary date and version, e.g. according "The 2018 ICD-10-CM codes are to be used from October 1, 2017 through September 30, 2018" so 20171001): 
```sql
SELECT sources.load_input_tables('ICD10CM',TO_DATE('20170428','YYYYMMDD'),'ICD10CM FY2017 code descriptions');
```
* Run load_stage.sql. Note: Load_stage generates list of the relationships that need to be checked and modified by the medical coder and after uploading this data to server load_stage continues making proper relationships using this manually created table
* Run generic_update: devv5.GenericUpdate();
