/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
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
**************************************************************************/

--1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'GGR',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.ggr_ir LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.ggr_ir LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_GGR'
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'RxNorm Extension',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'RxNorm Extension '||CURRENT_DATE,
	pVocabularyDevSchema	=> 'DEV_GGR',
	pAppendVocabulary		=> TRUE
);
END $_$;

--keep legacy mappings for the future
create table if not exists r_to_c_all
(
   concept_name       varchar(255),
   concept_class_id   varchar,
   concept_id         integer,
   precedence         integer,
   conversion_factor  float8
)
;
--we form this one first to clear way for future ds_stage
TRUNCATE TABLE pc_stage;
INSERT INTO pc_stage --take pack data straight from mpp
SELECT DISTINCT CONCAT (
		'mpp',
		mpp.mppcv
		) AS pack_concept_code,
	CONCAT (
		'mpp',
		mpp.mppcv,
		'-',
		sam.ppid
		) AS drug_concept_code,
	sam.ppq AS amount,
	mpp.cq AS box_size
FROM sources.ggr_mpp mpp -- Pack contents have two defining keys, we combine them
LEFT JOIN SOURCES.GGR_SAM sam ON mpp.mppcv = sam.mppcv
WHERE mpp.ouc = 'C';--OUC means *O*ne, m*U*ltiple or pa*C*k 


DROP TABLE IF EXISTS DEVICES_TO_FILTER;
CREATE TABLE DEVICES_TO_FILTER (
	MPPCV VARCHAR(255) NOT NULL,
	MPPNM VARCHAR(255) NOT NULL
	);

INSERT INTO DEVICES_TO_FILTER --this is the one most simple way to filter Devices with acceptable accuracy
SELECT DISTINCT mpp.mppcv,
	mpp.MPPNM
FROM sources.ggr_mpp mpp
LEFT JOIN SOURCES.GGR_SAM sam ON mpp.mppcv = sam.mppcv
WHERE sam.stofcv IN (
		'01990',
		'00649',
		'01475',
		'01843'
		)-- 'no active ingredient', 'ethanol', 'propanol', 'oxygen peroxide'. Latter three are only listed as ingredient in Devices
	
	union

SELECT DISTINCT mpp.mppcv,
	mpp.MPPNM
FROM sources.ggr_mpp mpp
WHERE hyrcv IN (
		-- contrast substances
		'0016253',
		'0016246',
		'0016303',
		'0016212',
		'0016253',
		'0016360',
		--Topical antiseptics, bandages etc:
		'0020826',
		'0025346',
		'0013847',
		'0013870',
		'0014738',
		'0014753',
		'0014779',
		'0014795',
		'0014811',
		'0014852',
		--homeopathy
		'0018671'
);
DROP TABLE IF EXISTS units;
CREATE TABLE units AS --temporary table with list of all measurement units we will insert into drug_concept_stage. mpp and sam are source
SELECT AU AS unit
FROM sources.ggr_mpp
WHERE mppcv NOT IN (
		SELECT mppcv
		FROM devices_to_filter
		)
	AND AU IS NOT NULL

UNION

SELECT INBASU AS unit
FROM SOURCES.GGR_SAM sam
WHERE mppcv NOT IN (
		SELECT mppcv
		FROM devices_to_filter
		)
	AND INBASU IS NOT NULL

UNION

SELECT inu2 AS unit
FROM SOURCES.GGR_SAM sam
WHERE mppcv NOT IN (
		SELECT mppcv
		FROM devices_to_filter
		)
	AND inu2 IS NOT NULL

UNION

SELECT INU AS unit
FROM SOURCES.GGR_SAM sam
WHERE mppcv NOT IN (
		SELECT mppcv
		FROM devices_to_filter
		)
	AND INU IS NOT NULL;

insert into units values ('l')
;
-- now that devices and packs are dealt with, we can fill ds_stage
TRUNCATE TABLE drug_concept_stage;
INSERT INTO drug_concept_stage -- Devices
SELECT DISTINCT mppnm AS concept_name,
	'GGR' AS vocabulary_ID,
	'Device' AS concept_class_id,
	'Med Product Pack' AS source_concept_class_id,
	'S' AS standard_concept,
	CONCAT (
		'mpp',
		mppcv
		) AS concept_code,
	NULL AS possible_excipient,
	'Device' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM devices_to_filter
;
INSERT INTO drug_concept_stage -- Brand Names
SELECT DISTINCT mpnm AS concept_name,
	'GGR' AS vocabulary_ID,
	'Brand Name' AS concept_class_id,
	'Medicinal Product' AS source_concept_class_id,
	NULL AS standard_concept,
	CONCAT (
		'mp',
		mpcv
		) AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.ggr_mp
