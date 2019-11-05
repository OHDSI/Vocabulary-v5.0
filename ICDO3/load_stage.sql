DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ICDO3',
	pVocabularyDate			=> TO_DATE ('20190601', 'yyyymmdd'), -- https://seer.cancer.gov/ICDO3/
	pVocabularyVersion		=> 'ICDO3 SEER Site/Histology Released 06/2019',
	pVocabularyDevSchema	=> 'DEV_icdo3'
);
END $_$
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
insert into morph_source_who
select distinct
	histology_behavior,
	'Preferred',
	histology_behavior_description,
	null :: varchar,
	null :: varchar
from comb_source_seer
where histology_behavior not in (select icdo32 from morph_source_who)
;
---morphology
delete from morph_source_who
where
	level like '_' --remove hierarchical concepts
;
drop table if exists comb_matched_seer cascade
;
create table comb_matched_seer as
with border as
(
	select distinct 
		substring ( trim (regexp_split_to_table (site_recode, ',')), '^C\d\d\d') as from_site_code,
		substring ( trim (regexp_split_to_table (site_recode, ',')), 'C\d\d\d$') as to_site_code,
		histology_behavior
	from comb_source_seer
)
select distinct
	b.histology_behavior as hist,
	t.code as site,
	b.histology_behavior||'-'||t.code as concept_code
from border b
join topo_source_iacr t on
	replace (t.code,'.','') between from_site_code and to_site_code

	union

select	
	*, --real data combinations
	 hist||'-'||site
