CREATE TABLE icd_cde_source_backup_2_20_2024 as SELECT * FROM icd_cde_source;
CREATE TABLE icd_cde_source_backup_local_ver as SELECT * FROM icd_cde_source;
TRUNCATE TABLE icd_cde_source;
INSERT INTO icd_cde_source (SELECT * FROM icd_cde_source_backup_local_ver);
SELECT * FROM icd_cde_source;

--1. СDE source insertion
DROP TABLE dev_icd10.icd_cde_source;
TRUNCATE TABLE dev_icd10.icd_cde_source;
CREATE TABLE dev_icd10.icd_cde_source
(
    source_code                TEXT NOT NULL,
    source_code_description    varchar,
    source_vocabulary_id       varchar,
    group_name                 varchar,
    group_id                   int,
    --group_code                 varchar, -- group code is dynamic and is assembled after grouping just before insertion data into the google sheet
    medium_group_id            integer,
    --medium_group_code          varchar,
    broad_group_id             integer,
    --broad_group_code           varchar,
    for_review                 varchar,
    decision                   varchar,
    decision_date              varchar,
    relationship_id            varchar,
    relationship_id_predicate  varchar,
    target_concept_id          integer,
    target_concept_code        varchar,
    target_concept_name        varchar,
    target_concept_class_id    varchar,
    target_standard_concept    varchar,
    target_invalid_reason      varchar,
    target_domain_id           varchar,
    target_vocabulary_id       varchar,
    rel_invalid_reason         varchar,
    valid_start_date           date,
    valid_end_date             date,
    mappings_origin            varchar
);

-- Run load_stage for every Vocabulary to be included into the CDE
-- Insert the whole source with existing mappings into the CDE. We want to preserve mappings to non-S or non valid concepts at this stage.
-- Concepts, that are not supposed to have mappings are not included
-- If there are several mapping sources all the versions should be included, excluding duplicates within one vocabulary.
-- Mapping duplicates between vocabularies are preserved

