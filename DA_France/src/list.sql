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
 and PRODUCT_DESC not like '%DCI%'
 and upper(PRODUCT_DESC) not in (select upper(concept_name) from devv5.concept where concept_class_id like 'Ingredient' and standard_concept='S')
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
