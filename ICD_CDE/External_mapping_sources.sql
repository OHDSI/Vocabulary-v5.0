--External mappings sources exploration
DROP TABLE map_for_review;
TRUNCATE TABLE map_for_review;
CREATE TABLE map_for_review (
    source_code varchar,
    source_code_description varchar,
    source_vocabulary_id varchar,
    relationship_id varchar,
    target_concept_id bigint,
    target_concept_code varchar,
    target_concept_name varchar,
    target_concept_class_id varchar,
    target_standard_concept varchar,
    target_invalid_reason varchar,
    target_domain_id varchar,
    target_vocabulary_id varchar,
    mappings_origin varchar);

-- Mappings through UMLS (NCI)
-- Mapping ICD10 to standard using SNOMED
INSERT INTO map_for_review (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            relationship_id,
                            target_concept_id,
                            target_concept_code,
                            target_concept_name,
                            target_concept_class_id,
                            target_standard_concept,
                            target_invalid_reason,
                            target_domain_id,
                            target_vocabulary_id,
                            mappings_origin)
SELECT DISTINCT
m.code as source_code,
sr.concept_name as source_name,
'ICD10' as source_vocabulary_id,
cr.relationship_id       as relationship_id,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class_id,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id,
'UMLS/NCIm' as mappings_origin
FROM sources.mrconso m
JOIN concept sr on m.code = sr.concept_code
JOIN sources.mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'SNOMED'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ('Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE m.sab = 'ICD10'
AND s.sab = 'SNOMEDCT_US'
AND sr.vocabulary_id = 'ICD10'
AND cc.standard_concept = 'S'
AND cc.invalid_reason is null --6276

UNION

-- Mapping ICD10 to standard using MedDRA
SELECT DISTINCT
m.code as source_code,
sr.concept_name as source_name,
'ICD10' as source_vocabulary_id,
cr.relationship_id       as relationship_id,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class_id,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id,
'UMLS/NCIm' as mappings_origin
FROM sources.mrconso m
JOIN concept sr on m.code = sr.concept_code
JOIN sources.mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'MedDRA'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ('Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE m.sab = 'ICD10'
AND s.sab = 'MDR'
AND sr.vocabulary_id = 'ICD10'
AND cc.standard_concept = 'S'
AND cc.invalid_reason is null --6276

UNION

-- Mapping ICD10CM to standard using SNOMED
SELECT DISTINCT
m.code as source_code,
sr.concept_name as source_name,
'ICD10CM' as source_vocabulary_id,
cr.relationship_id       as relationship_id,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class_id,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id,
'UMLS/NCIm' as mappings_origin
FROM sources.mrconso m
JOIN concept sr on m.code = sr.concept_code
JOIN sources.mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'SNOMED'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ('Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE m.sab = 'ICD10CM'
AND s.sab = 'SNOMEDCT_US'
AND sr.vocabulary_id = 'ICD10CM'
AND cc.standard_concept = 'S'
AND cc.invalid_reason is null --6276

UNION

-- Mapping ICD10CM to standard using MedDRA
SELECT DISTINCT
m.code as source_code,
sr.concept_name as source_name,
'ICD10CM' as source_vocabulary_id,
cr.relationship_id       as relationship_id,
cc.concept_id       as target_concept_id,
cc.concept_code     as target_concept_code,
cc.concept_name     as target_concept_name,
cc.concept_class_id as target_concept_class_id,
cc.standard_concept as target_standard_concept,
cc.invalid_reason   as target_invalid_reason,
cc.domain_id        as target_domain_id,
cc.vocabulary_id    as target_vocabulary_id,
'UMLS/NCIm' as mappings_origin
FROM sources.mrconso m
JOIN concept sr on m.code = sr.concept_code
JOIN sources.mrconso s using(cui)
JOIN concept c on c.concept_code = s.code and c.vocabulary_id = 'MedDRA'
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id and cr.relationship_id IN ('Maps to' ,'Maps to value') and cr.invalid_reason is null
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE m.sab = 'ICD10CM'
AND s.sab = 'MDR'
AND sr.vocabulary_id = 'ICD10CM'
AND cc.standard_concept = 'S'
AND cc.invalid_reason is null --6276
;

INSERT INTO map_for_review (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            relationship_id,
                            target_concept_id,
                            target_concept_code,
                            target_concept_name,
                            target_concept_class_id,
                            target_standard_concept,
                            target_invalid_reason,
                            target_domain_id,
                            target_vocabulary_id,
                            mappings_origin)
-- SNOMED-to-ICD10 equivalence
SELECT DISTINCT
        maptarget as source_code,
        cc.concept_name as source_code_description,
        'ICD10' as source_vocabulary_id,
        'Maps to' as relationship_id,
        c.concept_id as target_concept_id,
        c.concept_code as target_concept_code,
        c.concept_name as target_concept_name,
        c.concept_class_id as target_concept_class_id,
        c.standard_concept as target_standard_concept,
        c.invalid_reason as target_invalid_reason,
        c.domain_id as target_domain_id,
        c.vocabulary_id as target_vocabulary_id,
        'SNOMED_eq' as mappings_origin
FROM sources.der2_iisssccrefset_extendedmapfull_us s
JOIN concept c ON s.referencedcomponentid = c.concept_code AND c.vocabulary_id = 'SNOMED' AND c.standard_concept = 'S'
JOIN concept cc ON cc.concept_code = s.maptarget AND cc.vocabulary_id = 'ICD10'
WHERE refsetid = '447562003'
 AND active = '1'
 AND maprule = 'TRUE'
 AND mapcategoryid = '447637006' --118867

 UNION

-- SNOMED-to-ICD10CM equivalence
SELECT DISTINCT
        maptarget as source_code,
        cc.concept_name as source_code_description,
        'ICD10CM' as source_vocabulary_id,
        'Maps to' as relationship_id,
        c.concept_id as target_concept_id,
        c.concept_code as target_concept_code,
        c.concept_name as target_concept_name,
        c.concept_class_id as target_concept_class_id,
        c.standard_concept as target_standard_concept,
        c.invalid_reason as target_invalid_reason,
        c.domain_id as target_domain_id,
        c.vocabulary_id as target_vocabulary_id,
        'SNOMED_eq' as mappings_origin
FROM sources.der2_iisssccrefset_extendedmapfull_us s
JOIN concept c ON s.referencedcomponentid = c.concept_code AND c.vocabulary_id = 'SNOMED' AND c.standard_concept = 'S'
JOIN concept cc ON cc.concept_code = s.maptarget AND cc.vocabulary_id = 'ICD10CM'
WHERE refsetid = '447562003'
 AND active = '1'
 AND maprule = 'TRUE'
 AND mapcategoryid = '447637006'; --102336

 SELECT * FROM map_for_review; -- 242449


SELECT DISTINCT
       a.source_code,
       a.source_code_description,
       a.source_vocabulary_id,
       a.target_concept_id as descendant_concept_id,
       b.target_concept_id as ancestor_concept_id,
       a.target_concept_name as descendant_concept_name,
       b.target_concept_name as ancestor_concept_name
FROM map_for_review a
JOIN map_for_review b
    ON a.source_code = b.source_code
LEFT JOIN concept_ancestor ca
    ON a.target_concept_id = ca.descendant_concept_id
        AND b.target_concept_id = ca.ancestor_concept_id
WHERE a.target_concept_id != b.target_concept_id
; -- 9548 distinct codes

-- Insert mappings from external sources into the dev_icd10.icd_cde_source table
INSERT INTO icd_cde_source (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            group_name,
                            --medium_group_id,
                            --broad_group_id,
                            relationship_id,
                            --for_review,
                            target_concept_id,
                            target_concept_code,
                            target_concept_name,
                            target_concept_class_id,
                            target_standard_concept,
                            target_invalid_reason,
                            target_domain_id,
                            target_vocabulary_id,
                            rel_invalid_reason,
                            valid_start_date,
                            valid_end_date,
                            mappings_origin)
SELECT source_code as source_code,
       source_code_description as source_code_description,
       source_vocabulary_id as source_vocabulary_id,
       source_code_description as group_name,
       relationship_id as relationship_id,
       --'1' as for_review,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_concept_class_id,
       target_standard_concept,
       target_invalid_reason,
       target_domain_id,
       target_vocabulary_id,
       null as rel_invalid_reason,
       current_date as valid_start_date,
       '2099-12-31'::date as valid_end_date,
       mappings_origin
       FROM map_for_review;

--Update the status of mapping candidates from external sources
--DROP TABLE icd_cde_ext_sources;
TRUNCATE TABLE icd_cde_ext_sources;
CREATE TABLE icd_cde_ext_sources
(
group_name varchar,
group_id int,
group_code varchar [],
medium_group_id int,
medium_group_code varchar,
broad_group_id int,
broad_group_code varchar,
mappings_origin text[],
for_review varchar,
relationship_id varchar,
relationship_id_predicate varchar,
decision int,
decision_date date,
comments varchar,
target_concept_id int,
target_concept_code varchar,
target_concept_name varchar,
target_concept_class_id varchar,
target_standard_concept varchar,
target_invalid_reason varchar,
target_domain_id varchar,
target_vocabulary_id varchar,
mapper_id varchar,
rel_invalid_reason         varchar,
valid_start_date           date,
valid_end_date             date);

INSERT INTO icd_cde_ext_sources (
group_name,
group_id,
group_code,
mappings_origin,
for_review,
relationship_id,
--decision,
target_concept_id,
target_concept_code,
target_concept_name,
target_concept_class_id,
target_standard_concept,
target_invalid_reason,
target_domain_id,
target_vocabulary_id,
rel_invalid_reason,
valid_start_date,
valid_end_date)

WITH code_agg as
    (SELECT group_id,
    (array_agg (DISTINCT CONCAT (source_vocabulary_id || ':' || source_code))) as group_code
    FROM icd_cde_source
    GROUP BY group_id
    ORDER BY group_id)
SELECT DISTINCT
s.group_name,
s.group_id,
c.group_code,
array_agg (DISTINCT s.mappings_origin) as mappings_origin,
s.for_review,
s.relationship_id,
--s.decision,
s.target_concept_id,
cc.concept_code,
cc.concept_name,
cc.concept_class_id,
cc.standard_concept,
cc.invalid_reason,
cc.domain_id,
cc.vocabulary_id,
null as rel_invalid_reason,
current_date as valid_start_date,
'2099-12-31'::date as valid_end_date
FROM icd_cde_source s
JOIN code_agg c ON s.group_id = c.group_id
LEFT JOIN devv5.concept cc on s.target_concept_id = cc.concept_id
AND s.target_vocabulary_id = cc.vocabulary_id
WHERE for_review = '1'
AND target_invalid_reason is null
AND target_standard_concept = 'S'
AND array_length (c.group_code, 1) > 1
AND s.group_id not in (
    SELECT group_id FROM icd_cde_source s
    WHERE s.decision = '1')
GROUP BY s.group_id, s.group_name,
         target_concept_id,
         s.for_review,
         s.relationship_id,
         s.group_id,
         c.group_code,
         --s.decision,
         s.for_review,
         s.group_name,
         s.target_concept_id,
         cc.concept_code,
         cc.concept_name,
         cc.concept_class_id,
         cc.standard_concept,
         cc.invalid_reason,
         cc.domain_id,
         cc.vocabulary_id
ORDER BY group_id desc
;

--Set decision = 1 where there is only 1 mapping candidate (check for several mappings sources)
UPDATE icd_cde_ext_sources SET decision = '1', decision_date = current_date
WHERE group_name in (
SELECT group_name FROM icd_cde_ext_sources
WHERE array_length(mappings_origin, 1) >1
AND group_id NOT IN (
    SELECT group_id FROM icd_cde_ext_sources
    WHERE relationship_id = 'Maps to value'
    )
AND group_id IN (
    SELECT group_id FROM icd_cde_ext_sources
    GROUP BY group_id
    HAVING count (group_id)=1
    ))
;

--Decidion '1' for those with only mapping candidate with several sources
--UPDATE icd_cde_ext_sources SET decision = '1', decision_date = current_date
--WHERE group_name in (
--with sev as (
--SELECT * FROM icd_cde_ext_sources
--where decision is null
--and group_id not in (
--    SELECT group_id FROM icd_cde_ext_sources
--    where relationship_id = 'Maps to value'))
--SELECT group_name FROM sev where array_length(mappings_origin, 1)>1
--group by group_name
--having count (group_name) = 1)
--AND array_length(mappings_origin, 1)>1
--AND target_concept_code is not null;

--Decision '1' for those with the mapping candidate with >2 mapping sources
UPDATE icd_cde_ext_sources SET decision = '1', decision_date = current_date
WHERE group_name in (
SELECT group_name FROM icd_cde_ext_sources
WHERE group_id not in (
SELECT DISTINCT group_id FROM icd_cde_ext_sources WHERE decision = '1')
AND array_length(mappings_origin, 1)>2
AND group_id NOT IN (
    SELECT group_id FROM icd_cde_ext_sources
    WHERE relationship_id = 'Maps to value')
GROUP BY group_name
HAVING count (group_name) = 1)
AND array_length(mappings_origin, 1)>2;

--ADD UPDATE OF ICD_CDE_SOURCE ON icd_cde_ext_sources TABLE
--Update rel_invalid_reason, valid_start_date, valid_end_date fields for candidates
UPDATE icd_cde_ext_sources SET
decision_date = current_date
WHERE decision = '1';

WITH rec_for_source as(
    SELECT DISTINCT sr.source_code,
                      sr.source_code_description,
                      sr.source_vocabulary_id,
                      m.target_concept_id :: int,
                      m.decision_date
    FROM dev_icd10.icd_cde_ext_sources m
    JOIN (SELECT DISTINCT s.source_code_description,
                            s.group_name,
                            s.source_code,
                            s.source_vocabulary_id,
                            s.target_concept_id :: int
            FROM dev_icd10.icd_cde_source s) sr ON m.group_name = sr.group_name AND
                                                   m.target_concept_id = sr.target_concept_id
    WHERE m.decision = 1
      --AND m.group_id = 39774
)
UPDATE dev_icd10.icd_cde_source t SET
    decision = CASE WHEN t.source_code_description = t.group_name
                         THEN 1
                         ELSE NULL
                    END,
    decision_date = CASE WHEN t.source_code_description = t.group_name
                             THEN rs.decision_date
                             ELSE NULL
                        END
    --valid_start_date = rs.decision_date
FROM rec_for_source rs
WHERE  t.source_code = rs.source_code AND
       t.source_code_description = rs.source_code_description AND
       t.source_vocabulary_id = rs.source_vocabulary_id AND
       t.target_concept_id = rs.target_concept_id;

--MANUAL FILE
-- for external mappings integration
SELECT DISTINCT * FROM icd_cde_ext_sources es
WHERE group_id NOT IN (
SELECT DISTINCT group_id FROM icd_cde_ext_sources WHERE decision = '1')
AND group_id not in (SELECT group_id FROM icd_cde_manual)
;

--ADD relationships reviewed manualy
--DROP TABLE icd_cde_mapped_ext;
--TRUNCATE TABLE icd_cde_mapped_ext;
--CREATE TABLE icd_cde_mapped_ext_back_6_9_2024 AS SELECT * FROM icd_cde_mapped_ext;
CREATE TABLE icd_cde_mapped_ext
(
group_name varchar,
group_id int,
group_code varchar [],
medium_group_id int,
medium_group_code varchar,
broad_group_id int,
broad_group_code varchar,
mappings_origin varchar,
for_review varchar,
relationship_id varchar,
relationship_id_predicate varchar,
decision int,
decision_date date,
comments varchar,
target_concept_id int,
target_concept_code varchar,
target_concept_name varchar,
target_concept_class_id varchar,
target_standard_concept varchar,
target_invalid_reason varchar,
target_domain_id varchar,
target_vocabulary_id varchar,
mapper_id varchar,
rev_id text,
rel_invalid_reason varchar,
valid_start_date  date,
valid_end_date  date);

--Update mapper and reviewer fields
DELETE FROM icd_cde_mapped_ext WHERE group_code is null;
UPDATE icd_cde_mapped_ext SET mapper_id = 'TO' WHERE mapper_id = 'Mapper: tetiana.orlova@odysseusinc.com';
UPDATE icd_cde_mapped_ext SET mapper_id = 'JC' WHERE mapper_id = 'Mapper: janice.cruz@odysseusinc.com';
UPDATE icd_cde_mapped_ext SET mapper_id = 'IZ' WHERE mapper_id = 'Mapper: irina.zherko@odysseusinc.com';
UPDATE icd_cde_mapped_ext SET mapper_id = 'MK' WHERE mapper_id = 'Mapper: maria.khitrun@odysseusinc.com';
UPDATE icd_cde_mapped_ext SET mapper_id = 'TS' WHERE mapper_id = 'Mapper: tatiana.skugarevskaya@odysseusinc.com';
UPDATE icd_cde_mapped_ext SET rev_id = 'IZ' WHERE rev_id = 'Reviewer: irina.zherko@odysseusinc.com';
UPDATE icd_cde_mapped_ext SET rev_id = 'MK' WHERE rev_id = 'Reviewer: maria.khitrun@odysseusinc.com';
UPDATE icd_cde_mapped_ext SET rev_id = 'TS' WHERE rev_id = 'Reviewer: tatiana.skugarevskaya@odysseusinc.com';
UPDATE icd_cde_mapped_ext SET rev_id = 'TO' WHERE rev_id = 'Reviewer: tetiana.orlova@odysseusinc.com';
UPDATE icd_cde_mapped_ext SET rev_id = 'JC' WHERE rev_id = 'Reviewer: janice.cruz@odysseusinc.com';
UPDATE icd_cde_mapped_ext SET rev_id = null WHERE rev_id = 'Reviewer: 0';

--For the rest of external mappings integration (not those from August 2024 release)
DELETE FROM icd_cde_mapped_ext WHERE group_name IN (SELECT group_name FROM icd_cde_mapped_ext_back_6_9_2024);

INSERT INTO icd_cde_mapped (
    SELECT * FROM icd_cde_mapped_ext
    WHERE group_name not in (SELECT DISTINCT group_name FROM icd_cde_mapped));