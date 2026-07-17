--Change concepts attributes for some PPI concepts
UPDATE concept_manual
   SET concept_name = 'Yes, within the last 12 months'
WHERE concept_code = 'ehhwb_64' AND vocabulary_id = 'PPI';

UPDATE concept_manual
   SET concept_name = 'Yes, but not in the last 12 months'
WHERE concept_code = 'ehhwb_65' AND vocabulary_id = 'PPI';

UPDATE concept_manual
   SET concept_name = 'Yes, and this has caused problems in work or social relationships'
WHERE concept_code = 'ehhwb_39' AND vocabulary_id = 'PPI';

UPDATE concept_manual
   SET concept_name = 'Yes, but has not caused problems in relationships'
WHERE concept_code = 'ehhwb_40' AND vocabulary_id = 'PPI';

--Insert concepts, present in basic tables, but absent in _manual tables
INSERT INTO concept_manual VALUES
('Please specify:', 'Observation', 'PPI', 'Question', 'S', 'cdc_covid_xx_b_other', '2021-04-01', '2099-12-31', null);

INSERT INTO concept_manual VALUES
('Marijuana 3 Month Use: Once Or Twice', 'Observation', 'PPI', 'Answer', 'S', 'Marijuana3MonthUse_OneOrTwice', '2017-04-24', '2099-12-31', null);
