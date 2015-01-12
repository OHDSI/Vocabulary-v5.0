-- This script contains all activities that are needed after updating individual vocabularies


/*
--2 Add existing concept_names to synonym (unless already exists) if being overwritten with a new one
insert into concept_synonym
select
    c.concept_id,
    c.concept_name concept_synonym_name,
    4093769 language_concept_id -- English
from concept_stage cs, concept c
where c.concept_id=cs.concept_id and c.concept_name<>cs.concept_name
and not exists (select 1 from concept_synonym where concept_synonym_name=c.concept_name); -- synonym already exists
*/

