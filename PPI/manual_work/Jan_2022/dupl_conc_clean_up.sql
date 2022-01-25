--added new relationship, so lowercase concept will have a mapping
insert into concept_relationship_manual
select 'cope_a_202', c.concept_code, a.vocabulary_id, c.vocabulary_id, r.relationship_id, r.valid_start_date, r.valid_end_date, r.invalid_reason from concept a 
join concept_relationship r on a.concept_id = r.concept_id_1 and r.invalid_reason is null
join concept c on r.concept_id_2 = c.concept_id
where a.vocabulary_id ='PPI' and a.concept_code ='COPE_A_236' and ( c.concept_code, a.vocabulary_id, c.vocabulary_id, r.relationship_id) not in (
select  c.concept_code, a.vocabulary_id, c.vocabulary_id, r.relationship_id 
from concept a 
join concept_relationship r on a.concept_id = r.concept_id_1 and r.invalid_reason is null
join concept c on r.concept_id_2 = c.concept_id
where a.vocabulary_id ='PPI' and a.concept_code ='cope_a_236'
)
;
--added old relationships as Deprecated
insert into concept_relationship_manual
select a.concept_code, c.concept_code, a.vocabulary_id, c.vocabulary_id, r.relationship_id, r.valid_start_date, to_DATE ('2022-01-25','yyyy-MM-dd'), 'D' from devv5.concept a 
join devv5.concept_relationship r on a.concept_id = r.concept_id_1 and r.invalid_reason is null
join devv5.concept c on r.concept_id_2 = c.concept_id
where a.vocabulary_id ='PPI' and a.concept_code in ('COPE_A_236','COPE_A_202')
