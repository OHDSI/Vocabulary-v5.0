### Manual content processing:
- extract the following csv file into the concept_manual table: https://drive.google.com/file/d/1A37t5nrW13dvn3iy32Syi-eGChG6JBCh/view?usp=sharing

File is generated using the query:

`SELECT concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_manual
ORDER BY vocabulary_id, concept_code, valid_start_date, valid_end_date, concept_name`

##### csv format:
- delimiter: ','
- encoding: 'UTF8'
- header: ON
- decimal symbol: '.'
- quote escape: with backslash \
- quote always: FALSE
- NULL string: empty