--01. changed Domain
select old.concept_code,
       old.concept_name,
       old.concept_class_id,
       old.standard_concept,
       old.domain_id as old_domain_id,
       new.domain_id as new_domain_id
from devv5.concept old
join concept new using (concept_id) 
where old.domain_id != new.domain_id
;

--02. Domain of newly added concepts
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

--03. looking at new concepts and their mapping -- mapping absent
select a.concept_code, a.concept_name, a.domain_id , b.concept_name, b.vocabulary_id
 from concept a
left join concept_relationship r on a.concept_id= r.concept_id_1 and r.invalid_reason is null and r.relationship_Id ='Maps to'
left join concept  b on b.concept_id = r.concept_id_2
left join devv5.concept  c on c.concept_id = a.concept_id
where a.vocabulary_id ='<your_vocab>'
and c.concept_id is null and b.concept_id is null
;

--04. looking at new concepts and their mapping -- mapping present
select a.concept_code, a.concept_name, a.domain_id , b.concept_name, b.vocabulary_id
 from concept a
  join concept_relationship r on a.concept_id= r.concept_id_1 and r.invalid_reason is null and r.relationship_Id ='Maps to'
 join concept  b on b.concept_id = r.concept_id_2
left join devv5.concept  c on c.concept_id = a.concept_id
where a.vocabulary_id ='<your_vocab>'
and c.concept_id is null  
;

--05. looking at new concepts and their ancestry -- mapping absent
select a.concept_code, a.concept_name, a.concept_class_id, a.domain_id, b.concept_name, b.concept_class_id, b.vocabulary_id
from concept a
left join concept_relationship r on a.concept_id= r.concept_id_1 and r.invalid_reason is null and r.relationship_Id ='Is a'
left join concept b on b.concept_id = r.concept_id_2
left join devv5.concept  c on c.concept_id = a.concept_id
where a.vocabulary_id ='<your_vocab>'
and c.concept_id is null and b.concept_id is null
;

--06. looking at new concepts and their ancestry -- mapping present
select a.concept_code, a.concept_name, a.concept_class_id, a.domain_id, b.concept_name, b.concept_class_id, b.vocabulary_id
from concept a
join concept_relationship r on a.concept_id= r.concept_id_1 and r.invalid_reason is null and r.relationship_Id ='Is a'
join concept  b on b.concept_id = r.concept_id_2
left join devv5.concept  c on c.concept_id = a.concept_id
where a.vocabulary_id ='<your_vocab>'
and c.concept_id is null
;

--07. concepts changed their mapping
with new_map as (
select a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from concept a
join concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Maps to', 'Maps to value') and r.invalid_reason is null
join concept b on b.concept_id = concept_id_2
where a.vocabulary_id = '<your_vocab>' and a.invalid_reason is null
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
where a.vocabulary_id = '<your_vocab>' and a.invalid_reason is null
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

--08. concepts changed their ancestry
with new_map as (
select a.concept_code,
       a.concept_name,
       string_agg (r.relationship_id, '-' order by b.concept_code ) as relationship_agg,
       string_agg (b.concept_code, '-' order by b.concept_code ) as code_agg,
       string_agg (b.concept_name, '-/-' order by b.concept_code) as name_agg
from concept a
join concept_relationship r on a.concept_id = concept_id_1 and r.relationship_id in ('Is a') and r.invalid_reason is null
join concept b on b.concept_id = concept_id_2
where a.vocabulary_id = '<your_vocab>' and a.invalid_reason is null
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
where a.vocabulary_id = '<your_vocab>' and a.invalid_reason is null
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
