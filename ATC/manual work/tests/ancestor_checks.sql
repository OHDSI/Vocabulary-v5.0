--- What systemic forms of GCS we are now losing
WITH rxnorm AS (SELECT c2.*
                FROM devv5.concept_ancestor ca
                         JOIN devv5.concept c ON c.concept_id = ca.descendant_concept_id
                    AND c.concept_class_id = 'Ingredient'
                    AND LOWER(c.concept_name) IN ('betamethasone', 'cortisone', 'dexamethasone',
                                                  'fludrocortisone', 'fluocortolone', 'hydrocortisone',
                                                  'methylprednisolone', 'prednisolone', 'prednisone',
                                                  'prednylidene', 'triamcinolone', 'beclomethasone',
                                                  'budesonide', 'deflazacort', 'desonide', 'diflucortolone',
                                                  'fluocinonide', 'fluorometholone', 'fluticasone', 'halcinonide',
                                                  'mometasone', 'paramethasone', 'rimexolone')
                    AND ancestor_concept_id IN (21602723, 21602745)
                         JOIN devv5.concept_ancestor ca2 ON c.concept_id = ca2.ancestor_concept_id
                         JOIN devv5.concept c2 ON c2.concept_id = ca2.descendant_concept_id
                    AND c2.concept_name ~ 'Injec|Oral|Implant|Syringe|Pen' AND c2.standard_concept = 'S'--and c2.vocabulary_id = 'RxNorm'
)
SELECT cnt, db_cnt, r.concept_id, concept_name, vocabulary_id
FROM rxnorm r
         LEFT JOIN dev_anna.count_standard_aggregated cs ON cs.concept_id = r.concept_id
WHERE r.concept_id NOT IN (
    -- get systemic corticosteroids through ATC
    SELECT c.concept_id AS atc_id
    FROM devv5.concept_ancestor ca
             JOIN devv5.concept c ON c.concept_id = ca.descendant_concept_id
    WHERE ancestor_concept_id IN (21602745, 21602723))
ORDER BY cnt DESC;

---- Systemic GCS after pConceptAncestor update

WITH rxnorm AS (SELECT c2.*
                FROM dev_atc.concept_ancestor ca
                         JOIN dev_atc.concept c ON c.concept_id = ca.descendant_concept_id
                    AND c.concept_class_id = 'Ingredient'
                    AND LOWER(c.concept_name) IN ('betamethasone', 'cortisone', 'dexamethasone',
                                                  'fludrocortisone', 'fluocortolone', 'hydrocortisone',
                                                  'methylprednisolone', 'prednisolone', 'prednisone',
                                                  'prednylidene', 'triamcinolone', 'beclomethasone',
                                                  'budesonide', 'deflazacort', 'desonide', 'diflucortolone',
                                                  'fluocinonide', 'fluorometholone', 'fluticasone', 'halcinonide',
                                                  'mometasone', 'paramethasone', 'rimexolone')
                    AND ancestor_concept_id IN (21602723, 21602745)
                         JOIN dev_atc.concept_ancestor ca2 ON c.concept_id = ca2.ancestor_concept_id
                         JOIN dev_atc.concept c2 ON c2.concept_id = ca2.descendant_concept_id
                    AND c2.concept_name ~ 'Injec|Oral|Implant|Syringe|Pen' AND c2.standard_concept = 'S'--and c2.vocabulary_id = 'RxNorm'
)
SELECT cnt, db_cnt, r.concept_id, concept_name, vocabulary_id
FROM rxnorm r
         LEFT JOIN dev_anna.count_standard_aggregated cs ON cs.concept_id = r.concept_id
WHERE r.concept_id NOT IN (
    -- get systemic corticosteroids through ATC
    SELECT c.concept_id AS atc_id
    FROM dev_atc.concept_ancestor ca
             JOIN dev_atc.concept c ON c.concept_id = ca.descendant_concept_id
    WHERE ancestor_concept_id IN (21602745, 21602723))
ORDER BY cnt DESC;


---- See, what new connections we have after modified pConceptAncestor, compared to Old
SELECT c1.concept_id,
       c1.concept_code,
       c1.concept_name,
       c2.concept_id,
       c2.concept_name,
       c2.concept_class_id
