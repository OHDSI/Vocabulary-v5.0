--insert relationship between vaccine and insulins to concept_relationship_manual
insert into concept_relationship_manual
select 
null::integer,
null::integer, 
fcc ,
concept_code,
'GRR',
vocabulary_id, 
'Maps to', 
current_date , 
TO_DATE('20991231', 'yyyymmdd'), 
null::varchar
from vacc_ins_manual
join devv5.concept on concept_id = c_id::integer;

-- Append result to concept_relationship_stage table
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;


--for new vaccine and device mappings, since old mappings to RxN* are not deprecated automatically
insert into concept_relationship_stage
select distinct
	null :: int4,
	null :: int4,
	c.concept_code,
	c2.concept_code,
	'GRR',
	c2.vocabulary_id,
	'Maps to',
	r.valid_start_date,
	current_date ,
	'D'
from concept_relationship r
join concept c on 
	c.concept_id = r.concept_id_1 and
	c.vocabulary_id = 'GRR' and
	r.relationship_id = 'Maps to' and
	r.invalid_reason is null
join concept c2 on
	c2.concept_id = r.concept_id_2 and
	c2.vocabulary_id like 'RxN%'
join concept_relationship_stage t on
	c.concept_code = t.concept_code_1 and
	t.vocabulary_id_2 not like 'RxN%'
where (c.concept_code, c2.concept_code) not in (select concept_code_1, concept_code_2 from concept_relationship_stage)
;
delete from concept_relationship_stage x
where
	x.invalid_reason is null and
	x.vocabulary_id_2 like 'RxN%' and
	x.relationship_id = 'Maps to' and
	exists	
		(
			select
			from concept_relationship_stage y
			where
				x.concept_code_1 = y.concept_code_1 and
				y.invalid_reason is null and
				y.relationship_id = 'Maps to' and
				y.vocabulary_id_2 not like 'RxN%'
		)
;