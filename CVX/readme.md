Update of CVX

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 

1. Run create_source_tables.sql
2. Download CVX code distrbution file
- Open the site http://www2a.cdc.gov/vaccines/IIS/IISStandards/vaccines.asp?rpt=cvx
- Download Flat file http://www2a.cdc.gov/vaccines/IIS/IISStandards/downloads/cvx.txt and re-save in UTF-8 w/o BOM codepage
3. Load cvx.txt into CVX using control file of the same name
4. Load Vaccines administered (CVX) Value Set Updates from https://phinvads.cdc.gov/vads/ValueSetRssFeed.xml?oid=2.16.840.1.114222.4.11.934. Download all versions, except 4. Use cvx_vXXX control files.
5. Run load_stage.sql
6. Run generic_update.sql (from working directory)

 