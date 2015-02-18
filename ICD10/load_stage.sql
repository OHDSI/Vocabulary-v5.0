-- 1. Update latest_update field to new date 
ALTER TABLE vocabulary ADD latest_update DATE;
UPDATE vocabulary SET latest_update=to_date('20141010','yyyymmdd') WHERE vocabulary_id='ICD10'; 
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


--3. Create file for medical coder from the existing one
SELECT *
  FROM concept
 WHERE vocabulary_id = 'ICD10' AND invalid_reason IS NULL;
 
--4. Append file from medical coder to concept_stage

--5. Create file for medical coder from the existing one
SELECT *
  FROM concept c, concept_relationship r
 WHERE     c.concept_id = r.concept_id_1
       AND c.vocabulary_id = 'ICD10'
       AND r.invalid_reason IS NULL;

--6. Append file from medical coder to concept_relationship_stage

--7 Add mapping from deprecated to fresh concepts
INSERT  /*+ APPEND */  INTO concept_relationship_stage (
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
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

--8 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;


--9 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		