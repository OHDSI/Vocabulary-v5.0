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
**************************************************************************/

--Remove devices from our tables
update drug_concept_stage
set
  concept_class_id = 'Device',
  domain_id = 'Device',
  standard_concept = 'S'
where
  concept_code in (select DRUG_CONCEPT_CODE from dsfix where device is not null);
delete from internal_relationship_stage where concept_code_1 in (select DRUG_CONCEPT_CODE from dsfix where device is not null);

create table generated_concepts as
select
  'OMOP' || conc_stage_seq.nextval as concept_code,
  INGREDIENT_CONCEPT_NAME as CONCEPT_NAME,
  MAPPED_ID
from ( select distinct INGREDIENT_CONCEPT_NAME, MAPPED_ID from dsfix where mapped_id is not null);

insert into drug_concept_stage
select distinct
  concept_name,
  'BCFI' as vocabulary_ID,
  'Ingredient' as concept_class_id,
  'Stof' as source_concept_class_id,
  'S' as standard_concept,
  concept_code,
  null as possible_excipient,
  'Drug' as domain_id,
  trunc(sysdate) as valid_start_date,
  TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
  null as invalid_reason
from generated_concepts;

insert into internal_relationship_stage
  select distinct
    d.DRUG_CONCEPT_CODE,
    nvl (d.INGREDIENT_CONCEPT_CODE, g.concept_code)
  from dsfix d
left join generated_concepts g on d.INGREDIENT_CONCEPT_NAME = g.concept_name
where d.device is null
;
insert into ds_stage
select distinct
  d.DRUG_CONCEPT_CODE,
  nvl (d.INGREDIENT_CONCEPT_CODE, g.concept_code) as INGREDIENT_CONCEPT_CODE,
  d.AMOUNT_VALUE,
  d.AMOUNT_UNIT,
  d.NUMERATOR_VALUE,
  d.NUMERATOR_UNIT,
  d.DENOMINATOR_VALUE,
  d.DENOMINATOR_UNIT,
  d.BOX_SIZE
from dsfix d
left join generated_concepts g on d.INGREDIENT_CONCEPT_NAME = g.concept_name
where d.device is null and nvl (AMOUNT_VALUE,NUMERATOR_VALUE) is not null;
;
insert into concept_synonym_stage
select distinct
  NULL as synonym_concept_id,
  concept_name as synonym_concept_name,
  concept_code as synonym_concept_code,
  'BCFI' as vocabulary_ID,
  4180186 as language_concept_id --English
from generated_concepts
union
select distinct
  NULL as synonym_concept_id,
  concept_name as synonym_concept_name,
  concept_code as synonym_concept_code,
  'BCFI' as vocabulary_ID,
  4180190 as language_concept_id --French
from generated_concepts
union
select 
  NULL as synonym_concept_id,
  concept_name as synonym_concept_name,
  concept_code as synonym_concept_code,
  'BCFI' as vocabulary_ID,
  4182503 as language_concept_id --Dutch
from generated_concepts;

insert into relationship_to_concept
select distinct 
  concept_code as CONCEPT_CODE_1,
  'BCFI' as VOCABULARY_ID_1,
  MAPPED_ID as CONCEPT_ID_2,
  1 as PRECEDENCE,
  null as CONVERSION_FACTOR
from generated_concepts;

delete from drug_concept_stage where concept_code in ( -- we have deprecated some Drug Products as Devices, so we remove them
SELECT a.concept_code
      FROM drug_concept_stage a
        LEFT JOIN internal_relationship_stage b ON a.concept_code = b.concept_code_2
      WHERE a.concept_class_id = 'Brand Name'
      AND   b.concept_code_1 IS NULL);


 create table code_replace as 
 select 'OMOP'||new_vocab.nextval as new_code, concept_code as old_code from (
select distinct  concept_code from drug_concept_stage where concept_code like '%OMOP%' order by (cast ( regexp_substr( concept_code, '\d+') as int))
)
;
update drug_concept_stage a set concept_code = (select new_code from code_replace b where a.concept_code = b.old_code) 
where a.concept_code like '%OMOP%' 
;
commit
;
update relationship_to_concept a  set concept_code_1 = (select new_code from code_replace b where a.concept_code_1 = b.old_code)
where a.concept_code_1 like '%OMOP%'
;commit
;
update ds_stage a  set ingredient_concept_code = (select new_code from code_replace b where a.ingredient_concept_code = b.old_code)
where a.ingredient_concept_code like '%OMOP%' 
;
commit
;
update ds_stage a  set drug_concept_code = (select new_code from code_replace b where a.drug_concept_code = b.old_code)
where a.drug_concept_code like '%OMOP%' 
;commit
;
update internal_relationship_stage a  set concept_code_1 = (select new_code from code_replace b where a.concept_code_1 = b.old_code)
where a.concept_code_1 like '%OMOP%'
;commit
;
update internal_relationship_stage a  set concept_code_2 = (select new_code from code_replace b where a.concept_code_2 = b.old_code)
where a.concept_code_2 like '%OMOP%' 
;
commit
;
update pc_stage a  set DRUG_CONCEPT_CODE = (select new_code from code_replace b where a.DRUG_CONCEPT_CODE = b.old_code)
where a.DRUG_CONCEPT_CODE like '%OMOP%' 
;
update drug_concept_stage set standard_concept=null where concept_code in (select concept_code from drug_concept_stage 
join internal_relationship_stage on concept_code_1 = concept_code
where concept_class_id ='Ingredient' and standard_concept is not null);

commit;