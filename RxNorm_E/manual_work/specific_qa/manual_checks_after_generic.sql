--1. Drug Standard RxNorm/RxE concepts aren't linked to the Standard Drug Ingredients

--1a. statistics
--vocabulary version v20201222:
-- 16519/1905195 = 0.867%
SELECT c.vocabulary_id, c.concept_class_id, COUNT (*)
FROM concept c

WHERE c.domain_id = 'Drug'
    AND c.standard_concept = 'S'
    AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND c.concept_class_id NOT IN ('Ingredient')

AND NOT EXISTS (
                SELECT 1
                FROM concept_ancestor ca
                JOIN concept c2
                    ON ca.ancestor_concept_id = c2.concept_id
                        AND c2.concept_class_id = 'Ingredient'
                        AND c2.domain_id = 'Drug'
                        AND c2.standard_concept = 'S'
                WHERE ca.descendant_concept_id = c.concept_id
    )
GROUP BY 1,2
ORDER BY 1,2
;

--1b. full list
SELECT c.*
FROM concept c

WHERE c.domain_id = 'Drug'
    AND c.standard_concept = 'S'
    AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND c.concept_class_id NOT IN ('Ingredient')

AND NOT EXISTS (
                SELECT 1
                FROM concept_ancestor ca
                JOIN concept c2
                    ON ca.ancestor_concept_id = c2.concept_id
                        AND c2.concept_class_id = 'Ingredient'
                        AND c2.domain_id = 'Drug'
                        AND c2.standard_concept = 'S'
                WHERE ca.descendant_concept_id = c.concept_id
    )
ORDER BY concept_id
;


--2. Drug Standard RxNorm/RxE concepts aren't linked to the Standard Clinical Drug Forms
--2a. statistics
--vocabulary version v20201222:
-- 30110/1651102 = 1.82%
SELECT c.vocabulary_id, c.concept_class_id, COUNT (*)
FROM concept c

WHERE c.domain_id = 'Drug'
    AND c.standard_concept = 'S'
    AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND c.concept_class_id NOT IN ('Ingredient', 'Branded Drug Comp', 'Clinical Drug Comp')

AND NOT EXISTS (
                SELECT 1
                FROM concept_ancestor ca
                JOIN concept c2
                    ON ca.ancestor_concept_id = c2.concept_id
                        AND c2.concept_class_id = 'Clinical Drug Form'
                        AND c2.domain_id = 'Drug'
                        AND c2.standard_concept = 'S'
                WHERE ca.descendant_concept_id = c.concept_id
    )
GROUP BY 1,2
ORDER BY 1,2
;

--2b. full list
SELECT c.*
FROM concept c

WHERE c.domain_id = 'Drug'
    AND c.standard_concept = 'S'
    AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND c.concept_class_id NOT IN ('Ingredient', 'Branded Drug Comp', 'Clinical Drug Comp')

AND NOT EXISTS (
                SELECT 1
                FROM concept_ancestor ca
                JOIN concept c2
                    ON ca.ancestor_concept_id = c2.concept_id
                        AND c2.concept_class_id = 'Clinical Drug Form'
                        AND c2.domain_id = 'Drug'
                        AND c2.standard_concept = 'S'
                WHERE ca.descendant_concept_id = c.concept_id
    )
ORDER BY concept_id
;