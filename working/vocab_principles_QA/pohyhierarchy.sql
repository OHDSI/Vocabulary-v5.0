-- These checks are used for the analysis of concept hierarchy

--1.Number of standard concepts that have no parent or descendant in the hierarchy across the last two releases (use for the report)
with previous as (
select c.vocabulary_id, count(distinct  c.concept_id)
from dev_qaathena.concept_ancestor ca
join dev_qaathena.concept c on ca.descendant_concept_id = c.concept_id
where c.standard_concept = 'S'
and not exists(
    select 1
    from dev_qaathena.concept_ancestor ca2
    where ca2.descendant_concept_id = ca.descendant_concept_id
    and ca2.ancestor_concept_id != ca2.descendant_concept_id
)
and not exists(
    select 1
    from dev_qaathena.concept_ancestor ca3
    where ca3.ancestor_concept_id = ca.descendant_concept_id
    and ca3.ancestor_concept_id != ca3.descendant_concept_id
)
group by 1
),
    current as (
select c.vocabulary_id, count(distinct  c.concept_id)
from prodv5.concept_ancestor ca
join prodv5.concept c on ca.descendant_concept_id = c.concept_id
where c.standard_concept = 'S'
and not exists(
    select 1
    from prodv5.concept_ancestor ca2
    where ca2.descendant_concept_id = ca.descendant_concept_id
    and ca2.ancestor_concept_id != ca2.descendant_concept_id
)
and not exists(
    select 1
    from prodv5.concept_ancestor ca3
    where ca3.ancestor_concept_id = ca.descendant_concept_id
    and ca3.ancestor_concept_id != ca3.descendant_concept_id
)
group by 1
 )

select vocabulary_id,
       p.count as previous,
       c.count as current,
       c.count - p.count as delta
from previous p
join current c using (vocabulary_id)
order by vocabulary_id;

--2. Number of the classification concepts without descendants:
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

-- 3. Number of standard concepts without ancestors and descendants
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

