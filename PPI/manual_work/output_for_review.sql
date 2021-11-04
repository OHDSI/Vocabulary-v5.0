--new concepts
select * from concept 
where vocabulary_id ='PPI'
and concept_id not in (
select concept_id from devv5.concept where vocabulary_id ='PPI')
;
--new relationships
with new_c as
(
select * from concept 
where vocabulary_id ='PPI'
and concept_id not in (
select concept_id from devv5.concept where vocabulary_id ='PPI')
),
rel as (
select distinct r.* from concept_relationship r
join new_c on concept_id_2 = new_c.concept_id 
union
select distinct r.* from concept_relationship r
join new_c on concept_id_1 = new_c.concept_id 
)
select distinct rel.* from rel
