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
    source_code_description varchar(255),
    source_vocabulary_id    varchar(20),
    group_name              varchar(255),
    group_id                int,
    --group_code              varchar, -- group code is dynamic and is assembled after grouping just before insertion data into the google sheet
    medium_group_id         integer,
    --medium_group_code       varchar,
    broad_group_id          integer,
    --broad_group_code        varchar,
    relationship_id         varchar(20),
    target_concept_id       integer,
    target_concept_code     varchar(50),
    target_concept_name     varchar(255),
    target_concept_class_id varchar(20),
    target_standard_concept varchar(1),
    target_invalid_reason   varchar(1),
    target_domain_id        varchar(20),
    target_vocabulary_id    varchar(20),
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
and crs.concept_code_2 IS NOT NULL

--UNION
--
----to insert additional mappings from base_concept_relationship_manual
--SELECT cs.concept_code     as source_code,
--       cs.concept_name     as source_code_description,
--       'ICD10'             as source_vocabulary_id,
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
--FROM dev_icd10.concept_stage cs
--LEFT JOIN devv5.base_concept_relationship_manual crm
--    on cs.concept_code = crm.concept_code_1
--    and crm.relationship_id in ('Maps to', 'Maps to value')
--    and crm.vocabulary_id_1 = 'ICD10'
--LEFT JOIN concept c
--    on crm.concept_code_2 = c.concept_code
--    and crm.vocabulary_id_2 = c.vocabulary_id
--WHERE cs.concept_class_id not in ('ICD10 Chapter','ICD10 SubChapter', 'ICD10 Hierarchy')
--AND (crm.concept_code_1, crm.concept_code_2) NOT IN (SELECT concept_code_1, concept_code_2 FROM dev_icd10.concept_relationship_stage)
;

--Update 'mappings_origin' flag
UPDATE icd_cde_source SET
mappings_origin = 'functions_updated'
WHERE valid_start_date = (SELECT DISTINCT GREATEST (d.lu_1, d.lu_2)
FROM (SELECT v1.latest_update AS lu_1, v2.latest_update AS lu_2
			FROM dev_icd10.concept_relationship_stage crs
			JOIN dev_icd10.vocabulary v1 ON v1.vocabulary_id = crs.vocabulary_id_1
			JOIN dev_icd10.vocabulary v2 ON v2.vocabulary_id = crs.vocabulary_id_2) d)
   OR valid_end_date = (SELECT valid_end_date FROM dev_icd10.concept_relationship_stage crs
               WHERE valid_end_date = GREATEST(crs.valid_start_date, (
				SELECT MAX(v.latest_update) - 1
				FROM dev_icd10.vocabulary v
				WHERE v.vocabulary_id IN (
						crs.vocabulary_id_1,
						crs.vocabulary_id_2
						)
				)));

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
--Update 'mappings_origin' flag
UPDATE icd_cde_source SET
mappings_origin = 'functions_updated'
WHERE valid_start_date = (SELECT DISTINCT GREATEST (d.lu_1, d.lu_2)
FROM (SELECT v1.latest_update AS lu_1, v2.latest_update AS lu_2
			FROM dev_icd10cm.concept_relationship_stage crs
			JOIN dev_icd10cm.vocabulary v1 ON v1.vocabulary_id = crs.vocabulary_id_1
			JOIN dev_icd10cm.vocabulary v2 ON v2.vocabulary_id = crs.vocabulary_id_2) d)
   OR valid_end_date = (SELECT valid_end_date FROM dev_icd10cm.concept_relationship_stage crs
               WHERE valid_end_date = GREATEST(crs.valid_start_date, (
				SELECT MAX(v.latest_update) - 1
				FROM dev_icd10cm.vocabulary v
				WHERE v.vocabulary_id IN (
						crs.vocabulary_id_1,
						crs.vocabulary_id_2
						)
				)))
AND source_vocabulary_id = 'ICD10CM';

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
mappings_origin
FROM dev_icd10cm.icd10cm_refresh;

SELECT * FROM icd_cde_source;

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
       valid_start_date,
       valid_end_date,
       mappings_origin
FROM icd10gm_refresh;

;

--CIM10 with mappings (only manual mappings are inserted)
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
                            mappings_origin)
-- Check Select before insertion
SELECT cs.concept_code     as source_code,
       cs.concept_name     as source_code_description,
       'CIM10'             as source_vocabulary_id,
       cs.concept_name     as group_name,
       crm.relationship_id as relationship_id,
       c.concept_id        as target_concept_id,
       crm.concept_code_2  as target_concept_code,
       c.concept_name      as target_concept_name,
       c.concept_class_id  as target_concept_class,
       c.standard_concept  as target_standard_concept,
       c.invalid_reason    as target_invalid_reason,
       c.domain_id         as target_domain_id,
       crm.vocabulary_id_2 as target_vocabulary_id,
       'crm' as mappings_origin
