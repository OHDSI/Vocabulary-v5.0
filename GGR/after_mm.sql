/**************************************************************************/
--split relationship_to_concept_manual back into tomap_tables
truncate tomap_unit;
truncate tomap_form;
truncate tomap_supplier;
truncate tomap_ingred;
truncate tomap_bn;
truncate tofix_vax;
;
insert into tomap_unit
select 
	source_concept_code,
	target_concept_id,
	target_concept_name,
	conversion_factor
from relationship_to_concept_manual
where source_concept_class_id = 'Unit'
;
insert into tomap_form
select
	source_concept_code,
	source_concept_desc,
	source_concept_name,
	target_concept_id,
	target_concept_name,
	precedence	
from relationship_to_concept_manual
where source_concept_class_id = 'Dose Form'
;
insert into tomap_supplier
select
	source_concept_code,
	source_concept_name,
	target_concept_id,
	target_concept_name
from relationship_to_concept_manual
where source_concept_class_id = 'Supplier'
;
insert into tomap_ingred
select
	source_concept_code,
	source_concept_name,
	target_concept_id,
	target_concept_name,
	precedence
from relationship_to_concept_manual
where source_concept_class_id = 'Ingredient'
;
insert into tomap_bn
select
	source_concept_code,
	source_concept_name,
	target_concept_id,
	target_concept_name,
	source_concept_desc,
	invalid_indicator
from relationship_to_concept_manual
where source_concept_class_id = 'Brand Name'
;
insert into tofix_vax
select
	r.source_concept_code,
	r.source_concept_name,
	c.concept_id,
	c.concept_name,
	c.concept_class_id,
	c.vocabulary_id
from relationship_to_concept_manual r
join concept c on r.target_concept_id = c.concept_id
where source_concept_class_id = 'Drug Product'
;
TRUNCATE TABLE relationship_to_concept;
INSERT INTO relationship_to_concept --Measurement Units
SELECT DISTINCT concept_code AS CONCEPT_CODE_1,
	'GGR' AS VOCABULARY_ID_1,
	concept_ID AS CONCEPT_ID_2,
	1 AS PRECEDENCE,
	coalesce(CONVERSION_FACTOR, 1) AS CONVERSION_FACTOR
FROM tomap_unit;

INSERT INTO relationship_to_concept --Dose Forms
SELECT DISTINCT concept_code AS CONCEPT_CODE_1,
	'GGR' AS VOCABULARY_ID_1,
	mapped_id AS CONCEPT_ID_2,
	coalesce(precedence, 1) AS PRECEDENCE,
	NULL::FLOAT AS CONVERSION_FACTOR
FROM tomap_form;

INSERT INTO relationship_to_concept -- Suppliers
SELECT DISTINCT concept_code AS CONCEPT_CODE_1,
	'GGR' AS VOCABULARY_ID_1,
	mapped_id AS CONCEPT_ID_2,
	1 AS PRECEDENCE,
	NULL::FLOAT AS CONVERSION_FACTOR
FROM tomap_supplier
WHERE mapped_id IS NOT NULL;

INSERT INTO relationship_to_concept -- Brand names
SELECT DISTINCT concept_code AS CONCEPT_CODE_1,
	'GGR' AS VOCABULARY_ID_1,
	mapped_id AS CONCEPT_ID_2,
	1 AS PRECEDENCE,
	NULL::FLOAT AS CONVERSION_FACTOR
FROM tomap_bn
WHERE mapped_id IS NOT NULL;
/*
-- will contain only duplicate replacements for clean creation of internal_relationship_stage and ds_stage  
DROP TABLE IF EXISTS dupe_fix;
CREATE TABLE dupe_fix AS

SELECT rm.concept_code AS concept_code_1,
	mb.concept_code AS concept_code_2
FROM drug_concept_stage rm
JOIN tomap_bn mb ON rm.concept_name = mb.concept_name
	AND rm.concept_code != mb.concept_code;
	select * from dupe_fix
	join ggr_mp a on 'mp'||a.mpcv = concept_code_1
	join ggr_mp b on 'mp'||b.mpcv = concept_code_2;
*/
;
-- Rename Dose Forms
-- update drug_concept_stage d
-- set concept_name = (select distinct concept_name_en from tomap_form where concept_name_nl = d.concept_name and (precedence is null or precedence = 1)) 
-- where d.concept_class_id = 'Dose Form'
;
--ingredients splitter
--some source given ingredients are actually a combination of 2 or more
drop table if exists ing_split
;
create table ing_split as
select 
	concept_code as mix_code,
	concept_name as mix_name,
	null :: varchar as ingredient_code,
	mapped_name as ingredient_name,
	mapped_id
