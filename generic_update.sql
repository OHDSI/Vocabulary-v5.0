-- 1. Update existing concept details from concept_stage. This is different for different vocabularies.
-- It assumes that if no new detail is available the corresponding fields are null.
-- Only the firelds concept_name, domain_id, concept_class_id, standard_concept and valid_end_date are updated.
-- valid_start_date is set to the release date of the last update and should not overwrite the existing one
-- if the valid_start_date needs be updated, a separate script should be run
UPDATE concept c
SET (concept_name, domain_id,concept_class_id,standard_concept,valid_end_date) = (
  SELECT 
    coalesce(cs.concept_name, c.concept_name),
    coalesce(cs.domain_id, c.domain_id),
    coalesce(cs.concept_class_id, c.concept_class_id),
    coalesce(cs.standard_concept, c.standard_concept), 
    coalesce(cs.valid_end_date, c.valid_end_date)
  FROM concept_stage cs
  WHERE c.concept_id=cs.concept_id
)
where c.concept_id in (select concept_id from concept_stage)
-- The following contains the vocabularies or vocab subsets for which this functionality is desired
and case
  when c.vocabulary_id = 'SNOMED' then 1
  when c.vocabulary_id = 'LOINC' and c.concept_class_id='LOINC Answers' then 1 -- LOINC answers are not full, but incremental
  when c.vocabulary_id = 'LOINC' then 0
  else 0
end = 1
;

COMMIT;

-- 2. Deprecate concepts missing from concept_stage. This is only for full updates without explicit deprecations.
update concept c set
c.valid_end_date = (select latest_update-1 from vocabulary where vocabulary_id=c.vocabulary_id)
where not exists (select 1 from concept_stage cs where cs.concept_id=c.concept_id and cs.vocabulary_id=c.vocabulary_id)
and c.vocabulary_id in (select vocabulary_id from vocabulary where latest_update is not null)
and case
  when c.vocabulary_id = 'SNOMED' then 1
  when c.vocabulary_id = 'LOINC' and c.concept_class_id='LOINC Answers' then 1 -- LOINC answers are not full, but incremental
  when c.vocabulary_id = 'LOINC' then 0
  else 0
end = 1
;

COMMIT;

-- 3. add new concepts from concept_stage
DROP INDEX idx_concept_code;

INSERT INTO concept (concept_id,
                     concept_name,
                     domain_id,
                     vocabulary_id,
                     concept_class_id,
                     standard_concept,
                     concept_code,
                     valid_start_date,
                     valid_end_date,
                     invalid_reason)
   SELECT v5_concept.NEXTVAL,
          cs.concept_name,
          cs.domain_id,
          cs.vocabulary_id,
          cs.concept_class_id,
          cs.standard_concept,
          cs.concept_code,
          COALESCE (cs.valid_start_date, TO_DATE ('01.01.1970', 'dd.mm.yyyy')),
          COALESCE (cs.valid_end_date, TO_DATE ('31.12.2099', 'dd.mm.yyyy')),
          NULL
     FROM concept_stage cs
    WHERE cs.concept_id IS NULL;

CREATE INDEX idx_concept_code ON concept (concept_code ASC);

COMMIT;

-- 4. Update all relationships existing in concept_relationship_stage, including undeprecation of formerly deprecated ones

UPDATE concept_relationship d
   SET (d.valid_end_date, d.invalid_reason) =
          (SELECT distinct crs.valid_end_date, crs.invalid_reason
             FROM concept_relationship_stage crs
             JOIN concept c1 on c1.concept_code = crs.concept_code_1 and c1.vocabulary_id = crs.vocabulary_id_1
             JOIN concept c2 on c2.concept_code = crs.concept_code_2 and c2.vocabulary_id = crs.vocabulary_id_2
            WHERE     c1.concept_id = d.concept_id_1
                  AND c2.concept_id = d.concept_id_2
                  AND crs.relationship_id = d.relationship_id)
 WHERE EXISTS
          (SELECT 1
             FROM concept_relationship_stage r
             JOIN concept r1 on r1.concept_code = r.concept_code_1 and r1.vocabulary_id = r.vocabulary_id_1
             JOIN concept r2 on r2.concept_code = r.concept_code_2 and r2.vocabulary_id = r.vocabulary_id_2
            -- test whether either the concept_ids match
            WHERE     d.concept_id_1 = r1.concept_id
                  AND d.concept_id_2 = r2.concept_id
                  AND d.relationship_id = r.relationship_id
                  AND d.valid_end_date <> r.valid_end_date);
 
