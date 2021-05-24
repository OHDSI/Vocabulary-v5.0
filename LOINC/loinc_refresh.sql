with previous_mappings AS
    (SELECT concept_id_1, array_agg(concept_id_2 ORDER BY concept_id_2 DESC) AS old_maps_to
        FROM devv5.concept_relationship cr
        JOIN devv5.concept c
        ON cr.concept_id_1 = c.concept_id
        AND c.vocabulary_id = 'LOINC'
        --Previous mapping, available in devv5
        AND cr.relationship_id IN ('Maps to', 'Maps to value')
        AND cr.invalid_reason IS NULL

        GROUP BY concept_id_1
        ),
     current_mapping AS
         (
        SELECT concept_id_1, array_agg(concept_id_2 ORDER BY concept_id_2 DESC) AS new_maps_to
        FROM dev_loinc.concept_relationship cr
        JOIN dev_loinc.concept c
        ON cr.concept_id_1 = c.concept_id
        AND c.vocabulary_id = 'LOINC'
        --Previous mapping, available in devv5
        AND cr.relationship_id IN ('Maps to', 'Maps to value')
        AND cr.invalid_reason IS NULL

        GROUP BY concept_id_1
         )

SELECT DISTINCT c.*, CASE WHEN previous_mappings.concept_id_1 IS NOT NULL    --Mapping was available
                          AND NOT EXISTS (SELECT concept_id_1 FROM dev_loinc.concept_relationship lcr
                          JOIN dev_loinc.concept lc
                          ON lc.concept_id = lcr.concept_id_1 AND lc.vocabulary_id = 'LOINC'
                          WHERE lcr.relationship_id IN ('Maps to', 'Maps to value') AND lcr.invalid_reason IS NULL
                                AND lcr.concept_id_1 = c.concept_id --Concept_id never changes
                              ) THEN 'Used to be mapped and dont have replacement'

    --TODO: There are 2 concepts but LOINC hasn't been ran after snomed refresh so the mappings just died
                WHEN previous_mappings.concept_id_1 IN
                    (SELECT cc.concept_id FROM dev_loinc.concept_relationship_manual crm
                    JOIN devv5.concept c
                    ON crm.concept_code_2 = c.concept_code AND crm.vocabulary_id_2 = c.vocabulary_id
                    JOIN devv5.concept cc
                    ON cc.concept_code = crm.concept_code_1 AND cc.vocabulary_id = 'LOINC'
                    WHERE c.standard_concept IS NULL) THEN 'Mapping changed according to changes in other vocabs'

                --mapping changed
                WHEN previous_mappings.old_maps_to != current_mapping.new_maps_to THEN 'Mapping changed'

                WHEN c.concept_code NOT IN (SELECT concept_code FROM devv5.concept WHERE vocabulary_id = 'LOINC')
                                THEN 'New and not-mapped'
                                ELSE 'Just not mapped' END AS flag
FROM dev_loinc.concept c
LEFT JOIN previous_mappings
ON c.concept_id = previous_mappings.concept_id_1
LEFT JOIN current_mapping
ON c.concept_id = current_mapping.concept_id_1
    --new concept_relationship
LEFT JOIN dev_loinc.concept_relationship cr
ON c.concept_id = cr.concept_id_1
AND cr.relationship_id IN ('Maps to', 'Maps to value')
AND cr.invalid_reason IS NULL
/*
 WHERE c.concept_id / concept_code NOT IN (SELECT FROM _mapped table)
 */
WHERE cr.concept_id_2 IS NULL
AND (c.standard_concept IS NULL OR c.invalid_reason = 'D') AND c.vocabulary_id = 'LOINC'
AND c.concept_class_id NOT IN ('LOINC Hierarchy', 'LOINC Component', 'LOINC Method', 'LOINC System', 'LOINC Property', 'LOINC Time', 'LOINC Scale')
AND c.invalid_reason != 'U'
;




--Non-standard without mapping at the moment
SELECT DISTINCT * FROM devv5.concept c
WHERE c.vocabulary_id = 'LOINC'
--AND c.domain_id NOT IN ('Meas Value')
--AND c.concept_class_id IN ('Lab Test')
AND c.concept_class_id NOT IN ('LOINC Hierarchy', 'LOINC Component', 'LOINC Method', 'LOINC System', 'LOINC Property', 'LOINC Time', 'LOINC Scale')
AND c.standard_concept IS NULL
AND NOT EXISTS (SELECT concept_id_1 FROM devv5.concept_relationship cr
                WHERE relationship_id IN ('Maps to', 'Maps to value', 'Concept replaced by')
                AND cr.invalid_reason IS NULL
                AND concept_id_1 = c.concept_id
    )
ORDER BY domain_id, concept_code
;

--Replaced concepts from the LOINC vocabulary
SELECT * FROM devv5.concept_relationship cr
JOIN devv5.concept c
ON cr.concept_id_1 = c.concept_id
WHERE relationship_id = 'Concept replaced by'
AND c.vocabulary_id = 'LOINC'
;


--One time executed code to run and take concepts from concept_relationship_manual
--TODO: There are a lot of non-deprecated relationships to non-standard (in dev_loinc) concepts
SELECT c.concept_code, c.concept_name,
       crm.relationship_id,
       cc.*
FROM dev_loinc.concept_relationship_manual crm
JOIN dev_loinc.concept c
ON c.concept_code = crm.concept_code_1 AND c.vocabulary_id = 'LOINC'
JOIN dev_loinc.concept cc
ON cc.concept_code = crm.concept_code_2
WHERE crm.invalid_reason IS NULL
ORDER BY c.concept_code
;
