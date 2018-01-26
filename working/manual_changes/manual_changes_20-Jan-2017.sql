--updeprecate old 'true' 'maps to' mappings

--save mapping's old end date (if relationship was correctly deprecated [defined by generic's rules])
create table tmp_old_dates nologging as
select r.rowid rid, r.valid_end_date From concept c1, concept c2, concept_relationship r
where c1.concept_id=r.concept_id_1
and c2.concept_id=r.concept_id_2
and c1.vocabulary_id<>c2.vocabulary_id
and r.relationship_id='Maps to'
and r.invalid_reason='D'
and c2.invalid_reason='U'
and not exists (
    select 1 from concept_relationship r_int, concept c_int
    where r_int.concept_id_1=c1.concept_id
    and r_int.concept_id_2=c_int.concept_id
    and c_int.vocabulary_id=c2.vocabulary_id
    and r_int.relationship_id='Maps to'
    and r_int.invalid_reason is null
);

--do undeprecation
update concept_relationship set invalid_reason=null, valid_end_date=TO_DATE ('20991231', 'YYYYMMDD')
where rowid in (select rid from tmp_old_dates);

--build new 'Maps to' mappings (or update existing) from deprecated to fresh concept
MERGE INTO concept_relationship r
USING (
    SELECT
      root_concept_id_1, 
      concept_id_2,
      relationship_id,
      valid_start_date,
      valid_end_date,
      invalid_reason
    FROM (
        WITH upgraded_concepts
        AS (
          SELECT DISTINCT
          concept_id_1,
          FIRST_VALUE (concept_id_2) OVER (PARTITION BY concept_id_1 ORDER BY rel_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS concept_id_2
          FROM (
            SELECT r.concept_id_1,
              r.concept_id_2,
              CASE
                WHEN r.relationship_id = 'Concept replaced by' THEN 1
                WHEN r.relationship_id = 'Concept same_as to' THEN 2
                WHEN r.relationship_id = 'Concept alt_to to' THEN 3
                WHEN r.relationship_id = 'Concept poss_eq to' THEN 4
                WHEN r.relationship_id = 'Concept was_a to' THEN 5
                WHEN r.relationship_id = 'Maps to' THEN 6
              END AS rel_id
            FROM concept c1, concept c2, concept_relationship r
            WHERE (
              r.relationship_id IN (
                'Concept replaced by',
                'Concept same_as to',
                'Concept alt_to to',
                'Concept poss_eq to',
                'Concept was_a to'
              )
              OR (
                r.relationship_id = 'Maps to'
                AND c2.invalid_reason = 'U'
              )
            )
            AND r.invalid_reason IS NULL
            AND c1.concept_id = r.concept_id_1
            AND c2.concept_id = r.concept_id_2
            AND (
            (
              (
                (c1.vocabulary_id = c2.vocabulary_id and c1.vocabulary_id not in ('RxNorm','RxNorm Extension') and c2.vocabulary_id not in ('RxNorm','RxNorm Extension')) 
                OR (c1.vocabulary_id in ('RxNorm','RxNorm Extension') and c2.vocabulary_id in ('RxNorm','RxNorm Extension'))
              ) 
              AND r.relationship_id <> 'Maps to'
            ) 
              OR r.relationship_id = 'Maps to'
            )
            AND c2.concept_code <> 'OMOP generated'
            AND r.concept_id_1 <> r.concept_id_2
          )
        )
        SELECT 
          CONNECT_BY_ROOT concept_id_1 AS root_concept_id_1, u.concept_id_2,
          'Maps to' AS relationship_id,
          TO_DATE ('19700101', 'YYYYMMDD') AS valid_start_date,
          TO_DATE ('20991231', 'YYYYMMDD') AS valid_end_date,
          NULL AS invalid_reason
        FROM upgraded_concepts u
        WHERE CONNECT_BY_ISLEAF = 1
        CONNECT BY NOCYCLE PRIOR concept_id_2 = concept_id_1
    )
	--rule b) from generic_udpate
    WHERE NOT EXISTS (
        SELECT 1 FROM concept c_int
        WHERE c_int.concept_id=concept_id_2
        AND COALESCE(c_int.standard_concept,'C')='C'
    )    
) i ON ( r.concept_id_1 = i.root_concept_id_1
  AND r.concept_id_2 = i.concept_id_2
  AND r.relationship_id = i.relationship_id)
WHEN NOT MATCHED THEN
INSERT (
  concept_id_1,
  concept_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
VALUES (
  i.root_concept_id_1,
  i.concept_id_2,
  i.relationship_id,
  i.valid_start_date,
  i.valid_end_date,
  i.invalid_reason
)
WHEN MATCHED
THEN
UPDATE SET r.invalid_reason = NULL, r.valid_end_date = i.valid_end_date
WHERE r.invalid_reason IS NOT NULL;

-- 'Maps to' or 'Mapped from' relationships should not exist where
-- a) the source concept has standard_concept = 'S', unless it is to self
-- b) the target concept has standard_concept = 'C' or NULL

