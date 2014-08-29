-- Run this after 17_transform_row_maps.sql and before 17_load_maps.sql
select '1. Num Rec in stage' as scr, count(8) as cnt
from source_to_concept_map_stage c
where c.source_vocabulary_id in (17)
union all
select '2. Num Rec in DEV not deleted' as scr, count(8) as cnt
from dev.source_to_concept_map d
where d.source_vocabulary_id in (17)
  and d.target_vocabulary_id in (1)
  and nvl (d.invalid_reason, 'X') <> 'D'
union all
select '3. How many records would be new in DEV added' as scr, count(8) as cnt
from source_to_concept_map_stage c
where c.source_vocabulary_id in (17) and c.target_vocabulary_id in (1)
  and not exists (
    select 1
    from dev.source_to_concept_map d
    where d.source_vocabulary_id in (17)
      and c.source_code = d.source_code
      and d.source_vocabulary_id = c.source_vocabulary_id
      and d.mapping_type = c.mapping_type
      and d.target_concept_id = c.target_concept_id
      and d.target_vocabulary_id = c.target_vocabulary_id
  )
union all
select '4. How many DEV active will be marked for deletion' as scr, count(8) as cnt
from dev.source_to_concept_map d
where d.source_vocabulary_id in (17)
  and d.target_vocabulary_id in (1)
  and nvl (d.invalid_reason, 'X') <> 'D'
  and d.valid_start_date < to_date (substr (user, regexp_instr (user, '_[[:digit:]]') + 1, 256), 'yyyymmdd')
  and not exists (
    select 1
    from source_to_concept_map_stage c
    where c.source_vocabulary_id in (17)
    and c.source_code = d.source_code
    and d.source_vocabulary_id = c.source_vocabulary_id
    and d.mapping_type = c.mapping_type
    and d.target_concept_id = c.target_concept_id
    and d.target_vocabulary_id = c.target_vocabulary_id
  )
  and exists (
    select 1
    from source_to_concept_map_stage c
    where d.source_code = c.source_code
    and d.source_vocabulary_id = c.source_vocabulary_id
    and d.mapping_type = c.mapping_type
    and d.target_vocabulary_id = c.target_vocabulary_id
  )
;
