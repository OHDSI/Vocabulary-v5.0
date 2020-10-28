update concept_stage
set concept_id = null
;
analyze concept_stage
;
drop sequence if exists concept_ids_temp
;
CREATE SEQUENCE concept_ids_temp INCREMENT BY 1 START WITH 1 NO CYCLE CACHE 20
;
update concept_stage
set concept_id = nextval ('concept_ids_temp')
where concept_id is null and concept_class_id = 'ICD10PCS'
;
analyze concept_stage
;
drop table if exists ancestor_snomed cascade
;
create or replace view intl_code as --alternative way of finding valid codes since UMLS is updated infrequently
with namespaces as
	(
		select trim ('{}' from substring (c.concept_name from '\{?\d{7}\}?$')) as namespace
		from concept_relationship r
		join concept c on
			r.invalid_reason is null and
			r.relationship_id = 'Is a' and
			r.concept_id_1 = c.concept_id and
			r.concept_id_2 = 40546921 and --SNOMED Namespace concept
			r.concept_id_1 != 40555041 -- intl namespace
	)
select c.concept_code, c.concept_id
from concept c
left join namespaces n on
	c.concept_code like '%' || n.namespace || '%' and
	length (c.concept_code) > 8 --some intersection with core namespace: codes themself are at least 2 symbols long
where
	c.vocabulary_id = 'SNOMED' and
	c.invalid_reason is null and
	n.namespace is null
;
create table ancestor_snomed as
with recursive hierarchy_concepts (ancestor_concept_id,descendant_concept_id, root_ancestor_concept_id, levels_of_separation, full_path) as
	(
        select 
            ancestor_concept_id, descendant_concept_id, ancestor_concept_id as root_ancestor_concept_id,
            levels_of_separation, ARRAY [descendant_concept_id] AS full_path		
        from concepts
        union all
        select 
            c.ancestor_concept_id, c.descendant_concept_id, root_ancestor_concept_id,
            hc.levels_of_separation+c.levels_of_separation as levels_of_separation,
            hc.full_path || c.descendant_concept_id as full_path
        from concepts c
        join hierarchy_concepts hc on hc.descendant_concept_id=c.ancestor_concept_id
        WHERE c.descendant_concept_id <> ALL (full_path)
    ),
    concepts as (
        select
            r.concept_id_1 as ancestor_concept_id,
            r.concept_id_2 as descendant_concept_id,
            case when s.is_hierarchical=1 and c1.invalid_reason is null then 1 else 0 end as levels_of_separation
        from devv5.concept_relationship r 
        join devv5.relationship s on s.relationship_id=r.relationship_id and s.defines_ancestry=1
        join devv5.concept c1 on c1.concept_id=r.concept_id_1 and c1.invalid_reason is null AND c1.vocabulary_id='SNOMED'
        join devv5.concept c2 on c2.concept_id=r.concept_id_2 and c2.invalid_reason is null AND c2.vocabulary_id='SNOMED'
        where
			r.invalid_reason is null
--         	AND EXISTS (select 1 from sources.mrconso m1 where c1.concept_code = m1.code and m1.sab = 'SNOMEDCT_US')
--			AND EXISTS (select 1 from sources.mrconso m2 where c1.concept_code = m2.code and m2.sab = 'SNOMEDCT_US')
			and exists (select from intl_code m1 where c1.concept_id = m1.concept_id)
			and exists (select from intl_code m2 where c2.concept_id = m2.concept_id)
				--split false hierarchy
			and (r.concept_id_1, r.concept_id_2) not in 
				(
					(4197965,43021799), -- Non-coronary systemic artery structure should not be a child of Peripheral vascular system structure
					(4220536,4301737), -- Abdominal aorta structure should not be a child of Retroperitoneal compartment structure
					(4001042,4102601),	--Cerebrovascular system structure should not (?) be a child of Central nervous system part
					(4122814,4221351),	--Radiation plaque therapy should not be a child of Nuclear medicine study of systems
					(4271678,4117454),	--Vascular structure of kidney should not (?) be a child of Kidney structure
					(4117981,4257977)	--Dilation repair - action is not really a Repair - action
				)
	)
select 
	hc.root_ancestor_concept_id as ancestor_concept_id,
	hc.descendant_concept_id,
	min(hc.levels_of_separation) as min_levels_of_separation,
	max(hc.levels_of_separation) as max_levels_of_separation
from hierarchy_concepts hc
join devv5.concept c1 on c1.concept_id=hc.root_ancestor_concept_id and c1.invalid_reason is null
join devv5.concept c2 on c2.concept_id=hc.descendant_concept_id and c2.invalid_reason is null
GROUP BY hc.root_ancestor_concept_id, hc.descendant_concept_id

	UNION
	
SELECT c.concept_id AS ancestor_concept_id,
	c.concept_id AS descendant_concept_id,
	0 AS min_levels_of_separation,
	0 AS max_levels_of_separation
FROM concept c
WHERE
	c.vocabulary_id = 'SNOMED' and
	exists (select from intl_code m where c.concept_id = m.concept_id) and
-- 	EXISTS (select 1 from sources.mrconso m where c.concept_code = m.code and m.sab = 'SNOMEDCT_US') and
	c.invalid_reason is null
;
ALTER TABLE ancestor_snomed ADD CONSTRAINT xpkancestor_snomed PRIMARY KEY (ancestor_concept_id,descendant_concept_id);
;
ALTER TABLE ancestor_snomed ADD CONSTRAINT fpk_ancestor_snomed_c_1 FOREIGN KEY (ancestor_concept_id) REFERENCES concept (concept_id);
ALTER TABLE ancestor_snomed ADD CONSTRAINT fpk_ancestor_snomed_c_2 FOREIGN KEY (descendant_concept_id) REFERENCES concept (concept_id);
;
CREATE INDEX idx_sna_descendant ON ancestor_snomed (descendant_concept_id)
;
CREATE INDEX idx_sna_ancestor ON ancestor_snomed (ancestor_concept_id)
;
analyze ancestor_snomed
;
insert into ancestor_snomed
select 
	4179858,
	concept_id,
	1,
	1
from concept
where 
	concept_name like 'Entire %' and
	concept_class_id = 'Body Structure' and
	vocabulary_id = 'SNOMED' and
	not exists
		(
			select 
			from ancestor_snomed 
			where (ancestor_concept_id, descendant_concept_id) = (4179858,concept_id) --entire anatomical structure
		)
;/*
--equate Division, Bisection, Transection methods
update ancestor_snomed 
set
	min_levels_of_separation = 0,
	max_levels_of_separation = 0
where
	ancestor_concept_id in (4044522, 4044184) and
	descendant_concept_id in (4044184, 4138029)	*/
;
analyze ancestor_snomed
;
delete from ancestor_snomed --Endoscopes should not have parents: it is not ok to map endoscopic procedures to 'procedures using device'
where
	descendant_concept_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4290594) and --endoscope
	ancestor_concept_id not in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4290594) and --parent is not endoscope 
	min_levels_of_separation > 0 --not itself
;
--"4180941 procedure categorized by device invlolved" likewise shouldn't include any of endoscopic procedures
delete from ancestor_snomed
where
	descendant_concept_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4179713) and --Endoscopic procedure
	ancestor_concept_id = 4180941
