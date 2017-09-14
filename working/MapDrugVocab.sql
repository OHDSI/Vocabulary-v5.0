exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'r_existing', cascade  => true);
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'ex', cascade  => true);
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_relationship_stage', cascade  => true);

drop table map_drug;
create table map_drug as
select from_code, to_id, '00' as map_order
 from maps_to 
 where to_id not like '-%'; 

insert into map_drug (from_code, to_id, map_order)
select  distinct  cr.concept_code_1,first_value (r.concept_id) over (partition by cr.concept_code_1 order by rc2.precedence), '1'    -- Map Marketed Form to corresponding Branded/Clinical Drug (save box size and quant factor)
from r_existing r
  join ex e
    on r.quant_value = e.r_value and r.quant_unit_id = e.quant_unit_id
   and r.i_combo = e.ri_combo and r.d_combo = e.rd_combo and r.bn_id = e.bn_id and r.bs = e.bs
   and r.mf_id=0
   and e.concept_id like '-%'
  join relationship_to_concept rc  on rc.concept_id_2 = e.df_id
  join relationship_to_concept rc2 on rc.concept_code_1 = rc2.concept_code_1 and rc2.concept_id_2 = r.df_id
  join concept_relationship_stage cr
    on cr.concept_code_2 = e.concept_code
   and cr.relationship_id = 'Maps to'
   and cr.vocabulary_id_1 = (select vocabulary_id from drug_concept_stage where rownum=1)
   and cr.vocabulary_id_2 = 'RxNorm Extension'
  where cr.concept_code_1 not in (select from_code from map_drug);

insert into map_drug (from_code, to_id, map_order)
select  distinct  cr.concept_code_1,first_value (r.concept_id) over (partition by cr.concept_code_1 order by rc2.precedence), '2'    -- Kick box size out
from r_existing r
  join ex e
    on r.quant_value = e.r_value and r.quant_unit_id = e.quant_unit_id
   and r.i_combo = e.ri_combo and r.d_combo = e.rd_combo and r.bn_id = e.bn_id
   and r.bs = 0 and r.mf_id=0
   and e.concept_id like '-%'
  join relationship_to_concept rc  on rc.concept_id_2 = e.df_id
  join relationship_to_concept rc2 on rc.concept_code_1 = rc2.concept_code_1 and rc2.concept_id_2 = r.df_id 
  join concept_relationship_stage cr
    on cr.concept_code_2 = e.concept_code
   and cr.relationship_id = 'Maps to'
   and cr.vocabulary_id_1 = (select vocabulary_id from drug_concept_stage where rownum=1)
   and cr.vocabulary_id_2 = 'RxNorm Extension'
 where cr.concept_code_1 not in (select from_code from map_drug);

insert into map_drug (from_code, to_id, map_order)
select   distinct  cr.concept_code_1,first_value (r.concept_id) over (partition by cr.concept_code_1 order by rc2.precedence), '3'  -- Kick Quant factor out
from r_existing r
  join ex e
    on r.i_combo = e.ri_combo and r.d_combo = e.rd_combo and r.bn_id = e.bn_id
   and r.quant_value = 0 and r.quant_unit_id = 0 and r.bs = 0 and r.mf_id=0
   and e.concept_id like '-%'
  join relationship_to_concept rc  on rc.concept_id_2 = e.df_id
  join relationship_to_concept rc2 on rc.concept_code_1 = rc2.concept_code_1 and rc2.concept_id_2 = r.df_id
  join concept_relationship_stage cr
    on cr.concept_code_2 = e.concept_code
   and cr.relationship_id = 'Maps to'
   and cr.vocabulary_id_1 = (select vocabulary_id from drug_concept_stage where rownum=1)
   and cr.vocabulary_id_2 = 'RxNorm Extension'
 where cr.concept_code_1 not in (select from_code from map_drug);
  
insert into map_drug (from_code, to_id, map_order)
select   distinct  cr.concept_code_1,first_value (r.concept_id) over (partition by cr.concept_code_1 order by rc2.precedence), '3'  -- Kick BN out, save Quant factor 
from r_existing r
  join ex e
    on r.i_combo = e.ri_combo and r.d_combo = e.rd_combo
   and r.quant_value = e.r_value and r.quant_unit_id = e.quant_unit_id and r.bs = 0 and r.mf_id=0 and r.bn_id = 0
   and e.concept_id like '-%'
  join relationship_to_concept rc  on rc.concept_id_2 = e.df_id
  join relationship_to_concept rc2 on rc.concept_code_1 = rc2.concept_code_1 and rc2.concept_id_2 = r.df_id
  join concept_relationship_stage cr
    on cr.concept_code_2 = e.concept_code
   and cr.relationship_id = 'Maps to'
   and cr.vocabulary_id_1 = (select vocabulary_id from drug_concept_stage where rownum=1)
   and cr.vocabulary_id_2 = 'RxNorm Extension'
 where cr.concept_code_1 not in (select from_code from map_drug);


