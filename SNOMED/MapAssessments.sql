CREATE OR REPLACE FUNCTION dev_snomed.MapAssessments()
RETURNS VOID AS
$BODY$
BEGIN
-- 1. Map assessment procedures to the respective observables:
DROP TABLE IF EXISTS mapped;
CREATE UNLOGGED TABLE mapped AS
    SELECT DISTINCT cs.concept_code AS concept_code_1,
            cc.concept_code AS concept_code_2,
            cs.vocabulary_id AS vocabulary_id_1,
            cc.vocabulary_id AS vocabulary_id_2,
            'Maps to' AS relationship_id,
            current_date,
            '2099-12-31'::DATE,
            NULL
    FROM concept_stage cs
    JOIN concept_stage cc ON REGEXP_REPLACE(lower(cs.concept_name), '^assessment using | scale$', '', 'g') = REGEXP_REPLACE(lower(cc.concept_name), ' scale', '')
    WHERE cs.vocabulary_id = 'SNOMED'
        AND cc.vocabulary_id = 'SNOMED'
        AND cc.standard_concept = 'S'
        AND cs.domain_id = 'Measurement'
        AND cs.concept_class_id = 'Procedure'
        AND cc.concept_class_id = 'Staging / Scales'
        AND NOT EXISTS(SELECT 1
                       FROM concept_relationship_stage crs
                       WHERE (crs.concept_code_1, crs.vocabulary_id_1) = (cs.concept_code, cs.vocabulary_id)
                         AND crs.relationship_id = 'Maps to')
;

INSERT INTO concept_relationship_stage (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
)
SELECT *
FROM mapped
;

-- 2. Update standard status of the mapped concepts:
    UPDATE concept_stage cs
    SET standard_concept = null
    WHERE EXISTS(
        SELECT 1
        FROM mapped m
        WHERE m.concept_code_1 = cs.concept_code
        AND m.vocabulary_id_1 = cs.vocabulary_id
    );
END;
$BODY$
LANGUAGE plpgsql;