--TODO: add 3rd iteration for filtering cycle with sepparate debugging
--IN 3rd iteration first step should be to prefer attributes with the closest parent to attribute being investigated
analyze snomed_relationship
;
drop table if exists attr_from_usagi
;
create unlogged table attr_from_usagi
	(
		attr_name varchar(255),
		concept_id int4,
		concept_name varchar(255),
		NEW_CODE varchar(255),
		NEW_NAME varchar(255),
		extra varchar(255)
	);
-- upload usagi/manually mapped table
/*WbImport -file="Dropbox/i10patos_fu.csv"
			-type=text
			-table=ATTR_FROM_USAGI
			-encoding="UTF-8"
			-header=true
			-decode=false
			-dateFormat="yyyy-MM-dd"
			-timestampFormat="yyyy-MM-dd HH:mm:ss"
			-delimiter='\t'
			-quotechar='"'
			-decimal=.
			-fileColumns=ATTR_NAME,CONCEPT_ID,CONCEPT_NAME,NEW_CODE,NEW_NAME,EXTRA
			-quoteCharEscaping=none
			-ignoreIdentityColumns=false
			-deleteTarget=true
			-continueOnError=false
			-batchSize=1000;*/
;
WbImport -file=/Users/eduardkorchmar/Documents/i10p_attributes.csv
         -type=text
         -table=attr_from_usagi
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=attr_name,concept_id,new_code,new_name,$wb_skip$,extra
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000;
;
drop table if exists attr_map;
create unlogged table attr_map as
select
	attr_name,
	coalesce (c.concept_id, a.concept_id) as concept_id
from attr_from_usagi a
left join concept c on
	a.new_code = c.concept_code and
	c.vocabulary_id = 'SNOMED'
where 
	extra is null and
	coalesce (c.concept_id, a.concept_id) is not null
;
delete from attr_map where concept_id is null
;
drop table if exists icd10mappings
;
--final *source* table we will work with
create table icd10mappings as
select distinct
	c.concept_id as procedure_id,
	c.concept_code as procedure_code,
	c.concept_name as procedure_name,
	c2.concept_id as attribute_id,
	c2.concept_name as attribute_name,
	c2.concept_class_id,
	min (u.priority) over (partition by c.concept_id, c2.concept_id) :: int4 as priority
from atr_unil u
join concept_stage c on
	--c.vocabulary_id = 'ICD10PCS' and
	c.concept_id = u.concept_id
join attr_map a on
	u.attr_name = a.attr_name
join concept c2 on
	c2.concept_id = a.concept_id
