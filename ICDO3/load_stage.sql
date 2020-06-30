-- 0. Vocabulary update routine
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ICDO3',
	pVocabularyDate			=> TO_DATE ('20200630', 'yyyymmdd'), -- https://seer.cancer.gov/ICDO3/
	pVocabularyVersion		=> 'ICDO3 SEER Site/Histology Released 06/2019',
	pVocabularyDevSchema	=> 'DEV_icdo3'
);
END $_$
;
truncate table concept_stage, concept_relationship_stage, concept_synonym_stage
;
--1. Reformat sources
---Topography
;
update topo_source_iacr
set
	code = substring (trim(source_string),'^C\d\d\.?\d?'),
	concept_name = regexp_replace (trim(source_string), '^C\d\d\.?\d?\s+', '')
;
update topo_source_iacr
set concept_name = left (concept_name, 1) || replace (right (lower (concept_name), -1), ', nos', ', NOS')
where concept_name = upper (concept_name)
;
-- 2. Start building the hierarchy for progagating domain_ids from top to bottom
DROP TABLE IF EXISTS snomed_ancestor cascade;
CREATE UNLOGGED TABLE snomed_ancestor AS (
	WITH recursive hierarchy_concepts(ancestor_concept_code, descendant_concept_code, root_ancestor_concept_code, full_path) AS (
		SELECT ancestor_concept_code,
			descendant_concept_code,
			ancestor_concept_code AS root_ancestor_concept_code,
			ARRAY [descendant_concept_code::text] AS full_path
		FROM concepts
		
		UNION ALL
		
		SELECT c.ancestor_concept_code,
			c.descendant_concept_code,
			root_ancestor_concept_code,
			hc.full_path || c.descendant_concept_code::TEXT AS full_path
		FROM concepts c
		JOIN hierarchy_concepts hc ON hc.descendant_concept_code = c.ancestor_concept_code
		WHERE c.descendant_concept_code::TEXT <> ALL (full_path)
		),
	active_concept as
	(
		select distinct
			c.id,
			first_value (c.active) over
				(
					partition by c.id
					order by c.effectivetime desc
				) as active
		from sources.sct2_concept_full_merged c
	),
	active_status as
		(
			select distinct
				r.sourceid,
				r.destinationid,
				first_value (r.active) over
					(
						partition by r.id
						order by r.effectivetime desc
					) as active
			from sources.sct2_rela_full_merged r
			join active_concept a1 on
				a1.id = r.sourceid and
				a1.active = 1
			join active_concept a2 on
				a2.id = r.destinationid and
				a2.active = 1
			where 
				r.typeid = 116680003 -- Is a
		),
	concepts AS 
		(
			SELECT
				sourceid AS ancestor_concept_code,
				destinationid AS descendant_concept_code
			FROM active_status
			where active = 1
		) 
	SELECT DISTINCT -- switched places for some reason
		hc.root_ancestor_concept_code :: varchar AS descendant_concept_code,
		hc.descendant_concept_code :: varchar AS ancestor_concept_code 
	FROM hierarchy_concepts hc
)
;
--add relation to self for each target
insert into snomed_ancestor
SELECT DISTINCT
	descendant_concept_code AS descendant_concept_code,
	descendant_concept_code AS ancestor_concept_code 
FROM snomed_ancestor hc
;

ALTER TABLE snomed_ancestor ADD CONSTRAINT xpksnomed_ancestor PRIMARY KEY (ancestor_concept_code,descendant_concept_code);

;
create index snomed_ancestor_a on snomed_ancestor (ancestor_concept_code)
;
create index snomed_ancestor_d on snomed_ancestor (descendant_concept_code)
;
ANALYZE snomed_ancestor;
;
--3. Prepare updates for histology mapping from SNOMED refset
drop table if exists snomed_mapping
;
create table snomed_mapping as
with active_concept as
	(
		select distinct
			c.id as c_id,
			first_value (c.active) over
				(
					partition by c.id
					order by c.effectivetime desc
				) as c_active
		from sources.sct2_concept_full_merged c
	)
select distinct
	referencedcomponentid as snomed_code,
	maptarget as icdo_code
from sources.der2_srefset_simplemapfull_int
join active_concept on
	c_id = referencedcomponentid and
	c_active = 1
where
	refsetid = '446608001' and
	active = 1 and
	maptarget like '%/%'
