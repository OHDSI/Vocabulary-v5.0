
update relationship_to_concept_manual
set precedence = 1 
where precedence is null
;
-- 	'OMOP' || nextval('conc_stage_seq') AS concept_code,
DROP SEQUENCE IF EXISTS conc_stage_seq;
CREATE sequence conc_stage_seq MINVALUE 100 MAXVALUE 1000000 START
	WITH 100 INCREMENT BY 1 CACHE 20;
;
--create table of relations from products to ingredients -- thorugh mappings or brand_rx
drop table if exists prod_to_ing
;
--mapped ingredients
create table prod_to_ing as
select distinct
	p.prod_prd_id,
	c.concept_id,
	precedence,
	comp_number
from p_to_i p
join relationship_to_concept_manual r on
	r.source_attr_name = p.ing_name and
	r.source_attr_concept_class = 'Ingredient' and
	r.invalid_indicator is null
join concept c on
	c.concept_id = r.target_concept_id and
	c.concept_class_id = 'Ingredient'
;
--handle drugs that have ingredients translated to CVX
insert into official_mappings
select
	b.prod_prd_id,
	r.target_concept_id
from belg_source b
join relationship_to_concept_manual r on
	b.mast_prd_name = r.source_attr_name and
	r.source_attr_concept_class = 'Ingredient'
join concept c on
	c.concept_class_id = 'CVX' and
	c.concept_id = r.target_concept_id
;
/*
delete from belg_source b
where
	b.prod_prd_id in
	(
		select i.prod_prd_id
		from p_to_i i 
		join relationship_to_concept_manual r on
			i.ing_name = r.source_attr_name and
			r.source_attr_concept_class = 'Ingredient'
		join concept c on
			c.concept_class_id = 'CVX' and
			c.concept_id = r.target_concept_id
	)
;*/
--brand names, mapped to ingredients
insert into prod_to_ing
select distinct
	b.prod_prd_id,
	c.concept_id,
	1,
	row_number () over (partition by b.prod_prd_id)
from belg_source b
join relationship_to_concept_manual r on
	b.mast_prd_name = r.source_attr_name and
	r.source_attr_concept_class = 'Brand Name'
join concept c on
	c.concept_id = r.target_concept_id and
	c.concept_class_id = 'Ingredient'
join drug_concept_stage s on
	b.prod_prd_id = s.concept_code and
	s.domain_id = 'Drug'
left join prod_to_ing p on
	p.prod_prd_id = b.prod_prd_id
where p.prod_prd_id is null
;
--brand names, translated to ingredients over brand_rx
insert into prod_to_ing
select distinct
	b.prod_prd_id,
	x.i_id,
	1,
	row_number () over (partition by b.prod_prd_id)
from belg_source b
join relationship_to_concept_manual r on
	b.mast_prd_name = r.source_attr_name and
	r.source_attr_concept_class = 'Brand Name'
join brand_rx x on
	x.b_id = r.target_concept_id
join drug_concept_stage s on
	b.prod_prd_id = s.concept_code and
	s.domain_id = 'Drug'
left join prod_to_ing p on
	p.prod_prd_id = b.prod_prd_id
where p.prod_prd_id is null
;
--deal with brand names mapped over to CVX
insert into official_mappings
select
	b.prod_prd_id,
	r.target_concept_id
from belg_source b
join relationship_to_concept_manual r on
	b.mast_prd_name = r.source_attr_name and
	r.source_attr_concept_class = 'Brand Name'
join concept c on
	c.concept_class_id = 'CVX' and
	c.concept_id = r.target_concept_id
;
/*delete from belg_source b
where
	b.mast_prd_name in
	(
		select r.source_attr_name
		from relationship_to_concept_manual r 
		join concept c on
			b.mast_prd_name = r.source_attr_name and
			r.source_attr_concept_class = 'Brand Name' and
			c.concept_class_id = 'CVX' and
			c.concept_id = r.target_concept_id
	)
;*/
--save existing relation to ingredient for concepts that were only mapped to ingredient (legacy mappings, lowest precedence)
insert into prod_to_ing
with dirty as
	(
		select
			a.prod_prd_id,
			r.concept_id_2,
			1 as precedence, --direct mapping in last release
			row_number () over (partition by a.prod_prd_id) as comp
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
			c2.concept_class_id = 'Ingredient'
		left join prod_to_ing o using (prod_prd_id)
		left join devices_mapped x using (prd_name)
		left join junk_drugs j using (prd_name)
		where
			o.prod_prd_id is null and
			a.prd_name is null
	)
