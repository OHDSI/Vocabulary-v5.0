Update of ICD10CM

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Schema UMLS
- Working directory ICD10CM.

1. Run create_source_tables.sql
2. Download ftp://ftp.cdc.gov/pub/Health_Statistics/NCHS/Publications/ICD10CM/2015/ICD10CM_FY2015_code_descriptions.zip
3. Extract icd10cm_order_2015.txt
4. Load them into icd10cm_table with icd10cm.ctl.
5. Run load_stage.sql
6. Run generic_update.sql (from working directory)

 