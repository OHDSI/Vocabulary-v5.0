truncate table DRUG_CONCEPT_STAGE;
insert into DRUG_CONCEPT_STAGE (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,domain_id,VALID_START_DATE,VALID_END_DATE,INVALID_REASON,SOURCE_CONCEPT_CLASS_ID)
select distinct CONCEPT_NAME, 'Rxfix', 'Drug Product', '', CONCEPT_CODE, '',domain_id, valid_start_date, valid_end_date, INVALID_REASON,CONCEPT_CLASS_ID
from concept where regexp_like(concept_class_id,'Drug|Pack|Box|Marketed') and vocabulary_id='RxNorm Extension' and VALID_END_DATE>'02-Feb-2017' -- add constriction
UNION
select distinct b2.CONCEPT_NAME, 'Rxfix', b2.CONCEPT_CLASS_ID, '', b2.CONCEPT_CODE, '',b2.domain_id, b2.valid_start_date, b2.valid_end_date, b2.INVALID_REASON,b2.CONCEPT_CLASS_ID
from concept_relationship a 
join concept b on concept_id_1=b.concept_id and regexp_like(b.concept_class_id,'Drug|Pack|Box|Marketed') and b.vocabulary_id='RxNorm Extension' and a.invalid_reason is null
join concept b2 on concept_id_2=b2.concept_id and b2.concept_class_id in ('Dose Form','Brand Name','Supplier') and b2.vocabulary_id like 'Rx%' and b2.invalid_reason is null
UNION
select distinct b3.CONCEPT_NAME, 'Rxfix', b3.CONCEPT_CLASS_ID, '', b3.CONCEPT_CODE, '',b3.domain_id, b3.valid_start_date, b3.valid_end_date, b3.INVALID_REASON,b3.CONCEPT_CLASS_ID -- add fresh attributes instead of invalid
from concept_relationship a 
join concept b on concept_id_1=b.concept_id and regexp_like(b.concept_class_id,'Drug|Pack|Box|Marketed') and b.vocabulary_id='RxNorm Extension'
join concept b2 on concept_id_2=b2.concept_id and b2.concept_class_id in ('Dose Form','Brand Name','Supplier') and b2.vocabulary_id like 'Rx%' and b2.invalid_reason is not null
join concept_relationship a2 on a2.concept_id_1=b2.concept_id and a2.RELATIONSHIP_ID='Concept replaced by'
join concept b3 on a2.concept_id_2=b3.concept_id and b3.concept_class_id in ('Dose Form','Brand Name','Supplier') and b3.vocabulary_id like 'Rx%' 
UNION
select distinct CONCEPT_NAME, 'Rxfix', 'Ingredient', 'S',CONCEPT_CODE, '',domain_id, valid_start_date, valid_end_date, INVALID_REASON,'Ingredient'
from 
(select b.concept_name, b.concept_code, b.domain_id, b.valid_start_date, b.valid_end_date,b.INVALID_REASON
from drug_strength a join concept b on a.ingredient_concept_id=b.concept_id and b.invalid_reason is null  
join concept c on a.drug_concept_id=c.concept_id and c.vocabulary_id='RxNorm Extension'
where b.vocabulary_id like 'Rx%'
union
select a.concept_name, a.concept_code, a.domain_id, a.valid_start_date, a.valid_end_date ,a.INVALID_REASON --add ingredients from ancestor
from concept a join concept_ancestor b on a.concept_id=ancestor_concept_id and a.concept_class_id='Ingredient'
join concept a2 on descendant_concept_id=a2.concept_id and a2.vocabulary_id='RxNorm Extension')
UNION
select distinct CONCEPT_NAME, 'Rxfix', 'Unit', '', CONCEPT_CODE, '','Drug',TO_DATE('2017/01/24', 'yyyy/mm/dd'),TO_DATE('2099/12/31', 'yyyy/mm/dd'), '','Unit'
from (
      select distinct CONCEPT_NAME,CONCEPT_CODE from 
            (select distinct c3.CONCEPT_CODE as concept_name,  c3.CONCEPT_CODE as concept_code
             FROM concept c
             JOIN drug_strength ds on ds.DRUG_CONCEPT_ID=c.CONCEPT_ID and c.vocabulary_id='RxNorm Extension'
             join concept c3 on AMOUNT_UNIT_CONCEPT_ID=c3.CONCEPT_ID
             union
             select distinct c2.CONCEPT_CODE,c2.CONCEPT_CODE
             FROM concept c
             JOIN drug_strength ds on ds.DRUG_CONCEPT_ID=c.CONCEPT_ID and c.vocabulary_id='RxNorm Extension'
             join concept c2 on NUMERATOR_UNIT_CONCEPT_ID=c2.CONCEPT_ID
             union
             select distinct c1.CONCEPT_CODE,c1.CONCEPT_CODE
             FROM concept c
             JOIN drug_strength ds on ds.DRUG_CONCEPT_ID=c.CONCEPT_ID and c.vocabulary_id='RxNorm Extension'
             join concept c1 on DENOMINATOR_UNIT_CONCEPT_ID=c1.CONCEPT_ID)
             

      )
;

delete drug_concept_stage where concept_code in (
select concept_code from concept where vocabulary_id like 'RxNorm%' and invalid_reason='D' and VALID_END_DATE<'02-Feb-2017');

delete drug_concept_stage 
where concept_code in (
select concept_code from concept c join devv5.drug_strength ds on drug_concept_id=concept_id and vocabulary_id='RxNorm Extension' and c.invalid_reason is null
where denominator_value<0.05 and denominator_unit_concept_id=8587);

--insert into drug_concept_stage (CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON) 
--select CONCEPT_NAME,DOMAIN_ID,'Rxfix',CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON from concept_stage where concept_name='Fotemustine' and invalid_reason is null;

