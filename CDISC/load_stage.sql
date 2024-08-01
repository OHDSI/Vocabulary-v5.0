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
* Authors: Irina Zherko, Masha Khitrun, Aliaksei Katyshou, Vlad Korsik,
* Alexander Davydov, Oleg Zhuk, Timur Vakhitov
*
* Date: 2024
**************************************************************************/


--Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CDISC',
	pVocabularyDate			=> (SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
	pVocabularyVersion		=> (SELECT sver FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_CDISC'
);
END $_$;

--Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;

--1. Source preparation
--NCIm source processing
DROP TABLE IF EXISTS source;
CREATE TABLE source as (
WITH concepts AS (
SELECT
    c.scui,
    c.cui,
    STRING_AGG(DISTINCT CASE WHEN main.code LIKE '%CD'
                                  THEN main.str
                                  END, '-' )
                FILTER (WHERE main.str <> c.concept_name
                           AND str <> c.scui
                           AND main.sab = 'CDISC') AS concept_code,
    c.concept_name
FROM sources.meta_mrconso main
JOIN
(    SELECT scui,
            cui,
            str as concept_name,
            ROW_NUMBER() OVER (
           PARTITION BY scui
        ORDER BY
            CASE WHEN code in (SELECT TRIM(TRAILING 'CD' FROM t.code)
                                 FROM sources.meta_mrconso t
                                 WHERE t.scui = main.scui AND t.code LIKE '%CD') THEN 1
                 WHEN tty = 'PT' AND sab = 'CDISC' THEN
                     CASE WHEN (SELECT COUNT(*)

                                  FROM sources.meta_mrconso c2
                                 WHERE c2.str = main.str
                                   AND c2.tty = 'PT'
                                   AND c2.sab = 'CDISC'
                                   AND c2.scui = main.scui) > 1 THEN 2
                         ELSE 3
                     END
                 WHEN tty = 'SY' AND ispref = 'Y' THEN 4
                 WHEN sab = 'NCI' AND tty = 'SY' AND ispref = 'Y' THEN 5
            END,
            LENGTH(str) DESC
        ) as applied_condition
     FROM sources.meta_mrconso main
    WHERE main.sab = 'CDISC'
      AND LEFT(main.scui, 1) = 'C'
      AND SUBSTRING(main.scui FROM 2) ~ '\d') c ON main.scui = c.scui
WHERE c.applied_condition = 1
GROUP BY c.scui, c.cui, c.concept_name
),
synonyms AS (
    SELECT scui,
            str,
            ROW_NUMBER() OVER (
                PARTITION BY scui
                ORDER BY LENGTH(str) DESC
            ) as rn
     FROM sources.meta_mrconso
     WHERE sab = 'CDISC'
       AND code NOT LIKE '%CD'
),
longest_synonyms AS (
    SELECT scui, str
    FROM synonyms
   WHERE rn = 1
)
SELECT DISTINCT
    c.scui,
    c.cui,
    c.scui || COALESCE('-'||c.concept_code, '') AS concept_code,
    CASE
        WHEN c.concept_name ~ '^[^a-zA-Z\/]*$'
            THEN (SELECT ls.str FROM longest_synonyms ls WHERE scui = c.scui)
        ELSE c.concept_name
    END AS concept_name,
    CASE
        WHEN c.concept_name ~ '^[^a-zA-Z\/]*$' THEN c.concept_name
        ELSE s.str
    END AS synonym
FROM concepts c
LEFT JOIN synonyms s ON c.scui = s.scui
      AND s.str <> c.concept_name
      AND POSITION(s.str IN COALESCE(c.concept_code, '')) = 0)
;

--2. Populate cdisc_mapped with manually curated content (cdisc_refresh.sql)
--3. cdisc_mapped population with AUTO-mappings

--4. concept_stage table population
--4.1 concept_stage population
INSERT INTO concept_stage (
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
WITH concepts AS (
    SELECT DISTINCT
        s.concept_name,
        l.domain_id,
        'CDISC' as vocabulary_id,
        l.attribute,
        l.concept_class as concept_class_id,
        NULL as standard_concept,
        s.concept_code as concept_code
    FROM dev_cdisc.source s
    JOIN sources.meta_mrsty st ON s.cui = st.cui
    JOIN dev_cdisc.concept_class_lookup l on st.sty = l.attribute
),
concepts_count AS (
    SELECT
        concept_name,
        COUNT(DISTINCT domain_id) as unique_domain_id_count,
        COUNT(DISTINCT concept_class_id) as unique_concept_class_id_count
    FROM concepts
    GROUP BY concept_name
)
SELECT DISTINCT
    c.concept_name,
    CASE
        WHEN cc.unique_domain_id_count > 1
             OR cc.unique_concept_class_id_count > 1
            THEN 'Observation'
        ELSE c.domain_id
    END as domain_id,
    c.vocabulary_id,
    CASE
        WHEN cc.unique_domain_id_count > 1
             OR cc.unique_concept_class_id_count > 1
            THEN 'Observable Entity'
        ELSE c.concept_class_id
    END as concept_class_id,
    c.standard_concept,
    c.concept_code,
    '2023-12-01'::date AS valid_start_date,
    TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
    NULL as invalid_reason
FROM concepts c
JOIN concepts_count cc ON c.concept_name = cc.concept_name;


--4.2  Refining of Classes/Domains
--Domain cnd Classes Processing based on Definition table
-- Update Domain for units
-- Update Domain for units
UPDATE concept_stage
SET domain_id = 'Unit',
    concept_class_id = 'Unit'
WHERE concept_code in
(SELECT concept_code FROM dev_cdisc.source s
    JOIN sources.meta_mrdef b
ON s.cui=b.cui
AND (
    b.def ilike 'unit of%'
        OR b.def ilike 'a unit of%'
                OR b.def ilike 'the unit of%'
    OR b.def ilike 'a unit for%'
       OR b.def ilike 'the unit for%'

       OR b.def like 'A non-SI unit%'
       OR b.def like 'The non-SI unit%'

    OR b.def like 'A SI unit%'
       OR b.def like 'The SI unit%'

            OR b.def like 'A SI derived unit%'
       OR b.def like 'The SI derived unit %'

        OR b.def like 'The metric unit%'
       OR b.def like 'A metric unit%'

           or b.def like 'A traditional unit%'
       OR b.def like 'The traditional unit%'
    )
AND b.sab='CDISC' )
;

-- Update domain for Measurements
UPDATE concept_stage cs
SET domain_id = 'Measurement', concept_class_id = 'Procedure'
WHERE concept_code in
(
SELECT s.concept_code
FROM dev_cdisc.source s
    JOIN sources.meta_mrdef b
ON s.cui=b.cui
AND (
    b.def ilike '%measurement of%'
    AND b.def NOT ilike '%unit%')
AND b.sab='CDISC'
)
AND cs.domain_id <>'Measurement'
;

-- Update domain for Staging / Scales
UPDATE concept_stage cs
SET domain_id = 'Measurement', concept_class_id = 'Staging / Scales'
WHERE concept_code in
(SELECT concept_code FROM dev_cdisc.source s
    JOIN sources.meta_mrdef b
ON s.cui=b.cui
AND (
    b.def ilike 'Functional Assessment of%'
    OR b.def ilike '%Questionnaire%'
      OR b.def ilike '%survey%')
AND    b.def NOT ilike '%unit%'
AND b.sab='CDISC'
    )
AND cs.domain_id <>'Measurement'
AND cs.concept_class_id <> 'Staging / Scales'
;

-- Update domain and class for Social Context
UPDATE concept_stage cs
SET domain_id = 'Observation', concept_class_id = 'Social Context'
WHERE concept_code in
(SELECT concept_code
 FROM dev_cdisc.source s
JOIN sources.meta_mrsty b
ON  s.cui=b.cui
AND b.sty= 'Population Group' )
AND cs.domain_id <> 'Observation'
AND cs.concept_class_id <> 'Social Context'
;

-- Some manual domain changes
UPDATE concept_stage SET domain_id = 'Observation', concept_class_id = 'Observable Entity'  WHERE concept_code in ('C156595', 'C189365', 'C17943', 'C20050');

--4.3 Working with concept_manual table (not yet implemented)
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--5. concept_synonym_stage table population
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	    )
SELECT
       concept_code as concept_code,
       synonym as synonym_name,
       'CDISC' as vocabulary_id,
       4180186 AS language_concept_id -- English
FROM dev_cdisc.source
WHERE synonym is not null;

--6. concept_relationship_Manual table population
-- concept_relationship_Manual table population
INSERT INTO  concept_relationship_manual (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date,invalid_reason)
SELECT DISTINCT concept_code as concept_code_1,
       target_concept_code as concept_code_2,
       vocabulary_id as vocabulary_id_1,
       target_vocabulary_id as vocabulary_id_2,
       relationship_id as relationship_id,
       valid_start_date as valid_start_date,
       valid_end_date as valid_end_date,
       null as invalid_reason
       FROM dev_cdisc.cdisc_mapped
    WHERE target_concept_id is not null
    AND 'manual' = all(mapping_source)
      AND target_concept_code !='No matching concept'  -- _mapped file can contatin them
    and decision is true
ORDER BY concept_code,relationship_id;

--6.1. working with manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

-- 7. concept_relationship_stage population
--insert only 1-to-1 mappings
INSERT INTO concept_relationship_stage (
concept_code_1,
concept_code_2,
vocabulary_id_1,
vocabulary_id_2,
relationship_id,
valid_start_date,
valid_end_date,
invalid_reason)

SELECT DISTINCT
s.concept_code as concept_code_1,
r.target_concept_code as concept_code_2,
'CDISC' as vocabulary_id_1,
r.target_vocabulary_id as vocabulary_id_2,
r.relationship_id as relationship_id,
r.valid_start_date	AS valid_start_date,
r.valid_end_date AS valid_end_date,
null as invalid_reason
FROM concept_stage s
    JOIN dev_cdisc.cdisc_mapped r
        ON s.concept_code = r.concept_code
AND s.vocabulary_id='CDISC'
WHERE s.concept_code in
(   SELECT  concept_code
    FROM dev_cdisc.cdisc_mapped
        WHERE  decision is TRUE
        AND  'manual' != all(mapping_source)
    GROUP BY  concept_code
    HAVING count(*) = 1 -- for the 1st iteration automatic 1toM and to_value were prohibited
)
AND (s.concept_code,'CDISC') NOT IN (SELECT concept_code_1,vocabulary_id_1 FROM concept_relationship_manual where invalid_reason is null and relationship_id like 'Maps to%')
;

--insert only 1-to-2 mappings (EAV pairs)
INSERT INTO concept_relationship_stage (
concept_code_1,
concept_code_2,
vocabulary_id_1,
vocabulary_id_2,
relationship_id,
valid_start_date,
valid_end_date,
invalid_reason)

SELECT DISTINCT
s.concept_code as concept_code_1,
r.target_concept_code as concept_code_2,
'CDISC' as vocabulary_id_1,
r.target_vocabulary_id as vocabulary_id_2,
r.relationship_id as relationship_id,
r.valid_start_date	AS valid_start_date,
r.valid_end_date AS valid_end_date,
null as invalid_reason
FROM concept_stage s
    JOIN dev_cdisc.cdisc_mapped r
        ON s.concept_code = r.concept_code
AND s.vocabulary_id='CDISC'
WHERE s.concept_code in
(   SELECT  concept_code
    FROM dev_cdisc.cdisc_mapped
        WHERE  decision is TRUE
        AND  'manual' != all(mapping_source)
    GROUP BY  concept_code
    HAVING count(*) = 2 -- for the 1st iteration automatic 1toM and to_value were prohibited
)

    AND EXISTS(SELECT 1
             FROM dev_cdisc.cdisc_mapped b
             WHERE s.concept_code = b.concept_code
               AND b.relationship_id ~* 'value')

AND (s.concept_code,'CDISC')
        NOT IN (SELECT concept_code_1,vocabulary_id_1 FROM concept_relationship_manual where invalid_reason is null and relationship_id like 'Maps to%')
;

-- 8. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--9. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--10. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--11. Add mapping from deprecated to fresh concepts for 'Maps to value'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
