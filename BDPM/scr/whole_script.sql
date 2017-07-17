drop table non_drug;

--01_seq

--drop sequence new_voc;

--02_packs_and_homeop
drop table homeop_drug CASCADE CONSTRAINTS PURGE;
drop table PF_from_pack_comp_list;

--list
drop table brand_name;
drop table ds_inhaler;
drop table dcs_manufacturer CASCADE CONSTRAINTS PURGE;
drop table dcs_bn CASCADE CONSTRAINTS PURGE;
drop table list;
drop sequence new_vocc;
drop sequence new_vocab;
--pack_content
drop table p_c_amount;
--inside tables
drop table RxE_BR_n_st_0;
drop table RxE_Man_st_0;
drop table RxE_Ing_st_0;
--packaging_parsing
drop table packaging_pars_1;
drop table packaging_pars_2;
drop table packaging_pars_3;
drop table drug_ingred_to_ingred;
drop table ingredient_step_1;
drop table ingredient_step_2;
drop table ds_1;


--pack_rebuilt
DROP table pack_st_1 ;
drop TABLE PACK_CONT_1;
drop table ds_pack_1;
drop sequence PACK_SEQUENCE;
drop TABLE PACK_COMP_LIST;

truncate table drug_concept_stage;
truncate table ds_stage;
truncate table internal_relationship_stage;
truncate table relationship_to_concept;
truncate table pc_stage;
truncate table Concept_synonym_stage;
create table non_drug as
select b.drug_Code,drug_Descr,ingredient,form,form_code from ingredient a join drug b 
on a.drug_code=b.drug_code
where form_code in ('4307','9354','77898','87188','94901','41804','14832','72310','89969','49487','24033','31035','66548','16621','31035') 
or dosage like '%Bq%' or form like '%dialyse%';
--insert radiopharmaceutical drugs
insert into non_drug (drug_Code,drug_descr,ingredient,form,form_code)
Select a.drug_Code,drug_descr,ingredient,form,form_code from 
drug a join ingredient b 
on a.drug_Code=b.drug_Code
where form like '%radio%' 
and a.drug_Code not in (select drug_code from non_drug);
--ingredients used in diagnostics
insert into non_drug (drug_Code,drug_descr,ingredient,form,form_code)
Select a.drug_Code,drug_descr,ingredient,form,form_code from 
drug a join ingredient b 
on a.drug_Code=b.drug_Code
where ingredient like '%IOXITALAM%' or ingredient like '%GADOTÉR%' or ingredient like '%AMIDOTRIZOATE%'
and a.drug_code not in (select drug_code from non_drug);
--patterns for dosages
insert into non_drug (drug_code,ingredient,form_Code)
select distinct  drug_code,ingredient,form_Code from ingredient a where a.drug_code in (
select drug_code from packaging where packaging  like '%compartiment%') and ( drug_form like '%compartiment%' or drug_form='%émulsion%')
and drug_form not like '%compartiment A%' and drug_form not like '%compartiment B%' and drug_form not like '%compartiment C%'
and drug_form not like '%compartiment (A)%' and drug_form not like '%compartiment (B)%'
and a.drug_code not in (select drug_code from non_drug) ;
--some patterns
insert into non_drug ( drug_Code,drug_descr,ingredient,form,form_code)
Select a.drug_Code,drug_descr,ingredient,form,form_code from 
drug a
left join ingredient b on a.drug_Code=b.drug_code
where regexp_like (drug_descr, 'hémofiltration|AMINOMIX|dialys|test|radiopharmaceutique|MIBG|STRUCTOKABIVEN|NUMETAN|NUMETAH|REANUTRIFLEX|CLINIMIX|REVITALOSE|CONTROLE|IOMERON|HEXABRIX|XENETIX', 'i') 
and a.drug_code not in (select drug_code from non_drug);
--create table with homeopathic drugs as they will be proceeded in different way
create table homeop_drug as 
(
select a.* from ingredient a join drug b on a.drug_code=b.drug_code where ingredient like '%HOMÉOPA%' or drug_descr like '%degré de dilution compris entre%'
);
create table packaging_pars_1 as 
select din_7, drug_code,  PACKAGING, 
case when  regexp_like  (packaging, '^[[:digit:]\.\,]+\s*(mg|g|ml|litre|l)(\s|$|\,)') then regexp_substr (packaging, '^[[:digit:]\.\,]+\s*(mg|g|ml|litre|l)') else
regexp_substr (packaging, 'de.*') end as amount, 
case when not regexp_like  (packaging, '^\d+\s*(mg|g|ml|litre|l)(\s|$|\,)')
then regexp_substr (packaging, '^\d+') else null end as box_size from packaging 
;
--remove spaces in amount
  update PACKAGING_PARS_1 set  AMOUNT = regexp_replace ( AMOUNT,'([[:digit:]]+) ([[:digit:]]+)' , '\1\2' )
 where regexp_like (AMOUNT,'[[:digit:]]+ [[:digit:]]+')
 ;
 --ignore "dose"
update packaging_pars_1 
set amount ='' where  amount like '%dose(s)%'
;
-- define box size and amount (Quant factor mostly)
 create table packaging_pars_2 as
 select 
 case when regexp_like (amount , '[[:digit:]\.\,]+\s*(ml|g|mg|l|UI|MBq/ml|GBq/ml|litre(s*)|à|mlavec|kg)(\s|$|\,)', 'i') 
then regexp_substr ( regexp_substr (amount , '[[:digit:]\.\,]+\s*(ml|g|mg|l|UI|MBq/ml|GBq/ml|litres|kg)(\s|$|\,)', 1,1,'i'), '[[:digit:]\.\,]+\s*(ml|g|mg|l|UI|MBq/ml|GBq/ml|litres|kg)') else null end as amount, 
 case when not regexp_like (amount , '[[:digit:]\.\,]+\s*(ml|g|mg|l|UI|MBq/ml|GBq/ml|litre(s*)|à|mlavec|kg)(\s|$|\,)', 'i') 
 and (replace ( regexp_substr (amount , '[[:digit:]\.\,]+'), ',', '.')) is not null
then ( regexp_substr (amount , '\d+'))* nvl( box_size, 1) 
else cast (box_size as int) end as box_size,
din_7, drug_code,  PACKAGING
 from packaging_pars_1
 ;
 --pars amount to value and unit
create table packaging_pars_3 as
select 
replace (regexp_substr (amount , '[[:digit:]\.\,]+'), ',', '.') as amount_value ,
regexp_substr (amount, '(ml|g|mg|l|UI|MBq/ml|GBq/ml|litre(s*)|kg)', 1,1,'i') as amount_unit,
box_size ,din_7, drug_code,  PACKAGING
 from packaging_pars_2
 ;
 --manual fix
 UPDATE PACKAGING_PARS_3
   SET AMOUNT_VALUE = '5.5',
       AMOUNT_UNIT = 'ml'
WHERE DIN_7 = 3328273
AND   PACKAGING = 'poudre en flacon(s) en verre + 5,5 ml de solvant en flacon(s) en verre';
UPDATE PACKAGING_PARS_3
   SET AMOUNT_VALUE = '1',
       AMOUNT_UNIT = 'ml'
WHERE DIN_7 = 5500089
AND   PACKAGING = 'système à double seringues (polypropylène) 1 * 2 ml (1 ml + 1 ml) avec piston, clippées dans un double porte-seringue et munies de capuchons, avec un set de dispositifs d''application constitué de 2 pièces de raccordement et de 4 canules d''application';
UPDATE PACKAGING_PARS_3
   SET AMOUNT_VALUE = '2',
       AMOUNT_UNIT = 'ml'
WHERE DIN_7 = 5500091
AND   PACKAGING = 'système à double seringues (polypropylène) 1 * 4 ml (2 ml + 2 ml) avec piston, clippées dans un double porte-seringue et munies de capuchons, avec un set de dispositifs d''application constitué de 2 pièces de raccordement et de 4 canules d''application';
UPDATE PACKAGING_PARS_3
   SET AMOUNT_VALUE = '5',
       AMOUNT_UNIT = 'ml'
WHERE DIN_7 = 5500092
AND   PACKAGING = 'système à double seringues (polypropylène) 1 * 10 ml (5 ml + 5 ml) avec piston, clippées dans un double porte-seringue et munies de capuchons, avec un set de dispositifs d''application constitué de 2 pièces de raccordement et de 4 canules d''application';
UPDATE PACKAGING_PARS_3
   SET AMOUNT_VALUE = '20',
       AMOUNT_UNIT = 'ml'
WHERE DIN_7 = 5645150
AND   PACKAGING = 'Poudre en flacon(s) en verre + 20 ml de solvant flacon(s) en verre avec aiguille(s), une seringue à usage unique (polypropylène) et un nécessaire d''injection + un dispositif de transfert BAXJECT II HI-Flow';
UPDATE PACKAGING_PARS_3
   SET AMOUNT_VALUE = '5.5',
       AMOUNT_UNIT = 'ml'
WHERE DIN_7 = 3328310
AND   PACKAGING = 'poudre en flacon(s) en verre + 5,5 ml de solvant en flacon(s) en verre';
UPDATE PACKAGING_PARS_3
   SET AMOUNT_VALUE = '20',
       AMOUNT_UNIT = 'ml'
WHERE DIN_7 = 5645144
AND   PACKAGING = 'Poudre en flacon(s) en verre + 20 ml de solvant flacon(s) en verre avec aiguille(s), une seringue à usage unique (polypropylène) et un nécessaire d''injection + un dispositif de transfert BAXJECT II HI-Flow';
UPDATE PACKAGING_PARS_3
   SET AMOUNT_VALUE = '0.5',
       AMOUNT_UNIT = 'ml'
WHERE DIN_7 = 5611085
AND   PACKAGING = '2 poudres en flacons en verre et 2 fois 0,5 ml de solution en flacons en verre avec nécessaire d''application';
UPDATE PACKAGING_PARS_3
   SET AMOUNT_VALUE = '1',
       AMOUNT_UNIT = 'ml'
WHERE DIN_7 = 5611091
AND   PACKAGING = '2 poudres en flacons en verre et 2 fois 1 ml de solution en flacons en verre avec nécessaire d''application';
UPDATE PACKAGING_PARS_3
   SET AMOUNT_VALUE = '3',
       AMOUNT_UNIT = 'ml'
WHERE DIN_7 = 5611116
AND   PACKAGING = '2 poudres en flacons en verre et 2 fois 3 ml de solution en flacons en verre avec nécessaire d''application';
;
 --mistakes in the orinal table fixing
 UPDATE INGREDIENT
   SET VOLUME = '100 ml'
WHERE DRUG_CODE = '64482812'
AND   FORM_CODE = 3691;
;
UPDATE INGREDIENT
   SET DOSAGE = '0,05000 g'
WHERE DOSAGE = '0, 05000';
 ;
--find relationships between ingredients within the one drug
create table drug_ingred_to_ingred as 
select distinct a.drug_code, a.form_code as concept_code_1, a.ingredient as concept_name_1 , b.form_code as  concept_code_2 , b.ingredient as  concept_name_2 from ingredient a
 join ingredient b on a.drug_code = b.drug_code  and a.COMP_NUMBER = b.COMP_NUMBER and a.INGREDIENT != b.INGREDIENT
and a.INGR_NATURE = 'SA' and  b.INGR_NATURE = 'FT' 
;
--exclude homeopic_drugs and precise ingredients 
create table ingredient_step_1 as
select * from ingredient a where not exists (select 1 from drug_ingred_to_ingred b where a.drug_code = b.drug_code and form_code = concept_code_1)
and drug_code not in (select drug_code from homeop_drug )
;
--manual fix of dosages
UPDATE INGREDIENT_STEP_1
   SET DOSAGE = '1000000 Ul'
WHERE DRUG_CODE = '68039248'
AND   INGREDIENT = 'SULFATE DE POLYMYXINE B';
;
UPDATE INGREDIENT_STEP_1
   SET DOSAGE = '100000 UI'
WHERE FORM_CODE = 4031
AND   DOSAGE = '100  000 UI';