;
CREATE INDEX IDX_ICD10MAPPINGS ON ICD10MAPPINGS (ATTRIBUTE_ID, PROCEDURE_ID,CONCEPT_CLASS_ID)
;
CREATE INDEX icd10pattern ON icd10mappings (procedure_code varchar_pattern_ops);
;
create index idx_procedure_id on icd10mappings (procedure_id)
;
create index idx_attribute_id on icd10mappings (attribute_id)
;
create statistics icd10mapstats (ndistinct) on procedure_id,attribute_id from icd10mappings
;
analyze ICD10MAPPINGS
;
--if procedure has a body site attribute that (or it's parents) are subjects to 4214980 Lysis of adhesions subhierarchy, add it as procedure-attribute
insert into icd10mappings
select distinct
 i.procedure_id,
 i.procedure_code,
 i.procedure_name,
 4214980 as attribute_id,
 'Lysis of adhesions' as attribute_name,
 'Procedure' as concept_class_id,
 3 as priority
from icd10mappings i
join icd10mappings x on
	i.attribute_id = 4021230 and --Release
	x.procedure_id = i.procedure_id and
	x.concept_class_id = 'Body Structure'
join ancestor_snomed a on
	a.descendant_concept_id = x.attribute_id
join snomed_relationship r on
	r.concept_id_2 = a.ancestor_concept_id
join ancestor_snomed s on
	s.ancestor_concept_id = 4214980 and --Lysis of adhesions
	s.descendant_concept_id = r.concept_id_1
;
--Crushing should be replaced with 4046290 Lithotripsy as target for Fragmentation 0_F% in corresponding sites
update icd10mappings i
set
	(attribute_id,attribute_name) = (4046290,'Lithotripsy')
where
	attribute_id = 4246082 and -- Crushing
	procedure_id in
		(
			select procedure_id
			from icd10mappings
			join ancestor_snomed on
				attribute_id = descendant_concept_id and
				ancestor_concept_id in
					(
						4047487,	--Urinary system structure
						4146820,	--Biliary tract structure
						4328747	--Salivary structure
					)
		)
;
--if device is specified for Dilation, add Insertion of stent
insert into icd10mappings
select distinct
	i.procedure_id,
	i.procedure_code,
	i.procedure_name,
	4304209 as attribute_id,
	'Placement of stent' as attribute_name,
	'Procedure' as concept_class_id,
	3 as priority
from icd10mappings i
where 
	priority = 6 and --Device
	procedure_code like '0_7%'
;
delete from icd10mappings
where
	attribute_name = 'Closure by clip' and
	procedure_code like '0_W%'
;
--if device is specified for Occlusion, add Insertion <of stent>
insert into icd10mappings
select distinct
 i.procedure_id,
 i.procedure_code,
 i.procedure_name,
 4215793 as attribute_id,
 'Implantation' as attribute_name,
 'Procedure' as concept_class_id,
 3 as priority
from icd10mappings i
where 
	priority = 6 and --Device
	procedure_code like '0_L%'
;
update icd10mappings i
set	(attribute_id, attribute_name, concept_class_id) = (4222563, 'Radioisotope study of hematopoietic system', 'Procedure')
where
	attribute_id = 4226865 and --Blood
	procedure_code like 'C%'
;
--extraction in '1%' (Obstetrics) should be replaced w/ Delivery
update icd10mappings
set
	(attribute_id, attribute_name) = (4128030,'Delivery procedure')
where 
	attribute_id = 4027561 and --Extr, procedure
	procedure_code like '10D00Z%'
;
--replace liquid biopsies with specimen collection
update icd10mappings
set
	(attribute_id, attribute_name) = (4070456, 'Specimen collection')
where
	attribute_id = 4311405 and
	procedure_code like '0_9%'
;
/*update icd10mappings
set
	(attribute_id, attribute_name) = (4232677,'Delivery - action')
where 
	attribute_id = 4043861 and --Extr, method
	procedure_code like '1%'*/
;
--replace Radiographic guidance with 4059385 Radiotherapy - intraoperative control
update icd10mappings
set (attribute_id, attribute_name) = (4059385, 'Radiotherapy - intraoperative control')
where
	attribute_id = 4302076 and --Radiologic guidance procedure
	procedure_code like 'D%'
;
--replace Radiographic guidance with 4098799 Intraoperative neurophysiological monitoring
update icd10mappings
set (attribute_id, attribute_name) = (4098799, 'Intraoperative neurophysiological monitoring')
where
	attribute_id = 4302076 and --Radiologic guidance procedure
	procedure_code like '4%'
;
--Drainage => Centesis for Obstetrics
update icd10mappings
set
	(attribute_id, attribute_name) = (4313285,'Centesis')
where 
	attribute_id = 4046266 and
	procedure_code like '1%'
;
delete from icd10mappings where length (procedure_code) < 6
;
insert into icd10mappings --add attributes of root SNOMED procedures as attributes
select distinct
	i.procedure_id,
	i.procedure_code,
	i.procedure_name,
	c.concept_id,
	c.concept_name,
	c.concept_class_id,
	8 as priority
from icd10mappings i
join snomed_relationship r on
	r.concept_id_1 = i.attribute_id and
	i.concept_class_id = 'Procedure'
join concept c on
	c.concept_id = r.concept_id_2
where i.attribute_id in (4128030,4313285)
;
--Extraction in Obstetrics is Delivery procedure
update icd10mappings i
set
	(attribute_id, attribute_name) = (4128030,'Delivery procedure')
where
	procedure_code like '10D%' and
	attribute_id = 4027561 --Surgical extraction
;
--insert 4078956 'Surgical closure of stoma' into repair + stoma
insert into icd10mappings
select distinct
	i.procedure_id,
	i.procedure_code,
	i.procedure_name,
	c.concept_id,
	c.concept_name,
	c.concept_class_id,
	26 as priority
from icd10mappings i
join 
	(
		select * from concept where concept_id = 4078956 --Surgical closure of stoma
	) c	on true
where
	procedure_code in ('0WQ6XZ2','0WQFXZ2')
--something for stoma excisions? ('0WBFXZ2','0WB6XZ2')
;
--for all Dilations on Cardiovascular system structures, add device 4150246	Angioplasty catheter
insert into icd10mappings
select distinct
	i.procedure_id,
	i.procedure_code,
	i.procedure_name,
	4150246,
	'Angioplasty catheter',
	'Physical Object',
	26
from icd10mappings i
join ancestor_snomed a1 on
	i.attribute_id = a1.descendant_concept_id and
	a1.ancestor_concept_id = 4324523 -- Dilation Procedure
join icd10mappings x on
	i.procedure_id = x.procedure_id and
	x.concept_class_id = 'Body Structure'
join ancestor_snomed a2 on
	x.attribute_id = a2.descendant_concept_id and
	a2.ancestor_concept_id = 4014241 -- Structure of cardiovascular system
;
--comment whole indented section if no lvl6 manual mappings were made
		/*drop table if exists level6
		;
		create table level6 
			(
				ICD_CODE varchar (255),
				ICD_ID int4,
				ICD_NAME varchar (255),
				SNOMED_CODE varchar (31),
				SNOMED_NAME varchar (255),
				snomed_code_2 varchar (31),
				snomed_name_2 varchar (255)
			)
		;
		WbImport -file=/home/ekorchmar/Documents/newicd.csv
		         -type=text
		         -table=level6
		         -encoding="UTF-8"
		         -header=true
		         -decode=false
		         -dateFormat="yyyy-MM-dd"
		         -timestampFormat="yyyy-MM-dd HH:mm:ss"
		         -delimiter='\t'
		         -quotechar='"'
		         -decimal=.
		         -fileColumns=icd_code,icd_id,icd_name,snomed_code,snomed_name,snomed_code_2,snomed_name_2
		         -quoteCharEscaping=none
		         -ignoreIdentityColumns=false
		         -deleteTarget=true
		         -continueOnError=false
		         -batchSize=1000 
		;
		update level6 n
		set ICD_CODE = 
			(
				select concept_code from concept c where c.concept_id = n.icd_id
			)
		;
		--Administration breaks everything
		delete from level6 where icd_code like '3%'
		;
		--fusion may too
		delete from level6 where icd_code like '0_G%'
		;
		--removal of device
-- 		delete from level6 where icd_code like '0_P%'
		;
		update level6 set snomed_code = '4131005' where snomed_code = '119610009'
		;
		update level6 set snomed_code_2 = '4131005' where snomed_code_2 = '119610009'*/
		;
		delete from level6
		where icd_id in
			(
				select concept_id 
				from concept
				where vocabulary_id = 'ICD10PCS' and
				not
					(
						concept_code like '4%' or --only measurements
						concept_code like '0_W%'
					)
			)
		;
		with full_list as
			(
				select distinct
					icd_id,
					icd_code,
					snomed_code
				from level6
				where snomed_code is not null
					UNION
				select distinct
					icd_id,
					icd_code,
					snomed_code_2
				from level6
				where snomed_code_2 is not null
			)
		insert into icd10mappings
		select distinct
			ic.concept_id,
			ic.concept_code,
			ic.concept_name,
			c.concept_id,
			c.concept_name,
			c.concept_class_id,
			8 as priority
		from concept_stage ic
		join full_list f on
-- 			ic.vocabulary_id = 'ICD10PCS' and
			f.icd_code = substr (ic.concept_code,1,6) and
			length (ic.concept_code) = 7
		join concept c on
			c.vocabulary_id = 'SNOMED' and
			f.snomed_code = c.concept_code
		;
/*		with full_list as --insert attributes of all parent attributes
			(
				select distinct
					icd_id,
					icd_code,
					snomed_code
				from level6
				where snomed_code is not null
					UNION
				select distinct
					icd_id,
					icd_code,
					snomed_code_2
				from level6
				where snomed_code_2 is not null
			)*/
		insert into icd10mappings
		select distinct
			ic.procedure_id,
			ic.procedure_code,
			ic.procedure_name,
			ca.concept_id,
			ca.concept_name,
			ca.concept_class_id,
			18 as priority
		from icd10mappings ic
-- 			ic.vocabulary_id = 'ICD10PCS' and
-- 			f.icd_code = substr (ic.concept_code,1,6) and
		join concept c on
			ic.concept_class_id = 'Procedure' and
			ic.attribute_id = c.concept_id
		join snomed_relationship cr on
			c.concept_id = cr.concept_id_1 and
			cr.invalid_reason is null
		join concept ca on
			cr.concept_id_2 = ca.concept_id
		where (ic.procedure_id, ca.concept_id) not in (select procedure_id, attribute_id from icd10mappings)
		;
delete from ICD10MAPPINGS i
where exists 
	(
		select 1 
		from ICD10MAPPINGS x
		where 
			x.priority < i.priority and
			x.procedure_id = i.procedure_id and
			x.attribute_id = i.attribute_id
	)
;
delete from icd10mappings i
where exists 
	(
		select 1 
		from ICD10MAPPINGS x
		where 
			x.ctid < i.ctid and
			x.procedure_id = i.procedure_id and
			x.attribute_id = i.attribute_id
	)
;
ALTER TABLE ICD10MAPPINGS ADD CONSTRAINT xpk_ICD10MAPPINGS PRIMARY KEY (ATTRIBUTE_ID, PROCEDURE_ID)
;
drop table if exists false_pairs cascade
;
-- No biopsy in administration (diagnostic irrgation/washing)
delete from icd10mappings 
where
	procedure_code like '3%' and --Administration
	attribute_id = 4311405 --Biopsy
;
--remove parent attributes where their children are present, for clarity
create unlogged table false_pairs as
	select
		i.procedure_id, i.attribute_id
	from icd10mappings i
	join ancestor_snomed a on
		i.attribute_id = a.ancestor_concept_id and
		a.min_levels_of_separation != 0
	join icd10mappings i2 on
		i2.procedure_id = i.procedure_id and
		a.descendant_concept_id = i2.attribute_id
	where a.ancestor_concept_id not in
		(
			4062063	--Osteopathic manipulation -- to not lose branches
		)
;
delete from icd10mappings 
where (procedure_id, attribute_id) in (select * from false_pairs);
;
-- replace Graftting with Implantation for procedures mentioning 4205702 Prosthesis
update icd10mappings i
set
	(attribute_id, attribute_name) = (4215793, 'Implantation')
where
	i.attribute_id = 4000731 and --Grafting
	exists
		(
			select
			from icd10mappings x
			where
				x.procedure_id = i.procedure_id and
				x.attribute_id = 4205702 --Prosthesis
		)
	
;
--for Resection update all Body Structures with their common children with 4179858 Entire anatomical structure
--TODO: instead of immediate, find highest
with resections_bs as
(
	select distinct 
		i.procedure_id, 
		i.attribute_id,
		i.attribute_name,
		a2.descendant_concept_id as concept_id,
		c2.concept_name
	from icd10mappings i
	join ancestor_snomed a on 
		i.procedure_code like '0_T%' and
		i.concept_class_id = 'Body Structure' and
		i.attribute_id = a.ancestor_concept_id
	join ancestor_snomed a2 on
		a2.ancestor_concept_id = 4179858 and--Entire anatomical structure
		a2.descendant_concept_id = a.descendant_concept_id and
		a.min_levels_of_separation = 1 and
		a.max_levels_of_separation = 1
	join concept c2 on
		a2.descendant_concept_id = c2.concept_id
	join --weird effects with multiple body structures
		(
			select procedure_id 
			from icd10mappings
			where concept_class_id = 'Body Structure'
			group by procedure_id
			having count (attribute_id) = 1
		) bp_counter
	using (procedure_id)
),
resections_filtered as --at least some concepts weirdly have multiple 'entire structure' children
(
	select * 
	from resections_bs i
	where (i.procedure_id, i.attribute_id) in
		(
			select procedure_id, attribute_id
			from resections_bs
			group by procedure_id, attribute_id
			having count (concept_id) = 1 
		)
)
update icd10mappings i
set (attribute_id, attribute_name) = (select distinct concept_id, concept_name from resections_filtered where (procedure_id, attribute_id) = (i.procedure_id, i.attribute_id))
where (i.procedure_id, i.attribute_id) in (select procedure_id, attribute_id from resections_filtered)
;
--immobilization using splints in 2% should be children of 4119906 	Immobilization by splinting
update  icd10mappings i
set (attribute_id, attribute_name) = (4119906,'Immobilization by splinting')
where
	i.attribute_id = 4031047 and --Fixation
	i.procedure_code in
		(
			select x.procedure_code
			from ancestor_snomed a
			join icd10mappings x on
				a.ancestor_concept_id = 4042424 and --Splint
				x.attribute_id = a.descendant_concept_id
		)
;
--add 4287856 Insertion of therapeutic device to Drainage when Drainage Device is specified
insert into icd10mappings
select distinct
	i.procedure_id,
	i.procedure_code,
	i.procedure_name,
	4287856,
	'Insertion of therapeutic device',
	'Procedure',
	6
from icd10mappings i
where
	(
		procedure_code like '0_9%' or
		procedure_code like '1_9%'
	) and
	i.attribute_id = 4139147 --Drain
;
drop table if exists splitter
;
drop sequence if exists nv1
;
CREATE SEQUENCE nv1 INCREMENT BY 1 START WITH 2000000000 NO CYCLE CACHE 20
;--create table that will contain original icd ids and new
create table splitter as
with x as
	(
		select distinct procedure_id from icd10mappings
		where concept_class_id = 'Procedure'
		group by procedure_id
		having count(distinct attribute_id)>1
	)
select
	nextval ('nv1') as replaced_id,
	i.procedure_id,
	i.attribute_id as conflict_id
from icd10mappings i
join x on
	x.procedure_id = i.procedure_id and
	i.concept_class_id = 'Procedure'
;
create index idx_splitter1 on splitter (replaced_id)
;
create index idx_splitter2 on splitter (procedure_id)
;
create index idx_splitter3 on splitter (conflict_id)
;
analyze splitter
;
--repopulate replacements back into icd10mappings
-- explain
insert into icd10mappings
	select 
		s.replaced_id as procedure_id,
		i.procedure_code,
		i.procedure_name,
		i.attribute_id,
		i.attribute_name,
		i.concept_class_id,
		i.priority
from splitter s
join icd10mappings i on
	i.procedure_id = s.procedure_id and
		( --attribute is NOT a procedure OR exactly one of the procedures caused conflict
			i.concept_class_id != 'Procedure' or
			i.attribute_id = conflict_id
		)
;
delete from icd10mappings
where procedure_id in
	(
		select procedure_id from splitter
	)
;
delete from icd10mappings i --remove dublicates // they exist?
where exists
	(
		select
		from icd10mappings x
		where
			(i.procedure_id, i.attribute_id) = (x.procedure_id, x.attribute_id) and
			(i.ctid) > (x.ctid)
	)
;
--replace Prosthesis with Synthetic bone graft for every procedure that mentiones bones and prostheses
update icd10mappings i
set
	(attribute_id, attribute_name) = (4104882, 'Synthetic bone graft')
where exists
	(
		select
		from icd10mappings x
		join ancestor_snomed a on
			a.ancestor_concept_id = 4154333	and --Bone structure
			a.descendant_concept_id = x.attribute_id and
			i.procedure_id = x.procedure_id
	) and
	attribute_id = 4205702 --Prosthesis
;
-- for testing purposes
-- delete from ICD10MAPPINGS
-- where not (procedure_code like '1%' or procedure_code like '0_V%' or procedure_code like '0_W%' or procedure_code like '0_X%' or procedure_code like '0_Y%')
-- where not (procedure_code like '6A930ZZ')
-- where not (procedure_code like '008Y4ZZ')-- or (procedure_code like 'D_Y%')
-- where not (procedure_code like '0_7%')
--*/
;
analyze ICD10MAPPINGS
;
drop table if exists method_whitelist cascade
;
create table method_whitelist as
-- create acceptable 'Has method' list for each procedure using mappings
-- include: methods and their ancestors AND methods as attributes and their ancestors
select distinct 
	i.procedure_id,
--	ca.ancestor_concept_id as method_id
	cr.concept_id_2 as method_id
from icd10mappings i
join snomed_relationship cr on-- procedures -> methods
	cr.relationship_id in ('Has method','Has revision status') and
	cr.concept_id_1 = i.attribute_id and
	i.concept_class_id = 'Procedure' and
	cr.invalid_reason is null
/*join ancestor_snomed ca on --methods -> parents
	ca.descendant_concept_id = concept_id_2*/

	UNION

select distinct
	i.procedure_id,
	ca.ancestor_concept_id as method_id
from icd10mappings i
join ancestor_snomed ca on --methods -> parents
	ca.descendant_concept_id = i.attribute_id
join ancestor_snomed x on --attribute is descendant of Action
	x.ancestor_concept_id = 4044908 and
	x.descendant_concept_id = i.attribute_id
;
create index idx_mw on method_whitelist (procedure_id, method_id)
;
ALTER TABLE method_whitelist ADD CONSTRAINT fpk_method_id FOREIGN KEY (method_id) REFERENCES concept (concept_id)
;
create statistics sts_mw (ndistinct) on procedure_id, method_id from method_whitelist
;
analyze method_whitelist
;
--device removals are unspecific removals by method only
delete from method_whitelist
where
	procedure_id in 
		(
			select procedure_id
			from icd10mappings
			where
				procedure_code like '0_P%' or
				procedure_code like '1_P%' or
				procedure_code like '2_5%'
		) and
	method_id != 4044524 --Removal - action
;
--Evaluation is not a good substitute for Imaging
delete from method_whitelist
where
	procedure_id in
		(
			select procedure_id
			from icd10mappings
			join ancestor_snomed on
				attribute_id = descendant_concept_id and
				ancestor_concept_id = 4180938 --Imaging
		) and
	method_id = 4044176 --Evaluation - action
;
--Surgical action is not a substitute for Brachytherapies
delete from method_whitelist
where
	procedure_id in
		(
			select procedure_id
			from icd10mappings
			where
				procedure_code like 'D%'
		) and
	method_id = 4045049 --Surgical action
;
--Dilations are equivalent to dilation repairs
insert into method_whitelist
select distinct
	m.procedure_id,
	4257977 --Dilation repair - action
from method_whitelist m
where
	m.method_id = 4044550 --Dilation - action
;
--Drainages are never removals
delete from method_whitelist
where
	procedure_id in
		(
			select procedure_id
			from icd10mappings
			where
				attribute_id = 4044517 --Drainage - action
		) and
	method_id = 4044524 --Removal - action
;
--Divisions can be Transections
insert into method_whitelist
select
	procedure_id,
	4138029	--Transection - action
from method_whitelist
where method_id	= 4044522 --Division - action
;
analyze method_whitelist
;
--if there is attribute that is child of 4014241 Structure of cardiovascular system, replace percutaneous approach w/ transluminal
update icd10mappings i
set
	(attribute_id, attribute_name) = (4127468,'Transluminal approach')
where 
	i.attribute_id = 4013298 and
	i.procedure_code not like '3%' and -- in administration should be injection instead
	exists
		(
			select
			from icd10mappings m
			join ancestor_snomed a on
				a.ancestor_concept_id =	4014241	and
				a.descendant_concept_id = m.attribute_id and
				i.procedure_id = m.procedure_id
		)
;
--if there is attribute that is child of 4046957 Gastrointestinal tract structure, replace 4232657 Vascular stent w/ 46273135 Intestinal stent
update icd10mappings i
set
	(attribute_id, attribute_name) = (46273135,'Intestinal stent')
where 
	i.attribute_id = 4232657 and
-- 	i.procedure_code not like '3%' and -- in administration should be injection instead
	exists
		(
			select
			from icd10mappings m
			join ancestor_snomed a on
				a.ancestor_concept_id =	4046957	and
				a.descendant_concept_id = m.attribute_id and
				i.procedure_id = m.procedure_id
		)
;
drop table if exists mappings cascade
;
create table mappings -- final resulting table, subject for manual checks
	(
		procedure_id int4,
		snomed_id int4,
		rel_id varchar (127),
		priority int4
	)
;
analyze icd10mappings
;
drop table if exists test_group cascade
-- this table will contain ALL possible ICD10 to SNOMED matches
-- exactly one match with procedure-attribute or it's descendant
-- at least one match on any other attribute or it's ancestor
;
create unlogged table test_group as

select distinct -- parents <3
	i.procedure_id, --icd10 proc
	a.descendant_concept_id as snomed_id, --snomed proc match candidate
	ra.ancestor_concept_id as match_on, --matching attribute id
	ra.min_levels_of_separation as ac, --how far up is the mapping of the attribute, lower number = more precise
	a.max_levels_of_separation as depth, --how far down is the mapping of the procedure, less specific is better (avoid adding detalisation)
	x.concept_class_id, -- to store if attribute is a device; important to determine travelling direction in hierarchy
	x.priority -- number to store corresponding attribute letter position in ICD10PCS code for later filtering
from icd10mappings i
join ancestor_snomed a on  --Include all procedure descendants
	i.concept_class_id = 'Procedure' and
	a.ancestor_concept_id = i.attribute_id
	--and substr (i.procedure_code,1,3) = '0R9' --uncomment to test on single code group, useful to check mappings
/*left join snomed_relationship cx on --method HAS to be specified for this iteration
	cx.concept_id_1 = i.attribute_id and
	cx.invalid_reason is null and
	substr (i.procedure_code,1,1) in ('0') and --surgical procedures
	cx.relationship_id = 'Has method' and
	cx.concept_id_2 != 4301351 --surgical procedure (generic)*/
join icd10mappings x on --place horizontally procedures and all other attributes
	x.procedure_id = i.procedure_id and
	x.concept_class_id != 'Procedure'
join ancestor_snomed ra on --include ancestors of all other attributes
	ra.descendant_concept_id = x.attribute_id and
	ra.max_levels_of_separation <=3 --limit set because of acceptability and RAM limits reasons
join snomed_relationship r on -- find matching pairs of procedures and attributes in SNOMED
	r.concept_id_1 = a.descendant_concept_id and
	r.concept_id_2 = ra.ancestor_concept_id and
	r.invalid_reason is null
;

--separate insert -- 5th level exceeds memory limit
insert into test_group
select distinct -- parents <3
	i.procedure_id, --icd10 proc
	a.descendant_concept_id as snomed_id, --snomed proc match candidate
	ra.ancestor_concept_id as match_on, --matching attribute id
	ra.min_levels_of_separation as ac, --how far up is the mapping of the attribute, lower number = more precise
	a.max_levels_of_separation as depth, --how far down is the mapping of the procedure, less specific is better (avoid adding detalisation)
	x.concept_class_id, -- to store if attribute is a device; important to determine travelling direction in hierarchy
	x.priority -- number to store corresponding attribute letter position in ICD10PCS code for later filtering
from icd10mappings i
join ancestor_snomed a on  --Include all procedure descendants
	i.concept_class_id = 'Procedure' and
	a.ancestor_concept_id = i.attribute_id
	--and substr (i.procedure_code,1,3) = '0R9' --uncomment to test on single code group, useful to check mappings
/*left join snomed_relationship cx on --method HAS to be specified for this iteration
	cx.concept_id_1 = i.attribute_id and
	cx.invalid_reason is null and
	substr (i.procedure_code,1,1) in ('0') and --surgical procedures
	cx.relationship_id = 'Has method' and
	cx.concept_id_2 != 4301351 --surgical procedure (generic)*/
join icd10mappings x on --place horizontally procedures and all other attributes
	x.procedure_id = i.procedure_id and
	x.concept_class_id != 'Procedure'
join ancestor_snomed ra on --include ancestors of all other attributes
	ra.descendant_concept_id = x.attribute_id and
	ra.max_levels_of_separation >3 --limit set because of acceptability and RAM limits reasons
join snomed_relationship r on -- find matching pairs of procedures and attributes in SNOMED
	r.concept_id_1 = a.descendant_concept_id and
	r.concept_id_2 = ra.ancestor_concept_id and
	r.invalid_reason is null
;

--separate insert for devices and biopsies: should be mapped down the hierarchy too.
insert into test_group
select distinct -- parents <3
	i.procedure_id, --icd10 proc
	a.descendant_concept_id as snomed_id, --snomed proc match candidate
	ra.descendant_concept_id as match_on, --matching attribute id
	ra.min_levels_of_separation as ac, --how far down is the mapping of the device, lower number = more precise;
	a.max_levels_of_separation as depth, --how far down is the mapping of the procedure, less specific is better (avoid adding detalisation)
	x.concept_class_id, -- to store if attribute is a body site; important to take in the account for topographic procedures
	x.priority -- to store other info for later filtering
from icd10mappings i
join ancestor_snomed a on  --Include all procedure descendants
	i.concept_class_id = 'Procedure' and
	a.ancestor_concept_id = i.attribute_id
join icd10mappings x on --place horizontally procedures and devices
	x.procedure_id = i.procedure_id and
	(
		x.concept_class_id = 'Physical Object' or --in ('Device', 'Qualifier Value')
		exists (select 1 from ancestor_snomed where x.attribute_id = descendant_concept_id and ancestor_concept_id = 4043842) --Biopsy - action
	)
join ancestor_snomed ra on --include descendants of devices
	ra.ancestor_concept_id = x.attribute_id --and
-- 	ra.max_levels_of_separation in (1,2) --limit set because of acceptability and RAM limits reasons
join snomed_relationship r on -- find matching pairs of procedures and attributes in SNOMED
	r.concept_id_1 = a.descendant_concept_id and
	r.concept_id_2 = ra.descendant_concept_id and
	r.invalid_reason is null
;
CREATE INDEX idx_test_group	ON test_group (procedure_id, snomed_id, match_on) 
;
create statistics sts_tg (ndistinct) on procedure_id, snomed_id from test_group
;
analyze test_group
;
-- explain
--We don't need 'has method' targets as nature of the procedure is already saved by procedure-attribute
--TODO: Unless method is extension of the procedure-attirbute (like Surgical removal + extirpation)
delete from test_group
where
exists
	(
		select 
		from ancestor_snomed
		where ancestor_concept_id in (4044908,4116366) and --Revision or Action
			match_on = descendant_concept_id
			
	) /*and
not exists
	(
		select
		from ancestor_snomed a
		join snomed_relationship r on
			r.concept_id_2 = a.ancestor_concept_id and
			a.min_levels_of_separation > 0
		join icd10mappings i on
			i.concept_class_id = 'Procedure' and
			i.attribute_id = r.concept_id_1 and
			match_on = descendant_concept_id
		join ancestor_snomed a2 on
			a2.ancestor_concept_id = 4044908 and
			match_on = a2.descendant_concept_id
		join ancestor_snomed a3 on
			a3.ancestor_concept_id = 4044908 and
			a.ancestor_concept_id = a3.descendant_concept_id
	)*/
;
analyze test_group
;
--resusciation can only be used for 5A2% (restoration)
delete from test_group
where
	procedure_id not in (select procedure_id from icd10mappings where procedure_code like '5A2%') and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4205502)
