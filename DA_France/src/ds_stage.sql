--fill ds_stage
--manually found dosages
insert into ds_stage 
select distinct pfc, concept_code, packsize, AMOUNT_VALUE, AMOUNT_UNIT, NUMERATOR_VALUE,
NUMERATOR_UNIT, DENOMINATOR_VALUE, DENOMINATOR_UNIT 
from ds_stage_manual f join drug_concept_stage dcs on upper(molecule)=upper(concept_name) and dcs.concept_class_id='Ingredient';


--insulins
insert into DS_STAGE (drug_concept_code,ingredient_concept_code,numerator_value,numerator_unit,denominator_value,denominator_unit,box_size)
select pfc,concept_code_2,
STRG_UNIT* regexp_substr (volume, '[[:digit:]]+(\.[[:digit:]]+)?') as numerator_value,STRG_MEAS as numerator_unit,
regexp_substr (volume, '[[:digit:]]+(\.[[:digit:]]+)?') as denominator_value,
regexp_replace (volume, '[[:digit:]]+(\.[[:digit:]]+)?') as denominator_unit,
 packsize
from france_1 f join  internal_relationship_stage irs
on f.pfc=irs.concept_code_1
join drug_concept_stage dcs on concept_code_2=dcs.concept_code and dcs.concept_class_id='Ingredient'
 where volume !='NULL' and strg_meas not in ( '%','NULL')  AND MOLECULE NOT LIKE '%+%' and  MOLECULE LIKE '%INSULIN%'
 and pfc not in (select drug_concept_code from ds_stage)
;


-- for delayed (mh/H) drugs

create table ds_for_prolonged as
select pfc,concept_code,descr_pck,
regexp_SUBSTR(regexp_substr(descr_pck,'\d+(\.\d+)*\w*/\d+H'),'\d+(\.\d+)*') as numerator_value,
'MG' as numerator_unit,
regexp_replace(regexp_substr(descr_pck,'\d+(\.\d+)*\w*/\d+H'),'.*/|H') as denominator_value, 'H' as denominator_unit,packsize
from france_1 f join  internal_relationship_stage irs
on f.pfc=irs.concept_code_1
join drug_concept_stage dcs on concept_code_2=dcs.concept_code and dcs.concept_class_id='Ingredient'
where regexp_like(descr_pck,'/\d+\s?H') 
and molecule not like '%+%'
and pfc not in (select drug_concept_code from ds_stage)
;

update ds_for_prolonged set numerator_value=0.025
where pfc in 
(1512103,2227001,3420009,1230210,3235240,1128703,2414501,2323107,9737636,9737629,9737634,9737615)
;
update ds_for_prolonged set numerator_value=0.037
where pfc in (1128708,3420001,1230202,2427205,9737621)
;
update ds_for_prolonged set numerator_value=0.04
where pfc =2784501
;
update ds_for_prolonged set numerator_value=0.05
where pfc in (3235245,1128705,2590301,2414503,1512101,1856301,3420003,1230203,2427201,1856601,
2323108,2323108,2227003,9737641,9737606,9737630,9737610,9737609,9737639,9737607,9737605,9737608)
;

update ds_for_prolonged set numerator_value=0.06
where pfc =2784503
;

update ds_for_prolonged set numerator_value=0.075
where pfc in (1128710,2427207,2323109,1230204,3420005,2414505,1856603)
;
update ds_for_prolonged set numerator_value=0.075
where pfc in (9737642,2784505,9737638,9737633,9737616,9737631)
;
update ds_for_prolonged set numerator_value=0.1
where pfc in (1128706,2427203,3235250)
;
insert into ds_stage (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT,BOX_SIZE)
SELECT PFC,CONCEPT_CODE,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT,PACKSIZE
FROM ds_for_prolonged;

--doesn't have a volume and drug has only one ingredient
insert into DS_STAGE (drug_concept_code, ingredient_concept_code,amount_value,amount_unit,box_size)
select pfc,concept_code_2, strg_unit, STRG_MEAS, packsize
from france_1 f join  internal_relationship_stage irs
on f.pfc=irs.concept_code_1
join drug_concept_stage dcs on concept_code_2=dcs.concept_code and dcs.concept_class_id='Ingredient'
where volume ='NULL' AND strg_unit !='NULL' AND MOLECULE NOT LIKE '%+%' AND strg_meas != '%' and MOLECULE NOT LIKE '%NULL%'
and pfc not in (select drug_concept_code from ds_stage)
;

