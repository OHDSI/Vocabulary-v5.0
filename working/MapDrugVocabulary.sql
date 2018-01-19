/**************************************************
* Th  is script takes a drug vocabulary q and     *
* compares it to the existing drug vocabulary r   *
* The new vocabulary must be provided in the same *
* format as for generating a new drug vocabulary: *
* http://www.ohdsi.org/web/wiki/doku.php?id=documentation:international_drugs *
* As a result it creates records in the           *
* concept_relationship_stage table                *
*                                                 *
* To_do: Add quantification factor                *
* Suppport writing amount field                   *
**************************************************/
--truncate table concept_stage;
--truncate table concept_relationship_stage;
-- 1. Create lookup tables for existing vocab r (RxNorm and public country-specific ones)
-- Create table containing ingredients for each drug
--drop table r_drug_ing ;
create table r_drug_ing nologging as
  select de.concept_id as drug_id, an.concept_id as ing_id
  from concept_ancestor a 
  join concept an on a.ancestor_concept_id=an.concept_id and an.concept_class_id='Ingredient' 
    and an.vocabulary_id in ('RxNorm', 'RxNorm Extension') -- to be expanded as new vocabs are added
  join concept de on de.concept_id=a.descendant_concept_id  
    and de.vocabulary_id in ('RxNorm', 'RxNorm Extension')
    where an.invalid_reason is null 
;
-- Remove unparsable Albumin products that have no drug_strength entry: Albumin Human, USP 1 NS
delete from r_drug_ing where drug_id in (19094500, 19080557);
-- Count number of ingredients for each drug
--drop table r_ing_count;
create table r_ing_count nologging as
  select drug_id as did, count(*) as cnt from r_drug_ing group by drug_id
;
-- Set all counts for Ingredient and Clinical Drug Comp to null, so in comparisons it can match whatever number necessary. Reason is that, like ingredients, Clinical Drug Comp is always only one ingredient
update r_ing_count set cnt=null where did in (select concept_id from concept where concept_class_id in ('Clinical Drug Comp', 'Ingredient'));

--drop index x_r_drug_ing;
create index x_r_drug_ing on r_drug_ing(drug_id, ing_id) nologging;

-- Create lookup table for query vocab q (new vocab)
--drop table  q_drug_ing;
create table q_drug_ing nologging as
select drug.concept_code as drug_code, nvl(ing.concept_id, 0) as ing_id, i.concept_code as ing_code -- if ingredient is not mapped use 0 to still get the right ingredient count
from drug_concept_stage i
left join relationship_to_concept r1 on r1.concept_code_1=i.concept_code
left join concept ing on ing.concept_id=r1.concept_id_2 -- link standard ingredients to existing ones
join internal_relationship_stage r2 on r2.concept_code_2=i.concept_code
join drug_concept_stage drug on drug.concept_class_id not in ('Unit', 'Ingredient', 'Brand Name', 'Non-Drug Prod', 'Dose Form', 'Device', 'Observation') 
  and drug.domain_id='Drug' -- include only drug product concept classes
  and drug.concept_code=r2.concept_code_1
where i.concept_class_id='Ingredient'
and ing.invalid_reason is null
;
-- Count ingredients per drug
--drop table q_ing_count;
create table q_ing_count nologging as
  select drug_code as dcode, count(*) as cnt from q_drug_ing group by drug_code
;
create index x_q_drug_ing on q_drug_ing(drug_code, ing_id) nologging;

-- Create table that lists for each ingredient all drugs containing it from q and r
--drop table match;
create table match nologging as
  select q.ing_id as r_iid, q.ing_code as q_icode, q.drug_code as q_dcode, r.drug_id as r_did
  from q_drug_ing q join r_drug_ing r on q.ing_id=r.ing_id -- match query and result drug on common ingredient
;
create index x_match on match(q_dcode, r_did) nologging;

exec DBMS_STATS.GATHER_TABLE_STATS (ownname=> USER, tabname => 'match', estimate_percent => null, cascade => true);

