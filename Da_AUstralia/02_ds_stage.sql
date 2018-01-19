
drop table drugs_for_strentgh;
create table drugs_for_strentgh as
select fo_prd_id , prd_name, dosage,unit,dosage2, unit2, mol_name from fo_product where fo_prd_id not in (select concept_code from non_drug) and fo_prd_id not in (select fo_prd_id from PACK_DRUG_PRODUCT)
union select distinct concept_code,prd_name,dosage,unit, dosage_2,unit_2, mol_name from PACK_DRUG_PRODUCT join drug_concept_stage on prd_name= concept_name;
update drugs_for_strentgh 
set PRD_NAME=regexp_replace(PRD_NAME,',','.') where PRD_NAME is not null;
update drugs_for_strentgh 
set PRD_NAME = 'DEXSAL ANTACID LIQUID 1.25G-20MG/15' where prd_name = 'DEXSAL ANTACID LIQUID 1.25G-20MG/1';
update drugs_for_strentgh set unit = 'MCG' where unit like 'µg';
update drugs_for_strentgh set unit2 = 'MCG' where unit2 like 'µg';

drop table ds_strength_trainee purge;
create table ds_strength_trainee (DRUG_CONCEPT_CODE VARCHAR2(255 Byte),INGREDIENT_NAME VARCHAR2(255 Byte),BOX_SIZE NUMBER,AMOUNT_VALUE FLOAT(126),AMOUNT_UNIT VARCHAR2(255 Byte),NUMERATOR_VALUE FLOAT(126),NUMERATOR_UNIT VARCHAR2(255 Byte),DENOMINATOR_VALUE FLOAT(126), 
DENOMINATOR_UNIT VARCHAR2(255 Byte));


--1 molecule denominator in Hours--
insert into ds_strength_trainee (DRUG_CONCEPT_CODE,INGREDIENT_NAME,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
select FO_PRD_ID,mol_name,DOSAGE AS NUMERATOR_VALUE,UNIT AS NUMERATOR_UNIT,regexp_replace(regexp_substr(regexp_substr(PRD_NAME,'/.{0,2}(H|HRS|HOUR|HIURS)$'),'/\d*'), '/') as denominator_value,
regexp_substr(regexp_substr(PRD_NAME,'/.{0,2}(H|HRS|HOUR|HOURS)$'),'H|HRS|HOUR|HOURS')
from drugs_for_strentgh where regexp_like(prd_name, '/.{0,2}(H|HRS|HOUR|HOURS)$') and mol_name not like '%/%'
;

--1 molecule where %--
insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,NUMERATOR_VALUE ,NUMERATOR_UNIT ,DENOMINATOR_UNIT )
SELECT fo_prd_id AS DRUG_CONCEPT_CODE, MOL_NAME AS INGREDIENT_NAME, cast(dosage as number)*10 AS NUMERATOR_VALUE, 'mg' as NUMERATOR_UNIT, 'ml' as DENOMINATOR_UNIT
FROM drugs_for_strentgh
WHERE mol_name not like '%/%' and unit2 is null and unit like '%!%%' escape '!' and fo_prd_id not in (select drug_concept_code from ds_strength_trainee)
;
--1 molecule not %--
insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,AMOUNT_VALUE,AMOUNT_UNIT)
SELECT fo_prd_id, MOL_NAME,DOSAGE,UNIT
from drugs_for_strentgh
WHERE mol_name not like '%/%' and unit2 is null and unit not like '%!%%' escape '!' and dosage2 is null and fo_prd_id not in (select drug_concept_code from ds_strength_trainee)
;


--1 molecule not % where dosage 2 not null--
insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,AMOUNT_VALUE,AMOUNT_UNIT)
SELECT fo_prd_id, MOL_NAME, DOSAGE,UNIT
from drugs_for_strentgh
where mol_name not like '%/%' and unit2 is null and unit not like '%!%%' escape '!' and dosage2 is not null and (prd_name like '%/__H%' or prd_name like '%(%MG)' or dosage2 = '-1') and fo_prd_id not in (select drug_concept_code from ds_strength_trainee)
;
--NEED MANUAL PROCEDURE( NEARLY 20 ROWS) WHERE CONCEPT_CLASS_ID = 'Drug Product' and mol_name not like '%/%' and unit2 is null and unit not like '%!%%' escape '!' and dosage2 is not null and NOT NULL  (prd_name like '%/__H%' or prd_name like '%(%MG)' or dosage2 = '-1')--



