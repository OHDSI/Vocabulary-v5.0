--create relationship from non-standard ingredients to standard ingredients 
create table non_S_ing_to_S as
select distinct b.concept_code,a.concept_code as s_concept_Code
from drug_concept_stage a
join drug_concept_stage b on lower(a.concept_name)=lower(b.concept_name)
where a.STANDARD_CONCEPT='S' and a.CONCEPT_CLASS_ID='Ingredient'
and b.STANDARD_CONCEPT is null and b.CONCEPT_CLASS_ID='Ingredient';

--create relationship from non-standard forms to standard forms
create table non_S_form_to_S as
select distinct b.concept_code,a.concept_code as s_concept_Code
from drug_concept_stage a
join drug_concept_stage b on lower(a.concept_name)=lower(b.concept_name)
where a.STANDARD_CONCEPT='S' and a.CONCEPT_CLASS_ID='Dose Form'
and b.STANDARD_CONCEPT is null and b.CONCEPT_CLASS_ID='Dose Form';


create table drug_to_supplier as
select distinct a.concept_code,mf.concept_Code as supplier,mf.concept_name as s_name from drug_concept_Stage a
join drug_concept_Stage mf on regexp_substr (initcap(a.concept_name), '\(.*\)+') like '%'||mf.concept_name||'%' 
where mf.concept_class_id ='Supplier'
and a.concept_class_id='Drug Product';


create table supp_upd as
select a.concept_code,a.supplier
 from  drug_to_supplier a join drug_to_supplier d on d.concept_Code=a.concept_Code
where a.supplier!=d.supplier
and length(d.s_name)<length(a.s_name);

delete drug_to_supplier where concept_code in (select concept_code from supp_upd);
insert into drug_to_supplier (concept_code,supplier) 
select concept_code,supplier from supp_upd ;


truncate table internal_relationship_stage;
insert into internal_relationship_stage
(concept_code_1,concept_code_2)

select distinct * from (
-- drug to ingr

select distinct a.drug_concept_code as concept_Code_1,
case when a.ingredient_concept_Code in (select concept_Code from non_S_ing_to_S) then s_concept_Code else a.ingredient_concept_Code end
 as concept_Code_2
from ds_stage a left join non_S_ing_to_S b 
on a.ingredient_concept_Code=b.concept_code

union

--drug to supplier

select distinct concept_code,supplier from drug_to_supplier


union

--drug to form

select b.concept_Code,
case when c.concept_code in (select concept_Code from non_S_form_to_S) then s_concept_Code else c.concept_code end as concept_Code_2
from RF2_FULL_RELATIONSHIPS a
join drug_concept_stage b on SOURCEID=b.concept_code
join drug_concept_stage c on DESTINATIONID=c.concept_code
left join non_S_form_to_S d on d.concept_code=c.concept_code
where b.concept_class_id='Drug Product' and b.concept_name not like '%[Drug Pack]'
and c.concept_class_id='Dose Form'

union

select a.sourceid,case when c.concept_code in (select concept_Code from non_S_form_to_S) then s_concept_Code else c.concept_code end as concept_Code_2
from RF2_FULL_RELATIONSHIPS a 
join drug_concept_stage d2 on d2.concept_code=a.sourceid
join RF2_FULL_RELATIONSHIPS b on a.destinationid=b.sourceid 
join drug_concept_stage c on b.destinationid=c.concept_code
left join non_S_form_to_S d on d.concept_code=c.concept_code
where c.concept_class_id='Dose Form'
and a.sourceid not in (select pack_concept_Code from pc_stage)

--drug to BN

union

 select b.concept_Code,c.concept_code from RF2_FULL_RELATIONSHIPS a
join drug_concept_stage b on SOURCEID=b.concept_code
join drug_concept_stage c on DESTINATIONID=c.concept_code
where b.source_concept_class_id in ('Trade Product Unit','Trade Product Pack','Contain Trade Pack')
and c.concept_class_id='Brand Name'

union

select a.sourceid,c.concept_code  from RF2_FULL_RELATIONSHIPS a 
join drug_concept_stage d2 on d2.concept_code=a.sourceid
join RF2_FULL_RELATIONSHIPS b on a.destinationid =b.sourceid 
join drug_concept_stage c on b.destinationid=c.concept_code
where c.concept_class_id='Brand Name'  
and a.sourceid not in (select pack_concept_Code from pc_stage)
and d2.source_concept_class_id in ('Trade Product Unit','Trade Product Pack','Contain Trade Pack')

union

--drugs from packs
select distinct DRUG_CONCEPT_CODE,c.concept_Code from pc_stage a join internal_relationship_stage b on pack_concept_code=concept_Code_1
join drug_Concept_stage c on concept_Code_2=c.concept_Code and concept_class_id='Brand Name'
)
;

