/**************************************************************************
* Copyright 2020 Observational Health Data Sciences and Informatics (OHDSI)
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
* Authors: Timur Vakhitov, Dmitry Dymshyts
* Date: 2020
**************************************************************************/

--1. Update latest_update field to new date 
-- doesn't work
DO $_$ BEGIN PERFORM VOCABULARY_PACK.SetLatestUpdate (pVocabularyName => 'CIM10',pVocabularyDate =>(SELECT vocabulary_date
FROM dev_cim10.CIM10_2020
LIMIT 1),pVocabularyVersion =>(SELECT vocabulary_version
FROM dev_cim10.CIM10_2020
LIMIT 1),pVocabularyDevSchema => 'DEV_CIM10');

END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;

TRUNCATE TABLE concept_relationship_stage;

TRUNCATE TABLE concept_synonym_stage;

TRUNCATE TABLE pack_content_stage;

TRUNCATE TABLE drug_strength_stage;

--3. Create temporary tables with classes and modifiers from XML source
--modifier classes
DROP TABLE IF EXISTS modifier_classes;

CREATE UNLOGGED TABLE modifier_classes 
AS
SELECT s1.modifierclass_code,
       s1.modifierclass_modifier,
       s1.superclass_code,
       s1.rubric_id,
       s1.rubric_kind,
       l.rubric_label
FROM (SELECT *
      FROM (SELECT (xpath ('./@code',i.xmlfield))[1]::VARCHAR modifierclass_code,
                   (xpath('./@modifier',i.xmlfield))[1]::VARCHAR modifierclass_modifier,
                   (xpath('./SuperClass/@code',i.xmlfield))[1]::VARCHAR superclass_code,
                   UNNEST(xpath ('./Rubric/@id',i.xmlfield))::VARCHAR rubric_id,
                   UNNEST(xpath ('./Rubric/@kind',i.xmlfield))::VARCHAR rubric_kind,
                   UNNEST(xpath ('./Rubric',i.xmlfield)) rubric_label
            FROM (SELECT UNNEST(xpath ('/ClaML/ModifierClass',i.xmlfield)) xmlfield
                  FROM dev_cim10.CIM10_2020 i) AS i) AS s0) AS s1
  LEFT JOIN LATERAL (SELECT STRING_AGG(LTRIM(REGEXP_REPLACE(rubric_label,'\t','','g')),'') AS rubric_label
                     FROM (SELECT UNNEST(xpath ('//text()',s1.rubric_label))::VARCHAR rubric_label) AS s0) l ON TRUE;

--classes
DROP TABLE IF EXISTS classes;

CREATE UNLOGGED TABLE classes 
AS
WITH classes
AS
(SELECT s1.class_code,
       s1.rubric_kind,
       s1.superclass_code,
       s1.modifiedby_code,
       l.rubric_label
FROM (SELECT *
      FROM (SELECT (xpath ('./@code',i.xmlfield))[1]::VARCHAR class_code,
                   l.superclass_code,
                   l1.modifiedby_code,
                   UNNEST(xpath ('./Rubric/@kind',i.xmlfield))::VARCHAR rubric_kind,
                   UNNEST(xpath ('./Rubric',i.xmlfield)) rubric_label
            FROM (SELECT UNNEST(xpath ('/ClaML/Class',i.xmlfield)) xmlfield
                  FROM dev_cim10.CIM10_2020 i) AS i
              LEFT JOIN LATERAL (SELECT UNNEST(xpath ('./SuperClass/@code',i.xmlfield))::VARCHAR superclass_code) l ON TRUE
              LEFT JOIN LATERAL (SELECT UNNEST(xpath ('./ModifiedBy/@code',i.xmlfield))::VARCHAR modifiedby_code) l1 ON TRUE) AS s0) AS s1
  LEFT JOIN LATERAL (SELECT STRING_AGG(LTRIM(REGEXP_REPLACE(rubric_label,'\t','','g')),'') AS rubric_label
                     FROM (SELECT UNNEST(xpath ('//text()',s1.rubric_label))::VARCHAR rubric_label) AS s0) l ON TRUE)
--modify classes_table replacing  preferred name to preferredLong where it's possible
SELECT a.class_code,a.rubric_kind,a.superclass_code,a.modifiedby_code,COALESCE (b.rubric_label,a.rubric_label) AS rubric_label FROM classes a
  LEFT JOIN classes b
         ON a.class_code = b.class_code
        AND a.rubric_kind = 'preferred'
        AND b.rubric_kind = 'preferredLong'
