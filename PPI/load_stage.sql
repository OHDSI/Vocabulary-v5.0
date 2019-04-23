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
* Authors: Polina Talapova, Dmitry Dymshyts
* Date: 2019
**************************************************************************/

--1. Update a 'latest_update' field to a new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate( 
	pVocabularyName			=> 'PPI',
	pVocabularyDate			=> TO_DATE ('2018-12-28' ,'yyyy-mm-dd'), -- Date of Version Update from PPI Codebook
	pVocabularyVersion		=> 'Codebook Version 0.3.34',  -- Current Codebook Version from PPI Codebook
	pVocabularyDevSchema	=> 'dev_ppi'
);
END $_$;
 
--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

---------------------------
----CONCEPT STAGE----
--------------------------
--3. Load PPI concepts using a manual table of 'all_source_0334_LS' 
INSERT INTO CONCEPT_STAGE
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
SELECT CASE
         WHEN TYPE = 'Module' THEN display -- Modules do not require name changes
         ELSE new_display -- new PPI concept name (AVOF-1514)
       END AS concept_name,
       CASE
         WHEN b.concept_id IS NOT NULL THEN b.domain_id -- being mapped to Standard LOINC/SNOMED concept source concept inherit its domain 
         ELSE 'Observation' -- requirement for a questionnaire-like vocabulary
       END AS domain_id,
       'PPI' AS vocabulary_id,
       TYPE AS concept_class_id, -- can be Answer/Question/Topic/Module
       CASE        -- PPI Topics and Modules are considered to be Standard too (previously they were Classification concepts) 
         WHEN b.vocabulary_id IN ('LOINC','SNOMED') THEN NULL  -- if PPI source concept has a standard SNOMED/LOINC equivalent, it is considered to be Non-standard
         ELSE 'S' -- if PPI source concept does not have a standard SNOMED/LOINC equivalent, it is considered to be Standard
       END AS standard_concept,
       COALESCE(a.short_code,SUBSTRING(a.pmi_code,1,50)) AS concept_code, --  when a source short_code is absent, too long pmi_code should be cut and added to the CONCEPT_SYNONYM table
       TO_DATE(last_update,'mm/dd/yyyy'), -- given by the source
       TO_DATE('20991231','yyyymmdd')
FROM all_source_0334_LS A
  LEFT JOIN concept b
         ON a.concept_code = b.concept_code
        AND b.vocabulary_id IN ('LOINC', 'SNOMED') 
        AND b.standard_concept = 'S'
WHERE a.relationship_id = 'Maps to';

--4. Add PPI Measurement values using 'concept' table 
INSERT INTO CONCEPT_STAGE
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
SELECT concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date
FROM concept 
WHERE vocabulary_id = 'PPI'
AND   invalid_reason IS NULL
AND   (concept_class_id = 'Qualifier Value' -- indicates all PPI Measurement Values 
      OR (domain_id = 'Measurement' AND concept_class_id = 'Clinical Observation') -- genuine PPI Measurements 
      OR concept_code ~ 'protocol\-modifications|^notes$');  -- special PPI Observations (PPI Modifiers and 'Additional notes')

--5. update 'standard_concept' values for PPI Answers which have 'Maps to' PPI and 'Maps to value' SNOMED/LOINC. They should be non-standard
UPDATE concept_stage k
   SET standard_concept = NULL
FROM (SELECT a.concept_code
      FROM concept_stage a
        JOIN all_source_0334_LS b ON a.concept_code = COALESCE (b.short_code,SUBSTRING (b.pmi_code,1,50))
      WHERE b.type = 'Answer'
      AND   pmi_code IN (SELECT pmi_code
                         FROM all_source_0334_LS
                         WHERE concept_id IS NULL
                         AND   relationship_id = 'Maps to')
      AND   pmi_code IN (SELECT pmi_code
                         FROM all_source_0334_LS
                         WHERE relationship_id = 'Maps to value')) k1
WHERE k1.concept_code = k.concept_code;

---------------------------------------
----CONCEPT SYNONYM STAGE----
---------------------------------------
--6. Add all synonymic names from the manual table of 'all_source_0334_ls'
INSERT INTO CONCEPT_SYNONYM_STAGE
(
  synonym_name,
  synonym_concept_code,
  synonym_vocabulary_id,
  language_concept_id
)
 --  the first version of PPI source names
SELECT a.old_display AS synonym_name,
       b.concept_code AS synonym_concept_code,
       'PPI' AS synonym_vocabulary_id,
       4180186 AS language_concept_id -- English language
       FROM all_source_0334_ls a
  JOIN CONCEPT_STAGE b ON COALESCE (a.short_code,SUBSTRING (a.pmi_code,1,50)) = b.concept_code