--one ingredient and volume present (descr_pck not like '%/%')
insert into DS_STAGE (drug_concept_code,ingredient_concept_code,numerator_value,numerator_unit,denominator_value,denominator_unit,box_size)
select pfc,concept_code_2,strg_unit,strg_meas,
regexp_substr (volume, '[[:digit:]]+(\.[[:digit:]]+)?') as denominator_value,
regexp_replace (volume, '[[:digit:]]+(\.[[:digit:]]+)?') as denominator_unit,
 packsize
from france_1 f join  internal_relationship_stage irs
on f.pfc=irs.concept_code_1
join drug_concept_stage dcs on concept_code_2=dcs.concept_code and dcs.concept_class_id='Ingredient'
 where volume !='NULL' and strg_meas not in ( '%','NULL')  AND MOLECULE NOT LIKE '%+%' and descr_pck not like '%/%' and MOLECULE NOT LIKE '%NULL%'
and pfc not in (select drug_concept_code from ds_stage)
;

--one ingredient and volume present (descr_pck like '%/%') volume not like '%G'
insert into DS_STAGE (drug_concept_code,ingredient_concept_code,numerator_value,numerator_unit,denominator_value,denominator_unit,box_size)
with a as (
select PACKSIZE,PFC,regexp_substr (volume, '[[:digit:]]+(\.[[:digit:]]+)?') as denominator_value,
regexp_replace (volume, '[[:digit:]]+(\.[[:digit:]]+)?') as denominator_unit,STRG_UNIT ,STRG_MEAS,replace(regexp_substr (DESCR_PCK,'/\d*'),'/') as num_coef
 from france_1  where volume !='NULL' and volume not like '%G' and  strg_meas not in ( '%','NULL')  AND MOLECULE NOT LIKE '%+%' and descr_pck like '%/%' and MOLECULE NOT LIKE '%NULL%'
and pfc not in (select drug_concept_code from ds_stage) )
  select distinct PFC,concept_code_2,
nvl(((strg_unit*DENOMINATOR_VALUE)/num_coef),(strg_unit*DENOMINATOR_VALUE)) as numerator_value,strg_meas as numerator_unit, denominator_value,denominator_unit, packsize
from a join internal_relationship_stage irs
on a.pfc=irs.concept_code_1
join drug_concept_stage dcs on concept_code_2=dcs.concept_code and dcs.concept_class_id='Ingredient'

;
--one ingredient and volume present (descr_pck like '%/%') volume not like '%G' review manually!!!! 
--(select * from france where  volume !='NULL' and volume  like '%G' and  strg_meas not in ( '%','NULL')  AND MOLECULE NOT LIKE '%+%' and descr_pck like '%/%')

--one ingredient dosage like %, descr_pck not like '%DOS%'
insert into DS_STAGE (drug_concept_code,ingredient_concept_code,numerator_value,numerator_unit,denominator_value,denominator_unit,box_size)
select distinct pfc,concept_code_2,
case 
when regexp_replace(volume,'\d*(\.)?(\d)*') in ('L','ML')
then STRG_UNIT*(regexp_substr(volume,'\d*(\.)?(\d)*'))*10 
when regexp_replace(volume,'\d*(\.)?(\d)*') in ('KG','G')
then STRG_UNIT*(regexp_substr(volume,'\d*(\.)?(\d)*'))/100 
else null end
as numerator_value,
case
when regexp_replace(volume,'\d*(\.)?(\d)*')  ='ML'
then 'MG'
when regexp_replace(volume,'\d*(\.)?(\d)*')  ='L'
then 'G'
else 
regexp_replace(volume,'\d*(\.)?(\d)*') 
end as numerator_unit,
regexp_substr(volume,'\d*(\.)?(\d)*') as denominator_value,regexp_replace(volume,'\d*(\.)?(\d)*') as denominator_unit,
packsize
from france_1 f join  internal_relationship_stage irs
on f.pfc=irs.concept_code_1
join drug_concept_stage dcs on concept_code_2=dcs.concept_code and dcs.concept_class_id='Ingredient'
where volume !='NULL' and strg_meas = '%'  AND MOLECULE NOT LIKE '%+%' and lower(descr_pck) not like '/%dos%' and MOLECULE NOT LIKE '%NULL%'
;
;