from real_data_no_cr
where hist != '9999/9'
;
create index idx_comb on comb_matched_seer (concept_code)
;
analyze comb_matched_seer
;
-- Put attributes and combinations in concept_stage
truncate table concept_stage
;
--Topography
insert into concept_stage (CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select 
	null,
	trim (concept_name),
	'Observation',
	'ICDO3',
	'ICDO Topography',
	null,
	code,
	(SELECT latest_update FROM vocabulary WHERE vocabulary_id='ICDO3'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
	null
from topo_source_iacr
where code is not null
;
--Morphology
insert into concept_stage (CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select 
	null,
	trim (term),
	'Observation',
	'ICDO3',
	'ICDO Histology',
	null,
	icdo32,
	(SELECT latest_update FROM vocabulary WHERE vocabulary_id='ICDO3'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
	null
from morph_source_who
where 
	level = 'Preferred'
;
--manually add missing morphology -- if exists for source given combinations but is absent from official list)
insert into concept_stage (CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct
	trim (m.str),
	'Observation',
	'ICDO3',
	'ICDO Histology',
	null,
	m.code,
	(SELECT latest_update FROM vocabulary WHERE vocabulary_id='ICDO3'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
	null
from morph_to_snomed m
join comb_matched_seer c on
	c.hist = m.code
where m.code not in
	(
		select concept_code
		from concept_stage
		where concept_class_id = 'ICDO Histology'
	)
;
--Combinations
insert into concept_stage (CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select
	null,
	replace (m.concept_name, ', NOS', ', NOS,') ||
	' of '
	|| lower (left (t.concept_name, 1)) || right (t.concept_name, -1) as concept_name,
	'Condition',
	'ICDO3',
	'ICDO Condition',
	null,
	c.concept_code,
	(SELECT latest_update FROM vocabulary WHERE vocabulary_id='ICDO3'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
	null
from comb_matched_seer c
join concept_stage m on
	c.hist = m.concept_code
join concept_stage t on
	c.site = t.concept_code
;
delete from morph_to_snomed where code = '9999/9'
;
insert into morph_to_snomed --preserve missing morphology mapped to generic neoplasm
--Code 9999/9 must NOT be encountered in final tables and should be removed during post-processing 
values
	(
		'9999/9',
		'Unknown histology',
		'Maps to',
		4030314,
		'108369006',
		'Neoplasm',
		1
	)
;
insert into comb_matched_seer
--create mappings for missing topography/morphology
select
	'9999/9', -- unspecified morphology, mapped to generic neoplasm
	concept_code,
	'NULL-' || concept_code
from concept_stage
where concept_class_id = 'ICDO Topography'

	union

select
	concept_code,
	'0',--unspecified topography, will get mapped to concepts without a topography
	concept_code || '-NULL'
from concept_stage
where concept_class_id = 'ICDO Histology'
;
--one-legged concepts
insert into concept_stage (CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select
	null,
	'Neoplasm defined only by histology: '||concept_name,
	'Condition',
	'ICDO3',
	'ICDO Condition',
	null,
	concept_code || '-NULL',
	(SELECT latest_update FROM vocabulary WHERE vocabulary_id='ICDO3'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
	null	 
from concept_stage
where concept_class_id = 'ICDO Histology'
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
truncate concept_synonym_stage
;
--Populate concept_synonym_stage with morphologies
insert into concept_synonym_stage
--we ignore obsoletion status of synonyms for now: concepts may still be referenced by their old names in historical classifications
--ICDO3 does not distinguish between 'old' and 'wrong'
select
	null,
	trim (term),
	icdo32,
	'ICDO3',
	4180186 -- English
from morph_source_who
where level != 'Related' -- not actual synonyms
;
drop table if exists match_blob cascade
;
drop table if exists snomed_target_prepared cascade
;
create table snomed_target_prepared as
WITH def_status as --form list of defined neoplasia concepts without extraneous relations
(
	select distinct 
		c.concept_id,
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
		c.concept_name
	from concept c
	join concept_ancestor a on
		a.ancestor_concept_id in
			(
				4266186,	--Neoplasm and/or hamartoma
				4175485	--Myeloproliferative disorder
			) and
		a.descendant_concept_id = c.concept_id
	join def_status d on
		d.statusid = 900000000000073002 and -- Fully defined
		d.concept_id = c.concept_id
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
				'Has due to'
			)
	left join concept_relationship r1 on --refers to morphologies that are not neoplasms
		r1.relationship_id = 'Has asso morph' and
		r1.concept_id_1 = c.concept_id and
		not exists
			(
				select
				from concept_ancestor
				where
					ancestor_concept_id in 
						(
							4271032,	--Neoplasm
							4216275,	--Proliferation of hematopoietic cell type
							4093447,	--Dysplasia
							4296894	--Hyperplasia
						) and
					descendant_concept_id = r1.concept_id_2
			)
	where 
		r.relationship_id is null and
		r1.relationship_id is null and
		not exists --Branches that should not be considered 'defined'
			(
				select
				from concept_ancestor x
				where
					x.descendant_concept_id = c.concept_id and
					x.ancestor_concept_id in
						(
							4206181,	--Familial neoplastic disease
							4112992,	--Tumor of unknown origin
							4111016,	--Tumor of ill-defined site
							443389,		--Malignant tumor of ill-defined site
							4133025,	--Fetal neoplasm
							4020924,	--Occupational disorder
							45757107,	--Malignant neoplastic disease in pregnancy
							35622958,	--Disorder in remission
							4118990,	--Malignant tumor of unknown origin or ill-defined site
							437233,	--Multiple myeloma
							40490469	--Functionless pituitary neoplasm
						)
			)
)
select distinct
	c.concept_id,
	c.concept_name,
	coalesce (r1.concept_id_2, -1) as t_id, --preserve absent topography as meaning
	r2.concept_id_2 as m_id
from snomed_concept c
left join concept_relationship r1 on 
	r1.concept_id_1 = c.concept_id and r1.relationship_id = 'Has finding site' and
	not exists --topography may be duplicated (ancestor/descendant)
		(
			select
			from concept_relationship x
			join concept_ancestor a on
				a.descendant_concept_id = x.concept_id_2 and
				a.ancestor_concept_id = r1.concept_id_2 and
				x.concept_id_1 = r1.concept_id_1 and
				x.relationship_id = 'Has finding site' and
				a.min_levels_of_separation > 0
		)
join concept_relationship r2 on 
	r2.concept_id_1 = c.concept_id and r2.relationship_id = 'Has asso morph' and
	not exists --morphology may be duplicated (ancestor/descendant)
		(
			select
			from concept_relationship x
			join concept_ancestor a on
				a.descendant_concept_id = x.concept_id_2 and
				a.ancestor_concept_id = r2.concept_id_2 and
				x.concept_id_1 = r2.concept_id_1 and
				x.relationship_id = 'Has asso morph' and
				a.min_levels_of_separation > 0
		)
;
create index idx_snomed_target_prepared on snomed_target_prepared (concept_id)
;
analyze snomed_target_prepared
;
-- test
-- delete from comb_matched_seer
-- where concept_code !~ '^NULL'
;
--manual cleanup of common problems
--tunica vaginalis goes along with what should be parents
delete from snomed_target_prepared s
where 
	s.t_id != 4134453 and
	s.concept_id in
		(
			select concept_id
			from snomed_target_prepared
			where t_id = 4134453
		)	
;
--Structure of internal part of mouth is cooccuring with what should be it's descendants
delete from snomed_target_prepared s
where
	s.t_id = 44782621 and
	s.concept_id in
		(
			select concept_id
			from snomed_target_prepared
			where t_id = 44782621
		)
;
create table match_blob as
select distinct
	cs.concept_code as i_code,
	s.concept_id as s_id,
	s.m_id,
	s.t_id,

	coalesce (t.precedence, 1) - 1 +
	ta.min_levels_of_separation +
	case t.relationship_id
		when 'Is a' then 1
		else 0
	end as t_distance,

	coalesce (m.precedence, 1) - 1 +
	ma.min_levels_of_separation +
	case m.relationship_id
		when 'Is a' then 1
		else 0
	end as m_distance

from comb_matched_seer o
join concept_stage cs on o.concept_code = cs.concept_code

--topography & up
join topogr_to_snomed t on
	t.kode = o.site
join concept_ancestor ta on
	ta.descendant_concept_id = t.snomed_id

--morphology & up
join morph_to_snomed m on
	m.code = o.hist
join concept_ancestor ma on
	ma.descendant_concept_id = m.snomed_id

join snomed_target_prepared s on
	s.t_id = ta.ancestor_concept_id and
	s.m_id = ma.ancestor_concept_id
;
--match empty topographies
insert into match_blob
select distinct
	cs.concept_code as i_code,
	s.concept_id as s_id,
	s.m_id,
	-1,
	
	0 as t_distance,

	coalesce (m.precedence, 1) - 1 +
	ma.min_levels_of_separation +
	case m.relationship_id
		when 'Is a' then 1
		else 0
	end as m_distance

from comb_matched_seer o
join concept_stage cs on o.concept_code = cs.concept_code

--morphology & up
join morph_to_snomed m on
	m.code = o.hist
join concept_ancestor ma on
	ma.descendant_concept_id = m.snomed_id

join snomed_target_prepared s on
	s.t_id = -1 and
	s.m_id = ma.ancestor_concept_id
;
create index idx_blob on match_blob (i_code, s_id)
;
analyze match_blob
;
--Delete concepts that mention topographies contradicting source condition
delete from match_blob m
where exists
	(
		select 
		from snomed_target_prepared r
		where
			r.concept_id = m.s_id and
			r.t_id not in
				(
					select a.ancestor_concept_id
					from comb_matched_seer c
					join topogr_to_snomed t on
						t.kode = c.site and
						c.concept_code = m.i_code
					join concept_ancestor a on
						a.descendant_concept_id = t.snomed_id
				)
	) and
	t_id != -1
;
--Delete concepts that mention morphologies contradicting source condition
delete from match_blob m
where exists
	(
		select 
		from snomed_target_prepared r
		where
			r.concept_id = m.s_id and
			r.m_id not in
				(
					select a.ancestor_concept_id
					from comb_matched_seer c
					join morph_to_snomed t on
						t.code = c.hist and
						c.concept_code = m.i_code
					join concept_ancestor a on
						a.descendant_concept_id = t.snomed_id
				)
	)
;
analyze match_blob
;
--overlapping lesion
delete from match_blob
where
	s_id in (select descendant_concept_id from concept_ancestor where ancestor_concept_id = 197227) and --Overlapping malignant neoplasm of gastrointestinal tract
	i_code !~ '\.8$' --code for overlapping lesoins
;
--malignant WBC disorder special
delete from match_blob
where
	s_id = 4079274 and
	i_code not in
		(
			select c.concept_code
			from comb_matched_seer c
			join morph_to_snomed t on
				t.code = c.hist
			join concept_ancestor ca on
				ca.ancestor_concept_id = 4185782 and --Hematopoietic neoplasm
				ca.descendant_concept_id = t.snomed_id
		)
;
-- remove descendants where ancestors are available
delete from match_blob m
where exists
	(
		select
		from concept_ancestor a
		join match_blob b on
			b.s_id != m.s_id and
			b.s_id = a.descendant_concept_id and
			m.s_id = a.ancestor_concept_id and
			b.i_code = m.i_code	
	)
;
analyze match_blob
;
--clear hierarchical duplicates
with ms as
(
	select i_code,s_id,m_id,t_id, min (t_distance + m_distance) over (partition by i_code,s_id,m_id,t_id) as minsum
	from match_blob
)
delete from match_blob mb
where
	(i_code,s_id,m_id,t_id, t_distance + m_distance) not in
	(
		select *
		from ms
	)
;
truncate concept_relationship_stage
;
--write 'Maps to' relations where direct one-to-one mappings are available
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
	c.concept_code,
	'ICDO3',
	'SNOMED',
	'Maps to',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from match_blob m
join monorelation o using (i_code)
join concept c on
	c.concept_id = m.s_id
where
	m.t_distance = 0 and
	m.m_distance = 0
;
--write 'Is a' for everything else
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	m.i_code,
	c.concept_code,
	'ICDO3',
	'SNOMED',
	'Is a',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from match_blob m
join concept c on
	c.concept_id = m.s_id
left join concept_relationship_stage r on
	m.i_code = r.concept_code_1
where r.concept_code_1 is null
;
--write relations for attributes
---Morphology
----Maps to
with monorelation as
	(
		select code as code1
		from morph_to_snomed
		where relationship_id = 'Maps to'
		group by code
		having count (snomed_id) = 1
	)
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	code,
	snomed_code,
	'ICDO3',
	'SNOMED',
	'Maps to',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from morph_to_snomed
join monorelation on code = code1
;
----Is a
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	code,
	snomed_code,
	'ICDO3',
	'SNOMED',
	'Is a',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from morph_to_snomed
where code not in
	(
		select concept_code_1
		from concept_relationship_stage
	)
;
---Topography
----Maps to
with monorelation as
	(
		select kode as code1
		from topogr_to_snomed
		where 
			relationship_id = 'Maps to' and
			concept_code != '-1'
		group by kode
		having count (snomed_id) = 1
	)
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	kode,
	concept_code,
	'ICDO3',
	'SNOMED',
	'Maps to',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from topogr_to_snomed
join monorelation on kode = code1
;
----Is a
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	kode,
	concept_code,
	'ICDO3',
	'SNOMED',
	'Is a',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from topogr_to_snomed
where 
	concept_code != '-1' and
	kode not in
	(
		select concept_code_1
		from concept_relationship_stage
	)
;
--write internal relations
---Histology
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select
	c1.concept_code,
	c2.concept_code,
	'ICDO3',
	'ICDO3',
	'Has Histology ICDO',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from concept_stage c1
join concept_stage c2 on
	c1.concept_class_id = 'ICDO Condition' and
	c2.concept_class_id = 'ICDO Histology' and
	c1.concept_code like c2.concept_code || '-%'
;
---Topography
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select
	c1.concept_code,
	c2.concept_code,
	'ICDO3',
	'ICDO3',
	'Has Topography ICDO',
	TO_DATE ('01.01.1970', 'dd.mm.yyyy'),
	TO_DATE ('31.12.2099', 'dd.mm.yyyy')
from concept_stage c1
join concept_stage c2 on
	c1.concept_class_id = 'ICDO Condition' and
	c2.concept_class_id = 'ICDO Topography' and
	c1.concept_code like '%-' || c2.concept_code
;
--Make concepts without Maps to relations Standard
update concept_stage
set standard_concept = 'S'
where
	concept_code not in
		(
			select concept_code_1
			from concept_relationship_stage
			where relationship_id = 'Maps to'
		)
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
--since our relationship list is cannonically complete, we deprecate all existing relationship from ICDO3 to SNOMED if they are not reinforced in current release
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