--insert to concept from dev.concept  
insert into concept (
  concept_id,  concept_name,  domain_code,  class_code,  vocabulary_code,  standard_concept,  concept_code,  valid_start_date,  valid_end_date,  invalid_reason
)  
select c.concept_id,
  c.concept_name, 
  case 
    when vocabulary_id=1 then case -- SNOMED
      when d.domain_code is not null then d.domain_code -- available only for active concepts
      when c.concept_class='Clinical finding' then 'Condition'
      when c.concept_class='Procedure'then 'Procedure'
      when c.concept_class='Pharmaceutical / biological product' then 'Drug'
      when c.concept_class='Physical object' then 'Device'
      when c.concept_class='Model component' then 'Metadata'
      else 'Observation' end
  when vocabulary_id=11 then case -- remove old classes (only exists in deprecated concepts)
    when c.concept_class in ('UCUM Custom', 'UCUM Standard') then 'UCUM'
    else d.domain_code end
12
13
14
15
19
20
21
22
24
28
31
32
33
36
37
38
39
40
41
42
43
44
45
47
48
49
54
55
57
58
59
60
61
62
63
64
65
66
67
68

  cl.class_code,
  v.vocabulary_code,
  case when c.concept_level=0 then 'S' else null end as standard_concept,   
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_id_to_code v on v.vocabulary_id=c.vocabulary_id
left join class_old_to_new cl on cl.original=c.concept_class
;


select distinct vocabulary_id from dev.concept order by 1;

commit;

--insert to concept_relationship from concept_relationship  
insert into concept_relationship(
CONCEPT_ID_1,
CONCEPT_ID_2,
RELATIONSHIP_CODE,
VALID_START_DATE,
VALID_END_DATE,
INVALID_REASON) 
  select c.concept_id_1,
  c.concept_id_2, 
  v.relationship_code, 
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept_relationship c
join relationship_id_to_code v on v.relationship_id=c.relationship_id
;

