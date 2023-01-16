### Manual content processing:
1.Extract the following csv file into the concept_manual table:

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

2.Extract the following csv file into the concept_synonym_manual table:
https://docs.google.com/spreadsheets/d/17C887UjOZxPPJ0_H58AUU7mFuEq2wVD_EHQLpW2vth8/edit#gid=0
`SELECT synonym_name,
       synonym_concept_code,
       synonym_vocabulary_id,
       language_concept_id
FROM concept_synonym_manual
ORDER BY synonym_vocabulary_id, synonym_concept_code, language_concept_id, synonym_name`

3.Extract the following csv file into the concept_relationship_manual table: https://docs.google.com/spreadsheets/d/1THz5xZAkmdqUSAGct9z8Jh6f00_FSt49J89p55rRhDo/edit#gid=0
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
