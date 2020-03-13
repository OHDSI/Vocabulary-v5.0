Update of ICD9ProcCN

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory ICD9ProcCN.
- ICD9Proc must be loaded first

1. Go to https://github.com/ohdsi-china/Phase1Testing and download latest ICD9ProcCN version
2. Unzip CONCEPT.csv, CONCEPT_RELATIONSHIP.csv (password required) and rename to icd9proccn_concept.csv (we use modified version of this file) and icd9proccn_concept_relationship.csv
3. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('ICD9ProcCN',TO_DATE('20170101','YYYYMMDD'),'2017 Release');
4. Run load_stage.sql
5. Run generic_update: devv5.GenericUpdate();