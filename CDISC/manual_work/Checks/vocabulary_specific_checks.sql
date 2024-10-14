--Lookup the codes that are MultiConcatenations in concept_code
SELECT *
FROM concept
WHERE vocabulary_id='CDISC'
AND concept_code ~*'-.+-'
;

--check value without corresponded Observation/Measurement
--* We expect this check to return nothing. Returned rows lack Observation/Measurement for to_value mapping. It will lead to data loss.
SELECT *
FROM concept_relationship_stage a
WHERE  EXISTS(   SELECT 1
                    FROM concept_relationship_stage c
                    WHERE a.concept_code_1 = c.concept_code_1
                      AND (c.relationship_id = 'Maps to value' )
            )
and not EXISTS(   SELECT 1
                        FROM concept_relationship_stage b
                        LEFT JOIN concept c
                            ON c.concept_code = b.concept_code_2
                        and c.vocabulary_id=b.vocabulary_id_2
                        WHERE a.concept_code_1 = b.concept_code_1
                          AND c.domain_id in ('Observation', 'Measurement')
                          AND (b.relationship_id = 'Maps to')
              )
;