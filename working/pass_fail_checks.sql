CREATE OR REPLACE FUNCTION run_vocabulary_checks(vocabulary_names TEXT[])
RETURNS TABLE (
    check_name TEXT,
    result TEXT,
    affected_vocabs TEXT,
    comment TEXT
) AS $$
BEGIN

-- 1. Vocabulary-unspecific checks:
-- 1.1. Checks for concept table
-- 1.1.1. Concepts changed their name:
RETURN QUERY
    SELECT 'concept_name_changes' AS check_name,
           CASE WHEN EXISTS (
               SELECT 1
               FROM concept c
            JOIN prodv5.concept c2
               ON c.concept_code = c2.concept_code
                AND c.vocabulary_id = c2.vocabulary_id
                AND c.concept_name != c2.concept_name
                AND c.vocabulary_id = ANY(vocabulary_names)
           ) THEN 'warning' ELSE 'pass' END AS result,
           COALESCE ((SELECT string_agg(DISTINCT c.vocabulary_id, ', ')
                        FROM concept c
                        JOIN prodv5.concept c2
                          ON c.concept_code = c2.concept_code
                            AND c.vocabulary_id = c2.vocabulary_id
                            AND c.concept_name != c2.concept_name
                AND c.vocabulary_id = ANY(vocabulary_names)
                  ), '') AS affected_vocabs,
            CASE WHEN EXISTS (
               SELECT 1
               FROM concept c
            JOIN prodv5.concept c2
               ON c.concept_code = c2.concept_code
                AND c.vocabulary_id = c2.vocabulary_id
                AND c.concept_name != c2.concept_name
                AND c.vocabulary_id = ANY(vocabulary_names)
           ) THEN 'You can also run working/manual_checks_after_generic_update.sql' ELSE '' END AS comment
        ;

-- 1.1.2. Concepts changed their domain:
RETURN QUERY
    SELECT 'domain_changes' AS check_name,
           CASE WHEN EXISTS (
               SELECT 1
               FROM concept c
            JOIN prodv5.concept c2
               ON c.concept_code = c2.concept_code
                AND c.vocabulary_id = c2.vocabulary_id
                AND c.domain_id != c2.domain_id
                AND c.vocabulary_id = ANY(vocabulary_names)
           ) THEN 'fail' ELSE 'pass' END AS result,
           COALESCE ((SELECT string_agg(DISTINCT c.vocabulary_id, ', ')
                        FROM concept c
                        JOIN prodv5.concept c2
                          ON c.concept_code = c2.concept_code
                            AND c.vocabulary_id = c2.vocabulary_id
                            AND c.domain_id != c2.domain_id
                AND c.vocabulary_id = ANY(vocabulary_names)
                  ), '') AS affected_vocabs,
            CASE WHEN EXISTS (
               SELECT 1
               FROM concept c
            JOIN prodv5.concept c2
               ON c.concept_code = c2.concept_code
                AND c.vocabulary_id = c2.vocabulary_id
                AND c.domain_id != c2.domain_id
                AND c.vocabulary_id = ANY(vocabulary_names)
           ) THEN 'You can also run working/manual_checks_after_generic_update.sql' ELSE '' END AS comment
        ;

