
--1. Update latest_update field to new date 
ALTER TABLE vocabulary ADD latest_update DATE;
update vocabulary set latest_update=to_date('20141112','yyyymmdd') where vocabulary_id='HCPCS'; commit;

-- 2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
ALTER SESSION SET SKIP_UNUSABLE_INDEXES = TRUE; --disables error reporting of indexes and index partitions marked UNUSABLE
ALTER INDEX idx_cs_concept_code UNUSABLE;
ALTER INDEX idx_cs_concept_id UNUSABLE;
ALTER INDEX idx_concept_code_1 UNUSABLE;
ALTER INDEX idx_concept_code_2 UNUSABLE;

--3. Create concept_stage from HCPCS
INSERT INTO concept_stage (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT NULL AS concept_id,
       SUBSTR (a.LONG_DESCRIPTION, 1, 256) AS concept_name,
       c.domain_id AS domain_id,
       v.vocabulary_id,
       CASE WHEN LENGTH (HCPC) = 2 THEN 'HCPCS Modifier' ELSE 'HCPCS' END
          AS concept_class_id,
       CASE WHEN TERM_DT IS NOT NULL THEN NULL ELSE 'S' END
          AS standard_concept,
       HCPC AS concept_code,
       COALESCE (ADD_DATE, ACT_EFF_DT) AS valid_start_date,
       COALESCE (TERM_DT, TO_DATE ('20991231', 'yyyymmdd')) AS valid_end_date,
       CASE
          WHEN TERM_DT IS NULL THEN NULL
          WHEN XREF1 IS NULL THEN 'D'                            -- deprecated
          ELSE 'U'                                                 -- upgraded
       END
          AS invalid_reason
  FROM ANWEB_V2 a
       JOIN vocabulary v ON v.vocabulary_id = 'HCPCS'
       LEFT JOIN concept c
          ON     c.concept_code = A.BETOS
             AND c.concept_class_id = 'HCPCS Class'
             AND C.VOCABULARY_ID = 'HCPCS';
COMMIT;					  

--4 Update domain_id in concept_stage from concept
UPDATE concept_stage cs
   SET domain_id =
          (SELECT domain_id
             FROM concept c
            WHERE     C.CONCEPT_CODE = CS.CONCEPT_CODE
                  AND C.VOCABULARY_ID = CS.VOCABULARY_ID)
 WHERE CS.DOMAIN_ID IS NULL AND CS.VOCABULARY_ID = 'HCPCS';
COMMIT;

--5 Create CONCEPT_SYNONYM_STAGE
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   SELECT DISTINCT NULL AS synonym_concept_id,
                   HCPC AS synonym_concept_code,
                   DESCRIPTION AS synonym_name,
                   'HCPCS' AS synonym_vocabulary_id,
                   4093769 AS language_concept_id                   -- English
     FROM (SELECT LONG_DESCRIPTION, SHORT_DESCRIPTION, HCPC FROM ANWEB_V2) UNPIVOT (DESCRIPTION
                                                                           FOR DESCRIPTIONS
                                                                           IN (LONG_DESCRIPTION,
                                                                              SHORT_DESCRIPTION));
COMMIT;

--6  Load concept_relationship_stage from the existing one. The reason is that there is no good source for these relationships, and we have to build the ones for new codes from UMLS and manually
INSERT INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT NULL AS concept_id_1,
          NULL AS concept_id_2,
          c.concept_code AS concept_code_1,
          c1.concept_code AS concept_code_2,
          r.relationship_id AS relationship_id,
          c.vocabulary_id AS vocabulary_id_1,
          c1.vocabulary_id AS vocabulary_id_2,
          r.valid_start_date,
          r.valid_end_date,
          r.invalid_reason
     FROM concept_relationship r, concept c, concept c1
    WHERE     c.concept_id = r.concept_id_1
          AND c.vocabulary_id = 'HCPCS'
          AND C1.CONCEPT_ID = r.concept_id_2; 
COMMIT;

--7 Add upgrade relationships
INSERT INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT NULL AS concept_id_1,
                   NULL AS concept_id_2,
                   concept_code_1,
                   concept_code_2,
                   'Concept replaced by' AS relationship_id,
                   'HCPCS' AS vocabulary_id_1,
                   'HCPCS' AS vocabulary_id_2,
                   valid_start_date,
                   valid_end_date,
                   'U' AS invalid_reason
     FROM (SELECT A.HCPC AS concept_code_1,
                  A.XREF1 AS concept_code_2,
                  COALESCE (A.ADD_DATE, A.ACT_EFF_DT) AS valid_start_date,
                  COALESCE (A.TERM_DT, TO_DATE ('20991231', 'yyyymmdd'))
                     AS valid_end_date
             FROM ANWEB_V2 a, ANWEB_V2 b
            WHERE     A.XREF1 = B.HCPC
                  AND A.TERM_DT IS NOT NULL
                  AND B.TERM_DT IS NULL
           UNION ALL
           SELECT A.HCPC AS concept_code_1,
                  A.XREF2,
                  COALESCE (A.ADD_DATE, A.ACT_EFF_DT),
                  COALESCE (A.TERM_DT, TO_DATE ('20991231', 'yyyymmdd'))
             FROM ANWEB_V2 a, ANWEB_V2 b
            WHERE     A.XREF2 = B.HCPC
                  AND A.TERM_DT IS NOT NULL
                  AND B.TERM_DT IS NULL
           UNION ALL
           SELECT A.HCPC AS concept_code_1,
                  A.XREF3,
                  COALESCE (A.ADD_DATE, A.ACT_EFF_DT),
                  COALESCE (A.TERM_DT, TO_DATE ('20991231', 'yyyymmdd'))
             FROM ANWEB_V2 a, ANWEB_V2 b
            WHERE     A.XREF3 = B.HCPC
                  AND A.TERM_DT IS NOT NULL
                  AND B.TERM_DT IS NULL
           UNION ALL
           SELECT A.HCPC AS concept_code_1,
                  A.XREF4,
                  COALESCE (A.ADD_DATE, A.ACT_EFF_DT),
                  COALESCE (A.TERM_DT, TO_DATE ('20991231', 'yyyymmdd'))
             FROM ANWEB_V2 a, ANWEB_V2 b
            WHERE     A.XREF4 = B.HCPC
                  AND A.TERM_DT IS NOT NULL
                  AND B.TERM_DT IS NULL
           UNION ALL
           SELECT A.HCPC AS concept_code_1,
                  A.XREF5,
                  COALESCE (A.ADD_DATE, A.ACT_EFF_DT),
                  COALESCE (A.TERM_DT, TO_DATE ('20991231', 'yyyymmdd'))
             FROM ANWEB_V2 a, ANWEB_V2 b
            WHERE     A.XREF5 = B.HCPC
                  AND A.TERM_DT IS NOT NULL
                  AND B.TERM_DT IS NULL);
COMMIT;		  


--8 Create hierarchical relationships between HCPCS and HCPCS class
INSERT INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT
          NULL AS concept_id_1,
          NULL AS concept_id_2,
          A.HCPC AS concept_code_1,
          A.BETOS AS concept_code_2,
          'Is a' AS relationship_id,
          'HCPCS' AS vocabulary_id_1,
          'HCPCS Class' AS vocabulary_id_2,
          COALESCE (A.ADD_DATE, A.ACT_EFF_DT) AS valid_start_date,
          COALESCE (A.TERM_DT, TO_DATE ('20991231', 'yyyymmdd'))
             AS valid_end_date,
          CASE
             WHEN TERM_DT IS NULL THEN NULL
             WHEN XREF1 IS NULL THEN 'D'                         -- deprecated
             ELSE 'U'                                              -- upgraded
          END
             AS invalid_reason
     FROM ANWEB_V2 a
    WHERE A.BETOS IS NOT NULL;
COMMIT;	

--9 Create text for Medical Coder with new codes and mappings
SELECT NULL AS concept_id_1,
       NULL AS concept_id_2,
       c.concept_code AS concept_code_1,
       u2.scui AS concept_code_2,
       CASE
          WHEN c.domain_id = 'Procedure' THEN 'HCPCS - SNOMED proc'
          WHEN c.domain_id = 'Measurement' THEN 'HCPCS - SNOMED meas'
          ELSE 'HCPCS - SNOMED obs'
       END
          AS relationship_id, -- till here strawman for concept_relationship to be checked and filled out, the remaining are supportive information to be truncated in the return file
       c.concept_name AS cpt_name,
       u2.str AS snomed_str,
       sno.concept_id AS snomed_concept_id,
       sno.concept_name AS snomed_name
  FROM concept_stage c
       LEFT JOIN
       (                                         -- UMLS record for HCPCS code
        SELECT DISTINCT cui, scui
          FROM UMLS.mrconso
         WHERE sab IN ('HCPCS') AND suppress NOT IN ('E', 'O', 'Y')) u1
          ON u1.scui = concept_code                  -- join UMLS for code one
       LEFT JOIN
       (                        -- UMLS record for SNOMED code of the same cui
        SELECT DISTINCT
               cui,
               scui,
               FIRST_VALUE (
                  str)
               OVER (PARTITION BY scui
                     ORDER BY DECODE (tty,  'PT', 1,  'PTGB', 2,  10))
                  AS str
          FROM UMLS.mrconso
         WHERE sab IN ('SNOMEDCT_US') AND suppress NOT IN ('E', 'O', 'Y')) u2
          ON u2.cui = u1.cui
       LEFT JOIN concept sno
          ON sno.vocabulary_id = 'SNOMED' AND sno.concept_code = u2.scui -- SNOMED concept
 WHERE     NOT EXISTS
              (                        -- only new codes we don't already have
               SELECT 1
                 FROM concept co
                WHERE     co.concept_code = c.concept_code
                      AND co.vocabulary_id = 'HCPCS')
       AND c.vocabulary_id = 'HCPCS'
       AND c.concept_class_id IN ('HCPCS', 'HCPCS Modifier');
--10 Append resulting file from Medical Coder (in concept_relationship_stage format) to concept_relationship_stage

--11. Add mapping from deprecated to fresh concepts
INSERT  /*+ APPEND */  INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
    SELECT 
      root,
      concept_code_2,
      root_vocabulary_id,
      vocabulary_id_2,
      'Maps to',
      (SELECT latest_update FROM vocabulary WHERE vocabulary_id=root_vocabulary_id),
      TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
      NULL
    FROM 
    (
        SELECT root_vocabulary_id, root, concept_code_2, vocabulary_id_2 FROM (
          SELECT root_vocabulary_id, root, concept_code_2, vocabulary_id_2, dt,  ROW_NUMBER() OVER (PARTITION BY root_vocabulary_id, root ORDER BY dt DESC) rn
            FROM (
                SELECT 
                      concept_code_2, 
                      vocabulary_id_2,
                      valid_start_date AS dt,
                      CONNECT_BY_ROOT concept_code_1 AS root,
                      CONNECT_BY_ROOT vocabulary_id_1 AS root_vocabulary_id,
                      CONNECT_BY_ISLEAF AS lf
                FROM concept_relationship_stage
                WHERE relationship_id IN ( 'Concept replaced by',
                                               'Concept same_as to',
                                               'Concept alt_to to',
                                               'Concept poss_eq to',
                                               'Concept was_a to',
                                               'Original maps to'
                                             )
                      and NVL(invalid_reason, 'X') <> 'D'
                CONNECT BY  
                NOCYCLE  
                PRIOR concept_code_2 = concept_code_1
                      AND relationship_id IN ( 'Concept replaced by',
                                               'Concept same_as to',
                                               'Concept alt_to to',
                                               'Concept poss_eq to',
                                               'Concept was_a to',
                                               'Original maps to'
                                             )
                       AND vocabulary_id_2=vocabulary_id_1                     
                       AND NVL(invalid_reason, 'X') <> 'D'
                                   
                START WITH relationship_id IN ('Concept replaced by',
                                               'Concept same_as to',
                                               'Concept alt_to to',
                                               'Concept poss_eq to',
                                               'Concept was_a to',
                                               'Original maps to'
                                              )
                      AND NVL(invalid_reason, 'X') <> 'D'
          ) sou 
          WHERE lf = 1
        ) 
        WHERE rn = 1
    ) int_rel WHERE NOT EXISTS
    (select 1 from concept_relationship_stage r where
        int_rel.root=r.concept_code_1
        and int_rel.concept_code_2=r.concept_code_2
        and int_rel.root_vocabulary_id=r.vocabulary_id_1
        and int_rel.vocabulary_id_2=r.vocabulary_id_2
        and r.relationship_id='Maps to'
    );

COMMIT;

--12 Make sure all records are symmetrical and turn if necessary
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT crs.concept_code_2,
          crs.concept_code_1,
          crs.vocabulary_id_2,
          crs.vocabulary_id_1,
          r.reverse_relationship_id,
          crs.valid_start_date,
          crs.valid_end_date,
          crs.invalid_reason
     FROM concept_relationship_stage crs
          JOIN relationship r ON r.relationship_id = crs.relationship_id
    WHERE NOT EXISTS
             (                                           -- the inverse record
              SELECT 1
                FROM concept_relationship_stage i
               WHERE     crs.concept_code_1 = i.concept_code_2
                     AND crs.concept_code_2 = i.concept_code_1
                     AND crs.vocabulary_id_1 = i.vocabulary_id_2
                     AND crs.vocabulary_id_2 = i.vocabulary_id_1
                     AND r.reverse_relationship_id = i.relationship_id);
COMMIT;

--13 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;

--14 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;	

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script