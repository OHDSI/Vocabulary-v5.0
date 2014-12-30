--1 Fill concept_id where concept exists
update concept from concept_stage 
 -- Fill concept_id where concept exists
update concept_stage cs
set cs.concept_id=(select c.concept_id from concept c where c.concept_code=cs.concept_code and c.vocabulary_id=cs.vocabulary_id)
where cs.concept_id is null;

--2 Add existing concept_names to synonym (unless already exists) if being overwritten with a new one
insert into concept_synonym
select
    c.concept_id,
    c.concept_name concept_synonym_name,
    4093769 language_concept_id -- English
from concept_stage cs, concept c
where c.concept_id=cs.concept_id and c.concept_name<>cs.concept_name
and not exists (select 1 from concept_synonym where concept_synonym_name=c.concept_name); -- synonym already exists

--3 Update concepts
UPDATE concept c
SET (concept_name, domain_id,concept_class_id,standard_concept,valid_end_date) = (
  SELECT coalesce(cs.concept_name, c.concept_name), coalesce(cs.domain_id, c.domain_id),
  coalesce(cs.concept_class_id, c.concept_class_id),coalesce(cs.standard_concept, c.standard_concept), 
  coalesce(cs.valid_end_date, c.valid_end_date)
  FROM concept_stage cs
  WHERE c.concept_id=cs.concept_id)
where  concept_id in (select concept_id from concept_stage);

--4 Deprecate missing concepts
update concept c set
c.valid_end_date = c.valid_start_date-1
where not exists (select 1 from concept_stage cs where cs.concept_id=c.concept_id and cs.vocabulary_id=c.vocabulary_id);

--5 set invalid_reason for active concepts
update concept set invalid_reason=null where valid_end_date = to_date('31.12.2099','dd.mm.yyyy');

--6 set invalid_reason for deprecated concepts
update concept set invalid_reason='D' where invalid_reason is null -- unless is already set
and valid_end_date <> to_date('31.12.2099','dd.mm.yyyy');
COMMIT;

--7 add new concepts
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
COMMIT;

--8. fill in all concept_id_1 and _2 in concept_relationship_stage
/*
--create indexes if you don't did it already
CREATE INDEX idx_concept_code_1
   ON concept_relationship_stage (concept_code_1);
CREATE INDEX idx_concept_code_2
   ON concept_relationship_stage (concept_code_2);
*/

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
 
 --9 Make sure all records are symmetrical and turn if necessary
INSERT INTO concept_relationship_stage
   SELECT crs.concept_id_2 AS concept_id_1,
          crs.concept_id_1 AS concept_id_2,
          CRS.CONCEPT_CODE_2 AS CONCEPT_CODE_1,
          CRS.CONCEPT_CODE_1 AS CONCEPT_CODE_2,
          r.reverse_relationship_id AS relationship_id,
		  crs.vocabulary_id_2,
		  crs.vocabulary_id_1,
          crs.valid_start_date,
          crs.valid_end_date,
          crs.invalid_reason
     FROM concept_relationship_stage crs
          JOIN relationship r ON r.relationship_id = crs.relationship_id
    WHERE NOT EXISTS
             (                                           -- the inverse record
              SELECT 1
                FROM concept_relationship_stage i
               WHERE     crs.CONCEPT_CODE_1 = i.CONCEPT_CODE_2
                     AND crs.CONCEPT_CODE_2 = i.CONCEPT_CODE_1
                     AND r.reverse_relationship_id = i.relationship_id
					 AND crs.vocabulary_id_1=i.vocabulary_id_2
					 AND crs.vocabulary_id_2=i.vocabulary_id_1);
COMMIT;


 --10 Update all relationships existing in concept_relationship_stage, including undeprecation of formerly deprecated ones
 /*
 --create indexes if you don't did it already
 CREATE INDEX idx_concept_id_1
   ON concept_relationship_stage (concept_id_1);
CREATE INDEX idx_concept_id_2
   ON concept_relationship_stage (concept_id_2);
 */

UPDATE concept_relationship d
   SET (d.valid_end_date, d.invalid_reason) =
          (SELECT distinct crs.valid_end_date, crs.invalid_reason
             FROM concept_relationship_stage crs
            WHERE     crs.concept_id_1 = d.concept_id_1
                  AND crs.concept_id_2 = d.concept_id_2
                  AND crs.relationship_id = d.relationship_id)
 WHERE EXISTS
          (SELECT 1
             FROM concept_relationship_stage r
            -- test whether either the concept_ids match
            WHERE     d.concept_id_1 = r.concept_id_1
                  AND d.concept_id_2 = r.concept_id_2
                  AND d.relationship_id = r.relationship_id);
 
COMMIT; 

--11 Deprecate missing relationships, but only if the concepts exist. If relationships are missing because of deprecated concepts, leave them intact
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
                -- test whether either the concept_ids match, or the concept_ids matched to the concept_codes in either stage or dev
                WHERE     d.concept_id_1 = r.concept_id_1
                      AND d.concept_id_2 = r.concept_id_2
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
                                     'ICD9P replaces') -- check for existence of both concept_id_1 and concept_id_2
       AND EXISTS
              (SELECT 1
                 FROM concept_stage c
                WHERE c.concept_id = d.concept_id_1)
       AND EXISTS
              (SELECT 1
                 FROM concept_stage c
                WHERE c.concept_id = d.concept_id_2);      
	

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
	