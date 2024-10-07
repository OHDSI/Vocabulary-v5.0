-- The class_to_drug table is used in the ATC postprocessing script to select the best
-- ATC-RxNorm connections during ancestor building. It helps resolve cases with multiple
-- possible mappings—especially for combination drugs—by ranking connections to choose the most appropriate link.

-- prelim
DROP TABLE IF EXISTS rx;
CREATE TEMP TABLE rx AS
SELECT c.concept_id,
       c.concept_code,
       c.concept_name,
       c.concept_class_id,
       COUNT(cr.concept_id_2) AS n_ings
FROM devv5.concept c
         JOIN devv5.concept_relationship cr ON cr.concept_id_1 = c.concept_id
    AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND cr.invalid_reason IS NULL
    AND cr.relationship_id = 'RxNorm has ing'
GROUP BY c.concept_id, c.concept_code, c.concept_name;

INSERT INTO rx
SELECT c.concept_id,
       c.concept_code,
       c.concept_name,
       c.concept_class_id,
       COUNT(cc.concept_id) AS n_ings
FROM devv5.concept c
         JOIN devv5.concept_ancestor ca ON c.concept_id = ca.descendant_concept_id
    AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND c.concept_class_id != 'Ingredient'
         JOIN devv5.concept cc ON cc.concept_id = ca.ancestor_concept_id AND cc.concept_class_id = 'Ingredient'
WHERE c.concept_id NOT IN (SELECT concept_id FROM rx)
GROUP BY c.concept_id, c.concept_code, c.concept_name;

-- manual: covid, vaccines, insulin
-- covid 19
DROP TABLE IF EXISTS class_to_drug;
CREATE TEMP TABLE class_to_drug
AS
SELECT cs.concept_code AS class_code,
       cs.concept_name AS class_name,
       c.concept_id,
       c.concept_name,
       c.concept_class_id,
       1               AS order
FROM dev_atc.covid19_atc_rxnorm_manual cov
         JOIN dev_atc.concept_stage cs ON cov.concept_code_atc = cs.concept_code
         JOIN devv5.concept c ON cov.concept_id = c.concept_id
WHERE cov.to_drop IS NULL;

-- vaccines, insulin
INSERT INTO class_to_drug
SELECT DISTINCT cs.concept_code, cs.concept_name, c.concept_id, c.concept_name, c.concept_class_id, 1 AS order
FROM dev_atc.concept_stage cs
         JOIN dev_atc.concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
    AND cs.concept_class_id = 'ATC 5th'
    AND crs.invalid_reason IS NULL
    AND crs.relationship_id = 'ATC - RxNorm'
         JOIN devv5.concept c ON c.concept_id = crs.concept_id_2
WHERE cs.concept_code IN (SELECT class_code FROM dev_atc.class_to_drug_manual);

-- Scenario 2 & 3, mono: Ingredient A
-- 3847 ATCs and 17K Rx
INSERT INTO class_to_drug
SELECT DISTINCT cs.concept_code, cs.concept_name, rx.concept_id, rx.concept_name, rx.concept_class_id, 2 AS order
FROM dev_atc.concept_stage cs
         JOIN dev_atc.concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
    AND cs.concept_class_id = 'ATC 5th'
    AND crs.invalid_reason IS NULL
    AND crs.relationship_id = 'ATC - RxNorm'
         JOIN rx ON rx.concept_id = crs.concept_id_2
    AND n_ings = 1
WHERE NOT EXISTS (SELECT *
                  FROM dev_atc.concept_relationship_stage crs2
                  WHERE crs2.concept_code_1 = crs.concept_code_1
                    AND (crs2.relationship_id LIKE '%sec%' --or crs2.relationship_id like '%pr up%'
                      )
                    AND crs2.invalid_reason IS NULL)
  AND (cs.concept_code, rx.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug);

-- scenario 4, combo: Ingredient A + Ingredient B
-- 214 ATC, 500 Rx
INSERT INTO class_to_drug
SELECT DISTINCT cs.concept_code, cs.concept_name, rx.concept_id, rx.concept_name, rx.concept_class_id, 3 AS order
FROM dev_atc.concept_stage cs
         JOIN dev_atc.concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
    AND cs.concept_class_id = 'ATC 5th'
    AND crs.invalid_reason IS NULL
    AND crs.relationship_id = 'ATC - RxNorm'
         JOIN rx ON rx.concept_id = crs.concept_id_2
    AND n_ings = 2
