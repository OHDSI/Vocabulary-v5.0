create table ds_0_1_1 as -- still only MP
select distinct SOURCEID as drug_concept_code,DESTINATIONID as ingredient_concept_Code, b.concept_name,
case when lower(a.concept_name) like '%/each%' or lower(a.concept_name) like '%/application%' or lower(a.concept_name) like '%/dose%' or lower(a.concept_name) like '%/square' then VALUE else null end as amount_value,
case when lower(a.concept_name) like '%/each%' or lower(a.concept_name) like '%/application%' or lower(a.concept_name) like '%/dose%' or lower(a.concept_name) like '%/square' then regexp_replace(lower(a.concept_name),'/each|/square|/dose|/application','',1,0,'i') else null end as amount_unit,
case when lower(a.concept_name) not like '%/each%' and lower(a.concept_name) not like '%/application%' and lower(a.concept_name) not like '%/dose%' and lower(a.concept_name) not like '%/square' then VALUE else null end as numerator_value,
case when lower(a.concept_name) not like '%/each%' and lower(a.concept_name) not like '%/application%' and lower(a.concept_name) not like '%/dose%' and lower(a.concept_name) not like '%/square' then regexp_replace (a.concept_name, '/.*') else null end as numerator_unit,
case when lower(a.concept_name) not like '%/each%' and lower(a.concept_name) not like '%/application%' and lower(a.concept_name) not like '%/dose%' and lower(a.concept_name) not like '%/square' then replace(regexp_substr(a.concept_name, '/.*'),'/') else null end as denominator_unit
from ds_0 c
join concept_stage_sn a on  a.concept_code=c.UNITID
join drug_concept_stage b on SOURCEID=b.concept_code
;
update ds_0_1_1 
set amount_value=null, amount_unit=null
where lower(amount_unit)='ml';

create table ds_0_1_3 as
select  c.concept_code as  drug_concept_code, INGREDIENT_CONCEPT_CODE, amount_value,amount_unit,numerator_value,numerator_unit,denominator_unit,c.concept_name
from ds_0_1_1 a join RF2_FULL_RELATIONSHIPS b on a.drug_concept_code=destinationid
join drug_concept_stage c on sourceid=concept_code
where c.source_concept_class_id in ('Med Product Pack','Med Product Unit','Trade Product Unit','Trade Product Pack','Containered Pack')
and c.CONCEPT_NAME not like '%[Drug Pack]%'
and c.concept_code not in (select drug_concept_code from ds_0_1_1)
;
create table ds_0_1_4 as
select   c.concept_code as  drug_concept_code, INGREDIENT_CONCEPT_CODE, amount_value,amount_unit,numerator_value,numerator_unit,denominator_unit,c.concept_name
from ds_0_1_1 a join RF2_FULL_RELATIONSHIPS b on a.drug_concept_code=destinationid
join RF2_FULL_RELATIONSHIPS b2 on b.sourceid=b2.destinationid
join drug_concept_stage c on b2.sourceid=concept_code
where c.source_concept_class_id in ('Med Product Pack','Med Product Unit','Trade Product Unit','Trade Product Pack','Containered Pack')
and c.CONCEPT_NAME not like '%[Drug Pack]%'
;
delete ds_0_1_4 where drug_concept_Code in (select drug_concept_code from ds_0_1_1 union select drug_concept_code from ds_0_1_3);

create table ds_0_2_0 as(
select * from (
select DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,CONCEPT_NAME,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_UNIT from ds_0_1_1 
union
select DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,CONCEPT_NAME,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_UNIT from ds_0_1_3  
union
select DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,CONCEPT_NAME,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_UNIT from ds_0_1_4)
);  

create table ds_0_2 as
select drug_concept_code, INGREDIENT_CONCEPT_CODE, amount_value,amount_unit,numerator_value,numerator_unit,denominator_unit,concept_name,
trim(regexp_replace(regexp_replace(regexp_substr(concept_name, ',\s\d+\.?(\d)+\s(mg|ml|g|l|actuations)',1,1,'i'),',\s'),'\d+\.?\d+')) as new_denom_unit,--add real volume (, 50 Ml Vial)
regexp_substr(regexp_replace(regexp_substr(concept_name, ',\s\d+\.?(\d)+\s(mg|ml|g|l|actuation)',1,1,'i'),',\s'),'\d+\.?\d+') as new_denom_value
from ds_0_2_0;

