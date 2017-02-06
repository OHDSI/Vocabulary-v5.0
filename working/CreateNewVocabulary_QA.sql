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

--Improper valid_end_date
select concept_code, 'Improper valid_end_date'  as error_type from concept_stage where concept_code not in (
select concept_code  from concept_stage
where  valid_end_date <=SYSDATE or valid_end_date = to_date ('2099-12-31', 'YYYY-MM-DD') )
UNION
--Improper valid_start_date
select concept_code, 'Improper valid_start_date' from concept_stage where valid_start_date > SYSDATE

UNION

--dublicates
select concept_Code,'Duplicates in existing_concept_stage' 
from existing_concept_stage group by concept_Code having count(1)>1

UNION

select concept_Code_1,'Duplicates in concept_relationship_stage' from
(select CONCEPT_ID_1,CONCEPT_ID_2,CONCEPT_CODE_1,CONCEPT_CODE_2,VOCABULARY_ID_1,VOCABULARY_ID_2,RELATIONSHIP_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON
from concept_relationship_stage group by CONCEPT_ID_1,CONCEPT_ID_2,CONCEPT_CODE_1,CONCEPT_CODE_2,VOCABULARY_ID_1,VOCABULARY_ID_2,RELATIONSHIP_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON having count(1)>1)

UNION

--complete_concept_stage

--Check if the name in complete_concept_stage is correct
select cs.concept_Code,'Wrong Brand Name in concept_stage' from
concept_stage cs  LEFT JOIN xxx_replace x ON x.omop_code=cs.concept_code
LEFT JOIN complete_concept_stage ccs on ccs.concept_code=x.xxx_code
LEFT JOIN complete_concept_stage ccs2 on ccs2.concept_code=cs.concept_code
LEFT JOIN drug_concept_stage dcs ON coalesce(ccs.brand_code,ccs2.brand_code)=dcs.concept_code
--LEFT JOIN drug_concept_stage dcs ON ccs2.brand_code=dcs.concept_code
WHERE (regexp_substr(cs.concept_name,'\[.*\]',1,2))!='['||dcs.concept_name||']' AND cs.concept_class_id like '%Branded%'

UNION

select exs.concept_code,'Compete_concept_stage dont have concepts which are present in existing_Concept_stage'
from existing_Concept_stage exs 
LEFT JOIN complete_concept_stage ccs ON ccs.i_combo_code=exs.i_Combo_code AND ccs.DENOMINATOR_VALUE=exs.DENOMINATOR_VALUE
AND ccs.D_COMBO_CODE=exs.D_COMBO_CODE AND ccs.dose_form_code=exs.dose_form_code AND exs.brand_Code=ccs.brand_code AND ccs.box_size=exs.box_size and ccs.mf_code=exs.mf_Code
WHERE ccs.concept_code IS NULL

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


select cs.concept_code, 'Concepts from concept_stage do not have any relationship'  
from concept_stage cs
 LEFT JOIN concept_relationship_stage crs ON cs.concept_code=crs.concept_code_1 OR cs.concept_code=crs.concept_code_2 
LEFT JOIN  concept_relationship_stage CR2 ON cs.concept_code=CR2.concept_code_2 OR cs.concept_code=CR2.concept_code_1
WHERE crs.CONCEPT_CODE_1 IS NULL AND CR2.CONCEPT_CODE_2 IS NULL
and cs.domain_id = 'Drug'

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

--Check for duplicates, different standard_concept might be a problem
select concept_code,'Duplicates in concept_stage'
from concept_stage GROUP BY concept_Code HAVING COUNT (1)>1

UNION

--Marketed products
select cs.concept_code,'Marketed product represents more than one sub-product'
from concept_stage cs 
LEFT JOIN concept_relationship_stage crs ON crs.CONCEPT_CODE_1=cs.concept_code and crs.RELATIONSHIP_ID ='Marketed form of' 
LEFT JOIN  concept_relationship_stage CR2 ON cs.concept_code=CR2.concept_code_2 OR cs.concept_code=CR2.concept_code_1 and cr2.RELATIONSHIP_ID ='Has marketed form' 
WHERE cs.concept_class_id like 'Marketed%' and crs.CONCEPT_CODE_1 IS NULL AND CR2.CONCEPT_CODE_2 IS NULL