-- Create table with all drugs in q and r and the number of ingredients they share
--drop table shared_ing;
create table shared_ing nologging as
select r_did, q_dcode, count(*) as cnt from match group by r_did, q_dcode
;
-- Set all counts for Clinical Drug Comp to null, so in comparisons it can match whatever number necessary. Reason is that, like ingredients, Clinical Drug Comp is always only one ingredient
update shared_ing set cnt=null where r_did in (select concept_id from concept where concept_class_id in ('Clinical Drug Comp', 'Ingredient'));

--drop table r_bn;
create table r_bn nologging as
select distinct descendant_concept_id as concept_id_1, concept_id_2
from concept_relationship join concept_ancestor on ancestor_concept_id=concept_id_1 
join concept bn on concept_id_2=bn.concept_id and bn.vocabulary_id in ('RxNorm', 'RxNorm Extension') and bn.concept_class_id='Brand Name'
join concept c on concept_id_1=c.concept_id 
join concept bd on descendant_concept_id=bd.concept_id and bd.vocabulary_id in ('RxNorm', 'RxNorm Extension') and bd.concept_class_id in
 ('Branded Drug Box', 'Quantified Branded Box', 'Branded Drug Comp', 'Quant Branded Drug', 'Branded Drug Form', 'Branded Drug', 'Marketed Product', 'Branded Pack', 'Clinical Pack') 
where concept_relationship.invalid_reason is null and relationship_id='Has brand name'
and c.concept_class_id !='Ingredient' and c.invalid_reason is null and c.vocabulary_id like 'RxNorm%'
and bd.invalid_reason is null and bn.invalid_reason is null
;

create index x_r_bn on r_bn(concept_id_1) nologging;
exec DBMS_STATS.GATHER_TABLE_STATS (ownname=> USER, tabname => 'r_bn', estimate_percent => null, cascade => true);
;
exec DBMS_STATS.GATHER_TABLE_STATS (ownname=> USER, tabname => 'shared_ing', estimate_percent => null, cascade => true)
;
create index x_shared_ing on shared_ing(q_dcode, r_did) nologging
;
-- Create table that matches drugs q to r, based on Ingredient, Dose Form and Brand Name (if exist). Dose, box size or quantity are not yet compared
--drop table q_to_r_anydose; 
create table q_to_r_anydose nologging as
-- create table with all query drug codes q_dcode mapped to standard drug concept ids r_did, irrespective of the correct dose
with m as (
select distinct m.*, rc.cnt as rc_cnt, r.precedence as i_prec
  from match m
  join q_ing_count qc on qc.dcode=m.q_dcode -- count number of ingredients on query (left side) drug
  join r_ing_count rc on rc.did=m.r_did and qc.cnt=nvl(rc.cnt, qc.cnt) -- count number of ingredients on result (right side) drug. In case of Clinical Drug Comp the number should always match 
  join shared_ing on shared_ing.r_did=m.r_did and shared_ing.q_dcode=m.q_dcode and nvl(shared_ing.cnt, qc.cnt)=qc.cnt -- and make sure the number of shared ingredients is the same as the total number of ingredients for both q and r
  join relationship_to_concept r on r.concept_code_1=m.q_icode and r.concept_id_2=m.r_iid
)
select distinct
  m.q_dcode, m.q_icode, m.r_did, m.r_iid, m.i_prec,
-- remove the iterations of all the different matches to 0
  case when r_df.concept_id_2 is null then null else q_df.precedence end as df_prec, 
  case when r_bn.concept_id_2 is null then null else q_bn.precedence end as bn_prec,
  case when r_sp.concept_id_2 is null then null else q_sp.precedence end as sp_prec,
  m.rc_cnt -- get the number of ingredients in the r. It's set to null for ingredients and Clin Drug Comps, and we need that for the next step
