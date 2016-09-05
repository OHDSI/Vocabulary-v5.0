/*
-- start new sequence
drop sequence v5_concept;
DECLARE
 ex NUMBER;
BEGIN
  SELECT MAX(concept_id)+1 INTO ex FROM concept WHERE concept_id>=200 and concept_id<1000; -- Last valid value in the 500-1000 slot
  BEGIN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXCEPTION
      WHEN OTHERS THEN NULL;
  END;
END;
*/

/*
-- start new sequence
drop sequence v5_concept;
DECLARE
 ex NUMBER;
BEGIN
  SELECT MAX(concept_id)+1 INTO ex FROM concept WHERE concept_id>=5000 and concept_id<8000; -- Last valid value in the 5000-8000 slot
  BEGIN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXCEPTION
      WHEN OTHERS THEN NULL;
  END;
END;
*/

-- Add Cost Type vocabulary and concept classes
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values(v5_concept.nextval, 'OMOP Cost Type', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id) 
  values ('Cost Type', 'OMOP Cost Type', 'OMOP generated', null, (select concept_id from concept where concept_name='OMOP Cost Type'));
insert into vocabulary_conversion (vocabulary_id_v4, vocabulary_id_v5, omop_req, click_default, available, url, click_disabled) values (83, 'Cost Type', 'Y', 'Y', null, null, 'Y');

-- Add concept_class
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Cost Type', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Cost Type', 'Cost Type', (select concept_id from concept where concept_name = 'Cost Type'));

-- Add Cost Type Concepts
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Amount paid by the patient or reimbursed by the payer', 'Type Concept', 'Cost Type', 'Cost Type', 'S', 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Amount charged to the patient or the payer by the provider, list price', 'Type Concept', 'Cost Type', 'Cost Type', 'S', 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
  values (v5_concept.nextval, 'Cost incurred by the provider', 'Type Concept', 'Cost Type', 'Cost Type', 'S', 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);

-- Rename Multilex relationships to generic
alter table relationship disable constraint fpk_relationship_reverse;
alter table concept_relationship disable constraint fpk_concept_relationship_id;
update relationship set relationship_id='RxNorm - Source eq', relationship_name='RxNorm to Drug Source equivalent (OMOP)', reverse_relationship_id='Source - RxNorm eq' where relationship_id='RxNorm - Multilex eq';
update relationship set relationship_id='Source - RxNorm eq', relationship_name='Drug Source to RxNorm equivalent (OMOP)', reverse_relationship_id='RxNorm - Source eq' where relationship_id='Multilex - RxNorm eq';
update concept_relationship set relationship_id='RxNorm - Source eq' where relationship_id='RxNorm - Multilex eq';
update concept_relationship set relationship_id='Source - RxNorm eq' where relationship_id='Multilex - RxNorm eq';
update concept_relationship set relationship_id='Drug class of drug' where relationship_id='Class - Multilex ing';
update concept_relationship set relationship_id='Drug has drug class' where relationship_id='Multilex ing - class';
delete from relationship where relationship_id='Class - Multilex ing';
delete from relationship where relationship_id='Multilex ing - class';
update concept set concept_name='RxNorm to Drug Source equivalent (OMOP)' where concept_id=44818952;
update concept set concept_name='Drug Source to RxNorm equivalent (OMOP)' where concept_id=44818953;
update concept set valid_end_date='15-Aug-2016', invalid_reason='U' where concept_id=44818954;
update concept set valid_end_date='15-Aug-2016', invalid_reason='U' where concept_id=44818955;
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values(44818954, 234, 'Concept replaced by', '16-Aug-2016', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values(44818955, 233, 'Concept replaced by', '16-Aug-2016', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values(44818954, 234, 'Concept replaces', '16-Aug-2016', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values(44818955, 233, 'Concept replaces', '16-Aug-2016', '31-Dec-2099', null);
alter table concept_relationship enable constraint fpk_concept_relationship_id;
alter table relationship enable constraint fpk_relationship_reverse;

--------------------------------------------------------

alter table relationship disable constraint fpk_relationship_reverse;
alter table concept_relationship disable constraint fpk_concept_relationship_id;

-- Rename 'Maps to' to 'Source - RxNorm eq'
update concept_relationship
set relationship_id='Source - RxNorm eq', valid_end_date='31-Dec-2099', invalid_reason=null
where rowid in (
  select r.rowid
  from concept_relationship r 
  join concept c1 on r.concept_id_1=c1.concept_id 
  join concept c2 on c2.concept_id=r.concept_id_2 
  where 1=1
  and c1.vocabulary_id='dm+d'
  and c2.concept_class_id in ('Dose Form', 'Brand Name', 'Supplier')
); 

update concept_relationship
set relationship_id='RxNorm - Source eq', valid_end_date='31-Dec-2099', invalid_reason=null
where rowid in (
  select r.rowid
  from concept_relationship r 
  join concept c1 on r.concept_id_1=c1.concept_id 
  join concept c2 on c2.concept_id=r.concept_id_2 
  where 1=1
  and c2.vocabulary_id='dm+d'
  and c1.concept_class_id in ('Dose Form', 'Brand Name', 'Supplier')
); 

alter table concept_relationship enable constraint fpk_concept_relationship_id;
alter table relationship enable constraint fpk_relationship_reverse;

--------------------------------------------------------

-- Remove duplicates between RxNorm and RxNorm Extension
create table name_dedup as
select * from (
  select distinct
    concept_id as from_id,
    first_value(concept_id) over (partition by concept_name order by vocabulary_id, concept_id) as to_id
  from concept 
  join (
    select concept_name, concept_class_id from concept e join concept r using(concept_name, concept_class_id) where e.vocabulary_id='RxNorm Extension' and r.vocabulary_id='RxNorm' and r.invalid_reason is null
  ) using(concept_name, concept_class_id)
  where vocabulary_id like 'RxNorm%' and concept_name not like '%...%' and invalid_reason is null
) where from_id!=to_id
;

-- add the duplicates that have no RxNorm equivalent
insert into name_dedup
select * from (
  select distinct
    concept_id as from_id,
    first_value(concept_id) over (partition by concept_name order by concept_id) as to_id
  from concept 
  join (
    select concept_name, concept_class_id from concept where vocabulary_id='RxNorm Extension' and concept_id not in (select from_id from name_dedup) group by concept_name, concept_class_id having count(8)>1
  ) using(concept_name, concept_class_id)
  where vocabulary_id='RxNorm Extension' and concept_name not like '%...%' and invalid_reason is null
) where from_id!=to_id 
;
commit;

-- rewire
create table from_r nologging as
select from_r.to_id_1, from_r.to_id_2, from_r.relationship_id from (
  select 
    concept_id_1, nvl(nd1.to_id, concept_id_1) as to_id_1,
    concept_id_2, nvl(nd2.to_id, concept_id_2) as to_id_2,
    relationship_id
  from concept_relationship r
  join concept c1 on c1.concept_id=r.concept_id_1 and c1.vocabulary_id like 'RxNorm%'
  join concept c2 on c2.concept_id=r.concept_id_2 and c2.vocabulary_id like 'RxNorm%'  
  left join name_dedup nd1 on r.concept_id_1=nd1.from_id
  left join name_dedup nd2 on r.concept_id_2=nd2.from_id  
  where coalesce(nd1.to_id, nd2.to_id, 0)!=0 -- either one concept_id_ shouold have changed, otherwise we are redoing the entire table.
) from_r;

-- delete if rewired already exists
delete from concept_relationship where rowid in (
  select r.rowid from concept_relationship r join from_r using(concept_id_1, concept_id_2, relationship_id)
);

insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  select distinct to_id_1, to_id_2, relationship_id, trunc(sysdate), '31-Dec-2099', null 
  from from_r f 
  where not exists (
    select 1 from concept_relationship r where r.concept_id_1=f.to_id_1 and r.concept_id_2=f.to_id_2 and r.relationship_id=f.relationship_id
  )
;
drop table from_r purge;

-- Deprecate the duplicates and create forwarding relationships
update concept set valid_end_date=trunc(sysdate)-1, invalid_reason='U' where concept_id in (select from_id from name_dedup);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  select from_id, to_id, 'Concept replaced by', trunc(sysdate), '31-Dec-2099', null from name_dedup;
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  select to_id, from_id, 'Concept replaces', trunc(sysdate), '31-Dec-2099', null from name_dedup;

drop table name_dedup;

-- Introduce missing relationships
-- Branded to Clinical
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
with p as (
-- by name
  select distinct
-- c1.concept_name as concept_name_1, c2.concept_name as concept_name_2,
    c1.concept_id as concept_id_1, 
    c2.concept_id as concept_id_2
  from concept c1
  join concept c2 on c2.vocabulary_id like 'RxNorm%' 
    and c2.concept_class_id like '%Clinical%'
    and instr(c1.concept_name, c2.concept_name)>0
    and c2.invalid_reason is null
  where c1.vocabulary_id like 'RxNorm%' and c1.concept_class_id like '%Branded%'
  and c2.concept_name = regexp_replace (c1.concept_name, '\s\[.*\]\s*') and regexp_like (c1.concept_name, '\s\[.*\]\s*') and c2.invalid_reason is null and c1.invalid_reason is null
  minus
-- in concept_relationship
  select 
-- c1.concept_name as concept_name_1, c2.concept_name as concept_name_2,
  r.concept_id_1, r.concept_id_2
  from concept c1 
  join concept_relationship r on r.concept_id_1=c1.concept_id -- and r.invalid_reason is null
  join concept c2 on c2.concept_id=r.concept_id_2
  where c1.vocabulary_id like 'RxNorm%' and c2.vocabulary_id like 'RxNorm%'
       and c1.concept_class_id like '%Branded%' and c2.concept_class_id like '%Clinical%' and c1.concept_class_id = replace (c2.concept_class_id, 'Clinical', 'Branded')
)
select 
  concept_id_1, concept_id_2,
  'Tradename of' as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
union
select 
  concept_id_2, concept_id_1, 
  'Has tradename'  as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
;

-- Box of
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
with p as (
-- by name
  select distinct
    c1.concept_id as concept_id_1, 
    c2.concept_id as concept_id_2
--  c1.concept_name as concept_name_1, c2.concept_name as concept_name_2
  from concept c1
  join concept c2 on c2.vocabulary_id like 'RxNorm%' 
    and c2.concept_class_id in ('Branded Drug',  'Clinical Drug', 'Quant Branded Drug', 'Quant Clinical Drug')
    and instr(c1.concept_name, c2.concept_name)>0
  where c1.vocabulary_id like 'RxNorm%' and c1.concept_class_id like '%Box%'
  and substr(c1.concept_name, 1, instr(c1.concept_name, ' Box of ')-1)=c2.concept_name and c2.invalid_reason is null and c1.invalid_reason is null
  minus
-- in concept_relationship
  select r.concept_id_1, r.concept_id_2
--  c1.concept_name as concept_name_1, c2.concept_name as concept_name_2
  from concept c1 
  join concept_relationship r on r.concept_id_1=c1.concept_id -- and r.invalid_reason is null
  join concept c2 on c2.concept_id=r.concept_id_2
  where c1.vocabulary_id like 'RxNorm%' and c2.vocabulary_id like 'RxNorm%'
    and ( c1.concept_class_id=c2.concept_class_id ||' Box' or c1.concept_class_id = replace (c2.concept_class_id, 'Drug', 'Box') )
  and c1.concept_class_id like '%Box%'
) 
select 
  concept_id_1, concept_id_2,
  'Box of' as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
union
select 
  concept_id_2, concept_id_1,
 'Available as box'  as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
;

-- Marketed Product to others
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
with p as (
-- by name
  select distinct
-- c1.concept_name, c2.concept_name, 
  c1.concept_id as concept_id_1, 
  c2.concept_id as concept_id_2
-- c1.concept_name as concept_name_1, c2.concept_name as concept_name_2
  from concept c1
  join concept c2 on c2.vocabulary_id like 'RxNorm%' 
    and c2.concept_class_id in ('Branded Drug Box', 'Branded Drug', 'Clinical Drug Box', 'Clinical Drug', 'Quant Branded Box', 'Quant Branded Drug', 'Quant Clinical Box', 'Quant Clinical Drug')
    and instr(c1.concept_name, c2.concept_name)>0
  where c1.vocabulary_id like 'RxNorm%' and c1.concept_class_id='Marketed Product' and c2.invalid_reason is null and c1.invalid_reason is null
  and substr(c1.concept_name, 1, instr(c1.concept_name, ' by ')-1)=c2.concept_name
  minus
-- in concept_relationship
  select r.concept_id_1, r.concept_id_2
-- c1.concept_name as concept_name_1, c2.concept_name as concept_name_2
  from concept c1 
  join concept_relationship r on r.concept_id_1=c1.concept_id -- and r.invalid_reason is null
  join concept c2 on c2.concept_id=r.concept_id_2
  where c1.vocabulary_id like 'RxNorm%' and c2.vocabulary_id like 'RxNorm%'
    and c1.concept_class_id='Marketed Product' 
    and c2.concept_class_id in ('Branded Drug Box', 'Branded Drug', 'Clinical Drug Box', 'Clinical Drug', 'Quant Branded Box', 'Quant Branded Drug', 'Quant Clinical Box', 'Quant Clinical Drug')
)
select 
  concept_id_1, concept_id_2, 
  'Marketed form of'  as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
union
select 
  concept_id_2, concept_id_1, 
 'Has marketed form'  as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
;

--Quant to non-Quant
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
with p as (
-- by name
  select distinct
  c1.concept_id as concept_id_1, 
  c2.concept_id as concept_id_2
--   c1.concept_name as concept_name_1, c2.concept_name as concept_name_2
  from concept c1
  join concept c2 on c2.vocabulary_id like 'RxNorm%' 
    and c2.invalid_reason is null
  where c1.vocabulary_id like 'RxNorm%' and c1.concept_class_id like '%Quant%'
    and c2.concept_name = regexp_replace (c1.concept_name, '^[[:digit:]\.]+ [[:alpha:]]+ ') and regexp_like (c1.concept_name,  '^[[:digit:]\.]+ [[:alpha:]]+ ') and c2.invalid_reason is null and c1.invalid_reason is null
  minus
-- in concept_relationship
  select r.concept_id_1, r.concept_id_2
--  c1.concept_name as concept_name_1, c2.concept_name as concept_name_2
  from concept c1 
  join concept_relationship r on r.concept_id_1=c1.concept_id -- and r.invalid_reason is null
  join concept c2 on c2.concept_id=r.concept_id_2 and c2.invalid_reason is null
  where c1.vocabulary_id like 'RxNorm%' and c2.vocabulary_id like 'RxNorm%'
    and c2.concept_name = regexp_replace (c1.concept_name, '^[[:digit:]\.]+ [[:alpha:]]+ ') and regexp_like (c1.concept_name,  '^[[:digit:]\.]+ [[:alpha:]]+ ')
    and c1.invalid_reason is null
) 
select 
  concept_id_1, concept_id_2, 
  'Quantified form of' as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
union
select concept_id_2, concept_id_1, 
  'Has quantified form'  as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
;

-- Branded Drug to Branded Drug Component
-- build normalized version of ds_stage
create table ds_agg as 
select drug_concept_id, listagg (ingredient_concept_id, '-') within group (order by ingredient_concept_id) as ingred_combo,  
listagg (amount_value, '-') within group (order by  amount_value) as amount_combo,
listagg (numerator_value/nvl (DENOMINATOR_VALUE, 1), '-') within group (order by numerator_value/nvl (DENOMINATOR_VALUE, 1)) as dose_combo
from drug_strength group by drug_concept_id
;

insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
with p as (
-- by name
  select distinct
    c1.concept_id as concept_id_1, 
    first_value(c2.concept_id) over (partition by c1.concept_id order by c1.concept_id) as concept_id_2 -- there are duplications due to summed up precise ingredients that are mapping to the same ingredient
  from concept c1
  join concept c2 on c2.vocabulary_id like 'RxNorm%' and c2.invalid_reason is null
  join ds_agg ds1 on c1.concept_id = ds1.drug_concept_id
  join ds_agg ds2 on c2.concept_id = ds2.drug_concept_id and nvl (ds1.dose_combo, ' ') = nvl (ds2.dose_combo, ' ') and ds1.INGRED_COMBO = ds2.INGRED_COMBO and nvl (ds1.amount_combo, ' ')= nvl (ds2.amount_combo, ' ')
  --  and instr(c1.concept_name, c2.concept_name)>0
  where c1.invalid_reason is null
    and c1.vocabulary_id like 'RxNorm%' and c2.concept_class_id like '%Comp%' and c1.concept_class_id not like '%Comp%' and c1.concept_class_id ='Branded Drug'
    and regexp_substr( c2.concept_name, '\[.*\]' )= regexp_substr (c1.concept_name, '\[.*\]')
    and c2.invalid_reason is null and c1.invalid_reason is null
  minus
-- in concept_relationship
  select r.concept_id_1, r.concept_id_2
  from concept c1 
  join concept_relationship r on r.concept_id_1=c1.concept_id -- and r.invalid_reason is null
  join concept c2 on c2.concept_id=r.concept_id_2
  join ds_agg ds1 on c1.concept_id = ds1.drug_concept_id
  join ds_agg ds2 on c2.concept_id = ds2.drug_concept_id and nvl (ds1.dose_combo, ' ') = nvl (ds2.dose_combo, ' ') and ds1.INGRED_COMBO = ds2.INGRED_COMBO and nvl (ds1.amount_combo, ' ')= nvl (ds2.amount_combo, ' ')
  where c1.vocabulary_id like 'RxNorm%' and c2.concept_class_id like '%Comp%' and c1.concept_class_id not like '%Comp%' and c1.concept_class_id ='Branded Drug'
    and regexp_substr( c2.concept_name, '\[.*\]' )= regexp_substr (c1.concept_name, '\[.*\]')
) 
select concept_id_1, concept_id_2,
  'Consists of' as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
union
select concept_id_2, concept_id_1, 
  'Constitutes'  as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
;

--Clinical Drug to Clinical Drug Component
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
with p as (
-- by name
  select distinct 
    c1.concept_id as concept_id_1, c2.concept_id as concept_id_2
  from concept c1
  join concept c2 on c2.vocabulary_id like 'RxNorm%' 
  join drug_strength ds1 on c1.concept_id = ds1.drug_concept_id
  join drug_strength ds2 on c2.concept_id = ds2.drug_concept_id 
    and 'x'|| nvl(ds1.numerator_value/nvl(ds1.DENOMINATOR_VALUE, 1), '0') = 'x'|| nvl (ds2.numerator_value/nvl (ds2.DENOMINATOR_VALUE, 1), '0')
    and ds1.ingredient_concept_id = ds2.ingredient_concept_id and 'x'|| nvl (ds1.amount_value, '0')= 'x'|| nvl (ds2.amount_value, '0')
  where c1.vocabulary_id like 'RxNorm%' and c1.concept_class_id= 'Clinical Drug' and c2.concept_class_id = 'Clinical Drug Comp'
    and c2.invalid_reason is null and c1.invalid_reason is null
  minus
-- in concept_relationship
  select r.concept_id_1, r.concept_id_2
  from concept c1 
  join concept_relationship r on r.concept_id_1=c1.concept_id -- and r.invalid_reason is null
  join concept c2 on c2.concept_id=r.concept_id_2
  join drug_strength ds1 on c1.concept_id = ds1.drug_concept_id
  join drug_strength ds2 on c2.concept_id = ds2.drug_concept_id 
    and 'x'|| nvl (ds1.numerator_value/nvl (ds1.DENOMINATOR_VALUE, 1), '0') = 'x'|| nvl (ds2.numerator_value/nvl (ds2.DENOMINATOR_VALUE, 1), '0')
    and ds1.ingredient_concept_id = ds2.ingredient_concept_id and 'x'|| nvl (ds1.amount_value, '0')= 'x'|| nvl (ds2.amount_value, '0')
  --  and instr(c1.concept_name, c2.concept_name)>0
  where c1.vocabulary_id like 'RxNorm%' and c1.concept_class_id= 'Clinical Drug' and c2.concept_class_id = 'Clinical Drug Comp'
) 
select 
  concept_id_1, concept_id_2, 
  'Consists of' as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
union
select concept_id_2, concept_id_1, 
  'Constitutes'  as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
;

--prepare tables 
create table cnc_rel_class as
select ri.*, ci.concept_class_id as concept_class_id_1 , c2.concept_class_id as concept_class_id_2 
from concept_relationSHIp ri 
join concept ci on ci.concept_id = ri.concept_id_1 
join concept c2 on c2.concept_id = ri.concept_id_2 
where ci.vocabulary_id like  'RxNorm%' and ri.invalid_reason is null and ci.invalid_reason is null 
and  c2.vocabulary_id like 'RxNorm%'  and ci.invalid_reason is null 
;
create table ri_agg as 
select concept_id_1, listagg (concept_id_2, '-') within group (order by concept_id_2) as ingred_combo
from cnc_rel_class where concept_class_id_2 = 'Ingredient'
group by concept_id_1
;
create index cnc_rel_class_1 on cnc_rel_class (concept_id_1);
create index cnc_rel_class_2 on cnc_rel_class (concept_id_2);
create index ds_agg_1 on ds_agg (drug_concept_id);
create index ds_agg_2 on ds_agg (INGRED_COMBO);
create index ri_agg_1 on ri_agg (concept_id_1);
create index ri_agg_2 on ri_agg (INGRED_COMBO);

--Clinical Drug to Clinical Drug Form
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
with p as (
  select distinct
    c1.concept_id as concept_id_1, c2.concept_id as concept_id_2,  
    c1.concept_name as concept_name_1, c2.concept_name as concept_name_2
  from concept c1
  join concept c2 on c2.vocabulary_id like 'RxNorm%' 
  join cnc_rel_class r1 on r1.CONCEPT_ID_1 = c1.CONCEPT_ID and r1.CONCEPT_CLASS_ID_2 = 'Dose Form'
  join cnc_rel_class r2 on r2.CONCEPT_ID_1 = c2.CONCEPT_ID and r2.CONCEPT_CLASS_ID_2 = 'Dose Form' and r1.concept_id_2  = r2.concept_id_2
  join ds_agg  ri1 on ri1.drug_CONCEPT_ID = c1.CONCEPT_ID 
  join ri_agg ri2 on ri2.CONCEPT_ID_1 = c2.CONCEPT_ID  and ri1.INGRED_COMBO  = ri2.INGRED_COMBO
  where c1.vocabulary_id like 'RxNorm%' and c2.concept_class_id like 'Clinical Drug Form' and c1.concept_class_id like '%Clinical Drug' 
    and c2.invalid_reason is null and c1.invalid_reason is null
  minus
-- in concept_relationship
  select r.concept_id_1, r.concept_id_2,c1.concept_name as concept_name_1, c2.concept_name as concept_name_2
  from concept c1 
  join concept_relationship r on r.concept_id_1=c1.concept_id -- and r.invalid_reason is null
  join concept c2 on c2.concept_id=r.concept_id_2 and c2.concept_class_id like 'Clinical Drug Form' 
  where c1.vocabulary_id like 'RxNorm%' and c1.concept_class_id like '%Clinical Drug' 
)
select
  concept_id_1, concept_id_2,
  'Has component' as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
union
select 
  concept_id_2, concept_id_1, 
  'Component of'  as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
;

 --Branded Drug to Branded Drug Form
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
 with p as (
  select distinct
    c1.concept_id as concept_id_1,
    first_value(c2.concept_id) over (partition by c1.concept_id order by c2.vocabulary_id, c2.concept_id) as concept_id_2
  from concept c1
  join concept c2 on c2.vocabulary_id like 'RxNorm%' 
  join cnc_rel_class r1 on r1.CONCEPT_ID_1 = c1.CONCEPT_ID and r1.CONCEPT_CLASS_ID_2 = 'Dose Form'
  join cnc_rel_class r2 on r2.CONCEPT_ID_1 = c2.CONCEPT_ID and r2.CONCEPT_CLASS_ID_2 = 'Dose Form' and r1.concept_id_2  = r2.concept_id_2
  join ds_agg  ri1 on ri1.drug_CONCEPT_ID = c1.CONCEPT_ID --For Drugs
  join cnc_rel_class ri2 on ri2.CONCEPT_ID_1 = c2.CONCEPT_ID  and ri2.concept_class_id_1 = 'Branded Drug Form' and ri2.concept_class_id_2 = 'Clinical Drug Form'
  join ri_agg ria on ria.CONCEPT_ID_1 = ri2.CONCEPT_ID_2 and ri1.INGRED_COMBO  = ria.INGRED_COMBO --For Forms
  where c1.vocabulary_id like 'RxNorm%' and c2.concept_class_id like 'Branded Drug Form' and c1.concept_class_id like '%Branded Drug' 
    and regexp_substr( c2.concept_name, '\[.*\]' )= regexp_substr (c1.concept_name, '\[.*\]')
    and c2.invalid_reason is null and c1.invalid_reason is null
  minus
-- in concept_relationship
  select r.concept_id_1, r.concept_id_2
  from concept c1 
  join concept_relationship r on r.concept_id_1=c1.concept_id -- and r.invalid_reason is null
  join concept c2 on c2.concept_id=r.concept_id_2 and c2.concept_class_id like 'Branded Drug Form' 
  where c1.vocabulary_id like 'RxNorm%' and c1.concept_class_id like '%Branded Drug' 
)
select 
  concept_id_1, concept_id_2, 
  'Has component' as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
union
select 
  concept_id_2, concept_id_1, 
  'Component of'  as relationship_id,
  trunc(sysdate) as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from p
;

drop table ds_agg purge;
drop table cnc_rel_class purge; 
drop table ri_agg purge;

commit;





-- Add old NDC from GPI
select distinct n.gpi, n.gpi_desc, n.ndc, n.mkted_prod_formltn_nm as ndw_name, ndc.concept_name as ndc_name, rx.concept_id as rx_id, rx.concept_name as rx_name, rx.concept_class_id as rx_class, cd.concept_id as cd_id, cd.concept_name as cd_name, cd.concept_class_id as cd_class
from ndw_v_product n
join concept ndc on ndc.concept_code=n.ndc and ndc.vocabulary_id='NDC' 
join concept_relationship r on r.invalid_reason is null and r.concept_id_1=ndc.concept_id and r.relationship_id='Maps to'
join concept rx on rx.concept_id=r.concept_id_2
left join concept_relationship r2 on r2.concept_id_1=rx.concept_id and r2.invalid_reason is null and r2.relationship_id='Tradename of'
left join concept cd on cd.concept_id=r2.concept_id_2 
where n.gpi='83100020302005'
  ;
