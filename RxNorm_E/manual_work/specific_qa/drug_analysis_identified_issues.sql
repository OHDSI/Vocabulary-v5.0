--Standard Valid drugs with invalid drug attributes
--18332 rows
SELECT *
FROM concept c

JOIN concept_relationship r
    ON c.concept_id = r.concept_id_1
AND r.invalid_reason IS NULL
AND c.standard_concept = 'S'
AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')

JOIN concept c2
    ON c2.concept_id = r.concept_id_2
AND c2.invalid_reason IS NOT NULL
AND r.relationship_id = 'Has brand name'
AND c.concept_class_id != 'Ingredient';


--Example is here: https://github.com/OHDSI/Vocabulary-v5.0/issues/678
--20028
--Standard concepts, all belong to RxNorm Extension vocabulary
with standard_ingredients AS
    (
        SELECT *
        FROM concept c
        WHERE c.standard_concept = 'S' AND c.invalid_reason IS NULL
        AND c.concept_class_id = 'Ingredient'
        AND c.vocabulary_id IN ('RxNorm Extension', 'RxNorm')
    )

SELECT *
FROM concept c

WHERE c.concept_id NOT IN
(
    SELECT ca.descendant_concept_id
    FROM concept_ancestor ca
    JOIN standard_ingredients si
    ON si.concept_id = ca.ancestor_concept_id
    )
AND c.domain_id = 'Drug'
AND c.standard_concept = 'S'
AND c.invalid_reason IS NULL
AND c.vocabulary_id IN ('RxNorm Extension', 'RxNorm')
;



--! Analysis of dose forms
--Dose forms with corresponding dose form groups and count of associated drugs

--Each part of the query may be used separately or together

with dose_group_counts AS
(SELECT coalesce(c1.concept_id, 0) AS dose_group_id,
        coalesce(c1.concept_name, 'No dose group') AS dose_group_name,
        count(c.concept_id) AS dose_form_count

FROM concept c
LEFT JOIN concept_relationship cr
ON cr.concept_id_2 = c.concept_id AND cr.invalid_reason IS NULL AND cr.relationship_id = 'RxNorm inverse is a'
LEFT JOIN concept c1
ON c1.concept_id = cr.concept_id_1
WHERE c.concept_class_id = 'Dose Form' AND c.invalid_reason IS NULL AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
GROUP BY c1.concept_id, c1.concept_name
ORDER BY dose_form_count DESC),

    drug_counts AS
(
    SELECT c.concept_id AS dose_id,
           c.concept_name AS dose_name,
        count(c1.concept_id) AS drug_count
FROM concept c
LEFT JOIN concept_relationship cr
ON cr.concept_id_1 = c.concept_id AND cr.invalid_reason IS NULL AND cr.relationship_id = 'RxNorm dose form of'
LEFT JOIN concept c1
ON c1.concept_id = cr.concept_id_2

WHERE c.concept_class_id = 'Dose Form' AND c.invalid_reason IS NULL AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')

GROUP BY c.concept_id, c.concept_name
ORDER BY drug_count DESC
    ),

     dfg_to_dose_form AS
         (
        SELECT DISTINCT coalesce(c1.concept_id, 0) AS dose_group_id,
        coalesce(c1.concept_name, 'No dose group') AS dose_group_name,
        c.concept_id AS dose_id,
        c.concept_name AS dose_name

FROM concept c
LEFT JOIN concept_relationship cr
ON cr.concept_id_2 = c.concept_id AND cr.invalid_reason IS NULL AND cr.relationship_id = 'RxNorm inverse is a'
LEFT JOIN concept c1
ON c1.concept_id = cr.concept_id_1
WHERE c.concept_class_id = 'Dose Form' AND c.invalid_reason IS NULL AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
         )

SELECT dose_group_counts.dose_group_id, dose_group_counts.dose_group_name, dose_form_count,
       drug_counts.dose_id, drug_counts.dose_name, drug_counts.drug_count
FROM drug_counts
LEFT JOIN dfg_to_dose_form
ON drug_counts.dose_id = dfg_to_dose_form.dose_id
LEFT JOIN dose_group_counts
ON dfg_to_dose_form.dose_group_id = dose_group_counts.dose_group_id
GROUP BY dose_group_counts.dose_group_id, dose_group_counts.dose_group_name, dose_form_count, drug_counts.drug_count,
         drug_counts.dose_id, drug_counts.dose_name, drug_counts.drug_count
ORDER BY drug_count DESC, dose_id
;
