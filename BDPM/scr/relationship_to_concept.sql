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
drop table ingr_map_update;
create table ingr_map_update as 
with a as
(SELECT a.concept_code,a.concept_name,VOCABULARY_ID_1,precedence,rank() over (partition by a.concept_code order by c2.concept_id) as rank,
c2.concept_id,c2.standard_concept from
      drug_concept_stage a 
        join  relationship_to_concept rc on a.concept_code=rc.concept_code_1
        JOIN concept c1 ON c1.concept_id = concept_id_2
        join concept c2 on trim(regexp_replace(lower(c1.concept_name),'for homeopathic preparations|tartrate|phosphate'))=trim(regexp_replace(lower(c2.concept_name),'for homeopathic preparations'))
         and c2.standard_concept='S' and c2.concept_class_id='Ingredient'
      WHERE c1.invalid_reason IS NOT NULL)
select CONCEPT_CODE,CONCEPT_NAME,VOCABULARY_ID_1,PRECEDENCE,CONCEPT_ID,STANDARD_CONCEPT from a where concept_code in (select concept_code from a group by concept_code having count(concept_code)=1)
union
select CONCEPT_CODE,CONCEPT_NAME,VOCABULARY_ID_1,rank,CONCEPT_ID,STANDARD_CONCEPT from a where concept_code in (select concept_code from a group by concept_code having count(concept_code)!=1)
;
delete from relationship_to_concept where (concept_code_1,concept_id_2) in (
SELECT concept_code_1, concept_id_2
      FROM relationship_to_concept
        JOIN drug_concept_stage s ON s.concept_code = concept_code_1
        JOIN concept c ON c.concept_id = concept_id_2
      WHERE c.standard_concept IS NULL  AND   s.concept_class_id = 'Ingredient');
     
insert into relationship_to_concept select CONCEPT_CODE,VOCABULARY_ID_1,CONCEPT_ID,PRECEDENCE,''
 from ingr_map_update;
--add RxNorm Extension
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
;
insert into relationship_to_concept 
select concept_code,'BDPM',19127890,1,'' from drug_concept_stage where concept_name like 'inert ingredients';
--need to add manufacturer lately

--manufacturer
create table RxE_Man_st_0 as
select a.concept_code as concept_code_1,a.concept_name as concept_name_1,
c.concept_id, c.concept_name concept, rank() over (partition by a.concept_code order by c.concept_id) as precedence
 from drug_concept_stage a 
join devv5.concept c on 
regexp_replace(lower(a.concept_name),' ltd| plc| uk| \(.*\)| pharmaceuticals| pharma| gmbh| laboratories| ab| international| france| imaging')=
regexp_replace(lower(c.concept_name),' ltd| plc| uk| \(.*\)| pharmaceuticals| pharma| gmbh| laboratories| ab| international| france| imaging')
where a.concept_class_id = 'Supplier' 
and a.concept_code not in (select concept_code_1 from relationship_to_concept)
and c.vocabulary_id like 'RxNorm%' and c.concept_class_id=  'Supplier' and c.invalid_reason is null
;

insert into relationship_to_concept 
select concept_code,'BDPM', concept_id, precedence,''
from aut_supp_mapped a join drug_concept_stage b using(concept_name);--suppliers found manually


insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code_1, 'BDPM', CONCEPT_ID, precedence, '' 
from RxE_Man_st_0  -- RxNormExtension name equivalence
;
--Brands from RxE

create table RxE_BR_n_st_0 as
select a.concept_code as concept_code_1,a.concept_name as concept_name_1,
c.concept_id, c.concept_name
 from drug_concept_stage a 
join devv5.concept c on lower (a.concept_name )= lower (c.concept_name)
where a.concept_class_id = 'Brand Name' 
and a.concept_code not in (select concept_code_1 from relationship_to_concept)
and c.vocabulary_id like 'RxNorm%' and c.concept_class_id=  'Brand Name' and c.invalid_reason is null
;
insert into relationship_to_concept  (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
select concept_code_1, 'BDPM', CONCEPT_ID, 1, '' 
from RxE_BR_n_st_0  -- RxNormExtension name equivalence
;

DELETE FROM relationship_to_concept WHERE rowid  IN(
  SELECT MAX(rowid) FROM relationship_to_concept GROUP BY concept_code_1,precedence having count (1) >1);
commit;  
DELETE FROM internal_relationship_stage WHERE rowid  IN(
  SELECT MAX(rowid) FROM internal_relationship_stage GROUP BY concept_code_1,concept_code_2 having count (1) >1);
  commit;
update ds_stage set AMOUNT_VALUE=NUMERATOR_VALUE,AMOUNT_UNIT=NUMERATOR_UNIT, NUMERATOR_VALUE=null,NUMERATOR_UNIT=null,DENOMINATOR_VALUE=null,DENOMINATOR_UNIT=null
where (INGREDIENT_CONCEPT_CODE='16736' and drug_concept_code in (select concept_code from drug_concept_stage where 
CONCEPT_NAME in ('JINARC 30 mg, comprimé, JINARC 90 mg, comprimé comprimé de 90 mg','JINARC 15 mg, comprimé, JINARC 45 mg, comprimé comprimé de 45 mg','JINARC 30 mg, comprimé, JINARC 60 mg, comprimé comprimé de 60 mg')))
or (INGREDIENT_CONCEPT_CODE='41238' and drug_concept_code in (select concept_code from drug_concept_stage where 
CONCEPT_NAME in ('OTEZLA 10 mg, comprimé pelliculé, OTEZLA 20 mg, comprimé pelliculé, OTEZLA 30 mg, comprimé pelliculé, comprimé 30 mg','OTEZLA 10 mg, comprimé pelliculé, OTEZLA 20 mg, comprimé pelliculé, OTEZLA 30 mg, comprimé pelliculé, comprimé 20 mg')));



--delete non-relevant brand names
delete from relationship_to_concept where concept_code_1 in (
select concept_code from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
where a.concept_class_id= 'Brand Name' and b.concept_code_1 is null);
--update ds_stage after relationship_to concept found identical ingredients
delete from drug_concept_stage where concept_code in (select concept_code from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
where a.concept_class_id= 'Brand Name' and b.concept_code_1 is null);
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

--update IRS -remove suppliers where Dose form or dosage doesn't exist
DELETE FROM INTERNAL_RELATIONSHIP_STAGE WHERE (concept_code_1,concept_code_2) IN (
SELECT distinct concept_code_1,concept_code_2
                             FROM internal_relationship_stage
                               JOIN drug_concept_stage a ON concept_code_2 = a.concept_code  AND a.concept_class_id = 'Supplier'
                               JOIN drug_concept_stage b ON concept_code_1 = b.concept_code  AND b.concept_class_id in ('Drug Product','Drug Pack')
      where  (b.concept_code NOT IN (SELECT concept_code_1
                                  FROM internal_relationship_stage
                                    JOIN drug_concept_stage   ON concept_code_2 = concept_code  AND concept_class_id = 'Dose Form') OR b.concept_code NOT IN (SELECT drug_concept_code FROM ds_stage)))
;  
