-- Create table icd10_refresh
DROP TABLE icd9cm_refresh;
TRUNCATE TABLE icd9cm_refresh;
CREATE TABLE icd9cm_refresh
(
    source_code             TEXT NOT NULL,
    source_code_description varchar(255),
    source_vocabulary_id    varchar(20),
    relationship_id         varchar(20),
    target_concept_id       int,
    target_concept_code     varchar(50),
    target_concept_name     varchar(255),
    target_concept_class_id varchar(20),
    target_standard_concept varchar(1),
    target_invalid_reason   varchar(1),
    target_domain_id        varchar(20),
    target_vocabulary_id    varchar(20),
    rel_invalid_reason      varchar(1),
    valid_start_date        date,
    valid_end_date          date,
    mappings_origin         varchar
);

--Insert other potential replacement mappings
INSERT INTO icd9cm_refresh
    (source_code,
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
     rel_invalid_reason,
     valid_start_date,
     valid_end_date,
     mappings_origin)
(with mis_map as
(SELECT
cs.concept_code as source_code,
cs.concept_name as source_code_description,
cs.vocabulary_id as source_vocabulary_id,
crs.relationship_id as relationship_id,
crs.invalid_reason as rel_invalid_reason,
crs.valid_start_date as valid_start_date,
crs.valid_end_date as valid_end_date,
c.concept_id as target_concept_id
FROM concept_relationship_stage crs
LEFT JOIN concept c
ON crs.concept_code_2 = c.concept_code
and c.vocabulary_id = 'SNOMED'
JOIN concept_stage cs ON crs.concept_code_1 = cs.concept_code
WHERE relationship_id = 'Maps to'
     AND crs.invalid_reason in ('D', 'U')
AND concept_code_1 NOT IN
(SELECT concept_code_1 FROM concept_relationship_stage
    WHERE relationship_id = 'Maps to'
     AND invalid_reason is null)
    )
       SELECT DISTINCT m.source_code,
              m.source_code_description,
              m.source_vocabulary_id,
              m.relationship_id,
              c.concept_id as target_concept_id,
              c.concept_code as target_concept_code,
              c.concept_name as target_concept_name,
              c.concept_class_id as target_concept_class_id,
              c.standard_concept as target_standard_concept,
              c.invalid_reason as target_invalid_reason,
              c.domain_id as target_domain_id,
              c.vocabulary_id as target_vocabulary_id,
              m.rel_invalid_reason as rel_invalid_reason,
              m.valid_start_date as valid_start_date,
              m.valid_end_date as valid_end_date,
              'Concept poss_eq to' as mapping_origin
       FROM mis_map m JOIN concept_relationship cr
       ON m.target_concept_id = cr.concept_id_1
       JOIN concept c
       ON cr.concept_id_2 = c.concept_id
       AND cr.relationship_id in ('Concept poss_eq to')
       AND c.standard_concept = 'S'
       AND c.invalid_reason is null);

--Insert concepts without mapping
INSERT INTO icd9cm_refresh
    (source_code,
     source_code_description,
     source_vocabulary_id,
     target_concept_id,
     mappings_origin)
SELECT cs.concept_code as source_code,
       cs.concept_name as source_code_description,
       cs.vocabulary_id as source_vocabulary_id,
       NULL as target_concept_id,
       'without mapping' as mapping_origin
FROM concept_stage cs LEFT JOIN concept_relationship_stage crs on cs.concept_code = crs.concept_code_1
and crs.relationship_id in ('Maps to', 'Maps to value')
WHERE crs.concept_code_2 is null
and cs.invalid_reason is null
and cs.concept_class_id NOT IN ('ICD10 Chapter','ICD10 SubChapter', 'ICD10 Hierarchy');

























