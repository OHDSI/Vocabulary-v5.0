insert into concept_stage 
select * 
from basic_concept_stage
where concept_code not in (select concept_code from concept_stage) 
;
-- delete from basic_con_rel_stage where invalid_reason is not null
;
insert into concept_relationship_stage select * from basic_con_rel_stage
;
/*
delete from concept_stage a
using concept_stage b
WHERE
    a.ctid < b.ctid
    AND a.concept_code = b.concept_code
;
delete from concept_stage a
using concept_stage b
where 
	a.concept_name is null and
	b.concept_name is not null and
	a.concept_code = b.concept_code
;*/
;
delete from concept_stage a
where a.concept_name is null
;
drop table if exists insulins;
create table insulins
	(
		drug_code varchar,
		drug_concept_name varchar,
		gemscript_code varchar,
		concept_id int4,
		concept_name varchar
	)
;
/*WbImport -file=/home/ekorchmar/Downloads/NN_map_full_prdcode.txt
         -type=text
         -table=insulins
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=drug_code,drug_concept_name,gemscript_code,concept_id,concept_name
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100*/
;
/*--preserve nn_patch
insert into insulins
select distinct
	null :: int4, --don't mix cprd & thin codes
	n.source_name as concept_name,
	lpad (c.concept_code,8,'0'),
	n.concept_id_2,
	null :: varchar
from nn_patch n
join concept c on
	n.concept_id_1 = c.concept_id and
	n.concept_id_1 != 0 and
	c.concept_id is null and
-- 	c.standard_concept = 'S' and
	--avoid dupes
	not exists
		(
			select
			from insulins
			where 
			lpad (gemscript_code,8,'0') = lpad (c.concept_code,8,'0')
		)
;*/
--deprecate all old relations of concept_id = 0
insert into concept_relationship_stage
select distinct
	null :: int4,
	null :: int4,
	c.concept_code,
	c2.concept_code,
	'Gemscript',
	c2.vocabulary_id,
	'Maps to',
	r.valid_start_date,
	current_date - 1,
	'D'
from concept c
join insulins i on
	c.vocabulary_id = 'Gemscript' and
	c.concept_code = lpad (i.gemscript_code,8,'0') and
	i.concept_id = 0
join concept_relationship r on
	r.concept_id_1 = c.concept_id and
	relationship_id = 'Maps to' and
	r.invalid_reason is null
join concept c2 on
	c2.concept_id = r.concept_id_2
;
--not device, intentionally left unmapped
delete from concept_relationship_stage where concept_code_1 in (select gemscript_code from insulins where concept_id = 0) and concept_code_1 != concept_code_2 and invalid_reason is null
;
--fix deprecated
-- update insulins set concept_id = 19094121 where drug_code = '60951';
-- update insulins set concept_id = 19078603 where drug_code = '7300'
;
drop table if exists manual_rel
;
create table manual_rel as
select
	lpad (i.gemscript_code,8,'0') as concept_code_1,
	'Gemscript' as vocabulary_id_1,
	c.concept_code as concept_code_2,
	c.vocabulary_id as vocabulary_id_2
from insulins i
join concept c on
	c.concept_id = i.concept_id
where c.domain_id = 'Drug'
;/*
--manual fix for 1 influenza vaccine: should be fixed with future dm+d update
insert into manual_rel
values
	(
		'81761021',
		'Gemscript',
		'141',
		'CVX'
	)	
;*/
;
insert into manual_rel
with source_to_code as
	(
		select
			source_code,
			unnest(string_to_array(old_code_agg, '-')) as code
		from manual_2020
	),
source_to_concept as
	(
		select
			source_code,
			c.concept_code,
			c.vocabulary_id
		from source_to_code
		left join concept c on
			c.vocabulary_id ~ '^RxN' and
			c.concept_code = code
	)
select
	source_code,
	'Gemscript',
	concept_code,
	vocabulary_id
from source_to_concept
where
	(
		source_code,
		'Gemscript',
		concept_code,
		vocabulary_id
	)
	not in
	(select * from manual_rel)
