WITH pathological_triplets AS (
    SELECT concept_class_id_1, concept_class_id_2, relationship_id
    FROM (VALUES
        ('Branded Drug', 'Branded Drug', 'Constitutes'),
        ('Branded Drug', 'Branded Drug', 'Has marketed form'),
        ('Branded Drug', 'Branded Drug Box', 'Has marketed form'),
        ('Branded Drug', 'Clinical Drug', 'Constitutes'),
        ('Branded Drug', 'Quant Branded Box', 'Has marketed form'),
        ('Branded Drug', 'Clinical Drug Box', 'Available as box'),
        ('Branded Drug', 'Quant Branded Box', 'Available as box'),
        ('Branded Drug', 'Quant Branded Drug', 'Has marketed form'),
        ('Branded Drug Box', 'Branded Drug Box', 'Has marketed form'),
        ('Branded Drug Comp', 'Clinical Drug', 'Constitutes'),
        ('Clinical Drug', 'Branded Drug Form', 'RxNorm is a'),
        ('Clinical Drug', 'Clinical Drug', 'Constitutes'),
        ('Clinical Drug', 'Clinical Drug', 'Has marketed form'),
        ('Clinical Drug', 'Branded Drug', 'Has marketed form'),
        ('Clinical Drug', 'Branded Drug Box', 'Has marketed form'),
        ('Clinical Drug', 'Quant Branded Box', 'Has marketed form'),
        ('Clinical Drug', 'Quant Branded Drug', 'Has marketed form'),
        ('Clinical Drug', 'Quant Clinical Box', 'Has marketed form'),
        ('Clinical Drug', 'Quant Clinical Drug', 'Has marketed form'),
        ('Clinical Drug Box', 'Branded Drug Box', 'Has marketed form'),
        ('Clinical Drug Box', 'Quant Clinical Box', 'Has marketed form'),
        ('Clinical Drug Box', 'Quant Branded Box', 'Has marketed form'),
        ('Quant Branded Drug', 'Quant Clinical Box', 'Available as box'),
        ('Quant Clinical Box', 'Quant Branded Box', 'Has marketed form'),
        ('Quant Clinical Drug', 'Quant Clinical Drug', 'Has marketed form'),
        ('Quant Clinical Drug', 'Quant Branded Box', 'Has marketed form'),
        ('Quant Clinical Drug', 'Quant Branded Drug', 'Has marketed form'),
        ('Quant Clinical Drug', 'Quant Clinical Box', 'Has marketed form')
    ) AS t(concept_class_id_1, concept_class_id_2, relationship_id)
),
devv5_triplet_counts AS (
    SELECT
        pt.concept_class_id_1,
        pt.concept_class_id_2,
        pt.relationship_id,
        COUNT(*) AS devv5_count
    FROM devv5.concept_relationship cr
    JOIN devv5.concept c1 ON cr.concept_id_1 = c1.concept_id
        AND c1.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
        AND c1.invalid_reason IS NULL
    JOIN devv5.concept c2 ON cr.concept_id_2 = c2.concept_id
        AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
        AND c2.invalid_reason IS NULL
    JOIN pathological_triplets pt ON
        c1.concept_class_id = pt.concept_class_id_1
        AND c2.concept_class_id = pt.concept_class_id_2
        AND cr.relationship_id = pt.relationship_id
    WHERE cr.invalid_reason IS NULL
    GROUP BY pt.concept_class_id_1, pt.concept_class_id_2, pt.relationship_id
),
working_triplet_counts AS (
    SELECT
        pt.concept_class_id_1,
        pt.concept_class_id_2,
        pt.relationship_id,
        COUNT(*) AS working_count
    FROM concept_relationship cr
    JOIN concept c1 ON cr.concept_id_1 = c1.concept_id
        AND c1.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
        AND c1.invalid_reason IS NULL
    JOIN concept c2 ON cr.concept_id_2 = c2.concept_id
        AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
        AND c2.invalid_reason IS NULL
    JOIN pathological_triplets pt ON
        c1.concept_class_id = pt.concept_class_id_1
        AND c2.concept_class_id = pt.concept_class_id_2
        AND cr.relationship_id = pt.relationship_id
    WHERE cr.invalid_reason IS NULL
    GROUP BY pt.concept_class_id_1, pt.concept_class_id_2, pt.relationship_id
),
triplet_details AS (
    SELECT
        pt.concept_class_id_1,
        pt.concept_class_id_2,
        pt.relationship_id,
        COALESCE(d.devv5_count, 0) AS valid_anomalous_devv5,
        COALESCE(w.working_count, 0) AS valid_anomalous_working
    FROM pathological_triplets pt
    LEFT JOIN devv5_triplet_counts d
        ON pt.concept_class_id_1 = d.concept_class_id_1
        AND pt.concept_class_id_2 = d.concept_class_id_2
        AND pt.relationship_id = d.relationship_id
    LEFT JOIN working_triplet_counts w
        ON pt.concept_class_id_1 = w.concept_class_id_1
        AND pt.concept_class_id_2 = w.concept_class_id_2
        AND pt.relationship_id = w.relationship_id
),
total_counts AS (
    SELECT
        COALESCE(SUM(d.devv5_count), 0) AS valid_anomalous_devv5,
        COALESCE(SUM(w.working_count), 0) AS valid_anomalous_working
    FROM devv5_triplet_counts d
    FULL JOIN working_triplet_counts w
        ON d.concept_class_id_1 = w.concept_class_id_1
        AND d.concept_class_id_2 = w.concept_class_id_2
        AND d.relationship_id = w.relationship_id
)
SELECT
    concept_class_id_1 AS concept_class_id_1,
    concept_class_id_2 AS concept_class_id_2,
    relationship_id AS relationship_id,
    valid_anomalous_devv5,
    valid_anomalous_working,
    CASE
        WHEN valid_anomalous_devv5 = 0 THEN NULL
        ELSE ROUND(((valid_anomalous_working - valid_anomalous_devv5) * 100.0 / valid_anomalous_devv5), 2) || '%'
    END AS growth_percentage
FROM triplet_details
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
