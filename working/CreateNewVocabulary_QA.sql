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
* Authors: Christian Reich, Anna Ostropolets, Dmitry Dymshyts
* Date: 2016
**************************************************************************/
select error_type, count (1) from (

--dublicates
select concept_Code,'Duplicate codes in concept_stage'  as error_type
from concept_stage group by concept_Code having count(1)>1

UNION

select concept_name,'Duplicate names in concept_stage (RxE)' 
from concept_stage where lower(concept_name) in (select lower(concept_name) from concept_stage where vocabulary_id like 'Rx%' and invalid_reason is null and concept_name not like '%...%' group by concept_name having count(1)>1)

UNION
--concept_relationship_stage
select concept_code_2,'Missing concept_code_1'
from concept_relationship_stage where concept_code_1 is null

UNION
 
select concept_code_1,'Missing concept_code_2'
from concept_relationship_stage where concept_code_2 is null

UNION

select distinct relationship_id,'Wrong relationship_id in concept_relationship_stage'
from concept_relationship_stage where relationship_id not in (select distinct relationship_id from devv5.concept_relationship)

UNION

select concept_code,'Concepts from concept_relationship_stage missing in concept_stage' from 
concept_relationship_stage crs 
LEFT JOIN concept_stage cs ON cs.concept_code=crs.concept_code_1
WHERE cs.concept_code is null
AND crs.vocabulary_id_1=cs.vocabulary_id

UNION

--relationship problems in concept_relationship_stage
select concept_code, 'Deprecated concepts dont have necessary relationships'
from concept_stage
WHERE NOT EXISTS (select * from concept_stage c JOIN concept_relationship_stage cr ON cr.concept_code_1=c.concept_code
WHERE c.invalid_reason='D' and relationship_id in ('Maps to','Replaced by')) 
AND invalid_reason='D'

UNION

--check if relationship 'Has standard brand' exsists only to brand names
select concept_code_1,'Has standard brand refers not to brand name'
from concept_relationship_stage crs JOIN devv5.concept c on concept_code_2=concept_code
WHERE relationship_id='Has standard brand' AND c.concept_class_id!='Brand Name' AND c.vocabulary_id='RxNorm'

UNION
--check if relationship 'Has standard form' exsists only to dose form;
select concept_code_1,'Has standard form refers not to dose form'
from concept_relationship_stage crs JOIN devv5.concept c on concept_code_2=concept_code
WHERE relationship_id='Has standard form' AND c.concept_class_id!='Dose Form' AND c.vocabulary_id='RxNorm'

UNION

--check if relationship 'Has standard ing' exsists only to ingredient
select concept_code_1,'Has standard ing refers not to ingredient'
from concept_relationship_stage crs JOIN devv5.concept c on concept_code_2=concept_code
WHERE relationship_id='Has standard ing' AND c.concept_class_id!='Ingredient' AND c.vocabulary_id='RxNorm'

UNION

select distinct concept_code_1, 'Has tradename refers to wrong concept_class' 
from concept_relationship_stage crs 
LEFT JOIN concept_stage cs ON concept_code_2=cs.concept_code AND crs.vocabulary_id_2 = cs.vocabulary_id
LEFT JOIN concept_stage cs2 ON concept_code_1=cs2.concept_code AND crs.vocabulary_id_1 = cs2.vocabulary_id
WHERE relationship_id='Has tradename' AND (cs.concept_class_id not like '%Branded%'
OR cs2.concept_class_id not like '%Clinical%')

UNION

--Should be only Component to Drug relationship
select distinct concept_code_1, 'Constitutes refers to wrong concept_class'
from concept_relationship_stage crs 
LEFT JOIN concept_stage cs ON concept_code_2=cs.concept_code AND crs.vocabulary_id_2 = cs.vocabulary_id
LEFT JOIN concept_stage cs2 ON concept_code_1=cs2.concept_code AND crs.vocabulary_id_1 = cs2.vocabulary_id
WHERE relationship_id='Constitutes' AND (cs.concept_class_id not like '%Drug%'
OR cs2.concept_class_id not like '%Comp%')


UNION
--concept_stage

--important query - without it we'll ruin Generic_update
select distinct concept_class_id,'Wrong concept_class_id in concept_stage'
from concept_stage where concept_class_id not in (select distinct concept_class_id from devv5.concept_class)

UNION

--There should be no standard deprecated and updated concepts
select distinct c.concept_code, 'Wrong standard_concept' 
from concept_stage c JOIN concept_relationship_stage cr ON cr.concept_code_1=c.concept_code 
WHERE c.standard_concept='S' and (c.invalid_reason='U' or c.invalid_reason='D')
UNION
select distinct c.concept_code, 'Wrong standard_concept'
from concept_stage c JOIN concept_relationship_stage cr ON cr.concept_code_2=c.concept_code 
WHERE c.standard_concept='S' and (c.invalid_reason='U' or c.invalid_reason='D')

UNION
--drug_strength
select distinct drug_concept_code, 'Impossible dosages' 
from drug_strength_stage 
where ( NUMERATOR_UNIT_CONCEPT_ID=8576 and DENOMINATOR_UNIT_CONCEPT_ID=8587 and NUMERATOR_VALUE / DENOMINATOR_VALUE > 1000 )
or 
(NUMERATOR_UNIT_CONCEPT_ID=8576 and DENOMINATOR_UNIT_CONCEPT_ID=8576 and NUMERATOR_VALUE / DENOMINATOR_VALUE > 1 )
UNION

SELECT drug_concept_code, 'missing unit'
      FROM drug_strength_stage
      WHERE (numerator_value IS NOT NULL AND numerator_unit_concept_id IS NULL)
      OR    (denominator_value IS NOT NULL AND denominator_unit_concept_id IS NULL)
      OR    (amount_value IS NOT NULL AND amount_unit_concept_id IS NULL)

UNION

select distinct drug_concept_code, 'Percents in wrong place' 
from drug_strength_stage 
where (NUMERATOR_UNIT_CONCEPT_ID=8554 and DENOMINATOR_UNIT_CONCEPT_ID is not null) or AMOUNT_UNIT_CONCEPT_ID=8554

UNION

select r.concept_code_1 as concept_code, 'Concept_replaced by many concepts' --count(*) 
From concept_stage c1, concept_stage c2, concept_relationship_stage r
where c1.concept_code=r.concept_code_1
and c2.concept_code=r.concept_code_2
and c1.vocabulary_id='RxNorm Extension'
and c2.vocabulary_id='RxNorm Extension'
and  relationship_id='Concept replaced by'
and r.invalid_reason is null
group by r.concept_code_1
having count(*)>1
order by 2 desc

)
group by error_type
;