WHERE a.old_display IS NOT NULL 

UNION ALL 
 -- the second version of PPI source names
SELECT a.display AS synonym_name,
       b.concept_code AS synonym_concept_code,
       'PPI' AS synonym_vocabulary_id,
       4180186 AS language_concept_id-- English language
       FROM all_source_0334_ls a
  JOIN concept_stage b ON COALESCE (a.short_code,SUBSTRING (a.pmi_code,1,50)) = b.concept_code
  WHERE relationship_id = 'Maps to' 

UNION ALL
-- too long alpha character pmi_codes (there is no other way to preserve them)
SELECT a.pmi_code AS synonym_name, 
       b.concept_code AS synonym_concept_code,
       'PPI' AS synonym_vocabulary_id,
       4180186 AS language_concept_id-- English language
       FROM all_source_0334_ls a
  JOIN concept_stage b ON COALESCE (a.short_code,SUBSTRING (a.pmi_code,1,50)) = b.concept_code
  WHERE relationship_id = 'Maps to'
  AND short_code is null
  AND length (pmi_code)>50; 
 
-------------------------------------------
----CONCEPT RELATIONSHIP STAGE----
-------------------------------------------
--7. Build 'Maps to' and 'Maps to value' relationships from PPI concepts to SNOMED/LOINC Standard concepts using the manual table of 'all_source_0334_ls'
INSERT INTO CONCEPT_RELATIONSHIP_STAGE
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
SELECT COALESCE(a.short_code,SUBSTRING(a.pmi_code,1,50)) AS concept_code_1,  -- PPI concept code can be represenеed by either PMI_code or short_code in a case when length of PMI_code is inappropriate 
       c.concept_code AS concept_code_2, -- SNOMED/LOINC concept code
       'PPI' AS vocabulary_id_1,
       c.vocabulary_id AS vocabulary_id_2,
       a.relationship_id AS relationship_id, -- 'Maps to' and 'Maps to value'
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM all_source_0334_ls a
JOIN  CONCEPT c
    ON a.concept_code = c.concept_code
   WHERE c.vocabulary_id IN ('LOINC', 'SNOMED') 
   AND c.standard_concept = 'S'
   and a.concept_id is not null
   
UNION ALL
SELECT  COALESCE(a.short_code,SUBSTRING(a.pmi_code,1,50)) AS concept_code_1,  -- PPI concept code can be represenеed by either PMI_code or short_code in a case when length of PMI_code is inappropriate 
       c.concept_code AS concept_code_2, -- SNOMED/LOINC concept code
       'PPI' AS vocabulary_id_1,
       c.vocabulary_id AS vocabulary_id_2,
       a.relationship_id AS relationship_id, -- 'Maps to' and 'Maps to value'
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM all_source_0334_ls a
join all_source_0334_ls b on a.concept_code = b.pmi_code
JOIN  CONCEPT_STAGE c
    ON COALESCE(b.short_code,SUBSTRING(b.pmi_code,1,50))= c.concept_code
   WHERE c.vocabulary_id = 'PPI'
   AND c.standard_concept =  'S'
   and a.concept_id is null; -- for those PPI Concepts that mapped to itself or other PPI concepts  3070 (3302)

--8. Build 'Is a' relationships from Descendant PPI Questions/Topics to Ancestor PPI Questions/Topics directly
INSERT INTO CONCEPT_RELATIONSHIP_STAGE
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date
)
SELECT DISTINCT COALESCE(a1.concept_code,a.short_code,SUBSTRING(a.pmi_code,1,50)) AS concept_code_1, -- Descendant PPI Question/Topic should be represented by either a SNOMED/LOINC concept_code (when mapping exists) or PMI_code (if not)
       COALESCE(b1.concept_code,b.short_code,SUBSTRING(b.pmi_code,1,50)) AS concept_code_2, -- Ancestor PPI Question/Topic should be represented by either a SNOMED/LOINC concept_code (when mapping exists) or PMI_code (if not)
       COALESCE(a1.vocabulary_id,'PPI') AS vocabulary_id_1,
       COALESCE(b1.vocabulary_id,'PPI') AS vocabulary_id_2,
       'Is a' AS relationship_id,
       TO_DATE(a.LAST_UPDATE,'mm/dd/yyyy') AS valid_start_date, -- date of a last update from the source 
       TO_DATE('20991231','yyyymmdd') AS valid_end_date
FROM all_source_0334_ls a -- table representing Descendant PPI Questions/Topics
  LEFT JOIN CONCEPT a1
         ON a1.concept_code = a.concept_code
        AND a1.vocabulary_id IN ('LOINC', 'SNOMED')   
  JOIN all_source_0334_ls b -- table representing Ancestor PPI Questions/Topics  
    ON a.parent_code = b.pmi_code -- 'parent_code' field indicates Ancestor codes
  LEFT JOIN CONCEPT b1
         ON b1.concept_code = b.concept_code
        AND b1.vocabulary_id IN ('LOINC', 'SNOMED')