-- 1.2. Checks for concept_synonym table
RETURN QUERY
    SELECT 'concept_synonym_changes' AS check_name,
       CASE WHEN EXISTS (
           WITH old_syn AS (
               SELECT c.concept_code,
                      c.vocabulary_id,
                      string_agg(DISTINCT cs.language_concept_id::text, '; ' ORDER BY cs.language_concept_id::text) AS old_language_concept_id,
                      string_agg(cs.concept_synonym_name, '; ' ORDER BY cs.language_concept_id, cs.concept_synonym_name) AS old_synonym
               FROM devv5.concept c
               JOIN devv5.concept_synonym cs ON c.concept_id = cs.concept_id
               WHERE c.vocabulary_id = ANY(vocabulary_names)
               GROUP BY c.concept_code, c.vocabulary_id
           ),
           new_syn AS (
               SELECT c.concept_code,
                      c.vocabulary_id,
                      string_agg(DISTINCT cs.language_concept_id::text, '; ' ORDER BY cs.language_concept_id::text) AS new_language_concept_id,
                      string_agg(cs.concept_synonym_name, '; ' ORDER BY cs.language_concept_id, cs.concept_synonym_name) AS new_synonym
               FROM concept c
               JOIN concept_synonym cs ON c.concept_id = cs.concept_id
               WHERE c.vocabulary_id = ANY(vocabulary_names)
               GROUP BY c.concept_code, c.vocabulary_id
           )
           SELECT 1
           FROM old_syn o
           LEFT JOIN new_syn n
             ON o.concept_code = n.concept_code
            AND o.vocabulary_id = n.vocabulary_id
           WHERE
               (o.old_synonym = n.new_synonym AND o.old_language_concept_id != n.new_language_concept_id)
            OR ((o.old_synonym != n.new_synonym OR n.new_synonym IS NULL) AND o.old_language_concept_id = n.new_language_concept_id)
            OR ((o.old_synonym != n.new_synonym OR n.new_synonym IS NULL) AND o.old_language_concept_id != n.new_language_concept_id)
           LIMIT 1
       ) THEN 'fail' ELSE 'pass' END AS result,
       COALESCE((
           WITH old_syn AS (
               SELECT c.concept_code,
                      c.vocabulary_id,
                      string_agg(DISTINCT cs.language_concept_id::text, '; ' ORDER BY cs.language_concept_id::text) AS old_language_concept_id,
                      string_agg(cs.concept_synonym_name, '; ' ORDER BY cs.language_concept_id, cs.concept_synonym_name) AS old_synonym
               FROM devv5.concept c
               JOIN devv5.concept_synonym cs ON c.concept_id = cs.concept_id
               WHERE c.vocabulary_id = ANY(vocabulary_names)
               GROUP BY c.concept_code, c.vocabulary_id
           ),
           new_syn AS (
               SELECT c.concept_code,
                      c.vocabulary_id,
                      string_agg(DISTINCT cs.language_concept_id::text, '; ' ORDER BY cs.language_concept_id::text) AS new_language_concept_id,
                      string_agg(cs.concept_synonym_name, '; ' ORDER BY cs.language_concept_id, cs.concept_synonym_name) AS new_synonym
               FROM concept c
               JOIN concept_synonym cs ON c.concept_id = cs.concept_id
               WHERE c.vocabulary_id = ANY(vocabulary_names)
               GROUP BY c.concept_code, c.vocabulary_id
           )
           SELECT string_agg(DISTINCT o.vocabulary_id, ', ')
           FROM old_syn o
           LEFT JOIN new_syn n
             ON o.concept_code = n.concept_code
            AND o.vocabulary_id = n.vocabulary_id
           WHERE
               (o.old_synonym = n.new_synonym
            AND o.old_language_concept_id != n.new_language_concept_id)
            OR ((o.old_synonym != n.new_synonym OR n.new_synonym IS NULL) AND o.old_language_concept_id = n.new_language_concept_id)
            OR ((o.old_synonym != n.new_synonym OR n.new_synonym IS NULL) AND o.old_language_concept_id != n.new_language_concept_id)
       ), '') AS affected_vocabs,
       CASE WHEN EXISTS (
           WITH old_syn AS (
               SELECT c.concept_code,
                      c.vocabulary_id,
                      string_agg(DISTINCT cs.language_concept_id::text, '; ' ORDER BY cs.language_concept_id::text) AS old_language_concept_id,
                      string_agg(cs.concept_synonym_name, '; ' ORDER BY cs.language_concept_id, cs.concept_synonym_name) AS old_synonym
               FROM devv5.concept c
               JOIN devv5.concept_synonym cs ON c.concept_id = cs.concept_id
               WHERE c.vocabulary_id = ANY(vocabulary_names)
               GROUP BY c.concept_code, c.vocabulary_id
           ),
           new_syn AS (
               SELECT c.concept_code,
                      c.vocabulary_id,
                      string_agg(DISTINCT cs.language_concept_id::text, '; ' ORDER BY cs.language_concept_id::text) AS new_language_concept_id,
                      string_agg(cs.concept_synonym_name, '; ' ORDER BY cs.language_concept_id, cs.concept_synonym_name) AS new_synonym
               FROM concept c
               JOIN concept_synonym cs ON c.concept_id = cs.concept_id
               WHERE c.vocabulary_id = ANY(vocabulary_names)
               GROUP BY c.concept_code, c.vocabulary_id
           )
           SELECT 1
           FROM old_syn o
           LEFT JOIN new_syn n
             ON o.concept_code = n.concept_code
            AND o.vocabulary_id = n.vocabulary_id
           WHERE
               (o.old_synonym = n.new_synonym AND o.old_language_concept_id != n.new_language_concept_id)
            OR ((o.old_synonym != n.new_synonym OR n.new_synonym IS NULL) AND o.old_language_concept_id = n.new_language_concept_id)
            OR ((o.old_synonym != n.new_synonym OR n.new_synonym IS NULL) AND o.old_language_concept_id != n.new_language_concept_id)
           LIMIT 1
       ) THEN 'You can also run working/manual_checks_after_generic_update.sql' ELSE '' END AS comment
        ;
