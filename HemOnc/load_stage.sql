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
* Authors: Dmitry Dymshyts, Timur Vakhitov
* Date: 2019
**************************************************************************/

--1. Update latest_update field to new date

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'HemOnc',
	pVocabularyDate			=> to_date ('2019-08-29', 'yyyy-mm-dd'),
	pVocabularyVersion		=> 'HemOnc 2019-08-29',
	pVocabularyDevSchema	=> 'DEV_hemonc'
);
END $_$;
--truncate all working tables
truncate table concept_stage;
truncate concept_relationship_stage;
truncate concept_synonym_stage
;
--take only the folowing concept classes in the first iteration
insert into concept_stage 
select concept_id,concept_name,
case 
when ( concept_class_id in ('Procedure', 'Context') or concept_name ='Radiotherapy') then 'Procedure'
when concept_class_id in ('Component', 'Brand Name', 'Component Class', 'Route', 'Regimen type') then 'Drug'
when concept_class_id in ('Condition', 'Condition Class', 'BioCondition') then 'Condition'
when concept_class_id in ('Regimen', 'Modality') then 'Regimen' --https://github.com/OHDSI/OncologyWG/issues/69  --"69" haha
else 'Undefined' 
end as domain_id,
vocabulary_id, 
 concept_class_id , 
case
 when concept_class_id ='Condition Class' then 'C' -- let's make them classification concepts (in previos version Component Class was assigned manually, Jeremy fixed it in the 30-Aug-2019 release)
else standard_concept end as standard_concept
,concept_code,valid_start_date,valid_end_date, 
  invalid_reason 
from hemonc_concept_stage where concept_class_id in 
(
'Regimen type' -- type 
,'Component Class' -- looks like ATC, perhaps require additional mapping to ATC, in a first run make them "C", then replace with ATC, still a lot of work 
,'Component' -- ingredient, Standard if there's no equivalent in Rx, RxE
,'Context' -- therapy intent or line or other Context, STANDARD
,'Regimen' -- Standard
,'Brand Name',-- need to map to RxNorm, RxNorm Extension if possible, if not - leave it as is
'Route' ,
'Procedure', 
--added 30-Aug-2019
'Modality'
--need to be added, requires further analysis of relationships
/*
,
'BioCondition',
'Condition',
'Condition Class'
*/
)
and concept_name is not null
;
--concept_relationship_stage
insert into concept_relationship_stage
select distinct
concept_id_1,concept_id_2,concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,
 relationship_id  -- relationships are as is , Jeremy fixed already:)
,
r.valid_start_date,r.valid_end_date,
case when 
r.invalid_reason ='NA' then null else r.invalid_reason end
 from concept_stage a
 join hemonc_concept_relationship_stage r on a.concept_code = r.concept_code_1 and a.vocabulary_id = r.vocabulary_id_1  
  join (select * from concept where vocabulary_id in ('RxNorm', 'RxNorm Extension') union select * from concept_stage) b on b.concept_code = r.concept_code_2 and b.vocabulary_id = r.vocabulary_id_2
  where relationship_id not in   ( 
  -- these aren't investigated well yet
'Has been compared to',
'Can be preceded by',
'Can be followed by'
)
;
-- Antithymocyte globulin rabbit ATG was mapped to Thymoglobulin (Brand Name) , correct mapping will be added below
delete from concept_relationship_stage where concept_code_1 = '37' and concept_code_2 = '225741'  and relationship_id ='Maps to'
;
--update relationships to precise ingredient, replace precise ingredient with Ingredient 
update concept_relationship_stage rs
set concept_code_2 = (
select b.concept_code from 
concept a 
join concept_Relationship r on r.concept_id_1 = a.concept_id and r.relationship_id = 'Form of' and r.invalid_reason is null
join concept b on b.concept_class_id ='Ingredient' and b.standard_concept ='S' and b.concept_id = r.concept_id_2
where a.vocabulary_id ='RxNorm' and a.concept_class_id ='Precise Ingredient' 
and  a.concept_code = rs.concept_code_2 and rs.vocabulary_id_2 = a.vocabulary_id 
)
where exists (
select 1 from 
concept a 
join concept_Relationship r on r.concept_id_1 = a.concept_id and r.relationship_id = 'Form of' and r.invalid_reason is null
join concept b on b.concept_class_id ='Ingredient' and b.standard_concept ='S' and b.concept_id = r.concept_id_2
where a.vocabulary_id ='RxNorm' and a.concept_class_id ='Precise Ingredient' 
and  a.concept_code = rs.concept_code_2 and rs.vocabulary_id_2 = a.vocabulary_id 
)
;
--update wrong Maps to and relationships from Regimen to Drugs to Brand Names 
--and one totally incorrect drug form
--to do: make this step automatic
with repl as (
select distinct rs.concept_code_2 as old_code, b.concept_code as new_code from concept_relationship_stage rs
join concept a on a.concept_code = rs.concept_code_2 and rs.vocabulary_id_2 = a.vocabulary_id 
join concept_Relationship r on r.concept_id_1 = a.concept_id and r.relationship_id = 'Brand name of' and r.invalid_reason is null
join concept b on b.concept_class_id ='Ingredient' and b.standard_concept ='S' and b.concept_id = r.concept_id_2
join concept_stage cs on cs.concept_code = rs.concept_code_1 
and cs.concept_name not like '% and %' -- avoiding the combinatory drugs, they are mapped manually, see union below
and a.concept_code not in ('2119715', '1927886') -- Herceptin Hylecta , Rituxan Hycela -  need to make better automatic work-aroud when have time
where a.vocabulary_id ='RxNorm' and a.concept_class_id ='Brand Name' and rs.relationship_id in ('Maps to', 'Has antineopl Rx' 
, 'Has immunosuppr Rx'
 , 'Has local therap Rx'
 'Has support med Rx'
 )  
--Clinical Drug Forms Picked up manually
union select  '1552344' , '2044421' 
union select '1670317' , '1670309'
union select '794048' , '1942741' 
union select '2119715', '2119717' -- Herceptin Hylecta , Hyaluronidase / trastuzumab Injection [Herceptin Hylecta]
union select '1927886' , '1927888' -- Rituxan Hycela , Hyaluronidase / rituximab Injection [Rituxan Hycela] 
)

