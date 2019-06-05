DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'LPD_Belgium',
	pVocabularyDate			=> TO_DATE ('20190501', 'yyyymmdd'),
	pVocabularyVersion		=> 'LPD_Belgium 2019-MAY-31',
	pVocabularyDevSchema	=> 'dev_belg'
);
END $_$
;
drop table if exists belg_source_full
;
create table belg_source_full as select * from belg_source
;
drop table if exists official_mappings
;
--get mappings from GGR vocabulary
create table official_mappings as
select
	a.prod_prd_id,
	cr.concept_id_2 as concept_id
from belg_source a
join concept c0 on
	c0.vocabulary_id = 'GGR' and
	(
		c0.concept_code = to_char (prod_prd_eid :: int4, 'fm0000000')
	)
join concept_relationship cr on
	cr.concept_id_1 = c0.concept_id and
	cr.invalid_reason is null and
	cr.relationship_id = 'Maps to'
;
--get mappings for old codes from GGR vocabulary
insert into official_mappings
select
	a.prod_prd_id,
	cr.concept_id_2 as concept_id
from belg_source a
join concept c0 on
	c0.vocabulary_id = 'GGR' and
	(
		c0.concept_code = 'mpp' ||  to_char (prod_prd_eid :: int4, 'fm0000000')
	)
join concept_relationship cr on
	cr.concept_id_1 = c0.concept_id and
	cr.invalid_reason is null and
	cr.relationship_id = 'Maps to' and
	a.prod_prd_id not in
	(
		select prod_prd_id
		from official_mappings
	)
;
--find dublicates by name
insert into official_mappings
select distinct  b.prod_prd_id, o.concept_id
from belg_source b
join belg_source x on
	x.prd_name = b.prd_name and
	x.prod_prd_id != b.prod_prd_id
join official_mappings o on
	o.prod_prd_id = x.prod_prd_id
where 
	b.prod_prd_id not in
	(
		select prod_prd_id
		from official_mappings
	)
;
--preserve existing mappings, if not mapped in official
insert into official_mappings
select distinct
	a.prod_prd_id,
	r.concept_id_2
from belg_source a
join concept c on
	c.vocabulary_id = 'LPD_Belgium' and
	c.concept_code = a.prod_prd_id
join concept_relationship r on
	r.concept_id_1 = c.concept_id and
	r.relationship_id = 'Maps to' and
	r.invalid_reason is null
join concept c2 on
	c2.concept_id = r.concept_id_2 and
	c2.concept_class_id != 'Ingredient'
-- we trust already made official mappings more
left join official_mappings o using (prod_prd_id)
where o.prod_prd_id is null
;
--find dublicates by name
insert into official_mappings
select distinct b.prod_prd_id, o.concept_id
from belg_source b
join belg_source x on
	x.prd_name = b.prd_name and
	x.prod_prd_id != b.prod_prd_id
join official_mappings o on
	o.prod_prd_id = x.prod_prd_id
where 
	b.prod_prd_id not in
	(
		select prod_prd_id
		from official_mappings
	)
;
--remove older mappings
delete from official_mappings m
where exists
	(
		select
		from official_mappings o
		join concept x on
			m.concept_id = x.concept_id
		join concept y on
			o.concept_id = y.concept_id and
			x.valid_start_date > y.valid_start_date
		where
			m.prod_prd_id = o.prod_prd_id and
			m.concept_id != o.concept_id
	)
;
--remove changed mappings
delete from official_mappings m
where exists
	(
		select
		from official_mappings o
		join concept x on
			m.concept_id = x.concept_id
		join concept y on
			o.concept_id = y.concept_id and
			x.concept_code > y.concept_code
		where
			m.prod_prd_id = o.prod_prd_id and
			m.concept_id != o.concept_id
	)