--keep only those that have less than 4 ingredients
select *
from dirty d
where
	d.prod_prd_id not in
	(
		select prod_prd_id
		from dirty
		where comp = 4
	)
;
--create attributes from relationship_to_concept_manual table
with ingredients as
	(
		select distinct prod_prd_id || ':' || comp_number as component_alias
		from prod_to_ing
	)
insert into drug_concept_stage
select
	component_alias,
	'LPD_Belgium',
	'Ingredient',
	'Ingredient',
	'S',
	'OMOP' || nextval('conc_stage_seq') AS concept_code,
	null,
	'Drug',
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
from ingredients i
;
insert into drug_concept_stage
with monomapped as --conventional brand names, suppliers, dose forms
	(
		select distinct
			r.source_attr_name,
			r.source_attr_concept_class
		from relationship_to_concept_manual r
		join concept c on
			c.concept_id = r.target_concept_id
		where
			r.invalid_indicator is null and
			r.source_attr_concept_class = c.concept_class_id and
			r.source_attr_concept_class in ('Brand Name','Supplier','Dose Form') --not crossmaped to ingredient/CVX
	)
select distinct
	i.source_attr_name :: varchar,
	'LPD_Belgium',
	i.source_attr_concept_class,
	i.source_attr_concept_class,
	null,
	'OMOP' || nextval('conc_stage_seq') AS concept_code,
	null,
	'Drug',
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
from monomapped i
;
--Units
insert into drug_concept_stage
select distinct
	r.source_attr_name :: varchar, --they are temporary and only needed once, so we use concept_ids to save mappings here
	'LPD_Belgium',
	'Unit',
	'Unit',
	null,
	r.source_attr_name AS concept_code,
	null,
	'Drug',
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
from relationship_to_concept_manual r
where r.source_attr_concept_class in ('Unit')
;
truncate table internal_relationship_stage
;
--dose forms
insert into internal_relationship_stage
select distinct
	b.prod_prd_id,
	c.concept_code
from belg_source b
join drug_concept_stage c on
	c.concept_class_id = 'Dose Form' and
	c.concept_name = b.drug_form
left join devices_mapped d on
	d.prd_name = b.prd_name
left join junk_drugs j on j.prd_name = b.prd_name
where d.prd_name is null
and j.prd_name is null
;
--supplier
insert into internal_relationship_stage
select
	b.prod_prd_id,
	c.concept_code
from belg_source b
join drug_concept_stage c on
	c.concept_class_id = 'Supplier' and
	c.concept_name = b.manufacturer_name
left join devices_mapped d on
	d.prd_name = b.prd_name
	left join junk_drugs j on j.prd_name = b.prd_name
where d.prd_name is null and j.prd_name is null
;
--brand name
insert into internal_relationship_stage
select
	b.prod_prd_id,
	c.concept_code
from belg_source b
join drug_concept_stage c on
	c.concept_class_id = 'Brand Name' and
	c.concept_name = b.mast_prd_name
left join devices_mapped d on
	d.prd_name = b.prd_name
	left join junk_drugs j on j.prd_name = b.prd_name
where d.prd_name is null and j.prd_name is null
;
--ingredients
insert into internal_relationship_stage
select distinct
	p.prod_prd_id,
	d.concept_code
from prod_to_ing p
join drug_concept_stage d on
	d.concept_name = p.prod_prd_id || ':' || p.comp_number and
	d.concept_class_id = 'Ingredient'
;
--relationship_to_concept
truncate relationship_to_concept
;
insert into relationship_to_concept
select distinct
	c.concept_code,
	c.vocabulary_id,
	r.target_concept_id,
	r.precedence,
	r.conversion_factor
from relationship_to_concept_manual r
join drug_concept_stage c on
--Unmappable Brand Names already excluded
	c.concept_class_id = r.source_attr_concept_class and
	c.concept_name = r.source_attr_name
where
	r.source_attr_concept_class in ('Supplier', 'Unit', 'Dose Form','Brand Name') and
	r.target_concept_id is not null and
	r.invalid_indicator is null
;
--Ingredients
insert into relationship_to_concept
select distinct
	d.concept_code,
	d.vocabulary_id,
	p.concept_id,
	p.precedence,
	null :: int4
from prod_to_ing p
join drug_concept_stage d on
	d.concept_name = p.prod_prd_id || ':' || p.comp_number and
	d.concept_class_id = 'Ingredient'
