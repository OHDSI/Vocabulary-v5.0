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
	pVocabularyVersion		=>  (SELECT sver FROM sources.meta_mrsab WHERE rsab = 'CDISC' LIMIT 1),
	pVocabularyDevSchema	=>  'DEV_CDISC'
);
END $_$;

--Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;

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
SELECT
distinct
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
      AND POSITION(s.str IN COALESCE(c.concept_code, '')) = 0);

--concept_stage
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

-- Working with concept_manual table
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--concept_synonym_stage
TRUNCATE concept_synonym_stage;
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

-- Adopt mappings from NCIm/UMLS
DROP TABLE IF EXISTS rel;
CREATE TABLE rel (
    scui varchar,
    concept_name varchar,
    relationship_id varchar,
    target_concept_id bigint,
    target_concept_code varchar,
    target_concept_name varchar,
    target_concept_class varchar,
    target_standard_concept varchar,
    target_domain_id varchar,
    target_vocabulary_id varchar
);

-- Mapping to standard using SNOMED
INSERT INTO rel (
SELECT DISTINCT
m.scui,
m.concept_name,
cr.relationship_id       as relationship_id,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'SNOMED'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'SNOMEDCT_US');

-- Mapping to standard using LOINC
INSERT INTO rel (
SELECT DISTINCT
m.scui,
m.concept_name,
cr.relationship_id       as relationship_id,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id
FROM source m
JOIN sources.meta_mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'LOINC'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'lnc'
and m.scui not in (SELECT scui FROM rel));

--Mapping to S using CPT4
INSERT INTO rel (
SELECT DISTINCT
m.scui,
m.concept_name,
cr.relationship_id       as relationship_id,
cc.concept_id            as target_concept_id,
cc.concept_code          as target_concept_code,
cc.concept_name as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.domain_id as target_domain_id,
cc.vocabulary_id as target_vocabulary_id
FROM source m
JOIN sources.meta_mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'CPT4'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'CPT'
and m.scui not in (SELECT scui FROM rel));

--Mapping to S using ICD10
INSERT INTO rel (
SELECT DISTINCT
m.scui,
m.concept_name,
cr.relationship_id       as relationship_id,
cc.concept_id as target_concept_id,
cc.concept_code as target_concept_code,
cc.concept_name as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.domain_id as target_domain_id,
cc.vocabulary_id as target_vocabulary_id
FROM source m
JOIN sources.meta_mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'ICD10'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'ICD10'
and m.scui not in (SELECT scui FROM rel));

--Mapping to S using HCPCS
INSERT INTO rel (
SELECT DISTINCT
m.scui,
m.concept_name,
cr.relationship_id       as relationship_id,
cc.concept_id as target_concept_id,
cc.concept_code as target_concept_code,
cc.concept_name as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.domain_id as target_domain_id,
cc.vocabulary_id as target_vocabulary_id
FROM source m
JOIN sources.meta_mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'HCPCS'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'HCPCS'
and m.scui not in (SELECT scui FROM rel));

--Mapping to S using MedDRA
INSERT INTO rel (
SELECT DISTINCT
m.scui,
m.concept_name,
cr.relationship_id       as relationship_id,
cc.concept_id  as target_concept_id,
cc.concept_code  as target_concept_code,
cc.concept_name  as target_concept_name,
cc.concept_class_id  as target_concept_class,
cc.standard_concept  as target_standard_concept,
cc.domain_id  as target_domain_id,
cc.vocabulary_id as target_vocabulary_id
FROM source m
JOIN sources.meta_mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'MedDRA'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'MDR'
and m.scui not in (SELECT scui FROM rel));

--Mapping to S using HemOnc
INSERT INTO rel (
SELECT DISTINCT
m.scui,
m.concept_name,
cr.relationship_id       as relationship_id,
cc.concept_id  as target_concept_id,
cc.concept_code  as target_concept_code,
cc.concept_name  as target_concept_name,
cc.concept_class_id  as target_concept_class,
cc.standard_concept  as target_standard_concept,
cc.domain_id  as target_domain_id,
cc.vocabulary_id as target_vocabulary_id
FROM source m
JOIN sources.meta_mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'HemOnc'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'HemOnc'
and m.scui not in (SELECT scui FROM rel));

--Mapping to RxNorm
INSERT INTO rel (
SELECT DISTINCT
m.scui,
m.concept_name,
cr.relationship_id       as relationship_id,
cc.concept_id as target_concept_id,
cc.concept_code as target_concept_code,
cc.concept_name as target_concept_name,
cc.concept_class_id as target_concept_class,
cc.standard_concept as target_standard_concept,
cc.domain_id as target_domain_id,
cc.vocabulary_id as target_vocabulary_id
FROM source m
JOIN sources.meta_mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'RxNorm'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ( 'Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE s.sab = 'RXNORM'
and m.scui not in (SELECT scui FROM rel));

--Other meta_-derived mappings
INSERT INTO rel (
SELECT DISTINCT
s.scui,
s.concept_name,
'Maps to' as relationship_id,
c.concept_id as target_concept_id,
c.concept_code as target_concept_code,
c.concept_name as target_concept_name,
c.concept_class_id as target_concept_class,
c.standard_concept as target_standard_concept,
c.domain_id as target_domain_id,
c.vocabulary_id as target_vocabulary_id
FROM source s
JOIN sources.meta_mrrel mr on s.cui = mr.cui1
JOIN sources.meta_mrconso mc on mr.cui2 = mc.cui
JOIN concept c on mc.code = c.concept_code
WHERE c.vocabulary_id in ('SNOMED', 'RxNORM', 'CPT4', 'UCUM', 'LOINC')
AND c.standard_concept = 'S'
AND c.invalid_reason is null
AND mr.rela in ('mapped_from')
AND s.scui not in (SELECT scui FROM rel));

--Name-based mappings meta_-derived mappings
INSERT INTO rel (SELECT DISTINCT s.scui,
                                 s.concept_name,
                                 'Maps to'          AS relationship_id,
                                 c.concept_id       AS target_concept_id,
                                 c.concept_code     AS target_concept_code,
                                 c.concept_name     AS target_concept_name,
                                 c.concept_class_id AS target_concept_class,
                                 c.standard_concept AS target_standard_concept,
                                 c.domain_id        AS target_domain_id,
                                 c.vocabulary_id    AS target_vocabulary_id
                 FROM source s
                          JOIN concept c
                               ON c.concept_name = s.concept_name
                                   AND c.standard_concept = 'S'
                                   AND c.vocabulary_id IN ('SNOMED', 'LOINC')
                                   AND c.domain_id IN ('Condition', 'Procedure', 'Measurement', 'Observation')
                                   AND c.concept_class_id <> 'Substance'
                                   AND s.scui NOT IN (SELECT scui FROM rel))
;

--Working with concept_relationship_manual table
DELETE FROM concept_relationship_manual
where vocabulary_id_1='CDISC'
and concept_code_2='No matching concept'
;

--working with manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;


--concept_relationship_stage
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
CURRENT_DATE	AS valid_start_date,
TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
null as invalid_reason
FROM source s JOIN rel r ON s.scui = r.scui
WHERE s.scui in
(SELECT scui FROM rel
    GROUP BY scui
    HAVING count(scui) = 1
    )
and (s.concept_code,'CDISC') NOT IN (SELECT concept_code_1,vocabulary_id_1 FROM concept_relationship_manual where invalid_reason is null and relationship_id like 'Maps to%')
;

--Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--Add mapping from deprecated to fresh concepts for 'Maps to value'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

DROP TABLE source;
DROP TABLE rel;

