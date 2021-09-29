--01 check names correctness/consistency
SELECT s.concept_code, c.concept_name as old_name, s.concept_name as new_name, devv5.similarity (c.concept_name, s.concept_name)
FROM sources.sopt_source s
JOIN concept c ON c.concept_code = s.concept_code
	AND c.vocabulary_id = 'SOPT'
WHERE devv5.similarity (c.concept_name, s.concept_name) != 1
;