insert into map_drug (from_code, to_id, map_order)
select  distinct  cr.concept_code_1,first_value (r.concept_id) over (partition by cr.concept_code_1 order by rc2.precedence), '4'  -- Map Branded Drug to corresponding Clinical Drug (save box size)
from r_existing r
  join ex e
    on r.i_combo = e.ri_combo and r.d_combo = e.rd_combo and r.bs = e.bs
   and r.bn_id = 0  and r.quant_value = 0 and r.quant_unit_id = 0 and r.mf_id=0
   and e.concept_id like '-%'
  join relationship_to_concept rc  on rc.concept_id_2 = e.df_id
  join relationship_to_concept rc2 on rc.concept_code_1 = rc2.concept_code_1 and rc2.concept_id_2 = r.df_id 
  join concept_relationship_stage cr
    on cr.concept_code_2 = e.concept_code
   and cr.relationship_id = 'Maps to'
   and cr.vocabulary_id_1 = (select vocabulary_id from drug_concept_stage where rownum=1)
   and cr.vocabulary_id_2 = 'RxNorm Extension'
 where cr.concept_code_1 not in (select from_code from map_drug);
 

 
 insert into map_drug (from_code, to_id, map_order)
select  distinct  cr.concept_code_1,first_value (r.concept_id) over (partition by cr.concept_code_1 order by rc2.precedence), '5'  -- Map Branded Drug to corresponding Clinical Drug
from r_existing r
  join ex e
    on r.i_combo = e.ri_combo and r.d_combo = e.rd_combo
   and r.bn_id = 0  and r.quant_value = 0 and r.quant_unit_id = 0 and r.bs = 0 and r.mf_id=0
   and e.concept_id like '-%'
  join relationship_to_concept rc  on rc.concept_id_2 = e.df_id
  join relationship_to_concept rc2 on rc.concept_code_1 = rc2.concept_code_1 and rc2.concept_id_2 = r.df_id   
  join concept_relationship_stage cr
    on cr.concept_code_2 = e.concept_code
   and cr.relationship_id = 'Maps to'
   and cr.vocabulary_id_1 = (select vocabulary_id from drug_concept_stage where rownum=1)
   and cr.vocabulary_id_2 = 'RxNorm Extension'
 where cr.concept_code_1 not in (select from_code from map_drug);

insert into map_drug (from_code, to_id, map_order)
select  distinct  cr.concept_code_1,first_value (r.concept_id) over (partition by cr.concept_code_1 order by rc2.precedence), '6'  -- Branded Drug Form
from r_existing r
  join ex e
    on r.i_combo = e.ri_combo and r.bn_id = e.bn_id 
   and trim(r.d_combo) is null -- was ' ' in r_existing.d_combo
   and r.quant_value = 0 and r.quant_unit_id = 0 and r.bs = 0 and r.mf_id=0 
   and e.concept_id like '-%'
  join relationship_to_concept rc  on rc.concept_id_2 = e.df_id
  join relationship_to_concept rc2 on rc.concept_code_1 = rc2.concept_code_1 and rc2.concept_id_2 = r.df_id   
  join concept_relationship_stage cr
    on cr.concept_code_2 = e.concept_code
   and cr.relationship_id = 'Maps to'
   and cr.vocabulary_id_1 = (select vocabulary_id from drug_concept_stage where rownum=1)
   and cr.vocabulary_id_2 = 'RxNorm Extension'
 where cr.concept_code_1 not in (select from_code from map_drug);

insert into map_drug (from_code, to_id, map_order)
select  distinct cr.concept_code_1, r.concept_id, '7'  -- Branded Drug Com
from r_existing r
  join ex e
    on r.i_combo = e.ri_combo and r.d_combo = e.rd_combo and r.bn_id = e.bn_id
   and r.df_id = 0 and r.quant_value = 0 and r.quant_unit_id = 0 and r.bs = 0 and r.mf_id=0  
   and e.concept_id like '-%'
  join concept_relationship_stage cr
    on cr.concept_code_2 = e.concept_code
   and cr.relationship_id = 'Maps to'
   and cr.vocabulary_id_1 = (select vocabulary_id from drug_concept_stage where rownum=1)
   and cr.vocabulary_id_2 = 'RxNorm Extension'
 where cr.concept_code_1 not in (select from_code from map_drug);
 
 insert into map_drug (from_code, to_id, map_order)
select  distinct  cr.concept_code_1,first_value (r.concept_id) over (partition by cr.concept_code_1 order by rc2.precedence), '8'  -- Clinical Drug Form
from r_existing r
  join ex e
    on r.i_combo = e.ri_combo
   and trim(r.d_combo) is null 
   and r.bn_id = 0 and r.quant_value = 0 and r.quant_unit_id = 0 and r.bs = 0 and r.mf_id=0 
   and e.concept_id like '-%'
  join relationship_to_concept rc  on rc.concept_id_2 = e.df_id
  join relationship_to_concept rc2 on rc.concept_code_1 = rc2.concept_code_1 and rc2.concept_id_2 = r.df_id   
  join concept_relationship_stage cr
    on cr.concept_code_2 = e.concept_code
   and cr.relationship_id = 'Maps to'
   and cr.vocabulary_id_1 = (select vocabulary_id from drug_concept_stage where rownum=1)
   and cr.vocabulary_id_2 = 'RxNorm Extension'
 where cr.concept_code_1 not in (select from_code from map_drug);
 