;
analyze ancestor_snomed
;
drop table if exists relations
;
create table relations (relationship_id varchar (127))
;
DO $_$
	begin
		insert into relations values ('During');
		insert into relations values ('Has direct site');
		insert into relations values ('Has technique');
		insert into relations values ('Followed by');
		insert into relations values ('Using subst');
		insert into relations values ('Using device');
		insert into relations values ('Using energy');
		insert into relations values ('Using acc device');
		insert into relations values ('Occurs after');
		insert into relations values ('Has surgical appr');
		insert into relations values ('Has scale type');
		insert into relations values ('Has property');
		insert into relations values ('Has proc site');
		insert into relations values ('Has indir proc site');
		insert into relations values ('Has dir proc site');
		insert into relations values ('Has proc morph');
		insert into relations values ('Has proc device');
		insert into relations values ('Has proc context');
		insert into relations values ('Has pathology');
		insert into relations values ('Has asso morph');
		insert into relations values ('Has indir morph');
		insert into relations values ('Has method');
		insert into relations values ('Has specimen');
		insert into relations values ('Has dir subst');
		insert into relations values ('Has dir morph');
		insert into relations values ('Has dir device');
		insert into relations values ('Has asso finding');
		insert into relations values ('Has asso morph');
		insert into relations values ('Has surgical appr');
		insert into relations values ('Has access');
		insert into relations values ('Has revision status');
		insert into relations values ('Has component');
		insert into relations values ('Has focus');
		insert into relations values ('Has intent');
	end;
$_$
;
create index idx_relations on relations (relationship_id)
;
analyze relations
;
drop table if exists snomed_relationship cascade
;
create table snomed_relationship as
select distinct cr.concept_id_1, cr.concept_id_2, cr.invalid_reason, cr.relationship_id, cr.valid_end_date, cr.valid_start_date
from concept_relationship cr
join relations r on
	cr.relationship_id = r.relationship_id and
	cr.invalid_reason is null
join concept c1 on
	c1.concept_id = cr.concept_id_1 and
	c1.vocabulary_id = 'SNOMED' and
	c1.domain_id in ('Procedure','Measurement','Observation') and
	c1.standard_concept = 'S' and
	c1.concept_class_id not in ('Clinical Finding','Context-dependent','Qualifier Value')
join concept c2 on
	c2.concept_id = cr.concept_id_2 and
	c2.vocabulary_id = 'SNOMED'
where
	exists
		(
			select
			from ancestor_snomed a
			where
				a.descendant_concept_id = cr.concept_id_1
		) and
	exists
		(
			select
			from ancestor_snomed a
			where
				a.descendant_concept_id = cr.concept_id_2
		)
;
--to do: introduce 'No contrast' as Qualifier Value concept, assign it to all 'Imaging w/o contrast' children, add as mapping for Imaging chapter
;
ALTER TABLE snomed_relationship ADD CONSTRAINT xpk_snomed_relationship PRIMARY KEY (concept_id_1,concept_id_2,relationship_id);
;
ALTER TABLE snomed_relationship ADD CONSTRAINT fpk_snomed_relationship_c_1 FOREIGN KEY (concept_id_1) REFERENCES concept (concept_id);
ALTER TABLE snomed_relationship ADD CONSTRAINT fpk_snomed_relationship_c_2 FOREIGN KEY (concept_id_2) REFERENCES concept (concept_id);
ALTER TABLE snomed_relationship ADD CONSTRAINT fpk_snomed_relationship_id FOREIGN KEY (relationship_id) REFERENCES relationship (relationship_id);
;
create index idx_snomed_relationship_1 on snomed_relationship (concept_id_1);
create index idx_snomed_relationship_2 on snomed_relationship (concept_id_2);
create index idx_snomed_relationship_r on snomed_relationship (relationship_id);
create index idx_snomed_relationship_pair on snomed_relationship (concept_id_1,concept_id_2);
;
analyze snomed_relationship
;
--standartise liquid introductions
--injection => infusion
--avoid dupes

--replace injections with just one infusion
update snomed_relationship
set concept_id_2 = 4044191 --infusion- action
where
	concept_id_2 in
		(
			select descendant_concept_id 
			from ancestor_snomed
			where ancestor_concept_id = 4044190	--Injection - action
		) and
	concept_id_2 not in --too specific to lose
		(
			4236076,	--Apheresesis - action
			4234575	--Infiltration - action
		)
;
--fetal structire --> structure of product of conception (ICD10 terminology)
-- update snomed_relationship
-- set concept_id_2 = 4097520	--Structure of product of conception
-- where concept_id_2 = 4207963	--Fetal structure
;
update snomed_relationship 
set concept_id_2 = 4024722	--Haemostasis related substance
where
	concept_id_1 = 4253788 and
	relationship_id = 'Has dir subst'
;
delete from snomed_relationship 
where concept_id_2 in --too generic
	(
		4034052, --Body Organ Structure
		4014165, --Procedureal Approach
		4022675, --Substance
		4156221, --Extensiveness
		4230459, --Drug Allergen
		4199158, --Body Region Structure
		4106215, --Administration Approach
		4048506, --Specimen
		4044908, --Action
		4310109, --Body Tissue Structure
		4237304, --Instrument
-- 		4169265, --Device
		4180936, --Intents
		40481827,	--Anatomical or acquired body structure
		4338971	--Soft tissues
	)
;
delete from snomed_relationship s --if procedure has 'revision' attribute, it should not have generic 'surgery' 
where
	concept_id_1 in
		(
			select concept_id_1
			from snomed_relationship
			where concept_id_2 = 4116366 -- Revision
		)
	and concept_id_2 = 4045049 -- Surgery
;
delete from snomed_relationship
--if another method is specified, 'Surgery' is redundant
where 
	concept_id_2 = 4045049 and
	concept_id_1 in
		(
			select c.concept_id
			from snomed_relationship r
			join concept c on
				c.concept_id = r.concept_id_1 and
				r.relationship_id = 'Has method' and
				r.concept_id_2 = 4045049
			join concept_relationship cr on
				c.concept_id = cr.concept_id_1 and
				cr.relationship_id = 'Has method' and
				cr.concept_id_2 != 4045049
			join concept cx on
				cr.concept_id_2 = cx.concept_id
		)
;
drop table if exists attributes10
;
--generate atribute table for mappings
create table attributes10 as
with mrconso_united as
(
		select cui,lat,ts,lui,stt,sui,ispref,aui,saui,scui,sdui,sab,tty,code,str,srl,suppress,cvf from sources.mrconso
-- 			union all
-- 		select cui,lat,ts,lui,stt,sui,ispref,aui,saui,scui,sdui,sab,tty,code,str,srl,suppress,cvf from sources.icdo3_mrconso
),
i10 as
(
	select c.concept_id, m.code as concept_code, replace (m.str, ' @ ', '@') as concept_name
	FROM mrconso_united m
	join concept_stage c on
		m.sab = 'ICD10PCS' and 
		m.tty = 'PX' and 
		length (m.code) = 7 and
		c.concept_code = m.code and
		c.vocabulary_id = 'ICD10PCS'
 )
SELECT distinct concept_id,concept_code,l.attr_name,l.priority
FROM i10,
lateral
	(
		select *
		from unnest(string_to_array(i10.concept_name, '@')) 
		WITH ordinality AS x (attr_name, priority)
	) l
;
--remove laterality
;
drop table if exists atr_unil
;
create table atr_unil as
select distinct
	concept_id,
	concept_code,
	case
		when substr (concept_code,1,2) = '02' then attr_name --heart surgery
		when substr (concept_code,1,2) = '2B' then attr_name --heart imaging
		else replace (replace (attr_name,' Left',''),' Right','')
	end as attr_name,
	priority
