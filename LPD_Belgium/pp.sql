--we use postprocessing script instead of concept_relationship_manual to keep it for manual adjustments

--avoid confusion and duplicates (sourced from devices)
delete from concept_relationship_stage
where
	vocabulary_id_1 = 'LPD_Belgium' and
	invalid_reason is null and
	concept_code_1 in
	(
		select prod_prd_id
		from official_mappings
	)
;
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select
	o.prod_prd_id,
	c.concept_code,
	'LPD_Belgium',
	c.vocabulary_id,
	'Maps to',
	CURRENT_DATE,
	TO_DATE('20991231', 'yyyymmdd')
from official_mappings o
join concept c using (concept_id)
;
update concept_stage
set standard_concept = null
where
	domain_id = 'Device' and
	standard_concept = 'S' and
	concept_code in
		(
			select concept_code_1
			from concept_relationship_stage
			where
				vocabulary_id_2 != 'LPD_Belgium' and
				invalid_reason is null and
				relationship_id = 'Maps to'
		)
;
update concept_stage
set standard_concept = 'S'
where
	domain_id = 'Device' and
	standard_concept is null and
	concept_code not in
		(
			select concept_code_1
			from concept_relationship_stage
			where
				vocabulary_id_2 != 'LPD_Belgium' and
				invalid_reason is null and
				relationship_id = 'Maps to'
		)
;
-- we don't trust old mappings to ingredients
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date, invalid_reason)
select distinct
	c1.concept_code,
	c2.concept_code,
	'LPD_Belgium',
	c2.vocabulary_id,
	'Maps to',
	r.valid_start_date,
	(select latest_update from vocabulary where vocabulary_id = 'LPD_Belgium'),
	'D'
from concept_relationship r
join concept c1 on
	c1.concept_id = r.concept_id_1 and
	c1.vocabulary_id = 'LPD_Belgium' and
	r.relationship_id = 'Maps to'
join concept c2 on
	c2.concept_id = r.concept_id_2 and
	c2.concept_class_id = 'Ingredient'
join concept_stage cx on
	(c1.concept_code, c1.vocabulary_id) = (cx.concept_code, cx.vocabulary_id)
where
	(c1.concept_code,	c2.concept_code, 'LPD_Belgium', c2.vocabulary_id, 'Maps to') not in
	(
		select
			concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id
		from concept_relationship_stage
	)
;
--deprecate mappings to other vocabs, when mapping is made to non Rx vocab (devices to GGR or self, vaccines to CVX)
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date, invalid_reason)
select distinct
	c1.concept_code,
	c2.concept_code,
	'LPD_Belgium',
	c2.vocabulary_id,
	'Maps to',
	r.valid_start_date,
	(select latest_update from vocabulary where vocabulary_id = 'LPD_Belgium'),
	'D'
from concept_relationship r
join concept c1 on
	c1.concept_id = r.concept_id_1 and
	c1.vocabulary_id = 'LPD_Belgium' and
	r.relationship_id = 'Maps to'
join concept c2 on
	c2.concept_id = r.concept_id_2 and
	c2.vocabulary_id like 'RxN%'
join concept_relationship_stage crx on
	crx.invalid_reason is null and
	crx.relationship_id = 'Maps to' and
	crx.vocabulary_id_2 not like 'RxN%' and
	(c1.concept_code, c1.vocabulary_id) = (crx.concept_code_1, crx.vocabulary_id_1)
where
	(c1.concept_code,	c2.concept_code, 'LPD_Belgium', c2.vocabulary_id, 'Maps to') not in
	(
		select
			concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id
		from concept_relationship_stage
	)
;