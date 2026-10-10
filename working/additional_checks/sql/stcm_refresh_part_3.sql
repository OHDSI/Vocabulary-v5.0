use @newVocSchema
;
--STCM manual is ready, continue this later
--once we get the table for mapping, we don't need to track Invalid_reason, so all these rows in STCM can be deprecated
update @scratchSchema.source_to_concept_map s
set invalid_reason ='D', valid_end_date = current_date where exists (select 1 from concept c where c.concept_id = s.target_concept_id and coalesce (c.standard_concept, 'C') = 'C' )
and s.target_concept_id !=0
and s.invalid_reason is null
;
--deprecate STCM rows where source_concept exists in the manaul table but the target concept is different,
--note, if  a source concept has several mappings, and you want to update one of them, please put all mappings (even those you don't touch) in this manual table
--run for 17 minutes first time, for seconds later
update @scratchSchema.source_to_concept_map s
set invalid_reason ='D', valid_end_date = current_date where exists (select 1 from  @scratchSchema.STCM_manual m where m.source_code::varchar =s.source_code and  m.source_vocabulary_id =  s.source_vocabulary_id )
and not exists (select 1 from  @scratchSchema.STCM_manual m where m.source_code::varchar =s.source_code and  m.source_vocabulary_id =  s.source_vocabulary_id and s.target_concept_id = m.target_concept_id )
and s.invalid_reason is null
;
--add mappings made manualy
insert into @scratchSchema.source_to_concept_map
select distinct m.source_code,m.source_concept_id,m.source_vocabulary_id,m.source_code_description, m.target_concept_id, m.target_vocabulary_id,current_date as valid_start_date,to_date ('20991231', 'yyyyMMdd') as valid_end_date
,null as invalid_reason
from @scratchSchema.STCM_manual m
--if the mapping already exist we don't add it
-- case when we revive mapping will result in a new row creation with different dates, so it's should be fine
where not exists (select 1 from @scratchSchema.source_to_concept_map s2 where m.source_code::varchar =s2.source_code and  m.source_vocabulary_id =  s2.source_vocabulary_id and s2.target_concept_id = m.target_concept_id
and s2.invalid_reason is null)
;
--deprecate mappings to 0 if meaningful mapping exists but the case of source codes is different
update @scratchSchema.source_to_concept_map a
set invalid_reason = 'D', valid_end_date = current_date where exists (
select 1
from @scratchSchema.source_to_concept_map b
join concept c on c.concept_id = b.target_concept_id and c.standard_concept ='S'
where a.source_vocabulary_id ='JNJ_UNITS' and b.source_vocabulary_id ='JNJ_UNITS'  and a.target_concept_id =0 and a.invalid_reason is null
and upper (a.source_code) = upper (b.source_code) and b.target_concept_id !=0
)
;
