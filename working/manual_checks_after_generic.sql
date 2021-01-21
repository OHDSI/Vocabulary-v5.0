--01. Concept changes
--01.1. Concepts changed their Domain
select old.concept_code,
       old.concept_name as old_concept_name,
       old.concept_class_id as old_concept_class_id,
       old.standard_concept as old_standard_concept,
       old.domain_id as old_domain_id,
       new.domain_id as new_domain_id
from devv5.concept old
join concept new using (concept_id) 
where old.domain_id != new.domain_id
;

--01.2. Domain of newly added concepts
SELECT c1.concept_code,
       c1.concept_name,
       c1.concept_class_id,
       c1.standard_concept,
       c1.domain_id as new_domain
FROM concept c1
LEFT JOIN devv5.concept c2
    ON c1.concept_id = c2.concept_id
WHERE c2.vocabulary_id IS NULL
;

--01.3. Concepts changed their names
SELECT c.concept_code,
       c.vocabulary_id,
       c2.concept_name as old_name,
       c.concept_name as new_name,
       devv5.similarity (c2.concept_name, c.concept_name)
FROM concept c
JOIN devv5.concept c2
    ON c.concept_id = c2.concept_id
        AND c.concept_name != c2.concept_name
WHERE c.vocabulary_id IN (:your_vocabs)
ORDER BY devv5.similarity (c2.concept_name, c.concept_name)
;

--02. Mapping of concepts
--02.1. looking at new concepts and their mapping -- 'Maps to' absent
select a.concept_code as concept_code_source,
       a.concept_name as concept_name_source,
       a.vocabulary_id as vocabulary_id_source,
       a.concept_class_id as concept_class_id_source,
       a.domain_id as domain_id_source,
       b.concept_name as concept_name_target,
       b.vocabulary_id as vocabulary_id_target
 from concept a
left join concept_relationship r on a.concept_id= r.concept_id_1 and r.invalid_reason is null and r.relationship_Id ='Maps to'
left join concept  b on b.concept_id = r.concept_id_2
left join devv5.concept  c on c.concept_id = a.concept_id
where a.vocabulary_id IN (:your_vocabs)
and c.concept_id is null and b.concept_id is null
;

--02.2. looking at new concepts and their mapping -- 'Maps to' present
select a.concept_code as concept_code_source,
       a.concept_name as concept_name_source,
       a.vocabulary_id as vocabulary_id_source,
       a.concept_class_id as concept_class_id_source,
       a.domain_id as domain_id_source,
       CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>'
           ELSE b.concept_name END as concept_name_target,
       CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>'
           ELSE b.vocabulary_id END as vocabulary_id_target
from concept a
join concept_relationship r
    on a.concept_id=r.concept_id_1
           and r.invalid_reason is null
           and r.relationship_Id ='Maps to'
join concept b
    on b.concept_id = r.concept_id_2
left join devv5.concept  c
    on c.concept_id = a.concept_id
where a.vocabulary_id IN (:your_vocabs)
    and c.concept_id is null
    --and a.concept_id != b.concept_id --use it to exclude mapping to itself
;

--02.3. looking at new concepts and their ancestry -- 'Is a' absent
select a.concept_code, a.concept_name, a.concept_class_id, a.domain_id, b.concept_name, b.concept_class_id, b.vocabulary_id
from concept a
left join concept_relationship r on a.concept_id= r.concept_id_1 and r.invalid_reason is null and r.relationship_Id ='Is a'
left join concept b on b.concept_id = r.concept_id_2
left join devv5.concept  c on c.concept_id = a.concept_id
where a.vocabulary_id IN (:your_vocabs)
and c.concept_id is null and b.concept_id is null
;

--02.4. looking at new concepts and their ancestry -- 'Is a' present
select a.concept_code, a.concept_name, a.concept_class_id, a.domain_id, b.concept_name, b.concept_class_id, b.vocabulary_id
from concept a
join concept_relationship r on a.concept_id= r.concept_id_1 and r.invalid_reason is null and r.relationship_Id ='Is a'
join concept  b on b.concept_id = r.concept_id_2
left join devv5.concept  c on c.concept_id = a.concept_id
where a.vocabulary_id IN (:your_vocabs)
and c.concept_id is null
;

--02.5. concepts changed their mapping ('Maps to')
with new_map as (
select a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from concept a
join concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Maps to', 'Maps to value') and r.invalid_reason is null
join concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN (:your_vocabs) and a.invalid_reason is null
group by a.concept_code, a.concept_name
)
,
old_map as (
select a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from devv5. concept a
join devv5.concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Maps to', 'Maps to value') and r.invalid_reason is null
join devv5.concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN (:your_vocabs) and a.invalid_reason is null
group by a.concept_code, a.concept_name
)
select a.concept_code as source_code,
       a.concept_name as source_name,
       a.relationship_agg as old_relat_agg,
       a.code_agg as old_code_agg,
       a.name_agg as old_name_agg,
       b.relationship_agg as new_relat_agg,
       b.code_agg as new_code_agg,
       b.name_agg as new_name_agg
from old_map  a
join new_map b
on a.concept_code = b.concept_code and (a.code_agg != b.code_agg or a.relationship_agg != b.relationship_agg)
order by a.concept_code
;

--02.6. Concepts changed their ancestry ('Is a')
with new_map as (
select a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from concept a
join concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Is a') and r.invalid_reason is null
join concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN (:your_vocabs) and a.invalid_reason is null
group by a.concept_code, a.concept_name
)
,
old_map as (
select a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from devv5. concept a
join devv5.concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Is a') and r.invalid_reason is null
join devv5.concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN (:your_vocabs) and a.invalid_reason is null
group by a.concept_code, a.concept_name
)
select a.concept_code as source_code,
       a.concept_name as source_name,
       a.relationship_agg as old_relat_agg,
       a.code_agg as old_code_agg,
       a.name_agg as old_name_agg,
       b.relationship_agg as new_relat_agg,
       b.code_agg as new_code_agg,
       b.name_agg as new_name_agg
from old_map  a
join new_map b
on a.concept_code = b.concept_code and (a.code_agg != b.code_agg or a.relationship_agg != b.relationship_agg)
order by a.concept_code
;

--02.7. Concepts with 1-to-many mapping -- multiple 'Maps to' present
select a.concept_code as concept_code_source,
       a.concept_name as concept_name_source,
       a.domain_id as domain_id_source,
       CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>'
           ELSE b.concept_name END as concept_name_target,
       CASE WHEN a.concept_id = b.concept_id THEN '<Mapped to itself>'
           ELSE b.vocabulary_id END as vocabulary_id_target
from concept a
join concept_relationship r
    on a.concept_id=r.concept_id_1
           and r.invalid_reason is null
           and r.relationship_Id ='Maps to'
join concept b
    on b.concept_id = r.concept_id_2
where a.vocabulary_id IN (:your_vocabs)
    --and a.concept_id != b.concept_id --use it to exclude mapping to itself
    and a.concept_id IN (
                            select a.concept_id
                            from concept a
                            join concept_relationship r
                                on a.concept_id=r.concept_id_1
                                       and r.invalid_reason is null
                                       and r.relationship_Id ='Maps to'
                            join concept b
                                on b.concept_id = r.concept_id_2
                            where a.vocabulary_id IN (:your_vocabs)
                                --and a.concept_id != b.concept_id --use it to exclude mapping to itself
                            group by a.concept_id
                            having count(*) > 1
    )
;