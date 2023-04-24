-- Our aim is to build a unique hierarchy of Procedures with CPT4 embedded in SNOMED/OMOP Ext hierarchy.
--- The script below retrieves the number of concepts in hierarchy through either 'Is a' or 'Maps to' relationships against the number of concepts that are not yet in hierarchy.
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

     concepts_not_in_hierarchy AS (SELECT concept_id
                                   FROM concept
                                   WHERE concept_id NOT IN (SELECT concept_id_1
                                                            FROM concepts_in_hierarchy)
                                     AND vocabulary_id = 'CPT4'
                                     AND concept_class_id IN ('CPT4', 'Visit'))
SELECT 'concepts_in_hierarchy' AS flag,
       COUNT(concept_id_1)     AS count
FROM concepts_in_hierarchy

UNION

SELECT 'concepts_not_in_hierarchy' AS flag,
       COUNT(concept_id)
FROM concepts_not_in_hierarchy
;