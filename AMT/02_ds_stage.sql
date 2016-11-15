/*
create table ds_0 as
select sourceid,destinationid, UNITID, VALUE from RF2_SS_STRENGTH_REFSET a
join SCT2_RELA_FULL_AU b on referencedComponentId=b.id
--join drug_concept_stage c on c.concept_code=destinationid
--join drug_concept_stage d on d.concept_code=sourceid
;
*/
--in ds_0 denominator unit is always either 1 or null;

drop table ds_0_1_1 ;
create table ds_0_1_1 as -- still only MP
select distinct SOURCEID as drug_concept_code,DESTINATIONID as ingredient_concept_Code, b.concept_name,
case when lower(a.concept_name) like '%/each%' or lower(a.concept_name) like '%/application%' or lower(a.concept_name) like '%/dose%' or lower(a.concept_name) like '%/square' then VALUE else null end as amount_value,
case when lower(a.concept_name) like '%/each%' or lower(a.concept_name) like '%/application%' or lower(a.concept_name) like '%/dose%' or lower(a.concept_name) like '%/square' then regexp_replace(lower(a.concept_name),'/each|/square|/dose|/application','',1,0,'i') else null end as amount_unit,
case when lower(a.concept_name) not like '%/each%' and lower(a.concept_name) not like '%/application%' and lower(a.concept_name) not like '%/dose%' and lower(a.concept_name) not like '%/square' then VALUE else null end as numerator_value,
case when lower(a.concept_name) not like '%/each%' and lower(a.concept_name) not like '%/application%' and lower(a.concept_name) not like '%/dose%' and lower(a.concept_name) not like '%/square' then regexp_replace (a.concept_name, '/.*') else null end as numerator_unit,
case when lower(a.concept_name) not like '%/each%' and lower(a.concept_name) not like '%/application%' and lower(a.concept_name) not like '%/dose%' and lower(a.concept_name) not like '%/square' then replace(regexp_substr(a.concept_name, '/.*'),'/') else null end as denominator_unit,
case when lower(a.concept_name) not like '%/each%' and lower(a.concept_name) not like '%/application%' and lower(a.concept_name) not like '%/dose%' and lower(a.concept_name) not like '%/square'
then regexp_replace(regexp_replace(regexp_substr (lower(b.concept_name),'[0-9].*/[0-9]\.?[0-9]?\s(mg|ml|g|l|actuation|hour|square)?'),'.*/'),'\s.*','',1,1,'i') else null end as new_denom_value
--case when lower(a.concept_name) not like '%each%' and lower(a.concept_name) not like '%application%' and lower(a.concept_name) not like '%dose%' then '1' else null end as denominator_value
from ds_0 c
join concept_stage_sn a on  a.concept_code=c.UNITID
join drug_concept_stage b on SOURCEID=b.concept_code
;
update ds_0_1_1 
set amount_value=null, amount_unit=null
where lower(amount_unit)='ml';


update ds_0_1_1
set numerator_value=numerator_value*new_denom_value where new_denom_value is not null
and DENOMINATOR_UNIT not in ('24 hours','16 hours');
 
/*drop table ds_0_1_2 ;
create table ds_0_1_2 as--ckeck 2 joins and 1 join.nothing found
select  c.concept_code as  drug_concept_code, INGREDIENT_CONCEPT_CODE, amount_value,amount_unit,numerator_value,numerator_unit,new_denom_value,denominator_unit
from ds_0_1_1 a join RF2_FULL_RELATIONSHIPS b on a.drug_concept_code=b.sourceid
join RF2_FULL_RELATIONSHIPS b2 on b.destinationid=b2.sourceid
join drug_concept_stage c on b2.destinationid=concept_code
where c.source_concept_class_id in ('Med Product Pack','Med Product Unit','Trade Product Unit','Trade Product Pack','Contain Trade Pack')
and CONCEPT_NAME not like '%[Drug Pack]%'
and  c.concept_code not in (Select drug_concept_code from ds_0_1_1)
;
*/

drop table ds_0_1_3 ;
create table ds_0_1_3 as
select  c.concept_code as  drug_concept_code, INGREDIENT_CONCEPT_CODE, amount_value,amount_unit,numerator_value,numerator_unit,new_denom_value,denominator_unit,c.concept_name
from ds_0_1_1 a join RF2_FULL_RELATIONSHIPS b on a.drug_concept_code=destinationid
join drug_concept_stage c on sourceid=concept_code
where c.source_concept_class_id in ('Med Product Pack','Med Product Unit','Trade Product Unit','Trade Product Pack','Contain Trade Pack')
and c.CONCEPT_NAME not like '%[Drug Pack]%'
and c.concept_code not in (select drug_concept_code from ds_0_1_1)
;
drop table ds_0_1_4;
create table ds_0_1_4 as
select   c.concept_code as  drug_concept_code, INGREDIENT_CONCEPT_CODE, amount_value,amount_unit,numerator_value,numerator_unit,new_denom_value,denominator_unit,c.concept_name
from ds_0_1_1 a join RF2_FULL_RELATIONSHIPS b on a.drug_concept_code=destinationid
join RF2_FULL_RELATIONSHIPS b2 on b.sourceid=b2.destinationid
join drug_concept_stage c on b2.sourceid=concept_code
where c.source_concept_class_id in ('Med Product Pack','Med Product Unit','Trade Product Unit','Trade Product Pack','Contain Trade Pack')
and c.CONCEPT_NAME not like '%[Drug Pack]%'
;
delete ds_0_1_4 where drug_concept_Code in (select drug_concept_code from ds_0_1_1 union select drug_concept_code from ds_0_1_3);


