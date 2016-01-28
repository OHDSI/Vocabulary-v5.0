--create list of names given for ingredient-dosage combination
create table unique_ds_names as (
select a.concept_name||' '||case when amount_value !=0 then AMOUNT_VALUE||' '||AMOUNT_UNIT 
when NUMERATOR_VALUE !=0 and NUMERATOR_UNIT !='%' then NUMERATOR_VALUE||' '||NUMERATOR_UNIT||'/'||DENOMINATOR_UNIT
when NUMERATOR_UNIT ='%' then NUMERATOR_VALUE||' '||NUMERATOR_UNIT
else null end as concept_name, a.concept_name as ing_name,  ds.DS_CODE, ds.denominator_unit
 from unique_ds ds join drug_concept_stage a on ds.ingredient_concept_code = a.concept_code)
;
--it's complete_concept_stage table with ingredient combo code devided into separate rows
create table complete_concept_stage_I_cmb as (
select distinct CONCEPT_CODE,DENOMINATOR_VALUE,D_COMBO_CODE,DOSE_FORM_CODE,BRAND_CODE,BOX_SIZE,CONCEPT_CLASS_ID,
trim(regexp_substr(t.I_COMBO_CODE, '[^\-]+', 1, levels.column_value))  as I_combo_code
from complete_concept_stage t, 
table(cast(multiset(select level from dual connect by  level <= length (regexp_replace(t.I_COMBO_CODE, '[^\-]+'))  + 1) as sys.OdciNumberList)) levels)
;
--Give a rank for each ingredient PARTITION BY concept_code (each drug), then we use this rank number to understand how many ingredients drug has
create table complete_concept_I_cmb_rank as 
 (select CONCEPT_CODE,DENOMINATOR_VALUE,D_COMBO_CODE,DOSE_FORM_CODE,BRAND_CODE,BOX_SIZE,CONCEPT_CLASS_ID,I_COMBO_CODE,
RANK() OVER (PARTITION BY concept_code ORDER BY I_combo_code) as I_rank
from complete_concept_stage_I_cmb)
;
--it's complete_concept_stage table with Drug-component combo-code devided into separate rows
create table complete_concept_stage_cmb as (
select distinct CONCEPT_CODE,DENOMINATOR_VALUE,I_COMBO_CODE,DOSE_FORM_CODE,BRAND_CODE,BOX_SIZE,CONCEPT_CLASS_ID,
trim(regexp_substr(t.D_COMBO_CODE, '[^\-]+', 1, levels.column_value))  as combo_code
from complete_concept_stage t, 
table(cast(multiset(select level from dual connect by  level <= length (regexp_replace(t.D_COMBO_CODE, '[^\-]+'))  + 1) as sys.OdciNumberList)) levels)
;
--Give a rank for each Drug-component PARTITION BY concept_code (each drug), then we use this rank number to understand how many ingredients drug has
create table complete_concept_D_cmb_rank as 
 (select CONCEPT_CODE,DENOMINATOR_VALUE,I_COMBO_CODE,DOSE_FORM_CODE,BRAND_CODE,BOX_SIZE,CONCEPT_CLASS_ID,COMBO_CODE,
RANK() OVER (PARTITION BY concept_code ORDER BY combo_code) as D_rank
from complete_concept_stage_cmb)
;
-- create names when drug has 3 or less ingredients
create table complete_concept_stage_names as (
select distinct case -- for different classes we'll have different names
when a.concept_code = c.concept_code then c.concept_name  
when a.concept_class_id = 'Clinical Drug Comp' then  LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)
when a.concept_class_id = 'Branded Drug Comp' then  LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||' ['||br.concept_name||']'
when a.concept_class_id = 'Clinical Drug' then LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||' '||df.concept_name
when a.concept_class_id = 'Branded Drug' then LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||' '||df.concept_name||' ['||br.concept_name||']'
when a.concept_class_id = 'Clinical Drug Box' then LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||' '||df.concept_name||' Box of '||a.box_size
when a.concept_class_id = 'Branded Drug Box' 
then LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||' '||df.concept_name||' ['||br.concept_name||'] Box of '||a.box_size
when a.concept_class_id = 'Quant Clinical Drug' and b.denominator_unit is not null then a.denominator_value||' '||b.denominator_unit||' '||LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||' '||df.concept_name
when a.concept_class_id = 'Quant Branded Drug' and b.denominator_unit is not null then a.denominator_value||' '||b.denominator_unit||' '||LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||' '||df.concept_name||' ['||br.concept_name||']'
when a.concept_class_id = 'Quant Clinical Box' and b.denominator_unit is not null
then a.denominator_value||' '||b.denominator_unit||' '||LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||' '||df.concept_name||' Box of '||a.box_size
when a.concept_class_id = 'Quant Branded Box' and b.denominator_unit is not null 
then a.denominator_value||' '||b.denominator_unit||' '||LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||' '||df.concept_name||' ['||br.concept_name||'] Box of '||a.box_size
else null end as concept_name, a.CONCEPT_CODE,a.DENOMINATOR_VALUE,a.I_COMBO_CODE,a.d_combo_code, a.DOSE_FORM_CODE,a.BRAND_CODE,a.BOX_SIZE,a.CONCEPT_CLASS_ID
from complete_concept_stage  a
left join complete_concept_D_cmb_rank DR on dr.concept_code = a.concept_code
left join drug_concept_stage c on c.concept_code =a.concept_code
left join unique_ds_names b on dr.combo_code = b.DS_CODE
left join drug_concept_stage br on br.concept_code = a.BRAND_CODE
left join drug_concept_stage df on df.concept_code = a.DOSE_FORM_CODE
where a.concept_code not in (select concept_code from complete_concept_D_cmb_rank dr where dr.d_rank >3)
and a.concept_class_id != 'Clinical Drug Form' and  a.concept_class_id !=  'Branded Drug Form'
union 
--we join with complete_concept_I_cmb_rank because Clinical and Branded Drug Form classes don't have dosages we have in complete_concept_stage_cmb (Drug-components combo)
select distinct 
case
when a.concept_class_id = 'Clinical Drug Form' then substr ((LISTAGG (ing.concept_name, ' / ') WITHIN GROUP (ORDER BY ing.concept_name) OVER (PARTITION BY a.concept_code)),1,173) ||' '||df.concept_name
when a.concept_class_id = 'Branded Drug Form' then LISTAGG (ing.concept_name, ' / ') WITHIN GROUP (ORDER BY ing.concept_name) OVER (PARTITION BY a.concept_code)||' '||df.concept_name||' ['||br.concept_name||']'
else null end as concept_name, a.CONCEPT_CODE,a.DENOMINATOR_VALUE,a.I_COMBO_CODE,a.d_combo_code, a.DOSE_FORM_CODE,a.BRAND_CODE,a.BOX_SIZE,a.CONCEPT_CLASS_ID
from complete_concept_stage a
left join complete_concept_I_cmb_rank icm on icm.concept_code = a.concept_code
left join drug_concept_stage br on br.concept_code = a.BRAND_CODE
left join drug_concept_stage df on df.concept_code = a.DOSE_FORM_CODE
left join  drug_concept_stage ing on ing.concept_code = icm.i_combo_code 
where (a.concept_class_id = 'Clinical Drug Form' or  a.concept_class_id =  'Branded Drug Form')
and a.concept_code not in (select concept_code from complete_concept_I_cmb_rank dr where dr.i_rank >3)
)
;
-- create names when drug has more than 3 ingredients, in this case description contains only first 3 ingredients, other are replaced by '...'
--all other princeples of table building is the same as previous one
create table complete_concept_stage_names_3 as (
select distinct case
when a.concept_code = c.concept_code and a.concept_class_id in ('Ingredient', 'Brand Name', 'Dose Form', 'Unit') then c.concept_name 
when a.concept_class_id = 'Clinical Drug Comp' then  LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||'...'
when a.concept_class_id = 'Branded Drug Comp' then  LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||'...'||' ['||br.concept_name||']'
when a.concept_class_id = 'Clinical Drug' then LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||'...'||' '||df.concept_name
when a.concept_class_id = 'Branded Drug' then LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||'...'||' '||df.concept_name||' ['||br.concept_name||']'
when a.concept_class_id = 'Clinical Drug Box' then LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||'...'||' '||df.concept_name||' Box of '||a.box_size
when a.concept_class_id = 'Branded Drug Box' 
then LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||'...'||' '||df.concept_name||' ['||br.concept_name||'] Box of '||a.box_size
when a.concept_class_id = 'Quant Clinical Drug' and b.denominator_unit is not null then a.denominator_value||' '||b.denominator_unit||' '||LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||'...'||' '||df.concept_name
when a.concept_class_id = 'Quant Branded Drug' and b.denominator_unit is not null  then a.denominator_value||' '||b.denominator_unit||' '||LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||'...'||' '||df.concept_name||' ['||br.concept_name||']'
when a.concept_class_id = 'Quant Clinical Box' and b.denominator_unit is not null
then a.denominator_value||' '||b.denominator_unit||' '||LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||'...'||' '||df.concept_name||' Box of '||a.box_size
when a.concept_class_id = 'Quant Branded Box' and b.denominator_unit is not null 
then a.denominator_value||' '||b.denominator_unit||' '||LISTAGG (b.concept_name, ' / ') WITHIN GROUP (ORDER BY b.concept_name) OVER (PARTITION BY a.concept_code)||'...'||' '||df.concept_name||' ['||br.concept_name||'] Box of '||a.box_size
else null end as concept_name, a.CONCEPT_CODE,a.DENOMINATOR_VALUE,a.I_COMBO_CODE,a.d_combo_code, a.DOSE_FORM_CODE,a.BRAND_CODE,a.BOX_SIZE,a.CONCEPT_CLASS_ID
from complete_concept_stage  a
left join (select * from complete_concept_D_cmb_rank where D_rank <4) DR on dr.concept_code = a.concept_code
left join drug_concept_stage c on c.concept_code =a.concept_code
left join unique_ds_names b on dr.combo_code = b.DS_CODE
left join drug_concept_stage br on br.concept_code = a.BRAND_CODE
left join drug_concept_stage df on df.concept_code = a.DOSE_FORM_CODE
where a.concept_code in (select concept_code from complete_concept_D_cmb_rank dr where dr.d_rank >3)
and a.concept_class_id != 'Clinical Drug Form' and  a.concept_class_id !=  'Branded Drug Form'
union 
select distinct 
case
when a.concept_class_id = 'Clinical Drug Form' then LISTAGG (ing.concept_name, ' / ') WITHIN GROUP (ORDER BY ing.concept_name) OVER (PARTITION BY a.concept_code)||'...'||' '||df.concept_name
when a.concept_class_id = 'Branded Drug Form' then LISTAGG (ing.concept_name, ' / ') WITHIN GROUP (ORDER BY ing.concept_name) OVER (PARTITION BY a.concept_code)||'...'||' '||df.concept_name||' ['||br.concept_name||']'
else null end as concept_name, a.CONCEPT_CODE,a.DENOMINATOR_VALUE,a.I_COMBO_CODE,a.d_combo_code, a.DOSE_FORM_CODE,a.BRAND_CODE,a.BOX_SIZE,a.CONCEPT_CLASS_ID
from complete_concept_stage a
left join (select * from complete_concept_I_cmb_rank where I_rank<4) icm on icm.concept_code = a.concept_code
left join drug_concept_stage br on br.concept_code = a.BRAND_CODE
left join drug_concept_stage df on df.concept_code = a.DOSE_FORM_CODE
left join  drug_concept_stage ing on ing.concept_code = icm.i_combo_code 
where (a.concept_class_id = 'Clinical Drug Form' or  a.concept_class_id =  'Branded Drug Form')
and a.concept_code in (select concept_code from complete_concept_I_cmb_rank dr where dr.i_rank >3)
)
;
--union of tables with less than 3 and 3 and more ingredients
create table complete_concept_stage_name as
(select * from complete_concept_stage_names
union 
select * from complete_concept_stage_names_3)
;
--remove excessive spaces 
UPDATE complete_concept_stage_name a SET concept_name=regexp_REPLACE (concept_name, '\s+', ' ')
;
drop table unique_ds_names  purge ;
drop table complete_concept_stage_I_cmb purge ;
drop table complete_concept_I_cmb_rank purge ;
drop table complete_concept_stage_cmb purge ;
drop table complete_concept_D_cmb_rank purge ;
drop table  complete_concept_stage_names purge ;
drop table  complete_concept_stage_names_3 purge ;

commit
;