WHERE a.rubric_kind != 'preferredLong';

--4. Fill the concept_stage
INSERT INTO concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
WITH codes_need_modified
AS
(
--define all the concepts having modifiers, use filter a.rubric_kind ='modifierlink'
SELECT DISTINCT a.class_code,
       a.rubric_label,
       a.superclass_code,
       b.class_code AS concept_code,
       b.rubric_label AS concept_name,
       b.superclass_code AS super_concept_code
FROM classes a
  JOIN classes b ON b.class_code LIKE a.class_code || '%'
WHERE a.rubric_kind = 'modifierlink'
AND   b.rubric_kind = 'preferred'
AND   b.class_code NOT LIKE '%-%'),codes AS (SELECT a.*,
                                                    b.modifierclass_code,
                                                    b.rubric_label AS modifer_name
                                             FROM codes_need_modified a
                                               LEFT JOIN modifier_classes b
                                                      ON SUBSTRING (b.modifierclass_modifier,'^...(.*?)_') = a.class_code
                                                     AND modifierclass_modifier NOT LIKE '%_6'
                                                     AND b.rubric_kind = 'preferred'),concepts_modifiers AS (
--add all the modifiers using patterns described in a table
--'I70M10_4' with or without gangrene related to gout, seems to be a bug, modifier says [See site code at the beginning of this chapter]
SELECT a.concept_code || b.modifierclass_code AS concept_code,
       REGEXP_REPLACE(a.concept_name,'[A-Z]\d\d(\.|-|$).*','','g') || ', ' ||LOWER(REGEXP_REPLACE(b.modifer_name,'[A-Z]\d\d(\.|-|$).*','','g')) AS concept_name
FROM codes a
  JOIN codes b
    ON SUBSTRING (a.rubric_label,'\D\d\d') = b.concept_code
   AND a.rubric_label = b.rubric_label
   AND a.class_code != b.class_code
WHERE (
--modifyer with "." is added to code without "." and vice ver
(a.concept_code NOT LIKE '%.%' AND b.modifierclass_code LIKE '%.%') OR (a.concept_code LIKE '%.%' AND b.modifierclass_code NOT LIKE '%.%'))
UNION
--basic modifiers having relationship modifier - concept
SELECT a.concept_code || a.modifierclass_code AS concept_code,
       a.concept_name || ', ' || a.modifer_name
FROM codes a
WHERE ((a.concept_code NOT LIKE '%.%' AND a.modifierclass_code LIKE '%.%') OR (a.concept_code LIKE '%.%' AND a.modifierclass_code NOT LIKE '%.%'))
AND   a.modifierclass_code IS NOT NULL) SELECT concept_name,NULL AS domain_id,'CIM10' AS vocabulary_id,CASE WHEN LENGTH(concept_code) = 3 THEN 'ICD10 Hierarchy' ELSE 'ICD10 code' END AS concept_class_id,NULL AS standard_concept,concept_code,(SELECT latest_update
                                                                                                                                                                                                                                                  FROM vocabulary
                                                                                                                                                                                                                                                  WHERE vocabulary_id = 'CIM10') AS valid_start_date,TO_DATE('20991231','YYYYMMDD') AS valid_end_date,NULL AS invalid_reason FROM (
--full list of concepts 
SELECT *
FROM concepts_modifiers
UNION
SELECT class_code,
       CASE
         WHEN rubric_label LIKE 'Emergency use of%' THEN rubric_label
         ELSE REGEXP_REPLACE(rubric_label,'[A-Z]\d\d(\.|-|$).*','','g')
-- remove related code (A52.7) i.e.  Late syphilis of kidneyA52.7 but except of cases like "Emergency use of U07.0"

       END AS concept_name
FROM classes
WHERE rubric_kind = 'preferred'
AND   class_code NOT LIKE '%-%') AS s0 WHERE concept_code ~ '[A-Z]\d\d.*' AND concept_code !~ 'M(21.3|21.5|21.6|21.7|21.8|24.3|24.7|54.2|54.3|54.4|54.5|54.6|65.3|65.4|70.0|70.2|70.3|70.4|70.5|70.6|70.7|71.2|72.0|72.1|72.2|76.1|76.2|76.3|76.4|76.5|76.6|76.7|76.8|76.9|77.0|77.1|77.2|77.3|77.4|77.5|79.4|85.2|88.0|94.0)+\d+';

UPDATE concept_stage cs
   SET concept_name = i.new_name
