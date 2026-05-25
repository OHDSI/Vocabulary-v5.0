### Process of working with _manual tables

1. Upload concept_manual table into the working schema. Currently concept_manual table is empty.
The possible content is generated using the query:
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

2. Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file](https://drive.google.com/file/d/1MDsyRvu0cE4tX7pdApRRJ8A7TRNiN--n/view?usp=sharing) into the concept_relationship_manual table.
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


3. Work with dmd_refresh file:

3.1. Backup concept_relationship_manual table and concept_manual table.

3.2. Create dmd_mapped table and pre-populate it with the resulting manual table of the previous dmd refresh.

3.3. Review the previous mapping and map new concepts. If previous mapping can be improved, just change mapping of the respective row. To deprecate a previous mapping without a replacement, just delete a row.

3.4. Truncate the dmd_mapped table. Save the spreadsheet as the dmd_mapped table and upload it into the working schema.

3.5. Perform any mapping checks you have set.

3.6. Iteratively repeat steps 3.3-3.5 if found any issues.

3.7. Deprecate all mappings that differ from the new version of resulting mapping file.

3.8. Insert new and corrected mappings into the concept_relationship_manual table.