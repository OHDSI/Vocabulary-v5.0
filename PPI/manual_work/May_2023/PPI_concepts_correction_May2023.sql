-- Update 3 concepts and set different concept_class_id for 2 concepts

UPDATE dev_ppi.concept_relationship
SET valid_end_date = '2023-05-10', invalid_reason='D'
WHERE concept_id_1=40192497 AND concept_id_2=40770200;

INSERT INTO concept_manual
VALUES ('How often are you treated with less courtesy than other people when you go to a doctor''s office or other health care provider?', 'Observation', 'PPI', 'Question', 'S', 'sdoh_dms_1', '2021-11-03', '2099-12-31', null);

UPDATE dev_ppi.concept_relationship
SET valid_end_date = '2023-05-10', invalid_reason='D'
WHERE concept_id_1=40192425 AND concept_id_2=40770201;

INSERT INTO concept_manual
VALUES ('How often are you treated with less respect than other people when you go to a doctor''s office or other health care provider?', 'Observation', 'PPI', 'Question', 'S', 'sdoh_dms_2', '2021-11-03', '2099-12-31', null);

UPDATE dev_ppi.concept_relationship
SET valid_end_date = '2023-05-10', invalid_reason='D'
WHERE concept_id_1=1585849 AND concept_id_2=4124462;

INSERT INTO concept_manual
VALUES ('Sex At Birth: Sex At Birth None Of These', 'Observation', 'PPI', 'Answer', 'S', 'SexAtBirth_SexAtBirthNoneOfThese', '2017-05-26', '2099-12-31', null);


UPDATE dev_ppi.concept
SET concept_class_id='Answer'
WHERE concept_id=1585872;

UPDATE dev_ppi.concept
SET concept_class_id='Answer'
WHERE concept_id=1586164;


