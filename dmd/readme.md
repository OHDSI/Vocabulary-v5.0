Update of dm+d

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory dmd
- Updated and released versions of RxNorm, RxNorm Extension and SNOMED vocabularies

Update algorithm:

1. Run create_source_tables.sql
2. Download nhsbsa_dmd_X.X.X_xxxxxxxxxxxxxx.zip from https://isd.digital.nhs.uk/trud3/user/authenticated/group/0/pack/6/subpack/24/releases
3. Extract f_ampp2_xxxxxxx.xml, f_amp2_xxxxxxx.xml, f_vmpp2_xxxxxxx.xml, f_vmp2_xxxxxxx.xml, f_lookup2_xxxxxxx.xml, f_vtm2_xxxxxxx.xml and f_ingredient2_xxxxxxx.xml
4. Rename to f_ampp2.xml, f_amp2.xml, f_vmpp2.xml, f_vmp2.xml, f_lookup2.xml, f_vtm2.xml and f_ingredient2.xml
5. Download nhsbsa_dmdbonus_X.X.X_YYYYMMDDXXXXXX.zip from https://isd.digital.nhs.uk/trud3/user/authenticated/group/0/pack/6/subpack/25/releases
6. Extract weekXXYYYY-rX_X-BNF.zip/f_bnf1_XXXXXXX.xml and rename to dmdbonus.xml
7. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('DMD',TO_DATE('20210201','YYYYMMDD'),'dm+d Version 2.0.0 20210201');

8. Run additional_DDL.sql
9. Run load_stage.sql;
    - Update latest_update to current version
    - Commented portions include SELECTs needed to update manual tables
10. Run build_RxE.sql from ../working
11. Run postprocessing.sql
12. Run devv5.generic_update() function

R_TO_C_ALL contents which is sufficient for December 2020 1st week release is available under:
https://drive.google.com/drive/u/2/folders/1-_gcibtoQwhqnqAtf1bd02djLEicBr9w