;
--match of ICD10PCS procedure with procedure-attribute is redundant and may lead to loss of precision
delete from test_group t
where
	t.snomed_id in
		(
			select i.attribute_id
			from icd10mappings i
			where
				t.procedure_id = i.procedure_id and
				t.concept_class_id = 'Procedure'
			limit 1 --faster; guaranteed to be unique by splitter
		)
;
--measurements in own chapter
delete from test_group t
where
	t.procedure_id not in (select procedure_id from icd10mappings where procedure_code like '4%') and
	t.snomed_id in (select concept_id_1 from snomed_relationship where concept_id_2 = 4044177) --Measurement - action
;
delete from test_group where procedure_id in (select procedure_id from icd10mappings where procedure_code like '4%') --SNOMED has terrible hierarchy and attributes for measurements
;
delete from test_group where procedure_id in (select procedure_id from icd10mappings where procedure_code like '0_W%') --SNOMED has terrible hierarchy and attributes for Revision 
;
--respect method_whitelist
delete from test_group t
where
	t.procedure_id in (select procedure_id from method_whitelist) and
	not exists
		(
			select
			from snomed_relationship x
			join method_whitelist m on
				t.snomed_id = x.concept_id_1 and
				m.method_id = x.concept_id_2 and
				t.procedure_id = m.procedure_id
		)
;
--for multiple hits for the same procedure on same attribute (faulty SNOMED hierarchy), keep only the deepest match
delete from test_group t
where exists
	(
		select
		from test_group x
		where
			(t.procedure_id, t.snomed_id, t.match_on) = (x.procedure_id, x.snomed_id, x.match_on) and
			x.ac < t.ac
	)
;
--for multiple hits for the same procedure on same attribute (faulty SNOMED hierarchy), keep only the deepest match
delete from test_group t
where exists
	(
		select
		from test_group x
		where
			(t.procedure_id, t.snomed_id, t.match_on) = (x.procedure_id, x.snomed_id, x.match_on) and
			t.priority < x.priority
	)
;/*
--surgeries should not be mapping targets only for procedures utilizing non-surgical methods
delete from test_group
where
	snomed_id in 
		(
			select concept_id_1
			from snomed_relationship
			join ancestor_snomed on
				descendant_concept_id = concept_id_2 and
				ancestor_concept_id = 4045049
		) and
	procedure_id not in
		(
			select procedure_id
			from icd10mappings
			join snomed_relationship on
				concept_class_id = 'Procedure' and
				attribute_id = concept_id_1
			join ancestor_snomed on
				descendant_concept_id = concept_id_2 and
				ancestor_concept_id = 4045049
		)
;*/
--Amputations should only be considered for Detachment '0_6%'
delete from test_group
where
	procedure_id not in (select procedure_id from icd10mappings where procedure_code like '0_6%') and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4217482) --Amputation
;
--introduction of drainage devices must not intersect with introduction of substance
delete from test_group
where
	procedure_id not in (select procedure_id from icd10mappings where procedure_code like '0_9%') and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4181192) --Introduction of substance by body site
;
--if access through natural/artificial opening is specified, we must exclude body cavity endoscope devices (thoracoscope, laparoscope etc) and percutaneous approach
delete from test_group
where
	snomed_id in 
		(
			select concept_id_1
			from snomed_relationship
			join ancestor_snomed on
				descendant_concept_id = concept_id_2 and
				ancestor_concept_id in
					(
						4210589, --Body cavity endoscope
						4013298	--Percutaneous approach
					)
		) and
	procedure_id in
		(
			select procedure_id
			from icd10mappings
			join atr_unil on procedure_code = concept_code
			where attr_name = 'Via Natural or Artificial Opening Endoscopic'
		)
;
--Intravenous contrast CT can only be assumed for imaging of venous structures 
delete from test_group
where
	procedure_id not in
		(
			select procedure_id
			from icd10mappings
			join ancestor_snomed on
				attribute_id = descendant_concept_id and
				ancestor_concept_id = 4003033 --Venous system structure
		) and
	snomed_id in
		(
			select descendant_concept_id
			from ancestor_snomed
			where
				ancestor_concept_id = 4013967 --CT with intravenous contrast
		)
;
--fix methods for Administration (only introductions)
drop table if exists false_introd
;
create unlogged table false_introd as
select distinct
	procedure_id,
	snomed_id
from test_group t where
	procedure_id in (select procedure_id from icd10mappings where procedure_code like '3%') and
	snomed_id in
		(
			select concept_id_1
			from snomed_relationship
			left join ancestor_snomed on
				descendant_concept_id = concept_id_2 and
				ancestor_concept_id in 
					(
						4044532, -- Introduction - action
						4287563	--Insufflation -- for gas
					)
			where
				relationship_id = 'Has method' and
				descendant_concept_id is null /*and
				not exists 
					(
						select from icd10mappings
						where
							t.procedure_id = procedure_id and
							concept_id_2 = attribute_id
					)*/
		)
;
delete from false_introd fi
where
	exists
		(
			select from icd10mappings i
			join snomed_relationship r on
				r.relationship_id = 'Has method' and
				i.attribute_id = r.concept_id_2 and
				r.concept_id_1 = fi.snomed_id and
				i.procedure_id = fi.procedure_id
		)
;
--no surgery in Imaging 'B%'
insert into false_introd
select distinct
	t.procedure_id,
	t.snomed_id
from test_group t
join icd10mappings i on
	t.procedure_id = i.procedure_id and
	i.procedure_code like 'B%'
join snomed_relationship sr on
	sr.concept_id_1 = t.snomed_id
join ancestor_snomed a on
	sr.concept_id_2 = a.descendant_concept_id and
	a.ancestor_concept_id in 
		(
			4045049 --surgical action
-- 			4044176	--Evaluation - action
		)
;
delete from test_group where (procedure_id, snomed_id) in (select procedure_id, snomed_id from false_introd)
;
--0_R% (Replacement) must not have DIRECT relation to Devices
-- delete from test_group
-- where
-- 	procedure_id in (select procedure_id from icd10mappings where procedure_code like '0_R%') and
-- 	snomed_id in (select concept_id_1 from snomed_relationship where relationship_id = 'Has dir device')
;
--0_R% (Replacement) must not include Removal of devices or substances
delete from test_group
where
	procedure_id in (select procedure_id from icd10mappings where procedure_code like '0_R%') and
	snomed_id in
		(
			select descendant_concept_id
			from ancestor_snomed
			where ancestor_concept_id in (4180032)	-- Removal of object
		)
;
--only obstetric procedures '1%' should be mapped to descendants of 4302541 Obstetric procedure
delete from test_group
where
	procedure_id not in 
		(
			select procedure_id
			from icd10mappings 
			left join ancestor_snomed on
				ancestor_concept_id in
					(
						4097520,	--Structure of product of conception
						4241775	--Gravid uterus structure
					) and
				descendant_concept_id = attribute_id
			where procedure_code like '1%'
			
		) and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4302541)
;
analyze test_group
;
--only procedures with 'Diagnostic' attribute should refer to 4129646 Diagnostic intent
with dia_snm as
	(
		select concept_id_1
		from snomed_relationship
		where concept_id_2 = 4129646 --Diagnostic intent
	),
--likewise, no diagnostic procedure can have 4133895 Therapeutic intent
ther_snm as
	(
		select concept_id_1
		from snomed_relationship 
		where concept_id_2 = 4133895 --Therapeutic intent
	)
