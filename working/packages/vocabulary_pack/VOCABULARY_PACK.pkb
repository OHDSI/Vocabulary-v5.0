CREATE OR REPLACE PACKAGE BODY DEVV5.VOCABULARY_PACK
IS
   cManualTableName   CONSTANT VARCHAR2 (100) := 'CONCEPT_RELATIONSHIP_MANUAL';
   cMainDEVSchema     CONSTANT VARCHAR2 (100) := 'DEVV5';

   PROCEDURE SetLatestUpdate (pVocabularyName        IN VARCHAR2,
                              pVocabularyDate        IN DATE,
                              pVocabularyVersion     IN vocabulary.vocabulary_version%TYPE,
                              pVocabularyDevSchema   IN VARCHAR2,
                              pAppendVocabulary      IN BOOLEAN DEFAULT FALSE)
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      z   NUMBER;
   BEGIN
      IF pVocabularyName IS NULL
      THEN
         raise_application_error (-20000, 'pVocabularyName cannot be empty!');
      END IF;

      IF pVocabularyDate IS NULL
      THEN
         raise_application_error (-20000, 'pVocabularyDate cannot be empty!');
      END IF;

      IF pVocabularyDate > SYSDATE
      THEN
         raise_application_error (-20000, 'pVocabularyDate bigger than current date!');
      END IF;

      IF pVocabularyVersion IS NULL
      THEN
         raise_application_error (-20000, 'pVocabularyVersion cannot be empty!');
      END IF;

      IF pVocabularyDevSchema IS NULL
      THEN
         raise_application_error (-20000, 'pVocabularyDevSchema cannot be empty!');
      END IF;

      SELECT COUNT (*)
        INTO z
        FROM vocabulary
       WHERE vocabulary_id = pVocabularyName;

      IF z = 0
      THEN
         raise_application_error (-20000, 'Vocabulary with id=' || pVocabularyName || ' not found');
      END IF;

      SELECT COUNT (*)
        INTO z
        FROM all_users
       WHERE username = UPPER (pVocabularyDevSchema);

      IF z = 0
      THEN
         raise_application_error (-20000, 'Dev schema with name ' || pVocabularyDevSchema || ' not found');
      END IF;

      IF NOT pAppendVocabulary
      THEN
         BEGIN
            EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN latest_update';
         EXCEPTION
            WHEN OTHERS
            THEN
               NULL;
         END;

         BEGIN
            EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN dev_schema_name';
         EXCEPTION
            WHEN OTHERS
            THEN
               NULL;
         END;

         BEGIN
            EXECUTE IMMEDIATE 'DROP SYNONYM ' || cManualTableName;
         EXCEPTION
            WHEN OTHERS
            THEN
               NULL;
         END;

         EXECUTE IMMEDIATE 'ALTER TABLE vocabulary ADD latest_update DATE';

         EXECUTE IMMEDIATE 'ALTER TABLE vocabulary ADD dev_schema_name VARCHAR2 (100)';
      END IF;

      EXECUTE IMMEDIATE q'[
      UPDATE vocabulary
         SET latest_update = :a, vocabulary_version = :b, dev_schema_name = :c
       WHERE vocabulary_id = :d
       ]'
         USING pVocabularyDate,
               pVocabularyVersion,
               pVocabularyDevSchema,
               pVocabularyName;

      COMMIT;
   END;

   PROCEDURE CheckManualTable
   IS
      z   NUMBER;
   BEGIN
      SELECT COUNT (*)
        INTO z
        FROM concept_relationship_manual crm
             LEFT JOIN concept c1 ON c1.concept_code = crm.concept_code_1 AND c1.vocabulary_id = crm.vocabulary_id_1
             LEFT JOIN concept_stage cs1 ON cs1.concept_code = crm.concept_code_1 AND cs1.vocabulary_id = crm.vocabulary_id_1
             LEFT JOIN concept c2 ON c2.concept_code = crm.concept_code_2 AND c2.vocabulary_id = crm.vocabulary_id_2
             LEFT JOIN concept_stage cs2 ON cs2.concept_code = crm.concept_code_1 AND cs2.vocabulary_id = crm.vocabulary_id_1
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
             OR (crm.invalid_reason IS NULL AND crm.valid_end_date <> TO_DATE ('20991231', 'yyyymmdd'));

      IF z > 0
      THEN
         raise_application_error (-20000, 'CheckManualTable: ' || z || ' error(s) found');
      END IF;
   END;

   PROCEDURE ProcessManualRelationships
   IS
      z             NUMBER;
      cSchemaName   VARCHAR2 (100);
   BEGIN
      /*
       Checking table concept_relationship_manual for errors
      */
      CheckManualTable;

      EXECUTE IMMEDIATE 'SELECT MAX (dev_schema_name), COUNT (DISTINCT dev_schema_name) FROM vocabulary WHERE latest_update IS NOT NULL' INTO cSchemaName, z;

      IF z > 1
      THEN
         raise_application_error (-20000, 'SynchronizeManualTable: more than one dev_schema found');
      END IF;

      IF USER = cMainDEVSchema
      THEN
         SELECT COUNT (*)
           INTO z
           FROM all_tables
          WHERE owner = cSchemaName AND table_name = cManualTableName;

         IF z = 0
         THEN
            raise_application_error (-20000, 'SynchronizeManualTable: ' || cSchemaName || '.' || cManualTableName || ' not found');
         END IF;

         EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || cManualTableName;

         EXECUTE IMMEDIATE 'INSERT /*+ APPEND */ INTO ' || cManualTableName || ' SELECT * FROM ' || cSchemaName || '.' || cManualTableName;
      END IF;

      EXECUTE IMMEDIATE '
        MERGE INTO concept_relationship_stage crs
             USING (SELECT * FROM '||cManualTableName||') m
                ON (    crs.concept_code_1 = m.concept_code_1
                    AND crs.concept_code_2 = m.concept_code_2
                    AND crs.relationship_id = m.relationship_id
                    AND crs.vocabulary_id_1 = m.vocabulary_id_1
                    AND crs.vocabulary_id_2 = m.vocabulary_id_2)
        WHEN NOT MATCHED
        THEN
           INSERT     (concept_code_1,
                       concept_code_2,
                       vocabulary_id_1,
                       vocabulary_id_2,
                       relationship_id,
                       valid_start_date,
                       valid_end_date,
                       invalid_reason)
               VALUES (m.concept_code_1,
                       m.concept_code_2,
                       m.vocabulary_id_1,
                       m.vocabulary_id_2,
                       m.relationship_id,
                       m.valid_start_date,
                       m.valid_end_date,
                       m.invalid_reason)';
   END;

   PROCEDURE CheckReplacementMappings
   IS
   BEGIN
      EXECUTE IMMEDIATE q'[
      BEGIN
      --Delete duplicate replacement mappings (one concept has multiply target concepts)
      DELETE FROM concept_relationship_stage
            WHERE (concept_code_1, relationship_id) IN (  SELECT concept_code_1, relationship_id
                                                            FROM concept_relationship_stage
                                                           WHERE     relationship_id IN ('Concept replaced by',
                                                                                         'Concept same_as to',
                                                                                         'Concept alt_to to',
                                                                                         'Concept poss_eq to',
                                                                                         'Concept was_a to')
                                                                 AND invalid_reason IS NULL
                                                                 AND vocabulary_id_1 = vocabulary_id_2
                                                        GROUP BY concept_code_1, relationship_id
                                                          HAVING COUNT (DISTINCT concept_code_2) > 1);


      --Delete self-connected mappings ("A 'Concept replaced by' B" and "B 'Concept replaced by' A")
      DELETE FROM concept_relationship_stage
            WHERE ROWID IN (SELECT cs1.ROWID
                              FROM concept_relationship_stage cs1, concept_relationship_stage cs2
                             WHERE     cs1.invalid_reason IS NULL
                                   AND cs2.invalid_reason IS NULL
                                   AND cs1.concept_code_1 = cs2.concept_code_2
                                   AND cs1.concept_code_2 = cs2.concept_code_1
                                   AND cs1.vocabulary_id_1 = cs2.vocabulary_id_1
                                   AND cs2.vocabulary_id_2 = cs2.vocabulary_id_2
                                   AND cs1.vocabulary_id_1 = cs1.vocabulary_id_2
                                   AND cs1.relationship_id = cs2.relationship_id
                                   AND cs1.relationship_id IN ('Concept replaced by',
                                                               'Concept same_as to',
                                                               'Concept alt_to to',
                                                               'Concept poss_eq to',
                                                               'Concept was_a to'));



      --Deprecate concepts if we have no active replacement record in the concept_relationship_stage
      UPDATE concept_stage cs
         SET cs.valid_end_date =
                (SELECT v.latest_update - 1
                   FROM VOCABULARY v
                  WHERE v.vocabulary_id = cs.vocabulary_id),
             cs.invalid_reason = 'D',
             cs.standard_concept = NULL
       WHERE     NOT EXISTS
                    (SELECT 1
                       FROM concept_relationship_stage crs
                      WHERE     crs.concept_code_1 = cs.concept_code
                            AND crs.vocabulary_id_1 = cs.vocabulary_id
                            AND crs.invalid_reason IS NULL
                            AND crs.relationship_id IN ('Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept poss_eq to',
                                                        'Concept was_a to'))
             AND cs.invalid_reason = 'U';

      --Deprecate replacement records if target concept was depreceted
      MERGE INTO concept_relationship_stage r
           USING (WITH upgraded_concepts
                          AS (SELECT crs.concept_code_1,
                                     crs.vocabulary_id_1,
                                     crs.concept_code_2,
                                     crs.vocabulary_id_2,
                                     crs.relationship_id,
                                     CASE
                                        WHEN COALESCE (cs.concept_code, c.concept_code) IS NULL THEN 'D'
                                        ELSE CASE WHEN cs.concept_code IS NOT NULL THEN cs.invalid_reason ELSE c.invalid_reason END
                                     END
                                        AS invalid_reason
                                FROM concept_relationship_stage crs
                                     LEFT JOIN concept_stage cs ON crs.concept_code_2 = cs.concept_code AND crs.vocabulary_id_2 = cs.vocabulary_id
                                     LEFT JOIN concept c ON crs.concept_code_2 = c.concept_code AND crs.vocabulary_id_2 = c.vocabulary_id
                               WHERE     crs.relationship_id IN ('Concept replaced by',
                                                                 'Concept same_as to',
                                                                 'Concept alt_to to',
                                                                 'Concept poss_eq to',
                                                                 'Concept was_a to')
                                     AND crs.vocabulary_id_1 = crs.vocabulary_id_2
                                     AND crs.concept_code_1 <> crs.concept_code_2
                                     AND crs.invalid_reason IS NULL)
                      SELECT DISTINCT u.concept_code_1,
                                      u.vocabulary_id_1,
                                      u.concept_code_2,
                                      u.vocabulary_id_2,
                                      u.relationship_id
                        FROM upgraded_concepts u
                  CONNECT BY NOCYCLE PRIOR concept_code_1 = concept_code_2
                  START WITH concept_code_2 IN (SELECT concept_code_2
                                                  FROM upgraded_concepts
                                                 WHERE invalid_reason = 'D')) i
              ON (    r.concept_code_1 = i.concept_code_1
                  AND r.vocabulary_id_1 = i.vocabulary_id_1
                  AND r.concept_code_2 = i.concept_code_2
                  AND r.vocabulary_id_2 = i.vocabulary_id_2
                  AND r.relationship_id = i.relationship_id)
      WHEN MATCHED
      THEN
         UPDATE SET r.invalid_reason = 'D',
                    r.valid_end_date =
                       (SELECT latest_update - 1
                          FROM vocabulary
                         WHERE vocabulary_id IN (r.vocabulary_id_1, r.vocabulary_id_2));



      --Deprecate concepts if we have no active replacement record in the concept_relationship_stage (yes, again)
      UPDATE concept_stage cs
         SET cs.valid_end_date =
                (SELECT v.latest_update - 1
                   FROM VOCABULARY v
                  WHERE v.vocabulary_id = cs.vocabulary_id),
             cs.invalid_reason = 'D',
             cs.standard_concept = NULL
       WHERE     NOT EXISTS
                    (SELECT 1
                       FROM concept_relationship_stage crs
                      WHERE     crs.concept_code_1 = cs.concept_code
                            AND crs.vocabulary_id_1 = cs.vocabulary_id
                            AND crs.invalid_reason IS NULL
                            AND crs.relationship_id IN ('Concept replaced by',
                                                        'Concept same_as to',
                                                        'Concept alt_to to',
                                                        'Concept poss_eq to',
                                                        'Concept was_a to'))
             AND cs.invalid_reason = 'U';
   END;
   ]';
   END;

   PROCEDURE DeprecateWrongMAPSTO
   IS
   BEGIN
      EXECUTE IMMEDIATE q'[
      UPDATE concept_relationship_stage crs
         SET crs.valid_end_date =
                (SELECT latest_update - 1
                   FROM vocabulary
                  WHERE vocabulary_id IN (crs.vocabulary_id_1, crs.vocabulary_id_2) AND latest_update IS NOT NULL),
             crs.invalid_reason = 'D'
       WHERE     crs.relationship_id = 'Maps to'
             AND crs.invalid_reason IS NULL
             AND EXISTS
                    (SELECT 1
                       FROM concept_stage cs
                      WHERE cs.concept_code = crs.concept_code_2 AND cs.vocabulary_id = crs.vocabulary_id_2 AND cs.invalid_reason IN ('U', 'D'))
   ]';
   END;

   PROCEDURE AddFreshMAPSTO
   IS
   BEGIN
      EXECUTE IMMEDIATE
         q'[
      MERGE INTO concept_relationship_stage crs
           USING (  SELECT root_concept_code_1,
                           concept_code_2,
                           root_vocabulary_id_1,
                           vocabulary_id_2,
                           relationship_id,
                           (SELECT MAX (latest_update)
                              FROM vocabulary
                             WHERE latest_update IS NOT NULL)
                              AS valid_start_date,
                           TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
                           invalid_reason
                      FROM (WITH upgraded_concepts
                                    AS (SELECT DISTINCT
                                               concept_code_1,
                                               CASE
                                                  WHEN rel_id <> 6
                                                  THEN
                                                     FIRST_VALUE (concept_code_2) OVER (PARTITION BY concept_code_1 ORDER BY rel_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
                                                  ELSE
                                                     concept_code_2
                                               END
                                                  AS concept_code_2,
                                               vocabulary_id_1,
                                               vocabulary_id_2
                                          FROM (SELECT crs.concept_code_1,
                                                       crs.concept_code_2,
                                                       crs.vocabulary_id_1,
                                                       crs.vocabulary_id_2,
                                                       --if concepts have more than one relationship_id, then we take only the one with following precedence
                                                       CASE
                                                          WHEN crs.relationship_id = 'Concept replaced by' THEN 1
                                                          WHEN crs.relationship_id = 'Concept same_as to' THEN 2
                                                          WHEN crs.relationship_id = 'Concept alt_to to' THEN 3
                                                          WHEN crs.relationship_id = 'Concept poss_eq to' THEN 4
                                                          WHEN crs.relationship_id = 'Concept was_a to' THEN 5
                                                          WHEN crs.relationship_id = 'Maps to' THEN 6
                                                       END
                                                          AS rel_id
                                                  FROM concept_relationship_stage crs
                                                 WHERE     crs.relationship_id IN ('Concept replaced by',
                                                                                   'Concept same_as to',
                                                                                   'Concept alt_to to',
                                                                                   'Concept poss_eq to',
                                                                                   'Concept was_a to',
                                                                                   'Maps to')
                                                       AND crs.invalid_reason IS NULL
                                                       AND ( (crs.vocabulary_id_1 = crs.vocabulary_id_2 AND crs.relationship_id <> 'Maps to') OR crs.relationship_id = 'Maps to')
                                                       AND crs.concept_code_1 <> crs.concept_code_2
                                                UNION ALL
                                                --some concepts might be in 'base' tables
                                                SELECT c1.concept_code,
                                                       c2.concept_code,
                                                       c1.vocabulary_id,
                                                       c2.vocabulary_id,
                                                       6 AS rel_id
                                                  FROM concept c1, concept c2, concept_relationship r
                                                 WHERE     c1.concept_id = r.concept_id_1
                                                       AND c2.concept_id = r.concept_id_2
                                                       AND r.concept_id_1 <> r.concept_id_2
                                                       AND r.invalid_reason IS NULL
                                                       AND r.relationship_id = 'Maps to'))
                                SELECT CONNECT_BY_ROOT concept_code_1 AS root_concept_code_1,
                                       u.concept_code_2,
                                       CONNECT_BY_ROOT vocabulary_id_1 AS root_vocabulary_id_1,
                                       vocabulary_id_2,
                                       'Maps to' AS relationship_id,
                                       NULL AS invalid_reason
                                  FROM upgraded_concepts u
                                 WHERE CONNECT_BY_ISLEAF = 1
                            CONNECT BY NOCYCLE PRIOR concept_code_2 = concept_code_1 AND PRIOR vocabulary_id_2 = vocabulary_id_1) i
                     WHERE EXISTS
                              (SELECT 1
                                 FROM concept_relationship_stage crs
                                WHERE crs.concept_code_1 = root_concept_code_1 AND crs.vocabulary_id_1 = root_vocabulary_id_1)
                  GROUP BY root_concept_code_1,
                           concept_code_2,
                           root_vocabulary_id_1,
                           vocabulary_id_2,
                           relationship_id,
                           invalid_reason) i
              ON (    crs.concept_code_1 = i.root_concept_code_1
                  AND crs.concept_code_2 = i.concept_code_2
                  AND crs.vocabulary_id_1 = i.root_vocabulary_id_1
                  AND crs.vocabulary_id_2 = i.vocabulary_id_2
                  AND crs.relationship_id = i.relationship_id)
      WHEN NOT MATCHED
      THEN
         INSERT     (concept_code_1,
                     concept_code_2,
                     vocabulary_id_1,
                     vocabulary_id_2,
                     relationship_id,
                     valid_start_date,
                     valid_end_date,
                     invalid_reason)
             VALUES (i.root_concept_code_1,
                     i.concept_code_2,
                     i.root_vocabulary_id_1,
                     i.vocabulary_id_2,
                     i.relationship_id,
                     i.valid_start_date,
                     i.valid_end_date,
                     i.invalid_reason)
      WHEN MATCHED
      THEN
         UPDATE SET crs.invalid_reason = NULL, crs.valid_end_date = i.valid_end_date
                 WHERE crs.invalid_reason IS NOT NULL
   ]';
   END;

   PROCEDURE DeleteAmbiguousMAPSTO
   IS
   BEGIN
      DELETE FROM concept_relationship_stage
            WHERE ROWID IN
                     (SELECT rid
                        FROM (SELECT rid,
                                     concept_code_1,
                                     concept_code_2,
                                     pseudo_class_id,
                                     rn,
                                     MIN (pseudo_class_id) OVER (PARTITION BY concept_code_1, vocabulary_id_1, vocabulary_id_2) have_true_mapping,
                                     has_rel_with_comp
                                FROM (SELECT cs.ROWID rid,
                                             concept_code_1,
                                             concept_code_2,
                                             vocabulary_id_1,
                                             vocabulary_id_2,
                                             CASE WHEN c.concept_class_id IN ('Ingredient', 'Clinical Drug Comp') THEN 1 ELSE 2 END pseudo_class_id,
                                             ROW_NUMBER ()
                                                OVER (PARTITION BY concept_code_1, vocabulary_id_1, vocabulary_id_2 ORDER BY cs.valid_start_date DESC, c.valid_start_date DESC, c.concept_id DESC)
                                                rn,                                                                                                                               --fresh mappings first
                                             (SELECT 1
                                                FROM concept_relationship cr_int, concept_relationship_stage crs_int, concept c_int
                                               WHERE     cr_int.invalid_reason IS NULL
                                                     AND cr_int.relationship_id = 'RxNorm ing of'
                                                     AND cr_int.concept_id_1 = c.concept_id
                                                     AND c.concept_class_id = 'Ingredient'
                                                     AND crs_int.relationship_id = 'Maps to'
                                                     AND crs_int.invalid_reason IS NULL
                                                     AND crs_int.concept_code_1 = cs.concept_code_1
                                                     AND crs_int.vocabulary_id_1 = cs.vocabulary_id_1
                                                     AND crs_int.concept_code_2 = c_int.concept_code
                                                     AND crs_int.vocabulary_id_2 = c_int.vocabulary_id
                                                     AND c_int.domain_id = 'Drug'
                                                     AND c_int.concept_class_id = 'Clinical Drug Comp'
                                                     AND cr_int.concept_id_2 = c_int.concept_id)
                                                has_rel_with_comp
                                        FROM concept_relationship_stage cs, concept c
                                       WHERE     relationship_id = 'Maps to'
                                             AND cs.invalid_reason IS NULL
                                             AND cs.concept_code_2 = c.concept_code
                                             AND cs.vocabulary_id_2 = c.vocabulary_id
                                             AND c.domain_id = 'Drug'))
                       WHERE ( (have_true_mapping = 1 AND pseudo_class_id = 2) OR --if we have 'true' mappings to Ingredients or Clinical Drug Comps (pseudo_class_id=1), then delete all others mappings (pseudo_class_id=2)
                                                                                  (have_true_mapping <> 1 AND rn > 1) OR           --if we don't have 'true' mappings, then leave only one fresh mapping
                                                                                                                        has_rel_with_comp = 1 --if we have 'true' mappings to Ingredients AND Clinical Drug Comps, then delete mappings to Ingredients, which have mappings to Clinical Drug Comp
                                                                                                                                             ));
   END;
END VOCABULARY_PACK;
/