update INGREDIENT_STEP_1 
set dosage = '30000000 U' where dosage =  
'200 millions à 3000 millions germes reviviscibles'
;
--spaces in dosages
update ingredient_step_1 set DOSAGE = regexp_replace (DOSAGE,'([[:digit:]\,]+) ([[:digit:]\,]+)' , '\1\2' )
 where regexp_like (DOSAGE,'[[:digit:]\,]+ [[:digit:]\,]+')
 ;
 update ingredient_step_1 set DOSAGE = regexp_replace (DOSAGE,'([[:digit:]\,]+) ([[:digit:]\,]+)' , '\1\2' )
 where regexp_like (DOSAGE,'[[:digit:]\,]+ [[:digit:]\,]+')
 ;
 update ingredient_step_1 set volume = regexp_replace (volume,'([[:digit:]\,]+) ([[:digit:]\,]+)' , '\1\2' )
 where regexp_like (volume,'[[:digit:]\,]+ [[:digit:]\,]+')
 ;
  update ingredient_step_1 set volume = regexp_replace (volume,'([[:digit:]\,]+) ([[:digit:]\,]+)' , '\1\2' )
 where regexp_like (volume,'[[:digit:]\,]+ [[:digit:]\,]+')
;



--manual fix of dosages
update ingredient_step_1 set dosage = '31250000000 U' where dosage ='31,25 * 10^9 bactéries';
 update ingredient_step_1 set dosage = '1000 DICC50' where dosage ='au minimum 10^^3,0 DICC50';
 update ingredient_step_1 set dosage = '800000 UFC' where dosage ='2-8 x 10^5 UFC'
 ;
 update ingredient_step_1 set dosage = '2000 DICC50' where dosage ='au minimum 10^^3,3 DICC50'
;
update ingredient_step_1 set dosage = '5000 DICC50' where dosage ='au minimum 10^^3,7 DICC50'
;
update ingredient_step_1 set dosage = '10000000 U' where dosage ='10^(7+/- 0,5)' 
;
update ingredient_step_1 set dosage = '1 millions UI' where dosage like '1 million d%unités internationales (UI)' 
;
--parsing dosages taking exact digit - unit pares 
create table ingredient_step_2 as
select a.*, 
replace ( 
regexp_substr(
regexp_substr (dosage, 
'[[:digit:]\.\,]+\s*(UI|UFC|IU|micromoles|µmol|g|mg|mcg|microgramme(s*)|µg|millions UI|MBq|DICC50|UIK|Unités FEIBA|Gbq|UFP|U\.CEIP|ml|U|IR|Unités Antihéparine|log  DICC50|nanogrammes|M(\.|\s)U\.I\.|UD (Unité antigène D)|MU|Ul|unités|%|U\.I\.|ATU|mmol|mEq|DL50|U\.l\.|Unités|MUI|U\.|Unités antigène D|Millions UI|ppm mole|UI|kBq|SQ-T|milliard|microlitres|nanokatals|UD \(Unité antigène D\)|Unité antigène D|M UI|DICT50|micrcrogrammes|GBq|mg.|M.UI|MBq/ml|UD|UIK.|Mq|millions d.UI|U.I|U.D.|ng)(\s|$)')
, '[[:digit:]\.\,]+'), ',', '.') as dosage_value,

regexp_substr(
regexp_substr (dosage, 
'[[:digit:]\.\,]+\s*(UI|UFC|micromoles|IU|µmol|g|mg|mcg|microgramme(s*)|µg|millions UI|MBq|DICC50|UIK|Unités FEIBA|Gbq|UFP|U\.CEIP|ml|U|IR|Unités Antihéparine|log  DICC50|nanogrammes|M(\.|\s)U\.I\.|UD (Unité antigène D)|MU|Ul|unités|%|U\.I\.|ATU|mmol|mEq|DL50|U\.l\.|Unités|MUI|U\.|Unités antigène D|Millions UI|ppm mole|UI|kBq|SQ-T|milliard|microlitres|nanokatals|UD \(Unité antigène D\)|Unité antigène D|M UI|DICT50|micrcrogrammes|GBq|mg.|M.UI|MBq/ml|UD|UIK.|Mq|millions d.UI|U.I|U.D.|ng)(\s|$)')
, '(UI|UFC|micromoles|IU|µmol|g|mg|mcg|microgramme(s*)|µg|millions UI|MBq|DICC50|UIK|Unités FEIBA|Gbq|UFP|U\.CEIP|ml|U|IR|Unités Antihéparine|log  DICC50|nanogrammes|M(\.|\s)U\.I\.|UD (Unité antigène D)|MU|Ul|unités|%|U\.I\.|ATU|mmol|mEq|DL50|U\.l\.|Unités|MUI|U\.|Unités antigène D|Millions UI|ppm mole|UI|kBq|SQ-T|milliard|microlitres|nanokatals|UD \(Unité antigène D\)|Unité antigène D|M UI|DICT50|micrcrogrammes|GBq|mg.|M.UI|MBq/ml|UD|UIK.|Mq|millions d.UI|U.I|U.D.|ng)'
) as dosage_unit, 

replace ( 
regexp_substr(
regexp_substr (volume , '[[:digit:]\.\,]+\s*(cm *²|g|ml|cm\^2)') -- for denominartor
, '[[:digit:]\.\,]+'), ',', '.') as volume_value,

regexp_substr (
regexp_substr (volume , '[[:digit:]\.\,]+\s*(cm *²|g|ml|cm\^2)'),
'(cm *²|g|ml|cm\^2)'
) as volume_unit 

from ingredient_step_1 a
;
--fix inaccuracies coming from original data
UPDATE INGREDIENT_STEP_2
   SET DOSAGE_VALUE = '0.5'
WHERE DOSAGE_VALUE = '.5';

UPDATE INGREDIENT_STEP_2
   SET DOSAGE_VALUE = '200000000'
WHERE DOSAGE_VALUE = '200.000.000';
UPDATE INGREDIENT_STEP_2
   SET DOSAGE_VALUE = '1000000'
WHERE DOSAGE_VALUE = '1.000.000';

UPDATE INGREDIENT_STEP_2
   SET DOSAGE_VALUE = '19000.000'
WHERE DOSAGE_VALUE = '19.000.000';


--recalculate all the possible combinations between packaging info and ingredient info
create table ds_1 as 
select distinct din_7 as concept_code, a.drug_code, DRUG_FORM, form_code as ingredient_code, ingredient as ingredient_name, packaging, d.drug_descr, dosage_value, 
dosage_unit, volume_value, volume_unit, amount_value as pack_amount_value, amount_unit as pack_amount_unit,
case when volume_value is null and AMOUNT_VALUE is null and dosage_unit !='%' then dosage_value else null end as amount_value,
case when volume_value is null and AMOUNT_VALUE is null and dosage_unit !='%' then dosage_unit else null end as  amount_unit ,
case when volume_value is not null and amount_value is not null 
and dosage_unit !='%' and (lower (nvl( volume_unit, AMOUNT_unit)) = lower (nvl( AMOUNT_unit, volume_unit)) 
or volume_unit = 'g' and amount_unit = 'ml')
then dosage_value/volume_value*amount_value
when volume_value is not null and amount_value is null 
and dosage_unit !='%' and lower (nvl( volume_unit, AMOUNT_unit)) = lower (nvl( AMOUNT_unit, volume_unit)) then cast (dosage_value as float)

when volume_value is null and amount_value is not null and dosage_unit !='%' and lower (nvl( volume_unit, AMOUNT_unit)) = lower (nvl( AMOUNT_unit, volume_unit)) then cast (dosage_value as float)
when (volume_value is not null or AMOUNT_VALUE is not null) and dosage_unit !='%' 
and lower ( volume_unit) = 'm'||lower ( AMOUNT_unit) 
 then dosage_value/nvl(volume_value, 1)*nvl(amount_value, 1)*1000
 
when (volume_value is not null or AMOUNT_VALUE is not null) and dosage_unit !='%' 
and lower (amount_unit ) = 'k'||lower ( volume_unit) 
 then dosage_value/nvl(volume_value, 1)*nvl(amount_value, 1)*1000

/*volume (7g) / (sum (125 mg) * dosage - это numerator
1 ml * volume (7g) / (sum (dosage) group by within one drug) - это denumerator
*/
--not so simple
when  lower ( volume_unit) =  'ml'  and (lower ( AMOUNT_unit) like '%g%' or AMOUNT_unit = 'UI') then amount_value / dos_sum * dosage_value 
when  dosage_unit ='%' then cast (dosage_value as float) 
else null end as numerator_value,

case when (volume_value is not null or AMOUNT_VALUE is not null) then dosage_unit
     when dosage_unit ='%' then '%' 
     when  lower ( volume_unit) =  'ml' and (lower ( AMOUNT_unit) like '%g%' or AMOUNT_unit = 'UI')
then amount_unit
else null end as numerator_unit,   
 
case
when  lower ( volume_unit) =  'ml' and (lower ( AMOUNT_unit) like '%g%' or AMOUNT_unit = 'UI') then volume_value  * amount_value / dos_sum 

else cast (nvl (amount_value, volume_value) as float) end as denominator_value,

case when lower ( volume_unit) =  'ml' and (lower ( AMOUNT_unit) like '%g%' or AMOUNT_unit = 'UI') then volume_unit
else nvl(AMOUNT_unit, volume_unit) end as denominator_unit, 
box_size

from packaging_pars_3 a join ingredient_step_2 b on a.drug_code = b.drug_code 
join drug d on b.drug_code = d.drug_code
join  (
select drug_code, sum ( (dosage_value ) ) as dos_sum from ingredient_step_2 group by drug_code) s on s.drug_code = a.drug_code
;
--update when we have drug description containing dosage (unit!= %)
 update ds_1 set amount_value = replace ( 
regexp_substr(
regexp_substr (DRUG_DESCR, 
'[[:digit:]\.\,]+\s*(UI|IU|µmol|g|mg|mcg|microgramme(s*)|µg|millions UI|MBq|DICC50|UIK|Unités FEIBA|Gbq|UFP|U\.CEIP|ml|U|IR|Unités Antihéparine|log  DICC50|nanogrammes|M(\.|\s)U\.I\.|UD (Unité antigène D)|MU|Ul|unités|U\.I\.|ATU|mmol|mEq|DL50|U\.l\.|Unités|MUI|U\.|Unités antigène D|Millions UI|ppm mole|UI|kBq|SQ-T|milliard|microlitres|nanokatals|UD \(Unité antigène D\)|Unité antigène D|M UI|DICT50|micrcrogrammes|GBq|mg.|M.UI|MBq/ml|UD|UIK.|Mq|millions d.UI|U.I|U.D.|ng)(\s|$|\,)')
, '[[:digit:]\.\,]+'), ',', '.'),
amount_unit = 
regexp_substr(
regexp_substr (DRUG_DESCR, 
'[[:digit:]\.\,]+\s*(UI|IU|µmol|g|mg|mcg|microgramme(s*)|µg|millions UI|MBq|DICC50|UIK|Unités FEIBA|Gbq|UFP|U\.CEIP|ml|U|IR|Unités Antihéparine|log  DICC50|nanogrammes|M(\.|\s)U\.I\.|UD (Unité antigène D)|MU|Ul|unités|U\.I\.|ATU|mmol|mEq|DL50|U\.l\.|Unités|MUI|U\.|Unités antigène D|Millions UI|ppm mole|UI|kBq|SQ-T|milliard|microlitres|nanokatals|UD \(Unité antigène D\)|Unité antigène D|M UI|DICT50|micrcrogrammes|GBq|mg.|M.UI|MBq/ml|UD|UIK.|Mq|millions d.UI|U.I|U.D.|ng)(\s|$|\,)')
, '(UI|IU|µmol|g|mg|mcg|microgramme(s*)|µg|millions UI|MBq|DICC50|UIK|Unités FEIBA|Gbq|UFP|U\.CEIP|ml|U|IR|Unités Antihéparine|log  DICC50|nanogrammes|M(\.|\s)U\.I\.|UD (Unité antigène D)|MU|Ul|unités|U\.I\.|ATU|mmol|mEq|DL50|U\.l\.|Unités|MUI|U\.|Unités antigène D|Millions UI|ppm mole|UI|kBq|SQ-T|milliard|microlitres|nanokatals|UD \(Unité antigène D\)|Unité antigène D|M UI|DICT50|micrcrogrammes|GBq|mg.|M.UI|MBq/ml|UD|UIK.|Mq|millions d.UI|U.I|U.D.|ng)'
) 
where regexp_like (DRUG_DESCR, 
 '[[:digit:]\.\,]+\s*(UI|IU|µmol|g|mg|mcg|microgramme(s*)|µg|millions UI|MBq|DICC50|UIK|Unités FEIBA|Gbq|UFP|U\.CEIP|ml|U|IR|Unités Antihéparine|log  DICC50|nanogrammes|M(\.|\s)U\.I\.|UD (Unité antigène D)|MU|Ul|unités|U\.I\.|ATU|mmol|mEq|DL50|U\.l\.|Unités|MUI|U\.|Unités antigène D|Millions UI|ppm mole|UI|kBq|SQ-T|milliard|microlitres|nanokatals|UD \(Unité antigène D\)|Unité antigène D|M UI|DICT50|micrcrogrammes|GBq|mg.|M.UI|MBq/ml|UD|UIK.|Mq|millions d.UI|U.I|U.D.|ng)(\s|$|\,)')
