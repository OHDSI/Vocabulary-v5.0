delete from concept_relationship_stage
where
	concept_code_1 in (select source_code from tofix_vax where concept_id is not null) and
	vocabulary_id_1 = 'GGR' and
	relationship_id = 'Maps to'
;
insert into concept_relationship_stage
select
	null :: int4,
	null :: int4,
	v.source_code,
	c.concept_code,
	'GGR',
	c.vocabulary_id,
	'Maps to',
	(SELECT vocabulary_date FROM sources.ggr_ir LIMIT 1),
	to_date ('20991231','yyyymmdd') as valid_end_date,
	null as invalid_reason
from tofix_vax v
join concept c using (concept_id)
;
insert into concept_relationship_stage --deprecate old existing
select
	null :: int4,
	null :: int4,
	v.source_code,
	c.concept_code,
	'GGR',
	c.vocabulary_id,
	cr.relationship_id,
	cr.valid_start_date,
	(SELECT vocabulary_date FROM sources.ggr_ir LIMIT 1) - 1,
	'D'
from tofix_vax v
join concept x on
	(v.source_code, 'GGR') = (x.concept_code, x.vocabulary_id)
join concept_relationship cr on
	x.concept_id = cr.concept_id_1 and
	cr.relationship_id = 'Maps to' and
	cr.concept_id_2 != v.concept_id --not same as we map to
join concept c on
	c.concept_id = cr.concept_id_2
;
--Dose Forms are inconsistent between releases, discard them
delete from concept_relationship_stage where (concept_code_1, vocabulary_id_1) in (select concept_code, 'GGR' from concept_stage where concept_class_id = 'Dose Form')
;
delete from concept_stage where concept_class_id = 'Dose Form' and vocabulary_id = 'GGR'
;

--Discard pack component concepts
delete from concept_relationship_stage where (concept_code_1, vocabulary_id_1) in (select concept_code, 'GGR' from concept_stage where concept_class_id = 'Med Product Pack' and vocabulary_id = 'GGR' and concept_code like 'OMOP%')
;
delete from concept_stage where concept_class_id = 'Med Product Pack' and vocabulary_id = 'GGR' and concept_code like 'OMOP%'
;
delete from concept_relationship_stage where (concept_code_1, vocabulary_id_1) in (select concept_code, 'GGR' from concept_stage where concept_class_id = 'Ingredient' and vocabulary_id = 'GGR' and concept_code like 'OMOP%');
delete from concept_stage where concept_class_id = 'Ingredient' and vocabulary_id = 'GGR' and concept_code ~ 'OMOP';
insert into concept_stage (concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
select distinct
	null :: int4 as concept_id,
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
		(
			SELECT vocabulary_date FROM sources.ggr_ir LIMIT 1
		) - 1
		as valid_end_date,
	'D' as invalid_reason
from devv5.concept
where
	concept_code like 'OMOP%' and
	vocabulary_id = 'GGR' and invalid_reason is null
;
--deprecate 'Source - RxNorm eq' for ingredients -- should never exist
insert into concept_relationship_stage
select distinct
	null :: int4,
	null :: int4,
	c1.concept_code,
	c2.concept_code,
	'GGR',
	c2.vocabulary_id,
	'Source - RxNorm eq',
	r.valid_start_date,
		(
			SELECT vocabulary_date FROM sources.ggr_ir LIMIT 1
		) - 1,
	'D'
from concept_relationship r
join concept c1 on
	r.concept_id_1 = c1.concept_id and
	c1.vocabulary_id = 'GGR' and
	c1.concept_class_id = 'Ingredient' and
	r.invalid_reason is null and
	c1.invalid_reason is null and
	r.relationship_id = 'Source - RxNorm eq'
join concept c2 on
	r.concept_id_2 = c2.concept_id;
	

with doubles as (select concept_id_1 from concept_relationship cr
join concept on cr.concept_id_1 = concept_id where concept_code not in ( select concept_code from concept_stage)
and vocabulary_id = 'GGR'
and cr.relationship_id = 'Source - RxNorm eq'
and cr.invalid_reason is null
group by concept_id_1  having count(*)>1) 
insert into concept_relationship_stage
select distinct 
null :: int4, 
null :: int4, 
c.concept_code as concept_code_1, 
c1.concept_code as concept_code_2,
c.vocabulary_id as vocabulary_id_1, 
c1.vocabulary_id as vocabulary_id_2, 
cr.relationship_id, 
cr.valid_start_date, 
(select latest_update from vocabulary where vocabulary_id = 'GGR') - 1,
'D'
from doubles d
join concept_relationship cr using (concept_id_1)
join concept c on c.concept_id = cr.concept_id_1 
join concept c1 on c1.concept_id = cr.concept_id_2
where  cr.relationship_id = 'Source - RxNorm eq'
; 

insert into concept_relationship_stage
select distinct 
null :: int4,
null :: int4,
  c.concept_code as concept_code_1, 
  c1.concept_code as concept_code_2, 
  c.vocabulary_id as vocabulary_id_1, 
  c1.vocabulary_id as vocabulary_id_2, 
  cr.relationship_id, 
cr.valid_start_date, 
(select latest_update from vocabulary where vocabulary_id = 'GGR') -1,
'D'
from concept c
join concept_relationship cr on c.concept_id = cr.concept_id_1  
join concept c1 on concept_id_2 = c1.concept_id 
where c.vocabulary_id = 'GGR' 
and cr.invalid_reason is null 
and c.concept_class_id = 'Ingredient' 
and cr.relationship_id = 'Source - RxNorm eq';


