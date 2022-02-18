### STEP 6 of the refresh:

6.1. Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server).
Extract the [respective csv file] (https://drive.google.com/drive/u/0/folders/10Gg84mN7tc8d2ByQ9XHNe23rY-w9XBMk) into the concept_relationship_manual table.
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

6.2. Work with [meddra_refresh](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/meddra/manual_work/meddra_refresh.sql) file:

6.2.1. Backup concept_relationship_manual table and concept_manual table.

6.2.2. Create meddra_mapped table and pre-populate it with the resulting manual table of the previous MedDRA refresh.

6.2.3. Review the previous mapping and map new concepts. If previous mapping can be improved, just change mapping of the respective row. To deprecate a previous mapping without a replacement, just delete a row.

6.2.4. Select concepts to map and add them to the manual file in the spreadsheet editor.

6.2.5. Truncate the meddra_mapped table. Save the spreadsheet as the meddra_mapped table and upload it into the working schema.

6.2.6. Perform any mapping checks you have set.

6.2.7. Iteratively repeat steps 2.3-2.6 if found any issues.

6.2.8. Deprecate all mappings that differ from the new version of resulting mapping file.

6.2.9. Insert new and corrected mappings into the concept_relationship_manual table.