update concept_relationship_stage rs
set concept_code_2 = (select new_code from repl where old_code = concept_code_2)
where exists (select 1 from repl where old_code = concept_code_2)
;
--build mappings to missing RxNorm, RxNorm Extension, need to do this because of RxNorm updates and adds new ingredients
insert into concept_relationship_stage
select null, null, a.concept_code, c.concept_code, a.vocabulary_id, c.vocabulary_id, 'Maps to', a.valid_start_date, a.valid_end_date from  concept_stage a
left join  concept_relationship_stage r on a.concept_code = r.concept_code_1 and a.vocabulary_id = r.vocabulary_id_1 and vocabulary_id_2  in ('RxNorm', 'RxNorm Extension') and r.relationship_id = 'Maps to'
join concept c on lower (a.concept_name) =  lower (c.concept_name) and c.standard_concept = 'S' and c.vocabulary_id like 'Rx%'
where a.concept_class_id = 'Component' and r.concept_code_1 is  null
;
--build relationship from Regimen to Standard concepts 
--only for newly added mappings between HemOnc and RxNorm (E)
insert into concept_relationship_stage
select * from ( 
select null::int, null::int, a.concept_code as concept_code_1, r2.concept_code_2, a.vocabulary_id as vocabulary_id_1, r2.vocabulary_id_2,
case when r.relationship_id = 'Has antineoplastic' then 'Has antineopl Rx' 
when r.relationship_id =  'Has immunosuppressor' then 'Has immunosuppr Rx'
when  r.relationship_id =  'Has local Therapy' then 'Has local therap Rx'
when r.relationship_id =  'Has supportive med' then 'Has support med Rx'
else null end as relationship_id,
 a.valid_start_date, a.valid_end_date 
 from  concept_stage a
join  concept_relationship_stage r on a.concept_code = r.concept_code_1 and a.vocabulary_id = r.vocabulary_id_1
join  concept_stage b on b.concept_code = r.concept_code_2 and b.vocabulary_id = r.vocabulary_id_2
join concept_relationship_stage r2 on r2.concept_code_1 = r.concept_Code_2 and r2.vocabulary_id_2 like 'Rx%' and r2.relationship_id ='Maps to'
where a.concept_class_id= 'Regimen' and b.concept_class_id = 'Component'
) z -- in order not to write the relationship_id case in the last condtioin, I use subquery
where (concept_code_1, relationship_id, concept_code_2, vocabulary_id_1, vocabulary_id_2) not in (select concept_code_1, relationship_id, concept_code_2,  vocabulary_id_1, vocabulary_id_2 from concept_relationship_Stage)
--now it gives 5765 rows affected - seems to be wrong
;

--get rid of concept_relationship_stage duplicates
create table concept_relationship_stage_tmp as select distinct * from  concept_relationship_stage
;
truncate table concept_relationship_stage
;
insert into concept_relationship_stage select * from concept_relationship_stage_tmp
;
drop table concept_relationship_stage_tmp
;
--to build hierarchy relationships from RxNorm (E) concepts
insert into concept_relationship_stage (concept_id_1,concept_id_2,concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date,invalid_reason)
select 
distinct --results in  Duplications, which should be fine as we can have different ways to go through
null::int, null::int, 
rb.concept_code_2, ra.concept_code_2, rb.vocabulary_id_2, ra.vocabulary_id_2, 'Subsumes', ra.valid_start_date, ra.valid_end_date, null from concept_relationship_stage ra --component  to rxnorm
join concept_relationship_stage rb on ra.concept_code_1 = rb.concept_code_1 -- component to component class
where ra.relationship_id = 'Maps to'
and rb.relationship_id = 'Is a'
;
--concept synonym
insert into concept_synonym_stage 
select s.* from hemonc_concept_synonym_stage s
join concept_stage on synonym_concept_code = concept_code and synonym_vocabulary_id = vocabulary_id 
and synonym_name is not null -- 15704 has empty name, typo, I suppose
;
--Was replaced by , need to tell Jeremy
update concept_relationship_stage set relationship_id = 'Concept replaced by' where relationship_id = 'Was replaced by'
;
update concept_stage set standard_concept = null, invalid_reason ='U' where concept_code in (select concept_code_1 from concept_relationship_stage where relationship_id = 'Concept replaced by')
;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