FROM (SELECT c.concept_code,
             cs.concept_name || ' ' ||LOWER(c.concept_name) AS new_name
      FROM concept_stage c
        LEFT JOIN classes cl ON c.concept_code = cl.class_code
        LEFT JOIN concept_stage cs ON cl.superclass_code = cs.concept_code
      WHERE c.concept_code ~ '((Y06)|(Y07)).+'
      AND   rubric_kind = 'preferred'
      UNION ALL
      SELECT c.concept_code,
             c.concept_name || ' as the cause of abnormal reaction of the patient, or of later complication, without mention of misadventure at the time of the procedure'
      FROM concept_stage c
      WHERE c.concept_code ~ '((Y83)|(Y84)).+'
      UNION ALL
      SELECT c.concept_code,
             'Adverse effects in the therapeutic use of ' ||LOWER(concept_name)
      FROM concept_stage c
      WHERE concept_code >= 'Y40'
      AND   concept_code < 'Y60'
      UNION ALL
      SELECT c.concept_code,
             REPLACE(cs.concept_name,'during%','') || ' ' ||LOWER(c.concept_name)
      FROM concept_stage c
        LEFT JOIN classes cl ON c.concept_code = cl.CLASS_CODE
        LEFT JOIN concept_stage cs ON cl.SUPERCLASS_CODE = cs.concept_code
      WHERE c.concept_code ~ '((Y60)|(Y61)|(Y62)).+'
      AND   rubric_kind = 'preferred') i
WHERE cs.concept_code = i.concept_code;

--temporary solution --6 digit codes
INSERT INTO concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date
)
SELECT concept_name || ', ' || rubric_label AS concept_name,
       NULL,
       'CIM10',
       'ICD10 code',
       NULL,
       c.concept_code || modifierclass_code,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'CIM10'),
       TO_DATE('20991231','yyyyMMdd')
FROM concept_Stage c
  JOIN modifier_classes a
    ON (c.concept_Code LIKE 'F00.__'
    OR c.concept_Code LIKE 'F01.__'
    OR c.concept_Code LIKE 'F02.__')
-- these are codes_need_modified

   AND modifierclass_modifier = 'S05F00_6';

--5. Inherit external relations from international ICD10 whenever possible
INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date
)
SELECT DISTINCT -- there are duplicates in "classes" table
       c.concept_code AS concept_code_1,
       c2.concept_code AS concept_code_2,
       'CIM10' AS vocabulary_id_1,
       c2.vocabulary_id AS vocabulary_id_2,
       r.relationship_id AS relationship_id,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'CIM10') AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date
FROM concept_stage cs
  JOIN concept c
    ON c.vocabulary_id = 'ICD10'
   AND cs.concept_code = c.concept_code
  JOIN concept_relationship r
    ON r.concept_id_1 = c.concept_id
   AND r.invalid_reason IS NULL
   AND r.relationship_id IN ('Maps to', 'Maps to value')

  JOIN concept c2 ON c2.concept_id = r.concept_id_2;

--6. Append result to concept_relationship_stage table
DO $_$ BEGIN PERFORM VOCABULARY_PACK.ProcessManualRelationships ();

END $_$;

--7. Working with replacement mappings
DO $_$ BEGIN PERFORM VOCABULARY_PACK.CheckReplacementMappings ();

END $_$;

--8. Add mapping from deprecated to fresh concepts
DO $_$ BEGIN PERFORM VOCABULARY_PACK.AddFreshMAPSTO ();

END $_$;

--9. Add mapping from deprecated to fresh concepts for 'Maps to value'
DO $_$ BEGIN PERFORM VOCABULARY_PACK.AddFreshMapsToValue ();

END $_$;

--10. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$ BEGIN PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO ();

END $_$;

--11. Delete ambiguous 'Maps to' mappings
DO $_$ BEGIN PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO ();

END $_$;

--12. Add "subsumes" relationship between concepts where the concept_code is like of another
CREATE INDEX IF NOT EXISTS trgm_idx 
  ON concept_stage  USING GIN(concept_code devv5.gin_trgm_ops);

--for LIKE patterns
ANALYZE concept_stage;

INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
SELECT DISTINCT c1.concept_code AS concept_code_1,
       c2.concept_code AS concept_code_2,
       c1.vocabulary_id AS vocabulary_id_1,
       c1.vocabulary_id AS vocabulary_id_2,
       'Subsumes' AS relationship_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM concept_stage c1,
     concept_stage c2
