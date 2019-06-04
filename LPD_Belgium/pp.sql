--we use postprocessing script instead of concept_relationship_manual to keep it for manual adjustments

--avoid confusion and duplicates (sourced from devices)
delete from concept_relationship_stage
where
	vocabulary_id_1 = 'LPD_Belgium' and
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