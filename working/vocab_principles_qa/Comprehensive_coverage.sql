-- Rule: every non-S concept should be mapped to Standard, or mapped to 0

-- Distribution of concepts by vocabulary and domains which are non-standard without valid mapping
SELECT
    cc.domain_id,
    cc.vocabulary_id,
    COUNT(*) AS concept_count
FROM
    devv5.concept AS cc
WHERE
    NOT EXISTS (
        SELECT 1
        FROM
            devv5.concept_relationship AS cr
        INNER JOIN
            devv5.concept AS c ON cr.concept_id_2 = c.concept_id
        WHERE
            cr.relationship_id = 'Maps to|Maps to value'
            AND cr.invalid_reason IS NULL
            AND cc.concept_id = cr.concept_id_1
            AND cc.concept_id != cr.concept_id_2
            AND cc.vocabulary_id != c.vocabulary_id
    )
    AND cc.standard_concept != 'S'
    AND cc.invalid_reason IS NULL
GROUP BY
    cc.vocabulary_id,
    cc.domain_id
ORDER BY
    cc.domain_id,
    cc.vocabulary_id,
    concept_count DESC;



-- Concepts in selected vocabulary and domain which are non-standard without valid mapping

SELECT *
FROM
    devv5.concept AS cc
WHERE
    NOT EXISTS (
        SELECT 1
        FROM
            devv5.concept_relationship AS cr
        INNER JOIN
            devv5.concept AS c ON cr.concept_id_2 = c.concept_id
        WHERE
            cr.relationship_id = 'Maps to|Maps to value'
            AND cr.invalid_reason IS NULL
            AND cc.concept_id = cr.concept_id_1
            AND cc.concept_id != cr.concept_id_2
            AND cc.vocabulary_id != c.vocabulary_id
    )
    AND cc.standard_concept != 'S'
    AND cc.invalid_reason IS NULL
    AND cc.domain_id IN ('::your_domain')
    AND cc.vocabulary_id IN ('::your_vocabulary')
ORDER BY
    cc.vocabulary_id,
    cc.domain_id;