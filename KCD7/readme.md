Update of KCD7

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory KCD7.
- ICD10, SNOMED must be loaded first.

1. Run create_source_tables.sql
2. Get the latest data file, load into sources.kcd7
3. Run FULL FastRecreate:
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>false, include_deprecated_rels=>true, include_synonyms=>true);
```
4. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10gm-documentation/ICD10GM/load_stage.sql) for the first time to define problems in mapping
5. Perform manual work described in manual_work folder
6. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10gm-documentation/ICD10GM/load_stage.sql) to refresh ICD10GM
7. Run generic_update: 
```sql
SELECT devv5.GenericUpdate();
```
8. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql)
9. If no problems, enjoy!