from tomap_ingred
where 
	precedence is null and
	concept_code in
		(
			select concept_code
			from tomap_ingred
			group by concept_code
			having count (mapped_id) > 1
		)
;
with name_to_code as
	(
		select mapped_id, 'OMOP' || nextval ('new_vocab') as ingredient_code
		from (select distinct mapped_id from ing_split) i
	)
update ing_split x
set ingredient_code = (select distinct ingredient_code from name_to_code where mapped_id = x.mapped_id)
;
INSERT INTO relationship_to_concept -- Ingredients
SELECT DISTINCT concept_code AS CONCEPT_CODE_1,
	'GGR' AS VOCABULARY_ID_1,
	mapped_id AS CONCEPT_ID_2,
	coalesce(precedence, 1) AS PRECEDENCE,
	NULL::FLOAT AS CONVERSION_FACTOR
FROM tomap_ingred
WHERE 
	mapped_id IS NOT NULL and
	concept_code not in
	(
		select mix_code
		from ing_split
	)
;
insert into drug_concept_stage
select distinct 
	ingredient_name AS concept_name,
	'GGR' AS vocabulary_ID,
	'Ingredient' AS concept_class_id,
	'Ingredient' AS source_concept_class_id,
	'S' AS standard_concept,
	ingredient_code AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM ing_split
;
insert into relationship_to_concept
select distinct
	ingredient_code,
	'GGR',
	mapped_id,
	1,
	null :: float
from ing_split 
;

/*
--Reaction to 'n' and 'g' marks and renaming:
UPDATE drug_concept_stage
SET invalid_reason = 'T'
WHERE concept_code IN (
		SELECT concept_code
		FROM tomap_ingred
		WHERE mapped_name != 'n'
		);--  Mark as *T*emporary concepts that must be changed or deleted 

INSERT INTO drug_concept_stage -- Create corrected copies of temporary ingred concepts
SELECT DISTINCT CASE 
		WHEN tm.mapped_id IS NOT NULL
			THEN c.concept_name
		ELSE tm.mapped_name
		END AS concept_name,
	'GGR' AS vocabulary_ID,
	'Ingredient' AS concept_class_id,
	'Stof' AS source_concept_class_id,
	NULL AS standard_concept,
	tm.concept_code AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM tomap_ingred tm
LEFT JOIN concept c ON c.concept_id = tm.mapped_id
WHERE mapped_name NOT IN (
		'n',
		'd'
		) -- n are correct names, g are for deletion
	AND (
		tm.precedence = 1
		OR tm.precedence IS NULL
		);

DELETE
FROM drug_concept_stage
WHERE invalid_reason = 'T'
	OR (
		concept_name = 'd'
		AND concept_class_id IN (
			'Brand Name',
			'Ingredient'
			)
		);-- Clear temporary BN and Ingredients
*/
TRUNCATE TABLE internal_relationship_stage;
;
INSERT INTO internal_relationship_stage --Product to Ingredient
SELECT DISTINCT 
	CASE 
		WHEN mpp.OUC != 'C'	THEN CONCAT 
			(
				'mpp',
				mpp.mppcv
			)
		ELSE CONCAT 
			(
				'mpp',
				sam.mppcv,
				'-',
				sam.ppid
			)
	END,
	coalesce (i.ingredient_code, CONCAT ('stof',sam.stofcv))
FROM sources.ggr_mpp mpp
JOIN SOURCES.GGR_SAM sam ON 
	mpp.mppcv = sam.mppcv AND
	mpp.mppcv NOT IN 
		(
			SELECT mppcv
			FROM devices_to_filter
		)
left join ing_split i on --split ingredients
	i.mix_code = 'stof' || sam.stofcv
;
INSERT INTO internal_relationship_stage --Product to Dose Forms
SELECT DISTINCT 
	CONCAT ('mpp',mpp.mppcv),
	CONCAT ('gal',mpp.galcv)
FROM sources.ggr_mpp mpp
LEFT JOIN SOURCES.GGR_SAM sam ON sam.mppcv = mpp.mppcv
WHERE mpp.mppcv NOT IN
	(
		SELECT mppcv
		FROM devices_to_filter
	) and
	mpp.OUC != 'C' --pack contents have different insert 
