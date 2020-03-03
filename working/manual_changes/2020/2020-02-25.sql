--update LOINC Parts start date (run only once after generic_update)
UPDATE concept
SET valid_start_date = TO_DATE('19700101', 'yyyymmdd')
WHERE vocabulary_id = 'LOINC'
	AND concept_class_id IN (
		'LOINC Component',
		'LOINC Method',
		'LOINC Property',
		'LOINC Scale',
		'LOINC System',
		'LOINC Time'
		)
	AND valid_start_date = TO_DATE('20191213', 'yyyymmdd');
