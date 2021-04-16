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

#### csv format:
- delimiter: ','
- encoding: 'UTF8'
- header: ON
- decimal symbol: '.'
- quote escape: with backslash \
- quote always: FALSE
- NULL string: empty
