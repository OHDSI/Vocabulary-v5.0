--HCPCS betos Domain update
UPDATE concept c
SET domain_id = a.domain_id
FROM (  SELECT DISTINCT concept_id, b.domain_id
        FROM dev_hcpcs.betos_domain b
        JOIN concept c
            ON c.vocabulary_id = 'HCPCS'
                AND c.concept_class_id = 'HCPCS Class'
                AND b.betos = c.concept_code) as a
WHERE c.concept_id = a.concept_id
;
