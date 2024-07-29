--1. Update mapped table according to the new targets:
update hcpcs_mapped
set target_invalid_reason = null WHERE target_invalid_reason = 'Valid';
update hcpcs_mapped
set target_standard_concept = 'S' WHERE target_standard_concept = 'Standard';

with reviewed as (
select source_code_description,
       source_code,
       source_concept_class_id,
       source_invalid_reason,
       source_domain_id,
       source_vocabulary_id,
       cr_invalid_reason,
       mapping_tool,
       mapping_source,
       confidence,
       m.relationship_id,
       relationship_id_predicate,
       m.source,
       case when m.target_concept_id != c.concept_id then '!target updated!' END as comments,
       c.concept_id as target_concept_id,
       c.concept_code as target_concept_code,
       c.concept_name as target_concept_name,
       c.concept_class_id as target_concept_class_id,
       c.standard_concept as target_standard_concept,
       c.invalid_reason as target_invalid_reason,
       c.domain_id as target_domain_id,
       c.vocabulary_id as target_vocabulary_id,
       mapper_id,
       reviewer_id
from hcpcs_mapped m
join concept cc on (cc.concept_code, cc.vocabulary_id) = (m.target_concept_code, m.target_vocabulary_id)
left join devv5.concept_relationship cr on cc.concept_id = cr.concept_id_1 and cr.relationship_id = 'Maps to' and cr.invalid_reason is null
left join devv5.concept c on c.concept_id = cr.concept_id_2
where m.cr_invalid_reason  is NULL
and cr.relationship_id in ('Maps to', 'Maps to value')

union

select source_code_description,
       source_code,
       source_concept_class_id,
       source_invalid_reason,
       source_domain_id,
       source_vocabulary_id,
       cr_invalid_reason,
       mapping_tool,
       mapping_source,
       confidence,
       m.relationship_id,
       relationship_id_predicate,
       m.source,
       case when target_concept_code is NULL then '!no target!' end as comments,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_concept_class_id,
       target_standard_concept,
       target_invalid_reason,
       target_domain_id,
       target_vocabulary_id,
       mapper_id,
       reviewer_id
from hcpcs_mapped m
where relationship_id not in ('Maps to', 'Maps to value')
or (relationship_id in ('Maps to', 'Maps to value') and cr_invalid_reason = 'D')
or target_concept_id = 0
or target_concept_code is null
),

to_review as (
select source_code_description,
       source_code,
       source_concept_class_id,
       source_invalid_reason,
       source_domain_id,
       source_vocabulary_id,
       cr_invalid_reason,
       mapping_tool,
       mapping_source,
       confidence,
       m.relationship_id,
       relationship_id_predicate,
       m.source,
       case when c.standard_concept is null and c.concept_code is not null then '!non-standard target!'
              else null end as comments,
       c.concept_id as target_concept_id,
       c.concept_code as target_concept_code,
       c.concept_name as target_concept_name,
       c.concept_class_id as target_concept_class_id,
       c.standard_concept as target_standard_concept,
       c.invalid_reason as target_invalid_reason,
       c.domain_id as target_domain_id,
       c.vocabulary_id as target_vocabulary_id,
       mapper_id,
       reviewer_id
from hcpcs_mapped m
join devv5.concept c on (c.concept_code, c.vocabulary_id) = (m.target_concept_code, m.target_vocabulary_id)
where not exists (select 1
                  from reviewed r
                  where (r.source_code, r.relationship_id, r.cr_invalid_reason) = (m.source_code, m.relationship_id, m.cr_invalid_reason)))

select DISTINCT on (source_code, target_concept_id) * from reviewed
union
select * from to_review
order by source, source_code, relationship_id
;

--2. Extract new concepts for manual mapping or manual hierarchy creation:
SELECT c.concept_name,
        c.concept_code,
        c.concept_class_id,
        c.invalid_reason ,
        c.domain_id ,
        c.vocabulary_id,
		null as cr_invalid_reason,
        null as mapping_tool,
        null as mapping_source,
        '1' as confidence,
        'Maps to' as relationship_id
FROM concept c
WHERE vocabulary_id = 'HCPCS'
AND concept_code NOT IN (SELECT concept_code
                         FROM devv5.concept
                         WHERE vocabulary_id = 'HCPCS')
ORDER BY concept_code
;

with all_brands as (
SELECT distinct /*b.rxcui,*/ a.atv as hcpcs, b.tty, /*b.str,*/ SUBSTRING(b.str FROM '\[(.+)\]') as brand
FROM sources.rxnsat a, sources.rxnconso b
WHERE a.atn = 'DHJC'
AND (a.atv like 'J%'
or a.atv like 'Q%'
or a.atv like 'C%'
or a.atv like 'A%')
AND a.rxcui = b.rxcui
AND b.tty in (/*'GPCK', 'BPCK', 'SCD',*/ 'SBD')
ORDER BY a.atv),

rxcount as (
select hcpcs, count(brand) as count
from all_brands
group by hcpcs),

rxbrand as (SELECT hcpcs, a.brand
from all_brands a
join rxcount c using (hcpcs)
where c.count = 1),

all_mapped as (
SELECT DISTINCT m.source_code, c.concept_name as brand
from hcpcs_mapped m
join concept_relationship cr on m.target_concept_id = cr.concept_id_1 and cr.relationship_id = 'Has brand name' and cr.invalid_reason is null
join concept c on c.concept_id = cr.concept_id_2),

m_count as (
       SELECT source_code, count(brand) as count
       from all_mapped
       GROUP BY source_code
),

m_brand as (
SELECT source_code, brand
from all_mapped a
join m_count c USING (source_code)
where c.count = 1
	   )

select m.source_code, m.brand, r.brand
FROM m_brand m
left join rxbrand r on r.hcpcs = m.source_code
where m.brand <> r.brand
ORDER BY source_code
;

with all_mapped as (
SELECT DISTINCT m.source_code, c.concept_name as brand
from hcpcs_mapped m
join concept_relationship cr on m.target_concept_id = cr.concept_id_1 and cr.relationship_id = 'Has brand name' and cr.invalid_reason is null
join concept c on c.concept_id = cr.concept_id_2),

m_count as (
       SELECT source_code, count(brand) as count
       from all_mapped
       GROUP BY source_code
)
SELECT source_code, brand
from all_mapped a
join m_count c USING (source_code)
where c.count = 1

;