-- get ingredients and their counts to match
from m m
-- get the Dose Forms for each q and r
left join (
  select r.concept_code_1, m.concept_id_2, nvl(m.precedence, 1) as precedence
  from internal_relationship_stage r -- if Dose Form exists but not mapped use 0
  join drug_concept_stage on concept_code=r.concept_code_2 and concept_class_id = 'Dose Form'-- Dose Form of q
  join relationship_to_concept m on m.concept_code_1=r.concept_code_2 -- left join if not 
) q_df on q_df.concept_code_1=m.q_dcode 
left join (
  select r.concept_id_1, r.concept_id_2 from concept_relationship r
  join concept on concept_id=r.concept_id_2 and concept_class_id ='Dose Form' -- Dose Form of r
  where r.invalid_reason is null and r.relationship_id='RxNorm has dose form' and concept.invalid_reason is null
) r_df on r_df.concept_id_1=m.r_did
-- get Brand Name for q and r
left join (
  select r.concept_code_1, m.concept_id_2, nvl(m.precedence, 1) as precedence
  from internal_relationship_stage r  
  join drug_concept_stage on concept_code=r.concept_code_2 and concept_class_id = 'Brand Name' 
  join relationship_to_concept m on m.concept_code_1=r.concept_code_2
) q_bn on q_bn.concept_code_1=m.q_dcode
  left join r_bn on r_bn.concept_id_1=m.r_did and m.rc_cnt is not null -- only take Brand Names if they don't come from Ingredients or Clinical Drug Comps

-- get Supplier for q and r
left join (
  select r.concept_code_1, m.concept_id_2, nvl(m.precedence, 1) as precedence
  from internal_relationship_stage r 
  join drug_concept_stage on concept_code=r.concept_code_2 and concept_class_id = 'Supplier' 
  join relationship_to_concept m on m.concept_code_1=r.concept_code_2
) q_sp on q_sp.concept_code_1=m.q_dcode
left join (
  select r.concept_id_1, r.concept_id_2 
  from concept_relationship r
  join concept on concept_id=r.concept_id_2 and concept_class_id ='Supplier' 
  where r.invalid_reason is null 
) r_sp on r_sp.concept_id_1=m.r_did
--try the same with Box_size
left join (
select drug_concept_code, box_size from ds_stage where box_size is not null) q_bs on q_bs.drug_concept_code=m.q_dcode
left join 
(
select drug_concept_id, box_size from drug_strength where box_size is not null) r_bs on r_bs.drug_concept_id=m.r_did

left join (
select drug_concept_code, denominator_value*conversion_factor ||' '||concept_id_2  as quant_f from ds_stage ds
join relationship_to_concept rc on denominator_unit = rc.concept_code_1 and precedence =1 
 where denominator_value is not null) q_qnt on q_qnt.drug_concept_code=m.q_dcode
left join 
(
select drug_concept_id,  denominator_value ||' '|| denominator_unit_concept_id  as quant_f  from drug_strength where denominator_value is not null) r_qnt on r_qnt.drug_concept_id=m.r_did