update ds_0_2 set new_denom_value=regexp_substr(regexp_replace(regexp_substr(concept_name, ',\s\d+\sX\s\d+\.?(\d)+\s(mg|ml|g|l|actuation)',1,1,'i'),',\s\d+\sX\s'),'\d+\.?\d+'),
new_denom_unit=trim(regexp_replace(regexp_replace(regexp_substr(concept_name, ',\s\d+\sX\s\d+\.?(\d)+\s(mg|ml|g|l|actuations)',1,1,'i'),',\s\d+\sX\s'),'\d+\.?\d+')) --(5 X 50 Ml Vial)
where new_denom_value is null and regexp_substr(regexp_replace(regexp_substr(concept_name, ',\s\d+\sX\s\d+\.?(\d)+\s(mg|ml|g|l|actuation)',1,1,'i'),',\s\d+\sX\s'),'\d+\.?\d+') is not null;

update ds_0_2
set new_denom_unit=trim(regexp_replace(regexp_replace(regexp_substr(concept_name, ',\s\d+\s(mg|ml|g|l|actuations)',1,1,'i'),',\s'),'\d+')),--(, 5 Ml Vial)
new_denom_value=regexp_substr(regexp_replace(regexp_substr(concept_name, ',\s\d+\s(mg|ml|g|l|actuation)',1,1,'i'),',\s'),'\d+') where new_denom_value is null and new_denom_unit is null;

update ds_0_2
set new_denom_unit=trim(regexp_replace(regexp_replace(regexp_substr(concept_name, ',\s\d+\sX\s\d+\s(mg|ml|g|l|actuations)',1,1,'i'),',\s\d+\sX\s'),'\d+')),--(, 5 X 5 Ml Vial)
new_denom_value=regexp_substr(regexp_replace(regexp_substr(concept_name, ',\s\d+\sX\s\d+\s(mg|ml|g|l|actuation)',1,1,'i'),',\s\d+\sX\s'),'\d+') where new_denom_value is null and new_denom_unit is null;

update ds_0_2
set NUMERATOR_VALUE=amount_value,NUMERATOR_UNIT=amount_unit,amount_unit=null,amount_value=null
where amount_value is not null and NEW_DENOM_UNIT is not null and NEW_DENOM_UNIT not in ('Mg','G'); 

update ds_0_2
set new_denom_value=null
where drug_concept_code in (
select concept_code from drug_concept_stage where concept_name like '%Oral%' and regexp_like (concept_name , '\s5\sMl$'));

--select distinct * from ds_0_2 where new_denom_unit is not null and denominator_unit is null; 
update ds_0_2
set numerator_value=case when new_denom_value is not null and (lower(new_denom_unit)=lower(denominator_unit) or (denominator_unit='actuation' and new_denom_unit='Actuations')) then numerator_value*new_denom_value 
when new_denom_value is not null and lower(new_denom_unit) in ('g') and lower(denominator_unit) in ('mg') and lower(NUMERATOR_UNIT)='mg' then numerator_value*new_denom_value*1000
when new_denom_value is not null and lower(new_denom_unit) in ('g') and lower(denominator_unit) in ('ml') and lower(NUMERATOR_UNIT)='mg' then numerator_value*new_denom_value
when new_denom_value is not null and lower(new_denom_unit) in ('g') and lower(denominator_unit) in ('mg') and lower(NUMERATOR_UNIT)='microgram' then numerator_value*new_denom_value*1000000
when new_denom_value is not null and lower(new_denom_unit) in ('g') and lower(denominator_unit) in ('ml') and lower(NUMERATOR_UNIT)='microgram' then numerator_value*new_denom_value
when new_denom_value is not null and lower(new_denom_unit) in ('mg') and lower(denominator_unit) in ('g') and lower(NUMERATOR_UNIT)='mg' then numerator_value*new_denom_value/1000
when new_denom_value is not null and lower(new_denom_unit) in ('ml') and lower(denominator_unit) in ('g') and lower(NUMERATOR_UNIT)='mg' then numerator_value*new_denom_value
when new_denom_value is not null and lower(new_denom_unit) in ('ml') and denominator_unit is null  then numerator_value*new_denom_value
else cast(numerator_value as number) end ;