;
delete from belg_source b --only delta gets to be mapped
where exists (select from official_mappings where prod_prd_id = b.prod_prd_id)
;
drop table if exists devices_mapped
;
create table devices_mapped as
select prd_name
from belg_source 
where 
	regexp_match (prd_name,'[0-9 ]+(CM|MM|M)? ?X ?[0-9 ]+(CM|MM|M)[ $]') is not null or -- 00 MM X 00 MM
	prd_name like '% PANTS %' or
	(prd_name like '%SHAMPOO%' and mol_name = 'UNKNOWN') or
	regexp_match (prd_name,'\d{2,} ?G$') is not null or
	prd_name like '%ROUL%' or
	prd_name like '%TROUSSE%' or
	prd_name like 'BOTA%' or
	prd_name like '%COMPRESS%' or
	prd_name like '%VALVE%' or
	prd_name like '%BAND%' or
	prd_name like '%ACCESSOIRE%' or
	prd_name like '%COLLIER%' or
	prd_name like '%CM %' or
	prd_name like '%LATEX%' or
	prd_name like '%TALC%' or
	prd_name like '%STRIP%' or
	prd_name like '%LANCETTE%' or
	prd_name like '%PLUG%' or
	prd_name like 'BEQUILLE%' or
	prd_name like 'THERMOMETRE%' or
	--suppliers
	prd_name like '%UNDA' or
	prd_name like '%BOIRON%' or
	prd_name like '%HEEL' or
	prd_name like 'WELEDA%' or
	prd_name like '%WELEDA' or
	prd_name like '%HOMEOROPA%' or
	manufacturer_name like 'HEEL %' or
	manufacturer_name like 'BOIRON %' or
	--Brands (nutrition, devices)
	prd_name like '%CALDYN%' or
	prd_name like '%SOUVENAID%' or
	prd_name like '%ACTIMOVE%' or
	prd_name like 'PUSH %' or
	prd_name like '%FORTIMEL%' or
	prd_name like '2L%' or
	prd_name like 'AEROCHAMBER%' or
	prd_name like 'ONE TOUCH%' or
	prd_name like 'ONETOUCH%' or
	prd_name like 'MEPILEX%' or
	prd_name like 'TENA %' or
	prd_name like 'TRAUMEEL%' or
	--Devices
	prd_name like 'ALCOOL%DESINF%' or
	prd_name like 'ACCU%CHEK%' or
	prd_name like 'BD EMERALD%' or
	prd_name like 'BD MICROFINE%'
;
truncate drug_concept_stage
;
INSERT INTO drug_concept_stage --devices
SELECT distinct
	d.prd_name,
	'LPD_Belgium' AS vocabulary_id,
	'Device' AS concept_class_id,
	NULL AS source_concept_class_id,
	'S' AS standard_concept,
	d.prod_prd_id AS concept_code,
	NULL AS possible_excipient,
	'Device' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM belg_source d
JOIN devices_mapped m ON m.prd_name = d.prd_name;

INSERT INTO drug_concept_stage --drugs
SELECT d.prd_name,
	'LPD_Belgium' AS vocabulary_id,
	'Drug Product' AS concept_class_id,
	NULL AS source_concept_class_id,
	'S' AS standard_concept,
	d.prod_prd_id AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM belg_source d
WHERE prd_name NOT IN (
		SELECT prd_name
		FROM devices_mapped
		)
;
--insert Drug products and Devices (judging by their mappings) from official_mappings
insert into drug_concept_stage
select distinct
	f.prd_name,
	'LPD_Belgium' AS vocabulary_id,
	case when
		c.domain_id = 'Drug' then 'Drug Product'
		else 'Device'
	end,
	null :: varchar,
	case when
		c.domain_id = 'Drug' then null
		else 'S'
	end,
	f.prod_prd_id,
	null :: varchar,
	c.domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
from belg_source_full f
join official_mappings o on
	f.prod_prd_id = o.prod_prd_id
join concept c on
	c.concept_id = o.concept_id
;
--create a table to ensure legacy mapping inheritance
-- DROP TABLE IF EXISTS r_to_c_all CASCADE;

CREATE TABLE if not exists r_to_c_all
(
   concept_name       varchar(255),
   concept_class_id   varchar,
   concept_id         integer,
   precedence         integer,
   conversion_factor  float8
);
--we are only interested to find brand names that have 'stable' ingredient sets: with one possible ingredient combination
drop table if exists brand_rx
;
create table brand_rx as
with bn_to_i as
	(
		select
			c.concept_id as b_id,
			r.concept_id_2 as i_id,
			c.concept_name as concept_name,
			count (r.concept_id_2) over (partition by c.concept_id) as cnt_direct
		from concept c
		join concept_relationship r on
			r.relationship_id = 'Brand name of' and
			c.concept_id = r.concept_id_1
		join concept c2 on
			c2.concept_class_id = 'Ingredient' and
			c2.concept_id = r.concept_id_2 and
			c2.standard_concept = 'S'
		where
			c.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
			c.concept_class_id = 'Brand Name' and
			c.invalid_reason is null
	),
