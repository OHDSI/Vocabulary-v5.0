DROP TABLE NON_DRUGS;
drop table france_1;
drop table pre_ingr;
drop table ingr;
drop table Brand;
drop table Forms;
drop table UNIT;
drop table drug_products;
drop table list_temp;
drop table ds_for_prolonged;
drop table ds_complex;


drop sequence conc_stage_seq;
drop sequence new_vocab;





truncate table DRUG_concept_STAGE;
truncate table internal_relationship_stage;
truncate table DS_STAGE;
truncate table relationship_to_concept;
truncate table pc_stage;

/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Eldar Allakhverdiiev, Dmitry Dymshyts, Christian Reich
* Date: 2017
**************************************************************************/


--delete duplicates
delete from france where PFC IN (SELECT PFC FROM FRANCE GROUP BY PFC HAVING COUNT (1) >1) and
rowid not in (
select distinct min(rowid) over (partition by pfc) from  FRANCE); 



create table non_drugs as (
select PRODUCT_DESC,FORM_DESC,DOSAGE,DOSAGE_ADD,VOLUME,PACKSIZE,CLAATC,PFC,MOLECULE,CD_NFC_3,ENGLISH,LB_NFC_3,DESCR_PCK,STRG_UNIT,STRG_MEAS,  cast('' as varchar (250)) as concept_type from france where 
   regexp_like(upper(molecule),'BANDAGES|DEVICES|CARE PRODUCTS|DRESSING|CATHETERS|EYE OCCLUSION PATCH|INCONTINENCE COLLECTION APPLIANCES|SOAP|CREAM|HAIR|SHAMPOO|LOTION|FACIAL CLEANSER|LIP PROTECTANTS|CLEANSING AGENTS|SKIN|TONICS|TOOTHPASTES|MOUTH|SCALP LOTIONS|UREA 13|BARIUM|CRYSTAL VIOLET')
or regexp_like(upper(molecule),'LENS SOLUTIONS|INFANT |DISINFECTANT|ANTISEPTIC|CONDOMS|COTTON WOOL|GENERAL NUTRIENTS|LUBRICANTS|INSECT REPELLENTS|FOOD|SLIMMING PREPARATIONS|SPECIAL DIET|SWAB|WOUND|GADOBUTROL|GADODIAMIDE|GADOBENIC ACID|GADOTERIC ACID|GLUCOSE 1-PHOSPHATE|BRAN|PADS$|IUD')
or regexp_like(upper(molecule),'AFTER SUN PROTECTANTS|BABY MILKS|INCONTINENCE PADS|INSECT REPELLENTS|WIRE|CORN REMOVER|DDT|DECONGESTANT RUBS|EYE MAKE-UP REMOVERS|FIXATIVES|FOOT POWDERS|FIORAVANTI BALSAM|LOW CALORIE FOOD|NUTRITION|TETRAMETHRIN|OTHERS|NON MEDICATED|NON PHARMACEUTICAL|TRYPAN BLUE')
or (MOLECULE like '% TEST%' and MOLECULE not like 'TUBERCULIN%')
or DESCR_PCK like '%KCAL%'
or english = 'Non Human Usage Products'
or LB_NFC_3 like '%NON US.HUMAIN%'
)
;
--list
--list of ingredients
create table pre_ingr as (
SELECT ingred AS concept_name,pfc ,'Ingredient' as concept_class_id from (
select distinct
trim(regexp_substr(t.molecule, '[^\+]+', 1, levels.column_value))  as ingred,pfc --
from (select * from france where pfc not in (select distinct pfc from non_drugs))
 t,
table(cast(multiset(select level from dual connect by  level <= length (regexp_replace(t.molecule, '[^\+]+'))  + 1) as sys.OdciNumberList)) levels)where ingred !='NULL')
;

 -- extract ingredients where it is obvious for molecule like 'NULL'
create table france_1 as 
select * from france where molecule not like 'NULL'
union
select PRODUCT_DESC,FORM_DESC,DOSAGE,DOSAGE_ADD,VOLUME,PACKSIZE,CLAATC,a.PFC,
case when CONCEPT_NAME is not null then CONCEPT_NAME
else 'NULL' end
,CD_NFC_3,ENGLISH,LB_NFC_3,DESCR_PCK,STRG_UNIT,STRG_MEAS
from france a left join pre_ingr b on trim(regexp_replace(PRODUCT_DESC,'DCI'))=upper(concept_name)
where molecule like 'NULL';



