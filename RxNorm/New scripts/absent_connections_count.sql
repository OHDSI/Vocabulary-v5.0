WITH possible_relationships AS (
    SELECT * FROM (
        WITH t AS (
            SELECT 'Brand Name' c_class_1, 'Brand name of' relationship_id, 'Branded Drug Box' c_class_2 UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Branded Drug Comp' UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Branded Drug Form' UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Branded Drug' UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Branded Pack' UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Branded Pack Box' UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Marketed Product' UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Quant Branded Box' UNION ALL
            SELECT 'Brand Name', 'Brand name of', 'Quant Branded Drug' UNION ALL
            SELECT 'Branded Drug Box', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Branded Drug Box', 'Has quantified form', 'Quant Branded Box' UNION ALL
            SELECT 'Branded Drug Comp', 'Constitutes', 'Branded Drug' UNION ALL
            SELECT 'Branded Drug Form', 'RxNorm inverse is a', 'Branded Drug' UNION ALL
            SELECT 'Branded Drug', 'Available as box', 'Branded Drug Box' UNION ALL
            SELECT 'Branded Drug', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Branded Drug', 'Has quantified form', 'Quant Branded Drug' UNION ALL
            SELECT 'Clinical Drug Box', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Clinical Drug Box', 'Has quantified form', 'Quant Clinical Box' UNION ALL
            SELECT 'Clinical Drug Box', 'Has tradename', 'Branded Drug Box' UNION ALL
            SELECT 'Clinical Drug Comp', 'Constitutes', 'Clinical Drug' UNION ALL
            SELECT 'Clinical Drug Comp', 'Has tradename', 'Branded Drug Comp' UNION ALL
            SELECT 'Clinical Drug Form', 'Has tradename', 'Branded Drug Form' UNION ALL
            SELECT 'Clinical Drug Form', 'RxNorm inverse is a', 'Clinical Drug' UNION ALL
            SELECT 'Clinical Drug', 'Available as box', 'Clinical Drug Box' UNION ALL
            SELECT 'Clinical Drug', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Clinical Drug', 'Has quantified form', 'Quant Clinical Drug' UNION ALL
            SELECT 'Clinical Drug', 'Has tradename', 'Branded Drug' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Branded Drug Box' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Branded Drug Form' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Branded Drug' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Branded Pack' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Clinical Drug Box' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Clinical Drug Form' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Clinical Drug' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Clinical Pack' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Marketed Product' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Quant Branded Box' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Quant Branded Drug' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Quant Clinical Box' UNION ALL
            SELECT 'Dose Form', 'RxNorm dose form of', 'Quant Clinical Drug' UNION ALL
            SELECT 'Ingredient', 'Has brand name', 'Brand Name' UNION ALL
            SELECT 'Ingredient', 'RxNorm ing of', 'Clinical Drug Comp' UNION ALL
            SELECT 'Ingredient', 'RxNorm ing of', 'Clinical Drug Form' UNION ALL
            SELECT 'Marketed Product', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Supplier', 'Supplier of', 'Marketed Product' UNION ALL
            SELECT 'Quant Branded Box', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Quant Branded Drug', 'Available as box', 'Quant Branded Box' UNION ALL
            SELECT 'Quant Branded Drug', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Quant Clinical Box', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Quant Clinical Box', 'Has tradename', 'Quant Branded Box' UNION ALL
            SELECT 'Quant Clinical Drug', 'Available as box', 'Quant Clinical Box' UNION ALL
            SELECT 'Quant Clinical Drug', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Quant Clinical Drug', 'Has tradename', 'Quant Branded Drug' UNION ALL
            SELECT 'Branded Dose Group', 'Has brand name', 'Brand Name' UNION ALL
            SELECT 'Branded Dose Group', 'Has dose form group', 'Dose Form Group' UNION ALL
            SELECT 'Branded Dose Group', 'Marketed form of', 'Dose Form Group' UNION ALL
            SELECT 'Branded Dose Group', 'RxNorm has ing', 'Brand Name' UNION ALL
            SELECT 'Branded Dose Group', 'RxNorm inverse is a', 'Branded Drug Form' UNION ALL
            SELECT 'Branded Dose Group', 'RxNorm inverse is a', 'Branded Drug' UNION ALL
            SELECT 'Branded Dose Group', 'RxNorm inverse is a', 'Quant Branded Drug' UNION ALL
            SELECT 'Branded Dose Group', 'RxNorm inverse is a', 'Quant Clinical Drug' UNION ALL
            SELECT 'Branded Dose Group', 'Tradename of', 'Clinical Dose Group' UNION ALL
            SELECT 'Clinical Dose Group', 'Has dose form group', 'Dose Form Group' UNION ALL
            SELECT 'Clinical Dose Group', 'Marketed form of', 'Dose Form Group' UNION ALL
            SELECT 'Clinical Dose Group', 'RxNorm has ing', 'Ingredient' UNION ALL
            SELECT 'Clinical Dose Group', 'RxNorm has ing', 'Precise Ingredient' UNION ALL
            SELECT 'Clinical Dose Group', 'RxNorm inverse is a', 'Clinical Drug Form' UNION ALL
            SELECT 'Clinical Dose Group', 'RxNorm inverse is a', 'Clinical Drug' UNION ALL
            SELECT 'Clinical Dose Group', 'RxNorm inverse is a', 'Quant Branded Drug' UNION ALL
            SELECT 'Clinical Dose Group', 'RxNorm inverse is a', 'Quant Clinical Drug' UNION ALL
            SELECT 'Dose Form Group', 'RxNorm inverse is a', 'Dose Form' UNION ALL
            SELECT 'Precise Ingredient', 'Form of', 'Ingredient' UNION ALL
            SELECT 'Clinical Drug', 'Contained in', 'Clinical Pack' UNION ALL
            SELECT 'Clinical Drug', 'Contained in', 'Clinical Pack Box' UNION ALL
            SELECT 'Clinical Drug', 'Contained in', 'Branded Pack' UNION ALL
            SELECT 'Clinical Drug', 'Contained in', 'Branded Pack Box' UNION ALL
            SELECT 'Clinical Drug', 'Contained in', 'Marketed Product' UNION ALL
            SELECT 'Branded Drug', 'Contained in', 'Branded Pack' UNION ALL
            SELECT 'Branded Drug', 'Contained in', 'Branded Pack Box' UNION ALL
            SELECT 'Branded Drug', 'Contained in', 'Marketed Product' UNION ALL
            SELECT 'Quant Clinical Drug', 'Contained in', 'Clinical Pack' UNION ALL
            SELECT 'Quant Clinical Drug', 'Contained in', 'Clinical Pack Box' UNION ALL
            SELECT 'Quant Clinical Drug', 'Contained in', 'Branded Pack' UNION ALL
            SELECT 'Quant Clinical Drug', 'Contained in', 'Branded Pack Box' UNION ALL
            SELECT 'Quant Clinical Drug', 'Contained in', 'Marketed Product' UNION ALL
            SELECT 'Quant Branded Drug', 'Contained in', 'Branded Pack' UNION ALL
            SELECT 'Quant Branded Drug', 'Contained in', 'Branded Pack Box' UNION ALL
            SELECT 'Quant Branded Drug', 'Contained in', 'Marketed Product' UNION ALL
            SELECT 'Branded Pack', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Branded Pack Box', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Branded Pack', 'Available as box', 'Branded Pack Box' UNION ALL
            SELECT 'Clinical Pack', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Clinical Pack Box', 'Has marketed form', 'Marketed Product' UNION ALL
            SELECT 'Clinical Pack', 'Has tradename', 'Branded Pack' UNION ALL
            SELECT 'Clinical Pack', 'Available as box', 'Clinical Pack Box' UNION ALL
            SELECT 'Clinical Pack Box', 'Has tradename', 'Branded Pack Box'
        )
        SELECT * FROM t
        UNION ALL
        SELECT c_class_2, r.reverse_relationship_id, c_class_1
        FROM t rra, dev_rxnorm.relationship r
        WHERE rra.relationship_id = r.relationship_id
    ) AS s1
),
valid_concepts_dev_rxnorm AS (
    SELECT concept_id, concept_name, concept_class_id
    FROM dev_rxnorm.concept
    WHERE vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND invalid_reason IS NULL
),
existing_relationships_dev_rxnorm AS (
    SELECT
        cr.concept_id_1,
        cr.relationship_id,
        c2.concept_class_id AS concept_class_id_2
    FROM dev_rxnorm.concept_relationship cr
    JOIN valid_concepts_dev_rxnorm vc ON cr.concept_id_1 = vc.concept_id
    JOIN dev_rxnorm.concept c2 ON cr.concept_id_2 = c2.concept_id
    WHERE cr.invalid_reason IS NULL
    AND c2.invalid_reason IS NULL
    AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
),
absent_relationships_dev_rxnorm AS (
    SELECT
        vc.concept_class_id,
        pr.relationship_id,
        pr.c_class_2,
        COUNT(DISTINCT vc.concept_id) AS concept_count
    FROM valid_concepts_dev_rxnorm vc
    CROSS JOIN possible_relationships pr
    WHERE pr.c_class_1 = vc.concept_class_id
    AND NOT EXISTS (
        SELECT 1
        FROM existing_relationships_dev_rxnorm er
        WHERE er.concept_id_1 = vc.concept_id
        AND er.relationship_id = pr.relationship_id
        AND er.concept_class_id_2 = pr.c_class_2
    )
    GROUP BY vc.concept_class_id, pr.relationship_id, pr.c_class_2
),
valid_concepts_dev_test3 AS (
    SELECT concept_id, concept_name, concept_class_id
    FROM dev_test3.concept
    WHERE vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND invalid_reason IS NULL
),
existing_relationships_dev_test3 AS (
    SELECT
        cr.concept_id_1,
        cr.relationship_id,
        c2.concept_class_id AS concept_class_id_2
    FROM dev_test3.concept_relationship cr
    JOIN valid_concepts_dev_test3 vc ON cr.concept_id_1 = vc.concept_id
    JOIN dev_test3.concept c2 ON cr.concept_id_2 = c2.concept_id
    WHERE cr.invalid_reason IS NULL
    AND c2.invalid_reason IS NULL
    AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
),
absent_relationships_dev_test3 AS (
    SELECT
        vc.concept_class_id,
        pr.relationship_id,
        pr.c_class_2,
        COUNT(DISTINCT vc.concept_id) AS concept_count
    FROM valid_concepts_dev_test3 vc
    CROSS JOIN possible_relationships pr
    WHERE pr.c_class_1 = vc.concept_class_id
    AND NOT EXISTS (
        SELECT 1
        FROM existing_relationships_dev_test3 er
        WHERE er.concept_id_1 = vc.concept_id
        AND er.relationship_id = pr.relationship_id
        AND er.concept_class_id_2 = pr.c_class_2
    )
    GROUP BY vc.concept_class_id, pr.relationship_id, pr.c_class_2
)
SELECT
    COALESCE(s1.concept_class_id, s2.concept_class_id) AS concept_class,
    COALESCE(s1.relationship_id, s2.relationship_id) || ' - ' || COALESCE(s1.c_class_2, s2.c_class_2) AS missing_connections,
    COALESCE(s1.concept_count, 0) AS count_in_dev_rxnorm,
    COALESCE(s2.concept_count, 0) AS count_in_dev_test3,
    ABS(COALESCE(s1.concept_count, 0) - COALESCE(s2.concept_count, 0)) AS delta_abs,
    CASE
        WHEN COALESCE(s2.concept_count, 0) > 0
        THEN ROUND(((COALESCE(s1.concept_count, 0) - COALESCE(s2.concept_count, 0))::FLOAT / COALESCE(s2.concept_count, 0) * 100)::NUMERIC, 2)
        ELSE NULL
    END AS delta_percent
FROM absent_relationships_dev_rxnorm s1
FULL OUTER JOIN absent_relationships_dev_test3 s2
    ON s1.concept_class_id = s2.concept_class_id
    AND s1.relationship_id = s2.relationship_id
    AND s1.c_class_2 = s2.c_class_2
ORDER BY concept_class, missing_connections;