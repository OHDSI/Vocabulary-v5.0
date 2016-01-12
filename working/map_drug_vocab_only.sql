-- This is not fully ready and commented yet 12-Jan-2016

/************************************************
* Compare new drug vocabulary q to existing one r
************************************************/

-- Create lookup tables for existing vocab (RxNorm and new ones)
-- Create table containing ingredients for each drug
drop table r_drug_ing cascade constraints purge;
create table r_drug_ing as
  select de.concept_id as drug_id, an.concept_id as ing_id
  from devv5.concept_ancestor a 
  join devv5.concept an on a.ancestor_concept_id=an.concept_id and an.concept_class_id='Ingredient' and an.vocabulary_id='RxNorm'
  join devv5.concept de on de.concept_id=a.descendant_concept_id and de.concept_class_id!='Ingredient' -- and de.concept_class_id='Branded Drug Comp'
;
-- count number of ingredients for each drug
drop table r_ing_count cascade constraints purge;
create table r_ing_count as
  select drug_id as did, count(*) as cnt from r_drug_ing group by drug_id
;
-- Set all counts for Clinical Drug Comp to null, so in comparisons it can match whatever number necessary. Reason is that, like ingredients, Clinical Drug Comp is always only one ingredient
update r_ing_count set cnt=null where did in (select concept_id from devv5.concept where concept_class_id='Clinical Drug Comp');

create index x_r_drug_ing on r_drug_ing(drug_id, ing_id);

-- Create lookup tables for query vocab (new vocab)
drop table q_drug_ing cascade constraints purge;
create table q_drug_ing as
-- for each drug code list standard ingredient (translated ID and original code)
select drug.concept_code as drug_code, nvl(ing.concept_id, 0) as ing_id, i.concept_code as ing_code -- if ingredient is not mapped use 0 to get the right count
from drug_concept_stage i
left join relationship_to_concept r1 on r1.concept_code_1=i.concept_code
left join devv5.concept ing on ing.concept_id=r1.concept_id_2 -- link standard ingredients to existing ones
join internal_relationship_stage r2 on r2.concept_code_2=i.concept_code
join drug_concept_stage drug on drug.concept_class_id not in ('Unit', 'Ingredient', 'Brand Name', 'Non-Drug Prod', 'Dose Form') and drug.concept_code=r2.concept_code_1
where i.concept_class_id='Ingredient'
;
drop table q_ing_count cascade constraints purge;
create table q_ing_count as
  select drug_code as dcode, count(*) as cnt from q_drug_ing group by drug_code
;
create index x_q_drug_ing on q_drug_ing(drug_code, ing_id);

-- create table that lists for each ingredient all drugs continaing it from q and r
drop table match cascade constraints purge;
create table match as
  select q.ing_id as r_iid, q.ing_code as q_icode, q.drug_code as q_dcode, r.drug_id as r_did
  from q_drug_ing q join r_drug_ing r on q.ing_id=r.ing_id -- match query and result drug on common ingredient
;
create index x_match on match(q_dcode, r_did);

-- create table with all drugs in q and r and the number of ingredients they share
drop table shared_ing cascade constraints purge;
create table shared_ing as
select r_did, q_dcode, count(*) as cnt from match group by r_did, q_dcode
;
-- Set all counts for Clinical Drug Comp to null, so in comparisons it can match whatever number necessary. Reason is that, like ingredients, Clinical Drug Comp is always only one ingredient
update shared_ing set cnt=null where r_did in (select concept_id from devv5.concept where concept_class_id='Clinical Drug Comp');

