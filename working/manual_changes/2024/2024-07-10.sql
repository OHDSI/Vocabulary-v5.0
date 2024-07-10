--Change concepts attributes for some PPI concepts

UPDATE concept
   SET concept_class_id = 'Question'
WHERE concept_id = '596889'
AND concept_code = 'cdc_covid_xx_b';

UPDATE concept
   SET concept_name = 'Yes, within the last 12 months'
WHERE concept_id = '1704120'
AND concept_code = 'ehhwb_64';

UPDATE concept
   SET concept_name = 'Yes, but not in the last 12 months'
WHERE concept_id = '1704077'
AND concept_code = 'ehhwb_65';

UPDATE concept
   SET concept_name = 'Yes, and this has caused problems in work or social relationships'
WHERE concept_id = '1704125'
AND concept_code = 'ehhwb_39';

UPDATE concept
   SET concept_name = 'Yes, but has not caused problems in relationships'
WHERE concept_id = '1704122'
AND concept_code = 'ehhwb_40';

UPDATE concept
   SET concept_name = 'Marijuana 3 Month Use: Once Or Twice'
WHERE concept_id = '1585652'
AND concept_code = 'Marijuana3MonthUse_OneOrTwice';