;
drop table if exists guess_bn
;
--add guessed brand names
create table guess_bn as
select distinct
	b.prod_prd_id,
	r.b_id
from belg_source b
join brand_rx r on
	b.prd_name ilike r.concept_name || ' %'
join prod_to_ing i on
	b.prod_prd_id = i.prod_prd_id
where b.prod_prd_id not in
	(
		select concept_code_1
		from internal_relationship_stage
		join drug_concept_stage on
			concept_code_2 = concept_code and
			concept_class_id = 'Brand Name'
	)
;
delete from guess_bn
where prod_prd_id in
	(
		select prod_prd_id
		from guess_bn
		group by prod_prd_id
		having count (b_id) > 1
	)
;
insert into drug_concept_stage
with bn_set as --newly found bns
	(
		select distinct b_id
		from guess_bn
	)
select distinct
	b_id :: varchar,
	'LPD_Belgium',
	'Brand Name',
	'Brand Name',
	null,
	'OMOP' || nextval('conc_stage_seq') AS concept_code,
	null,
	'Drug',
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
from bn_set
;
insert into internal_relationship_stage
select distinct
	g.prod_prd_id,
	c.concept_code
from guess_bn g
join drug_concept_stage c on
	c.concept_class_id = 'Brand Name' and
	g.b_id :: varchar = c.concept_name
;
insert into relationship_to_concept
select distinct
	c.concept_code,
	c.vocabulary_id,
	c.concept_name :: int4,
	1
from drug_concept_stage c
join guess_bn g on
	c.concept_class_id = 'Brand Name' and
	g.b_id :: varchar = c.concept_name
;
truncate ds_stage
;
INSERT INTO ds_stage
WITH a AS (
		SELECT prod_prd_id
		FROM prod_to_ing
		GROUP BY prod_prd_id
		HAVING count(distinct comp_number) = 1
		),
	SIMPLE AS (
		SELECT d.*
		FROM belg_source d
		JOIN a ON a.prod_prd_id = d.prod_prd_id
		WHERE (
				d.prd_dosage != '0'
				OR d.prd_dosage2 != '0'
				OR d.prd_dosage3 != '0'
				)
			AND d.unit_name1 NOT LIKE '%!%%' ESCAPE '!'
			AND (
				d.unit_name1 NOT LIKE '%/%'
				OR unit_name1 = '% v/v'
				)
			AND d.prd_name NOT IN (
				SELECT *
				FROM devices_mapped
				)
				and d.prd_name not in (SELECT *
				FROM junk_drugs)
		),
	percents AS (
		SELECT d.*
		FROM belg_source d
		JOIN a ON a.prod_prd_id = d.prod_prd_id
		WHERE (
				d.prd_dosage != '0'
				OR d.prd_dosage2 != '0'
				OR d.prd_dosage3 != '0'
				)
			AND d.unit_name1 = '%'
			AND d.prd_name NOT IN (
				SELECT *
				FROM devices_mapped
				)
				AND d.prd_name NOT IN (
				SELECT *
				FROM junk_drugs
				)
		),
	transderm AS (
		SELECT d.*
		FROM belg_source d
		JOIN a ON a.prod_prd_id = d.prod_prd_id
		WHERE (
				d.prd_dosage != '0'
				OR d.prd_dosage2 != '0'
				OR d.prd_dosage3 != '0'
				)
			AND d.unit_name1 LIKE 'm_g/%h'
			AND d.prd_name NOT IN (
				SELECT *
				FROM devices_mapped
				)
				AND d.prd_name NOT IN (
				SELECT *
				FROM junk_drugs
				)
		)
SELECT c1.concept_code AS drug_concept_code,
	c2.concept_code AS ingredient_concept_code,
	NULL::INT AS box_size,
	/*replace(SIMPLE.prd_dosage, ',', '.')::FLOAT*/prd_dosage AS amount_value,
	SIMPLE.unit_name1 AS amount_unit,
	NULL AS numerator_value,
	NULL AS numerator_unit,
	NULL AS denominator_value,
	NULL AS denominator_unit
FROM SIMPLE
JOIN drug_concept_stage c1 ON SIMPLE.prod_prd_id = c1.concept_code
	AND concept_class_id = 'Drug Product'
JOIN prod_to_ing p ON p.prod_prd_id = SIMPLE.prod_prd_id
JOIN drug_concept_stage c2 ON p.prod_prd_id || ':' || p.comp_number = c2.concept_name

UNION

