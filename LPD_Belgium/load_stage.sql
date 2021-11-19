/**************************************************************************
* Copyright 2016 Observational Health Data Sciences AND Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may NOT use this file except IN compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to IN writing, software
* distributed under the License is distributed ON an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* Authors: Polina Talapova, Dmitry Dymshyts
* Date: Nov 2021
**************************************************************************/
-- run Latest Update
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'LPD_Belgium',
	pVocabularyDate			=> TO_DATE ('20210801', 'yyyymmdd'),
	pVocabularyVersion		=> 'LPD_Belgium 2021-SEP-01',
	pVocabularyDevSchema	=> 'dev_belg'
);
END $_$;

-- truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

-- add manual work
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

-- add mappings using the crosswalk between GRR and RxN/RxE vocabularies
INSERT INTO concept_relationship_stage
(concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date,invalid_reason)
WITH t1
AS
(
  SELECT DISTINCT prod_prd_id AS concept_code_1,
       c2.concept_code AS concept_code_2,
       c2.vocabulary_id AS vocabulary_id_2
FROM belg_source_full a
  JOIN concept c
    ON c.concept_code = a.prod_prd_eid
   AND c.vocabulary_id = 'GGR'
  JOIN concept_relationship r
    ON c.concept_id = r.concept_id_1
   AND r.relationship_id = 'Maps to'
  JOIN concept c2 ON c2.concept_id = r.concept_id_2
  JOIN  concept_relationship r2 on r2.concept_id_1 = r.concept_id_2),
  t2 as(
SELECT DISTINCT concept_code_1 AS concept_code_1,
       concept_code_2 AS concept_code_2,
       'LPD_Belgium' AS vocabulary_id_1,
       vocabulary_id_2 AS vocabulary_id_2,
       'Maps to' as relationship_id, 
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM t1 ) 
select * from t2 cs
WHERE NOT EXISTS -- to prevent duplicates
(SELECT 1 FROM concept_relationship_stage crs
                  WHERE crs.concept_code_1 = cs.concept_code_1
                  AND   crs.vocabulary_id_1 = cs.vocabulary_id_1
                  AND   crs.concept_code_2 = cs.concept_code_2
                  AND   crs.vocabulary_id_2 = cs.vocabulary_id_2
                  AND   crs.relationship_id = cs.relationship_id
		  ); -- 7015

-- add mappings from the lookup of map_drug table
INSERT INTO concept_relationship_stage
(concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date,invalid_reason)
WITH t1 AS
(
  SELECT *
  FROM devv5.concept
  WHERE vocabulary_id = 'LPD_Belgium'
  AND   concept_id IN (SELECT concept_id_1
                       FROM devv5.concept_relationship
                       WHERE relationship_id = 'Maps to'
                       AND   invalid_reason IS NULL)
)
SELECT DISTINCT 
       b.prod_prd_id as concept_code_1,-- b.prd_name, 
       a.concept_code as concept_code_2,-- a.concept_name,
     'LPD_Belgium' AS vocabulary_id_1,
       a.vocabulary_id AS vocabulary_id_2,
       'Maps to' as relationship_id, 
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM map_drug_lookup_21 a
  JOIN belg_source_full b ON prod_prd_eid = source_code
  LEFT JOIN concept_relationship_stage c ON b.prod_prd_id = c.concept_code_1
  LEFT JOIN t1 ON b.prod_prd_id = t1.concept_code
WHERE c.concept_code_1 IS NULL
AND   t1.concept_code IS NULL; -- 2824

-- update domains of Devices, var.1
UPDATE concept_stage a
   SET domain_id = k.domain_id,
       concept_class_id = k.concept_class_id
FROM (SELECT a.concept_code,
             'Device' AS domain_id,
             'Device' AS concept_class_id
      FROM concept_stage a
        JOIN concept_relationship_stage b ON b.concept_code_1 = a.concept_code
        JOIN concept c
          ON c.concept_code = b.concept_code_2
         AND c.vocabulary_id = b.vocabulary_id_2
         AND c.domain_id = 'Device') k
WHERE k.concept_code = a.concept_code; -- 1465 

-- update domains of Devices, var.2
UPDATE concept_stage a
   SET domain_id = k.domain_id,
       concept_class_id = k.concept_class_id
FROM (SELECT DISTINCT concept_code,
             'Device' AS domain_id,
             'Device' AS concept_class_id
      FROM concept_stage
      WHERE concept_code NOT IN (SELECT concept_code_1
                                 FROM concept_relationship_stage
                                 WHERE relationship_id = 'Maps to')
      AND   standard_concept IS NULL
      AND   invalid_reason IS NULL
      AND   concept_code NOT IN (SELECT belg_code
                                 FROM belg_all_relationships
                                 WHERE relationship_id = 'Maps to'
                                 AND   r_invalid_reason IS NULL)
      AND   concept_class_id NOT IN ('Brand Name','Device','Dose Form'))k
      --and concept_code not in (select source_code from lpd_belg_wt)) k
WHERE k.concept_code = a.concept_code; -- 9635

-- Make devices non-standard 
UPDATE concept_Stage
   SET standard_concept = NULL
WHERE domain_id = 'Device';

-- perform mapping replacement using function below
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

-- add mappings from deprecated to fresh codes
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

-- deprecate 'Maps to' mappings to deprecated AND updated codes
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO(); 
END $_$;

-- remove ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DELETEAmbiguousMAPSTO();
END $_$;

-- run checks
SELECT qa_tests.Check_Stage_Tables();

-- if everything is fine, uncomment the query and run Generic Update
--SELECT devv5.genericupdate();