--list of ingredients
create table ingr as (
SELECT ingred AS concept_name,pfc ,'Ingredient' as concept_class_id from (
select distinct
trim(regexp_substr(t.molecule, '[^\+]+', 1, levels.column_value))  as ingred,pfc --
from (select * from france_1 where pfc not in (select distinct pfc from non_drugs))
 t,
table(cast(multiset(select level from dual connect by  level <= length (regexp_replace(t.molecule, '[^\+]+'))  + 1) as sys.OdciNumberList)) levels)where ingred !='NULL')
;

--list of Brand Names

CREATE TABLE Brand AS (
SELECT product_desc AS concept_name , pfc,
'Brand Name' as concept_class_id
 FROM  france_1 where pfc not in (select distinct pfc from non_drugs)
 and pfc not in (select distinct pfc from france_1 where molecule='NULL')
 and PRODUCT_DESC not like '%DCI%' and not regexp_like(PRODUCT_DESC,'L\.IND|LAB IND|^VAC |VACCIN')
 and upper(PRODUCT_DESC)	not in (select upper(concept_name) from devv5.concept where concept_class_id like 'Ingredient' and standard_concept='S')
 )
 ;
 
update brand set concept_name ='UMULINE PROFIL' where concept_name like 'UMULINE PROFIL%';
update brand set concept_name ='CALCIPRAT' where concept_name like 'CALCIPRAT D3';
update brand set concept_name ='DOMPERIDONE ZENTIVA' where concept_name like 'DOMPERIDONE ZENT%';


 
--list of Dose Forms

CREATE TABLE Forms AS (
SELECT distinct  trim(DOSE_FORM_NAME) AS concept_name, 'Dose Form' as concept_class_id
FROM france_names_translation  -- munual translations
where DOSE_FORM not in (select LB_NFC_3 from  non_drugs
));



-- units, take units used for volume and strength definition

CREATE TABLE UNIT AS (
SELECT strg_meas AS concept_name,'Unit' as concept_class_id, strg_meas  as concept_CODE 
FROM (
select distinct strg_meas from france_1 where pfc not in (select pfc from non_drugs)
union 
select distinct regexp_replace (volume, '[[:digit:]\.]') from france_1  WHERE strg_meas !='NULL' and  
pfc not in (select pfc from non_drugs)) a
where a.strg_meas not in ('CH', 'NULL')

)
;

 insert into unit values ('UI' ,'Unit','UI');
 insert into unit values ('MUI' ,'Unit','MUI');
 insert into unit values ('DOS' ,'Unit','DOS');
 insert into unit values ('GM' ,'Unit','GM');
 insert into unit values ('H' ,'Unit','H');
 
--no inf. about suppliers
create table drug_products as (
select distinct
case when d.pfc is not null then
trim( regexp_replace (replace ((volume||' '||substr ((replace (molecule, '+', ' / ')),1, 175) --To avoid names length more than 255
||'  '||c.DOSE_FORM_NAME||' ['||PRODUCT_DESC||']'||' Box of '||a.packsize), 'NULL', ''), '\s+', ' '))
else 
trim( regexp_replace (replace ((volume||' '||substr ((replace (molecule, '+', ' / ')),1, 175) --To avoid names length more than 255
||' '||c.DOSE_FORM_NAME||' Box of '||a.packsize), 'NULL', ''), '\s+', ' ')) end
as concept_name,'Drug Product' as concept_class_id, a.pfc as concept_code
from france_1 a
left join Brand d on d.CONCEPT_NAME = a.PRODUCT_DESC
left join  france_names_translation c on a.LB_NFC_3 = c.dose_form  -- france_names_translation is manually created table containing Form translation to English 
where a.pfc not in (select distinct pfc from non_drugs)
and molecule not like 'NULL'
)
;

--SEQUENCE FOR OMOP-GENERATED CODES

create sequence conc_stage_seq 
MINVALUE 100
  MAXVALUE 1000000
  START WITH 100
  INCREMENT BY 1
  CACHE 20;
  ;

