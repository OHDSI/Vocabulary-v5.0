--1. Update latest_update field to new date 
BEGIN
   EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN latest_update';
EXCEPTION WHEN OTHERS THEN NULL;
END;
ALTER TABLE vocabulary ADD latest_update DATE;
update vocabulary set latest_update=to_date('20150629','yyyymmdd'), vocabulary_version='LOINC 2.52' where vocabulary_id='LOINC'; commit;

-- 2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
ALTER SESSION SET SKIP_UNUSABLE_INDEXES = TRUE; --disables error reporting of indexes and index partitions marked UNUSABLE
ALTER INDEX idx_cs_concept_code UNUSABLE;
ALTER INDEX idx_cs_concept_id UNUSABLE;
ALTER INDEX idx_concept_code_1 UNUSABLE;
ALTER INDEX idx_concept_code_2 UNUSABLE;

--3. Create concept_stage from LOINC
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
          SUBSTR (COALESCE (CONSUMER_NAME,
			CASE WHEN LENGTH(LONG_COMMON_NAME)>255 AND SHORTNAME IS NOT NULL THEN SHORTNAME ELSE LONG_COMMON_NAME END)
			,1,255) AS concept_name,
          CASE CLASSTYPE
             WHEN '1' THEN 'Measurement'
             WHEN '2' THEN 'Measurement'
             WHEN '3' THEN 'Observation'
             WHEN '4' THEN 'Observation'
          END
             AS domain_id,
          v.vocabulary_id,
          CASE CLASSTYPE
             WHEN '1' THEN 'Lab Test'
             WHEN '2' THEN 'Clinical Observation'
             WHEN '3' THEN 'Claims Attachment'
             WHEN '4' THEN 'Survey'
          END
             AS concept_class_id,
          'S' AS standard_concept,
          LOINC_NUM AS concept_code,
          CASE
             WHEN STATUS = 'ACTIVE' AND CHNG_TYPE = 'ADD'
             THEN
                COALESCE (DATE_LAST_CHANGED, v.latest_update)
             WHEN STATUS = 'TRIAL' AND CHNG_TYPE = 'ADD'
             THEN
                COALESCE (DATE_LAST_CHANGED, v.latest_update)
             ELSE
                v.latest_update
          END
             AS valid_start_date,
          CASE
             WHEN STATUS = 'DISCOURAGED' AND CHNG_TYPE = 'DEL'
             THEN
                DATE_LAST_CHANGED
             WHEN STATUS = 'DISCOURAGED'
             THEN
                v.latest_update
             WHEN STATUS = 'DEPRECATED'
             THEN
                DATE_LAST_CHANGED
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXISTS
                     (SELECT 1
                        FROM MAP_TO m
                       WHERE m.loinc = l.loinc_num)
             THEN
                'U'
             WHEN STATUS = 'DISCOURAGED'
             THEN
                'D'
             WHEN STATUS = 'DEPRECATED'
             THEN
                'D'
             ELSE
                NULL
          END
             AS invalid_reason
     FROM LOINC l, vocabulary v
    WHERE v.vocabulary_id = 'LOINC';
COMMIT;					  

--4 Load classes from loinc_class directly into concept_stage
INSERT INTO concept_stage SELECT * FROM loinc_class;
COMMIT;

--5 Add LOINC hierarchy
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
   SELECT DISTINCT
          NULL AS concept_id,
          SUBSTR (code_text, 1, 256) AS concept_name,
          CASE WHEN CODE > 'LP76352-1' THEN 'Observation' ELSE 'Measurement' END
             AS domain_id,
          'LOINC' AS vocabulary_id,
          'LOINC Hierarchy' AS concept_class_id,
          'C' AS standart_concept,
          CODE AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM loinc_hierarchy
    WHERE CODE LIKE 'LP%';
COMMIT;

--6 Add concept_relationship_stage link to multiaxial hierarchy
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
          IMMEDIATE_PARENT AS concept_code_1,
          CODE AS concept_code_2,
          'Subsumes' AS relationship_id,
          'LOINC' AS vocabulary_id_1,
          'LOINC' AS vocabulary_id_2,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
          NULL AS invalid_reason
     FROM LOINC_HIERARCHY;
COMMIT;

--7 Add concept_relationship_stage to LOINC Classes inside the Class table. Create a 'Subsumes' relationship
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
          l2.concept_code AS concept_code_1,
          l1.concept_code AS concept_code_2,
          'Subsumes' AS relationship_id,
          'LOINC' AS vocabulary_id_1,
          'LOINC' AS vocabulary_id_2,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
          NULL AS invalid_reason
     FROM LOINC_CLASS l1, LOINC_CLASS l2
    WHERE     l1.concept_code LIKE l2.concept_code || '%'
          AND l1.concept_code <> l2.concept_code;