--liquid ingr with 1 molecule and no % anywhere--
insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,NUMERATOR_VALUE,NUMERATOR_UNIT, DENOMINATOR_VALUE,DENOMINATOR_UNIT )
SELECT fo_prd_id, MOL_NAME, DOSAGE, UNIT, DOSAGE2,UNIT2
FROM drugs_for_strentgh
where MOL_NAME  not like '%/%' and unit2 is not null and unit not like '%!%%' escape '!' and unit2 not like '%!%%' escape '!' and fo_prd_id not in (select drug_concept_code from ds_strength_trainee)
;


--NEED MANUAL PROCEDURE( NEARLY 40 ROWS) WHERE CONCEPT_CLASS_ID = 'Drug Product' and FO_PRODUCT.MOL_NAME  not like '%/%' and unit2 is not null and (unit like '%!%%' escape '!' or unit2  like '%!%%' escape '!')--

--multiple ingr--
--multiple with pattern ' -%-%-/'--
create or replace view multiple_liquid as
select FO_PRD_ID, PRD_NAME,regexp_replace(regexp_substr( prd_name, '(\d+(\.\d+)?\D*-)+\d+(\.\d+)?\D*'), '/.*') as AA,
regexp_substr(regexp_substr(regexp_substr(prd_name, '(\d+(\.\d+)?\D*-)+\d+(\.\d+)?\D*/.*'),'/\d+.*\s?'), '(\d+(\.\d)?)' ) as DENOMINATOR_VALUE ,
regexp_substr(regexp_substr(regexp_substr( prd_name, '(\d+(\.\d+)?\D*-)+\d+(\.\d+)?\D*/.*'),'/.*'), '(MG|IU|%|G|ML|MCG|MMOL|BILLION.*|MILLION.*|\D*UNITS.|L|LOZ|LOZENGE|µg|U){1}')  as DENOMINATOR_UNIT, mol_name
from
(select * from drugs_for_strentgh where regexp_like(prd_name, '(\d+(\.\d+)?\D*-)+\d+(\.\d+)?\D*/{1}\d?(\.\d+)?\D*') and MOL_NAME like '%/%')
;

create or replace view ds_multiple_liquid as
select FO_PRD_ID,PRD_NAME,G,
regexp_substr(W,'\d+(\.\d+)?') as numerator_value, 
regexp_substr(W,'MG|IU|%|G|ML|MCG|MMOL.*|BILLION.*|MILLION.*|\D*UNITS|DOSE|L|LOZ|µg|U') as numerator_unit,
DENOMINATOR_VALUE, DENOMINATOR_UNIT
from
(select FO_PRD_ID,PRD_NAME,DENOMINATOR_VALUE,DENOMINATOR_UNIT,
regexp_substr(AA, '[^-]+',1,level)as w,
regexp_substr(MOL_NAME , '[^/]+',1,level) as g 
from multiple_liquid
connect by FO_PRD_ID=prior FO_PRD_ID and prior dbms_random.value is not null 
and ( regexp_substr(AA, '[^-]+',1,level) is not null 
or regexp_substr(MOL_NAME , '[^/]+',1,level) is not null))
;
--multiple with pattern '/' --
create or replace view ds_multiple1 as
select FO_PRD_ID,PRD_NAME,A, mol_name from (
select regexp_substr(prd_name,'\d+.?\d*(MG|IU|%|G|ML|MCG|MMOL|BILLION.*|MILLION.*| \D*UNITS|L|LOZ|µg|U){1}/\d+.*') as A, PRD_NAME,FO_PRD_ID, mol_name
from drugs_for_strentgh 
where mol_name like '%/%' and FO_PRD_ID not in (select distinct FO_PRD_ID from ds_multiple_liquid)) where A is not null
;

