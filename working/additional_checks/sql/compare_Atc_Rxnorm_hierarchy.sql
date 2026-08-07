-- ATC/RxNorm hierarchy edges that existed in the old vocabulary but are absent in the new one.
-- Run compare_atc_rxnorm_hierarchy_added.sql for the inverse (new edges).
WITH old_edges AS (
    SELECT
        ca.ancestor_concept_id,
        ca.descendant_concept_id,
        ca.min_levels_of_separation,
        a.vocabulary_id AS ancestor_vocabulary_id,
        d.vocabulary_id AS descendant_vocabulary_id
    FROM @oldVocSchema.concept_ancestor ca
    JOIN @oldVocSchema.concept a ON a.concept_id = ca.ancestor_concept_id
    JOIN @oldVocSchema.concept d ON d.concept_id = ca.descendant_concept_id
    WHERE ca.min_levels_of_separation IN (0, 1)
      AND a.vocabulary_id IN ('ATC', 'RxNorm')
      AND d.vocabulary_id IN ('ATC', 'RxNorm')
),
new_edges AS (
    SELECT
        ca.ancestor_concept_id,
        ca.descendant_concept_id,
        ca.min_levels_of_separation,
        a.vocabulary_id AS ancestor_vocabulary_id,
        d.vocabulary_id AS descendant_vocabulary_id
    FROM @newVocSchema.concept_ancestor ca
    JOIN @newVocSchema.concept a ON a.concept_id = ca.ancestor_concept_id
    JOIN @newVocSchema.concept d ON d.concept_id = ca.descendant_concept_id
    WHERE ca.min_levels_of_separation IN (0, 1)
      AND a.vocabulary_id IN ('ATC', 'RxNorm')
      AND d.vocabulary_id IN ('ATC', 'RxNorm')
)
SELECT
    o.ancestor_concept_id,
    a_old.concept_name AS ancestor_concept_name,
    o.ancestor_vocabulary_id,
    o.descendant_concept_id,
    d_old.concept_name AS descendant_concept_name,
    o.descendant_vocabulary_id,
    o.min_levels_of_separation
FROM old_edges o
LEFT JOIN new_edges n
  ON  n.ancestor_concept_id       = o.ancestor_concept_id
  AND n.descendant_concept_id     = o.descendant_concept_id
  AND n.min_levels_of_separation  = o.min_levels_of_separation
JOIN @oldVocSchema.concept a_old ON a_old.concept_id = o.ancestor_concept_id
JOIN @oldVocSchema.concept d_old ON d_old.concept_id = o.descendant_concept_id
WHERE n.ancestor_concept_id IS NULL
--add your concept of interest:
--AND o.descendant_concept_id IN (40222663, 40222660)
ORDER BY
    o.ancestor_vocabulary_id,
    o.descendant_vocabulary_id,
    o.ancestor_concept_id,
    o.descendant_concept_id,
    o.min_levels_of_separation