--volume = 'NULL' AND strg_unit !='NULL' AND MOLECULE NOT LIKE '%+%' AND strg_meas = '%'
insert into DS_STAGE (drug_concept_code,ingredient_concept_code,numerator_value,numerator_unit,denominator_unit,box_size)
select pfc,concept_code_2, STRG_UNIT*10 as numerator_value, 'MG' as numerator_unit, 'ML' as denominator_unit,packsize
from france_1 f join  internal_relationship_stage irs
on f.pfc=irs.concept_code_1
join drug_concept_stage dcs on concept_code_2=dcs.concept_code and dcs.concept_class_id='Ingredient'
where volume = 'NULL' AND strg_unit !='NULL' AND MOLECULE NOT LIKE '%+%' AND strg_meas = '%' and MOLECULE NOT LIKE '%NULL%'
and pfc not in (select drug_concept_code from ds_stage)
;

--volume !='NULL' and strg_unit='NULL' and MOLECULE NOT LIKE '%+%'
insert into DS_STAGE (drug_concept_code,ingredient_concept_code,amount_value,amount_unit,box_size)
select pfc,concept_code_2, regexp_substr(volume,'\d*(\.)?(\d)*') as amount_value,regexp_replace(volume,'\d*(\.)?(\d)*') as amount_unit,packsize
 from france_1 f join  internal_relationship_stage irs
on f.pfc=irs.concept_code_1
join drug_concept_stage dcs on concept_code_2=dcs.concept_code and dcs.concept_class_id='Ingredient'
where volume !='NULL' and strg_unit='NULL' and MOLECULE NOT LIKE '%+%' and MOLECULE NOT LIKE '%NULL%'
and pfc not in (select drug_concept_code from ds_stage)
and regexp_replace(volume,'\d*(\.)?(\d)*') not in ('L','ML')
;

-- need to extract dosages from descr_pck where  MOLECULE NOT LIKE '%+%' and volume ='NULL' and strg_unit='NULL'

--complex ingredients (excluding 'INSULIN')

create table ds_complex as 
with a as (
select distinct PRODUCT_DESC,FORM_DESC,DOSAGE,DOSAGE_ADD,VOLUME,PACKSIZE,CLAATC,PFC,MOLECULE,CD_NFC_3,ENGLISH,LB_NFC_3,DESCR_PCK,STRG_UNIT,STRG_MEAS,
trim(regexp_substr(t.molecule, '[^\+]+', 1, levels.column_value))  as ingred,
trim(regexp_substr(regexp_replace(t.descr_pck,'^\D*/' ), '[^/]+', 1, levels.column_value))  as concentr
from
(select * from france_1  where molecule like '%+%' and regexp_like(descr_pck, '.*\d+.*/.*\d+.*') and pfc not in (select distinct pfc from non_drugs) and molecule not like '%INSULIN%' and MOLECULE NOT LIKE '%NULL%' ) t,
table(cast(multiset(select level from dual connect by  level <= length (regexp_replace(t.molecule, '[^\+]+'))  + 1) as sys.OdciNumberList)) levels)
select distinct PRODUCT_DESC,FORM_DESC,DOSAGE,DOSAGE_ADD,VOLUME,PACKSIZE,CLAATC,PFC,MOLECULE,CD_NFC_3,ENGLISH,LB_NFC_3,DESCR_PCK,STRG_UNIT,STRG_MEAS,
 INGRED, CONCENTR, 
                 case when regexp_substr(concentr,'\d+\.\d+') is not null then regexp_substr(concentr,'\d+\.\d+')
                 when regexp_substr(concentr,'\d+\.\d+') is null then regexp_substr(concentr,'\d+') else null end as STRength,
  regexp_replace(regexp_substr (concentr,  '\d+(\.\d+)*\S+'),'\d+(\.\d+)*')  as UNIT
from a
;