delete from test_group
where 
	(
		procedure_id not in 
			(
				select procedure_id from icd10mappings where attribute_id in (4311405,4129646)
				
					union all
					
				select procedure_id from icd10mappings where attribute_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4297090) --Evaluation
			) and snomed_id in (select concept_id_1 from dia_snm)
	) or
	(procedure_id in (select procedure_id from icd10mappings where attribute_id = 4129646) and snomed_id in (select concept_id_1 from ther_snm))
;
--disallow Open procedures to have Percutaneous approach and vice versa
with pct_snm as
	(
		select concept_id_1
		from snomed_relationship
		where concept_id_2 in (4013298,4127468) --Percutaneous, Transluminal
	)
delete from test_group
where
	(procedure_id in (select procedure_id from icd10mappings where attribute_id = 4044378) and snomed_id in (select concept_id_1 from pct_snm))
;
--disallow Open procedures to have Percutaneous approach and vice versa
with open_snm as
	(
		select concept_id_1
		from snomed_relationship
		where concept_id_2 = 4044378 --Open approach
	)
delete from test_group
where
	(procedure_id in (select procedure_id from icd10mappings where attribute_id in (4013298,4127468)) and snomed_id in (select concept_id_1 from open_snm))
;
analyze test_group
;
--similarly, endoscopy must be specified. Open can't be endoscopic
with end_snm as
	(
		select concept_id_1
		from snomed_relationship
		join concept_ancestor on
			ancestor_concept_id = 4290594 and --endoscope
			descendant_concept_id = concept_id_2
	),
open_snm as
	(
		select concept_id_1
		from snomed_relationship
		where concept_id_2 = 4044378 --Open approach
	)
delete from test_group
where
	(procedure_id in (select procedure_id from icd10mappings where attribute_id = 4290594) and snomed_id in (select concept_id_1 from open_snm)) or
	(procedure_id not in (select procedure_id from icd10mappings where attribute_id = 4290594) and snomed_id in (select concept_id_1 from end_snm))
;
analyze test_group
;
--procedures with 4044524 Removal - action should only be for procedures that have core 4134423 Removal of device or 4134598 Surgical removal or 4027561 Surgical extraction
delete from test_group
where
	snomed_id in (select concept_id_1 from snomed_relationship where concept_id_2 = 4044524) and
	procedure_id in 
		(
			select
				coalesce (s.procedure_id, i.procedure_id)
			from icd10mappings i
			left join splitter s on
				s.replaced_id = i.procedure_id
			where i.procedure_id in (4134423,4134598,4027561)
		)
;
--Catheterization should not be counted as primary target for Dilations
delete from test_group t
where
	procedure_id in (select procedure_id from icd10mappings where procedure_code like '0_7%') and --Dilation
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4164278) --Catheterization
;
--remove reattachments/closures/dilations from Repair
--remove prostheses, vascular grafts from Repair
--remove children of methodless procedures, like 'shunt procedure'
delete from test_group
where
	snomed_id in
		(
			select concept_id_1 from snomed_relationship where concept_id_2 in (4044539,4044539,4081507,4044550,4257977,4045074,4126220,4174131) --reattachment, closure, closure method, Dilation - action, Dilation repair, Stabilization, resurf., refashioning
			
				union all
				
			select concept_id_1
			from snomed_relationship
			join concept_ancestor on
				ancestor_concept_id in (4205702,4105060,4124754,4142191,4223622) and --prostheses, Cardiovascular material, graft, vascular device, implant and children
				descendant_concept_id = concept_id_2
				
				union all
			
			select descendant_concept_id
			from ancestor_snomed
			where ancestor_concept_id in (4090313,4031047) --shunt into peritoneum, fixation
		) and
	procedure_id in 
		(
			select procedure_id from icd10mappings where substr (procedure_code,1,1) = '0' and substr (procedure_code,3,1) = 'Q' and procedure_code not in ('0WQ6XZ2','0WQFXZ2')
		)
;
--Resections are removals of entire organs and can't refer to 40599742 Lesion
/* proof:
select * 
from concept p
join concept_ancestor ca on
	ca.descendant_concept_id = p.concept_id and
	
	p.standard_concept = 'S' and
	p.vocabulary_id = 'SNOMED' and
	p.concept_class_id = 'Procedure' and
	
	ca.ancestor_concept_id = 4279903
join concept_relationship r1 on
	r1.concept_id_1 = p.concept_id and
	r1.invalid_reason is null
join concept a1 on
	a1.concept_id = r1.concept_id_2 and
	a1.vocabulary_id = 'SNOMED' and
	a1.concept_class_id = 'Body Structure' and
	a1.standard_concept = 'S'
join concept_ancestor ca2 on
	ca2.descendant_concept_id = a1.concept_id and
	ca2.ancestor_concept_id = 4179858
	
join concept_ancestor cp2 on
	cp2.descendant_concept_id = p.concept_id
join concept_relationship r2 on
	cp2.ancestor_concept_id = r2.concept_id_1 and
	r2.concept_id_2 = 40599742 
	
 	and cp2.min_levels_of_separation < ca.min_levels_of_separation
*/
delete from test_group
where
	snomed_id in (select concept_id_1 from snomed_relationship where concept_id_2 = 40599742) and
	procedure_id in 
	(
		select concept_id from concept_stage where vocabulary_id = 'ICD10PCS' and substr (concept_code,1,1) = '0' and substr (concept_code,3,1) = 'T'
			union all
		select replaced_id from concept_stage join splitter on procedure_id = concept_id where vocabulary_id = 'ICD10PCS' and substr (concept_code,1,1) = '0' and substr (concept_code,3,1) = 'T'
	)
;
analyze test_group
;
drop table if exists no_morph_allowed cascade
;
--procedures that specify abnormal morphology (except for 40599742 Lesion) cant be normally present in ICD10PCS
create unlogged table no_morph_allowed as
select t.procedure_id, t.snomed_id, cr.concept_id_2
from test_group t
join snomed_relationship cr on
	t.snomed_id = cr.concept_id_1 and
	cr.relationship_id in ('Has proc morph','Has dir morph','Has asso morph','Has indir morph') and
	cr.concept_id_2 != 40599742 and -- generic 'lesion'
	cr.invalid_reason is null
;
--allow procedures with matching specified morphologies
delete from no_morph_allowed n
where
	n.concept_id_2 in
	(
		select a.descendant_concept_id 
		from icd10mappings i
		join ancestor_snomed a on
			n.procedure_id = i.procedure_id and
			i.concept_class_id = 'Morph Abnormality' and
			a.ancestor_concept_id = i.attribute_id
			
	)
;
create index idx_no_morph_allowed on no_morph_allowed (procedure_id, snomed_id)
;
analyze no_morph_allowed
;
delete from test_group
where
	(procedure_id, snomed_id) in
	(
		select procedure_id, snomed_id
		from no_morph_allowed
	)
;
analyze test_group
;
drop table if exists body_attr cascade
;
create table body_attr as -- all allowed body parts for ICD10Procedures
select distinct
	i.procedure_id,
	ca.ancestor_concept_id as bp_id	
from icd10mappings i
join ancestor_snomed ca on
	i.concept_class_id = 'Body Structure' and
	ca.descendant_concept_id = i.attribute_id

/*	union
	
select distinct
	i.procedure_id,
	ca.descendant_concept_id as bp_id	
from icd10mappings i
join ancestor_snomed ca on
	i.concept_class_id = 'Body Structure' and
	ca.ancestor_concept_id = i.attribute_id and
	ca.min_levels_of_separation > 0*/
;
create index idx_bp on body_attr (procedure_id, bp_id)
;
analyze body_attr
;
drop table if exists body_precis
;
create unlogged table body_precis as
select distinct
	t.procedure_id,
	t.snomed_id
from test_group	t

join snomed_relationship cr on --body structures in SNOMED procedures
	cr.invalid_reason is null and
	t.snomed_id = cr.concept_id_1
join relations r on
	r.relationship_id = cr.relationship_id
join concept c2 on
	c2.concept_id = cr.concept_id_2 and
	c2.vocabulary_id = 'SNOMED' and
	c2.concept_class_id = 'Body Structure'

left join body_attr b on
	t.procedure_id = b.procedure_id and
	c2.concept_id = b.bp_id
	
join icd10mappings m on
	m.procedure_code like '0%' and
	m.procedure_id = t.procedure_id

where b.procedure_id is null
;
CREATE INDEX idx_body_precis ON body_precis (procedure_id, snomed_id) 
;
analyze body_precis
;
create unlogged table test_group1 as
select t.*
from test_group t
left join body_precis a on
	t.procedure_id = a.procedure_id and
	t.snomed_id = a.snomed_id
where a.procedure_id is null
;
drop table if exists body_precis cascade
;
drop table if exists test_group cascade
;
alter table test_group1 rename to test_group
;
CREATE INDEX idx_test_group ON test_group (snomed_id, procedure_id) 
;
CREATE INDEX idx_test_group1 ON test_group (snomed_id) 
;
CREATE INDEX idx_test_group2 ON test_group (procedure_id) 
;
analyze test_group
;
drop table if exists removal_id cascade
;
--SNOMED 'replacements' are both 'removals' and 'placements', so we ensure that no separate 'insertion' or 'removal' in ICD10PCS will get coded as 'replacement'
create unlogged table removal_id as--for removals, that should not be insertions
	(
		select i.procedure_id
		from icd10mappings i
		where
			(--removal surgical; code pattern 0.P....
				substr (i.procedure_code,1,1) = '0' and
				substr (i.procedure_code,3,1) in ('P','B','T','C')
			)
			or
			(--removal of device; code pattern 2.5....
				substr (i.procedure_code,1,1) = '2' and
				substr (i.procedure_code,3,1) = '5'
			)
-- 			or
-- 			(--Repair; code pattern 0.Q.... -- grafts/implants belong in other chapter
-- 				substr (i.procedure_code,1,1) = '0' and
-- 				substr (i.procedure_code,3,1) = 'Q'
-- 			)
-- 			or
-- 			substr (i.procedure_code,1,1) = 'B' --whole imaging chapter. eliminates whole angiographic stent insertion stuff while we are at it
	)
;
delete from test_group t
where
	procedure_id in (select procedure_id from removal_id) and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id in (4027403,4132647,4185115)) --introduction, construction, repair
;
delete from test_group t
where
	procedure_id in (select procedure_id from removal_id) and
	snomed_id in (select concept_id_1 from snomed_relationship join ancestor_snomed on descendant_concept_id = concept_id_2 and ancestor_concept_id in (4175951)) --Morph abnormality
;
drop table if exists removal_id cascade
;/*
delete from test_group t where --don't mix removal of device and surgical removal
	exists 
		(
			select 1 
			from icd10mappings i where
				i.procedure_id = t.procedure_id and
					(
						(
							substr (i.procedure_code,1,1) = '0' and
							substr (i.procedure_code,3,1) in ('P','B','T','C')
						) or
						(
							substr (i.procedure_code,1,3) in ('109','10T','10D','10P','10A')
						) or
						(
							i.procedure_code like '8C0__6%'
						)
					)
		) and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id in (4134423)) --removal of device*/
;
create unlogged table insertion_id as -- for insertions
	(
		select i.procedure_id
		from icd10mappings i
		where
			(--insertion surgical; pattern 0.H.... or 1.H....
				substr (i.procedure_code,1,1) in ('0','1') and
				substr (i.procedure_code,3,1) = 'H'
			)
	)
;
delete from test_group
where
	procedure_id in (select * from insertion_id) and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id in (4042150,4300185,4000731)) --removal, transplantation, grafting
;
drop table if exists insertion_id cascade
;
drop table if exists radio_id cascade
;
create unlogged table radio_id as -- delete brachytherapy from surgical destruction -- has its own chapter
	(
		select i.procedure_id
		from icd10mappings i
		where
			(--destruction surgical; pattern 0.5....
				substr (i.procedure_code,1,1) = '0' and
				substr (i.procedure_code,3,1) = '5'
			)
	)
;
delete from test_group
where
	procedure_id in (select procedure_id from radio_id) and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id in (4029715,4180941)) --radiotherapy, procedures with specified devices
;
delete from test_group where
	procedure_id in (select procedure_id from radio_id) and
	snomed_id in (select concept_id_1 from snomed_relationship where concept_id_2 = 4133890 and invalid_reason is null) --stereotactic surgery belongs in other chapter
;
drop table if exists radio_id cascade
;
delete from test_group where --Stereotactic Radiosurgery children should only appear for D02* codes 
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4215577) and
	not exists
		(
			select from icd10mappings
			where procedure_id = test_group.procedure_id and
			substr (procedure_code,1,3) = 'D02'
		)
	
;
--also stereotactic, not mentioned in attr
delete from test_group t
where
	exists
		(
			select
			from ancestor_snomed a
			where
				a.descendant_concept_id = t.snomed_id and
				a.ancestor_concept_id = 4215577
		)
	and procedure_id not in (2791307,2791308,2791309,2791310,2791311,2791312,2791313,2791314,2791315,2791316,2791317,2791318,4063662)
