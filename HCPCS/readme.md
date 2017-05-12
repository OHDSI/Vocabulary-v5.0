Update of HCPCS

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Schema UMLS
- Updated RxNorm and RxNorm Extension (for procedure_drug.sql and MapDrugVocabulary.sql)
- Fresh concept_ancestor (for MapDrugVocabulary.sql)
- Working directory HCPCS.

1. Run create_source_tables.sql
2. Download the latest file http://www.cms.gov/Medicare/Coding/HCPCSReleaseCodeSets/Alpha-Numeric-HCPCS.html, file name YYYY-Alpha-Numeric-HCPCS-File.zip
3. Exctract HCPCYYYY_CONTR_ANWEB.xlsx
4. Open file and resave to ANWEB_V2.csv
5. Load them into ANWEB_V2. Use the control files of the same name.
6. Run load_stage.sql (with updated pVocabularyDate = latest update of vocabulary)
7. Run generic_update.sql (from working directory)

 