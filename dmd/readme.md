Update of dm+d

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory dmd
- Updated and released versions of RxNorm, RxNorm Extension and SNOMED vocabularies

Update algorithm:
1. Run additional_DDL.sql
2. Run load_stage.sql;
    - Update latest_update to current version
    - Commented portions include SELECTs needed to update manual tables
3. Run build_RxE.sql from ../working
4. Run postprocessing.sql
5. Run devv5.generic_update() function

R_TO_C_ALL contents which is sufficient for December 2020 1st week release is available under:
https://drive.google.com/drive/u/2/folders/1-_gcibtoQwhqnqAtf1bd02djLEicBr9w