-- 1.3. Checks for concept_relationship table
-- 1.3.1. New concepts without mapping:
RETURN QUERY
    SELECT 'new_concepts_without_mapping' as check_name,
           CASE WHEN EXISTS(
               SELECT 1
                FROM concept a
                LEFT JOIN concept_relationship r ON a.concept_id= r.concept_id_1 AND r.invalid_reason IS NULL AND r.relationship_Id ='Maps to'
                LEFT JOIN concept b ON b.concept_id = r.concept_id_2
                LEFT JOIN prodv5.concept c ON (c.concept_code, c.vocabulary_id) = (a.concept_code, a.vocabulary_id)
                WHERE a.vocabulary_id = ANY(vocabulary_names)
                AND c.concept_id IS NULL AND b.concept_id IS NULL
           ) THEN 'fail' ELSE 'pass' END AS result,
        COALESCE ((SELECT string_agg(DISTINCT a.vocabulary_id, ', ')
            FROM concept a
            LEFT JOIN concept_relationship r ON a.concept_id= r.concept_id_1 AND r.invalid_reason IS NULL AND r.relationship_Id ='Maps to'
            LEFT JOIN concept b ON b.concept_id = r.concept_id_2
            LEFT JOIN prodv5.concept c ON (c.concept_code, c.vocabulary_id) = (a.concept_code, a.vocabulary_id)
            WHERE a.vocabulary_id = ANY(vocabulary_names)
            AND c.concept_id IS NULL AND b.concept_id IS NULL), '') AS affected_vocabs,
        CASE WHEN EXISTS(
               SELECT 1
                FROM concept a
                LEFT JOIN concept_relationship r ON a.concept_id= r.concept_id_1 AND r.invalid_reason IS NULL AND r.relationship_Id ='Maps to'
                LEFT JOIN concept b ON b.concept_id = r.concept_id_2
                LEFT JOIN prodv5.concept c ON (c.concept_code, c.vocabulary_id) = (a.concept_code, a.vocabulary_id)
                WHERE a.vocabulary_id = ANY(vocabulary_names)
                AND c.concept_id IS NULL AND b.concept_id IS NULL
           ) THEN 'You can also run working/manual_checks_after_generic_update.sql' ELSE '' END AS comment
;