UPDATE concept_relationship d
SET d.valid_end_date = trunc(sysdate),
d.invalid_reason = 'D'
WHERE d.ROWID IN (
  SELECT r.ROWID FROM concept_relationship r, concept c1, concept c2 WHERE
  r.concept_id_1 = c1.concept_id
  AND r.concept_id_2 = c2.concept_id
  AND (
  -- rule a)
    (c1.standard_concept = 'S' AND c1.concept_id != c2.concept_id)
  -- rule b)
    OR COALESCE (c2.standard_concept, 'X') != 'S'
  )
  AND r.relationship_id = 'Maps to'
  AND r.invalid_reason IS NULL
);

--deprecate replacement records if target concept was deprecated
MERGE INTO concept_relationship r
USING (
  WITH upgraded_concepts AS (
    SELECT r.concept_id_1,
    r.concept_id_2,
    r.relationship_id,
    c2.invalid_reason
    FROM concept c1, concept c2, concept_relationship r
    WHERE r.relationship_id IN (
      'Concept replaced by',
      'Concept same_as to',
      'Concept alt_to to',
      'Concept poss_eq to',
      'Concept was_a to'
    )
    AND r.invalid_reason IS NULL
    AND c1.concept_id = r.concept_id_1
    AND c2.concept_id = r.concept_id_2
    AND c1.vocabulary_id = c2.vocabulary_id
    AND c2.concept_code <> 'OMOP generated'
    AND r.concept_id_1 <> r.concept_id_2
  )
  SELECT u.concept_id_1, u.concept_id_2, u.relationship_id
  FROM upgraded_concepts u
  CONNECT BY NOCYCLE PRIOR concept_id_1 = concept_id_2
  START WITH concept_id_2 IN (
    SELECT concept_id_2
    FROM upgraded_concepts
    WHERE invalid_reason = 'D'
  )
) i
ON (r.concept_id_1 = i.concept_id_1 AND r.concept_id_2 = i.concept_id_2 AND r.relationship_id = i.relationship_id)
WHEN MATCHED
THEN
UPDATE SET r.invalid_reason = 'D', r.valid_end_date = TRUNC (SYSDATE);

--deprecate concepts if we have no active replacement record in the concept_relationship
UPDATE concept c SET
c.valid_end_date = TRUNC (SYSDATE),
c.invalid_reason = 'D',
c.standard_concept = NULL
WHERE
NOT EXISTS (
  SELECT 1
  FROM concept_relationship r
  WHERE r.concept_id_1 = c.concept_id
  AND r.invalid_reason IS NULL
  AND r.relationship_id in (
    'Concept replaced by',
    'Concept same_as to',
    'Concept alt_to to',
    'Concept poss_eq to',
    'Concept was_a to'
  )
)
AND c.invalid_reason = 'U' ;

--deprecate 'Maps to' mappings to deprecated and upgraded concepts
UPDATE concept_relationship r
SET r.valid_end_date = TRUNC (SYSDATE), r.invalid_reason = 'D'
WHERE r.relationship_id = 'Maps to'
AND r.invalid_reason IS NULL
AND EXISTS (
  SELECT 1
  FROM concept c
  WHERE c.concept_id = r.concept_id_2 AND c.invalid_reason IN ('U', 'D')
);

--return proper date for correctly deprecated mappings
merge into concept_relationship r
using (
    select * from tmp_old_dates
) i
on (r.rowid=i.rid and r.invalid_reason='D')
when matched then update set r.valid_end_date=i.valid_end_date where r.valid_end_date<>i.valid_end_date;

--reverse (reversing new mappings and deprecate existings)
MERGE INTO concept_relationship r
USING (
  SELECT r.*, rel.reverse_relationship_id
  FROM concept_relationship r, relationship rel
  WHERE r.relationship_id IN (
    'Concept replaced by',
    'Concept same_as to',
    'Concept alt_to to',
    'Concept poss_eq to',
    'Concept was_a to',
    'Maps to'
  )
  AND r.relationship_id = rel.relationship_id
) i
ON (r.concept_id_1 = i.concept_id_2 AND r.concept_id_2 = i.concept_id_1 AND r.relationship_id = i.reverse_relationship_id)
WHEN NOT MATCHED
THEN
INSERT (
  concept_id_1,
  concept_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason)
VALUES (
  i.concept_id_2,
  i.concept_id_1,
  i.reverse_relationship_id,
  i.valid_start_date,
  i.valid_end_date,
  i.invalid_reason
)
WHEN MATCHED
THEN
UPDATE SET r.invalid_reason = i.invalid_reason, r.valid_end_date = i.valid_end_date
WHERE (NVL (r.invalid_reason, 'X') <> NVL (i.invalid_reason, 'X') OR r.valid_end_date <> i.valid_end_date);

--clean up
drop table tmp_old_dates purge;