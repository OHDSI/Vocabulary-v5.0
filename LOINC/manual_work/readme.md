### STEP 2 of the refresh: upload manual staging tables
1.Extract the [respective csv file](https://drive.google.com/file/d/1sXdWNn1oN-EhsqFyT6cl2TI4YBXbDQyV/view?usp=sharing) into the concept_manual table.
The file was generated using the query:
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
ORDER BY vocabulary_id, concept_code, invalid_reason, valid_start_date, valid_end_date, concept_name
```

2.Extract the [respective csv file](https://drive.google.com/file/d/1-R7_j_PNDrNIO1me_ni4-FNL2bs0iE1d/view?usp=sharing) into the concept_relationship_manual table.
The file was generated using the query:
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
ORDER BY vocabulary_id_1, vocabulary_id_2, relationship_id, concept_code_1, concept_code_2, invalid_reason, valid_start_date, valid_end_date
```
#### csv format:
- delimiter: ','
- encoding: 'UTF8'
- header: ON
- decimal symbol: '.'
- quote escape: with backslash \
- quote always: FALSE
- NULL string: empty

### STEP 7 of the refresh:
1. Make backup of the concept_relationship_manual table.
2. Run [loinc_refresh](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/LOINC/manual_work/loinc_refresh.sql) file. At the beginning create loinc_source table.
3. Download loinc_source table and open it in Excel.
4. Download table with actual mappings existing in CRM (!If you don't have it) and place it in the same Excel file.
5. Download table with New and Covid concepts lacking hierarchy and place it in the same Excel file (these concepts need 'Is a' mapping).
6. Perform manual review and mapping. Note, if you think that current mapping is better than suggested replacement, just make a new mapping of this row. If you want to deprecate current mapping without replacement, just delete row.
7. Save table as loinc_mapped and upload it into your schema.
8. Run in loinc_refresh file Step 2 and Step 3.

