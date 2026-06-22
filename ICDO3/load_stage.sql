/**************************************************************************
* Copyright 2020 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov, Dmitry Dymshyts, Eduard Korchmar, Vladislav Korsik
* Date: 2021
**************************************************************************/

-- 1. Vocabulary update routine
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ICDO3',
	pVocabularyDate			=> TO_DATE ('20231129', 'yyyymmdd'), -- https://seer.cancer.gov/ICDO3/
	pVocabularyVersion		=> 'ICDO3 SEER Site/Histology Released 06/2020',
	pVocabularyDevSchema	=> 'DEV_icdo3'
);
END $_$
;
--2. Initial cleanup
truncate table concept_stage, concept_relationship_stage, concept_synonym_stage, drug_strength_stage, pack_content_stage
;
-- 3.1. Building SNOMED hierarchy to pick future mapping targets
DROP TABLE IF EXISTS snomed_ancestor;
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
		-- filter out new sources, as SNOMED update could have been delayed
		where
			to_date(c.effectivetime :: varchar, 'yyyymmdd') <= (select to_date(substring(vocabulary_version from 78 for 10),'yyyy-mm-dd') from vocabulary where vocabulary_id = 'SNOMED')
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
				r.typeid = 116680003 and -- Is a
				--filter out newer sources
				to_date(r.effectivetime :: varchar, 'yyyymmdd') <= (select to_date(substring(vocabulary_version from 78 for 10),'yyyy-mm-dd') from vocabulary where vocabulary_id = 'SNOMED')
		),
	concepts AS 
		(
			SELECT
				destinationid AS ancestor_concept_code,
				sourceid AS descendant_concept_code
			FROM active_status
			where active = 1
		) 
	SELECT DISTINCT
		hc.descendant_concept_code :: varchar AS descendant_concept_code,
		hc.root_ancestor_concept_code :: varchar AS ancestor_concept_code 
	FROM hierarchy_concepts hc
)
;
--3.2. Add relation to self for each target
insert into snomed_ancestor
SELECT DISTINCT
	descendant_concept_code AS descendant_concept_code,
	descendant_concept_code AS ancestor_concept_code 
FROM snomed_ancestor hc
;
--3.3. Add missing relation to Primary Malignant Neoplasm where needed
insert into snomed_ancestor (ancestor_concept_code, descendant_concept_code)
select distinct '1240414004', snomed_code
from r_to_c_all r
where
	r.concept_code ~ '\d{4}\/3' and
	r.relationship_id = 'Maps to' and
	not exists
		(
			select 1
			from snomed_ancestor a
			where
				a.ancestor_concept_code = '1240414004' and --PMN
				a.descendant_concept_code = r.snomed_code
		) 
/*	and	not exists -- no common descendants with Secondary malignant neoplasm
		(
			select 1
			from snomed_ancestor a1
			join snomed_ancestor a2 on
				a1.ancestor_concept_code = r.snomed_code and
				a2.ancestor_concept_code = '14799000' and --SMN
				a1.descendant_concept_code = a2.descendant_concept_code
		)
--It filters out nothing at this moment, so commented out for performance. Might still be needed in future as a safety measure
*/
;
ALTER TABLE snomed_ancestor ADD CONSTRAINT xpksnomed_ancestor PRIMARY KEY (ancestor_concept_code,descendant_concept_code)
;
create index snomed_ancestor_d on snomed_ancestor (descendant_concept_code)
;
ANALYZE snomed_ancestor
;
--4. Prepare updates for histology mapping from SNOMED refset
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
		-- filter out new sources, as SNOMED update could have been delayed
		where
			to_date(c.effectivetime :: varchar, 'yyyymmdd') <= (select to_date(substring(vocabulary_version from 78 for 10),'yyyy-mm-dd') from vocabulary where vocabulary_id = 'SNOMED')
	)
select distinct
	referencedcomponentid as snomed_code,
	maptarget as icdo_code
from sources.der2_srefset_simplemapfull_int
join active_concept on
	c_id = referencedcomponentid and
	c_active = 1
where
	-- filter out new sources, as SNOMED update could have been delayed
	to_date(effectivetime :: varchar, 'yyyymmdd') <= (select to_date(substring(vocabulary_version from 78 for 10),'yyyy-mm-dd') from vocabulary where vocabulary_id = 'SNOMED') and
	
	refsetid = '446608001' and
	active = 1 and
	maptarget like '%/%'
;
--5. Remove descendants where ancestor is specified as mapping target
delete from snomed_mapping m1
where exists
	(
		select
		from snomed_mapping m2
		join snomed_ancestor a on
			a.ancestor_concept_code != a.descendant_concept_code and
			a.descendant_concept_code = m1.snomed_code :: varchar and
			a.ancestor_concept_code = m2.snomed_code :: varchar and
			m2.icdo_code = m1.icdo_code
	)
;
--6. Remove ambiguous mappings
delete from snomed_mapping
where icdo_code in
	(
		select icdo_code
		from snomed_mapping
		group by icdo_code
		having count (1) > 1
	)
;
--7. Update mappings
--7.1. Histology mappings from SNOMED International refset
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
	r.concept_code in (select s.icdo_code from snomed_mapping s) and
	r.precedence is null -- no automated modification for concepts with alternating mappings