truncate table ds_stage;
insert into ds_stage (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
select c.concept_code, c2.concept_code,box_size,AMOUNT_VALUE,c3.CONCEPT_CODE,NUMERATOR_VALUE,c4.CONCEPT_CODE,DENOMINATOR_VALUE,c5.CONCEPT_CODE
FROM concept c
JOIN devv5.drug_strength ds on ds.DRUG_CONCEPT_ID=c.CONCEPT_ID
JOIN concept c2 on ds.INGREDIENT_CONCEPT_ID=c2.CONCEPT_ID
left join concept c3 on AMOUNT_UNIT_CONCEPT_ID=c3.CONCEPT_ID
left join concept c4 on NUMERATOR_UNIT_CONCEPT_ID=c4.CONCEPT_ID
left join concept c5 on DENOMINATOR_UNIT_CONCEPT_ID=c5.CONCEPT_ID
WHERE c.vocabulary_id='RxNorm Extension' ;

--update ds_stage from homeopathy
update ds_stage set 
    amount_value=numerator_value, 
    amount_unit=numerator_unit,
    numerator_value=null,
    numerator_unit=null,
    denominator_value=null,
    denominator_unit=null
where numerator_unit in ('[hp_X]','[hp_C]');

--add units absent in drug_strength
UPDATE DS_STAGE   SET AMOUNT_UNIT = '[U]' WHERE DRUG_CONCEPT_CODE = 'OMOP467711' AND   INGREDIENT_CONCEPT_CODE = '560';
UPDATE DS_STAGE   SET AMOUNT_UNIT = '[U]' WHERE DRUG_CONCEPT_CODE = 'OMOP467709' AND   INGREDIENT_CONCEPT_CODE = '560';
UPDATE DS_STAGE   SET AMOUNT_VALUE = 100,       AMOUNT_UNIT = 'mg',       NUMERATOR_VALUE = NULL,       NUMERATOR_UNIT = '' WHERE DRUG_CONCEPT_CODE = 'OMOP420833' AND   INGREDIENT_CONCEPT_CODE = '1202';
UPDATE DS_STAGE   SET AMOUNT_UNIT = '[U]' WHERE DRUG_CONCEPT_CODE = 'OMOP467706' AND   INGREDIENT_CONCEPT_CODE = '560';
UPDATE DS_STAGE   SET AMOUNT_VALUE = 25,       AMOUNT_UNIT = 'mg',       NUMERATOR_VALUE = NULL,       NUMERATOR_UNIT = '' WHERE DRUG_CONCEPT_CODE = 'OMOP420835' AND   INGREDIENT_CONCEPT_CODE = '2409';
UPDATE DS_STAGE   SET AMOUNT_UNIT = '[U]' WHERE DRUG_CONCEPT_CODE = 'OMOP467710' AND   INGREDIENT_CONCEPT_CODE = '560';
UPDATE DS_STAGE   SET AMOUNT_UNIT = '[U]' WHERE DRUG_CONCEPT_CODE = 'OMOP467715' AND   INGREDIENT_CONCEPT_CODE = '560';
UPDATE DS_STAGE   SET AMOUNT_UNIT = '[U]' WHERE DRUG_CONCEPT_CODE = 'OMOP467705' AND   INGREDIENT_CONCEPT_CODE = '560';
UPDATE DS_STAGE   SET AMOUNT_UNIT = '[U]' WHERE DRUG_CONCEPT_CODE = 'OMOP467712' AND   INGREDIENT_CONCEPT_CODE = '560';
UPDATE DS_STAGE   SET AMOUNT_UNIT = '[U]',       NUMERATOR_UNIT = '' WHERE DRUG_CONCEPT_CODE = 'OMOP467708' AND   INGREDIENT_CONCEPT_CODE = '560';
UPDATE DS_STAGE   SET AMOUNT_VALUE = 100,       AMOUNT_UNIT = 'mg',       NUMERATOR_VALUE = NULL,       NUMERATOR_UNIT = '' WHERE DRUG_CONCEPT_CODE = 'OMOP420834' AND   INGREDIENT_CONCEPT_CODE = '1202';
UPDATE DS_STAGE   SET AMOUNT_UNIT = '[U]' WHERE DRUG_CONCEPT_CODE = 'OMOP467714' AND   INGREDIENT_CONCEPT_CODE = '560';
UPDATE DS_STAGE   SET AMOUNT_VALUE = 25,       AMOUNT_UNIT = 'mg',       NUMERATOR_VALUE = NULL,       NUMERATOR_UNIT = '' WHERE DRUG_CONCEPT_CODE = 'OMOP420834' AND   INGREDIENT_CONCEPT_CODE = '2409';
UPDATE DS_STAGE   SET AMOUNT_UNIT = '[U]' WHERE DRUG_CONCEPT_CODE = 'OMOP467713' AND   INGREDIENT_CONCEPT_CODE = '560';
UPDATE DS_STAGE   SET AMOUNT_VALUE = 25,       AMOUNT_UNIT = 'mg',       NUMERATOR_VALUE = NULL,       NUMERATOR_UNIT = '' WHERE DRUG_CONCEPT_CODE = 'OMOP420731' AND   INGREDIENT_CONCEPT_CODE = '2409';
UPDATE DS_STAGE   SET AMOUNT_VALUE = 100,       AMOUNT_UNIT = 'mg',       NUMERATOR_VALUE = NULL,       NUMERATOR_UNIT = '' WHERE DRUG_CONCEPT_CODE = 'OMOP420832' AND   INGREDIENT_CONCEPT_CODE = '1202';
UPDATE DS_STAGE   SET AMOUNT_VALUE = 25,       AMOUNT_UNIT = 'mg',       NUMERATOR_VALUE = NULL,       NUMERATOR_UNIT = '' WHERE DRUG_CONCEPT_CODE = 'OMOP420833' AND   INGREDIENT_CONCEPT_CODE = '2409';
UPDATE DS_STAGE   SET AMOUNT_VALUE = 100,       AMOUNT_UNIT = 'mg',       NUMERATOR_VALUE = NULL,       NUMERATOR_UNIT = '' WHERE DRUG_CONCEPT_CODE = 'OMOP420835' AND   INGREDIENT_CONCEPT_CODE = '1202';


update ds_stage
set NUMERATOR_UNIT='mg',NUMERATOR_VALUE=NUMERATOR_VALUE/1000
where NUMERATOR_UNIT='ug';
update ds_stage
set AMOUNT_UNIT='mg',AMOUNT_VALUE=AMOUNT_VALUE/1000
where AMOUNT_UNIT='ug';
update ds_stage
set AMOUNT_UNIT='[iU]',AMOUNT_VALUE=AMOUNT_VALUE*1000000
where AMOUNT_UNIT='ukat';

update ds_stage 
set NUMERATOR_UNIT='[U]'
where NUMERATOR_UNIT='[iU]';
update ds_stage 
set DENOMINATOR_UNIT='[U]'
where DENOMINATOR_UNIT='[iU]';
update ds_stage 
set AMOUNT_UNIT='[U]'
where AMOUNT_UNIT='[iU]';


--Fentanyl buccal film
UPDATE ds_stage
set AMOUNT_VALUE=NUMERATOR_VALUE,AMOUNT_UNIT=NUMERATOR_UNIT,DENOMINATOR_VALUE=null,DENOMINATOR_UNIT=null ,NUMERATOR_UNIT=null,NUMERATOR_VALUE=null
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code
where nvl(AMOUNT_UNIT,NUMERATOR_UNIT) in ('cm','mm' ) or DENOMINATOR_UNIT in ('cm','mm')
and ( b.concept_name like '%Buccal Film%' or b.concept_name like '%Breakyl Start%'));