COMMIT; 

-- 5. Deprecate missing relationships, but only if the concepts exist. If relationships are missing because of deprecated concepts, leave them intact.
-- Also, only relationships are considered missing if the combination of vocabulary_id_1, vocabulary_id_2 and relationship_id is present in concept_relationship_stage
CREATE TABLE r_coverage AS
SELECT DISTINCT r1.vocabulary_id||'-'||r2.vocabulary_id||'-'||r.relationship_id as combo
       FROM concept_relationship_stage r
       JOIN concept r1 on r1.concept_code = r.concept_code_1 and r1.vocabulary_id = r.vocabulary_id_1
       JOIN concept r2 on r2.concept_code = r.concept_code_2 and r2.vocabulary_id = r.vocabulary_id_2
       WHERE r.relationship_id NOT IN ('Maps to',
                                       'Mapped from',
                                       'UCUM replaced by',
                                       'UCUM replaces',
                                       'Concept replaced by',
                                       'Concept replaces',
                                       'Concept same_as to',
                                       'Concept same_as from',
                                       'Concept alt_to to',
                                       'Concept alt_to from',
                                       'Concept poss_eq to',
                                       'Concept poss_eq from',
                                       'Concept was_a to',
                                       'Concept was_a from',
                                       'LOINC replaced by',
                                       'LOINC replaces',
                                       'RxNorm replaced by',
                                       'RxNorm replaces',
                                       'SNOMED replaced by',
                                       'SNOMED replaces',
                                       'ICD9P replaced by',
                                       'ICD9P replaces'
                                      )
;

UPDATE concept_relationship d
   SET valid_end_date =
            (SELECT latest_update
               FROM vocabulary v, concept_stage c
              WHERE     v.vocabulary_id = c.vocabulary_id
                    AND c.concept_id = d.concept_id_1)
          - 1,                                       -- day before release day
       invalid_reason = 'D'
 WHERE     NOT EXISTS
              (SELECT 1
                 FROM concept_relationship_stage r
                 JOIN concept r1 on r1.concept_code = r.concept_code_1 and r1.vocabulary_id = r.vocabulary_id_1
                 JOIN concept r2 on r2.concept_code = r.concept_code_2 and r2.vocabulary_id = r.vocabulary_id_2
                -- test whether either the concept_ids match, or the concept_ids matched to the concept_codes in either stage or dev
                WHERE     d.concept_id_1 = r1.concept_id
                      AND d.concept_id_2 = r2.concept_id
                      AND d.relationship_id = r.relationship_id)
       AND d.valid_end_date = TO_DATE ('20991231', 'YYYYMMDD') -- deprecate those that are fresh and active
       AND d.valid_start_date <
                (SELECT latest_update
                   FROM vocabulary v, concept_stage c
                  WHERE     v.vocabulary_id = c.vocabulary_id
                        AND c.concept_id = d.concept_id_1)
              - 1                               -- started before release date
       -- exclude replacing relationships, usually they are not maintained after a concept died
       AND d.relationship_id NOT IN ('UCUM replaced by',
                                     'UCUM replaces',
                                     'Concept replaced by',
                                     'Concept replaces',
                                     'Concept same_as to',
                                     'Concept same_as from',
                                     'Concept alt_to to',
                                     'Concept alt_to from',
                                     'Concept poss_eq to',
                                     'Concept poss_eq from',
                                     'Concept was_a to',
                                     'Concept was_a from',
                                     'LOINC replaced by',
                                     'LOINC replaces',
                                     'RxNorm replaced by',
                                     'RxNorm replaces',
                                     'SNOMED replaced by',
                                     'SNOMED replaces',
                                     'ICD9P replaced by',
                                     'ICD9P replaces') 
       -- check for existence of both concept_id_1 and concept_id_2
       AND d.concept_id_1 in (
                SELECT concept_id FROM concept_stage c
       )
       AND d.concept_id_2 in (
                SELECT concept_id FROM concept_stage c
       )
       -- check the combination of vocab1, vocab2 and relationship_id
       AND EXISTS (
              SELECT 1
                  FROM concept e1, concept e2
                WHERE  e1.concept_id = d.concept_id_1 and e2.concept_id = d.concept_id_2
                  AND d.relationship_id||'-'||e1.vocabulary_id||'-'||e2.vocabulary_id in (SELECT combo FROM r_coverage)
              )