;
--7.2. Deprecated concepts with replacement
with replacement as
	(
		select r.concept_code, r.snomed_code as old_code, c2.concept_code as new_code
		from r_to_c_all r
		join concept c on
			c.concept_code = snomed_code and
			c.vocabulary_id = 'SNOMED' and
			c.invalid_reason = 'U'
		join concept_relationship x on
			x.concept_id_1 = c.concept_id and
			x.relationship_id = 'Maps to' and
			x.invalid_reason is null
		join concept c2 on
			c2.concept_id = x.concept_id_2
	)
update r_to_c_all a
set snomed_code = new_code
from replacement x
where
	a.concept_code = x.concept_code and
	x.old_code = a.snomed_code and
	a.precedence is null -- no automated modification for concepts with alternating mappings
;
--8. Remove duplications
delete from r_to_c_all r1
where exists
	(
		select
		from r_to_c_all r2
		where
			r1.concept_code = r2.concept_code and
			r2.snomed_code = r1.snomed_code and
			r2.ctid < r1.ctid
	) and
	r1.precedence is null -- no automated modification for concepts with alternating mappings
;
--9. Preserve missing morphology mapped to generic neoplasm
delete from r_to_c_all where concept_code = '9999/9'
;
insert into r_to_c_all
--Code 9999/9 must NOT be encountered in final tables and should be removed during post-processing 
values
	(
		'9999/9',
		'Unknown histology',
		'Maps to',
		'108369006' --Neoplasm
	)
;
create index if not exists rtca_target_vc on r_to_c_all (snomed_code)
;
analyze r_to_c_all
;
--check for deprecated concepts in r_to_c_all.snomed_code field
DO $_$
declare
	codes text;
BEGIN
	select
		string_agg (r.concept_code, ''',''')
	into codes
	from r_to_c_all r
	left join concept c on
		r.snomed_code = c.concept_code and
		c.vocabulary_id = 'SNOMED' and
		c.invalid_reason is null
	where
		c.concept_code is null and
		r.snomed_code != '-1'
	;
	IF codes IS NOT NULL THEN
			RAISE EXCEPTION 'Following attributes relations target deprecated SNOMED concepts: ''%''', codes ;
	END IF;
END $_$
;
--10. Populate_concept stage with attributes
--10.1. Topography
insert into concept_stage (CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE)
select 
	null,
	trim (concept_name),
	'Spec Anatomic Site',
	'ICDO3',
	'ICDO Topography',
	null,
	code,
	TO_DATE ('19700101', 'yyyymmdd'),
	TO_DATE ('20991231', 'yyyymmdd')
from topo_source_iacr
where code is not null
;
--10.2. Morphology
insert into concept_stage (CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE)
select 
	null,
	trim (term),
	'Observation',
	'ICDO3',
	'ICDO Histology',
	null,
	icdo32,
	coalesce
		(
			c.valid_start_date,
			--new concept gets new date
			(
				select latest_update
				from vocabulary
				where latest_update is not null
				limit 1
			)
		),
	TO_DATE ('20991231', 'yyyymmdd')
from morph_source_who
left join concept c on
	icdo32 = c.concept_code and
	c.vocabulary_id = 'ICDO3'
where
	level not in ('Related', 'Synonym') and
	icdo32 is not null
