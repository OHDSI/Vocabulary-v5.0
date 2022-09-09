STEP 7 of the Refresh
7.1. Upload concept_manual table into the working schema (skip this step if implementing on the Pallas vocabulary server).
    Extract the [respective csv file](https://drive.google.com/drive/u/0/folders/1P2dJ9PDMDuu03K-EqzAR8QgmLj72kEB0) into the concept_manual table. The file was generated using the query:

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

7.2 Upload concept_relationship_manual into the working schema (skip this step if implementing on the Pallas vocabulary server).
    Extract the [respective csv file](https://drive.google.com/drive/u/1/folders/1P2dJ9PDMDuu03K-EqzAR8QgmLj72kEB0) into the concept_relationship_manual table. The file was generated using the query:

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
7.3. Work with the [ops_refresh] file