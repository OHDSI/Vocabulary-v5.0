### STEP 7 of the refresh:

7.1. Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server).
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

7.2. Work with the [meddra_refresh](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/MedDRA/Manual_work/meddra_refresh.sql) file:

7.2.1. Create combined tables with mapping candidates from different sources.

7.2.2. Create meddra_environment table.

7.2.3. Upload meddra_environment table for manual review.

7.2.4. Truncate meddra_environment table.

7.2.5. Save the spreadsheet as the 'meddra_environment_table' and upload it into the working schema.

7.2.6. Change concept_relationship_manual table according to meddra_environment table.

7.2.7. Create MedDRA-SNOMED hierarchical relationships.

7.2.8. Deprecate previously assigned hierarchical relationships for measurements

7.2.9. Deprecate previously assigned hierarchical relationships for concepts who changed mappings