-- Create table that matches drugs q to r, based Form, Brand Name (if exists), and dose. Does not take into account box size or quantity
drop table q_to_r_anydose cascade constraints purge;
create table q_to_r_anydose as
-- create table with all query drug codes q_dcode mapped to standard drug concept ids r_did, irrespective of the correct dose
with m as (select distinct m.*, rc.cnt as rc_cnt from match m
  join q_ing_count qc on qc.dcode=m.q_dcode -- count number of ingredients on query (left side) drug
  join r_ing_count rc on rc.did=m.r_did and qc.cnt=nvl(rc.cnt, qc.cnt) -- count number of ingredients on result (right side) drug. In case of Clinical Drug Comp the number should always match 
  join shared_ing on shared_ing.r_did=m.r_did and shared_ing.q_dcode=m.q_dcode and nvl(shared_ing.cnt, qc.cnt)=qc.cnt -- and make sure the number of shared ingredients is the same as the total number of ingredients for both q and r
) 
select * from (
  select 
    m.q_dcode, m.q_icode, m.r_did, m.r_iid, 
-- remove the iterations of all the different matches to 0
    case when r_df.concept_id_2 is null then null else q_df.precedence end as df_prec, 
    case when r_bn.concept_id_2 is null then null else q_bn.precedence end as bn_prec,
    m.rc_cnt -- get the number of ingredients in the r. It's set to null for ingredients and Clin Drug Comps, and we need that for the next step
  -- get ingredients and their counts to match
  from m m
  
  -- get the Dose Forms for each q and r, if has no Form use 1, 0 if not mapped
  left join (
    select r.concept_code_1, m.concept_id_2, nvl(m.precedence, 1) as precedence
    from internal_relationship_stage r -- if Dose Form exists but not mapped use 0
    join drug_concept_stage on concept_code=r.concept_code_2 and concept_class_id = 'Dose Form'-- Dose Form of q
    join relationship_to_concept m on m.concept_code_1=r.concept_code_2 -- left join if not 
  ) q_df on q_df.concept_code_1=m.q_dcode 
  left join (
    select r.concept_id_1, r.concept_id_2 from devv5.concept_relationship r
    join devv5.concept on concept_id=r.concept_id_2 and concept_class_id ='Dose Form' -- Dose Form of r
    where r.invalid_reason is null and r.relationship_id='RxNorm has dose form'
  ) r_df on r_df.concept_id_1=m.r_did
  
  -- get Brand Name for q and r, if not Branded use 1 for Clinical, 0 if not mapped
  left join (
    select r.concept_code_1, m.concept_id_2, nvl(m.precedence, 1) as precedence
    from internal_relationship_stage r 
    join drug_concept_stage on concept_code=r.concept_code_2 and concept_class_id = 'Brand Name' 
    join relationship_to_concept m on m.concept_code_1=r.concept_code_2
  ) q_bn on q_bn.concept_code_1=m.q_dcode
  left join (
    select r.concept_id_1, r.concept_id_2 -- if no Brand Name exists (Clinical Drug) return 0
    from devv5.concept_relationship r
    join devv5.concept on concept_id=r.concept_id_2 and concept_class_id ='Brand Name'
    where r.invalid_reason is null 
  ) r_bn on r_bn.concept_id_1=m.r_did 
  
  where coalesce(q_bn.concept_id_2, /* q_bn.concept_id_2, */0)=coalesce(r_bn.concept_id_2, q_bn.concept_id_2, 0) -- Allow matching of the same Brand Name or no Brand Name, but not another Brand Name
  and coalesce(q_df.concept_id_2, /*q_df.concept_id_2, */0)=coalesce(r_df.concept_id_2, q_df.concept_id_2, 0) -- Allow matching of the same Dose Form or no Dose Form, but not another Dose Form´
union
  select q_dcode, q_icode, r_iid as r_did, r_iid, null as df_prec, null as bn_prec, null as rc_cnt from m-- add just the ingredients
)
;

