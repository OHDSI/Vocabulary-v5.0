--Checks that maybe used in any vocabulary after the BuildRxe and before GenericUpdate
--Checking difference between old and new versions of mapping

--Stats after build rxe

--1. Mapping has not been changed
with old_mapping AS
(SELECT c.concept_id AS concept_id_1, c.concept_code AS concept_code_1, c.concept_name AS concept_name_1, c.vocabulary_id AS vocabulary_id_1, cr.relationship_id,
        c1.concept_id AS concept_id_2, c1.concept_code AS concept_code_2, c1.concept_name AS concept_name_2, c1.vocabulary_id AS vocabulary_id_2
FROM concept_relationship cr
JOIN concept c
ON c.concept_id = cr.concept_id_1
JOIN concept c1
ON c1.concept_id = cr.concept_id_2
WHERE cr.relationship_id = 'Maps to' AND cr.invalid_reason IS NULL
    )

SELECT old_mapping.concept_code_1, concept_name_1, crs.relationship_id, old_mapping.concept_id_2, old_mapping.concept_code_2, concept_name_2, old_mapping.vocabulary_id_2
FROM concept_relationship_stage crs
JOIN old_mapping
ON old_mapping.concept_code_1 = crs.concept_code_1 AND old_mapping.vocabulary_id_1 = crs.vocabulary_id_1
    AND old_mapping.concept_code_2 = crs.concept_code_2 AND old_mapping.vocabulary_id_2 = crs.vocabulary_id_2
    AND old_mapping.relationship_id = crs.relationship_id;




--2. Mapping was present and has been changed in new version
with old_mapping AS
(SELECT c.concept_id AS concept_id_1, c.concept_code AS concept_code_1, c.concept_name AS concept_name_1, c.vocabulary_id AS vocabulary_id_1, cr.relationship_id,
        c1.concept_id AS concept_id_2, c1.concept_code AS concept_code_2, c1.concept_name AS concept_name_2, c1.vocabulary_id AS vocabulary_id_2
FROM concept_relationship cr
JOIN concept c
ON c.concept_id = cr.concept_id_1
JOIN concept c1
ON c1.concept_id = cr.concept_id_2
WHERE cr.relationship_id = 'Maps to' AND cr.invalid_reason IS NULL
    )

SELECT old_mapping.concept_code_1, dcs.concept_name, crs.relationship_id,
       cs.concept_code AS new_concept_code, cs.concept_name AS new_concept_name, cs.vocabulary_id AS new_vocabulary_id,
       old_mapping.concept_code_2 AS old_concept_code_2, concept_name_2 AS old_concept_name_2, old_mapping.vocabulary_id_2 AS old_vocabulary_id_2
FROM concept_relationship_stage crs
JOIN old_mapping
ON old_mapping.concept_code_1 = crs.concept_code_1 AND old_mapping.vocabulary_id_1 = crs.vocabulary_id_1
    AND old_mapping.concept_code_2 != crs.concept_code_2
    AND old_mapping.relationship_id = crs.relationship_id
JOIN concept_stage cs
ON cs.concept_code = crs.concept_code_2 AND cs.vocabulary_id = crs.vocabulary_id_2
JOIN drug_concept_stage dcs
ON dcs.concept_code = old_mapping.concept_code_1
;




--2.1 Mapping was present and has been changed in new version
--EXCLUDING DIFFERENCES IN SUPPLIERS (THEY CHANGED FOR REAL)
with old_mapping AS
(SELECT c.concept_id AS concept_id_1, c.concept_code AS concept_code_1, c.concept_name AS concept_name_1, c.vocabulary_id AS vocabulary_id_1, cr.relationship_id,
        c1.concept_id AS concept_id_2, c1.concept_code AS concept_code_2, c1.concept_name AS concept_name_2, c1.vocabulary_id AS vocabulary_id_2
FROM concept_relationship cr
JOIN concept c
ON c.concept_id = cr.concept_id_1
JOIN concept c1
ON c1.concept_id = cr.concept_id_2
WHERE cr.relationship_id = 'Maps to' AND cr.invalid_reason IS NULL
    )

SELECT old_mapping.concept_code_1, dcs.concept_name, crs.relationship_id,
       cs.concept_code AS new_concept_code, cs.concept_name AS new_concept_name, cs.vocabulary_id AS new_vocabulary_id,
       old_mapping.concept_code_2 AS old_concept_code_2, concept_name_2 AS old_concept_name_2, old_mapping.vocabulary_id_2 AS old_vocabulary_id_2
FROM concept_relationship_stage crs
JOIN old_mapping
ON old_mapping.concept_code_1 = crs.concept_code_1 AND old_mapping.vocabulary_id_1 = crs.vocabulary_id_1
    AND old_mapping.concept_code_2 != crs.concept_code_2
    AND old_mapping.relationship_id = crs.relationship_id
JOIN concept_stage cs
ON cs.concept_code = crs.concept_code_2 AND cs.vocabulary_id = crs.vocabulary_id_2
JOIN drug_concept_stage dcs
ON dcs.concept_code = old_mapping.concept_code_1
WHERE substring(lower(concept_name_2), '^.* by') != substring(lower(cs.concept_name), '^.* by')
;




