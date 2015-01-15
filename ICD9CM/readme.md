Update of ICD9CM

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Working directory ICD9CM.

1. Run create_source_tables.sql
2. Download from ICD-9-CM-vXX-master-descriptions.zip from http://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/codes.html
3. Extract CMSXX_DESC_LONG_DX.txt and CMSXX_DESC_SHORT_DX.txt
4. Load them into CMS_DESC_LONG_DX and CMS_DESC_SHORT_DX. Use the control files of the same name.
5. Download YYYYab-1-meta.nlm (for example 2014ab-1-meta.nlm) from http://www.nlm.nih.gov/research/umls/licensedcontent/umlsknowledgesources.html (already done for SNOMED).
Unpack MRCONSO.RRF.aa.gz and MRCONSO.RRF.ab.gz, then run
--gunzip *.gz
--cat MRCONSO.RRF.aa MRCONSO.RRF.ab > MRCONSO.RRF
and load MRCONSO.RRF into MRCONSO using MRCONSO.ctl in SNOMED folder

6. Run load_stage.sql
7. Run generic_update.sql (from root directory)

 