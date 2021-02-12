### Manual content processing:
1.Extract the following csv file into the concept_manual table: https://docs.google.com/spreadsheets/d/1LuBHQ7eA4LxH5bIuHVZB0eRKP_VCX9fr1eYixPuaC7I/edit#gid=0

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

2.Extract the following csv file into the concept_synonym_manual table: https://docs.google.com/spreadsheets/d/1MWjA5i9aaFNxMmyzJzlxvjoNfXzCXNvrCsh06bJbaIg/edit#gid=0

`SELECT synonym_name,
       synonym_concept_code,
       synonym_vocabulary_id,
       language_concept_id
FROM concept_synonym_manual
ORDER BY synonym_vocabulary_id, synonym_concept_code, language_concept_id, synonym_name`

3.Extract the following csv file into the concept_relationship_manual table: https://docs.google.com/spreadsheets/d/1lcAxPfHS4MMw8LdTBeHEOnC4ELG4h22_f244I2GRzq8/edit#gid=331698122

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