;
delete from test_group t --removal is not a proper method substitute for drainages and excisions/resections
where
	procedure_id in 
	(
		select procedure_id
		from icd10mappings
		join ancestor_snomed a on 
			attribute_id = descendant_concept_id and
			concept_class_id = 'Procedure'
		where 
			(ancestor_concept_id = 4046266) or --Drainage
			procedure_code like '0_B%' or
			procedure_code like '0_T%'
	) and
	snomed_id in (select concept_id_1 from snomed_relationship where concept_id_2 = 4044524 and relationship_id = 'Has method') --Removal - action
;
analyze test_group
;
--only procedures with attributes of of 4291637 Split thickness skin graft & 4324976 Full thickness skin graft can have their children as mapping
delete from test_group t
where
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4291637) and
	not exists
		(
			select
			from icd10mappings
			where t.procedure_id = procedure_id and attribute_id = 4291637
		)
;
delete from test_group t
where
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4324976) and
	not exists
		(
			select
			from icd10mappings
			where t.procedure_id = procedure_id and attribute_id = 4324976
		)
;
--if following attributes (descendants) are not specified in ICD10PCS, but present in SNOMED, exclude those matches
drop table if exists attribute_groups;
create unlogged table attribute_groups as
	(
		select descendant_concept_id
		from ancestor_snomed
		where 
			ancestor_concept_id in
				(
					4272314,	--Biomedical Device
					4125334,	--Biomedical equipment
					4019381,	--Biological substance
					4137142,	--Body fluid
-- 					4060422,	--Catheter
-- 					4237304,	--Instrument
					4044182,	--Incision - action
					4240671,	--Anatomical structure
					40480953,	--Chemical
					4190927,	--Diagnostic Substance
					4236076,	--Apheresesis
					4136419,	--Coronary artery graft
-- 					4230986,	--Imaging - action -- to ensure that imaging methods will be precise (e.g. fluoroscopy won't get mapped as CT)
					4254051,	--Drug or medicament
					4122668,	--Arteriovenous graft material
					4220780,	--Skin flap
					4117491,	--Anastomosis - action
					4307814,	--Anterior approach
					4011082,	--Posterior approach
-- 					4261266,	--Drug-device combination product
					4029811,	--Baffle
					4048506,	--Specimen
					4193315,	--Substance categorized functionally
					45767774,	--Disability-assistive device
					4170072,	--Metal device
-- 					4231016,	--Monitoring - action
					4106470,	--Insertion - action
					4044176,	--Evaluation - action
					4195036,	--Desensitization - action
					4044552,	--Fitting - action
					4044379,	--Closed approach
					4044186,	--Surgical removal - action
					35624141,	--Substance categorized by disposition
					4045089,	--Iontophoresis - action
					4220084,	--Radiation
					4014165,	--Procedural approach
					4123769,	--Personal effects and clothing
					4169265,	--Device
					4044176,	--Evaluation - action
					4324450,	--Guidance intent
					4044378,	--Open approach
					4208339,	--Donor graft
					4105047,	--Fetal and embryonic material
					4240422,	--Body substance
					4259632	--Organism
				)
	)
;
-- create index idx_atrgr on attribute_groups (ancestor_concept_id, descendant_concept_id);
-- create index idx_atrgr1 on attribute_groups (ancestor_concept_id);
create index idx_atrgr2 on attribute_groups (descendant_concept_id);
;
analyze attribute_groups
;
drop table if exists pair_w_snomed_a cascade
;
create unlogged table pair_w_snomed_a as --suspicion
	(
		select distinct
			t.procedure_id,
			t.snomed_id,
			concept_id_2
		from test_group t
		join snomed_relationship on
			concept_id_1 = snomed_id
		join attribute_groups on
			concept_id_2 = descendant_concept_id
-- 		left join method_whitelist m on --allow for methods of core procedures
-- 			m.method_id = concept_id_2 and
-- 			m.procedure_id = t.procedure_id
		left join ancestor_snomed m on
			m.descendant_concept_id = concept_id_2 and
			m.ancestor_concept_id = 4044908 --Action; these should be ffiltered in other part of the script, here unnecessary strict
-- 		where m.procedure_id is null
		where m.descendant_concept_id is null
	)
;
create index idx_snm_atr on pair_w_snomed_a (procedure_id, snomed_id);
create index idx_snm_atr2 on pair_w_snomed_a (procedure_id, concept_id_2);
;
analyze pair_w_snomed_a
;
-- explain
delete from pair_w_snomed_a p --clear suspicion when i10p has attribute. or ancestor
where
	exists
		(
			select
			from icd10mappings i
			join ancestor_snomed a on
				a.descendant_concept_id = i.attribute_id and
				i.procedure_id = p.procedure_id and
				a.ancestor_concept_id = p.concept_id_2
		)
;
analyze pair_w_snomed_a
;
--should we allow descendants too?
;
delete from test_group
where
	(procedure_id, snomed_id) in
	(
		select procedure_id, snomed_id from pair_w_snomed_a
	)
;
--GI endoscopes can only be used w/ procedures on GIT
delete from test_group t
where
	exists --snomed uses git endoscope
		(
			select
			from snomed_relationship r
			join ancestor_snomed x on
				r.concept_id_1 = t.snomed_id and
				r.concept_id_2 = x.descendant_concept_id and
				x.ancestor_concept_id = 4207031 -- Digestive endoscope
		) and
	not exists --icd10pcs does not have a git body structure
		(
			select
			from icd10mappings i
			join ancestor_snomed a on
				i.procedure_id = t.procedure_id and
				i.attribute_id = a.descendant_concept_id and
				a.ancestor_concept_id = 4314892 --Structure of digestive system
		)
;
--urinary endoscopes should only be used for procedures through Artficial or Natural Opening
delete from test_group
where
	snomed_id in 
		(
			select concept_id_1
			from snomed_relationship
			join ancestor_snomed on
				descendant_concept_id = concept_id_2 and
				ancestor_concept_id = 4208651 --Urinary endoscope
		) and
	procedure_id not in
		(
			select procedure_id
			from icd10mappings
			join atr_unil on procedure_code = concept_code
			where attr_name = 'Via Natural or Artificial Opening Endoscopic'
		)
;
--reattachment is only in its own branch
delete from test_group t
where
	procedure_id not in (select procedure_id from icd10mappings where procedure_code like '0_M%') and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4161186)
;
drop table if exists maxfix cascade 
;
create unlogged table maxfix
	(
		procedure_id int4,
		snomed_id int4
	)
;
drop table if exists minfix cascade 
;
create unlogged table minfix
	(
		procedure_id int4,
		snomed_id int4
	)
;
CREATE INDEX idx_minfix
	ON minfix (procedure_id, snomed_id)
;
drop table if exists pinpoint cascade 
;
create unlogged table pinpoint as
select * from test_group
where false
;
CREATE INDEX idx_pinpoint
	ON pinpoint (procedure_id, snomed_id)
;
drop table if exists test_group4
;
create unlogged table test_group4 as
select * from test_group
where false
;
CREATE INDEX idx_test_group4
	ON test_group4 (procedure_id, snomed_id, match_on)
;
drop table if exists group_mid cascade
;
create unlogged table group_mid as
select * from test_group
where false
;
create INDEX idx_group_mid ON group_mid (procedure_id, snomed_id, ac)
;
drop table if exists group_finalised
;
create unlogged table group_finalised as
select
	t.procedure_id,
	t.snomed_id,
	t.depth,
	t.priority,
	t.ac
from test_group t
where false
;
create INDEX idx_group_finalised ON group_finalised (procedure_id, snomed_id)
;
drop table if exists mindeep cascade
;
create unlogged table mindeep as 
	(
		select procedure_id, depth
		from test_group
		where false
	)
;
create INDEX idx_mindeep ON mindeep (procedure_id)
;
--utilize function to better control cycles
create or replace function fill_mapping
	(
		check_priority int4,
		debug_value int4,
		use_maxfix boolean default true
	)
returns void
language plpgsql
as
$body$
begin
	truncate test_group4
	;
	insert into test_group4
	select distinct * 
	from test_group
	where 
		(procedure_id, snomed_id) in (select procedure_id, snomed_id from test_group where priority = check_priority)
	;
	analyze test_group4
	;
	truncate maxfix
	; 
	insert into maxfix --we keep only matches with the highest number of matched attributes
		with x as
			(
				select distinct  -- count number of matched attributes for every match pair
					procedure_id,
					snomed_id,
					count (match_on) as c
				from test_group4
				where use_maxfix
				group by procedure_id,snomed_id
			),
		maxim as
			(
				select distinct procedure_id, max(c) as m  --define highest number for every ICD10PCS procedure
				from x
				group by procedure_id
			)
		select x.procedure_id,x.snomed_id from x
		join maxim ma on
			ma.m > x.c and
			ma.procedure_id = x.procedure_id
	;
	analyze maxfix
	;
	truncate group_mid
	;
	insert into group_mid --remove those with less matches
	select t.* from test_group4 t
		left join maxfix m on
		m.procedure_id = t.procedure_id and
		m.snomed_id = t.snomed_id
	where m.procedure_id is null
	;
	analyze group_mid
	;
	truncate pinpoint
	;
	insert into pinpoint --find procedures with the smallest hierarchical distance on defining attribute in this iteration; more important than sum of distances, but less often useful
	with minac as
		(
			select distinct procedure_id, min (ac) over (partition by procedure_id) as ac
			from group_mid
			where priority = check_priority
		)
	select distinct g.*
	from group_mid g
	join minac m on
		m.procedure_id = g.procedure_id and
		g.priority = check_priority and
		m.ac = g.ac
	;
	analyze pinpoint
	;
	truncate minfix
	;
	insert into minfix --attempt to find closest matches by demanding lowest possible sum of distances between all attributes in matching pairs
		with x as
			(
				select  -- find sum of distances for every match pair
					g.procedure_id,
					g.snomed_id,
					sum (g.ac)
						over (partition by g.procedure_id, g.snomed_id) as c
				from pinpoint g
			),
		minim as --find lowest possible sum for every ICD10PCS procedure
			(
				select distinct procedure_id, min(c) as m
				from x
				group by procedure_id
			)
		select x.procedure_id,x.snomed_id from x -- create a list of all pairs that have higher sum
		join minim mi on
			mi.m < x.c and
			mi.procedure_id = x.procedure_id
	;
	analyze minfix
	;
	truncate group_finalised
	;
	insert into group_finalised -- recreate table without pairs with higher sums
		(
			select distinct
				t.procedure_id,
				t.snomed_id,
				t.depth,
				debug_value as priority,
				sum (ac)
					over (partition by t.procedure_id, t.snomed_id) as missed
			from pinpoint t
			left join minfix m on
				m.procedure_id = t.procedure_id and
				m.snomed_id = t.snomed_id
			where m.procedure_id is null
		)
	;
	analyze group_finalised
	;
	insert into mindeep -- among all remaining matches, keep the most generic procedure (highest ancestor in procedure tree); table stores minimaly possible level of depth among all matches
			(
				select distinct procedure_id, min(depth) as m
				from group_finalised
				group by procedure_id
			)
	;
	analyze mindeep
	;
	insert into mappings
	select distinct
		g.procedure_id,
		g.snomed_id,
		'Is a',
		g.priority
	from group_finalised g
	join mindeep m on
		g.procedure_id = m.procedure_id and
		g.depth = m.depth
	;
end;
$body$
volatile
cost 1000
;
-- explain
with proc_prio as
	(
		select distinct priority
		from test_group
-- 		limit 1000
	)
select fill_mapping (priority, priority, true)
from proc_prio
;
--clear conflicts on methods -- or if methods are not allowed
delete from test_group t
where
	not exists
		(
			select
			from snomed_relationship r
			join method_whitelist m on
				r.concept_id_1 = t.snomed_id and
				r.concept_id_2 = m.method_id and
				t.procedure_id = m.procedure_id
		)
;
with proc_prio as
	(
		select distinct priority
		from test_group
-- 		limit 1000
	)
select fill_mapping (priority, priority+100, false)
from proc_prio
;
CREATE INDEX idx_MAPPINGS ON MAPPINGS (PROCEDURE_ID, SNOMED_ID, PRIORITY) 
;
analyze MAPPINGS
;
insert into method_whitelist
select distinct --surgery, where no other specified
	i.procedure_id,
	4045049 as method_id
from icd10mappings i
--left join method_whitelist w using (procedure_id)
where
--	w.procedure_id is null and
	substr (i.procedure_code,1,1) in ('0','1','B') --only surgical procedures & imaging
;
drop table if exists test_group cascade
;
-- Now we do the same, but with Procedure parent instead of procedure-attributes
-- This way we try to preserve attributes not included in previous iteration, having ICD10PCS procedures being children to possibly generic "procedure referring to attribute"
-- FULL ANTI JOIN
create unlogged table test_group as	
select distinct -- parents <3
	i.procedure_id, --icd10 proc
	a.descendant_concept_id as snomed_id, --snomed proc match candidate
	ra.ancestor_concept_id as match_on, --matching attribute id
	ra.min_levels_of_separation as ac, --how far up is the mapping of the attribute, lower number = more precise
	a.max_levels_of_separation as depth, --how far down is the mapping of the procedure, less specific is better (avoid adding detalisation)
	i.concept_class_id, -- to store if attribute is a device; important to determine travelling direction in hierarchy
	i.priority -- number to store corresponding attribute letter position in ICD10PCS code for later filtering