--multiple with pattern '-'--
create or replace view ds_multiple2 as
select FO_PRD_ID, PRD_NAME, b, mol_name from (
select regexp_substr(prd_name,'\d.?\d*(MG|IU|%|G|ML|MCG|MMOL|BILLION.*|MILLION.*|\D*UNITS|L|LOZ|µg|U){1}-\d.*') as b, PRD_NAME,fo_prd_id, mol_name
from drugs_for_strentgh 
where mol_name like '%/%' and FO_PRD_ID not in (select distinct FO_PRD_ID from ds_multiple_liquid)) where b is not null
;
--connecticng ingredient to comp. dosage--
drop table MULTIPLE_INGREDIENTS;
create table MULTIPLE_INGREDIENTS as
select FO_PRD_ID, PRD_NAME,
regexp_substr(A, '[^/]+',1,level)as w, 
regexp_substr(MOL_NAME , '[^/]+',1,level) as g 
from ds_multiple1
connect by FO_PRD_ID=prior FO_PRD_ID and prior dbms_random.value is not null 
and ( regexp_substr( A, '[^/]+',1,level) is not null 
or regexp_substr(MOL_NAME , '[^/]+',1,level) is not null)
union
select FO_PRD_ID, PRD_NAME,
regexp_substr(b, '[^-]+',1,level) w, 
regexp_substr(MOL_NAME , '[^/]+',1,level) 
from ds_multiple2
connect by FO_PRD_ID=prior FO_PRD_ID and prior dbms_random.value is not null 
and ( regexp_substr( b, '[^-]+',1,level) is not null 
or regexp_substr(MOL_NAME , '[^/]+',1,level) is not null)
;


insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME )
SELECT CONCEPT_CODE, BB.MOL_NAME
from DRUG_CONCEPT_STAGE JOIN
(select FO_PRD_ID, PRD_NAME, regexp_substr(W,'\d+(\.\d*)?') as dosage, regexp_substr (W,'MG|IU|%|G|ML|MCG|MMOL|BILLION.*|MILLION.*|\D*UNITS|L|LOZ|µg|U' ) as unit, g as mol_name from MULTIPLE_INGREDIENTS )BB
on CONCEPT_CODE = FO_PRD_ID 
where CONCEPT_CLASS_ID = 'Drug Product'  and (DOSAGE IS NULL OR UNIT IS NULL);


insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,NUMERATOR_VALUE ,NUMERATOR_UNIT ,DENOMINATOR_UNIT )
select CONCEPT_CODE AS DRUG_CONCEPT_CODE, AA.MOL_NAME AS INGREDIENT_NAME, cast(AA.dosage as number)*10 AS NUMERATOR_VALUE, 'mg' as NUMERATOR_UNIT, 'ml' as DENOMINATOR_UNIT
from DRUG_CONCEPT_STAGE JOIN
(select FO_PRD_ID, PRD_NAME, regexp_substr(W,'\d+(\.\d*)?') as dosage, regexp_substr (W,'MG|IU|%|G|ML|MCG|MMOL|BILLION.*|MILLION.*|\D*UNITS|L|LOZ|µg|U' ) as unit, g as mol_name from MULTIPLE_INGREDIENTS ) AA
on CONCEPT_CODE = FO_PRD_ID 
where CONCEPT_CLASS_ID = 'Drug Product' and unit like '%!%%' escape '!' 
;

insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,AMOUNT_VALUE,AMOUNT_UNIT)
SELECT CONCEPT_CODE, BB.MOL_NAME, BB.DOSAGE, BB.UNIT
from DRUG_CONCEPT_STAGE JOIN
(select FO_PRD_ID, PRD_NAME, regexp_substr(W,'\d+(\.\d*)?') as dosage, regexp_substr (W,'MG|IU|%|G|ML|MCG|MMOL|BILLION.*|MILLION.*|\D*UNITS|L|LOZ|µg|U' ) as unit, g as mol_name from MULTIPLE_INGREDIENTS )BB
on CONCEPT_CODE = FO_PRD_ID 
where CONCEPT_CLASS_ID = 'Drug Product'  and unit not like '%!%%' escape '!'
;
 insert into ds_strength_trainee (DRUG_CONCEPT_CODE ,INGREDIENT_NAME ,NUMERATOR_VALUE ,NUMERATOR_UNIT ,DENOMINATOR_VALUE, DENOMINATOR_UNIT )
 select FO_PRD_ID as DRUG_CONCEPT_CODE,G as INGREDIENT_NAME, NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT from ds_multiple_liquid;
 

