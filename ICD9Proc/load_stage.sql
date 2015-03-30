-- 1. Update latest_update field to new date 
BEGIN
   EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN latest_update';
EXCEPTION WHEN OTHERS THEN NULL;
END;
ALTER TABLE vocabulary ADD latest_update DATE;
UPDATE vocabulary SET latest_update=to_date('20141001','yyyymmdd'), vocabulary_version='ICD9CM v32 master descriptions' WHERE vocabulary_id='ICD9Proc'; 
COMMIT;

-- 2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
ALTER SESSION SET SKIP_UNUSABLE_INDEXES = TRUE; --disables error reporting of indexes and index partitions marked UNUSABLE
ALTER INDEX idx_cs_concept_code UNUSABLE;
ALTER INDEX idx_cs_concept_id UNUSABLE;
ALTER INDEX idx_concept_code_1 UNUSABLE;
ALTER INDEX idx_concept_code_2 UNUSABLE;


--3. Load into concept_stage from CMS_DESC_LONG_SG
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
          NAME AS concept_name,
          'Procedure' AS domain_id,
          'ICD9Proc' AS vocabulary_id,
          length(code)||'-dig billing code' AS concept_class_id,
          'S' AS standard_concept,
          REGEXP_REPLACE (code, '^([0-9]{2})([0-9]+)', '\1.\2')
             AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'ICD9Proc')
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM CMS_DESC_LONG_SG;
COMMIT;					  

--4 Add the non-billable or HT codes for ICD9Proc
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
          SUBSTR (str, 1, 256) AS concept_name,
          'Procedure' AS domain_id,
          'ICD9Proc' AS vocabulary_id,
          length(replace(code,'.'))||'-dig nonbill code' AS concept_class_id,
          'S' AS standard_concept,
          code AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'ICD9Proc')
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM UMLS.mrconso
    WHERE     sab = 'ICD9CM'
          AND tty = 'HT'
          AND (INSTR (code, '.') = 3 OR -- Dot in 3rd position in Procedure codes, in UMLS also called ICD9CM
                                       LENGTH (code) = 2     -- Procedure code
                                                        )
          AND code NOT IN (SELECT concept_code
                             FROM concept_stage
                            WHERE vocabulary_id LIKE 'ICD9%')
          AND suppress = 'N';

COMMIT;

--5 load into concept_synonym_stage name from both CMS_DESC_LONG_DX.txt and CMS_DESC_SHORT_DX
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   (SELECT NULL AS synonym_concept_id,
           REGEXP_REPLACE (code, '^([0-9]{2})([0-9]+)', '\1.\2')
              AS synonym_concept_code,
           NAME AS synonym_name,
		   'ICD9Proc' as synonym_vocabulary_id,
           4093769 AS language_concept_id                           -- English
      FROM (SELECT * FROM CMS_DESC_LONG_SG
            UNION
            SELECT * FROM CMS_DESC_SHORT_SG));
COMMIT;

--6 Add the non-billable or HT codes for ICD9Proc as a synonym
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   SELECT NULL AS synonym_concept_id,
          code AS synonym_concept_code,
          SUBSTR (str, 1, 256) AS synonym_name,
          'ICD9Proc' AS vocabulary_id,
          4093769 AS language_concept_id                            -- English
     FROM UMLS.mrconso
    WHERE     sab = 'ICD9CM'
          AND tty = 'HT'
          AND (INSTR (code, '.') = 3 OR -- Dot in 3rd position in Procedure codes, in UMLS also called ICD9CM
                                       LENGTH (code) = 2     -- Procedure code
                                                        )
          AND code NOT IN (SELECT concept_code
                             FROM concept_stage
                            WHERE vocabulary_id LIKE 'ICD9%')
          AND suppress = 'N';

COMMIT;

--7   Load concept_relationship_stage from the existing one. The reason is that there is no good source for these relationships, and we have to build the ones for new codes from UMLS and manually
INSERT INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT NULL AS concept_id_1,
          NULL AS concept_id_2,
          c1.concept_code AS concept_code_1,
          c2.concept_code AS concept_code_2,
          c1.vocabulary_id AS vocabulary_id_1,
          c2.vocabulary_id AS vocabulary_id_2,
          r.relationship_id AS relationship_id,
          r.valid_start_date,
          r.valid_end_date,
          r.invalid_reason
     FROM concept_relationship r, concept c1, concept c2
    WHERE     c1.concept_id = r.concept_id_1
          AND (
              c1.vocabulary_id = 'ICD9Proc' OR c2.vocabulary_id = 'ICD9Proc'
          )
          AND C2.CONCEPT_ID = r.concept_id_2  
          AND r.invalid_reason IS NULL -- only fresh ones
          AND r.relationship_id NOT IN ('Domain subsumes', 'Is domain') 
;
COMMIT;		  

--8 Create text for Medical Coder with new codes and mappings
SELECT NULL AS concept_id_1,
       NULL AS concept_id_2,
       c.concept_code AS concept_code_1,
       NULL AS concept_code_2
  FROM concept_stage c
 WHERE NOT EXISTS
          (SELECT 1
             FROM concept co
            WHERE     co.concept_code = c.concept_code
                  AND co.vocabulary_id = 'ICD9Proc') -- only new codes we don't already have
AND c.vocabulary_id = 'ICD9Proc';

--9 Append resulting file from Medical Coder (in concept_relationship_stage format) to concept_relationship_stage

--10. Add mapping from deprecated to fresh concepts
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

--11 Add "subsumes" relationship between concepts where the concept_code is like of another
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT c1.concept_code AS concept_code_1,
          c2.concept_code AS concept_code_2,
          c1.vocabulary_id AS vocabulary_id_1,
          c1.vocabulary_id AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = c1.vocabulary_id)
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM concept_stage c1, concept_stage c2
    WHERE     c2.concept_code LIKE c1.concept_code || '%'
          AND c1.concept_code <> c2.concept_code;
COMMIT;

--12 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL
;

COMMIT;

--13 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		