WHERE c2.concept_code LIKE c1.concept_code || '%'
AND   c1.concept_code <> c2.concept_code
AND   NOT EXISTS (SELECT 1
                  FROM concept_relationship_stage r_int
                  WHERE r_int.concept_code_1 = c1.concept_code
                  AND   r_int.concept_code_2 = c2.concept_code
                  AND   r_int.relationship_id = 'Subsumes');

DROP INDEX trgm_idx;

--13. Update domain_id for ICD10 from target concepts domains
UPDATE concept_stage cs
   SET domain_id = i.domain_id
FROM (SELECT DISTINCT cs1.concept_code,
             FIRST_VALUE(c2.domain_id) OVER (PARTITION BY cs1.concept_code ORDER BY CASE c2.domain_id WHEN 'Condition' THEN 1 WHEN 'Observation' THEN 2 WHEN 'Procedure' THEN 3 WHEN 'Measurement' THEN 4 WHEN 'Device' THEN 5 ELSE 6 END) AS domain_id
      FROM concept_relationship_stage crs
        JOIN concept_stage cs1
          ON cs1.concept_code = crs.concept_code_1
         AND cs1.vocabulary_id = crs.vocabulary_id_1
         AND cs1.vocabulary_id = 'CIM10'
        JOIN concept c2
          ON c2.concept_code = crs.concept_code_2
         AND c2.vocabulary_id = crs.vocabulary_id_2
      WHERE crs.relationship_id = 'Maps to'
      AND   crs.invalid_reason IS NULL
      UNION ALL
      SELECT DISTINCT cs1.concept_code,
             FIRST_VALUE(c2.domain_id) OVER (PARTITION BY cs1.concept_code ORDER BY CASE c2.domain_id WHEN 'Condition' THEN 1 WHEN 'Observation' THEN 2 WHEN 'Procedure' THEN 3 WHEN 'Measurement' THEN 4 WHEN 'Device' THEN 5 ELSE 6 END)
      FROM concept_relationship cr
        JOIN concept c1
          ON c1.concept_id = cr.concept_id_1
         AND c1.vocabulary_id = 'CIM10'
        JOIN concept c2 ON c2.concept_id = cr.concept_id_2
        JOIN concept_stage cs1
          ON cs1.concept_code = c1.concept_code
         AND cs1.vocabulary_id = c1.vocabulary_id
      WHERE cr.relationship_id = 'Maps to'
      AND   cr.invalid_reason IS NULL
      AND   NOT EXISTS (SELECT 1
                        FROM concept_relationship_stage crs_int
                        WHERE crs_int.concept_code_1 = cs1.concept_code
                        AND   crs_int.vocabulary_id_1 = cs1.vocabulary_id
                        AND   crs_int.relationship_id = cr.relationship_id)) i
WHERE i.concept_code = cs.concept_code
AND   cs.vocabulary_id = 'CIM10';

--Manual fix for concepts without mapping
UPDATE concept_stage
   SET domain_id = 'Observation'
WHERE domain_id IS NULL;

--14. Clean up
DROP TABLE modifier_classes;

DROP TABLE classes;

--additional French work
-- Preserve original names in concept_synonym_stage
UPDATE concept_stage a
   SET concept_name = b.name_4
FROM codes b
WHERE a.concept_code = b.code_4m
AND   concept_code IN ('D51','U07.4','D51.8','U07.3','U07.2','D51.3','U07.5','U07.7','U07.8','U07.9','U07.6');

UPDATE concept_stage a
   SET concept_name = 'Anémie par carence en vitamine B12'
WHERE concept_code = 'D51';

INSERT INTO concept_synonym_stage
(
  synonym_name,
  synonym_concept_code,
  synonym_vocabulary_id,
  language_concept_id
)
SELECT concept_name,
       concept_code,
       'CIM10',
       4180190 -- French language
       FROM concept_stage;

--update concept_Stage, set english names from ICD10
UPDATE concept_stage cs
   SET concept_name = c.concept_name
FROM concept c
WHERE c.concept_code = cs.concept_code
AND   c.vocabulary_id = 'ICD10';

-- 11427 rows affected in 2019 version
DO $_$ BEGIN PERFORM VOCABULARY_PACK.ProcessManualConcepts ();

END $_$;

--remove duplicates
DELETE
FROM concept_stage cs
WHERE EXISTS (SELECT 1
              FROM concept_stage cs_int
              WHERE cs_int.concept_code = cs.concept_code
              AND   cs_int.ctid > cs.ctid);

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
