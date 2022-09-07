Update of HCPCS

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Schema UMLS
- SNOMED must be loaded first
- Updated RxNorm and RxNorm Extension (for ProcedureDrug.sql and MapDrugVocabulary.sql)
- Fresh concept_ancestor (for MapDrugVocabulary.sql)
- Working directory HCPCS.

1. Run create_source_tables.sql
2. Run ProcedureDrug.sql and MapDrugVocabulary.sql in your dev-schema for HCPCS e.g. dev_hcpcs (this will create two procedures)
3. Download the latest file https://www.cms.gov/Medicare/Coding/HCPCSReleaseCodeSets/HCPCS-Quarterly-Update file name Mon-YYYY-Alpha-Numeric-HCPCS-File.zip
4. Extract HCPCYYYY_CONTR_ANWEB.xlsx and rename to HCPC_CONTR_ANWEB.xlsx
5. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('HCPCS',TO_DATE('20171106','YYYYMMDD'),'2018 Alpha Numeric HCPCS File');
_-- If you already have the source tables uploaded in the vocab schema then start with step 6_
6. Run fast_recreate_schema.sql 
7. Run load_stage.sql 
8. Run generic_update: devv5.GenericUpdate(); 
9. Perform the manual work 
10. Repeat steps 6-8 
11. Perform vocab specific QA and general checks found here: [https://github.com/Alexdavv/IntermediateWork/blob/master/vocabularies%20QA%20and%20run.sql]()

CSV sources for CONCEPT_MANUAL and CONCEPT_RELATIONSHIP_MANUAL are available here:
https://drive.google.com/drive/u/2/folders/1mvXzaXW9294RaDC2DgnM1qBi1agCwxHJ