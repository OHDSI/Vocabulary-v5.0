-- Rule: every non-S concept should be mapped to Standard, or mapped to 0

-- Distribution of concepts by vocabulary and domains which are non-standard without valid mapping
SELECT
    c.domain_id,
  --  c.vocabulary_id,
    COUNT(*) AS concept_count
FROM
    devv5.concept AS c
WHERE
    NOT EXISTS (
        SELECT 1
        FROM
            devv5.concept_relationship AS cr
        INNER JOIN
            devv5.concept AS cc
        ON cr.concept_id_2 = cc.concept_id
        WHERE
            cr.relationship_id LIKE 'Maps to%'
            AND cr.invalid_reason IS NULL
            AND c.concept_id = cr.concept_id_1
            AND c.concept_id != cr.concept_id_2
            AND c.vocabulary_id != cc.vocabulary_id
    )
    AND c.standard_concept IS NULL
    AND c.invalid_reason IS NULL
GROUP BY
  --  c.vocabulary_id,
    c.domain_id
ORDER BY
    c.domain_id,
    --c.vocabulary_id,
    concept_count DESC;



-- Concepts in selected vocabulary and domain which are non-standard without valid mapping

SELECT *
FROM
    devv5.concept AS c
WHERE
    NOT EXISTS (
        SELECT 1
        FROM
            devv5.concept_relationship AS cr
        INNER JOIN
            devv5.concept AS cc
        ON cr.concept_id_2 = cc.concept_id
        WHERE
            cr.relationship_id LIKE 'Maps to%'
            AND cr.invalid_reason IS NULL
            AND c.concept_id = cr.concept_id_1
            AND c.concept_id != cr.concept_id_2
            AND c.vocabulary_id != cc.vocabulary_id
    )
    AND c.standard_concept IS NULL
    AND c.invalid_reason IS NULL
    AND c.domain_id IN ('::your_domain')
    AND c.vocabulary_id IN ('::your_vocabulary');