from attributes10
--Only include procedures from actual data! (manual table)
-- join ICD10_ACTUAL on icd_code = concept_code
;
update atr_unil set attr_name = SUBSTR (attr_name, 1, LENGTH(attr_name) - 1) where attr_name like '%,'
;
-- drop table attributes10
;
--add destructive agent to chemical destr concepts Injection of neurolytic nerve agent and children
insert into snomed_relationship
select distinct
	descendant_concept_id,
	4117508,	--Chemical destruction
	null as invalid_reason,
	'Has method' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
join snomed_relationship r on
	a.descendant_concept_id = r.concept_id_1 -- at least 1 other record is present
where
	ancestor_concept_id in
		(
			4099926,	--Injection of neurolytic nerve agent
			4307810,	--Chemolysis of spinal canal structure
			4277583,	--Chemodenervation
			4100042	--Chemosurgery
		) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4117508))
;
-- add 4124754 Graft to 4168166 Bypass Graft
insert into snomed_relationship
select distinct
	descendant_concept_id,
	4124754,	--Graft
	null as invalid_reason,
	'Using subst',
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
join snomed_relationship r on
	a.descendant_concept_id = r.concept_id_1 -- at least 1 other record is present\
where
	ancestor_concept_id in
		(
			4168166	--Bypass Graft
		) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4124754))
;
--add 4159470 Antineoplastic agent to chemo concepts and children
insert into snomed_relationship
select distinct
	descendant_concept_id,
	4159470,	--Antineoplastic
	null as invalid_reason,
	'Has dir subst' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
join snomed_relationship r on
	a.descendant_concept_id = r.concept_id_1 -- at least 1 other record is present
where
	ancestor_concept_id in
		(
			4273629	--Chemotherapy
		) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4159470))
;
--add 4159498 Histamine receptor antagonist to 46271422 Administration of antipyretic
insert into snomed_relationship
select 
	descendant_concept_id,
	4159498,	--Histamine receptor antagonist
	null as invalid_reason,
	'Has dir subst' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (46271422) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4159498))
;
--add 4286329 Interleukin-2 to 4218960 interleukin 2 therapy
insert into snomed_relationship
select 
	descendant_concept_id,
	4286329,	--Interleukin-2
	null as invalid_reason,
	'Has dir subst' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (4218960) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4286329))
;
--add 4129646 Diagnostic intent 4122814 Nuclear medicine study of systems
insert into snomed_relationship
select 
	descendant_concept_id,
	4129646,	--Diagnostic intent
	null as invalid_reason,
	'Has intent' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (4122814) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4129646))
;
--add 4155005 Intravascular ultrasound device to 4085444 Intravascular US scan
insert into snomed_relationship
select 
	descendant_concept_id,
	4155005,	--Intravascular ultrasound device
	null as invalid_reason,
	'Has intent' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (4085444) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4155005))
;
--add 4155005 Intravascular ultrasound device to 4098215 Intravascular echocardiography
insert into snomed_relationship
select 
	descendant_concept_id,
	4155005,	--Intravascular ultrasound device
	null as invalid_reason,
	'Has intent' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (4098215) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4155005))
;
--add 4013297 Transesophageal approach to 4019323 Transesophageal aortography and 4019824 Transesophageal echocardiography
insert into snomed_relationship
select 
	descendant_concept_id,
	4013297,	--Transesophageal approach
	null as invalid_reason,
	'Has access' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (4019323) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4013297))
;
--add 4013297 Transesophageal approach to 4019323 Transesophageal aortography and 4019824 Transesophageal echocardiography
insert into snomed_relationship
select 
	descendant_concept_id,
	4013297,	--Transesophageal approach
	null as invalid_reason,
	'Has access' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (4019824) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4013297))
;
--add 4044379 Closed approach to 4142040 Closed drainage of chest
insert into snomed_relationship
select 
	descendant_concept_id,
	4044379,	--Closed approach
	null as invalid_reason,
	'Has access' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (4142040) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4044379))
;
--add 4136419 Coronary artery graft to 42872515 CT angiography of coronary artery bypass graft
insert into snomed_relationship
select 
	descendant_concept_id,
	4136419,	--Coronary artery graft
	null as invalid_reason,
	'Has dir proc site' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (42872515) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4136419))
;
--add 4136419 Coronary artery graft to 4329385 Fluoroscopic angiography of coronary graft using contrast
insert into snomed_relationship
select 
	descendant_concept_id,
	4136419,	--Coronary artery graft
	null as invalid_reason,
	'Has dir proc site' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (4329385) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4136419))
;
--add 4185128 Body tissue material to 44783018 Full thickness autograft of skin
insert into snomed_relationship
select 
	descendant_concept_id,
	4185128,	--Body tissue material
	null as invalid_reason,
	'Has dir proc site' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (44783018) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4185128))
;
--add 4207963 Fetal structure to 4196167 MRI of fetus
insert into snomed_relationship
select 
	descendant_concept_id,
	4207963,	--Fetal structure
	null as invalid_reason,
	'Has dir proc site' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (4196167) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4207963))
;
--add 4008953 Vascular prosthesis to 4305643 Artificial graft
insert into snomed_relationship
select 
	descendant_concept_id,
	4008953,	--Vascular prosthesis
	null as invalid_reason,
	'Has dir device' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (4305643) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4008953))
;
--add 4117483 Occlusion - action to 4282394 Surgical occlusion of blood vessel
insert into snomed_relationship
select 
	descendant_concept_id,
	4117483,	--Occlusion - action
	null as invalid_reason,
	'Has method' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (4282394) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4117483))
;
--Add radiation to all radiotherapies
insert into snomed_relationship 
select 
	descendant_concept_id,
	4054326,	--Ionizing radiation
	null,
	'Using energy',
	to_date ('20991231','yyyymmdd'),
	to_date ('yyyymmdd','20991231')
from ancestor_snomed a
where
	ancestor_concept_id in (4029715) and --Radiation oncology AND/OR radiotherapy
	descendant_concept_id not in --except
		(
			select descendant_concept_id
			from ancestor_snomed
			where
				ancestor_concept_id in
					(
						4161415	--Radionuclide therapy (brachytherapy)
					)
		) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4054326))
;
--Add 45772840 Implantable cardiac pacemaker to 4184306 Insertion of carotid pacemaker
insert into snomed_relationship
select 
	descendant_concept_id,
	45772840,	--Implantable cardiac pacemaker
	null as invalid_reason,
	'Has dir proc site' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (4184306) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,45772840))
;
--add 4127468 Transluminal approach to 40489873 Transluminal angioplasty
insert into snomed_relationship
select 
	descendant_concept_id,
	4127468,	--Transluminal approach
	null as invalid_reason,
	'Has access' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (40489873) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4127468))
;
;
--Add 4127468 Transluminal approach to 4181955 Endovascular insertion of stent
-- insert into snomed_relationship
-- select 
-- 	descendant_concept_id,
-- 	4127468,	--Transluminal approach
-- 	null as invalid_reason,
-- 	'Has access' as relationship_id,
-- 	to_date ('20991231','yyyymmdd') as valid_end_date,
-- 	to_date ('yyyymmdd','20991231') as valid_start_date
-- from ancestor_snomed a
-- where
-- 	ancestor_concept_id in (4181955) and
-- 	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4127468))
;
insert into snomed_relationship 
values 
	(
		40489414,	--Bypass of femoral artery by anastomosis of femoral artery to peroneal artery using vein graft
		4339212,	--Structure of peroneal artery
		null,
		'Has dir proc site',
		to_date ('20991231','yyyymmdd'),
		to_date ('yyyymmdd','20991231')
	)