SELECT c1.concept_code AS drug_concept_code,
	c2.concept_code AS ingredient_concept_code,
	NULL AS box_size,
	NULL AS amount_value,
	NULL AS amount_unit,
	10 * percents.prd_dosage /*(replace(percents.prd_dosage, ',', '.')::FLOAT)*/ AS numerator_value,
	'mg' AS denominator_unit, --mg
	null::FLOAT AS numerator_value,
	'ml' AS denominator_unit --ml
FROM percents
JOIN drug_concept_stage c1 ON percents.prod_prd_id = c1.concept_code
	AND concept_class_id = 'Drug Product'
JOIN prod_to_ing p ON p.prod_prd_id = percents.prod_prd_id
JOIN drug_concept_stage c2 ON p.prod_prd_id || ':' || p.comp_number = c2.concept_name

UNION

SELECT c1.concept_code AS drug_concept_code,
	c2.concept_code AS ingredient_concept_code,
	NULL AS box_size,
	transderm.prd_dosage/*replace(transderm.prd_dosage, ',', '.')::FLOAT*/ AS amount_value,
	CASE 
		WHEN transderm.unit_id LIKE 'mg%'
			THEN 'mg' --mg
		ELSE 'mcg' --mcg
		END AS amount_unit,
	NULL AS numerator_value,
	NULL AS denominator_unit,
	NULL AS numerator_value,
	NULL AS denominator_unit
FROM transderm
JOIN drug_concept_stage c1 ON transderm.prd_name = c1.concept_name
	AND concept_class_id = 'Drug Product'