COMMIT;

--8 Add concept_relationship between LOINC and LOINC classes from LOINC
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
          l.class AS concept_code_1,
          l.loinc_num AS concept_code_2,
          'Subsumes' AS relationship_id,
          'LOINC' AS vocabulary_id_1,
          'LOINC' AS vocabulary_id_2,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
          NULL AS invalid_reason
     FROM LOINC_CLASS lc, loinc l
    WHERE lc.concept_code = l.class;
COMMIT;
	
--9 Create CONCEPT_SYNONYM_STAGE
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   (SELECT NULL AS synonym_concept_id,
           LOINC_NUM AS synonym_concept_code,
           SUBSTR (TO_CHAR (RELATEDNAMES2), 1, 1000) AS synonym_name,
           'LOINC' as synonym_vocabulary_id,
           4093769 AS language_concept_id                           -- English
      FROM loinc
     WHERE TO_CHAR (RELATEDNAMES2) IS NOT NULL
    UNION
    SELECT NULL AS synonym_concept_id,
           LOINC_NUM AS synonym_concept_code,
           SUBSTR (LONG_COMMON_NAME, 1, 1000) AS synonym_name,
           'LOINC' as synonym_vocabulary_id,
           4093769 AS language_concept_id                           -- English
      FROM loinc
     WHERE LONG_COMMON_NAME IS NOT NULL
    UNION
    SELECT NULL AS synonym_concept_id,
           LOINC_NUM AS synonym_concept_code,
           SHORTNAME AS synonym_name,
           'LOINC' as synonym_vocabulary_id,
           4093769 AS language_concept_id                           -- English
      FROM loinc
     WHERE SHORTNAME IS NOT NULL);
COMMIT;

--10 Adding Loinc Answer codes
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
   SELECT DISTINCT
          NULL AS concept_id,
          DisplayText AS concept_name,
          'Meas Value' AS domain_id,
          'LOINC' AS vocabulary_id,
          'Answer' AS concept_class_id,
          'S' AS standard_concept,
          AnswerStringID AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM LOINC_ANSWERS la, loinc l
    WHERE la.loinc = l.loinc_num AND AnswerStringID IS NOT NULL; --AnswerStringID may be null
COMMIT;	

--11 Link LOINCs to Answers in concept_relationship_stage
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
                   Loinc AS concept_code_1,
                   AnswerStringID AS concept_code_2,
                   'Has Answer' AS relationship_id,
                   'LOINC' AS vocabulary_id_1,
                   'LOINC' AS vocabulary_id_2,
                   TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM LOINC_ANSWERS
    WHERE AnswerStringID IS NOT NULL;
COMMIT;	

--12 Link LOINCs to Forms in concept_relationship_stage
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
                   ParentLoinc AS concept_code_1,
                   Loinc AS concept_code_2,
                   'Panel contains' AS relationship_id,
                   'LOINC' AS vocabulary_id_1,
                   'LOINC' AS vocabulary_id_2,
                   TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM LOINC_FORMS WHERE Loinc <> ParentLoinc;
COMMIT;	

--13 Add LOINC to SNOMED map
INSERT /*+ APPEND */
      INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT l.maptarget AS concept_code_1,
          l.referencedcomponentid AS concept_code_2,
          'LOINC' AS vocabulary_id_1,
          'SNOMED' AS vocabulary_id_2,
          'LOINC - SNOMED eq' AS relationship_id,
          v.latest_update AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM scccRefset_MapCorrOrFull_INT l, vocabulary v
    WHERE v.vocabulary_id = 'LOINC';
COMMIT;

--14 Add LOINC to CPT map	 
INSERT /*+ APPEND */
      INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT l.fromexpr AS concept_code_1,
          l.toexpr AS concept_code_2,
          'LOINC' AS vocabulary_id_1,
          'CPT4' AS vocabulary_id_2,
          'LOINC - CPT4 eq' AS relationship_id,
          v.latest_update AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM CPT_MRSMAP l, vocabulary v
    WHERE v.vocabulary_id = 'LOINC';
COMMIT;	 

/*
--15 Add replacement relationships
INSERT /*+ APPEND * /
      INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT l.loinc AS concept_code_1,
          l.map_to AS concept_code_2,
          'LOINC' AS vocabulary_id_1,
          'LOINC' AS vocabulary_id_2,
          'Concept replaced by' AS relationship_id,
          v.latest_update AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM MAP_TO l, vocabulary v
    WHERE v.vocabulary_id = 'LOINC';
COMMIT;
*/

--16 Add mapping from deprecated to fresh concepts
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

--17 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;

--18 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;	

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script