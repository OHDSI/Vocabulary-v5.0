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
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

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

--2. concept_stage table population
--2.1 concept_stage population
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


--2.2  Refining of Classes/Domains
--Domain cnd Classes Processing based on Definition table
-- Update Domain for units
-- Update Domain for units
UPDATE concept_stage
SET domain_id = 'Unit',
    concept_class_id = 'Unit'
WHERE concept_code in
(SELECT concept_code FROM source s
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
FROM source s
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
(SELECT concept_code FROM source s
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
 FROM source s
JOIN sources.meta_mrsty b
ON  s.cui=b.cui
AND b.sty= 'Population Group' )
AND cs.domain_id <> 'Observation'
AND cs.concept_class_id <> 'Social Context'
;

-- Some manual domain changes
UPDATE concept_stage SET domain_id = 'Observation', concept_class_id = 'Observable Entity'  WHERE concept_code in ('C156595', 'C189365', 'C17943', 'C20050');

--2.3 Working with concept_manual table (not yet implemented)
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--3. concept_synonym_stage table population
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

--4. concept_relationship_manual table population
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;


--5. Automated/Not curated mappings integration  (to be used to populate CRS)
DROP TABLE IF EXISTS cdisc_automapped;
CREATE TABLE cdisc_automapped
(   metadata_enriched boolean DEFAULT TRUE,
    concept_code VARCHAR (50) NOT NULL, --CDISC code
    concept_name   VARCHAR (255), --CDISC name
    vocabulary_id VARCHAR (20)  DEFAULT 'CDISC',
    sty VARCHAR, -- semantic type form NCImetha
    mapability VARCHAR, -- -OMOP mapability of source code e.g.: FoN - flavor of null;NOmop - non omop use-case; NULL - mappable (voc_metadata extension)
    relationship_id VARCHAR (20), --OMOP Rel
    relationship_id_predicate VARCHAR (20),  --OMOP Rel Predicate (voc_metadata extension)
    mapping_source VARCHAR [], -- Origin of Mapping
    mapping_path VARCHAR [], -- For non-manual sources the array with codes in a chain
    decision  boolean,
    confidence FLOAT,  --OMOP Rel Confidence (voc_metadata extension)
    mapper_id VARCHAR,  --OMOP Rel mapper_id - email (voc_metadata extension)
    reviewer_id VARCHAR, --OMOP Rel reviewer_id - email (voc_metadata extension)
    valid_start_date date, --OMOP Rel valid_start_date
    valid_end_date date, --OMOP Rel valid_end_date
    invalid_reason VARCHAR,  --OMOP Rel invalid_reason
    comments VARCHAR, --technical comments on mapping
    target_concept_id BIGINT,
    target_concept_code VARCHAR (50),
    target_concept_name VARCHAR (255),
    target_concept_class VARCHAR (50),
    target_standard_concept VARCHAR (10),
    target_invalid_reason VARCHAR (20),
    target_domain_id VARCHAR (20),
    target_vocabulary_id VARCHAR (20));
;

-- Mapping to standard using SNOMED
INSERT INTO cdisc_automapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
'NCI-metathesaurus' as mapper_id,
'Unreviewed'  as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'SNOMED'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'SNOMEDCT_US'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_automapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;

-- Mapping to standard using LOINC
INSERT INTO cdisc_automapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
    'NCI-metathesaurus' as mapper_id,
'Unreviewed'  as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'LOINC'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'lnc'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_automapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;

--Mapping to S using ICD10
INSERT INTO cdisc_automapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
'NCI-metathesaurus' as mapper_id,
'Unreviewed'  as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'ICD10'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'ICD10'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_automapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;


--Mapping to S using HCPCS
INSERT INTO cdisc_automapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
'NCI-metathesaurus' as mapper_id,
'Unreviewed'  as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'HCPCS'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'HCPCS'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_automapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;


--Mapping to S using CPT4
INSERT INTO cdisc_automapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
'NCI-metathesaurus' as mapper_id,
'Unreviewed'  as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'CPT4'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'CPT'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_automapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;


--Mapping to S using MedDRA
INSERT INTO cdisc_automapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
'NCI-metathesaurus' as mapper_id,
'Unreviewed'  as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'MedDRA'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'MDR'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_automapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;

--Mapping to S using HemOnc
INSERT INTO cdisc_automapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
'NCI-metathesaurus' as mapper_id,
'Unreviewed'  as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'HemOnc'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'HemOnc'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_automapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;

--Mapping to RxNorm
INSERT INTO cdisc_automapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
cr.relationship_id       as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', s.code)) as mapping_path,
TRUE as decision,
1 as confidence,
'NCI-metathesaurus' as mapper_id,
'Unreviewed'  as reviewer_id,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1) as valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrsty st ON m.cui = st.cui
JOIN sources.meta_mrconso s on s.cui=m.cui
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'RxNorm'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'RXNORM'
AND m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_automapped)
GROUP BY m.concept_code,
m.concept_name,
cr.relationship_id ,
string_to_array(CONCAT('Auto-NCIm',':',s.sab),':','NULL') ,
TRUE,
(SELECT   TO_DATE(substring(sver FROM 1 FOR 4) || '-' || substring(sver FROM 6 FOR 2) || '-01','YYYY-MM-DD') FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;

--Mapping to non-Defined standard by name-match (OMOP)
INSERT INTO cdisc_automapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
'Maps to'     as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-OMOP-name_match',':', cc.vocabulary_id),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', cc.concept_code)) as mapping_path,
TRUE as decision,
1 as confidence,
'Unreviewed'as mapper_id,
'Unreviewed'  as reviewer_id,
CURRENT_DATE	AS  valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
  FROM source m
      JOIN sources.meta_mrsty st ON m.cui = st.cui
                          JOIN concept cc
                               ON trim(lower(cc.concept_name)) =trim(lower(m.concept_name))
                                   AND cc.standard_concept = 'S'
                                   AND cc.vocabulary_id IN ('SNOMED', 'LOINC')
                                   AND cc.domain_id IN ('Condition', 'Procedure', 'Measurement', 'Observation')
                                   AND cc.concept_class_id <> 'Substance'
