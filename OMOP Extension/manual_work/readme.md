### Manual content processing:
1.Extract the following csv file into the concept_manual table: https://drive.google.com/file/d/1j5AlnUzvpNrCf9dMdol4gRq5QImGkegY/view?usp=sharing

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
ORDER BY vocabulary_id, concept_code, invalid_reason, valid_start_date, valid_end_date, concept_name`

2.Extract the following csv file into the concept_synonym_manual table: https://drive.google.com/file/d/1AdzCBO-hc_l2udDrM-I52pYZLlFbzR73/view?usp=sharing

`SELECT synonym_name,
       synonym_concept_code,
       synonym_vocabulary_id,
       language_concept_id
FROM concept_synonym_manual
ORDER BY synonym_vocabulary_id, synonym_concept_code, language_concept_id, synonym_name`

3.Extract the following csv file into the concept_relationship_manual table: https://drive.google.com/file/d/1gMqPAl2TimE-6T5Zf45TzYit1jHiV_Ju/view?usp=sharing

`SELECT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_relationship_manual
ORDER BY vocabulary_id_1, vocabulary_id_2, relationship_id, concept_code_1, concept_code_2, invalid_reason, valid_start_date, valid_end_date
;`


##### csv format:
- delimiter: ','
- encoding: 'UTF8'
- header: ON
- decimal symbol: '.'
- quote escape: with backslash \
- quote always: FALSE
- NULL string: empty