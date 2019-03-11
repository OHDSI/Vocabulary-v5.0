Update of DPD

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working schema dev_dpd

1. Run create_source_tables.sql
2. Download the latest file from http://www.hc-sc.gc.ca/dhp-mps/prodpharma/databasdon/dpd_bdpp_data_extract-eng.php (file names: allfiles.zip,allfiles_ia.zip,allfiles_ap.zip)
3. Extract
 - drug.txt, drug_ia.txt, drug_ap.txt
 - ingred.txt, ingred_ia.txt, ingred_ap.txt
 - form.txt, form_ia.txt, form_ap.txt
 - route.txt, route_ia.txt, route_ap.txt
 - package.txt, package_ia.txt, package_ap.txt
 - status.txt, status_ia.txt, status_ap.txt
 - comp.txt, comp_ia.txt, comp_ap.txt
 - ther.txt, ther_ia.txt, ther_ap.txt
4. Run in devv5: SELECT sources.load_input_tables('DPD',TO_DATE('20170901', 'yyyymmdd'),'DPD 20170901');
5. Run load_stage.sql
6. Run Build_RxE.sql
7. Run generic_update: devv5.GenericUpdate();
8. Run drops.sql to remove all the temporary tables