FROM dev_atc.concept_ancestor ca
         JOIN dev_atc.concept c1 ON ca.ancestor_concept_id = c1.concept_id
    AND c1.vocabulary_id = 'ATC'
    AND c1.concept_class_id = 'ATC 5th'
    AND c1.invalid_reason IS NULL
         JOIN dev_atc.concept c2 ON ca.descendant_concept_id = c2.concept_id
    AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND c2.invalid_reason IS NULL
WHERE (c1.concept_id, c2.concept_id) NOT IN (SELECT c1.concept_id,
                                                    c2.concept_id
                                             FROM devv5.concept_ancestor ca
                                                      JOIN devv5.concept c1 ON ca.ancestor_concept_id = c1.concept_id
                                                 AND c1.vocabulary_id = 'ATC'
                                                 AND c1.concept_class_id = 'ATC 5th'
                                                 AND c1.invalid_reason IS NULL
                                                      JOIN devv5.concept c2 ON ca.descendant_concept_id = c2.concept_id
                                                 AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                                 AND c2.invalid_reason IS NULL);

---- What new connections for systemic GCS we get after pConceptAncestor update.
SELECT c1.concept_id,
       c1.concept_code,
       c1.concept_name,
       c2.concept_id,
       c2.concept_name,
       c2.concept_class_id
FROM dev_atc.concept_ancestor ca
         JOIN dev_atc.concept c1 ON ca.ancestor_concept_id = c1.concept_id
    AND c1.vocabulary_id = 'ATC'
    AND c1.concept_class_id = 'ATC 5th'
    AND c1.invalid_reason IS NULL
    AND LEFT(c1.concept_code, 4) IN ('H02B', 'H02A')
         JOIN dev_atc.concept c2 ON ca.descendant_concept_id = c2.concept_id
    AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND c2.invalid_reason IS NULL
WHERE (c1.concept_id, c2.concept_id) NOT IN (SELECT c1.concept_id,
                                                    c2.concept_id
                                             FROM dev_atatur.concept_ancestor ca
                                                      JOIN dev_atatur.concept c1
                                                           ON ca.ancestor_concept_id = c1.concept_id
                                                               AND c1.vocabulary_id = 'ATC'
                                                               AND c1.concept_class_id = 'ATC 5th'
                                                               AND c1.invalid_reason IS NULL
                                                      JOIN dev_atatur.concept c2
                                                           ON ca.descendant_concept_id = c2.concept_id
                                                               AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                                               AND c2.invalid_reason IS NULL);


---- See, what connections we have after classic pConceptAncestor, compared to modified pConceptAncestor
SELECT c1.concept_id,
       c1.concept_code,
       c1.concept_name,
       c2.concept_id,
       c2.concept_name,
       c2.concept_class_id
FROM devv5.concept_ancestor ca
         JOIN devv5.concept c1 ON ca.ancestor_concept_id = c1.concept_id
    AND c1.vocabulary_id = 'ATC'
    AND c1.concept_class_id = 'ATC 5th'
    AND c1.invalid_reason IS NULL
         JOIN devv5.concept c2 ON ca.descendant_concept_id = c2.concept_id
    AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND c2.invalid_reason IS NULL
WHERE (c1.concept_id, c2.concept_id) NOT IN (SELECT c1.concept_id,
                                                    c2.concept_id
                                             FROM dev_atc.concept_ancestor ca
                                                      JOIN dev_atc.concept c1 ON ca.ancestor_concept_id = c1.concept_id
                                                 AND c1.vocabulary_id = 'ATC'
                                                 AND c1.concept_class_id = 'ATC 5th'
                                                 AND c1.invalid_reason IS NULL
                                                      JOIN dev_atc.concept c2
                                                           ON ca.descendant_concept_id = c2.concept_id
                                                               AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                                               AND c2.invalid_reason IS NULL);


----- See what links we have in CR table, and don't have in CA.
SELECT c.concept_id,
       c.concept_code,
       c.concept_name,
       cr.relationship_id,
       c1.concept_id,
       c1.concept_code,
       c1.concept_name
FROM dev_atc.concept_relationship cr
         JOIN dev_atc.concept c
              ON c.concept_id = cr.concept_id_1
                  AND c.invalid_reason IS NULL
                  AND c.vocabulary_id = 'ATC'
                  AND c.concept_class_id = 'ATC 5th'
         JOIN dev_atc.concept c1
              ON c1.concept_id = cr.concept_id_2
                  AND c1.invalid_reason IS NULL
                  AND c1.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                  AND c1.concept_class_id = 'Clinical Drug Form'
         LEFT JOIN dev_atc.concept_ancestor ca
                   ON (cr.concept_id_1, cr.concept_id_2) = (ca.ancestor_concept_id, ca.descendant_concept_id)

