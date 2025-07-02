-- This check compares the quantity of valid abnormal relationships between RxN/RxE concept classes in devv5 and the working schema
-- The result should not show an increase in counts

WITH normal_triplets AS (

    ----- All values that we manually checked and marked as relevant
    SELECT DISTINCT concept_class_id_1, concept_class_id_2, relationship_id
    FROM (VALUES
            ('Branded Drug', 'Branded Drug', 'Consists of'),
            ('Branded Drug', 'Branded Drug', 'Has tradename'),
            ('Branded Drug', 'Branded Drug', 'Marketed form of'),
            ('Branded Drug', 'Branded Drug', 'Tradename of'),
            ('Branded Drug', 'Branded Drug Comp', 'Has tradename'),
            ('Branded Drug', 'Marketed Product', 'Has marketed form'),
            ('Branded Drug', 'Clinical Drug', 'Marketed form of'),
            ('Branded Drug', 'Branded Drug Box', 'Available as box'),
            ('Branded Drug', 'Quant Clinical Drug', 'Has quantified form'),
            ('Branded Drug', 'Quant Clinical Drug', 'Tradename of'),
            ('Branded Drug Box', 'Branded Drug', 'Box of'),
            ('Branded Drug Box', 'Branded Drug', 'Marketed form of'),
            ('Branded Drug Box', 'Branded Drug Box', 'Has tradename'),
            ('Branded Drug Box', 'Branded Drug Box', 'Marketed form of'),
            ('Branded Drug Box', 'Branded Drug Box', 'Tradename of'),
            ('Branded Drug Box', 'Clinical Drug', 'Marketed form of'),
            ('Branded Drug Box', 'Clinical Drug Box', 'Marketed form of'),
            ('Branded Drug Box', 'Clinical Drug Box', 'Tradename of'),
            ('Branded Drug Box', 'Marketed Product', 'Has marketed form'),
            ('Branded Drug Box', 'Quant Branded Box', 'Has marketed form'),
            ('Branded Drug Box', 'Quant Branded Box', 'Has quantified form'),
            ('Branded Drug Box', 'Quant Clinical Box', 'Has quantified form'),
            ('Branded Drug Comp', 'Branded Drug', 'Tradename of'),
            ('Branded Drug Comp', 'Branded Drug Comp', 'Has tradename'),
            ('Branded Drug Comp', 'Branded Drug Comp', 'Tradename of'),
            ('Branded Drug Comp', 'Clinical Drug', 'Tradename of'),
            ('Branded Drug Comp', 'Marketed Product', 'Tradename of'),
            ('Branded Drug Comp', 'Quant Branded Drug', 'Constitutes'),
            ('Branded Drug Form', 'Branded Drug Form', 'Has tradename'),
            ('Branded Drug Form', 'Branded Drug Form', 'Tradename of'),
            ('Branded Drug Form', 'Quant Branded Drug', 'RxNorm inverse is a'),
            ('Branded Pack', 'Branded Pack Box', 'Available as box'),
            ('Branded Pack', 'Marketed Product', 'Has marketed form'),
            ('Branded Pack Box', 'Branded Pack', 'Box of'),
            ('Branded Pack Box', 'Branded Pack Box', 'Has tradename'),
            ('Branded Pack Box', 'Branded Pack Box', 'Tradename of'),
            ('Branded Pack Box', 'Clinical Drug', 'Contains'),
            ('Branded Pack Box', 'Clinical Pack Box', 'Tradename of'),
            ('Branded Pack Box', 'Quant Clinical Drug', 'Contains'),
            ('Clinical Drug', 'Branded Drug', 'Consists of'),
            ('Clinical Drug', 'Branded Drug Comp', 'Consists of'),
            ('Clinical Drug', 'Branded Drug Comp', 'Has tradename'),
            ('Clinical Drug', 'Branded Drug Form', 'RxNorm is a'),
            ('Clinical Drug', 'Clinical Drug', 'Consists of'),
            ('Clinical Drug', 'Branded Pack Box', 'Contained in'),
            ('Clinical Drug', 'Clinical Drug', 'Marketed form of'),
            ('Clinical Drug', 'Clinical Pack Box', 'Contained in'),
            ('Clinical Drug', 'Marketed Product', 'Contained in'),
            ('Clinical Drug', 'Marketed Product', 'Has marketed form'),
            ('Clinical Drug', 'Quant Branded Drug', 'Has tradename'),
            ('Clinical Drug', 'Clinical Drug Box', 'Available as box'),
            ('Clinical Drug', 'Quant Clinical Box', 'Available as box'),
            ('Clinical Drug Box', 'Branded Drug', 'Box of'),
            ('Clinical Drug Box', 'Branded Drug Box', 'Has tradename'),
            ('Clinical Drug Box', 'Clinical Drug', 'Box of'),
            ('Clinical Drug Box', 'Marketed Product', 'Has marketed form'),
            ('Clinical Drug Box', 'Quant Clinical Box', 'Has quantified form'),
            ('Clinical Drug Comp', 'Quant Clinical Drug', 'Constitutes'),
            ('Clinical Drug Form', 'Ingredient', 'Drug has drug class'),
            ('Clinical Drug Form', 'Quant Clinical Drug', 'RxNorm inverse is a'),
            ('Clinical Pack', 'Marketed Product', 'Has marketed form'),
            ('Clinical Pack', 'Clinical Pack Box', 'Available as box'),
            ('Clinical Pack Box', 'Branded Pack Box', 'Has tradename'),
            ('Clinical Pack Box', 'Clinical Drug', 'Contains'),
            ('Clinical Pack Box', 'Clinical Pack', 'Box of'),
            ('Clinical Pack Box', 'Quant Clinical Drug', 'Contains'),
            ('Ingredient', 'Clinical Drug Form', 'Drug class of drug'),
            ('Marketed Product', 'Branded Drug', 'Marketed form of'),
            ('Marketed Product', 'Branded Drug Box', 'Marketed form of'),
            ('Marketed Product', 'Branded Drug Comp', 'Has tradename'),
            ('Marketed Product', 'Branded Pack', 'Marketed form of'),
            ('Marketed Product', 'Clinical Drug', 'Contains'),
            ('Marketed Product', 'Clinical Drug', 'Marketed form of'),
            ('Marketed Product', 'Clinical Drug Box', 'Marketed form of'),
            ('Marketed Product', 'Clinical Pack', 'Marketed form of'),
            ('Marketed Product', 'Quant Branded Box', 'Marketed form of'),
            ('Marketed Product', 'Quant Branded Drug', 'Marketed form of'),
            ('Marketed Product', 'Quant Clinical Box', 'Marketed form of'),
            ('Marketed Product', 'Quant Clinical Drug', 'Contains'),
            ('Marketed Product', 'Quant Clinical Drug', 'Marketed form of'),
            ('Quant Branded Box', 'Branded Drug', 'Box of'),
            ('Quant Branded Box', 'Branded Drug', 'Marketed form of'),
            ('Quant Branded Box', 'Branded Drug Box', 'Marketed form of'),
            ('Quant Branded Box', 'Branded Drug Box', 'Quantified form of'),
            ('Quant Branded Box', 'Clinical Drug', 'Marketed form of'),
            ('Quant Branded Box', 'Clinical Drug Box', 'Marketed form of'),
            ('Quant Branded Box', 'Marketed Product', 'Has marketed form'),
            ('Quant Branded Box', 'Quant Branded Box', 'Has tradename'),
            ('Quant Branded Box', 'Quant Branded Box', 'Tradename of'),
            ('Quant Branded Box', 'Quant Branded Drug', 'Box of'),
            ('Quant Branded Box', 'Quant Clinical Box', 'Marketed form of'),
            ('Quant Branded Box', 'Quant Clinical Box', 'Tradename of'),
            ('Quant Branded Box', 'Quant Clinical Drug', 'Marketed form of'),
            ('Quant Branded Drug', 'Branded Drug', 'Marketed form of'),
            ('Quant Branded Drug', 'Branded Drug Comp', 'Consists of'),
            ('Quant Branded Drug', 'Branded Drug Form', 'RxNorm is a'),
            ('Quant Branded Drug', 'Clinical Drug', 'Marketed form of'),
            ('Quant Branded Drug', 'Clinical Drug', 'Tradename of'),
            ('Quant Branded Drug', 'Marketed Product', 'Has marketed form'),
            ('Quant Branded Drug', 'Quant Branded Drug', 'Has quantified form'),
            ('Quant Branded Drug', 'Quant Branded Drug', 'Has tradename'),
            ('Quant Branded Drug', 'Quant Branded Drug', 'Quantified form of'),
            ('Quant Branded Drug', 'Quant Branded Drug', 'Tradename of'),
            ('Quant Branded Drug', 'Quant Branded Box', 'Available as box'),
            ('Quant Branded Drug', 'Quant Clinical Drug', 'Marketed form of'),
            ('Quant Clinical Box', 'Branded Drug Box', 'Quantified form of'),
            ('Quant Clinical Box', 'Clinical Drug', 'Box of'),
            ('Quant Clinical Box', 'Clinical Drug', 'Marketed form of'),
            ('Quant Clinical Box', 'Clinical Drug Box', 'Marketed form of'),
            ('Quant Clinical Box', 'Clinical Drug Box', 'Quantified form of'),
            ('Quant Clinical Box', 'Marketed Product', 'Has marketed form'),
            ('Quant Clinical Box', 'Quant Branded Box', 'Has tradename'),
            ('Quant Clinical Box', 'Quant Branded Drug', 'Box of'),
            ('Quant Clinical Box', 'Quant Clinical Drug', 'Box of'),
            ('Quant Clinical Box', 'Quant Clinical Drug', 'Marketed form of'),
            ('Quant Clinical Drug', 'Branded Drug', 'Has tradename'),
            ('Quant Clinical Drug', 'Branded Drug', 'Quantified form of'),
            ('Quant Clinical Drug', 'Clinical Drug', 'Marketed form of'),
            ('Quant Clinical Drug', 'Clinical Drug Comp', 'Consists of'),
            ('Quant Clinical Drug', 'Clinical Drug Form', 'RxNorm is a'),
            ('Quant Clinical Drug', 'Branded Pack Box', 'Contained in'),
            ('Quant Clinical Drug', 'Clinical Pack Box', 'Contained in'),
            ('Quant Clinical Drug', 'Marketed Product', 'Contained in'),
            ('Quant Clinical Drug', 'Marketed Product', 'Has marketed form'),
            ('Quant Clinical Drug', 'Quant Clinical Box', 'Available as box'),
            ('Quant Clinical Drug', 'Quant Clinical Drug', 'Has quantified form'),
            ('Quant Clinical Drug', 'Quant Clinical Drug', 'Marketed form of'),
            ('Quant Clinical Drug', 'Quant Clinical Drug', 'Quantified form of')
        ) AS t(concept_class_id_1, concept_class_id_2, relationship_id)

    UNION

    ----- All values inside RxNorm we count for relevant
    select DISTINCT t1.concept_class_id as concept_class_id_1,
           t2.concept_class_id as concept_class_id_2,
           cr.relationship_id
    from devv5.concept_relationship cr
            join devv5.concept t1 on cr.concept_id_1 = t1.concept_id
                                            --and t1.invalid_reason is NULL
                                            and t1.vocabulary_id = 'RxNorm'
                                            --and cr.invalid_reason is null
            join devv5.concept t2 on cr.concept_id_2 = t2.concept_id
                                            --and t2.invalid_reason is NULL
                                            and t2.vocabulary_id = 'RxNorm'
),
devv5_triplet_counts AS (
    SELECT
        c1.concept_class_id AS concept_class_id_1,
        c2.concept_class_id AS concept_class_id_2,
        cr.relationship_id,
        COUNT(*) AS devv5_count
    FROM devv5.concept_relationship cr
    JOIN devv5.concept c1 ON cr.concept_id_1 = c1.concept_id
        AND c1.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                 and c1.standard_concept in ('C', 'S')
        AND c1.invalid_reason IS NULL
    JOIN devv5.concept c2 ON cr.concept_id_2 = c2.concept_id
        AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
        and c2.standard_concept in ('C', 'S')
        AND c2.invalid_reason IS NULL
    WHERE cr.invalid_reason IS NULL
         and (c1.vocabulary_id, c2.vocabulary_id) != ('RxNorm', 'RxNorm')
         and cr.relationship_id not in ('Maps to', 'Mapped from')
    GROUP BY c1.concept_class_id, c2.concept_class_id, cr.relationship_id
),
working_triplet_counts AS (
    SELECT
        c1.concept_class_id AS concept_class_id_1,
        c2.concept_class_id AS concept_class_id_2,
        cr.relationship_id,
        COUNT(*) AS working_count
    FROM concept_relationship cr
    JOIN concept c1 ON cr.concept_id_1 = c1.concept_id
        AND c1.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
        and c1.standard_concept in ('C', 'S')
        AND c1.invalid_reason IS NULL
    JOIN concept c2 ON cr.concept_id_2 = c2.concept_id
        AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
        and c2.standard_concept in ('C', 'S')
        AND c2.invalid_reason IS NULL
    WHERE cr.invalid_reason IS NULL
       and (c1.vocabulary_id, c2.vocabulary_id) != ('RxNorm', 'RxNorm')
       and cr.relationship_id not in ('Maps to', 'Mapped from')
    GROUP BY c1.concept_class_id, c2.concept_class_id, cr.relationship_id
),
anomalous_triplets AS (
    SELECT
        d.concept_class_id_1,
        d.concept_class_id_2,
        d.relationship_id,
        COALESCE(d.devv5_count, 0) AS valid_anomalous_devv5,
        COALESCE(w.working_count, 0) AS valid_anomalous_working
    FROM devv5_triplet_counts d
    LEFT JOIN working_triplet_counts w
        ON d.concept_class_id_1 = w.concept_class_id_1
        AND d.concept_class_id_2 = w.concept_class_id_2
        AND d.relationship_id = w.relationship_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM normal_triplets nt
        WHERE nt.concept_class_id_1 = d.concept_class_id_1
        AND nt.concept_class_id_2 = d.concept_class_id_2
        AND nt.relationship_id = d.relationship_id
    )
    UNION
    SELECT
        w.concept_class_id_1,
        w.concept_class_id_2,
        w.relationship_id,
        COALESCE(d.devv5_count, 0) AS valid_anomalous_devv5,
        COALESCE(w.working_count, 0) AS valid_anomalous_working
    FROM working_triplet_counts w
    LEFT JOIN devv5_triplet_counts d
        ON w.concept_class_id_1 = d.concept_class_id_1
        AND w.concept_class_id_2 = d.concept_class_id_2
        AND w.relationship_id = d.relationship_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM normal_triplets nt
        WHERE nt.concept_class_id_1 = w.concept_class_id_1
        AND nt.concept_class_id_2 = w.concept_class_id_2
        AND nt.relationship_id = w.relationship_id
    )
),
total_counts AS (
    SELECT
        COALESCE(SUM(valid_anomalous_devv5), 0) AS valid_anomalous_devv5,
        COALESCE(SUM(valid_anomalous_working), 0) AS valid_anomalous_working
    FROM anomalous_triplets
)
SELECT
    concept_class_id_1,
    concept_class_id_2,
    relationship_id,
    valid_anomalous_devv5,
    valid_anomalous_working,
    CASE
        WHEN valid_anomalous_devv5 = 0 THEN NULL
        ELSE ROUND(((valid_anomalous_working - valid_anomalous_devv5) * 100.0 / valid_anomalous_devv5), 2) || '%'
    END AS growth_percentage
FROM anomalous_triplets
UNION ALL
SELECT
    'Total' AS concept_class_id_1,
    '' AS concept_class_id_2,
    '' AS relationship_id,
    valid_anomalous_devv5,
    valid_anomalous_working,
    CASE
        WHEN valid_anomalous_devv5 = 0 THEN NULL
        ELSE ROUND(((valid_anomalous_working - valid_anomalous_devv5) * 100.0 / valid_anomalous_devv5), 2) || '%'
    END AS growth_percentage
FROM total_counts
ORDER BY concept_class_id_1, concept_class_id_2, relationship_id;