WHERE NOT EXISTS (SELECT *
                  FROM dev_atc.concept_relationship_stage crs2
                  WHERE crs2.concept_code_1 = crs.concept_code_1
                    AND (crs2.relationship_id LIKE '%up%')
                    AND crs2.invalid_reason IS NULL)
  AND EXISTS (SELECT *
              FROM dev_atc.concept_relationship_stage crs2
              WHERE crs2.concept_code_1 = crs.concept_code_1
                AND crs2.relationship_id LIKE '%sec%lat%' -- assuming everything has pr lat hence only allowing pr lat and sec lat
                AND crs2.invalid_reason IS NULL)
  AND (cs.concept_code, rx.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug);

-- 3 and 4 fixed ingredients, some of the combos are wrong but keep due to the lack of time
-- 305 Rx
INSERT INTO class_to_drug
SELECT DISTINCT cs.concept_code, cs.concept_name, rx.concept_id, rx.concept_name, rx.concept_class_id, 4 AS order
FROM dev_atc.concept_stage cs
         JOIN dev_atc.concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
    AND cs.concept_class_id = 'ATC 5th'
    AND crs.invalid_reason IS NULL
    AND crs.relationship_id = 'ATC - RxNorm'
         JOIN rx ON rx.concept_id = crs.concept_id_2
    AND n_ings IN (3, 4)
WHERE NOT EXISTS (SELECT *
                  FROM dev_atc.concept_relationship_stage crs2
                  WHERE crs2.concept_code_1 = crs.concept_code_1
                    AND (crs2.relationship_id LIKE '%up%')
                    AND crs2.invalid_reason IS NULL)
  AND EXISTS (SELECT *
              FROM dev_atc.concept_relationship_stage crs2
              WHERE crs2.concept_code_1 = crs.concept_code_1
                AND crs2.relationship_id LIKE '%sec%lat%' -- assuming everything has pr lat hence only allowing pr lat and sec lat
                AND crs2.invalid_reason IS NULL)
  AND cs.concept_name NOT LIKE '% comb%'
  AND (cs.concept_code, rx.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug);

-- scenario 5, combo of
-- takes precedence because it is in fact Ingredient A + Ingredient B
-- ~20 ATC, 6K Rx
INSERT INTO class_to_drug
SELECT DISTINCT cs.concept_code, cs.concept_name, rx.concept_id, rx.concept_name, rx.concept_class_id, 5 AS order
FROM dev_atc.concept_stage cs
         JOIN dev_atc.concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
    AND cs.concept_class_id = 'ATC 5th'
    AND crs.invalid_reason IS NULL
    AND crs.relationship_id = 'ATC - RxNorm'
         JOIN rx ON rx.concept_id = crs.concept_id_2
WHERE (cs.concept_name LIKE '%combinations of %' OR cs.concept_name LIKE '%in combination%')
  AND (cs.concept_code, rx.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug);

-- scenario 6, combo: Ingredient A + group B
-- if there is an extra ingredient beyond a and group b also goes here
INSERT INTO class_to_drug
SELECT DISTINCT cs.concept_code, cs.concept_name, rx.concept_id, rx.concept_name, rx.concept_class_id, 6 AS order
FROM dev_atc.concept_stage cs
         JOIN dev_atc.concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
    AND cs.concept_class_id = 'ATC 5th'
    AND crs.invalid_reason IS NULL
    AND crs.relationship_id = 'ATC - RxNorm'
         JOIN rx ON rx.concept_id = crs.concept_id_2
    AND n_ings >= 2
WHERE EXISTS (SELECT *
              FROM dev_atc.concept_relationship_stage crs2
              WHERE crs2.concept_code_1 = crs.concept_code_1
                AND (crs2.relationship_id LIKE '%up%')
                AND crs2.invalid_reason IS NULL)
  AND cs.concept_name NOT LIKE '%combinations%'
  AND (cs.concept_code, rx.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug);

-- everything else
INSERT INTO class_to_drug
SELECT DISTINCT cs.concept_code, cs.concept_name, rx.concept_id, rx.concept_name, rx.concept_class_id, 7 AS order
FROM dev_atc.concept_stage cs
         JOIN dev_atc.concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
    AND cs.concept_class_id = 'ATC 5th'
    AND crs.invalid_reason IS NULL
    AND crs.relationship_id = 'ATC - RxNorm'
         JOIN rx ON rx.concept_id = crs.concept_id_2
WHERE (cs.concept_code, rx.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug);