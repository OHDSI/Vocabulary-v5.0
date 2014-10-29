/************************************************/
/* Create conversion tables                     */
/************************************************/

create table relationship_conversion (
  relationship_id number,
  relationship_id_new varchar(20)
);
-- SQLLDER using relationship_conversion.ctl

create table vocabulary_conversion (
  vocabulary_id_v4 number,
  vocabulary_id_v5 varchar(20),
  omop_req varchar(1), -- whether the vocabulary belongs to a metadata group created by OMOP
  click_default varchar(1), -- whether the vocabulary should be clicked as default
  available varchar(25) -- whether the vocabulary requires a license
);
-- SQLLDR using vocabulary_conversion.ctl

create table concept_class_conversion (
  concept_class varchar(50),
  concept_class_id_new varchar(20)
);
-- SQLLDR using concept_class_conversion.ctl
;

/************************************************/
/* Create all combinations of mapping types     */
/************************************************/

-- drop table mapping_types;
create table mapping_types as 
select 
  source_vocabulary_id, source_code,
  rtrim(mapping_type, '/') m_types
from ( 
  select source_vocabulary_id, source_code, mapping_type, rn
  from (
    select distinct source_vocabulary_id, source_code, mapping_type from dev.source_to_concept_map 
    where mapping_type not in ('MedDRA', 'Unmapped', 'Indication') and invalid_reason is null
  )
  model partition by (source_vocabulary_id, source_code) dimension by (row_number() over (partition by source_vocabulary_id, source_code order by mapping_type) rn)
    measures (mapping_type, cast(null as varchar2(100)) m_types)
    rules (
      mapping_type[any] order by rn desc = mapping_type[cv()]||'/'||mapping_type[cv()+1]
    )
)
where rn = 1
;

/************************************************/
/* Create all combinations of Read domains      */
/************************************************/

-- drop table read_domains;
create table read_domains as 
select 
  source_code,
  rtrim(mapping_type, '/') m_types
from ( 
  select source_code, mapping_type, rn
  from (
    select distinct source_code, mapping_type from dev.source_to_concept_map 
    where source_vocabulary_id=17 and mapping_type!='Unmapped'
    union
    select distinct substr(source_code, 1, 6) as source_code, mapping_type from dev.source_to_concept_map 
    where source_vocabulary_id=17 and mapping_type!='Unmapped'
    union
    select distinct substr(source_code, 1, 5) as source_code, mapping_type from dev.source_to_concept_map 
    where source_vocabulary_id=17 and mapping_type!='Unmapped'
    union
    select distinct substr(source_code, 1, 4) as source_code, mapping_type from dev.source_to_concept_map 
    where source_vocabulary_id=17 and mapping_type!='Unmapped'
    union
    select distinct substr(source_code, 1, 3) as source_code, mapping_type from dev.source_to_concept_map 
    where source_vocabulary_id=17 and mapping_type!='Unmapped'
  )
  model partition by (source_code) dimension by (row_number() over (partition by source_code order by mapping_type) rn)
    measures (mapping_type, cast(null as varchar2(100)) m_types)
    rules (
      mapping_type[any] order by rn desc = mapping_type[cv()]||'/'||mapping_type[cv()+1]
    )
)
where rn = 1
;

update read_domains set m_types='Condition/Drug' where m_types='Condition/Drug';
update read_domains set m_types='Condition/Measurement' where m_types='Condition/Measurement';
update read_domains set m_types='Condition/Measurement' where m_types='Condition/Measurement/Observation';
update read_domains set m_types='Condition' where m_types='Condition/Observation';
update read_domains set m_types='Condition/Procedure' where m_types='Condition/Observation/Procedure';
update read_domains set m_types='Condition/Procedure' where m_types='Condition/Procedure';
update read_domains set m_types='Device/Drug' where m_types='Device/Drug';
update read_domains set m_types='Device/Procedure' where m_types='Device/Observation/Procedure';
update read_domains set m_types='Device/Procedure' where m_types='Device/Procedure';
update read_domains set m_types='Drug/Measurement' where m_types='Drug/Measurement';
update read_domains set m_types='Drug/Measurement' where m_types='Drug/Measurement/Observation';
update read_domains set m_types='Drug/Observation' where m_types='Drug/Observation';
update read_domains set m_types='Drug/Procedure' where m_types='Drug/Observation/Procedure';
update read_domains set m_types='Drug/Procedure' where m_types='Drug/Procedure';
update read_domains set m_types='Measurement' where m_types='Measurement/Observation';
update read_domains set m_types='Procedure' where m_types='Measurement/Observation/Procedure';
update read_domains set m_types='Procedure' where m_types='Measurement/Procedure';
update read_domains set m_types='Procedure' where m_types='Observation/Procedure';
update read_domains set m_types='Provider specialty' where m_types='Observation/Provider';
update read_domains set m_types='Provider specialty' where m_types='Provider';
update read_domains set m_types='Race' where m_types='Observation/Race';
update read_domains set m_types='Procedure' where m_types='Procedure/Provider';


/************************************************/
/* Set new sequence                             */
/************************************************/
-- drop sequence v5_concept;
create sequence v5_concept
  minvalue 44819300
  maxvalue 500000000
  start with 44819300
  increment by 1
;

/************************************************/
/* Write new concepts and concept_relationships */
/************************************************/

-- truncate table concept;
-- truncate table concept_relationship;

-- Insert to concept_relationship all existing relationships from dev.concept_relationship  
insert /*+ append */ into concept_relationship (
  concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason
)
select * from (
  select 
    c.concept_id_1,
    c.concept_id_2, 
    v.relationship_id_new as relationship_id,
    c.valid_start_date,
    c.valid_end_date,
    c.invalid_reason
  from dev.concept_relationship c
  left join relationship_conversion v on v.relationship_id=c.relationship_id
) where relationship_id is not null
;

commit;

-- Vocabulary 0 - No information
insert into concept
select 
  c.concept_id,
  c.concept_name, 
  'Metadata' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  cl.concept_class_id_new as concept_class_id,
  'S' as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=0
;

-- Vocabulary 1 - SNOMED
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  c.concept_name, 
  case
    when d.domain_id is not null then d.domain_id -- available only for active concepts
    when cd.domain_name='Provider' and c.concept_class='Environment or geographical location' then 'Place of Service'
    when cd.domain_name='Provider' and c.concept_class='Social context' then 'Provider Specialty'
    when cd.domain_name='Race' then 'Race'
    when c.concept_class='Clinical finding' then 'Condition'
    when c.concept_class='Procedure'then 'Procedure'
    when c.concept_class='Pharmaceutical / biological product' then 'Drug'
    when c.concept_class='Physical object' then 'Device'
    when c.concept_class='Model component' then 'Metadata'
    else 'Observation' 
  end as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  cl.concept_class_id_new as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    when d.domain_id='Metadata' then null 
    when d.domain_id='Drug' then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
left join dev.concept_domain cd on cd.concept_id=c.concept_id
where c.vocabulary_id=1
;

-- Vocabulary 2 - ICD9CM
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  v5_concept.nextval as concept_id, newconcept.*
from (
  select distinct
    -- pick the longest source_code_description
    first_value(m.source_code_description) over (partition by m.source_code order by length(m.source_code_description) desc) as concept_name,
    -- transform mapping_type into domain: take from mapping_type, or from MedDRA target concept_id, or assign constant Condition
    coalesce(d.domain_id, d2.domain_id, 'Condition') as domain_id,
    v.vocabulary_id_v5 as vocabulary_id,
    -- class codes for new concepts
    case
      when substr(m.source_code, 1, 1)='V' then 'ICD9CM V code'
      when substr(m.source_code, 1, 1)='E' then 'ICD9CM E code'
      else 'ICD9CM code'
    end as concept_class_id,
    null as standard_concept,
    m.source_code as concept_code,
    min(m.valid_start_date) over (partition by m.source_code) as valid_start_date,
    max(m.valid_end_date) over (partition by m.source_code) as valid_end_date,
    case 
      when max(m.valid_end_date) over (partition by m.source_code)='31-Dec-2099' then null
      else 'D'
    end as invalid_reason
  from dev.source_to_concept_map m
  left join vocabulary_conversion v on v.vocabulary_id_v4=m.source_vocabulary_id
  left join dev.concept c on c.concept_id=m.target_concept_id
  left join concept_class_conversion c1 on c1.concept_class=c.concept_class
  left join mapping_types mt on mt.source_code=m.source_code and mt.source_vocabulary_id=m.source_vocabulary_id
  left join domain d on lower(d.domain_name)=lower(mt.m_types) 
  left join dev.concept_domain cd on cd.concept_id=m.target_concept_id and m.target_concept_id=15
  left join domain d2 on lower(d2.domain_name)=lower(cd.domain_name)
  where m.source_vocabulary_id=2
) newconcept
;

insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null
and m.source_vocabulary_id=2 and m.mapping_type not in ('MedDRA', 'Unmapped', 'Indication')
;

-- add ICD9CM to MedDRA
insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'ICD9CM - MedDRA' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null
and m.source_vocabulary_id=2 and m.target_vocabulary_id=15
;

-- back MedDRA to ICD9CM
insert into concept_relationship
select 
  trg.concept_id as concept_id_1,
  src.concept_id as concept_id_2,
  'MedDRA - ICD9CM' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null
and m.source_vocabulary_id=2 and m.target_vocabulary_id=15
;

-- add ICD9CM to FDB Indication
insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'ICD9CM - FDB Ind' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null
and m.source_vocabulary_id=2 and m.target_vocabulary_id=19
;

-- back FDB Ind to ICD9CM
insert into concept_relationship
select 
  trg.concept_id as concept_id_1,
  src.concept_id as concept_id_2,
  'FDB Ind - ICD9CM' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null
and m.source_vocabulary_id=2 and m.target_vocabulary_id=19
;

-- Vocabulary 3 - ICD9Proc
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  c.concept_name, 
  d.domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  cl.concept_class_id_new as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=3
;

-- add ICD9Proc to Rxnorm (procedure drugs) and self maps
insert into concept_relationship
select
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null
and m.source_vocabulary_id=3 and m.target_vocabulary_id in (3, 8)
and trg.concept_level>0 and trg.invalid_reason is null -- only map to Standard Concepts
and src.concept_id!=trg.concept_id -- map to self will be dealt with later
;

-- Vocabulary 4 - CPT4
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 254) as concept_name, 
  coalesce(d.domain_id, 'Procedure') as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=4
;

-- add CPT4 to Rxnorm (procedure drugs), self and SNOMED (conditions) maps
insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null
and m.source_vocabulary_id=4 and m.target_vocabulary_id in (1, 4, 8)
and trg.concept_level>0 and trg.invalid_reason is null -- only map to Standard Concepts
and src.concept_id!=trg.concept_id -- map to self will be dealt with later
;

-- Vocabulary 5 - HCPCS
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 254) as concept_name, 
  coalesce(d.domain_id, 'Procedure') as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=5
;

-- add HCPCS to Rxnorm (procedure drugs), self and SNOMED (conditions) maps
insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null
and m.source_vocabulary_id=5 and m.target_vocabulary_id in (1, 5, 8)
and trg.concept_level>0 and trg.invalid_reason is null -- only map to Standard Concepts
and src.concept_id!=trg.concept_id -- map to self will be dealt with later
;

-- Vocabulary 6 - LOINC
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 254) as concept_name, 
  coalesce(d.domain_id, 'Procedure') as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=6
;

-- Vocabulary 7 - NDFRT
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Drug' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  cl.concept_class_id_new as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'C' 
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=7
;

-- Vocabulary 8 - RxNorm
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 254) as concept_name, 
  'Drug' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  cl.concept_class_id_new as concept_class_id,
  case 
    when c.concept_class like '%Drug Form' and c.invalid_reason is null then 'S'
    when c.concept_class like '%Drug Component' and c.invalid_reason is null then 'S'
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=8
;

-- Vocabulary 9 - NDC
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  v5_concept.nextval as concept_id, 
  newconcept.*
from (
  select distinct
    -- pick the longest source_code_description
    substr(first_value(m.source_code_description) over (partition by m.source_code order by length(m.source_code_description) desc), 1, 255) as concept_name,
    -- transform mapping_type into domain: take from mapping_type, or from MedDRA target concept_id, or assign constant Condition
    'Drug' as domain_id,
    v.vocabulary_id_v5 as vocabulary_id,
    -- class codes for new concepts
    case
      when length(m.source_code)=11 then '11-digit NDC'
      when length(m.source_code)=9 then '9-digit NDC'
      else 'NDC'
    end as concept_class_id,
    null as standard_concept,
    m.source_code as concept_code,
    min(m.valid_start_date) over (partition by m.source_code) as valid_start_date,
    max(m.valid_end_date) over (partition by m.source_code) as valid_end_date,
    case 
      when max(m.valid_end_date) over (partition by m.source_code)='31-Dec-2099' then null
      else 'D'
    end as invalid_reason
  from dev.source_to_concept_map m
  left join vocabulary_conversion v on v.vocabulary_id_v4=m.source_vocabulary_id
  left join dev.concept c on c.concept_id=m.target_concept_id
  left join mapping_types mt on mt.source_code=m.source_code and mt.source_vocabulary_id=m.source_vocabulary_id
  where m.source_vocabulary_id=9
) newconcept
;

insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null and target_concept_id!=0
and m.source_vocabulary_id=9
;

-- Vocabulary 10 - GPI
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  v5_concept.nextval as concept_id, 
  newconcept.*
from (
  select distinct
    -- pick the longest source_code_description
    coalesce(substr(first_value(m.source_code_description) over (partition by m.source_code order by length(m.source_code_description) desc), 1, 255), ' ') 
      as concept_name,
    -- transform mapping_type into domain: take from mapping_type, or from MedDRA target concept_id, or assign constant Condition
    'Drug' as domain_id,
    v.vocabulary_id_v5 as vocabulary_id,
    -- class codes for new concepts
    v.vocabulary_id_v5 as concept_class_id,
    null as standard_concept,
    m.source_code as concept_code,
    min(m.valid_start_date) over (partition by m.source_code) as valid_start_date,
    max(m.valid_end_date) over (partition by m.source_code) as valid_end_date,
    case 
      when max(m.valid_end_date) over (partition by m.source_code)='31-Dec-2099' then null
      else 'D'
    end as invalid_reason
  from dev.source_to_concept_map m
  left join vocabulary_conversion v on v.vocabulary_id_v4=m.source_vocabulary_id
  left join dev.concept c on c.concept_id=m.target_concept_id
  left join mapping_types mt on mt.source_code=m.source_code and mt.source_vocabulary_id=m.source_vocabulary_id
  where m.source_vocabulary_id=10
) newconcept
;

insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null and target_concept_id!=0
and m.source_vocabulary_id=10
;

-- Vocabulary 11 - UCUM
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  coalesce(d.domain_id, 'Unit') as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  cl.concept_class_id_new as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S' 
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=11
;

-- Vocabulary 12 - Gender
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 254) as concept_name, 
  coalesce(d.domain_id, 'Gender') as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S' 
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=12
;

-- map null flavors to null
insert into concept_relationship
select 
  concept_id as concept_id_1,
  0 as concept_id_2,
  'Maps to' as relationship_id,
  '1-Jan-1970' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from concept 
where vocabulary_id='Gender' and standard_concept is null
;

-- Vocabulary 13 - Race
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 254) as concept_name, 
  coalesce(d.domain_id, 'Race') as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S' 
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=13
;

-- map null flavors to null
insert into concept_relationship
select 
  concept_id as concept_id_1,
  0 as concept_id_2,
  'Maps to' as relationship_id,
  '1-Jan-1970' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from concept 
where vocabulary_id='Race' and standard_concept is null
;

-- Vocabulary 14 - Place of Service
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 254) as concept_name, 
  coalesce(d.domain_id, 'Place of Service') as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S' 
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=14
;

-- Vocabulary 15 - MedDRA
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 254) as concept_name, 
  coalesce(d.domain_id, 'Condition') as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'C' 
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=15
;

-- Vocabulary 16 - Multum
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  v5_concept.nextval as concept_id, 
  newconcept.*
from (
  select distinct
    -- pick the longest source_code_description
    coalesce(substr(first_value(m.source_code_description) over (partition by m.source_code order by length(m.source_code_description) desc), 1, 255), ' ') 
      as concept_name,
    -- transform mapping_type into domain: take from mapping_type, or from MedDRA target concept_id, or assign constant Condition
    'Drug' as domain_id,
    v.vocabulary_id_v5 as vocabulary_id,
    -- class codes for new concepts
    v.vocabulary_id_v5 as concept_class_id,
    null as standard_concept,
    m.source_code as concept_code,
    min(m.valid_start_date) over (partition by m.source_code) as valid_start_date,
    max(m.valid_end_date) over (partition by m.source_code) as valid_end_date,
    case 
      when max(m.valid_end_date) over (partition by m.source_code)='31-Dec-2099' then null
      else 'D'
    end as invalid_reason
  from dev.source_to_concept_map m
  left join vocabulary_conversion v on v.vocabulary_id_v4=m.source_vocabulary_id
  left join dev.concept c on c.concept_id=m.target_concept_id
  left join mapping_types mt on mt.source_code=m.source_code and mt.source_vocabulary_id=m.source_vocabulary_id
  where m.source_vocabulary_id=16
) newconcept
;

insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null and target_concept_id!=0
and m.source_vocabulary_id=16
;

-- Vocabulary 17 - Read
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  v5_concept.nextval as concept_id, newconcept.*
from (
  select distinct
    -- pick the longest source_code_description
    coalesce(first_value(m.source_code_description) over (partition by m.source_code order by length(m.source_code_description) desc), ' ') as concept_name,
    -- transform mapping_type into domain: take from mapping type and cut off character after character from source_code till something there 
    coalesce(d7.domain_id, d6.domain_id, d5.domain_id, d4.domain_id, d3.domain_id, 'Observation') as domain_id,
    v.vocabulary_id_v5 as vocabulary_id,
    -- class codes for new concepts
    v.vocabulary_id_v5 as concept_class_id,
    null as standard_concept,
    m.source_code as concept_code,
    min(m.valid_start_date) over (partition by m.source_code) as valid_start_date,
    max(m.valid_end_date) over (partition by m.source_code) as valid_end_date,
    case 
      when max(m.valid_end_date) over (partition by m.source_code)='31-Dec-2099' then null
      else 'D'
    end as invalid_reason
  from dev.source_to_concept_map m
  left join vocabulary_conversion v on v.vocabulary_id_v4=m.source_vocabulary_id
  left join dev.concept c on c.concept_id=m.target_concept_id
  left join concept_class_conversion c1 on c1.concept_class=c.concept_class
  left join read_domains rd7 on rd7.source_code=m.source_code
  left join domain d7 on d7.domain_name=rd7.m_types
  left join read_domains rd6 on rd6.source_code=substr(m.source_code, 1, 6)
  left join domain d6 on d6.domain_name=rd6.m_types
  left join read_domains rd5 on rd5.source_code=substr(m.source_code, 1, 5)
  left join domain d5 on d5.domain_name=rd5.m_types
  left join read_domains rd4 on rd4.source_code=substr(m.source_code, 1, 4)
  left join domain d4 on d4.domain_name=rd4.m_types
  left join read_domains rd3 on rd3.source_code=substr(m.source_code, 1, 3)
  left join domain d3 on d3.domain_name=rd3.m_types
  where m.source_vocabulary_id=17
) newconcept
;

insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null and m.target_concept_id!=0
and m.source_vocabulary_id=17
;

-- Vocabulary 18 - OXMIS
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  v5_concept.nextval as concept_id, 
  newconcept.*
from (
  select distinct
    -- pick the longest source_code_description
    first_value(m.source_code_description) over (partition by m.source_code order by length(m.source_code_description) desc) as concept_name,
    -- transform mapping_type into domain: take from mapping_type, or from MedDRA target concept_id, or assign constant Condition
    coalesce(d.domain_id, 'Condition') as domain_id,
    v.vocabulary_id_v5 as vocabulary_id,
    -- class codes for new concepts
    v.vocabulary_id_v5 as concept_class_id,
    null as standard_concept,
    m.source_code as concept_code,
    min(m.valid_start_date) over (partition by m.source_code) as valid_start_date,
    max(m.valid_end_date) over (partition by m.source_code) as valid_end_date,
    case 
      when max(m.valid_end_date) over (partition by m.source_code)='31-Dec-2099' then null
      else 'D'
    end as invalid_reason
  from dev.source_to_concept_map m
  left join vocabulary_conversion v on v.vocabulary_id_v4=m.source_vocabulary_id
  left join dev.concept c on c.concept_id=m.target_concept_id
  left join concept_class_conversion c1 on c1.concept_class=c.concept_class
  left join mapping_types mt on mt.source_code=m.source_code and mt.source_vocabulary_id=m.source_vocabulary_id
  left join domain d on lower(d.domain_name)=lower(mt.m_types) 
  where m.source_vocabulary_id=18
) newconcept
;

insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null and m.target_concept_id!=0
and m.source_vocabulary_id=18
;

-- Vocabulary 19 - FDB Indication
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Drug' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'C'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=19
;

-- Vocabulary 20 - ETC
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Drug' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'C'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=20
;

-- Vocabulary 21 - ATC
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select distinct
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Drug' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  cl.concept_class_id_new as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    when cl.concept_class_id_new='ATC 5th' and c.concept_level!=0 then 'S'
    else 'C'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=21
;

-- Vocabulary 22 - Multilex
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Drug' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  cl.concept_class_id_new as concept_class_id,
  case
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=22
;

insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null and target_concept_id!=0
and m.source_vocabulary_id=22
;

-- Vocabulary 24 - Visit
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Visit' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  'S' standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=24
;

-- Vocabulary 28 - VA Product
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Drug' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  null as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=28
;

insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null and m.target_concept_id!=0
and m.source_vocabulary_id=28
;

-- Vocabulary 31 - SMQ
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Condition' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  'C' standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=31
;

-- Vocabulary 32 - VA Class
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Drug' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'C'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=32
;

-- Vocabulary 33 - Cohort
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  case 
    when c.concept_id<600000000 then 'Condition'
    else 'Drug'
  end as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'C'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=33
;

-- Vocabulary 34 - ICD10
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  v5_concept.nextval as concept_id, 
  newconcept.*
