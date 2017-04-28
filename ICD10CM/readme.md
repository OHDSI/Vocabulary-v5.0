Update of ICD10CM

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Schema UMLS
- Working directory ICD10CM.

1. Run create_source_tables.sql
2. Download ICD10CM_FYYYYY_code_descriptions.zip or icd10cm_order_YYYY.txt from ftp://ftp.cdc.gov/pub/Health_Statistics/NCHS/Publications/ICD10CM/YYYY
3. Extract icd10cm_order_YYYY.txt (if needed) and rename to icd10cm.txt
4. Load into icd10cm_table with icd10cm.ctl
5. Run load_stage.sql (with updated pVocabularyDate = latest update of vocabulary, e.g. trunc(sysdate))
Note: Load_stage generates list of the relationships that need to be checked and modified by the medical coder and after uploading this data to server load_stage continues making proper relationships using this manually created table
6. Run generic_update.sql (from working directory)

 
