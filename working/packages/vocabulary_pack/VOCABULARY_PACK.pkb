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

         EXECUTE IMMEDIATE 'INSERT INTO ' || cManualTableName || ' SELECT * FROM ' || cSchemaName || '.' || cManualTableName;
      END IF;

      EXECUTE IMMEDIATE '
        MERGE INTO concept_relationship_stage crs
             USING (SELECT * FROM ' || cManualTableName || ') m
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
                       (SELECT MAX(latest_update) - 1
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
   ]'  ;
   END;

   PROCEDURE DeprecateWrongMAPSTO
   IS
   BEGIN
      /* the code doesn't check the concept table, so deprecated
      EXECUTE IMMEDIATE q'[
      UPDATE concept_relationship_stage crs
         SET crs.valid_end_date =
                (SELECT MAX(latest_update) - 1
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
   */
      EXECUTE IMMEDIATE
         q'[
    UPDATE concept_relationship_stage crs
       SET crs.valid_end_date =
              (SELECT MAX (latest_update) - 1
                 FROM vocabulary
                WHERE vocabulary_id IN (crs.vocabulary_id_1, crs.vocabulary_id_2) AND latest_update IS NOT NULL),
           crs.invalid_reason = 'D'
     WHERE     crs.relationship_id = 'Maps to'
           AND crs.invalid_reason IS NULL
           AND EXISTS
                  (SELECT 1
                     FROM (     SELECT 1
                                  FROM (                     --taking invalid_reason of concept_code_2, first from the concept_stage, next from the concept (if concept doesn't exists in the concept_stage)
                                        SELECT cs.concept_code,
                                               cs.vocabulary_id,
                                               cs.invalid_reason,
                                               1 AS source_id
                                          FROM concept_stage cs
                                         WHERE cs.concept_code = crs.concept_code_2 AND cs.vocabulary_id = crs.vocabulary_id_2
                                        UNION ALL
                                        SELECT c.concept_code,
                                               c.vocabulary_id,
                                               c.invalid_reason,
                                               2 AS source_id
                                          FROM concept c
                                         WHERE c.concept_code = crs.concept_code_2 AND c.vocabulary_id = crs.vocabulary_id_2)
                              ORDER BY source_id
                           FETCH FIRST 1 ROW ONLY)
                    WHERE invalid_reason IN ('U', 'D'))   
    ]' ;
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
                                                       AND (
                                                       (
                                                         (
                                                           (crs.vocabulary_id_1 = crs.vocabulary_id_2 AND crs.vocabulary_id_1 NOT IN ('RxNorm','RxNorm Extension') AND crs.vocabulary_id_2 NOT IN ('RxNorm','RxNorm Extension')) 
                                                           OR (crs.vocabulary_id_1 IN ('RxNorm','RxNorm Extension') AND crs.vocabulary_id_2 IN ('RxNorm','RxNorm Extension'))
                                                         ) 
                                                         AND crs.relationship_id <> 'Maps to'
                                                       ) 
                                                         OR crs.relationship_id = 'Maps to'
                                                       )                                                       
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
                                                       AND r.relationship_id = 'Maps to'
                                                       --don't use already deprecated relationships
                                                       AND NOT EXISTS (
                                                            SELECT 1 FROM concept_relationship_stage crs_int
                                                            WHERE crs_int.concept_code_1=c1.concept_code
                                                            AND crs_int.vocabulary_id_1=c1.vocabulary_id
                                                            AND crs_int.concept_code_2=c2.concept_code
                                                            AND crs_int.vocabulary_id_2=c2.vocabulary_id
                                                            AND crs_int.relationship_id=r.relationship_id
                                                            AND crs_int.invalid_reason IS NOT NULL
                                                       )))                                                       
                                SELECT CONNECT_BY_ROOT concept_code_1 AS root_concept_code_1,
                                       u.concept_code_2,
                                       CONNECT_BY_ROOT vocabulary_id_1 AS root_vocabulary_id_1,
                                       vocabulary_id_2,
                                       'Maps to' AS relationship_id,
                                       NULL AS invalid_reason
                                  FROM upgraded_concepts u
                                 WHERE CONNECT_BY_ISLEAF = 1
                            CONNECT BY NOCYCLE PRIOR concept_code_2 = concept_code_1 AND PRIOR vocabulary_id_2 = vocabulary_id_1) int
                     WHERE EXISTS
                              (SELECT 1
                                 FROM concept_relationship_stage crs
                                WHERE crs.concept_code_1 = int.root_concept_code_1 AND crs.vocabulary_id_1 = int.root_vocabulary_id_1)                    
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
   ]'  ;
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
                                FROM (SELECT cs.ROWID                                                                               rid,
                                             concept_code_1,
                                             concept_code_2,
                                             vocabulary_id_1,
                                             vocabulary_id_2,
                                             CASE WHEN c.concept_class_id IN ('Ingredient', 'Clinical Drug Comp') THEN 1 ELSE 2 END pseudo_class_id,
                                             ROW_NUMBER ()
                                                OVER (PARTITION BY concept_code_1, vocabulary_id_1, vocabulary_id_2 ORDER BY cs.valid_start_date DESC, c.valid_start_date DESC, c.concept_id DESC)
                                                rn,                                                                                                                               --fresh mappings first
                                             (SELECT 1
                                                FROM concept_relationship_stage cr_int, concept_relationship_stage crs_int, concept_stage c_int
                                               WHERE     cr_int.invalid_reason IS NULL
                                                     AND cr_int.relationship_id = 'RxNorm ing of'
                                                     AND cr_int.concept_code_1 = c.concept_code
                                                     AND cr_int.vocabulary_id_1 = c.vocabulary_id
                                                     AND c.concept_class_id = 'Ingredient'
                                                     AND crs_int.relationship_id = 'Maps to'
                                                     AND crs_int.invalid_reason IS NULL
                                                     AND crs_int.concept_code_1 = cs.concept_code_1
                                                     AND crs_int.vocabulary_id_1 = cs.vocabulary_id_1
                                                     AND crs_int.concept_code_2 = c_int.concept_code
                                                     AND crs_int.vocabulary_id_2 = c_int.vocabulary_id
                                                     AND c_int.domain_id = 'Drug'
                                                     AND c_int.concept_class_id = 'Clinical Drug Comp'
                                                     AND cr_int.concept_code_2 = c_int.concept_code
                                                     AND cr_int.vocabulary_id_2 = c_int.vocabulary_id)
                                                has_rel_with_comp
                                        FROM concept_relationship_stage cs, concept_stage c
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

   FUNCTION UpdateVocabulary (pVocabularyName IN VARCHAR2)
      RETURN VARCHAR2
   IS
      /*
       CREATE TABLE vocabulary_access
       (
          vocabulary_id      VARCHAR2 (20) NOT NULL,
          vocabulary_auth    VARCHAR2 (500),
          vocabulary_url     VARCHAR2 (500) NOT NULL,
          vocabulary_login   VARCHAR2 (100),
          vocabulary_pass    VARCHAR2 (100),
          is_main            NUMBER,
          --CONSTRAINT f_vocabulary_access_1 FOREIGN KEY (vocabulary_id) REFERENCES vocabulary_conversion (vocabulary_id_v5) -- cannot use this constraint for UMLS
       );
      */
      cURL            vocabulary_access.vocabulary_url%TYPE;
      cVocabOldDate   DATE;
      cVocabHTML      CLOB;
      cVocabDate      DATE;
      cPos1           NUMBER;
      cPos2           NUMBER;
      cSearchString   VARCHAR2 (500);
      cRet            VARCHAR2 (500);

      PROCEDURE CheckPositions (int_Pos1 IN NUMBER, int_Pos2 IN NUMBER)
      IS
      BEGIN
         IF int_Pos1 = 0 OR int_Pos2 = 0 OR int_Pos2 <= int_Pos1
         THEN
            raise_application_error (-20000, 'Something wrong while parsing ' || pVocabularyName);
         END IF;
      END;
   BEGIN
      IF pVocabularyName IS NULL
      THEN
         raise_application_error (-20000, pVocabularyName || ' cannot be empty!');
      END IF;

      SELECT MAX (vocabulary_url)
        INTO cURL
        FROM vocabulary_access
       WHERE vocabulary_id = pVocabularyName AND is_main = 1;

      IF cURL IS NULL
      THEN
         raise_application_error (-20000, pVocabularyName || ' not found in vocabulary_access table!');
      END IF;

      /*
        set proper update date
      */
      IF pVocabularyName <> 'UMLS'
      THEN
         SELECT NVL (LATEST_UPDATE, TO_DATE ('19700101', 'yyyymmdd'))
           INTO cVocabOldDate
           FROM vocabulary_conversion
          WHERE vocabulary_id_v5 = pVocabularyName;
      ELSE
         SELECT LAST_DDL_TIME
           INTO cVocabOldDate
           FROM ALL_OBJECTS
          WHERE OWNER = 'UMLS' AND OBJECT_NAME = 'MRCONSO';
      END IF;

      /*
        INSERT INTO vocabulary_access
             VALUES ('UMLS',
                     'https://utslogin.nlm.nih.gov/cas/',
                     'https://www.nlm.nih.gov/research/umls/licensedcontent/umlsknowledgesources.html',
                     '',
                     '',
                     1);
        start checking
        supported:
        1. RxNorm
        2. UMLS
        3. SNOMED
        4. HCPCS
        5. ICD9CM
        6. ICD9Proc
        7. ICD10CM
        8. ICD10PCS
        9. LOINC
        10. MedDRA
        11. NDC
        12. OPCS4
        13. Read
      */
      UTL_HTTP.set_wallet ('file:/home/oracle/wallet', 'wallet_password');
      cVocabHTML := HTTPURITYPE (cURL).getCLOB ();

      CASE
         WHEN pVocabularyName = 'RxNorm'
         THEN
            cSearchString := 'https://download.nlm.nih.gov/umls/kss/rxnorm/RxNorm_full_';
            cPos1 := INSTR (cVocabHTML, cSearchString);
            cPos2 := INSTR (cVocabHTML, '.zip', cPos1);
            CheckPositions (cPos1, cPos2);
            cVocabDate := TO_DATE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), 'mmddyyyy');
         WHEN pVocabularyName = 'UMLS'
         THEN
            cSearchString := '<table class="umls_download">';
            cPos1 := INSTR (cVocabHTML, cSearchString);
            cPos1 := INSTR (cVocabHTML, '<td>', cPos1 + 1);
            cPos1 := INSTR (cVocabHTML, '<td>', cPos1 + 1);
            cPos1 := INSTR (cVocabHTML, '<td>', cPos1 + 1);
            cPos2 := INSTR (cVocabHTML, '</td>', cPos1);
            CheckPositions (cPos1, cPos2);
            cVocabDate := TO_DATE (SUBSTR (cVocabHTML, cPos1 + 4, cPos2 - cPos1 - 4), 'mondd,yyyy');
         WHEN pVocabularyName = 'SNOMED'
         THEN
            cSearchString := '<a class="btn btn-primary btn-md" href="';
            cPos1 := INSTR (cVocabHTML, cSearchString);
            cPos2 := INSTR (cVocabHTML, '.zip">Download RF2 Files Now!</a>', cPos1);
            CheckPositions (cPos1, cPos2);
            cVocabDate := TO_DATE (REGEXP_SUBSTR (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), '[[:digit:]]+'), 'yyyymmdd');
         WHEN pVocabularyName = 'HCPCS'
         THEN
            SELECT TO_DATE ( (MAX (t.title) - 1) || '0101', 'yyyymmdd')
              INTO cVocabDate
              FROM XMLTABLE ('/rss/channel/item' PASSING xmltype (cVocabHTML) COLUMNS title NUMBER PATH 'title', description VARCHAR2 (500) PATH 'link') t
             WHERE t.description LIKE '%Alpha-Numeric-HCPCS-File%' AND t.description NOT LIKE '%orrections%';
         WHEN pVocabularyName IN ('ICD9CM', 'ICD9Proc')
         THEN
            cSearchString := '<a type="application/zip" href="/Medicare/Coding/ICD9ProviderDiagnosticCodes/Downloads';
            cPos1 := INSTR (cVocabHTML, cSearchString);
            cPos2 := INSTR (cVocabHTML, '[ZIP,', cPos1);
            CheckPositions (cPos1, cPos2);
            cVocabHTML := REGEXP_REPLACE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), '[[:space:]]+$', '');
            cSearchString := 'Effective';
            cPos1 := INSTR (cVocabHTML, cSearchString);
            cPos2 := LENGTH (cVocabHTML) + 1;
            CheckPositions (cPos1, cPos2);
            cVocabDate := TO_DATE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), 'mondd,yyyy');
         WHEN pVocabularyName = 'ICD10CM'
         THEN
            cSearchString := '<div id="contentArea" >';
            cPos1 := INSTR (cVocabHTML, cSearchString);
            cSearchString := '<strong>Note: <a href="';
            cPos1 := INSTR (cVocabHTML, cSearchString, cPos1);
            cPos2 := INSTR (cVocabHTML, '">', cPos1);
            CheckPositions (cPos1, cPos2);
            cVocabDate :=
               TO_DATE (TO_NUMBER (REGEXP_SUBSTR (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), ' [[:digit:]]{4} ')) - 1 || '0101', 'yyyymmdd');
         WHEN pVocabularyName = 'ICD10PCS'
         THEN
            cSearchString := 'ICD-10 PCS and GEMs';
            cPos1 := INSTR (cVocabHTML, cSearchString);
            cSearchString := '">';
            cPos1 := INSTR (cVocabHTML, cSearchString, cPos1);
            cPos2 := INSTR (cVocabHTML, '</a>', cPos1);
            CheckPositions (cPos1, cPos2);
            cVocabDate :=
               TO_DATE (TO_NUMBER (REGEXP_SUBSTR (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), '^[[:digit:]]+')) - 1 || '0101', 'yyyymmdd');
         WHEN pVocabularyName = 'LOINC'
         THEN
            cSearchString := 'LOINC Table';
            cPos1 := INSTR (cVocabHTML, cSearchString);
            cSearchString := '<span class="discreet">Released';
            cPos1 := INSTR (cVocabHTML, cSearchString, cPos1);
            cSearchString := '<span>';
            cPos1 := INSTR (cVocabHTML, cSearchString, cPos1);
            cPos2 := INSTR (cVocabHTML, '</span>', cPos1);
            CheckPositions (cPos1, cPos2);
            cVocabDate := TO_DATE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), 'yyyy-mm-dd');
         WHEN pVocabularyName = 'MedDRA'
         THEN
                 SELECT TO_DATE (REGEXP_SUBSTR (TRIM (title), '[[:alpha:]]+ [[:digit:]]+$'), 'mon yyyy')
                   INTO cVocabDate
                   FROM XMLTABLE ('/rss/channel/item' PASSING xmltype (cVocabHTML) COLUMNS link_str VARCHAR2 (500) PATH 'link', pubDate VARCHAR2 (500) PATH 'pubDate', title VARCHAR2 (500) PATH 'title') t
                  WHERE t.link_str LIKE '%www.meddra.org/how-to-use/support-documentation/english'
               ORDER BY TO_TIMESTAMP_TZ (pubDate, 'dy dd mon yyyy hh24:mi:ss tzhtzm') DESC
            FETCH FIRST 1 ROW ONLY;
         WHEN pVocabularyName = 'NDC'
         THEN
            cSearchString := 'Current through: ';
            cPos1 := INSTR (cVocabHTML, cSearchString);
            cPos2 := INSTR (cVocabHTML, '</p>', cPos1);
            CheckPositions (cPos1, cPos2);
            cVocabDate := TO_DATE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), 'mondd,yyyy');
         WHEN pVocabularyName IN ('OPCS4', 'Read')
         THEN
            cSearchString := '<h2 class="available no-bottom-margin">';
            cPos1 := INSTR (cVocabHTML, cSearchString);
            /*
            gets 21.0.0_YYYYMMDD000001
            cPos2 := INSTR (cVocabHTML, '</h2>', cPos1);
            cVocabDate:=to_date(regexp_substr(TRIM (REGEXP_REPLACE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), '[[:space:]]+', ' ')),'[[:digit:]]{8}'),'yyyymmdd');
            */
            cSearchString := 'Released on';
            cPos1 := INSTR (cVocabHTML, cSearchString, cPos1);
            cPos2 := INSTR (cVocabHTML, '</h3>', cPos1);
            CheckPositions (cPos1, cPos2);
            cVocabDate :=
               TO_DATE (
                  REGEXP_REPLACE (TRIM (REGEXP_REPLACE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), '[[:space:]]+', ' ')),
                                  '([[:alpha:] ]+)([[:digit:]]+)(st|nd|th|rd)',
                                  '\2'),
                  'dd month yyyy');
         ELSE
            raise_application_error (-20000, pVocabularyName || ' are not supported at this time!');
      END CASE;

      IF cVocabDate IS NULL
      THEN
         raise_application_error (-20000, 'NULL detected for ' || pVocabularyName);
      END IF;

      IF cVocabDate > cVocabOldDate
      THEN
         cRet := cVocabOldDate || ' -> ' || cVocabDate;
      END IF;

      RETURN cRet;
   END;

   PROCEDURE CheckVocabularyUpdates
   IS
      cRet                   VARCHAR2 (1000);
      cMailText              VARCHAR2 (20000);
      crlf                   VARCHAR2 (2) := UTL_TCP.crlf;
      email                  var_array := var_array ('timur.vakhitov@firstlinesoftware.com');
      cHTML_OK      CONSTANT VARCHAR2 (100) := '<font color=''green''>&#10004;</font> ';
      cHTML_ERROR   CONSTANT VARCHAR2 (100) := '<font color=''red''>&#10008;</font> ';
   BEGIN
      FOR cVocab IN (SELECT DISTINCT vocabulary_id
                       FROM vocabulary_access)
      LOOP
         BEGIN
            cRet := UpdateVocabulary (cVocab.vocabulary_id);

            IF cRet IS NOT NULL
            THEN
               cRet := '<b>' || cVocab.vocabulary_id || '</b> is updated! [' || cRet || ']';

               IF cMailText IS NULL
               THEN
                  cMailText := cHTML_OK || cRet;
               ELSE
                  cMailText := cMailText || crlf || cHTML_OK || cRet;
               END IF;
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               cRet := '<b>' || cVocab.vocabulary_id || '</b> returns error:' || crlf || SQLERRM || crlf || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;

               IF cMailText IS NULL
               THEN
                  cMailText := cHTML_ERROR || cRet;
               ELSE
                  cMailText := cMailText || crlf || cHTML_ERROR || cRet;
               END IF;
         END;
      END LOOP;

      IF cMailText IS NOT NULL
      THEN
         SendMailHTML (email, 'Vocabulary checks notification', cMailText);
      END IF;
   END;

   PROCEDURE StartReleaseNEW
   IS
      crlf        VARCHAR2 (2) := UTL_TCP.crlf;
      email     var_array := var_array ('timur.vakhitov@firstlinesoftware.com');
      cRet        VARCHAR2 (5000);
      l_output    DBMS_OUTPUT.chararr;
      l_lines     INTEGER := 1000;
      l_outline   VARCHAR2 (4000);
      l_outall    VARCHAR2 (32000);
   BEGIN
      DBMS_OUTPUT.enable (1000000);
      DBMS_JAVA.set_output (1000000);

      --pConceptAncestor;
      --DEVV4.v5_to_v4;

      csv.generate ('VOCAB_DUMP', 'concept.csv', p_query => 'SELECT * FROM concept where rownum<100');
      csv.generate ('VOCAB_DUMP', 'concept_relationship.csv', p_query => 'SELECT * FROM concept_relationship where rownum<100');
      host_command ('/home/vocab_dump/upload_vocab.sh');
      DBMS_OUTPUT.get_lines (l_output, l_lines);

      FOR i IN 1 .. l_lines
      LOOP
         l_outline := TRIM (REGEXP_REPLACE (l_output (i), '[[:space:]]+', ' '));

         IF l_outline IS NOT NULL
         THEN
            l_outall := l_outall || crlf || l_outline;
         END IF;
      END LOOP;

      l_outall := SUBSTR (l_outall, 3, 4000);

      IF l_outall IS NOT NULL
      THEN
         raise_application_error (-20000, l_outall);
      END IF;

      cRet := 'Release completed';

      SendMailHTML (email, 'Release status [OK]', cRet);
   EXCEPTION
      WHEN OTHERS
      THEN
         cRet := SUBSTR ('Release completed with errors:' || crlf || SQLERRM || crlf || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, 1, 5000);
         SendMailHTML (email, 'Release status [ERROR]', cRet);
   END;

   PROCEDURE StartRelease
   IS
      crlf      VARCHAR2 (2) := UTL_TCP.crlf;
      email     var_array := var_array ('timur.vakhitov@firstlinesoftware.com', 'reich@ohdsi.org', 'reich@omop.org', 'alexander.yatsenko@odysseusinc.com','anna.ostropolets@odysseusinc.com');
      cRet      VARCHAR2 (5000);
      cVocabs   VARCHAR2 (4000);
   BEGIN
      pConceptAncestor;
      DEVV4.v5_to_v4;
      CREATE_PROD_BACKUP@link_prodv5;
      CREATE_PRODV4@link_prodv5;
      CREATE_PRODV5@link_prodv5;

      SELECT LISTAGG (vocabulary_id, ', ') WITHIN GROUP (ORDER BY vocabulary_id)
        INTO cVocabs
        FROM (SELECT DISTINCT vocabulary_id
                FROM (SELECT *
                        FROM prodv5.concept@link_prodv5
                       WHERE invalid_reason IS NULL
                      MINUS
                      SELECT *
                        FROM prodv5_backup.concept@link_prodv5
                       WHERE invalid_reason IS NULL));

      cRet := 'Release completed';

      IF cVocabs IS NOT NULL
      THEN
         cRet := cRet || crlf || 'Affected vocabularies: ' || cVocabs;
      END IF;

      SendMailHTML (email, 'Release status [OK]', cRet);
   EXCEPTION
      WHEN OTHERS
      THEN
         cRet := SUBSTR ('Release completed with errors:' || crlf || SQLERRM || crlf || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, 1, 5000);
         SendMailHTML (email, 'Release status [ERROR]', cRet);
   END;
END VOCABULARY_PACK;
/