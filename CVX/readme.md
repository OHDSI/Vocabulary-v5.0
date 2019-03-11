Update of CVX

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- RxNorm must be loaded first

1. Run create_source_tables.sql
2. Download CVX code distrbution file
- Open the site http://www2a.cdc.gov/vaccines/IIS/IISStandards/vaccines.asp?rpt=cvx
- Download Excel file (https://www2a.cdc.gov/vaccines/IIS/IISStandards/downloads/web_cvx.xlsx)
3. Load Vaccines administered (CVX) Value Set Updates from https://phinvads.cdc.gov/vads/ValueSetRssFeed.xml?oid=2.16.840.1.114222.4.11.934. Download all versions (in Excel format), except 4.
4. Sequentially upload data to the database by executing in devv5: SELECT sources.load_input_tables('CVX', 'CVX Code Set '||TO_DATE('YYYYMMDD', 'yyyymmdd'));
where YYYYMMDD = date of 'Vaccines administered value set' taken from RSS feed
Example:
- put web_cvx.xlsx and ValueSetConceptDetailResultSummary.xls (version 1) into your upload folder
- run SELECT sources.load_input_tables('CVX','CVX Code Set '||TO_DATE('20081201', 'yyyymmdd'));
- leave the web_cvx.xlsx and replace ValueSetConceptDetailResultSummary.xls with ValueSetConceptDetailResultSummary.xls from version 2
- run SELECT sources.load_input_tables('CVX','CVX Code Set '||TO_DATE('20091015', 'yyyymmdd'));
- repeat untill last version
Note: be careful with dates, because we need a minimum date of each concept code of all the sets
5. Download "CPT Codes Mapped to CVX Codes" from https://www2a.cdc.gov/vaccines/iis/iisstandards/vaccines.asp?rpt=cpt
6. Download "Mapping CVX to Vaccine Groups" from https://www2a.cdc.gov/vaccines/iis/iisstandards/vaccines.asp?rpt=vg
7. Run load_stage.sql
8. Run generic_update: devv5.GenericUpdate();