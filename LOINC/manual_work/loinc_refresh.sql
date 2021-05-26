with previous_mappings AS
    (SELECT concept_id_1, c.standard_concept, array_agg(concept_id_2 ORDER BY concept_id_2 DESC) AS old_maps_to
        FROM devv5.concept_relationship cr
        JOIN devv5.concept c
        ON cr.concept_id_1 = c.concept_id
        AND c.vocabulary_id = 'LOINC'
        --Previous mapping, available in devv5
        AND cr.relationship_id IN ('Maps to', 'Maps to value')
        AND cr.invalid_reason IS NULL

        GROUP BY concept_id_1, standard_concept
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

SELECT DISTINCT c.concept_code AS concept_code, c.concept_name AS concept_name,
                NULL::varchar AS relationship_id,
                CASE WHEN previous_mappings.concept_id_1 IS NOT NULL    --Mapping was available
                          AND NOT EXISTS (SELECT concept_id_1 FROM dev_loinc.concept_relationship lcr
                          JOIN dev_loinc.concept lc
                          ON lc.concept_id = lcr.concept_id_1 AND lc.vocabulary_id = 'LOINC'
                          WHERE lcr.relationship_id IN ('Maps to', 'Maps to value') AND lcr.invalid_reason IS NULL
                                AND lcr.concept_id_1 = c.concept_id --Concept_id never changes
                              )
                          AND previous_mappings.standard_concept = 'S'
                    THEN 'Was Standard and don''t have replacement now'

                    WHEN previous_mappings.concept_id_1 IS NOT NULL    --Mapping was available
                          AND NOT EXISTS (SELECT concept_id_1 FROM dev_loinc.concept_relationship lcr
                          JOIN dev_loinc.concept lc
                          ON lc.concept_id = lcr.concept_id_1 AND lc.vocabulary_id = 'LOINC'
                          WHERE lcr.relationship_id IN ('Maps to', 'Maps to value') AND lcr.invalid_reason IS NULL
                                AND lcr.concept_id_1 = c.concept_id --Concept_id never changes
                              )
                          AND previous_mappings.standard_concept != 'S'
                    THEN 'Was non-Standard but mapped and don''t have replacement now'

--TODO: There are 2 concepts but LOINC hasn't been ran after snomed refresh so the mappings just died.
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
                                ELSE 'Not mapped' END AS flag,
                NULL::int AS target_concept_id,
                NULL::varchar AS target_concept_code,
                NULL::varchar AS target_concept_name,
                NULL::varchar AS target_concept_class_id,
                NULL::varchar AS target_standard_concept,
                NULL::varchar AS target_invalid_reason,
                NULL::varchar AS target_domain_id,
                NULL::varchar AS target_vocabulary_id

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

--TODO: implement diff logic
/*
 WHERE c.concept_id / concept_code NOT IN (SELECT FROM _mapped table)
 */

WHERE cr.concept_id_2 IS NULL
AND (c.standard_concept IS NULL OR c.invalid_reason = 'D') AND c.vocabulary_id = 'LOINC'
AND c.concept_class_id IN ('Lab Test'
                           --,'Survey', 'Answer', 'Clinical Observation' --TODO: postponed for now
                           )

UNION ALL

SELECT concept_code_1 AS concept_code, c.concept_name AS concept_name, crm.relationship_id AS relationship_id, 'concept_relationship_manual' AS flag,
       cc.concept_id AS target_concept_id,
       cc.concept_code AS target_concept_code,
       cc.concept_name AS target_concept_name,
       cc.concept_class_id AS target_concept_class_id,
       cc.standard_concept AS target_standard_concept,
       cc.invalid_reason AS target_invalid_reason,
       cc.domain_id AS target_domain_id,
       cc.vocabulary_id AS target_vocabulary_id

FROM dev_loinc.concept_relationship_manual crm
JOIN dev_loinc.concept c ON c.concept_code = crm.concept_code_1 AND c.vocabulary_id = 'LOINC'  AND crm.invalid_reason IS NULL
JOIN dev_loinc.concept cc ON cc.concept_code = crm.concept_code_2 AND cc.vocabulary_id = crm.vocabulary_id_2

ORDER BY concept_code, flag
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
--TODO: There are a lot of non-deprecated relationships to non-standard (in dev_loinc) concepts.
-- Bring the list to the manual file.
-- There should be a check that force us to manually fix the manual file (even before running the 1st query to get the delta). So once the concept is in the manual file, it should NOT appear in delta. Basically this is "check if target concepts are Standard and exist in the concept table"
-- Once the relationship to the specific target concept is gone, the machinery should make it D in CRM using the current_date.
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