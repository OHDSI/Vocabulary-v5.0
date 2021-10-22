truncate concept_relationship_stage
;
insert into concept_relationship_stage
	(
		concept_id_1,
		concept_id_2,
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
	)
select distinct
	null :: int4,
	null :: int4,
	cs.concept_code,
	c.concept_code,
	cs.vocabulary_id,
	c.vocabulary_id,
	rel_id,
	to_date ('19700101', 'yyyyddmm'),
	to_date ('20993112', 'yyyyddmm'),
	null :: varchar
from concept_stage cs
join mappings m on
	m.procedure_id = cs.concept_id
join concept c on
	m.snomed_id = c.concept_id
;
drop table if exists attr_insert
;
create table attr_insert
	(
		icd_code varchar,
		relationship_id varchar,
		attribute_id int4
	)
;
-- explain
insert into attr_insert
--first, inherit all attributes from SNOMED ancestors; if SNOMED attribute is a descendant it will be used instead
/*with attr_replace as
	(
		select
			i.procedure_id,
			a.descendant_concept_id,
			i.attribute_id
		from icd10mappings i
		join ancestor_snomed a on
			i.attribute_id = a.ancestor_concept_id and
			i.concept_class_id != 'Procedure'
	)*/
select --distinct
	cs.concept_code, --by using code instead of id, we circumvent the need for SPLITTER table reusal
	sr.relationship_id,
-- 	coalesce (ar.attribute_id, sr.concept_id_2)
	sr.concept_id_2
from mappings m
join concept_stage cs on
	cs.concept_id = m.procedure_id
join snomed_relationship sr on
	m.snomed_id = sr.concept_id_1
--Replace procedures' attributes with descendants when such are present in icd10mappings
/*left join attr_replace ar on
	ar.procedure_id = cs.concept_id and
	sr.concept_id_2 = ar.descendant_concept_id*/
;
create index idx_attr_insert on attr_insert (icd_code,attribute_id)
;
analyze attr_insert
;
--remove duplicates
--actually faster now
--also eliminates has dir X/ has indir X -- DIRTY!
delete from attr_insert a
where
	exists
		(
			select 
			from attr_insert 
			where
				(icd_code,attribute_id) = (a.icd_code,a.attribute_id) and
				a.ctid > ctid -- hardware adress
		)
;
-- Now get attributes from icd10mappings
insert into attr_insert
select distinct --attribute_id, attribute_name, concept_class_id
	procedure_code,
	null :: varchar,
	attribute_id
from icd10mappings i
where
	(i.procedure_code, i.attribute_id) not in (select icd_code,attribute_id from attr_insert) and
	i.concept_class_id not in ('Procedure', 'Context-dependent') --procedures too
;
--if attribute has only one type of relations in concept_relationship table, pick it up
with no_alts as
	(
		select
			ai.attribute_id
		from snomed_relationship r
		join attr_insert ai on
			ai.relationship_id is null and
			ai.attribute_id = r.concept_id_2
		group by ai.attribute_id
		having count (distinct r.relationship_id) = 1
	)
update attr_insert
set
	relationship_id = (select distinct relationship_id from snomed_relationship where concept_id_2 = attribute_id)
where
	relationship_id is null and
	attribute_id in (select attribute_id from no_alts)
;
update attr_insert
set
	relationship_id = 
		(
			select
				case concept_class_id
					when 'Body Structure' then 'Has dir proc site'
					when 'Clinical Finding' then 'Has focus'
					when 'Observable Entity' then 'Has focus'
					when 'Pharma/Biol Product' then 'Using subst'
					when 'Physical Force' then 'Using energy'
					when 'Physical Object' then 'Using device'
					when 'Specimen' then 'Has specimen'
					when 'Substance' then 'Using subst'
					when 'Qualifier Value' then 'Has property'
					else 'Has component' --no other classes currently found
				end
			from concept
			where concept_id = attribute_id
		)
where
	relationship_id is null
;
delete from attr_insert a
where
	exists
		(
			select
			from attr_insert x
			join ancestor_snomed s on
				s.descendant_concept_id = x.attribute_id and
				s.ancestor_concept_id = a.attribute_id and
				s.min_levels_of_separation != 0
			where 
				x.icd_code = a.icd_code
				--and x.relationship_id = a.relationship_id
		)
;
insert into concept_relationship_stage
	(
		concept_id_1,
		concept_id_2,
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
	)
select 
	null :: int4,
	null :: int4,
	a.icd_code,
	c.concept_code,
	'ICD10PCS',
	c.vocabulary_id,
	a.relationship_id,
	to_date ('19700101', 'yyyyddmm'),
	to_date ('20993112', 'yyyyddmm'),
	null :: varchar
from attr_insert a
join concept c on
	c.concept_id = a.attribute_id
;
delete from concept_relationship_stage i
where
	exists
		(
			select
			from concept_relationship_stage x
			where 
				i.concept_code_1 = x.concept_code_1 and
				i.concept_code_2 = x.concept_code_2 and
				x.ctid > i.ctid
		)
;
--6. Add "subsumes" relationship between concepts where the concept_code is like of another
CREATE INDEX IF NOT EXISTS trgm_idx ON concept_stage USING GIN (concept_code devv5.gin_trgm_ops); --for LIKE patterns
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	c1.vocabulary_id AS vocabulary_id_1,
	c1.vocabulary_id AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = c1.vocabulary_id
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage c1,
	concept_stage c2
WHERE c2.concept_code LIKE c1.concept_code || '_'
	AND c1.concept_code <> c2.concept_code
/*	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage r_int
		WHERE r_int.concept_code_1 = c1.concept_code
			AND r_int.concept_code_2 = c2.concept_code
			AND r_int.relationship_id = 'Subsumes'
		)*/
-- limit 100
;
DROP INDEX trgm_idx;
;
--deprecate every old relationship entry;
insert into concept_relationship_stage 
	(
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
	)
-- explain
select 
	c1.concept_code,
	c2.concept_code,
	c1.vocabulary_id,
	c2.vocabulary_id,
	cr.relationship_id,
	cr.valid_start_date,
	current_date - 1 as valid_end_date,
	'D'
from concept_relationship cr
join concept c1 on
	c1.vocabulary_id = 'ICD10PCS' and
	c1.concept_id = cr.concept_id_1
join concept c2 on
	c2.vocabulary_id in (/*'ICD10PCS',*/ 'SNOMED') and
	c2.concept_id = cr.concept_id_2 and
	cr.relationship_id not in ('Maps to', 'Mapped from')
where
	(
		c1.concept_code,
		c2.concept_code,
		c1.vocabulary_id,
		c2.vocabulary_id,
		cr.relationship_id
	) not in
	(
		select
			concept_code_1,
			concept_code_2,
			vocabulary_id_1,
			vocabulary_id_2,
			relationship_id
		from concept_relationship_stage r
		
/*		union all
		
		select 
			concept_code_2,
			concept_code_1,
			vocabulary_id_2,
			vocabulary_id_1,
			reverse_relationship_id
		from concept_relationship_stage r
		join relationship using (relationship_id)*/
	)
;
--7. Add ICD10CM to RxNorm manual mappings
-- DO $_$
-- BEGIN
-- 	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
-- END $_$;

--8. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--9. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--10. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--11. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

truncate concept_relationship_manual;
insert into concept_relationship_manual (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date,invalid_reason)
select concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date,invalid_reason from concept_relationship_stage
