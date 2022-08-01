STEP 6 of the refresh:

6.1. Upload concept_manual table into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file](https://drive.google.com/file/d/1sXdWNn1oN-EhsqFyT6cl2TI4YBXbDQyV/view?usp=sharing) into the concept_manual table.
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

6.2. Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file](https://drive.google.com/file/d/1-R7_j_PNDrNIO1me_ni4-FNL2bs0iE1d/view?usp=sharing) into the concept_relationship_manual table.
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


6.3. Work with read_refresh file:

6.3.1. Backup concept_relationship_manual table and concept_manual table.

6.3.2. Create read_mapped table and pre-populate it with the resulting manual table of the previous read refresh.

6.3.3. Select concepts to map (flag shows different reasons for mapping refresh) and add them to the manual file in the spreadsheet editor.

6.3.4. Review the previous mapping and map new concepts. If previous mapping can be improved, just change mapping of the respective row. To deprecate a previous mapping without a replacement, just delete a row.

6.3.5. Truncate the read_mapped table. Save the spreadsheet as the read_mapped table and upload it into the working schema.

6.3.6. Perform any mapping checks you have set.

6.3.7. Iteratively repeat steps 6.3.5-6.3.7 if found any issues.

6.3.8. Deprecate all mappings that differ from the new version of resulting mapping file.

6.3.9. Insert new and corrected mappings into the concept_relationship_manual table.