bn_to_i_dp as --what possible ingredient sets drug products give us
	(
		select distinct
			c.concept_id as b_id,
			r.concept_id_2 as dp_id,
			d.ingredient_concept_id as i_id,
			count (d.ingredient_concept_id) over (partition by r.concept_id_2) as cnt_drug
		from concept c
		join concept_relationship r on
			r.relationship_id = 'Brand name of' and
			c.concept_id = r.concept_id_1
		join concept c2 on
			c2.concept_class_id != 'Ingredient' and --only combinations and ingredient themselves can have brand names;
			c2.concept_id = r.concept_id_2
		join drug_strength d on
			c2.concept_id = d.drug_concept_id
		join concept c3 on
			d.ingredient_concept_id = c3.concept_id and
			c3.standard_concept = 'S'
		where
			c.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
			c.concept_class_id = 'Brand Name' and
			c.invalid_reason is null
	)
select distinct
	b.b_id,
	b.concept_name,
	b.i_id
from bn_to_i b
left join bn_to_i_dp d on
	d.b_id = b.b_id and
	b.cnt_direct > d.cnt_drug
where d.b_id is null
;
insert into brand_rx
--preserve also bn that are consistent inside RxN
with bn_to_i as
	(
		select
			c.concept_id as b_id,
			r.concept_id_2 as i_id,
			c.concept_name as concept_name,
			count (r.concept_id_2) over (partition by c.concept_id) as cnt_direct
		from concept c
		join concept_relationship r on
			r.relationship_id = 'Brand name of' and
			c.concept_id = r.concept_id_1
		join concept c2 on
			c2.concept_class_id = 'Ingredient' and
			c2.concept_id = r.concept_id_2 and
			c2.standard_concept = 'S'
		where
			c.concept_id not in (select b_id from brand_rx) and --avoid duplication
			c.vocabulary_id = 'RxNorm' and
			c.concept_class_id = 'Brand Name' and
			c.invalid_reason is null and
			exists 
			-- there are RxNorm Drug products with r.concept_id_2 as an ingredient
				(
					select
					from drug_strength d
					join concept x on
						d.drug_concept_id = x.concept_id and
						x.vocabulary_id = 'RxNorm' and
						x.concept_class_id != 'Ingredient' and
						d.ingredient_concept_id = r.concept_id_2
					-- with that brand name and ingredient
					join concept_relationship cr on
						cr.concept_id_1 = x.concept_id and
						relationship_id = 'Has brand name' and
						cr.concept_id_2 = c.concept_id
					where d.invalid_reason is null
				)
	),
bn_to_i_dp as --what possible ingredient sets drug RxN products give us
	(
		select distinct
			c.concept_id as b_id,
			r.concept_id_2 as dp_id,
			d.ingredient_concept_id as i_id,
			count (d.ingredient_concept_id) over (partition by r.concept_id_2) as cnt_drug
		from concept c
		join concept_relationship r on
			r.relationship_id = 'Brand name of' and
			c.concept_id = r.concept_id_1
		join concept c2 on
			c2.concept_class_id != 'Ingredient' and --only combinations and ingredient themselves can have brand names;
			c2.concept_id = r.concept_id_2
		join drug_strength d on
			c2.concept_id = d.drug_concept_id
		join concept c3 on
			d.ingredient_concept_id = c3.concept_id and
			c3.standard_concept = 'S'
		where
			c.concept_id not in (select b_id from brand_rx) and --avoid duplication
			c.vocabulary_id = 'RxNorm' and
			c.concept_class_id = 'Brand Name' and
			c.invalid_reason is null and
			d.invalid_reason is null
	)
select distinct
	b.b_id,
	b.concept_name,
	b.i_id
from bn_to_i b
left join bn_to_i_dp d on
	d.b_id = b.b_id and
	b.cnt_direct > d.cnt_drug
