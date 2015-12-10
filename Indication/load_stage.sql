-- 1. Update latest_update field to new date 
BEGIN
   EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN latest_update';
EXCEPTION WHEN OTHERS THEN NULL;
END;
ALTER TABLE vocabulary ADD latest_update DATE;
UPDATE vocabulary SET (latest_update, vocabulary_version)=(select to_date(NDDF_VERSION,'YYYYMMDD'), NDDF_VERSION||' Release' from NDDF_PRODUCT_INFO) WHERE vocabulary_id='Indication';
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

--3. Add Indication to concept_stage from RFMLDX0_DXID and RFMLDRHO_DXID_HIST
INSERT /*+ APPEND */ INTO  concept_stage (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT DISTINCT
          d.dxid_desc100 AS concept_name,
          'Drug' AS domain_id,
          'Indication' AS vocabulary_id,
          'Indication' AS concept_class_id,
          'C' AS standard_concept,
          d.dxid AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          CASE d.dxid_status
             WHEN '1'
             THEN
                CASE
                   WHEN h.fmlrepdxid IS NULL
                   THEN
                      (SELECT V.LATEST_UPDATE-1 FROM VOCABULARY V WHERE V.VOCABULARY_ID = 'Indication')
                   ELSE
                      fmldxrepdt
                END
             WHEN '2'
             THEN
                (SELECT V.LATEST_UPDATE-1 FROM VOCABULARY V WHERE V.VOCABULARY_ID = 'Indication')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE d.dxid_status
             WHEN '1'
             THEN
                CASE WHEN h.fmlrepdxid IS NULL THEN 'D' ELSE 'U' END
             WHEN '2'
             THEN
                'D'
             ELSE
                NULL
          END
             AS invalid_reason
     FROM RFMLDX0_DXID d
          LEFT JOIN RFMLDRH0_DXID_HIST h ON h.fmlprvdxid = d.dxid; -- find in replacement table
COMMIT;

--4. Add synonymus
INSERT /*+ APPEND */ INTO  concept_synonym_stage (synonym_concept_code,
                                   synonym_vocabulary_id,
                                   synonym_name,
                                   language_concept_id)
   SELECT dxid AS synonym_concept_code,
          'Indication' AS synonym_vocabulary_id,
          DESCRIPTION AS synonym_name,
          4093769 AS language_concept_id                            -- English
     FROM (SELECT dxid_syn_desc56, dxid_syn_desc100, dxid
             FROM RFMLSYN0_DXID_SYN
            WHERE dxid_syn_status = 0)
          UNPIVOT
             (DESCRIPTION             --take both dxid_syn_desc56 and dxid_syn_desc100
             FOR DESCRIPTIONS
             IN (dxid_syn_desc56, dxid_syn_desc100))
   UNION
   SELECT dxid AS synonym_concept_code,
          'Indication' AS synonym_vocabulary_id,
          DESCRIPTION AS synonym_name,
          4093769 AS language_concept_id                            -- English
     FROM (SELECT dxid_desc56, dxid_desc100, dxid FROM RFMLDX0_DXID)
          UNPIVOT
             (DESCRIPTION             --take both dxid_desc56 and dxid_desc100
                         FOR DESCRIPTIONS IN (dxid_desc56, dxid_desc100));
COMMIT;

								   
--4. Load into concept_relationship_stage
 -- Upgrade relationship for concepts
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT h.fmlprvdxid AS concept_code_1,
          h.fmlrepdxid AS concept_code_2,
          'Indication' AS vocabulary_id_1,
          'Indication' AS vocabulary_id_2,
          'Concept replaced by' AS relationship_id,
          h.fmldxrepdt AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM RFMLDRH0_DXID_HIST h;
COMMIT;

 -- Indication to RxNorm
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT
          rx.concept_code AS concept_code_1,
          m.dxid AS concept_code_2,
          'RxNorm' AS vocabulary_id_1,
          'Indication' AS vocabulary_id_2,
          CASE m.indcts_lbl
             WHEN 'L' THEN 'Has FDA-appr ind'
             WHEN 'U' THEN 'Has off-label ind'
             ELSE NULL
          END
             AS relationship_id,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM concept rx                                                 -- RxNorm
          JOIN concept_relationship r
             ON     r.concept_id_1 = rx.concept_id
                AND r.invalid_reason IS NULL
                AND r.relationship_id = 'Mapped from'
          JOIN concept g
             ON     g.concept_id = r.concept_id_2
                AND g.vocabulary_id = 'GCN_SEQNO'
          JOIN rindmgc0_indcts_gcnseqno_link l
             ON l.gcn_seqno = g.concept_code
          JOIN rindmma2_indcts_mstr m ON m.indcts = l.indcts
    WHERE m.indcts_lbl <> 'P'; -- use only FDA-approved ('L') or unlabelled ('U') ones, not proxy indications
COMMIT;	

-- Contraindication to RxNorm
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT rx.concept_code AS concept_code_1,
                   m.dxid AS concept_code_2,
                   'RxNorm' AS vocabulary_id_1,
                   'Indication' AS vocabulary_id_2,
                   'Has CI' AS relationship_id,
                   TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM concept rx                                                 -- RxNorm
          JOIN concept_relationship r
             ON     r.concept_id_1 = rx.concept_id
                AND r.invalid_reason IS NULL
                AND r.relationship_id = 'Mapped from'
          JOIN concept g
             ON     g.concept_id = r.concept_id_2
                AND g.vocabulary_id = 'GCN_SEQNO'
          JOIN rddcmgc0_contra_gcnseqno_link l
             ON l.gcn_seqno = g.concept_code
          JOIN rddcmma1_contra_mstr m ON m.ddxcn = l.ddxcn;
COMMIT;	 

-- Indication to SNOMED through ICD9CM and ICD10CM
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT rs.related_dxid AS concept_code_1,
                   c.concept_code AS concept_code_2,
                   'Indication' AS vocabulary_id_1,
                   'SNOMED' AS vocabulary_id_2,
                   'Ind/CI - SNOMED' AS relationship_id,
                   TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM RFMLISR1_ICD_SEARCH rs
          JOIN concept icd
             ON     icd.concept_code = rs.search_icd_cd
                AND icd.vocabulary_id IN ('ICD9CM', 'ICD10CM') -- potentially restrict by fml_clin_code and fml_nav_code
          JOIN concept_relationship r
             ON     r.concept_id_1 = icd.concept_id
                AND r.invalid_reason IS NULL
                AND r.relationship_id = 'Maps to'
          JOIN concept c
             ON     c.concept_id = r.concept_id_2
                AND c.vocabulary_id = 'SNOMED'
                AND c.domain_id = 'Condition';
COMMIT;				

--5. Add mapping from deprecated to fresh concepts
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
    ) int_rel WHERE NOT EXISTS -- only new mapping we don't already have
    (select 1 from concept_relationship_stage r where
        int_rel.root=r.concept_code_1
        and int_rel.concept_code_2=r.concept_code_2
        and int_rel.root_vocabulary_id=r.vocabulary_id_1
        and int_rel.vocabulary_id_2=r.vocabulary_id_2
        and r.relationship_id='Maps to'
    );

COMMIT;

--6. Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;


--7. Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		