drop table ds_0_2;
create table ds_0_2 as 
select distinct drug_concept_code, INGREDIENT_CONCEPT_CODE, amount_value,amount_unit,numerator_value,numerator_unit,new_denom_value,denominator_unit,concept_name from (
select drug_concept_code, INGREDIENT_CONCEPT_CODE, amount_value,amount_unit,numerator_value,numerator_unit,new_denom_value,denominator_unit,concept_name  from ds_0_1_3
union
select drug_concept_code, INGREDIENT_CONCEPT_CODE, amount_value,amount_unit,numerator_value,numerator_unit,new_denom_value,denominator_unit,concept_name  from ds_0_1_4
union
select drug_concept_code, INGREDIENT_CONCEPT_CODE, amount_value,amount_unit,numerator_value,numerator_unit,new_denom_value,denominator_unit,concept_name  from ds_0_1_1)
;

delete ds_0_2 where drug_concept_code in (select concept_Code from non_drug);

update ds_0_2
set amount_value=round(amount_value,5),
 numerator_value=round(numerator_value,5),
 new_denom_value=round(new_denom_value,5);
update ds_0_2
set new_denom_value=null where DENOMINATOR_UNIT='24 hours';

update ds_0_2 
set NUMERATOR_VALUE=NUMERATOR_VALUE/NEW_DENOM_VALUE 
where drug_concept_code in (
select concept_code from drug_concept_stage where regexp_like (concept_name , '/(10|5|15)\sMl')
and concept_name like '%Oral%' and regexp_like (concept_name , '\s(10|5|15)\sMl$'));

update ds_0_2
set new_denom_value=null
where drug_concept_code in (
select concept_code from drug_concept_stage where regexp_like (concept_name , '/(10|5|15)\sMl')
and concept_name like '%Oral%' and regexp_like (concept_name , '\s(10|5|15)\sMl$'));--not real volume


update ds_0_2
set amount_unit=initcap(amount_unit),
numerator_unit=initcap(numerator_unit),
denominator_unit=initcap(denominator_unit);

drop table ds_0_2_1 ;
create table ds_0_2_1 as--ckeck 2 joins and 1 join.nothing found
select distinct c.concept_code as  drug_concept_code, INGREDIENT_CONCEPT_CODE, amount_value,amount_unit,numerator_value,numerator_unit,new_denom_value,denominator_unit,c.concept_name
from ds_0_2 a join RF2_FULL_RELATIONSHIPS b on a.drug_concept_code=b.sourceid
join RF2_FULL_RELATIONSHIPS b2 on b.destinationid=b2.sourceid
join drug_concept_stage c on b2.destinationid=concept_code
where c.source_concept_class_id in ('Med Product Pack','Med Product Unit','Trade Product Unit','Trade Product Pack','Contain Trade Pack')
and c.CONCEPT_NAME not like '%[Drug Pack]%'
and  c.concept_code not in (Select drug_concept_code from ds_0_2)
;

insert into ds_0_2
select * from ds_0_2_1;


update ds_0_2
set NUMERATOR_VALUE=NUMERATOR_VALUE*(regexp_substr(regexp_substr (concept_name , ',\s\d+ Ml$'),'\d+'))/new_denom_value,
NEW_DENOM_VALUE=(regexp_substr(regexp_substr (concept_name , ',\s\d+ Ml$'),'\d+'))
where new_denom_value in ('5','10','15')  and regexp_substr (concept_name , ',\s\d+ Ml$') != ', 10 Ml' and regexp_substr (concept_name , ',\s\d+ Ml$') != ', 15 Ml' and regexp_substr (concept_name , ',\s\d+ Ml$') != ', 5 Ml';

update ds_0_2 
set NEW_DENOM_VALUE=(regexp_substr(regexp_substr (concept_name , ',\s\d+ Ml$'),'\d+')),NUMERATOR_VALUE=NUMERATOR_VALUE*(regexp_substr(regexp_substr (concept_name , ',\s\d+ Ml$'),'\d+'))
where new_denom_value is null and DENOMINATOR_UNIT='Ml' and regexp_substr (concept_name , ',\s\d+ Ml$') != ', 10 Ml' and regexp_substr (concept_name , ',\s\d+ Ml$') != ', 15 Ml' and regexp_substr (concept_name , ',\s\d+ Ml$') != ', 5 Ml';


truncate table ds_stage ;
insert into ds_stage --add box size
(DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
select distinct drug_concept_code, INGREDIENT_CONCEPT_CODE,regexp_substr(regexp_substr (b.concept_name, '(\d)+\sX\s(\d)+'),'(\d+)',1,1), amount_value,amount_unit,numerator_value,numerator_unit,new_denom_value,denominator_unit
from ds_0_2 a
join drug_concept_stage b on a.drug_concept_code=b.concept_code
where b.concept_name not like '%[Drug Pack]'
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
 from RF2_FULL_RELATIONSHIPS a join drug_concept_stage b on b.concept_code=a.sourceid
 join RF2_FULL_RELATIONSHIPS d on d.sourceid=a.destinationid
join drug_concept_stage c on c.concept_code=d.destinationid
where b.concept_class_id='Drug Product'
and c.concept_class_id='Ingredient'
and a.sourceid not in (select drug_concept_code from ds_stage)
and a.sourceid not in (select pack_concept_code from pc_stage);


update 
ds_stage
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