/*
 * Apply this script to a schema after running 01_patch_dmd.sql and a generic
 update in schema mode.

 * -- vmps, amps, ampps etc. must be created from fresh sources! Execute
 dmd/load_stage.sql up until line #510.
 */

--TODO: Find a place for these steps with Timur V.
--3.2. Deprecate all existing relationships -- unless it is an external Maps to
UPDATE concept_relationship cr
SET
    valid_end_date = to_date('31-10-2023', 'DD-MM-YYYY'),
    invalid_reason = 'D'
WHERE
    EXISTS (
        SELECT 1
        FROM devv5.concept_relationship r
        JOIN devv5.concept c ON
            c.concept_id = r.concept_id_1
        JOIN devv5.concept c2 ON
            c2.concept_id = r.concept_id_2
        JOIN snomed_concepts_to_steal s ON
            s.concept_id = c.concept_id
        LEFT JOIN snomed_concepts_to_steal s2 ON
            s2.concept_id = c2.concept_id
        WHERE
            NOT (
                r.relationship_id = 'Maps to'
                        AND s2.concept_id IS NOT NULL
                )
            AND r.invalid_reason IS NULL
    )
;
--3.3. Steal the concepts!
UPDATE concept c SET
                     vocabulary_id = 'dm+d',
                     invalid_reason = 'D',
                     standard_concept = NULL,
                     valid_end_date = to_date('31-10-2023', 'DD-MM-YYYY'),
                     valid_start_date = CASE
                                            WHEN valid_start_date >= to_date('31-10-2023', 'DD-MM-YYYY')
                                                THEN to_date('01-01-1970', 'DD-MM-YYYY')
                                            ELSE valid_start_date
                                        END
FROM snomed_concepts_to_steal s
WHERE
    c.concept_id = s.concept_id
;
DROP TABLE snomed_concepts_to_steal;
