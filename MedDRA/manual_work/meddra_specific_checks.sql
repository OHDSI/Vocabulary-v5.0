-- All target_concepts in dev_meddra.meddra_environment that became non-standard.
SELECT *
FROM dev_meddra.meddra_environment AS me
INNER JOIN dev_meddra.concept AS c
ON me.target_concept_id = c.concept_id
AND (c.invalid_reason IS NOT NULL or c.standard_concept!='S' or c.standard_concept IS NULL) AND me.decision='1'
-- INNER JOIN dev_meddra.concept_relationship AS cr
-- ON c.concept_id = cr.concept_id_1 AND cr.relationship_id='Maps to' AND cr.invalid_reason IS NULL
-- INNER JOIN dev_meddra.concept AS cc
-- ON cr.concept_id_2 = cc.concept_id AND cc.standard_concept='S' AND cc.invalid_reason IS NULL;



-- Procedure for loops of ancestor creation

DROP TABLE dev_meddra.meddra_loops_temporary;
CREATE TABLE dev_meddra.meddra_loops_temporary AS
    SELECT * FROM vocabulary_pack.GetAncestorLoops(pVocabularies=>'MedDRA,SNOMED,OMOP Extension');

SELECT * FROM dev_meddra.meddra_loops_temporary;

-- Create a temporary table to store the results
DROP TABLE temp_ancestor_paths;
CREATE TEMPORARY TABLE temp_ancestor_paths (
    ancestor_id INT,
    descendant_id INT,
    path TEXT
);

-- Loop through each row in the dev_meddra.meddra_loops_temporary table
DO $$
DECLARE
    rec RECORD;
    ancestor_id INT;
    descendant_id INT;
    path TEXT;
BEGIN
    FOR rec IN SELECT * FROM dev_meddra.meddra_loops_temporary LOOP
        ancestor_id := rec.ancestor_concept_id;
        descendant_id := rec.descendant_concept_id;

        -- Fetch the path using the vocabulary_pack.GetAncestorPath_in_DEV function
        EXECUTE 'SELECT vocabulary_pack.GetAncestorPath_in_DEV($1, $2)'
        INTO path
        USING ancestor_id, descendant_id;

        -- Insert the result into the temporary table
        INSERT INTO temp_ancestor_paths (ancestor_id, descendant_id, path)
        VALUES (ancestor_id, descendant_id, path);
    END LOOP;
END $$;

DROP TABLE extracted_paths;
CREATE TEMP TABLE extracted_paths (
    ancestor_id INT,
    descendant_id INT,
    step_1 INT,
    step_2 INT,
    step_3 INT,
    step_4 INT
);

INSERT INTO extracted_paths (ancestor_id, descendant_id, step_1, step_2, step_3, step_4)
SELECT
    ancestor_id,
    descendant_id,
    (regexp_match(path, '(\d+)'))[1]::INT AS step_1,
    (regexp_match(path, '\d+ ''Subsumes'' (\d+)'))[1]::INT AS step_2,
    (regexp_match(path, '\d+ ''Subsumes'' \d+ ''Subsumes'' (\d+)'))[1]::INT AS step_3,
    (regexp_match(path, '\d+ ''Subsumes'' \d+ ''Subsumes'' \d+ ''Subsumes'' (\d+)'))[1]::INT AS step_4
FROM
    temp_ancestor_paths;

-- Results assessment
SELECT c1.concept_code, c1.concept_name, c1.vocabulary_id, c1.concept_class_id, 'Subsumes',
       c2.concept_code, c2.concept_name, c2.vocabulary_id, c2.concept_class_id, 'Subsumes',
       c3.concept_code, c3.concept_name, c3.vocabulary_id, c3.concept_class_id, 'Subsumes',
       c4.concept_code, c4.concept_name, c4.vocabulary_id, c4.concept_class_id
FROM extracted_paths AS t
INNER JOIN devv5.concept AS c1
ON t.step_1 = c1.concept_id
INNER JOIN devv5.concept AS c2
ON t.step_2 = c2.concept_id
INNER JOIN devv5.concept AS c3
ON t.step_3 = c3.concept_id
INNER JOIN devv5.concept AS c4
ON t.step_4 = c4.concept_id;



-- Checks for finding discrepancies in hierarchy between MedDAR and SNOMED

