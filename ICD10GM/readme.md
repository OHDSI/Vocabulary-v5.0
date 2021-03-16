### ICD10 upload/update

#### Prerequisites
- Basic knowledge of the [OMOP representation of the ICD10 vocabulary](https://www.ohdsi.org/web/wiki/doku.php?id=documentation:vocabulary:icd10gm)
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- SNOMED and ICD10 must be loaded first
- Working directory dev_icd10gm
- Manual tables must be filled (e.g. for translations)
#### Sequence of actions
1. Download the latest ICD-10-GM version [here](https://www.dimdi.de/dynamic/de/klassifikationen/downloads/) 
2. Unzip the file \Klassifikationsdateien\icd10gmYYYYsyst_kodes.txt and rename to icd10gm.csv
3. Run [create_source_tables.sql] (https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10gm-documentation/ICD10GM/create_source_tables.sql)
4. Run in devv5 (with fresh vocabulary date and version): 
```sql
SELECT sources.load_input_tables('ICD10GM',TO_DATE('20200101','YYYYMMDD'),'2020 Release');
```
5. Run the FastRecreate:
```sql
SELECT devv5.FastRecreateSchema('dev_icd10'); 
```
6. As described in the "manual_work" folder, upload concept_manual.csv, concept_relationship_manual.csv and concept_synonym_manual.csv into eponymous tables, which exist by default in the dev schema after the FastRecreate. If you already have manual staging tables, obligatory create backups of them (e.g. concept_relationship_manual_backup_ddmmyy, concept_manual_backup_ddmmyy, concept_synonym_manual_ddmmyy)
7. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10gm-documentation/ICD10GM/load_stage.sql) for the first time to define problems in mapping
8. Run [mapping_refresh_qa.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10gm-documentation/ICD10GM/mapping_refresh_qa.sql) to obtain the list with mappings to outdated, deprecated or updated Standard concepts
9. Perform manual review and mapping
10. If everything is OK, deprecate old mappings for the ICD10 codes of interest in the concept_relationship_manual with valid_end_date = current_date and invalid_reason = 'D' 
11. Add fresh mappings to the concept_relationship_manual with valid_start_date = current_date and invalid_reason IS NULL. Note, that all changes in concept_relationship_manual table should be reflected in the folder "manual_work" (e.g. manual_work_MMYY.sql)
12. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10gm-documentation/ICD10GM/load_stage.sql) for the second time to refresh ICD10
13. Run generic_update: 
```sql
SELECT devv5.GenericUpdate();
```
14. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql)
15. If no problems, enjoy!