;
--10.3. Get obsolete and unconfirmed morphology concepts
insert into concept_stage (CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct
	trim (m.concept_name),
	'Observation',
	'ICDO3',
	'ICDO Histology',
	null,
	m.concept_code,
	greatest (TO_DATE ('19700101', 'yyyymmdd'), c.valid_start_date), -- don't reduce existing start date
	(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id='ICDO3'),
	'D'
from r_to_c_all m
left join concept c on
	m.concept_code = c.concept_code and
	c.vocabulary_id = 'ICDO3'
where
	m.concept_code like '%/%' and
	m.concept_code not in
	(
		select concept_code
		from concept_stage
		where concept_class_id = 'ICDO Histology'
	)
;
--10.4. Get dates from manual table
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--11. Form table with replacements to handle historic changes for combinations and histologies
drop table if exists code_replace
;
--11.1. Explicitly stated histologies replacements
create table code_replace as
select distinct
	code as old_code,
	substring (fate, '\d{4}\/\d$') as code,
	'ICDO Histology' as concept_class_id
from changelog_extract
where fate ~ 'Moved to \d{4}\/\d'

	union all

select distinct
	code as old_code,
	left (code,4) || '/' || right (fate,1) as code,
	'ICDO Histology' as concept_class_id
from changelog_extract
where fate ~ 'Moved to \/\d'
;
--11.2. Same names; old code deprecated
insert into code_replace
select distinct
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
--11.3. Form table with existing and old combinations
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
--11.4. Create mappings for missing topography/morphology
select
	'9999/9', -- unspecified morphology, mapped to generic neoplasm
	concept_code,
	'NULL-' || concept_code
from concept_stage
where 
	concept_class_id = 'ICDO Topography' and
	concept_code like '%.%' -- not hierarchical

	union all

select
	concept_code,
	'-1',--unspecified topography, combination will get mapped to a concept without a topography
	concept_code || '-NULL'
from concept_stage
where
	concept_class_id = 'ICDO Histology' and
	concept_code like '%/%' -- not hierarchical
;
-- 12. Populate concept_stage with combinations
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
	--get validdity period from histology concept
	m.valid_start_date,
	m.valid_end_date,
		
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
--12.1. One-legged concepts (no topography)
insert into concept_stage (CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select distinct
	'Neoplasm defined only by histology: '||c.concept_name,
	'Condition',
	'ICDO3',
	'ICDO Condition',
	null,
	c.concept_code || '-NULL',
--get validity period from histology concept
	c.valid_start_date,
	c.valid_end_date,
		
	case when r.code is not null
		then 'D'
		else null
	end
from concept_stage c
left join code_replace r on
	r.old_code = c.concept_code || '-NULL'
where
	c.concept_class_id = 'ICDO Histology' and
	c.concept_code like '%/%' -- not hierarchical
;
--12.2. One-legged concepts (no histology)
insert into concept_stage (CONCEPT_ID,CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select
	null,
	'Neoplasm defined only by topography: '||concept_name,
	'Condition',
	'ICDO3',
	'ICDO Condition',
	null,
	'NULL-' || concept_code,
	TO_DATE ('19700101', 'yyyymmdd'),
	TO_DATE ('20991231', 'yyyymmdd'),
	null	 
from concept_stage
where
	concept_class_id = 'ICDO Topography' and
	concept_code like '%.%' -- not hierarchical
;
--13. Form stable list of existing precoordinated concepts in SNOMED
drop table if exists snomed_target_prepared
;
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
	-- filter out new sources, as SNOMED update could have been delayed
	where
		to_date(f.effectivetime :: varchar, 'yyyymmdd') <= (select to_date(substring(vocabulary_version from 78 for 10),'yyyy-mm-dd') from vocabulary where vocabulary_id = 'SNOMED')
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
				'414026006'	--Disorder of hematopoietic cell proliferation
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
				'Has due to'
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
							'415181008',	--Proliferation of hematopoietic cell type
							'25723000',	--Dysplasia
							'76197007'	--Hyperplasia
						) and
					descendant_concept_code = a.concept_code
			)
	left join concept_relationship r2 on --has occurence that has outlying targets
		r1.relationship_id = 'Has occurrence' and
		r2.concept_id_1 = c.concept_id and
		r2.concept_id_2 in
			(
				4121979, --Fetal period
				4275212, --Infancy
				4116829, --Childhood
				4116830, --Congenital
				35624340 --Period of life between birth and death
			)
	where 
		r.relationship_id is null and
		r1.relationship_id is null and
		r2.relationship_id is null and
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
							'127332000',	--Fetal neoplasm
							'115966001',	--Occupational disorder
							'10749871000119100',	--Malignant neoplastic disease in pregnancy
							'765205004',	--Disorder in remission
							'127274007', --Neoplasm of lymph nodes of multiple sites
							'448563005',	--Functionless pituitary neoplasm
							--BROKEN IN CURRENT SNOMED: CHECK THIS NEXT RELEASE!
							'96901000119105', --Prostate cancer metastatic to eye (disorder)
							'255068000'	--Carcinoma of bone, connective tissue, skin and breast
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
--14. Form mass of all possible matches to filter later
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
	end as m_exact,
	1 as debug_id

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
--14.1 match to concepts without topographies
insert into match_blob
select distinct
	o.concept_code as i_code,
	s.concept_code as s_id,
	s.m_id,
	'-1' as t_id,

-- concepts with known or 'deliberately' unknown topography should not have t_exact = TRUE
	coalesce ((t.relationship_id = 'Maps to' and t.snomed_code = '-1'),true) as t_exact, 

	(ma.descendant_concept_code = ma.ancestor_concept_code) and
	(m.relationship_id = 'Maps to') as m_exact,

	2 as debug_id

from comb_table o

--morphology & up
join r_to_c_all m on
	m.concept_code = o.histology_behavior
join snomed_ancestor ma on
	ma.descendant_concept_code = m.snomed_code

--check if topography is Exactly unknown or just missing
left join r_to_c_all t on
	t.concept_code = o.site

join snomed_target_prepared s on
	s.t_id in ('-1','87784001') and --"Soft tissues" is not a real topography
	s.m_id = ma.ancestor_concept_code

where o.concept_code not in (select old_code from code_replace)
;
create index idx_blob on match_blob (i_code, s_id)
;
create index idx_blob_s on match_blob (s_id)
;
analyze match_blob
;
--14.2 match blood cancers to concepts without topographes
--Lymphoma/Leukemia group concepts relating to generic hematopoietic structures as topography
insert into match_blob
select distinct
	cs.concept_code as i_code,
	s.concept_code as s_id,
	s.m_id,
	'-1',
	
	TRUE as t_exact,

	(ma.descendant_concept_code = ma.ancestor_concept_code) and
	(m.relationship_id = 'Maps to') as m_exact,

	3 as debug_id

from comb_table o
join concept_stage cs on o.concept_code = cs.concept_code

--morphology & up
join r_to_c_all m on
	m.concept_code = o.histology_behavior
join snomed_ancestor ma on
	ma.descendant_concept_code = m.snomed_code

join snomed_target_prepared s on
	s.m_id = ma.ancestor_concept_code
where
	left (o.histology_behavior,3) between '9590' and '9990' and -- all hematological neoplasms
-- Blood, Reticuloendothelial system, Hematopoietic NOS
	o.site ~ '^C42\.[034]$' and
	s.t_id in
	(
		'14016003',	--Bone marrow structure
		'254198003',	--Lymph nodes of multiple sites
		'57171008',	--Hematopoietic system structure
		'87784001',	--Soft tissues
		'127908000',	--Mononuclear phagocyte system structure
		'-1' -- Unknown
	)
	and not exists
	(
		select 1
		from match_blob m
		where
			m.i_code = cs.concept_code and
			m.m_exact and
			m.t_exact
	)

;
analyze match_blob
;
--14.2. Delete concepts that mention topographies contradicting source condition
delete from match_blob m
where
	not m.t_exact and -- for lymphomas/leukemias
	exists
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
--14.3. Delete concepts that mention morphologies contradicting source condition
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
--14.4. Handle overlapping lesion
delete from match_blob
where
	s_id in
		(
			select descendant_concept_code
			from snomed_ancestor 
			where ancestor_concept_code in
				(
					'109821008', --Overlapping malignant neoplasm of gastrointestinal tract
					'188256008', --Malignant neoplasm of overlapping lesion of urinary organs
					'109384006', --Overlapping malignant neoplasm of heart, mediastinum and pleura
					'109347009', --Overlapping malignant neoplasm of bone and articular cartilage
					'109851002', --Overlapping malignant neoplasm of retroperitoneum and peritoneum
					'254388002', --Overlapping neoplasm of oral cavity and lips and salivary glands
					'109919002', --Overlapping malignant neoplasm of peripheral nerves and autonomic nervous system
					'109948008', --Overlapping malignant neoplasm of eye and adnexa, primary
					'188256008' --Malignant neoplasm of overlapping lesion of urinary organs 
				)
			
		) and 
	i_code not like '%.8' --code for overlapping lesions
;
analyze match_blob
;
--14.5. malignant WBC disorder special
delete from match_blob
where
	s_id = '277543005' and --Malignant white blood cell disorder
	i_code not in
		(
			select c.concept_code
			from comb_table c
			join r_to_c_all t on
				t.concept_code = c.histology_behavior
			join snomed_ancestor ca on
				ca.ancestor_concept_code = '414388001' and --Hematopoietic neoplasm
				ca.descendant_concept_code = t.snomed_code :: varchar
		)
;
--15. Core logic
--15.1. For t_exact and m_exact, remove descendants where ancestors are available as targets
delete from match_blob m
where exists
	(
		select 1
		from snomed_ancestor a
		join match_blob b on
			b.s_id != m.s_id and
			m.s_id = a.descendant_concept_code and
			b.s_id = a.ancestor_concept_code and
			b.i_code = m.i_code	and
			b.t_exact and
			b.m_exact
	) and
	m.t_exact and
	m.m_exact
;
--15.2. Do the same just for for t_exact with morphology being less precise than best alternative
-- solves problematic concepts like 255168002 Benign neoplasm of esophagus, stomach and/or duodenum (disorder)
--Multiple topographies
delete from match_blob m
where exists
	(
		select 1
		from snomed_ancestor a
		join match_blob b on
			b.s_id != m.s_id and
			m.s_id = a.descendant_concept_code and
			b.s_id = a.ancestor_concept_code and
			b.i_code = m.i_code	and
			b.t_exact
		--don't remove if morphology is less precise
		join snomed_ancestor x on
			x.descendant_concept_code = b.m_id and
			x.ancestor_concept_code = m.m_id
	) and
	m.t_exact
;
--15.3. Remove ancestors where descendants are available as targets
delete from match_blob m
where exists
	(
		select 1
		from snomed_ancestor a
		join match_blob b on
			b.s_id != m.s_id and
			b.s_id = a.descendant_concept_code and
			m.s_id = a.ancestor_concept_code and
			b.i_code = m.i_code
	)
;
 --debug artifact
 truncate table concept_relationship_stage
 ;
 

--16. Fill mappings and other relations to SNOMED in concept_relationship_stage
--16.1. Write 'Maps to' relations where perfect one-to-one mappings are available and unique
with monorelation as
	(
		select i_code
		from match_blob
		where
			t_exact and
			m_exact
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
	TO_DATE ('19700101', 'yyyymmdd'),
	TO_DATE ('20991231', 'yyyymmdd')
from match_blob m
join monorelation o using (i_code)
where
i_code not like '%/6%' -- exclude secondary cancer as they now are mapped to cancer modifier
and	m.t_exact and
	m.m_exact
;
 --Interim Table with Mappings
DROP TABLE if exists icdo3_to_cm_metastasis;
--ICDO3 /6 codes mappings to Cancer Modifier
CREATE TABLE icdo3_to_cm_metastasis as
WITH getherd_mts_codes as (
     --aggregate the source
    SELECT DISTINCT
                          concept_name,
                          concept_code,
                          split_part(concept_code,'-',2) as tumor_site_code,
                          vocabulary_id
          FROM concept_stage c
         WHERE c.vocabulary_id = 'ICDO3'
           and c.concept_class_id = 'ICDO Condition'
           and c.concept_code ILIKE '%/6%'
)

   , tabb as (SELECT distinct
                              tumor_site_code,
                              s.vocabulary_id,
                              cc.concept_id    as snomed_id,
                              cc.concept_name  as snomed_name,
                              cc.vocabulary_id as snomed_voc,
                              cc.concept_code  as snomed_code
              FROM getherd_mts_codes s
                       LEFT JOIN concept c
                                 ON s.tumor_site_code = c.concept_code
                                     and c.concept_class_id = 'ICDO Topography'
                       LEFT JOIN concept_relationship cr
                                 ON c.concept_id = cr.concept_id_1
                                     and cr.invalid_reason is null
                                     and cr.relationship_id = 'Maps to'
                       LEFT JOIN concept cc
                                 on cr.concept_id_2 = cc.concept_id
                                     and cr.invalid_reason is null
                                     and cc.standard_concept = 'S'
)
,
tabbc as (SELECT tumor_site_code,
                 tabb.vocabulary_id as icd_voc,
                 snomed_id,
                 snomed_name,
                 snomed_voc,
                 snomed_code,
                 concept_id,
                 concept_name,
                 domain_id,
                 c.vocabulary_id,
                 concept_class_id,
                 standard_concept,
                 concept_code,
                 c.valid_start_date,
                 c.valid_end_date,
                 c.invalid_reason

          FROM TABB -- table with SITEtoSNOMED mappngs
JOIN concept_relationship cr
ON tabb.snomed_id=cr.concept_id_1
JOIN concept c
ON c.concept_id=cr.concept_id_2
and c.concept_class_id='Metastasis')


,
similarity_tab as (
SELECT distinct
            CASE WHEN tumor_site_code=   'C38.4' then row_number()
             OVER (PARTITION BY tumor_site_code ORDER BY devv5.similarity(snomed_name,concept_name) asc)
               else row_number() OVER (PARTITION BY tumor_site_code 
               ORDER BY devv5.similarity(snomed_name,concept_name) desc)  end as similarity,
                tumor_site_code,
                icd_voc,
                snomed_id,
                snomed_name,
                snomed_voc,
                snomed_code,
                concept_id,
                concept_name,
                domain_id,
                tabbc.vocabulary_id,
                concept_class_id,
                standard_concept,
                concept_code,
                valid_start_date,
                valid_end_date,
                invalid_reason
FROM tabbc)

SELECT distinct
                a.concept_name as icd_name,
                a.concept_code as icd_code,
                a.tumor_site_code,
                a.vocabulary_id as icd_vocab,
                concept_id,
                s.concept_code,
                s.concept_name,
                s.vocabulary_id
FROM
similarity_tab s
JOIN getherd_mts_codes a
ON s.tumor_site_code=a.tumor_site_code
where similarity=1
;
--Assumption MTS
INSERT INTO icdo3_to_cm_metastasis
(icd_name,
 icd_code,
 tumor_site_code,
 icd_vocab,
 concept_id,
 concept_code,
 concept_name,
 vocabulary_id)
SELECT distinct
                s.concept_name as icd_name,
                s.concept_code as icd_code,
              split_part(s.concept_code,'-',2) as tumor_site_code,
                icd_code,
               m. concept_id,
               m.concept_code,
                m.concept_name,
                m.vocabulary_id
FROM concept_stage s
JOIN icdo3_to_cm_metastasis  m
on split_part(split_part(s.concept_code,'-',2),'.',1)||'.9'=m.tumor_site_code
WHERE s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'

;

-- Pathologically confirmed metastasis
INSERT INTO icdo3_to_cm_metastasis
(icd_name,
 icd_code,
 tumor_site_code,
 icd_vocab,
 concept_id,
 concept_code,
 concept_name,
 vocabulary_id)
SELECT distinct s.concept_name as icd_name,
                s.concept_code as icd_code,
                   split_part(s.concept_code,'-',2),
                s.vocabulary_id as icd_vocab,
               c. concept_id,
               c.concept_code,
                c.concept_name,
                c.vocabulary_id
FROM concept_stage s,concept  c
WHERE c.concept_code = 'OMOP4998770'
and c.vocabulary_id ='Cancer Modifier'
and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'
and    split_part(s.concept_code,'-',2) IN ('NULL','C80.9','C76.7')

;

--Assumption that the codes represent CTC
INSERT INTO icdo3_to_cm_metastasis
(icd_name,
 icd_code,
 tumor_site_code,
 icd_vocab,
 concept_id,
 concept_code,
 concept_name,
 vocabulary_id)
SELECT distinct s.concept_name as icd_name,
                s.concept_code as icd_code,
               split_part(s.concept_code,'-',2),
                s.vocabulary_id as icd_vocab,
               c. concept_id,
               c.concept_code,
                c.concept_name,
                c.vocabulary_id
FROM concept_stage s, concept  c
WHERE c.concept_code = 'OMOP4999341'
and c.vocabulary_id ='Cancer Modifier'
and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'
and    split_part(s.concept_code,'-',2) ='C42.0'

;

--Hardcoded values (mostly LN stations)
INSERT INTO icdo3_to_cm_metastasis
(icd_name,
 icd_code,
 tumor_site_code,
 icd_vocab,
 concept_id,
 concept_code,
 concept_name,
 vocabulary_id)
SELECT icd_name,
       icd_code,
       tumor_site_code,
       icd_vocab,
       concept_id,
       concept_code,
       concept_name,
       vocabulary_id
FROM (
         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                       split_part(s.concept_code,'-',2) as tumor_site_code,
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
             concept  c
         WHERE c.concept_code = 'OMOP5031980'
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C40.0', 'C47.1')

         UNION ALL

                    SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
              concept  c
         WHERE c.concept_code = 'OMOP5031483'--	Metastasis to the Anal Canal
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C21')
         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
             concept  c
         WHERE c.concept_code = 'OMOP5031707'
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) = 'C40.2'

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
            concept  c
         WHERE c.concept_code = 'OMOP5031839'--	Metastasis to the Retroperitoneum And Peritoneum'
           and c.vocabulary_id = 'Cancer Modifier' 
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) = 'C48.8'

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
              concept  c
         WHERE c.concept_code = 'OMOP5031916'--	Metastasis to the Soft Tissues
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) = 'C49.9'

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
              concept  c
         WHERE c.concept_code = 'OMOP5031618'--	Metastasis to the Female Genital Organ
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C57', 'C57.7')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
            concept  c
         WHERE c.concept_code = 'OMOP5031819'--	Metastasis to the Prostate
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C61.9')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
              concept  c
         WHERE c.concept_code = 'OMOP5031716'--	Metastasis to the Male Genital Organ
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C63')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
             concept  c
         WHERE c.concept_code = 'OMOP5117515'--	Metastasis to meninges NEW CONCEPT
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C70', 'C70.9')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
             concept  c
         WHERE c.concept_code = 'OMOP5117516'--	Metastasis to abdomen --new concept
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C76.2')


         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
          concept  c
         WHERE c.concept_code = 'OMOP4998263' --Lymph Nodes
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C77')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
            concept  c
         WHERE c.concept_code = 'OMOP4998263' --Lymph Nodes -- TODO NEW CODE NEEDED (not sure that /6 resembles always distant)
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C77.0')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
             concept  c
         WHERE c.concept_code = 'OMOP4998263' --Lymph Nodes -- TODO NEW CODE NEEDED (not sure that /6 resembles always distant)
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis) and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C77.1')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
          concept  c
         WHERE c.concept_code = 'OMOP4998263' --Lymph Nodes -- TODO NEW CODE NEEDED (not sure that /6 resembles always distant)
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)  and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C77.2')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
              concept  c
         WHERE c.concept_code = 'OMOP4998263' --Lymph Nodes -- TODO NEW CODE NEEDED (not sure that /6 resembles always distant)
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)  and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C77.2')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
            concept  c
         WHERE c.concept_code = 'OMOP4998263' --Lymph Nodes -- TODO NEW CODE NEEDED (not sure that /6 resembles always distant)
           and c.vocabulary_id = 'Cancer Modifier' 
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)  and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C77.3')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
           concept  c
         WHERE c.concept_code = 'OMOP5000384'--	Inguinal Lymph Nodes
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)  and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C77.4')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
              concept  c
         WHERE c.concept_code = 'OMOP4999638'--	Pelvic Lymph Nodes
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)  and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C77.5')

         UNION ALL

         SELECT distinct s.concept_name  as icd_name,
                         s.concept_code  as icd_code,
                         split_part(s.concept_code,'-',2),
                         s.vocabulary_id as icd_vocab,
                         c.concept_id,
                         c.concept_code,
                         c.concept_name,
                         c.vocabulary_id
         FROM concept_stage s,
           concept  c
         WHERE c.concept_code = 'OMOP4998263' --Lymph Nodes
           and c.vocabulary_id = 'Cancer Modifier'
           and s.concept_code not in (select icd_code from icdo3_to_cm_metastasis)  and s.concept_code like '%/6-%'
           and split_part(s.concept_code,'-',2) in ('C77.9')
     ) as  map