WHERE cr.relationship_id = 'ATC - RxNorm'
  AND cr.invalid_reason IS NULL
  AND ca.ancestor_concept_id IS NULL;

-- ATC/RxNorm hierarchy edges that existed in the old vocabulary but are absent in the new one.
-- Run compare_atc_rxnorm_hierarchy_added.sql for the inverse (new edges).
WITH old_edges AS (
    SELECT
        ca.ancestor_concept_id,
        ca.descendant_concept_id,
        ca.min_levels_of_separation,
        a.vocabulary_id AS ancestor_vocabulary_id,
        d.vocabulary_id AS descendant_vocabulary_id
    FROM prodv5.concept_ancestor ca
    JOIN prodv5.concept a ON a.concept_id = ca.ancestor_concept_id
    JOIN prodv5.concept d ON d.concept_id = ca.descendant_concept_id
    WHERE ca.min_levels_of_separation IN (0, 1)
      AND a.vocabulary_id IN ('ATC')
      AND d.vocabulary_id IN ('RxNorm')
),
new_edges AS (
    SELECT
        ca.ancestor_concept_id,
        ca.descendant_concept_id,
        ca.min_levels_of_separation,
        a.vocabulary_id AS ancestor_vocabulary_id,
        d.vocabulary_id AS descendant_vocabulary_id
    FROM concept_ancestor ca
    JOIN concept a ON a.concept_id = ca.ancestor_concept_id
    JOIN concept d ON d.concept_id = ca.descendant_concept_id
    WHERE ca.min_levels_of_separation IN (0, 1)
      AND a.vocabulary_id IN ('ATC')
      AND d.vocabulary_id IN ('RxNorm')
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
JOIN prodv5.concept a_old ON a_old.concept_id = o.ancestor_concept_id
JOIN prodv5.concept d_old ON d_old.concept_id = o.descendant_concept_id
WHERE n.ancestor_concept_id IS NULL
--add your concept of interest:
--AND o.descendant_concept_id IN (40222663, 40222660)
ORDER BY
    o.ancestor_vocabulary_id,
    o.descendant_vocabulary_id,
    o.ancestor_concept_id,
    o.descendant_concept_id,
    o.min_levels_of_separation;

-- ATC/RxNorm hierarchy edges that are new in the new vocabulary (absent in the old one).
-- Run compare_Atc_Rxnorm_hierarchy.sql for the inverse (lost edges).
WITH old_edges AS (
    SELECT
        ca.ancestor_concept_id,
        ca.descendant_concept_id,
        ca.min_levels_of_separation,
        a.vocabulary_id AS ancestor_vocabulary_id,
        d.vocabulary_id AS descendant_vocabulary_id
    FROM prodv5.concept_ancestor ca
    JOIN prodv5.concept a ON a.concept_id = ca.ancestor_concept_id
    JOIN prodv5.concept d ON d.concept_id = ca.descendant_concept_id
    WHERE ca.min_levels_of_separation IN (0, 1)
      AND a.vocabulary_id IN ('ATC')
      AND d.vocabulary_id IN ('RxNorm')
),
new_edges AS (
    SELECT
        ca.ancestor_concept_id,
        ca.descendant_concept_id,
        ca.min_levels_of_separation,
        a.vocabulary_id AS ancestor_vocabulary_id,
        d.vocabulary_id AS descendant_vocabulary_id
    FROM concept_ancestor ca
    JOIN concept a ON a.concept_id = ca.ancestor_concept_id
    JOIN concept d ON d.concept_id = ca.descendant_concept_id
    WHERE ca.min_levels_of_separation IN (0, 1)
      AND a.vocabulary_id IN ('ATC')
      AND d.vocabulary_id IN ('RxNorm')
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
JOIN dev_test6.concept a_new ON a_new.concept_id = n.ancestor_concept_id
JOIN dev_test6.concept d_new ON d_new.concept_id = n.descendant_concept_id
WHERE o.ancestor_concept_id IS NULL
ORDER BY
    n.ancestor_vocabulary_id,
    n.descendant_vocabulary_id,
    n.ancestor_concept_id,
    n.descendant_concept_id,
    n.min_levels_of_separation


