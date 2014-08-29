-- Mark records that exist in dev.source_to_concept_map (except description)
update source_to_concept_map_stage d
set source_to_concept_map_id = (
  select 1 from dev.source_to_concept_map c
  where d.source_code = c.source_code 
    and d.source_vocabulary_id = c.source_vocabulary_id
--    and d.mapping_type = c.mapping_type
    and d.target_concept_id = c.target_concept_id
    and d.target_vocabulary_id = c.target_vocabulary_id
    and nvl(d.primary_map,'X') = nvl(c.primary_map, 'X')
    and nvl(c.invalid_reason,'X') <> 'D'
)
;

-- deprecate records in dev that are no longer in the list
update dev.source_to_concept_map c set
-- set the valid_end_date to the previous day of the date in the release (part of the schema name)
  valid_end_date = to_date(substr(user, regexp_instr(user, '_[[:digit:]]')+1, 256),'yyyymmdd')-1,
  invalid_reason = 'D'
where not exists (
  select 1 from source_to_concept_map_stage d 
  where d.source_code          = c.source_code 
    and d.source_vocabulary_id = c.source_vocabulary_id
 --   and d.mapping_type         = c.mapping_type
    and d.target_concept_id    = c.target_concept_id
    and d.target_vocabulary_id = c.target_vocabulary_id
    and nvl(d.primary_map,'X') =  nvl(c.primary_map,'X')
)
  and c.valid_end_date = to_date('12312099','mmddyyyy')
  and c.valid_start_date < to_date(substr(user, regexp_instr(user, '_[[:digit:]]')+1, 256),'yyyymmdd')
  and c.source_vocabulary_id = 17
  and c.target_vocabulary_id = 1
-- deprecate only if there is a replacement, otherwise leave intact
  and exists (
    select 1 from source_to_concept_map_stage d 
    where d.source_code          = c.source_code 
      and d.source_vocabulary_id = c.source_vocabulary_id
  --    and d.mapping_type         = c.mapping_type
      and d.target_vocabulary_id = c.target_vocabulary_id
)
;

-- insert new records 
insert into dev.source_to_concept_map
select distinct 
  source_code,
  17 as source_vocabulary_id,
  source_code_description, 
  target_concept_id,
  target_vocabulary_id,
  mapping_type, 
  'Y' as primary_map,
  to_date(substr(user, regexp_instr(user, '_[[:digit:]]')+1, 256),'yyyymmdd') as valid_start_date,
  -- to_date('19700101','yyyymmdd') as valid_start_date,
  to_date('12312099','mmddyyyy') as valid_end_date,
  null as invalid_reason
from    source_to_concept_map_stage
where   1 = 1
-- new ones are marked
  and source_to_concept_map_id is null
;

-- Update descriptions (don't usually run)
update dev.save17 m 
set m.source_code_description = (
  select distinct coalesce(v2.description_long, v2.description, v2.description_short)
  from keyv2 v2
  where v2.readcode||v2.termcode = m.source_code 
)
where m.source_vocabulary_id=17
;

commit;
exit;