insert into map_drug (from_code, to_id, map_order)
with e as (
select ex.concept_id, concept_code, trim(regexp_substr(rd_combo, '[^\-]+', 1, levels.column_value)) as rd_combo,
trim(regexp_substr(ri_combo, '[^\-]+', 1, levels.column_value)) as ri_combo, regexp_count(ri_combo,'-') as cnt
from  ex,
table(cast(multiset(select level from dual connect by level <= length (regexp_replace(rd_combo, '[^\-]+'))+1) as sys.OdciNumberList))
levels),
     r as (
select count(r.concept_id) over (partition by e.concept_id) as cnt_2, e.concept_id, r.concept_id as r_concept_id
from e 
join r_existing r
on r.i_combo = e.ri_combo and r.d_combo = e.rd_combo and concept_class_id = 'Clinical Drug Comp')
select distinct cr.concept_code_1, r_concept_id, '9' -- Clinical Drug Comp
from r join e using (concept_id)
  join concept_relationship_stage cr
    on cr.concept_code_2 = e.concept_code
   and cr.relationship_id = 'Maps to'
   and cr.vocabulary_id_1 = (select vocabulary_id from drug_concept_stage where rownum=1)
   and cr.vocabulary_id_2 = 'RxNorm Extension'
 where cr.concept_code_1 not in (select from_code from map_drug)
and cnt_2=cnt+1 -- take only those where components counts are equal
; 

insert into map_drug (from_code, to_id, map_order)
select distinct i.concept_code_1, c.concept_id,'10' -- Drug to ingredient
from internal_relationship_stage i
join drug_concept_stage on i.concept_code_2 = concept_code and concept_class_id = 'Ingredient'
join concept_relationship_stage cr on cr.concept_code_1 = concept_code and relationship_id = 'Source - RxNorm eq'
join concept c on c.concept_code = cr.concept_code_2 and c.vocabulary_id like 'Rx%'
where i.concept_code_1 not in (select from_code from map_drug)
;

insert into map_drug (from_code, to_id, map_order)
select distinct i.concept_code_2, c.concept_id,'11' -- add the set of source attributes
from internal_relationship_stage i
join drug_concept_stage on i.concept_code_2 = concept_code and concept_class_id in ('Ingredient','Brand Name','Suppier','Dose Form')
join concept_relationship_stage cr on cr.concept_code_1 = concept_code and relationship_id = 'Source - RxNorm eq'
join concept c on c.concept_code = cr.concept_code_2 and c.vocabulary_id like 'Rx%'
where i.concept_code_2 not in (select from_code from map_drug)
; 

--Proceed packs
insert into map_drug (from_code, to_id, map_order) -- existing mapping
select distinct pack_concept_code,pack_concept_id, '12'
from q_existing_pack q
join r_existing_pack using(components, cnt, bn_id, bs, mf_id)
;
insert into map_drug (from_code, to_id, map_order) -- Map Packs to corresponding Rx Packs without a supplier 
select distinct pack_concept_code,pack_concept_id, '13'
from q_existing_pack q
join r_existing_pack using(components, cnt, bn_id, bs)
where pack_concept_code not in (select from_code from map_drug)
;
insert into map_drug (from_code, to_id, map_order) -- Map Packs to corresponding Rx Packs without a supplier and box_size
select distinct pack_concept_code,pack_concept_id, '14' 
from q_existing_pack q
join r_existing_pack using(components, cnt, bn_id)
where pack_concept_code not in (select from_code from map_drug)
;
insert into map_drug (from_code, to_id, map_order) -- Map Packs to corresponding Rx Packs without a supplier, box size and brand name
select distinct pack_concept_code,pack_concept_id, '15'
from q_existing_pack q
join r_existing_pack using(components, cnt)
where pack_concept_code not in (select from_code from map_drug)
;

delete map_drug 
where from_code like 'OMOP%' --delete newly created concepts not to overload concept table
; 

--delete all unnecessary concepts
truncate table concept_relationship_stage;
truncate table pack_content_stage;
truncate table drug_strength_stage;

insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select from_code, c.concept_code, dc.vocabulary_id, c.vocabulary_id,
case when dc.concept_class_id in ('Ingredient','Brand Name','Suppier','Dose Form') then 'Source - RxNorm eq'
     else 'Maps to' end,
sysdate,to_date ('20991231', 'yyyymmdd')  
from map_drug m
join drug_concept_stage dc on dc.concept_code = m.from_code
join concept c on to_id = c.concept_id
union
select concept_code, concept_code, vocabulary_id, vocabulary_id, 'Maps to', sysdate,to_date ('20991231', 'yyyymmdd')  
from drug_concept_stage where domain_id = 'Device'
;
delete concept_stage 
where concept_code not in (select from_code from map_drug) and domain_id = 'Drug' --save devices
;