;
INSERT INTO internal_relationship_stage --Pack Contents to Dose Forms
SELECT DISTINCT 
	CONCAT ('mpp',mpp.mppcv,'-',sam.ppid),
	coalesce 
		(
			t.concept_code,
			(
				--!!! CHECK WHICH ONES GET THIS MAPPING FROM HERE BEFORE COMPILING
				select distinct concept_code from tomap_form where concept_name_nl = 'inj. susp. i.m. [flac.]' -- one form in ppgal field does not have a proper code
			)
		)
FROM sources.ggr_mpp mpp
JOIN SOURCES.GGR_SAM sam ON sam.mppcv = mpp.mppcv
left join tomap_form t on-- only form name, get code ourselves
	t.concept_name_nl = sam.ppgal
WHERE mpp.mppcv NOT IN
	(
		SELECT mppcv
		FROM devices_to_filter
	) and
	mpp.OUC = 'C'
;
INSERT INTO internal_relationship_stage --Product to Suppliers
SELECT DISTINCT 
		CONCAT ('mpp',mpp.mppcv),
		CONCAT 
			(
				'ir',
				mp.ircv
			)
FROM sources.ggr_mpp mpp
JOIN sources.ggr_mp mp ON mp.mpcv = mpp.mpcv
where mpp.mppcv not in 
	(
		select mppcv
		from devices_to_filter
	)
; 

INSERT INTO internal_relationship_stage --Product to Brand Names
SELECT DISTINCT 
	CONCAT ('mpp',mpp.mppcv),
	CONCAT ('mp',mpp.mpcv)
FROM sources.ggr_mpp mpp
where mpp.mppcv not in 
	(
		select mppcv
		from devices_to_filter
	)
 and 'mp'||mpp.mpcv not in (select concept_code from tomap_bn where invalid_indicator = 'D') ;


-- DELETE
-- FROM internal_relationship_stage
-- WHERE concept_code_1 IN (
-- 		SELECT concept_code
-- 		FROM drug_concept_stage
-- 		WHERE concept_class_id = 'Device'
-- 		);

/*delete from internal_relationship_stage 
  where concept_code_2 like 'stof%'
  and concept_code_2 not in (select concept_code from drug_concept_stage where concept_class_id = 'Ingredient')*/;
truncate ds_stage;
INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size
	) --devices are out of the way and packs are neatly organized, so it's best time to do it