;
insert into snomed_relationship 
values 
	(
		40490431,	--Bypass of femoral artery by anastomosis of femoral artery to tibial artery using vein graft
		4194449,	--Branch of popliteal artery
		null,
		'Has dir proc site',
		to_date ('20991231','yyyymmdd'),
		to_date ('yyyymmdd','20991231')
	)
;
--add 4148334 Cecostomy - stoma to 4287937 Cecostomy operations
insert into snomed_relationship
select 
	descendant_concept_id,
	4148334,	--Vascular prosthesis
	null as invalid_reason,
	'Has dir proc site' as relationship_id,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	to_date ('yyyymmdd','20991231') as valid_start_date
from ancestor_snomed a
where
	ancestor_concept_id in (4287937) and
	not exists (select from snomed_relationship where (concept_id_1, concept_id_2) = (descendant_concept_id,4148334))
;
insert into snomed_relationship 
values 
	(
		4152539,	--Thoracoscopic splanchnicectomy
		4199473,	--Thoracic structure
		null,
		'Has dir proc site',
		to_date ('20991231','yyyymmdd'),
		to_date ('yyyymmdd','20991231')
	)
;
insert into snomed_relationship 
values 
	(
		4160414,	--Fluoroscopic genitography
		4216845,	--Genital structure
		null,
		'Has dir proc site',
		to_date ('20991231','yyyymmdd'),
		to_date ('yyyymmdd','20991231')
	)
;
-- replace Technecium 99m with Technecium 99
-- update snomed_relationship
-- set concept_id_2 = 4296015
-- where concept_id_2 = 4219119
;
--removve attribute ancestor when descendant is present
delete from snomed_relationship s1
where
	exists
		(
			select 
			from snomed_relationship s2
			join ancestor_snomed a on
				s2.concept_id_1 = s1.concept_id_1 and
				s2.concept_id_2 = a.descendant_concept_id and
				a.ancestor_concept_id = s1.concept_id_2 and
				a.min_levels_of_separation > 0
		)
;
;
delete from snomed_relationship
where
	(concept_id_1, concept_id_2) in
	(
		(4330786, 4129084) --Grafting of bone using synthetic graft, Bone graft [tissue]
	)