;

select * from concept_relationship d
 WHERE     NOT EXISTS
              (SELECT 1
                 FROM concept_relationship_stage r
                 JOIN concept r1 on r1.concept_code = r.concept_code_1 and r1.vocabulary_id = r.vocabulary_id_1
                 JOIN concept r2 on r2.concept_code = r.concept_code_2 and r2.vocabulary_id = r.vocabulary_id_2
                -- test whether either the concept_ids match, or the concept_ids matched to the concept_codes in either stage or dev
                WHERE     d.concept_id_1 = r1.concept_id
                      AND d.concept_id_2 = r2.concept_id
                      AND d.relationship_id = r.relationship_id)
       AND d.valid_end_date = TO_DATE ('20991231', 'YYYYMMDD') -- deprecate those that are fresh and active
       AND d.valid_start_date <
       -- started before release date
                (SELECT latest_update -1
                   FROM vocabulary v, concept_stage c
                  WHERE     v.vocabulary_id = c.vocabulary_id
                        AND c.concept_id = d.concept_id_1)
       -- exclude replacing relationships, usually they are not maintained after a concept died
       AND d.relationship_id NOT IN ('UCUM replaced by',
                                     'UCUM replaces',
                                     'Concept replaced by',
                                     'Concept replaces',
                                     'Concept same_as to',
                                     'Concept same_as from',
                                     'Concept alt_to to',
                                     'Concept alt_to from',
                                     'Concept poss_eq to',
                                     'Concept poss_eq from',
                                     'Concept was_a to',
                                     'Concept was_a from',
                                     'LOINC replaced by',
                                     'LOINC replaces',
                                     'RxNorm replaced by',
                                     'RxNorm replaces',
                                     'SNOMED replaced by',
                                     'SNOMED replaces',
                                     'ICD9P replaced by',
                                     'ICD9P replaces') 
       -- check for existence of both concept_id_1 and concept_id_2
/*
       AND d.concept_id_1 in (
                SELECT concept_id FROM concept_stage c
       )
       AND d.concept_id_2 in (
                SELECT concept_id FROM concept_stage c
       )
*/ 
       -- check the combination of vocab1, vocab2 and relationship_id
       AND EXISTS (
              SELECT 1
                  FROM concept e1, concept e2
                WHERE  e1.concept_id = d.concept_id_1 and e2.concept_id = d.concept_id_2
                  AND e1.vocabulary_id||'-'||e2.vocabulary_id||'-'||d.relationship_id in (SELECT combo FROM r_coverage)
              )
;

select * from concept_relationship d
      -- whether the combination of vocab1, vocab2 and relationship exists (in r_coverage) and the individual concepts exist
      -- (intended to be covered by this particular vocab udpate)
      WHERE EXISTS (
              SELECT 1
                  FROM concept e1, concept e2
                WHERE  e1.concept_id = d.concept_id_1 and e2.concept_id = d.concept_id_2
                  AND e1.vocabulary_id||'-'||e2.vocabulary_id||'-'||d.relationship_id in (SELECT combo FROM r_coverage)
                  AND e1.valid_end_date = TO_DATE ('20991231', 'YYYYMMDD') 
                  AND e2.valid_end_date = TO_DATE ('20991231', 'YYYYMMDD') 
              )
      -- and the record is currently fresh
      AND d.valid_end_date = TO_DATE ('20991231', 'YYYYMMDD') 
       -- and it was started before release date
      AND d.valid_start_date <
                (SELECT latest_update -1 FROM vocabulary v, concept_stage c
                  WHERE     v.vocabulary_id = c.vocabulary_id
                        AND c.concept_id = d.concept_id_1)
       -- and doesn't exist in the new concept_relationship
      AND NOT EXISTS (
              SELECT 1
                 FROM concept_relationship_stage r
                 JOIN concept r1 on r1.concept_code = r.concept_code_1 and r1.vocabulary_id = r.vocabulary_id_1
                 JOIN concept r2 on r2.concept_code = r.concept_code_2 and r2.vocabulary_id = r.vocabulary_id_2
                WHERE     d.concept_id_1 = r1.concept_id
                      AND d.concept_id_2 = r2.concept_id
                      AND d.relationship_id = r.relationship_id
        )
