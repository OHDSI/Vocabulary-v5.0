/*;
update concept_relationship
set
	invalid_reason = 'D',
	valid_end_date = current_date - 1
where
	concept_id_1 in 
		(
			select c.concept_id
			from concept c
			join concept_relationship_stage r on
				r.concept_code_1 = c.concept_code and
				r.vocabulary_id_1 = c.vocabulary_id	and
				r.vocabulary_id_2 = 'CVX'
		) and
	relationship_id = 'Maps to'
;
update concept_relationship
set
	invalid_reason = 'D',
	valid_end_date = current_date - 1
where
	concept_id_2 in 
		(
			select c.concept_id
			from concept c
			join concept_relationship_stage r on
				r.concept_code_1 = c.concept_code and
				r.vocabulary_id_1 = c.vocabulary_id	and
				r.vocabulary_id_2 = 'CVX'
		) and
	relationship_id = 'Mapped from'*/
; -- old mappings to RxN* are not deprecated automatically
insert into concept_relationship_stage
select distinct
	null :: int4,
	null :: int4,
	c.concept_code,
	c2.concept_code,
	'dm+d',
	c2.vocabulary_id,
	'Maps to',
	r.valid_start_date,
	current_date - 1,
	'D'
from concept_relationship r
join concept c on 
	c.concept_id = r.concept_id_1 and
	c.vocabulary_id = 'dm+d' and
	r.relationship_id = 'Maps to'
join relationship_to_concept t on
	c.concept_code = t.concept_code_1
join concept cx on
	cx.concept_id = t.concept_id_2 and
	cx.vocabulary_id = 'CVX'
join concept c2 on
	c2.concept_id = r.concept_id_2
where c2.vocabulary_id like 'RxN%'
;--save CVX mappings from relationship_to_concept
insert into concept_relationship_stage
select
	null,
	null,
	r.concept_code_1,
	c.concept_code,
	'dm+d',
	c.vocabulary_id,
	'Maps to',
	current_date,
	TO_DATE('20991231','yyyymmdd'),
	null
from relationship_to_concept r
join concept c on
	r.concept_id_2 = c.concept_id and
	(
		c.vocabulary_id = 'CVX' or
		c.concept_class_id ~ '(Drug|Pack)'
	)
;
--Devices can and should be mapped to SNOMED as they are the same concepts
insert into concept_relationship_stage
select distinct
	null :: int4 as concept_id_1,
	null :: int4 as concept_id_2,
	c.concept_code as concept_code_1,
	x.concept_code as concept_code_2,
	'dm+d',
	'SNOMED',
	'Maps to',
	current_date as valid_start_date,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	null as invalid_reason
from concept_stage c 
join concept x on
	x.concept_code = c.concept_code and

	x.invalid_reason is null and
	x.vocabulary_id = 'SNOMED' and
	x.standard_concept = 'S' and 
	x.domain_id = 'Device' and -- some are Observations, we don't want them

	c.vocabulary_id = 'dm+d' and
	c.domain_id = 'Device'
;
--SNOMED mappings now take precedence
update concept_relationship_stage r
set 
	invalid_reason = 'D',
	valid_end_date = 
	(
        SELECT MAX(latest_update) - 1
        FROM vocabulary
        WHERE vocabulary_id IN (r.vocabulary_id_1, r.vocabulary_id_2)
              AND latest_update IS NOT NULL
      )
where
	vocabulary_id_2 != 'SNOMED' and
	relationship_id = 'Maps to' and
	invalid_reason is null and
	exists
		(
			select 
			from concept_relationship_stage
			where
				concept_code_1 = r.concept_code_1 and
				vocabulary_id_2 = 'SNOMED' and
				relationship_id = 'Maps to'
		)
;
update concept_stage 
set standard_concept = NULL
where
	domain_id = 'Device' and
	vocabulary_id = 'dm+d' and
	exists
		(
			select
			from concept_relationship_stage
			where
				concept_code_1 = concept_code and
				relationship_id = 'Maps to' and
				vocabulary_id_2 = 'SNOMED'
		)
