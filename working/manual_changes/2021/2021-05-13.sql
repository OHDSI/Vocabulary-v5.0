--two codes that need to be changed [AVOF-3140]
UPDATE concept
SET concept_code = 'cdc_covid_19_7_xx23_other'
WHERE vocabulary_id = 'PPI'
	AND concept_code = 'cdc covid_19_7_xx23_other';

UPDATE concept
SET concept_code = 'cdc_covid_19_7_xx23_other_cope_a_204'
WHERE vocabulary_id = 'PPI'
	AND concept_code = 'cdc covid_19_7_xx23_other_cope_a_204';