--2.2 Mapping was present and has been changed in new version
--CHANGED BRAND NAMES
with old_mapping AS
(SELECT c.concept_id AS concept_id_1, c.concept_code AS concept_code_1, c.concept_name AS concept_name_1, c.vocabulary_id AS vocabulary_id_1, cr.relationship_id,
        c1.concept_id AS concept_id_2, c1.concept_code AS concept_code_2, c1.concept_name AS concept_name_2, c1.vocabulary_id AS vocabulary_id_2
FROM concept_relationship cr
JOIN concept c
ON c.concept_id = cr.concept_id_1
JOIN concept c1
ON c1.concept_id = cr.concept_id_2
WHERE cr.relationship_id = 'Maps to' AND cr.invalid_reason IS NULL
    )

SELECT old_mapping.concept_code_1, dcs.concept_name, crs.relationship_id,
       cs.concept_code AS new_concept_code, cs.concept_name AS new_concept_name, cs.vocabulary_id AS new_vocabulary_id,
       old_mapping.concept_code_2 AS old_concept_code_2, concept_name_2 AS old_concept_name_2, old_mapping.vocabulary_id_2 AS old_vocabulary_id_2
FROM concept_relationship_stage crs
JOIN old_mapping
ON old_mapping.concept_code_1 = crs.concept_code_1 AND old_mapping.vocabulary_id_1 = crs.vocabulary_id_1
    AND old_mapping.concept_code_2 != crs.concept_code_2
    AND old_mapping.relationship_id = crs.relationship_id
JOIN concept_stage cs
ON cs.concept_code = crs.concept_code_2 AND cs.vocabulary_id = crs.vocabulary_id_2
JOIN drug_concept_stage dcs
ON dcs.concept_code = old_mapping.concept_code_1
WHERE substring(lower(concept_name_2), '\[.*\]') != substring(lower(cs.concept_name), '\[.*\]')
;




--3. Mapping to new RxNormExtension concept
SELECT cs.concept_code, cs.concept_name,
       crs.relationship_id,
       cs1.concept_code, cs1.concept_name
FROM concept_relationship_stage crs
JOIN concept_stage cs
ON cs.concept_code = crs.concept_code_1 AND cs.vocabulary_id = crs.vocabulary_id_1 AND crs.relationship_id = 'Maps to'
JOIN concept_stage cs1
ON cs1.concept_code = crs.concept_code_2 AND cs1.vocabulary_id = crs.vocabulary_id_2
LEFT JOIN concept c
ON c.concept_code = crs.concept_code_2 AND c.vocabulary_id = crs.vocabulary_id_2
WHERE c.concept_id IS NULL
;




--! Excluding combodrugs
--DROP TABLE ingredients_major_diff;
--Concepts that changed ingredients
CREATE TABLE ingredients_major_diff AS
(with old_mapping AS
(SELECT c.concept_id AS concept_id_1, c.concept_code AS concept_code_1, c.concept_name AS concept_name_1, c.vocabulary_id AS vocabulary_id_1, cr.relationship_id,
        c1.concept_id AS concept_id_2, c1.concept_code AS concept_code_2, c1.concept_name AS concept_name_2, c1.vocabulary_id AS vocabulary_id_2
FROM concept_relationship cr
JOIN concept c
ON c.concept_id = cr.concept_id_1
JOIN concept c1
ON c1.concept_id = cr.concept_id_2
WHERE cr.relationship_id = 'Maps to' AND cr.invalid_reason IS NULL
    )

SELECT old_mapping.concept_code_1, dcs.concept_name, crs.relationship_id,
       cs.concept_code AS new_concept_code, cs.concept_name AS new_concept_name, cs.vocabulary_id AS new_vocabulary_id,
       old_mapping.concept_code_2 AS old_concept_code_2, concept_name_2 AS old_concept_name_2, old_mapping.vocabulary_id_2 AS old_vocabulary_id_2,
       c.concept_name AS new_ingredient_name
FROM concept_relationship_stage crs
JOIN old_mapping
ON old_mapping.concept_code_1 = crs.concept_code_1 AND old_mapping.vocabulary_id_1 = crs.vocabulary_id_1
    AND old_mapping.concept_code_2 != crs.concept_code_2
    AND old_mapping.relationship_id = crs.relationship_id
JOIN concept_stage cs
ON cs.concept_code = crs.concept_code_2 AND cs.vocabulary_id = crs.vocabulary_id_2
JOIN drug_concept_stage dcs
ON dcs.concept_code = old_mapping.concept_code_1
    --Picking up ingredients
JOIN concept_ancestor ca
ON ca.descendant_concept_id = old_mapping.concept_id_2
JOIN concept c
ON c.concept_id = ca.ancestor_concept_id AND c.concept_class_id = 'Ingredient'
WHERE old_mapping.concept_name_2 !~ ' / '
AND cs.concept_name !~* c.concept_name

ORDER BY concept_code_1)
;