drop table ds_trainee_upd;
create table ds_trainee_upd as
select DRUG_CONCEPT_CODE,INGREDIENT_NAME,regexp_substr(regexp_substr(PRD_NAME,'\d+\w+/(\d)?(\.)?(\d)?\w+'),'(\d+)\w+') as numerator, regexp_replace(regexp_substr(PRD_NAME,'\d+\w+/(\d)?(\.)?(\d)?\w+'),'(\d+)\w+/') as denominator
from ds_strength_trainee a join drugs_for_strentgh b on fo_prd_id=drug_Concept_code
where PRD_NAME like '%/%' and amount_value is not null and mol_name not like '%/%'
and not regexp_like (regexp_substr(PRD_NAME,'(\d)+\w+/(\d)?(\.)?(\d)?\w+'),'SPRAY|PUMP|SACHET|INHAL|PUFF|DROP|DOSE|CAP|DO|SQUARE|LOZ|ELECTROLYTES|APPLICATI|BLIS|VIAL|BLIST');

drop table ds_trainee_upd_2;
create table ds_trainee_upd_2 as
select DRUG_CONCEPT_CODE,INGREDIENT_NAME,
case when denominator='STRAIN' then '0.1' when  denominator='33' then '33.6' when denominator like '%2%'  then '24' else regexp_substr(DENOMINATOR,'\d+') end as denominator_value,
case when denominator like '%H%' then 'HOUR' when denominator like '%L%' then 'L' when denominator='33' then 'MG' when denominator='STRAIN' then 'ML' when denominator like '%ACTUA%' then 'ACTUATION'
 when denominator like '%2%' then 'HOUR' else regexp_replace(DENOMINATOR,'\d+') end as denominator_unit,
 regexp_replace(NUMERATOR,'\d+') as numerator_unit,
regexp_substr(NUMERATOR,'\d+') as numerator_value
from ds_trainee_upd


;
drop table ds_stage_manual_all;
create table ds_stage_manual_all
(
DRUG_CONCEPT_CODE	VARCHAR2(255),
INGREDIENT_NAME	VARCHAR2(255),
BOX_SIZE	NUMBER,
AMOUNT_VALUE	FLOAT(126),
AMOUNT_UNIT	VARCHAR2(255),	
NUMERATOR_VALUE	FLOAT(126),	
NUMERATOR_UNIT	VARCHAR2(255),	
DENOMINATOR_VALUE	FLOAT(126),
DENOMINATOR_UNIT	VARCHAR2(255)	
);

WbImport -file=C:/Users/eallakhverdiiev/Desktop/ds_stage_manual_all.txt
         -type=text
         -table=DS_STAGE_MANUAL_ALL
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -decimal=.
         -fileColumns=DRUG_CONCEPT_CODE,$wb_skip$,$wb_skip$,INGREDIENT_NAME,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100;
        
