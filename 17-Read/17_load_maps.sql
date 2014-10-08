-- insert new records 
--find greatest possible concept_id in concept, to start next
--select MAX(t.concept_id)+1 INTO REST from  concept t; 

declare
 ex number;
begin
  select MAX(concept_id)  + 1 into ex from concept;
  If ex > 0 then
    begin
            execute immediate 'DROP SEQUENCE SEQ_CONCEPT';
      exception when others then
        null;
    end;
    execute immediate 'CREATE SEQUENCE SEQ_CONCEPT INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
  end if;
end;

commit; 

 
 --insert to concept from source_to_concept_map  
  insert into concept
select 
    seq_concept.nextval as concept_id,
  first_value(m.source_code_description) over  (partition by m.source_vocabulary_id, m.source_code order by length(m.source_code_description) desc) as concept_name,
    m.mapping_type as domain_code,
    cl.class_code as class_code,
   'Read' as vocabulary_code,     
    null as standard_concept,
  m.source_code as concept_code,
  to_date(substr(user, regexp_instr(user, '_[[:digit:]]')+1, 256),'yyyymmdd') as valid_start_date,
  to_date('20991231', 'YYYYMMDD') as valid_end_date,
  null as invalid_reason
from dev.source_to_concept_map m
join vocabulary_id_to_code v on v.vocabulary_id=m.source_vocabulary_id
left join dev.concept c on c.concept_id=m.target_concept_id
join class_old_to_new cl on cl.original=c.concept_class
where m.source_vocabulary_id = 17  -- vocabulary_id=10, 17 missing source_code_descriptions 
; 

commit; 

-- insert to concept_relationship from source_to_concept_map  
 insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_code,
  to_date(substr(user, regexp_instr(user, '_[[:digit:]]')+1, 256),'yyyymmdd') as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
  join vocabulary_id_to_code v1 on v1.vocabulary_id=m.source_vocabulary_id
join concepttmp src on src.vocabulary_code=v1.vocabulary_code and src.concept_code=m.source_code
join concepttmp trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null
;

commit;

-- deprecate records in prototype that are no longer in the list
update prototype.concept_relationship c set
-- set the valid_end_date to the previous day of the date in the release (part of the schema name)
  valid_end_date = to_date(substr(user, regexp_instr(user, '_[[:digit:]]')+1, 256),'yyyymmdd')-1,
  invalid_reason = 'D'
where not exists (
  select 1 from concept_relationship_stage d 
  where d.concept_id_2    = c.concept_id_2
)
  and c.valid_end_date = to_date('12312099','mmddyyyy')
  and c.valid_start_date < to_date(substr(user, regexp_instr(user, '_[[:digit:]]')+1, 256),'yyyymmdd')
  and c.source_vocabulary_code = 'Read'
  and c.concept_id_2 = 1
-- deprecate only if there is a replacement, otherwise leave intact
  and exists (
    select 1 from concept_relationship_stage d 
    where  d.concept_id_2 = c.concept_id_2
)
;

-- deprecate records in prototype that are no longer in the list
update prototype.concept c set
-- set the valid_end_date to the previous day of the date in the release (part of the schema name)
  valid_end_date = to_date(substr(user, regexp_instr(user, '_[[:digit:]]')+1, 256),'yyyymmdd')-1,
  invalid_reason = 'D'
where not exists (
  select 1 from concept_stage d 
  where d.concept_code          = c.concept_code 
    and d.vocabulary_code = c.vocabulary_code
)
  and c.valid_end_date = to_date('12312099','mmddyyyy')
  and c.valid_start_date < to_date(substr(user, regexp_instr(user, '_[[:digit:]]')+1, 256),'yyyymmdd')
  and c.vocabulary_code = 'Read'
-- deprecate only if there is a replacement, otherwise leave intact
  and exists (
    select 1 from concept d 
    where d.concept_code          = c.concept_code 
      and d.vocabulary_code = c.vocabulary_code
)
;
exit;