-- remove comments if mapping should be done both upwards (standard) and downwards (to find a possible unique low-granularity solution)
where coalesce(q_bn.concept_id_2, /* r_bn.concept_id_2, */0)=coalesce(r_bn.concept_id_2, q_bn.concept_id_2, 0) -- Allow matching of the same Brand Name or no Brand Name, but not another Brand Name
and coalesce(q_df.concept_id_2, /*r_df.concept_id_2, */0)=coalesce(r_df.concept_id_2, q_df.concept_id_2, 0) -- Allow matching of the same Dose Form or no Dose Form, but not another Dose Form?
and coalesce(q_sp.concept_id_2, /*r_df.concept_id_2, */0)=coalesce(r_sp.concept_id_2, q_sp.concept_id_2, 0) -- Allow matching of the same Supplier or no Supplier, but not another Supplier
and coalesce(q_bs.box_size, /*q_bs.box_size, */0)=coalesce(r_bs.box_size, q_bs.box_size, 0) 
and coalesce(q_qnt.quant_f, /*r_sp.concept_id_2, */'X')=coalesce(r_qnt.quant_f, q_qnt.quant_f, 'X') 
;
--select * from q_to_r_wdose
--;
-- Add matching of dose and its units
--drop table q_to_r_wdose ;
create table q_to_r_wdose nologging as
-- Create two temp tables with all strength and unit information
with q as (
  select q_ds.drug_concept_code, q_ds.ingredient_concept_code, 
    q_ds.amount_value*q_ds_a.conversion_factor as amount_value, q_ds_a.concept_id_2 as amount_unit_concept_id, 
    q_ds.numerator_value*q_ds_n.conversion_factor as numerator_value, q_ds_n.concept_id_2 as numerator_unit_concept_id,
    nvl(q_ds.denominator_value, 1)*nvl(q_ds_d.conversion_factor, 1) as denominator_value, q_ds_d.concept_id_2 as denominator_unit_concept_id,
    coalesce(q_ds_a.precedence, q_ds_n.precedence, q_ds_d.precedence) as u_prec, box_size
  from ds_stage q_ds
  left join relationship_to_concept q_ds_a on q_ds_a.concept_code_1=q_ds.amount_unit -- amount units
  left join relationship_to_concept q_ds_n on q_ds_n.concept_code_1=q_ds.numerator_unit -- numerator units
  left join relationship_to_concept q_ds_d on q_ds_d.concept_code_1=q_ds.denominator_unit -- denominator units
), r as (
  select 
    r_ds.drug_concept_id, r_ds.ingredient_concept_id, 
    r_ds.amount_value, r_ds.amount_unit_concept_id,
    r_ds.numerator_value, r_ds.numerator_unit_concept_id,
    nvl(r_ds.denominator_value, 1) as denominator_value, -- Quantified have a value in the denominator, the others haven't.
    r_ds.denominator_unit_concept_id, box_size --once we get RxNorm Extension this value will be exist
  from drug_strength r_ds 
)
-- Create variables div as r amount / q amount, and unit as 1 for matching and 0 as non-matching 
select 
  q_dcode, q_icode, r_did, r_iid, nvl(df_prec, 100) as df_prec, nvl(bn_prec, 100) as bn_prec, nvl(u_prec, 100) as u_prec, i_prec,
  case when div>1 then 1/div else div end as div, -- the one the closest to 1 wins, but the range is 0-1, which is the opposite direction of the other ones
  unit as u_match, rc_cnt
