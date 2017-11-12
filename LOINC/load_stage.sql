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
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'LOINC',
                                          pVocabularyDate        => TO_DATE ('20170623', 'yyyymmdd'),
                                          pVocabularyVersion     => 'LOINC 2.61',
                                          pVocabularyDevSchema   => 'DEV_LOINC');
END;
/
COMMIT;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

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
          CASE 
             WHEN CLASSTYPE = '1' THEN 'Measurement'
             WHEN CLASSTYPE = '2' and SCALE_TYP ='Qn' THEN 'Measurement'
             WHEN CLASSTYPE = '2' and SCALE_TYP !='Qn' THEN 'Observation'
             WHEN CLASSTYPE = '3' THEN 'Observation'
             WHEN CLASSTYPE = '4' THEN 'Observation'
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
          COALESCE (c.valid_start_date, v.latest_update) AS valid_start_date,
          CASE
             WHEN STATUS IN ('DISCOURAGED', 'DEPRECATED') 
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

--And delete wrong relationship ('History & Physical order set' to 'FLACC pain assessment panel', AVOF-352). 
--chr(38)=&
DELETE FROM concept_relationship_stage
      WHERE concept_code_1 = 'PANEL.H'||chr(38)||'P' AND concept_code_2 = '38213-5' AND relationship_id = 'Subsumes';
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
           4180186 AS language_concept_id                           -- English
      FROM loinc
     WHERE TO_CHAR (RELATEDNAMES2) IS NOT NULL
    UNION
    SELECT NULL AS synonym_concept_id,
           LOINC_NUM AS synonym_concept_code,
           SUBSTR (LONG_COMMON_NAME, 1, 1000) AS synonym_name,
           'LOINC' as synonym_vocabulary_id,
           4180186 AS language_concept_id                           -- English
      FROM loinc
     WHERE LONG_COMMON_NAME IS NOT NULL
    UNION
    SELECT NULL AS synonym_concept_id,
           LOINC_NUM AS synonym_concept_code,
           SHORTNAME AS synonym_name,
           'LOINC' as synonym_vocabulary_id,
           4180186 AS language_concept_id                           -- English
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


--15 Add replacement relationships
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
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
    WHERE v.vocabulary_id = 'LOINC'
	UNION ALL
	/*
	for some pairs of concepts LOINC gives us a reverse mapping 'Concept replaced by'
	so we need to deprecate old mappings
	*/
	SELECT c1.concept_code,
		   c2.concept_code,
		   c1.vocabulary_id,		   
		   c2.vocabulary_id,
		   r.relationship_id,
		   r.valid_start_date,
		   (SELECT latest_update - 1
			  FROM vocabulary
			 WHERE vocabulary_id = 'LOINC' AND latest_update IS NOT NULL),
		   'D'
	  FROM concept c1,
		   concept c2,
		   concept_relationship r,
		   map_to mt
	 WHERE     c1.concept_id = r.concept_id_1
		   AND c2.concept_id = r.concept_id_2
		   AND c1.vocabulary_id = 'LOINC'
		   AND c2.vocabulary_id = 'LOINC'
		   AND r.relationship_id IN ('Concept replaced by', 'Maps to')
		   AND r.invalid_reason IS NULL
		   AND mt.map_to = c1.concept_code
		   AND mt.loinc = c2.concept_code;
COMMIT;

--16 Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
/
COMMIT;

--17 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
/
COMMIT;	

--18 Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
/
COMMIT;		 

--19 Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
/
COMMIT;

