/*
 * Apply this script to a schema after running 01_patch_dmd.sql and a generic
 update in delta mode.
 */

--TODO: Find a place for these steps with Timur V.
--3.2. Deprecate all existing relationships -- unless it is an external Maps to
UPDATE concept_relationship cr
SET
    valid_end_date = p.patch_date - INTERVAL '1 day',
    invalid_reason = 'D'
FROM patch_date p
WHERE
    EXISTS (
        SELECT 1
        FROM snomed_concepts_to_steal s
        LEFT JOIN snomed_concepts_to_steal s2 ON
            s2.concept_id = cr.concept_id_2
        WHERE
                cr.invalid_reason IS NULL
            AND s.concept_id = cr.concept_id_1
            AND NOT (
                    cr.relationship_id = 'Maps to'
                AND s2.concept_id IS NULL)
    )
;
--3.2. Ditto, for reverse relationships
UPDATE concept_relationship cr
SET
    valid_end_date = p.patch_date - INTERVAL '1 day',
    invalid_reason = 'D'
FROM patch_date p
WHERE
    EXISTS (
        SELECT 1
        FROM snomed_concepts_to_steal s
        LEFT JOIN snomed_concepts_to_steal s2 ON
            s2.concept_id = cr.concept_id_1
        WHERE
            cr.invalid_reason IS NULL
            AND s.concept_id = cr.concept_id_2
            AND NOT (
                    cr.relationship_id = 'Mapped from'
                AND s2.concept_id IS NULL)
    )
;
--3.4. Steal the concepts!
UPDATE concept c SET
     vocabulary_id = 'dm+d',
     invalid_reason = 'D',
     standard_concept = NULL,
     valid_end_date = p.patch_date - INTERVAL '1 day',
     valid_start_date = CASE
                            WHEN valid_start_date >= p.patch_date - INTERVAL '1 day'
                                THEN to_date('01-01-1970', 'DD-MM-YYYY')
                            ELSE valid_start_date
                        END
FROM snomed_concepts_to_steal s
JOIN patch_date p ON TRUE
WHERE
    c.concept_id = s.concept_id
;
DROP TABLE snomed_concepts_to_steal;