SELECT DISTINCT CASE 
		WHEN OUC = 'C'
			THEN CONCAT (
					'mpp',
					sam.mppcv,
					'-',
					sam.ppid
					) -- Pack contents have two defining keys, we combine them
		ELSE CONCAT (
				'mpp',
				mpp.mppcv
				)
		END AS drug_concept_code,
	'stof' || sam.stofcv AS ingredient_concept_code,
	CASE 
		WHEN sam.inq != 0
			AND mpp.afu IS NULL
			AND -- not a soluble powder
			sam.inbasu IS NULL
			AND -- has no denominator
			(
				mpp.cfu IS NULL
				OR mpp.cfu IN (
					'x',
					'parels'
					)
				) -- CFU may refer to both box size and amount of drug
			THEN sam.inq
		WHEN sam.stofcv = '01422'
			THEN 0
		ELSE NULL
		END::FLOAT AS AMOUNT_VALUE,
	CASE 
		WHEN sam.inq != 0
			AND mpp.afu IS NULL
			AND sam.inbasu IS NULL
			AND (
				mpp.cfu IS NULL
				OR mpp.cfu IN (
					'x',
					'parels'
					)
				)
			THEN sam.inu
		WHEN sam.stofcv = '01422'
			THEN 'mg'
		ELSE NULL
		END AS AMOUNT_UNIT,
	CASE 
		WHEN --defined like numerator/denominator, 
			sam.inq != 0
			AND sam.inbasu IS NOT NULL
			THEN CASE --liter filter
					WHEN mpp.cfu = 'l'
						THEN sam.INQ * coalesce((mpp.cfq * 1000 / sam.inbasq), 1)
						ELSE sam.INQ * coalesce((mpp.cfq / sam.inbasq), 1)
					END
		WHEN --defined like powder/solvent
			sam.inq != 0
			AND mpp.afu IS NOT NULL
			AND sam.inbasu IS NULL
			THEN sam.INQ
		ELSE NULL
		END::FLOAT AS NUMERATOR_VALUE,
	CASE 
		WHEN --defined like numerator/denominator
			sam.inq != 0
			AND sam.inbasu IS NOT NULL
			THEN sam.INU
		WHEN --defined like powder/solvent
			sam.inq != 0
			AND mpp.afu IS NOT NULL
			AND sam.inbasu IS NULL
			THEN sam.INU
		ELSE NULL
		END AS NUMERATOR_UNIT,
	CASE 
		WHEN --defined like numerator/denominator
			sam.inq != 0
			AND sam.inbasu IS NOT NULL
			THEN coalesce(mpp.CFQ, sam.inbasq)
		WHEN --defined like powder/solvent
			sam.inq != 0
			AND mpp.afu IS NOT NULL
			AND sam.inbasu IS NULL
			THEN mpp.afq
		ELSE NULL
		END::FLOAT AS DENOMINATOR_VALUE,
	CASE 
		WHEN --defined like numerator/denominator
			sam.inbasq != 0 and (mpp.CFU = 'x' or mpp.cfu is null)
			AND sam.inbasu IS NOT NULL
			THEN sam.inbasu
		WHEN --defined like numerator/denominator
			sam.inbasq != 0 and mpp.CFU != 'x'
			AND sam.inbasu IS NOT NULL
			THEN mpp.CFU
		WHEN --defined like powder/solvent
			sam.inq != 0
			AND mpp.afu IS NOT NULL
			AND sam.inbasu IS NULL
			THEN mpp.afu
		ELSE NULL
		END AS DENOMINATOR_UNIT,
	CASE 
		/* when mpp.OUC = 'C' and sam.ppq != 0 then sam.ppq 
    when mpp.OUC != 'C' and mpp.cfu in ('x', 'parels') then mpp.cfq 
    when mpp.OUC != 'C' and mpp.afu is not null and sam.inbasu is not null then mpp.afq / sam.inbasq */
		WHEN mpp.OUC != 'C'
-- 			AND mpp.cq != 1
			THEN mpp.cq
		ELSE NULL
		END AS BOX_SIZE
FROM sources.ggr_mpp mpp
LEFT JOIN SOURCES.GGR_SAM sam ON mpp.mppcv = sam.mppcv
;

--update /cm� to have proper denominator
with square_denom as
	(
		select distinct drug_concept_code, replace (replace (dim, ',' ,'.'), ' cm','') as dim from ds_stage --find where changes are needed, parse dimensions
		join SOURCES.GGR_SAM sam on 'mpp' || mppcv = drug_concept_code and 'stof' || stofcv = ingredient_concept_code 
		where denominator_unit = 'cm�' and inbasq = 1 and dim is not null
	),
calc as
	(
		select distinct
			drug_concept_code, 
			substring (dim from '^(\d+(\.\d+)?)') :: float * --extract and calculate
			substring (dim from '(\d+(\.\d+)?)$') :: float 
				as tot
		from square_denom
	)
update ds_stage
set 
	denominator_value = (select tot from calc where drug_concept_code = ds_stage.drug_concept_code),
	numerator_value = numerator_value * (select tot from calc where drug_concept_code = ds_stage.drug_concept_code)
where drug_concept_code in (select drug_concept_code from calc)
;

--update hours for transdermal systems with 1 u (hour) in denominator
--we can only do this for these that specify 'weekly' dose form
with weekly_to_fix as
	(
		select distinct drug_concept_code
		from ds_stage d
		join internal_relationship_stage i on
			d.drug_concept_code = i.concept_code_1 and
			(d.denominator_value, d.denominator_unit) = (1,'u') and
			i.concept_code_2 like 'gal%' --find dose Dose Forms
		join concept_synonym_stage y on --dose forms refer to weekly
			y.synonym_concept_code = i.concept_code_2 and
			y.language_concept_id = 4182503 and
			y.synonym_name ilike '%wekelijks%'
	)
update ds_stage
set 
	denominator_value = 168, --hours in a week
	numerator_value = 168 * numerator_value
where drug_concept_code in (select * from weekly_to_fix)
;
--No other clues were found in source as for duration
--Any additional rules should go here if you found them
;
update ds_stage d --remove quantity everywhere else
set
	denominator_value = null,
	box_size = null
where
	(d.denominator_value, d.denominator_unit) = (1,'u')
