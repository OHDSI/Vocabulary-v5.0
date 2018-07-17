Update of GGR

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

1. Run create_source_tables.sql and additional_DDL.sql
2. Download GGR file
- Open the site http://www.bcfi.be/nl/download
- Download latest zip archieve (CSV format, NL-version) e.g. http://www.bcfi.be/nl/download/file?type=EMD&name=/csv4Emd_Nl_1709A.zip
- Extract all *.csv except Ggr_Link.csv and Hyr.csv
3. Run in devv5: SELECT sources.load_input_tables('GGR',TO_DATE('20170901', 'yyyymmdd'),'GGR 20170901');
4. Run auto_init.sql.
Note: BN, Ingredients: lowercase 'n' in mapped_name suggests using concept_name instead. Lowercase 'g' in mapped_name indicates that concept should not be mapped. Brand Names with incorrect Suppliers must be deleted manually at this stage.
5. Give tables tomap_unit, tomap_form, tomap_supplier, tomap_bn, tomap_ingred to Medical Coder.
Reupload all tomap_* tables.
Note: manual tables in correct format for current version are present in subdirectory manual_work
6. Run after_mm.sql
Give table dsfix to Medical Coder.
Note: Place 'D' in Device field for products, that should be marked as Devices
Upload dsfix.csv and run fixes.sql
7. Run generic_update.sql (from working directory)