from (
  select distinct m.*, case when r.drug_concept_id is null then 0 else q.u_prec end as u_prec,
    case
      when r.drug_concept_id is null then 1 -- if no drug_strength exist (Drug Forms etc.)
      when q.amount_value is not null and r.amount_value is not null then q.amount_value/r.amount_value
      when q.numerator_unit_concept_id=8554 and r.numerator_unit_concept_id=8576 and r.denominator_unit_concept_id=8587 then (q.numerator_value*10)/(r.numerator_value/r.denominator_value) -- % vs mg/mL
      when q.numerator_unit_concept_id=8554 and r.numerator_unit_concept_id!=8554 then (q.numerator_value/100)/(r.numerator_value/r.denominator_value) -- % in one but not in the other
      when q.numerator_unit_concept_id!=8554 and r.numerator_unit_concept_id=8554 then (q.numerator_value/q.denominator_value)/(r.numerator_value/100) -- % in the other but not in one
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
commit;

-- Remove all multiple mappings with close divs and keep the best
delete from q_to_r_wdose
where rowid in (
  select r from (
    select rowid as r,
      rank() over (partition by q_dcode, q_icode, df_prec, bn_prec, u_prec order by div desc, i_prec) rn
    from q_to_r_wdose
  )
  where rn > 1    
)
;
commit;

-- Remove all those where not everything fits
-- The table has to be created separately because both subsequent queries define one field as null
--drop table q_to_r ;
create table q_to_r nologging as
select q_dcode, r_did, r_iid, bn_prec, df_prec, u_prec, rc_cnt from q_to_r_wdose
where 1=0;

exec DBMS_STATS.GATHER_TABLE_STATS (ownname=> USER, tabname => 'q_to_r_wdose', estimate_percent => null, cascade => true)
;
create index q_to_r_wdose_q on q_to_r_wdose(q_dcode)nologging
;

insert /*+ APPEND */ into q_to_r
select 
  a.q_dcode, a.r_did, null as r_iid, a.bn_prec, a.df_prec, a.u_prec, a.rc_cnt
from ( -- take the distinct set of drug-drug pairs with the same Brand Name, Dose Form and unit precedence
-- only for those where multiple ingredients could be contained in the concept (everything but Ingredient and Clin Drug Comp)
  select q_dcode, r_did, bn_prec, df_prec, u_prec, rc_cnt, count(8) as cnt from q_to_r_wdose where nvl(rc_cnt, 0)>1 
  group by q_dcode, r_did, bn_prec, df_prec, u_prec, rc_cnt
) a
-- but make sure there are sufficient amount of components (ingredients) in each group
where a.cnt=a.rc_cnt
group by a.q_dcode, a.r_did, a.bn_prec, a.df_prec, a.u_prec, a.rc_cnt
-- not one of the components should miss the match
having not exists (
  select 1 
  from q_to_r_wdose m -- join the set of the same 
  where a.q_dcode=m.q_dcode and a.r_did=m.r_did
  and a.bn_prec=m.bn_prec and a.df_prec=m.df_prec and a.u_prec=m.u_prec 
-- Change the factor closer to 1 if matching should be tighter. Currently, anything within 10% amount will be considered a match.
  and (m.div<0.9 or m.u_match=0)
)
;
commit;

-- Second step add Ingredients and the correct Clinical Drug Components. Their number may not match the total number of Ingredients in the query drug
insert /*+ APPEND */ into q_to_r
select distinct q_dcode, r_did, r_iid, bn_prec, df_prec, u_prec, null as rc_cnt
from q_to_r_wdose
where nvl(rc_cnt, 1)=1 -- process only those that don't have combinations (Ingredients and Clin Drug Components)
and div>=0.9 and u_match=1
;
--possible mapping with different dosages for different ingredient, each ingredient should be unique
create table poss_map as
select distinct b.* from (
select dcs.concept_name as concept_name_1,dcs.concept_code, concept.concept_name as concept_name_2, concept.concept_id, RC_CNT, ingredient_concept_id, count (1) as cnt
 from q_to_r_anydose
join ds_stage ds1 on q_dcode = drug_concept_code
join drug_strength ds2 on r_did = drug_concept_id and r_iid = ingredient_concept_id
and 'x'|| nvl (ds1.numerator_value/nvl (ds1.DENOMINATOR_VALUE, 1), '0') = 'x'|| nvl (ds2.numerator_value/nvl (ds2.DENOMINATOR_VALUE, 1), '0')
and 'x'|| nvl (ds1.amount_value, '0')= 'x'|| nvl (ds2.amount_value, '0') 
join drug_concept_stage dcs on dcs.concept_code = Q_DCODE 
join concept on concept_id = R_DID and concept.invalid_reason is null
where rc_cnt >1 
group by dcs.concept_name,dcs.concept_code, concept.concept_name, concept.concept_id, RC_CNT,  ingredient_concept_id
) a-- where cnt >= rc_cnt
join 
(
select dcs.concept_name as concept_name_1,dcs.concept_code, concept.concept_name as concept_name_2, concept.concept_id , RC_CNT,  count (1) as cnt
 from q_to_r_anydose
join ds_stage ds1 on q_dcode = drug_concept_code
join drug_strength ds2 on r_did = drug_concept_id and r_iid = ingredient_concept_id
and 'x'|| nvl (ds1.numerator_value/nvl (ds1.DENOMINATOR_VALUE, 1), '0') = 'x'|| nvl (ds2.numerator_value/nvl (ds2.DENOMINATOR_VALUE, 1), '0')
and 'x'|| nvl (ds1.amount_value, '0')= 'x'|| nvl (ds2.amount_value, '0') 
join drug_concept_stage dcs on dcs.concept_code = Q_DCODE 
join concept on concept_id = R_DID and concept.invalid_reason is null
where rc_cnt >1 
group by dcs.concept_name,dcs.concept_code, concept.concept_name, concept.concept_id ,RC_CNT
) b on a.CONCEPT_CODE = b.concept_code and a.concept_id = b.concept_id
join 
(
select dcs.concept_name as concept_name_1,dcs.concept_code, concept.concept_name as concept_name_2, concept.concept_id, RC_CNT, ingredient_concept_code, count (1) as cnt from q_to_r_anydose
join ds_stage ds1 on q_dcode = drug_concept_code
join drug_strength ds2 on r_did = drug_concept_id and r_iid = ingredient_concept_id
and 'x'|| nvl (ds1.numerator_value/nvl (ds1.DENOMINATOR_VALUE, 1), '0') = 'x'|| nvl (ds2.numerator_value/nvl (ds2.DENOMINATOR_VALUE, 1), '0')
and 'x'|| nvl (ds1.amount_value, '0')= 'x'|| nvl (ds2.amount_value, '0') 
join drug_concept_stage dcs on dcs.concept_code = Q_DCODE 
join concept on concept_id = R_DID and concept.invalid_reason is null
where rc_cnt >1 
group by dcs.concept_name,dcs.concept_code, concept.concept_name, concept.concept_id, RC_CNT,  ingredient_concept_code
) c
on a.CONCEPT_CODE = c.concept_code and a.concept_id = c.concept_id
where  b.cnt >= b.rc_cnt and a.cnt =1 and c.cnt = 1
; 
--insert possible mappings if they are not already present in q_to_r
insert into q_to_r (Q_DCODE,R_DID) 
select concept_code, concept_id from poss_map b where not exists (select 1 from q_to_r a where a.Q_DCODE = concept_code and R_DID = concept_id)
;
commit;
--full relationship with classes within RxNorm
--drop table cnc_rel_class; 
create table cnc_rel_class as
select ri.*, ci.concept_class_id as concept_class_id_1 , c2.concept_class_id as concept_class_id_2 
from concept_relationSHIp ri 
join concept ci on ci.concept_id = ri.concept_id_1 
join concept c2 on c2.concept_id = ri.concept_id_2 
where ci.vocabulary_id like  'RxNorm%' and ri.invalid_reason is null and ci.invalid_reason is null 
and  c2.vocabulary_id like 'RxNorm%'  and c2.invalid_reason is null 
;
--define order as combination of attributes number and each attribute weight
--drop table attrib_cnt; 
create table attrib_cnt as
select concept_id_1, count (1)|| max(weight) as weight  from (
--need to go throught Drug Form / Component to get the Brand Name
select distinct concept_id_1, 3 as weight from 
r_bn
union ALL
select concept_id_1, 1 from cnc_rel_class where concept_class_id_2 in ('Supplier')
union ALL
select concept_id_1, 5 from cnc_rel_class where concept_class_id_2 in ('Dose Form')
union ALL
select distinct drug_concept_id, 6 from (
select * from drug_strength where nvl (numerator_value, amount_value) is not null)
--remove comments when Box_size will be present 
union
select distinct drug_concept_id, 2 from  (
select * from drug_strength where Box_size is not null)
union ALL
select distinct drug_concept_id, 4 from  (
select * from drug_strength where DENOMINATOR_VALUE is not null)
) group by concept_id_1
union
select concept_id , '0' from concept where concept_class_id ='Ingredient' and vocabulary_id like 'RxNorm%'
;
--drop table Q_DCODE_to_hlc
;
create table Q_DCODE_to_hlc as
select q.Q_DCODE from q_to_r q join concept c on concept_id = q.R_DID where ( CONCEPT_CLASS_ID in 
('Branded Drug Box', 'Quant Branded Box', 'Quant Branded Drug', 'Branded Drug', 'Marketed Product', 'Branded Pack', 'Clinical Pack' , 
'Clinical Drug Box', 'Quant Clinical Box', 'Clinical Branded Drug',  'Clinical Drug', 'Marketed Product')
or concept_name like '% / %' ) and c.standard_concept = 'S' 
;
--drop table dupl;
create table dupl as(
select st.*, c.concept_class_id,attrib_cnt.*  from q_to_r q join attrib_cnt on r_did  = concept_id_1 
join drug_concept_stage ds on Q_DCODE = ds.concept_code
join concept c on c.concept_id = q.R_DID 
join (select drug_concept_code, count (1) as cnt from ds_stage group by drug_concept_code having count(1) >1)st on drug_concept_code = Q_DCODE 
where Q_DCODE not in (select Q_DCODE from Q_DCODE_to_hlc)
)
;
 --best map
--drop table best_map;
create table best_map as 
select distinct  first_value(concept_id_1) over (partition by q_dcode order by weight desc) as r_did , q_dcode
from attrib_cnt join q_to_r on r_did  = concept_id_1 
where Q_DCODE not in ( select drug_concept_code from dupl)
union select CONCEPT_ID_1, drug_concept_code from dupl where WEIGHT = 0
;

commit;
-- Write concept_relationship_stage
--still thinking about update process
--truncate table concept_relationship_stage;
insert /*+ APPEND */ into concept_relationship_stage
						(concept_code_1,
						concept_code_2,
						vocabulary_id_1,
						vocabulary_id_2,
						relationship_id,
						valid_start_date,
						valid_end_date,
						invalid_reason)
select 
  q_dcode as concept_code_1,
  c.concept_code as concept_code_2,  
  (select vocabulary_id from drug_concept_stage where rownum=1) as vocabulary_id_1,
  c.vocabulary_id as vocabulary_id_2,
  'Maps to' as relationship_id,
  (SELECT latest_update FROM vocabulary WHERE vocabulary_id=(select vocabulary_id from drug_concept_stage where rownum=1)) as valid_start_date,
  TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
  null as invalid_reason
from best_map m
join concept c on c.concept_id=m.r_did and c.vocabulary_id like 'RxNorm%'
;
commit
;
--uncomment when it's a part of a drug vocabulary when creating concept_stage with this script 
/* 
--add source drugs as a part concept_stage
-- Write source drugs as non-standard
insert into concept_stage (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
select distinct
  null as concept_id, 
  concept_name,
  domain_id,
  vocabulary_id,
 concept_class_id as concept_class_id,
  null as standard_concept, -- Source Concept, no matter whether active or not
  concept_code,
  nvl(valid_start_date, (select latest_update from vocabulary v where v.vocabulary_id=(select vocabulary_id from drug_concept_stage where rownum=1))) as valid_start_date,
  nvl(valid_end_date, to_date('2099-12-31', 'yyyy-mm-dd')) as valid_end_date,
  case invalid_reason when 'U' then 'D' else invalid_reason end as invalid_reason -- if they are 'U' they get mapped using Maps to to RxNorm/E anyway
from drug_concept_stage
where concept_class_id in ('Procedure Drug') -- but no Unit
  and nvl(domain_id, 'Drug')='Drug'
;
*/
commit;
/*
--uncomment when it's a part of a drug vocabulary when creating concept_stage with this script
-- Write source devices as standard (unless deprecated)
insert  into concept_stage (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
select distinct
  null as concept_id, 
  concept_name,
  domain_id,
  vocabulary_id,
  nvl(source_concept_class_id, concept_class_id) as concept_class_id,
  case when invalid_reason is not null then null else 'S' end as standard_concept, -- Devices are not mapped
  concept_code,
  nvl(valid_start_date, (select latest_update from vocabulary v where v.vocabulary_id=(select vocabulary_id from drug_concept_stage where rownum=1))) as valid_start_date,
  nvl(valid_end_date, to_date('2099-12-31', 'yyyy-mm-dd')) as valid_end_date,
  invalid_reason -- if they are 'U' they get mapped using Maps to to RxNorm/E anyway
from drug_concept_stage
where domain_id='Device'
;
commit;
*/
--Clean up
drop table r_drug_ing purge;
drop table r_ing_count purge;
drop table q_drug_ing purge;
drop table q_ing_count purge;
drop table match purge;
drop table shared_ing purge;
drop table r_bn purge;
drop table q_to_r_anydose purge;
drop table q_to_r_wdose purge;
drop table q_to_r purge;
drop table poss_map purge;
drop table cnc_rel_class purge; 
drop table attrib_cnt purge;
drop table Q_DCODE_to_hlc purge;
drop table dupl purge;
drop table best_map purge;
--from procedure_drug.sql
drop table drug_concept_stage purge;
drop table relationship_to_concept purge;
drop table internal_relationship_stage purge;
drop table ds_stage purge;