--incorrect dosages for CLAVULANIC ACID+AMOXICILLIN
update ds_complex set
strength = regexp_substr(regexp_substr(descr_pck,'\d+(\.\d+)*\w*/\d+(\.\d+)*'),'\d+(\.\d+)*'),
unit='MG'
where molecule like 'CLAVULANIC ACID+AMOXICILLIN' and descr_pck not like '%ML' and ingred like 'AMOXICILLIN'
;
update ds_complex set
strength = regexp_replace(regexp_substr(descr_pck,'\d+(\.\d+)*\w*/\d+(\.\d+)*'),'\d+(\.\d+)*\w*/'),
unit='MG'
where molecule like 'CLAVULANIC ACID+AMOXICILLIN' and descr_pck not like '%ML' and ingred like 'CLAVULANIC ACID';

update ds_complex set
strength = regexp_substr(regexp_substr(descr_pck,'\d+(\.\d+)*\w*/\d+(\.\d+)*'),'\d+(\.\d+)*')*regexp_substr(volume,'\d+(\.\d+)*'),
unit='MG'
where molecule like 'CLAVULANIC ACID+AMOXICILLIN' and descr_pck  like '%ML' and ingred like 'AMOXICILLIN'
;
update ds_complex set
strength = regexp_replace(regexp_substr(descr_pck,'\d+(\.\d+)*\w*/\d+(\.\d+)*'),'\d+(\.\d+)*\w*/')*regexp_substr(volume,'\d+(\.\d+)*'),
unit='MG'
where molecule like 'CLAVULANIC ACID+AMOXICILLIN' and descr_pck  like '%ML' and ingred like 'CLAVULANIC ACID'
;

update ds_complex set volume='24H', unit='MCG' where pfc in (2521201,3750501)
;

update ds_complex set volume='30DOS',unit='Y' where pfc=5351301
;



insert into DS_STAGE (drug_concept_code,ingredient_concept_code,numerator_value,numerator_unit,denominator_value,denominator_unit,box_size)
select distinct pfc,concept_code,
strength as numerator_value,
unit as numerator_unit,
regexp_substr (volume, '[[:digit:]]+(\.[[:digit:]]+)?') as denominator_value,
regexp_replace (volume, '[[:digit:]]+(\.[[:digit:]]+)?') as denominator_unit,
packsize
from ds_complex f join  drug_concept_stage dcs on
INGRED=DCS.CONCEPT_NAME AND dcs.concept_class_id='Ingredient'
where volume !='NULL' and MOLECULE NOT LIKE '%NULL%';
 
 insert into DS_STAGE (drug_concept_code,ingredient_concept_code,amount_value,amount_unit,box_size)
select distinct pfc,concept_code,
strength as numerator_value,
unit as numerator_unit,
packsize
from ds_complex f join  drug_concept_stage dcs on
INGRED=DCS.CONCEPT_NAME AND dcs.concept_class_id='Ingredient'
where volume ='NULL' and MOLECULE NOT LIKE '%NULL%';


update ds_stage set 
amount_unit = null where amount_unit like 'NULL';
update ds_stage set 
numerator_unit = null where numerator_unit like 'NULL';
update ds_stage set 
denominator_unit = null where denominator_unit like 'NULL'
;
--need to review

     UPDATE DS_STAGE SET  AMOUNT_UNIT='MG' WHERE (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE) IN (
select DISTINCT  A.drug_concept_code,A.INGREDIENT_CONCEPT_CODE from ds_stage a join ds_stage b on a.drug_concept_code=b.drug_concept_code and a.ingredient_concept_code !=b.ingredient_concept_code
and  a.AMOUNT_VALUE IS NOT NULL AND   a.AMOUNT_UNIT IS NULL AND b.AMOUNT_UNIT LIKE 'MG');

     UPDATE DS_STAGE SET  AMOUNT_UNIT='IU' WHERE (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE) IN (
select DISTINCT  A.drug_concept_code,A.INGREDIENT_CONCEPT_CODE from ds_stage a join ds_stage b on a.drug_concept_code=b.drug_concept_code and a.ingredient_concept_code !=b.ingredient_concept_code
and  a.AMOUNT_VALUE IS NOT NULL AND   a.AMOUNT_UNIT IS NULL AND b.AMOUNT_UNIT LIKE 'IU');

     UPDATE DS_STAGE SET  AMOUNT_UNIT='Y' WHERE (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE) IN (
select DISTINCT  A.drug_concept_code,A.INGREDIENT_CONCEPT_CODE from ds_stage a join ds_stage b on a.drug_concept_code=b.drug_concept_code and a.ingredient_concept_code !=b.ingredient_concept_code
and  a.AMOUNT_VALUE IS NOT NULL AND   a.AMOUNT_UNIT IS NULL AND b.AMOUNT_UNIT LIKE 'Y');


      UPDATE DS_STAGE SET  AMOUNT_UNIT='MG' WHERE (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE) IN 
