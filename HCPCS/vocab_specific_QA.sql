-- 1. Check if there are any known drug brand names missed in the mapping:

WITH a AS
(
  SELECT c.concept_id AS hcpcs_id,
         c.concept_name AS hcpcs_name,
         c.concept_code AS hcpcs_code,
         -- relevant Brand Name only from RxNorm
         cc.concept_name AS brand
  FROM devv5.concept c
    JOIN devv5.concept cc
      ON (UPPER (c.concept_name) LIKE '%(' ||upper (cc.concept_name) || ')%'
      OR UPPER (c.concept_name) LIKE '%, ' ||upper (cc.concept_name) || ',%')
  WHERE cc.vocabulary_id = 'RxNorm'
  AND   cc.concept_class_id = 'Brand Name'
  AND   cc.invalid_reason IS NULL
  AND   c.vocabulary_id = 'HCPCS'
  AND   c.domain_id = 'Drug'
)
SELECT a.*, c.*
FROM a
  JOIN devv5.concept_relationship cr
    ON cr.concept_id_1 = a.hcpcs_id
   AND cr.invalid_reason IS NULL
   AND cr.relationship_id = 'Maps to'
  JOIN devv5.concept c ON c.concept_id = cr.concept_id_2
WHERE concept_class_id NOT LIKE 'Brand%';