;
DELETE
FROM ds_stage
WHERE --delete devices and dataless rows
	drug_concept_code IN (
		SELECT CONCAT (
				'mpp',
				mppcv
				)
		FROM DEVICES_TO_FILTER
		)
	OR ingredient_concept_code IS NULL
	OR (
		amount_value IS NULL
		AND numerator_value IS NULL
		AND ingredient_concept_code != 'stof01422' --Inert ingredients
		)
	OR AMOUNT_UNIT = 'ml';--vaccines without otherwise set doses, exclusively


UPDATE ds_stage
SET NUMERATOR_UNIT = 'g'
WHERE NUMERATOR_UNIT = 'ml';-- tinctures/liquid extracts, herbal


DELETE
FROM ds_stage
WHERE ingredient_concept_code NOT IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Ingredient'
		);-- filter deprecated ingreds

;

alter table ds_stage -- add mapped ingredient's concept_id to aid next step in dealing with dublicates
add concept_id int4
;
update ds_stage
set concept_id =
	(
		select concept_id_2
		from relationship_to_concept
		where
			concept_code_1 = ingredient_concept_code and
			precedence = 1
	)
;
--Fix ingredients that got replaced/mapped as same one (e.g. Ascorbic acid + Sodium ascorbate => Ascorbic acid)
drop table if exists ds_split
;
create table ds_split as
select distinct
	drug_concept_code,
	min (ingredient_concept_code) over (partition by drug_concept_code, concept_id) :: varchar as ingredient_concept_code, --one at random
	sum (amount_value) over (partition by drug_concept_code, concept_id) as amount_value,
	amount_unit,
	sum (numerator_value) over (partition by drug_concept_code, concept_id) as numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size,
	concept_id
from ds_stage
where
	(drug_concept_code, concept_id) in
	(
		SELECT drug_concept_code, concept_id
		FROM ds_stage
		GROUP BY drug_concept_code, concept_id
		HAVING COUNT(*) > 1
	)
;

delete from ds_stage
where
	(drug_concept_code, concept_id) in
	(
		SELECT drug_concept_code, concept_id
		FROM ds_split
	)
;
insert into ds_stage
	(
		drug_concept_code,
		ingredient_concept_code,
		amount_value,
		amount_unit,
		numerator_value,
		numerator_unit,
		denominator_value,
		denominator_unit,
		box_size,
		concept_id
	)
select *
from ds_split
;
alter table ds_stage
drop column concept_id
;
--same changes to irs
delete from internal_relationship_stage
where
	concept_code_1 in (select drug_concept_code from ds_split) and
	concept_code_2 in (select concept_code from drug_concept_stage where concept_class_id = 'Ingredient')
;
insert into internal_relationship_stage
select
	drug_concept_code,
	ingredient_concept_code
from ds_split
;
TRUNCATE TABLE concept_synonym_stage;

-- INSERT INTO concept_synonym_stage --English translations
-- SELECT distinct NULL :: int4 AS synonym_concept_id,
-- 	concept_name AS synonym_concept_name,
-- 	concept_code AS synonym_concept_code,
-- 	'GGR' AS vocabulary_ID,
-- 	4180186 AS language_concept_id --English
-- FROM drug_concept_stage
-- WHERE 
-- 	concept_class_id in ('Ingredient', 'Dose Form') and
-- 	concept_code not in (select mix_code from ing_split) and
-- 	concept_name is not null
;


/* Ingredients */
INSERT INTO concept_synonym_stage --French Ingredients
SELECT distinct NULL :: int4 AS synonym_concept_id,
	finnm AS synonym_concept_name,
	CONCAT (
		'stof',
		stofcv
		) AS synonym_concept_code,
	'GGR' AS vocabulary_ID,
	4180190 AS language_concept_id --French
FROM sources.ggr_innm
WHERE CONCAT (
		'stof',
		stofcv
		) IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Ingredient'
		) and
		'stof' || stofcv not in (select mix_code from ing_split)
;

INSERT INTO concept_synonym_stage --Dutch Ingredients
SELECT distinct NULL :: int4 AS synonym_concept_id,
	ninnm AS synonym_concept_name,
	CONCAT (
		'stof',
		stofcv
		) AS synonym_concept_code,
	'GGR' AS vocabulary_ID,
	4182503 AS language_concept_id --Dutch
