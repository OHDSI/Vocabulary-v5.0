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
/*
--1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'GGR',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.ggr_ir LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.ggr_ir LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_GGR'
);
END $_$;
*/

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
LEFT JOIN sources.ggr_sam sam ON mpp.mppcv = sam.mppcv
WHERE mpp.ouc = 'C';--OUC means *O*ne, m*U*ltiple or pa*C*k 


DROP TABLE IF EXISTS DEVICES_TO_FILTER;
CREATE TABLE DEVICES_TO_FILTER (
	MPPCV VARCHAR(255) NOT NULL,
	MPPNM VARCHAR(255) NOT NULL
	);

INSERT INTO DEVICES_TO_FILTER --this is the one most simple way to filter Devices with incredible accuracy
SELECT DISTINCT mpp.mppcv,
	mpp.MPPNM
FROM sources.ggr_mpp mpp
LEFT JOIN sources.ggr_sam sam ON mpp.mppcv = sam.mppcv
WHERE sam.stofcv IN (
		'01990',
		'00649',
		'01475',
		'01843'
		);-- 'no active ingredient', 'ethanol', 'propanol', 'oxygen peroxide'. Latter three are only listed as ingredient in Devices

INSERT INTO DEVICES_TO_FILTER
SELECT DISTINCT mpp.mppcv,
	mpp.MPPNM
FROM sources.ggr_mpp mpp
WHERE hyrcv IN (
		'0016253',
		'0016246',
		'0016303',
		'0020263',
		'0016212',
		'0016253'
		);-- These are codes for contrast substances

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
FROM sources.ggr_sam
WHERE mppcv NOT IN (
		SELECT mppcv
		FROM devices_to_filter
		)
	AND INBASU IS NOT NULL

UNION

SELECT inu2 AS unit
FROM sources.ggr_sam
WHERE mppcv NOT IN (
		SELECT mppcv
		FROM devices_to_filter
		)
	AND inu2 IS NOT NULL

UNION

SELECT INU AS unit
FROM sources.ggr_sam
WHERE mppcv NOT IN (
		SELECT mppcv
		FROM devices_to_filter
		)
	AND INU IS NOT NULL;

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
FROM devices_to_filter;

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
		);

INSERT INTO drug_concept_stage -- Ingredients
SELECT DISTINCT ninnm AS concept_name,
	'GGR' AS vocabulary_ID,
	'Ingredient' AS concept_class_id,
	'Stof' AS source_concept_class_id,
	NULL AS standard_concept,
	CONCAT (
		'stof',
		STOFCV
		) AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.ggr_innm;

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
FROM sources.ggr_ir;

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
FROM sources.ggr_gal;

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
		);--filter devices

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
LEFT JOIN sources.ggr_sam sam ON sam.mppcv = mpp.mppcv
WHERE OUC = 'C';

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
FROM units;

DROP TABLE IF EXISTS tomap_unit;

CREATE TABLE tomap_unit (
	Concept_code VARCHAR(255),
	concept_id INT4,
	Concept_name VARCHAR(255),
	conversion_factor FLOAT
	);

INSERT INTO tomap_unit
SELECT unit AS concept_code,
	NULL AS concept_id,
	NULL AS concept_name,
	NULL AS conversion_factor
FROM units;

DROP TABLE IF EXISTS tomap_form;

CREATE TABLE tomap_form (
	concept_code VARCHAR(255),
	concept_name_fr VARCHAR(255),
	concept_name_nl VARCHAR(255),
	concept_name_en VARCHAR(255),
	mapped_id INT4,
	mapped_name VARCHAR(255),
	precedence INT4
	);

INSERT INTO tomap_form
SELECT CONCAT (
		'gal',
		galcv
		) AS concept_code,
	fgalnm AS concept_name_fr,
	ngalnm AS concept_name_nl,
	NULL AS concept_name_en,
	NULL AS mapped_id,
	NULL AS mapped_name,
	NULL AS precedence
FROM sources.ggr_gal;

DROP TABLE IF EXISTS tomap_supplier;

CREATE TABLE tomap_supplier (
	concept_code VARCHAR(255),
	concept_name VARCHAR(255),
	mapped_id INT4,
	mapped_name VARCHAR(255)
	);

INSERT INTO tomap_supplier
SELECT dc.concept_code AS concept_code,
	dc.concept_name,
	c.concept_id AS mapped_id,
	c.concept_name AS mapped_name
FROM drug_concept_stage dc
LEFT JOIN concept c ON c.concept_class_id = 'Supplier'
	AND c.vocabulary_id LIKE 'Rx%'
	AND c.invalid_reason IS NULL
	AND lower(c.concept_name) = lower(dc.concept_name)
WHERE dc.concept_class_id = 'Supplier';

DROP TABLE IF EXISTS tomap_bn;

CREATE TABLE tomap_bn (
	concept_code VARCHAR(255),
	concept_name VARCHAR(255),
	mapped_id INT4,
	mapped_name VARCHAR(255),
	supplier_name VARCHAR(255)
	);

INSERT INTO tomap_bn
SELECT dc.concept_code AS concept_code,
	dc.concept_name,
	c.concept_id AS mapped_id,
	c.concept_name AS mapped_name,
	ir.NIRNM AS supplier_names
FROM drug_concept_stage dc
JOIN sources.ggr_mp mp ON CONCAT (
		'mp',
		mp.mpcv
		) = dc.concept_code
JOIN sources.ggr_ir ir ON mp.ircv = ir.ircv
LEFT JOIN concept c ON c.concept_class_id = 'Brand Name'
	AND c.vocabulary_id LIKE 'Rx%'
	AND c.invalid_reason IS NULL
	AND lower(c.concept_name) = lower(dc.concept_name)
WHERE dc.concept_class_id = 'Brand Name';


DELETE
FROM tomap_bn
WHERE supplier_name = 'PI-Pharma';--Dublicates exclusively, simplifies manual work 

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
	c.concept_id AS mapped_id,
	c.concept_name AS mapped_name,
	NULL AS precedence
FROM drug_concept_stage dc
LEFT JOIN concept c ON c.concept_class_id = 'Ingredient'
	AND c.vocabulary_id LIKE 'Rx%'
	AND c.invalid_reason IS NULL
	AND lower(c.concept_name) = lower(dc.concept_name)
WHERE dc.concept_class_id = 'Ingredient';