where   icd_code not in (select icd_code from icdo3_to_cm_metastasis)
;
update icdo3_to_cm_metastasis set icd_vocab ='ICDO3' where icd_vocab !='ICDO3'
;

--Insert into Concept_stage
INSERT INTO concept_relationship_stage
(concept_code_1,
 concept_code_2,
 vocabulary_id_1,
 vocabulary_id_2,
 relationship_id,
 valid_start_date,
 valid_end_date)

SELECT distinct
       icd_code as concept_code_1 ,
       concept_code as concept_code_2,
       icd_vocab as vocabulary_id_1,
      vocabulary_id as vocabulary_id_2,
                                  'Maps to'     relationship_id,
                CURRENT_DATE as valid_start_date,
                    TO_DATE('20991231', 'yyyymmdd')  as valid_end_date

FROM icdo3_to_cm_metastasis
;
--16.2. Check if there are manual 'Maps to' for perfectly processed concepts in manual table; we should get error if there are intersections
DO $_$
declare
	codes text;
BEGIN
	select
		string_agg (m.concept_code_1, ''',''')
	into codes
	from concept_relationship_manual m
	join concept_relationship_stage s on
		s.concept_code_1 = m.concept_code_1 and
		s.vocabulary_id_1 = m.vocabulary_id_1 and
		m.invalid_reason is null and
		m.relationship_id = 'Maps to';
	IF codes IS NOT NULL THEN
			RAISE EXCEPTION 'Following codes need to be removed from manual table: ''%''', codes ;
	END IF;
