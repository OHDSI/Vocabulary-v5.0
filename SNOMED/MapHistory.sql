CREATE OR REPLACE FUNCTION dev_snomed.MapHistory ()
RETURNS VOID AS
$BODY$
BEGIN
-- This script creates mappings for thr defined personal history concepts using SNOMED attribute relationships:
WITH source_inclusion AS (
             SELECT cs.*
                    FROM concept_stage cs
                    JOIN concept_relationship_stage crs ON (crs.concept_code_1, crs.vocabulary_id_1) = (cs.concept_code, cs.vocabulary_id)
                                                               AND crs.relationship_id = 'Has temporal context'
                                                               AND crs.concept_code_2 = '410513005' -- Past
                                                               AND crs.vocabulary_id_2 = 'SNOMED'
                                                               AND crs.invalid_reason IS NULL
       			UNION
--Procedures WITH context 'Done'
       		  SELECT cs.*
                    FROM concept_stage cs
                    JOIN concept_relationship_stage crs ON (crs.concept_code_1, crs.vocabulary_id_1) = (cs.concept_code, cs.vocabulary_id)
                                                          AND crs.relationship_id = 'Has proc context'
                                                          AND crs.concept_code_2 = '385658003' -- Done
                                                          AND crs.vocabulary_id_2 = 'SNOMED'
                                                          AND crs.invalid_reason IS NULL
					),

source_exclusion AS (
             SELECT descendant_concept_code
             FROM snomed_ancestor
             WHERE ancestor_concept_code in (
                                             '57177007', -- Family history WITH explicit context
                                             '394698008', -- Birth history
                                             '271903000', --History of pregnancy
                                             '103709008' -- Failed attempted procedure
                                            )
             UNION
             SELECT concept_code_1
             FROM concept_relationship_stage
             WHERE relationship_id = 'Has relat context'
             AND (concept_code_2, vocabulary_id_2) = ('262043009', 'SNOMED') -- exclude history related to a partner
					),

mapsto AS (
        SELECT distinct c.concept_code AS concept_code_1,
                           c.vocabulary_id AS vocabulary_id_1,
                           ii.concept_code AS concept_code_2,
                           ii.vocabulary_id AS vocabulary_id_2,
                           'Maps to' AS relationship_id

           FROM concept_stage c,
                concept ii
           WHERE c.vocabulary_id = 'SNOMED'
             AND (c.concept_code, c.vocabulary_id) IN (SELECT concept_code, vocabulary_id FROM source_inclusion)
             AND c.concept_code NOT IN (SELECT descendant_concept_code FROM source_exclusion)
             AND ii.concept_id = '1340204' --History of event
             AND (c.invalid_reason IS NULL OR c.invalid_reason = 'D')
             AND c.concept_code NOT IN (SELECT concept_code_1
                                        FROM concept_relationship_stage m
                                        WHERE m.relationship_id IN ('Maps to', 'Maps to value')
                                          AND m.invalid_reason IS NULL)),
    tovalue AS (
        SELECT distinct cs.concept_code AS concept_code_1,
                           cs.vocabulary_id AS vocabulary_id_1,
                           ii.concept_code AS concept_code_2,
                           ii.vocabulary_id AS vocabulary_id_2,
                           'Maps to value' AS relationship_id
    FROM concept_stage cs
    JOIN concept_relationship_stage crs ON (crs.concept_code_1, crs.vocabulary_id_1) = (cs.concept_code, cs.vocabulary_id)
                                        AND crs.relationship_id IN ('Has asso proc', 'Has asso finding')
                                        AND crs.invalid_reason IS NULL
    JOIN concept_stage ii ON (ii.concept_code, ii.vocabulary_id) = (crs.concept_code_2, crs.vocabulary_id_2)
    JOIN snomed_ancestor sa ON sa.descendant_concept_code::TEXT = cs.concept_code
    WHERE cs.vocabulary_id = 'SNOMED'
        AND (cs.concept_code, cs.vocabulary_id) IN (SELECT concept_code, vocabulary_id FROM source_inclusion)
        AND cs.concept_code NOT IN (SELECT descendant_concept_code FROM source_exclusion)
        AND ii.standard_concept = 'S'
        AND (cs.invalid_reason IS NULL OR cs.invalid_reason = 'D')
        AND cs.concept_code NOT IN (SELECT concept_code_1
                                   FROM concept_relationship_stage m
                                    WHERE m.relationship_id IN ('Maps to', 'Maps to value')
                                      AND m.invalid_reason IS NULL)),

pairs AS (
    SELECT m.concept_code_1
    FROM mapsto m
    JOIN tovalue t ON m.concept_code_1 = t.concept_code_1
    WHERE t.concept_code_2 NOT IN ('71388002', -- Procedure
                                   '185087000', -- Notifications
                                   '409063005', -- Counselling
                                   '223458004', --Informing
                                   '420227002', -- Recommendation to
                                   '223482009', -- Discussion
                                   '419099009', -- Dead
                                   '16076005', --Prescription
                                   '409073007' -- Education
        ))

INSERT INTO concept_relationship_stage
(concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason)
SELECT DISTINCT concept_code_1,
        concept_code_2,
        vocabulary_id_1,
        vocabulary_id_2,
        relationship_id,
        current_date,
        '2099-12-31'::DATE,
        NULL
FROM (SELECT *
      FROM mapsto m
      WHERE exists (SELECT 1
                   FROM pairs p
                   WHERE p.concept_code_1 = m.concept_code_1)

      UNION
      SELECT *
      FROM tovalue t
      WHERE exists (SELECT 1
                   FROM pairs p
                   WHERE p.concept_code_1 = t.concept_code_1)) a0
;


END;
$BODY$
LANGUAGE plpgsql;