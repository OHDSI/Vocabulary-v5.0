drop table ICD10_mapp_for_lena_24112016;
create table ICD10_mapp_for_lena_24112016 as
 
 select distinct a.concept_code, a.concept_name, 
 
nvl (c.concept_name, b.concept_name) as exist_ICD_name, nvl ( b.vocabulary_id, c.vocabulary_id) as exist_ICD_vocab_id,
 nvl ( b.relationship_id,c.relationship_id) as relationship_id  ,nvl (b.target_code, c.target_code) as target_code, nvl (b.target_name, c.target_name) as target_name, nvl (b.target_concept_class_id, c.target_concept_class_id) as target_concept_class_id
 ,
  UTL_MATCH.JARO_WINKLER_SIMILARITY (a.concept_name , b.concept_name) as JARO_WINKLER_SIMIL, 
UTL_MATCH.EDIT_DISTANCE_SIMILARITY (a.concept_name , b.concept_name) as EDIT_DISTANCE_SIMIL, 
UTL_MATCH.EDIT_DISTANCE(a.concept_name , b.concept_name) as EDIT_DISTANCE,

case when lower (a.concept_name) = lower(b.concept_name) then 'same_name' when (a.concept_name) != lower(b.concept_name) then 'different_name' else null end as name_equality
 from concept_stage a
 left join 
 (select a.concept_code, a.concept_name, a.vocabulary_id, relationship_id, c.concept_code as target_code, c.concept_name as  target_name,c.concept_class_id as target_concept_class_id
 from devv5.concept a 
 join devv5.concept_relationship b on b.concept_id_1 = a.concept_id
join devv5.concept c on c.concept_id = b.concept_id_2 and c.vocabulary_id = 'SNOMED' and b.invalid_reason is null 
where  a.vocabulary_id = 'ICD10CM' and b.invalid_reason is null and c.invalid_reason is null 
) 
b on a.concept_code = b.concept_code
left join 
(
select a.concept_code, a.concept_name,  a.vocabulary_id,  relationship_id, c.concept_code as target_code, c.concept_name as  target_name,c.concept_class_id as target_concept_class_id
 from devv5.concept a 
 join devv5.concept_relationship b on b.concept_id_1 = a.concept_id
join devv5.concept c on c.concept_id = b.concept_id_2 and c.vocabulary_id = 'SNOMED' and b.invalid_reason is null 
where  a.vocabulary_id = 'ICD10' and b.invalid_reason is null and c.invalid_reason is null 
) c on a.concept_code = c.concept_code
;
 select * from ICD10_mapp_for_lena_24112016 -- gave it to medical coder
;