where d.b_id is null
;
--update r_to_c_all mappings from official Belgium schema
delete from r_to_c_all 
where
	(concept_name,concept_class_id) in
	(
		select upper (concept_name),concept_class_id
		from dev_ggr.r_to_c_all
		where concept_class_id in ('Ingredient', 'Supplier')
	) 
;
insert into r_to_c_all
select upper (concept_name),concept_class_id,concept_id,precedence,conversion_factor
from dev_ggr.r_to_c_all
where concept_class_id in ('Ingredient', 'Supplier')
;
delete from r_to_c_all 
where
	(concept_name,concept_class_id) in
	(
		select concept_name,concept_class_id
		from dev_ggr.r_to_c_all
		where concept_class_id in ('Dose Form', 'Unit')
	)
;
insert into r_to_c_all
select concept_name,concept_class_id,concept_id,precedence,conversion_factor
from dev_ggr.r_to_c_all
where concept_class_id in ('Dose Form', 'Unit')
;
--also update BNs that 'tell' ingredients (brand_rx)
delete from r_to_c_all 
where
	(concept_name,concept_class_id) in
	(
		select upper (r.concept_name), r.concept_class_id
		from dev_ggr.r_to_c_all r
		join brand_rx b on
			r.concept_class_id = 'Brand Name' and
			b.b_id = r.concept_id
	) 
;
insert into r_to_c_all
select upper (r.concept_name),r.concept_class_id,r.concept_id,r.precedence,r.conversion_factor
from dev_ggr.r_to_c_all r
join brand_rx b on
		concept_class_id = 'Brand Name' and
		b.b_id = r.concept_id
;
--update legacy mappings if target was changed in concept table
update r_to_c_all
set precedence = 1
where precedence is null 
;
update r_to_c_all
set concept_id = 
	(
		select distinct c2.concept_id
		from concept_relationship r
		join concept c2 on
			c2.concept_id = r.concept_id_2 and
			r_to_c_all.concept_id = r.concept_id_1 and
			r.relationship_id in ('Concept replaced by','Maps to') and
			r.invalid_reason is null
	)
where
	exists
		(
			select
			from concept
			where 
				concept_id = r_to_c_all.concept_id and
				(
					invalid_reason = 'U' or
					concept_class_id = 'Precise Ingredient' --RxN could move Ingredient to PI cathegory
				)
		)
;
delete from r_to_c_all r1
where
	exists 
		(
			select
			from r_to_c_all r2
			where
				(r2.concept_name, r2.concept_class_id, r2.concept_id) = (r1.concept_name, r1.concept_class_id, r1.concept_id) and
				r2.precedence < r1.precedence
		) or
	r1.concept_id is null or
	exists
		(
			select
			from concept
			where 
				concept_id = r1.concept_id and
				invalid_reason = 'D'
		)
;
drop table if exists p_to_i
;
create table p_to_i as
select distinct
	s.prod_prd_id,
	s.prd_name,
	s.mol_name,
	ing_name,
	row_number () over (partition by s.prod_prd_id) as comp_number
from belg_source s, lateral unnest(string_to_array(s.mol_name, '/')) ing_name
where
	not exists 
		(
			select
			from devices_mapped d
			where d.prd_name = s.prd_name
		) and
	s.mol_name != 'UNKNOWN'
;
drop table if exists to_map
;
--start getting mappings
create table to_map as
with innm as
	(
		select distinct ing_name
		from p_to_i
	)
select distinct
	i.ing_name as source_attr_name,
	'Ingredient' as source_attr_concept_class,
	coalesce (c.concept_id,c2.concept_id) as concept_id,
	coalesce (c.concept_name,c2.concept_name) as concept_name,
	coalesce (c.concept_class_id,c2.concept_class_id) as target_concept_class_id,
	r.precedence,
	null :: float8 as conversion_factor
from innm i
left join r_to_c_all r on
	r.concept_class_id = 'Ingredient' and
	i.ing_name = r.concept_name
left join concept c on
	r.concept_id = c.concept_id
