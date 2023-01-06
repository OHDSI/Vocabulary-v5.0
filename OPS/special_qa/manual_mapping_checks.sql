-- 1-to-many mapping to descendant and its ancestor
--* We expect this check to return nothing.

SELECT a.source_code,
        a.source_code_description,
        a.to_value,
        a.target_concept_id as descendant_concept_id,
        a.target_concept_code as descendant_concept_code,
        a.target_concept_name as descendant_concept_name,
        a.target_vocabulary_id as descendant_vocabulary_id,
        b.target_concept_id as ancestor_concept_id,
        b.target_concept_code as ancestor_concept_code,
        b.target_concept_name as ancestor_concept_name,
        b.target_vocabulary_id as ancestor_vocabulary_id
    FROM dev_ops.ops_mapped a
    JOIN dev_ops.ops_mapped b on a.source_code = b.source_code
    JOIN devv5.concept_ancestor ca on a.target_concept_id = ca.descendant_concept_id
         AND b.target_concept_id = ca.ancestor_concept_id
WHERE a.target_concept_id != b.target_concept_id
;