END $_$;

--16.3. Get mappings from manual table
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--16.4. Write 'Is a' for everything else
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	m.i_code,
	m.s_id,
	'ICDO3',
	'SNOMED',
	'Is a',
	TO_DATE ('19700101', 'yyyymmdd'),
	TO_DATE ('20991231', 'yyyymmdd')
from match_blob m
left join concept_relationship_stage r on
		m.i_code = r.concept_code_1
	AND r.relationship_id = 'Maps to'
where r.concept_code_1 is null
;
--17. Write relations for attributes
--17.1. Maps to
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	concept_code,
	snomed_code,
	'ICDO3',
	'SNOMED',
	'Maps to',
	TO_DATE ('19700101', 'yyyymmdd'),
	TO_DATE ('20991231', 'yyyymmdd')
from r_to_c_all	
left join code_replace on
	old_code = concept_code
where 
	old_code is null and
	snomed_code != '-1' and 
	relationship_id = 'Maps to' and
	coalesce (precedence,1) = 1
;
--17.2. Is a
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	concept_code,
	snomed_code,
	'ICDO3',
	'SNOMED',
	'Is a',
	TO_DATE ('19700101', 'yyyymmdd'),
	TO_DATE ('20991231', 'yyyymmdd')
from r_to_c_all
where concept_code not in
	(
		select concept_code_1
		from concept_relationship_stage
	) and
	concept_code != '9999/9' and
	snomed_code != '-1'