DROP TABLE LLT_MAP_HIER;
CREATE TABLE LLT_MAP_HIER AS
SELECT llt.concept_id as llt_id,llt_rel.relationship_id,pt.concept_id as pt_id,array_agg(DISTINCT llt_rel.concept_id_2) as target_id_array_agg
FROM concept llt
JOIN concept_relationship llt_rel
on llt.concept_id = llt_rel.concept_id_1
and llt_rel.relationship_id IN ('Maps to','Maps to value')
and llt_rel.invalid_reason IS NULL
    and llt.vocabulary_id='MedDRA'
    and llt.concept_class_id='LLT'
JOIN concept_relationship llt_hier
on llt.concept_id=llt_hier.concept_id_1
and llt_hier.relationship_id='Is a'
and llt_hier.invalid_reason IS NULL
JOIN concept pt
on pt.concept_id=llt_hier.concept_id_2
    and pt.vocabulary_id='MedDRA'
    and pt.concept_class_id='PT'
GROUP BY llt.concept_id, llt_rel.relationship_id,pt.concept_id
;

SELECT *
from LLT_MAP_HIER
;


DROP TABLE PT_MAP;
CREATE TABLE PT_MAP AS
SELECT pt.concept_id as pt_id,pt_rel.relationship_id,array_agg(DISTINCT pt_rel.concept_id_2) as target_id_array_agg
FROM concept pt
JOIN concept_relationship pt_rel
on pt.concept_id = pt_rel.concept_id_1
and pt_rel.relationship_id IN ('Maps to','Maps to value')
and pt_rel.invalid_reason IS NULL
    and pt.vocabulary_id='MedDRA'
    and pt.concept_class_id='PT'
GROUP BY pt_rel.relationship_id,pt.concept_id
;

DROP TABLE discrepancies_in_llt_pt;
CREATE TABLE discrepancies_in_llt_pt as
    SELECT a.llt_id,a.relationship_id as llt_relationship_id,a.target_id_array_agg as llt_target_id_array_agg,
       c.pt_id,
       c.relationship_id as pt_relationship_id,
       c.target_id_array_agg as pt_target_id_array_agg
from llt_map_hier a
JOIN pt_map c
on a.pt_id=c.pt_id
and a.relationship_id=c.relationship_id
where  exists (SELECT 1
               FROM pt_map b
               where a.pt_id=b.pt_id
               and a.relationship_id=b.relationship_id
              )
and  not exists (SELECT 1
               FROM pt_map b1
               where a.pt_id=b1.pt_id
               and a.target_id_array_agg=b1.target_id_array_agg
                and a.relationship_id=b1.relationship_id
)
;

DROP TABLE valid_llt_pt_1_to_1_child_paren_pairs;
CREATE TABLE valid_llt_pt_1_to_1_child_paren_pairs as
    SELECT a.llt_id,
                          a.relationship_id     AS llt_relationship_id,
                          a.target_id_array_agg AS llt_target_id_array_agg,
                          c.pt_id,
                          c.relationship_id     AS pt_relationship_id,
                          c.target_id_array_agg AS pt_target_id_array_agg
                   FROM llt_map_hier a
                            JOIN pt_map c
                                 ON a.pt_id = c.pt_id
                                        and a.relationship_id=c.relationship_id
                   WHERE EXISTS (SELECT 1
                                 FROM pt_map b
                                 WHERE a.pt_id = b.pt_id
                                   and a.relationship_id=b.relationship_id)
                     AND NOT EXISTS (SELECT 1
                                     FROM pt_map b1
                                     WHERE a.pt_id = b1.pt_id
                                       AND a.target_id_array_agg = b1.target_id_array_agg
                                       AND a.relationship_id = b1.relationship_id)

                     AND EXISTS (SELECT 1
                                 FROM pt_map b2
                                 WHERE a.pt_id = b2.pt_id
                                   AND a.relationship_id = b2.relationship_id)
                     AND a.relationship_id = 'Maps to'
                      AND c.relationship_id = 'Maps to'
                     AND ARRAY_LENGTH(a.target_id_array_agg, 1) = 1
                     AND ARRAY_LENGTH(c.target_id_array_agg, 1) = 1
                     AND EXISTS (SELECT 1
                                 FROM concept_ancestor ca
                                 WHERE ca.ancestor_concept_id = c.target_id_array_agg[1]
                                   AND ca.descendant_concept_id = a.target_id_array_agg[1]);

SELECT *
from discrepancies_in_llt_pt
where llt_id not in (SELECT llt_id from valid_llt_pt_1_to_1_child_paren_pairs)
;