FROM sources.ggr_innm
WHERE CONCAT (
		'stof',
		stofcv
		) IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Ingredient'
		) and
		'stof' || stofcv not in (select mix_code from ing_split)
;

/* Dose Forms */
INSERT INTO concept_synonym_stage
-- SELECT distinct NULL :: int4 AS synonym_concept_id,
-- 	concept_name_en AS synonym_concept_name,
-- 	concept_code AS synonym_concept_code,
-- 	'GGR' AS vocabulary_ID,
-- 	4180186 AS language_concept_id --English
-- FROM tomap_form
-- WHERE concept_name_en IS NOT NULL

-- UNION

SELECT distinct NULL :: int4 AS synonym_concept_id,
	concept_name_fr AS synonym_concept_name,
	concept_code AS synonym_concept_code,
	'GGR' AS vocabulary_ID,
	4180190 AS language_concept_id --French
FROM tomap_form
WHERE concept_name_fr IS NOT NULL

UNION

SELECT distinct NULL :: int4 AS synonym_concept_id,
	concept_name_nl AS synonym_concept_name,
	concept_code AS synonym_concept_code,
	'GGR' AS vocabulary_ID,
	4182503 AS language_concept_id --Dutch
FROM tomap_form
WHERE concept_name_nl IS NOT NULL;


/* create table for manual fixes */
 -- fix duplicates with ingreds
DROP TABLE IF EXISTS dsfix;

CREATE TABLE dsfix AS 
--Those with different ingredient count in irs and source (ingredient mixes)
--Those that map to same ingredient multiple times
--SAM entry without dosages
--Those with entry in MPP, but not SAM
--Those expected to be reported by QA scripts --to implement

--Those with different ingredient count in irs and source (ingredient mixes)
SELECT 
	d.drug_concept_code,
	a.concept_name AS drug_concept_name,
	b.concept_code AS ingredient_concept_code,
	b.concept_name AS ingredient_concept_name,
	d.amount_value,
	d.amount_unit,
	d.numerator_value,
	d.numerator_unit,
	d.denominator_value,
	d.denominator_unit,
	d.box_size
FROM ds_stage d
JOIN drug_concept_stage a ON d.drug_concept_code = a.concept_code
left join ing_split i on i.mix_code = d.ingredient_concept_code
JOIN drug_concept_stage b ON b.concept_code = coalesce (i.ingredient_code, d.ingredient_concept_code)
WHERE drug_concept_code IN 
	(
		select irs_count.drug_concept_code
		from
			(
				SELECT 
					concept_code_1 as drug_concept_code,
					count (distinct concept_code_2) as ic
				from internal_relationship_stage
				join drug_concept_stage on
					concept_code_2 = concept_code and
					concept_class_id = 'Ingredient'
				group by concept_code_1
			) irs_count
		join
			(
				SELECT
					case mpp.ouc
						when 'C' then 'mpp' || sam.mppcv || '-' || sam.ppid
						else 'mpp' || sam.mppcv
					end as drug_concept_code,
					count (distinct sam.stofcv) as ic
				from sources.ggr_mpp mpp
				join SOURCES.GGR_SAM sam using (mppcv)
				where sam.stofcv !='01422'
				group by drug_concept_code
			) source_count
		on 
			irs_count.drug_concept_code = source_count.drug_concept_code and
			irs_count.ic > source_count.ic
	)

UNION

--SAM entry without dosages
SELECT 
	d.concept_code as drug_concept_code,
	d.concept_name AS drug_concept_name,
	b.concept_code AS ingredient_concept_code,
	b.concept_name AS ingredient_concept_name,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL
from sources.ggr_mpp mpp
join SOURCES.GGR_SAM sam on sam.mppcv = mpp.mppcv
left join ing_split i on i.mix_code = 'stof' || sam.stofcv
JOIN drug_concept_stage b ON b.concept_code = coalesce (i.ingredient_code, 'stof' || sam.stofcv)
join drug_concept_stage d on
	case mpp.ouc
		when 'C' then 'mpp' || sam.mppcv || '-' || sam.ppid
		else 'mpp' || sam.mppcv
	end = d.concept_code and
	d.domain_id != 'Device'  and
	sam.inq = 0 and
	b.concept_name != 'Inert Ingredients'
	and  sam.stofcv !='01422'--contraceptives are ok, 'placebo' ingredient shouldn't be inserted


	UNION