--previous scripts
DROP TABLE IF EXISTS refresh_lookup;
CREATE TABLE refresh_lookup AS WITH miss_map
AS
(
	-- 'deprecated mapping'
	SELECT c.concept_code AS icd_code,
       c.concept_name AS icd_name,
       a.relationship_id AS current_relationship,
       b.concept_id AS current_id,
       b.concept_code AS current_code,
       b.concept_name AS current_name,
       b.domain_id AS current_domain,
       b.vocabulary_id AS current_vocabulary,
       'deprecated mapping' AS reason
FROM concept_relationship_stage a
  JOIN concept b
    ON a.concept_code_2 = b.concept_code
   AND b.vocabulary_id = a.vocabulary_id_2
   AND a.relationship_id IN ('Maps to', 'Maps to value')
   AND b.invalid_reason IN ('D', 'U')
  JOIN concept_stage c
    ON a.concept_code_1 = c.concept_code
    AND c.concept_class_id NOT IN ('ICD10 Chapter','ICD10 SubChapter')
AND a.invalid_reason IS NULL
UNION
-- 'non-standard mapping'
SELECT c.concept_code,
       c.concept_name,
       a.relationship_id AS current_relationship,
       b.concept_id AS current_id,
       b.concept_code AS current_code,
       b.concept_name AS current_name,
       b.domain_id AS current_domain,
       b.vocabulary_id AS current_vocabulary,
       'non-standard mapping' AS reason
FROM concept_relationship_stage a
  JOIN concept b
    ON a.concept_code_2 = b.concept_code
   AND b.vocabulary_id = a.vocabulary_id_2
   AND a.relationship_id IN ('Maps to', 'Maps to value')
   AND b.invalid_reason IS NULL
   AND b.standard_concept IS NULL
  JOIN concept_stage c
    ON a.concept_code_1 = c.concept_code
    AND c.concept_class_id NOT IN ('ICD10 Chapter','ICD10 SubChapter')
	AND a.invalid_reason is null
UNION
-- 'without mapping'
SELECT a.concept_code,
       a.concept_name,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       'without mapping' AS reason
FROM concept_stage a
  LEFT JOIN concept_relationship_stage r
         ON a.concept_code = concept_code_1
        AND r.relationship_id IN ('Maps to')
        AND r.invalid_reason IS NULL
  LEFT JOIN concept b
         ON b.concept_code = concept_code_2
        AND b.vocabulary_id = vocabulary_id_2
WHERE a.vocabulary_id = 'ICD10'
AND   a.invalid_reason IS NULL
AND   b.concept_id IS NULL
AND a.concept_class_id NOT IN ('ICD10 Chapter','ICD10 SubChapter')),
--brothers of depracted concepts: for cases when source concept has 1-to-many mapping and one of the target concepts is dead, we should see all other target concepts to create an accurate mapping
miss_map_brother AS ( SELECT
       a.icd_code,
       a.icd_name,
       c.relationship_id,
       b.concept_id AS current_id,
       b.concept_code AS current_code,
       b.concept_name AS current_name,
       b.domain_id AS current_domain,
       b.vocabulary_id AS current_vocabulary,
       b.concept_id,
       b.concept_code,
        b.concept_name,
       b.domain_id,
       b.vocabulary_id,
       'brother of deprecated mapping' AS reason
FROM miss_map a
JOIN concept_relationship_stage c ON c.concept_code_1 = a.icd_code
JOIN concept b
    ON c.concept_code_2 = b.concept_code
   AND b.vocabulary_id = c.vocabulary_id_2
   AND c.relationship_id IN ('Maps to', 'Maps to value')
   AND b.invalid_reason IS NULL),
-- concepts which mapping can be replaced through 'Maps to' relationship
t1 AS (SELECT d.concept_code AS icd_code,
              d.concept_name AS icd_name,
              d.domain_id AS icd_domain,
              j.concept_id AS repl_by_id,
              j.concept_code AS repl_by_code,
              j.concept_name AS repl_by_name,
              j.domain_id AS repl_by_domain,
              j.vocabulary_id AS repl_by_vocabulary,
              NULL
       FROM concept_relationship_stage a
         JOIN concept b
           ON a.concept_code_2 = b.concept_code
          AND b.vocabulary_id = a.vocabulary_id_2
          AND a.relationship_id = 'Maps to'
          AND b.invalid_reason IN ('D', 'U')
          JOIN concept_stage d
    ON a.concept_code_1 = d.concept_code
         JOIN concept_relationship r2 ON b.concept_id = r2.concept_id_1
         JOIN concept j
           ON j.concept_id = r2.concept_id_2
          AND j.vocabulary_id = 'SNOMED'-- place for target vocabulary
          AND j.standard_concept = 'S'
          AND r2.relationship_id = 'Maps to'
       WHERE a.concept_code_1 IN (SELECT icd_code FROM miss_map)),
-- concepts which mapping can be replaced through 'Concept replaces' relationship
t2 AS (SELECT d.concept_code AS icd_code,
              d.concept_name AS icd_name,
              d.domain_id AS icd_domain,
              j.concept_id AS repl_by_id,
              j.concept_code AS repl_by_code,
              j.concept_name AS repl_by_name,
              j.domain_id AS repl_by_domain,
              j.vocabulary_id AS repl_by_vocabulary,
              NULL
       FROM concept_relationship_stage a
         JOIN concept b
           ON a.concept_code_2 = b.concept_code
          AND b.vocabulary_id = a.vocabulary_id_2
          AND a.relationship_id = 'Maps to'
          AND b.invalid_reason IN ('D', 'U')
        JOIN concept_stage d
    ON a.concept_code_1 = d.concept_code
         JOIN concept_relationship r2 ON b.concept_id = r2.concept_id_1
         JOIN concept j
           ON j.concept_id = r2.concept_id_2
          AND j.vocabulary_id = 'SNOMED' -- place for target vocabulary
          AND j.standard_concept = 'S'
          AND r2.relationship_id = 'Concept replaced by'
       WHERE a.concept_code_1 IN (SELECT icd_code FROM miss_map)),
