/**************************************************
* This script takes a drug vocabulary q and       *
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

-- 1. Create lookup tables for existing vocab r (RxNorm and public country-specific ones)
-- Create table containing ingredients for each drug
create table r_drug_ing nologging as
  select de.concept_id as drug_id, an.concept_id as ing_id
  from concept_ancestor a 
  join concept an on a.ancestor_concept_id=an.concept_id and an.concept_class_id='Ingredient' 
    and an.vocabulary_id in ('RxNorm') -- to be expanded as new vocabs are added
  join concept de on de.concept_id=a.descendant_concept_id  
    and de.vocabulary_id in ('RxNorm')
;
-- Remove unparsable Albumin products that have no drug_strength entry: Albumin Human, USP 1 NS
delete from r_drug_ing where drug_id in (19094500, 19080557);
-- Count number of ingredients for each drug
create table r_ing_count nologging as
  select drug_id as did, count(*) as cnt from r_drug_ing group by drug_id
;
-- Set all counts for Ingredient and Clinical Drug Comp to null, so in comparisons it can match whatever number necessary. Reason is that, like ingredients, Clinical Drug Comp is always only one ingredient
update r_ing_count set cnt=null where did in (select concept_id from concept where concept_class_id in ('Clinical Drug Comp', 'Ingredient'));

create index x_r_drug_ing on r_drug_ing(drug_id, ing_id) nologging;

-- Create lookup table for query vocab q (new vocab)
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
;
-- Count ingredients per drug
create table q_ing_count nologging as
  select drug_code as dcode, count(*) as cnt from q_drug_ing group by drug_code
;
create index x_q_drug_ing on q_drug_ing(drug_code, ing_id) nologging;

-- Create table that lists for each ingredient all drugs containing it from q and r
create table match nologging as
  select q.ing_id as r_iid, q.ing_code as q_icode, q.drug_code as q_dcode, r.drug_id as r_did
  from q_drug_ing q join r_drug_ing r on q.ing_id=r.ing_id -- match query and result drug on common ingredient
;
create index x_match on match(q_dcode, r_did) nologging;

-- Create table with all drugs in q and r and the number of ingredients they share
create table shared_ing nologging as
select r_did, q_dcode, count(*) as cnt from match group by r_did, q_dcode
;
-- Set all counts for Clinical Drug Comp to null, so in comparisons it can match whatever number necessary. Reason is that, like ingredients, Clinical Drug Comp is always only one ingredient
update shared_ing set cnt=null where r_did in (select concept_id from concept where concept_class_id in ('Clinical Drug Comp', 'Ingredient'));

-- Create table that matches drugs q to r, based on Ingredient, Dose Form and Brand Name (if exist). Dose, box size or quantity are not yet compared
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
  where r.invalid_reason is null and r.relationship_id='RxNorm has dose form'
) r_df on r_df.concept_id_1=m.r_did
-- get Brand Name for q and r
left join (
  select r.concept_code_1, m.concept_id_2, nvl(m.precedence, 1) as precedence
  from internal_relationship_stage r 
  join drug_concept_stage on concept_code=r.concept_code_2 and concept_class_id = 'Brand Name' 
  join relationship_to_concept m on m.concept_code_1=r.concept_code_2
) q_bn on q_bn.concept_code_1=m.q_dcode
left join (
  select r.concept_id_1, r.concept_id_2 
  from concept_relationship r
  join concept on concept_id=r.concept_id_2 and concept_class_id ='Brand Name'
  where r.invalid_reason is null 
) r_bn on r_bn.concept_id_1=m.r_did and m.rc_cnt is not null -- only take Brand Names if they don't come from Ingredients or Clinical Drug Comps
-- remove comments if mapping should be done both upwards (standard) and downwards (to find a possible unique low-granularity solution)
where coalesce(q_bn.concept_id_2, /* q_bn.concept_id_2, */0)=coalesce(r_bn.concept_id_2, q_bn.concept_id_2, 0) -- Allow matching of the same Brand Name or no Brand Name, but not another Brand Name
and coalesce(q_df.concept_id_2, /*q_df.concept_id_2, */0)=coalesce(r_df.concept_id_2, q_df.concept_id_2, 0) -- Allow matching of the same Dose Form or no Dose Form, but not another Dose Form�
;

