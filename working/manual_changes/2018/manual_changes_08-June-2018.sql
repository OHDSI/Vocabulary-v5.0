--set 'Device' for some HCPCS concepts
UPDATE concept
SET domain_id = 'Device'
WHERE vocabulary_id = 'HCPCS'
	AND (
		concept_code IN (
			'C9247',
			'J7341'
			)
		OR concept_code BETWEEN 'J7343'
			AND 'J7350'
		);