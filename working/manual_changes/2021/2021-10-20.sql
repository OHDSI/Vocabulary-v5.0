--remove HGNC and MEDRT from the vocabulary table and deprecate in the concept [AVOF-3264, AVOF-3283]
DELETE
FROM vocabulary
WHERE vocabulary_concept_id IN (
		32537,
		32918
		);

UPDATE concept
SET valid_end_date = CURRENT_DATE,
	invalid_reason = 'D'
WHERE concept_id IN (
		32537,
		32918
		);

DELETE
FROM vocabulary_conversion
WHERE vocabulary_id_v5 IN (
		'HGNC',
		'MEDRT'
		);