--Those with entry in MPP, but not SAM
SELECT 
	concept_code AS drug_concept_code,
	concept_name AS drug_concept_name,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL
FROM drug_concept_stage dcs
join sources.ggr_mpp mpp on
	'mpp' || mpp.mppcv = dcs.concept_code
left join SOURCES.GGR_SAM sam using (mppcv)
WHERE 
	dcs.domain_id != 'Device' AND
	sam.mppcv IS NULL
	and sam.stofcv !='01422'
	
order by drug_concept_code
;
--select * from dsfix;48
ALTER TABLE dsfix ADD device VARCHAR(255); --to manually proclaim devices
ALTER TABLE dsfix ADD mapped_id int4; -- to add mappings for new ingredients
-- truncate table r_to_c_all
;

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
left join ing_split i on
	i.mix_code = d.concept_code
where i.mix_code is null
;


insert into r_to_c_insert --save ingredient mixes, too
select
	concept_name,
	'Ingredient',
	mapped_id,
	precedence,
	null :: int4
from tomap_ingred t
where concept_code in
	(
		select concept_code
		from tomap_ingred
		where precedence is null
		group by concept_code
		having count (mapped_id) > 1
	)
;
--preserve manually mapped vaccines
insert into r_to_c_insert
select
	t.source_name,
	'Med Product Pack',
	t.concept_id,
	1 as precedence,
	null as conversion_factor
from tofix_vax t
join drug_concept_stage c on
	t.concept_id is not null and
	c.concept_name = t.source_name and
	c.source_concept_class_id = 'Med Product Pack'
;
--replace old mappings that were changed in tomap_* tables
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
--ingredient names should be made english
-- update drug_concept_stage x
-- set concept_name = (select distinct mapped_name from tomap_ingred where concept_code = x.concept_code and (precedence = 1 or precedence is null))
-- where
-- 	concept_class_id = 'Ingredient' and
-- 	concept_code not in (select mix_code from ing_split)
;
--replace ingredients in stage tables with ones from dsfix
DELETE
 FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM dsfix
		);

delete
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT drug_concept_code
		FROM dsfix
		)
	AND concept_code_2 in (select concept_code from drug_concept_stage where concept_class_id = 'Ingredient');
;
INSERT INTO internal_relationship_stage
SELECT DISTINCT d.drug_concept_code, d.ingredient_concept_code
FROM dsfix d
WHERE d.device IS NULL;





DROP TABLE IF EXISTS code_replace;
CREATE TABLE code_replace AS
SELECT 'OMOP' || nextval('new_vocab') AS new_code,
	concept_code AS old_code
FROM (
	SELECT concept_code
	FROM drug_concept_stage
	WHERE 
		concept_code LIKE 'OMOP%' or
		concept_code like 'mpp%-_' or
		concept_code like 'gal%'
	GROUP BY concept_code
	ORDER BY LPAD(concept_code, 50, '0')
	) AS s0;



UPDATE drug_concept_stage a
set
concept_code = 
  (
    select b.new_code  
    FROM code_replace b
    WHERE a.concept_code = b.old_code
  )    
where concept_code in (select old_code from code_replace);

UPDATE relationship_to_concept a
SET concept_code_1 = 
(
select b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code)
where concept_code_1 in (select old_code from code_replace);

UPDATE ds_stage a
SET ingredient_concept_code = 
(select b.new_code
FROM code_replace b
WHERE a.ingredient_concept_code = b.old_code)
where ingredient_concept_code in (select old_code from code_replace);

UPDATE ds_stage a
SET drug_concept_code = 
(select b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code)
where drug_concept_code in (select old_code from code_replace);

UPDATE internal_relationship_stage a
SET concept_code_1 = 
(select b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code)
where concept_code_1 in (select old_code from code_replace);

UPDATE internal_relationship_stage a
SET concept_code_2 = 
(select b.new_code
FROM code_replace b
WHERE a.concept_code_2 = b.old_code)
where concept_code_2 in (select old_code from code_replace);

UPDATE pc_stage a
SET drug_concept_code = 
(select b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code)
where drug_concept_code in (select old_code from code_replace);

UPDATE drug_concept_stage
SET standard_concept = NULL
WHERE concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		JOIN internal_relationship_stage ON concept_code_1 = concept_code
		WHERE concept_class_id = 'Ingredient'
			AND standard_concept IS NOT NULL
);


