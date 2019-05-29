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
4. Upload legacy r_to_c_all (highly recommended, but not necessary)
5. Run auto_init.sql with updated Latest_update.
6. Manually fill table relationship_to_concept_to_map and re-upload as relationship_to_concept_manual
Note:
    BN, Ingredients: Fill new name without concept_id to change the name of the concept
    Entry in invalid_indicator indicates that RxE concept should not be created.
    manual_work/ directory contains examples of manual mappings made April 2019.
7. Run after_mm.sql
8. Run build_rxe.sql from working/ directory
9. Run postprocessing.sql
10. Run generic_update: devv5.GenericUpdate();