Update of GGR

Prerequisites:
- Schema DevV5 with copies of tables concept, drug_strength, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Preferrable: r_to_c_all table with legacy attribute mappings, found in this directory.

1. Run create_source_tables.sql and additional_DDL.sql
2. Download GGR file
- Open the site http://www.bcfi.be/nl/download
- Download latest zip archieve (CSV format, NL-version) e.g. http://www.bcfi.be/nl/download/file?type=EMD&name=/csv4Emd_Nl_1709A.zip
- Extract all *.csv except Ggr_Link.csv and Hyr.csv
3. Run in devv5: SELECT sources.load_input_tables('GGR',TO_DATE('20190401', 'yyyymmdd'),'GGR 20190401');
4. Run auto_init.sql.
5. Manually fill tables:
-select * from tomap_unit;
-select * from tomap_form;
-select * from tomap_supplier;
-select * from tomap_ingred;
-select * from tomap_bn;
-select * from tofix_vax;
Note: BN, Ingredients: lowercase 'n' in mapped_name suggests using concept_name instead. Lowercase 'g' in mapped_name indicates that concept should not be mapped. Brand Names with incorrect Suppliers must be deleted manually at this stage.
6. Reupload all tomap_* tables.
-manual_work/ directory contains examples of manual mappings made April 2019.
7. Run after_mm.sql
8. Run build_rxe.sql from working/ directory
9. Run postprocessing.sql
10. Run generic_update: devv5.GenericUpdate();
11. Keep new version of r_to_c_all table for the future use