--20 Set the proper concept_class_id for children of "Document ontology" (AVOF-352)
UPDATE concept_stage
   SET concept_class_id = 'LOINC Document Type'
 WHERE concept_code IN
           (SELECT descendant_concept_code
              FROM (  SELECT descendant_concept_code, descendant_vocabulary_id
                        FROM (    SELECT descendant_concept_code, descendant_vocabulary_id
                                    FROM (SELECT crs.concept_code_1 AS ancestor_concept_code,
                                                 crs.vocabulary_id_1 AS ancestor_vocabulary_id,
                                                 crs.concept_code_2 AS descendant_concept_code,
                                                 crs.vocabulary_id_2 AS descendant_vocabulary_id
                                            FROM concept_relationship_stage crs
                                                 JOIN relationship s ON s.relationship_id = crs.relationship_id AND s.defines_ancestry = 1
                                                 JOIN concept_stage c1
                                                     ON c1.concept_code = crs.concept_code_1 AND c1.vocabulary_id = crs.vocabulary_id_1 AND c1.invalid_reason IS NULL AND c1.vocabulary_id = 'LOINC'
                                                 JOIN concept_stage c2
                                                     ON c2.concept_code = crs.concept_code_2 AND c1.vocabulary_id = crs.vocabulary_id_2 AND c2.invalid_reason IS NULL AND c2.vocabulary_id = 'LOINC'
                                           WHERE crs.invalid_reason IS NULL)
                              CONNECT BY PRIOR descendant_concept_code = ancestor_concept_code AND descendant_vocabulary_id = ancestor_vocabulary_id
                              START WITH ancestor_concept_code = 'LP76352-1')
                    GROUP BY descendant_concept_code, descendant_vocabulary_id) ca
                   JOIN concept_stage c2 ON c2.concept_code = ca.descendant_concept_code AND c2.vocabulary_id = ca.descendant_vocabulary_id AND c2.standard_concept IS NOT NULL);
COMMIT;

--21 Set the proper domain_id='Measurement' for perents where ALL childrens are 'Measurement' too (AVOF-612)
UPDATE concept_stage cs
   SET cs.domain_id = 'Measurement'
 WHERE     cs.concept_code IN
               (SELECT DISTINCT root_ancestor_concept_code
                  FROM (SELECT root_ancestor_concept_code,
                               COUNT (*) OVER (PARTITION BY root_ancestor_concept_code) cnt_descendant,
                               SUM (CASE WHEN descendant_domain = 'Measurement' THEN 1 ELSE 0 END) OVER (PARTITION BY root_ancestor_concept_code) sum_childen_measurement
                          FROM (SELECT root_ancestor_concept_code, descendant_concept_code, descendant_domain
                                  FROM (  SELECT root_ancestor_concept_code,
                                                 descendant_concept_code,
                                                 descendant_vocabulary_id,
                                                 descendant_domain
                                            FROM (    SELECT CONNECT_BY_ROOT ancestor_concept_code AS root_ancestor_concept_code,
                                                             descendant_concept_code,
                                                             descendant_vocabulary_id,
                                                             descendant_domain
                                                        FROM (SELECT crs.concept_code_1 AS ancestor_concept_code,
                                                                     crs.vocabulary_id_1 AS ancestor_vocabulary_id,
                                                                     crs.concept_code_2 AS descendant_concept_code,
                                                                     crs.vocabulary_id_2 AS descendant_vocabulary_id,
                                                                     c2.domain_id AS descendant_domain
                                                                FROM concept_relationship_stage crs
                                                                     JOIN relationship s ON s.relationship_id = crs.relationship_id AND s.defines_ancestry = 1
                                                                     JOIN concept_stage c1
                                                                         ON     c1.concept_code = crs.concept_code_1
                                                                            AND c1.vocabulary_id = crs.vocabulary_id_1
                                                                            AND c1.invalid_reason IS NULL
                                                                            AND c1.vocabulary_id = 'LOINC'
                                                                     JOIN concept_stage c2
                                                                         ON     c2.concept_code = crs.concept_code_2
                                                                            AND c1.vocabulary_id = crs.vocabulary_id_2
                                                                            AND c2.invalid_reason IS NULL
                                                                            AND c2.vocabulary_id = 'LOINC'
                                                               WHERE crs.invalid_reason IS NULL)
                                                  CONNECT BY PRIOR descendant_concept_code = ancestor_concept_code AND descendant_vocabulary_id = ancestor_vocabulary_id)
                                        GROUP BY root_ancestor_concept_code,
                                                 descendant_concept_code,
                                                 descendant_vocabulary_id,
                                                 descendant_domain) ca
                                       JOIN concept_stage c2 ON c2.concept_code = ca.descendant_concept_code AND c2.vocabulary_id = ca.descendant_vocabulary_id AND c2.standard_concept IS NOT NULL))
                 WHERE cnt_descendant = sum_childen_measurement)
       AND cs.domain_id <> 'Measurement';
COMMIT;
 -- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script