WHERE mpcv NOT IN (
		--filter devices we added earlier, as we don't need to store brand names for them
		SELECT mpp.mpcv
		FROM sources.ggr_mpp mpp
		JOIN devices_to_filter dev ON dev.mppcv = mpp.mppcv
		)
;
INSERT INTO drug_concept_stage -- Ingredients
SELECT DISTINCT ninnm AS concept_name,
	'GGR' AS vocabulary_ID,
	'Ingredient' AS concept_class_id,
	'Ingredient' AS source_concept_class_id,
	'S' AS standard_concept,
	CONCAT (
		'stof',
		STOFCV
		) AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.ggr_innm
join SOURCES.GGR_SAM s using (stofcv) -- we only need ingredients that are being used in drugs
where s.mppcv not in (select mppcv from devices_to_filter)
;
INSERT INTO drug_concept_stage -- Suppliers
SELECT DISTINCT NIRNM AS concept_name,
	'GGR' AS vocabulary_ID,
	'Supplier' AS concept_class_id,
	'Supplier' AS source_concept_class_id,
	NULL AS standard_concept,
	CONCAT (
		'ir',
		ircv
		) AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.ggr_ir
;
INSERT INTO drug_concept_stage -- Dose forms
SELECT DISTINCT NGALNM AS concept_name,
	'GGR' AS vocabulary_ID,
	'Dose Form' AS concept_class_id,
	NULL AS source_concept_class_id,
	NULL AS standard_concept,
	CONCAT (
		'gal',
		galcv
		) AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.ggr_gal
;
INSERT INTO drug_concept_stage -- Products, no pack contents
SELECT DISTINCT mppnm AS concept_name,
	'GGR' AS vocabulary_ID,
	'Drug Product' AS concept_class_id,
	'Med Product Pack' AS source_concept_class_id,
	NULL AS standard_concept,
	CONCAT (
		'mpp',
		mppcv
		) AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.ggr_mpp
WHERE mppcv NOT IN (
		SELECT mppcv
		FROM devices_to_filter
		)
;--filter devices
INSERT INTO drug_concept_stage -- Products, in packs
SELECT DISTINCT CONCAT (
		mpp.mppnm,
		', pack content #',
		RIGHT(pc.drug_concept_code, 1)
		) AS concept_name, -- Generate new pack content name
	'GGR' AS vocabulary_ID,
	'Drug Product' AS concept_class_id,
	'Med Product Pack' AS source_concept_class_id,
	NULL AS standard_concept,
	pc.drug_concept_code AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.ggr_mpp mpp
JOIN PC_STAGE pc ON pc.PACK_CONCEPT_CODE = CONCAT (
		'mpp',
		mpp.mppcv
		)
LEFT JOIN SOURCES.GGR_SAM sam ON sam.mppcv = mpp.mppcv
WHERE OUC = 'C'
;
INSERT INTO drug_concept_stage -- Measurement units
SELECT DISTINCT unit AS concept_name,
	'GGR' AS vocabulary_ID,
	'Unit' AS concept_class_id,
	NULL AS source_concept_class_id,
	NULL AS standard_concept,
	unit AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM units
;
--update legacy mappings if target was changed
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
DROP TABLE IF EXISTS tomap_unit
;
CREATE TABLE tomap_unit (
	Concept_code VARCHAR(255),
	concept_id INT4,
	Concept_name VARCHAR(255),
	conversion_factor FLOAT
	)
;
INSERT INTO tomap_unit
SELECT unit AS concept_code,
	r.concept_id,
	r.concept_name,
	r.conversion_factor
FROM units
left join r_to_c_all r on
	r.concept_class_id = 'Unit' and
	unit = r.concept_name
;
DROP TABLE IF EXISTS tomap_form
;
CREATE TABLE tomap_form (
	concept_code VARCHAR(255),
	concept_name_fr VARCHAR(255),
	concept_name_nl VARCHAR(255),
	mapped_id INT4,
	mapped_name VARCHAR(255),
	precedence INT4
	)
;
INSERT INTO tomap_form
SELECT CONCAT (
		'gal',
		galcv
		) AS concept_code,
	fgalnm AS concept_name_fr,
	ngalnm AS concept_name_nl,
	l.concept_id AS mapped_id,
	l.concept_name AS mapped_name,
	r.precedence AS precedence
FROM sources.ggr_gal g
left join r_to_c_all r on
	g.ngalnm = r.concept_name and
	r.concept_class_id = 'Dose Form'
left join concept l on
	l.concept_id = r.concept_id
;
DROP TABLE IF EXISTS tomap_supplier
;
CREATE TABLE tomap_supplier (
	concept_code VARCHAR(255),
	concept_name VARCHAR(255),
	mapped_id INT4,
	mapped_name VARCHAR(255)
	)
;
INSERT INTO tomap_supplier
SELECT dc.concept_code AS concept_code,
	dc.concept_name,
	coalesce (l.concept_id, l2.concept_id) AS mapped_id,
	coalesce (l.concept_name, l2.concept_name) AS mapped_name