delete  from relationship_to_concept r1
where exists
	(
		select
		from relationship_to_concept r2
		where
			(r1.concept_code_1, r1.concept_id_2, r1.precedence) = (r2.concept_code_1, r2.concept_id_2, r2.precedence) and
			r1.ctid > r2.ctid
	)
;
--we conclude that 'Orphans' are not real supplier names
delete from internal_relationship_stage where concept_code_2 in (select concept_code from drug_concept_stage where concept_class_id = 'Supplier' and concept_name ilike '%orphan%');
delete from relationship_to_concept where concept_code_1 in (select concept_code from drug_concept_stage where concept_class_id = 'Supplier' and concept_name ilike '%orphan%');
delete from drug_concept_stage where concept_class_id = 'Supplier' and concept_name ilike '%orphan%';

delete from relationship_to_concept where concept_code_1 like 'gal%' and concept_code_1 not in (select concept_code_2 from internal_relationship_stage);
delete from concept_synonym_stage where synonym_concept_code like 'gal%' and synonym_concept_code not in (select concept_code_2 from internal_relationship_stage);
delete from drug_concept_stage where concept_code like 'gal%' and concept_code not in (select concept_code_2 from internal_relationship_stage);
;
--No dosage means no suppliers
delete from internal_relationship_stage 
where
	concept_code_2 like 'ir%' and
	concept_code_1 in
	(
		SELECT concept_code
		FROM drug_concept_stage dcs
		JOIN (
				SELECT concept_code_1
				FROM internal_relationship_stage
				JOIN drug_concept_stage ON concept_code_2 = concept_code
					AND concept_class_id = 'Supplier'
				LEFT JOIN ds_stage ON drug_concept_code = concept_code_1
				LEFT JOIN pc_stage on pack_concept_code = concept_code_1
				WHERE 
					ds_stage.drug_concept_code IS NULL and
					pc_stage.pack_concept_code IS NULL
			) s ON s.concept_code_1 = dcs.concept_code
		WHERE dcs.concept_class_id = 'Drug Product'
			AND invalid_reason IS NULL
			and dcs.concept_code not in (select pack_concept_code from pc_stage)
	)
;

delete from relationship_to_concept where concept_code_1 not in (select concept_code from drug_concept_stage)
;
delete from internal_relationship_stage where concept_code_2 not in (select concept_code from drug_concept_stage)
;
delete from ds_stage where drug_concept_code not in (select concept_code from drug_concept_stage);




--MPP codes are expected to be met in source data; revert them to source presentation
update drug_concept_stage
set concept_code = replace (concept_code,'mpp','')
where concept_code like 'mpp%'
;
update internal_relationship_stage
set concept_code_1 = replace (concept_code_1,'mpp','')
where concept_code_1 like 'mpp%'
;
update ds_stage
set drug_concept_code = replace (drug_concept_code,'mpp','')
where drug_concept_code like 'mpp%'
;
update pc_stage
set pack_concept_code = replace (pack_concept_code,'mpp','')
;--194
update tofix_vax
set source_code = replace (source_code,'mpp','')
;--58
--Ensure vaccines are processed separately and don't create extra entities in RxE
delete from ds_stage 
where
	drug_concept_code in
	(
		select source_code
		from tofix_vax
		where concept_id is not null
	)
;
delete from internal_relationship_stage
where
	concept_code_1 in
	(
		select source_code
		from tofix_vax
		where concept_id is not null
	)
;
-- delete from pc_stage
-- where
-- 	pack_concept_code in
-- 	(
-- 		select source_code
-- 		from tofix_vax
-- 		where concept_id is not null
-- 	)
;
;
-- remove problematic ingredients
-- deprecated and unused
delete from internal_relationship_stage where concept_code_2 in (select concept_code_1 from relationship_to_concept join concept on concept_id_2 = concept_id where concept_class_id = 'Ingredient' and invalid_reason = 'D' and precedence = 1);
delete from drug_concept_stage where concept_code in (select concept_code_1 from relationship_to_concept join concept on concept_id_2 = concept_id where concept_class_id = 'Ingredient' and invalid_reason = 'D' and precedence = 1);
delete from relationship_to_concept where concept_code_1 in (select concept_code_1 from relationship_to_concept join concept on concept_id_2 = concept_id where concept_class_id = 'Ingredient' and invalid_reason = 'D' and precedence = 1);
update 
ds_stage
set box_size = null
where box_size = '1';