update ds_0_2
set denominator_unit=new_denom_unit where new_denom_unit is not null and amount_unit is null;


update ds_0_2
set amount_value=round(amount_value,5),
 numerator_value=round(numerator_value,5),
 new_denom_value=round(new_denom_value,5);
 

update ds_0_2
set amount_unit=initcap(amount_unit),
numerator_unit=initcap(numerator_unit),
denominator_unit=initcap(denominator_unit);
 
update ds_0_2
set new_denom_value=null where DENOMINATOR_UNIT='24 Hours' or  DENOMINATOR_UNIT='16 Hours';

create table ds_0_3 
as
select a.*, regexp_substr(regexp_substr (concept_name, '(\d)+\sX\s(\d)+'),'(\d+)',1,1) as box_size 
from ds_0_2 a;

update ds_0_3 
set box_size=regexp_substr(regexp_substr(concept_name, '(,\s\d+$)|(,\s\d+,\s.*$)'),'\d+') 
where amount_value is not null and box_size is null;

update ds_0_3
set new_denom_value=null where amount_unit is not null;

--transform gases dosages into %
update ds_0_3
set numerator_value=case when denominator_unit in ('Ml','L') and numerator_unit='Ml' then cast(numerator_value as number)*100 else cast(numerator_value as number) end,
numerator_unit=case when denominator_unit in ('Ml','L') and numerator_unit='Ml' then '%' else numerator_unit end,
denominator_unit=case when new_denom_value is not null then denominator_unit else null end
where 
concept_name like '% Gas%') ;

