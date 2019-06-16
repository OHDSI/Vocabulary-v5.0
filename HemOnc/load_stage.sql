
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'HemOnc',
	pVocabularyDate			=> to_date ('2019-05-30', 'yyyy-mm-dd'),
	pVocabularyVersion		=> 'HemOnc 2019-05-30',
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
when concept_class_id in ('Regimen', 'Component', 'Brand_Name', 'Component Class', 'Route', 'Regimen type') then 'Drug'
when concept_class_id in ('Condition', 'Condition Class', 'BioCondition') then 'Condition'
else 'Undefined' 
end as domain_id,
vocabulary_id, 
case when concept_class_id ='Brand_Name' then 'Brand Name' else concept_class_id end as concept_class_id, 
case when concept_class_id ='Component Class' then 'C' else standard_concept end as standard_concept
,concept_code,valid_start_date,valid_end_date, 
null as invalid_reason --fix when new release comes up
from hemonc_concept_stage where concept_class_id in 
(
'Regimen type' -- type 
,'Component Class' -- looks like ATC, perhaps require additional mapping to ATC, in a first run make them "C", then replace with ATC, still a lot of work 
,'Component' -- ingredient, Standard if there's no equivalent in Rx, RxE
,'Context' -- therapy intent or line or other Context, STANDARD
,'Regimen' -- Standard
,'Brand_Name',-- need to map to RxNorm, RxNorm Extension if possible, if not - leave it as is
'Route' ,
'Procedure'
)
and concept_name is not null
;
--concept_relationship_stage
insert into concept_relationship_stage
select distinct
concept_id_1,concept_id_2,concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,
case when  relationship_id = 'Has Route' then 'May have route' 
else 
--relationship_ids have this structure "First word only is initcap"
replace 
((initcap ( substring (lower (relationship_id), '[a-z]*\s')) 
||
regexp_replace (lower (relationship_id), '[a-z]*\s', '')
), 'rx', 'Rx') end as relationship_id
,
r.valid_start_date,r.valid_end_date,
case when 
r.invalid_reason ='NA' then null else r.invalid_reason end
 from concept_stage a
 join hemonc_concept_relationship_stage r on a.concept_code = r.concept_code_1 and a.vocabulary_id = r.vocabulary_id_1  
  join (select * from concept where vocabulary_id in ('RxNorm', 'RxNorm Extension') union select * from concept_stage) b on b.concept_code = r.concept_code_2 and b.vocabulary_id = r.vocabulary_id_2
  where relationship_id not in   (
'Has Been Compared To',
'Can Be Preceded By',
'Can Be Followed By'
)
;
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
--update wrong Maps to Brand Names and one totally incorrect drug form
--to do, make this step automatic
with repl as (
select distinct rs.concept_code_2 as old_code, b.concept_code as new_code from concept_relationship_stage rs
join concept a on a.concept_code = rs.concept_code_2 and rs.vocabulary_id_2 = a.vocabulary_id 
join concept_Relationship r on r.concept_id_1 = a.concept_id and r.relationship_id = 'Brand name of' and r.invalid_reason is null
join concept b on b.concept_class_id ='Ingredient' and b.standard_concept ='S' and b.concept_id = r.concept_id_2
join concept_stage cs on cs.concept_code = rs.concept_code_1 and cs.concept_name not like '% and %' -- fix this later
where a.vocabulary_id ='RxNorm' and a.concept_class_id ='Brand Name' and rs.relationship_id ='Maps to'
--Clinical Drug Forms Picked up manually
union select  '1552344' , '2044421' 
union select '1927886',  '1927883'
union select '1670317' , '1670309'
union select '794048' , '1942741' 
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
--need to build this because we added some new mappings 
insert into concept_relationship_stage
select * from ( 
select null::int, null::int, a.concept_code as concept_code_1, r2.concept_code_2, a.vocabulary_id as vocabulary_id_1, r2.vocabulary_id_2,
case when r.relationship_id = 'Has antineoplastic' then 'Has antineopl Rx' 
when r.relationship_id =  'Has immunosuppressor' then 'Has immunosuppr Rx'
when  r.relationship_id =  'Has local therapy' then 'Has local therap Rx'
when r.relationship_id =  'Has supportive med' then 'Has support med Rx'
else null end as relationship_id,
 a.valid_start_date, a.valid_end_date 
 from  concept_stage a
join  concept_relationship_stage r on a.concept_code = r.concept_code_1 and a.vocabulary_id = r.vocabulary_id_1
join  concept_stage b on b.concept_code = r.concept_code_2 and b.vocabulary_id = r.vocabulary_id_2
join concept_relationship_stage r2 on r2.concept_code_1 = r.concept_Code_2 and r2.vocabulary_id_2 like 'Rx%' and r2.relationship_id ='Maps to'
where a.concept_class_id= 'Regimen' and b.concept_class_id = 'Component'
) z -- in order not to write the relationship_id case in the last condtioin, I use subquery
where (concept_code_1, relationship_id, concept_code_2) not in (select concept_code_1, relationship_id, concept_code_2 from concept_relationship_Stage)
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