FROM drug_concept_stage dc
LEFT JOIN r_to_c_all c ON 
	c.concept_class_id = 'Supplier'	AND
	c.concept_name ilike dc.concept_name
left join concept l on
	c.concept_id = l.concept_id
--add direct name match to the mix
left join concept l2 on
	l2.concept_name ilike dc.concept_name and
	l2.invalid_reason is null and
	l2.concept_class_id = 'Supplier' and
	l2.vocabulary_id = 'RxNorm Extension'
WHERE dc.concept_class_id = 'Supplier';
;
DROP TABLE IF EXISTS tomap_bn;

CREATE TABLE tomap_bn (
	concept_code VARCHAR(255),
	concept_name VARCHAR(255),
	mapped_id INT4,
	mapped_name VARCHAR(255),
	supplier_name VARCHAR(255)
	)
;
insert into tomap_bn
SELECT distinct
	dc.concept_code,
	dc.concept_name,
	coalesce (l.concept_id, l2.concept_id) AS mapped_id,
	coalesce (l.concept_name, l2.concept_name) AS mapped_name,
	ir.NIRNM AS supplier_name
FROM drug_concept_stage dc
JOIN sources.ggr_mp mp ON CONCAT ('mp',mp.mpcv) = dc.concept_code
JOIN sources.ggr_ir ir ON mp.ircv = ir.ircv
LEFT JOIN r_to_c_all c ON 
	c.concept_class_id = 'Brand Name' AND
	c.concept_name ilike dc.concept_name
left join concept l on
	c.concept_id = l.concept_id
--add direct name match to the mix
left join concept l2 on
	l2.concept_name ilike dc.concept_name and
	l2.invalid_reason is null and
	l2.concept_class_id = 'Brand Name' and
	l2.vocabulary_id in ('RxNorm','RxNorm Extension')
WHERE dc.concept_class_id = 'Brand Name'
;
--avoid duplicates for name matches
delete from tomap_bn t
where
	t.mapped_id is not null and
	exists
		(
			select
			from tomap_bn x
			join concept c1 on
				x.mapped_id = c1.concept_id
			join concept c2 on
				t.mapped_id = c2.concept_id
			where
				t.concept_code = x.concept_code and
				t.mapped_id != x.mapped_id and
				c1.concept_code < c2.concept_code
		)
;
--avoid duplicates
delete from tomap_supplier t
where
	t.mapped_id is not null and
	exists
		(
			select
			from tomap_supplier x
			join concept c1 on
				x.mapped_id = c1.concept_id
			join concept c2 on
				t.mapped_id = c2.concept_id
			where
				t.concept_code = x.concept_code and
				t.mapped_id != x.mapped_id and
				c1.concept_code < c2.concept_code
		)
;
DROP TABLE IF EXISTS tomap_ingred;
CREATE TABLE tomap_ingred (
	concept_code VARCHAR(255),
	concept_name VARCHAR(255),
	mapped_id INT4,
	mapped_name VARCHAR(255),
	precedence INT4
	);
INSERT INTO tomap_ingred
SELECT dc.concept_code,
	dc.concept_name,
	l.concept_id AS mapped_id,
	l.concept_name AS mapped_name,
	c.precedence
FROM drug_concept_stage dc
LEFT JOIN r_to_c_all c ON 
	c.concept_class_id = 'Ingredient' AND 
	c.concept_name ilike dc.concept_name
left join concept l on
	l.concept_id = c.concept_id
WHERE dc.concept_class_id = 'Ingredient'
;
drop table tofix_vax
;
create table tofix_vax as
select
	c.concept_code as source_code,
	c.concept_name as source_name,
	coalesce (x.concept_id, x2.concept_id) as concept_id,
	coalesce (x.concept_name, x2.concept_name) as concept_name,
	coalesce (x.concept_class_id, x2.concept_class_id) as concept_class_id,
	coalesce (x.vocabulary_id, x2.vocabulary_id) as vocabulary_id
from drug_concept_stage c
join sources.ggr_mpp g on
	g.hyr_ like 'LA%' and --vaccines group
	g.ouc != 'C' and -- packs still must be processed as packs
	c.concept_name = g.mppnm and
 	c.source_concept_class_id = 'Med Product Pack'
left join r_to_c_all r on
	r.concept_class_id = 'Med Product Pack' and
	c.concept_name = r.concept_name
left join concept x on
	x.concept_id = r.concept_id
left join concept s on --old mappings from concept_relationship
	s.vocabulary_id = 'GGR' and
	'mpp' || s.concept_code = c.concept_code
left join concept_relationship cr on
	cr.invalid_reason is null and
	cr.relationship_id = 'Maps to' and
	cr.concept_id_1 = s.concept_id
left join concept x2 on
	x2.concept_id = cr.concept_id_2