insert into concept_ancestor select * from dev.concept_ancestor;
--delete absent concept_id (which exist in dev.concept and don't in prototype.concept)

--find greatest possible concept_id in concept, to start next
select t.concept_id from concept t order by t.concept_id desc;
 
--drop sequence SEQ_CONCEPT;
create sequence SEQ_CONCEPT
minvalue 1
maxvalue 9999999999999999999999999999
start with 
44818714 --take result from select t.concept_id from concept t order by t.concept_id desc; plus one 
increment by 1
cache 20;

commit; 

-- Create local copy of stcm whithout mapping_type for 0 and MedDRA 
-- drop table source_to_concept_map;
create table source_to_concept_map as
select 
  source_code, source_vocabulary_id, source_code_description, target_concept_id, 
  case 
    when invalid_reason is not null then null
    when mapping_type in ('MedDRA', 'Unmapped', 'Indication') then null
    else mapping_type 
  end as mapping_type,
  valid_start_date, valid_end_date, invalid_reason  
from dev.source_to_concept_map;
 
 --insert to concept from source_to_concept_map  
insert into concept;
select * from (
-- select domain_code, class_code, count(8) from (
  select distinct 
    1 as concept_id, --seq_concept.nextval as concept_id,
    first_value(m.source_code_description) over (partition by m.source_vocabulary_id, m.source_code order by length(m.source_code_description) desc) as concept_name,
    case 
      when count(distinct m.mapping_type) over (partition by m.source_vocabulary_id, m.source_code)>1 then 'Mixed'
      else coalesce(first_value(m.mapping_type ignore nulls) over (partition by m.source_vocabulary_id, m.source_code), case
        when source_vocabulary_id=9 then 'Drug'
        else 'null-domain'
      end)
    end as domain_code,
  -- class codes for new concepts
    case 
      when m.source_vocabulary_id=2 then -- ICD-9-CM
        case
          when substr(m.source_code, 1, 1)='V' then 'V code'
          when substr(m.source_code, 1, 1)='E' then 'E code'
          else 'Diagnosis code'
        end
      when m.source_vocabulary_id=9 then -- NDC
        case 
          when length(m.source_code)=11 then '11-digit NDC'
          when length(m.source_code)=9 then '9-digit NDC'
          else 'NDC'
        end
      when m.source_vocabulary_id=10 then -- GPI
        case
          when m.target_concept_id=0 then 'Drug'
          else c1.class_code
        end 
      when m.source_vocabulary_id=16 then -- Multum
        case
          when m.target_concept_id=0 then 'Drug'
          else c1.class_code
        end 
      when m.source_vocabulary_id=17 then -- Read
        case
          when m.target_concept_id=0 then 'Condition'
          else first_value(m.mapping_type) over (partition by m.source_vocabulary_id, m.source_code order by decode(m.mapping_type, 
            'Condition', 1, 'Observation', 2, 'Procedure', 3, 'Race', 4, 'Provider', 5, 'Device', 6, 'Drug', 7, 'Measurement', 8, 10))
        end 
      when m.source_vocabulary_id=18 then -- Oxmis
        case
          when m.target_concept_id=0 then 'Condition'
          else first_value(m.mapping_type) over (partition by m.source_vocabulary_id, m.source_code order by decode(m.mapping_type, 
            'Condition', 1, 'Procedure', 2, 'Observation', 3, 'Measurement', 4, 'Device', 5, 10))
        end 
      when m.source_vocabulary_id=28 then -- VA Product
        case
          when m.target_concept_id=0 then 'Drug'
          else c1.class_code
        end
      when m.source_vocabulary_id=34 then  -- ICD-10-CM
        case
          when m.target_concept_id=0 then 'Condition'
          else first_value(m.mapping_type) over (partition by m.source_vocabulary_id, m.source_code order by decode(m.mapping_type, 
            'Condition', 1, 'Observation', 2, 'Procedure', 3, 10))
        end
      when m.source_vocabulary_id=35 then 'Procedure' -- ICD-10-PCS
      when m.source_vocabulary_id=46  then -- NLM Mesh
        case
          when m.target_concept_id=0 then 'Condition'
          else first_value(m.mapping_type) over (partition by m.source_vocabulary_id, m.source_code order by decode(m.mapping_type, 
            'Condition', 1, 'Drug', 2, 'Procedure', 3, 'Measurement', 4, 'Observation', 5, 10))
        end 
      when m.source_vocabulary_id=50 then -- FDA SPL
        case
          when m.target_concept_id=0 then 'Drug'
          else c1.class_code
        end 
      when m.source_vocabulary_id=53 then --  FDB Genseqno
        case
          when m.target_concept_id=0 then 'Drug'
          else c1.class_code
        end 
      when m.source_vocabulary_id=56 then -- Gemscript
        case
          when m.target_concept_id=0 then 'Drug'
          else c1.class_code
        end 
      else c1.class_code end
    as class_code,  
    v.vocabulary_code as vocabulary_code,
    null as standard_concept,
    m.source_code as concept_code,
    to_date('19700101', 'YYYYMMDD') as valid_start_date,
    to_date('20991231', 'YYYYMMDD') as valid_end_date,
    null as invalid_reason
  from source_to_concept_map m
  join vocabulary_id_to_code v on v.vocabulary_id=m.source_vocabulary_id
  left join dev.concept c on c.concept_id=m.target_concept_id
  left join class_old_to_new c1 on c1.original=c.concept_class
  where m.source_vocabulary_id in (2)  -- vocabulary_id=10, 17 missing source_code_descriptions 
  -- where m.source_vocabulary_id in (2, 9, 10, 16, 17, 18, 34, 35, 46, 50, 53, 56)  -- vocabulary_id=10, 17 missing source_code_descriptions 
)
where domain_code='null-domain'
--group by domain_code, class_code
;

select * from dev.source_to_concept_map where source_code='883';
select * from dev.concept where concept_id=36211308;
select * from dev.concept_domain where concept_id=441226;
commit; 

select * from dev.source_to_concept_map m where not exists (select 1 from dev.concept c where m.target_concept_id=c.concept_id);

-- insert to concept_relationship from source_to_concept_map  
 insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_code,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
  join vocabulary_id_to_code v1 on v1.vocabulary_id=m.source_vocabulary_id
join concepttmp src on src.vocabulary_code=v1.vocabulary_code and src.concept_code=m.source_code
join concepttmp trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null
;