update DS_STAGE_MANUAL_ALL 
set INGREDIENT_NAME=regexp_replace(INGREDIENT_NAME,',','.') where INGREDIENT_NAME is not null;
update DS_STAGE_MANUAL_ALL SET INGREDIENT_NAME=trim(REGEXP_REPLACE(INGREDIENT_NAME,'"'));



 
delete ds_strength_trainee 
where drug_concept_code in (select drug_concept_code from ds_stage_manual_all);      
insert into ds_strength_trainee select * from ds_stage_manual_all;
update ds_strength_trainee 
set DENOMINATOR_UNIT= 'ACTUATION' where drug_concept_code in (select drug_concept_code  from ds_strength_trainee join drugs on drug_concept_code = fo_prd_id  where PRD_NAME like '%DOSE') and NUMERATOR_UNIT is not null and DENOMINATOR_VALUE is null;
update ds_strength_trainee 
set DENOMINATOR_UNIT= 'ACTUATION', NUMERATOR_VALUE= AMOUNT_VALUE, NUMERATOR_UNIT= AMOUNT_UNIT, AMOUNT_VALUE = null , AMOUNT_UNIT= null
where drug_concept_code in (select drug_concept_code  from ds_strength_trainee join drugs on drug_concept_code = fo_prd_id  where PRD_NAME like '%DOSE' and denominator_unit is null);
update ds_strength_trainee 
set DENOMINATOR_UNIT = 'ml' where drug_concept_code in (select DRUG_CONCEPT_CODE from ds_strength_trainee join drugs on drug_concept_code = fo_prd_id  where regexp_like(prd_name,'-\d+\w+/\d+$') and mol_name like '%/%');
update ds_strength_trainee 
set DENOMINATOR_UNIT = 'ml' where DENOMINATOR_UNIT = 'ML';
update ds_strength_trainee set AMOUNT_VALUE = null, AMOUNT_UNIT = null where AMOUNT_VALUE= '0';
UPDATE DS_STRENGTH_TRAINEE  SET DENOMINATOR_UNIT = 'HOUR' WHERE DENOMINATOR_VALUE = '24';
UPDATE DS_STRENGTH_TRAINEE  SET DENOMINATOR_UNIT = 'HOUR' WHERE DENOMINATOR_UNIT  = 'H';
UPDATE DS_STRENGTH_TRAINEE  SET INGREDIENT_NAME = 'NICOTINAMIDE' WHERE INGREDIENT_NAME  = 'NICOTINIC ACID';
DELETE FROM DS_STRENGTH_TRAINEE WHERE DRUG_CONCEPT_CODE = '28058' AND INGREDIENT_NAME = 'NICOTINAMIDE' AND AMOUNT_VALUE= '20';
UPDATE DS_STRENGTH_TRAINEE SET AMOUNT_VALUE ='520' WHERE DRUG_CONCEPT_CODE = '28058' AND INGREDIENT_NAME = 'NICOTINAMIDE';
DELETE FROM DS_STRENGTH_TRAINEE WHERE DRUG_CONCEPT_CODE = '27625' AND INGREDIENT_NAME = 'NICOTINAMIDE' AND AMOUNT_VALUE= '25';
UPDATE DS_STRENGTH_TRAINEE SET AMOUNT_VALUE = '125' WHERE DRUG_CONCEPT_CODE = '27625' AND INGREDIENT_NAME = 'NICOTINAMIDE';
DELETE FROM DS_STRENGTH_TRAINEE WHERE DRUG_CONCEPT_CODE = '15248' AND INGREDIENT_NAME = 'SILYBUM MARIANUM' AND AMOUNT_VALUE= '1';
UPDATE DS_STRENGTH_TRAINEE SET AMOUNT_VALUE = '8' WHERE DRUG_CONCEPT_CODE = '15248' AND INGREDIENT_NAME = 'SILYBUM MARIANUM';
DELETE FROM DS_STRENGTH_TRAINEE WHERE DRUG_CONCEPT_CODE = '88716' AND INGREDIENT_NAME = 'NICOTINAMIDE';
INSERT INTO DS_STRENGTH_TRAINEE (DRUG_CONCEPT_CODE,INGREDIENT_NAME) VALUES ('88716','NICOTINAMIDE');
update DS_STRENGTH_TRAINEE set  AMOUNT_UNIT = TRIM(regexp_replace(AMOUNT_UNIT,'S$'))   where  regexp_like (AMOUNT_UNIT,'^\s');
update DS_STRENGTH_TRAINEE set  NUMERATOR_UNIT = TRIM(regexp_replace(NUMERATOR_UNIT,'S$'))   where  regexp_like (NUMERATOR_UNIT,'^\s');
update DS_STRENGTH_TRAINEE set  DENOMINATOR_UNIT = TRIM(regexp_replace(DENOMINATOR_UNIT,'S$'))   where  regexp_like (DENOMINATOR_UNIT,'^\s');


truncate table ds_stage;
 insert into ds_stage (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
 select DRUG_CONCEPT_CODE,concept_code,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT from ds_strength_trainee join drug_concept_stage 
 on ingredient_name = concept_name where concept_class_id ='Ingredient';

--some new units appeared--
insert into DRUG_concept_STAGE (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select amount_unit,'AMT','Unit','',amount_unit,'Drug', TO_DATE('2016/10/01', 'yyyy/mm/dd'),TO_DATE('2099/12/31', 'yyyy/mm/dd'), ''
 from (select amount_unit from ds_strength_trainee union select NUMERATOR_UNIT from ds_strength_trainee union select DENOMINATOR_UNIT from ds_strength_trainee) minus (select concept_name from DRUG_concept_STAGE where concept_class_id like 'Unit'))
 WHERE AMOUNT_UNIT IS NOT NULL;



