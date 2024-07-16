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
* Authors: Irina Zherko,  Masha Khitrun,
* Aliaksei Katyshou, Vlad Korsik,
* Alexander Davydov, Oleg Zhuk,
* Timur Vakhitov
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

--1. Source preparation (cdisc_refresh.sql)
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
    FROM source s
    JOIN sources.meta_mrsty st ON s.cui = st.cui
    JOIN concept_class_lookup l on st.sty = l.attribute
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
(SELECT concept_code FROM source s
    JOIN sources.meta_mrdef b
on s.cui=b.cui
and (
    b.def ilike 'unit of%'
        or b.def ilike 'a unit of%'
                or b.def ilike 'the unit of%'
    or b.def ilike 'a unit for%'
       or b.def ilike 'the unit for%'

       or b.def like 'A non-SI unit%'
       or b.def like 'The non-SI unit%'

    or b.def like 'A SI unit%'
       or b.def like 'The SI unit%'

            or b.def like 'A SI derived unit%'
       or b.def like 'The SI derived unit %'

        or b.def like 'The metric unit%'
       or b.def like 'A metric unit%'

           or b.def like 'A traditional unit%'
       or b.def like 'The traditional unit%'
    )
and b.sab='CDISC' )
;

-- Update domain for Measurements
UPDATE concept_stage cs
SET domain_id = 'Measurement', concept_class_id = 'Procedure'
WHERE concept_code in
(
SELECT s.concept_code
FROM source s
    JOIN sources.meta_mrdef b
on s.cui=b.cui
and (
    b.def ilike '%measurement of%'
    and b.def not ilike '%unit%')
and b.sab='CDISC'
)
and cs.domain_id <>'Measurement'
;

-- Update domain for Staging / Scales
UPDATE concept_stage cs
SET domain_id = 'Measurement', concept_class_id = 'Staging / Scales'
WHERE concept_code in
(SELECT concept_code FROM source s
    JOIN sources.meta_mrdef b
on s.cui=b.cui
and (
    b.def ilike 'Functional Assessment of%'
    or b.def ilike '%Questionnaire%'
      or b.def ilike '%survey%')
and    b.def not ilike '%unit%'
and b.sab='CDISC'
    )
and cs.domain_id <>'Measurement'
and cs.concept_class_id <> 'Staging / Scales'
;

-- Update domain and class for Social Context
UPDATE concept_stage cs
SET domain_id = 'Observation', concept_class_id = 'Social Context'
WHERE concept_code in
(SELECT concept_code
 FROM source s
JOIN sources.meta_mrsty b
on  s.cui=b.cui
and b.sty= 'Population Group' )
and cs.domain_id <> 'Observation'
and cs.concept_class_id <> 'Social Context'
;


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
FROM source
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
       FROM cdisc_mapped
    WHERE target_concept_id is not null
    and mapping_source ='manual'
      and target_concept_code !='No matching concept'  -- _mapped file can contatin them
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
    JOIN cdisc_mapped r
        ON s.concept_code = r.concept_code
and s.vocabulary_id='CDISC'
WHERE s.concept_code in
(   SELECT  concept_code
    FROM cdisc_mapped
        where  decision is TRUE
        and  mapping_source != 'manual'
    GROUP BY  concept_code
    HAVING count(*) = 1 -- for the 1st iteration automatic 1toM and to_value were prohibited
)
and (s.concept_code,'CDISC') NOT IN (SELECT concept_code_1,vocabulary_id_1 FROM concept_relationship_manual where invalid_reason is null and relationship_id like 'Maps to%')
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
    JOIN cdisc_mapped r
        ON s.concept_code = r.concept_code
and s.vocabulary_id='CDISC'
WHERE s.concept_code in
(   SELECT  concept_code
    FROM cdisc_mapped
        where  decision is TRUE
        and  mapping_source != 'manual'
    GROUP BY  concept_code
    HAVING count(*) = 2 -- for the 1st iteration automatic 1toM and to_value were prohibited
)

    AND EXISTS(SELECT 1
             FROM cdisc_mapped b
             WHERE s.concept_code = b.concept_code
               AND b.relationship_id ~* 'value')

and (s.concept_code,'CDISC') NOT IN (SELECT concept_code_1,vocabulary_id_1 FROM concept_relationship_manual where invalid_reason is null and relationship_id like 'Maps to%')

;

-- 8 Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--9 Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--10 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--11 Add mapping from deprecated to fresh concepts for 'Maps to value'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

--12 Final clean-up
DROP TABLE source;

