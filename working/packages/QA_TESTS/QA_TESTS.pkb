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

   FUNCTION get_summary (table_name IN VARCHAR2)
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
         INSERT INTO DEV_SUMMARY
              SELECT 'concept' AS table_name,
                     c.vocabulary_id,
                     NULL,
                     concept_class_id,
                     NULL    AS relationship_id,
                     invalid_reason,
                     COUNT (*) AS cnt,
                     NULL    AS cnt_delta
                FROM concept@LINK_PRODV5 c
            GROUP BY c.vocabulary_id, concept_class_id, invalid_reason;

         MERGE INTO DEV_SUMMARY t1
              USING (  SELECT 'concept'     AS table_name,
                              c.vocabulary_id AS vocabulary_id_1,
                              NULL,
                              concept_class_id,
                              NULL          AS relationship_id,
                              invalid_reason,
                              COUNT (*)     AS cnt,
                              NULL          AS cnt_delta
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
         INSERT INTO DEV_SUMMARY
              SELECT 'concept_relationship' AS table_name,
                     c1.vocabulary_id,
                     c2.vocabulary_id,
                     NULL                 AS concept_class_id,
                     r.relationship_id,
                     r.invalid_reason,
                     COUNT (*)            AS cnt,
                     NULL                 AS cnt_delta
                FROM concept@LINK_PRODV5 c1, concept@LINK_PRODV5 c2, concept_relationship@LINK_PRODV5 r
               WHERE c1.concept_id = r.concept_id_1 AND c2.concept_id = r.concept_id_2
            GROUP BY c1.vocabulary_id,
                     c2.vocabulary_id,
                     r.relationship_id,
                     r.invalid_reason;

         MERGE INTO DEV_SUMMARY t1
              USING (  SELECT 'concept_relationship' AS table_name,
                              c1.vocabulary_id     AS vocabulary_id_1,
                              c2.vocabulary_id     AS vocabulary_id_2,
                              NULL                 AS concept_class_id,
                              r.relationship_id,
                              r.invalid_reason,
                              COUNT (*)            AS cnt,
                              NULL                 AS cnt_delta
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
         INSERT INTO DEV_SUMMARY
              SELECT 'concept_ancestor' AS table_name,
                     c.vocabulary_id,
                     NULL,
                     NULL             AS concept_class_id,
                     NULL             AS relationship_id,
                     NULL             AS invalid_reason,
                     COUNT (*)        AS cnt,
                     NULL             AS cnt_delta
                FROM concept@LINK_PRODV5 c, concept_ancestor@LINK_PRODV5 ca
               WHERE c.concept_id = CA.ANCESTOR_CONCEPT_ID
            GROUP BY c.vocabulary_id;

         MERGE INTO DEV_SUMMARY t1
              USING (  SELECT 'concept_ancestor' AS table_name,
                              c.vocabulary_id  AS vocabulary_id_1,
                              NULL,
                              NULL             AS concept_class_id,
                              NULL             AS relationship_id,
                              NULL             AS invalid_reason,
                              COUNT (*)        AS cnt,
                              NULL             AS cnt_delta
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
              AS (SELECT rel_id
                    FROM (SELECT relationship_id, reverse_relationship_id
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
                AND r.relationship_id IN (SELECT *
                                            FROM t)
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
                AND r.relationship_id IN (SELECT *
                                            FROM t)
                AND NVL (check_id, 2) = 2
         UNION ALL
         --relationships without reverse
         SELECT 3 check_id, r.*
           FROM concept_relationship r, relationship rel
          WHERE     r.invalid_reason IS NULL
                AND r.relationship_id = rel.relationship_id
                AND r.concept_id_1 <> r.concept_id_2
                AND NOT EXISTS
                       (SELECT 1
                          FROM concept_relationship r_int
                         WHERE r_int.relationship_id = rel.reverse_relationship_id AND r_int.invalid_reason IS NULL AND r_int.concept_id_1 = r.concept_id_2 AND r_int.concept_id_2 = r.concept_id_1)
                AND r.relationship_id IN (SELECT *
                                            FROM t)
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
                AND r.relationship_id IN (SELECT *
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
          WHERE                                                                                                                                                               --r.invalid_reason IS NULL
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
          WHERE    c.valid_end_date < c.valid_start_date
                OR (valid_end_date = TO_DATE ('20991231', 'YYYYMMDD') AND invalid_reason IS NOT NULL)
                OR (valid_end_date <> TO_DATE ('20991231', 'YYYYMMDD') AND invalid_reason IS NULL)
                OR valid_start_date > SYSDATE AND NVL (check_id, 7) = 7
         UNION ALL
         -- wrong valid_start_date, valid_end_date or invalid_reason for the concept_relationship
         SELECT 8 check_id, r.*
           FROM concept_relationship r
          WHERE                                                                                                                                                   --valid_end_date < valid_start_date OR
                (  valid_end_date = TO_DATE ('20991231', 'YYYYMMDD') AND invalid_reason IS NOT NULL)
                OR (valid_end_date <> TO_DATE ('20991231', 'YYYYMMDD') AND invalid_reason IS NULL)
                OR valid_start_date > SYSDATE AND NVL (check_id, 8) = 8
         UNION ALL
         -- Rxnorm/Rxnorm Extension name duplications
         SELECT 9                     check_id,
                concept_id_1,
                concept_id_2,
                'Concept replaced by' AS relationship_id,
                NULL                  AS valid_start_date,
                NULL                  AS valid_end_date,
                NULL                  AS invalid_reason
           FROM (SELECT FIRST_VALUE (c.concept_id) OVER (PARTITION BY LOWER (c.concept_name) ORDER BY c.vocabulary_id DESC, c.concept_name, c.concept_id) AS concept_id_1,
                        c.concept_id                                                                                                                      AS concept_id_2,
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
          WHERE concept_id_1 <> concept_id_2 AND NOT (c1.vocabulary_id = 'RxNorm' AND c2.vocabulary_id = 'RxNorm') AND NVL (check_id, 9) = 9;
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
END QA_TESTS;
/