create table list_temp
as select concept_name ,concept_class_id, 'OMOP'||conc_stage_seq.nextval as concept_code
from (
select distinct concept_name,concept_class_id  from ingr
union
select distinct concept_name,concept_class_id from Brand
where concept_name not in (select concept_name from ingr)
union
select distinct concept_name,concept_class_id from Forms
)
;
--fill drug_concept_stage

insert into DRUG_concept_STAGE (CONCEPT_NAME,VOCABULARY_ID,DOMAIN_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select CONCEPT_NAME, 'DA_France','Drug', CONCEPT_CLASS_ID, 'S', CONCEPT_CODE, '', TO_DATE(sysdate, 'yyyy/mm/dd') as valid_start_date, --check start date
TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date, ''
 from (
 select * from list_temp
 union 
 select * from drug_products
 union 
 select * from unit)
;

--DEVICES (rebuild names)
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,DOMAIN_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct
substr(volume||' '||case molecule 
 when 'NULL' then '' else molecule||' ' end||case dosage
  when 'NULL' then '' else dosage||' ' end||case dosage_add
  when 'NULL' then '' else dosage_add||' ' end||case form_desc when 'NULL' then '' else form_desc 
   end||case product_desc when 'NULL' then '' else ' ['||product_desc||']' end||' Box of '||packsize , 1,255
   )
      as concept_name, 'DA_France','Device', 'Device', 'S', pfc, '', TO_DATE(sysdate, 'yyyy/mm/dd') as valid_start_date, --check start date
TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date, ''
from non_drugs;


--fill IRS
--Drug to Ingredients

insert into internal_relationship_stage
select distinct pfc, concept_code from list_temp a join ingr using (concept_name,concept_class_id)
;
--drug to Brand Name
insert into internal_relationship_stage
select distinct pfc, concept_code from list_temp a join brand using (concept_name,concept_class_id)
;
--drug to Dose Form

insert into internal_relationship_stage
select distinct pfc, concept_code
from france_1 a join france_names_translation b on a.LB_NFC_3=b.DOSE_FORM
join drug_concept_stage c on b.dose_form_name = c.concept_name and concept_class_id='Dose Form'
;
commit;
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
COMMIT;--fill RLC
--Ingredients

select distinct a.concept_code as concept_code_1,'DA_France',f.concept_id as concept_id_2 , rank() over (partition by a.concept_code order by f.concept_id) as precedence 
from drug_concept_stage a join devv5.concept c 
on upper (c.concept_name) = upper(a.concept_name) and c.concept_class_id in ( 'Ingredient' , 'VTM', 'AU Substance')
join devv5.concept_relationship b on c.concept_id =concept_id_1
join devv5.concept f on f.concept_id=concept_id_2
where f.vocabulary_id like 'Rx%' and f.standard_concept='S'
and f.concept_class_id = 'Ingredient'
and a.concept_name like 'CYANOCOBALAMIN'
;


insert into relationship_to_concept 
select distinct a.concept_code,a.VOCABULARY_ID,c.concept_id,
rank() over (partition by a.concept_code order by concept_id_2) as precedence,
'' as conversion_factor
from drug_concept_stage a 
join ingredient_all_completed b on a.concept_name=b.concept_name
join devv5.concept c on c.concept_id=concept_id_2
where a.concept_class_id='Ingredient'
and (b.concept_name,concept_id_2) not in (select concept_name,concept_id_2 from drug_concept_stage 
join relationship_to_concept on concept_code=concept_code_1 and concept_class_id='Ingredient')
;

--Brand Names
insert into relationship_to_concept (concept_code_1, vocabulary_id_1,concept_id_2, precedence)
with a as (
select a.concept_code as concept_code_1,c.concept_id as concept_id_2 
from drug_concept_stage a join devv5.concept c 
on upper (c.concept_name) = upper(a.concept_name) and c.concept_class_id = 'Brand Name' and c.vocabulary_id like 'Rx%' and c.invalid_reason is null
where a.concept_class_id = 'Brand Name'
),
b as (
select concept_code,cast(concept_id_2 as number)
from  brand_names_manual a join drug_concept_stage b on upper(a.concept_name) =upper(b.concept_name)
and (concept_code,concept_id_2) not in (select concept_code_1,concept_id_2 from relationship_to_concept)
)
select concept_code_1, 'DA_France',concept_id_2, rank() over (partition by concept_code_1 order by concept_id_2)
from (select concept_code_1,concept_id_2 from a union select * from b)
;




--Dose Forms
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor)
select b.concept_code, 'DA_France',	CONCEPT_ID_2	, PRECEDENCE, '' from new_form_name_mapping a  --munualy created table 
join drug_concept_stage b on b.concept_name = a.DOSE_FORM_NAME
;
    