;
--Remove descendants where ancestor is specified as mapping target
delete from snomed_mapping m1
where exists
	(
		select
		from snomed_mapping m2
		join snomed_ancestor a on
			a.ancestor_concept_code != a.descendant_concept_code and
			a.descendant_concept_code = m2.snomed_code :: varchar and
			a.ancestor_concept_code = m1.snomed_code :: varchar and
			m2.icdo_code = m1.icdo_code
	)
;
--Remove ambiguous mappings
delete from snomed_mapping
where icdo_code in
	(
		select icdo_code
		from snomed_mapping
		group by icdo_code
		having count (1) > 1
	)
;
--4. Update histology mappings from SNOMED International refset
update r_to_c_all r
set
	relationship_id = 'Maps to',
	snomed_code = 
		(
			select s.snomed_code
			from snomed_mapping s
			where r.concept_code = s.icdo_code
		)
where
	r.concept_code in (select s.icdo_code from snomed_mapping s)
;
--5. Update histology mappings from CAP provided mappings
-- Licensing of provided mappings does not allow us to use them
/*with active_concept as
	(
		select distinct
			c.id as c_id,
			first_value (c.active) over
				(
					partition by c.id
					order by c.effectivetime desc
				) as c_active
		from sources.sct2_concept_full_merged c
	),
cap_map as
(
	select distinct
		left (icdo3morph,4) || '/' || right (icdo3morph,1) as icdo,
		conceptid
	from cap_mapping
	join active_concept on
		c_id = conceptid and
		c_active = 1
	where 
		icdo3_match ~ 'Match$' and
		snomed_match ~ 'Match$'
)
update r_to_c_all r
set
	relationship_id = 'Maps to',
	snomed_code = 
		(
			select c.conceptid
			from cap_map c
			where r.concept_code = c.icdo
		)
where
	concept_code in 
		(
			select icdo
			from cap_map
			group by icdo
			having count (conceptid) =1
		)*/
;
--Remove duplications
delete from r_to_c_all r1
where exists
	(
		select
		from r_to_c_all r2
		where
			r1.concept_code = r2.concept_code and
			r2.snomed_code = r1.snomed_code and
			r2.ctid < r1.ctid
	)
;
--6. Populate concept stage with attributes
 --preserve missing morphology mapped to generic neoplasm
delete from r_to_c_all where concept_code = '9999/9'
;
insert into r_to_c_all
--Code 9999/9 must NOT be encountered in final tables and should be removed during post-processing 
values
	(
		'9999/9',
		'Unknown histology',
		'Maps to',
		'108369006'
	)