;
analyze concept_relationship_stage;
--delete useless deprecations (non-existent relations)
delete from concept_relationship_stage i
where
	(concept_code_1, vocabulary_id_1, concept_code_2, vocabulary_id_2/*, relationship_id*/) not in
	(
		select
			c1.concept_code,
			c1.vocabulary_id,
			c2.concept_code,
			c2.vocabulary_id/*,
			r.relationship_id*/
		from concept_relationship r
		join concept c1 on
			c1.concept_id = r.concept_id_1 and
			(c1.concept_code, c1.vocabulary_id) = (i.concept_code_1, i.vocabulary_id_1)
		join concept c2 on
			c2.concept_id = r.concept_id_2 and
			(c2.concept_code, c2.vocabulary_id) = (i.concept_code_2, i.vocabulary_id_2)
	) and
	invalid_reason is not null
;

--add replacements for VMPs, replaced by source
insert into concept_stage
select
	null :: int4 as concept_id,
	coalesce (v.nmprev, v.nm) as concept_name,
	case --take domain ID from replacement drug
		when d.vpid is null then 'Drug'
		else 'Device'
	end as domain_id,
	'dm+d',
	'VMP',
	null :: varchar as standard_concept,
	v.vpidprev as concept_code,
	to_date ('19700101','yyyymmdd') as valid_start_date,
	coalesce (v.NMDT, current_date - 1) as valid_end_date,
	'U' as invalid_reason
from vmps v
left join vmps u on --make sure old code was not processed on it's own
	v.vpidprev = u.vpid
left join devices d on u.vpid = d.vpid
where
	v.vpidprev is not null and
	u.vpid is null
;
--Get replacement mappings for deprecated VMPs
insert into concept_relationship_stage
select distinct
	null :: int4,
	null :: int4,
	v.vpidprev,
	r.concept_code_2,
	'dm+d',
	r.vocabulary_id_2,
	'Maps to',
	(SELECT vocabulary_date FROM sources.f_lookup2 LIMIT 1),
	TO_DATE('20991231','yyyymmdd'),
	null
from vmps v
join concept_relationship_stage r on
	v.vpid = r.concept_code_1
where vpidprev is not null and
	vpidprev not in (select concept_code_1 from concept_relationship_stage where invalid_reason is null)
;

--deprecate all old maps
insert into concept_relationship_stage
select distinct
	null :: int4,
	null :: int4,
	c.concept_code,
	c2.concept_code,
	'dm+d',
	c2.vocabulary_id,
	'Maps to',
	r.valid_start_date,
	current_date - 1,
	'D'
from concept_relationship r
join concept c on 
	c.concept_id = r.concept_id_1 and
	c.vocabulary_id = 'dm+d' and
	r.relationship_id = 'Maps to'
join concept_stage cs on
	cs.concept_code = c.concept_code
join concept c2 on 
	c2.concept_id = r.concept_id_2
where
	not exists
		(
			select 1
			from concept_relationship_stage
			where
				concept_code_1 = c.concept_code and
				concept_code_2 = c2.concept_code and
				vocabulary_id_2 = c2.vocabulary_id
		)
;
-- Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

-- Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--deprecate old ingredient mappings
insert into concept_relationship_stage
select
	null :: int4,
	null :: int4,
	c.concept_code,
	c2.concept_code,
	c.vocabulary_id,
	c2.vocabulary_id,
	'Maps to',
	r.valid_start_date,
	current_date - 1,
	'D'
from concept c
join concept_relationship r on
	r.concept_id_1 = c.concept_id and
	r.relationship_id = 'Maps to' and
	r.invalid_reason is null and
	c.vocabulary_id = 'dm+d'
join concept c2 on
	c2.concept_id = r.concept_id_2 and
	c2.concept_class_id = 'Ingredient'
left join internal_relationship_stage i on
	i.concept_code_2 = c.concept_code
where
	i.concept_code_2 is null and
	c.concept_class_id not in
		('VMP','AMP','VMPP','AMPP')

update concept_stage set concept_name = trim(concept_name)
;

delete from concept_relationship_stage where concept_code_1 = '8203003' and invalid_reason is null
;