FROM dev_cim10.concept_stage cs
LEFT JOIN devv5.base_concept_relationship_manual crm
    on cs.concept_code = crm.concept_code_1
    and crm.relationship_id in ('Maps to', 'Maps to value')
    and crm.vocabulary_id_1 = 'CIM10'
LEFT JOIN concept c
    on crm.concept_code_2 = c.concept_code
    and crm.vocabulary_id_2 = c.vocabulary_id
WHERE crm.concept_code_2 is not null;

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
                            mappings_origin)
-- Check Select before insertion
SELECT cs.concept_code     as source_code,
       cs.concept_name     as source_code_description,
       'ICD10CN'             as source_vocabulary_id,
       cs.concept_name     as group_name,
       crm.relationship_id as relationship_id,
       c.concept_id        as target_concept_id,
       crm.concept_code_2  as target_concept_code,
       c.concept_name      as target_concept_name,
       c.concept_class_id  as target_concept_class,
       c.standard_concept  as target_standard_concept,
       c.invalid_reason    as target_invalid_reason,
       c.domain_id         as target_domain_id,
       crm.vocabulary_id_2 as target_vocabulary_id,
       'crm' as mappings_origin
FROM dev_icd10cn.concept_stage cs
LEFT JOIN devv5.base_concept_relationship_manual crm
    on cs.concept_code = crm.concept_code_1
    and crm.relationship_id in ('Maps to', 'Maps to value')
    and crm.vocabulary_id_1 = 'ICD10CN'
LEFT JOIN concept c
    on crm.concept_code_2 = c.concept_code
    and crm.vocabulary_id_2 = c.vocabulary_id
WHERE crm.concept_code_2 is not null;

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
                            mappings_origin)
-- Check Select before insertion
SELECT cs.concept_code     as source_code,
       cs.concept_name     as source_code_description,
       'KCD7'             as source_vocabulary_id,
       cs.concept_name     as group_name,
       crm.relationship_id as relationship_id,
       c.concept_id        as target_concept_id,
       crm.concept_code_2  as target_concept_code,
       c.concept_name      as target_concept_name,
       c.concept_class_id  as target_concept_class,
       c.standard_concept  as target_standard_concept,
       c.invalid_reason    as target_invalid_reason,
       c.domain_id         as target_domain_id,
       crm.vocabulary_id_2 as target_vocabulary_id,
       'crm' as mappings_origin
FROM dev_kcd7.concept_stage cs
LEFT JOIN devv5.base_concept_relationship_manual crm
    on cs.concept_code = crm.concept_code_1
    and crm.relationship_id in ('Maps to', 'Maps to value')
    and crm.vocabulary_id_1 = 'KCD7'
LEFT JOIN concept c
    on crm.concept_code_2 = c.concept_code
    and crm.vocabulary_id_2 = c.vocabulary_id
WHERE crm.concept_code_2 is not null;

--check all the inserted rows --157702
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



-- Review all source_codes with mappings, including potential replacement mappings
SELECT * FROM icd_cde_source
ORDER BY source_code;

-- Assign the unique group_id to unique source concept
DROP TABLE cde_source_concepts;
CREATE TABLE cde_source_concepts (
    source_code TEXT NOT NULL,
	source_code_description TEXT,
	source_vocabulary_id TEXT NOT NULL,
	group_id SERIAL,
	group_name TEXT NOT NULL);

INSERT INTO cde_source_concepts (source_code,
                                 source_code_description,
                                 source_vocabulary_id,
                                 group_name)
SELECT DISTINCT source_code,
                source_code_description,
                source_vocabulary_id,
                group_name FROM icd_cde_source;

--UPDATE group_id in the initial source table
UPDATE icd_cde_source s SET group_id =
    (SELECT m.group_id FROM cde_source_concepts m WHERE m.source_code = s.source_code
                                                 AND m.source_code_description = s.source_code_description
                                                 AND m.source_vocabulary_id = s.source_vocabulary_id);

SELECT * FROM icd_cde_source_backup_local_ver;

--GROUPING CRITERIUM 1: (same codes with identical mappings)
DROP TABLE grouped1;
CREATE TABLE grouped1 as (
SELECT DISTINCT
       c1.source_code as source_code,
       c1.source_code_description as source_code_description,
       c1.source_vocabulary_id as source_vocabulary_id,
       c.source_code as source_code_1,
       c.source_code_description as source_code_description_1,
       c.source_vocabulary_id as source_vocabulary_id_1
    FROM dev_icd10.icd_cde_source c
    JOIN dev_icd10.icd_cde_source c1
    ON c.source_code = c1.source_code
    and c.source_vocabulary_id != c1.source_vocabulary_id
    and c.source_code_description != c1.source_code_description
    and c.target_concept_id = c1.target_concept_id
    and c1.source_vocabulary_id = 'ICD10');