;
434742	4031262
4176793	4050373

select * from concept where concept_id in (434742, 4031262, 4176793, 4050373);
select * from concept_relationship_stage where concept_code_1 in (268239009, 363024001)--  and concept_code_2 in (109414004, 20919000)
;

DROP TABLE r_coverage PURGE;

--select r.relationship_id, r1.concept_name, r1.domain_id, r2.concept_name, r2.domain_id from concept_relationship r 
select distinct r.relationship_id from concept_relationship r
                 JOIN concept r1 on r1.concept_id = r.concept_id_1
                 JOIN concept r2 on r2.concept_id = r.concept_id_2
where r.valid_end_date='31-jul-2014';
select * from concept where concept_id in (4116359, 4178026);

COMMIT;				
--12 insert new relationships
INSERT INTO concept_relationship (concept_id_1,
                                  concept_id_2,
                                  relationship_id,
                                  valid_start_date,
                                  valid_end_date,
                                  invalid_reason)
   SELECT distinct crs.concept_id_1,
          crs.concept_id_2,
          crs.relationship_id,
          crs.valid_start_date,
          TO_DATE ('20991231', 'YYYYMMDD') AS valid_end_date,
          NULL AS invalid_reason
     FROM concept_relationship_stage crs
    WHERE NOT EXISTS
             (SELECT 1
                FROM concept_relationship r
               -- test whether either the concept_ids match, or the concept_ids matched to the concept_codes in either stage or dev
               WHERE     crs.concept_id_1 = r.concept_id_1
                     AND crs.concept_id_2 = r.concept_id_2
                     AND crs.relationship_id = r.relationship_id);

COMMIT;	
	
--XX Update invalid_reason
update concept set invalid_reason=null where valid_end_date = to_date('31.12.2099','dd.mm.yyyy');

update concept c set c.invalid_reason='U' 
where c.valid_end_date <> to_date('31.12.2099','dd.mm.yyyy')
and exists (
    select 1 from concept_relationship r 
    where r.concept_id_1=c.concept_id AND r.relationship_id in (
            'UCUM replaced by',
            'Concept replaced by',
            'Concept same_as to',
            'Concept alt_to to',
            'Concept poss_eq to',
            'Concept was_a to',
            'LOINC replaced by',
            'RxNorm replaced by',
            'SNOMED replaced by',
            'ICD9P replaced by',
    )
;

update concept c set c.invalid_reason='D'
where c.valid_end_date <> to_date('31.12.2099','dd.mm.yyyy')
and not exists (
    select 1 from concept_relationship r 
    where r.concept_id_1=c.concept_id AND r.relationship_id in (
            'UCUM replaced by',
            'Concept replaced by',
            'Concept same_as to',
            'Concept alt_to to',
            'Concept poss_eq to',
            'Concept was_a to',
            'LOINC replaced by',
            'RxNorm replaced by',
            'SNOMED replaced by',
            'ICD9P replaced by',
    )
;
-- 4. Fill in all concept_id_1 and _2 in concept_relationship_stage
UPDATE concept_relationship_stage crs
   SET (crs.concept_id_1, crs.concept_id_2) =
          (SELECT 
                  COALESCE (cs1.concept_id, c1.concept_id,crs.concept_id_1),
                  COALESCE (cs2.concept_id, c2.concept_id,crs.concept_id_2)
             FROM concept_relationship_stage r
                  LEFT JOIN concept_stage cs1
                     ON cs1.concept_code = r.concept_code_1 and cs1.vocabulary_id=r.vocabulary_id_1
                  LEFT JOIN concept c1 ON c1.concept_code = r.concept_code_1 and c1.vocabulary_id=r.vocabulary_id_1
                  LEFT JOIN concept_stage cs2
                     ON cs2.concept_code = r.concept_code_2 and cs2.vocabulary_id=r.vocabulary_id_2
                  LEFT JOIN concept c2 ON c2.concept_code = r.concept_code_2 and c2.vocabulary_id=r.vocabulary_id_2
            WHERE      crs.rowid=r.rowid        
         )
 WHERE crs.concept_id_1 IS NULL OR crs.concept_id_2 IS NULL;
 
 COMMIT;
 