truncate table ds_stage ;
insert into ds_stage --add box size
(DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
select distinct drug_concept_code, INGREDIENT_CONCEPT_CODE,box_size, amount_value,amount_unit,numerator_value,numerator_unit,new_denom_value,denominator_unit
from ds_0_3 
;
UPDATE DS_STAGE   SET AMOUNT_VALUE = NULL,       AMOUNT_UNIT = '' WHERE DRUG_CONCEPT_CODE = '80146011000036104';
UPDATE DS_STAGE   SET AMOUNT_VALUE = NULL,       AMOUNT_UNIT = '' WHERE DRUG_CONCEPT_CODE = '81257011000036108';

insert into ds_stage (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE) -- add drugs that don't have dosages
select distinct a.sourceid,a.destinationid
 from RF2_FULL_RELATIONSHIPS a join drug_concept_stage b on b.concept_code=a.sourceid
join drug_concept_stage c on c.concept_code=a.destinationid
where b.concept_class_id='Drug Product'
and c.concept_class_id='Ingredient'
and sourceid not in (select drug_concept_code from ds_stage)
and sourceid not in (select pack_concept_code from pc_stage);

insert into ds_stage (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE)
select distinct a.sourceid,d.destinationid
 from RF2_FULL_RELATIONSHIPS a 
join drug_concept_stage b on b.concept_code=a.sourceid
join RF2_FULL_RELATIONSHIPS d on d.sourceid=a.destinationid
join drug_concept_stage c on c.concept_code=d.destinationid
where b.concept_class_id='Drug Product'
and c.concept_class_id='Ingredient'
and a.sourceid not in (select drug_concept_code from ds_stage)
and b.concept_name not like '%Drug Pack%';

update ds_stage
set NUMERATOR_UNIT='Mg',NUMERATOR_VALUE=NUMERATOR_VALUE/1000
where drug_concept_code in
(select distinct   a.drug_concept_code from (
select distinct a.amount_unit, a.numerator_unit ,cs.concept_code,  cs.concept_name as canada_name, rc.concept_name as RxName  , a.drug_concept_code from ds_stage a join relationship_to_concept b on a.ingredient_concept_code = b.concept_code_1
join drug_Concept_stage cs on cs.concept_code = a.ingredient_concept_code
join devv5.concept rc on rc.concept_id = b.concept_id_2
join drug_Concept_stage rd on rd.concept_code = a.drug_concept_code
join (
select a.drug_concept_code, b.concept_id_2 from ds_stage a join relationship_to_concept b on a.ingredient_concept_code = b.concept_code_1
group by a.drug_concept_code, b.concept_id_2 having count (1) > 1) c 
on c.DRUG_CONCEPT_CODE= a.DRUG_CONCEPT_CODE and c.CONCEPT_ID_2 = b.CONCEPT_ID_2
where precedence = 1) a
join 
(
select distinct a.amount_unit, a.numerator_unit , cs.concept_name as canada_name, rc.concept_name  as RxName,a.drug_concept_code from ds_stage a join relationship_to_concept b on a.ingredient_concept_code = b.concept_code_1
join drug_Concept_stage cs on cs.concept_code = a.ingredient_concept_code
join devv5.concept rc on rc.concept_id = b.concept_id_2
join drug_Concept_stage rd on rd.concept_code = a.drug_concept_code
join (
select a.drug_concept_code, b.concept_id_2 from ds_stage a join relationship_to_concept b on a.ingredient_concept_code = b.concept_code_1
group by a.drug_concept_code, b.concept_id_2 having count (1) > 1) c 
on c.DRUG_CONCEPT_CODE= a.DRUG_CONCEPT_CODE and c.CONCEPT_ID_2 = b.CONCEPT_ID_2
where precedence = 1) b on a.RxName = b.RxName and a.drug_concept_code = b.drug_concept_code and (a.AMOUNT_UNIT !=b.amount_unit or a.NUMERATOR_UNIT != b.NUMERATOR_UNIT or a.NUMERATOR_UNIT is null and b.NUMERATOR_UNIT is not null
or a.AMOUNT_UNIT is null and b.amount_unit is not null))
and NUMERATOR_UNIT='Microgram';

update ds_stage 
set numerator_value=numerator_value/1000,numerator_unit='Mg' where numerator_unit='Microgram' and numerator_value>999;
update ds_stage 
set amount_value=amount_value/1000,amount_unit='Mg' where amount_unit='Microgram' and amount_value>999;

update ds_stage set DENOMINATOR_VALUE=null, NUMERATOR_VALUE=NUMERATOR_VALUE/5 where DRUG_CONCEPT_CODE in
(select DRUG_CONCEPT_CODE from ds_stage a join drug_concept_stage on drug_concept_code=concept_code  where DENOMINATOR_VALUE='5' and concept_name like '%Oral%Measure%');

update ds_stage set DENOMINATOR_UNIT='Actuation' where DENOMINATOR_UNIT='Actuations';
update ds_stage set DENOMINATOR_UNIT='Ml',DENOMINATOR_VALUE=DENOMINATOR_VALUE*1000 where DENOMINATOR_UNIT='L'
and drug_concept_code not in
(select SOURCEID
from RF2_FULL_RELATIONSHIPS a
where DESTINATIONID in ('122011000036104','187011000036109'));

update ds_stage a
set ingredient_concept_code=(select  s_concept_code from non_S_ing_to_S where CONCEPT_CODE=ingredient_concept_code ) where ingredient_concept_code in (select CONCEPT_CODE from non_S_ing_to_S);

update ds_stage --fix patches
set denominator_unit='Hour',denominator_value=24
where denominator_unit='24 Hours';
update ds_stage
set denominator_unit='Hour',denominator_value=16
where denominator_unit='16 Hours';

create table ds_sum as
select distinct drug_concept_code,ingredient_concept_code,BOX_SIZE,
sum (amount_value) as amount_value,
amount_unit,numerator_value,numerator_unit,denominator_value,denominator_unit from ds_stage
group by drug_concept_code,ingredient_concept_code,box_size,amount_unit,numerator_value,numerator_unit,
denominator_value,denominator_unit
;

truncate table ds_stage;
insert into ds_stage 
select * from ds_sum;

--Movicol
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 8000,       NUMERATOR_UNIT = 'Unit',       DENOMINATOR_VALUE = 20,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '94311000036106' AND   INGREDIENT_CONCEPT_CODE = '1981011000036104'; 
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 8000,       NUMERATOR_UNIT = 'Unit',       DENOMINATOR_VALUE = 20,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '94321000036104' AND   INGREDIENT_CONCEPT_CODE = '1981011000036104';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 100000,       NUMERATOR_UNIT = 'Unit',       DENOMINATOR_VALUE = 50,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '94331000036102' AND   INGREDIENT_CONCEPT_CODE = '1981011000036104';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 100000,       NUMERATOR_UNIT = 'Unit',       DENOMINATOR_VALUE = 50,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '94341000036107' AND   INGREDIENT_CONCEPT_CODE = '1981011000036104';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 46.6,       NUMERATOR_UNIT = 'Mg',       DENOMINATOR_VALUE = 25,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '652501000168101' AND   INGREDIENT_CONCEPT_CODE = '2500011000036101';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 46.6,       NUMERATOR_UNIT = 'Mg',       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '652511000168103' AND   INGREDIENT_CONCEPT_CODE = '2500011000036101';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 932,      NUMERATOR_UNIT = 'Mg',       DENOMINATOR_VALUE = 500,      DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '652521000168105' AND   INGREDIENT_CONCEPT_CODE = '2500011000036101';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 350.7,       NUMERATOR_UNIT = 'Mg',      DENOMINATOR_VALUE = 25,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '652501000168101' AND   INGREDIENT_CONCEPT_CODE = '2591011000036106';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 350.7,       NUMERATOR_UNIT = 'Mg',       DENOMINATOR_VALUE = 25,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '652511000168103' AND   INGREDIENT_CONCEPT_CODE = '2591011000036106';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 7014,       NUMERATOR_UNIT = 'Mg',       DENOMINATOR_VALUE = 500,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '652521000168105' AND   INGREDIENT_CONCEPT_CODE = '2591011000036106';
UPDATE DS_STAGE   SET DENOMINATOR_VALUE = 25,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '652501000168101' AND   INGREDIENT_CONCEPT_CODE = '2735011000036100';
UPDATE DS_STAGE   SET DENOMINATOR_VALUE = 25,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '652511000168103' AND   INGREDIENT_CONCEPT_CODE = '2735011000036100';
UPDATE DS_STAGE   SET DENOMINATOR_VALUE = 500,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '652521000168105' AND   INGREDIENT_CONCEPT_CODE = '2735011000036100';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 178.5,       NUMERATOR_UNIT = 'Mg',       DENOMINATOR_VALUE = 25,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '652501000168101' AND   INGREDIENT_CONCEPT_CODE = '2736011000036107';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 178.5,       NUMERATOR_UNIT = 'Mg',       DENOMINATOR_VALUE = 25,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '652511000168103' AND   INGREDIENT_CONCEPT_CODE = '2736011000036107';
 UPDATE DS_STAGE   SET NUMERATOR_VALUE = 3570,       NUMERATOR_UNIT = 'Mg',       DENOMINATOR_VALUE = 500,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '652521000168105' AND   INGREDIENT_CONCEPT_CODE = '2736011000036107';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 13125,       NUMERATOR_UNIT = 'Mg',       DENOMINATOR_VALUE = 25,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '652501000168101' AND   INGREDIENT_CONCEPT_CODE = '2799011000036106';
UPDATE DS_STAGE   SET NUMERATOR_VALUE = 13125,       NUMERATOR_UNIT = 'Mg', DENOMINATOR_VALUE = 25,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '652511000168103' AND   INGREDIENT_CONCEPT_CODE = '2799011000036106';
UPDATE DS_STAGE   SET AMOUNT_UNIT = '',       NUMERATOR_VALUE = 262.5,       NUMERATOR_UNIT = 'G',       DENOMINATOR_VALUE = 500,       DENOMINATOR_UNIT = 'Ml' WHERE DRUG_CONCEPT_CODE = '652521000168105' AND   INGREDIENT_CONCEPT_CODE = '2799011000036106';

--inserting Inert Tablets with '0' in amount
insert into ds_stage (drug_concept_code,ingredient_concept_code,amount_value,amount_unit)
select concept_code,'920012011000036105','0','Mg'
from drug_concept_stage 
where concept_name like '%Inert%' and concept_name not like '%Drug Pack%' and concept_class_id='Drug Product';

--bicarbonate
DELETE
FROM DS_STAGE
WHERE DRUG_CONCEPT_CODE in ('652521000168105','652501000168101','652511000168103' )
AND   INGREDIENT_CONCEPT_CODE = '2735011000036100';
UPDATE DS_STAGE
   SET DENOMINATOR_VALUE = 25
WHERE DRUG_CONCEPT_CODE = '652511000168103' AND   INGREDIENT_CONCEPT_CODE = '2500011000036101';

delete ds_stage where drug_concept_code in (select concept_code from non_drug);