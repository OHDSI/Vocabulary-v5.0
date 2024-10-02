### CIM10 upload/update

#### Prerequisites
- Basic knowledge of the [OMOP representation of the ICD10 vocabulary](https://www.ohdsi.org/web/wiki/doku.php?id=documentation:vocabulary:icd10gm)
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- SNOMED and ICD10 must be loaded first
- Working directory dev_icd10gm
- Manual tables must be filled (e.g. for translations)
- 
#### Sequence of actions
1. Download the latest CIM10 version
2. Run create_source_tables.sql
3. Run in devv5 (with fresh vocabulary date and version): 
```sql
SELECT sources.load_input_tables('ICD10GM',TO_DATE('20200101','YYYYMMDD'),'2020 Release');
```
4. Run FULL FastRecreate:
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>false, include_deprecated_rels=>true, include_synonyms=>true);
```
5. Run load_stage for the first time to define problems in mapping
6. Perform manual work described in manual_work folder
7. Run load_stage
8. Run generic_update: 
```sql
SELECT devv5.GenericUpdate();
```
10. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql)
11. If no problems, enjoy!