;
--18. Create internal hierarchy for attributes and combos
drop table if exists attribute_hierarchy
;
--18.1. Internal hierarchy for morphology attribute
create table attribute_hierarchy as
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
		h2.end_code || 'Z' >= h3.end_code -- to guarantee inclusion of upper bound
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
		s.concept_code
			between h.start_code
			and	h.end_code || 'Z' -- to guarantee inclusion of upper bound
	where
		s.concept_class_id = 'ICDO Histology' and
		s.concept_code not in (select old_code from code_replace) and
		s.standard_concept is null and
		--avoid jump from 2 to atom where 3 is available; concept_ancestor will not care
		h.concept_code not in
			(
				select ancestor_code
				from relation_hierarchy
			) and
		--obviously excludde hierarchical concepts
		s.concept_code not in
			(
				select concept_code
				from hierarchy
			)
)
select *
from relation_hierarchy

	union all

select *
from relation_atom
;
insert into attribute_hierarchy
--18.2. Internal hierarchy for topography attribute
select
	t1.code,
	t2.code,
	'A'
from topo_source_iacr t1
join topo_source_iacr t2 on
	t1.code like '%.%' and
	t2.code not like '%.%' and
	t1.code like t2.code || '.%'
;
--19. Write 'Is a' for hierarchical concepts
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	ancestor_code,
	descendant_code,
	'ICDO3',
	'ICDO3',
	'Subsumes',
	TO_DATE ('19700101', 'yyyymmdd'),
	TO_DATE ('20991231', 'yyyymmdd')
