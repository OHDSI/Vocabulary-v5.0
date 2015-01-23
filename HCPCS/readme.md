Update of HCPCS

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Schema UMLS
- Working directory HCPCS.

1. Run create_source_tables.sql
2. Download the latest file http://www.cms.gov/Medicare/Coding/HCPCSReleaseCodeSets/Alpha-Numeric-HCPCS.html, file name YYYY-Annual-Alpha-Numeric-HCPCS-File.zip
3. Exctract HCPCYYYY_CONTR_ANWEB_v2.txt
4. Load them into ANWEB_V2. Use the control files of the same name.
5. Run load_stage.sql
6. Run generic_update.sql (from root directory)

 