-- Create temp tables for speed
-- create for each drug/ingredient q to r pair two coefficients: Do the amounts come close and do the units comply
drop table q_to_r_wdose purge;
create table q_to_r_wdose as
with q as (
  select q_ds.drug_concept_code, q_ds.ingredient_concept_code, 
  q_ds.amount_value*q_ds_a.conversion_factor as amount_value, q_ds_a.concept_id_2 as amount_unit_concept_id, 
  q_ds.numerator_value*q_ds_n.conversion_factor as numerator_value, q_ds_n.concept_id_2 as numerator_unit_concept_id,
  nvl(q_ds.denominator_value, 1)*q_ds_d.conversion_factor as denominator_value, q_ds_d.concept_id_2 as denominator_unit_concept_id,
  coalesce(q_ds_a.precedence, q_ds_n.precedence, q_ds_d.precedence) as u_prec
  from drug_strength_stage q_ds
  left join relationship_to_concept q_ds_a on q_ds_a.concept_code_1=q_ds.amount_unit -- amount units
  left join relationship_to_concept q_ds_n on q_ds_n.concept_code_1=q_ds.numerator_unit -- numerator units
  left join relationship_to_concept q_ds_d on q_ds_d.concept_code_1=q_ds.denominator_unit -- denominator units
), r as (
-- drug_strength of r
  select 
    r_ds.drug_concept_id, r_ds.ingredient_concept_id, 
    r_ds.amount_value, r_ds.amount_unit_concept_id,
    r_ds.numerator_value, r_ds.numerator_unit_concept_id,
    nvl(r_ds.denominator_value, 1) as denominator_value, -- Quantified have a value in the denominator, the others haven't.
    r_ds.denominator_unit_concept_id
  from da_france.drug_strength r_ds -- CHANGE BEFORE RELEASE and remove schema
)
select 
  q_dcode, q_icode, r_did, r_iid, nvl(df_prec, 100) as df_prec, nvl(bn_prec, 100) as bn_prec, nvl(u_prec, 100) as u_prec,
  case when div>1 then 1/div else div end as div, -- the one the closest to 1 wins, but the range is 0-1, which is the opposite direction of the other ones
  unit as u_match, rc_cnt
from (
  select distinct m.*, case when r.drug_concept_id is null then 0 else q.u_prec end as u_prec,
    case
      when r.drug_concept_id is null then 1 -- if no drug_strength exist (Drug Forms etc.)
      when q.amount_value is not null and r.amount_value is not null then q.amount_value/r.amount_value
      when q.numerator_unit_concept_id=8554 and r.numerator_unit_concept_id=8576 and r.denominator_unit_concept_id=8587 then (q.numerator_value*10)/(r.numerator_value/r.denominator_value) -- % vs mg/mL
      when q.numerator_unit_concept_id=8554 and r.numerator_unit_concept_id!=8554 then (q.numerator_value/100)/(r.numerator_value/r.denominator_value) -- percent in one but not in the other
      when q.numerator_unit_concept_id!=8554 and r.numerator_unit_concept_id=8554 then (q.numerator_value/q.denominator_value)/(r.numerator_value/100) -- percent in the other but not in one
      when q.numerator_value is not null and r.numerator_value is not null then (q.numerator_value/q.denominator_value)/(r.numerator_value/r.denominator_value) -- denominator empty unless Quant
    else 0 end as div,
    case 
      when r.drug_concept_id is null then 1 -- if no drug_strength exist (Drug Forms etc.)
      when q.amount_unit_concept_id=r.amount_unit_concept_id then 1
      when q.numerator_unit_concept_id=8554 and r.numerator_unit_concept_id=8576 and r.denominator_unit_concept_id=8587 then 1 -- % vs mg/mL
      when q.numerator_unit_concept_id=8554 and r.numerator_unit_concept_id=r.denominator_unit_concept_id then 1 -- % vs mg/mg or mL/mL
      when q.numerator_unit_concept_id=q.denominator_unit_concept_id and r.numerator_unit_concept_id=8554 then 1 -- g/g, mg/mg or mL/mL vs %
      when q.numerator_unit_concept_id=r.numerator_unit_concept_id and q.denominator_unit_concept_id=r.denominator_unit_concept_id then 1
    else 0 end as unit
  from q_to_r_anydose m
  -- drug strength for each q ingredient
  left join q on q.drug_concept_code=m.q_dcode and q.ingredient_concept_code=m.q_icode
  -- drug strength for each r ingredient 
  left join r on r.drug_concept_id=m.r_did and r.ingredient_concept_id=m.r_iid
)
;

