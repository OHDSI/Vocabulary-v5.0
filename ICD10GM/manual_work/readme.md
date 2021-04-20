### STEP 6 of the refresh: work with manual staging tables

1.Extract the [respective csv file](https://drive.google.com/file/d/1ZjYCykojpUyxljZ4v1Qs3Yz72TiXWvKC/view?usp=sharing) into the concept_manual table. The file was generated using the query:
```sql
SELECT concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_manual
ORDER BY vocabulary_id, concept_code, invalid_reason, valid_start_date, valid_end_date, concept_name;
```
2. Some concepts can disappear from the source after ICD10GM update. Run this script and delete from concept_manual table "dead" concepts to prevent possible mistakes
```sql
DELETE FROM concept_manual
WHERE concept_code NOT IN (SELECT concept_code FROM sources.icd10gm);
```
3.Extract the [respective csv file](https://drive.google.com/file/d/1oPJtaUuhhU7uDSQ6y2QwwFwmps_rRm5x/view?usp=sharing) into the concept_relationship_manual table. The file was generated using the query:
```sql
SELECT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_relationship_manual
ORDER BY vocabulary_id_1, vocabulary_id_2, relationship_id, concept_code_1, concept_code_2, invalid_reason, valid_start_date, valid_end_date;
```
4.Extract the [respective csv file](https://drive.google.com/file/d/1R9C_1edHPNPB9YCDIut_E1P0-c1ZkwcT/view?usp=sharing) into the concept_synonym_manual table. The file was generated using the query:
```sql
SELECT synonym_name,
       synonym_concept_code,
       synonym_vocabulary_id,
       language_concept_id
FROM concept_synonym_manual
ORDER BY synonym_name, synonym_concept_code, synonym_vocabulary_id, language_concept_id;
```

### STEP 8 of the refresh: solving problems which are difened during the first load_stage run

1. Run [mapping_refresh.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10gm-documentation/ICD10GM/manual_work/mapping_refresh.sql). Table refresh_lookup will be created. It contains the list with mappings to outdated, deprecated or updated Standard concepts, as well as automaticaly improved mapping. 
2. Download this table and open it in Excel. Columns icd_ represent ICD10GM concepts with uncertain mapping, columns current_ refer to mapping which currently exists in concept_relationship_manual and columns repl_by_ suggest automatically created mapping, the reason for concepts appearing in this table you can see in column reason (e.g., 'improve_map','without mapping').
3. Perform manual review and mapping. Note, if you think that current mapping is better than suggested replacement, delete rows with these concepts from Excel table. Add column repl_by_relationship and put there necessary relationship_id following the recommendations described below. Then, delete current_ and reason columns.
4. Save table as refresh_lookup_done.csv and upload it into your schema using script [create_manual_table.sql](https://github.com/OHDSI/Vocabulary-v5.0/tree/icd10gm-documentation/ICD10GM/manual_work)
5. Run [manual_mapping_qa.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10gm-documentation/ICD10GM/manual_work/manual_mapping_qa.sql) to check whether refresh mapping meets the ICD10GM logic
6. If everything is OK, deprecate old mappings for the ICD10GM codes of interest and add fresh mappings to the concept_relationship_manual using [crm_changes.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10gm-documentation/ICD10GM/manual_work/crm_changes.sql) script

### Recomanditions for relationship_ids
  * **"Maps to"** is used for 1-to-1 FULL equivalent mapping only
  * **"Maps to" + "Maps to value"** is used for for Observations and Measurements with results
  * **"Is a"** is a temporary relationship used for this check only and applicable for 1-to-1 PARTIAL equivalent AND 1-to-many mappings.
Preserve a manual table with 'Is a' relationships, but change 'Is a' to 'Maps to' during the insertion into the concept_relatioship_manual (e.g. using CASE WHEN).

#### csv format:
- delimiter: ','
- encoding: 'UTF8'
- header: ON
- decimal symbol: '.'
- quote escape: with backslash \
- quote always: FALSE
- NULL string: empty