and amount_value is null and numerator_value is null
;
--update when we have drug description containing dosage (unit = %)
 update ds_1 set numerator_value = replace ( 
regexp_substr(
regexp_substr (DRUG_DESCR, 
'[[:digit:]\.\,]+\s*%'), '[[:digit:]\.\,]+'), ',', '.'),
numerator_unit = 
regexp_substr(
regexp_substr (DRUG_DESCR, 
'[[:digit:]\.\,]+\s*%(\s|$|\,)')
, '%') 
where regexp_like (DRUG_DESCR, 
 '[[:digit:]\.\,]+\s*%')and amount_value is null and numerator_value is null
;


--UPDATE UNITS WITH TRANSLATION OF UNITS
--HERE SHOULD BE KIND OF MANUAL TABLES DESCRIPTION, BECAUSE UNIT_TRANSLATION WE GOT FROM ds_1 BEFORE THIS UPDATE
UPDATE ds_1 set
amount_unit = (SELECT TRANSLATION FROM UNIT_TRANSLATION --manual table
WHERE amount_unit = UNIT)
;
UPDATE ds_1 set
numerator_unit = (SELECT TRANSLATION FROM UNIT_TRANSLATION WHERE numerator_unit = UNIT)
WHERE EXISTS (SELECT 1 FROM UNIT_TRANSLATION WHERE numerator_unit = UNIT)
;
UPDATE ds_1 set
denominator_unit = (SELECT TRANSLATION FROM UNIT_TRANSLATION WHERE denominator_unit = UNIT)
WHERE EXISTS (SELECT 1 FROM UNIT_TRANSLATION WHERE denominator_unit = UNIT)
;
--make sure we don't include non-drug into ds_stage
delete from ds_1 where drug_code in (select drug_code from non_drug) ;
;
UPDATE DS_1
   SET NUMERATOR_UNIT = 'mg'
WHERE CONCEPT_CODE = 5654597
AND   INGREDIENT_CODE = 1080;

--for gazes consider whole volume as amount
update ds_1 set
amount_value = denominator_value,
amount_unit = denominator_unit,
numerator_value = '',
numerator_unit ='',
denominator_value ='',
denominator_unit =''
where 
 drug_form = 'gaz'
and amount_value is null and  amount_unit is null
;
COMMIT
;
create table pack_st_1 as
select drug_code, drug_form, form_code
from ingredient_step_1 where drug_code in (
select drug_code from 
(
select distinct drug_code, drug_form from ingredient_step_1) group by drug_code having count (1) > 1
)
AND drug_code not in (select drug_code from non_drug)
and drug_code not in (select drug_code from HOMEOP_DRUG)
;
delete from pack_st_1 where drug_code in (64122611,67657035);

--sequence will be used in pack component definition
CREATE SEQUENCE PACK_SEQUENCE
  MINVALUE 1
  MAXVALUE 1000000
  START WITH 1
  INCREMENT BY 1
  CACHE 100
  ;

--take all the pack components 
  CREATE TABLE PACK_COMP_LIST AS 
  select 'PACK'||PACK_SEQUENCE.nextval as pack_component_code, 
  a.*  
  from (
select distinct 
a.DRUG_CODE,a.DRUG_FORM,DRUG_DESCR,DENOMINATOR_VALUE,DENOMINATOR_UNIT
from ds_1 a join pack_st_1 b on a.drug_code = b.drug_code and a.drug_form = b.drug_form and a.ingredient_code = form_code
where a.drug_code not in (select drug_code from non_drug)
) A  
;
--pack content, but need to put amounts manualy
CREATE TABLE PACK_CONT_1 AS 
SELECT distinct concept_code,pack_component_code, a.drug_descr as pack_name, a.drug_descr ||' '|| a.drug_form as pack_component_name, packaging--, amount_value, amount_DRUG_CODE,DRUG_FORM,DRUG_DESCR,DENOMINATOR_VALUE,DENOMINATOR_UNIT
FROM PACK_COMP_LIST B
JOIN DS_1 A on  a.DRUG_CODE = b.drug_code
and a.DRUG_FORM= b.DRUG_FORM
and a.DRUG_DESCR = b.DRUG_DESCR
and nvl(a.DENOMINATOR_VALUE, '0') = nvl (b.DENOMINATOR_VALUE, '0') 
and nvl (a.DENOMINATOR_UNIT, '0') = nvl (b.DENOMINATOR_UNIT, '0')
;
update PACK_CONT_1 set pack_component_name='INERT INGREDIENT Metered Dose Inhaler' where concept_code='5731866' and pack_component_name like 'ARIDOL, poudre pour inhalation en gélule gélule transparente';


--ds_stage for Pack_components 
create table ds_pack_1 as
select    PACK_COMPONENT_CODE,a.DRUG_FORM,INGREDIENT_CODE,INGREDIENT_NAME,
PACKAGING,a.DRUG_DESCR,DOSAGE_VALUE,DOSAGE_UNIT,VOLUME_VALUE,VOLUME_UNIT,PACK_AMOUNT_VALUE,PACK_AMOUNT_UNIT,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,a.DENOMINATOR_VALUE,a.DENOMINATOR_UNIT, cast ('' as int) as BOX_SIZE
from ds_1 a join PACK_COMP_LIST b   
on nvl(a.DENOMINATOR_VALUE, '0') = nvl (b.DENOMINATOR_VALUE, '0') 
and nvl (a.DENOMINATOR_UNIT, '0') = nvl (b.DENOMINATOR_UNIT, '0')
and  a.DRUG_FORM = b.DRUG_FORM
and a.DRUG_CODE =b.DRUG_CODE
;
--pack components forms 
create table PF_from_pack_comp_list as (
select distinct PACK_COMPONENT_CODE,-- ROUTE,DRUG_FORM,
case when DRUG_FORM like '%comprimé%' then 'Oral Tablet'
     when (DRUG_FORM like '%sachet%' or DRUG_FORM like '%solution%' or DRUG_FORM like '%poche%' or DRUG_FORM like '%poudre%' or DRUG_FORM like '%solvant%') and ROUTE='orale' then 'Oral Solution'
     when DRUG_FORM like '%granulés%'  then 'Oral Granules'
     when DRUG_FORM like '%gélule%' and ROUTE='orale' then 'Oral Capsule' 
     when DRUG_FORM like '%gélule%' and ROUTE='inhalée' then 'Metered Dose Inhaler' 
     when DRUG_FORM like '%poudre%' and ROUTE='inhalée' then 'Inhalant Powder' 
     when (DRUG_FORM like '%solution%' or DRUG_FORM like '%poudre%' or DRUG_FORM like '%solvant%') and ROUTE='nasale' then 'Nasal Solution'
     when DRUG_FORM like '%solution%' or DRUG_FORM like '%poudre%' or DRUG_FORM like '%solvant%' then 'Injectable Solution'
     when DRUG_FORM like '%suspension%' or DRUG_FORM like 'émulsion%' then 'Injectable Suspension'
     when DRUG_FORM like '%dispositif%'  then 'Transdermal Patch' else 'Injectable Solution' end as PACK_FORM
     from  PACK_COMP_LIST pcl
     JOIN drug d ON d.DRUG_CODE=pcl.DRUG_CODE);