-- all concepts which can be remapped autimatically (however, should be reviewed)
t3 AS (SELECT * FROM t1 UNION SELECT * FROM t2),
-- look-up table with all concepts with deprecated mapping + automatically remapped
t4 AS (SELECT miss_map.icd_code,
              miss_map.icd_name,
              miss_map.current_relationship,
              miss_map.current_id,
              miss_map.current_code,
              miss_map.current_name,
              miss_map.current_domain,
              miss_map.current_vocabulary,
              t3.repl_by_id,
              t3.repl_by_code,
              t3.repl_by_name,
              t3.repl_by_domain,
              t3.repl_by_vocabulary,
              miss_map.reason
       FROM miss_map
         LEFT JOIN t3 ON miss_map.icd_code = t3.icd_code
      UNION
         SELECT * FROM miss_map_brother),
-- improve_map - automatically detected mapping improvements. Look carefully! Target vocabulary could have the same names of concepts with different domain_ids. Also, ICD10 chapter means a lot and should be taken into account for choosing appropriate mapping
improve_map
AS
(SELECT DISTINCT
a.concept_code AS icd_code,
       a.concept_name AS icd_name,
       r.relationship_id AS current_relationship,
       d.concept_id AS current_id,
       d.concept_code AS current_code,
       d.concept_name AS current_name,
       d.domain_id AS current_domain,
       d.vocabulary_id AS current_vocabulary,
       c.concept_id AS repl_by_id,
       code AS repl_by_code,
       str AS repl_by_name,
       c.domain_id AS repl_by_domain,
       c.vocabulary_id AS repl_by_vocabulary,
       'improve_map' AS reason
FROM concept a
JOIN concept_relationship r ON r.concept_id_1 = a.concept_id AND a.vocabulary_id = 'ICD10'
JOIN concept d ON d.concept_id = r.concept_id_2 AND r.invalid_reason IS NULL AND d.standard_concept = 'S' AND r.relationship_id IN ('Maps to', 'Maps to value')
  JOIN sources.mrconso
    ON lower (a.concept_name) = lower (str)
   AND sab = 'SNOMEDCT_US'
   AND suppress = 'N'
   AND tty = 'PT'
  JOIN concept c
    ON c.concept_code = code
   AND c.vocabulary_id = 'SNOMED'
   AND c.standard_concept = 'S'
   AND c.concept_class_id IN ('Procedure', 'Context-dependent', 'Clinical Finding', 'Event', 'Social Context', 'Observable Entity')),
t5 as (
SELECT  * FROM improve_map
WHERE icd_code IN (SELECT icd_code
                   FROM improve_map
                   WHERE repl_by_code != current_code)
AND icd_code NOT IN (SELECT icd_code FROM improve_map WHERE icd_name ~ '\s+and\s+' GROUP BY icd_code HAVING COUNT(icd_code)=1)
                   ),
t6 AS (
SELECT DISTINCT
a.concept_code AS icd_code,
       a.concept_name AS icd_name,
       r.relationship_id AS current_relationship,
       d.concept_id AS current_id,
       d.concept_code AS current_code,
       d.concept_name AS current_name,
       d.domain_id AS current_domain,
       d.vocabulary_id AS current_vocabulary,
       c.concept_id AS repl_by_id,
       c.concept_code AS repl_by_code,
       c.concept_name AS repl_by_name,
       c.domain_id AS repl_by_domain,
       c.vocabulary_id AS repl_by_vocabulary,
       'improve_map' AS reason
FROM concept a
JOIN concept_relationship r ON r.concept_id_1 = a.concept_id and a.vocabulary_id = 'ICD10'
JOIN concept d ON d.concept_id = r.concept_id_2 AND r.invalid_reason IS NULL AND d.standard_concept = 'S' AND r.relationship_id IN ('Maps to', 'Maps to value')
  JOIN concept_synonym cs ON lower (a.concept_name) = lower (cs.concept_synonym_name) AND a.vocabulary_id = 'ICD10'
  JOIN concept c
    ON cs.concept_id = c.concept_id
   AND c.vocabulary_id = 'SNOMED'
   AND c.standard_concept = 'S'
   AND c.concept_class_id IN ('Procedure', 'Context-dependent', 'Clinical Finding', 'Event', 'Social Context', 'Observable Entity')
AND c.concept_id NOT IN (SELECT descendant_concept_id FROM devv5.concept_ancestor WHERE ancestor_concept_id = 40485423 )), -- concept Unilateral clinical finding has weak hierarchy
p_map AS (
    SELECT * FROM t5
  UNION
--exclude the cases 1 to 1 mapping with the current_id = repl_by_id, if there's multiple mapping and current_id = repl_by_id, the additional mapping serves as a hiearchy connector, so these are included into the comparison
    SELECT * FROM t6 WHERE icd_code NOT IN (SELECT icd_code FROM (
SELECT *, COUNT(1) over (partition BY icd_code) AS cnt FROM t6) a WHERE a.cnt =1 AND current_id = repl_by_id))
SELECT * FROM p_map
UNION
SELECT * FROM t4
ORDER BY icd_code;

SELECT * FROM refresh_lookup;