WHERE b.type != 'Answer'
AND   a.type != 'Answer'; -- Answers do not participate in the PPI Hierarchy

--9. Build 'Is a' relationships from Descendant PPI Questions/Topics to Ancestor PPI Questions/Topics indirectly through the connection with Answers as hierarchical intermediators 
/*(Ancestor Question -> Answer -> Descendant Question => Ancestor Question -> Descendant Question)*/
INSERT INTO CONCEPT_RELATIONSHIP_STAGE
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date
)
SELECT DISTINCT COALESCE(a1.concept_code,a.short_code,SUBSTRING(a.PMI_CODE,1,50)) AS concept_code_1, -- Descendant PPI Question/Topic should be represented by either a SNOMED/LOINC concept_code (when mapping exists) or PMI_code (if not)
       COALESCE(d1.concept_code,d.short_code,SUBSTRING(d.PMI_CODE,1,50)) AS concept_code_2,-- Ancestor PPI Question/Topic should be represented by either a SNOMED/LOINC concept_code (when mapping exists) or PMI_code (if not)
       COALESCE(a1.vocabulary_id,'PPI') AS vocabulary_id_1,
       COALESCE(d1.vocabulary_id,'PPI') AS vocabulary_id_2,
       'Is a' AS relationship_id,
       TO_DATE(a.LAST_UPDATE,'mm/dd/yyyy') AS valid_start_date, -- date of a last update from the source 
       TO_DATE('20991231','yyyymmdd') AS valid_end_date
FROM all_source_0334_ls a -- table representing Descendant PPI Questions/Topics 
  LEFT JOIN CONCEPT a1
         ON a1.concept_code = a.concept_code
        AND a1.vocabulary_id IN ('LOINC', 'SNOMED')
  JOIN all_source_0334_ls b -- table representing PPI Answers 
ON a.parent_code = b.pmi_code -- 'parent_code' of a Descendant PPI Question/Topic indicates an Ancestor PPI Answer code
  JOIN all_source_0334_ls d -- table representing Ancestor PPI Questions/Topics 
ON b.parent_code = d.pmi_code --'parent_code' of a PPI Answer indicates an Ancestor PPI Question/Topic code 
  LEFT JOIN CONCEPT d1
         ON d1.concept_code = d.concept_code
        AND d1.vocabulary_id IN ('LOINC', 'SNOMED')
WHERE b.type = 'Answer' 
AND   a.type != 'Answer' ;

--10. Build 'Answer of' relationships from PPI Answers to related PPI Questions/Topics
INSERT INTO CONCEPT_RELATIONSHIP_STAGE
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date
)
SELECT DISTINCT COALESCE(a.short_code,SUBSTRING(a.PMI_CODE,1,50)) AS concept_code_1,-- PPI Answer should be represented by a PMI_code only
       COALESCE(b1.concept_code,b.short_code,SUBSTRING(b.PMI_CODE,1,50)) AS concept_code_2, -- PPI Question/Topic should be represented by either a SNOMED/LOINC concept_code (when mapping exists) or PMI_code (if not)
       'PPI' AS vocabulary_id_1,
       COALESCE(b1.vocabulary_id,'PPI') AS vocabulary_id_2, -- 'SNOMED'/'LOINC'(when mapping exists) or 'PPI' (if not)
       'Answer of (PPI)' AS relationship_id,
       TO_DATE(a.LAST_UPDATE,'mm/dd/yyyy') AS valid_start_date, -- date of a last update from the source 
       TO_DATE('20991231','yyyymmdd') AS valid_end_date
FROM all_source_0334_ls a -- table representing PPI Answers 
  JOIN all_source_0334_ls b -- table representing PPI Questions/Topics
ON a.parent_code = b.pmi_code
  LEFT JOIN CONCEPT b1
         ON b1.concept_code = b.concept_code
        AND b1.vocabulary_id IN ('LOINC', 'SNOMED') 
WHERE a.type = 'Answer';

--11. Build 'Has PPI parent code' relationships from Descendant PPI concepts to Ancestor PPI concepts as they are given by the source (a 'Personal Medical History' module is excluded)
INSERT INTO CONCEPT_RELATIONSHIP_STAGE
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date
)
SELECT DISTINCT COALESCE(a.short_code,SUBSTRING(a.PMI_CODE,1,50)) AS concept_code_1, -- Descendant PPI concept code
       COALESCE(b.short_code,SUBSTRING(b.PMI_CODE,1,50)) AS concept_code_2, -- Ancestor PPI concept code
       'PPI' AS vocabulary_id_1,
       'PPI' AS vocabulary_id_2,
       'Has PPI parent code' AS relationship_id,
       TO_DATE(a.LAST_UPDATE,'mm/dd/yyyy') AS valid_start_date, -- date of a last update from the source 
       TO_DATE('20991231','yyyymmdd') AS valid_end_date