--ds_1 for drugs and ds_pack_1 for packs
insert into ds_stage (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
select distinct cast (CONCEPT_CODE as varchar (200)) as CONCEPT_CODE,INGREDIENT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT from ds_1 
WHERE concept_code not in (select concept_code from PACK_CONT_1)
union 
select distinct PACK_COMPONENT_CODE,INGREDIENT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT from ds_pack_1
;
--sum up the same ingredients manualy
DELETE FROM DS_STAGE WHERE  DRUG_CONCEPT_CODE = '3087355' AND   INGREDIENT_CONCEPT_CODE = '5356' AND   BOX_SIZE = 20 AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 1.4 AND   NUMERATOR_UNIT = 'g' AND   DENOMINATOR_VALUE = 10 AND   DENOMINATOR_UNIT = 'g';
DELETE FROM DS_STAGE WHERE  DRUG_CONCEPT_CODE = '3200509' AND   INGREDIENT_CONCEPT_CODE = '1261' AND   BOX_SIZE = 1 AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 5 AND   NUMERATOR_UNIT = 'mg' AND   DENOMINATOR_VALUE = 1 AND   DENOMINATOR_UNIT = 'ml';
DELETE FROM DS_STAGE WHERE  DRUG_CONCEPT_CODE = '3205777' AND   INGREDIENT_CONCEPT_CODE = '1261' AND   BOX_SIZE = 1 AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 3 AND   NUMERATOR_UNIT = 'mg' AND   DENOMINATOR_VALUE = 1 AND   DENOMINATOR_UNIT = 'ml';
DELETE FROM DS_STAGE WHERE  DRUG_CONCEPT_CODE = '3698389' AND   INGREDIENT_CONCEPT_CODE = '563' AND   BOX_SIZE = 10 AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 0.695 AND   NUMERATOR_UNIT = 'g' AND   DENOMINATOR_VALUE = 500 AND   DENOMINATOR_UNIT = 'ml';
DELETE FROM DS_STAGE WHERE  DRUG_CONCEPT_CODE = '3698426' AND   INGREDIENT_CONCEPT_CODE = '563' AND   BOX_SIZE = 10 AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 1.2 AND   NUMERATOR_UNIT = 'g' AND   DENOMINATOR_VALUE = 500 AND   DENOMINATOR_UNIT = 'ml';
DELETE FROM DS_STAGE WHERE  DRUG_CONCEPT_CODE = '5536774' AND   INGREDIENT_CONCEPT_CODE = '1261' AND   BOX_SIZE = 25 AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 3 AND   NUMERATOR_UNIT = 'mg' AND   DENOMINATOR_VALUE = 1 AND   DENOMINATOR_UNIT = 'ml';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 2.5 WHERE  DRUG_CONCEPT_CODE = '3087355' AND   INGREDIENT_CONCEPT_CODE = '5356' AND   BOX_SIZE = 20 AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 1.1 AND   NUMERATOR_UNIT = 'g' AND   DENOMINATOR_VALUE = 10 AND   DENOMINATOR_UNIT = 'g';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 7 WHERE  DRUG_CONCEPT_CODE = '3200509' AND   INGREDIENT_CONCEPT_CODE = '1261' AND   BOX_SIZE = 1 AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 2 AND   NUMERATOR_UNIT = 'mg' AND   DENOMINATOR_VALUE = 1 AND   DENOMINATOR_UNIT = 'ml';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 5.7 WHERE  DRUG_CONCEPT_CODE = '3205777' AND   INGREDIENT_CONCEPT_CODE = '1261' AND   BOX_SIZE = 1 AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 2.7 AND   NUMERATOR_UNIT = 'mg' AND   DENOMINATOR_VALUE = 1 AND   DENOMINATOR_UNIT = 'ml';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 1.715 WHERE  DRUG_CONCEPT_CODE = '3698389' AND   INGREDIENT_CONCEPT_CODE = '563' AND   BOX_SIZE = 10 AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 1.015 AND   NUMERATOR_UNIT = 'g' AND   DENOMINATOR_VALUE = 500 AND   DENOMINATOR_UNIT = 'ml';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 2.795 WHERE  DRUG_CONCEPT_CODE = '3698426' AND   INGREDIENT_CONCEPT_CODE = '563' AND   BOX_SIZE = 10 AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 1.595 AND   NUMERATOR_UNIT = 'g' AND   DENOMINATOR_VALUE = 500 AND   DENOMINATOR_UNIT = 'ml';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 5.7 WHERE  DRUG_CONCEPT_CODE = '5536774' AND   INGREDIENT_CONCEPT_CODE = '1261' AND   BOX_SIZE = 25 AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 2.7 AND   NUMERATOR_UNIT = 'mg' AND   DENOMINATOR_VALUE = 1 AND   DENOMINATOR_UNIT = 'ml';
;
DELETE FROM DS_STAGE WHERE DRUG_CONCEPT_CODE = '3284943' AND   INGREDIENT_CONCEPT_CODE = '29848' AND   BOX_SIZE = 5 AND   AMOUNT_VALUE = 0.23 AND   AMOUNT_UNIT = 'mg';
DELETE FROM DS_STAGE WHERE DRUG_CONCEPT_CODE = '3354164' AND   INGREDIENT_CONCEPT_CODE = '1023' AND   BOX_SIZE = 24 AND   AMOUNT_VALUE = 300 AND   AMOUNT_UNIT = 'mg';
DELETE FROM DS_STAGE WHERE DRUG_CONCEPT_CODE = '3404695'  AND   INGREDIENT_CONCEPT_CODE = '2202'  AND   BOX_SIZE = 24  AND   AMOUNT_VALUE = 62.5  AND   AMOUNT_UNIT = 'mg';
DELETE FROM DS_STAGE WHERE DRUG_CONCEPT_CODE = '5758486'  AND   INGREDIENT_CONCEPT_CODE = '29848'  AND   BOX_SIZE = 30  AND   AMOUNT_VALUE = 0.23  AND   AMOUNT_UNIT = 'mg';
DELETE FROM DS_STAGE WHERE DRUG_CONCEPT_CODE = '3584846'  AND   INGREDIENT_CONCEPT_CODE = '1023'  AND   BOX_SIZE = 30  AND   AMOUNT_VALUE = 500  AND   AMOUNT_UNIT = 'mg';
UPDATE DS_STAGE   SET AMOUNT_VALUE = 1.53 WHERE DRUG_CONCEPT_CODE = '3284943'  AND   INGREDIENT_CONCEPT_CODE = '29848'  AND   BOX_SIZE = 5  AND   AMOUNT_VALUE = 1.31  AND   AMOUNT_UNIT = 'mg';
UPDATE DS_STAGE   SET AMOUNT_VALUE = 500 WHERE DRUG_CONCEPT_CODE = '3354164'  AND   INGREDIENT_CONCEPT_CODE = '1023'  AND   BOX_SIZE = 24  AND   AMOUNT_VALUE = 200  AND   AMOUNT_UNIT = 'mg';
UPDATE DS_STAGE   SET AMOUNT_VALUE = 250 WHERE DRUG_CONCEPT_CODE = '3404695'  AND   INGREDIENT_CONCEPT_CODE = '2202'  AND   BOX_SIZE = 24  AND   AMOUNT_VALUE = 187.5  AND   AMOUNT_UNIT = 'mg';
UPDATE DS_STAGE   SET AMOUNT_VALUE = 700 WHERE DRUG_CONCEPT_CODE = '3584846'  AND   INGREDIENT_CONCEPT_CODE = '1023'  AND   BOX_SIZE = 30  AND   AMOUNT_VALUE = 200  AND   AMOUNT_UNIT = 'mg';
UPDATE DS_STAGE   SET AMOUNT_VALUE = 1.53 WHERE DRUG_CONCEPT_CODE = '5758486'  AND   INGREDIENT_CONCEPT_CODE = '29848'  AND   BOX_SIZE = 30  AND   AMOUNT_VALUE = 1.31  AND   AMOUNT_UNIT = 'mg';
--sometimes denominator is just a sum of components, so in this case we need to ignore denominators
update ds_stage 
 set 
amount_value = numerator_value,
amount_unit = numerator_unit,
numerator_value = '',
numerator_unit ='',
denominator_value ='',
denominator_unit =''
where 
drug_concept_code in (
select a.drug_concept_code from ds_stage a join 
(
select drug_concept_code, sum (numerator_value) as summ, NUMERATOR_UNIT from ds_stage group by drug_concept_code, denominator_value , denominator_unit, NUMERATOR_UNIT
) b on a.drug_concept_code = b.drug_concept_code and  summ / denominator_value < 1.2 and summ / denominator_value > 0.8
and a.numerator_unit = b.NUMERATOR_UNIT 
where a.NUMERATOR_UNIT = a.DENOMINATOR_UNIT
)
;
--drug with no din7
insert into ds_stage (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
VALUES (60253264,612,'2.5','IU','1','ml');


update ds_stage
set numerator_value=numerator_value*10*DENOMINATOR_VALUE,
    numerator_unit='mg'
where NUMERATOR_UNIT='%';
update ds_stage 
set DENOMINATOR_VALUE=null,
    DENOMINATOR_UNIT=null
where DENOMINATOR_UNIT is not null and NUMERATOR_UNIT is null;

merge into ds_stage a 
using ds_stage_update b
on (a.drug_concept_code=b.drug_concept_code and a.ingredient_concept_code=b.ingredient_concept_code and a.box_size=b.box_size)
when matched then update set
a.AMOUNT_VALUE=b.AMOUNT_VALUE,
a.AMOUNT_UNIT=b.AMOUNT_UNIT,
a.NUMERATOR_VALUE=b.NUMERATOR_VALUE,
a.NUMERATOR_UNIT=b.NUMERATOR_UNIT,
a.DENOMINATOR_VALUE=b.DENOMINATOR_VALUE,
a.DENOMINATOR_UNIT=b.DENOMINATOR_UNIT
;
update ds_stage set NUMERATOR_VALUE=AMOUNT_VALUE*30,NUMERATOR_UNIT=AMOUNT_UNIT,DENOMINATOR_VALUE=30,DENOMINATOR_UNIT='ACTUAT', AMOUNT_VALUE=null,AMOUNT_UNIT=null
where drug_concept_code in ('2761996','3000459');
update ds_stage set NUMERATOR_VALUE=power(10,NUMERATOR_VALUE), NUMERATOR_UNIT='CCID_50' where NUMERATOR_UNIT='log CCID_50';
update ds_stage set NUMERATOR_VALUE=10 where drug_concept_code='5704697' and ingredient_concept_code='51742';
update ds_stage set NUMERATOR_VALUE=20 where drug_concept_code='5704711' and ingredient_concept_code='51742';
update ds_stage set NUMERATOR_VALUE=10 where drug_concept_code='5750852' and ingredient_concept_code='51742';
update ds_stage set NUMERATOR_VALUE=20 where drug_concept_code='5750875' and ingredient_concept_code='51742';
update ds_stage set NUMERATOR_VALUE=10 where drug_concept_code='5756211' and ingredient_concept_code='51742';
update ds_stage set NUMERATOR_VALUE=20 where drug_concept_code='5756228' and ingredient_concept_code='51742';
delete from ds_stage where ingredient_concept_code='3011' and amount_value='0';
--update dosages for inhalers
create table ds_inhaler as
with a as (
select DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT,packaging,
trim(regexp_replace(regexp_substr(PACKAGING,'(\d*)(\s*) dose'),'dose')) as num_coef,regexp_replace(regexp_substr(PACKAGING,'\d* (plaquette|cartouche|flacon|inhalateur)'),'plaquette|cartouche|flacon|inhalateur') as box_coef
 from ds_stage a join packaging b on drug_concept_code=cast(din_7 as varchar(20)) where packaging like 'dose%inhal%' or packaging like '%inhal%dose%')
select distinct drug_concept_code,ingredient_concept_code, box_coef as box_size,' ' as AMOUNT_VALUE,' ' as AMOUNT_UNIT,a.AMOUNT_VALUE*num_coef as NUMERATOR_VALUE,a.AMOUNT_UNIT as NUMERATOR_UNIT, num_coef as DENOMINATOR_VALUE, 'ACTUAT' as DENOMINATOR_UNIT
 from a where num_coef is not null;
 insert into ds_inhaler (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
 values ('3812112','4179','1','12000','mcg','120','ACTUAT');
 insert into ds_inhaler (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
 values ('3812112','30613','1','720','mcg','120','ACTUAT');
  insert into ds_inhaler (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
 values ('3814128','4179','1','12000','mcg','120','ACTUAT');
  insert into ds_inhaler (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
 values ('3814128','30613','1','720','mcg','120','ACTUAT'); 

merge into ds_stage a 
using ds_inhaler b
on (a.drug_concept_code=b.drug_concept_code and a.ingredient_concept_code=b.ingredient_concept_code)
when matched then update set
a.BOX_SIZE=b.BOX_SIZE,
a.AMOUNT_VALUE=null,
a.AMOUNT_UNIT=null,
a.NUMERATOR_VALUE=b.NUMERATOR_VALUE,
a.NUMERATOR_UNIT=b.NUMERATOR_UNIT,
a.DENOMINATOR_VALUE=b.DENOMINATOR_VALUE,
a.DENOMINATOR_UNIT=b.DENOMINATOR_UNIT
;
--manufacturers
create table dcs_manufacturer as 
(select distinct manufacturer as concept_name,'Supplier' as concept_class_id from drug);
update dcs_manufacturer
 set concept_name=ltrim(concept_name,' ');

--Parsing drug description extracting brand names 
create table brand_name as (select regexp_substr (drug_descr, '^([A-Z]+(\s)?-?/?[A-Z]+(\s)?[A-Z]?)+') as brand_name,drug_code from drug where drug_descr not like '%degré de dilution compris entre%' and regexp_substr (drug_descr, '^([A-Z]+(\s)?-?[A-Z]+)+') is not null) ;
UPDATE BRAND_NAME   SET BRAND_NAME = 'NP100 PREMATURES AP-HP' WHERE DRUG_CODE = '60208447';
UPDATE BRAND_NAME   SET BRAND_NAME = 'NP2 ENFANTS AP-HP' WHERE DRUG_CODE = '66809426';
UPDATE BRAND_NAME   SET BRAND_NAME = 'PO 12 2 POUR CENT' WHERE DRUG_CODE = '64593595';
update BRAND_NAME set BRAND_NAME ='HUMEXLIB' where brand_name like 'HUMEXLIB%';
update BRAND_NAME set BRAND_NAME ='HUMEX' where brand_name like 'HUMEX %';
update BRAND_NAME set BRAND_NAME ='CLARIX' where brand_name like 'CLARIX %';
update BRAND_NAME set BRAND_NAME ='ACTIVOX' where brand_name like 'ACTIVOX %';


update brand_name   set brand_name=rtrim(brand_name,' ');
 
 --Brand name = Ingredient (RxNorm)
delete brand_name where upper(brand_name) in (select upper(concept_name) from devv5.concept where concept_Class_id='Ingredient');
 --Brand name = Ingredient (BDPM translated)
delete brand_name where lower(brand_name) in (select lower(translation) from ingr_translation_all)
;
 --Brand name = Ingredient (BDPM original)
delete brand_name where lower(brand_name) in (select lower(CONCEPT_NAME) from ingr_translation_all); 
delete brand_name where brand_name in ('ARGENTUM COMPLEXE N','ESTERS ETHYLIQUES D','ACIDUM PHOSPHORICUM COMPLEXE N','POTASSIUM H','FUCUS COMPLEXE N','CREME AU CALENDULA','CRATAEGUS COMPLEXE N',
'BADIAGA COMPLEXE N','BERBERIS COMPLEXE N');
update brand_name set brand_name=regexp_replace(brand_name,'ADULTES|ENFANTS|NOURRISSONS') where upper(brand_name) like 'SUPPOSITOIRE%';


--list for drug_concept_stage
create table dcs_bn as (
select distinct brand_name as concept_name, 'Brand Name' as concept_class_id from brand_name 
where brand_name not in (select brand_name from BRAND_NAME_EXCEPTION-- previously created table with Brand names similar to ingredients
)
and drug_code not in (select drug_code from non_drug));


--list of Dose Form (translated before)
create table list as (
select distinct trim(translation) as concept_name ,'Dose Form' as concept_class_id,'1000000000' as concept_Code from FORM_TRANSLATION --manual table
union
--Brand Names
select distinct trim(concept_name),concept_class_id,'100000000000' from dcs_bn
union 
--manufacturers
select distinct trim(concept_name),concept_class_id,'100000000000' from dcs_manufacturer
);
delete from list where concept_name like 'Enteric Oral Capsule';
insert into list  values ('inert ingredients','Ingredient','100000000000');
 
--temporary sequence 
CREATE SEQUENCE new_vocc
  MINVALUE 1
  MAXVALUE 1000000
  START WITH 1
  INCREMENT BY 1
  CACHE 100;
  --put OMOP||numbers
update list
set concept_code='OMOP'||new_vocc.nextval;
;

--Fill drug_concept_stage
--Drug Product
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select SUBSTR( d.drug_descr,1, 240) ,'BDPM', 'Drug Product', '', cast (din_7 as varchar (200)), '', 'Drug',APPROVAL_DATE, TO_DATE ('20991231', 'yyyymmdd'), ''
from drug d join packaging p on p.drug_code = d.drug_code
where d.drug_code not in( select drug_code from non_drug)
and d.drug_code not in( select drug_code from pack_st_1)
;
--Device
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select SUBSTR( d.drug_descr,1, 240) ,'BDPM', 'Device', '', cast (din_7 as varchar (200)), '', 'Device', APPROVAL_DATE, TO_DATE ('20991231', 'yyyymmdd'), ''
from drug d join packaging p on p.drug_code = d.drug_code
where d.drug_code  in( select drug_code from non_drug)
;
--Brand Names and Dose forms and manufacturers
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct concept_name,'BDPM', concept_class_id, '', CONCEPT_CODE, '', 'Drug', TO_DATE ('19700101', 'yyyymmdd'), TO_DATE ('20991231', 'yyyymmdd'), ''
from list
;
-- units 
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct CONCEPT_CODE,'BDPM', 'Unit', '', CONCEPT_CODE, '', 'Drug', TO_DATE ('19700101', 'yyyymmdd'), TO_DATE ('20991231', 'yyyymmdd'), ''
from aut_unit_all_mapped
;
-- Pack_components 
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct SUBSTR(PACK_COMPONENT_NAME,1, 240) ,'BDPM', 'Drug Product', '', PACK_COMPONENT_CODE, '', 'Drug', TO_DATE ('19700101', 'yyyymmdd'), TO_DATE ('20991231', 'yyyymmdd'), ''
from PACK_CONT_1
;
--Packs
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct SUBSTR(PACK_NAME,1, 240) ,'BDPM', 'Drug Pack', '', CONCEPT_CODE, '', 'Drug', TO_DATE ('19700101', 'yyyymmdd'), TO_DATE ('20991231', 'yyyymmdd'), ''
from PACK_CONT_1
;

--Ingredients 
insert into drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct TRANSLATION ,'BDPM', 'Ingredient', '', concept_code, '', 'Drug', TO_DATE ('19700101', 'yyyymmdd'), TO_DATE ('20991231', 'yyyymmdd'), ''
from ingr_translation_all 
;
delete from drug_concept_stage where concept_code in ('89969','49487','24033','72310','31035','66548','16621','31035');
--standard concept definition, not sure if we need this
MERGE
INTO    drug_concept_stage dcs
USING   (
select concept_name, concept_code from drug_concept_stage WHERE concept_class_id NOT IN ('Brand Name', 'Dose Form', 'Unit', 'Ingredient', 'Supplier') 
) d ON (d.concept_code=dcs.concept_code)
WHEN MATCHED THEN UPDATE
    SET dcs.standard_concept = 'S'
;
--standard concept definition, not sure if we need this
MERGE
INTO    drug_concept_stage dcs
USING   (
select concept_name, MIN(concept_code) m from drug_concept_stage WHERE concept_class_id='Ingredient' group by concept_name having count(concept_name) > 1
) d ON (d.m=dcs.concept_code)
WHEN MATCHED THEN UPDATE
    SET dcs.standard_concept = 'S'
;
UPDATE drug_concept_stage
SET standard_concept='S' WHERE concept_class_id='Ingredient' 
and concept_name not in (select concept_name from drug_concept_stage WHERE concept_class_id='Ingredient' group by concept_name having count(concept_name) > 1)
;
--drug with no din7
INSERT INTO DRUG_CONCEPT_STAGE(  CONCEPT_NAME,  VOCABULARY_ID,  CONCEPT_CLASS_ID,  STANDARD_CONCEPT,  CONCEPT_CODE,  POSSIBLE_EXCIPIENT,  DOMAIN_ID,  VALID_START_DATE,  VALID_END_DATE,  INVALID_REASON)
VALUES(  'VACCIN RABIQUE INACTIVE MERIEUX, poudre et solvant pour suspension injectable. Vaccin rabique préparé sur cellules diploïdes humaines',  'BDPM',  'Drug Product',  'S',  '60253264',  NULL, 'Drug',  TO_TIMESTAMP('1996-01-07 00:06:00.000','YYYY-MM-DD HH24:MI:SS.FF'), TO_TIMESTAMP('2099-12-31 00:00:00.000','YYYY-MM-DD HH24:MI:SS.FF'),  NULL);
commit
;
--Drug to Ingredients
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select distinct drug_concept_code, ingredient_concept_code from ds_stage d
where d.drug_concept_code not in (select drug_code from non_drug)
and d.drug_concept_code not in (select PACK_COMPONENT_CODE from PACK_CONT_1)
;
--Homeop. drug to Ingredients
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select distinct din_7,form_code from packaging join homeop_drug using(drug_code);

;
--Pack Component to Ingredient
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select distinct drug_concept_code, ingredient_concept_code from ds_stage d
where d.drug_concept_code  in (select PACK_COMPONENT_CODE from PACK_CONT_1)
;
insert into internal_relationship_stage (concept_code_1)
select concept_code from drug_concept_stage where concept_name like 'INERT INGREDIENT Metered Dose Inhaler';
update internal_relationship_stage set concept_code_2= (select concept_code from drug_concept_stage where concept_name like 'inert ingredients')
where concept_code_1 in (select concept_code from drug_concept_stage where concept_name like 'INERT INGREDIENT Metered Dose Inhaler') and concept_code_2 is null;
--Drug to Brand Name
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select distinct din_7, concept_code from brand_name b join drug_concept_stage d on lower ( brand_name) = lower ( concept_name ) and d.concept_class_id = 'Brand Name'
join packaging p on p.drug_code = b.drug_code
where b.drug_code not in (select drug_code from non_drug)
;
--Drug to Supplier 
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select distinct din_7, concept_code from drug b join drug_concept_stage  d on  lower ( manufacturer) = ' '||lower ( concept_name ) and d.concept_class_id = 'Supplier'
join packaging p on p.drug_code = b.drug_code
where b.drug_code not in (select drug_code from non_drug)
;
--Drug to Dose Form
--separately for packs and drugs 
--for drugs, excluding packs and non_drugs
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select distinct din_7, concept_code from drug d
join FORM_TRANSLATION on regexp_replace(form||' '||route,'  ',' ') = FORM_ROUTE
join drug_concept_stage on TRANSLATION = concept_name and  concept_class_id = 'Dose Form'
join packaging p on p.drug_code = d.drug_code
where d.drug_code not in (select drug_code from non_drug)
and d.drug_code not in (select CONCEPT_CODE from PACK_CONT_1)
;
-- Drug to Dose Form for Pack components 
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select PACK_COMPONENT_CODE,concept_code
from PF_FROM_PACK_COMP_LIST pf 
JOIN drug_concept_stage dcs on PACK_FORM=concept_name;

--manual update of CODE_INGRED_TO_INGRED
delete from CODE_INGRED_TO_INGRED where concept_code_1 in (select form_code from non_drug);
--Ingredient to Ingredient
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select * from CODE_INGRED_TO_INGRED;

--manualy defined same ingredients
insert into internal_relationship_stage (CONCEPT_CODE_1,CONCEPT_CODE_2)
select distinct b.concept_code concept_code_1,a.concept_code concept_Code_2 from drug_concept_stage  a join drug_concept_stage b on a.concept_name=b.concept_name
where a.concept_name in (
select concept_name from drug_concept_stage group by concept_name having count(8)>1) 
and a.concept_class_id='Ingredient' and a.standard_concept='S' and b.standard_concept is null
and b.concept_code  not in (select cast (CONCEPT_CODE_2 as varchar (200)) from CODE_INGRED_TO_INGRED)
;

--drug doesn't have packaging
INSERT INTO INTERNAL_RELATIONSHIP_STAGE (  CONCEPT_CODE_1,  CONCEPT_CODE_2)
SELECT  '60253264',  concept_code from drug_concept_stage where concept_name='Injectable Solution';
INSERT INTO INTERNAL_RELATIONSHIP_STAGE (  CONCEPT_CODE_1,  CONCEPT_CODE_2)
SELECT  '60253264',  concept_code from drug_concept_stage where concept_name='VACCIN RABIQUE INACTIVE MERIEUX';
INSERT INTO INTERNAL_RELATIONSHIP_STAGE (  CONCEPT_CODE_1,  CONCEPT_CODE_2)
SELECT  '60253264',  concept_code from drug_concept_stage where concept_name='SANOFI PASTEUR';
--Forms mapping
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code, 'BDPM', concept_id, PRECEDENCE, '' 
from AUT_FORM_ALL_MAPPED --manual table
join drug_concept_stage d on lower (d.concept_name) = lower (translation) 
;
--Brand names
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code, 'BDPM', concept_id, PRECEDENCE, '' 
from AUT_BN_MAPPED_ALL a --manual table
join drug_concept_stage d on lower (d.concept_name) = lower (a.BRAND_NAME )
;
--Units
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code, 'BDPM', CONCEPT_ID_2, PRECEDENCE, CONVERSION_FACTOR
from AUT_UNIT_ALL_MAPPED  --manual table
;
--Ingredients 
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code, 'BDPM', CONCEPT_ID, PRECEDENCE, '' 
from AUT_INGR_MAPPED_ALL  --manual table
;
drop table ingr_map_update;
create table ingr_map_update as 
with a as
(SELECT a.concept_code,a.concept_name,VOCABULARY_ID_1,precedence,rank() over (partition by a.concept_code order by c2.concept_id) as rank,
c2.concept_id,c2.standard_concept from
      drug_concept_stage a 
        join  relationship_to_concept rc on a.concept_code=rc.concept_code_1
        JOIN concept c1 ON c1.concept_id = concept_id_2
        join concept c2 on trim(regexp_replace(lower(c1.concept_name),'for homeopathic preparations|tartrate|phosphate'))=trim(regexp_replace(lower(c2.concept_name),'for homeopathic preparations'))
         and c2.standard_concept='S' and c2.concept_class_id='Ingredient'
      WHERE c1.invalid_reason IS NOT NULL)
select CONCEPT_CODE,CONCEPT_NAME,VOCABULARY_ID_1,PRECEDENCE,CONCEPT_ID,STANDARD_CONCEPT from a where concept_code in (select concept_code from a group by concept_code having count(concept_code)=1)
union
select CONCEPT_CODE,CONCEPT_NAME,VOCABULARY_ID_1,rank,CONCEPT_ID,STANDARD_CONCEPT from a where concept_code in (select concept_code from a group by concept_code having count(concept_code)!=1)
;
delete from relationship_to_concept where (concept_code_1,concept_id_2) in (
SELECT concept_code_1, concept_id_2
      FROM relationship_to_concept
        JOIN drug_concept_stage s ON s.concept_code = concept_code_1
        JOIN concept c ON c.concept_id = concept_id_2
      WHERE c.standard_concept IS NULL  AND   s.concept_class_id = 'Ingredient');
     
insert into relationship_to_concept select CONCEPT_CODE,VOCABULARY_ID_1,CONCEPT_ID,PRECEDENCE,''
 from ingr_map_update;
--add RxNorm Extension
create table RxE_Ing_st_0 as
select a.concept_code as concept_code_1,a.concept_name as concept_name_1,
c.concept_id, c.concept_name
 from drug_concept_stage a 
join devv5.concept c on lower (a.concept_name )= lower (c.concept_name)
where a.concept_class_id = 'Ingredient' 
and a.concept_code not in (select concept_code_1 from relationship_to_concept)
and c.vocabulary_id ='RxNorm Extension' and c.concept_class_id = 'Ingredient' and c.invalid_reason is null
;
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code_1, 'BDPM', CONCEPT_ID, 1, '' 
from RxE_Ing_st_0  -- RxNormExtension name equivalence
;
--one ingredient found manualy
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
values (538, 'BDPM', 21014151, 1, '') 
;
insert into relationship_to_concept 
select concept_code,'BDPM',19127890,1,'' from drug_concept_stage where concept_name like 'inert ingredients';
--need to add manufacturer lately

--manufacturer
create table RxE_Man_st_0 as
select a.concept_code as concept_code_1,a.concept_name as concept_name_1,
c.concept_id, c.concept_name concept, rank() over (partition by a.concept_code order by c.concept_id) as precedence
 from drug_concept_stage a 
join devv5.concept c on 
regexp_replace(lower(a.concept_name),' ltd| plc| uk| \(.*\)| pharmaceuticals| pharma| gmbh| laboratories| ab| international| france| imaging')=
regexp_replace(lower(c.concept_name),' ltd| plc| uk| \(.*\)| pharmaceuticals| pharma| gmbh| laboratories| ab| international| france| imaging')
where a.concept_class_id = 'Supplier' 
and a.concept_code not in (select concept_code_1 from relationship_to_concept)
and c.vocabulary_id like 'RxNorm%' and c.concept_class_id=  'Supplier' and c.invalid_reason is null
;

insert into relationship_to_concept 
select concept_code,'BDPM', concept_id, precedence,''
from aut_supp_mapped a join drug_concept_stage b using(concept_name);--suppliers found manually


insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code_1, 'BDPM', CONCEPT_ID, precedence, '' 
from RxE_Man_st_0  -- RxNormExtension name equivalence
;
--Brands from RxE

create table RxE_BR_n_st_0 as
select a.concept_code as concept_code_1,a.concept_name as concept_name_1,
c.concept_id, c.concept_name
 from drug_concept_stage a 
join devv5.concept c on lower (a.concept_name )= lower (c.concept_name)
where a.concept_class_id = 'Brand Name' 
and a.concept_code not in (select concept_code_1 from relationship_to_concept)
and c.vocabulary_id like 'RxNorm%' and c.concept_class_id=  'Brand Name' and c.invalid_reason is null
;
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code_1, 'BDPM', CONCEPT_ID, 1, '' 
from RxE_BR_n_st_0  -- RxNormExtension name equivalence
;

DELETE FROM relationship_to_concept WHERE rowid  IN(
  SELECT MAX(rowid) FROM relationship_to_concept GROUP BY concept_code_1,precedence having count (1) >1);
commit;  
DELETE FROM internal_relationship_stage WHERE rowid  IN(
  SELECT MAX(rowid) FROM internal_relationship_stage GROUP BY concept_code_1,concept_code_2 having count (1) >1);
  commit;
update ds_stage set AMOUNT_VALUE=NUMERATOR_VALUE,AMOUNT_UNIT=NUMERATOR_UNIT, NUMERATOR_VALUE=null,NUMERATOR_UNIT=null,DENOMINATOR_VALUE=null,DENOMINATOR_UNIT=null
where (INGREDIENT_CONCEPT_CODE='16736' and drug_concept_code in (select concept_code from drug_concept_stage where 
CONCEPT_NAME in ('JINARC 30 mg, comprimé, JINARC 90 mg, comprimé comprimé de 90 mg','JINARC 15 mg, comprimé, JINARC 45 mg, comprimé comprimé de 45 mg','JINARC 30 mg, comprimé, JINARC 60 mg, comprimé comprimé de 60 mg')))
or (INGREDIENT_CONCEPT_CODE='41238' and drug_concept_code in (select concept_code from drug_concept_stage where 
CONCEPT_NAME in ('OTEZLA 10 mg, comprimé pelliculé, OTEZLA 20 mg, comprimé pelliculé, OTEZLA 30 mg, comprimé pelliculé, comprimé 30 mg','OTEZLA 10 mg, comprimé pelliculé, OTEZLA 20 mg, comprimé pelliculé, OTEZLA 30 mg, comprimé pelliculé, comprimé 20 mg')));



--delete non-relevant brand names
delete from relationship_to_concept where concept_code_1 in (
select concept_code from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
where a.concept_class_id= 'Brand Name' and b.concept_code_1 is null);
--update ds_stage after relationship_to concept found identical ingredients
delete from drug_concept_stage where concept_code in (select concept_code from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
where a.concept_class_id= 'Brand Name' and b.concept_code_1 is null);
drop table ds_sum;
create table ds_sum as 
with a  as (
SELECT distinct ds.drug_concept_code,ds.ingredient_concept_code,ds.box_size, ds.AMOUNT_VALUE,ds.AMOUNT_UNIT,ds.NUMERATOR_VALUE,ds.NUMERATOR_UNIT,ds.DENOMINATOR_VALUE,ds.DENOMINATOR_UNIT,rc.concept_id_2
      FROM ds_stage ds
        JOIN ds_stage ds2 ON ds.drug_concept_code = ds2.drug_concept_code AND ds.ingredient_concept_code != ds2.ingredient_concept_code
        JOIN relationship_to_concept rc ON ds.ingredient_concept_code = rc.concept_code_1
        JOIN relationship_to_concept rc2 ON ds2.ingredient_concept_code = rc2.concept_code_1
            WHERE rc.concept_id_2 = rc2.concept_id_2
            )
 select distinct DRUG_CONCEPT_CODE,max(INGREDIENT_CONCEPT_CODE)over (partition by DRUG_CONCEPT_CODE,concept_id_2) as ingredient_concept_code,box_size,
 sum(AMOUNT_VALUE) over (partition by DRUG_CONCEPT_CODE)as AMOUNT_VALUE,AMOUNT_UNIT,sum(NUMERATOR_VALUE) over (partition by DRUG_CONCEPT_CODE,concept_id_2)as NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT
 from a
 union
 select DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,box_size, null as AMOUNT_VALUE, '' as AMOUNT_UNIT, null as NUMERATOR_VALUE, '' as NUMERATOR_UNIT, null as DENOMINATOR_VALUE, '' as DENOMINATOR_UNIT 
 from a where (drug_concept_code,ingredient_concept_code) not in (select drug_concept_code, max(ingredient_concept_code) from a group by drug_concept_code);
delete from ds_stage where  (drug_concept_code,ingredient_concept_code) in (select drug_concept_code,ingredient_concept_code from ds_sum);
INSERT INTO DS_STAGE SELECT * FROM DS_SUM where nvl(AMOUNT_VALUE,NUMERATOR_VALUE) is not null;
--update irs after relationship_to concept found identical ingredients
delete from internal_relationship_stage where (concept_code_1,concept_code_2) in (
SELECT concept_code_1,concept_code_2
      FROM (SELECT DISTINCT concept_code_1,concept_code_2, COUNT(concept_code_2) OVER (PARTITION BY concept_code_1) AS irs_cnt
            FROM internal_relationship_stage
              JOIN drug_concept_stage ON concept_code = concept_code_2 AND concept_class_id = 'Ingredient') irs
        JOIN (SELECT DISTINCT drug_concept_code, COUNT(ingredient_concept_code) OVER (PARTITION BY drug_concept_code) AS ds_cnt
              FROM ds_stage) ds
          ON drug_concept_code = concept_code_1   AND irs_cnt != ds_cnt)
and  (concept_code_1,concept_code_2) not in (select drug_concept_code,ingredient_concept_code from ds_stage)        
;

--update IRS -remove suppliers where Dose form or dosage doesn't exist
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE (concept_code_1,concept_code_2) IN (
SELECT distinct concept_code_1,concept_code_2
                             FROM internal_relationship_stage
                               JOIN drug_concept_stage a ON concept_code_2 = a.concept_code  AND a.concept_class_id = 'Supplier'
                               JOIN drug_concept_stage b ON concept_code_1 = b.concept_code  AND b.concept_class_id in ('Drug Product','Drug Pack')
      where  (b.concept_code NOT IN (SELECT concept_code_1
                                  FROM internal_relationship_stage
                                    JOIN drug_concept_stage   ON concept_code_2 = concept_code  AND concept_class_id = 'Dose Form') OR b.concept_code NOT IN (SELECT drug_concept_code FROM ds_stage)))
;  
--manualy define packs amounts
create table p_c_amount as (
select distinct a.pack_component_code,a.PACKAGING,a.concept_code,b.drug_form,cast('99' as integer)as amount,cast('99' as integer) as box_size from PACK_CONT_1 a join PACK_COMP_LIST b on a.PACK_COMPONENT_CODE=b.PACK_COMPONENT_CODE);
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 2170290 AND   DRUG_FORM = 'poudre';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 2170290 AND   DRUG_FORM = 'solution';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 2219116 AND   DRUG_FORM = 'solution 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 2219116 AND   DRUG_FORM = 'solution 2';
UPDATE P_C_AMOUNT   SET AMOUNT = '14' WHERE CONCEPT_CODE = 2733209 AND   DRUG_FORM = 'comprimé à 1 mg';
UPDATE P_C_AMOUNT   SET AMOUNT = '11' WHERE CONCEPT_CODE = 2733209 AND   DRUG_FORM = '"comprimé à 0,5 mg"';
UPDATE P_C_AMOUNT   SET AMOUNT = '12' WHERE CONCEPT_CODE = 2742556 AND   DRUG_FORM = 'comprimé jour';
UPDATE P_C_AMOUNT   SET AMOUNT = '4' WHERE CONCEPT_CODE = 2742556 AND   DRUG_FORM = 'comprimé nuit';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 2794926 AND   DRUG_FORM = 'solution de 63 microgrammes';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 2794926 AND   DRUG_FORM = 'solution de 94 microgrammes';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3001051 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '84' WHERE CONCEPT_CODE = 3001051 AND   DRUG_FORM = 'comprimé rose';
UPDATE P_C_AMOUNT   SET AMOUNT = '20' WHERE CONCEPT_CODE = 3048384 AND   DRUG_FORM = 'poche A';
UPDATE P_C_AMOUNT   SET AMOUNT = '20' WHERE CONCEPT_CODE = 3048384 AND   DRUG_FORM = 'poche B';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 3209686 AND   DRUG_FORM = 'solvant';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 3209686 AND   DRUG_FORM = 'poudre';
UPDATE P_C_AMOUNT   SET AMOUNT = '12' WHERE CONCEPT_CODE = 3254882 AND   DRUG_FORM = 'comprimé bleu';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 3254882 AND   DRUG_FORM = 'comprimé rouge';
UPDATE P_C_AMOUNT   SET AMOUNT = '10' WHERE CONCEPT_CODE = 3254882 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3254913 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3254913 AND   DRUG_FORM = 'comprimé orange';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3254913 AND   DRUG_FORM = 'comprimé orange pâle';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3254936 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3254936 AND   DRUG_FORM = 'comprimé orange';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3254936 AND   DRUG_FORM = 'comprimé orange pâle';
UPDATE P_C_AMOUNT   SET AMOUNT = '4' WHERE CONCEPT_CODE = 3263651 AND   DRUG_FORM = 'comprimé';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 3263651 AND   DRUG_FORM = 'solution';
UPDATE P_C_AMOUNT   SET AMOUNT = '4' WHERE CONCEPT_CODE = 3269642 AND   DRUG_FORM = 'comprimé';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 3269642 AND   DRUG_FORM = 'solution';
UPDATE P_C_AMOUNT   SET AMOUNT = '48' WHERE CONCEPT_CODE = 3272443 AND   DRUG_FORM = 'gélule bleue';
UPDATE P_C_AMOUNT   SET AMOUNT = '48' WHERE CONCEPT_CODE = 3272443 AND   DRUG_FORM = 'gélule rouge gastro-résistante';
UPDATE P_C_AMOUNT   SET AMOUNT = '24' WHERE CONCEPT_CODE = 3273129 AND   DRUG_FORM = 'gélule bleue';
UPDATE P_C_AMOUNT   SET AMOUNT = '24' WHERE CONCEPT_CODE = 3273129 AND   DRUG_FORM = 'gélule rouge gastro-résistante';
UPDATE P_C_AMOUNT   SET AMOUNT = '20' WHERE CONCEPT_CODE = 3292546 AND   DRUG_FORM = 'solution en ampoule B';
UPDATE P_C_AMOUNT   SET AMOUNT = '20' WHERE CONCEPT_CODE = 3292546 AND   DRUG_FORM = 'solution en ampoule A';
UPDATE P_C_AMOUNT   SET AMOUNT = '48' WHERE CONCEPT_CODE = 3295438 AND   DRUG_FORM = 'gélule bleue gastro-soluble';
UPDATE P_C_AMOUNT   SET AMOUNT = '48' WHERE CONCEPT_CODE = 3295438 AND   DRUG_FORM = 'gélule rouge gastro-résistante';
UPDATE P_C_AMOUNT   SET AMOUNT = '24' WHERE CONCEPT_CODE = 3299548 AND   DRUG_FORM = 'gélule bleue gastro-soluble';
UPDATE P_C_AMOUNT   SET AMOUNT = '24' WHERE CONCEPT_CODE = 3299548 AND   DRUG_FORM = 'gélule rouge gastro-résistante';
UPDATE P_C_AMOUNT   SET AMOUNT = '5' WHERE CONCEPT_CODE = 3305065 AND   DRUG_FORM = 'comprimé marron foncé';
UPDATE P_C_AMOUNT   SET AMOUNT = '10' WHERE CONCEPT_CODE = 3305065 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 3305065 AND   DRUG_FORM = 'comprimé beige';
UPDATE P_C_AMOUNT   SET AMOUNT = '5' WHERE CONCEPT_CODE = 3305071 AND   DRUG_FORM = 'comprimé marron foncé';
UPDATE P_C_AMOUNT   SET AMOUNT = '10' WHERE CONCEPT_CODE = 3305071 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 3305071 AND   DRUG_FORM = 'comprimé beige';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 3305088 AND   DRUG_FORM = 'comprimé beige';
UPDATE P_C_AMOUNT   SET AMOUNT = '10' WHERE CONCEPT_CODE = 3305088 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '5' WHERE CONCEPT_CODE = 3305088 AND   DRUG_FORM = 'comprimé marron foncé';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 3305094 AND   DRUG_FORM = 'comprimé beige';
UPDATE P_C_AMOUNT   SET AMOUNT = '10' WHERE CONCEPT_CODE = 3305094 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '5' WHERE CONCEPT_CODE = 3305094 AND   DRUG_FORM = 'comprimé marron foncé';
UPDATE P_C_AMOUNT   SET AMOUNT = '11' WHERE CONCEPT_CODE = 3344355 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '10' WHERE CONCEPT_CODE = 3344355 AND   DRUG_FORM = 'comprimé bleu';
UPDATE P_C_AMOUNT   SET AMOUNT = '14' WHERE CONCEPT_CODE = 3357300 AND   DRUG_FORM = 'solution A';
UPDATE P_C_AMOUNT   SET AMOUNT = '14' WHERE CONCEPT_CODE = 3357300 AND   DRUG_FORM = 'solution B';
UPDATE P_C_AMOUNT   SET AMOUNT = '11' WHERE CONCEPT_CODE = 3360437 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '10' WHERE CONCEPT_CODE = 3360437 AND   DRUG_FORM = 'comprimé rose';
UPDATE P_C_AMOUNT   SET AMOUNT = '3' WHERE CONCEPT_CODE = 3386477 AND   DRUG_FORM = 'comprimé bleu';
UPDATE P_C_AMOUNT   SET AMOUNT = '3' WHERE CONCEPT_CODE = 3386477 AND   DRUG_FORM = 'comprimé rose';
UPDATE P_C_AMOUNT   SET AMOUNT = '14' WHERE CONCEPT_CODE = 3438524 AND   DRUG_FORM = 'comprimé jaune';
UPDATE P_C_AMOUNT   SET AMOUNT = '14' WHERE CONCEPT_CODE = 3438524 AND   DRUG_FORM = 'comprimé rose';
UPDATE P_C_AMOUNT   SET AMOUNT = '4' WHERE CONCEPT_CODE = 3447463 AND   DRUG_FORM = 'gélule';
UPDATE P_C_AMOUNT   SET AMOUNT = '12' WHERE CONCEPT_CODE = 3447463 AND   DRUG_FORM = 'comprimé';
UPDATE P_C_AMOUNT   SET AMOUNT = '24' WHERE CONCEPT_CODE = 3490370 AND   DRUG_FORM = 'gélule orange';
UPDATE P_C_AMOUNT   SET AMOUNT = '24' WHERE CONCEPT_CODE = 3490370 AND   DRUG_FORM = 'gélule verte';
UPDATE P_C_AMOUNT   SET AMOUNT = '24' WHERE CONCEPT_CODE = 3490387 AND   DRUG_FORM = 'gélule orange';
UPDATE P_C_AMOUNT   SET AMOUNT = '24' WHERE CONCEPT_CODE = 3490387 AND   DRUG_FORM = 'gélule verte';
UPDATE P_C_AMOUNT   SET AMOUNT = '14' WHERE CONCEPT_CODE = 3526435 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '14' WHERE CONCEPT_CODE = 3526435 AND   DRUG_FORM = 'comprimé gris';
UPDATE P_C_AMOUNT   SET AMOUNT = '4' WHERE CONCEPT_CODE = 3542871 AND   DRUG_FORM = 'solution 2 : glucose avec calcium';
UPDATE P_C_AMOUNT   SET AMOUNT = '4' WHERE CONCEPT_CODE = 3542871 AND   DRUG_FORM = 'solution 1 : acides aminés avec électrolytes';
UPDATE P_C_AMOUNT   SET AMOUNT = '4' WHERE CONCEPT_CODE = 3542919 AND   DRUG_FORM = 'solution d''acides aminés';
UPDATE P_C_AMOUNT   SET AMOUNT = '4' WHERE CONCEPT_CODE = 3542919 AND   DRUG_FORM = 'solution de glucose';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 3549583 AND   DRUG_FORM = 'suspension';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 3549583 AND   DRUG_FORM = 'poudre';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 3552473 AND   DRUG_FORM = 'poudre';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 3552473 AND   DRUG_FORM = 'suspension';
UPDATE P_C_AMOUNT   SET AMOUNT = '8' WHERE CONCEPT_CODE = 3563583 AND   DRUG_FORM = 'solution 2 : glucose avec calcium';
UPDATE P_C_AMOUNT   SET AMOUNT = '8' WHERE CONCEPT_CODE = 3563583 AND   DRUG_FORM = 'solution 1 : acides aminés avec électrolytes';
UPDATE P_C_AMOUNT   SET AMOUNT = '8' WHERE CONCEPT_CODE = 3563608 AND   DRUG_FORM = 'solution 1 : acides aminés avec électrolytes';
UPDATE P_C_AMOUNT   SET AMOUNT = '8' WHERE CONCEPT_CODE = 3563608 AND   DRUG_FORM = 'solution 2 : glucose avec calcium';
UPDATE P_C_AMOUNT   SET AMOUNT = '8' WHERE CONCEPT_CODE = 3563695 AND   DRUG_FORM = 'solution d''acides aminés';
UPDATE P_C_AMOUNT   SET AMOUNT = '8' WHERE CONCEPT_CODE = 3563695 AND   DRUG_FORM = 'solution de glucose';
UPDATE P_C_AMOUNT   SET AMOUNT = '14' WHERE CONCEPT_CODE = 3575304 AND   DRUG_FORM = 'sachet 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '14' WHERE CONCEPT_CODE = 3575304 AND   DRUG_FORM = 'sachet 2';
UPDATE P_C_AMOUNT   SET AMOUNT = '4' WHERE CONCEPT_CODE = 3575327 AND   DRUG_FORM = 'comprimé bleu';
UPDATE P_C_AMOUNT   SET AMOUNT = '12' WHERE CONCEPT_CODE = 3575327 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '16' WHERE CONCEPT_CODE = 3583947 AND   DRUG_FORM = 'comprimé beige';
UPDATE P_C_AMOUNT   SET AMOUNT = '12' WHERE CONCEPT_CODE = 3583947 AND   DRUG_FORM = 'comprimé bleu';
UPDATE P_C_AMOUNT   SET AMOUNT = '10' WHERE CONCEPT_CODE = 3584622 AND   DRUG_FORM = 'comprimé rose';
UPDATE P_C_AMOUNT   SET AMOUNT = '14' WHERE CONCEPT_CODE = 3584622 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '16' WHERE CONCEPT_CODE = 3584792 AND   DRUG_FORM = 'comprimé rouge';
UPDATE P_C_AMOUNT   SET AMOUNT = '12' WHERE CONCEPT_CODE = 3584792 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3589938 AND   DRUG_FORM = 'comprimé bleu ciel';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3589938 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3589938 AND   DRUG_FORM = 'comprimé bleu foncé';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3589944 AND   DRUG_FORM = 'comprimé bleu ciel';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3589944 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3589944 AND   DRUG_FORM = 'comprimé bleu foncé';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3589950 AND   DRUG_FORM = 'comprimé bleu foncé';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3589950 AND   DRUG_FORM = 'comprimé bleu ciel';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3589950 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3589967 AND   DRUG_FORM = 'comprimé bleu foncé';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3589967 AND   DRUG_FORM = 'comprimé bleu ciel';
UPDATE P_C_AMOUNT   SET AMOUNT = '7' WHERE CONCEPT_CODE = 3589967 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 3603791 AND   DRUG_FORM = 'poudre';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 3603791 AND   DRUG_FORM = 'solution';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 3635118 AND   DRUG_FORM = 'gélule blanche';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 3635118 AND   DRUG_FORM = 'gélule blanche et rose';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 3687434 AND   DRUG_FORM = 'poudre';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 3687434 AND   DRUG_FORM = 'suspension';
UPDATE P_C_AMOUNT   SET AMOUNT = '3' WHERE CONCEPT_CODE = 3689516 AND   DRUG_FORM = 'comprimé 300 IR';
UPDATE P_C_AMOUNT   SET AMOUNT = '28' WHERE CONCEPT_CODE = 3689516 AND   DRUG_FORM = 'comprimé 100 IR';
UPDATE P_C_AMOUNT   SET AMOUNT = '5' WHERE CONCEPT_CODE = 3715811 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '10' WHERE CONCEPT_CODE = 3715811 AND   DRUG_FORM = 'comprimé vert';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 3715811 AND   DRUG_FORM = 'comprimé beige';
UPDATE P_C_AMOUNT   SET AMOUNT = '5' WHERE CONCEPT_CODE = 3715828 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '10' WHERE CONCEPT_CODE = 3715828 AND   DRUG_FORM = 'comprimé vert';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 3715828 AND   DRUG_FORM = 'comprimé beige';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 3759027 AND   DRUG_FORM = 'solution à 22 microgrammes';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 3759027 AND   DRUG_FORM = '"solution à 8,8 microgrammes"';
UPDATE P_C_AMOUNT   SET AMOUNT = '10' WHERE CONCEPT_CODE = 3770000 AND   DRUG_FORM = 'comprimé jaune';
UPDATE P_C_AMOUNT   SET AMOUNT = '5' WHERE CONCEPT_CODE = 3770000 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 3770000 AND   DRUG_FORM = 'comprimé brique';
UPDATE P_C_AMOUNT   SET AMOUNT = '11' WHERE CONCEPT_CODE = 3771809 AND   DRUG_FORM = 'comprimé à 1 mg';
UPDATE P_C_AMOUNT   SET AMOUNT = '14' WHERE CONCEPT_CODE = 3771809 AND   DRUG_FORM = '"comprimé à 0,5 mg"';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 3788164 AND   DRUG_FORM = 'poudre du sachet B';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 3788164 AND   DRUG_FORM = 'poudre du sachet A';
UPDATE P_C_AMOUNT   SET AMOUNT = '24' WHERE CONCEPT_CODE = 3813057 AND   DRUG_FORM = 'granulés';
UPDATE P_C_AMOUNT   SET AMOUNT = '4' WHERE CONCEPT_CODE = 3813057 AND   DRUG_FORM = 'comprimé';
UPDATE P_C_AMOUNT   SET AMOUNT = '72' WHERE CONCEPT_CODE = 3828455 AND   DRUG_FORM = 'granulés';
UPDATE P_C_AMOUNT   SET AMOUNT = '12' WHERE CONCEPT_CODE = 3828455 AND   DRUG_FORM = 'comprimé';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 3909484 AND   DRUG_FORM = 'comprimé rouge foncé';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 3909484 AND   DRUG_FORM = 'comprimé jaune foncé';
UPDATE P_C_AMOUNT   SET AMOUNT = '17' WHERE CONCEPT_CODE = 3909484 AND   DRUG_FORM = 'comprimé jaune clair';
UPDATE P_C_AMOUNT   SET AMOUNT = '5' WHERE CONCEPT_CODE = 3909484 AND   DRUG_FORM = 'comprimé rouge';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 3909490 AND   DRUG_FORM = 'comprimé rouge foncé';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 3909490 AND   DRUG_FORM = 'comprimé jaune foncé';
UPDATE P_C_AMOUNT   SET AMOUNT = '17' WHERE CONCEPT_CODE = 3909490 AND   DRUG_FORM = 'comprimé jaune clair';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 3909490 AND   DRUG_FORM = 'comprimé rouge';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 4166252 AND   DRUG_FORM = 'compartiment de la solution de glucose';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 4166252 AND   DRUG_FORM = 'compartiment de l''émulsion lipidique';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 4166252 AND   DRUG_FORM = 'compartiment des acides aminés';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5500089 AND   DRUG_FORM = 'composant 2';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5500089 AND   DRUG_FORM = 'composant 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5500091 AND   DRUG_FORM = 'composant 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5500091 AND   DRUG_FORM = 'composant 2';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5500092 AND   DRUG_FORM = 'composant 2';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5500092 AND   DRUG_FORM = 'composant 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 5611085 AND   DRUG_FORM = 'solvant (flacon 2)';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 5611085 AND   DRUG_FORM = 'poudre (flacon 3)';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 5611085 AND   DRUG_FORM = 'solvant (flacon 4)';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 5611085 AND   DRUG_FORM = 'poudre (flacon 1)';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 5611091 AND   DRUG_FORM = 'poudre (flacon 1)';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 5611091 AND   DRUG_FORM = 'solvant (flacon 2)';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 5611091 AND   DRUG_FORM = 'solvant (flacon 4)';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 5611091 AND   DRUG_FORM = 'poudre (flacon 3)';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 5611116 AND   DRUG_FORM = 'solvant (flacon 4)';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 5611116 AND   DRUG_FORM = 'poudre (flacon 3)';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 5611116 AND   DRUG_FORM = 'solvant (flacon 2)';
UPDATE P_C_AMOUNT   SET AMOUNT = '2' WHERE CONCEPT_CODE = 5611116 AND   DRUG_FORM = 'poudre (flacon 1)';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5620894 AND   DRUG_FORM = 'solution de reconstitution de la poudre 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5620894 AND   DRUG_FORM = 'poudre 2';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5620894 AND   DRUG_FORM = 'poudre 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5620902 AND   DRUG_FORM = 'poudre 2';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5620902 AND   DRUG_FORM = 'solution de reconstitution de la poudre 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5620902 AND   DRUG_FORM = 'poudre 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5620925 AND   DRUG_FORM = 'poudre 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5620925 AND   DRUG_FORM = 'poudre 2';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5620925 AND   DRUG_FORM = 'solution de reconstitution de la poudre 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5645167 AND   DRUG_FORM = 'poudre du composant 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5645167 AND   DRUG_FORM = 'poudre du composant 2';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5650932 AND   DRUG_FORM = 'solution 2';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5650932 AND   DRUG_FORM = 'solution 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5650949 AND   DRUG_FORM = 'solution 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5650949 AND   DRUG_FORM = 'solution 2';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5731866 AND   DRUG_FORM = 'gélule transparente';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5754637 AND   DRUG_FORM = 'solution 2';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5754637 AND   DRUG_FORM = 'solution 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5754643 AND   DRUG_FORM = 'solution 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5754643 AND   DRUG_FORM = 'solution 2';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5754666 AND   DRUG_FORM = 'solution 2';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5754666 AND   DRUG_FORM = 'solution 1';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5755766 AND   DRUG_FORM = 'solution de protéines pour colle';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5755766 AND   DRUG_FORM = 'solution de thrombine';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5755772 AND   DRUG_FORM = 'solution de thrombine';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5755772 AND   DRUG_FORM = 'solution de protéines pour colle';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5755789 AND   DRUG_FORM = 'solution de protéines pour colle';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 5755789 AND   DRUG_FORM = 'solution de thrombine';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 2794903 AND   DRUG_FORM = 'solution de 94 microgrammes';
UPDATE P_C_AMOUNT   SET AMOUNT = '1' WHERE CONCEPT_CODE = 2794903 AND   DRUG_FORM = 'solution de 63 microgrammes';
UPDATE P_C_AMOUNT   SET AMOUNT = '4' WHERE CONCEPT_CODE = 3000888 AND   DRUG_FORM = 'comprimé 20 mg';
UPDATE P_C_AMOUNT   SET AMOUNT = '4' WHERE CONCEPT_CODE = 3000888 AND   DRUG_FORM = 'comprimé 10 mg';
UPDATE P_C_AMOUNT   SET AMOUNT = '19' WHERE CONCEPT_CODE = 3000888 AND   DRUG_FORM = 'comprimé 30 mg';
UPDATE P_C_AMOUNT   SET AMOUNT = '28' WHERE CONCEPT_CODE = 3001606 AND   DRUG_FORM = 'comprimé de 15 mg';
UPDATE P_C_AMOUNT   SET AMOUNT = '28' WHERE CONCEPT_CODE = 3001606 AND   DRUG_FORM = 'comprimé de 45 mg';
UPDATE P_C_AMOUNT   SET AMOUNT = '28' WHERE CONCEPT_CODE = 3001609 AND   DRUG_FORM = 'comprimé de 60 mg';
UPDATE P_C_AMOUNT   SET AMOUNT = '28' WHERE CONCEPT_CODE = 3001609 AND   DRUG_FORM = 'comprimé de 30 mg';
UPDATE P_C_AMOUNT   SET AMOUNT = '28' WHERE CONCEPT_CODE = 3001611 AND   DRUG_FORM = 'comprimé de 90 mg';
UPDATE P_C_AMOUNT   SET AMOUNT = '28' WHERE CONCEPT_CODE = 3001611 AND   DRUG_FORM = 'comprimé de 30 mg';
UPDATE P_C_AMOUNT   SET AMOUNT = '10' WHERE CONCEPT_CODE = 3004510 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 3004510 AND   DRUG_FORM = 'comprimé beige';
UPDATE P_C_AMOUNT   SET AMOUNT = '5' WHERE CONCEPT_CODE = 3004510 AND   DRUG_FORM = 'comprimé marron foncé';
UPDATE P_C_AMOUNT   SET AMOUNT = '10' WHERE CONCEPT_CODE = 3004511 AND   DRUG_FORM = 'comprimé blanc';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 3004511 AND   DRUG_FORM = 'comprimé beige';
UPDATE P_C_AMOUNT   SET AMOUNT = '5' WHERE CONCEPT_CODE = 3004511 AND   DRUG_FORM = 'comprimé marron foncé';
UPDATE P_C_AMOUNT   SET AMOUNT = '48' WHERE CONCEPT_CODE = 3272443 AND   DRUG_FORM = 'gélule bleue gastro-soluble';
UPDATE P_C_AMOUNT   SET AMOUNT = '24' WHERE CONCEPT_CODE = 3273129 AND   DRUG_FORM = 'gélule bleue gastro-soluble';
UPDATE P_C_AMOUNT   SET AMOUNT = '6' WHERE CONCEPT_CODE = 3759027 AND   DRUG_FORM = 'solution à 8,8 microgrammes';
UPDATE  P_C_AMOUNT   SET AMOUNT = NULL WHERE AMOUNT='99';
--fixed box_size
UPDATE P_C_AMOUNT   SET BOX_SIZE = '1' WHERE CONCEPT_CODE = 2761996;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '1' WHERE CONCEPT_CODE = 3184064;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '3' WHERE CONCEPT_CODE = 3184087;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '1' WHERE CONCEPT_CODE = 3254913;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '3' WHERE CONCEPT_CODE = 3254936;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '1' WHERE CONCEPT_CODE = 3280709;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '3' WHERE CONCEPT_CODE = 3280715;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '1' WHERE CONCEPT_CODE = 3305065;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '3' WHERE CONCEPT_CODE = 3305071;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '1' WHERE CONCEPT_CODE = 3305088;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '3' WHERE CONCEPT_CODE = 3305094;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '1' WHERE CONCEPT_CODE = 3584622;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '1' WHERE CONCEPT_CODE = 3588413;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '3' WHERE CONCEPT_CODE = 3588436;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '1' WHERE CONCEPT_CODE = 3589938;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '3' WHERE CONCEPT_CODE = 3589944;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '1' WHERE CONCEPT_CODE = 3589950;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '3' WHERE CONCEPT_CODE = 3589967;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '1' WHERE CONCEPT_CODE = 3715811;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '3' WHERE CONCEPT_CODE = 3715828;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '3' WHERE CONCEPT_CODE = 3770000;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '1' WHERE CONCEPT_CODE = 3899975;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '3' WHERE CONCEPT_CODE = 3899981;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '1' WHERE CONCEPT_CODE = 3909484;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '1' WHERE CONCEPT_CODE = 3918106;
UPDATE P_C_AMOUNT   SET BOX_SIZE = '3' WHERE CONCEPT_CODE = 3918112;
UPDATE  P_C_AMOUNT   SET BOX_SIZE = NULL WHERE BOX_SIZE='99'
;

--insert results into pack_content table
insert into PC_stage (PACK_CONCEPT_CODE,DRUG_CONCEPT_CODE,AMOUNT,BOX_SIZE)
select cast(CONCEPT_CODE as varchar(255)),PACK_COMPONENT_CODE,AMOUNT,BOX_SIZE from P_C_AMOUNT;

--Concept_synonym_stage 
INSERT INTO Concept_synonym_stage 
(SYNONYM_CONCEPT_ID,SYNONYM_NAME,SYNONYM_CONCEPT_CODE,SYNONYM_VOCABULARY_ID,LANGUAGE_CONCEPT_ID)
Select '', CONCEPT_NAME,CONCEPT_CODE, 'BDPM',  '4180190' -- French language 
from INGR_TRANSLATION_ALL
union  
Select '',FORM_ROUTE, CONCEPT_CODE , 'BDPM',  '4180190' from FORM_TRANSLATION ft
join DRUG_CONCEPT_STAGE dcs on ft.TRANSLATION= dcs.concept_name 
union
select '', concept_name, concept_code, 'BDPM', '4180186' from drug_concept_stage where concept_class_id != 'Unit';
-- Create sequence for new OMOP-created standard concepts
declare
 ex number;
begin
select max(iex)+1 into ex from (  
    
    select cast(substr(concept_code, 5) as integer) as iex from concept where concept_code like 'OMOP%'  and concept_code not like '% %'
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
select distinct  concept_code from drug_concept_stage where concept_code like '%OMOP%' or concept_code like '%PACK%' order by (cast ( regexp_substr( concept_code, '\d+') as int))
)
;
update drug_concept_stage a set concept_code = (select new_code from code_replace b where a.concept_code = b.old_code) 
where a.concept_code like '%OMOP%' or a.concept_code like '%PACK%'
;
commit
;
update relationship_to_concept a  set concept_code_1 = (select new_code from code_replace b where a.concept_code_1 = b.old_code)
where a.concept_code_1 like '%OMOP%' or a.concept_code_1 like '%PACK%'
;commit
;
update ds_stage a  set ingredient_concept_code = (select new_code from code_replace b where a.ingredient_concept_code = b.old_code)
where a.ingredient_concept_code like '%OMOP%' or a.ingredient_concept_code like '%PACK%'
;
commit
;
update ds_stage a  set drug_concept_code = (select new_code from code_replace b where a.drug_concept_code = b.old_code)
where a.drug_concept_code like '%OMOP%' or a.drug_concept_code like '%PACK%'
;commit
;
update internal_relationship_stage a  set concept_code_1 = (select new_code from code_replace b where a.concept_code_1 = b.old_code)
where a.concept_code_1 like '%OMOP%' or a.concept_code_1 like '%PACK%'
;commit
;
update internal_relationship_stage a  set concept_code_2 = (select new_code from code_replace b where a.concept_code_2 = b.old_code)
where a.concept_code_2 like '%OMOP%' or a.concept_code_2 like '%PACK%'
;
commit
;
update pc_stage a  set DRUG_CONCEPT_CODE = (select new_code from code_replace b where a.DRUG_CONCEPT_CODE = b.old_code)
where a.DRUG_CONCEPT_CODE like '%OMOP%' or a.DRUG_CONCEPT_CODE like '%PACK%'
;
update drug_concept_stage set standard_concept=null where concept_code in (select concept_code from drug_concept_stage 
join internal_relationship_stage on concept_code_1 = concept_code
where concept_class_id ='Ingredient' and standard_concept is not null);

commit;
update drug_concept_stage set concept_class_id = 'Drug Product' where concept_class_id='Drug Pack';
commit; 

delete drug_concept_stage where concept_code in (select pack_concept_code from pc_stage);
delete drug_concept_stage where concept_code in (select drug_concept_code from pc_stage);
delete internal_relationship_stage where concept_code_1 in (select pack_concept_code from pc_stage);
delete internal_relationship_stage where concept_code_1 in (select drug_concept_code from pc_stage);
delete ds_stage where drug_concept_code in (select drug_concept_code from pc_stage);commit; 
truncate table pc_stage;

commit; 