;
delete from concept_relationship_stage where concept_code_1 in (select concept_code_1 from manual_rel)
;
insert into concept_relationship_stage
	(
		concept_code_1,
		vocabulary_id_1,
		concept_code_2,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date
	)
select
	concept_code_1,
	vocabulary_id_1,
	concept_code_2,
	vocabulary_id_2,
	'Maps to',
	CURRENT_DATE,
	to_date('20991231', 'yyyymmdd')
from manual_rel
;
update concept_stage
set standard_concept = 'S'
where
	domain_id = 'Device'
	and concept_code not in (select concept_code_1 from concept_relationship_stage where vocabulary_id_2 in ('dm+d','SNOMED') and invalid_reason is null)
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

-- Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

-- Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;
/*
--manualy deprecate
insert into concept_relationship_stage
	(
		concept_code_1,
		vocabulary_id_1,
		concept_code_2,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
	)
values 
	(
		'63790020',
		'Gemscript',
		'OMOP3095547',
		'RxNorm Extension',
		'Maps to',
		to_date ('2017-08-02', 'yyyy-mm-dd'),
		current_date - 1,
		'D'
	)
;*/
--we don't need dose form concepts
delete from concept_stage where concept_class_id = 'Dose Form'
;
--Checked: dose forms exclusively
delete from concept_relationship_stage where concept_code_1 not in (select concept_code from concept_stage)
;
--for new vaccine and device mappings, since old mappings to RxN* are not deprecated automatically
insert into concept_relationship_stage
select distinct
	null :: int4,
	null :: int4,
	c.concept_code,
	c2.concept_code,
	'Gemscript',
	c2.vocabulary_id,
	'Maps to',
	r.valid_start_date,
	current_date - 1,
	'D'
from concept_relationship r
join concept c on 
	c.concept_id = r.concept_id_1 and
	c.vocabulary_id = 'Gemscript' and
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

--if there is a mapping to gemscript (where from?) and any other vocab, deprecate it
/*
update concept_relationship_stage x
set
	invalid_reason = 'D',
	valid_end_date = current_date - 1 */
--delete it entirely
delete from concept_relationship_stage x
where
	invalid_reason is null and
	vocabulary_id_2 = 'Gemscript' and
	x.concept_code_1 in
		(
			select concept_code_1
			from concept_relationship_stage
			where
				invalid_reason is null and
				vocabulary_id_2 != 'Gemscript'
		)
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
				y.vocabulary_id_2 not like 'RxN%' and
				y.vocabulary_id_2 != 'Gemscript' --not inside itself
		)
;
--there are old concept codes that are less than 8 characters in length
--we just deprecate them and their existing mappings
with concept_set as
	(
		select concept_code, concept_id
		from concept
		where 
			vocabulary_id = 'Gemscript' and
			length (concept_code) < 8
	)
insert into concept_relationship_stage 
select
	null :: int4,
	null :: int4,
	c.concept_code,
	g.concept_code,
	'Gemscript',
	g.vocabulary_id,
	r.relationship_id,
	r.valid_start_date as valid_start_date,
	current_date - 1 as valid_end_date,
	'D'
from concept_set c
join concept_relationship r on
	c.concept_id = r.concept_id_1
join concept g on
	g.concept_id = r.concept_id_2 and
	r.invalid_reason is null
;
--deprecate concepts too
with concept_set as
	(
		select *
		from concept
		where 
			vocabulary_id = 'Gemscript' and
			length (concept_code) < 8
	)
insert into concept_stage
select distinct
	null :: int4 as concept_id,
	c.concept_name,
	c.domain_id,
	c.vocabulary_id,
	c.concept_class_id,
	null ::varchar as standard_concept,
	c.concept_code,
	c.valid_start_date,
	current_date - 1 as valid_end_date,
	'D' as invalid_reason
from concept_set c
;
--if there is a duplicate relationship inside a vocabulary, remove it
delete from concept_relationship_stage x
where
	x.invalid_reason is not null and
	exists
		(
			select
			from concept_relationship_stage y
			where
				(y.concept_code_1,y.concept_code_2,y.vocabulary_id_1,y.vocabulary_id_2) = (x.concept_code_1,x.concept_code_2,x.vocabulary_id_1,x.vocabulary_id_2) and
				y.invalid_reason is null
		)