from icd10mappings i
join ancestor_snomed ra on --include ancestors of all other attributes
	ra.descendant_concept_id = i.attribute_id and
	i.concept_class_id != 'Procedure' and
	ra.max_levels_of_separation <=3 --limit set because of acceptability and RAM limits reasons
join snomed_relationship r on -- find matching pairs of procedures and attributes in SNOMED
	r.concept_id_2 = ra.ancestor_concept_id and
	r.invalid_reason is null
join ancestor_snomed a on --Get all SP procedure descendants
	r.concept_id_1 = a.descendant_concept_id and
	a.ancestor_concept_id = 4322976 -- Procedure
--only include generic procedures without specified METHOD (except for general 'Surgery')
left join snomed_relationship cf on
	cf.concept_id_1 = a.descendant_concept_id and
	cf.relationship_id in ('Has method','Has revision status') and
	cf.invalid_reason is null
where cf.concept_id_1 is null
;
insert into test_group
select distinct -- parents >3
	i.procedure_id, --icd10 proc
	a.descendant_concept_id as snomed_id, --snomed proc match candidate
	ra.ancestor_concept_id as match_on, --matching attribute id
	ra.min_levels_of_separation as ac, --how far up is the mapping of the attribute, lower number = more precise
	a.max_levels_of_separation as depth, --how far down is the mapping of the procedure, less specific is better (avoid adding detalisation)
	i.concept_class_id, -- to store if attribute is a device; important to determine travelling direction in hierarchy
	i.priority -- number to store corresponding attribute letter position in ICD10PCS code for later filtering
from icd10mappings i
join ancestor_snomed ra on --include ancestors of all other attributes
	ra.descendant_concept_id = i.attribute_id and
	i.concept_class_id != 'Procedure' and
	ra.max_levels_of_separation > 3
join snomed_relationship r on -- find matching pairs of procedures and attributes in SNOMED
	r.concept_id_2 = ra.ancestor_concept_id and
	r.invalid_reason is null
join ancestor_snomed a on --Get all SP procedure descendants
	r.concept_id_1 = a.descendant_concept_id and
	a.ancestor_concept_id = 4322976 -- Procedure
--only include generic procedures without specified METHOD (except for general 'Surgery')
left join snomed_relationship cf on
	cf.concept_id_1 = a.descendant_concept_id and
	cf.relationship_id in ('Has method','Has revision status') and
	cf.invalid_reason is null
where cf.concept_id_1 is null
;
-- FULL INNER JOIN

-- explain-- analyze verbose
insert into test_group	
select distinct -- parents <3
	i.procedure_id, --icd10 proc
	ax.concept_id as snomed_id, --snomed proc match candidate
	ra.ancestor_concept_id as match_on, --matching attribute id
	ra.min_levels_of_separation as ac, --how far up is the mapping of the attribute, lower number = more precise
	a.max_levels_of_separation as depth, --how far down is the mapping of the procedure, less specific is better (avoid adding detalisation)
	i.concept_class_id, -- to store if attribute is a device; important to determine travelling direction in hierarchy
	i.priority -- number to store corresponding attribute letter position in ICD10PCS code for later filtering
from icd10mappings i
join ancestor_snomed ra on --include ancestors of all other attributes
	ra.descendant_concept_id = i.attribute_id and
	i.concept_class_id != 'Procedure' and
	ra.max_levels_of_separation <=3 --limit set because of acceptability and RAM limits reasons
join concept tc on
	tc.concept_id = ra.ancestor_concept_id
join snomed_relationship r on -- find matching pairs of procedures and attributes in SNOMED
	r.concept_id_2 = tc.concept_id
join concept ax on
	ax.concept_class_id = 'Procedure' and
	ax.concept_id = r.concept_id_1
join ancestor_snomed a on --Get all SP procedure descendants
	ax.concept_id = a.descendant_concept_id and
	a.ancestor_concept_id = 4322976 -- Procedure
--only include generic procedures with specified methods in whitelist
join snomed_relationship cf on
	cf.concept_id_1 = ax.concept_id and
	cf.relationship_id in ('Has method','Has revision status')
join concept ct on
	ct.concept_id = cf.concept_id_2
join method_whitelist w on
	ct.concept_id = w.method_id and
	w.procedure_id = i.procedure_id
;
insert into test_group
select distinct -- parents >3
	i.procedure_id, --icd10 proc
	ax.concept_id as snomed_id, --snomed proc match candidate
	ra.ancestor_concept_id as match_on, --matching attribute id
	ra.min_levels_of_separation as ac, --how far up is the mapping of the attribute, lower number = more precise
	a.max_levels_of_separation as depth, --how far down is the mapping of the procedure, less specific is better (avoid adding detalisation)
	i.concept_class_id, -- to store if attribute is a device; important to determine travelling direction in hierarchy
	i.priority -- number to store corresponding attribute letter position in ICD10PCS code for later filtering
from icd10mappings i
join ancestor_snomed ra on --include ancestors of all other attributes
	ra.descendant_concept_id = i.attribute_id and
	i.concept_class_id != 'Procedure' and
	ra.max_levels_of_separation > 3
join concept tc on
	tc.concept_id = ra.ancestor_concept_id
join snomed_relationship r on -- find matching pairs of procedures and attributes in SNOMED
	r.concept_id_2 = tc.concept_id
join concept ax on
	ax.concept_class_id = 'Procedure' and
	ax.concept_id = r.concept_id_1
join ancestor_snomed a on --Get all SP procedure descendants
	ax.concept_id = a.descendant_concept_id and
	a.ancestor_concept_id = 4322976 -- Procedure
--only include generic procedures with specified methods in whitelist
join snomed_relationship cf on
	cf.concept_id_1 = ax.concept_id and
	cf.relationship_id in ('Has method','Has revision status')
join concept ct on
	ct.concept_id = cf.concept_id_2
join method_whitelist w on
	ct.concept_id = w.method_id and
	w.procedure_id = i.procedure_id
;
CREATE INDEX idx_test_group ON test_group (procedure_id, snomed_id, match_on)
;
analyze test_group;
;
--'Map' in CNS has too generic attributes, has mess in this part of script
delete from test_group
where procedure_id in (select procedure_id from icd10mappings where procedure_code like '00K%')
;
--match of ICD10PCS procedure with procedure-attribute is redundant and may lead to loss of precision
delete from test_group t
where
	t.snomed_id in
		(
			select i.attribute_id
			from icd10mappings i
			where
				t.procedure_id = i.procedure_id and
				t.concept_class_id = 'Procedure'
			limit 1 --faster; guaranteed to be unique by splitter
		)
;
--resusciation can only be used for 5A2% (restoration)
delete from test_group
where
	procedure_id not in (select procedure_id from icd10mappings where procedure_code like '5A2%') and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4205502)
;
--measurements in own chapter
delete from test_group t
where
	t.procedure_id not in (select procedure_id from icd10mappings where procedure_code like '4%') and
	t.snomed_id in (select concept_id_1 from snomed_relationship where concept_id_2 = 4044177) --Measurement - action
;
delete from test_group where procedure_id in (select procedure_id from icd10mappings where procedure_code like '4%') --SNOMED has terrible hierarchy and attributes for measurements
;
delete from test_group where procedure_id in (select procedure_id from icd10mappings where procedure_code like '0_W%') --SNOMED has terrible hierarchy and attributes for Revisions
;
--separate from first iteration
delete from test_group
where (procedure_id, snomed_id) in (select procedure_id, snomed_id from mappings)
;
analyze test_group
;
--for multiple hits for the same procedure on same attribute (faulty SNOMED hierarchy), keep only the deepest match
delete from test_group t
where exists
	(
		select
		from test_group x
		where
			(t.procedure_id, t.snomed_id, t.match_on) = (x.procedure_id, x.snomed_id, x.match_on) and
			x.ac < t.ac
	)
;
--for multiple hits for the same procedure on same attribute (faulty SNOMED hierarchy), keep only the deepest match
delete from test_group t
where exists
	(
		select
		from test_group x
		where
			(t.procedure_id, t.snomed_id, t.match_on) = (x.procedure_id, x.snomed_id, x.match_on) and
			t.priority < x.priority
	)
;
--Amputations should only be considered for Detachment '0_6%'
delete from test_group
where
	procedure_id not in (select procedure_id from icd10mappings where procedure_code like '0_6%') and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4217482) --Amputation
;
--introduction of drainage devices must not intersect with introduction of substance
delete from test_group
where
	procedure_id not in (select procedure_id from icd10mappings where procedure_code like '0_9%') and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4181192) --Introduction of substance by body site
;
--if access through natural/artificial opening is specified, we must exclude body cavity endoscope devices (thoracoscope, laparoscope etc) and percutaneous approach
delete from test_group
where
	snomed_id in 
		(
			select concept_id_1
			from snomed_relationship
			join ancestor_snomed on
				descendant_concept_id = concept_id_2 and
				ancestor_concept_id in
					(
						4210589, --Body cavity endoscope
						4013298	--Percutaneous approach
					)
		) and
	procedure_id in
		(
			select procedure_id
			from icd10mappings
			join atr_unil on procedure_code = concept_code
			where attr_name = 'Via Natural or Artificial Opening Endoscopic'
		)
;
--Intravenous contrast CT can only be assumed for imaging of venous structures 
delete from test_group
where
	procedure_id not in
		(
			select procedure_id
			from icd10mappings
			join ancestor_snomed on
				attribute_id = descendant_concept_id and
				ancestor_concept_id = 4003033 --Venous system structure
		) and
	snomed_id in
		(
			select descendant_concept_id
			from ancestor_snomed
			where
				ancestor_concept_id = 4013967 --CT with intravenous contrast
		)
;
--fix methods for Administration (only introductions)
drop table if exists false_introd
;
create unlogged table false_introd as
select distinct
	procedure_id,
	snomed_id
from test_group t where
	procedure_id in (select procedure_id from icd10mappings where procedure_code like '3%') and
	snomed_id in
		(
			select concept_id_1
			from snomed_relationship
			left join ancestor_snomed on
				descendant_concept_id = concept_id_2 and
				ancestor_concept_id in 
					(
						4044532, -- Introduction - action
						4287563	--Insufflation -- for gas
					)
			where
				relationship_id = 'Has method' and
				descendant_concept_id is null /*and
				not exists 
					(
						select from icd10mappings
						where
							t.procedure_id = procedure_id and
							concept_id_2 = attribute_id
					)*/
		)
;
delete from false_introd fi
where
	exists
		(
			select from icd10mappings i
			join snomed_relationship r on
				r.relationship_id = 'Has method' and
				i.attribute_id = r.concept_id_2 and
				r.concept_id_1 = fi.snomed_id and
				i.procedure_id = fi.procedure_id
		)
;
--no surgery in Imaging 'B%'
insert into false_introd
select distinct
	t.procedure_id,
	t.snomed_id
from test_group t
join icd10mappings i on
	t.procedure_id = i.procedure_id and
	i.procedure_code like 'B%'
join snomed_relationship sr on
	sr.concept_id_1 = t.snomed_id
join ancestor_snomed a on
	sr.concept_id_2 = a.descendant_concept_id and
	a.ancestor_concept_id in 
		(
			4045049 --surgical action
-- 			4044176	--Evaluation - action
		)
;
delete from test_group where (procedure_id, snomed_id) in (select procedure_id, snomed_id from false_introd)
;
--0_R% (Replacement) must not have DIRECT relation to Devices
-- delete from test_group
-- where
-- 	procedure_id in (select procedure_id from icd10mappings where procedure_code like '0_R%') and
-- 	snomed_id in (select concept_id_1 from snomed_relationship where relationship_id = 'Has dir device')
;
--0_R% (Replacement) must not include Removal of devices or substances
delete from test_group
where
	procedure_id in (select procedure_id from icd10mappings where procedure_code like '0_R%') and
	snomed_id in
		(
			select descendant_concept_id
			from ancestor_snomed
			where ancestor_concept_id in (4180032)	-- Removal of object
		)
;
--only obstetric procedures '1%' should be mapped to descendants of 4302541 Obstetric procedure
delete from test_group
where
	procedure_id not in 
		(
			select procedure_id
			from icd10mappings 
			left join ancestor_snomed on
				ancestor_concept_id in
					(
						4097520,	--Structure of product of conception
						4241775	--Gravid uterus structure
					) and
				descendant_concept_id = attribute_id
			where procedure_code like '1%'
			
		) and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4302541)
;
--No snomed procedure should have Method more specific than root procedure in pos. 3
--Repairs are exception as their interrelationships are inconsistent in snomed
drop table if exists false_method
;
create unlogged table false_method as
with repairs as --exclude children of repair and removal method
	(
		select descendant_concept_id as repairs_id
		from ancestor_snomed
		where ancestor_concept_id in (4117981,4324523) --surgical repairs, dilations
	)
select distinct
	t.procedure_id,
	t.snomed_id