--Fentanyl buccal film
UPDATE ds_stage
set AMOUNT_VALUE=NUMERATOR_VALUE,AMOUNT_UNIT=NUMERATOR_UNIT,DENOMINATOR_VALUE=null,DENOMINATOR_UNIT=null ,NUMERATOR_UNIT=null,NUMERATOR_VALUE=null
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code
where nvl(AMOUNT_UNIT,NUMERATOR_UNIT) in ('cm','mm' ) or DENOMINATOR_UNIT in ('cm','mm')
and ( b.concept_name like '%Buccal Film%' or b.concept_name like '%Breakyl Start%' or NUMERATOR_VALUE in ('0.808','1.21','1.62')));

--add denominator to trandermal patch

UPDATE ds_stage 
set NUMERATOR_VALUE=0.012,DENOMINATOR_VALUE=null,DENOMINATOR_UNIT='h',AMOUNT_UNIT=null,AMOUNT_VALUE=null,NUMERATOR_UNIT='mg'
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code --also found like 0.4*5.25 cm=2.1 mg=0.012/h
where  b.concept_name like '%Fentanyl%Transdermal%' and AMOUNT_VALUE in ('2.55','2.1','2.5','0.4','1.38'))
;
UPDATE ds_stage 
set NUMERATOR_VALUE=0.025,DENOMINATOR_VALUE=null,DENOMINATOR_UNIT='h',AMOUNT_UNIT=null,AMOUNT_VALUE=null,NUMERATOR_UNIT='mg'
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code 
where b.concept_name like '%Fentanyl%Transdermal%' and AMOUNT_VALUE in ('0.275','2.75','3.72','4.2','5.1','0.6','0.319','0.25','5','4.8'))
;

UPDATE ds_stage 
set NUMERATOR_VALUE=0.05,DENOMINATOR_VALUE=null,DENOMINATOR_UNIT='h',AMOUNT_UNIT=null,AMOUNT_VALUE=null,NUMERATOR_UNIT='mg'
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code
where  b.concept_name like '%Fentanyl%Transdermal%' and AMOUNT_VALUE in ('5.5','10.2','7.5','8.25','8.4','0.875','9.6','14.4','15.5'))
;
UPDATE ds_stage 
set NUMERATOR_VALUE=0.075,DENOMINATOR_VALUE=null,DENOMINATOR_UNIT='h',AMOUNT_UNIT=null,AMOUNT_VALUE=null,NUMERATOR_UNIT='mg'
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code --168
where  b.concept_name like '%Fentanyl%Transdermal%' and AMOUNT_VALUE in ('12.6','15.3','12.4','19.2','23.1'))
;

UPDATE ds_stage 
set NUMERATOR_VALUE=0.1,DENOMINATOR_VALUE=null,DENOMINATOR_UNIT='h',AMOUNT_UNIT=null,AMOUNT_VALUE=null,NUMERATOR_UNIT='mg'
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code --168
where  b.concept_name like '%Fentanyl%Transdermal%' and AMOUNT_VALUE in ('16.8','10','11','20.4','16.5'))
;

-- Fentanyl topical
UPDATE ds_stage 
set NUMERATOR_VALUE=0.012,DENOMINATOR_VALUE=null,DENOMINATOR_UNIT='h'
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code --also found like 0.4*5.25 cm=2.1 mg=0.012/h
where nvl(AMOUNT_UNIT,NUMERATOR_UNIT) in ('cm','mm' ) or DENOMINATOR_UNIT in ('cm','mm')
and regexp_like(b.concept_name,'Fentanyl') and NUMERATOR_VALUE in ('2.55','2.1','2.5','0.4'))
;
UPDATE ds_stage 
set NUMERATOR_VALUE=0.025,DENOMINATOR_VALUE=null,DENOMINATOR_UNIT='h'
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code 
where nvl(AMOUNT_UNIT,NUMERATOR_UNIT) in ('cm','mm' ) or DENOMINATOR_UNIT in ('cm','mm')
and regexp_like(b.concept_name,'Fentanyl') and NUMERATOR_VALUE in ('0.275','2.75','3.72','4.2','5.1','0.6','0.319','0.25','5'))
;

UPDATE ds_stage 
set NUMERATOR_VALUE=0.05,DENOMINATOR_VALUE=null,DENOMINATOR_UNIT='h'
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code
where nvl(AMOUNT_UNIT,NUMERATOR_UNIT) in ('cm','mm' ) or DENOMINATOR_UNIT in ('cm','mm')
and regexp_like(b.concept_name,'Fentanyl') and NUMERATOR_VALUE in ('5.5','10.2','7.5','8.25','8.4','0.875'))
;
UPDATE ds_stage 
set NUMERATOR_VALUE=0.075,DENOMINATOR_VALUE=null,DENOMINATOR_UNIT='h'
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code --168
where nvl(AMOUNT_UNIT,NUMERATOR_UNIT) in ('cm','mm' ) or DENOMINATOR_UNIT in ('cm','mm')
and regexp_like(b.concept_name,'Fentanyl') and NUMERATOR_VALUE in ('12.6','15.3'))
;

UPDATE ds_stage 
set NUMERATOR_VALUE=0.1,DENOMINATOR_VALUE=null,DENOMINATOR_UNIT='h'
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code --168
where nvl(AMOUNT_UNIT,NUMERATOR_UNIT) in ('cm','mm' ) or DENOMINATOR_UNIT in ('cm','mm')
and regexp_like(b.concept_name,'Fentanyl') and NUMERATOR_VALUE in ('16.8','10','11','20.4'))
;

--rivastigmine