;
-- if there is a mapping to SNOMED, remove other maps to
delete from concept_relationship_stage x
where
	x.vocabulary_id_2 != 'SNOMED' and
	x.relationship_id = 'Maps to' and
	exists
		(
			select
			from concept_relationship_stage y
			where
				(y.concept_code_1,y.vocabulary_id_1) = (x.concept_code_1,x.vocabulary_id_1) and
				y.invalid_reason is null and
				y.vocabulary_id_2 = 'SNOMED' and
				y.relationship_id = 'Maps to'
		)
;
-- if there is a mapping to CVX in crs, manually deprecate other maps to
insert into concept_relationship_stage
select
	null :: int4,
	null :: int4,
	crs.concept_code_1,
	t.concept_code,
	crs.vocabulary_id_1,
	t.vocabulary_id,
	r.relationship_id,
	r.valid_start_date,
	current_date - 1,
	'D' as invalid_reason
from concept_relationship_stage crs
join concept x on
	crs.concept_code_1 = x.concept_code and
	crs.vocabulary_id_1 = x.vocabulary_id
join concept_relationship r on
	r.invalid_reason is null and
	r.relationship_id = 'Maps to' and
	x.concept_id = r.concept_id_1
join concept t on
	t.vocabulary_id != 'CVX' and
	t.concept_id = r.concept_id_2
where
	crs.vocabulary_id_2 = 'CVX' and
	crs.relationship_id = 'Maps to' and
	crs.invalid_reason is null and
	not exists
		(
			select
			from concept_relationship_stage y
			where
				(y.concept_code_1, y.concept_code_2, y.vocabulary_id_1, y.vocabulary_id_2) = (crs.concept_code_1, t.concept_code, crs.vocabulary_id_1, t.vocabulary_id)
		)
;
--no standard concepts can have mappings to other vocabs
update concept_stage
set standard_concept = null
where
	concept_code in (select concept_code_1 from concept_relationship_stage where invalid_reason is null and relationship_id = 'Maps to' and vocabulary_id_2 != 'Gemscript') and
	standard_concept is not null
;
-- Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
end; $_$;


-- Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
end; $_$;


-- Add mapping from deprecated to fresh concepts, and also from non-standard to standard concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
end; $_$;
;
analyze concept_relationship_stage
;
-- Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
end; $_$;
--deprecated relationships are meaningless if they never existed in the first place
-- explain
delete from concept_relationship_stage c
where
	c.invalid_reason is not null and
	c.relationship_id = 'Maps to' and
	(c.concept_code_1, c.concept_code_2, c.vocabulary_id_1, c.vocabulary_id_2) not in
	(
		select c1.concept_code, c2.concept_code, c1.vocabulary_id, c2.vocabulary_id
		from concept_relationship r
		join concept c1 on c1.concept_id = r.concept_id_1 and r.invalid_reason is null and r.relationship_id = 'Maps to' and c1.vocabulary_id = 'Gemscript'
		join concept c2 on c2.concept_id = r.concept_id_2
	)
;
--if Gemscript device remains standard, restore a mapping to it from THIN
-- explain
insert into concept_relationship_stage
select distinct
	null :: int4,
	null :: int4,
	cs.concept_code,
	tc.concept_code,
	cs.vocabulary_id,
	tc.vocabulary_id,
	'Maps to',
	m.valid_start_date,
	m.valid_end_date,
	null :: varchar as invalid_reason
from concept_stage cs
join thin_gemsc_dmd t on
	cs.concept_class_id = 'Gemscript THIN' and
	cs.concept_code = t.encrypted_drugcode
join concept_stage tc on
	tc.concept_code = t.gemscript_drugcode and
	tc.domain_id = 'Device' and
	tc.vocabulary_id = 'Gemscript'
join concept_relationship_stage m on -- has mapping to itself ergo standard
	m.concept_code_1 = tc.concept_code and
	m.concept_code_2 = tc.concept_code and
	m.vocabulary_id_1 = 'Gemscript' and
	m.vocabulary_id_2 = 'Gemscript'
