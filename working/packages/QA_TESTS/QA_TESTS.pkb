CREATE OR REPLACE PACKAGE BODY DEVV5.QA_TESTS
/*
    CREATE TABLE DEV_SUMMARY
    (
       table_name         VARCHAR2 (100),
       vocabulary_id_1    VARCHAR2 (100),
       vocabulary_id_2    VARCHAR2 (100),
       concept_class_id   VARCHAR2 (100),
       relationship_id    VARCHAR2 (100),
       invalid_reason     VARCHAR2 (10),
       cnt                NUMBER,
       cnt_delta          NUMBER
    );
 */
IS
    PROCEDURE create_dev_table
    IS
        z   NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO z
          FROM user_tables
         WHERE table_name = 'DEV_SUMMARY';

        IF z = 0
        THEN
            EXECUTE IMMEDIATE 'CREATE TABLE DEV_SUMMARY AS SELECT * FROM DEVV5.DEV_SUMMARY WHERE 1=0';
        END IF;
    END;

    PROCEDURE purge_cache
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        create_dev_table;

        EXECUTE IMMEDIATE 'TRUNCATE TABLE DEV_SUMMARY';
    END;

    FUNCTION get_summary (table_name IN VARCHAR2, pCompareWith IN VARCHAR2 DEFAULT 'PRODV5')
        RETURN rep_t_GetSummary
    IS
        Res                    rep_t_GetSummary := rep_t_GetSummary ();

        z                      NUMBER;
        iTable_name   CONSTANT VARCHAR2 (100) := SUBSTR (LOWER (table_name), 0, 100);
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF iTable_name NOT IN ('concept', 'concept_relationship', 'concept_ancestor')
        THEN
            raise_application_error (-20001, 'WRONG_TABLE_NAME');
        END IF;

        create_dev_table;

        SELECT COUNT (*) INTO z FROM DEV_SUMMARY;

        --fill the table if it empty (caching)
        IF z = 0
        THEN
            --summary for 'concept'
            EXECUTE IMMEDIATE '
            INSERT INTO DEV_SUMMARY
                  SELECT ''concept'' AS table_name,
                         c.vocabulary_id,
                         NULL,
                         concept_class_id,
                         NULL AS relationship_id,
                         invalid_reason,
                         COUNT (*) AS cnt,
                         NULL AS cnt_delta
                    FROM '     || pCompareWith || '.concept c
                GROUP BY c.vocabulary_id, concept_class_id, invalid_reason';

            MERGE INTO DEV_SUMMARY t1
                 USING (  SELECT 'concept' AS table_name,
                                 c.vocabulary_id AS vocabulary_id_1,
                                 NULL,
                                 concept_class_id,
                                 NULL AS relationship_id,
                                 invalid_reason,
                                 COUNT (*) AS cnt,
                                 NULL AS cnt_delta
                            FROM concept c
                        GROUP BY c.vocabulary_id, concept_class_id, invalid_reason) t2
                    ON (    t1.table_name = t2.table_name
                        AND t1.vocabulary_id_1 = t2.vocabulary_id_1
                        AND t1.concept_class_id = t2.concept_class_id
                        AND NVL (t1.invalid_reason, 'X') = NVL (t2.invalid_reason, 'X'))
            WHEN MATCHED
            THEN
                UPDATE SET t1.cnt_delta = t2.cnt - t1.cnt
                         WHERE t1.cnt_delta IS NULL AND t1.table_name = 'concept'
            WHEN NOT MATCHED
            THEN
                INSERT     VALUES ('concept',
                                   t2.vocabulary_id_1,
                                   NULL,
                                   t2.concept_class_id,
                                   NULL,
                                   t2.invalid_reason,
                                   NULL,
                                   t2.cnt);

            --summary for 'concept_relationship'
            EXECUTE IMMEDIATE '
            INSERT INTO DEV_SUMMARY
                  SELECT ''concept_relationship'' AS table_name,
                         c1.vocabulary_id,
                         c2.vocabulary_id,
                         NULL AS concept_class_id,
                         r.relationship_id,
                         r.invalid_reason,
                         COUNT (*) AS cnt,
                         NULL AS cnt_delta
                    FROM '     || pCompareWith || '.concept c1, ' || pCompareWith || '.concept c2, ' || pCompareWith || '.concept_relationship r
                   WHERE c1.concept_id = r.concept_id_1 AND c2.concept_id = r.concept_id_2
                GROUP BY c1.vocabulary_id,
                         c2.vocabulary_id,
                         r.relationship_id,
                         r.invalid_reason';

            MERGE INTO DEV_SUMMARY t1
                 USING (  SELECT 'concept_relationship' AS table_name,
                                 c1.vocabulary_id AS vocabulary_id_1,
                                 c2.vocabulary_id AS vocabulary_id_2,
                                 NULL AS concept_class_id,
                                 r.relationship_id,
                                 r.invalid_reason,
                                 COUNT (*) AS cnt,
                                 NULL AS cnt_delta
                            FROM concept c1, concept c2, concept_relationship r
                           WHERE c1.concept_id = r.concept_id_1 AND c2.concept_id = r.concept_id_2
                        GROUP BY c1.vocabulary_id,
                                 c2.vocabulary_id,
                                 r.relationship_id,
                                 r.invalid_reason) t2
                    ON (    t1.table_name = t2.table_name
                        AND t1.vocabulary_id_1 = t2.vocabulary_id_1
                        AND t1.vocabulary_id_2 = t2.vocabulary_id_2
                        AND t1.relationship_id = t2.relationship_id
                        AND NVL (t1.invalid_reason, 'X') = NVL (t2.invalid_reason, 'X'))
            WHEN MATCHED
            THEN
                UPDATE SET t1.cnt_delta = t2.cnt - t1.cnt
                         WHERE t1.cnt_delta IS NULL AND t1.table_name = 'concept_relationship'
            WHEN NOT MATCHED
            THEN
                INSERT     VALUES ('concept_relationship',
                                   t2.vocabulary_id_1,
                                   t2.vocabulary_id_2,
                                   NULL,
                                   t2.relationship_id,
                                   t2.invalid_reason,
                                   NULL,
                                   t2.cnt);

            --summary for 'concept_ancestor'
            EXECUTE IMMEDIATE '
            INSERT INTO DEV_SUMMARY
                  SELECT ''concept_ancestor'' AS table_name,
                         c.vocabulary_id,
                         NULL,
                         NULL AS concept_class_id,
                         NULL AS relationship_id,
                         NULL AS invalid_reason,
                         COUNT (*) AS cnt,
                         NULL AS cnt_delta
                    FROM '     || pCompareWith || '.concept c, ' || pCompareWith || '.concept_ancestor ca
                   WHERE c.concept_id = CA.ANCESTOR_CONCEPT_ID
                GROUP BY c.vocabulary_id';

            MERGE INTO DEV_SUMMARY t1
                 USING (  SELECT 'concept_ancestor' AS table_name,
                                 c.vocabulary_id AS vocabulary_id_1,
                                 NULL,
                                 NULL AS concept_class_id,
                                 NULL AS relationship_id,
                                 NULL AS invalid_reason,
                                 COUNT (*) AS cnt,
                                 NULL AS cnt_delta
                            FROM concept c, concept_ancestor ca
                           WHERE c.concept_id = CA.ANCESTOR_CONCEPT_ID
                        GROUP BY c.vocabulary_id) t2
                    ON (t1.table_name = t2.table_name AND t1.vocabulary_id_1 = t2.vocabulary_id_1)
            WHEN MATCHED
            THEN
                UPDATE SET t1.cnt_delta = t2.cnt - t1.cnt
                         WHERE t1.cnt_delta IS NULL AND t1.table_name = 'concept_ancestor'
            WHEN NOT MATCHED
            THEN
                INSERT     VALUES ('concept_ancestor',
                                   t2.vocabulary_id_1,
                                   NULL,
                                   NULL,
                                   NULL,
                                   NULL,
                                   NULL,
                                   t2.cnt);

            COMMIT;
        END IF;


        IF iTable_name = 'concept'
        THEN
            FOR R IN (SELECT ds.vocabulary_id_1,
                             ds.concept_class_id,
                             ds.invalid_reason,
                             COALESCE (ds.cnt_delta, -cnt) AS cnt_delta
                        FROM DEV_SUMMARY ds
                       WHERE COALESCE (ds.cnt_delta, -cnt) <> 0 AND ds.table_name = iTable_name)
            LOOP
                Res.EXTEND;
                Res (Res.LAST) :=
                    rep_GetSummary (R.vocabulary_id_1,
                                    NULL,
                                    R.concept_class_id,
                                    NULL,
                                    R.invalid_reason,
                                    R.cnt_delta);
            END LOOP;
        ELSIF iTable_name = 'concept_relationship'
        THEN
            FOR R IN (SELECT ds.vocabulary_id_1,
                             ds.vocabulary_id_2,
                             ds.relationship_id,
                             ds.invalid_reason,
                             COALESCE (ds.cnt_delta, -cnt) AS cnt_delta
                        FROM DEV_SUMMARY ds
                       WHERE COALESCE (ds.cnt_delta, -cnt) <> 0 AND ds.table_name = iTable_name)
            LOOP
                Res.EXTEND;
                Res (Res.LAST) :=
                    rep_GetSummary (R.vocabulary_id_1,
                                    R.vocabulary_id_2,
                                    NULL,
                                    R.relationship_id,
                                    R.invalid_reason,
                                    R.cnt_delta);
            END LOOP;
        ELSIF iTable_name = 'concept_ancestor'
        THEN
            FOR R IN (SELECT ds.vocabulary_id_1, COALESCE (ds.cnt_delta, -cnt) AS cnt_delta
                        FROM DEV_SUMMARY ds
                       WHERE COALESCE (ds.cnt_delta, -cnt) <> 0 AND ds.table_name = iTable_name)
            LOOP
                Res.EXTEND;
                Res (Res.LAST) :=
                    rep_GetSummary (R.vocabulary_id_1,
                                    NULL,
                                    NULL,
                                    NULL,
                                    NULL,
                                    R.cnt_delta);
            END LOOP;
        END IF;


        RETURN Res;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            RAISE;
    END;

    FUNCTION get_checks (check_id IN NUMBER DEFAULT NULL)
        RETURN rep_t_GetChecks
    IS
        Res   rep_t_GetChecks := rep_t_GetChecks ();



        CURSOR C
        IS
            WITH t
                 AS (SELECT rel_id, CASE WHEN rel_id = direct_mapping THEN 1 ELSE 0 END AS direct_mapping
                       FROM (SELECT relationship_id, reverse_relationship_id, relationship_id AS direct_mapping
                               FROM relationship
                              WHERE relationship_id IN ('Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept poss_eq to',
                                                        'Concept was_a to',
                                                        'Maps to'))
                            UNPIVOT
                                (rel_id FOR relationship_ids IN (relationship_id, reverse_relationship_id)))
            --relationships cycle
            SELECT 1 check_id, r.*
              FROM concept_relationship r, concept_relationship r_int
             WHERE     r.invalid_reason IS NULL
                   AND r_int.concept_id_1 = r.concept_id_2
                   AND r_int.concept_id_2 = r.concept_id_1
                   AND r.concept_id_1 <> r.concept_id_2
                   AND r_int.relationship_id = r.relationship_id
                   AND r_int.invalid_reason IS NULL
                   AND NVL (check_id, 1) = 1
            UNION ALL
            --opposing relationships between same pair of concepts
            SELECT 2 check_id, r.*
              FROM concept_relationship r, concept_relationship r_int, relationship rel
             WHERE     r.invalid_reason IS NULL
                   AND r.relationship_id = rel.relationship_id
                   AND r_int.concept_id_1 = r.concept_id_1
                   AND r_int.concept_id_2 = r.concept_id_2
                   AND r.concept_id_1 <> r.concept_id_2
                   AND r_int.relationship_id = rel.reverse_relationship_id
                   AND r_int.invalid_reason IS NULL
                   AND NVL (check_id, 2) = 2
            UNION ALL
            --relationships without reverse
            SELECT 3 check_id, r.*
              FROM concept_relationship r, relationship rel
             WHERE     r.relationship_id = rel.relationship_id
                   AND r.concept_id_1 <> r.concept_id_2
                   AND NOT EXISTS
                           (SELECT 1
                              FROM concept_relationship r_int
                             WHERE r_int.relationship_id = rel.reverse_relationship_id AND r_int.concept_id_1 = r.concept_id_2 AND r_int.concept_id_2 = r.concept_id_1)
                   AND NVL (check_id, 3) = 3
            UNION ALL
            --replacement relationships between different vocabularies (exclude RxNorm to RxNorm Ext OR RxNorm Ext to RxNorm replacement relationships)
            SELECT 4 check_id, r.*
              FROM concept_relationship r, concept c1, concept c2
             WHERE     r.invalid_reason IS NULL
                   AND r.concept_id_1 <> r.concept_id_2
                   AND c1.concept_id = r.concept_id_1
                   AND c2.concept_id = r.concept_id_2
                   AND c1.vocabulary_id <> c2.vocabulary_id
                   AND NOT (c1.vocabulary_id IN ('RxNorm', 'RxNorm Extension') AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension'))
                   AND r.relationship_id IN (SELECT rel_id
                                               FROM t
                                              WHERE rel_id NOT IN ('Maps to', 'Mapped from'))
                   AND NVL (check_id, 4) = 4
            UNION ALL
            --wrong relationships: 'Maps to' to 'D' or 'U'; replacement relationships to 'D'
            SELECT 5 check_id, r.*
              FROM concept c2, concept_relationship r
             WHERE     c2.concept_id = r.concept_id_2
                   AND (   (c2.invalid_reason IN ('D', 'U') AND r.relationship_id = 'Maps to')
                        OR (    c2.invalid_reason = 'D'
                            AND r.relationship_id IN ('Concept replaced by',
                                                      'Concept same_as to',
                                                      'Concept alt_to to',
                                                      'Concept poss_eq to',
                                                      'Concept was_a to')))
                   AND r.invalid_reason IS NULL
                   AND NVL (check_id, 5) = 5
            UNION ALL
            --direct and reverse mappings are not same
            SELECT 6 check_id, r.*
              FROM concept_relationship r, relationship rel, concept_relationship r_int
             WHERE                                                                                                                                                            --r.invalid_reason IS NULL
                       --AND
                       r.relationship_id = rel.relationship_id
                   AND r_int.relationship_id = rel.reverse_relationship_id
                   --AND r_int.invalid_reason IS NULL
                   AND r_int.concept_id_1 = r.concept_id_2
                   AND r_int.concept_id_2 = r.concept_id_1
                   AND (r.valid_end_date <> r_int.valid_end_date OR NVL (r.invalid_reason, 'X') <> NVL (r_int.invalid_reason, 'X'))
                   AND NVL (check_id, 6) = 6
            UNION ALL
            -- wrong valid_start_date, valid_end_date or invalid_reason for the concept
            SELECT 7 check_id,
                   c.concept_id,
                   NULL,
                   c.vocabulary_id,
                   c.valid_start_date,
                   c.valid_end_date,
                   c.invalid_reason
              FROM concept c
             WHERE     (   c.valid_end_date < c.valid_start_date
                        OR (valid_end_date = TO_DATE ('20991231', 'YYYYMMDD') AND invalid_reason IS NOT NULL)
                        OR (valid_end_date <> TO_DATE ('20991231', 'YYYYMMDD') AND invalid_reason IS NULL)
                        OR valid_start_date > SYSDATE)
                   AND NVL (check_id, 7) = 7
            UNION ALL
            -- wrong valid_start_date, valid_end_date or invalid_reason for the concept_relationship
            SELECT 8 check_id, r.*
              FROM concept_relationship r
             WHERE     (   (valid_end_date = TO_DATE ('20991231', 'YYYYMMDD') AND invalid_reason IS NOT NULL)
                        OR (valid_end_date <> TO_DATE ('20991231', 'YYYYMMDD') AND invalid_reason IS NULL)
                        OR valid_start_date > SYSDATE)
                   AND NVL (check_id, 8) = 8
            UNION ALL
            -- Rxnorm/Rxnorm Extension name duplications
            SELECT 9 check_id,
                   concept_id_1,
                   concept_id_2,
                   'Concept replaced by' AS relationship_id,
                   NULL AS valid_start_date,
                   NULL AS valid_end_date,
                   NULL AS invalid_reason
              FROM (SELECT FIRST_VALUE (c.concept_id) OVER (PARTITION BY LOWER (c.concept_name) ORDER BY c.vocabulary_id DESC, c.concept_name, c.concept_id) AS concept_id_1,
                           c.concept_id AS concept_id_2,
                           c.vocabulary_id
                      FROM concept c
                           JOIN (  SELECT LOWER (concept_name) AS concept_name, concept_class_id
                                     FROM concept
                                    WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name NOT LIKE '%...%' AND invalid_reason IS NULL
                                 GROUP BY LOWER (concept_name), concept_class_id
                                   HAVING COUNT (*) > 1
                                 MINUS
                                   SELECT LOWER (concept_name), concept_class_id
                                     FROM concept
                                    WHERE vocabulary_id = 'RxNorm' AND concept_name NOT LIKE '%...%' AND invalid_reason IS NULL
                                 GROUP BY LOWER (concept_name), concept_class_id
                                   HAVING COUNT (*) > 1) d
                               ON LOWER (c.concept_name) = LOWER (d.concept_name) AND c.vocabulary_id LIKE 'RxNorm%' AND c.invalid_reason IS NULL) c_int
                   JOIN concept c1 ON c1.concept_id = c_int.concept_id_1
                   JOIN concept c2 ON c2.concept_id = c_int.concept_id_2
             WHERE concept_id_1 <> concept_id_2 AND NOT (c1.vocabulary_id = 'RxNorm' AND c2.vocabulary_id = 'RxNorm') AND NVL (check_id, 9) = 9
            UNION ALL
            --one concept has multiple replaces
            SELECT 10 check_id, r.*
              FROM concept_relationship r
             WHERE     (r.concept_id_1, r.relationship_id) IN (  SELECT r_int.concept_id_1, r_int.relationship_id
                                                                   FROM concept_relationship r_int
                                                                  WHERE     r_int.relationship_id IN (SELECT rel_id
                                                                                                        FROM t
                                                                                                       WHERE rel_id NOT IN ('Maps to', 'Mapped from') AND direct_mapping = 1)
                                                                        AND r_int.invalid_reason IS NULL
                                                               GROUP BY r_int.concept_id_1, r_int.relationship_id
                                                                 HAVING COUNT (*) > 1)
                   AND NVL (check_id, 10) = 10;
    BEGIN
        FOR R IN C
        LOOP
            Res.EXTEND;
            Res (Res.LAST) :=
                rep_GetChecks (R.check_id,
                               R.CONCEPT_ID_1,
                               R.CONCEPT_ID_2,
                               R.RELATIONSHIP_ID,
                               R.VALID_START_DATE,
                               R.VALID_END_DATE,
                               R.INVALID_REASON);
        END LOOP;

        RETURN Res;
    END;

    PROCEDURE check_stage_tables
    IS
        z   NUMBER;
    BEGIN
        EXECUTE IMMEDIATE q'[
        SELECT SUM (cnt)
          FROM (SELECT COUNT (*) cnt
                  FROM concept_relationship_stage crs
                       LEFT JOIN vocabulary v1 ON v1.vocabulary_id = crs.vocabulary_id_1 AND v1.latest_update IS NOT NULL
                       LEFT JOIN vocabulary v2 ON v2.vocabulary_id = crs.vocabulary_id_2 AND v2.latest_update IS NOT NULL
                 WHERE COALESCE (v1.latest_update, v2.latest_update) IS NULL
                UNION ALL
                SELECT COUNT (*)
                  FROM concept_stage cs LEFT JOIN vocabulary v ON v.vocabulary_id = cs.vocabulary_id AND v.latest_update IS NOT NULL
                 WHERE v.latest_update IS NULL
                UNION ALL
                SELECT COUNT (*)
                  FROM concept_relationship_stage
                 WHERE    valid_start_date IS NULL
                       OR valid_end_date IS NULL
                       OR (invalid_reason IS NULL AND valid_end_date <> TO_DATE ('20991231', 'yyyymmdd'))
                       OR (invalid_reason IS NOT NULL AND valid_end_date = TO_DATE ('20991231', 'yyyymmdd'))
                UNION ALL
                SELECT COUNT (*)
                  FROM (SELECT relationship_id FROM concept_relationship_stage
                        MINUS
                        SELECT relationship_id FROM relationship)
                UNION ALL
                SELECT COUNT (*)
                  FROM (SELECT concept_class_id FROM concept_stage
                        MINUS
                        SELECT concept_class_id FROM concept_class)
                UNION ALL
                SELECT COUNT (*)
                  FROM (SELECT domain_id FROM concept_stage
                        MINUS
                        SELECT domain_id FROM domain)
                UNION ALL
                SELECT COUNT (*)
                  FROM (SELECT vocabulary_id FROM concept_stage
                        MINUS
                        SELECT vocabulary_id FROM vocabulary)
                UNION ALL
                SELECT COUNT (*)
                  FROM concept_stage
                 WHERE concept_name IS NULL OR domain_id IS NULL OR concept_class_id IS NULL OR concept_code IS NULL OR valid_start_date IS NULL OR valid_end_date IS NULL
                UNION ALL
                  SELECT COUNT (*)
                    FROM concept_relationship_stage
                GROUP BY concept_code_1, concept_code_2, relationship_id
                  HAVING COUNT (*) > 1
                UNION ALL
                  SELECT COUNT (*)
                    FROM concept_stage
                GROUP BY concept_code, vocabulary_id
                  HAVING COUNT (*) > 1
                UNION ALL
                  SELECT COUNT (*)
                    FROM pack_content_stage
                GROUP BY pack_concept_code,
                         pack_vocabulary_id,
                         drug_concept_code,
                         drug_vocabulary_id,
                         amount
                  HAVING COUNT (*) > 1
                UNION ALL
                  SELECT COUNT (*)
                    FROM drug_strength_stage
                GROUP BY drug_concept_code,
                         vocabulary_id_1,
                         ingredient_concept_code,
                         vocabulary_id_2,
                         amount_value
                  HAVING COUNT (*) > 1
                UNION ALL
                SELECT COUNT (*)
                  FROM concept_relationship_stage crm
                       LEFT JOIN concept c1 ON c1.concept_code = crm.concept_code_1 AND c1.vocabulary_id = crm.vocabulary_id_1
                       LEFT JOIN concept_stage cs1 ON cs1.concept_code = crm.concept_code_1 AND cs1.vocabulary_id = crm.vocabulary_id_1
                       LEFT JOIN concept c2 ON c2.concept_code = crm.concept_code_2 AND c2.vocabulary_id = crm.vocabulary_id_2
                       LEFT JOIN concept_stage cs2 ON cs2.concept_code = crm.concept_code_2 AND cs2.vocabulary_id = crm.vocabulary_id_2
                       LEFT JOIN vocabulary v1 ON v1.vocabulary_id = crm.vocabulary_id_1
                       LEFT JOIN vocabulary v2 ON v2.vocabulary_id = crm.vocabulary_id_2
                       LEFT JOIN relationship rl ON rl.relationship_id = crm.relationship_id
                 WHERE    (c1.concept_code IS NULL AND cs1.concept_code IS NULL)
                       OR (c2.concept_code IS NULL AND cs2.concept_code IS NULL)
                       OR v1.vocabulary_id IS NULL
                       OR v2.vocabulary_id IS NULL
                       OR rl.relationship_id IS NULL
                       OR crm.valid_start_date > SYSDATE
                       OR crm.valid_end_date < crm.valid_start_date
                       OR (crm.invalid_reason IS NULL AND crm.valid_end_date <> TO_DATE ('20991231', 'yyyymmdd')))]' INTO z;

        IF z <> 0
        THEN
            raise_application_error (-20001, z || ' error(s) found in stage tables. Check working\QA_stage_tables.sql');
        END IF;
    END;
END QA_TESTS;
/