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
* Authors: Christian Reich, Dmitry Dymshyts
* Date: 2016
**************************************************************************/

-- 1. relationship_to_concept
--incorrect mapping to concept
select a.concept_name, a.concept_class_id, c.concept_name, c.concept_class_id from relationship_to_concept r join drug_concept_stage a on a.concept_code= r.concept_code_1 
join devv5.concept c on c.concept_id = r.concept_id_2
where  a.concept_class_id !=  c.concept_class_id
;
--concept_id's that don't exist
select a.concept_name, a.concept_class_id, r.CONCEPT_ID_2, c.concept_name, c.concept_class_id from relationship_to_concept r 
join drug_concept_stage a on a.concept_code= r.concept_code_1 
left join devv5.concept c on c.concept_id = r.concept_id_2  and a.concept_class_id =  c.concept_class_id
where  c.concept_name is  null
; 
-- drug_strength_stage
--look if we have some unexpected amount_units
select * from drug_strength_stage where UPPER ( amount_unit) not in ('G', 'MG', 'KG', 'UNITS', 'UNIT','MIU','IU', 'MMOL', 'MOL',
'CELL','MU','L', 'ML', 'MEQ', 'MCG','CFU', 'MCCI','CH','DOSE','GALU','K','D','M','C','X','DH','B','PPM','TM','XMK')
--also take a look on other unit columns
;
-- drug codes are not exist in a drug_concept_stage but present in drug_strength_stage
select * from drug_strength_stage s 
left join drug_concept_stage a on a.concept_code = s.drug_concept_code and a.concept_class_id like  '%Drug%'
left join drug_concept_stage b on b.concept_code = s.INGREDIENT_CONCEPT_CODE and b.concept_class_id = 'Ingredient'
left join AP_IA_NON_DRUGS n on n.drug_code = s.drug_concept_code
where a.concept_code is null and n.DRUG_CODE is not null
;
-- ingredient codes not exist in a drug_concept_stage but present in drug_strength_stage
select * from drug_strength_stage s 
left join drug_concept_stage a on a.concept_code = s.drug_concept_code and a.concept_class_id like '%Drug%'
left join drug_concept_stage b on b.concept_code = s.INGREDIENT_CONCEPT_CODE and b.concept_class_id = 'Ingredient'
where b.concept_code is null 
;
--strange entries combinations in drug_strength_stage table , 
select * from drug_strength_stage s where AMOUNT_VALUE is not null and AMOUNT_UNIT is null or 
(denominator_VALUE is not null and denominator_UNIT is null) or (NUMERATOR_VALUE is not null and denominator_UNIT is null and DENOMINATOR_VALUE is null and NUMERATOR_UNIT !='%')
or (AMOUNT_VALUE is  null and AMOUNT_UNIT is not null)
;
-- drugs aren't present in drug_strength table
select * from drug_concept_stage where concept_code not in (select drug_concept_code from drug_strength_stage) and concept_class_id like '%Drug%'
;
--Quantitive drugs don't have denominator value 
SELECT * FROM drug_strength_stage s WHERE DRUG_CONCEPT_CODE IN (
select A.CONCEPT_CODE from drug_concept_stage a join  drug_strength_stage s on a.concept_code = s.drug_concept_code and a.concept_class_id like '%Quant%' and (s.DENOMINATOR_VALUE is null or NUMERATOR_VALUE is null))
;
--look if for some drugs we have empty and non-empty DENOMINATOR_VALUE fields
select * from drug_strength_stage a join drug_strength_stage b on a.drug_concept_code = b.drug_concept_code and a.DENOMINATOR_VALUE is null and b.DENOMINATOR_VALUE is not null 
;
-- volume units (ML or L) as amount units or denominator units
select * from drug_strength_stage where drug_concept_code in (
select drug_concept_code from  drug_strength_stage s where (amount_unit in ('ML', 'L') or NUMERATOR_unit in ('ML', 'L')))
;
--different values for the same ingredient and drug, look separately on numerator_value, DENOMINATOR_VALUE and Units
select DISTINCT A.* from DRUG_strength_STAGE a join DRUG_strength_STAGE b on a.drug_concept_code = b.drug_concept_code and a.INGREDIENT_CONCEPT_CODE = b.INGREDIENT_CONCEPT_CODE and a.numerator_value != b.numerator_value
;
select DISTINCT A.* from DRUG_strength_STAGE a join DRUG_strength_STAGE b on a.drug_concept_code = b.drug_concept_code and a.INGREDIENT_CONCEPT_CODE = b.INGREDIENT_CONCEPT_CODE and a.DENOMINATOR_VALUE != b.DENOMINATOR_VALUE
;
select DISTINCT A.* from DRUG_strength_STAGE a join DRUG_strength_STAGE b on a.drug_concept_code = b.drug_concept_code and a.INGREDIENT_CONCEPT_CODE = b.INGREDIENT_CONCEPT_CODE and ( a.DENOMINATOR_UNIT != b.DENOMINATOR_UNIT OR A.NUMERATOR_UNIT != B.NUMERATOR_UNIT)
;
--internal_relationship

--missing relationships:
--Branded Drug to Brand Name
--Drug to Ingredient
--Drug (non Component) to Form
select * from  drug_concept_stage a left join 
internal_relationship_stage s on s.concept_code_1= a.concept_code  
 where  (
 (a.concept_class_id like '%Branded%' and a.concept_class_id ='Brand Name')
 or (a.concept_class_id like '%Drug%' and a.concept_class_id ='Ingredient')
 or (a.concept_class_id like '%Drug%' and a.concept_class_id not like '%Comp%' and a.concept_class_id ='Dose Form')
 )
 AND S.concept_code_1 IS NULL
 ;
--duplicates in drug_concept_stage table
select * from drug_concept_stage  
where concept_code in (
select concept_code from drug_concept_stage group by concept_code having count(8)>1)
;
--several brand names
select * from drug_concept_stage a 
join internal_relationship_stage s on a.concept_code = s.concept_code_1
join drug_concept_stage b on b.concept_code =s.concept_code_2
and b.concept_class_id = 'Brand Name'
where a.concept_code in (
select a.concept_code from drug_concept_stage a 
join internal_relationship_stage s on a.concept_code = s.concept_code_1
join drug_concept_stage b on b.concept_code =s.concept_code_2
and b.concept_class_id = 'Brand Name'
group by a.concept_code having count(1) >1)
;
--several Dose forms
select * from drug_concept_stage a 
join internal_relationship_stage s on a.concept_code = s.concept_code_1
join drug_concept_stage b on b.concept_code =s.concept_code_2
and b.concept_class_id = 'Dose Form'
where a.concept_code in (
select a.concept_code from drug_concept_stage a 
join internal_relationship_stage s on a.concept_code = s.concept_code_1
join drug_concept_stage b on b.concept_code =s.concept_code_2
and b.concept_class_id = 'Dose Form'
group by a.concept_code having count(1) >1)
;
--same names for different drug classes
select * from drug_concept_stage where trim(lower(concept_name)) in (
  select trim(lower(concept_name)) as n from drug_concept_stage where concept_class_id in ('Brand Name', 'Dose Form', 'Unit', 'Ingredient') group by trim(lower(concept_name)) having count(8)>1)
  ;
--short names but not a Unit
select * from drug_concept_stage where length(concept_name)=1 and concept_class_id not in ('Unit')
;