;
create index if not exists rtca_target_vc on r_to_c_all (snomed_code)
;
analyze r_to_c_all
;
--Topography
insert into concept_stage (CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE)
select 
	null,
	trim (concept_name),
	case
		when code like '%.%'
		then 'Spec Anatomic Site'
		else 'Condition'
	end,
	'ICDO3',
	'ICDO Topography',
	case
		when code like '%.%'
		then null
		else 'C'
	end,
	code,
	(SELECT latest_update FROM vocabulary WHERE vocabulary_id='ICDO3'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from topo_source_iacr
where code is not null
;
--Morphology
insert into concept_stage (CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select 
	null,
	trim (term),
	case
		when level like '_'
		then 'Condition'
		else 'Observation'
	end,
	'ICDO3',
	'ICDO Histology',
	case
		when level like '_'
		then 'C'
		else null
	end,
	icdo32,
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
	null
from morph_source_who
where
	level not in ('Related', 'Synonym') and
	icdo32 is not null
;
--Get obsolete and unconfirmed morphology concepts
insert into concept_stage (CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct
	trim (m.str),
	'Observation',
	'ICDO3',
	'ICDO Histology',
	null,
	m.code,
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id='ICDO3'),
	'D'
from morph_to_snomed m
where m.code not in
	(
		select concept_code
		from concept_stage
		where concept_class_id = 'ICDO Histology'
	)
;

--7. Form table with replacements to handle historic changes for combinations and histologies
drop table if exists code_replace
;
--Explicitly stated histologies replacements
create table code_replace as
select
	code as old_code,
	substring (fate, '\d{4}\/\d$') as code,
	'ICDO Histology' as concept_class_id
from changelog_extract
where fate ~ 'Moved to \d{4}\/\d'

	union

select
	code as old_code,
	left (code,4) || '/' || right (fate,1) as code,
	'ICDO Histology' as concept_class_id
from changelog_extract
where fate ~ 'Moved to \/\d'
;
--Same names; old code deprecated
insert into code_replace
select 
	d2.concept_code as old_code,
	d1.concept_code as code,
	'ICDO Histology' as concept_class_id
from concept_stage d1
join concept_stage d2 on
	d1.invalid_reason is null and
	d2.invalid_reason is not null and
	d1.concept_name = d2.concept_name and
	d1.concept_class_id = 'ICDO Histology' and
	d2.concept_class_id = 'ICDO Histology'
left join code_replace on
	old_code = d2.concept_code
where old_code is null
;
--Form table with existing and old combinations
drop table if exists comb_table
;
--Existing
create table comb_table as
select distinct
	*,
	histology_behavior || '-' || site as concept_code
from sources.icdo3_valid_combination c
;
--Old; will be deprecated; transfer combinations to new concepts
insert into comb_table
select
	r.code,
	c.site,
	r.code || '-' || c.site as concept_code
from comb_table c
join code_replace r on
	r.old_code = c.histology_behavior
where
	(r.code,c.site,r.code || '-' || c.site) not in (select * from comb_table)
;
insert into code_replace
select
	c.concept_code as old_code,
	r.code || '-' || c.site as code,
	'ICDO Condition'
from comb_table c
join code_replace r on
	r.old_code = c.histology_behavior
;
insert into comb_table
--create mappings for missing topography/morphology
select
	'9999/9', -- unspecified morphology, mapped to generic neoplasm
	concept_code,
	'NULL-' || concept_code
from concept_stage
where 
	concept_class_id = 'ICDO Topography' and
	concept_code ~ '\.' -- not hierarchical

	union

select
	concept_code,
	'-1',--unspecified topography, combination will get mapped to concepts without a topography
	concept_code || '-NULL'
from concept_stage
where
	concept_class_id = 'ICDO Histology' and
	(standard_concept is null or standard_concept != 'C') -- not hierarchical
;
-- 8. Fill concept_stage with combinations
insert into concept_stage (CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct
		replace (m.concept_name, ', NOS', ', NOS,') ||
		' of '
		|| lower (left (t.concept_name, 1)) || right (t.concept_name, -1) as concept_name,
	'Condition',
	'ICDO3',
	'ICDO Condition',
	null,
	c.concept_code,
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	
	case when r.code is not null
		then (SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id='ICDO3')
		else TO_DATE ('31.12.2099', 'dd.mm.yyyy')
		end,
		
	case when r.code is not null
		then 'D'
		else null
	end
from comb_table c
join concept_stage m on
	c.histology_behavior = m.concept_code
join concept_stage t on
	c.site = t.concept_code
left join code_replace r on
	r.old_code = c.concept_code
where c.concept_code !~ '(9999\/9|NULL)'
;
--one-legged concepts
insert into concept_stage (CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct
	'Neoplasm defined only by histology: '||c.concept_name,
	'Condition',
	'ICDO3',
	'ICDO Condition',
	null,
	c.concept_code || '-NULL',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	case when r.code is not null
		then (SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id='ICDO3')
		else TO_DATE ('31.12.2099', 'dd.mm.yyyy')
		end,
		
	case when r.code is not null
		then 'D'
		else null
	end
from concept_stage c
left join code_replace r on
	r.old_code = c.concept_code || '-NULL'
where
	c.concept_class_id = 'ICDO Histology' and
	(c.standard_concept is null or c.standard_concept != 'C') -- not hierarchical
;
insert into concept_stage (CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select
	null,
	'Neoplasm defined only by topography: '||concept_name,
	'Condition',
	'ICDO3',
	'ICDO Condition',
	null,
	'NULL-' || concept_code,
	(SELECT latest_update FROM vocabulary WHERE vocabulary_id='ICDO3'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
	null	 
from concept_stage
where concept_class_id = 'ICDO Topography'
;
--9. Form stable list of existing precoordinated concepts in SNOMED
drop table if exists snomed_target_prepared cascade
;
--TODO: use source SNOMED files for better filtering
create table snomed_target_prepared as
WITH def_status as --form list of defined neoplasia concepts without extraneous relations
(
	select distinct 
		c.concept_code,
		first_value (f.statusid) over (partition by f.id order by f.effectivetime desc) as statusid
	from sources.sct2_concept_full_merged f
	join concept c on
		c.vocabulary_id = 'SNOMED' and
		c.standard_concept = 'S' and
		c.concept_code = f.id :: varchar
),
snomed_concept as
(
	select
		c.concept_id,
		c.concept_code,
		c.concept_name
	from concept c
	join snomed_ancestor a on
		a.ancestor_concept_code in
			(
				'399981008',	--Neoplasm and/or hamartoma
				'425333006'	--Myeloproliferative disorder
			) and
		a.descendant_concept_code = c.concept_code and
		c.vocabulary_id = 'SNOMED'
	join def_status d on
		d.statusid = 900000000000073002 and -- Fully defined
		d.concept_code = c.concept_code
	left join concept_relationship r on --concepts defined outside of ICDO3 model
		r.concept_id_1 = c.concept_id and
		r.relationship_id in
			(
				'Followed by',
				'Using finding inform',
				'Finding asso with',
				'Has interprets',
				'Has clinical course',
				'Using finding method',
				'Has causative agent',
				'Has interpretation',
				'Occurs after',
				'Has due to',
				'Has occurrence'
			)
	left join concept_relationship r1 on --refers to morphologies that are not neoplasms
		r1.relationship_id = 'Has asso morph' and
		r1.concept_id_1 = c.concept_id and
		not exists
			(
				select
				from snomed_ancestor
				join concept a on
					a.concept_id = r1.concept_id_2
				where
					ancestor_concept_code in 
						(
							'400177003',	--Neoplasm
							'4216275',	--Proliferation of hematopoietic cell type
							'25723000',	--Dysplasia
							'76197007'	--Hyperplasia
						) and
					descendant_concept_code = a.concept_code
			)
	where 
		r.relationship_id is null and
		r1.relationship_id is null and
		not exists --Branches that should not be considered 'defined'
			(
				select
				from snomed_ancestor x
				where
					x.descendant_concept_code = c.concept_code and
					x.ancestor_concept_code in
						(
							'111941005',	--Familial disease
							'255051004',	--Tumor of unknown origin
							'255054007',	--Tumor of ill-defined site
							'363357005',		--Malignant tumor of ill-defined site
							'127332000',	--Fetal neoplasm
							'115966001',	--Occupational disorder
							'10749871000119100',	--Malignant neoplastic disease in pregnancy
							'765205004',	--Disorder in remission
							'302817000',	--Malignant tumor of unknown origin or ill-defined site
							'109989006',	--Multiple myeloma
							'448563005'	--Functionless pituitary neoplasm
						)
			)
)
select distinct
	c.concept_code,
	c.concept_name,
	coalesce (x1.concept_code, '-1') as t_id, --preserve absent topography as meaning
	x2.concept_code as m_id
from snomed_concept c
left join concept_relationship r1 on 
	r1.concept_id_1 = c.concept_id and r1.relationship_id = 'Has finding site'
left join concept x1 on
	x1.concept_id = r1.concept_id_2 and
	x1.vocabulary_id = 'SNOMED' and
	not exists --topography may be duplicated (ancestor/descendant)
		(
			select
			from concept_relationship x
			join concept n on
				n.concept_id = x.concept_id_2
			join snomed_ancestor a on
				a.descendant_concept_code = n.concept_code and
				a.ancestor_concept_code = x1.concept_code and
				x.concept_id_1 = r1.concept_id_1 and
				x.relationship_id = 'Has finding site' and
				a.ancestor_concept_code != a.descendant_concept_code
		)
join concept_relationship r2 on 
	r2.concept_id_1 = c.concept_id and r2.relationship_id = 'Has asso morph'
join concept x2 on
	x2.concept_id = r2.concept_id_2 and
	x2.vocabulary_id = 'SNOMED' and
	not exists --morphology may be duplicated (ancestor/descendant)
		(
			select
			from concept_relationship x
			join concept n on
				n.concept_id = x.concept_id_2
			join snomed_ancestor a on
				a.descendant_concept_code = n.concept_code and
				a.ancestor_concept_code = x2.concept_code and
				x.concept_id_1 = r2.concept_id_1 and
				x.relationship_id = 'Has asso morph' and
				a.ancestor_concept_code != a.descendant_concept_code
		)
;
create index idx_snomed_target_prepared on snomed_target_prepared (concept_code)
;
create index idx_snomed_target_attr on snomed_target_prepared (m_id, t_id)
;
create index idx_snomed_target_m on snomed_target_prepared (m_id)
;
create index idx_snomed_target_t on snomed_target_prepared (t_id)
;
analyze snomed_target_prepared
;
delete from snomed_target_prepared a
where
	a.t_id = '-1' and
	exists
		(
			select
			from snomed_target_prepared b
			where
				a.concept_code = b.concept_code and
				b.t_id != '-1'
		)
;
analyze snomed_target_prepared
;
--10 Form mass of all possible matches to filter later
drop table if exists match_blob
;
create table match_blob as
select distinct
	o.concept_code as i_code,
	s.concept_code as s_id,
	s.m_id,
	s.t_id,

	case when
		(ta.descendant_concept_code = ta.ancestor_concept_code) and
		(t.relationship_id = 'Maps to')
		then true
		else false
	end as t_exact,

	case when
	(ma.descendant_concept_code = ma.ancestor_concept_code) and
	(m.relationship_id = 'Maps to') 
		then true
		else false
	end as m_exact

from comb_table o

--topography & up
join r_to_c_all t on
	t.concept_code = o.site
join snomed_ancestor ta on
	ta.descendant_concept_code = t.snomed_code

--morphology & up
join r_to_c_all m on
	m.concept_code = o.histology_behavior
join snomed_ancestor ma on
	ma.descendant_concept_code = m.snomed_code

join snomed_target_prepared s on
	s.t_id = ta.ancestor_concept_code and
	s.m_id = ma.ancestor_concept_code

where o.concept_code not in (select old_code from code_replace)
;
--match to concepts without topographies
insert into match_blob
select distinct
	cs.concept_code as i_code,
	s.concept_code as s_id,
	s.m_id,
	'-1',
	
	TRUE as t_exact,

	(ma.descendant_concept_code = ma.ancestor_concept_code) and
	(m.relationship_id = 'Maps to') as m_exact

from comb_table o
join concept_stage cs on o.concept_code = cs.concept_code

--morphology & up
join r_to_c_all m on
	m.concept_code = o.histology_behavior
join snomed_ancestor ma on
	ma.descendant_concept_code = m.snomed_code

join snomed_target_prepared s on
	s.t_id = '-1' and
	s.m_id = ma.ancestor_concept_code

where cs.concept_code not in (select old_code from code_replace)
;
create index idx_blob on match_blob (i_code, s_id)
;
create index idx_blob_s on match_blob (s_id)
;
analyze match_blob
;
--Delete concepts that mention topographies contradicting source condition
delete from match_blob m
where exists
	(
		select 1
		from snomed_target_prepared r
		where
			r.concept_code = m.s_id
            and not exists 
				(
					select 1
					from comb_table c
					join r_to_c_all t on t.concept_code = c.site
					join snomed_ancestor a on a.descendant_concept_code = t.snomed_code
                    where a.ancestor_concept_code=r.t_id
                    and c.concept_code = m.i_code
				)
			and r.t_id != '-1'
	)
;
--Delete concepts that mention morphologies contradicting source condition
delete from match_blob m
where exists
	(
		select 1
		from snomed_target_prepared r
		where
			r.concept_code = m.s_id
            and not exists 
				(
					select 1
					from comb_table c
					join r_to_c_all t on t.concept_code = c.histology_behavior
					join snomed_ancestor a on a.descendant_concept_code = t.snomed_code
                    where a.ancestor_concept_code=r.m_id
                    and c.concept_code = m.i_code
				)
	)
;
--Handle overlapping lesion
delete from match_blob
where
	s_id in (select descendant_concept_code from snomed_ancestor where ancestor_concept_code = '109821008') and --Overlapping malignant neoplasm of gastrointestinal tract
	i_code !~ '\.8$' --code for overlapping lesions
;
analyze match_blob
;
--malignant WBC disorder special
delete from match_blob
where
	s_id = '277543005' and --Malignant white blood cell disorder
	i_code not in
		(
			select c.concept_code
			from comb_table c
			join morph_to_snomed t on
				t.code = c.histology_behavior
			join snomed_ancestor ca on
				ca.ancestor_concept_code = '414388001' and --Hematopoietic neoplasm
				ca.descendant_concept_code = t.snomed_code :: varchar
		)
;
--CORE LOGIC: remove ancestors where descendants are available as targets
delete from match_blob m
where exists
	(
		select
		from snomed_ancestor a
		join match_blob b on
			b.s_id != m.s_id and
			b.s_id = a.descendant_concept_code and
			m.s_id = a.ancestor_concept_code and
			b.i_code = m.i_code	
	)
;
--11 Fill mappings and other relations to SNOMED in concept_relationship_stage
truncate concept_relationship_stage
;
--write 'Maps to' relations where perfect one-to-one mappings are available
with monorelation as
	(
		select i_code
		from match_blob
		group by i_code
		having count (distinct s_id) = 1
	)
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	m.i_code,
	m.s_id as concept_code,
	'ICDO3',
	'SNOMED',
	'Maps to',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from match_blob m
join monorelation o using (i_code)
where
	m.t_exact and
	m.m_exact
;
--write 'Is a' for everything else
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	m.i_code,
	m.s_id,
	'ICDO3',
	'SNOMED',
	'Is a',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from match_blob m
left join concept_relationship_stage r on
	m.i_code = r.concept_code_1
where r.concept_code_1 is null
;
--write relations for attributes
----Maps to
with monorelation as
	(
		select concept_code as code1
		from r_to_c_all
		where relationship_id = 'Maps to'
		group by concept_code
		having count (snomed_code) = 1
	)
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	concept_code,
	snomed_code,
	'ICDO3',
	'SNOMED',
	'Maps to',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from r_to_c_all
join monorelation on concept_code = code1
left join code_replace on
	old_code = concept_code
where old_code is null and snomed_code != '-1'
;
----Is a
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	concept_code,
	snomed_code,
	'ICDO3',
	'SNOMED',
	'Is a',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from r_to_c_all
where concept_code not in
	(
		select concept_code_1
		from concept_relationship_stage
	) and
	concept_code != '9999/9' and
	snomed_code != '-1'
;
--12. Create internal hierarchy for attributes and combos
drop table if exists attribute_hierarcy
;
--Internal hierarchy for morphology attribute
create table attribute_hierarcy as
with hierarchy as
(
	select
		level, -- 2 and 3
		icdo32 as concept_code,
		substring (icdo32, '^\d{3}') as start_code,
		substring (icdo32, '\d{3}$') as end_code
	from morph_source_who 
	join concept_stage on
		concept_code = icdo32
	where level in ('2','3')
),
relation_hierarchy as
--Level 3 should be included in 2
(
	select
		h3.concept_code as descendant_code,
		h2.concept_code as ancestor_code,
		'H'--ierarchy
			as reltype
	from hierarchy h2
	join hierarchy h3 on
		h2.level = '2' and
		h3.level = '3' and
		h2.start_code <= h3.start_code and
		h2.end_code >= h3.end_code
),
relation_atom as
(
	select
		s.concept_code as descendant_code,
		h.concept_code as ancestor_code,
		'A'--tom
			as reltype
	from concept_stage s
	join hierarchy h on
		s.concept_code between start_code and end_code
	where
		s.concept_class_id = 'ICDO Histology' and
		s.concept_code not in (select old_code from code_replace) and
		s.standard_concept is null and
		--avoid jump from 2 to atom where 3 is available; concept_ancestor will not care
		h.concept_code not in
			(
				select descendant_code
				from relation_hierarchy
			)
)
select *
from relation_hierarchy

	union all

select *
from relation_atom
;
insert into attribute_hierarcy
--Internal hierarchy for topography attribute
select
	t1.code,
	t2.code,
	'A'
from topo_source_iacr t1
join topo_source_iacr t2 on
	t1.code ~ '\.' and
	t2.code !~ '\.' and
	t1.code like t2.code || '.%'
;
--Write 'Is a' for hierarchical concepts
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select
	ancestor_code,
	descendant_code,
	'ICDO3',
	'ICDO3',
	'Subsumes',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from attribute_hierarcy
where reltype = 'H'
;
--Write 'Is a' for combinations to Classification attributes
--Write 'Is a' for hierarchical Histologies
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	a.ancestor_code,
	coalesce (m.concept_code_2,t.concept_code),
	'ICDO3',
	coalesce (m.vocabulary_id_2,'ICDO3'),
	'Subsumes',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from attribute_hierarcy a
join comb_table t on
	t.histology_behavior = a.descendant_code
left join code_replace r on
	r.old_code = t.concept_code
left join concept_relationship_stage m on --check if mapping to SNOMED is present; if yes, SNOMED concept should be here instead
	m.relationship_id = 'Maps to' and
	m.concept_code_1 = t.concept_code
where
	a.reltype = 'A' and
	r.old_code is null
;
--Write 'Is a' for hierarchical Topographies
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	a.ancestor_code,
	coalesce (m.concept_code_2,t.concept_code),
	'ICDO3',
	coalesce (m.vocabulary_id_2,'ICDO3'),
	'Subsumes',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from attribute_hierarcy a
join comb_table t on
	t.site = a.descendant_code
left join code_replace r on
	r.old_code = t.concept_code
left join concept_relationship_stage m on --check if mapping to SNOMED is present; if yes, SNOMED concept should be here instead
	m.relationship_id = 'Maps to' and
	m.concept_code_1 = t.concept_code
where
	a.reltype = 'A' and
	r.old_code is null
;
drop table if exists legacy_comb
;
create table legacy_comb as
-- 13. Create classification combinations for hierarchy-level topographies (supports previously created concepts)  
select distinct
	c.histology_behavior,
	c.site,
	c.concept_code,
	a.ancestor_code as ancestor_site,
	c.histology_behavior || '-' || a.ancestor_code as ancestor_code
from comb_table c
join attribute_hierarcy a on
	c.site = a.descendant_code and
	a.reltype = 'A'
left join code_replace r on
	r.old_code = c.concept_code
where 
	r.old_code is null and
	c.histology_behavior != '9999/9'
;
insert into concept_stage
select distinct
	null :: int4,
		replace (m.concept_name, ', NOS', ', NOS,') ||
		' of '
		|| lower (left (t.concept_name, 1)) || right (t.concept_name, -1) as concept_name,
	'Condition',
	'ICDO3',
	'ICDO Condition',
	'C',
	c.ancestor_code,
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from legacy_comb c
join concept_stage m on
	c.histology_behavior = m.concept_code
join concept_stage t on
	c.ancestor_site = t.concept_code
where c.concept_code !~ '(9999\/9|NULL)'
;
--preserve classification of SNOMED concepts
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	a.ancestor_code,
	coalesce (m.concept_code_2,a.concept_code),
	'ICDO3',
	coalesce (m.vocabulary_id_2,'ICDO3'),
	'Subsumes',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from legacy_comb a
left join concept_relationship_stage m on --check if mapping to SNOMED is present; if yes, SNOMED concept should be here instead
	m.relationship_id = 'Maps to' and
	m.concept_code_1 = a.concept_code
;
--14. Form internal relations (to attributes)
--write internal relations
---Histology
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select
	c1.concept_code,
	c1.histology_behavior,
	'ICDO3',
	'ICDO3',
	'Has Histology ICDO',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from comb_table c1
left join code_replace c2 on
	c2.old_code = c1.concept_code
where c2.old_code is null
;
---Topography
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select
	c1.concept_code,
	c1.site,
	'ICDO3',
	'ICDO3',
	'Has Topography ICDO',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from comb_table c1
left join code_replace c2 on
	c2.old_code = c1.concept_code
where 
	c2.old_code is null and
	c1.site != '-1'
;
--standard conditions should have 'Has asso morph' & 'Has finding site' from SNOMED parents
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	s.concept_code,
	o.concept_code,
	'ICDO3',
	'SNOMED',
	a.relationship_id,
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from concept_stage s
join concept_relationship_stage r on
	s.concept_class_id = 'ICDO Condition' and
	r.concept_code_1 = s.concept_code and
	r.relationship_id = 'Is a'
join concept t on
	t.concept_code = r.concept_code_2 and
	t.vocabulary_id = 'SNOMED'
join concept_relationship a on
	a.invalid_reason is null and
	a.concept_id_1 = t.concept_id and
	a.relationship_id in
		(
			'Has asso morph',
			'Has finding site'
		)
join concept o on
	o.concept_id = a.concept_id_2
;
--remove parents as target attributes
delete from concept_relationship_stage s
where
	relationship_id in ('Has asso morph','Has finding site') and
	exists
	(
		select
		from concept_relationship_stage s2
		join concept cd on
			s2.concept_code_2 = cd.concept_code and
			cd.vocabulary_id = 'SNOMED' and
			s2.concept_code_1 = s.concept_code_1 and
			s.relationship_id = s2.relationship_id 
		join concept_ancestor a on
			cd.concept_id = a.descendant_concept_id and
			a.min_levels_of_separation <> 0
		join concept ca on
			ca.concept_id = a.ancestor_concept_id and
			ca.concept_code = s.concept_code_2
	)
;
--15. Handle replacements and self-mappings
--Add replacements from code_replace
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select
	old_code,	
	code,
	'ICDO3',
	'ICDO3',
	'Concept replaced by',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from code_replace cr
;
--Add mappings for replaced concepts
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select
	cr.old_code,	
	coalesce (r.concept_code_2,cr.code),
	'ICDO3',
	coalesce (r.vocabulary_id_2,'ICDO3'),
	'Maps to',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from code_replace cr
left join concept_relationship_stage r on
	r.concept_code_1 = cr.code and
	r.relationship_id = 'Maps to' and
	r.invalid_reason is null
where
--Only for conditions or directly mapped Histologies
	(cr.concept_class_id = 'ICDO Condition' or r.concept_code_1 is not null)
;
--Make concepts without Maps to relations Standard
update concept_stage
set standard_concept = 'S'
where
	domain_id = 'Condition' and
	standard_concept is null and -- not 'C'
	invalid_reason is null and
	concept_code not in
		(
			select concept_code_1
			from concept_relationship_stage
			where relationship_id = 'Maps to'
		)
;
--Add self-"maps to" to Standard concepts
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select
	concept_code,
	concept_code,
	'ICDO3',
	'ICDO3',
	'Maps to',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from concept_stage
where standard_concept = 'S'
;
--15 Since our relationship list is cannonically complete, we deprecate all existing relationships if they are not reinforced in current release
--from ICDO3 to SNOMED
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date, invalid_reason)
select
	c.concept_code,
	c2.concept_code,
	'ICDO3',
	'SNOMED',
	r.relationship_id,
	r.valid_start_date,
	(
		select latest_update - 1
		from vocabulary
		where latest_update is not null
		limit 1
	),
	'D'
from concept_relationship r
join concept c on
	c.concept_id = r.concept_id_1 and
	c.vocabulary_id = 'ICDO3' and
	r.invalid_reason is null
join concept c2 on
	c2.concept_id = r.concept_id_2 and
	c2.vocabulary_id = 'SNOMED'
left join concept_relationship_stage s on
	s.concept_code_1 = c.concept_code and
	s.concept_code_2 = c2.concept_code and
	s.relationship_id = r.relationship_id
where s.concept_code_1 is null
;
--From ICDO to ICDO
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date, invalid_reason)
with rela as
--Ensure such relations were created this release (avoids mirroring problem)
(
	select distinct relationship_id
	from concept_relationship_stage
	where
		vocabulary_id_1 = 'ICDO3' and
		vocabulary_id_2 = 'ICDO3' and
		invalid_reason is null
)
select
	c.concept_code,
	c2.concept_code,
	'ICDO3',
	'ICDO3',
	r.relationship_id,
	r.valid_start_date,
	(
		select latest_update - 1
		from vocabulary
		where latest_update is not null
		limit 1
	),
	'D'
from concept_relationship r
join rela a using (relationship_id)
join concept c on
	c.concept_id = r.concept_id_1 and
	c.vocabulary_id = 'ICDO3' and
	r.invalid_reason is null
join concept c2 on
	c2.concept_id = r.concept_id_2 and
	c2.vocabulary_id = 'ICDO3'
left join concept_relationship_stage s on
	s.concept_code_1 = c.concept_code and
	s.concept_code_2 = c2.concept_code and
	s.relationship_id = r.relationship_id
where s.concept_code_1 is null
;
-- 16. Drop all temporary tables
drop table if exists  snomed_mapping, snomed_ancestor, snomed_target_prepared, attribute_hierarcy, comb_table, match_blob, legacy_comb, code_replace cascade
;