from (
  select distinct
    -- pick the longest source_code_description
    coalesce(first_value(m.source_code_description) over (partition by m.source_code order by length(m.source_code_description) desc), ' ') as concept_name,
    -- transform mapping_type : Default Unmapped and missing into Condition
    coalesce(case m.mapping_type when 'Unmapped' then 'Condition' else m.mapping_type end, 'Condition') as domain_id,
    v.vocabulary_id_v5 as vocabulary_id,
    -- class codes for new concepts
    'ICD10 code' as concept_class_id, 
    null as standard_concept,
    m.source_code as concept_code,
    min(m.valid_start_date) over (partition by m.source_code) as valid_start_date,
    max(m.valid_end_date) over (partition by m.source_code) as valid_end_date,
    case 
      when max(m.valid_end_date) over (partition by m.source_code)='31-Dec-2099' then null
      else 'D'
    end as invalid_reason
  from dev.source_to_concept_map m
  left join vocabulary_conversion v on v.vocabulary_id_v4=m.source_vocabulary_id
  left join dev.concept c on c.concept_id=m.target_concept_id
  left join concept_class_conversion c1 on c1.concept_class=c.concept_class
  where m.source_vocabulary_id=34
) newconcept
;

insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null and m.target_concept_id!=0
and m.source_vocabulary_id=34
;

-- Vocabulary 35 - ICD10PCS
-- Not implemented

-- Vocabulary 36 - Drug Type
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Drug Type' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=36
;

-- Vocabulary 37 - Condition Type
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Condition Type' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=37
;

-- Vocabulary 38 - Procedure Type
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Procedure Type' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=38
;

-- Vocabulary 39 - Observation Type
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Observation Type' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=39
;

-- Vocabulary 40 - DRG
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Observation' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=40
;

-- Vocabulary 41 - MDC
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 254) as concept_name, 
  'Observation' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=41
;

-- Vocabulary 42 - APC
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 254) as concept_name, 
  'Observation' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=42
;

-- Vocabulary 43 - Revenue Code
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 254) as concept_name, 
  d.domain_id as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=43
;

-- Vocabulary 44 - Ethnicity
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 254) as concept_name, 
  d.domain_id as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=44
;

-- Vocabulary 45 - Death Type
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  d.domain_id as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=45
;

-- Vocabulary 46 - Mesh
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  v5_concept.nextval as concept_id, 
  newconcept.*
from (
  select distinct
    -- pick the longest source_code_description
    coalesce(first_value(m.source_code_description) over (partition by m.source_code order by length(m.source_code_description) desc), ' ') as concept_name,
    -- transform mapping_type : Default Unmapped and missing into Condition
    d.domain_id as domain_id,
    v.vocabulary_id_v5 as vocabulary_id,
    -- class codes for new concepts
    m.mapping_type as concept_class_id, 
    null as standard_concept,
    m.source_code as concept_code,
    min(m.valid_start_date) over (partition by m.source_code) as valid_start_date,
    max(m.valid_end_date) over (partition by m.source_code) as valid_end_date,
    case 
      when max(m.valid_end_date) over (partition by m.source_code)='31-Dec-2099' then null
      else 'D'
    end as invalid_reason
  from dev.source_to_concept_map m
  left join vocabulary_conversion v on v.vocabulary_id_v4=m.source_vocabulary_id
  left join dev.concept c on c.concept_id=m.target_concept_id
  left join concept_class_conversion c1 on c1.concept_class=c.concept_class
  left join mapping_types mt on mt.source_code=m.source_code and mt.source_vocabulary_id=m.source_vocabulary_id
  left join domain d on lower(d.domain_name)=lower(mt.m_types) 
where m.source_vocabulary_id=46
) newconcept
;

insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null and m.target_concept_id!=0
and m.source_vocabulary_id=46
;

-- Vocabulary 47 - NUCC
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Provider Specialty' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=47
;

-- Vocabulary 48 - Specialty
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Provider Specialty' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=48
;

-- Vocabulary 49 - LOINC Hierarchy
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Measurement' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=49
;

-- Vocabulary 50 - SPL
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  v5_concept.nextval as concept_id, 
  newconcept.*