--Temporary table for grouping
DROP TABLE IF EXISTS cde_manual_group1;
CREATE TABLE cde_manual_group1 (
	source_code TEXT NOT NULL,
	source_code_description TEXT,
	source_vocabulary_id TEXT NOT NULL,
	group_id int,
	group_name TEXT NOT NULL,
	target_concept_id INT4
);

CREATE UNIQUE INDEX idx_pk_cde_manual_group1 ON cde_manual_group1 ((source_code || ':' || source_vocabulary_id));
CREATE INDEX idx_cde_manual_group_gid_1 ON cde_manual_group1 (group_id);

INSERT INTO cde_manual_group1 (source_code, source_code_description, source_vocabulary_id, group_name)
SELECT DISTINCT source_code,
                source_code_description,
                source_vocabulary_id,
                source_code_description
    FROM grouped1;

INSERT INTO cde_manual_group1 (source_code, source_code_description, source_vocabulary_id, group_name)
SELECT DISTINCT source_code_1,
                source_code_description_1,
                source_vocabulary_id_1,
                source_code_description_1
    FROM grouped1
WHERE (source_code_1, source_vocabulary_id_1) NOT IN (SELECT source_code, source_vocabulary_id FROM cde_manual_group1)
;

--generate unique group_id
DROP SEQUENCE cde_group_id_1;
CREATE SEQUENCE cde_group_id_1 START 114886;
UPDATE cde_manual_group1
SET group_id = nextval('cde_group_id_1')
WHERE group_id IS NULL;

--group the concepts
DO $$
DECLARE
r RECORD;
BEGIN
FOR r IN SELECT DISTINCT source_code, source_vocabulary_id, source_code_1, source_vocabulary_id_1 FROM grouped1  LOOP
PERFORM cde_groups.MergeSeparateConcepts('cde_manual_group1', ARRAY[concat(r.source_code, ':', r.source_vocabulary_id), concat(r.source_code_1, ':', r.source_vocabulary_id_1)]);
END LOOP;
END $$;

-- Update group_id in the original source table
UPDATE icd_cde_source s SET group_id =
    (SELECT m.group_id FROM cde_manual_group1 m WHERE m.source_code = s.source_code
                                                 AND m.source_code_description = s.source_code_description
                                                 AND m.source_vocabulary_id = s.source_vocabulary_id)
WHERE source_code in (SELECT source_code FROM cde_manual_group1)
  and source_code_description in (SELECT source_code_description FROM cde_manual_group1)
AND source_vocabulary_id in (SELECT source_vocabulary_id FROM cde_manual_group1);

-- Check if the concepts from one group in temporary table have the same group in source table
with temporary_group_code as
    (SELECT group_id, (array_agg (DISTINCT CONCAT (source_vocabulary_id || ':' || source_code) ORDER BY (CONCAT (source_vocabulary_id || ':' || source_code)))) as group_code
FROM cde_manual_group1
GROUP BY group_id
ORDER BY group_id),
     source_group_code as
         (SELECT group_id, (array_agg (DISTINCT CONCAT (source_vocabulary_id || ':' || source_code) ORDER BY (CONCAT (source_vocabulary_id || ':' || source_code)))) as group_code
FROM icd_cde_source
GROUP BY group_id
ORDER BY group_id)
SELECT * FROM source_group_code s
JOIN temporary_group_code t ON s.group_id = t.group_id
WHERE s.group_code != t.group_code;

--GROUPING CRITERIUM 2: identical source_code_description
DROP TABLE grouped2;
CREATE TABLE grouped2 as (
SELECT DISTINCT
       c.source_code as source_code,
       c.source_code_description as source_code_description,
       c.source_vocabulary_id as source_vocabulary_id,
       --c.group_id,
       c1.source_code as source_code_1,
       c1.source_code_description as source_code_description_1,
       c1.source_vocabulary_id as source_vocabulary_id_1
FROM icd_cde_source c
    JOIN dev_icd10.icd_cde_source c1
    ON c.source_code_description = c1.source_code_description
    and c1.source_vocabulary_id = 'ICD10'
    and (c.source_code, c.source_vocabulary_id) != (c1.source_code, c1.source_vocabulary_id))

--Remove "cross-links"
--! These records should be processed very accurately
--Only one entry per entity is allowed
DROP TABLE IF EXISTS excluded_records;
CREATE TABLE excluded_records AS
SELECT * FROM grouped2 g
    WHERE exists(
        select 1 from grouped2 g1
                 where (g1.source_code_1, g1.source_vocabulary_id_1) = (g.source_code, g.source_vocabulary_id)
                 and (g1.source_code, g1.source_vocabulary_id) = (g1.source_code, g1.source_vocabulary_id)
    );

