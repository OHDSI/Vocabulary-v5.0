--get the latest OMOP schema we need to align STCM with
use @newVocSchema
;
--create a copy of source_to_concept_map from that schema (previosly copied from the previous version schema)
drop table if exists @scratchSchema.source_to_concept_map
;
create table @scratchSchema.source_to_concept_map as select * from  @oldVocSchema.source_to_concept_map
;
--insert new target_concepts we got by using concepts replacing non-standard target_concepts

--possible problem: STCM doesn't support Maps to value mappings, which can be a case in theory
insert into @scratchSchema.source_to_concept_map
select source_code, source_concept_id, source_vocabulary_id, source_code_description , b.concept_id as target_concept_id, b.vocabulary_id as target_vocabulary_id, current_date as valid_start_date,
to_date ('2099-12-31', 'yyyy-MM-dd') as valid_end_date, null as invalid_reason
from @scratchSchema.source_to_concept_map s
join concept c on c.concept_id = s.target_concept_id and coalesce (c.standard_concept, 'C') = 'C' -- when it's null or C it is a mistake
join concept_relationship cr on cr.concept_id_1 = s.target_concept_id and cr.relationship_id = 'Maps to'
join concept b on b.concept_id = cr.concept_id_2
where s.target_concept_id !=0 and s.invalid_reason is null
--what if this mapping already exists
and not exists (select 1 from @scratchSchema.source_to_concept_map s2 where (s2.source_code, s2.source_vocabulary_id) = (s.source_code, s.source_vocabulary_id) and s2.target_concept_id = b.concept_id and s2.invalid_reason is null)
; --updated rows 5403

--update source_to_concept_map
--deprecate source_to_concept_map rows where it's possible to update them automatically by using query above
update @scratchSchema.source_to_concept_map s set invalid_reason ='D', valid_end_date =current_date where exists (
select 1 from concept c
join concept_relationship cr on cr.concept_id_1 = s.target_concept_id and cr.relationship_id = 'Maps to'
where s.target_concept_id !=0
and c.concept_id = s.target_concept_id and coalesce (c.standard_concept, 'C') = 'C' -- when it's null or C it is a mistake
)
and s.invalid_reason is null
--updated rows 5391, some concept was replaced by two concepts
;
drop table if exists @scratchSchema.drug_repl
;
--automated replacement of drugs if they become deprecated or non-standard, but don't have 'Maps to' relationship in the vocabulary
create table @scratchSchema.drug_repl as
with aaa as (
select distinct source_code,source_concept_id,source_vocabulary_id,source_code_description,coalesce (c.concept_id,c2.concept_id, c3.concept_id, c4.concept_id) as target_concept_id,
coalesce (c.vocabulary_id,c2.vocabulary_id, c3.vocabulary_id, c4.vocabulary_id)  as target_vocabulary_id,current_date as valid_start_date,s.valid_end_date,s.invalid_reason, s.target_concept_id as old_target_concept_id,
coalesce (c.concept_class_id,c2.concept_class_id, c3.concept_class_id, c4.concept_class_id)  as concept_class_id
from @scratchSchema.source_to_concept_map s
join concept c0 on c0.concept_id = s.target_concept_id and coalesce (c0.standard_concept, 'C') = 'C' -- when it's null or C it is a mistake
join concept_relationship r on r.concept_id_1 = s.target_concept_id and relationship_id in  ('Tradename of', 'RxNorm is a', 'RxNorm has ing', 'Has ingredient','Consists of',  'Maps to')
left join concept c on c.concept_id = r.concept_id_2 and c.vocabulary_id ='RxNorm' and c.standard_concept = 'S'
join concept_relationship r2 on r2.concept_id_1 = r.concept_id_2 and r2.relationship_id in ('Tradename of', 'RxNorm is a', 'RxNorm has ing', 'Has ingredient', 'Consists of',  'Maps to')
left join concept c2 on c2.concept_id = r2.concept_id_2 and c2.vocabulary_id ='RxNorm' and c2.standard_concept = 'S'
join concept_relationship r3 on r3.concept_id_1 = r2.concept_id_2 and r3.relationship_id in ('Tradename of', 'RxNorm is a', 'RxNorm has ing', 'Has ingredient', 'Consists of',  'Maps to')
left join concept c3 on c3.concept_id = r3.concept_id_2 and c3.vocabulary_id ='RxNorm' and c3.standard_concept = 'S'
join concept_relationship r4 on r4.concept_id_1 = r3.concept_id_2 and r4.relationship_id in ('Tradename of', 'RxNorm is a', 'RxNorm has ing', 'Has ingredient', 'Consists of',  'Maps to')
left join concept c4 on c4.concept_id = r4.concept_id_2 and c4.vocabulary_id ='RxNorm' and c4.standard_concept = 'S'
where s.target_concept_id !=0 and s.invalid_reason is null
and s.invalid_reason is null
and coalesce (c.concept_id,c2.concept_id, c3.concept_id, c4.concept_id) is not null
)
select * from (
select *, min(concept_class_id) over (partition by old_target_concept_id) as best_class from  aaa) a where concept_class_id =best_class
;
insert into @scratchSchema.source_to_concept_map
select source_code,source_concept_id,source_vocabulary_id,source_code_description,target_concept_id,target_vocabulary_id,valid_start_date,valid_end_date,invalid_reason from @scratchSchema.drug_repl d
--what if this mapping already exists
where not exists (select 1 from source_to_concept_map s2 where (s2.source_code, s2.source_vocabulary_id) = (d.source_code, d.source_vocabulary_id) and s2.target_concept_id = d.target_concept_id and s2.invalid_reason is null)
;
--deprecate old STCM mappings that got new mappings by the previous step
update @scratchSchema.source_to_concept_map s set invalid_reason ='D', valid_end_date = current_date where exists (select 1 from  @scratchSchema.drug_repl where s.target_concept_id = old_target_concept_id)
and invalid_reason is null
;
