--concept stats
select domain_id, invalid_reason, count (concept_code)
from concept_stage
group by domain_id, invalid_reason
;
--mapping status
with concept_vocab as
	(
		select distinct
			s.concept_code,
			coalesce
				(
					vocabulary_id_2,
					'Unmapped'
				) as vocabulary_id
		from concept_stage s
		left join concept_relationship_stage r on
			s.concept_code = r.concept_code_1 and
			r.relationship_id = 'Maps to'
	),
vocab_agg as
	(
		select
			concept_code,
				string_agg (vocabulary_id, '/') over
				(
					partition by concept_code
					order by vocabulary_id asc
				) as vocabulary_id
		from concept_vocab
	)
select
	vocabulary_id,
	count (concept_code)
from vocab_agg
group by vocabulary_id
;
--concepts without antecedence (and not 3-digit)
--should be null
select *
from concept_stage
left join concept_relationship_stage on
	concept_code = concept_code_1 and
	relationship_id = 'Is a'
where
	concept_code_1 is null and
	concept_code !~ '^\d\-\d{2}$' -- 0-00
;
--duplicate names
with names as
(
	select concept_name
	from concept_stage
	group by concept_name
	having count (concept_code) > 1
)
select *
from concept_stage
where concept_name in (select * from names)
order by concept_name, concept_code
--either cutoff (full names still available in synonym) or deprecated
