### STEP 5 of the refresh: work with manual staging tables
1.Extract the [respective csv file](https://drive.google.com/file/d/14X9LbiG7dqbfh_XK2jKV_yprO4-Y2feM/view?usp=sharing) into the concept_manual table. The file was generated using the query:
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
2.Extract the [respective csv file](https://drive.google.com/file/d/1BdfX6R7LF4YLadOIkBVUWzm2HH09vjI2/view?usp=sharing) into the concept_relationship_manual table. The file was generated using the query:
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
#### csv format:
- delimiter: ','
- encoding: 'UTF8'
- header: ON
- decimal symbol: '.'
- quote escape: with backslash \
- quote always: FALSE
- NULL string: empty

### STEP 7 of the refresh: solving problems which are difened during the first load_stage run
1. Run [mapping_refresh.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10-documentation/ICD10/manual_work/mapping_refresh.sql). Table refresh_lookup will be created. It contains the list with mappings to outdated, deprecated or updated Standard concepts, as well as automaticaly improved mapping. 
2. Download this table and open it in Excel. Columns icd_ represent ICD10 concepts with uncertain mapping, columns current_ refer to mapping which currently exists in concept_relationship_stage and columns repl_by_ suggest automatically created mapping, the reason for concepts appearing in this table you can see in column reason (e.g., 'improve_map','without mapping').
3. Perform manual review and mapping. Note, if you think that current mapping is better than suggested replacement, delete rows with these concepts from Excel table. Add column repl_by_relationship and put there necessary relationship_id following the recommendations described below. Then, delete current_ and reason columns.
4. Save table as refresh_lookup_done.csv and upload it into your schema using script [create_manual_table.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10-documentation/ICD10/manual_work/create_manual_table.sql)
5. Run [manual_mapping_qa.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10-documentation/ICD10/manual_work/manual_mapping_qa.sql) to check whether refresh mapping meets the ICD10 logic
6. If everything is OK, deprecate old mappings for the ICD10 codes of interest and add fresh mappings to the concept_relationship_manual using [crm_changes.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/icd10-documentation/ICD10/manual_work/crm_changes.sql) script

### Recomanditions for relationship_ids
  * **"Maps to"** is used for 1-to-1 FULL equivalent mapping only
  * **"Maps to" + "Maps to value"** is used for for Observations and Measurements with results
  * **"Is a"** is a temporary relationship used for this check only and applicable for 1-to-1 PARTIAL equivalent AND 1-to-many mappings.
Preserve a manual table with 'Is a' relationships, but change 'Is a' to 'Maps to' during the insertion into the concept_relatioship_manual (e.g. using CASE WHEN).

#### Required fields in a manual table
- icd_id INT, 
- icd_code VARHCAR, 
- icd_name VARHCAR, 
- relationship_id VARCHAR, 
- concept_id INT, 
- concept_code VARCHAR, 
- concept_name VARCHAR
