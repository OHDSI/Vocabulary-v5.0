spool 17_transform_row_maps.log;

-- Create temporary table for uploading concept. 
truncate table concept_stage;
truncate table concept_relationship_stage;

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

-- create new stage
insert into concept_stage
select 
  seq_concept.nextval as concept_id,
  coalense(v2.description_long, v2.description, v2.description_short) as concept_name
  'XXX' as domain_code, -- ??  
  null as class_code,
  'Read' as vocabulary_code,
  null as standart_concept, 
  v2.readcode||v2.termcode as concept_code,
  --don't need it
  to_date(substr(user, regexp_instr(user, '_[[:digit:]]')+1, 256),'yyyymmdd') as valid_start_date,
  to_date('12312099','mmddyyyy') as valid_end_date,
  null as invalid reason
from from rcsctmap2_uk m, keyv2 v2 

;

insert into concept_relationship_stage
select 
  c.concept as concept_id_1,
  --coalesce(mapped.target_concept_id, 0) as  concept_id_2,
  c.concept_id as concept_id_2,
  'Maps to' as relationship_code,
  to_date(substr(user, regexp_instr(user, '_[[:digit:]]')+1, 256),'yyyymmdd') as valid_start_date,
  to_date('12312099','mmddyyyy') as valid_end_date,
  m.invalid_reason
from rcsctmap2_uk m
  left join dev.concept c on m.conceptid=c.concept_code and c.vocabulary_code='SNOMED'
;

--update concept_stage y set y.domain_code=(select domain_code from
--dev.concept c on m.conceptid=c.concept_code and c.vocabulary_code='SNOMED')

--;
/*
update concept read set read.domain_code=(select snomed.domain_code from
dev.concept snomed, concept_relationship_stage r where snomed.vocabulary_code='SNOMED' 
--and snomed.concept_id=r.concept_id_1
and r.concept_id_2=read.concept_id)
where exists (select 1 from concept_relationship_stage where concept_id_2=read.concept_id)
and read.vocabulary_code='READ'
*/

-- Remap when target_concept_id is obsolete
drop table historical_tree;

create table historical_tree as 
select root, concept_id_2 from (
  select root, concept_id_2, dt,  row_number() over (partition by  root order by dt desc) rn
    from (
      select rownum rn, level lv, lpad(' ', 8 * level) || c1.concept_name||'-->'||c2.concept_name tree, r.concept_id_1, r.concept_id_2, r.relationship_id,
        r.valid_start_date dt,
        c1.concept_code ||'-->'||c2.concept_code  tree_code,
        c1.vocabulary_id||'-->'||c2.vocabulary_id tree_voc,
        c1.concept_level||'-->'||c2.concept_level tree_lv,
        c1.concept_class||'-->'||c2.concept_class tree_cl,
        connect_by_iscycle iscy,
        connect_by_root concept_id_1 root,
        connect_by_isleaf lf
      from  concept_relationship r, relationship rt, concept c1, concept c2
      where 1 = 1
        and rt.relationship_id = r.relationship_id  and r.relationship_id in (311, 349, 351, 353, 355) -- SNOMED update relationships
        and nvl(r.invalid_reason, 'X') <> 'D'
        and c1.concept_id = r.concept_id_1
        and c2.concept_id = r.concept_id_2
      connect by  
      nocycle  
      prior r.concept_id_2 = r.concept_id_1
        and rt.relationship_id = r.relationship_id  and r.relationship_id in (311, 349, 351, 353, 355)
        and nvl(r.invalid_reason, 'X') <> 'D'
      start with rt.relationship_id = r.relationship_id  and r.relationship_id in (311, 349, 351, 353, 355)
      and nvl(r.invalid_reason, 'X') <> 'D'
    ) sou 
) where rn = 1
;

create index x_hi_tree on historical_tree (root);

update concept_relationship_stage m
set concept_id_2 = (select concept_id_2 from historical_tree t where m.target_concept_id = t.root )
where exists (select 1 from historical_tree tt where m.target_concept_id = tt.root )
;
----- end remap --
commit;
exit;