--non standard concepts to standard
insert into internal_relationship_stage
(concept_code_1,concept_code_2)
select distinct * from (
select  concept_code,s_concept_Code from non_S_ing_to_S 
union
select concept_code,s_concept_Code from non_S_form_to_S );

--fix drugs with 2 forms like capsule and enteric capsule 


create table irs_upd as
select a.concept_code_1,c.concept_code
 from  internal_Relationship_stage a join drug_concept_stage b on b.concept_Code=a.concept_Code_2 and b.concept_Class_id='Dose Form'
join internal_Relationship_stage d on d.concept_Code_1=a.concept_Code_1
join drug_concept_stage c on c.concept_Code=d.concept_Code_2 and c.concept_Class_id='Dose Form'
where b.concept_code!=c.concept_code
and length(b.concept_name)<length(c.concept_name);

insert into irs_upd
select a.concept_code_1,c.concept_code
 from  internal_Relationship_stage a join drug_concept_stage b on b.concept_Code=a.concept_Code_2 and b.concept_Class_id='Dose Form'
join internal_Relationship_stage d on d.concept_Code_1=a.concept_Code_1
join drug_concept_stage c on c.concept_Code=d.concept_Code_2 and c.concept_Class_id='Dose Form'
where b.concept_code!=c.concept_code
and length(b.concept_name)=length(c.concept_name)
and b.concept_code<c.concept_code;

drop table irs_upd_2; --fix those drugs that have 3 simimlar forms (like Tablet,Coated Tablet and Film Coated Tablet)
create table irs_upd_2 as
select a.concept_code_1,a.concept_code 
from irs_upd a join irs_upd b on a.concept_code_1=b.concept_Code_1
where a.concept_code_1 in (select concept_code_1 from irs_upd group by concept_code_1,concept_code having count (1)>1) 
and a.concept_code>b.concept_code;

delete irs_upd where concept_code_1 in (select concept_code_1 from irs_upd_2) ;
insert into irs_upd 
select * from irs_upd_2;

delete internal_Relationship_stage 
where concept_code_1 in 
(select distinct a.concept_code from drug_concept_stage a 
join internal_relationship_stage s on a.concept_code = s.concept_code_1
join drug_concept_stage b on b.concept_code =s.concept_code_2
and b.concept_class_id = 'Dose Form'
where a.concept_code in (
select a.concept_code from drug_concept_stage a 
join internal_relationship_stage s on a.concept_code = s.concept_code_1
join drug_concept_stage b on b.concept_code =s.concept_code_2
and b.concept_class_id = 'Dose Form'
group by a.concept_code having count(1) >1))
and concept_code_2 in (select concept_Code from drug_concept_stage where concept_class_id='Dose Form');

insert into internal_Relationship_stage (concept_code_1,concept_code_2)
select distinct concept_code_1,concept_code from irs_upd;

delete drug_concept_stage  where concept_code in ( --dose forms that dont relate to any drug
select distinct concept_code from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
where a.concept_class_id= 'Dose Form' and b.concept_code_1 is null)
and STANDARD_CONCEPT='S';


delete internal_relationship_stage where concept_code_2='701581000168103'; --2 BN
--estragest,estracombi,estraderm
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = '933225691000036100' AND   CONCEPT_CODE_2 = '13821000168101';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = '933225691000036100' AND   CONCEPT_CODE_2 = '4174011000036102';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = '933231511000036106' AND   CONCEPT_CODE_2 = '13821000168101';
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE CONCEPT_CODE_1 = '933231511000036106' AND   CONCEPT_CODE_2 = '4174011000036102';

