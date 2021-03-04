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
2.Extract [the respective csv file](https://drive.google.com/file/d/1BdfX6R7LF4YLadOIkBVUWzm2HH09vjI2/view?usp=sharing) into the concept_relationship_manual table. The file was generated using the query:
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

### STEP 9 of the refresh: a manual mapping check for mechanical and semantic errors
1. This script should be run BEFORE insert of refeshed or newly added mappings into concept_relationship_manual. 
2. During mapping of ICD codes we recommend to use the following relationship_ids:
  * **"Maps to"** is used for 1-to-1 FULL equivalent mapping only
  * **"Maps to" + "Maps to value"** is used for for Observations and Measurements with results
  * **"Is a"** is a temporary relationship used for this check only and applicable for 1-to-1 PARTIAL equivalent AND 1-to-many mappings.
3. Preserve a manual table with 'Is a' relationships, but change 'Is a' to 'Maps to' during the insertion into the concept_relatioship_manual (e.g. using CASE WHEN).

#### Required fields in a manual table
- icd_id INT, 
- icd_code VARHCAR, 
- icd_name VARHCAR, 
- relationship_id VARCHAR, 
- concept_id INT, 
- concept_code VARCHAR, 
- concept_name VARCHAR