FROM all_source_0334_ls a -- table representing Descendant PPI concepts
  JOIN all_source_0334_ls b -- table representing Ancestor PPI concepts
    ON a.parent_code = b.pmi_code
   AND a.module != 'Personal Medical History'; 

--12. Build 'Has PPI parent code' relationships from Descendant PPI concepts to Ancestor PPI concepts indicating History as they are given by 'PMH hierarchy for Odysseus' ('pmh_hier_done' table)
INSERT INTO CONCEPT_RELATIONSHIP_STAGE
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date
)
SELECT DISTINCT COALESCE(a.short_code,SUBSTRING(a.PMI_CODE,1,50)) AS concept_code_1,   --  Descendant PPI concept code
       COALESCE(b.short_code,SUBSTRING(b.PMI_CODE,1,50)) AS concept_code_2, -- Ancestor PPI concept code
       'PPI' AS vocabulary_id_1,
       'PPI' AS vocabulary_id_2,
       'Has PPI parent code' AS relationship_id,
       TO_DATE(a.LAST_UPDATE,'mm/dd/yyyy') AS valid_start_date, -- date of a last update from the source 
       TO_DATE('20991231','yyyymmdd') AS valid_end_date
FROM all_source_0334_ls a -- table representing Descendant PPI concepts
  JOIN pmh_hier_done k ON a.pmi_code = k.child_code
  JOIN all_source_0334_ls b -- table representing Ancestor PPI concepts
ON k.parent_code = b.pmi_code; 

--13. Build 'Maps to' relationships for PPI Physical Measurements and PPI Measurement Values  (existing mappings) 
INSERT INTO CONCEPT_RELATIONSHIP_STAGE
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date
)
SELECT c1.concept_code,
       c2.concept_code,
       c1.vocabulary_id,
       c2.vocabulary_id,
       relationship_id,
       cr.valid_start_date,
       cr.valid_end_date
FROM concept_relationship cr
  JOIN concept c1 ON concept_id_1 = c1.concept_id
  JOIN concept c2 ON concept_id_2 = c2.concept_id
WHERE c1.vocabulary_id = 'PPI'
AND   cr.invalid_reason IS NULL
AND   relationship_id = 'Maps to'
AND   c1.invalid_reason IS NULL
AND   c2.invalid_reason IS NULL
AND   (
c1.domain_id = 'Measurement' AND c1.concept_class_id = 'Clinical Observation'
OR 
c1.concept_code ~ 'protocol\-modifications|^notes$'
OR
c1.concept_class_id = 'Qualifier Value') 

UNION ALL
-- fix mapping for 'Irregularity detected' PPI Meas Value manually (target SNOMED concept was updated) 
SELECT  'irregularity-detected', -- Irregularity detected
       '361137007' ,  -- 	Irregular heart beat
       'PPI',
       'SNOMED',
       'Maps to',
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'PPI') AS valid_start_date,
       TO_DATE('2099-12-31','yyyy-mm-dd') AS valid_end_date;

 --13. Build reverse relationship. This is necessary for next point
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
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
WHERE NOT EXISTS (
		-- the inverse record
		SELECT 1
		FROM concept_relationship_stage i
		WHERE crs.concept_code_1 = i.concept_code_2
			AND crs.concept_code_2 = i.concept_code_1
			AND crs.vocabulary_id_1 = i.vocabulary_id_2
			AND crs.vocabulary_id_2 = i.vocabulary_id_1
			AND r.reverse_relationship_id = i.relationship_id
		);

--14. Deprecate all relationships in concept_relationship that aren't exist in concept_relationship_stage
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT a.concept_code,
	b.concept_code,
	a.vocabulary_id,
	b.vocabulary_id,
	relationship_id,
	r.valid_start_date,
	CURRENT_DATE,
	'D'
FROM concept a
JOIN concept_relationship r ON a.concept_id = concept_id_1
	AND r.invalid_reason IS NULL
JOIN concept b ON b.concept_id = concept_id_2
WHERE 'PPI' IN (
		a.vocabulary_id,
		b.vocabulary_id
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = a.concept_code
			AND crs_int.concept_code_2 = b.concept_code
			AND crs_int.vocabulary_id_1 = a.vocabulary_id
			AND crs_int.vocabulary_id_2 = b.vocabulary_id
			AND crs_int.relationship_id = r.relationship_id
		);