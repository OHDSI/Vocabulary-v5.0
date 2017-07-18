--fill RLC
--Ingredients

select distinct a.concept_code as concept_code_1,'DA_France',f.concept_id as concept_id_2 , rank() over (partition by a.concept_code order by f.concept_id) as precedence 
from drug_concept_stage a join devv5.concept c 
on upper (c.concept_name) = upper(a.concept_name) and c.concept_class_id in ( 'Ingredient' , 'VTM', 'AU Substance')
join devv5.concept_relationship b on c.concept_id =concept_id_1
join devv5.concept f on f.concept_id=concept_id_2
where f.vocabulary_id like 'Rx%' and f.standard_concept='S'
and f.concept_class_id = 'Ingredient'
and a.concept_name like 'CYANOCOBALAMIN'
;


insert into relationship_to_concept 
select distinct a.concept_code,a.VOCABULARY_ID,c.concept_id,
rank() over (partition by a.concept_code order by concept_id_2) as precedence,
'' as conversion_factor
from drug_concept_stage a 
join ingredient_all_completed b on a.concept_name=b.concept_name
join devv5.concept c on c.concept_id=concept_id_2
where a.concept_class_id='Ingredient'
and (b.concept_name,concept_id_2) not in (select concept_name,concept_id_2 from drug_concept_stage 
join relationship_to_concept on concept_code=concept_code_1 and concept_class_id='Ingredient')
;

--Brand Names
insert into relationship_to_concept (concept_code_1, vocabulary_id_1,concept_id_2, precedence)
with a as (
select a.concept_code as concept_code_1,c.concept_id as concept_id_2 
from drug_concept_stage a join devv5.concept c 
on upper (c.concept_name) = upper(a.concept_name) and c.concept_class_id = 'Brand Name' and c.vocabulary_id like 'Rx%' and c.invalid_reason is null
where a.concept_class_id = 'Brand Name'
),
b as (
select concept_code,cast(concept_id_2 as number)
from  brand_names_manual a join drug_concept_stage b on upper(a.concept_name) =upper(b.concept_name)
and (concept_code,concept_id_2) not in (select concept_code_1,concept_id_2 from relationship_to_concept)
)
select concept_code_1, 'DA_France',concept_id_2, rank() over (partition by concept_code_1 order by concept_id_2)
from (select concept_code_1,concept_id_2 from a union select * from b)
;




--Dose Forms
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor)
select b.concept_code, 'DA_France',	CONCEPT_ID_2	, PRECEDENCE, '' from new_form_name_mapping a  --munualy created table 
join drug_concept_stage b on b.concept_name = a.DOSE_FORM_NAME
;
    
--Units
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('%', 'DA_France',8554,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('G', 'DA_France',8576,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('IU', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('IU', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('K', 'DA_France',8510,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('K', 'DA_France',8718,2,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('KG', 'DA_France',8576,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('L', 'DA_France',8587,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('M', 'DA_France',8510,1,1000000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MCG', 'DA_France',8576,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MG', 'DA_France',8576,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ML', 'DA_France',8576,2,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('U', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('U', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('Y', 'DA_France',8576,1,0.001);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('UI', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('UI', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MUI', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MUI', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('GM', 'DA_France',8576,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('DOS', 'DA_France',45744809,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('TU', 'DA_France',9413,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('TU', 'DA_France',8510,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('TU', 'DA_France',8718,3,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MU', 'DA_France',8510,2,0.000001);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MU', 'DA_France',8718,3,0.000001);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('H', 'DA_France',8505,1,1);




--update ds_stage after relationship_to concept found identical ingredients
drop table ds_sum;
create table ds_sum as 
with a  as (
SELECT distinct ds.drug_concept_code,ds.ingredient_concept_code,ds.box_size, ds.AMOUNT_VALUE,ds.AMOUNT_UNIT,ds.NUMERATOR_VALUE,ds.NUMERATOR_UNIT,ds.DENOMINATOR_VALUE,ds.DENOMINATOR_UNIT,rc.concept_id_2
      FROM ds_stage ds
        JOIN ds_stage ds2 ON ds.drug_concept_code = ds2.drug_concept_code AND ds.ingredient_concept_code != ds2.ingredient_concept_code
        JOIN relationship_to_concept rc ON ds.ingredient_concept_code = rc.concept_code_1
        JOIN relationship_to_concept rc2 ON ds2.ingredient_concept_code = rc2.concept_code_1
            WHERE rc.concept_id_2 = rc2.concept_id_2
            )
 select distinct DRUG_CONCEPT_CODE,max(INGREDIENT_CONCEPT_CODE)over (partition by DRUG_CONCEPT_CODE,concept_id_2) as ingredient_concept_code,box_size,
 sum(AMOUNT_VALUE) over (partition by DRUG_CONCEPT_CODE)as AMOUNT_VALUE,AMOUNT_UNIT,sum(NUMERATOR_VALUE) over (partition by DRUG_CONCEPT_CODE,concept_id_2)as NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT
 from a
 union
 select DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,box_size, null as AMOUNT_VALUE, '' as AMOUNT_UNIT, null as NUMERATOR_VALUE, '' as NUMERATOR_UNIT, null as DENOMINATOR_VALUE, '' as DENOMINATOR_UNIT 
 from a where (drug_concept_code,ingredient_concept_code) not in (select drug_concept_code, max(ingredient_concept_code) from a group by drug_concept_code);
delete from ds_stage where  (drug_concept_code,ingredient_concept_code) in (select drug_concept_code,ingredient_concept_code from ds_sum);
INSERT INTO DS_STAGE SELECT * FROM DS_SUM where nvl(AMOUNT_VALUE,NUMERATOR_VALUE) is not null;
--update irs after relationship_to concept found identical ingredients
delete from internal_relationship_stage where (concept_code_1,concept_code_2) in (
SELECT concept_code_1,concept_code_2
      FROM (SELECT DISTINCT concept_code_1,concept_code_2, COUNT(concept_code_2) OVER (PARTITION BY concept_code_1) AS irs_cnt
            FROM internal_relationship_stage
              JOIN drug_concept_stage ON concept_code = concept_code_2 AND concept_class_id = 'Ingredient') irs
        JOIN (SELECT DISTINCT drug_concept_code, COUNT(ingredient_concept_code) OVER (PARTITION BY drug_concept_code) AS ds_cnt
              FROM ds_stage) ds
          ON drug_concept_code = concept_code_1   AND irs_cnt != ds_cnt)
and  (concept_code_1,concept_code_2) not in (select drug_concept_code,ingredient_concept_code from ds_stage)        
;




