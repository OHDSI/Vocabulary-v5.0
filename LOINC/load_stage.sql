/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov, Christian Reich
* Date: 2016
**************************************************************************/

--1. Update latest_update field to new date 
BEGIN
   EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN latest_update';
EXCEPTION WHEN OTHERS THEN NULL;
END;
ALTER TABLE vocabulary ADD latest_update DATE;
update vocabulary set latest_update=to_date('20151221','yyyymmdd'), vocabulary_version='LOINC 2.54' where vocabulary_id='LOINC'; commit;

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
                COALESCE (c.valid_start_date, v.latest_update)
             WHEN STATUS = 'TRIAL' AND CHNG_TYPE = 'ADD'
             THEN
                COALESCE (c.valid_start_date, v.latest_update)
             ELSE
                v.latest_update
          END
             AS valid_start_date,
          CASE
             WHEN STATUS = 'DISCOURAGED' AND CHNG_TYPE = 'DEL'
             THEN
                CASE WHEN C.VALID_END_DATE>V.LATEST_UPDATE OR C.VALID_END_DATE  IS NULL THEN V.LATEST_UPDATE ELSE C.VALID_END_DATE END 
             WHEN STATUS = 'DISCOURAGED'
             THEN
                CASE WHEN C.VALID_END_DATE>V.LATEST_UPDATE OR C.VALID_END_DATE  IS NULL THEN V.LATEST_UPDATE ELSE C.VALID_END_DATE END
             WHEN STATUS = 'DEPRECATED'
             THEN
                CASE WHEN C.VALID_END_DATE>V.LATEST_UPDATE OR C.VALID_END_DATE  IS NULL THEN V.LATEST_UPDATE ELSE C.VALID_END_DATE END
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
     FROM LOINC l, vocabulary v, concept c
    WHERE v.vocabulary_id = 'LOINC'
    AND l.LOINC_NUM=c.concept_code(+)
    AND c.vocabulary_id(+)='LOINC';
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
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT l.maptarget AS concept_code_1,
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

--16 Delete duplicate mappings (one concept has multiply target concepts)
DELETE FROM concept_relationship_stage
      WHERE (concept_code_1, relationship_id) IN
               (  SELECT concept_code_1, relationship_id
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
COMMIT;

--17 Delete self-connected mappings ("A 'Concept replaced by' B" and "B 'Concept replaced by' A")
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
COMMIT;

--18 Deprecate concepts if we have no active replacement record in the concept_relationship_stage
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
COMMIT;	

--19 Deprecate replacement records if target concept was depreceted 
MERGE INTO concept_relationship_stage r
     USING (WITH upgraded_concepts
                    AS (SELECT crs.concept_code_1,
                               crs.vocabulary_id_1,
                               crs.concept_code_2,
                               crs.vocabulary_id_2,
                               crs.relationship_id,
                               cs.invalid_reason
                          FROM concept_relationship_stage crs, concept_stage cs
                         WHERE     crs.relationship_id IN ('Concept replaced by',
                                                           'Concept same_as to',
                                                           'Concept alt_to to',
                                                           'Concept poss_eq to',
                                                           'Concept was_a to')
                               AND crs.invalid_reason IS NULL
                               AND crs.concept_code_2 = cs.concept_code
                               AND crs.vocabulary_id_2 = cs.vocabulary_id
                               AND crs.vocabulary_id_1 = crs.vocabulary_id_2
                               AND crs.concept_code_1 <> crs.concept_code_2)
                SELECT u.concept_code_1,
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
COMMIT;

--20 Deprecate concepts if we have no active replacement record in the concept_relationship_stage (yes, again)
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
COMMIT;

--21 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
UPDATE concept_relationship_stage crs
   SET crs.valid_end_date =
          (SELECT latest_update - 1
             FROM vocabulary
            WHERE vocabulary_id IN (crs.vocabulary_id_1, crs.vocabulary_id_2)),
       crs.invalid_reason = 'D'
 WHERE     crs.relationship_id = 'Maps to'
       AND crs.invalid_reason IS NULL
       AND EXISTS
              (SELECT 1
                 FROM concept_stage cs
                WHERE cs.concept_code = crs.concept_code_2 AND cs.vocabulary_id = crs.vocabulary_id_2 AND cs.invalid_reason IN ('U', 'D'));
COMMIT;		

--22 Add mapping from deprecated to fresh concepts
MERGE INTO concept_relationship_stage crs
     USING (WITH upgraded_concepts
                    AS (SELECT DISTINCT concept_code_1,
                                        FIRST_VALUE (concept_code_2) OVER (PARTITION BY concept_code_1 ORDER BY rel_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS concept_code_2,
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
                                  FROM concept_relationship_stage crs, concept_stage cs
                                 WHERE     (   crs.relationship_id IN ('Concept replaced by',
                                                                       'Concept same_as to',
                                                                       'Concept alt_to to',
                                                                       'Concept poss_eq to',
                                                                       'Concept was_a to')
                                            OR (crs.relationship_id = 'Maps to' AND cs.invalid_reason = 'U'))
                                       AND crs.invalid_reason IS NULL
                                       AND ( (crs.vocabulary_id_1 = crs.vocabulary_id_2 AND crs.relationship_id <> 'Maps to') OR crs.relationship_id = 'Maps to')
                                       AND crs.concept_code_2 = cs.concept_code
                                       AND crs.vocabulary_id_2 = cs.vocabulary_id
                                       AND crs.concept_code_1 <> crs.concept_code_2
                                UNION ALL
                                --some concepts might be in 'base' tables, but information about 'U' - in 'stage'
                                SELECT c1.concept_code,
                                       c2.concept_code,
                                       c1.vocabulary_id,
                                       c2.vocabulary_id,
                                       6 AS rel_id
                                  FROM concept c1,
                                       concept c2,
                                       concept_relationship r,
                                       concept_stage cs
                                 WHERE     c1.concept_id = r.concept_id_1
                                       AND c2.concept_id = r.concept_id_2
                                       AND r.concept_id_1 <> r.concept_id_2
                                       AND r.invalid_reason IS NULL
                                       AND r.relationship_id = 'Maps to'
                                       AND cs.vocabulary_id = c2.vocabulary_id
                                       AND cs.concept_code = c2.concept_code
                                       AND cs.invalid_reason = 'U'))
                SELECT CONNECT_BY_ROOT concept_code_1 AS root_concept_code_1,
                       u.concept_code_2,
                       CONNECT_BY_ROOT vocabulary_id_1 AS root_vocabulary_id_1,
                       vocabulary_id_2,
                       'Maps to' AS relationship_id,
                       (SELECT latest_update
                          FROM vocabulary
                         WHERE vocabulary_id = vocabulary_id_2)
                          AS valid_start_date,
                       TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
                       NULL AS invalid_reason
                  FROM upgraded_concepts u
                 WHERE CONNECT_BY_ISLEAF = 1
            CONNECT BY NOCYCLE PRIOR concept_code_2 = concept_code_1
            START WITH concept_code_1 IN (SELECT concept_code_1 FROM upgraded_concepts
                                          MINUS
                                          SELECT concept_code_2 FROM upgraded_concepts)) i
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
           WHERE crs.invalid_reason IS NOT NULL;
COMMIT;

--23 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;

--24 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;	

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script