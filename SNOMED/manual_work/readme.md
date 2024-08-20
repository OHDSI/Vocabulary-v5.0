### Process of working with _manual tables
18.1. Upload concept_manual table into the working schema. Currently concept_manual table is empty.
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

18.2. Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file](https://drive.google.com/file/d/1iz9GwyqEbGHZ4xXVcZs-fyXJKU47ulrU/view?usp=sharing) into the concept_relationship_manual table.
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

18.3. Work with [snomed_refresh](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/SNOMED/manual_work/snomed_refresh.sql) file:

18.3.1. Create snomed_mapped table and pre-populate it with the resulting manual table of the previous SNOMED refresh.

18.3.2. Review the previous mapping and map new concepts. Use _cr_invalid_reason_ field to deprecate mappings.

18.3.3. Truncate the snomed_mapped table. Save the spreadsheet as the snomed_mapped table and upload it into the working schema.

18.3.4. Perform any mapping checks you have set.

18.3.5. Iteratively repeat steps 18.3.2-18.3.4 if found any issues.

18.3.6. Change concept_relationship_manual table according to snomed_mapped table.

18.3.7. Create concept_mapped table and populate it with concepts that require manual changes.

18.3.8 Truncate concept_mapped table. Save the spreadsheet as 'concept_mapped table' and upload it to the schema.

18.3.9 Change concept_manual table according to concept_mapped table.