UPDATE ds_stage
set NUMERATOR_VALUE=13.3, DENOMINATOR_VALUE=24,DENOMINATOR_UNIT='h'
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code
where nvl(AMOUNT_UNIT,NUMERATOR_UNIT) in ('cm','mm' ) or DENOMINATOR_UNIT in ('cm','mm')
and b.concept_name like '%rivastigmine%' and NUMERATOR_VALUE=27);

UPDATE ds_stage
set NUMERATOR_VALUE=case when DENOMINATOR_VALUE is null then NUMERATOR_VALUE*24  else NUMERATOR_VALUE/DENOMINATOR_VALUE*24 end, DENOMINATOR_VALUE=24,DENOMINATOR_UNIT='h'
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code
where nvl(AMOUNT_UNIT,NUMERATOR_UNIT) in ('cm','mm' ) or DENOMINATOR_UNIT in ('cm','mm')
and b.concept_name like '%rivastigmine%');

--nicotine
UPDATE ds_stage
set NUMERATOR_VALUE=case when DENOMINATOR_VALUE is null then NUMERATOR_VALUE*16 else NUMERATOR_VALUE/DENOMINATOR_VALUE*16 end,DENOMINATOR_VALUE=16,DENOMINATOR_UNIT='h'
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code
where nvl(AMOUNT_UNIT,NUMERATOR_UNIT) in ('cm','mm' ) or DENOMINATOR_UNIT in ('cm','mm')
and b.concept_name like '%Nicotine%' and NUMERATOR_VALUE in ('0.625','0.938','1.56','35.2'));

UPDATE ds_stage
set NUMERATOR_VALUE=14,DENOMINATOR_VALUE=24,DENOMINATOR_UNIT='h'
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code
where nvl(AMOUNT_UNIT,NUMERATOR_UNIT) in ('cm','mm' ) or DENOMINATOR_UNIT in ('cm','mm')
and b.concept_name like '%Nicotine%' and NUMERATOR_VALUE in ('5.57','5.14','36','78'));

--Povidone-Iodine
update ds_stage
set numerator_value='100', denominator_value=null,DENOMINATOR_UNIT='mL'
where drug_concept_code in (
select drug_concept_code from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code
where nvl(AMOUNT_UNIT,NUMERATOR_UNIT) in ('cm','mm' ) or DENOMINATOR_UNIT in ('cm','mm') and concept_name like '%Povidone-Iodine%' ); 


--the other cm
UPDATE ds_stage
set DENOMINATOR_UNIT='cm2'
where DRUG_CONCEPT_CODE in (
select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage b on a.drug_concept_code=b.concept_code
where nvl(AMOUNT_UNIT,NUMERATOR_UNIT) in ('cm','mm' ) or DENOMINATOR_UNIT in ('cm','mm'));

commit;

--delete 3 leg dogs
delete ds_stage where drug_concept_code in(
with a as (
select drug_concept_id,count(drug_concept_id) as cnt1 from drug_strength 
group by drug_concept_id
),
b as (
select descendant_concept_id, count(descendant_concept_id) as cnt2 from concept_ancestor a 
join concept b on ancestor_concept_id=b.concept_id and concept_class_id='Ingredient'
join concept b2 on descendant_concept_id=b2.concept_id where b2.concept_class_id not like '%Comp%'
group by descendant_concept_id)
select  concept_code
from a join b on a.drug_concept_id=b.descendant_concept_id
join concept c on drug_concept_id=concept_id 
where cnt1<cnt2
and c.vocabulary_id!='RxNorm');
/*
create table dogs as
with a as (
select drug_concept_id,count(drug_concept_id) as cnt1 from drug_strength 
group by drug_concept_id
),
b as (
select descendant_concept_id, count(descendant_concept_id) as cnt2 from concept_ancestor a 
join concept b on ancestor_concept_id=b.concept_id and concept_class_id='Ingredient'
join concept b2 on descendant_concept_id=b2.concept_id where b2.concept_class_id not like '%Comp%'
group by descendant_concept_id)
select  concept_code
from a join b on a.drug_concept_id=b.descendant_concept_id
join concept c on drug_concept_id=concept_id 
where cnt1<cnt2
and c.vocabulary_id!='RxNorm';
delete ds_stage where drug_concept_code in (select concept_code from dogs);
drop table dogs; */

--delete drugs that have denominator_value less than 0.05

delete ds_stage
where drug_concept_code in (
select drug_concept_code from ds_stage
where denominator_value<0.05 and denominator_unit='mL');

delete ds_stage
where drug_concept_code in (
select concept_code from concept c join drug_strength ds on drug_concept_id=concept_id and vocabulary_id='RxNorm Extension' and c.invalid_reason is null
where denominator_value<0.05 and denominator_unit_concept_id=8587);

UPDATE DS_STAGE   SET NUMERATOR_VALUE = 10000,       DENOMINATOR_UNIT = 'mL' WHERE DRUG_CONCEPT_CODE = 'OMOP420658' AND   INGREDIENT_CONCEPT_CODE = '8536' AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 10 AND   NUMERATOR_UNIT = '[U]' AND   DENOMINATOR_VALUE IS NULL AND   DENOMINATOR_UNIT = 'mg';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 10000,       DENOMINATOR_UNIT = 'mL' WHERE DRUG_CONCEPT_CODE = 'OMOP420659' AND   INGREDIENT_CONCEPT_CODE = '8536' AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 10 AND   NUMERATOR_UNIT = '[U]' AND   DENOMINATOR_VALUE IS NULL AND   DENOMINATOR_UNIT = 'mg';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 10000,       DENOMINATOR_UNIT = 'mL' WHERE DRUG_CONCEPT_CODE = 'OMOP420660' AND   INGREDIENT_CONCEPT_CODE = '8536' AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 10 AND   NUMERATOR_UNIT = '[U]' AND   DENOMINATOR_VALUE IS NULL AND   DENOMINATOR_UNIT = 'mg';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 10000,       DENOMINATOR_UNIT = 'mL' WHERE DRUG_CONCEPT_CODE = 'OMOP420661' AND   INGREDIENT_CONCEPT_CODE = '8536' AND   AMOUNT_VALUE IS NULL AND   AMOUNT_UNIT IS NULL AND   NUMERATOR_VALUE = 10 AND   NUMERATOR_UNIT = '[U]' AND   DENOMINATOR_VALUE IS NULL AND   DENOMINATOR_UNIT = 'mg';