DELETE FROM grouped2 g
    WHERE exists(
        SELECT 1 FROM grouped2 g1
                 WHERE (g1.source_code_1, g1.source_vocabulary_id_1) = (g.source_code, g.source_vocabulary_id)
                 AND (g1.source_code, g1.source_vocabulary_id) = (g1.source_code, g1.source_vocabulary_id)
    );

DROP TABLE IF EXISTS cde_manual_group2;
CREATE TABLE cde_manual_group2 (
	source_code TEXT NOT NULL,
	source_code_description TEXT,
	source_vocabulary_id TEXT NOT NULL,
	group_id int,
	group_name TEXT NOT NULL
	);

CREATE UNIQUE INDEX idx_pk_cde_manual_group ON cde_manual_group2 ((source_code || ':' || source_vocabulary_id));
CREATE INDEX idx_cde_manual_group_gid2 ON cde_manual_group2 (group_id);

INSERT INTO cde_manual_group2 (source_code, source_code_description, source_vocabulary_id, group_name)
SELECT DISTINCT g2.source_code,
                g2.source_code_description,
                g2.source_vocabulary_id,
                --s.group_id,
                g2.source_code_description
    FROM grouped2 g2;
    --JOIN icd_cde_source s
    --ON g2.source_code = s.source_code
    --AND g2.source_vocabulary_id = s.source_vocabulary_id;

INSERT INTO cde_manual_group2 (source_code, source_code_description, source_vocabulary_id, group_name)
SELECT DISTINCT g2.source_code_1,
                g2.source_code_description_1,
                g2.source_vocabulary_id_1,
                --s.group_id,
                g2.source_code_description_1
    FROM grouped2 g2
    --JOIN icd_cde_source s
    --ON g2.source_code_1 = s.source_code
    --AND g2.source_vocabulary_id_1 = s.source_vocabulary_id
 WHERE (source_code_1, source_vocabulary_id_1) NOT IN (SELECT source_code, source_vocabulary_id FROM cde_manual_group2)
;
--generate unique group_id
DROP SEQUENCE cde_group_id_2;
CREATE SEQUENCE cde_group_id_2 START 1900000;
UPDATE cde_manual_group2
SET group_id = nextval('cde_group_id_2')
WHERE group_id IS NULL;

--DO $$
--DECLARE
--r RECORD;
--BEGIN
--FOR r IN SELECT DISTINCT group_id, source_code_1, source_vocabulary_id_1 FROM grouped2  LOOP
--PERFORM cde_groups.MergeGroupsByConcept('cde_manual_group2', r.group_id::int, ARRAY [concat(r.source_code_1, ':', r.source_vocabulary_id_1)]);
--END LOOP;
--END $$;

--group the concepts
DO $$
DECLARE
r RECORD;
BEGIN
FOR r IN SELECT DISTINCT source_code, source_vocabulary_id, source_code_1, source_vocabulary_id_1 FROM grouped2  LOOP
PERFORM cde_groups.MergeSeparateConcepts('cde_manual_group2', ARRAY[concat(r.source_code, ':', r.source_vocabulary_id), concat(r.source_code_1, ':', r.source_vocabulary_id_1)]);
END LOOP;
END $$;

-- Update the original source table
UPDATE icd_cde_source s SET group_id =
    (SELECT m.group_id FROM cde_manual_group2 m
    WHERE m.source_code = s.source_code AND m.source_code_description = s.source_code_description AND m.source_vocabulary_id = s.source_vocabulary_id)
WHERE source_code in
      (SELECT source_code FROM cde_manual_group2)
  and source_code_description in (SELECT source_code_description FROM cde_manual_group2);

-- Check if the concepts from one group in temporary table have the same group in source table
with temporary_group_code as
    (SELECT group_id, (array_agg (DISTINCT CONCAT (source_vocabulary_id || ':' || source_code) ORDER BY (CONCAT (source_vocabulary_id || ':' || source_code)))) as group_code
FROM cde_manual_group2
GROUP BY group_id
ORDER BY group_id),
     source_group_code as
         (SELECT group_id, (array_agg (DISTINCT CONCAT (source_vocabulary_id || ':' || source_code) ORDER BY (CONCAT (source_vocabulary_id || ':' || source_code)))) as group_code
FROM icd_cde_source
GROUP BY group_id
ORDER BY group_id)
SELECT * FROM source_group_code s
JOIN temporary_group_code t ON s.group_id = t.group_id
WHERE s.group_code != t.group_code;

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
ORDER BY s.group_id
;

SELECT * FROM icd_cde_manual;
select google_pack.SetSpreadSheet ('icd_cde_manual', '1a3os1cjgIuji7Q4me9DAzt1wb49hew3X4OURLRuyACs','ICD_CDE')



