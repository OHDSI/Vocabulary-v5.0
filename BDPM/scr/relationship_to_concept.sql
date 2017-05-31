
--Forms mapping
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code, 'BDPM', concept_id, PRECEDENCE, '' 
from AUT_FORM_ALL_MAPPED --manual table
join drug_concept_stage d on lower (d.concept_name) = lower (translation) 
;
--Brand names
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code, 'BDPM', concept_id, PRECEDENCE, '' 
from AUT_BN_MAPPED_ALL a --manual table
join drug_concept_stage d on lower (d.concept_name) = lower (a.BRAND_NAME )
;
--Units
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code, 'BDPM', CONCEPT_ID_2, PRECEDENCE, CONVERSION_FACTOR
from AUT_UNIT_ALL_MAPPED  --manual table
;
--Ingredients 
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code, 'BDPM', CONCEPT_ID, PRECEDENCE, '' 
from AUT_INGR_MAPPED_ALL  --manual table
;
--add RxNorm Extension
drop table RxE_Ing_st_0;
create table RxE_Ing_st_0 as
select a.concept_code as concept_code_1,a.concept_name as concept_name_1,
c.concept_id, c.concept_name
 from drug_concept_stage a 
join devv5.concept c on lower (a.concept_name )= lower (c.concept_name)
where a.concept_class_id = 'Ingredient' 
and a.concept_code not in (select concept_code_1 from relationship_to_concept)
and c.vocabulary_id ='RxNorm Extension' and c.concept_class_id = 'Ingredient' and c.invalid_reason is null
;
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code_1, 'BDPM', CONCEPT_ID, 1, '' 
from RxE_Ing_st_0  -- RxNormExtension name equivalence
;
--one ingredient found manualy
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
values (538, 'BDPM', 21014151, 1, '') 
--need to add manufacturer lately
;
--manufacturer
drop table RxE_Man_st_0;
create table RxE_Man_st_0 as
select a.concept_code as concept_code_1,a.concept_name as concept_name_1,
c.concept_id, c.concept_name
 concept from drug_concept_stage a 
join devv5.concept c on lower (a.concept_name )= lower (c.concept_name)
where a.concept_class_id = 'Supplier' 
and a.concept_code not in (select concept_code_1 from relationship_to_concept)
and c.vocabulary_id ='RxNorm Extension' and c.concept_class_id=  'Supplier' and c.invalid_reason is null
;
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code_1, 'BDPM', CONCEPT_ID, 1, '' 
from RxE_Man_st_0  -- RxNormExtension name equivalence
;
--Brands from RxE
drop table RxE_BR_n_st_0;
create table RxE_BR_n_st_0 as
select a.concept_code as concept_code_1,a.concept_name as concept_name_1,
c.concept_id, c.concept_name
 from drug_concept_stage a 
join devv5.concept c on lower (a.concept_name )= lower (c.concept_name)
where a.concept_class_id = 'Brand Name' 
and a.concept_code not in (select concept_code_1 from relationship_to_concept)
and c.vocabulary_id ='RxNorm Extension' and c.concept_class_id=  'Brand Name' and c.invalid_reason is null
;
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code_1, 'BDPM', CONCEPT_ID, 1, '' 
from RxE_BR_n_st_0  -- RxNormExtension name equivalence
;
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
values ('OMOP419267','BDPM',		21014727, 1, '' 	);
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
values (
'OMOP419574',	'BDPM',21017079	, 1, '' 
) ;insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
values (
'OMOP419607',	'BDPM',	21016373	, 1, '' 
) ;insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
values (
'OMOP422612',	'BDPM',	21018267	, 1, '' 
) ;insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
values (
'OMOP423147',	'BDPM',	21016214	, 1, '' 
) ;insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
values (
'OMOP424729',	'BDPM',	21014875, 1, '' )
;