-- remove all multiple mappings
delete from q_to_r_wdose
where rowid in (
  select rowid from (
    select rowid,
      row_number() over (partition by q_dcode, q_icode, df_prec, bn_prec, u_prec order by div desc) rn
    from q_to_r_wdose
  )
  where rn > 1    
)
;

-- Remove all those where not everything fits
drop table q_to_r purge;
-- table has to be created separately because both subsequent queries define one field as null
create table q_to_r as
select q_dcode, r_did, r_iid, bn_prec, df_prec, u_prec, rc_cnt from q_to_r_wdose
where 1=0;

insert into q_to_r
select 
  a.q_dcode, a.r_did, null as r_iid, a.bn_prec, a.df_prec, a.u_prec, a.rc_cnt
from ( -- take the distinct set of drug-drug paris with the same brandname, doseform and unit precedence
  select q_dcode, r_did, bn_prec, df_prec, u_prec, rc_cnt, count(8) as cnt from q_to_r_wdose where nvl(rc_cnt, 0)>1 -- only for those where multiple ingredients could be contained in the concept (everything but Ingredient and Clin Drug Comp)
-- and q_dcode = '3645105'
  group by q_dcode, r_did, bn_prec, df_prec, u_prec, rc_cnt
) a
-- but make sure there are sufficient amount of components (ingredients) in each group
where a.cnt=a.rc_cnt
-- group within each drug-to drug pair, with the same brandname, doseform and unit precedence numbers
group by a.q_dcode, a.r_did, a.bn_prec, a.df_prec, a.u_prec, a.rc_cnt
-- not one of the components should miss the match
having not exists (
  select 1 
  from q_to_r_wdose m -- join the set of the same 
  where a.q_dcode=m.q_dcode and a.r_did=m.r_did
  and a.bn_prec=m.bn_prec and a.df_prec=m.df_prec and a.u_prec=m.u_prec
  and (m.div<0.9 or m.u_match=0)
)
;

-- Second step add Ingredients and the correct Clinical Drug Components. Their number may not match the total number of Ingredients in the query drug
insert into q_to_r
select distinct q_dcode, r_did, r_iid, bn_prec, df_prec, u_prec, null as rc_cnt
from q_to_r_wdose
where nvl(rc_cnt, 1)=1 -- process only those that done have combinations (ingredients and Clin Drug Components)
and div>=0.9 and u_match=1
-- and q_dcode='3645105'
;

commit;

-- Get the best possible mapping
drop table best_map;
create table best_map as
with r as (
  select qr.*, c.concept_class_id from q_to_r qr join devv5.concept c on c.concept_id=qr.r_did
)
select distinct 
--   rcnt.*,
  rmap.* 