from attribute_hierarchy a
where a.ancestor_code != a.descendant_code
;
--20. Form internal relations (to attributes)
--write internal relations
--20.1. Histology
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	c1.concept_code,
	c1.histology_behavior,
	'ICDO3',
	'ICDO3',
	'Has Histology ICDO',
	TO_DATE ('19700101', 'yyyymmdd'),
	TO_DATE ('20991231', 'yyyymmdd')
from comb_table c1
left join code_replace c2 on
	c2.old_code = c1.concept_code
where c2.old_code is null
;
--20.2. Topography
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	c1.concept_code,
	c1.site,
	'ICDO3',
	'ICDO3',
	'Has Topography ICDO',
	TO_DATE ('19700101', 'yyyymmdd'),
	TO_DATE ('20991231', 'yyyymmdd')
from comb_table c1
left join code_replace c2 on
	c2.old_code = c1.concept_code
where 
	c2.old_code is null and
	c1.site != '-1'
;
--20.3. Standard conditions should have 'Has asso morph' & 'Has finding site' from SNOMED parents
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	s.concept_code,
	o.concept_code,
	'ICDO3',
	'SNOMED',
	a.relationship_id,
	TO_DATE ('19700101', 'yyyymmdd'),
	TO_DATE ('20991231', 'yyyymmdd')
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
--20.4. Add own attributes to standard conditions
---Topography
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select
	s.concept_code,
	r1.snomed_code,
	'ICDO3',
	'SNOMED',
	'Has finding site',
	TO_DATE ('19700101', 'yyyymmdd'),
	TO_DATE ('20991231', 'yyyymmdd')
from comb_table s
left join concept_relationship_stage x on -- no mapping for condition
	s.concept_code = x.concept_code_1 and
	x.relationship_id = 'Maps to'
join r_to_c_all r1 on
	s.site = r1.concept_code
where
	 x.concept_code_1 is null and
	 r1.snomed_code != '-1' and
	 not exists
	 	(
	 		select 1
	 		from concept_relationship_stage a
	 		where
	 			a.concept_code_1 = s.concept_code and
	 			a.concept_code_2 = r1.snomed_code
	 	)

	UNION ALL
---Histology
select
	s.concept_code,
	r1.snomed_code,
	'ICDO3',
	'SNOMED',
	'Has asso morph',
	TO_DATE ('19700101', 'yyyymmdd'),
	TO_DATE ('20991231', 'yyyymmdd')
from comb_table s
left join concept_relationship_stage x on -- no mapping for condition
	s.concept_code = x.concept_code_1 and
	x.relationship_id = 'Maps to'
join r_to_c_all r1 on
	s.histology_behavior = r1.concept_code and
	coalesce (r1.precedence,1) = 1
where
	 x.concept_code_1 is null and
	 r1.snomed_code != '-1' and
	 not exists
	 	(
	 		select 1
	 		from concept_relationship_stage a
	 		where
	 			a.concept_code_1 = s.concept_code and
	 			a.concept_code_2 = r1.snomed_code
	 	)
