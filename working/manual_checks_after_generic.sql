--01. Concept changes
--01.1. Concepts changed their Domain
select new.concept_id,
       new.concept_code,
       new.concept_name as concept_name,
       new.concept_class_id as concept_class_id,
       new.standard_concept as standard_concept,
       new.vocabulary_id as vocabulary_id,
       old.domain_id as old_domain_id,
       new.domain_id as new_domain_id
from concept new
join devv5.concept old
    using (concept_id)
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

--02.5. concepts changed their mapping ('Maps to'), this includes 2 scenarios: mapping changed; mapping present in one version, absent in another;
--to detect the absent mappings cases, sort by the respective code_agg to get the NULL values first.
with new_map as (
select a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from concept a
left join concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Maps to', 'Maps to value') and r.invalid_reason is null
left join concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN (:your_vocabs)
    --and a.invalid_reason is null --to exclude invalid concepts
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
left join devv5.concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Maps to', 'Maps to value') and r.invalid_reason is null
left join devv5.concept b on b.concept_id = concept_id_2
where a.vocabulary_id IN (:your_vocabs)
    --and a.invalid_reason is null --to exclude invalid concepts
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
on a.concept_code = b.concept_code and (coalesce (a.code_agg, '') != coalesce (b.code_agg, '') or coalesce (a.relationship_agg, '') != coalesce (b.relationship_agg, ''))
order by a.concept_code
;

--02.6. Concepts changed their ancestry ('Is a'), this includes 2 scenarios: Ancestor(s) changed; ancestor(s) present in one version, absent in another;
--to detect the absent ancestry cases, sort by the respective code_agg to get the NULL values first.
with new_map as (
select a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from concept a
left join concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Is a') and r.invalid_reason is null
left join concept b on b.concept_id = concept_id_2
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
left join devv5.concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Is a') and r.invalid_reason is null
left join devv5.concept b on b.concept_id = concept_id_2
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
on a.concept_code = b.concept_code and (coalesce (a.code_agg, '') != coalesce (b.code_agg, '') or coalesce (a.relationship_agg, '') != coalesce (b.relationship_agg, ''))
order by a.concept_code
;

--02.7. Concepts with 1-to-many mapping -- multiple 'Maps to' present
select a.concept_code as concept_code_source,
       a.concept_name as concept_name_source,
       a.domain_id as domain_id_source,
       b.concept_code as concept_code_target,
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

--02.8. Concepts became non-Standard with no mapping replacement
select a.concept_code,
       a.concept_name,
       a.concept_class_id,
       a.domain_id,
       a.vocabulary_id
from concept a
join devv5.concept b
        on a.concept_id = b.concept_id
where a.vocabulary_id IN (:your_vocabs)
    and b.standard_concept = 'S'
    and a.standard_concept IS NULL
    and not exists (
                    SELECT 1
                    FROM concept_relationship cr
                    WHERE a.concept_id = cr.concept_id_1
                        AND cr.relationship_id = 'Maps to'
                        AND cr.invalid_reason IS NULL
    )
;

--02.9. Concepts are presented in CRM with "Maps to" link, but end up with no valid "Maps to"
SELECT *
FROM concept c
WHERE c.vocabulary_id IN (:your_vocabs)
    AND EXISTS (SELECT 1
                FROM concept_relationship_manual crm
                WHERE c.concept_code = crm.concept_code_1
                    AND c.vocabulary_id = crm.vocabulary_id_1
                    AND crm.relationship_id = 'Maps to')
AND NOT EXISTS (SELECT 1
                FROM concept_relationship cr
                WHERE c.concept_id = cr.concept_id_1
                    AND cr.relationship_id = 'Maps to'
                    AND cr.invalid_reason IS NULL)
;

--02.10. Mapping of vaccines (please move to the project-specific QA folder and adjust vaccine_exclusion in there)
with vaccine_exclusion as (SELECT
    'placeholder|placeholder' as vaccine_exclusion
    )

select distinct c.concept_name, c.concept_class_id, b.concept_name, b.concept_class_id, b.vocabulary_id
from concept c
left join concept_relationship cr on cr.concept_id_1 = c.concept_id and relationship_id ='Maps to' and cr.invalid_reason is null
left join concept b on b.concept_id = cr.concept_id_2
where c.vocabulary_id IN (:your_vocabs)

    and ((c.concept_name ~* (select vaccine_inclusion from dev_rxe.vaccine_inclusion) and c.concept_name !~* (select vaccine_exclusion from vaccine_exclusion))
        or
        (b.concept_name ~* (select vaccine_inclusion from dev_rxe.vaccine_inclusion) and b.concept_name !~* (select vaccine_exclusion from vaccine_exclusion)))
;

--02.11. Mapping of covid concepts (please adjust inclusion/exclusion in the master branch if found something)
with covid_inclusion as (SELECT
    'sars(?!(tedt|aparilla))|^cov(?!(er|onia|aWound|idien))|cov$|^ncov|ncov$|corona(?!(l|ry))|severe acute|covid(?!ien)' as covid_inclusion
    ),

covid_exclusion as (SELECT
    '( |^)LASSARS' as covid_exclusion
    )


select distinct c.concept_name, c.concept_class_id, b.concept_name, b.concept_class_id, b.vocabulary_id
from concept c
left join concept_relationship cr on cr.concept_id_1 = c.concept_id and relationship_id ='Maps to' and cr.invalid_reason is null
left join concept b on b.concept_id = cr.concept_id_2
where c.vocabulary_id IN (:your_vocabs)

    and ((c.concept_name ~* (select covid_inclusion from covid_inclusion) and c.concept_name !~* (select covid_exclusion from covid_exclusion))
        or
        (b.concept_name ~* (select covid_inclusion from covid_inclusion) and b.concept_name !~* (select covid_exclusion from covid_exclusion)))
;