JOIN prod_to_ing p ON p.prod_prd_id = transderm.prod_prd_id
JOIN drug_concept_stage c2 ON p.prod_prd_id || ':' || p.comp_number = c2.concept_name
;
--GUESSWORK AND PARSING
--guess forms
INSERT INTO internal_relationship_stage
with assume as
(
	SELECT DISTINCT prod_prd_id,
		CASE 
			WHEN prd_name LIKE '%INJECT%'
				OR prd_name LIKE '%SERINGU%'
				OR prd_name LIKE '%STYLO%'
				OR prd_name LIKE '% INJ %'
				THEN (select concept_code from drug_concept_stage where concept_name = 'flac. pour injection' and concept_class_id = 'Dose Form') --solution injectable
			WHEN prd_name LIKE '%POUR SUSPE%'
				THEN (select concept_code from drug_concept_stage where concept_name = 'sirop.' and concept_class_id = 'Dose Form') --suspension
			WHEN prd_name LIKE '%COMPRI%'
				OR prd_name LIKE '%TABS %'
				OR prd_name LIKE '% DRAG%'
				THEN (select concept_code from drug_concept_stage where concept_name = 'compr.' and concept_class_id = 'Dose Form') --tablets
			WHEN prd_name LIKE '%GELUL%'
				OR prd_name LIKE '%CAPS %'
				or (prd_name like '% GEL %' and prd_name not like '%ML%' and regexp_match (prd_name,' \d*G( |$)') is null)
				THEN (select concept_code from drug_concept_stage where concept_name = 'gélule(s)' and concept_class_id = 'Dose Form') --caps
			WHEN prd_name LIKE '%SPRAY%'
				THEN (select concept_code from drug_concept_stage where concept_name = 'spray nasal' and concept_class_id = 'Dose Form') --spray
			WHEN prd_name LIKE '%CREME%'
				OR prd_name LIKE '%CREAM%'
				or prd_name LIKE '%POMM%'
				THEN (select concept_code from drug_concept_stage where concept_name = 'crème' and concept_class_id = 'Dose Form') --cream
			WHEN prd_name LIKE '%LAVEMENTS%'
				OR prd_name LIKE '%LAVEMENTS%'
				THEN (select concept_code from drug_concept_stage where concept_name = 'suppos.' and concept_class_id = 'Dose Form') --suppos
			WHEN prd_name LIKE '%INHALAT%'
				THEN (select concept_code from drug_concept_stage where concept_name = 'inhalation' and concept_class_id = 'Dose Form') --suppos
			WHEN prd_name LIKE '% COMP%'
				OR prd_name LIKE '%TAB%'
				THEN (select concept_code from drug_concept_stage where concept_name = 'compr.' and concept_class_id = 'Dose Form') --tablets
			WHEN prd_name LIKE '%PERFUS%'
				THEN (select concept_code from drug_concept_stage where concept_name = 'flac. pour injection' and concept_class_id = 'Dose Form') --solution injectable
			WHEN prd_name LIKE '%BUCCAL%'
				or prd_name like '%SIROP%'
				THEN (select concept_code from drug_concept_stage where concept_name = 'amp. buvable(s)' and concept_class_id = 'Dose Form') --solution injectable
			ELSE null
			END as concept_code_2
	FROM belg_source
	WHERE
		prod_prd_id NOT IN 
			(
				SELECT concept_code_1
				FROM internal_relationship_stage
				join drug_concept_stage on concept_code_2 = concept_code
				WHERE concept_class_id = 'Dose Form'
			) and
		prod_prd_id IN
			(
				SELECT concept_code_1
				FROM internal_relationship_stage
				join drug_concept_stage on concept_code_2 = concept_code
				WHERE concept_class_id = 'Ingredient'
			)
)
select *
from assume
where concept_code_2 is not null
;
DROP TABLE IF EXISTS map_auto;
CREATE TABLE map_auto AS
		WITH unmapped AS (
				SELECT DISTINCT 
					d.prod_prd_id,
					regexp_replace(d.prd_name, ' (\d+) (\d+ ?(MG|MCG|G(?![A-Z])|UI|IU|ML))', ' \1.\2', 'g') AS fixed_name,
					x.concept_code as component
				FROM belg_source d
				JOIN prod_to_ing c ON c.prod_prd_id = d.prod_prd_id
				join drug_concept_stage x on
					c.prod_prd_id || ':' || c.comp_number = x.concept_name and
					x.concept_class_id = 'Ingredient'
				WHERE 
					d.prod_prd_id NOT IN
						(
							SELECT drug_concept_code
							FROM ds_stage
						)
					AND d.prd_name NOT IN
						(
							SELECT prd_name
							FROM devices_mapped
						)
							AND d.prd_name NOT IN
						(
							SELECT prd_name
							FROM junk_drugs
						)
					AND regexp_match (d.prd_name, '(X| )\d+ ?(MG|MCG|G(?![A-Z])|UI|IU)( |$)') is not null
					AND (ARRAY(SELECT unnest(regexp_matches(d.prd_name, '((?:\d+)\.?(?:\d+)? ?(?:MCG|MG|G(?![A-Z])|UI|IU) )', 'g')))) [3] IS NULL
				),
			list AS ( --only 1 or 2 ingredient drugs can be processed this way; more is unreliable
				SELECT prod_prd_id
				FROM unmapped
				GROUP BY prod_prd_id
				HAVING count(component) < 3
				)

	SELECT DISTINCT
		u.prod_prd_id,
		u.fixed_name,
	-- amount 1
		substring (u.fixed_name, '[\d\.]+(?= ?(MG|MCG|G(?![A-Z])|UI|IU))') :: float AS a1,
	-- unit 1
		lower (substring (u.fixed_name, '(?<=[\d\.]+ ?)(MG|MCG|G(?![A-Z])|UI|IU)')) AS u1,
	-- dosage 2
		substring (u.fixed_name, '(?<=[\d\.]+ ?(MG|MCG|G(?![A-Z])|UI|IU).*)[\d\.]+(?= ?(MG|MCG|G(?![A-Z])|UI|IU))') :: float AS a2,
	-- unit 2
		lower (substring (u.fixed_name, '(?<=[\d\.]+ ?(MG|MCG|G(?![A-Z])|UI|IU).*[\d\.]+ ?)(MG|MCG|G(?![A-Z])|UI|IU)')) AS u2,
		min(u.component) OVER (PARTITION BY u.prod_prd_id) AS i1,
		max(u.component) OVER (PARTITION BY u.prod_prd_id) AS i2
	FROM unmapped u
	WHERE prod_prd_id IN (
			SELECT *
			FROM list
			);

UPDATE map_auto
SET i2 = NULL
WHERE i1 = i2
;
--only one dosage for multiple ingredients
delete from map_auto
where
	i2 is not null and
	u2 is null
;
--extract units and values for denominators
ALTER TABLE map_auto 
	ADD DV float,
	ADD DU varchar;
;
update map_auto
set	DU = 'ml'
where fixed_name ~ '(?<=([\d|\.]+)| )ML( |$)'
;
update map_auto
set	DU = 'ml' -- more common
where 
	fixed_name ~ '(?<=([\d|\.]+)| )G(?![A-Z])' and
	u1 != 'g' and
	coalesce (u2,'OK') != 'g'
;
update map_auto
set	DU = 'actuat'
where 
	fixed_name ~ '(?<=([\d|\.]+)| )DOS( |$)'
