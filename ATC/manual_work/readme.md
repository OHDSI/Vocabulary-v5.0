### STEP 1 of the ATC refresh/deployment: work with manual tables
* run *create_manual_tables.sql*
* extract the [respective csv files](https://drive.google.com/drive/folders/1TUfnmGCWj6d9KmJ5rZtGevQd0XsDgNQw?usp=sharing) into newly created tables. 
* extract the [respective csv file](https://drive.google.com/file/d/1z1SdeGG80NX_QkziS7Rs8mjnMncDIpwn/view?usp=sharing) into the *concept_manual* table. The file was generated using the query:
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
* extract the [respective csv file](https://drive.google.com/file/d/1RYLXRCUU4OLYk6XERZjlntYe3k1s3EjJ/view?usp=sharing) into the *concept_relationship_manual* table. The file was generated using the query:
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
* extract the [respective csv file](https://drive.google.com/file/d/1Cb_WdgGMuqUcBW4URFdsrWV1zR-s8JZg/view?usp=sharing) into the *concept_synonym_manual* table. The file was generated using the query:
```sql
SELECT synonym_name,
       synonym_concept_code,
       synonym_vocabulary_id,
       language_concept_id
FROM concept_synonym_manual
ORDER BY synonym_concept_code,
         synonym_name;
```
#### csv format:
- delimiter: ','
- encoding: 'UTF8'
- header: ON
- decimal symbol: '.'
- quote escape: with backslash \
- quote always: FALSE
- NULL string: empty