(SELECT DISTINCT DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE FROM DS_STAGE A JOIN france_1 B ON DRUG_CONCEPT_CODE=PFC AND ENGLISH LIKE 'Oral Solid%'
 AND AMOUNT_UNIT IS NULL AND AMOUNT_VALUE IS NOT NULL);


update ds_stage set 
numerator_value = 3000, denominator_value=60,amount_value=null,amount_unit=null,
numerator_unit='MCG',denominator_unit='DOS'
where drug_concept_code in
('2393701','2393702','2393703','2971805','2971806')
and ingredient_concept_code in (select concept_code from drug_concept_stage where concept_class_id='Ingredient' and concept_name like 'SALMETEROL')
;

update ds_stage set 
numerator_value = 1400, denominator_value=28,amount_value=null,amount_unit=null,
numerator_unit='MCG',denominator_unit='DOS'
where drug_concept_code in 
('2971801','2971802','2971803')
and ingredient_concept_code in (select concept_code from drug_concept_stage where concept_class_id='Ingredient' and concept_name like 'SALMETEROL')
;


update ds_stage set 
numerator_value= amount_value*100,amount_value=null,amount_unit=null, denominator_value=amount_value,
numerator_unit='MCG',denominator_unit='DOS'
where ingredient_concept_code in (select concept_code from drug_concept_stage where concept_class_id='Ingredient' and concept_name like 'FLUTICASONE')
and drug_concept_code in ('2393701','2971802')
;

update ds_stage set 
numerator_value= amount_value*250,amount_value=null,amount_unit=null, denominator_value=amount_value,
numerator_unit='MCG',denominator_unit='DOS'
where ingredient_concept_code in (select concept_code from drug_concept_stage where concept_class_id='Ingredient' and concept_name like 'FLUTICASONE')
and drug_concept_code in ('2393702','2971803','2971805')
;

update ds_stage set 
numerator_value= amount_value*500,amount_value=null,amount_unit=null, denominator_value=amount_value,
numerator_unit='MCG',denominator_unit='DOS'
where ingredient_concept_code in (select concept_code from drug_concept_stage where concept_class_id='Ingredient' and concept_name like 'FLUTICASONE')
and drug_concept_code in ('2393703','2971801','2971806')
;

update ds_stage set 
numerator_value= 2760, denominator_value=30,amount_value=null,amount_unit=null,
numerator_unit='MCG',denominator_unit='DOS'
where ingredient_concept_code in (select concept_code from drug_concept_stage where concept_class_id='Ingredient' and concept_name like 'FLUTICASONE FUROATE')
and drug_concept_code='5475101'
;

update ds_stage set 
numerator_value= 660, denominator_value=30, amount_value=null,amount_unit=null,
numerator_unit='MCG',denominator_unit='DOS'
where ingredient_concept_code in (select concept_code from drug_concept_stage where concept_class_id='Ingredient' and concept_name like 'VILANTEROL')
and drug_concept_code='5475101'
;
update ds_stage set 
numerator_value= 24000, denominator_value=60, amount_value=null,amount_unit=null,
numerator_unit='MCG',denominator_unit='DOS'
where ingredient_concept_code in (select concept_code from drug_concept_stage where concept_class_id='Ingredient' and concept_name like 'BUDESONIDE')
and drug_concept_code='4671001'
;
update ds_stage set 
numerator_value= 720, denominator_value=60, amount_value=null,amount_unit=null,
numerator_unit='MCG',denominator_unit='DOS'
where ingredient_concept_code in (select concept_code from drug_concept_stage where concept_class_id='Ingredient' and concept_name like 'FORMOTEROL')
and drug_concept_code='4671001'
;
delete from ds_stage where drug_concept_code ='2935001';
COMMIT;