;
--Prevent procedures that are not going to be correct in pool
delete from snomed_relationship t where
	exists
		(
			select 1
			from ancestor_snomed sa
			where 
				sa.descendant_concept_id = t.concept_id_1 and
				sa.ancestor_concept_id in
					(
						4141414,	--Prosthetic augmentation of ligament
						4072421,	--Gamete intrauterine transfer
						4066570,	--Intracranial transection of cranial nerve
						4045947,	--Selective fetal reduction
						4151662,	--Delayed closure of abdominal wall
						4234230,	--Lip shave
						4204846,	--Implantation of tissue mandril for vascular graft
						4020665,	--Transluminal heart assist operations
						4119584,	--Facial wrinkle removal
						4263596,	--Megavoltage radiation therapy
						4099228,	--Test of the spine
						4090026,	--Maxillofacial technical procedure
						4001216,	--Coagulation
-- 						4220195,	--Subtotal resection of esophagus
						4234895,	--Excision of prominence of cornea in staphyloma
						4295740,	--Orthopedic procedure on head
						4067147,	--Excision of retraction pocket of tympanic membrane
						4228472,	--Excision of hyperplastic oral soft tissue
						4177087,	--Surgical implantation to lymphatic system
						4124029,	--Intra-abdominal manipulation of GIT
						4294054,	--Abdominoperineal resection of anus
						4338039,	--Speech and language disorder
						4309959,	--Excision of benign lesion of trunk
						4170944,	--Forcible deformity correction
						4075282,	--Excision of whole muscle group
						4034380,	--Excision of knee fat pad
						4063526,	--Major excision of brain tissue
						4020363,	--Open operations for combined abnormality of great vessels
						4194001,	--Reversal of procedure for complex congenital heart disease
						4031263,	--Plication
						4043547,	--Diagnostic procedure on cerebellum
						4336891,	--Operation to open an interatrial communication
						4292577,	--Operation for transposition-like conditions
						4339964,	--Repair of cor triatrium
						4183608,	--Repair of heart septum with tissue graft
						4336605,	--Decalcification of aortic valve
						4324535,	--Osteoclasis
						4194410,	--Repair for facial weakness
						4338450,	--Repair of implanted pulmonary paravalvular leak
						4293017,	--Open heart valvuloplasty of pulmonary valve without replacement
						4049978,	--Intraventricular operation for transposition or double outlet ventricle
						4339978,	--Suture of left ventricle
						4336896,	--Suture of right ventricle
						4137391,	--Repair of univentricular heart
						4197929,	--Banding
						4220486,	--Creation of syndactyly
						4126758,	--Repair of cleft palate
						4013482,	--Dermodesis
						4148131,	--Open heart valvuloplasty without replacement of valve
						4339739,	--Operation on implanted aortic valve
						4082195,	--Balloon cardiac valvotomy
						4282481,	--Change in bone length
						4067486,	--Functional endoscopic sinus surgery - therapeutic endoscopy of nose and sinus
						4067363,	--Functional endoscopic sinus surgery - diagnostic endoscopy of nose and sinus
						4071381,	--Adjustment to origin of tendon or muscle
						4041640,	--Interposition arthroplasty
						45766060,	--Reversal of sterilization
						4027897,	--Repair of cardiac pacemaker pocket in skin AND/OR subcutaneous tissue
						4022625,	--Repair of femoral artery with temporary silastic shunt
						4335870,	--Removal of intravitreal gas/fluid
						4232320,	--Cardiopulmonary resuscitation
						36713386,	--Vascular system care
						4021515,	--Covering eye
						4122481,	--Repair of existing restoration of tooth
						4141800,	--Correction of pectus deformity
						4022936,	--Open removal or destruction of renal lesion
						4069040,	--Release of transfixion of tongue
						4236837,	--Tendon pulley reconstruction
						4045962,	--Laser recanalization of intracranial vessel
						4080104,	--Correction of complex craniofacial deformity
						4225281,	--Rhinocheiloplasty
						45766058,	--Sterilization procedure
						40486699,	--Endoscopic ultrasonography of retroperitoneum
						4172366,	--Percutaneous arterial device procedure
						4315400,	--Local excision
						4031292,	--Removal of foreign material from previous herniorraphy
						4203782,	--Harvesting of donor material
						4218438,	--Circumcision
						4121165,	--Cholecystectomy and exploration of bile duct
						4270654,	--Excision of cystic duct remnant
-- 						4089389,	--Intersex surgery
						4170791,	--Percutaneous needle biopsy -- Biopsies in ICD10PCS must specify exact method: drainage or excision
-- 						4223677,	--Neurolysis
						40479863,	--Drainage of pelvirectal tissue --for test purposes. May be valid target entry, remove if needed
-- 						4277583,	--Chemodenervation
						4045615,	--Intracranial destruction of cranial nerve
						4072499,	--Regimes and therapies
						4335047,	--Injection of neurolytic substance to Gasserian ganglion
						4177374,	--Intermittent infusion of therapeutic substance
						4157327,	--Counting procedure-related devices
						4078727,	--Continuous infusion of therapeutic substance
						4182281,	--Inhibition of lactation procedure
						4191700,	--Injection of trigger points
						4202594,	--Administration of drug or medicament by intravenous push
						4219502,	--Sedation
						4104373,	--Angiocardiography, positive contrast
-- 						4085444,	--Intravascular US scan
						4181212,	--Radiologic imaging, special views and positions --subconcepts specify too much
						4302147,	--Echography, B-scan
						4345944,	--Sinogram
						42872567,	--Magnetic resonance imaging T2 mapping
						4240658,	--Diagnostic radiography with gas-air, negative contrast
						4019821,	--Intravenous digital subtraction angiography
						4312101,	--Hypotonic duodenography
						44783484,	--Postmortem imaging procedure
						4081549,	--Stereographic radiography
						4202298,	--X-ray of lower limb using mobile image intensifier
						37016708,	--CT of lower limb for bone length measurement
						4125533,	--Specific spinal X-ray
						4082995,	--X-ray photon absorptiometry
						4206456,	--Antegrade urography
						4336465,	--Coronary artery bypass grafts x 2 -- even though there ARE multiple CABG procedures in ICD10PCS, it is impossible to define them by SNOMED's own attributes
						4096930,	--Creation of shunt left-to-right, systemic to pulmonary circulation
						4338735,	--Unifocalization operation
						4050281,	--Extra-anatomical bypass graft
						4225224,	--Femoro-proximal popliteal artery bypass
						4226951,	--Femoro-distal popliteal artery bypass
						4066165,	--Composite graft
						4075317,	--Reconstruction with mucosal graft
						4341382,	--Construction of continent urinary reservoir
						4245767,	--Intestinal bypass for morbid obesity
						4139026,	--Antireflux operation
						4313420,	--Cineplastic amputation
						4204692,	--Reamputation
						4113332,	--Activation of implant
						4309515,	--Insertion of laminaria into cervix -- only Organism Laminaria is available
						4178808,	--Exteriorization by anatomic site
						4066570,	--Intracranial transection of cranial nerve
						4119229,	--Intraspinal nerve root division
						4149679,	--Vascular access incision
						4246742,	--Reopening of osteotomy site
						4034392,	--Division of intra-articular plica
						4231994,	--Division of vaginal septum
						4266534,	--Division of isthmus of horseshoe kidney
						4234025,	--Deep incision with opening of bone cortex of leg
						506537,		--Tc-99 MIBI (technetium 99m methoxyisobutylisonitrile) parathyroid subtraction study
						44789773,	--Parathyroid washout
						4077087,	--Plastic excision of skin
						4057955,	--Microbiology procedure
						4051946,	--Closure of an aortic tunnel
-- 						4291637,	--Split thickness skin graft --must be specified
-- 						4324976,	--Full thickness skin graft --must be specified
						4114792,	--Complex reconstruction of soft tissue of hand
						4032135,	--Procedure to previous chest wall incision
						4337583,	--Operation in laryngeal paralysis
						4034305,	--Operation on joint arthroplasty
						4336592,	--Operation on implanted mitral valve
						4336600,	--Operation on implanted tricuspid valve
						4098578,	--Revision of anastomosis of blood vessel
						4335171,	--Revision of skin pocket for pacemaker
						4216243,	--Photoplethysmography
						4338595,	--Cardiac support using extracorporeal membrane oxygenation circuitry
						4059828,	--Thyroid tumor/metastasis irradiation
						40480502,	--Conformal radiotherapy
						40480519,	--Intensity modulated radiation therapy
						4060643,	--Intracavitary X-ray therapy
						42537347,	--Administration of antipruritic
						46271422,	--Administration of antipyretic
						4034460,	--Application of spinal traction system
						4181464,	--Revisional foraminoplasty of spine
						44813781,	--Fluoroscopy guided trans-arterial hepatic radioembolisation using yttrium-90 microspheres
						4050562,	--Cardiac conduit operation
						4263226,	--Resection of aortic valve for subvalvular stenosis
						42872823,	--Revision of transplantation of heart
						4021421,	--Revision of urinary diversion
						4082802,	--Revision of first stage urethroplasty
						4343119,	--Revision of hypospadias repair
						4216177,	--Postoperative chemotherapy
						4156930,	--Temporary implant radiotherapy
						4344627,	--Multifetal pregnancy reduction
						4175670,	--Soak
						40492443,	--Sampling for smear
						4021009,	--Female perineal area care procedures
						4314791,	--Biopsy of soft tissue of forearm, deep
						4234095,	--Biopsy of soft tissue of forearm, superficial
						4102441,	--Biopsy of soft tissue of ankle area, deep
						4031834,	--Biopsy of soft tissue of ankle area, superficial
						4128562,	--McKeown esophagectomy
						4122235,	--Trans-hiatal esophagectomy
						4237320,	--Procedure with procedure focus
						4069074,	--Wedge resection
						4069986,	--Excision of blemish of skin of head or neck
						4224756,	--Diagnostic radiography of fistula or sinus tract, positive contrast
						4347685,	--Gastrointestinal tract loopogram
						4202557,	--Contrast enema
						36714957,	--Expiratory CT
						4138256,	--Intravenous pyelogram
						4046291,	--Induction of emesis
						45766298,	--Combined chemotherapy and radiation therapy
						4061549,	--Combined radiotherapy
						46273717,	--Endothelial keratoplasty
						4308732,	--Lamellar keratoplasty
						4172642,	--Penetrating keratoplasty
						4326512,	--Grafting of bone using autogenous muscle pedicle graft
						4236996,	--Scraping
						4092974,	--Special investigations on ear
						4197652,	--Drilling
						4020329,	--Pancreaticoduodenectomy
						4078567,	--Excision of ovotestis
						4070143,	--Microtherapeutic endoscopic operations on larynx
						4211374,	--Incision AND drainage
						4301005,	--Fistulisation of ranula
						4157327,	--Counting procedure-related devices
						4196073,	--Removal of pectus deformity implant device
						4173615,	--Incision of uterus
						4089389,	--Intersex surgery
						4055623,	--Repair of inverted uterus
						4228655,	--Manual examination of uterus
						4058450,	--Specific imaging methods
						4167021,	--Radiologic examination, osseous survey, complete
						4197721,	--Contrast meal
						4345931,	--Pouchogram
						4165871,	--Dental examination for personal identification
						4013011,	--Intra-oral photography
						4346079,	--Breast sinogram
						4345945,	--Pneumocystogram
						4148004,	--Venography of inferior vena cava with serialography
						4058774,	--Purpose of radiotherapy
						4140835,	--Pulmonary resuscitation
						4061026,	--Dynamic non-imaging isotope study
						4059831,	--Internal radiotherapy - unsealed source
						4276330,	--General radiation therapy consultation and report
						4059677,	--Isotope uptake/excretion studies (procedure)
						4253945,	--Vectorcardiogram
						4168511,	--Radionuclide white blood cell imaging study
						4346616,	--Whole body radioiodine I123 study
						4197633,	--Myocardial perfusion stress imaging using Thallium 201
						4076066,	--Removal of implanted substance from bone
						4223546,	--Microdissection of nerve
						4051950,	--Operation on systemic to pulmonary artery shunt
						4143507,	--Intubated ureterotomy
						4330187,	--Intracranial microdissection
						37397404,	--Contralateral neck dissection
						4341539,	--Release of penis from zipper
						4301430,	--Removal of bone fragments
						4290099,	--Ocular photography, close up
						4071170,	--Ocular photography for medical evaluation and documentation, stereophotography
						4151924,	--Reimplantation
						4230644,	--Transposition of cranial and peripheral nerves -- inverted hierarchy
						4119982,	--Delay of skin flap
						4082207,	--Division of flap
						4118083,	--Final inset of skin flap
						37110029,	--Antibiotic therapy for prevention of recurrent infection
						42538259	--Endovascular insertion of drug coated stent
					)
		)
