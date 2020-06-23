--insulines
DROP TABLE IF EXISTS dev_amt.insulines;
CREATE TABLE dev_amt.insulines AS
    (
    WITH inclusion AS (
                      SELECT 'insul|aspart |lispro|glulisine|velosulin|glargin|detemir|degludec|' ||
                             'actrap|afrezza|apidra|basaglar|fiasp|humalog|' ||
                             'humuli|hypurin|lantus|levemir|novolin|novolog|' ||
                             'novomix|novorapid|mixtard|optisulin|protaphane|' ||
                             'ryzodeg|semglee|soluqua|toujeo|tresiba'
                      ),
         exclusion AS (SELECT 'Ctpp|Mpp|Tpp|Mpuu|Tpuu')

    SELECT *
    FROM (
         SELECT DISTINCT dcs.*
         FROM drug_concept_stage dcs
         WHERE dcs.concept_name ~* (SELECT * FROM inclusion)
           AND dcs.concept_name !~* (SELECT * FROM exclusion)
           AND dcs.concept_class_id NOT IN ('Unit', 'Supplier')

         UNION

         SELECT DISTINCT dcs2.*
         FROM drug_concept_stage dcs1
         JOIN sources.amt_rf2_full_relationships fr
             ON dcs1.concept_code = fr.sourceid::text
         JOIN drug_concept_stage dcs2
             ON dcs2.concept_code = fr.destinationid::text
         WHERE dcs1.concept_name ~* (SELECT * FROM inclusion)
           AND dcs2.concept_name !~* (SELECT * FROM exclusion)
           AND dcs1.concept_class_id NOT IN ('Unit', 'Supplier')
         ) a
    WHERE concept_class_id IN ('Ingredient', 'Drug Product', 'Device', 'Brand Name')
    );

SELECT *
FROM insulines
ORDER BY concept_name;

--check if there are more insulines (using irs)
DROP TABLE IF EXISTS insulines_2;
CREATE TABLE insulines_2 AS
    (
    SELECT *
    FROM (
         SELECT DISTINCT dcs2.*
         FROM drug_concept_stage dcs
         JOIN internal_relationship_stage irs
             ON dcs.concept_code = irs.concept_code_1 OR dcs.concept_code = irs.concept_code_2
         JOIN drug_concept_stage dcs2
             ON dcs2.concept_code = irs.concept_code_1 OR dcs2.concept_code = irs.concept_code_2
         WHERE dcs.concept_code IN (
                                   SELECT concept_code
                                   FROM insulines
                                   WHERE concept_code IS NOT NULL
                                   )
           AND dcs2.concept_class_id IN ('Drug Product', 'Ingredient', 'Device', 'Brand Name')

         UNION

         SELECT DISTINCT *
         FROM insulines
         WHERE concept_class_id IN ('Drug Product', 'Ingredient', 'Device', 'Brand Name')
         ) AS a
    )
;

SELECT *
FROM insulines_2
ORDER BY concept_name;


--insulines attributes mapping review
SELECT DISTINCT dcs.concept_code,
                dcs.concept_class_id,
                dcs.concept_name,
                NULL,
                mapping_type,
                precedence,
                concept_id_2,
                c.concept_code,
                c.concept_name,
                c.concept_class_id,
                c.standard_concept,
                c.invalid_reason,
                c.domain_id,
                c.vocabulary_id
FROM "mapping_review_backup_2020-03-31" m
JOIN drug_concept_stage dcs
    ON dcs.concept_code = m.concept_code_1
JOIN concept c
    ON m.concept_id_2 = c.concept_id
WHERE m.concept_code_1 IN (
                          SELECT concept_code
                          FROM insulines_2
                          WHERE concept_class_id IN ('Ingredient', 'Brand Name')
                          )
;


--insulines final mapping review
SELECT DISTINCT ins.concept_code, ins.concept_name as source_concept_name, ins.concept_class_id, c2.*,
                CASE WHEN d5c.concept_name IS NULL THEN 'new' END AS new_concept
FROM insulines_2 ins
LEFT JOIN concept c1
    ON ins.concept_code = c1.concept_code AND c1.vocabulary_id = 'AMT'
LEFT JOIN concept_relationship cr
    ON c1.concept_id = cr.concept_id_1 AND cr.relationship_id in ('Maps to', 'Source - RxNorm eq') AND cr.invalid_reason IS NULL
LEFT JOIN concept c2
    ON cr.concept_id_2 = c2.concept_id
LEFT JOIN devv5.concept d5c
    ON c2.concept_id = d5c.concept_id
ORDER BY source_concept_name
;