/*
--checked that denominator_unit=Quant factor unit,updated to make denominator_value=quant factor
MERGE  INTO ds_stage ds
USING   (
select distinct a.DRUG_CONCEPT_CODE
 from ds_stage a
 join concept_stage c on c.concept_code=a.drug_concept_code and c.vocabulary_id='RxNorm Extension'
where denominator_value!=regexp_substr (concept_name,'^\d+(\.\d+)?')
and a.DRUG_CONCEPT_CODE not in (
select distinct a.DRUG_CONCEPT_CODE
 from ds_stage a join ds_stage b 
 on a.drug_concept_code = b.drug_concept_code 
 where a.DENOMINATOR_VALUE != b.DENOMINATOR_VALUE)
 )  d 

ON (d.DRUG_CONCEPT_CODE=ds.DRUG_CONCEPT_CODE)
                   
WHEN MATCHED THEN UPDATE
SET DENOMINATOR_VALUE=DENOMINATOR_VALUE/1000,
    NUMERATOR_VALUE=NUMERATOR_VALUE/1000
 ;

 -- update denominator and numerator keeping in mind Quant factor
MERGE  INTO ds_stage ds
USING   (
select distinct a.DRUG_CONCEPT_CODE
 from ds_stage a
 join concept_stage c on c.concept_code=a.drug_concept_code and c.vocabulary_id='RxNorm Extension'
where denominator_value!=regexp_substr (concept_name,'^\d+(\.\d+)?')
and a.DRUG_CONCEPT_CODE  in (
select distinct a.DRUG_CONCEPT_CODE
 from ds_stage a join ds_stage b 
 on a.drug_concept_code = b.drug_concept_code 
 where a.DENOMINATOR_VALUE != b.DENOMINATOR_VALUE)
 and length (denominator_value)>3  and (length (regexp_substr (concept_name,'^\d+(\.\d+)?'))<3 or (regexp_substr (concept_name,'^\d+(\.\d+)?')) like '%.%')
 )  d 

ON (d.DRUG_CONCEPT_CODE=ds.DRUG_CONCEPT_CODE)
                   
WHEN MATCHED THEN UPDATE
SET DENOMINATOR_VALUE=DENOMINATOR_VALUE/1000,
    NUMERATOR_VALUE=NUMERATOR_VALUE/1000
 ;   
*/
--update drugs that have soluble and solid ingredients in the same drug 
update ds_stage ds
set numerator_value=amount_value,numerator_unit=amount_unit,amount_unit=null,amount_value=null,
denominator_unit='mL'
where drug_concept_code in (
select drug_concept_code from ds_Stage a join ds_stage b using (drug_concept_code) 
where a.amount_value is not null 
and b.numerator_value is not null and b.DENOMINATOR_UNIT='mL')
and amount_value is not null;

update ds_stage ds
set numerator_value=amount_value,numerator_unit=amount_unit,amount_unit=null,amount_value=null,
denominator_unit='mg'
where drug_concept_code in (
select drug_concept_code from ds_Stage a join ds_stage b using (drug_concept_code) 
where a.amount_value is not null 
and b.numerator_value is not null and b.DENOMINATOR_UNIT='mg')
and amount_value is not null;

--rounding

update ds_stage
set 
AMOUNT_VALUE=round(AMOUNT_VALUE, 3-floor(log(10, AMOUNT_VALUE))-1),
NUMERATOR_VALUE=round(NUMERATOR_VALUE, 3-floor(log(10, NUMERATOR_VALUE))-1),
DENOMINATOR_VALUE=round(DENOMINATOR_VALUE, 3-floor(log(10, DENOMINATOR_VALUE))-1)
;
commit;

--update different denominator units
MERGE  INTO ds_stage ds
USING   (
select distinct a.DRUG_CONCEPT_CODE, regexp_substr (concept_name,'^\d+(\.\d+)?') as cx
 from ds_stage a join ds_stage b 
 on a.drug_concept_code = b.drug_concept_code 
 join concept_stage c on c.concept_code=a.drug_concept_code and c.vocabulary_id='RxNorm Extension'
 where a.DENOMINATOR_VALUE != b.DENOMINATOR_VALUE
 )  d 

ON (d.DRUG_CONCEPT_CODE=ds.DRUG_CONCEPT_CODE)
                   
WHEN MATCHED THEN UPDATE
SET DENOMINATOR_VALUE=cx
WHERE d.DRUG_CONCEPT_CODE=ds.DRUG_CONCEPT_CODE
 ;
 commit;

--percent
update ds_stage
set numerator_unit=amount_unit,NUMERATOR_VALUE=AMOUNT_VALUE,AMOUNT_VALUE=null,amount_unit=null
where  amount_unit ='%' 
;

UPDATE DS_STAGE   SET NUMERATOR_VALUE = 25 WHERE DRUG_CONCEPT_CODE = 'OMOP303266';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 25 WHERE DRUG_CONCEPT_CODE = 'OMOP303267';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 25 WHERE DRUG_CONCEPT_CODE = 'OMOP303268';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 1 WHERE DRUG_CONCEPT_CODE = 'OMOP317478';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 1 WHERE DRUG_CONCEPT_CODE = 'OMOP317478';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 1 WHERE DRUG_CONCEPT_CODE = 'OMOP317479';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 1 WHERE DRUG_CONCEPT_CODE = 'OMOP317479';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 1 WHERE DRUG_CONCEPT_CODE = 'OMOP317480';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 1 WHERE DRUG_CONCEPT_CODE = 'OMOP317480';
UPDATE DS_STAGE   SET DENOMINATOR_UNIT = 'mL' WHERE DRUG_CONCEPT_CODE in ( 'OMOP420658','OMOP420659','OMOP420660','OMOP420661') ;

update ds_stage
set NUMERATOR_VALUE=NUMERATOR_VALUE*10,NUMERATOR_UNIT='mg',DENOMINATOR_VALUE=null,DENOMINATOR_UNIT='mL' 
where DENOMINATOR_UNIT='{actuat}' and NUMERATOR_UNIT='%'
;
update ds_stage 
set NUMERATOR_VALUE=100,DENOMINATOR_VALUE=null,DENOMINATOR_UNIT=null
where NUMERATOR_UNIT='%' and NUMERATOR_VALUE  in ('0.000283','0.1','35.3');