from (
  select 
-- cnt, cclass, bn_prec as p, df_prec as d, u_prec as u,
    q_dcode, 
    first_value(bn_prec) over (partition by q_dcode order by cclass, bn_prec, df_prec, u_prec) as bn_prec,
    first_value(df_prec) over (partition by q_dcode order by cclass, bn_prec, df_prec, u_prec) as df_prec,
    first_value(u_prec) over (partition by q_dcode order by cclass, bn_prec, df_prec, u_prec) as u_prec
  from (  
    select * from (
      select q_dcode, r_iid, bn_prec, df_prec, u_prec, cclass, count(8) as cnt
      from (
        select q_dcode, 
          r_iid, -- we need to group by ingredient for the concept classes that keep ingredients individually (Ing, Clin Drug Comp)
          bn_prec, df_prec, u_prec, 
          decode(concept_class_id,
            'Quant Branded Box', 1,
            'Quant Clinical Box', 2,
            'Branded Drug Box', 3,
            'Clinical Drug Box', 4,
            'Quant Clinical Drug', 5,
            'Quant Branded Drug', 6,
            'Branded Drug', 7,
            'Clinical Drug', 8,
            'Branded Drug Form', 9,
            'Clinical Drug Form', 10,
            'Branded Drug Comp', 11,
            'Clinical Drug Comp', 12,
            'Ingredient', 13,
            20
          ) as cclass
        from r 
      )
      group by q_dcode, r_iid, bn_prec, df_prec, u_prec, cclass
    ) where cclass in (12, 13) or cnt<2 -- either Ingredient/Clinica Drug Comp or single map
  ) 
) rcnt
join r rmap on rmap.q_dcode=rcnt.q_dcode and rmap.bn_prec=rcnt.bn_prec and rmap.df_prec=rcnt.df_prec and rmap.u_prec=rcnt.u_prec
-- where rcnt.q_dcode='1136003'-- '3195423' 3645105 1136004
;

commit; 

-- figure out whether there are still duplicates of the same ingredient and Clin Drug Form. It doesn't seem to happen, but would happen if 
select q_dcode, r_iid
;
select *
from best_map
where rc_cnt is null
and bn_prec=100 and df_prec=100
-- group by q_dcode, r_iid having count(8)>1
order by 1;

---------------------------------- Use for debugging
select r.concept_name, qr.* from q_to_r qr join devv5.concept r on r.concept_id=qr.r_did where qr.q_dcode='3645105';
select * from q_to_r where q_dcode='1017302'; -- and r_did=40054620;
select r.concept_name, qr.* from q_to_r_wdose qr join devv5.concept r on r.concept_id=qr.r_did where qr.q_dcode='1017302' order by r_did;
select q.concept_code, q.concept_name, r.concept_name from best_map m join devv5.concept r on r.concept_id=m.r_did join drug_concept_stage q on q.concept_code=m.q_dcode 
where 1=1
and q.concept_code='2442902'
-- and lower(q.concept_name) like '%spironolactone%' 
order by 1;
select * from q_to_r_wdose where q_dcode='2442902' order by 3, 7;
select * from q_to_r_wdose where q_dcode='1007902';-- and q_icode='OMOP22563';
select * from q_to_r where q_dcode='2442902';
select count(8) from q_to_r;

select * from q_drug_ing where drug_code='3134680';
select distinct m.*, rc.cnt as rc_cnt from match m
  left join q_ing_count qc on qc.dcode=m.q_dcode -- count number of ingredients on query (left side) drug
  left join r_ing_count rc on rc.did=m.r_did and qc.cnt=nvl(rc.cnt, qc.cnt) -- count number of ingredients on result (right side) drug. In case of Clinical Drug Comp the number should always match 
  left join shared_ing on shared_ing.r_did=m.r_did and shared_ing.q_dcode=m.q_dcode and nvl(shared_ing.cnt, qc.cnt)=qc.cnt -- and make sure the number of shared ingredients is the same as the total number of ingredients for both q and r
where m.q_dcode='3134680';
select * from match where q_dcode='3134680';
select * from drug_strength where drug_concept_id=19023828;
select * from drug_concept_stage where concept_code in ('1136003'); -- 1197205
select * from devv5.concept where concept_id in (40054620, 1539469);
select * from devv5.concept where lower(concept_name) like '%amlodipine%perindopril%' and vocabulary_id='RxNorm';
select * from drug_concept_stage where lower(concept_name) like '%ethanol%70%';
select q.concept_code, q.concept_name, r.concept_id, r.concept_name, qr.* from q_to_r qr
join devv5.concept r on r.concept_id=qr.r_did
join drug_concept_stage q on q.concept_code=qr.q_dcode
order by 1;