--ICD10 with mappings
INSERT INTO icd_cde_source (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            group_name,
                            --medium_group_id,
                            --broad_group_id,
                            relationship_id,
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
-- Check Select before insertion
-- To insert mappings from concept_relationship_stage
SELECT cs.concept_code     as source_code,
       cs.concept_name     as source_code_description,
       'ICD10'             as source_vocabulary_id,
       cs.concept_name     as group_name,
       crs.relationship_id as relationship_id,
       c.concept_id        as target_concept_id,
       crs.concept_code_2  as target_concept_code,
       c.concept_name      as target_concept_name,
       c.concept_class_id  as target_concept_class,
       c.standard_concept  as target_standard_concept,
       c.invalid_reason    as target_invalid_reason,
       c.domain_id         as target_domain_id,
       crs.vocabulary_id_2 as target_vocabulary_id,
       crs.invalid_reason  as rel_invalid_reason,
       crs.valid_start_date as valid_start_date,
       crs.valid_end_date  as valid_end_date,
       CASE WHEN c.concept_id is not null THEN 'crs' ELSE null END as mappings_origin
FROM dev_icd10.concept_stage cs
LEFT JOIN dev_icd10.concept_relationship_stage crs
    on cs.concept_code = crs.concept_code_1
    and crs.relationship_id in ('Maps to', 'Maps to value')
LEFT JOIN concept c
    on crs.concept_code_2 = c.concept_code
    and crs.vocabulary_id_2 = c.vocabulary_id
where cs.concept_class_id not in ('ICD10 Chapter','ICD10 SubChapter')
--and crs.concept_code_2 IS NOT NULL;

--Update 'mappings_origin' flag
UPDATE icd_cde_source s SET
mappings_origin = 'functions_updated'
WHERE valid_start_date in (SELECT DISTINCT GREATEST (d.lu_1, d.lu_2)
FROM (SELECT v1.latest_update AS lu_1, v2.latest_update AS lu_2
			FROM concept_relationship_stage crs
			JOIN vocabulary v1 ON v1.vocabulary_id = crs.vocabulary_id_1
			JOIN vocabulary v2 ON v2.vocabulary_id = crs.vocabulary_id_2) d)
OR valid_end_date in (SELECT DISTINCT GREATEST(crs.valid_start_date, (
				SELECT MAX(v.latest_update) - 1
				FROM vocabulary v
				WHERE v.vocabulary_id IN (
						crs.vocabulary_id_1,
						crs.vocabulary_id_2
					)
			)) FROM concept_relationship_stage crs);

--Insertion of the potential replacement mappings and concepts without mappings
INSERT INTO icd_cde_source (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            group_name,
                            relationship_id,
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
SELECT
source_code,
source_code_description,
source_vocabulary_id,
source_code_description as group_name,
relationship_id,
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
mappings_origin
FROM icd10_refresh;

--ICD10CM with mappings
INSERT INTO icd_cde_source (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            group_name,
                            --medium_group_id,
                            --broad_group_id,
                            relationship_id,
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
-- Check Select before insertion --135145 S valid, 263603 non-S valid, 266773 non-S not-valid
SELECT cs.concept_code     as source_code,
       cs.concept_name     as source_code_description,
       'ICD10CM'           as source_vocabulary_id,
       cs.concept_name     as group_name,
       crs.relationship_id as relationship_id,
       c.concept_id        as target_concept_id,
       crs.concept_code_2  as target_concept_code,
       c.concept_name      as target_concept_name,
       c.concept_class_id  as target_concept_class,
       c.standard_concept  as target_standard_concept,
       c.invalid_reason    as target_invalid_reason,
       c.domain_id         as target_domain_id,
       crs.vocabulary_id_2 as target_vocabulary_id,
       crs.invalid_reason  as rel_invalid_reason,
       crs.valid_start_date as valid_start_date,
       crs.valid_end_date as valid_end_date,
       CASE WHEN c.concept_id is not null THEN 'crs' ELSE null END as mappings_origin
FROM dev_icd10cm.concept_stage cs
LEFT JOIN dev_icd10cm.concept_relationship_stage crs
    on cs.concept_code = crs.concept_code_1
    and relationship_id in ('Maps to', 'Maps to value')
LEFT JOIN concept c
    on crs.concept_code_2 = c.concept_code
    and crs.vocabulary_id_2 = c.vocabulary_id
WHERE crs.concept_code_2 IS NOT NULL;

--Update 'mappings_origin' flag
UPDATE icd_cde_source s SET
mappings_origin = 'functions_updated'
WHERE valid_start_date in (SELECT DISTINCT GREATEST (d.lu_1, d.lu_2)
FROM (SELECT v1.latest_update AS lu_1, v2.latest_update AS lu_2
			FROM dev_icd10cm.concept_relationship_stage crs
			JOIN vocabulary v1 ON v1.vocabulary_id = crs.vocabulary_id_1
			JOIN vocabulary v2 ON v2.vocabulary_id = crs.vocabulary_id_2 WHERE crs.concept_code_2 IS NOT NULL) d)
OR valid_end_date in (SELECT DISTINCT GREATEST(crs.valid_start_date, (
				SELECT MAX(v.latest_update) - 1
				FROM vocabulary v
				WHERE v.vocabulary_id IN (
						crs.vocabulary_id_1,
						crs.vocabulary_id_2
					)
			)) FROM dev_icd10cm.concept_relationship_stage crs);

--Insertion of the potential replacement mappings and concepts without mappings
INSERT INTO icd_cde_source (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            group_name,
                            relationship_id,
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
SELECT
source_code,
source_code_description,
source_vocabulary_id,
source_code_description as group_name,
relationship_id,
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
mappings_origin
FROM dev_icd10cm.icd10cm_refresh;

--ICD10GM with mappings (only manual mappings, conflicts and unique codes are inserted)
INSERT INTO icd_cde_source (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            group_name,
                            --medium_group_id,
                            --broad_group_id,
                            relationship_id,
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
SELECT source_code,
       source_code_description,
       source_vocabulary_id,
       source_code_description,
       relationship_id,
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
       mappings_origin
FROM dev_icd10gm.icd10gm_refresh;

--CIM10 with mappings (only manual mappings, conflicts and unique codes are inserted)
INSERT INTO icd_cde_source (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            group_name,
                            --medium_group_id,
                            --broad_group_id,
                            relationship_id,
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
SELECT source_code,
       source_code_description,
       source_vocabulary_id,
       source_code_description,
       relationship_id,
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
       mappings_origin
FROM dev_cim10.CIM10_refresh;

--ICD10CN with mappings (only manual mappings are inserted)
INSERT INTO icd_cde_source (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            group_name,
                            --medium_group_id,
                            --broad_group_id,
                            relationship_id,
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
SELECT source_code,
       source_code_description,
       source_vocabulary_id,
       source_code_description,
       relationship_id,
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
       mappings_origin
FROM dev_icd10cn.icd10cn_refresh;;

--KCD7 with mappings (only manual mappings are inserted)
INSERT INTO icd_cde_source (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            group_name,
                            --medium_group_id,
                            --broad_group_id,
                            relationship_id,
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
SELECT source_code,
       source_code_description,
       source_vocabulary_id,
       source_code_description,
       relationship_id,
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
       mappings_origin
FROM dev_kcd7.KCD7_refresh;

--ICD9CM with mappings
INSERT INTO icd_cde_source (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            group_name,
                            --medium_group_id,
                            --broad_group_id,
                            relationship_id,
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
-- Check Select before insertion
-- To insert mappings from concept_relationship_stage
SELECT cs.concept_code     as source_code,
       cs.concept_name     as source_code_description,
       'ICD9CM'             as source_vocabulary_id,
       cs.concept_name     as group_name,
       crs.relationship_id as relationship_id,
       c.concept_id        as target_concept_id,
       crs.concept_code_2  as target_concept_code,
       c.concept_name      as target_concept_name,
       c.concept_class_id  as target_concept_class,
       c.standard_concept  as target_standard_concept,
       c.invalid_reason    as target_invalid_reason,
       c.domain_id         as target_domain_id,
       crs.vocabulary_id_2 as target_vocabulary_id,
       crs.invalid_reason  as rel_invalid_reason,
       crs.valid_start_date as valid_start_date,
       crs.valid_end_date  as valid_end_date,
       CASE WHEN c.concept_id is not null THEN 'crs' ELSE null END as mappings_origin
FROM dev_icd9cm.concept_stage cs
LEFT JOIN dev_icd9cm.concept_relationship_stage crs
    on cs.concept_code = crs.concept_code_1
    and crs.relationship_id in ('Maps to', 'Maps to value')
LEFT JOIN concept c
    on crs.concept_code_2 = c.concept_code
    and crs.vocabulary_id_2 = c.vocabulary_id
where crs.concept_code_2 IS NOT NULL;

--Update 'mappings_origin' flag
UPDATE icd_cde_source s SET
mappings_origin = 'functions_updated'
WHERE valid_start_date in (SELECT DISTINCT GREATEST (d.lu_1, d.lu_2)
FROM (SELECT v1.latest_update AS lu_1, v2.latest_update AS lu_2
			FROM dev_icd9cm.concept_relationship_stage crs
			JOIN vocabulary v1 ON v1.vocabulary_id = crs.vocabulary_id_1
			JOIN vocabulary v2 ON v2.vocabulary_id = crs.vocabulary_id_2) d)
OR valid_end_date in (SELECT DISTINCT GREATEST(crs.valid_start_date, (
				SELECT MAX(v.latest_update) - 1
				FROM vocabulary v
				WHERE v.vocabulary_id IN (
						crs.vocabulary_id_1,
						crs.vocabulary_id_2
					)
			)) FROM dev_icd9cm.concept_relationship_stage crs);

--Insertion of the potential replacement mappings and concepts without mappings
INSERT INTO icd_cde_source (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            group_name,
                            relationship_id,
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
SELECT
source_code,
source_code_description,
source_vocabulary_id,
source_code_description as group_name,
relationship_id,
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
mappings_origin
FROM dev_icd9cm.icd9cm_refresh;

-- Insert community contribution
-- TRUNCATE TABLE dev_icd10.icd_community_contribution;
CREATE TABLE dev_icd10.icd_community_contribution
(
    source_code             TEXT NOT NULL,
    source_code_description varchar,
    source_vocabulary_id    varchar,
    group_name              varchar,
    group_id                int,
    --group_code              varchar, -- group code is dynamic and is assembled after grouping just before insertion data into the google sheet
    medium_group_id         integer,
    --medium_group_code       varchar,
    broad_group_id          integer,
    --broad_group_code        varchar,
    for_review              varchar,
    relationship_id         varchar,
    target_concept_id       integer,
    target_concept_code     varchar,
    target_concept_name     varchar,
    target_concept_class_id varchar,
    target_standard_concept varchar,
    target_invalid_reason   varchar,
    target_domain_id        varchar,
    target_vocabulary_id    varchar,
    rel_invalid_reason      varchar,
    valid_start_date        date,
    valid_end_date          date,
    mappings_origin         varchar
);

INSERT INTO icd_cde_source (source_code,
                            source_code_description,
                            source_vocabulary_id,
                            group_name,
                            --medium_group_id,
                            --broad_group_id,
                            relationship_id,
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
SELECT source_code,
       source_code_description,
       source_vocabulary_id,
       source_code_description,
       relationship_id,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_concept_class_id,
       'S' as target_standard_concept,
       null as target_invalid_reason,
       target_domain_id,
       target_vocabulary_id,
       rel_invalid_reason,
       valid_start_date,
       valid_end_date,
       'CC' as mappings_origin
FROM dev_icd10.icd_community_contribution;

--2. check all the inserted rows
SELECT * FROM icd_cde_source
ORDER BY source_code;

--3. check all the ICD10 concepts are in the CDE
SELECT *
FROM dev_icd10.concept_stage
WHERE (concept_code, concept_name) not in
(SELECT source_code, source_code_description FROM icd_cde_source
WHERE source_vocabulary_id = 'ICD10')
AND concept_class_id not in ('ICD10 Chapter','ICD10 SubChapter');

--4. check all the ICD10CM concepts are in the CDE
SELECT *
FROM dev_icd10cm.concept_stage
WHERE (concept_code, concept_name) not in
(SELECT source_code, source_code_description FROM icd_cde_source
WHERE source_vocabulary_id = 'ICD10CM');

--5. Check for null values in source_code, source_code_description, source_vocabulary_id fields
SELECT * FROM icd_cde_source
    WHERE source_code is null
    OR source_code_description is null
    or source_vocabulary_id is null;

--6. Grouping
DROP TABLE grouped;
CREATE TABLE grouped as (
WITH RECURSIVE hierarchy_concepts
AS (
	SELECT c.ancestor_id AS root_source_code_description, --create virtual group by description
		c.ancestor_id,
		c.descendant_id,
		ARRAY [c.descendant_id] AS full_path
	FROM concepts c
	WHERE c.ancestor_id IN (
			--each code+target can have several descriptions, so to simplify the hierarchy, we take only one "minimum" description
			SELECT MIN(cr.source_code_description)
			FROM concepts_raw cr
			GROUP BY cr.source_code,
				cr.target_concept_code
			)

	UNION ALL

	SELECT hc.root_source_code_description,
		c.ancestor_id,
		c.descendant_id,
		hc.full_path || c.descendant_id AS full_path
	FROM concepts c
	JOIN hierarchy_concepts hc ON hc.descendant_id = c.ancestor_id
	WHERE c.descendant_id <> ALL (hc.full_path)
	),
concepts_raw AS (
    SELECT * FROM icd_cde_source),
concepts AS (
	/*the general idea is to "group" by description first, resulting in pairs
	name1->(code1,target1),(code2,target2), ...
	name2->(code2,target2),(code3,target3), ...
	... etc
	and then convert the code+target pair back into names so that we can build a hierarchy from the first name (name1/name2) to all other names of all pairs

	in this query we get "ancestor" (source_code_description) and all its "descendants" by code+target, but use their descriptions so that we can build a hierarchy by "source_code_description" field
	*/
	SELECT cr1.source_code_description AS ancestor_id,
		cr2.source_code_description AS descendant_id
	FROM concepts_raw cr1
	--get source_code_description instead of code+target
	--some pairs may be in a single copy - that's why LEFT JOIN
	LEFT JOIN concepts_raw cr2 ON cr2.source_code = cr1.source_code
		AND cr2.target_concept_code = cr1.target_concept_code
		AND cr1.source_code_description <> cr2.source_code_description
	),
groups AS (
	SELECT MIN(root_source_code_description) AS root_source_code_description, --in some cases, a concept may fall into several groups at once. we take only one. remember, this field is just an indicator (partition) of groups
		COALESCE(descendant_id, root_source_code_description) AS descendant_id
	FROM hierarchy_concepts hc
	GROUP BY COALESCE(descendant_id, root_source_code_description)
)
--now we're ready to make a real grouping
SELECT DENSE_RANK() OVER (ORDER BY g.root_source_code_description) AS strict_group_id,
	FIRST_VALUE(cr.source_code_description) OVER (
		PARTITION BY g.root_source_code_description ORDER BY CASE
				WHEN cr.source_vocabulary_id = 'ICD10'
					THEN 0
				ELSE 1
				END,
			LENGTH(cr.source_code_description) DESC,
			cr.source_code_description --in case different groups have the same length
		) AS strict_group_name,
	cr.*
FROM groups g
JOIN concepts_raw cr ON cr.source_code_description = g.descendant_id);

UPDATE icd_cde_source
SET group_id = strict_group_id, group_name = strict_group_name FROM grouped
WHERE icd_cde_source.source_code = grouped.source_code
AND icd_cde_source.source_code_description = grouped.source_code_description
AND icd_cde_source.source_vocabulary_id = grouped.source_vocabulary_id;

--6. Check every concept is represented in only one group
SELECT DISTINCT
source_code,
source_vocabulary_id,
COUNT (DISTINCT group_id)
FROM icd_cde_source
GROUP BY group_id, source_code, source_vocabulary_id
HAVING COUNT (DISTINCT group_id) > 1;

--7. Check for group_name uniqueness
with names as (SELECT DISTINCT group_name FROM icd_cde_source)
SELECT DISTINCT group_name
FROM names
GROUP BY group_name
HAVING count(group_name) >1;

--8. Update for_review field (can be on different conditions during every refresh)
--For groups with several concepts and several mapping sources
UPDATE icd_cde_source SET for_review = '1'
    WHERE group_id in (SELECT group_id FROM icd_cde_source
GROUP BY group_id
HAVING COUNT (DISTINCT (source_vocabulary_id, source_code)) >1)
AND
group_id in (SELECT group_id FROM icd_cde_source
GROUP BY group_id
HAVING COUNT (DISTINCT (mappings_origin)) > 1)
;

--For ICD10, ICD10CM codes without mapping
UPDATE icd_cde_source SET for_review = '1'
WHERE group_id in (
    SELECT group_id FROM icd_cde_source
        WHERE source_vocabulary_id in ('ICD10', 'ICD10CM') AND target_concept_id is NULL);

--For 'Concept poss_eq' to
UPDATE icd_cde_source SET for_review = '1'
WHERE group_id in (
    SELECT group_id FROM icd_cde_source
   WHERE mappings_origin = 'Concept poss_eq to');

--For community contribution
UPDATE icd_cde_source SET for_review = '1'
WHERE group_id in (
    SELECT group_id FROM icd_cde_source
   WHERE mappings_origin = 'CC');

--9. Table for manual mapping and review creation
--DROP TABLE icd_cde_manual;
TRUNCATE TABLE icd_cde_manual;
CREATE TABLE icd_cde_manual
(
group_name varchar,
group_id int,
group_code varchar,
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
mapper_id varchar);

INSERT INTO icd_cde_manual (
group_name,
group_id,
group_code,
mappings_origin,
for_review,
relationship_id,
target_concept_id,
target_concept_code,
target_concept_name,
target_concept_class_id,
target_standard_concept,
target_invalid_reason,
target_domain_id,
target_vocabulary_id)

with code_agg as
    (SELECT group_id, (array_agg (DISTINCT CONCAT (source_vocabulary_id || ':' || source_code))) as group_code
    FROM icd_cde_source
    GROUP BY group_id
    ORDER BY group_id)
    -- map_or as
    --(SELECT group_id, string_agg (DISTINCT mappings_origin, ',') as mapping_origin
    --FROM icd_cde_source
    --GROUP BY group_id, target_concept_id
    --ORDER BY group_id)
SELECT DISTINCT
s.group_name,
s.group_id,
c.group_code,
string_agg (DISTINCT s.mappings_origin, ',')  as mapping_origin,
s.for_review,
s.relationship_id,
s.target_concept_id,
s.target_concept_code,
s.target_concept_name,
s.target_concept_class_id,
s.target_standard_concept,
s.target_invalid_reason,
s.target_domain_id,
s.target_vocabulary_id
FROM icd_cde_source s
JOIN code_agg c ON s.group_id = c.group_id
--JOIN map_or m ON s.group_id = m.group_id
WHERE for_review = '1'
AND (target_invalid_reason is null
AND target_standard_concept = 'S')
OR target_concept_id is null
GROUP BY s.group_id, s.group_name,
         target_concept_id,
         s.for_review,
         s.relationship_id,
         s.group_id,
         c.group_code,
         s.for_review,
         s.group_name,
         s.target_concept_id,
         s.target_concept_code,
         s.target_concept_name,
         s.target_concept_class_id,
         s.target_standard_concept,
         s.target_invalid_reason,
         s.target_domain_id,
         s.target_vocabulary_id
ORDER BY group_id desc
;

--for manual work
SELECT DISTINCT * FROM icd_cde_manual
WHERE group_id in
((SELECT group_id FROM icd_cde_manual
GROUP BY group_id
    HAVING count (group_id)>1)
UNION
SELECT group_id FROM icd_cde_manual
WHERE mappings_origin in ('CC', 'without mapping')
GROUP BY group_id
    HAVING count (group_id)=1)
--AND group_name not in (select group_name from icd_cde_mapped) -- only to add some group names
ORDER BY group_name;

--USE only if updates in the google sheet table are needed
--Create new table with all necessary updates
CREATE TABLE icd_cde_manual_updated
as (SELECT DISTINCT * FROM icd_cde_manual
WHERE group_id in
((SELECT group_id FROM icd_cde_manual
GROUP BY group_id
    HAVING count (group_id)>1)
UNION
SELECT group_id FROM icd_cde_manual
WHERE mappings_origin in ('CC', 'without mapping')
GROUP BY group_id
    HAVING count (group_id)=1)
ORDER BY group_name);

--Create current manual table and upload current state of google sheet
CREATE TABLE icd_cde_manual_current
(
group_name varchar,
group_id int,
group_code varchar,
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
mapper_id varchar);

--Select data to reload into the google sheet
SELECT DISTINCT
u.group_name as group_name,
u.group_id as group_id,
u.group_code as group_code,
null as medium_group_id,
null as medium_group_code,
null as broad_group_id,
null as broad_group_code,
c.mappings_origin as mappings_origin,
u.for_review as for_review,
c.relationship_id as relationship_id,
c.relationship_id_predicate as relationship_id_predicate,
c.decision as decision,
c.decision_date as decision_date,
c.comments as comments,
c.target_concept_id as target_concept_id,
c.target_concept_code as target_concept_code,
c.target_concept_name as target_concept_name,
c.target_concept_class_id as target_concept_class,
c.target_standard_concept as target_standard_concept,
c.target_invalid_reason as target_invalid_reason,
c.target_domain_id as target_domain_id,
c.target_vocabulary_id as target_vocabulary_id,
c.mapper_id as mapper_id
FROM icd_cde_manual_updated u
JOIN icd_cde_manual_current c
ON u.group_name = c.group_name

UNION

SELECT DISTINCT
u.group_name as group_name,
u.group_id as group_id,
u.group_code as group_code,
null as medium_group_id,
null as medium_group_code,
null as broad_group_id,
null as broad_group_code,
u.mappings_origin as mapping_origin,
u.for_review as for_review,
u.relationship_id as relationship_id,
u.relationship_id_predicate as relationship_id_predicate,
u.decision as decision,
u.decision_date as decision_date,
u.comments as comments,
u.target_concept_id as target_concept_id,
u.target_concept_code as target_concept_code,
u.target_concept_name as target_concept_name,
u.target_concept_class_id as target_concept_class_id,
u.target_standard_concept as target_standard_concept,
u.target_invalid_reason as target_invalid_reason,
u.target_domain_id as target_domain_id,
u.target_vocabulary_id as target_vocabulary_id,
u.mapper_id as mapper_id
FROM icd_cde_manual_updated u
WHERE (u.group_name, u.target_concept_id)
NOT IN (SELECT group_name, target_concept_id  FROM icd_cde_manual_current)
ORDER BY group_name;

--10. Create mapped table
--DROP TABLE icd_cde_mapped;
--TRUNCATE TABLE icd_cde_mapped;
CREATE TABLE icd_cde_mapped
(
group_name varchar,
group_id int,
group_code varchar,
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
rel_invalid_reason varchar,
valid_start_date  date,
valid_end_date  date);

SELECT * FROM icd_cde_mapped;

--11. Update mapped table
--Update decision flag --miss null!
UPDATE icd_cde_mapped SET decision = '0'
WHERE decision is null;

--Update target_standard_concept field
UPDATE icd_cde_mapped SET target_standard_concept = 'S'
WHERE target_standard_concept = 'Standard';

--Update target_invalid_reason field
UPDATE icd_cde_mapped SET target_invalid_reason = NULL
WHERE target_invalid_reason = 'Valid';

--Update rel_invalid_reason, valid_start_date, valid_end_date fields for declined candidates
UPDATE icd_cde_mapped SET
decision_date = current_date
WHERE decision in ('0', '1');

--12. Update targets status in the initial table from mapped table
UPDATE dev_icd10.icd_cde_source s
SET (relationship_id_predicate,
     decision,
     decision_date) = (
         SELECT DISTINCT
     relationship_id_predicate,
     decision,
     decision_date
FROM icd_cde_mapped m
WHERE s.group_name = m.group_name
AND s.target_concept_id = m.target_concept_id
AND s.target_concept_code = m.target_concept_code
--AND s.target_concept_name = m.target_concept_name
--AND s.target_concept_class_id = m.target_concept_class_id
--AND s.target_standard_concept = m.target_standard_concept
--AND s.target_invalid_reason = m.target_invalid_reason
--AND s.target_domain_id = m.target_domain_id
--AND s.target_vocabulary_id = m.target_vocabulary_id
    );

--Insert new and update existing relationships according to _mapped table.
INSERT INTO dev_icd10.icd_cde_source as s
    (source_code,
     source_code_description,
     source_vocabulary_id,
     group_name,
     group_id,
     relationship_id,
     relationship_id_predicate,
     decision,
     decision_date,
     target_concept_id,
     target_concept_code,
     target_concept_name,
     target_concept_class_id,
     target_standard_concept,
     target_invalid_reason,
     target_domain_id,
     target_vocabulary_id
)
	SELECT
	group_code,
	group_name,
	group_code,
	group_name,
	group_id,
	relationship_id,
    relationship_id_predicate,
    decision,
    decision_date,
    target_concept_id,
    target_concept_code,
    target_concept_name,
    target_concept_class_id,
    target_standard_concept,
    target_invalid_reason,
    target_domain_id,
    target_vocabulary_id
	FROM icd_cde_mapped m
	WHERE (m.group_name, m.target_concept_id) not in (SELECT group_name, target_concept_id FROM icd_cde_source)

	ON CONFLICT ON CONSTRAINT unique_manual_relationships
	DO UPDATE
	    SET (relationship_id_predicate,
     decision,
     decision_date) = (
         SELECT
     relationship_id_predicate,
     decision,
     decision_date
FROM icd_cde_mapped m
WHERE s.group_name = m.group_name
AND s.target_concept_id = m.target_concept_id);


--Update target for concept without mappings
UPDATE dev_icd10.icd_cde_source s
SET (relationship_id_predicate,
     decision,
     decision_date,
     relationship_id,
     target_concept_id,
     target_concept_code,
     target_concept_name,
     target_concept_class_id,
     target_standard_concept,
     target_invalid_reason,
     target_domain_id,
     target_vocabulary_id) = (
         SELECT
     relationship_id_predicate,
     decision,
     decision_date,
     relationship_id,
     target_concept_id,
     target_concept_code,
     target_concept_name,
     target_concept_class_id,
     target_standard_concept,
     target_invalid_reason,
     target_domain_id,
     target_vocabulary_id
FROM icd_cde_mapped m
WHERE s.group_id = m.group_id
AND s.mappings_origin = 'without mapping'
    );

--13. Create final table with mappings
TRUNCATE TABLE icd_cde_proc;
INSERT INTO icd_cde_proc (source_code,
                          source_code_description,
                          source_vocabulary_id,
                          group_name,
                          mappings_origin,
                          decision,
                          decision_date,
                          relationship_id,
                          relationship_id_predicate,
                          target_concept_id,
                          target_concept_code,
                          target_concept_name,
                          target_concept_class_id,
                          target_standard_concept,
                          target_invalid_reason,
                          target_domain_id,
                          target_vocabulary_id,
                          rel_invalid_reason)
SELECT DISTINCT
s.source_code as source_code,
s.source_code_description as source_code_description,
s.source_vocabulary_id as source_vocabulary_id,
s.group_name as group_name,
s.mappings_origin,
m.decision as decision,
m.decision_date as decision_date,
m.relationship_id as relatioonship_id,
m.relationship_id_predicate as relationship_id_predicate,
m.target_concept_id,
m.target_concept_code,
m.target_concept_name,
m.target_concept_class_id,
m.target_standard_concept,
m.target_invalid_reason,
m.target_domain_id,
m.target_vocabulary_id,
m.rel_invalid_reason
FROM icd_cde_source s JOIN icd_cde_mapped m
ON s.group_name = m.group_name
and m.decision = '1'
;

INSERT INTO icd_cde_proc (source_code,
                          source_code_description,
                          source_vocabulary_id,
                          group_name,
                          mappings_origin,
                          decision,
                          decision_date,
                          relationship_id,
                          relationship_id_predicate,
                          target_concept_id,
                          target_concept_code,
                          target_concept_name,
                          target_concept_class_id,
                          target_standard_concept,
                          target_invalid_reason,
                          target_domain_id,
                          target_vocabulary_id,
                          rel_invalid_reason)
SELECT source_code,
source_code_description,
source_vocabulary_id,
group_name,
mappings_origin,
decision,
decision_date,
relationship_id,
relationship_id_predicate,
target_concept_id,
target_concept_code,
target_concept_name,
target_concept_class_id,
target_standard_concept,
target_invalid_reason,
target_domain_id,
target_vocabulary_id,
rel_invalid_reason
    FROM icd_cde_source where group_name not in (SELECT group_name FROM icd_cde_mapped)
and rel_invalid_reason is null;

UPDATE icd_cde_proc SET relationship_id = 'Maps to' where relationship_id = 'Maps to '

SELECT * FROM icd_cde_proc where group_name = 'Osteitis deformans in neoplastic disease, multiple sites';

SELECT * FROM icd_cde_source where group_name = 'Osteitis deformans in neoplastic disease, multiple sites';