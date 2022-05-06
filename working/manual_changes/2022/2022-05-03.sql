--fix wrong date for NDC [AVOF-3394]
UPDATE concept c
SET valid_start_date = CURRENT_DATE
WHERE c.vocabulary_id = 'NDC'
	AND c.valid_start_date > CURRENT_DATE + INTERVAL '2 year';