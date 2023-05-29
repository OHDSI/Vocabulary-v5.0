-- 1. Our aim is to build a unique hierarchy of Procedures with CPT4 embedded in SNOMED/OMOP Ext hierarchy.
--- The script below retrieves following data:
---- 'concepts_in_hierarchy' - the number of concepts in hierarchy through 'Is a' relationships;
---- 'mapped_concepts' - the number of mapped to SNOMED/OMOP Ext. concepts;
---- 'concepts_not_in_hierarchy' - the number of concepts that are not yet in hierarchy.
--- These counts don't include classification concepts and modifiers, and also concepts mapped to other vocabularies.
--- Use this counts for analysis and renew respective numbers in https://github.com/OHDSI/Vocabulary-v5.0/wiki/Known-Issues-in-Vocabularies

WITH concepts_in_hierarchy AS (SELECT DISTINCT cr.concept_id_1
                                FROM concept_relationship cr
                                        JOIN concept c ON cr.concept_id_1 = c.concept_id
                                        JOIN concept c1 ON cr.concept_id_2 = c1.concept_id
                               WHERE c.vocabulary_id = 'CPT4'
                                 AND c.concept_class_id = 'CPT4'
                                 AND c1.vocabulary_id IN ('SNOMED', 'OMOP Extension')
                                 AND cr.relationship_id IN ('Is a', 'Maps to')
                                 AND cr.invalid_reason IS NULL),

    mapped_to_snomed as (SELECT DISTINCT cr.concept_id_1
                           FROM concept_relationship cr
                                        JOIN concept c ON cr.concept_id_1 = c.concept_id
                                        JOIN concept c1 ON cr.concept_id_2 = c1.concept_id
                               WHERE c.vocabulary_id = 'CPT4'
                                 AND c.concept_class_id = 'CPT4'
                                 AND c1.vocabulary_id IN ('SNOMED', 'OMOP Extension')
                                 AND cr.relationship_id IN ('Maps to')
                                 AND cr.invalid_reason IS NULL),

     concepts_not_in_hierarchy AS (SELECT concept_id
                                   FROM concept
                                   WHERE concept_id NOT IN (SELECT concept_id_1
                                                            FROM concepts_in_hierarchy)
                                     AND vocabulary_id = 'CPT4'
                                     AND standard_concept = 'S'
                                     AND concept_class_id IN ('CPT4', 'Visit'))
SELECT 'concepts_in_hierarchy' AS flag,
       COUNT(concept_id_1)     AS count
FROM concepts_in_hierarchy

UNION

SELECT 'mapped_to_snomed'    AS flag,
       COUNT(concept_id_1)  AS count
FROM mapped_to_snomed

UNION

SELECT 'concepts_not_in_hierarchy' AS flag,
       COUNT(concept_id)
FROM concepts_not_in_hierarchy
;

-- 2. In CPT4 concepts may migrate between categories and acquire new concept_code. These changes are made in source.
--- According to the existing logic both concepts remain standard and valid with the only difference of added "(Deprecated)" to the old concept_name
--- These semantic duplicates should be mapped to concepts with new concept_codes and destandardized.
SELECT c1.concept_code AS old_code,
       c1.concept_name AS old_name,
       c1.domain_id AS old_domain,
       c2.concept_code AS new_code,
       c2.concept_name AS new_name,
       c2.domain_id AS new_domain
FROM concept c1
         JOIN concept c2 ON c1.concept_name = c2.concept_name || ' (Deprecated)'
WHERE c1.vocabulary_id = 'CPT4'
  AND c1.standard_concept = 'S'
  AND c1.invalid_reason IS NULL
  AND c2.vocabulary_id = 'CPT4'
  AND c2.standard_concept = 'S'
  AND c2.invalid_reason IS NULL
  AND c1.concept_class_id = 'CPT4';