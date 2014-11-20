-- drop synonym concept;
select * from concept;


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

-- Check above rules:
-- Check existing concepts for valid_start_date and valid_end_date
select * from concept_stage cs
join concept c on cs.concept_id=c.concept_id
where case 
  when cs.valid_start_date>=current_date() then false
  when cs.valid_end_date>=current_date() and cs.valid_end_date!='31-Dec-2099' then false
  else true
end
;

-- Check new concepts for completeness
select * from concept_stage cs
left join concept c on cs.concept_id=c.concept_id
where c.concept_id is null -- have no match
and case 
  when cs.concept_name is null then false
  when cs.domain_id is null then false
  when cs.concept_class_id is null then false
  when cs.standard_concept is null then false
  when cs.concept_code is null then false
  when cs.valid_start_date>=current_date() then false
  when cs.valid_end_date!='31-Dec-2099' then false
  else true
end
;

-- Add existing concept_names to synonym (unless already exists) if being overwritten with a new one
insert into concept_synonym sy 
select 
  c.concept_id,
  c.concept_name as sy.concept_synonym_name,
  4093769 as language_concept_id -- English
from concept c 
join concept_stage cs on c.concept_id=cs.concept_id and c.concept_name!=cs.concept_name 
and not exists (select 1 from concept_synonym where concept_synonym_name=c.concept_name) -- synonym already exists
;

-- Update concepts
update concept c set
  c.concept_name= (select coalesce(cs.concept_name, c.concept_name) from concept c where c.concept_id=cs.concept_id)
  c.domain_id = (select coalesce(cs.domain_id, c.domain_id) from concept c where c.concept_id=cs.concept_id)
  c.concept_class_id = (select coalesce(cs.concept_class_id, c.concept_class_id) from concept c where c.concept_id=cs.concept_id)
  c.standard_concept = (select coalesce(cs.standard_concept, c.standard_concept) from concept c where c.concept_id=cs.concept_id)
  c.valid_start_date = (select coalesce(cs.valid_start_date, c.valid_start_date) from concept c where c.concept_id=cs.concept_id)
  c.valid_end_date = (select coalesce(cs.valid_end_date, c.valid_end_date) from concept c where c.concept_id=cs.concept_id)
where exists (select 1 from concept_stage cs where cs.concept_id=c.concept_id)
;

-- Deprecate missing concepts
update concept c set
  c.valid_end_date = '31-Dec-2099'
where c.vocabulary_id = (select distinct vocabulary_id from concept_stage)
and not exists (select 1 from concept_stage cs where cs.concept_id=c.concept_id)
;

-- set invalid_reason for active concepts
update concept set
  invalid_reason=null
where vocabulary_id = (select distinct vocabulary_id from concept_stage)
and valid_end_date = '31-Dec-2099'
;

-- set invalid_reason for deprecated concepts
update concept set
  invalid_reason='D'
where vocabulary_id = (select distinct vocabulary_id from concept_stage)
and invalid_reason is null -- unless is already set
and valid_end_date != '31-Dec-2099'
;

-- Add new concepts
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  v5_concept.nextval,
  cs.concept_name,
  cs.domain_id,
  (select distinct vocabulary_id from concept_stage),
  cs.concept_class_id,
  cs.standard_concept,
  cs.concept_code,
  coalesce(cs.valid_start_date, '1-Jan-1970'),
  coalesce(cs.valid_end_date, '31-Dec-2099'),
  null
from concept_stage cs
where cs.concept_id is null
;