;
delete from snomed_relationship t where
	exists
		(
			select 1
			from snomed_relationship sr
			where 
				sr.concept_id_1 = t.concept_id_1 and
				sr.concept_id_2 in
					(
						4232653,	--Glueing
						4255049,	--Swab
						4195605,	--Abscess morphology
						4007976,	--Lymphocyst
						4211223,	--Trephine
						4311963,	--Aneurysm
						4148390,	--Laceration
						4097825,	--Suture
						4300943,	--Surgical Patch -- seem to refer to 'shape' of graft in procedures while ICD10PCS specifies material
						4046730,	--Laser device
						4106026,	--Pack
-- 						4307814,	--Anterior approach -- moved to attribute filter
-- 						4011082,	--Posterior approach
						4232320,	--Cardiopulmonary resuscitation
						4044538,	--Surgical lengthening - action
						4044196,	--Surgical shortening - action
						4044510,	--Core biopsy needle -- kind of needle is never specified
						4301694,	--Surgical staple
						4044376,	--Pars plana approach
						4083673,	--Diathermy device
						4232804,	--Surgical band
						4232816,	--Prophylaxis - intent
						4167878,	--Diagnostic dye -- weird hierarchy
						4113754,	--Caustic
						4180939,	--Negative contrast media -- no differentiation in ICD10PCS
						4157557,	--Microvascular anastomosis - action
						4238039,	--Transurethral approach
						4232667,	--Gold weight
						4042333,	--Trabeculae carneae cordis
						4236072,	--Attention - action
						4234439,	--Nonsurgical biopsy - action
						4045055,	--Incisional biopsy - action
						4079310,	--Excision biopsy
						4193369,	--Entire body organ
-- 						4044524,	--Removal - action
						4237366,	--Body system structure
						4044554,	--Preventive intent
						4093606,	--Emergency
						4234571,	--Screening intent
						40480953	--Chemical
					)
		)
