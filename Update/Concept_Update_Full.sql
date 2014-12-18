/******************************************************************************************
*
* Expects a concept_stage table to be present from a vocabulary_specific script
* Update from full list
* 1a. Existing concept:
* concept_id or vocabulary_id/concept_code have to exist to identify the concept, in this order of precedence.
* If concept_name, domain_id, concept_class_id, standard_concept, valid_start_date, valid_end_date, invalid_reason have content, they will overwrite the existing concept.
* valid_start_date has to be null or before today's date.
* valid_end_date can be used for deprecating a concept, but leaving a concept out out from concept_stage will do the same thing.  
* valid_end_date has to be before today's date (deprecation), null (no change) or 31-Dec-2099 (undeprecation).
* If invalid_reason is null and valid_end_date is not 31-Dec-2099, it will be set to 'D'. If valid_end_date is 31-Dec-2099 invaid_reason is set to null.
* As a result, only invalid_reason='U' survives if the valid_end_date is before 31-Dec-2099 (before today's really).
* 1a. New concept:
* concept_id should be null.
* vocabulary_id/concept_code have to exist to create a new concept.
* concept_name, domain_id, concept_class_id, standard_concept have to have content. 
* If valid_start_date is null, 1-Jan-1970 is assumed as default. Otherwise, it has to be before today's date.
* valid_end_date can only be null (assumed 31-Dec-2099) or 31-Dec-2099
* invalid_reason is ignored and set to null.
* 
**********************************************************************************************/

-- Fill concept_id where concept exists
update concept_stage cs
set cs.concept_id=(select c.concept_id from concept c where c.concept_code=cs.concept_code and c.vocabulary_id=cs.vocabulary_id)
where cs.concept_id is null;
commit;

-- Check above rules:
-- Check existing concepts for valid_start_date and valid_end_date
select * from concept_stage cs, concept c
where cs.concept_id=c.concept_id
and (
    cs.valid_start_date>=sysdate OR
    (cs.valid_end_date>=sysdate and cs.valid_end_date<>to_date('31.12.2099','dd.mm.yyyy'))
);

-- Check new concepts for completeness
select * from concept_stage cs
left join concept c on cs.concept_id=c.concept_id
where c.concept_id is null -- have no match
and 
(
   cs.concept_name is null OR
   cs.domain_id is null OR
   cs.concept_class_id is null OR
   cs.standard_concept is null OR
   cs.concept_code is null OR
   cs.valid_start_date>=sysdate OR
   cs.valid_end_date<>to_date('31.12.2099','dd.mm.yyyy')
);

-- Add existing concept_names to synonym (unless already exists) if being overwritten with a new one
insert into concept_synonym
select
    c.concept_id,
    c.concept_name concept_synonym_name,
    4093769 language_concept_id -- English
from concept_stage cs, concept c
where c.concept_id=cs.concept_id and c.concept_name<>cs.concept_name
and not exists (select 1 from concept_synonym where concept_synonym_name=c.concept_name); -- synonym already exists

-- Update concepts
UPDATE concept c
SET (concept_name, domain_id,concept_class_id,standard_concept,valid_end_date) = (
  SELECT coalesce(cs.concept_name, c.concept_name), coalesce(cs.domain_id, c.domain_id),
  coalesce(cs.concept_class_id, c.concept_class_id),coalesce(cs.standard_concept, c.standard_concept), 
  coalesce(cs.valid_end_date, c.valid_end_date)
  FROM concept_stage cs
  WHERE c.concept_id=cs.concept_id)
where  concept_id in (select concept_id from concept_stage);

-- Deprecate missing concepts
update concept c set
c.valid_end_date = c.valid_start_date-1
where not exists (select 1 from concept_stage cs where cs.concept_id=c.concept_id and cs.vocabulary_id=c.vocabulary_id);

-- set invalid_reason for active concepts
update concept set
invalid_reason=null
where valid_end_date = to_date('31.12.2099','dd.mm.yyyy');

-- set invalid_reason for deprecated concepts
update concept set
invalid_reason='D'
where invalid_reason is null -- unless is already set
and valid_end_date <> to_date('31.12.2099','dd.mm.yyyy');

-- Add new concepts
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
   SELECT v5dev.v5_concept.NEXTVAL,
          cs.concept_name,
          cs.domain_id,
          cs.vocabulary_id,
          cs.concept_class_id,
          cs.standard_concept,
          cs.concept_code,
          COALESCE (cs.valid_start_date,
                    TO_DATE ('01.01.1970', 'dd.mm.yyyy')),
          COALESCE (cs.valid_end_date, TO_DATE ('31.12.2099', 'dd.mm.yyyy')),
          NULL
     FROM concept_stage cs
    WHERE cs.concept_id IS NULL;
	


 --Update all relationships existing in concept_relationship_stage, including undeprecation of formerly deprecated ones
 CREATE INDEX idx_concept_id_1
   ON concept_relationship_stage (concept_id_1);
CREATE INDEX idx_concept_id_2
   ON concept_relationship_stage (concept_id_2);

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
 
 
--Deprecate missing relationships, but only if the concepts exist.
-- If relationships are missing because of deprecated concepts, leave them intact
--Do it with all vocabulary (Read, SNOMED, RxNorm), but with his own release day
UPDATE concept_relationship d
   SET valid_end_date = to_date('20141130', 'YYYYMMDD'), -- day before release day
       invalid_reason = 'D'
 WHERE     NOT EXISTS
              (SELECT 1
                 FROM concept_relationship_stage r
                -- test whether either the concept_ids match, or the concept_ids matched to the concept_codes in either stage or dev
                WHERE     d.concept_id_1 = r.concept_id_1
                      AND d.concept_id_2 = r.concept_id_2
                      AND d.relationship_id = r.relationship_id)

       AND d.valid_end_date = TO_DATE ('20991231', 'YYYYMMDD') -- deprecate those that are fresh and active
       AND d.valid_start_date < TO_DATE ('20141130', 'YYYYMMDD') -- started before release date
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
                WHERE c.concept_id = d.concept_id_1 and C.VOCABULARY_ID='SNOMED' )
       AND EXISTS
              (SELECT 1
                 FROM concept_stage c
                WHERE c.concept_id = d.concept_id_2 and C.VOCABULARY_ID='SNOMED');                  

--insert new relationships
INSERT INTO concept_relationship (concept_id_1,
                                  concept_id_2,
                                  relationship_id,
                                  valid_start_date,
                                  valid_end_date,
                                  invalid_reason)
   SELECT distinct crs.concept_id_1,
          crs.concept_id_2,
          crs.relationship_id,
          TO_DATE ('20141201', 'YYYYMMDD') AS valid_start_date,
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

commit;	
	