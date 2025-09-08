--- What systemic forms of GCS we are now loosing
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
