create table ds_0 as
select sourceid,destinationid, UNITID, VALUE from RF2_SS_STRENGTH_REFSET a
join SCT2_RELA_FULL_AU b on referencedComponentId=b.id
;

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
where c.source_concept_class_id in ('Med Product Pack','Med Product Unit','Trade Product Unit','Trade Product Pack','Contain Trade Pack')
and c.CONCEPT_NAME not like '%[Drug Pack]%'
and c.concept_code not in (select drug_concept_code from ds_0_1_1)
;

create table ds_0_1_4 as
select   c.concept_code as  drug_concept_code, INGREDIENT_CONCEPT_CODE, amount_value,amount_unit,numerator_value,numerator_unit,denominator_unit,c.concept_name
from ds_0_1_1 a join RF2_FULL_RELATIONSHIPS b on a.drug_concept_code=destinationid
join RF2_FULL_RELATIONSHIPS b2 on b.sourceid=b2.destinationid
join drug_concept_stage c on b2.sourceid=concept_code
where c.source_concept_class_id in ('Med Product Pack','Med Product Unit','Trade Product Unit','Trade Product Pack','Contain Trade Pack')
and c.CONCEPT_NAME not like '%[Drug Pack]%'
;
delete ds_0_1_4 where drug_concept_Code in (select drug_concept_code from ds_0_1_1 union select drug_concept_code from ds_0_1_3);




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
select concept_code from drug_concept_stage where regexp_like (concept_name , '/5\sMl')
and concept_name like '%Oral%' and regexp_like (concept_name , '\s5\sMl$'));

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

drop table ds_0_3 ;
create table ds_0_3 as
select a.*, regexp_substr(regexp_substr (concept_name, '(\d)+\sX\s(\d)+'),'(\d+)',1,1) as box_size 
from ds_0_2 a;

update ds_0_3 
set box_size=regexp_substr(regexp_substr(concept_name, '(,\s\d+$)|(,\s\d+,\s.*$)'),'\d+') 
where amount_value is not null and box_size is null;

update ds_0_3
set new_denom_value=null where amount_unit is not null;

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
 from RF2_FULL_RELATIONSHIPS a join drug_concept_stage b on b.concept_code=a.sourceid
 join RF2_FULL_RELATIONSHIPS d on d.sourceid=a.destinationid
join drug_concept_stage c on c.concept_code=d.destinationid
where b.concept_class_id='Drug Product'
and c.concept_class_id='Ingredient'
and a.sourceid not in (select drug_concept_code from ds_stage)
and a.sourceid not in (select pack_concept_code from pc_stage);


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
set amount_value=amount_value/1000,amount_unit='Mg' where amount_unit='Microgram' and numerator_value>999;

update ds_stage set DENOMINATOR_UNIT='Actuation' where DENOMINATOR_UNIT='Actuations';
update ds_stage set DENOMINATOR_UNIT='Ml',DENOMINATOR_VALUE=DENOMINATOR_VALUE*1000 where DENOMINATOR_UNIT='L';