;
--wrong attributes assigned
delete from snomed_relationship t
where concept_id_1 in 
	(
		4177089,	--Surgical repair procedure by device
		4081877,	--Cephalometry X-ray
		4168236,	--Evaluation of uterine fundal height
		4070574,	--Reconstruction of chest wall with microvascular transferred flap
		4337440,	--Operation to close an interatrial communication
		4026042,	--First postoperative examination and eye dressing
		4175640,	--Repair of heart assist system
		4322244,	--Reparative closure using a device
		4323148,	--Correction of overlapping toes
		4281685,	--Reattachment of extremity of toe
		4323422,	--Reconstruction of foot and toes with fixation device
		4081713,	--Correction of inverted nipples
		4019224,	--Repair of hemitruncus arteriosus
		4280075,	--Repair of nonunion of tarsal bones
		4075211,	--Dutoit and Roux operation
		4070122,	--Functional endoscopic sinus surgery - therapeutic antroscopy via canine fossa
		4067364,	--Functional endoscopic sinus surgery - diagnostic antroscopy via inferior meatus
		4070120,	--Functional endoscopic sinus surgery - diagnostic antroscopy via middle meatus
		4327864,	--Endovascular repair of carotid artery
		42872718,	--Open repair of extraarticular ligament
		4074406,	--Complex reconstruction operations on hand and foot
		4106922,	--Primary open repair intra-articular ligament
		4106923,	--Revision open repair intra-articular ligament
		4173654,	--Correction of scoliosis
		4195461,	--Excision, fusion and repair of toes
		4234427,	--Repair of of hernia cul-de-sac
		4233447,	--Excision of nerve of posterior thigh muscle
		4031517,	--Operative reduction of prolapse of anus
		4340250,	--Sphincteroplasty of duodenal papilla
		40479754,	--Augmentation of soft tissue of face using expanded polytetrafluoroethylene implant
		4146450,	--Extraarticular scapular resection with reconstruction of shoulder
		4130330,	--Ligation or embolization of pelvic vessels
		4120436,	--Enteromesenteric bridge operation
		4197922,	--Lymphangiography
		4138163,	--Repair of coronary sinus abnormality
		4014415,	--Neuroplasty of nerve of foot
		4138606,	--Endoscopic vocal cord medialization
		4337813,	--Operation on temporal bone, middle fossa approach
		4196381,	--Removal of electroencephalographic receiver from brain
		4079719,	--Removal of constricting band from limb
		4233447,	--Excision of nerve of posterior thigh muscle
		4261385,	--Craniectomy with excision of bone lesion of skull
		4033529,	--Deep biopsy of soft tissue of back
		4184922,	--Superficial biopsy of soft tissue of back
		4050587,	--Resection and end-to-end anastomosis of pulmonary trunk
		4123415,	--Anal myectomy
		4333165,	--Vitreous base vitrectomy
		4068324,	--Frontalis muscle support operation
		4114786,	--Excision of lymphoedematous tissue of leg
		4138729,	--Excision of lymphedematous tissue of arm
		4088617,	--Endoscopic airway clearance
		40484127,	--Excision of ruptured appendix by open approach
		4031112,	--Myectomy for graft
		4198051,	--Removal of necrotic bone fragment from joint
		4074242,	--Metacarpal support operation on carpus
		4337945,	--Resection of temporal bone by external approach
		4167423,	--Nasal bone infraction
		4071391,	--Wide excision of muscle tissue
		4023806,	--Fistulisation of cisterna chyli
		4119728,	--External maxillary antrostomy
		4030839,	--Open pleuroperitoneal shunt procedure
		36717747,	--Gender reassignment surgery
		4239147,	--Opticociliary neurectomy
		4073665,	--Image controlled operations on abdominal cavity
		4169913,	--Drainage of ventricle through previously implanted catheter
		4038381,	--Neuromuscular stimulation
		4176964,	--Paracentesis of female genital tract structure
		4118899,	--Hypodermic drug injection
		4170937,	--Irrigation to evacuate
		4083667,	--Intravenous fluid replacement
		4121918,	--Dried plasma injection
		4080949,	--Injection of pericardial sac for local action
		4335037,	--Fracture infiltration with local anesthetic
		4136980,	--Selective angiocardiography
		4329522,	--Fluoroscopic angiography for thrombolysis follow-up
		40482321,	--Three dimensional rotational fluoroscopic angiography with contrast
		4206840,	--Fluoroscopic arteriography of carotid artery with direct puncture
		4335683,	--Fluoroscopic intravenous digital subtraction angiography of carotid artery
		4329784,	--Fluoroscopic angiography of abdominal vessel using carbon dioxide contrast
		4162205,	--Fluoroscopic angiography of lower leg with carbon dioxide negative contrast
		46272920,	--Gated computed tomography for cardiac function with contrast
		4252039,	--Ophthalmic angiography
		4346066,	--Digital fluoroscopy swallow
		4303253,	--Fluoroscopic gastrointestinal tract loopography
		4161386,	--Fluoroscopy of gastrointestinal tract using water soluble contrast swallow and meal
		45765924,	--Fluoroscopy of upper gastrointestinal tract and small bowel follow through
		4231193,	--Ultrasonography of subcutaneous contraceptive implant
		44805203,	--Transoesophageal echocardiography for complex congenital heart disease
		4069976,	--Repositioning of umbilical cord
		4168831,	--Minimally invasive direct coronary artery bypass
		4305852,	--Off-pump coronary artery bypass
		4331729,	--Creation of arteriovenous fistula with nonautogenous graft
		4240458,	--Ilioiliac bypass graft with vein
		4226815,	--Femorofemoral crossover arterial bypass with vein
		4194864,	--Femoroposterior tibial reversed vein bypass graft
		4020467,	--Creation of venovenous bypass
		4194116,	--Tubotubal anastomosis
		4340238,	--Triple bypass of pancreas
		4068874,	--Therapeutic percutaneous attention to connection of bile duct
		40486568,	--Conversion from previous anastomosis of stomach to jejunum
		4067088,	--Bypass of esophagus by interposition of microvascularly attached colon
		4049813,	--Femorofemoral venous crossover shunt
		4143503,	--Palma operation
		4141239,	--Extracranial transection of accessory nerve
		4094249,	--Ball operation, undercutting of perianal tissue
		4018712,	--Open division of accessory pathway within heart
		4069467,	--Division of annular pancreas
		4133356,	--Iliac fossa muscle cutting incision
		4287864,	--Division of cartilage of spine
		4074538,	--Angulation periarticular division of bone
		4067594,	--Excision of lesion of larynx using lateral pharyngotomy as approach
		4307531,	--Operation on soft tissue of hand
		4149493,	--Biopsy of soft tissue of upper arm, superficial
		4271855,	--Biopsy of soft tissue of upper arm, deep
		40486919,	--Excision of intradural lesion of base of anterior cranial fossa
		40486920,	--Excision of intradural lesion of base of posterior cranial fossa
		40493241,	--Excision of intradural lesion of base of middle cranial fossa
		4243335,	--Initial implantation of cardiac dual-chamber device
		4280568,	--Vaginal cone irradiation
		4235673,	--Grafting of full thickness free graft to trunk with direct closure of donor site
		4234327,	--Removal and replacement of subcutaneous port component after open gastric restrictive procedure
		4019930,	--Revision of correction of tetralogy of Fallot
		4260660,	--Secondary revision of orbitocraniofacial reconstruction
		4108862,	--Revision of implanted intra-arterial infusion pump
		4098343,	--Pulse generated run-off
		4101913,	--Capillaroscopy
		4329379,	--Radionuclide electrocardiography gated myocardial perfusion rest study using thallium 201
		4118462,	--Radionuclide water and electrolyte study
		35624220,	--Radionuclide imaging using high dose gallium-67
		4063662,	--Intracranial stereotactic release of cranial nerve
		4243752,	--Revision of intracranial neurostimulator receiver
		4041195,	--Neurolysis of carpal tunnel
		4339970,	--Resection of right ventricular muscle
		4117941,	--Revision of distal catheter of ventricular shunt
		4118813,	--Revision of proximal catheter of ventricular shunt
		4311119,	--Revision of spinal neurostimulator receiver
		4018585,	--Revision of connection of thoracic artery to coronary artery
		4107093,	--Revision uncemented total replacement ankle joint
		4063319,	--Revision of mallet finger
		4261527,	--Reconstruction of below-elbow amputation
		4231505,	--Stereotactic insertion of intracerebral infusion catheter
		4117349,	--Extraperitoneal drainage
		4118039,	--Nerve division/destruction
		46286841,	--Radionuclide study for detection of liver to lung shunt using Tc99m MAA
		4077467,	--Arthroscopic excision of implanted ligament
		4230237,	--Proximal subtotal pancreatectomy with pancreaticoduodenectomy and pancreatic jejunostomy
		4129792,	--Fenestrectomy
		4223084,	--Excision of exostosis from external auditory canal
		44783602,	--Laparoscopic nephrectomy of remaining kidney
		44783603,	--Laparoscopic nephrectomy of remaining kidney by retroperitoneal approach
		4299613,	--Total ostectomy
		4072076,	--Endoscopic resection of posterior urethral valve
		4051031,	--Straight graft of the abdominal aorta
		4207687,	--Direct repair of intrathoracic artery with bypass
		4040390,	--Procedure on body system
		4107270,	--Arthroscopic division of synovial plica
		4125354,	--CT of systems
		46272569,	--Biomedical equipment procedure
		4080168,	--Peritoneal ovum and sperm transfer
		4137885,	--Alar reconstruction with cartilage graft
		4078410,	--Release of thumb-in-palm deformity
		4123862,	--Cartilage graft - prominent ear
		4127409,	--Tympanoplasty type II with graft against incus or malleus
		37016845,	--Laparoscopic oesophagectomy and gastric mobilisation
		4151772,	--FESS - Functional endoscopic sinus surgery - posterior ethmoidectomy
		4201632,	--Percutaneous transhepatic insertion of biliary drain
		40487558,	--Endoscopic nasobiliary drainage
		4067796,	--Endoscopic retrograde drainage of lesion of pancreas
		4291027,	--Removal of electronic heart device
		4074102,	--Removal correctional spinal instrumentation
		4082149,	--Nasal decrusting
		4205533,	--Suction clearance of nasal cavity
		4060479,	--Venography - pertrochanteric
		4346509,	--Ventricular shuntogram
		4003642,	--Radiologic examination of femur, anteroposterior and lateral views
		4060757,	--Soft tissue X-ray limbs
		4073696,	--Open hemostasis of prostate
		4168511,	--Radionuclide white blood cell imaging study
		4194722,	--Removal of Gentamicin beads from bone
		4224942,	--Insertion of tissue mandril of artery of extremity
		4239323,	--Intraoperative transluminal angioplasty of visceral artery
		4214294,	--Vascular line exchange over wire
		4335750,	--Suprahyoid laryngeal release procedure
		4335459,	--Thyrohyoid laryngeal release procedure
		4045578,	--Removal of arterial graft or prosthesis
		4222749,	--Removal of vascular graft or prosthesis
		4287086,	--Surgical removal of erupted tooth requiring elevation of mucoperiosteal flap and removal of bone and/or section of tooth
		4021187,	--Application of antithromboembolic stockings
		4330633,	--Application of support tights
		4142426,	--Removal of ring from digit of hand
		4188069,	--Functional endoscopic sinus surgery, limited
		4167047,	--X-ray for colonic transit study
		4262396,	--Take-down of arterial anastomosis
		4045613,	--Revision of intracranial pressure transducer
		4048957,	--Revision of intracranial pressure catheter
		4013889,	--Revision of obstructed valve in CSF shunt system
		4263342,	--Neuroplasty and transposition of cranial nerve
		4065703,	--Transposition of ligament of orbit
		4144564,	--Primary neurolysis and transposition of peripheral nerve
		4064113,	--Secondary neurolysis and transposition of peripheral nerve
		4174825,	--Removal of intracranial neurostimulator receiver
		4104744,	--Division of trigeminal nerve at foramen ovale
		4231368,	--Laparoscopic selective transection of vagus nerve
		4215103	--Operation on neck and trunk
	)
;
--has only bad DESCENDANTS
delete from snomed_relationship
where concept_id_1 in
	(
		select descendant_concept_id
		from ancestor_snomed 
		where
			min_levels_of_separation > 0 and
			ancestor_concept_id in 
				(
-- 					4021108,	--Total nephrectomy
					4291635,	--Transplantation of tissue of chest wall
					4076156	--Percutaneous discectomy
-- 					4121042	--Imaging guidance
				)
	)
