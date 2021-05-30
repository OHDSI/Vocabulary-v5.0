--01. LOINC concepts changed their SNOMED ancestry
with new_map as (
select a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from concept a
join concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Is a') and r.invalid_reason is null
join concept b on b.concept_id = concept_id_2 and b.vocabulary_id = 'SNOMED'
where a.vocabulary_id = 'LOINC' and a.invalid_reason is null
group by a.concept_code, a.concept_name
)
,
old_map as (
select a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from devv5.concept a
join devv5.concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Is a') and r.invalid_reason is null
join devv5.concept b on b.concept_id = concept_id_2 and b.vocabulary_id = 'SNOMED'
where a.vocabulary_id = 'LOINC' and a.invalid_reason is null
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