from test_group t
join icd10mappings i on
	i.procedure_code like '0%' and --surgical procedures
	i.procedure_id = t.procedure_id
join snomed_relationship r2 on
	t.snomed_id = r2.concept_id_1 and
	r2.relationship_id in ('Has revision status','Has method') and
	r2.concept_id_2 != 4045049
where 
	not exists --not repair
		(
			select
			from repairs where
				repairs_id = r2.concept_id_2
		) and
	not exists --not in whitelist
		(
			select
			from method_whitelist
			where
				procedure_id = t.procedure_id and
				method_id = r2.concept_id_2
		)
;--however, repairs should not be presented as an option for non-repairs
insert into false_method
with repairs as --exclude children of repair and removal method
	(
		select descendant_concept_id as repairs_id
		from ancestor_snomed
		where ancestor_concept_id = 4117981 --surgical repairs
	)
select
	t.procedure_id,
	t.snomed_id
from test_group t
join icd10mappings i on
	substr (i.procedure_code,1,1) in ('0') and --surgical procedures
	substr (i.procedure_code,3,1) not in ('1','7','Q','R','N','S','U','X','J','0','7') and --Not one that can possibly be repair
	i.procedure_id = t.procedure_id
join snomed_relationship r2 on
	t.snomed_id = r2.concept_id_1 and
	r2.relationship_id in ('Has method') and
	r2.concept_id_2 in (select repairs_id from repairs)
;
analyze test_group
;
--repairs do not include any form of constructions
insert into false_method
with constructs as
	(
		select descendant_concept_id
		from ancestor_snomed
		where ancestor_concept_id in 
			(
				4045072, --Construction - action
				4044532	--Introduction - action
			)
	)
select
	t.procedure_id,
	t.snomed_id
from test_group t
join icd10mappings i on
-- 	substr (i.procedure_code,1,1) in ('0') and --surgical procedures
-- 	substr (i.procedure_code,3,1) in ('Q') and
	i.procedure_code like '0_Q%' and
	i.procedure_id = t.procedure_id
join snomed_relationship r2 on
	t.snomed_id = r2.concept_id_1 and
	r2.relationship_id in ('Has method') and
	r2.concept_id_2 in (select * from constructs)
;
CREATE INDEX idx_false_method2 ON false_method (procedure_id,snomed_id) 
;
analyze false_method
;
drop table if exists test_group1 cascade
;
create unlogged table test_group1 as
select t.*
from test_group t
left join false_method f on
	f.procedure_id = t.procedure_id and
	f.snomed_id = t.snomed_id
where f.procedure_id is null
;
drop table if exists test_group cascade
;
drop table if exists false_method cascade
;
alter table test_group1 rename to test_group
;
CREATE INDEX idx_test_group	ON test_group (procedure_id, snomed_id, match_on)
;
analyze test_group
;
--procedures with 4044524 Removal - action should only be for procedures that have core 4134423 Removal of device or 4134598 Surgical removal or 4027561 Surgical extraction
delete from test_group
where
	snomed_id in (select concept_id_1 from snomed_relationship where concept_id_2 = 4044524) and
	procedure_id in 
		(
			select
				coalesce (s.procedure_id, i.procedure_id)
			from icd10mappings i
			left join splitter s on
				s.replaced_id = i.procedure_id
			where i.procedure_id in (4134423,4134598,4027561)
		)
;
--Catheterization should not be counted as primary target for Dilations
delete from test_group t
where
	procedure_id in (select procedure_id from icd10mappings where procedure_code like '0_7%') and --Dilation
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4164278) --Catheterization
;
--remove reattachments/closures/dilations from Repair
--remove prostheses, vascular grafts from Repair
--remove children of methodless procedures, like 'shunt procedure'
delete from test_group
where
	snomed_id in
		(
			select concept_id_1 from snomed_relationship where concept_id_2 in (4044539,4044539,4081507,4044550,4257977,4045074,4126220,4174131) --reattachment,closure, closure method, Dilation - action, Dilation repair, Stabilization, resurf., refashioning
			
				union all
				
			select concept_id_1
			from snomed_relationship
			join concept_ancestor on
				ancestor_concept_id in (4205702,4105060,4124754,4142191,4223622) and --prostheses, Cardiovascular material, graft, vascular device, implant and children
				descendant_concept_id = concept_id_2
				
				union all
			
			select descendant_concept_id
			from ancestor_snomed
			where ancestor_concept_id in (4090313,4031047) --shunt into peritoneum, fixation
		) and
	procedure_id in 
		(
			select procedure_id from icd10mappings where substr (procedure_code,1,1) = '0' and substr (procedure_code,3,1) = 'Q' and procedure_code not in ('0WQ6XZ2','0WQFXZ2')
		)
;
--only procedures with 'Diagnostic' attribute should refer to 4129646 Diagnostic intent
with dia_snm as
	(
		select concept_id_1
		from snomed_relationship
		where concept_id_2 = 4129646 --Diagnostic intent
	),
--likewise, no diagnostic procedure can have 4133895 Therapeutic intent
ther_snm as
	(
		select concept_id_1
		from snomed_relationship 
		where concept_id_2 = 4133895 --Therapeutic intent
	)
delete from test_group
where 
	(
		procedure_id not in 
			(
				select procedure_id from icd10mappings where attribute_id in (4311405,4129646)
				
					union all
					
				select procedure_id from icd10mappings where attribute_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4297090) --Evaluation
			) and snomed_id in (select concept_id_1 from dia_snm)
	) or
	(procedure_id in (select procedure_id from icd10mappings where attribute_id = 4129646) and snomed_id in (select concept_id_1 from ther_snm))
;
--disallow Open procedures to have Percutaneous approach and vice versa
with pct_snm as
	(
		select concept_id_1
		from snomed_relationship
		where concept_id_2 in (4013298,4127468) --Percutaneous, Transluminal
	)
delete from test_group
where
	(procedure_id in (select procedure_id from icd10mappings where attribute_id = 4044378) and snomed_id in (select concept_id_1 from pct_snm))
;
--disallow Open procedures to have Percutaneous approach and vice versa
with open_snm as
	(
		select concept_id_1
		from snomed_relationship
		where concept_id_2 = 4044378 --Open approach
	)
delete from test_group
where
	(procedure_id in (select procedure_id from icd10mappings where attribute_id in (4013298,4127468)) and snomed_id in (select concept_id_1 from open_snm))
;
analyze test_group
;
--similarly, endoscopy must be specified. Open can't be endoscopic and vice versa
with end_snm as
	(
		select concept_id_1
		from snomed_relationship
		join concept_ancestor on
			ancestor_concept_id = 4290594 and --endoscope
			descendant_concept_id = concept_id_2
	),
open_snm as
	(
		select concept_id_1
		from snomed_relationship
		where concept_id_2 = 4044378 --Open approach
	)
delete from test_group
where
	(procedure_id in (select procedure_id from icd10mappings where attribute_id = 4290594) and snomed_id in (select concept_id_1 from open_snm)) or
	(procedure_id not in (select procedure_id from icd10mappings where attribute_id = 4290594) and snomed_id in (select concept_id_1 from end_snm))
;
--Resections are removals of entire organs and can't refer to 40599742 Lesion
/* proof:
select * 
from concept p
join concept_ancestor ca on
	ca.descendant_concept_id = p.concept_id and
	
	p.standard_concept = 'S' and
	p.vocabulary_id = 'SNOMED' and
	p.concept_class_id = 'Procedure' and
	
	ca.ancestor_concept_id = 4279903
join concept_relationship r1 on
	r1.concept_id_1 = p.concept_id and
	r1.invalid_reason is null
join concept a1 on
	a1.concept_id = r1.concept_id_2 and
	a1.vocabulary_id = 'SNOMED' and
	a1.concept_class_id = 'Body Structure' and
	a1.standard_concept = 'S'
join concept_ancestor ca2 on
	ca2.descendant_concept_id = a1.concept_id and
	ca2.ancestor_concept_id = 4179858
	
join concept_ancestor cp2 on
	cp2.descendant_concept_id = p.concept_id
join concept_relationship r2 on
	cp2.ancestor_concept_id = r2.concept_id_1 and
	r2.concept_id_2 = 40599742 
	
 	and cp2.min_levels_of_separation < ca.min_levels_of_separation
*/
delete from test_group
where
	snomed_id in (select concept_id_1 from snomed_relationship where concept_id_2 = 40599742) and
	procedure_id in (select procedure_id from icd10mappings where procedure_code like '0_T%')
;
analyze test_group
;
--SNOMED 'replacements' are both 'removals' and 'placements', so we ensure that no separate 'insertion' or 'removal' in ICD10PCS will get coded as 'replacement'
create unlogged table removal_id as--for removals
	(
		select i.procedure_id
		from icd10mappings i
		where
			(--removal surgical; code pattern 0.P....
				substr (i.procedure_code,1,1) = '0' and
				substr (i.procedure_code,3,1) in ('P','B','T','C')
			)
			or
			(--removal of device; code pattern 2.5....
				substr (i.procedure_code,1,1) = '2' and
				substr (i.procedure_code,3,1) = '5'
			)
-- 			or
-- 			(--Repair; code pattern 0.Q.... -- grafts/implants belong in other chapter
-- 				substr (i.procedure_code,1,1) = '0' and
-- 				substr (i.procedure_code,3,1) = 'Q'
-- 			)
-- 			or
-- 			substr (i.procedure_code,1,1) = 'B' --whole imaging chapter. eliminates whole angiographic stent insertion stuff while we are at it
	)
;
/*delete from test_group t where --don't mix removal of device and surgical removal
	exists 
		(
			select 1 
			from icd10mappings i where
				i.procedure_id = t.procedure_id and
					(
						(
							substr (i.procedure_code,1,1) = '0' and
							substr (i.procedure_code,3,1) in ('P','B','T','C')
						) or
						(
							substr (i.procedure_code,1,3) in ('109','10T','10D','10P','10A')
						) or
						(
							i.procedure_code like '8C0__6%'
						)
					)
		) and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id in (4134423)) --removal of device*/
;
delete from test_group t
where
	procedure_id in (select procedure_id from removal_id) and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id in (4027403,4132647,4185115)) --introduction, construction, repair
;
delete from test_group t
where
	procedure_id in (select procedure_id from removal_id) and
	snomed_id in (select concept_id_1 from snomed_relationship join ancestor_snomed on descendant_concept_id = concept_id_2 and ancestor_concept_id in (4175951)) --Morph abnormality
;
drop table if exists removal_id cascade
;
create unlogged table insertion_id as -- for insertions
	(
		select i.procedure_id
		from icd10mappings i
		where
			(--insertion surgical; pattern 0.H.... or 1.H....
				substr (i.procedure_code,1,1) in ('0','1') and
				substr (i.procedure_code,3,1) = 'H'
			)
	)
;
delete from test_group
where
	procedure_id in (select * from insertion_id) and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id in (4042150,4300185,4000731)) --removal, transplantation, grafting
;
delete from test_group t where --don't mix removal of device and surgical removal
	exists 
		(
			select 1 
			from icd10mappings i where
				i.procedure_id = t.procedure_id and 
				substr (i.procedure_code,1,1) = '0' and
				substr (i.procedure_code,3,1) in ('P','B','T','C')
		) and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id in (4134423)) --removal of device
;
drop table if exists insertion_id cascade
;
create unlogged table radio_id as -- delete brachytherapy from surgical destruction -- has its own chapter
	(
		select i.procedure_id
		from icd10mappings i
		where
			(--destruction surgical; pattern 0.5....
				substr (i.procedure_code,1,1) = '0' and
				substr (i.procedure_code,3,1) = '5'
			)
	)
;
delete from test_group
where
	procedure_id in (select procedure_id from radio_id) and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id in (4029715,4180941)) --radiotherapy, procedures with specified devices
;
delete from test_group where
	procedure_id in (select procedure_id from radio_id) and
	snomed_id in (select concept_id_1 from snomed_relationship where concept_id_2 = 4133890 and invalid_reason is null) --stereotactic surgery belongs in other chapter
;
drop table if exists radio_id cascade
;
delete from test_group where --Stereotactic Radiosurgery children should only appear for D02* codes 
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4215577) and
	not exists
		(
			select from icd10mappings
			where procedure_id = test_group.procedure_id and
			substr (procedure_code,1,3) = 'D02'
		)
	
;
--also stereotactic, not mentioned in attr
delete from test_group t
where
	exists
		(
			select
			from ancestor_snomed a
			where
				a.descendant_concept_id = t.snomed_id and
				a.ancestor_concept_id = 4215577
		)
	and procedure_id not in (2791307,2791308,2791309,2791310,2791311,2791312,2791313,2791314,2791315,2791316,2791317,2791318,4063662)
;
analyze test_group
;
drop table if exists no_morph_allowed cascade
;
--procedures that specify abnormal morphology (except for 40599742 Lesion) cant be normally present in ICD10PCS
create unlogged table no_morph_allowed as
select t.procedure_id, t.snomed_id, cr.concept_id_2
from test_group t
join snomed_relationship cr on
	t.snomed_id = cr.concept_id_1 and
	cr.relationship_id in ('Has proc morph','Has dir morph','Has asso morph','Has indir morph') and
	cr.concept_id_2 != 40599742 and -- generic 'lesion'
	cr.invalid_reason is null
