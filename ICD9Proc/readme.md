Update of ICD9Proc

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- SNOMED must be loaded first
- Schema UMLS
- Working directory ICD9Proc.

1. Run create_source_tables.sql
2. Download from ICD-9-CM-vXX-master-descriptions.zip from http://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/codes.html
3. Extract CMSXX_DESC_LONG_SG.txt and CMSXX_DESC_SHORT_SG.txt
4. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('ICD9Proc',TO_DATE('20141001','YYYYMMDD'),'ICD9CM v32 master descriptions');
5. Run FULL FastRecreate:
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>true, include_deprecated_rels=>true, include_synonyms=>true);
```
7. Run [load_stage.sql] for the first time to define problems in mapping.
8. Perform manual work described in manual_work folder
9. Run [load_stage.sql] for the second time to refresh ICD10CM
10. Run generic_update: 
```sql
SELECT devv5.GenericUpdate();
```
11. Run [manual_checks_after_generic.sql]