WHERE  m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_automapped)
GROUP BY m.concept_code,
m.concept_name,
string_to_array(CONCAT('Auto-OMOP-name_match',':', cc.vocabulary_id),':','NULL') ,
TRUE,
CURRENT_DATE ,
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;


--Mapping to non-Defined standard by synonym name-match (OMOP)
INSERT INTO cdisc_automapped (concept_code, concept_name, sty, mapability, relationship_id, relationship_id_predicate,
                          mapping_source, mapping_path, decision, confidence, mapper_id, reviewer_id, valid_start_date,
                          valid_end_date, invalid_reason, comments, target_concept_id, target_concept_code,
                          target_concept_name, target_concept_class, target_standard_concept, target_invalid_reason,
                          target_domain_id, target_vocabulary_id)

SELECT DISTINCT
m.concept_code,
m.concept_name,
string_agg(DISTINCT st.sty, '|') as sty,
NULL as mapability,
'Maps to'     as relationship_id,
NULL as relationship_id_predicate,
string_to_array(CONCAT('Auto-OMOP-synonym_match',':', cc.vocabulary_id),':','NULL') as mapping_source,
ARRAY_AGG(DISTINCT CONCAT( m.concept_code, ' > ', cc.concept_code)) as mapping_path,
TRUE as decision,
1 as confidence,
'Unassigned'  as mapper_id,
'Unreviewed'  as reviewer_id,
CURRENT_DATE	AS valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
NULL as invalid_reason,
NULL as comments,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
  FROM source m
      JOIN sources.meta_mrsty st ON m.cui = st.cui
                          JOIN concept cc
                              JOIN concept_synonym cs
                                  on cc.concept_id=cs.concept_id
                               ON trim(lower(cs.concept_synonym_name)) =trim(lower(m.concept_name))
                                   AND cc.standard_concept = 'S'
                                   AND cc.vocabulary_id IN ('SNOMED', 'LOINC')
                                   AND cc.domain_id IN ('Condition', 'Procedure', 'Measurement', 'Observation')
                                   AND cc.concept_class_id NOT IN ( 'Substance','Organism')
WHERE  m.concept_code not in (SELECT DISTINCT concept_code FROM cdisc_automapped)
GROUP BY m.concept_code,
m.concept_name,
string_to_array(CONCAT('Auto-OMOP-synonym_match',':', cc.vocabulary_id),':','NULL') ,
TRUE,
CURRENT_DATE,
TO_DATE('20991231', 'yyyymmdd'),
cc.concept_id     ,
cc.concept_code  ,
cc.concept_name   ,
cc.concept_class_id,
cc.standard_concept ,
cc.invalid_reason ,
cc.domain_id ,
cc.vocabulary_id
;

--Population of the concept_relationship_stage table automated mappings
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
    JOIN cdisc_automapped r
        ON s.concept_code = r.concept_code
AND s.vocabulary_id='CDISC'
WHERE  (
    s.concept_code in
(   SELECT  concept_code
    FROM cdisc_automapped
        WHERE  decision is TRUE
    GROUP BY  concept_code
    HAVING count(*) = 1 -- for the 1st iteration automatic 1toM and to_value were prohibited
)
        OR ( s.concept_code in
(   SELECT  concept_code
    FROM cdisc_automapped
        WHERE  decision is TRUE
    GROUP BY  concept_code
    HAVING count(*) = 2 -- for the 1st iteration automatic 1toM and to_value were prohibited
)

    AND EXISTS(SELECT 1
             FROM cdisc_automapped b
             WHERE s.concept_code = b.concept_code
               AND b.relationship_id ~* 'value')
            )
    )

        AND (s.concept_code,'CDISC') NOT IN (SELECT concept_code_1,vocabulary_id_1 FROM concept_relationship_stage where invalid_reason is null and relationship_id like 'Maps to%')
;

-- 6. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--7. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--8. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--9. Add mapping from deprecated to fresh concepts for 'Maps to value'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