-- 1.3.2. Concepts lost their mapping:
RETURN QUERY
     SELECT 'concepts_lost_mapping' as check_name,
            CASE WHEN EXISTS(
                    SELECT 1
                    FROM concept c
                             LEFT JOIN prodv5.concept_relationship cr ON c.concept_id = cr.concept_id_1
                        AND cr.relationship_id = 'Maps to'
                        AND cr.invalid_reason IS NULL
                             LEFT JOIN concept_relationship cr1 ON c.concept_id = cr1.concept_id_1
                        AND cr1.relationship_id = 'Maps to'
                        AND cr1.invalid_reason IS NULL
                    WHERE cr.concept_id_2 IS NOT NULL
                      AND cr1.concept_id_2 IS NULL
                      AND cr.concept_id_1 != cr.concept_id_2
                      AND c.vocabulary_id = ANY (vocabulary_names)
            ) THEN 'fail' ELSE 'pass' END AS result,
        COALESCE ((SELECT string_agg(DISTINCT c.vocabulary_id, ', ')
            FROM concept c
                 LEFT JOIN prodv5.concept_relationship cr ON c.concept_id = cr.concept_id_1
                        AND cr.relationship_id = 'Maps to'
                        AND cr.invalid_reason IS NULL
                             LEFT JOIN concept_relationship cr1 ON c.concept_id = cr1.concept_id_1
                        AND cr1.relationship_id = 'Maps to'
                        AND cr1.invalid_reason IS NULL
                    WHERE cr.concept_id_2 IS NOT NULL
                      AND cr1.concept_id_2 IS NULL
                      AND cr.concept_id_1 != cr.concept_id_2
                      AND c.vocabulary_id = ANY (vocabulary_names)), '') AS affected_vocabs,
         CASE WHEN EXISTS(
                    SELECT 1
                    FROM concept c
                             LEFT JOIN prodv5.concept_relationship cr ON c.concept_id = cr.concept_id_1
                        AND cr.relationship_id = 'Maps to'
                        AND cr.invalid_reason IS NULL
                             LEFT JOIN concept_relationship cr1 ON c.concept_id = cr1.concept_id_1
                        AND cr1.relationship_id = 'Maps to'
                        AND cr1.invalid_reason IS NULL
                    WHERE cr.concept_id_2 IS NOT NULL
                      AND cr1.concept_id_2 IS NULL
                      AND cr.concept_id_1 != cr.concept_id_2
                      AND c.vocabulary_id = ANY (vocabulary_names)
           ) THEN 'You can also run working/manual_checks_after_generic_update.sql' ELSE '' END AS comment
;
-- 1.3.3 Concepts are presented in CRM with a "Maps to" link, but end up with no valid "Maps to" in basic tables
 -- This check controls that concepts that are manually mapped withing the concept_relationship_manual table have Standard target concepts, and links are properly processed by the vocabulary machinery.
 RETURN QUERY
     SELECT 'mapping exists in concept_relationship_manual but not in concept_relationship' as check_name,
     CASE WHEN EXISTS(
                    SELECT 1
                    FROM concept c
                    WHERE c.vocabulary_id = ANY (vocabulary_names)
            AND EXISTS (SELECT 1
                 FROM concept_relationship_manual crm
                 WHERE c.concept_code = crm.concept_code_1
                     AND c.vocabulary_id = crm.vocabulary_id_1
                     AND crm.relationship_id = 'Maps to' AND crm.invalid_reason IS NULL)
            AND NOT EXISTS (SELECT 1
                 FROM concept_relationship cr
                 WHERE c.concept_id = cr.concept_id_1
                     AND cr.relationship_id = 'Maps to'
                     AND cr.invalid_reason IS NULL)
            ) THEN 'fail' ELSE 'pass' END AS result,
     COALESCE ((SELECT string_agg(DISTINCT c.vocabulary_id, ', ')
                    FROM concept c
                    WHERE c.vocabulary_id = ANY (vocabulary_names)
            AND EXISTS (SELECT 1
                 FROM concept_relationship_manual crm
                 WHERE c.concept_code = crm.concept_code_1
                     AND c.vocabulary_id = crm.vocabulary_id_1
                     AND crm.relationship_id = 'Maps to' AND crm.invalid_reason IS NULL)
            AND NOT EXISTS (SELECT 1
                 FROM concept_relationship cr
                 WHERE c.concept_id = cr.concept_id_1
                     AND cr.relationship_id = 'Maps to'
                     AND cr.invalid_reason IS NULL)), '') AS affected_vocabs,
     CASE WHEN EXISTS(
                    SELECT 1
                    FROM concept c
                    WHERE c.vocabulary_id = ANY (vocabulary_names)
            AND EXISTS (SELECT 1
                 FROM concept_relationship_manual crm
                 WHERE c.concept_code = crm.concept_code_1
                     AND c.vocabulary_id = crm.vocabulary_id_1
                     AND crm.relationship_id = 'Maps to' AND crm.invalid_reason IS NULL)
            AND NOT EXISTS (SELECT 1
                 FROM concept_relationship cr
                 WHERE c.concept_id = cr.concept_id_1
                     AND cr.relationship_id = 'Maps to'
                     AND cr.invalid_reason IS NULL)
           ) THEN 'Run
