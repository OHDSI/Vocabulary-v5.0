-- 1. Our aim is to build a unique hierarchy of Procedures with CPT4 embedded in SNOMED/OMOP Ext hierarchy.
--- The script below retrieves following data:
---- 'concepts_in_hierarchy' - the number of concepts in hierarchy through 'Is a' relationships;
---- 'mapped' - the number of mapped to SNOMED/OMOP Ext./etc. concepts;
---- 'concepts_not_in_hierarchy' - the number of standard concepts that are not yet in SNOMED/OMOP Ext hierarchy.
--- The script below allows you to compare current status of hierarchy in devv5 with new status after manual work performed
--- These counts don't include classification concepts and modifiers, and also concepts mapped to other vocabularies.
--- Use this counts for analysis and renew respective numbers in https://github.com/OHDSI/Vocabulary-v5.0/wiki/Known-Issues-in-Vocabularies

WITH current_status AS (
       SELECT 'concepts_in_hierarchy' AS flag,
              count (DISTINCT cr.concept_id_1) AS count
                                FROM devv5.concept_relationship cr
                                        JOIN concept c ON cr.concept_id_1 = c.concept_id
                                        JOIN concept c1 ON cr.concept_id_2 = c1.concept_id
                               WHERE c.vocabulary_id = 'CPT4'
                                 AND c.concept_class_id = 'CPT4'
                                 AND c1.vocabulary_id IN ('SNOMED', 'OMOP Extension')
                                 AND cr.relationship_id IN ('Is a')
                                 AND cr.invalid_reason IS NULL

       UNION

       SELECT 'mapped' AS flag,
              count (DISTINCT cr.concept_id_1)
                           FROM devv5.concept_relationship cr
                                        JOIN concept c ON cr.concept_id_1 = c.concept_id
                                        JOIN concept c1 ON cr.concept_id_2 = c1.concept_id
                               WHERE c.vocabulary_id = 'CPT4'
                                 AND c.concept_class_id IN ('CPT4', 'Visit')
                                 AND c1.vocabulary_id IN ('SNOMED', 'OMOP Extension')
                                 AND cr.relationship_id IN ('Maps to')
                                 AND cr.invalid_reason IS NULL

       UNION

       SELECT 'concepts_not_in_hierarchy' AS flag,
              count (DISTINCT concept_id)
                            FROM concept
                            WHERE vocabulary_id = 'CPT4'
                                AND concept_class_id IN ('CPT4', 'Visit')
                          		AND standard_concept = 'S'
                                AND concept_id NOT IN (SELECT concept_id_1
														FROM devv5.concept_relationship cr
														   JOIN concept c ON cr.concept_id_1 = c.concept_id
														   JOIN concept c1 ON cr.concept_id_2 = c1.concept_id
															   AND c.vocabulary_id = 'CPT4'
															   AND c1.vocabulary_id IN ('SNOMED', 'OMOP Extension')
															   AND cr.relationship_id in ('Maps to', 'Is a')
															   AND cr.invalid_reason IS NULL)
),

new_status AS (
              SELECT 'concepts_in_hierarchy' AS flag,
              count (DISTINCT cr.concept_id_1) AS count
                                FROM concept_relationship cr
                                        JOIN concept c ON cr.concept_id_1 = c.concept_id
                                        JOIN concept c1 ON cr.concept_id_2 = c1.concept_id
                               WHERE c.vocabulary_id = 'CPT4'
                                 AND c.concept_class_id = 'CPT4'
                                 AND c1.vocabulary_id IN ('SNOMED', 'OMOP Extension')
                                 AND cr.relationship_id IN ('Is a')
                                 AND cr.invalid_reason IS NULL

       UNION

       SELECT 'mapped' AS flag,
              count (DISTINCT cr.concept_id_1)
                           FROM concept_relationship cr
                                        JOIN concept c ON cr.concept_id_1 = c.concept_id
                                        JOIN concept c1 ON cr.concept_id_2 = c1.concept_id
                               WHERE c.vocabulary_id = 'CPT4'
                                 AND c.concept_class_id IN ('CPT4', 'Visit')
                                 AND c1.vocabulary_id IN ('SNOMED', 'OMOP Extension')
                                 AND cr.relationship_id IN ('Maps to')
                                 AND cr.invalid_reason IS NULL

       UNION

       SELECT 'concepts_not_in_hierarchy' AS flag,
              count (DISTINCT concept_id)
                            FROM concept
                            WHERE vocabulary_id = 'CPT4'
                                AND concept_class_id IN ('CPT4', 'Visit')
                            	AND standard_concept = 'S'
                                AND concept_id NOT IN (SELECT concept_id_1
														FROM concept_relationship cr
														   JOIN concept c ON cr.concept_id_1 = c.concept_id
														   JOIN concept c1 ON cr.concept_id_2 = c1.concept_id
															   AND c.vocabulary_id = 'CPT4'
															   AND c1.vocabulary_id IN ('SNOMED', 'OMOP Extension')
															   AND cr.relationship_id IN ('Maps to', 'Is a')
															   AND cr.invalid_reason IS NULL)
)

SELECT flag,
       a.count AS current_status,
       b.count AS new_status
       FROM current_status a
	JOIN new_status b USING (flag)
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