--get mappings over concept_synonym
left join 
	(
		select
			ct.concept_id, ct.concept_name, ct.concept_class_id, cs.concept_synonym_name
		from concept_synonym cs
		join concept x on
			x.concept_id = cs.concept_id and
			x.vocabulary_id = 'GGR' and
			x.concept_class_id = 'Ingredient'
		join concept_relationship cr on
			cr.concept_id_1 = x.concept_id and
			cr.relationship_id = 'Maps to'
		join concept ct on
			ct.concept_id = cr.concept_id_2 and
			ct.concept_class_id = 'Ingredient' and
			ct.standard_concept = 'S'
		) c2 on
	c2.concept_synonym_name ilike i.ing_name
;
insert into to_map
with bn as
	(
		select distinct mast_prd_name
		from belg_source
		where mast_prd_name is not null
	)
select
	i.mast_prd_name,
	'Brand Name',
	coalesce (c.concept_id,c2.concept_id),
	coalesce (c.concept_name,c2.concept_name),
	coalesce (c.concept_class_id,c2.concept_class_id) as concept_class_id,
	null,
	null
from bn i
left join r_to_c_all r on
	r.concept_class_id = 'Brand Name' and
	i.mast_prd_name = r.concept_name
left join concept c on
	r.concept_id = c.concept_id
left join concept c2 on
	upper (c2.concept_name) = i.mast_prd_name and
	c2.invalid_reason is null and
	c2.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
	c2.concept_class_id = 'Brand Name'
;
insert into to_map
with supp as
	(
		select distinct manufacturer_name
		from belg_source
		where manufacturer_name is not null
	)
select
	manufacturer_name,
	'Supplier',
	coalesce (c.concept_id,c2.concept_id),
	coalesce (c.concept_name,c2.concept_name),
	coalesce (c.concept_class_id,c2.concept_class_id) as concept_class_id,
	null,
	null
from supp i
left join r_to_c_all r on
	r.concept_class_id = 'Supplier' and
	i.manufacturer_name = r.concept_name
left join concept c on
	r.concept_id = c.concept_id
left join concept c2 on
	upper (c2.concept_name) = i.manufacturer_name and
	c2.invalid_reason is null and
	c2.vocabulary_id in ('RxNorm', 'RxNorm Extension') and
	c2.concept_class_id = 'Supplier'
;
insert into to_map
with unit as
	(
		SELECT UNIT_NAME1 AS NAME
		FROM belg_source d
		
		UNION
		
		SELECT UNIT_NAME2 AS NAME
		FROM belg_source d
		
		UNION
		
		SELECT UNIT_NAME3 AS NAME
		FROM belg_source d
	)
select
	NAME,
	'Unit',
	c.concept_id,
	c.concept_name,
	c.concept_class_id,
	null,
	coalesce (r.conversion_factor,1)
from unit i
left join r_to_c_all r on
	r.concept_class_id = 'Unit' and
	i.NAME = r.concept_name
left join concept c on
	r.concept_id = c.concept_id
where 
	name is not null and
	name != 'unknown'
;
insert into to_map
with forms as
	(
		select distinct drug_form
		from belg_source
	)
select distinct
	i.drug_form,
	'Dose Form',
	c.concept_id,
	c.concept_name,
	c.concept_class_id,
	r.precedence,
	null :: int4
from forms i
left join r_to_c_all r on
	r.concept_class_id = 'Dose Form' and
	i.drug_form = r.concept_name
left join concept c on
	r.concept_id = c.concept_id
where i.drug_form is not null
;
drop table if exists relationship_to_concept_to_map
;
create table relationship_to_concept_to_map as
select distinct
	source_attr_name,
	source_attr_concept_class,
	concept_id as target_concept_id,
	concept_name as target_concept_name,
	target_concept_class_id,
	precedence,
	conversion_factor,
	case
		when 
			source_attr_concept_class = 'Brand Name' and
			target_concept_class_id = 'Brand Name' and
			concept_id not in (select b_id from brand_rx)
		then '!'
		else null
	end :: varchar as invalid_indicator
from to_map
;
--Entry invalid_indicator means attribute should not be treated as such (ingredient as BN, excipient as ingredient)
--Multiple mappings for Ingredients with empty precedence fields indicate split
--Brand Names can (and should) be mapped to their Ingredients when BN mappings are not found
;
drop table if exists relationship_to_concept_manual
;
create table relationship_to_concept_manual as
select *
from relationship_to_concept_to_map
where false
;