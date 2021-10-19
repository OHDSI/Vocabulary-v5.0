--CAP
SELECT *
FROM dev_mnerovnya.cap_to_cm;
--NAACCR
SELECT *
FROM dev_mnerovnya.naaccr_to_cm



-- Topography of distance to margin
SELECT DISTINCT SUBSTR(concept_name, instr(LOWER(concept_name), ' to ') + 4) AS b
FROM devv5.concept
WHERE vocabulary_id = 'Cancer Modifier'
  AND LOWER(concept_name) LIKE '%istance%to%margin%'
UNION
DISTINCT
SELECT DISTINCT SUBSTR(concept_name, instr(LOWER(concept_name), ' from ') + 6) AS b
FROM devv5.concept
WHERE vocabulary_id = 'Cancer Modifier'
  AND LOWER(concept_name) LIKE '%istance%from%margin%'
ORDER BY 1
LIMIT 1000;

-- Histologies within margins
SELECT DISTINCT SUBSTR(concept_name, instr(concept_name, ' by ') + 4)
FROM concept
WHERE vocabulary_id = 'Cancer Modifier'
  AND LOWER(concept_name) LIKE '% by %'
ORDER BY 1
LIMIT 1000;

SELECT *
FROM devv5.concept
WHERE vocabulary_id = 'NAACCR'
  AND LOWER(concept_name) ILIKE '%size%'
  AND concept_class_id = 'NAACCR Variable'
  AND concept_name NOT IN (SELECT vr_name FROM naaccr_to_cm);
