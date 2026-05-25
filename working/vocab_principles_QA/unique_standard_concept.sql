--- This group of checks allows comparing numbers of concepts with fully homonymic concept names
--- These checks are case-insensitive to ensure better sensitivity, but it causes lower specificity in some cases (e.g., blood phenotype determination)

--1. Analysis of duplicates within one domain
--- 1.1 Summary of intra-domain duplicates
select distinct c.domain_id,
                count(distinct c.concept_id) as count
       from devv5.concept c
join devv5.concept cc on lower(c.concept_name) = lower(cc.concept_name)
where c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and cc.domain_id = c.domain_id
and c.concept_name not like '%...%'
group by c.domain_id
order by count desc;

-- 1.2 Domain-specific check to have a precise look at the vocabularies and concept classes containing intra-domain duplicates
select distinct concat(c.vocabulary_id, ' - ',  cc.vocabulary_id) as vocab_concat,
                concat(c.concept_class_id, ' - ', cc.concept_class_id) as cc_concat,
                case when c.vocabulary_id <> cc.vocabulary_id
                       then count(distinct c.concept_id) + count(distinct cc.concept_id)
                       else count(distinct c.concept_id) end as count
from devv5.concept c
join devv5.concept cc on lower(c.concept_name) = lower(cc.concept_name)
where c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and cc.domain_id = c.domain_id
and c.domain_id = :your_domain
and c.concept_name not like '%...%'
GROUP BY c.vocabulary_id, cc.vocabulary_id, c.concept_class_id, cc.concept_class_id
order by vocab_concat, count desc, cc_concat;

-- 1.3 A check to look at the concept_level duplicates
select distinct c.concept_name,
    c.concept_id,
    c.concept_code,
    c.domain_id,
    c.concept_class_id,
    c.standard_concept,
    c.valid_start_date,
    c.valid_end_date,
    c.vocabulary_id
from devv5.concept c, devv5.concept cc
where lower(c.concept_name) = lower(cc.concept_name)
and c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.domain_id = cc.domain_id
and c.domain_id = :your_domain
and c.concept_name not like '%...%'
order by c.concept_name, c.concept_class_id, c.vocabulary_id;


-- 2. Analysis of duplicates across different domains
--- 2.1 Summary of domain pairs across various vocabularies and concept classes
select distinct concat (c.domain_id, ' - ', cc.domain_id) as domain_concat,
				concat(c.vocabulary_id, ' - ',  cc.vocabulary_id) as vocab_concat,
                concat(c.concept_class_id, ' - ', cc.concept_class_id) as cc_concat,
                case when c.vocabulary_id <> cc.vocabulary_id
                       then count(distinct c.concept_id) + count(distinct cc.concept_id)
                       else count(distinct c.concept_id) end as count
from devv5.concept c
join devv5.concept cc on lower(c.concept_name) = lower(cc.concept_name)
where c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.domain_id != cc.domain_id
and c.concept_name not like '%...%'
group by c.domain_id, cc.domain_id, c.vocabulary_id, cc.vocabulary_id, c.concept_class_id, cc.concept_class_id
order by domain_concat, vocab_concat, count desc, cc_concat;

-- 2.2 Concept-level check
select distinct c.concept_name,
    c.concept_id,
  	c.concept_code,
    c.domain_id,
    c.concept_class_id,
    c.vocabulary_id
from devv5.concept c, devv5.concept cc
where lower(c.concept_name) = lower(cc.concept_name)
and c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.domain_id in (:your_domains)
and cc.domain_id in (:your_domains)
and c.domain_id <> cc.domain_id
and c.concept_name not like '%...%'
order by c.concept_name, c.domain_id, c.concept_class_id, c.vocabulary_id;

-- 2.3 Number of post-coordinated concepts across the OHDSI vocabularies
select distinct vocabulary_id,
                count(distinct concept_id) as count
from concept c
where exists (
       select 1
       from concept_relationship cr
       where c.concept_id = cr.concept_id_1
       and cr.relationship_id = 'Maps to'
       and cr.invalid_reason is null
)
and exists (
       select 1
       from concept_relationship cr
       where c.concept_id = cr.concept_id_1
       and cr.relationship_id = 'Maps to value'
       and cr.invalid_reason is null
)
group by vocabulary_id
order by count desc;