where 
	not exists
		(
			select
			from concept_relationship_stage
			where
				(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2) = (cs.concept_code,tc.concept_code,cs.vocabulary_id,tc.vocabulary_id)
		) and
	cs.concept_code not in (select concept_code_1 from concept_relationship_stage where invalid_reason is null)
;
--fix domains (mapping target sets for mapping source)
update concept_stage s
set domain_id =
	(
		select distinct c2.domain_id
		from concept_relationship_stage r
		join concept_stage c1 on (c1.concept_code, c1.vocabulary_id) = (r.concept_code_1, r.vocabulary_id_1)
		join concept_stage c2 on (c2.concept_code, c2.vocabulary_id) = (r.concept_code_2, r.vocabulary_id_2) and c1.domain_id != c2.domain_id
		where c1.concept_code = s.concept_code
	)
where concept_code in
	(
		select c1.concept_code
		from concept_relationship_stage r
		join concept_stage c1 on (c1.concept_code, c1.vocabulary_id) = (r.concept_code_1, r.vocabulary_id_1)
		join concept_stage c2 on (c2.concept_code, c2.vocabulary_id) = (r.concept_code_2, r.vocabulary_id_2) and c1.domain_id != c2.domain_id
	)
;
--likewise, restore mapping for THIN concepts after thin_need_to_map
-- explain
insert into concept_relationship_stage
select distinct
	null :: int4,
	null :: int4,
	cs.concept_code,
	m.concept_code_2,
	cs.vocabulary_id,
	m.vocabulary_id_2,
	'Maps to',
	m.valid_start_date,
	m.valid_end_date,
	null :: varchar as invalid_reason
from concept_stage cs
join thin_gemsc_dmd t on
	cs.concept_class_id = 'Gemscript THIN' and
	cs.concept_code = t.encrypted_drugcode
join concept_stage tc on
	tc.concept_code = t.gemscript_drugcode and
	tc.vocabulary_id = 'Gemscript'
join concept_relationship_stage m on -- has mapping to standard
	m.concept_code_1 = tc.concept_code and
	m.invalid_reason is null and
	m.relationship_id = 'Maps to' and
	m.vocabulary_id_2 in ('RxNorm', 'RxNorm Extension', 'dm+d', 'SNOMED')
where 
	not exists
		(
			select
			from concept_relationship_stage
			where
				(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2) = (cs.concept_code,m.concept_code_2,cs.vocabulary_id,m.vocabulary_id_2)
		) and
	cs.concept_code not in (select concept_code_1 from concept_relationship_stage where invalid_reason is null)
;
delete from concept_stage where concept_name = concept_code --bug
;
--mapping to gemscript and another vocab? deprecate to gemscript
update concept_relationship_stage x
set
	invalid_reason = 'D',
	valid_end_date = current_date - 1
where
	invalid_reason is null and
	vocabulary_id_2 = 'Gemscript' and
	x.concept_code_1 in
		(
			select concept_code_1
			from concept_relationship_stage
			where
				invalid_reason is null and
				vocabulary_id_2 != 'Gemscript'
		)
;
update concept_stage s
set domain_id =
	(
		select distinct c2.domain_id
		from concept_relationship_stage r
		join concept_stage c1 on (c1.concept_code, c1.vocabulary_id) = (r.concept_code_1, r.vocabulary_id_1)
		join concept c2 on (c2.concept_code, c2.vocabulary_id) = (r.concept_code_2, r.vocabulary_id_2) and c1.domain_id != c2.domain_id
		where c1.concept_code = s.concept_code
	)
where concept_code in
	(
		select c1.concept_code
		from concept_relationship_stage r
		join concept_stage c1 on (c1.concept_code, c1.vocabulary_id) = (r.concept_code_1, r.vocabulary_id_1)
		join concept c2 on (c2.concept_code, c2.vocabulary_id) = (r.concept_code_2, r.vocabulary_id_2) and c1.domain_id != c2.domain_id
	)
;
delete from concept_relationship_stage where
relationship_id = 'Maps to' and
vocabulary_id_2 = 'Gemscript' and
invalid_reason is null and
concept_code_2 in 
	(
		select concept_code
		from concept_stage
		where domain_id = 'Drug'
	)