;
--if actuation not in dcs, add it
insert into drug_concept_stage
select 'actuat', 'LPD_Belgium','Unit','Unit',null,'actuat',null,'Drug', CURRENT_DATE, TO_DATE('20991231', 'yyyymmdd'), null
where not exists
	(select from drug_concept_stage where (concept_code, concept_class_id) = ('actuat','Unit'))
;
insert into relationship_to_concept
select 'actuat', 'LPD_Belgium',45744809,1,1
where not exists
	(select from relationship_to_concept where (concept_code_1 = 'actuat'))
;
update map_auto
set	DV = substring (fixed_name, '[\d+\.]+(?= ?(ML|G(?!EL)|DOS))') :: float
where DU is not null
;
UPDATE map_auto
SET u1 = 'IU'
WHERE u1 in ('ui','iu');

UPDATE map_auto
SET u2 = 'IU'
WHERE u2 in ('ui','iu');

--get rid of artifacts
delete from map_auto
where
	prod_prd_id in
	(
		select prod_prd_id
		from map_auto
		where 0 in (a1,a2,dv)
	)
;
--monocomponent amounts
INSERT INTO ds_stage
SELECT
	m.prod_prd_id,
	m.i1,
	NULL,
	A1,
	U1,
	NULL,
	NULL,
	NULL,
	NULL
FROM map_auto m
where
	i2 IS NULL and
	du is null
;
--monocomponent numerators
INSERT INTO ds_stage
SELECT
	m.prod_prd_id,
	m.i1,
	NULL,
	null,
	null,
	m.a1,
	m.u1,
	m.dv,
	m.du
FROM map_auto m
where
	i2 IS NULL and
	du is not null
;
--to simplify processing
delete from map_auto
where prod_prd_id in (select drug_concept_code from ds_stage)
;
drop table if exists ma_match
;
--find passing combination of components -- amount only
create table ma_match as
with ma_dosages as
	(
		select 
			m.prod_prd_id,
			m.a1 as source_amount_value,
			m.u1 as source_amount_unit,
			m.a1 * r.conversion_factor as rx_amount_value,
			r.concept_id_2 as rx_amount_unit
		from map_auto m
		join relationship_to_concept r on --transform unit
			r.concept_code_1 = m.u1
		where du is null
		
			union
			
		select 
			m.prod_prd_id,
			m.a2 as source_amount_value,
			m.u2 as source_amount_unit,
			m.a2 * r.conversion_factor as rx_amount_value,
			r.concept_id_2 as rx_amount_unit_id
		from map_auto m
		join relationship_to_concept r on --transform unit
			r.concept_code_1 = m.u2
		where du is null
	),
	ma_ingredients as
	(
		select
			m.prod_prd_id,
			i1 as source_ingredient_concept_code,
			r.concept_id_2 as ingredient_concept_id,
			r.precedence
		from map_auto m
		join relationship_to_concept r on --transform ingredient
			r.concept_code_1 = i1
		where du is null

			union

		select
			m.prod_prd_id,
			i2 as source_ingredient_concept_code,
			r.concept_id_2 as ingredient_concept_id,
			r.precedence
		from map_auto m
		join relationship_to_concept r on --transform ingredient
			r.concept_code_1 = i2
		where du is null
	),
ds_ex as
	(
		select
			d.drug_concept_id,
			d.ingredient_concept_id,
			d.amount_value,
			d.amount_unit_concept_id
		from drug_strength d
		join concept c on
			d.drug_concept_id = c.concept_id and
			c.standard_concept = 'S' and
			c.concept_class_id = 'Clinical Drug' and
			d.amount_value is not null and
			d.invalid_reason is null
		--2-component drugs only
		where
			d.drug_concept_id in
				(
					select drug_concept_id
					from drug_strength
					where invalid_reason is null
					group by drug_concept_id
					having count (ingredient_concept_id) = 2
				)
	)
select distinct i.prod_prd_id, i.source_ingredient_concept_code, i.precedence, d.source_amount_value, d.source_amount_unit, e.drug_concept_id
from ma_ingredients i
join ma_dosages d on
	i.prod_prd_id = d.prod_prd_id
--get existing combinations
join ds_ex e on
	e.ingredient_concept_id = i.ingredient_concept_id and
	d.rx_amount_value = e.amount_value and
	d.rx_amount_unit = e.amount_unit_concept_id