from (
  select distinct
    -- pick the longest source_code_description
    coalesce(substr(first_value(m.source_code_description) over (partition by m.source_code order by length(m.source_code_description) desc), 1, 255), ' ') as concept_name,
    -- transform mapping_type : Default Unmapped and missing into Condition
    'Drug' as domain_id,
    v.vocabulary_id_v5 as vocabulary_id,
    -- class codes for new concepts
    v.vocabulary_id_v5 as concept_class_id, 
    null as standard_concept,
    m.source_code as concept_code,
    min(m.valid_start_date) over (partition by m.source_code) as valid_start_date,
    max(m.valid_end_date) over (partition by m.source_code) as valid_end_date,
    case 
      when max(m.valid_end_date) over (partition by m.source_code)='31-Dec-2099' then null
      else 'D'
    end as invalid_reason
  from dev.source_to_concept_map m
  left join vocabulary_conversion v on v.vocabulary_id_v4=m.source_vocabulary_id
  left join dev.concept c on c.concept_id=m.target_concept_id
  left join concept_class_conversion c1 on c1.concept_class=c.concept_class
  where m.source_vocabulary_id=50
) newconcept
;

insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null and m.target_concept_id!=0
and m.source_vocabulary_id=50
;

-- Vocabulary 53 - Genseqno
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  v5_concept.nextval as concept_id, 
  newconcept.*
from (
  select distinct
    -- pick the longest source_code_description
    coalesce(first_value(m.source_code_description) over (partition by m.source_code order by length(m.source_code_description) desc), ' ') as concept_name,
    -- transform mapping_type : Default Unmapped and missing into Condition
    'Drug' as domain_id,
    v.vocabulary_id_v5 as vocabulary_id,
    -- class codes for new concepts
    v.vocabulary_id_v5 as concept_class_id, 
    null as standard_concept,
    m.source_code as concept_code,
    min(m.valid_start_date) over (partition by m.source_code) as valid_start_date,
    max(m.valid_end_date) over (partition by m.source_code) as valid_end_date,
    case 
      when max(m.valid_end_date) over (partition by m.source_code)='31-Dec-2099' then null
      else 'D'
    end as invalid_reason
  from dev.source_to_concept_map m
  left join vocabulary_conversion v on v.vocabulary_id_v4=m.source_vocabulary_id
  left join dev.concept c on c.concept_id=m.target_concept_id
  left join concept_class_conversion c1 on c1.concept_class=c.concept_class
  where m.source_vocabulary_id=53
) newconcept
;

insert into concept_relationship
select 
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null and m.target_concept_id!=0
and m.source_vocabulary_id=53
;

-- Vocabulary 54 - CCS
-- Not implemented

-- Vocabulary 55 - OPCS4
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Procedure' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  'Procedure' as concept_class_id,
  case 
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=55
;

-- Vocabulary 56 - Gemscript
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  v5_concept.nextval as concept_id, 
  newconcept.*
from (
  select distinct
    -- pick the longest source_code_description
    coalesce(first_value(m.source_code_description) over (partition by m.source_code order by length(m.source_code_description) desc), ' ') as concept_name,
    -- transform mapping_type : Default Unmapped and missing into Condition
    coalesce(case m.mapping_type when 'Unmapped' then 'Condition' else m.mapping_type end, 'Condition') as domain_id,
    v.vocabulary_id_v5 as vocabulary_id,
    -- class codes for new concepts
    v.vocabulary_id_v5 as concept_class_id, 
    null as standard_concept,
    m.source_code as concept_code,
    min(m.valid_start_date) over (partition by m.source_code) as valid_start_date,
    max(m.valid_end_date) over (partition by m.source_code) as valid_end_date,
    case 
      when max(m.valid_end_date) over (partition by m.source_code)='31-Dec-2099' then null
      else 'D'
    end as invalid_reason
  from dev.source_to_concept_map m
  left join vocabulary_conversion v on v.vocabulary_id_v4=m.source_vocabulary_id
  left join dev.concept c on c.concept_id=m.target_concept_id
  left join concept_class_conversion c1 on c1.concept_class=c.concept_class
  where m.source_vocabulary_id=56
) newconcept
;

insert into concept_relationship
select
  src.concept_id as concept_id_1,
  trg.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  m.valid_start_date as valid_start_date,
  m.valid_end_date as valid_end_date,
  m.invalid_reason
from dev.source_to_concept_map m
join vocabulary_conversion v1 on v1.vocabulary_id=m.source_vocabulary_id
join concept src on src.vocabulary_id=v1.vocabulary_id_v5 and src.concept_code=m.source_code
join dev.concept trg on trg.concept_id=m.target_concept_id
where m.invalid_reason is null and m.target_concept_id!=0
and m.source_vocabulary_id=56
;

-- Vocabulary 57 - HES Specialty
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Provider Specialty' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  'S' as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=57
;

-- Vocabulary 58 - Note Type
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name,
  d.domain_id as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  'S' as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=58
;

-- Vocabulary 59 - Domain
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Metadata' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  'S' as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=59
;