;
-- overly specific endoscopes
delete from snomed_relationship t
where concept_id_1 in
	(
		select concept_id_1
		from snomed_relationship r
		join ancestor_snomed a on
			a.descendant_concept_id = r.concept_id_2 and
			a.ancestor_concept_id in
				(
					4120689, --rigid endoscope
					4106959, --flexible endoscope
					4176578	--Strap
				)
	
	)
;
delete from snomed_relationship where concept_id_1 in (select concept_id from concept where concept_name like 'Submucous %' and vocabulary_id = 'SNOMED' and concept_class_id = 'Procedure');
delete from snomed_relationship where concept_id_1 in (select concept_id from concept where concept_name like '% without fracture reduction' and vocabulary_id = 'SNOMED' and concept_class_id = 'Procedure');
delete from snomed_relationship where concept_id_1 in (	select concept_id from concept where concept_name ilike '%cardiac conduit%' and vocabulary_id = 'SNOMED' and concept_class_id = 'Procedure');
delete from snomed_relationship where concept_id_1 in (	select concept_id from concept where concept_name like '% with % flap' and vocabulary_id = 'SNOMED' and concept_class_id = 'Procedure'); --flap is not specified in attrs
delete from snomed_relationship where concept_id_1 in (	select concept_id from concept where concept_name ilike '%revision%anastomosis%' and vocabulary_id = 'SNOMED' and concept_class_id = 'Procedure'); --anastomosis is not specified in attrs
delete from snomed_relationship where concept_id_1 in (	select concept_id from concept where concept_name ilike '%revision%bypass%' and vocabulary_id = 'SNOMED' and concept_class_id = 'Procedure'); --anastomosis is not specified in attrs
delete from snomed_relationship where concept_id_1 in (	select concept_id from concept where concept_name ilike '%revision%coag%' and vocabulary_id = 'SNOMED' and concept_class_id = 'Procedure');
delete from snomed_relationship where concept_id_1 in (	select concept_id from concept where concept_name ilike '%revision%fusion%' and vocabulary_id = 'SNOMED' and concept_class_id = 'Procedure');
delete from snomed_relationship where concept_id_1 in (	select concept_id from concept where concept_name ilike '%revision%implant%' and vocabulary_id = 'SNOMED' and concept_class_id = 'Procedure');
delete from snomed_relationship where concept_id_1 in (	select concept_id from concept where concept_name ilike '%revision%amputat%' and vocabulary_id = 'SNOMED' and concept_class_id = 'Procedure');
delete from snomed_relationship where concept_id_1 in (	select concept_id from concept where concept_name ilike '%revision%stimul%' and vocabulary_id = 'SNOMED' and concept_class_id = 'Procedure');
delete from snomed_relationship where concept_id_1 in (	select concept_id from concept where concept_name ilike '%revision%reservo%' and vocabulary_id = 'SNOMED' and concept_class_id = 'Procedure');
delete from snomed_relationship where concept_id_1 in (	select concept_id from concept where concept_name like 'Chemical test, %' and vocabulary_id = 'SNOMED' and concept_class_id = 'Procedure');
;
--Imaging procedures can't specify approach
delete from snomed_relationship
where
	concept_id_1 in
		(
			select concept_id_1
			from ancestor_snomed
			join snomed_relationship on
				relationship_id = 'Has access' and
				concept_id_1 = descendant_concept_id and
				ancestor_concept_id = 4180938 --Imaging
		)
;
delete from snomed_relationship --Procedure should be specified as performed ON 'Structure of product of conception', not TO
where
	concept_id_1 in
		(
			select concept_id_1 from snomed_relationship where relationship_id = 'Has dir proc site' and concept_id_2 = 4097520
		)
;
--Imaging guided operations have to go
delete from snomed_relationship x
where 
	x.concept_id_1 in
	(
		select r.concept_id_1
		from snomed_relationship r 
		join ancestor_snomed a1 on
			a1.ancestor_concept_id = 4180938 and -- Imaging (procedure) that specifies a method
			relationship_id in ('Has method','Has revision status') and
			r.concept_id_1 = a1.descendant_concept_id
		left join ancestor_snomed a2 on --that is not a kind of Imaging
			a2.ancestor_concept_id = 4230986 and --Imaging - action
			r.concept_id_2 = a2.descendant_concept_id
		where a2.descendant_concept_id is null
	)
	
;
--group of procedures that specify site in name but not attributes
delete from snomed_relationship t
where concept_id_1 in
	(
		select concept_id
		from concept
		where 
			vocabulary_id = 'SNOMED' and
			concept_name like 'Neuroplasty of% nerve at%'
	)
;
DELETE
FROM snomed_relationship
WHERE concept_id_1 IN 
	(
		SELECT c1.concept_id
		FROM snomed_relationship
		JOIN concept c1 ON
			concept_id_1 = c1.concept_id AND
			relationship_id = 'Has focus'
		JOIN concept c2 ON
			concept_id_2 = c2.concept_id AND
			c2.domain_id = 'Condition'
	)
;
delete from snomed_relationship --remove common descendants of Excision and Destructive
WHERE concept_id_1 IN 
	(
		SELECT a1.descendant_concept_id
		from ancestor_snomed a1
		join ancestor_snomed a2 on
			a1.descendant_concept_id = a2.descendant_concept_id and
			a1.ancestor_concept_id = 4275431 and --destr
			a2.ancestor_concept_id = 4279903 --excis
	)
;
analyze snomed_relationship
;
drop table if exists snomed_relationship_hashed cascade -- delete descendants with same attribute groups as ancestors 
;
create unlogged table snomed_relationship_hashed as
with ordered as
	(
		select distinct concept_id_1, concept_id_2
		from snomed_relationship
		join concept on
			concept_id_1 = concept_id and
			concept_class_id = 'Procedure'
		where concept_id_2 not in --too generic to matter, parent is preferrable
			(
				4045049,	--Surgical Action
				40599742,	--Lesion
				4240671,	--Anatomical structure
				4022675,	--Substance
				4254051		--Drug or medicament
			)
		order by concept_id_1, concept_id_2
	)
select concept_id_1, md5(string_agg(concept_id_2::text,'|'))::char(32) as attr_hash
from ordered
group by concept_id_1
;
create index idx_snomed_relationship_hashed on snomed_relationship_hashed (concept_id_1, attr_hash)
;
analyze snomed_relationship_hashed
;
drop table if exists relationship_cleanup cascade
;
create unlogged table relationship_cleanup as
select a.descendant_concept_id
from snomed_relationship_hashed c
join snomed_relationship_hashed c2 on
	c.attr_hash = c2.attr_hash and
	c.concept_id_1 != c2.concept_id_1
join ancestor_snomed a on
	a.descendant_concept_id = c.concept_id_1 and
	a.ancestor_concept_id = c2.concept_id_1 and
	a.min_levels_of_separation != 0
;
delete from snomed_relationship where
	exists (select 1 from relationship_cleanup where concept_id_1 = descendant_concept_id)
;
delete from snomed_relationship r
where 
	concept_id_2 = 4045049 and
	not exists
		(
			select
			from snomed_relationship
			where 
				concept_id_2 != 4045049 and
				concept_id_1 = r.concept_id_1
		)
;
analyze snomed_relationship
;
