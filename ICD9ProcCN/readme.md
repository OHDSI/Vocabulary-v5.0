Update of ICD9ProcCN

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory ICD9ProcCN.
- ICD9Proc must be loaded first

1. Go to https://github.com/ohdsi-china/Phase1Testing and download latest ICD9ProcCN version
2. Unzip CONCEPT.csv, CONCEPT_RELATIONSHIP.csv (password required) and rename to icd9proccn_concept.csv (we use modified version of this file) and icd9proccn_concept_relationship.csv
3. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('ICD9ProcCN',TO_DATE('20170101','YYYYMMDD'),'2017 Release');
4. Run FULL FastRecreate:
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>true, include_deprecated_rels=>true, include_synonyms=>true);
```
5. Run [load_stage.sql] for the first time to define problems in mapping.
6. Perform manual work described in manual_work folder
7. Run [load_stage.sql] for the second time to refresh ICD10CM
8. Run generic_update: 
```sql
SELECT devv5.GenericUpdate();
```
9. Run [manual_checks_after_generic.sql]