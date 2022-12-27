### STEP 9 of the refresh:

9.1. Upload concept_manual table into the working schema (skip this step if implementing on the Pallas vocabulary server). 
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

9.2 Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server).
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

9.2. Work with cpt4_refresh.sql:

9.2.1 Create backup of concept_relationship_manual and concept_manual tables

9.2.2. Create cpt4_mapped table and pre-populate it with the resulting manual table of the previous CPT4 refresh.

9.2.3. Review the previous mapping and map new concepts. If previous mapping can be improved, just change mapping of the respective row. To deprecate a previous mapping without a replacement, just delete a row.

9.2.4. Select concepts to map and add them to the manual file in the spreadsheet editor.

9.2.5. Truncate the cpt4_mapped table. Save the spreadsheet as the cpt4_mapped table and upload it into the working schema.

9.2.6. Perform any mapping checks you have set.

9.2.7. Iteratively repeat steps 2.3-2.6 if found any issues.

9.2.8. Insert new and corrected mappings into the concept_relationship_manual table.

9.2.9. Deprecate all relationships, that need to be deprecated.