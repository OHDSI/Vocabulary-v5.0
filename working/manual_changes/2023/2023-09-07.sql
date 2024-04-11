UPDATE vocabulary v
SET v.vocabulary_name = REPLACE(v.vocabulary_name, 'Dundee', 'Nottingham')
WHERE v.vocabulary_id IN (
		'CO-CONNECT',
		'CO-CONNECT TWINS',
		'CO-CONNECT MIABIS'
		);

UPDATE concept c
SET concept_name = v.vocabulary_name
FROM vocabulary v
WHERE c.concept_id = v.vocabulary_concept_id
	AND v.vocabulary_id IN (
		'CO-CONNECT',
		'CO-CONNECT TWINS',
		'CO-CONNECT MIABIS'
		);