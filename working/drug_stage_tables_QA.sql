/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Christian Reich, Dmitry Dymshyts, Anna Ostropolets
* Date: 2016
**************************************************************************/
--this algorithm shows you concept_code and an error type related to this code, 
--for ds_stage it gets drug_concept_code
--for relationship_to_concept it gives concept_code_1
--for internal_relationship it gives concpept_code_1
--for drug_concept_stage it gives concept_code
-- 1. relationship_to_concept
--incorrect mapping to concept
--different classes in concept_code_1 and concept_id_2
select error_type, count (1) from (
select a.concept_code, 'different classes in concept_code_1 and concept_id_2' as error_type from relationship_to_concept r 
join drug_concept_stage a on a.concept_code= r.concept_code_1 
join devv5.concept c on c.concept_id = r.concept_id_2 and c.vocabulary_id = 'RxNorm'
where  a.concept_class_id !=  c.concept_class_id
union
--concept_id's that don't exist
select a.concept_code, 'concept_id_2 exists but doesnt belong to any concept' from relationship_to_concept r 
join drug_concept_stage a on a.concept_code= r.concept_code_1 
left join devv5.concept c on c.concept_id = r.concept_id_2  
where  c.concept_name is  null
union 
-- 2. ds_stage
--wrong units
 select distinct drug_concept_code, 'unit doesnt exist in concept_table' from ds_stage where
 ( amount_unit not in (select concept_code from drug_concept_stage where concept_class_id ='Unit')
or numerator_unit not in (select concept_code from drug_concept_stage where concept_class_id ='Unit')
or denominator_unit not in (select concept_code from drug_concept_stage where concept_class_id ='Unit')
)
union
-- drug codes are not exist in a drug_concept_stage but present in ds_stage
select distinct s.drug_concept_code, 'ds_stage has drug_codes absent in drug_concept_stage' from ds_stage s 
left join drug_concept_stage a on a.concept_code = s.drug_concept_code and a.concept_class_id='Drug Product'
left join drug_concept_stage b on b.concept_code = s.INGREDIENT_CONCEPT_CODE and b.concept_class_id = 'Ingredient'
where a.concept_code is null  
union
-- ingredient codes not exist in a drug_concept_stage but present in ds_stage
select distinct s.drug_concept_code, 'ds_stage has ingredient_codes absent in drug_concept_stage' from ds_stage s 
left join drug_concept_stage a on a.concept_code = s.drug_concept_code and a.concept_class_id='Drug Product'
left join drug_concept_stage b on b.concept_code = s.INGREDIENT_CONCEPT_CODE and b.concept_class_id = 'Ingredient'
where b.concept_code is null 
union
--impossible entries combinations in ds_stage table
select distinct s.drug_concept_code, 'impossible combination of values and units in ds_stage' from ds_stage s where AMOUNT_VALUE is not null and AMOUNT_UNIT is null or 
(denominator_VALUE is not null and denominator_UNIT is null) or (NUMERATOR_VALUE is not null and denominator_UNIT is null and DENOMINATOR_VALUE is null and NUMERATOR_UNIT !='%')
or (AMOUNT_VALUE is null and AMOUNT_UNIT is not null)
union
--Different DENOMINATOR_VALUE or DENOMINATOR_unit in the same drug
select distinct a.drug_concept_code, 'Different DENOMINATOR_VALUE or DENOMINATOR_unit in the same drug' 
 from ds_stage a join ds_stage b on a.drug_concept_code = b.drug_concept_code 
 and (a.DENOMINATOR_VALUE is null and b.DENOMINATOR_VALUE is not null  
 or a.DENOMINATOR_VALUE != b.DENOMINATOR_VALUE
 or a.DENOMINATOR_unit != b.DENOMINATOR_unit)
union
--ds_stage dublicates
select drug_concept_code, 'ds_stage dublicates' from (
select drug_concept_code, ingredient_concept_code from ds_stage group by drug_concept_code, ingredient_concept_code having count (1) > 1 
)
union
--3. internal_relationship_dublicates
select concept_code_1, 'internal_relationship_dublicates' from (
select concept_code_1, concept_code_2 from internal_relationship_stage group by concept_code_1, concept_code_2 having count (1) > 1 
)
union
--4.drug_concept_stage
--duplicates in drug_concept_stage table
select distinct concept_code,'Duplicate concept code' from drug_concept_stage  
where concept_code in (
select concept_code from drug_concept_stage group by concept_code having count(1)>1)
union
--same names for different drug classes
select concept_code, 'same names for basic drug classes'  from drug_concept_stage where trim(lower(concept_name)) in (
  select trim(lower(concept_name)) as n from drug_concept_stage where concept_class_id in ('Brand Name', 'Dose Form', 'Unit', 'Ingredient', 'Supplier') and standard_concept='S' group by trim(lower(concept_name)) having count(8)>1)
  union
--short names but not a Unit
select concept_code, 'short names but not a Unit' from drug_concept_stage where length(concept_name)<3 and concept_class_id not in ('Unit')
union 
--concept_name is null
select concept_code,'concept_name is null' from drug_concept_stage where concept_name is null
union
--relationship_to_concept
--relationship_to_concept concept_code_1_2 duplicates
select concept_code_1, 'relationship_to_concept concept_code_1_2 duplicates' from (
select concept_code_1, concept_id_2 from relationship_to_concept group by  concept_code_1, concept_id_2 having count (1) >1)
union
--relationship_to_concept concept_code_1_precedence duplicates
select concept_code_1, 'relationship_to_concept concept_code_1_2 duplicates' from (
select concept_code_1, precedence from relationship_to_concept group by  concept_code_1, precedence having count (1) >1)
union
--Brand Name doesnt relate to any drug
select distinct a.concept_code, 'Brand Name doesnt relate to any drug' from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
where a.concept_class_id= 'Brand Name' and b.concept_code_1 is null
union
--Dose Form doesnt relate to any drug
select distinct a.concept_code, 'Dose Form doesnt relate to any drug' from drug_concept_stage a left join  internal_relationship_stage b on a.concept_code = b.concept_code_2
where a.concept_class_id= 'Dose Form' and b.concept_code_1 is null
union
--duplicates in ds_stage
--Concept_code_1 - Precedence duplicates
select concept_code_1, 'Concept_code_1 - precedence duplicates' from (
select  concept_code_1,precedence from relationship_to_concept group by concept_code_1,precedence having count (1) >1 )
union
----Concept_code_1 - Ingredient duplicates
select concept_code_1, 'Concept_code_1 - precedence duplicates' from (
select  concept_code_1,concept_id_2 from relationship_to_concept group by concept_code_1,concept_id_2 having count (1) >1 )
union
--Unit without mapping
select CONCEPT_CODE, 'Unit without mapping' from 
drug_concept_Stage a left join relationship_to_concept b on a.concept_code = b.concept_code_1
where concept_class_id in('Unit') and b.concept_code_1 is null
union
--Dose Form without mapping
select CONCEPT_CODE, 'Dose Form without mapping' from 
drug_concept_Stage a 
left join relationship_to_concept b on a.concept_code = b.concept_code_1
where concept_class_id in('Dose Form') and b.concept_code_1 is null
union
--duplicates will be present in drug_concept_stage, unable to summarize values
select distinct   a.drug_concept_code, 'concept overlaps with other one by target concept, please look also onto rigth sight of query result' from (
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
or a.AMOUNT_UNIT is null and b.amount_unit is not null)
union
--Improper valid_end_date
select concept_code, 'Improper valid_end_date' from drug_concept_stage where concept_code not in (
select concept_code  from drug_concept_stage
where  valid_end_date <=SYSDATE or valid_end_date = to_date ('2099-12-31', 'YYYY-MM-DD') )
union
--Improper valid_start_date
select concept_code, 'Improper valid_start_date' from drug_concept_stage where valid_start_date >  SYSDATE
union
--Wrong vocabulary mapping
select concept_code_1,'Wrong vocabulary mapping' from relationship_to_concept a
join devv5.concept b on a.concept_id_2=b.concept_id 
where b.VOCABULARY_ID not in ('ATC','UCUM','RxNorm','RxNorm Extension')
union
--"<=0" in ds_stage values
select drug_concept_code,'0 in values' 
from ds_stage where amount_value<=0 or denominator_value<=0 or numerator_value<=0
union
--pc_stage issues
--pc_stage duplicates
select PACK_CONCEPT_CODE, 'pc_stage duplicates' from (
select PACK_CONCEPT_CODE, DRUG_CONCEPT_CODE  from pc_stage group by DRUG_CONCEPT_CODE, PACK_CONCEPT_CODE having count (1) > 1 )
union 
--non drug as a pack component
select DRUG_CONCEPT_CODE, 'non drug as a pack component' from pc_stage 
join drug_concept_stage on DRUG_CONCEPT_CODE = concept_code and concept_class_id !='Drug Product'
union
--wrong drug classes
select concept_code, 'wrong drug classes' from drug_concept_stage where concept_class_id not in ('Ingredient', 'Unit', 'Drug Product', 'Dose Form', 'Supplier', 'Brand Name', 'Device')
union
--wrong domains
select concept_code, 'wrong domain_id' from drug_concept_stage where domain_id not in ('Drug', 'Device')
union
--wrong dosages ,> 1000
select drug_concept_code, 'wrong dosages > 1000' from ds_stage 

where (
lower (numerator_unit) in ('mg')
and lower (denominator_unit) in ('ml','g')
or 
lower (numerator_unit) in ('g')
and lower (denominator_unit) in ('l')
)
and numerator_value / denominator_value > 1000
union
--wrong dosages ,> 1
select drug_concept_code, 'wrong dosages > 1' from ds_stage 

where lower (numerator_unit) in ('g')
and lower (denominator_unit) in ('ml')

and numerator_value / denominator_value > 1
union
--% in ds_stage 
select drug_concept_code, '% in ds_stage' from ds_stage 
where numerator_unit='%' or amount_unit ='%' or denominator_unit ='%'
union
-- as we don't have the mapping all the decives should be standard
select concept_code , 'non-standard devices' from drug_concept_stage where domain_id = 'Device' and standard_concept is null
union
--several attributes but should be the only one
select concept_code_1, 'several attributes but should be the only one' from (
select concept_code_1,b.concept_class_id  from internal_relationship_stage a
join drug_concept_stage  b on concept_code = concept_code_2 
where b.concept_class_id in ('Supplier', 'Dose Form', 'Brand Name')
group by concept_code_1,b.concept_class_id having count (1) >1
)
union
--replacement mappings to several concepts
select concept_code_1, 'several attributes but should be the only one' from (
select concept_code_1,b.concept_class_id  from internal_relationship_stage a
join drug_concept_stage  z on z.concept_code = concept_code_1
join drug_concept_stage  b on b.concept_code = concept_code_2 
where b.concept_class_id = z.concept_class_id
group by concept_code_1,b.concept_class_id having count (1) >1
)
union
--sequence intersection
select a.concept_code, 'sequence intersection' from drug_concept_stage a 
join concept b on a.concept_code = b.concept_code
where a.concept_code like 'OMOP%'
union
--invalid_concept_id_2
select concept_code_1,'invalid_concept_id_2' from relationship_to_concept 
join concept on concept_id = concept_id_2 
where invalid_reason is not null
union
--map to non-stand_ingredient
select concept_code_1,'map to non-stand_ingredient' from relationship_to_concept 
join drug_concept_stage s on s.concept_code = concept_code_1  
join concept c on c.concept_id = concept_id_2 
where c.standard_concept is null and s.concept_class_id = 'Ingredient'
union
 --map to unit that doesn't exist in RxNorm
select a.concept_code_1,'map to unit that doesn''t exist in RxNorm'  from relationship_to_concept a 
join drug_concept_stage b on concept_code_1=concept_code  
join concept on concept_id_2=concept_id
where b.concept_class_id='Unit' and concept_id_2 not in (
select distinct nvl(AMOUNT_UNIT_CONCEPT_ID,NUMERATOR_UNIT_CONCEPT_ID) from drug_strength a 
join concept b on drug_concept_id=concept_id and vocabulary_id='RxNorm' 
where nvl(AMOUNT_UNIT_CONCEPT_ID,NUMERATOR_UNIT_CONCEPT_ID) is not null
union select distinct DENOMINATOR_UNIT_CONCEPT_ID from drug_strength a 
join concept b on drug_concept_id=concept_id and vocabulary_id='RxNorm' 
where DENOMINATOR_UNIT_CONCEPT_ID is not null)
union
select concept_code_1,'Empty conversion factor'
from relationship_to_concept a join drug_concept_stage b on concept_code_1=concept_code and concept_class_id='Unit'
 where conversion_factor is null
union
--replacement with invalid concept
select concept_code_1, 'replacement with invalid concept' from internal_relationship_stage
join drug_concept_stage on concept_code = concept_code_2 
where invalid_reason is not null
union
--standard but invalid concept
select concept_code,'standard but invalid concept' from drug_concept_stage where standard_concept='S' and invalid_reason is not null
union
--standard ingredients have replacemt mapping 
select concept_code,'standard ingredients have replacemt mapping'  from drug_concept_stage 
join internal_relationship_stage on concept_code_1 = concept_code
where concept_class_id ='Ingredient' and standard_concept is not null
union
--non-standard ingredients don't have replacemt mapping 
select concept_code,'non-standard ingredients dont have replacemt mapping ' from drug_concept_stage 
left join internal_relationship_stage on concept_code_1 = concept_code
where concept_class_id ='Ingredient' and standard_concept is  null and concept_code_2 is null
union
--wrong dosages ,> 1000, with conversion
select drug_concept_code, 'wrong dosages > 1000, with conversion' from ds_stage ds
join relationship_to_concept n on numerator_unit = n.concept_code_1 and n.concept_id_2 = 8576
join relationship_to_concept d on denominator_unit = d.concept_code_1 and d.concept_id_2 = 8587
where  numerator_value*n.conversion_factor / (denominator_value*d.conversion_factor) > 1000
) group by error_type
;
