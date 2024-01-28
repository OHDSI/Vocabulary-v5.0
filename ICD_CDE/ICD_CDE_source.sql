CREATE TABLE icd_cde_source_backup as SELECT * FROM icd_cde_source;
CREATE TABLE icd_cde_source_backup_local_ver as SELECT * FROM icd_cde_source;
TRUNCATE TABLE icd_cde_source;
INSERT INTO icd_cde_source (SELECT * FROM icd_cde_source_backup_local_ver);
SELECT * FROM icd_cde_source;

--СDE source insertion
DROP TABLE dev_icd10.icd_cde_source;
TRUNCATE TABLE dev_icd10.icd_cde_source;
CREATE TABLE dev_icd10.icd_cde_source
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
where cs.concept_class_id not in ('ICD10 Chapter','ICD10 SubChapter', 'ICD10 Hierarchy')
and crs.concept_code_2 IS NOT NULL;

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
WHERE crs.concept_code_2 IS NOT NULL

--UNION
--
----to insert additional mappings from base_concept_relationship_manual
--SELECT cs.concept_code     as source_code,
--       cs.concept_name     as source_code_description,
--       'ICD10CM'           as source_vocabulary_id,
--       cs.concept_name     as group_name,
--       crm.relationship_id as relationship_id,
--       c.concept_id        as target_concept_id,
--       crm.concept_code_2  as target_concept_code,
--       c.concept_name      as target_concept_name,
--       c.concept_class_id  as target_concept_class,
--       c.standard_concept  as target_standard_concept,
--       c.invalid_reason    as target_invalid_reason,
--       c.domain_id         as target_domain_id,
--       crm.vocabulary_id_2 as target_vocabulary_id,
--       crm.valid_start_date as valid_start_date,
--       crm.valid_end_date as valid_end_date,
--       'crm' as mappings_origin
--FROM dev_icd10cm.concept_stage cs
--LEFT JOIN devv5.base_concept_relationship_manual crm
--    on cs.concept_code = crm.concept_code_1
--    and crm.relationship_id in ('Maps to', 'Maps to value')
--    and crm.vocabulary_id_1 = 'ICD10CM'
--LEFT JOIN concept c
--    on crm.concept_code_2 = c.concept_code
--    and crm.vocabulary_id_2 = c.vocabulary_id
--WHERE (crm.concept_code_1, crm.concept_code_2) NOT IN (SELECT concept_code_1, concept_code_2 FROM dev_icd10cm.concept_relationship_stage)
;

--Update 'mappings_origin' flag
UPDATE icd_cde_source s SET
mappings_origin = 'functions_updated'
WHERE valid_start_date in (SELECT DISTINCT GREATEST (d.lu_1, d.lu_2)
FROM (SELECT v1.latest_update AS lu_1, v2.latest_update AS lu_2
			FROM dev_icd10cm.concept_relationship_stage crs
			JOIN vocabulary v1 ON v1.vocabulary_id = crs.vocabulary_id_1
			JOIN vocabulary v2 ON v2.vocabulary_id = crs.vocabulary_id_2 WHERE crs.concept_code_2 IS NOT NULL) d )
OR valid_end_date in (SELECT DISTINCT GREATEST(crs.valid_start_date, (
				SELECT MAX(v.latest_update) - 1
				FROM vocabulary v
				WHERE v.vocabulary_id IN (
						crs.vocabulary_id_1,
						crs.vocabulary_id_2
					)
			)) FROM dev_icd10cm.concept_relationship_stage crs);

;

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

--check all the inserted rows
SELECT * FROM icd_cde_source
ORDER BY source_code;

--check all the ICD10 concepts are in the CDE
SELECT *
FROM dev_icd10.concept_stage
WHERE (concept_code, concept_name) not in
(SELECT source_code, source_code_description FROM icd_cde_source
WHERE source_vocabulary_id = 'ICD10')
AND concept_class_id not in ('ICD10 Chapter','ICD10 SubChapter', 'ICD10 Hierarchy');

--check all the ICD10CM concepts are in the CDE
SELECT *
FROM dev_icd10cm.concept_stage
WHERE (concept_code, concept_name) not in
(SELECT source_code, source_code_description FROM icd_cde_source
WHERE source_vocabulary_id = 'ICD10CM');

--Check for null values in source_code, source_code_description, source_vocabulary_id fields
SELECT * FROM icd_cde_source
    WHERE source_code is null
    OR source_code_description is null
    or source_vocabulary_id is null;

--Grouping
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

-- check every concept is represented in only one group
SELECT DISTINCT
source_code,
source_vocabulary_id,
COUNT (DISTINCT group_id)
FROM icd_cde_source
GROUP BY group_id, source_code, source_vocabulary_id
HAVING COUNT (DISTINCT group_id) > 1;

--Table for manual mapping and review creation
DROP TABLE icd_cde_manual;
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
for_review int,
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
relationship_id,
target_concept_id,
target_concept_code,
target_concept_name,
target_concept_class_id,
target_standard_concept,
target_invalid_reason,
target_domain_id,
target_vocabulary_id,
mapper_id)

with code_agg as (SELECT group_id, (array_agg (DISTINCT CONCAT (source_vocabulary_id || ':' || source_code))) as group_code
FROM icd_cde_source
GROUP BY group_id
ORDER BY group_id)
SELECT DISTINCT
s.group_name,
s.group_id,
c.group_code,
s.mappings_origin,
s.relationship_id,
s.target_concept_id,
s.target_concept_code,
s.target_concept_name,
s.target_concept_class_id,
s.target_standard_concept,
s.target_invalid_reason,
s.target_domain_id,
s.target_vocabulary_id,
null as mapper_id
FROM icd_cde_source s
JOIN code_agg c
ON s.group_id = c.group_id
ORDER BY s.group_id desc
;

SELECT * FROM icd_cde_manual LIMIT 1000;
select google_pack.SetSpreadSheet ('icd_cde_manual', '1a3os1cjgIuji7Q4me9DAzt1wb49hew3X4OURLRuyACs','ICD_CDE')



