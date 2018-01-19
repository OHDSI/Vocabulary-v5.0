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
