### STEP 5 of the refresh:

5.1. Upload concept_manual table into the working schema (skip this step if implementing on the Pallas vocabulary server). 
Extract the [respective csv file] (https://drive.google.com/drive/u/0/folders/1TWGdyVy95AT-9GfK7KaKY2HQA4rDqxrH) into the concept_manual table. 
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

5.2 Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file] (https://drive.google.com/drive/u/0/folders/1TWGdyVy95AT-9GfK7KaKY2HQA4rDqxrH) into the concept_relationship_manual table.
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

5.2. Work with cpt4_refresh.sql:

5.2.1. Create cpt4_mapped table and pre-populate it with the resulting manual table of the previous CPT4 refresh.

5.2.2. Review the previous mapping and map new concepts. Use _cr_invalid_reason_ field to deprecate mappings.

5.2.3. Truncate the cpt4_mapped table. Save the spreadsheet as the cpt4_mapped table and upload it into the working schema.

5.2.4. Perform any mapping checks you have set.

5.2.5. Iteratively repeat steps 2.3-2.6 if found any issues.

5.2.6. Insert new and corrected mappings into the concept_relationship_manual table.

5.2.7. Create concept_mapped table and populate it with concepts that require manual changes.

5.2.8  Truncate concept_mapped table. Save the spreadsheet as 'concept_mapped table' and upload it to the schema.

5.2.9  Change concept_manual table according to concept_mapped table.