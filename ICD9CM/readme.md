Update of ICD9CM

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Schema UMLS
- Working directory ICD9CM.

1. Run create_source_tables.sql
2. Download from ICD-9-CM-vXX-master-descriptions.zip from http://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/codes.html
3. Extract CMSXX_DESC_LONG_DX.txt and CMSXX_DESC_SHORT_DX.txt
4. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('ICD9CM',TO_DATE('20141001','YYYYMMDD'),'ICD9CM v32 master descriptions');
5. Run load_stage.sql
6. Run generic_update.sql (from working directory)

 