--HCPCS betos Domain update
UPDATE concept c
SET domain_id = b.domain_id
FROM dev_hcpcs.betos_domain b
WHERE b.betos = c.concept_code
	AND c.vocabulary_id = 'HCPCS'
	AND c.concept_class_id = 'HCPCS Class';
