--Checks after generic
--1. All concepts from the group have the same mapping:
--! NB devv5, dev_icd10.icd_cde_source are used in the current implementation, correct schemas accordingly
WITH groups AS
    (
        SELECT DISTINCT s.source_code, s.source_vocabulary_id, c.concept_id, s.group_id
        FROM dev_icd10.icd_cde_source s
        JOIN devv5.concept c
        ON (c.concept_code, c.vocabulary_id) = (s.source_code, s.source_vocabulary_id)
    ),

    mapping_groups AS
    (
        SELECT cr.concept_id_1, g.group_id,
               array_agg(cr.relationship_id ORDER BY cr.concept_id_2) AS map_rel,
               array_agg(cr.concept_id_2 ORDER BY cr.concept_id_2) AS map_id
        FROM devv5.concept_relationship cr
        JOIN groups g
            ON g.concept_id = cr.concept_id_1
            AND cr.invalid_reason IS NULL AND cr.relationship_id IN ('Maps to', 'Maps to value')
        GROUP BY cr.concept_id_1, group_id
    )

SELECT concept_id_1, group_id, map_rel, map_id
FROM mapping_groups mg
WHERE EXISTS(
    SELECT 1 FROM mapping_groups mg1
    WHERE mg.group_id = mg1.group_id
    AND (mg1.map_rel, mg1.map_id) != (mg.map_rel, mg.map_id)
          )
ORDER BY group_id;

--2.Check all the community contributions were included
WITH cc AS
(SELECT
cc.source_code,
cc.source_code_description,
cc.source_vocabulary_id,
string_agg(cc.relationship_id, '-' ORDER BY cc.relationship_id, cc.source_code, cc.source_vocabulary_id) as cc_relationship_id,
string_agg (cc.target_concept_code, '-' ORDER BY cc.relationship_id, cc.source_code, cc.source_vocabulary_id) as cc_target_concept_code,
string_agg(cc.target_concept_name, '-' ORDER BY cc.relationship_id, cc.source_code, cc.source_vocabulary_id) as cc_target_concept_name
FROM dev_icd10.icd_community_contribution cc
GROUP BY cc.source_code, cc.source_code_description, cc.source_vocabulary_id),

new_map AS (
SELECT a.concept_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) as relationship_agg,
       string_agg (CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>' ELSE b.concept_code END, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS code_agg,
       string_agg (case when a.concept_id = b.concept_id THEN '<Mapped to itself>' else b.concept_name END, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS name_agg
FROM concept a
LEFT JOIN concept_relationship r ON a.concept_id = concept_id_1 and r.relationship_id IN ('Maps to', 'Maps to value') AND r.invalid_reason is null
LEFT JOIN concept b ON b.concept_id = concept_id_2
WHERE (a.concept_code, a.vocabulary_id) IN (SELECT source_code, source_vocabulary_id FROM dev_icd10.icd_community_contribution)
    --and a.invalid_reason is null --to exclude invalid concepts
GROUP BY a.concept_id, a.vocabulary_id, a.concept_class_id, a.standard_concept, a.concept_code, a.concept_name
)
,
old_map AS (
SELECT a.concept_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) AS relationship_agg,
       string_agg (CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>' ELSE b.concept_code END, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) as code_agg,
       string_agg (CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>' ELSE b.concept_name end, '-/-' ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id) as name_agg
FROM devv5.concept a
LEFT JOIN devv5.concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id IN ('Maps to', 'Maps to value') and r.invalid_reason is null
LEFT JOIN devv5.concept b on b.concept_id = concept_id_2
WHERE (a.concept_code, a.vocabulary_id) in (SELECT source_code, source_vocabulary_id FROM dev_icd10.icd_community_contribution)
    --and a.invalid_reason is null --to exclude invalid concepts
GROUP BY a.concept_id, a.vocabulary_id, a.concept_class_id, a.standard_concept, a.concept_code, a.concept_name
)
SELECT DISTINCT
       cc.source_code,
       cc.source_code_description,
       cc.source_vocabulary_id,
       cc.cc_relationship_id,
       cc.cc_target_concept_code,
       cc.cc_target_concept_name,
       a.relationship_agg as old_relat_agg,
       a.code_agg as old_code_agg,
       a.name_agg as old_name_agg,
       b.relationship_agg as new_relat_agg,
       b.code_agg as new_code_agg,
       b.name_agg as new_name_agg
FROM cc JOIN old_map a ON cc.source_code = a.concept_code AND cc.source_vocabulary_id = a.vocabulary_id
JOIN new_map b on cc.source_code = b.concept_code AND cc.source_vocabulary_id = b.vocabulary_id AND
                  ((coalesce (cc.cc_target_concept_code, '') != coalesce (b.code_agg, '')) OR (coalesce (cc_relationship_id, '') != coalesce (b.relationship_agg, '')))
ORDER BY cc.source_code
;
