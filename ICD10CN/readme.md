Update of ICD10CN

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- ICD10 must be loaded first
- Working directory ICD10CN.

1. Go to https://github.com/ohdsi-china/Phase1Testing and download latest ICD10CN version
2. Unzip CONCEPT.csv, CONCEPT_RELATIONSHIP.csv (password required) and rename to icd10cn_concept.csv (we use modified version of this file) and icd10cn_concept_relationship.csv
3. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('ICD10CN',TO_DATE('20160101','YYYYMMDD'),'2016 Release');
4. Run load_stage.sql
5. Run generic_update: devv5.GenericUpdate();