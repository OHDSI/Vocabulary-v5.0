-- These checks are used for the analysis of concept hierarchy

--- 1. Number of the classification concepts without descendants:
select vocabulary_id,
       domain_id,
       concept_class_id,
       count(*) as number_of_concepts
from concept c
where c.standard_concept IN ('C', 'S')
  and not exists (select 1
                  from concept_ancestor ca
                  where c.concept_id = ca.ancestor_concept_id
                    and ca.descendant_concept_id != ca.ancestor_concept_id)
group by vocabulary_id,
         domain_id,
         concept_class_id
order by number_of_concepts desc;
;

-- 2. Number of standard concepts without ancestors and descendants
select vocabulary_id,
       count(*) as count
from concept c1
where c1.standard_concept = 'S'
and not exists(
select 1
from concept_ancestor ca
where c1.concept_id = ca.descendant_concept_id
and ca.descendant_concept_id != ca.ancestor_concept_id)
and not exists(
select 1
from concept_ancestor ca
where c1.concept_id = ca.ancestor_concept_id
and ca.descendant_concept_id != ca.ancestor_concept_id)
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