-- where cr.concept_id_1 is null or cr2.concept_id_1 is not null
;
--allow procedures with matching specified morphologies
delete from no_morph_allowed n
where
	n.concept_id_2 in
	(
		select a.descendant_concept_id 
		from icd10mappings i
		join ancestor_snomed a on
			n.procedure_id = i.procedure_id and
			i.concept_class_id = 'Morph Abnormality' and
			a.ancestor_concept_id = i.attribute_id
			
	)
;
create index idx_no_morph_allowed on no_morph_allowed (procedure_id, snomed_id)
;
analyze no_morph_allowed
;
delete from test_group
where
	(procedure_id, snomed_id) in
	(
		select procedure_id, snomed_id
		from no_morph_allowed
	)
;
analyze test_group
;/*
-- sometimes procedures in snomed have multiple related attributes. We only need to keep unique matches for SNOMED attributes
-- A procedure may have for example both 'Upper limb structure' AND 'Vascular structure of forearm', with ICD10PCS procedure having only the second analogue.
-- to find superfluos attributes we rely on ancestor_snomed table; match attribute is considered superfluous if the same match is also made with that attributes descendant;
-- therefore, in any chain of ancestorship only the most specific attribute will be kept
create unlogged table incorrect_attributes as
select distinct -- natching pair we check
	ca.procedure_id,
	ca.snomed_id,
	ca.match_on
from test_group ca
join ancestor_snomed c on
	c.ancestor_concept_id = ca.match_on and -- all children of the attribute
	c.min_levels_of_separation > 0 -- not the same attribute
join test_group x on
	ca.procedure_id = x.procedure_id and -- exact matching pair is formed with children
	ca.snomed_id = x.snomed_id and
	c.descendant_concept_id = x.match_on
;
CREATE INDEX idx_incorrect_attributes
	ON incorrect_attributes (procedure_id, snomed_id, match_on) 
;
analyze incorrect_attributes;
;
create unlogged table test_group1 as
select t.*
from test_group t
left join incorrect_attributes a on
	t.procedure_id = a.procedure_id and
	t.snomed_id = a.snomed_id and
	t.match_on = a.match_on
where a.procedure_id is null
;
drop table if exists incorrect_attributes cascade
;
drop table if exists test_group cascade
;
alter table test_group1 rename to test_group
;
create index idx_test_group on test_group (procedure_id, snomed_id)
;
analyze test_group*/
;
/*
delete from test_group t --surgical occlusion has surgery as method --not anymore
where 
	exists
		(
			select 
			from ancestor_snomed
			where
				ancestor_concept_id = 4282394 and
				descendant_concept_id = t.snomed_id
		) and
	not exists --not surgical occlusion by itself
		(
			select
			from concept
			where 
				concept_id = t.procedure_id and
				substr (concept_code,1,1) = '0' and
				substr (concept_code,3,1) = 'L'
		)*/
;
/*
--any Methods should not be considered for this iteration as they are always preserved in the first one
delete from test_group
where match_on in
	(
		select descendant_concept_id
		from ancestor_snomed
		where ancestor_concept_id = 4044908
	)*/
;
analyze test_group
;
delete from test_group t --removal is not a proper method substitute for drainages and excisions/resections
where
	procedure_id in 
	(
		select procedure_id
		from icd10mappings
		join ancestor_snomed a on 
			attribute_id = descendant_concept_id and
			concept_class_id = 'Procedure'
		where 
			(ancestor_concept_id = 4046266) or --Drainage
			procedure_code like '0_B%' or
			procedure_code like '0_T%'
	) and
	snomed_id in (select concept_id_1 from snomed_relationship where concept_id_2 = 4044524 and relationship_id = 'Has method') --Removal - action
;
analyze test_group
;
--only procedures with attributes of of 4291637 Split thickness skin graft & 4324976 Full thickness skin graft can have their children as mapping
delete from test_group t
where
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4291637) and
	not exists
		(
			select
			from icd10mappings
			where t.procedure_id = procedure_id and attribute_id = 4291637
		)
;
delete from test_group t
where
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4324976) and
	not exists
		(
			select
			from icd10mappings
			where t.procedure_id = procedure_id and attribute_id = 4324976
		)
;
--reuse old attribute_groups
drop table if exists pair_w_snomed_a cascade
;
create unlogged table pair_w_snomed_a as --suspicion
	(
		select distinct
			procedure_id,
			snomed_id,
-- 			ancestor_concept_id, --needed?
			concept_id_2
		from test_group
		join snomed_relationship on
			concept_id_1 = snomed_id
		join attribute_groups on
			concept_id_2 = descendant_concept_id
	)
;
create index idx_snm_atr on pair_w_snomed_a (procedure_id, snomed_id);
create index idx_snm_atr2 on pair_w_snomed_a (procedure_id, concept_id_2);
;
analyze pair_w_snomed_a
;
-- explain
delete from pair_w_snomed_a p --clear suspicion when i10p has attribute. or ancestor
where
	exists
		(
			select
			from icd10mappings i
			join ancestor_snomed a on
				a.descendant_concept_id = i.attribute_id and
				i.procedure_id = p.procedure_id and
				a.ancestor_concept_id = p.concept_id_2
		)
;
analyze pair_w_snomed_a
;
--should we allow descendants too?
;
delete from test_group
where
	(procedure_id, snomed_id) in (select procedure_id, snomed_id from pair_w_snomed_a)
;
--GI endoscopes can only be used w/ procedures on GIT
delete from test_group t
where
	exists --snomed uses git endoscope
		(
			select
			from snomed_relationship r
			join ancestor_snomed x on
				r.concept_id_1 = t.snomed_id and
				r.concept_id_2 = x.descendant_concept_id and
				x.ancestor_concept_id = 4207031 -- Digestive endoscope
		) and
	not exists --icd10pcs does not have a git body structure
		(
			select
			from icd10mappings i
			join ancestor_snomed a on
				i.procedure_id = t.procedure_id and
				i.attribute_id = a.descendant_concept_id and
				a.ancestor_concept_id = 4314892 --Structure of digestive system
		)
;
--urinary endoscopes should only be used for procedures through Artficial or Natural Opening
delete from test_group
where
	snomed_id in 
		(
			select concept_id_1
			from snomed_relationship
			join ancestor_snomed on
				descendant_concept_id = concept_id_2 and
				ancestor_concept_id = 4208651 --Urinary endoscope
		) and
	procedure_id not in
		(
			select procedure_id
			from icd10mappings
			join atr_unil on procedure_code = concept_code
			where attr_name = 'Via Natural or Artificial Opening Endoscopic'
		)
;
--reattachment is only in its own branch
delete from test_group t
where
	procedure_id not in (select procedure_id from icd10mappings where procedure_code like '0_M%') and
	snomed_id in (select descendant_concept_id from ancestor_snomed where ancestor_concept_id = 4161186)
;
with proc_prio as
	(
		select distinct priority
		from test_group
	)
select fill_mapping (priority, priority + 10, true) -- +10 is to differentiate iterations in debugging
from proc_prio
;
analyze mappings
;
--add high dose brachytherapy (removed before for being a stub concept)
insert into mappings
select
	procedure_id,
	4216178, --High dose brachytherapy
	'Is a',
	30
from icd10mappings
where procedure_code like 'D_1_9%'
;
-- explain
update mappings m
set
	procedure_id =  (select s.procedure_id from splitter s where s.replaced_id = m.procedure_id)
where m.procedure_id in (select replaced_id from splitter)
;
--if level 6 is present, add it as a mapping
with full_list as
	(
		select distinct
			icd_id,
			icd_code,
			snomed_code
		from level6
		where snomed_code is not null
			UNION
		select distinct
			icd_id,
			icd_code,
			snomed_code_2
		from level6
		where snomed_code_2 is not null
	)
insert into mappings
select distinct
	coalesce (s.replaced_id, c1.concept_id) as procedure_id,
	c2.concept_id as snomed_id,
	'Is a' as rel_id,
	26 as priority
from full_list f
join concept_stage c1 on
	substr (c1.concept_code,1,6) = f.icd_code and
	c1.concept_class_id = 'ICD10PCS'
left join splitter s on
	s.procedure_id = c1.concept_id
join concept c2 on
	c2.concept_code = f.snomed_code and
	c2.vocabulary_id = 'SNOMED'
;
--add procedure itself to test_group to warrant at least most generic mapping where nothing else is available 
--example: 3C1ZX8Z Irrigation of Indwelling Device using Irrigating Substance, External Approach is just Irrigation with no better specification available
insert into mappings
select
	coalesce (s.replaced_id, i.procedure_id) as procedure_id,
	i.attribute_id as snomed_id,
	'Is a' as rel_id,
	0 as priority
from icd10mappings i
left join splitter s on
	s.procedure_id = i.procedure_id
where i.concept_class_id = 'Procedure'
;
analyze mappings
;
--removing duplicates/ancestors again
create unlogged table mappings1 as
with min_priority as
	(
		select
			a.procedure_id,
			a.snomed_id,
			min (a.priority) over (partition by a.procedure_id,a.snomed_id) as priority
		from mappings a
	)
select m.* from mappings m
join min_priority i on
	i.procedure_id = m.procedure_id and
	i.snomed_id = m.snomed_id and
	i.priority = m.priority
;
drop table if exists mappings cascade
;
alter table mappings1 rename to mappings
;
CREATE INDEX idx_MAPPINGS ON MAPPINGS (PROCEDURE_ID, SNOMED_ID, PRIORITY) 
;
CREATE INDEX idx_MAPPINGS2 ON MAPPINGS (PROCEDURE_ID) 
;
analyze MAPPINGS
;
create table mappings1 as
select 
	coalesce (s.procedure_id,m.procedure_id) as procedure_id,
	m.snomed_id,
	m.rel_id,
	m.priority
from mappings m
left join splitter s on
	s.replaced_id = m.procedure_id
;
drop table if exists mappings cascade
;
alter table mappings1 rename to mappings
;
CREATE INDEX idx_MAPPINGS ON MAPPINGS (PROCEDURE_ID, SNOMED_ID, PRIORITY) 
;
analyze MAPPINGS
;
delete from mappings m
where exists
	(
		select
		from mappings a
		join ancestor_snomed ca on
			ca.descendant_concept_id = a.snomed_id and
			ca.min_levels_of_separation != 0 and
			m.procedure_id = a.procedure_id and
			m.snomed_id = ca.ancestor_concept_id
	)
;
analyze MAPPINGS
;
drop table if exists teeth_extr cascade --remap teeth excisions to extractions
;
create unlogged table teeth_extr as
select concept_id 
from concept
where
	vocabulary_id = 'ICD10PCS' and
	(
		concept_code like '0CTW%' or
		concept_code like '0CTX%' or
		concept_code like '0CCW%' or
		concept_code like '0CCX%'
	)
;
delete from mappings m
where m.procedure_id in (select concept_id from teeth_extr)
;
insert into mappings
select
	concept_id,
	4208393,
	'Is a',
	30
from teeth_extr
;
-- commented: while code and algorythms may be proven valuable for future interactions, they don't serve a purpose at this time
/*
--Quasi-ancestorship: if all attributes that target has are ancestors of every attribute of another target, remove them
drop MATERIALIZED view if exists i_to_a
;
create MATERIALIZED VIEW i_to_a as --monster table to have indices on
with focus as
	(
		select procedure_id
		from mappings
-- 		where procedure_id = 2726160
		group by procedure_id
		having count (distinct snomed_id) > 1
	)
select distinct
	m.procedure_id,
	m.snomed_id,
	r.concept_id_2
from mappings m
join snomed_relationship r on
	r.concept_id_1 = m.snomed_id
join focus f using (procedure_id)
;
create index i_to_a_rel on i_to_a (procedure_id, snomed_id);
create index i_to_a_atr on i_to_a (concept_id_2);
;
analyze i_to_a
;
with quasidescendants as
(
	select
		I0.procedure_id, 
		I0.snomed_id
	from i_to_a I0
	where not exists
		(
			select
			from i_to_a Ix
			join ancestor_snomed a1 on
				Ix.procedure_id = I0.procedure_id and
				Ix.snomed_id != I0.snomed_id and --okay if on same level (levels_of_separation = 0), but the attribute must be found on another SNOMED procedure
			
				a1.ancestor_concept_id = I0.concept_id_2 and
				a1.descendant_concept_id = Ix.concept_id_2
			
			join snomed_relationship_hashed hx on -- Ix and I0 must also have different attribute set; otherwise both will be marked
				hx.concept_id_1 = Ix.snomed_id
			join snomed_relationship_hashed h0 on
				h0.concept_id_1 = I0.snomed_id and
				hx.attr_hash != h0.attr_hash
		)
)
delete from mappings
where
	(procedure_id, snomed_id) not in (select * from quasidescendants) and
	procedure_id in (select procedure_id from quasidescendants)*/
