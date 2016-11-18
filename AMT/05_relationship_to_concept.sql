--as sequence is changing we need to introduce table with names but with no codes

drop table aut_bn_all_nc ;
create table aut_bn_all_nc as (
select concept_name_1,concept_id_2,precedence from aut_bn_2_1
union
select concept_name_1,concept_id_2,precedence from aut_bn_1);

drop table relationship_to_concept_nc ;
create table relationship_to_concept_nc as ( 
   select * from
(
select AMOUNT_UNIT as concept_name_1,CONCEPT_id_2,precedence, CONVERSION_FACTOR from aut_unit_all_mapped 
union
select concept_name_1,CONCEPT_id_2,cast (precedence as number),null from aut_supplier_all_mapped
union
select concept_name_1,CONCEPT_id_2,cast (precedence as number),null from aut_form_all_mapped
union
select concept_name_1,CONCEPT_id_2,cast (precedence as number),null from aut_bn_all_nc
))
;

drop table RELATIONSHIP_TO_CONCEPT_2 ;
create table RELATIONSHIP_TO_CONCEPT_2 as
select a.*,concept_code as concept_code_1 from relationship_to_concept_nc a join drug_concept_stage b on lower(b.concept_name)=lower(a.concept_name_1);


truncate table RELATIONSHIP_TO_CONCEPT;
insert into  RELATIONSHIP_TO_CONCEPT ( concept_code_1,  vocabulary_id_1	, concept_id_2	, precedence,CONVERSION_FACTOR) 
select distinct concept_code_1,'AMT',CONCEPT_id_2,precedence,CONVERSION_FACTOR from
RELATIONSHIP_TO_CONCEPT_2
;
insert into RELATIONSHIP_TO_CONCEPT
select concept_code_1,'AMT',CONCEPT_id_2,cast (precedence as number),null from aut_ing_all_mapped;

delete relationship_to_concept where concept_code_1='65191011000036105';