delete ds_Stage where NUMERATOR_UNIT='%' and DENOMINATOR_UNIT is not null;

--delete huge dosages
delete ds_stage where drug_concept_code in (
select  drug_concept_code from ds_stage 
where (( lower (numerator_unit) in ('mg') and lower (denominator_unit) in ('ml','g') or  lower (numerator_unit) in ('g') and lower (denominator_unit) in ('l') ) and numerator_value / denominator_value > 1000 )
or (lower (numerator_unit) in ('g') and lower (denominator_unit) in ('ml') and numerator_value / denominator_value > 1));

delete ds_stage where ( (AMOUNT_UNIT='%' and amount_value>100) or (NUMERATOR_UNIT='%' and NUMERATOR_VALUE>100));

--delete deprecated ingredients
delete ds_stage where INGREDIENT_CONCEPT_CODE in (
select distinct INGREDIENT_CONCEPT_CODE from ds_stage s 
left join drug_concept_stage b on b.concept_code = s.INGREDIENT_CONCEPT_CODE and b.concept_class_id = 'Ingredient'
join concept c on  s.INGREDIENT_CONCEPT_CODE =c.concept_code and c.VOCABULARY_ID like 'Rx%' and c.INVALID_REASON='D'
where b.concept_code is null);

--kind of strange drugs
delete ds_Stage where drug_concept_code in (select DRUG_CONCEPT_CODE from ds_Stage where NUMERATOR_UNIT='mg' and DENOMINATOR_UNIT='mg' and NUMERATOR_VALUE/DENOMINATOR_VALUE>1);

commit;


truncate table internal_relationship_stage;
insert into internal_relationship_stage (concept_code_1,concept_code_2)
--Drug to form
select distinct dc.concept_code,c2.concept_code
from drug_concept_stage dc 
join concept c on c.concept_code=dc.concept_code and c.vocabulary_id='RxNorm Extension' and dc.concept_class_id='Drug Product'
join concept_relationship cr on c.concept_id=concept_id_1 and cr.invalid_reason is null
join concept c2 on concept_id_2=c2.concept_id and c2.concept_class_id='Dose Form' 
and c2.VOCABULARY_ID like 'Rx%' and c2.invalid_reason is null 
--where regexp_like (c.concept_name,c2.concept_name) --Problem with Transdermal patch/system
;
insert into internal_relationship_stage (concept_code_1,concept_code_2)
--Drug to BN
select distinct dc.concept_code,c2.concept_code
from drug_concept_stage dc 
join concept c on c.concept_code=dc.concept_code and c.vocabulary_id='RxNorm Extension' and dc.concept_class_id='Drug Product'
join concept_relationship cr on c.concept_id=concept_id_1 and cr.invalid_reason is null
join concept c2 on concept_id_2=c2.concept_id and c2.concept_class_id='Brand Name' and c2.VOCABULARY_ID like 'Rx%' and c2.invalid_reason is null 
where regexp_like (c.concept_name,c2.concept_name)
;
insert into internal_relationship_stage (concept_code_1,concept_code_2)
select distinct DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE
from ds_Stage
;
insert into internal_relationship_stage (concept_code_1,concept_code_2)
--Drug to supplier
select distinct dc.concept_code,c2.concept_code
from drug_concept_stage dc 
join concept c on c.concept_code=dc.concept_code and c.vocabulary_id='RxNorm Extension' and dc.concept_class_id='Drug Product'
join concept_relationship cr on c.concept_id=concept_id_1 and cr.invalid_reason is null
join concept c2 on concept_id_2=c2.concept_id and c2.concept_class_id='Supplier' and c2.VOCABULARY_ID like 'Rx%' and c2.invalid_reason is null 
;
--insert relationships to those packs that do not have Pack's BN
insert into internal_relationship_stage (concept_code_1,concept_code_2)
select distinct a.concept_code,c2.concept_code
 from concept a join concept_relationship b on concept_id_1=a.concept_id and a.vocabulary_id='RxNorm Extension'
and a.concept_class_id like '%Branded%Pack%'
left join concept c2 on c2.concept_name=replace(replace(regexp_substr(regexp_substr (a.concept_name, 'Pack\s\[.*\]'),'\[.*\]'),'['),']')
and c2.vocabulary_id like 'RxNorm%' and c2.concept_class_id='Brand Name'
where concept_id_1 not in (
select concept_id_1 from concept a join concept_relationship b on concept_id_1=a.concept_id and a.vocabulary_id='RxNorm Extension'
and a.concept_class_id like '%Pack%'
join concept c on concept_id_2=c.concept_id and c.CONCEPT_CLASS_ID='Brand Name' and b.invalid_reason is null);

--Delete baxter(where baxter and baxter ltd)
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP432125' AND   CONCEPT_CODE_2 = 'OMOP439843';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP431603' AND   CONCEPT_CODE_2 = 'OMOP439843';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP430700' AND   CONCEPT_CODE_2 = 'OMOP439843';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP425698' AND   CONCEPT_CODE_2 = 'OMOP440161';

--Packs BN

DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP339685' AND   CONCEPT_CODE_2 = 'OMOP337535';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP339638' AND   CONCEPT_CODE_2 = 'OMOP332839';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP339638' AND   CONCEPT_CODE_2 = 'OMOP335369';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP339724' AND   CONCEPT_CODE_2 = 'OMOP332839';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP339724' AND   CONCEPT_CODE_2 = 'OMOP335369';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP339725' AND   CONCEPT_CODE_2 = 'OMOP335369';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP339764' AND   CONCEPT_CODE_2 = 'OMOP332839';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP339764' AND   CONCEPT_CODE_2 = 'OMOP335369';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP339816' AND   CONCEPT_CODE_2 = 'OMOP337535';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP340066' AND   CONCEPT_CODE_2 = 'OMOP337535';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP340021' AND   CONCEPT_CODE_2 = 'OMOP337535';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP339872' AND   CONCEPT_CODE_2 = 'OMOP337535';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP339858' AND   CONCEPT_CODE_2 = 'OMOP337535';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP340000' AND   CONCEPT_CODE_2 = 'OMOP335369';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP339960' AND   CONCEPT_CODE_2 = 'OMOP335369';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP339960' AND   CONCEPT_CODE_2 = 'OMOP332839';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572794' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572847' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572888' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572925' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572982' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572989' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573017' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573133' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573182' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573216' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573251' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573269' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573316' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573326' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573372' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573421' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573424' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573452' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573458' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573503' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573506' AND   CONCEPT_CODE_2 = '352943';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572794' AND   CONCEPT_CODE_2 = 'OMOP571753';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572888' AND   CONCEPT_CODE_2 = 'OMOP571753';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572982' AND   CONCEPT_CODE_2 = 'OMOP571753';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572989' AND   CONCEPT_CODE_2 = 'OMOP571753';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573017' AND   CONCEPT_CODE_2 = 'OMOP571753';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573182' AND   CONCEPT_CODE_2 = 'OMOP571753';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573216' AND   CONCEPT_CODE_2 = 'OMOP571753';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573326' AND   CONCEPT_CODE_2 = 'OMOP571753';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573372' AND   CONCEPT_CODE_2 = 'OMOP571753';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573421' AND   CONCEPT_CODE_2 = 'OMOP571753';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573424' AND   CONCEPT_CODE_2 = 'OMOP571753';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573458' AND   CONCEPT_CODE_2 = 'OMOP571753';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573506' AND   CONCEPT_CODE_2 = 'OMOP571753';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572847' AND   CONCEPT_CODE_2 = 'OMOP570448';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572925' AND   CONCEPT_CODE_2 = 'OMOP570448';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573133' AND   CONCEPT_CODE_2 = 'OMOP570448';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573251' AND   CONCEPT_CODE_2 = 'OMOP570448';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573269' AND   CONCEPT_CODE_2 = 'OMOP570448';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573316' AND   CONCEPT_CODE_2 = 'OMOP570448';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573452' AND   CONCEPT_CODE_2 = 'OMOP570448';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573503' AND   CONCEPT_CODE_2 = 'OMOP570448';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP420941' AND   CONCEPT_CODE_2 = 'OMOP336140';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP420949' AND   CONCEPT_CODE_2 = 'OMOP336140';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572812' AND   CONCEPT_CODE_2 = 'OMOP569970';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572814' AND   CONCEPT_CODE_2 = 'OMOP572251';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572829' AND   CONCEPT_CODE_2 = 'OMOP572079';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572832' AND   CONCEPT_CODE_2 = 'OMOP334155';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572835' AND   CONCEPT_CODE_2 = 'OMOP570365';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572838' AND   CONCEPT_CODE_2 = 'OMOP434173';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572858' AND   CONCEPT_CODE_2 = 'OMOP333380';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572861' AND   CONCEPT_CODE_2 = 'OMOP571775';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572861' AND   CONCEPT_CODE_2 = 'OMOP571394';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572881' AND   CONCEPT_CODE_2 = '352555';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572923' AND   CONCEPT_CODE_2 = 'OMOP572251';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572928' AND   CONCEPT_CODE_2 = 'OMOP570811';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572928' AND   CONCEPT_CODE_2 = 'OMOP572263';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572961' AND   CONCEPT_CODE_2 = 'OMOP333380';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572991' AND   CONCEPT_CODE_2 = '352555';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP572992' AND   CONCEPT_CODE_2 = 'OMOP334155';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573012' AND   CONCEPT_CODE_2 = 'OMOP571351';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573012' AND   CONCEPT_CODE_2 = '58328';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573013' AND   CONCEPT_CODE_2 = 'OMOP334155';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573021' AND   CONCEPT_CODE_2 = 'OMOP571439';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573035' AND   CONCEPT_CODE_2 = 'OMOP571371';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573041' AND   CONCEPT_CODE_2 = 'OMOP572263';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573041' AND   CONCEPT_CODE_2 = 'OMOP571272';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573057' AND   CONCEPT_CODE_2 = 'OMOP334155';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573066' AND   CONCEPT_CODE_2 = 'OMOP569970';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573077' AND   CONCEPT_CODE_2 = 'OMOP569970';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573100' AND   CONCEPT_CODE_2 = 'OMOP334155';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573507' AND   CONCEPT_CODE_2 = '352555';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573301' AND   CONCEPT_CODE_2 = '352555';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573288' AND   CONCEPT_CODE_2 = '352555';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573250' AND   CONCEPT_CODE_2 = '352555';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573138' AND   CONCEPT_CODE_2 = '352555';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573108' AND   CONCEPT_CODE_2 = '352555';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573478' AND   CONCEPT_CODE_2 = 'OMOP571351';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573196' AND   CONCEPT_CODE_2 = 'OMOP571351';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573383' AND   CONCEPT_CODE_2 = 'OMOP571322';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573373' AND   CONCEPT_CODE_2 = 'OMOP334155';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573353' AND   CONCEPT_CODE_2 = 'OMOP334155';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573297' AND   CONCEPT_CODE_2 = 'OMOP334155';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573522' AND   CONCEPT_CODE_2 = 'OMOP571012';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573267' AND   CONCEPT_CODE_2 = 'OMOP571828';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573238' AND   CONCEPT_CODE_2 = 'OMOP572315';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573367' AND   CONCEPT_CODE_2 = 'OMOP335602';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573405' AND   CONCEPT_CODE_2 = 'OMOP572079';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573210' AND   CONCEPT_CODE_2 = 'OMOP571751';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573376' AND   CONCEPT_CODE_2 = 'OMOP571371';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573172' AND   CONCEPT_CODE_2 = 'OMOP570221';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573172' AND   CONCEPT_CODE_2 = 'OMOP571433';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573478' AND   CONCEPT_CODE_2 = '58328';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573196' AND   CONCEPT_CODE_2 = '58328';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573463' AND   CONCEPT_CODE_2 = 'OMOP333380';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573402' AND   CONCEPT_CODE_2 = 'OMOP333380';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573393' AND   CONCEPT_CODE_2 = 'OMOP333380';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573300' AND   CONCEPT_CODE_2 = 'OMOP333380';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573183' AND   CONCEPT_CODE_2 = 'OMOP333380';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573267' AND   CONCEPT_CODE_2 = 'OMOP571237';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573271' AND   CONCEPT_CODE_2 = 'OMOP571972';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573460' AND   CONCEPT_CODE_2 = 'OMOP570215';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573119' AND   CONCEPT_CODE_2 = 'OMOP570740';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573132' AND   CONCEPT_CODE_2 = 'OMOP571249';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573144' AND   CONCEPT_CODE_2 = 'OMOP571698';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573144' AND   CONCEPT_CODE_2 = 'OMOP337652';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573173' AND   CONCEPT_CODE_2 = 'OMOP571249';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573181' AND   CONCEPT_CODE_2 = 'OMOP571775';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573181' AND   CONCEPT_CODE_2 = 'OMOP571394';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573199' AND   CONCEPT_CODE_2 = 'OMOP570811';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573199' AND   CONCEPT_CODE_2 = '203169';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573215' AND   CONCEPT_CODE_2 = 'OMOP571394';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573222' AND   CONCEPT_CODE_2 = 'OMOP571394';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573215' AND   CONCEPT_CODE_2 = 'OMOP569968';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573222' AND   CONCEPT_CODE_2 = 'OMOP569968';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573238' AND   CONCEPT_CODE_2 = '225684';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573259' AND   CONCEPT_CODE_2 = 'OMOP570740';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573270' AND   CONCEPT_CODE_2 = 'OMOP570365';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573278' AND   CONCEPT_CODE_2 = 'OMOP333665';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573314' AND   CONCEPT_CODE_2 = 'OMOP571249';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573345' AND   CONCEPT_CODE_2 = 'OMOP570091';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573350' AND   CONCEPT_CODE_2 = 'OMOP571249';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573399' AND   CONCEPT_CODE_2 = 'OMOP571439';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573422' AND   CONCEPT_CODE_2 = 'OMOP569837';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573422' AND   CONCEPT_CODE_2 = 'OMOP333665';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573428' AND   CONCEPT_CODE_2 = '151629';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = 'OMOP573428' AND   CONCEPT_CODE_2 = 'OMOP570803';