;
--20.5. remove co-occurrent parents of target attributes (consider our concepts fully defined)
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
		join snomed_ancestor a on
			cd.concept_code = a.descendant_concept_code and
			a.descendant_concept_code != a.ancestor_concept_code
		join concept ca on
			ca.concept_code = a.ancestor_concept_code and
			ca.concept_code = s.concept_code_2 and
			ca.vocabulary_id = 'SNOMED'
	)
;
--21. Handle replacements and self-mappings
--Add replacements from code_replace
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	old_code,
	code,
	'ICDO3',
	'ICDO3',
	'Concept replaced by',
	TO_DATE ('19700101', 'yyyymmdd'),
	TO_DATE ('20991231', 'yyyymmdd')
from code_replace cr
;
--22. Make concepts without 'Maps to' relations Standard
update concept_stage
set standard_concept = 'S'
where
	invalid_reason is null and
	concept_code not in
		(
			select concept_code_1
			from concept_relationship_stage
			where relationship_id = 'Maps to'
		) and
	(
		concept_class_id = 'ICDO Condition' or
		(concept_class_id = 'ICDO Topography' and concept_code like '%.%') or
		(concept_class_id = 'ICDO Histology' and concept_code like '%/%')
	)
;
--23. Populate concept_synonym_stage
--23.1. with morphologies
insert into concept_synonym_stage (
    synonym_name,
    synonym_concept_code,
    synonym_vocabulary_id,
    language_concept_id
)
--we ignore obsoletion status of synonyms for now: concepts may still be referenced by their old names in historical classifications
--ICDO3 does not distinguish between 'old' and 'wrong'
select distinct
	trim (term),
	icdo32,
	'ICDO3',
	4180186 -- English
from morph_source_who
where
	level != 'Related' -- not actual synonyms
	and icdo32 is not null
;
--24. Vocabulary pack procedures
--24.1. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--25.2, Add mapping from deprecated to fresh concepts -- Disabled - breaks Upgraded concepts
/*DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;*/
--do this instead:
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select
	r.concept_code_1,
	coalesce (r2.concept_code_2, r.concept_code_2),
	r.vocabulary_id_1,
	coalesce (r2.vocabulary_id_2, r.vocabulary_id_2),
	'Maps to',
	TO_DATE ('19700101', 'yyyymmdd'),
	TO_DATE ('20991231', 'yyyymmdd')
from concept_relationship_stage r
left join concept_relationship_stage r2 on
	r2.relationship_id = 'Maps to' and
	r.concept_code_2 = r2.concept_code_1
where
	r.relationship_id = 'Concept replaced by' and
	not exists
		(
			select 1
			from concept_relationship_stage r3
			where
				r.concept_code_1 = r3.concept_code_1 and
				r3.relationship_id = 'Maps to'
		)
;
--25.3. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--25.4. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--26. If concept got replaced, give it invalid_reason = 'U'
update concept_stage x
set invalid_reason = 'U'
where
	invalid_reason = 'D' and
	exists
		(
			select 1
			from concept_relationship_stage
			where
				invalid_reason is null and
				relationship_id = 'Concept replaced by' and
				concept_code_1 = x.concept_code
		)
;
--27. Condition built from deprecated (not replaced) histologies need to have their validity period or invalid_reason modified
--27.1. invalid_reason => 'D'
update concept_stage
set  invalid_reason = 'D'
where
	concept_class_id = 'ICDO Condition' and
	standard_concept is null and
	valid_end_date < current_date and
	invalid_reason is null
;
--28.2. end date => '20991231'
update concept_stage
set  valid_end_date = to_date ('20991231','yyyymmdd')
where
	concept_class_id = 'ICDO Condition' and
	standard_concept = 'S' and
	valid_end_date < current_date and
	invalid_reason is null
;
--29. Since our relationship list is cannonically complete, we deprecate all existing relationships if they are not reinforced in current release
--29.1. From ICDO3 to SNOMED
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
--29.2. From ICDO to ICDO
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
	--Workaround for fixes between source releases
	case 
		when r.valid_start_date <=
		(
			select latest_update
			from vocabulary
			where latest_update is not null
			limit 1
		)
		then TO_DATE ('19700101', 'yyyymmdd')
		else r.valid_start_date		
	end,
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
where
	s.concept_code_1 is null and
	--don't deprecate maps to self for Standard concepts
	not
		(
			c.concept_id = c2.concept_id and
			r.relationship_id = 'Maps to' and
			exists
				(
					select 1
					from concept_stage x
					where x.concept_code = c.concept_code
				)
		)
;
-- 30. Cleanup: drop all temporary tables
drop table if exists snomed_mapping, snomed_target_prepared, attribute_hierarchy, comb_table, match_blob, code_replace, snomed_ancestor, icdo3_to_cm_metastasis;
;

--TODO:
/*
	1. Once SNOMED metadata is implemented in concept_relationship, drop dependency on SNOMED sources and creation of separate snomed_ancestor
	2. Include SEER conversion tables as relations between ICDO Topography sources and ICD10(CM)
	3. Create user-space tool to create automated mappings to SNOMED for custom combinations
	4. Create separate QA routine for sources and manual tables
	5. Allow for generic mapping when source topography is organ system structure (e.g. Glioma of Nervous system, NOS can be mapped to Glioma (disorder))
	6. Add German synonyms
*/

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
