/*
update drug_concept_stage set concept_name='Independent Pharmacy Cooperative' where concept_name='Ipc';
update drug_concept_stage set concept_name='Sun Pharmaceutical' where concept_name='Sun';
update drug_concept_stage set concept_name='Boucher & Muir Pty Ltd' where concept_name='Bnm';
update drug_concept_stage set concept_name='Pharma GXP' where concept_name='Gxp';
update drug_concept_stage set concept_name='Douglas Pharmaceuticals' where concept_name='Douglas';
update drug_concept_stage set concept_name='FBM-PHARMA' where concept_name='Fbm';
update drug_concept_stage set concept_name='DRX Pharmaceutical Consultants' where concept_name='Drx';
update drug_concept_stage set concept_name='Saudi pharmaceutical' where concept_name='Sau';
update drug_concept_stage set concept_name='FBM-PHARMA' where concept_name='Fbm';
*/

delete drug_concept_stage where concept_Code in (
select distinct a.concept_code from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
where a.concept_class_id= 'Brand Name' and b.concept_code_1 is null
union
select distinct a.concept_code from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
where a.concept_class_id= 'Dose Form' and b.concept_code_1 is null
);

--updating ingredients that create duplicates after mapping to RxNorm
create table ds_sum_2 as 
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
 from a where (drug_concept_code,ingredient_concept_code) 
 not in (select drug_concept_code, max(ingredient_concept_code) from a group by drug_concept_code)
;

delete from ds_stage where  (drug_concept_code,ingredient_concept_code) in 
(select drug_concept_code,ingredient_concept_code from ds_sum_2);

INSERT INTO DS_STAGE (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
SELECT distinct DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT
FROM DS_SUM_2 where nvl(AMOUNT_VALUE,NUMERATOR_VALUE) is not null;

--delete relationship to ingredients that we removed
delete internal_relationship_stage
where (concept_code_1,concept_code_2) in (
select drug_concept_code,ingredient_concept_code from ds_sum_2 where nvl(AMOUNT_VALUE,NUMERATOR_VALUE) is null);

--deleting drug forms 
DELETE ds_stage
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage
                            WHERE COALESCE(amount_value,numerator_value,0) = 0);
                            
                            
--update existing relationship to concept

update relationship_to_concept r
 set r.concept_id_2=(select cr.concept_id_2 from concept c join concept_relationship cr
 on cr.concept_id_1=concept_id and c.invalid_reason='U' and relationship_id='Concept replaced by' 
 where concept_id=r.concept_id_2
 )
where exists (select 1 from concept c join concept_relationship cr
 on cr.concept_id_1=concept_id and c.invalid_reason='U' and relationship_id='Concept replaced by' 
 where concept_id=r.concept_id_2);
 
  update relationship_to_concept r
 set r.concept_id_2=(select cr.concept_id_2 from concept c join concept_relationship cr
 on cr.concept_id_1=concept_id and c.invalid_reason='U' and relationship_id='Concept replaced by' 
 where concept_id=r.concept_id_2
 )
where exists (select 1 from concept c join concept_relationship cr
 on cr.concept_id_1=concept_id and c.invalid_reason='U' and relationship_id='Concept replaced by' 
 where concept_id=r.concept_id_2);
 
update 
relationship_to_concept
set concept_id_2=44015694
where concept_id_2=43252800
;
update 
relationship_to_concept
set concept_id_2=44814450
where concept_id_2=21017574
;
update 
relationship_to_concept
set concept_id_2=43252166
where concept_id_2=43252168
;
update 
relationship_to_concept
set concept_id_2=45892419
where concept_id_2=919345
;
update 
relationship_to_concept
set concept_id_2=43253544
where concept_id_2=43253545
;
update 
relationship_to_concept
set concept_id_2=43253506
where concept_id_2=43252243
;
update 
relationship_to_concept
set concept_id_2=42873956
where concept_id_2=46274499
;
update 
relationship_to_concept
set concept_id_2=19089408
where concept_id_2=43252075
;
update 
relationship_to_concept
set concept_id_2=1310937
where concept_id_2=21014056
;
update 
relationship_to_concept
set concept_id_2=44818494
where concept_id_2 in (19024669,19013754)
;
update 
relationship_to_concept
set concept_id_2=44023661
where concept_id_2 in (21019464)
;
update 
relationship_to_concept
set concept_id_2=35742006
where concept_id_2 in ( 21016548)
;
delete drug_concept_stage where concept_code in
 (select concept_code_1 from relationship_to_concept 
join concept c on concept_id_2=c.concept_id 
and c.invalid_reason='D' and concept_class_id!='Ingredient'
and concept_id_2 not in (43252204,43252218));

delete internal_relationship_stage where concept_code_2 in
 (select concept_code_1 from relationship_to_concept 
join concept c on concept_id_2=c.concept_id 
and c.invalid_reason='D' and concept_class_id!='Ingredient'
and concept_id_2 not in (43252204,43252218));

delete relationship_to_concept 
where concept_code_1 in (select concept_code_1 from
relationship_to_concept
join concept c on concept_id_2=c.concept_id 
and c.invalid_reason='D' and concept_class_id!='Ingredient'
and concept_id_2 not in (43252204,43252218));

;

--add water
insert into ds_stage (drug_concept_code,ingredient_concept_code,numerator_value,numerator_unit,denominator_unit)
select concept_code,'11295',1000 ,'Mg','Ml'
 from drug_concept_stage  dcs
join (
SELECT concept_code_1
FROM internal_relationship_stage
JOIN drug_concept_stage  ON concept_code_2 = concept_code  AND concept_class_id = 'Supplier'
left join ds_stage on drug_concept_code = concept_code_1 
where drug_concept_code is null
union 
SELECT concept_code_1
FROM internal_relationship_stage
JOIN drug_concept_stage  ON concept_code_2 = concept_code  AND concept_class_id = 'Supplier'
where concept_code_1 not in (SELECT concept_code_1
                                  FROM internal_relationship_stage
                                    JOIN drug_concept_stage   ON concept_code_2 = concept_code  AND concept_class_id = 'Dose Form')
) s on s.concept_code_1 = dcs.concept_code
where dcs.concept_class_id = 'Drug Product' and invalid_reason is null 
and concept_name like 'Water%';

insert into internal_relationship_stage 
(concept_code_1,concept_code_2)
select distinct drug_concept_code,ingredient_concept_code  from ds_stage where (drug_concept_code,ingredient_concept_code ) not in 
(select concept_code_1,concept_code_2 from internal_relationship_stage);

UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 19099465
WHERE CONCEPT_CODE_1 = '63031000168107'
AND   CONCEPT_ID_2 = 43128317;

