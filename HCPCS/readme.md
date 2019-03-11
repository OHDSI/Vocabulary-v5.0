Update of HCPCS

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Schema UMLS
- Updated RxNorm and RxNorm Extension (for ProcedureDrug.sql and MapDrugVocabulary.sql)
- Fresh concept_ancestor (for MapDrugVocabulary.sql)
- Working directory HCPCS.

1. Run create_source_tables.sql
2. Run ProcedureDrug.sql and MapDrugVocabulary.sql in your dev-schema for HCPCS e.g. dev_hcpcs (this will create two procedures)
3. Download the latest file http://www.cms.gov/Medicare/Coding/HCPCSReleaseCodeSets/Alpha-Numeric-HCPCS.html file name YYYY-Alpha-Numeric-HCPCS-File.zip
4. Exctract HCPCYYYY_CONTR_ANWEB.xlsx and rename to HCPC_CONTR_ANWEB.xlsx
5. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('HCPCS',TO_DATE('20171106','YYYYMMDD'),'2018 Alpha Numeric HCPCS File');
6. Run load_stage.sql
7. Run generic_update: devv5.GenericUpdate();