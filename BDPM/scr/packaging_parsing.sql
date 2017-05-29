--using general rule: mostly packaging begins with Box_size and de% contains quantitve info 
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
select distinct din_7 as concept_code, a.drug_code, DRUG_FORM, form_code as ingredient_code, ingredient as ingredient_name, packaging, d.drug_descr, dosage_value, dosage_unit, volume_value, volume_unit, amount_value as pack_amount_value, amount_unit as pack_amount_unit,
case when volume_value is null and AMOUNT_VALUE is null and dosage_unit !='%' then dosage_value else null end as amount_value,
case when volume_value is null and AMOUNT_VALUE is null and dosage_unit !='%' then dosage_unit else null end as  amount_unit ,

case
when volume_value is not null and amount_value is not null 
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

