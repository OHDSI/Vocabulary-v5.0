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
* Authors: Timur Vakhitov, Christian Reich
* Date: 2016
**************************************************************************/

--create temporary table with new replacement relationships
create table rxe_dupl as
select concept_id_1, c1.vocabulary_id as vocabulary_id_1, 'Concept replaced by' as relationship_id, concept_id_2
from (
  select 
    first_value(c.concept_id) over (partition by lower(c.concept_name) order by c.vocabulary_id desc, c.concept_name, c.concept_id) as concept_id_1,
    c.concept_id as concept_id_2, c.vocabulary_id
  from concept c
  join (
    select lower(concept_name) as concept_name, concept_class_id from concept where vocabulary_id like 'RxNorm%' and concept_name not like '%...%' and invalid_reason is null group by lower(concept_name), concept_class_id having count (1) >1
  minus 
    select lower(concept_name), concept_class_id from concept where vocabulary_id='RxNorm' and concept_name not like '%...%' and invalid_reason is null group by lower(concept_name), concept_class_id having count (1) >1
  ) d on lower(c.concept_name)=lower(d.concept_name) 
  and c.vocabulary_id like 'RxNorm%' and c.invalid_reason is null
) c_int
  join concept c1 on c1.concept_id=c_int.concept_id_1 
  join concept c2 on c2.concept_id=c_int.concept_id_2
where concept_id_1!=concept_id_2
and not (c1.vocabulary_id='RxNorm' and c2.vocabulary_id='RxNorm');

--make concepts 'U'
update concept set standard_concept=null, invalid_reason='U', valid_end_date=trunc(sysdate) 
where (concept_id, vocabulary_id) in (select concept_id_1, vocabulary_id_1 from rxe_dupl);

--insert new replacement relationships
insert into concept_relationship
(
    concept_id_1,
    concept_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
)
select concept_id_1, concept_id_2, relationship_id, trunc(sysdate), to_date ('20991231', 'yyyymmdd'), null 
from rxe_dupl;

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

--'Maps to' or 'Mapped from' relationships should not exist where 
-- a) the source concept has standard_concept = 'S', unless it is to self
-- b) the target concept has standard_concept = 'C' or NULL
-- c) the target concept has invalid_reason='D' or 'U'
UPDATE concept_relationship
   SET valid_end_date = trunc(sysdate),
       invalid_reason = 'D'
 WHERE ROWID IN (SELECT r.ROWID
                     FROM concept_relationship r,
                          concept c1,
                          concept c2
                    WHERE     r.concept_id_1 = c1.concept_id
                          AND r.concept_id_2 = c2.concept_id
                          AND (       (c1.standard_concept = 'S'
                                  AND c1.concept_id != c2.concept_id) -- rule a)
                               OR COALESCE (c2.standard_concept, 'X') != 'S' -- rule b)
                               OR c2.invalid_reason IN ('U', 'D') -- rule c)
                              )
                          AND r.relationship_id = 'Maps to'
                          AND r.invalid_reason IS NULL);
commit;

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

commit;

drop table rxe_dupl purge;