;
delete from ma_match --delete unmatched component combinations
where
	(prod_prd_id, drug_concept_id) not in
	( 
		select prod_prd_id, drug_concept_id
		from ma_match
		group by prod_prd_id, drug_concept_id
		having count (source_ingredient_concept_code) = 2
	)
;
delete from ma_match --delete varying component combinations (where is still not possible to guess which ingredient has which dosage)
where
	(prod_prd_id) not in
	( 
		select prod_prd_id
		from ma_match
		group by prod_prd_id
		having count (distinct source_ingredient_concept_code || '/' || source_amount_value || '/' || source_amount_unit) = 2
	)
;
insert into ds_stage (drug_concept_code, ingredient_concept_code, amount_value, amount_unit)
select distinct
	prod_prd_id,
	source_ingredient_concept_code,
	source_amount_value,
	source_amount_unit
from ma_match
;
--to simplify processing
delete from map_auto
where prod_prd_id in (select drug_concept_code from ds_stage)
;
drop table if exists ma_match
;
--find passing combination of components -- num/denom
create table ma_match as
with ma_dosages as
	(
		select 
			m.prod_prd_id,
			m.a1 as source_numerator_value,
			m.u1 as source_numerator_unit,
			m.dv as source_denominator_value,
			m.du as source_denominator_unit,
			m.a1 * r1.conversion_factor as rx_numerator_value,
			r1.concept_id_2 as rx_numerator_unit,
			m.dv * r2.conversion_factor as rx_denominator_value,
			r2.concept_id_2 as rx_denominator_unit
		from map_auto m
		join relationship_to_concept r1 on --transform num unit
			r1.concept_code_1 = m.u1
		join relationship_to_concept r2 on --transform den unit
			r2.concept_code_1 = m.du
		where du is not null
		
			union
			
		select 
			m.prod_prd_id,
			m.a2 as source_numerator_value,
			m.u2 as source_numerator_unit,
			m.dv as source_denominator_value,
			m.du as source_denominator_unit,
			m.a2 * r1.conversion_factor as rx_numerator_value,
			r1.concept_id_2 as rx_numerator_unit,
			m.dv * r2.conversion_factor as rx_denominator_value,
			r2.concept_id_2 as rx_denominator_unit
		from map_auto m
		join relationship_to_concept r1 on --transform num unit
			r1.concept_code_1 = m.u2
		join relationship_to_concept r2 on --transform den unit
			r2.concept_code_1 = m.du
		where du is not null
	),
	ma_ingredients as
	(
		select
			m.prod_prd_id,
			i1 as source_ingredient_concept_code,
			r.concept_id_2 as ingredient_concept_id,
			r.precedence
		from map_auto m
		join relationship_to_concept r on --transform ingredient
			r.concept_code_1 = i1
		where du is not null

			union

		select
			m.prod_prd_id,
			i2 as source_ingredient_concept_code,
			r.concept_id_2 as ingredient_concept_id,
			r.precedence
		from map_auto m
		join relationship_to_concept r on --transform ingredient
			r.concept_code_1 = i2
		where du is not null
	),
ds_ex as
	(
		select
			d.drug_concept_id,
			d.ingredient_concept_id,
			d.numerator_value,
			d.numerator_unit_concept_id,
			d.denominator_value,
			d.denominator_unit_concept_id
		from drug_strength d
		join concept c on
			d.drug_concept_id = c.concept_id and
			c.standard_concept = 'S' and
			c.concept_class_id in ('Clinical Drug','Quant Clinical Drug') and
			d.numerator_value is not null and
			d.invalid_reason is null
		--2-component drugs only
		where
			d.drug_concept_id in
				(
					select drug_concept_id
					from drug_strength
					where invalid_reason is null
					group by drug_concept_id
					having count (ingredient_concept_id) = 2
				)
	)
select distinct i.prod_prd_id, i.source_ingredient_concept_code, i.precedence, d.source_numerator_value, d.source_numerator_unit, d.source_denominator_value, d.source_denominator_unit, e.drug_concept_id
from ma_ingredients i
join ma_dosages d on
	i.prod_prd_id = d.prod_prd_id
--get existing combinations
join ds_ex e on
	e.ingredient_concept_id = i.ingredient_concept_id and
	d.rx_numerator_value = e.numerator_value and
	d.rx_numerator_unit = e.numerator_unit_concept_id and
	coalesce (d.rx_denominator_value,0) = coalesce (e.denominator_value,0) and -- 0 can exist only in case of null
	d.rx_denominator_unit = e.denominator_unit_concept_id
