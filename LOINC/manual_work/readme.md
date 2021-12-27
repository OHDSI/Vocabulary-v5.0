### STEP 25 of the refresh:
25.1. Upload concept_manual table. Extract the [respective csv file](https://drive.google.com/file/d/1sXdWNn1oN-EhsqFyT6cl2TI4YBXbDQyV/view?usp=sharing) into the concept_manual table.
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

25.2. Upload concept_relationship_manual table. Extract the [respective csv file](https://drive.google.com/file/d/1-R7_j_PNDrNIO1me_ni4-FNL2bs0iE1d/view?usp=sharing) into the concept_relationship_manual table.
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

25.3. Work with [loinc_refresh](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/LOINC/manual_work/loinc_refresh.sql) file:

25.3.1. Make backup of the concept_relationship_manual table and concept_manual table.
25.3.2. Create loinc_to_map table (source table for refresh).
25.3.3. Download loinc_to_map table and open it in spreadsheet viewer.
25.3.4. Download table with New and Covid concepts lacking hierarchy and place it in the same spreadsheet viewer (these concepts need 'Is a' mapping).
25.3.5. Add concepts from 23.3 and 23.4 steps to the table for manual mapping.
25.3.6. Perform manual review of previous mapping and map new concepts. Note, if you think that previous mapping can be improved, just make a new mapping of this row. If you want to deprecate previous mapping without replacement, just delete row.
25.3.7. Make backup of loinc_mapped table.
25.3.8. Save table as loinc_mapped and upload it into your schema.
25.3.9. Deprecate all mappings that differ from the new version.
25.3.10. Insert new mappings + corrected mappings.

