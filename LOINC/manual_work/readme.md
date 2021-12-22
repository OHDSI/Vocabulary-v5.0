### STEP 18 of the refresh: upload manual tables
18.1 Extract the [respective csv file](https://drive.google.com/file/d/1sXdWNn1oN-EhsqFyT6cl2TI4YBXbDQyV/view?usp=sharing) into the concept_manual table.
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

18.2.Extract the [respective csv file](https://drive.google.com/file/d/1-R7_j_PNDrNIO1me_ni4-FNL2bs0iE1d/view?usp=sharing) into the concept_relationship_manual table.
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

### STEP 23 of the refresh (work with [loinc_refresh](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/LOINC/manual_work/loinc_refresh.sql) file):
23.1. Make backup of the concept_relationship_manual table.
23.2. Create loinc_source table.
23.3. Download loinc_source table and open it in spreadsheet viewer.
23.4. Download table with New and Covid concepts lacking hierarchy and place it in the same  spreadsheet viewer (these concepts need 'Is a' mapping).
23.5. Add concepts from 23.3 and 23.4 steps to the concept_relationship_manual table.
23.6. Perform manual review and mapping. Note, if you think that current mapping is better than suggested replacement, just make a new mapping of this row. If you want to deprecate current mapping without replacement, just delete row.
23.7. Save table as loinc_mapped and upload it into your schema (before make backup of this table) – Step 23.7.1 and 23.7.2 in the loinc_refresh file.
23.8. Run in the loinc_refresh file Step 23.8.1 and Step 23.8.2.