;
delete from ma_match --delete unmatched component combinations
where
	(prod_prd_id, drug_concept_id) not in
	( 
		select prod_prd_id, drug_concept_id
		from ma_match
		group by prod_prd_id, drug_concept_id
		having count (source_ingredient_concept_code) = 2
	)
;
delete from ma_match --delete varying component combinations (where is still not possible to guess which ingredient has which dosage)
where
	(prod_prd_id) not in
	( 
		select prod_prd_id
		from ma_match
		group by prod_prd_id
		having count (distinct source_ingredient_concept_code || '/' || source_numerator_value || '/' || source_numerator_unit || '/' || coalesce (source_denominator_value,0) || '/' || source_denominator_unit) = 2
	)
;
insert into ds_stage (drug_concept_code, ingredient_concept_code, numerator_value, numerator_unit, denominator_value, denominator_unit)
select distinct
	prod_prd_id,
	source_ingredient_concept_code,
	source_numerator_value,
	source_numerator_unit,
	source_denominator_value,
	source_denominator_unit
from ma_match
;
--save updated mappings in r_to_c_all
drop table if exists r_to_c_insert
;
--get entire list and fill it using relationship_to_concept table
create table r_to_c_insert as 
select * from r_to_c_all
where false
;
insert into r_to_c_insert
select
	d.concept_name,
	d.concept_class_id,
	r.concept_id_2 as concept_id,
	r.precedence,
	r.conversion_factor
from drug_concept_stage d
join relationship_to_concept r on
	r.concept_code_1 = d.concept_code
where
	d.concept_class_id in ('Supplier','Unit','Dose Form','Brand Name')
;
--ingredients are preserved separately
insert into r_to_c_insert
select
	source_attr_name,
	source_attr_concept_class,
	target_concept_id,
	precedence,
	conversion_factor
from relationship_to_concept_manual
where
	source_attr_concept_class = 'Ingredient' and
	target_concept_id is not null and
	invalid_indicator is null
;
--replace old mappings that were changed in manual tables

delete from r_to_c_all
where
	(concept_name, concept_class_id) in
	(
		select concept_name, concept_class_id
		from r_to_c_insert
	)
;
insert into r_to_c_all
select * from r_to_c_insert
;

delete from ds_stage where drug_concept_code in (SELECT drug_concept_code
		FROM ds_stage
		join relationship_to_concept on
			concept_code_1 in (numerator_unit,amount_unit) and
			concept_id_2 = 8587)
;



delete from internal_relationship_stage where concept_code_1 in (
select concept_code_1 from internal_relationship_stage 
join drug_concept_stage on concept_code_2 = concept_code and concept_class_id = 'Supplier'
where concept_code_1 in (	SELECT concept_code
		FROM drug_concept_stage dcs
		JOIN (
			SELECT concept_code_1
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Supplier'
			LEFT JOIN ds_stage ON drug_concept_code = concept_code_1
			WHERE drug_concept_code IS NULL

			UNION

			SELECT concept_code_1
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Supplier'
			WHERE concept_code_1 NOT IN (
					SELECT concept_code_1
					FROM internal_relationship_stage
					JOIN drug_concept_stage ON concept_code_2 = concept_code
						AND concept_class_id = 'Dose Form'
					)
			) s
		        ON s.concept_code_1 = dcs.concept_code
		WHERE dcs.concept_class_id = 'Drug Product'
			AND dcs.invalid_reason IS NULL
			and s.concept_code_1 not in (select pack_concept_code from pc_stage)))
			and concept_code_2 in (select concept_code_2 from internal_relationship_stage 
join drug_concept_stage on concept_code_2 = concept_code and concept_class_id = 'Supplier'
where concept_code_1 in (	SELECT concept_code
		FROM drug_concept_stage dcs
		JOIN (
			SELECT concept_code_1
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Supplier'
			LEFT JOIN ds_stage ON drug_concept_code = concept_code_1
			WHERE drug_concept_code IS NULL

			UNION

			SELECT concept_code_1
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Supplier'
			WHERE concept_code_1 NOT IN (
					SELECT concept_code_1
					FROM internal_relationship_stage
					JOIN drug_concept_stage ON concept_code_2 = concept_code
						AND concept_class_id = 'Dose Form'
					)
			) s
		        ON s.concept_code_1 = dcs.concept_code
		WHERE dcs.concept_class_id = 'Drug Product'
			AND dcs.invalid_reason IS NULL
			and s.concept_code_1 not in (select pack_concept_code from pc_stage)));



