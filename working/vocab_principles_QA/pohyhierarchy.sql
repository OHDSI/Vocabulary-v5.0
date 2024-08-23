-- These checks are used for the analysis of concept hierarchy

--- 1. Number of the classification concepts without descendants:
select vocabulary_id,
       count(*) as count
from devv5.concept c1
where c1.standard_concept = 'C'
  and c1.invalid_reason is null
and not exists(
select 1
from devv5.concept c
join devv5.concept_relationship cr on c.concept_id = cr.concept_id_1
where c.standard_concept = 'C'
and cr.relationship_id = 'Subsumes'
and cr.invalid_reason is null
and c.concept_id = c1.concept_id)
group by vocabulary_id
order by count desc
;

-- 2. Number of standard concepts without ancestors and descendants
select vocabulary_id,
       count(*) as count
from devv5.concept c1
where c1.standard_concept = 'S'
and not exists(
select 1
from devv5.concept c
join devv5.concept_relationship cr on c.concept_id = cr.concept_id_1
where c.standard_concept = 'S'
and cr.relationship_id = 'Is a'
and cr.invalid_reason is null
and c.concept_id = c1.concept_id)
and not exists(
select 1
from devv5.concept c
join devv5.concept_relationship cr on c.concept_id = cr.concept_id_1
where c.standard_concept = 'S'
and cr.relationship_id = 'Subsumes'
and cr.invalid_reason is null
and c.concept_id = c1.concept_id)
group by vocabulary_id
order by count desc
;

-- 3.Number of Standard concepts that fall beyond the concept_ancestor (should retrieve null)
select *
from concept c
where standard_concept = 'S'
and not exists (
       select 1
       from concept_ancestor ca
       where descendant_concept_id = c.concept_id
       or ancestor_concept_id = c.concept_id
);

