### ICD10GM upload/update

#### Prerequisites
- Basic knowledge of the [OMOP representation of the ICD10 vocabulary](https://www.ohdsi.org/web/wiki/doku.php?id=documentation:vocabulary:icd10gm)
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- SNOMED and ICD10 must be loaded first
- Working directory dev_icd10gm
- Manual tables must be filled (e.g. for translations)
#### Sequence of actions
1. Download the latest ICD-10-GM version [here](https://www.bfarm.de/DE/Kodiersysteme/Services/Downloads/_node.html) 
2. Unzip the file \Klassifikationsdateien\icd10gmYYYYsyst_kodes.txt and rename to icd10gm.csv
3. Run [create_source_tables.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10gm-documentation/ICD10GM/create_source_tables.sql)
4. Run in devv5 (with fresh vocabulary date and version): 
```sql
SELECT sources.load_input_tables('ICD10GM',TO_DATE('20200101','YYYYMMDD'),'2020 Release');
```
5. Run FULL FastRecreate:
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>false, include_deprecated_rels=>true, include_synonyms=>true);
```
6. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10gm-documentation/ICD10GM/load_stage.sql) for the first time to define problems in mapping
7. Perform manual work described in manual_work folder
8. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10gm-documentation/ICD10GM/load_stage.sql) to refresh ICD10GM
9. Run generic_update: 
```sql
SELECT devv5.GenericUpdate();
```
10. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql)
11. If no problems, enjoy!