SELECT *
FROM concept c
WHERE c.vocabulary_id IN (:your_vocabs)
AND EXISTS (SELECT 1
FROM concept_relationship_manual crm
WHERE c.concept_code = crm.concept_code_1
AND c.vocabulary_id = crm.vocabulary_id_1
AND crm.relationship_id = ''Maps to'' AND crm.invalid_reason IS NULL)
AND NOT EXISTS (SELECT 1
FROM concept_relationship cr
WHERE c.concept_id = cr.concept_id_1
AND cr.relationship_id = ''Maps to''
AND cr.invalid_reason IS NULL)
;' ELSE '' END AS comment
 ;

-- 1.3.4. Concepts that have a 'Maps to value' link without a valid 'Maps to' link:
RETURN QUERY
     SELECT '''Maps to value'' without valid ''Maps to''' as check_name,
     CASE WHEN EXISTS(
                    SELECT 1
                    FROM concept c
                    WHERE c.vocabulary_id = ANY (vocabulary_names)
            AND EXISTS (SELECT 1
                 FROM concept_relationship cr
                 WHERE c.concept_id = cr.concept_id_1
                 AND cr.relationship_id = 'Maps to value'
                 AND cr.invalid_reason IS NULL
            )
            AND NOT EXISTS (SELECT 1
                            FROM concept_relationship cr2
                            WHERE c.concept_id = cr2.concept_id_1
                            AND cr2.relationship_id = 'Maps to'
                            AND cr2.invalid_reason IS NULL)
     ) THEN 'fail' ELSE 'pass' END AS result,
    COALESCE((SELECT string_agg(DISTINCT c.vocabulary_id, ', ')
                    FROM concept c
                    WHERE c.vocabulary_id = ANY (vocabulary_names)
            AND EXISTS (SELECT 1
                 FROM concept_relationship cr
                 WHERE c.concept_id = cr.concept_id_1
                 AND cr.relationship_id = 'Maps to value'
                 AND cr.invalid_reason IS NULL
            )
            AND NOT EXISTS (SELECT 1
                            FROM concept_relationship cr2
                            WHERE c.concept_id = cr2.concept_id_1
                            AND cr2.relationship_id = 'Maps to'
                            AND cr2.invalid_reason IS NULL)), ''
    ) AS affected_vocabs,
    CASE WHEN EXISTS(
                    SELECT 1
                    FROM concept c
                    WHERE c.vocabulary_id = ANY (vocabulary_names)
            AND EXISTS (SELECT 1
                 FROM concept_relationship cr
                 WHERE c.concept_id = cr.concept_id_1
                 AND cr.relationship_id = 'Maps to value'
                 AND cr.invalid_reason IS NULL
            AND NOT EXISTS (SELECT 1
                            FROM concept_relationship cr2
                            WHERE c.concept_id = cr2.concept_id_1
                            AND cr2.relationship_id = 'Maps to'
                            AND cr2.invalid_reason IS NULL)
            )
    ) THEN 'Run SELECT *
           FROM concept c
                    WHERE c.vocabulary_id IN (:your_vocab)
            AND EXISTS (SELECT 1
                 FROM concept_relationship cr
                 WHERE c.concept_id = cr.concept_id_1
                 AND cr.relationship_id = ''Maps to value''
                 AND cr.invalid_reason IS NULL
            AND NOT EXISTS (SELECT 1
                            FROM concept_relationship cr2
                            WHERE c.concept_id = cr2.concept_id_1
                            AND cr2.relationship_id = ''Maps to''
                            AND cr2.invalid_reason IS NULL' ELSE '' END AS comment;
-- 2. Vocabulary-specific checks:
END;
$$ LANGUAGE plpgsql;