-- Vocabulary 60 - PCORNet
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  case 'c.concept_class'
    when 'Chart Availability' then 'Observation'
    when 'Admitting Source' then 'Observation'
    when 'Discharge Disposition' then 'Observation'
    when 'Biobank Flag' then 'Observation'
    when 'Enrollment Basis' then 'Observation'
    when 'Race' then 'Race'
    when 'Discharge Status' then 'Observation'
    when 'Encounter Type' then 'Metadata'
    when 'Hispanic' then 'Ethnicity'
    when 'Sex' then 'Observation'
    else 'Observation' 
  end as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  cl.concept_class_id_new as concept_class_id,
  case
    when c.concept_level=0 then null
    when c.invalid_reason is not null then null
    else 'S'
  end as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=60
;

-- Vocabulary 61 - Obs Period Type
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Obs Period Type' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  'S' as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=61
;

-- Vocabulary 62 - Visit Type
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Visit Type' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  'S' as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=62
;

-- Vocabulary 63 - Device Type
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Device Type' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  'S' as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=63
;

-- Vocabulary 64 - Meas Type
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Meas Type' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  'S' as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=64
;

-- Vocabulary 65 - Currency
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Currency' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  'S' as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=65
;

-- Vocabulary 66 - Relationship
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Metadata' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  'S' as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=66
;

-- Vocabulary 67 - Vocabulary
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Metadata' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  'S' as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=67
;

-- Vocabulary 68 - Concept Class
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Metadata' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  'S' as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=68
;

-- Vocabulary 69 - Cohort Type
insert into concept (
  concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
select 
  c.concept_id,
  substr(c.concept_name, 1, 255) as concept_name, 
  'Cohort Type' as domain_id,
  v.vocabulary_id_v5 as vocabulary_id,
  v.vocabulary_id_v5 as concept_class_id,
  'S' as standard_concept,
  c.concept_code,
  c.valid_start_date,
  c.valid_end_date,
  c.invalid_reason
from dev.concept c
left join dev.concept_relationship r on r.concept_id_2=c.concept_id and r.relationship_id=359
left join dev.concept dc on dc.concept_id=r.concept_id_1
left join domain d on d.domain_concept_id=dc.concept_id 
left join vocabulary_conversion v on v.vocabulary_id_v4=c.vocabulary_id
left join concept_class_conversion cl on cl.concept_class=c.concept_class
where c.vocabulary_id=69
;

-- Vocabulary 70 - ICD10CM
-- not implemented

commit;

-- Create relationships to self for Standard Concepts only
insert into concept_relationship
select 
  nw.concept_id as concept_id_1,
  nw.concept_id as concept_id_2,
  'Maps to' as relationship_id,
  nw.valid_start_date,
  nw.valid_end_date,
  nw.invalid_reason
from concept nw
where nw.standard_concept='S'
and vocabulary_id!='Multilex' -- already contain the self maps
;

commit;

-- Turn concept_relationships
insert /*+ append */ into concept_relationship
select 
  concept_id_2 as concept_id_1,
  concept_id_1 as concept_id_2,
  'Mapped from' as relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
from concept_relationship
where relationship_id='Maps to'
;

commit;

-- After adding indexes

-- Fix few remaining ATC that were deprecated
update concept set concept_class_id='ATC 5th' where concept_class_id='ATC';

-- set ATC 5th level to non-standard if RxNorm exists
update concept c set standard_concept=null 
where concept_class_id='ATC 5th' 
and exists (
  select 1 from concept_relationship r, concept c1, concept c2 where c1.concept_id=r.concept_id_1 and c2.concept_id=r.concept_id_2 
  and c1.vocabulary_id='ATC' and c2.vocabulary_id='RxNorm' and c1.concept_class_id='ATC 5th' and c2.concept_class_id='Ingredient'
  and r.invalid_reason is null
)
;

-- Coopy concept_ancestor 
insert into concept_ancestor select * from dev.concept_ancestor;

/**********************************************************


select concept_id_1,concept_id_2,relationship_id, count(8) from concept_relationship
group by concept_id_1,concept_id_2,relationship_id having count(8)>1
;

select distinct source_vocabulary_id, target_vocabulary_id from dev.source_to_concept_map where source_vocabulary_id!=target_vocabulary_id 
and target_vocabulary_id!=0 order by 1,2;

select distinct c1.vocabulary_id, c1.standard_concept as c1_standard, c2.standard_concept as c2_standard 
from concept_relationship r, concept c1, concept c2 where c1.concept_id=r.concept_id_1 and c2.concept_id=r.concept_id_2 
and c1.vocabulary_id=c2.vocabulary_id 
and r.relationship_id='Maps to'
-- and c1.standard_concept is null
and r.invalid_reason is null
;
