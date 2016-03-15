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
* Authors: Christian Reich
* Date: 2016
**************************************************************************/

--incorrect mapping to concept
select a.concept_name, a.concept_class_id, c.concept_name, c.concept_class_id from relationship_to_concept r join drug_concept_stage a on a.concept_code= r.concept_code_1 
join devv5.concept c on c.concept_id = r.concept_id_2
where  a.concept_class_id !=  c.concept_class_id
;
--concept_id's that don't exist
select a.concept_name, a.concept_class_id, r.CONCEPT_ID_2, c.concept_name, c.concept_class_id from relationship_to_concept r 
join drug_concept_stage a on a.concept_code= r.concept_code_1 
left join devv5.concept c on c.concept_id = r.concept_id_2 and a.concept_class_id =  c.concept_class_id
where  c.concept_name is null
; 
--drug_strength_stage 
select * from drug_strength_stage where  amount_unit ='NIL'
;
--look if we have some strange amount_units
select distinct amount_unit  from drug_strength_stage
;
-- drug codes not exist in a drug_concept_stage but present in drug_strength_stage
select * from drug_strength_stage s 
left join drug_concept_stage a on a.concept_code = s.drug_concept_code and a.concept_class_id like  '%Drug%'
left join drug_concept_stage b on b.concept_code = s.INGREDIENT_CONCEPT_CODE and b.concept_class_id = 'Ingredient'
where a.concept_code is null 
;
-- ingredient codes not exist in a drug_concept_stage but present in drug_strength_stage
select * from drug_strength_stage s 
left join drug_concept_stage a on a.concept_code = s.drug_concept_code and a.concept_class_id like '%Drug%'
left join drug_concept_stage b on b.concept_code = s.INGREDIENT_CONCEPT_CODE and b.concept_class_id = 'Ingredient'
where b.concept_code is null 
;
-- internal_relationship_stage has codes missing in drug_concept_stage
--code_2
select *from internal_relationship_stage s
left join drug_concept_stage a on a.concept_code = s.concept_code_1 
left join drug_concept_stage b on b.concept_code = s.concept_code_2 
where b.concept_code is null 
;
-- internal_relationship_stage has codes missing in drug_concept_stage
--code_1
select count(1) from internal_relationship_stage s
left join drug_concept_stage a on a.concept_code = s.concept_code_1 
left join drug_concept_stage b on b.concept_code = s.concept_code_2 
where a.concept_code is null 
;
--strange combinations in drug_strength_stage table like we have strength but no unit of measurement
select * from drug_strength_stage s where AMOUNT_VALUE is not null and AMOUNT_UNIT is null
;
select * from drug_strength_stage s where denominator_VALUE is not null and denominator_UNIT is null
;
select * from drug_strength_stage s where NUMERATOR_VALUE is not null and denominator_UNIT is null and DENOMINATOR_VALUE is null and NUMERATOR_UNIT !='%'
;
select * from drug_strength_stage s where AMOUNT_VALUE is  null and AMOUNT_UNIT is not null
;
-- manual review of internal_relationship_stage
select a.concept_code, a.concept_name, a.concept_class_id, b.concept_code , b.concept_name, b.concept_class_id  from internal_relationship_stage s
left join drug_concept_stage a on a.concept_code = s.concept_code_1 
left join drug_concept_stage b on b.concept_code = s.concept_code_2 
where a.concept_code is not null 
;
-- manual review of Brand Names
select * from  drug_concept_stage
where concept_class_id like 'Brand Name'
;
-- some drugs doesn't present in drug_strength table
select * from  drug_concept_stage a left join 
 drug_strength_stage s on s.drug_concept_code = a.concept_code
 where a.concept_class_id like '%Drug%'
 AND S.drug_concept_code IS NULL
;
--Branded drug that doesn't have relationship to Brand Name, please find out why does it happen: is concept_class_id definition incorrect or relationship table?
select * from  drug_concept_stage a left join 
internal_relationship_stage s on s.concept_code_1= a.concept_code and a.concept_class_id like'%Brand%'
 where a.concept_class_id like '%Branded%'
 AND S.concept_code_1 IS NULL
 ;
--duplicates in drug_concept_stage table
select * from drug_concept_stage where concept_code in (
select concept_code from drug_concept_stage group by concept_code having count(8)>1)
;
