CREATE OR REPLACE FUNCTION dev_snomed.MapAllergies ()
RETURNS VOID AS
$BODY$
BEGIN

DROP TABLE IF EXISTS allergy_map;
CREATE UNLOGGED TABLE allergy_map AS

    WITH source_inclusion AS (
                 SELECT descendant_concept_code
                 FROM snomed_ancestor
                 WHERE ancestor_concept_code IN ('609328004') -- Allergic disposition
                        ),

    drugs AS (
                 SELECT descendant_concept_code
                 FROM snomed_ancestor
                 WHERE ancestor_concept_code IN ('416098002') -- Allergy to drug
                        ),
    mapsto AS (
            SELECT DISTINCT c.concept_code AS concept_code_1,
                               c.vocabulary_id AS vocabulary_id_1,
                               ii.concept_code AS concept_code_2,
                               ii.vocabulary_id AS vocabulary_id_2,
                               'Maps to' AS relationship_id
    FROM concept_stage c, concept_stage ii
    WHERE c.vocabulary_id = 'SNOMED'
        AND c.concept_code IN (SELECT descendant_concept_code
                               FROM source_inclusion)
        AND c.concept_code NOT IN (SELECT concept_code_1
                                   FROM concept_relationship_stage
                                   WHERE relationship_id = 'Has due to' -- exclude allergies due to underlying conditions
                                     AND vocabulary_id_1 = 'SNOMED'
                                     AND invalid_reason IS NULL)
        AND ii.concept_code = (CASE WHEN c.concept_code IN (SELECT descendant_concept_code FROM drugs)
               THEN '416098002' -- Allergy to drug
               ELSE '609328004' -- Allergic disposition
            END)
        AND ii.vocabulary_id = 'SNOMED'
        AND (c.invalid_reASon IS NULL or c.invalid_reason = 'D')
        AND (c.concept_code, c.vocabulary_id) NOT IN (
                                   SELECT concept_code_1, vocabulary_id_1
                                   FROM concept_relationship_stage m
                                    WHERE m.relationship_id in ('Maps to', 'Maps to value')
                                     )),

    tovalue AS (
            SELECT DISTINCT c.concept_code AS concept_code_1,
                               c.vocabulary_id AS vocabulary_id_1,
                               CASE WHEN c.concept_code in (SELECT descendant_concept_code FROM drugs)
                                   THEN ii.concept_code
                                   ELSE crs.concept_code_2 END AS concept_code_2,
                               CASE WHEN c.concept_code in (SELECT descendant_concept_code FROM drugs)
                                   THEN ii.vocabulary_id
                                   ELSE crs.vocabulary_id_2 END AS vocabulary_id_2,
                               'Maps to value' AS relationship_id
            FROM concept_stage c
            LEFT JOIN  concept_relationship_stage crs on (crs.concept_code_1, crs.vocabulary_id_1) = (c.concept_code, c.vocabulary_id)
                                                            AND crs.relationship_id = 'Has causative agent'
                                                            AND crs.invalid_reason IS NULL
            LEFT JOIN  concept_relationship_stage crs1 on (crs1.concept_code_1, crs1.vocabulary_id_1) = (crs.concept_code_2, crs.vocabulary_id_2)
                                                             AND crs1.relationship_id = 'Maps to'
                                                             AND crs1.invalid_reason IS NULL
            JOIN concept ii on (ii.concept_code, ii.vocabulary_id) = (crs1.concept_code_2, crs1.vocabulary_id_2)
            WHERE c.vocabulary_id = 'SNOMED'
                AND c.concept_code in (SELECT descendant_concept_code FROM source_inclusion)
                AND ii.standard_concept = 'S'
                AND (c.invalid_reason IS NULL or c.invalid_reason = 'D')
                AND (c.concept_code, c.vocabulary_id) NOT IN (
                                           SELECT concept_code_1, vocabulary_id_1
                                           FROM concept_relationship_stage m
                                            WHERE m.relationship_id in ('Maps to', 'Maps to value')
                                             )),

    pairs AS (
            SELECT m.concept_code_1
            FROM mapsto m
            JOIN tovalue t on m.concept_code_1 = t.concept_code_1
                                  AND t.concept_code_2 NOT IN (
                                      '105590001' -- Substance
                                      )

    )

    SELECT DISTINCT concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id,
            current_date,
            '2099-12-31'::date,
            NULL
    FROM (
            SELECT * FROM mapsto m
            WHERE exists(SELECT 1 FROM pairs p
                                  WHERE p.concept_code_1 = m.concept_code_1)

                UNION ALL

                SELECT * FROM tovalue t
            WHERE exists(SELECT 1 FROM pairs p
                                  WHERE p.concept_code_1 = t.concept_code_1)
    ) map
    ;

    INSERT INTO concept_relationship_stage
    (concept_code_1,
        concept_code_2,
        vocabulary_id_1,
        vocabulary_id_2,
        relationship_id,
        valid_start_date,
        valid_end_date,
        invalid_reason)
    SELECT *
    FROM allergy_map;

-- Update standard status of the mapped concepts:
    UPDATE concept_stage cs
    SET standard_concept = null
    WHERE EXISTS(
        SELECT 1
        FROM allergy_map a
        WHERE a.concept_code_1 = cs.concept_code
        AND a.vocabulary_id_1 = cs.vocabulary_id
    );

END;
$BODY$
LANGUAGE plpgsql;