-- Add matching of dose and its units
create table q_to_r_wdose nologging as
-- Create two temp tables with all strength and unit information
with q as (
  select q_ds.drug_concept_code, q_ds.ingredient_concept_code, 
    q_ds.amount_value*q_ds_a.conversion_factor as amount_value, q_ds_a.concept_id_2 as amount_unit_concept_id, 
    q_ds.numerator_value*q_ds_n.conversion_factor as numerator_value, q_ds_n.concept_id_2 as numerator_unit_concept_id,
    nvl(q_ds.denominator_value, 1)*nvl(q_ds_d.conversion_factor, 1) as denominator_value, q_ds_d.concept_id_2 as denominator_unit_concept_id,
    coalesce(q_ds_a.precedence, q_ds_n.precedence, q_ds_d.precedence) as u_prec
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
    r_ds.denominator_unit_concept_id
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
create table q_to_r nologging as
select q_dcode, r_did, r_iid, bn_prec, df_prec, u_prec, rc_cnt from q_to_r_wdose
where 1=0;

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
commit;

-- Get the best possible mapping that is unique in its concept class. Try bottom up from the lowest end of the drug hierarchy
create table best_map nologging as
with r as (
  select distinct qr.*, cast(c.concept_code as integer) as concept_code, c.concept_class_id from q_to_r qr join concept c on c.concept_id=qr.r_did 
)
select distinct 
  rmap.q_dcode,  
  first_value(rmap.r_did) over (partition by rmap.q_dcode, rmap.r_iid order by rmap.concept_code desc) as r_did, 
rmap.r_iid,
rmap.bn_prec,
rmap.rc_cnt,
rmap.concept_class_id
from (
-- get the best match within class, with the best brand name, dose form and unit precedence
  select distinct
    q_dcode, r_iid,
    first_value(concept_class_id) over (partition by q_dcode, r_iid order by cclass) as concept_class_id
  from (  
    select q_dcode, r_iid, concept_class_id,
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
    from (
      select q_dcode, r_iid, concept_class_id, count(8) as cnt
      from (
        select q_dcode, 
          r_iid, -- group by ingredient for the concept classes that keep ingredients individually (Ing, Clin Drug Comp)
          concept_class_id
        from r 
      )
      group by q_dcode, r_iid, concept_class_id
    ) where concept_class_id in ('Clinical Drug Comp', 'Ingredient') or cnt<2 -- either Ingredient/Clinica Drug Comp or single map
  ) 
) rcnt
join r rmap on rmap.q_dcode=rcnt.q_dcode and nvl(rmap.r_iid, 0)=nvl(rcnt.r_iid, 0) and rmap.concept_class_id=rcnt.concept_class_id
-- where rmap.q_dcode='C9285'
;

-- Remove those which have both Ingredient/Drug Comp hits as well as other hits.
delete from best_map with_i
where with_i.r_iid is not null and exists (
  select 1 from best_map no_i where with_i.q_dcode=no_i.q_dcode and no_i.r_iid is null
);

commit;

-- Write concept_relationship_stage
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
  'RxNorm' as vocabulary_id_2,
  'Maps to' as relationship_id,
  (SELECT latest_update FROM vocabulary WHERE vocabulary_id=(select vocabulary_id from drug_concept_stage where rownum=1)) as valid_start_date,
  TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
  null as invalid_reason
from best_map m
join concept c on c.concept_id=m.r_did and c.vocabulary_id='RxNorm';

commit;

/****************************
* Clean up
*****************************/

drop table drug_concept_stage purge;
drop table relationship_to_concept purge;
drop table internal_relationship_stage purge;
drop table ds_stage purge;
drop table r_drug_ing purge;
drop table r_ing_count purge;
drop table q_drug_ing purge;
drop table q_ing_count purge;
drop table match purge;
drop table shared_ing purge;
drop table q_to_r_anydose purge;
drop table q_to_r_wdose purge;
drop table q_to_r purge;
drop table best_map purge;
