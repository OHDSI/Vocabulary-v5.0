-- 1. Update latest_update field to new date 
ALTER TABLE vocabulary ADD latest_update DATE;
UPDATE vocabulary SET latest_update=to_date('20140901','yyyymmdd') WHERE vocabulary_id = 'MedDRA'; 
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

--3. Insert into concept_stage
INSERT INTO concept_stage (concept_name,
                           vocabulary_id,
                           domain_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT soc_name AS concept_name,
          'MedDRA' AS vocabulary_id,
          NULL AS domain_id,
          'SOC' AS concept_class_id,
          'C' AS standard_concept,
          soc_code AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM soc_term
   UNION ALL
   SELECT hlgt_name AS concept_name,
          'MedDRA' AS vocabulary_id,
          NULL AS domain_id,
          'HLGT' AS concept_class_id,
          'C' AS standard_concept,
          hlgt_code AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM hlgt_pref_term
   UNION ALL
   SELECT hlt_name AS concept_name,
          'MedDRA' AS vocabulary_id,
          NULL AS domain_id,
          'HLT' AS concept_class_id,
          'C' AS standard_concept,
          hlt_code AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM hlt_pref_term
   UNION ALL
   SELECT pt_name AS concept_name,
          'MedDRA' AS vocabulary_id,
          NULL AS domain_id,
          'PT' AS concept_class_id,
          'C' AS standard_concept,
          pt_code AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM pref_term
   UNION ALL
   SELECT llt_name AS concept_name,
          'MedDRA' AS vocabulary_id,
          NULL AS domain_id,
          'LLT' AS concept_class_id,
          'C' AS standard_concept,
          llt_code AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM low_level_term
    WHERE llt_currency = 'Y' AND llt_code <> pt_code;
COMMIT;					  



--4 Create internal hierarchical relationships
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT soc_code AS concept_code_1,
          hlgt_code AS concept_code_2,
          'MedDRA' AS vocabulary_id_1,
          'MedDRA' AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM soc_hlgt_comp
   UNION ALL
   SELECT hlgt_code AS concept_code_1,
          hlt_code AS concept_code_2,
          'MedDRA' AS vocabulary_id_1,
          'MedDRA' AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM hlgt_hlt_comp
   UNION ALL
   SELECT hlt_code AS concept_code_1,
          pt_code AS concept_code_2,
          'MedDRA' AS vocabulary_id_1,
          'MedDRA' AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM hlt_pref_comp
   UNION ALL
   SELECT pt_code AS concept_code_1,
          llt_code AS concept_code_2,
          'MedDRA' AS vocabulary_id_1,
          'MedDRA' AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM low_level_term
    WHERE llt_currency = 'Y' AND llt_code <> pt_code;
COMMIT;

--5 Copy existing relationships
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
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
          c2.vocabulary_id AS vocabulary_id_2,
          r.relationship_id AS relationship_id,
          r.valid_start_date AS valid_start_date,
          r.valid_end_date AS valid_end_date,
          r.invalid_reason AS invalid_reason
     FROM concept_relationship r, concept c1, concept c2
    WHERE     c1.concept_id = r.concept_id_1
          AND c2.concept_id = r.concept_id_2
          AND r.relationship_id IN ('MedDRA - SNOMED eq',
                                    'MedDRA - SMQ',
                                    'MedDRA - ICD9CM');
COMMIT;

									
--6 Add mapping from deprecated to fresh concepts
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


--7 Create a relationship file for the Medical Coder
select c.concept_code, c.concept_name, c.domain_id, c.concept_class_id, c1.concept_code concept_code_snomed 
from concept_stage c
left join concept_relationship_stage r on c.concept_code=r.concept_code_1 and r.relationship_id = 'MedDRA - SNOMED eq'
left join concept c1 on c1.concept_code=r.concept_code_2 and c1.vocabulary_id='SNOMED';

--8 Append result to concept_relationship_stage table

--9 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL
;
COMMIT;

--10 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		