;
update concept_stage
set standard_concept = null
where domain_id = 'Drug'
;
create index if not exists idx_crs_targets on concept_relationship_stage (concept_code_2, vocabulary_id_2)
;
analyze concept_relationship_stage
;
delete from concept_relationship_stage r1
where
	exists
	(
		select
		from concept c1
		join concept_ancestor ca on
			ca.ancestor_concept_id = c1.concept_id and
-- 			ca.min_levels_of_separation > 0 and
			(c1.concept_code, c1.vocabulary_id) = (r1.concept_code_2, r1.vocabulary_id_2)
		join concept c2 on
			c2.concept_id = ca.descendant_concept_id
		join concept_relationship_stage r2 on
			(r1.concept_code_1) = (r2.concept_code_1) and
			(r2.concept_code_2, r2.vocabulary_id_2) != (r1.concept_code_2, r1.vocabulary_id_2) and
			(c2.concept_code, c2.vocabulary_id) = (r2.concept_code_2, r2.vocabulary_id_2) and
			r2.invalid_reason is null
	)
-- 	and r1.vocabulary_id_2 in ('RxNorm', 'RxNorm Extension')
	and r1.invalid_reason is null
;
update concept_stage set concept_name = trim (concept_name)
;
update concept_relationship_stage
set invalid_reason = null,
valid_end_date = to_date ('20991231','yyyymmdd') 
where valid_start_date > valid_end_date
;
delete from concept_relationship_stage where concept_code_2 is null
;
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
values
	('35204020','OMOP4742295','Gemscript','RxNorm Extension','Maps to','2020-08-01','2099-12-31'),
	('42961021','OMOP2784462','Gemscript','RxNorm Extension','Maps to','2020-08-01','2099-12-31'),
	('63784020','OMOP552650','Gemscript','RxNorm Extension','Maps to','2020-08-01','2099-12-31'),
	('63787020','1360482','Gemscript','RxNorm','Maps to','2020-08-01','2099-12-31'),
	('09790020','OMOP302708','Gemscript','RxNorm Extension','Maps to','2020-08-01','2099-12-31'),
	('13628020','OMOP2781193','Gemscript','RxNorm Extension','Maps to','2020-08-01','2099-12-31'),
	('98505998','343099','Gemscript','RxNorm','Maps to','2020-08-01','2099-12-31'),
	('53971020','343099','Gemscript','RxNorm','Maps to','2020-08-01','2099-12-31'),
	('60642021','OMOP319607','Gemscript','RxNorm Extension','Maps to','2020-08-01','2099-12-31'),
	('09794020','OMOP2782332','Gemscript','RxNorm Extension','Maps to','2020-08-01','2099-12-31'),
	('09796020','OMOP2610438','Gemscript','RxNorm Extension','Maps to','2020-08-01','2099-12-31'),
	('60643021','OMOP319607','Gemscript','RxNorm Extension','Maps to','2020-08-01','2099-12-31')
;
update concept_relationship_stage
set vocabulary_id_2 = 'CVX', concept_code_2 = '129'
where concept_code_1 in ('88913998', '84802020')
;
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
values
	('89503021','141','Gemscript','CVX','Maps to','2020-08-01','2099-12-31'),
	('83346021','141','Gemscript','CVX','Maps to','2020-08-01','2099-12-31'),
	('85480021','141','Gemscript','CVX','Maps to','2020-08-01','2099-12-31')
;
update concept_stage s
set standard_concept = 'S',
domain_id = 'Device'
where domain_id = 'Drug' and
concept_code not in (select concept_code_1 from concept_relationship_stage where invalid_reason is null and concept_code_1 = s.concept_code) and
exists
	(
	select 1
	from devv5.concept
	where
		domain_id = 'Device' and
		vocabulary_id = 'Gemscript' and
		concept_code = s.concept_code
	)
;
update concept_relationship_stage set
concept_code_2 = '378923' and
vocabulary_id_2 = 'RxNorm'
where concept_code_1 in ('98222998','55101020')