UNION

select concept_code_1 as concept_Code , 'Marketed products have relationships other than Marketed form of,Has Supplier'  from (
select crs.concept_code_1, crs.relationship_id from concept_stage cs 
JOIN concept_relationship_stage crs ON crs.CONCEPT_CODE_1=cs.concept_code 
AND crs.VOCABULARY_ID_1=cs.VOCABULARY_ID WHERE cs.concept_class_id like 'Marketed%' 
AND crs.RELATIONSHIP_ID not in ('Marketed form of', 'Has Supplier', 'Contains'))

UNION

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

-- duplicated attributes
/*with new_concept as (select * from  concept UNION  select * from  concept_stage), 
new_concept_relat as (
select CONCEPT_ID_1,CONCEPT_ID_2,CONCEPT_CODE_1,CONCEPT_CODE_2,VOCABULARY_ID_1,VOCABULARY_ID_2,RELATIONSHIP_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON from concept_relationship_stage
UNION
select CONCEPT_ID_1,CONCEPT_ID_2,CONCEPT_CODE_2,CONCEPT_CODE_1,VOCABULARY_ID_1,VOCABULARY_ID_2,'reverse '||RELATIONSHIP_ID as RELATIONSHIP_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON from concept_relationship_stage
)
 select  concept_code_1, 'duplicated attributes'
  from new_concept_relat r
join new_concept b on concept_code_1 = b.concept_code
join new_concept c on concept_code_2 = c.concept_code
where c.concept_class_id in ('Dose Form', 'Brand Name', 'Supplier')
and b.vocabulary_id like 'RxNorm%' and c.vocabulary_id like 'RxNorm%' and r.invalid_reason is null and (b.concept_class_id like '%Drug%' or b.concept_class_id like '%Marketed%' or  b.concept_class_id like '%Box%' ) --And relationship_id = 'RxNorm has dose form'
group by concept_code_1, c.concept_class_id having count (1) >1 

UNION
 
*/

select concept_name,'Valid dublicates'
 from concept_stage where vocabulary_id = 'RxNorm Extension' and concept_name not like '%...%' and invalid_reason is null
group by concept_name , invalid_reason 
 having count (1) > 1

UNION

--drug_strength

select distinct drug_concept_code, 'Impossible dosages' 
from drug_strength_stage 
where ( NUMERATOR_UNIT_CONCEPT_ID=8576 and DENOMINATOR_UNIT_CONCEPT_ID=8587 and NUMERATOR_VALUE / DENOMINATOR_VALUE > 1000 )
or 
(NUMERATOR_UNIT_CONCEPT_ID=8576 and DENOMINATOR_UNIT_CONCEPT_ID=8576 and NUMERATOR_VALUE / DENOMINATOR_VALUE > 1 )


UNION


select distinct drug_concept_code, 'Percents in wrong place' 
from drug_strength_stage 
where (NUMERATOR_UNIT_CONCEPT_ID=8554 and DENOMINATOR_UNIT_CONCEPT_ID is not null) or AMOUNT_UNIT_CONCEPT_ID=8554


UNION


--ancestor
select cast (an_id as varchar(255)),'wrong ancestor RxE to descedant RxNorm'
from
(select a.min_levels_of_separation as a_min,
  an.concept_id as an_id, an.concept_name as an_name, an.vocabulary_id as an_vocab, an.domain_id as an_domain, an.concept_class_id as an_class,
  de.concept_id as de_id, de.concept_name as de_name, de.vocabulary_id as de_vocab, de.domain_id as de_domain, de.concept_class_id as de_class
from concept an
join concept_ancestor a on a.ancestor_concept_id=an.concept_id and an.vocabulary_id='RxNorm Extension'
join concept de on de.concept_id=a.descendant_concept_id and de.vocabulary_id='RxNorm')

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