--Units
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('%', 'DA_France',8554,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('G', 'DA_France',8576,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('IU', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('IU', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('K', 'DA_France',8510,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('K', 'DA_France',8718,2,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('KG', 'DA_France',8576,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('L', 'DA_France',8587,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('M', 'DA_France',8510,1,1000000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MCG', 'DA_France',8576,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MG', 'DA_France',8576,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ML', 'DA_France',8576,2,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('U', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('U', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('Y', 'DA_France',8576,1,0.001);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('UI', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('UI', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MUI', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MUI', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('GM', 'DA_France',8576,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('DOS', 'DA_France',45744809,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('TU', 'DA_France',9413,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('TU', 'DA_France',8510,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('TU', 'DA_France',8718,3,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MU', 'DA_France',8510,2,0.000001);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MU', 'DA_France',8718,3,0.000001);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('H', 'DA_France',8505,1,1);
insert into concept_synonym_stage
(SYNONYM_NAME,SYNONYM_CONCEPT_CODE,SYNONYM_VOCABULARY_ID,LANGUAGE_CONCEPT_ID)
select dose_form,concept_code,'DA_France','4180190' -- French language 
from 
france_names_translation a join drug_concept_stage
on trim(upper(DOSE_FORM_NAME))=upper(concept_name);




-- Create sequence for new OMOP-created standard concepts
declare
 ex number;
begin
select max(iex)+1 into ex from (  
    
    select cast(replace(concept_code, 'OMOP') as integer) as iex from concept where concept_code like 'OMOP%'  and concept_code not like '% %'
);
  begin
    execute immediate 'create sequence new_vocab increment by 1 start with ' || ex || ' nocycle cache 20 noorder';
    exception
      when others then null;
  end;
end;
/

drop table code_replace;
 create table code_replace as 
 select 'OMOP'||new_vocab.nextval as new_code, concept_code as old_code from (
select distinct  concept_code from drug_concept_stage where concept_code like '%OMOP%' order by (cast ( regexp_substr( concept_code, '\d+') as int))
)
;
update drug_concept_stage a set concept_code = (select new_code from code_replace b where a.concept_code = b.old_code) 
where a.concept_code like '%OMOP%' 
;
commit
;
update relationship_to_concept a  set concept_code_1 = (select new_code from code_replace b where a.concept_code_1 = b.old_code)
where a.concept_code_1 like '%OMOP%'
;commit
;
update ds_stage a  set ingredient_concept_code = (select new_code from code_replace b where a.ingredient_concept_code = b.old_code)
where a.ingredient_concept_code like '%OMOP%' 
;
commit
;
update ds_stage a  set drug_concept_code = (select new_code from code_replace b where a.drug_concept_code = b.old_code)
where a.drug_concept_code like '%OMOP%' 
;commit
;
update internal_relationship_stage a  set concept_code_1 = (select new_code from code_replace b where a.concept_code_1 = b.old_code)
where a.concept_code_1 like '%OMOP%'
;commit
;
update internal_relationship_stage a  set concept_code_2 = (select new_code from code_replace b where a.concept_code_2 = b.old_code)
where a.concept_code_2 like '%OMOP%' 
;
commit
;
update pc_stage a  set DRUG_CONCEPT_CODE = (select new_code from code_replace b where a.DRUG_CONCEPT_CODE = b.old_code)
where a.DRUG_CONCEPT_CODE like '%OMOP%' 
;
update drug_concept_stage set standard_concept=null where concept_code in (select concept_code from drug_concept_stage 
join internal_relationship_stage on concept_code_1 = concept_code
where concept_class_id ='Ingredient' and standard_concept is not null);

commit;
commit; 
