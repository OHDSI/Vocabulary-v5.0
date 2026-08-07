-- ATC/RxNorm hierarchy edges that are new in the new vocabulary (absent in the old one).
-- Run compare_Atc_Rxnorm_hierarchy.sql for the inverse (lost edges).
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
    n.ancestor_concept_id,
    a_new.concept_name AS ancestor_concept_name,
    n.ancestor_vocabulary_id,
    n.descendant_concept_id,
    d_new.concept_name AS descendant_concept_name,
    n.descendant_vocabulary_id,
    n.min_levels_of_separation
FROM new_edges n
LEFT JOIN old_edges o
  ON  o.ancestor_concept_id       = n.ancestor_concept_id
  AND o.descendant_concept_id     = n.descendant_concept_id
  AND o.min_levels_of_separation  = n.min_levels_of_separation
JOIN @newVocSchema.concept a_new ON a_new.concept_id = n.ancestor_concept_id
JOIN @newVocSchema.concept d_new ON d_new.concept_id = n.descendant_concept_id
WHERE o.ancestor_concept_id IS NULL
ORDER BY
    n.ancestor_vocabulary_id,
    n.descendant_vocabulary_id,
    n.ancestor_concept_id,
    n.descendant_concept_id,
    n.min_levels_of_separation
