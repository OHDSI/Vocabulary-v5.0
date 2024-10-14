--This code is used to generate valid concept_code
SELECT 'OMOP'||max(replace(concept_code, 'OMOP','')::int4)+1 FROM devv5.concept WHERE concept_code LIKE 'OMOP%' AND concept_code NOT LIKE '% %';