--delete deprecated concepts
delete internal_relationship_stage where concept_code_2 in (

select concept_code  from concept c where c.VOCABULARY_ID like 'Rx%' and c.INVALID_REASON='D' and concept_class_id='Ingredient');


commit;

truncate table pc_stage;
insert into pc_stage (PACK_CONCEPT_CODE,DRUG_CONCEPT_CODE,AMOUNT,BOX_SIZE)
select c.CONCEPT_CODE,c2.CONCEPT_CODE,AMOUNT,BOX_SIZE
from pack_content join concept c on PACK_CONCEPT_ID=c.CONCEPT_ID and c.vocabulary_id='RxNorm Extension'
join concept c2 on DRUG_CONCEPT_ID=c2.CONCEPT_ID;

--fix 2 equal components
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339574' AND   DRUG_CONCEPT_CODE = '197659' AND   AMOUNT = 12;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339579' AND   DRUG_CONCEPT_CODE = '311704' AND   AMOUNT IS NULL;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339579' AND   DRUG_CONCEPT_CODE = '317128' AND   AMOUNT IS NULL;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339728' AND   DRUG_CONCEPT_CODE = '1363273' AND   AMOUNT = 7;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339876' AND   DRUG_CONCEPT_CODE = '864686' AND   AMOUNT IS NULL;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339876' AND   DRUG_CONCEPT_CODE = '1117531' AND   AMOUNT IS NULL;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339900' AND   DRUG_CONCEPT_CODE = '392651' AND   AMOUNT IS NULL;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339900' AND   DRUG_CONCEPT_CODE = '197662' AND   AMOUNT IS NULL;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339913' AND   DRUG_CONCEPT_CODE = '199797' AND   AMOUNT IS NULL;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339913' AND   DRUG_CONCEPT_CODE = '199796' AND   AMOUNT IS NULL;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP340051' AND   DRUG_CONCEPT_CODE = '1363273' AND   AMOUNT = 7;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP340128' AND   DRUG_CONCEPT_CODE = '197659' AND   AMOUNT = 12;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339633' AND   DRUG_CONCEPT_CODE = '310463' AND   AMOUNT = 5;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339814' AND   DRUG_CONCEPT_CODE = '310463' AND   AMOUNT = 5;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339886' AND   DRUG_CONCEPT_CODE = '312309' AND   AMOUNT = 6;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339886' AND   DRUG_CONCEPT_CODE = '312308' AND   AMOUNT = 109;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339895' AND   DRUG_CONCEPT_CODE = '312309' AND   AMOUNT = 6;
DELETE FROM PC_STAGE WHERE PACK_CONCEPT_CODE = 'OMOP339895' AND   DRUG_CONCEPT_CODE = '312308' AND   AMOUNT = 109;
UPDATE PC_STAGE   SET AMOUNT = 12 WHERE PACK_CONCEPT_CODE = 'OMOP339633' AND   DRUG_CONCEPT_CODE = '310463' AND   AMOUNT = 7;
UPDATE PC_STAGE   SET AMOUNT = 12 WHERE PACK_CONCEPT_CODE = 'OMOP339814' AND   DRUG_CONCEPT_CODE = '310463' AND   AMOUNT = 7;

commit;

truncate table relationship_to_concept;
insert into relationship_to_concept (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE)
select a.concept_code, a.VOCABULARY_ID,b.concept_id,1
 from drug_concept_stage a 
join concept b on a.concept_code=b.concept_code and b.vocabulary_id in ('RxNorm','RxNorm Extension') and a.concept_class_id in ('Dose Form','Brand Name','Supplier','Ingredient') ;

insert into relationship_to_concept (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select a.concept_code, a.VOCABULARY_ID,b.concept_id,1,1
 from drug_concept_stage a 
join concept b on a.concept_code=b.concept_code and a.concept_class_id='Unit' and b.vocabulary_id='UCUM' ;

UPDATE RELATIONSHIP_TO_CONCEPT   SET CONCEPT_ID_2 = 19011438
WHERE CONCEPT_CODE_1 = '1428040';

UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 8576,
       CONVERSION_FACTOR = 0.001
WHERE CONCEPT_CODE_1 = 'ug'
AND   CONCEPT_ID_2 = 9655
;


--strange staff
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP572936'
AND   CONCEPT_CODE_2 = '225684';
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573198'
AND   CONCEPT_CODE_2 = 'OMOP571371';
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573146'
AND   CONCEPT_CODE_2 = 'OMOP571828';
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573039'
AND   CONCEPT_CODE_2 = '151629';
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP572936'
AND   CONCEPT_CODE_2 = 'OMOP572315';
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP572882'
AND   CONCEPT_CODE_2 = 'OMOP333380';
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP572848'
AND   CONCEPT_CODE_2 = 'OMOP571012';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573146'
AND   CONCEPT_CODE_2 = 'OMOP571237';
