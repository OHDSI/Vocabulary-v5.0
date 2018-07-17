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

-- will contain only duplicate replacements for clean creation of internal_relationship_stage and ds_stage  
DROP TABLE IF EXISTS dupe_fix;
CREATE TABLE dupe_fix AS

SELECT rm.concept_code AS concept_code_1,
	mb.concept_code AS concept_code_2
FROM drug_concept_stage rm
JOIN tomap_bn mb ON rm.concept_name = mb.concept_name
	AND rm.concept_code != mb.concept_code;

DELETE
FROM drug_concept_stage
WHERE concept_class_id = 'Dose Form';-- Rename Dose Forms

INSERT INTO drug_concept_stage
SELECT DISTINCT concept_name_en AS concept_name,
	'GGR' AS vocabulary_ID,
	'Dose Form' AS concept_class_id,
	NULL AS source_concept_class_id,
	NULL AS standard_concept,
	concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM tomap_form;

DELETE
FROM drug_concept_stage
WHERE concept_class_id = 'Brand Name'
	AND concept_code NOT IN (
		SELECT concept_code
		FROM tomap_bn
		);-- delete manually removed dupes

--Reaction to 'n' and 'g' marks and renaming:
UPDATE drug_concept_stage
SET invalid_reason = 'T'
WHERE concept_code IN (
		SELECT concept_code
		FROM tomap_bn
		WHERE mapped_name != 'n'
		);-- Mark as *T*emporary concepts that must be changed or deleted

INSERT INTO drug_concept_stage -- Create corrected copies of temporary BN concepts
SELECT DISTINCT CASE 
		WHEN tm.mapped_id IS NOT NULL
			THEN c.concept_name
		ELSE tm.mapped_name
		END AS concept_name,
	'GGR' AS vocabulary_ID,
	'Brand Name' AS concept_class_id,
	'Medicinal Product' AS source_concept_class_id,
	NULL AS standard_concept,
	tm.concept_code AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM tomap_bn tm
LEFT JOIN concept c ON c.concept_id = tm.mapped_id
WHERE mapped_name NOT IN (
		'n',
		'd'
		);-- n are correct names, g are for deletion

INSERT INTO relationship_to_concept -- Ingredients
SELECT DISTINCT concept_code AS CONCEPT_CODE_1,
	'GGR' AS VOCABULARY_ID_1,
	mapped_id AS CONCEPT_ID_2,
	coalesce(precedence, 1) AS PRECEDENCE,
	NULL::FLOAT AS CONVERSION_FACTOR
FROM tomap_ingred
WHERE mapped_id IS NOT NULL;

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

TRUNCATE TABLE internal_relationship_stage;

--Mark one of the each duplicate group as *S*tandard
UPDATE drug_concept_stage
SET standard_concept = 'S'
WHERE concept_code IN (
		SELECT min(concept_code)
		FROM drug_concept_stage
		GROUP BY concept_name
		)
	AND concept_class_id IN (
		'Ingredient',
		'Brand Name'
		);

--insert mappings to standard from dupes in internal_relationship_stage
INSERT INTO internal_relationship_stage
SELECT DISTINCT c1.concept_code,
	c2.concept_code
FROM drug_concept_stage c1
JOIN drug_concept_stage c2 ON c1.concept_code != c2.concept_code
	AND lower(c1.concept_name) = lower(c2.concept_name)
	AND c1.concept_class_id = c2.concept_class_id
	AND c2.standard_concept = 'S';

UPDATE drug_concept_stage
SET standard_concept = NULL
WHERE concept_class_id = 'Brand Name';

INSERT INTO dupe_fix
SELECT *
FROM internal_relationship_stage;

INSERT INTO internal_relationship_stage --Product to Ingredient
SELECT DISTINCT CASE 
		WHEN mpp.OUC != 'C'
			THEN CONCAT (
					'mpp',
					mpp.mppcv
					)
		ELSE CONCAT (
				'mpp',
				sam.mppcv,
				'-',
				sam.ppid
				)
		END,
	coalesce(d2.concept_code_2, CONCAT (
			'stof',
			sam.stofcv
			))
FROM sources.ggr_mpp mpp
JOIN sources.ggr_sam sam ON mpp.mppcv = sam.mppcv
	AND mpp.mppcv NOT IN (
		SELECT mppcv
		FROM devices_to_filter
		)
LEFT JOIN dupe_fix d2 ON CONCAT (
		'stof',
		sam.stofcv
		) = d2.concept_code_1;

INSERT INTO internal_relationship_stage --Product to Dose Forms
SELECT DISTINCT CASE 
		WHEN mpp.OUC != 'C'
			THEN CONCAT (
					'mpp',
					sam.mppcv
					)
		ELSE CONCAT (
				'mpp',
				sam.mppcv,
				'-',
				sam.ppid
				)
		END,
	'gal' || mpp.galcv
FROM sources.ggr_mpp mpp
LEFT JOIN sources.ggr_sam sam ON sam.mppcv = mpp.mppcv
WHERE mpp.mppcv NOT IN (
		SELECT mppcv
		FROM devices_to_filter
		)
	AND sam.mppcv::int4 = 0;

INSERT INTO internal_relationship_stage --Product to Suppliers
SELECT DISTINCT CASE 
		WHEN mpp.OUC != 'C'
			THEN CONCAT (
					'mpp',
					mpp.mppcv
					)
		ELSE CONCAT (
				'mpp',
				sam.mppcv,
				'-',
				sam.ppid
				)
		END,
	CONCAT (
		'ir',
		mp.ircv
		)
FROM sources.ggr_mpp mpp
JOIN sources.ggr_sam sam ON sam.mppcv = mpp.mppcv
JOIN sources.ggr_mp mp ON mp.mpcv = mpp.mpcv
	AND CONCAT (
		'mp',
		mpp.mpcv
		) IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Brand Name'
		);

INSERT INTO internal_relationship_stage --Product to Brand Names
SELECT DISTINCT CASE 
		WHEN mpp.OUC != 'C'
			THEN CONCAT (
					'mpp',
					mpp.mppcv
					)
		ELSE CONCAT (
				'mpp',
				sam.mppcv,
				'-',
				sam.ppid
				)
		END,
	coalesce(du.concept_code_2, CONCAT (
			'mp',
			mpp.mpcv
			))
FROM sources.ggr_mpp mpp
LEFT JOIN dupe_fix du ON 'mp' || mpp.mpcv = du.concept_code_1
LEFT JOIN sources.ggr_sam sam ON sam.mppcv = mpp.mppcv
WHERE CONCAT (
		'mp',
		mpp.mpcv
		) IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Brand Name'
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Device'
		);

/*delete from internal_relationship_stage 
  where concept_code_2 like 'stof%'
  and concept_code_2 not in (select concept_code from drug_concept_stage where concept_class_id = 'Ingredient')*/;

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
	) --devices and duplicates are out of the way and packs are neatly organized, so it's best time to do it
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
	coalesce(du.concept_code_2, CONCAT (
			'stof',
			sam.stofcv
			)) AS ingredient_concept_code,
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
			sam.inq != 0
			AND sam.inbasu IS NOT NULL
			THEN sam.inbasu
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
			AND mpp.cq != 1
			THEN mpp.cq
		ELSE NULL
		END AS BOX_SIZE
FROM sources.ggr_mpp mpp
LEFT JOIN sources.ggr_sam sam ON mpp.mppcv = sam.mppcv
LEFT JOIN dupe_fix du ON du.concept_code_1 = CONCAT (
		'stof',
		sam.stofcv
		);

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
		AND ingredient_concept_code != 'stof01422'
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

/*
delete from ds_stage where drug_concept_code in ( --deletes incomplete entries
 SELECT concept_code_1
      FROM (SELECT DISTINCT concept_code_1, COUNT(concept_code_2) OVER (PARTITION BY concept_code_1) AS irs_cnt
            FROM internal_relationship_stage
              JOIN drug_concept_stage ON concept_code = concept_code_2 AND concept_class_id = 'Ingredient') irs
        JOIN (SELECT DISTINCT drug_concept_code, COUNT(ingredient_concept_code) OVER (PARTITION BY drug_concept_code) AS ds_cnt
              FROM ds_stage) ds
          ON drug_concept_code = concept_code_1   AND irs_cnt != ds_cnt); */

TRUNCATE TABLE concept_synonym_stage;

INSERT INTO concept_synonym_stage --English translations
SELECT NULL AS synonym_concept_id,
	concept_name AS synonym_concept_name,
	concept_code AS synonym_concept_code,
	'GGR' AS vocabulary_ID,
	4180186 AS language_concept_id --English
FROM drug_concept_stage
WHERE concept_class_id = ('Ingredient');


/* Ingredients */
INSERT INTO concept_synonym_stage --French Ingredients
SELECT NULL AS synonym_concept_id,
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
		);

INSERT INTO concept_synonym_stage --Dutch Ingredients
SELECT NULL AS synonym_concept_id,
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
		);

/* Dose Forms */
INSERT INTO concept_synonym_stage
SELECT NULL::int4 AS synonym_concept_id,
	concept_name_en AS synonym_concept_name,
	concept_code AS synonym_concept_code,
	'GGR' AS vocabulary_ID,
	4180186 AS language_concept_id --English
FROM tomap_form
WHERE concept_name_en IS NOT NULL

UNION

SELECT NULL::int4 AS synonym_concept_id,
	concept_name_fr AS synonym_concept_name,
	concept_code AS synonym_concept_code,
	'GGR' AS vocabulary_ID,
	4180190 AS language_concept_id --French
FROM tomap_form
WHERE concept_name_fr IS NOT NULL

UNION

SELECT NULL::int4 AS synonym_concept_id,
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

SELECT drug_concept_code,
	a.concept_name AS drug_concept_name,
	ingredient_concept_code,
	b.concept_name AS ingredient_concept_name,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size
FROM ds_stage d
JOIN drug_concept_stage a ON d.drug_concept_code = a.concept_code
JOIN drug_concept_stage b ON b.concept_code = d.ingredient_concept_code
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		GROUP BY drug_concept_code,
			ingredient_concept_code
		HAVING COUNT(1) > 1
		
		UNION ALL
		
		SELECT concept_code_1
		FROM (
			SELECT DISTINCT concept_code_1,
				COUNT(concept_code_2) OVER (PARTITION BY concept_code_1) AS irs_cnt
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code = concept_code_2
				AND concept_class_id = 'Ingredient'
			) irs
		JOIN (
			SELECT DISTINCT drug_concept_code,
				COUNT(ingredient_concept_code) OVER (PARTITION BY drug_concept_code) AS ds_cnt
			FROM ds_stage
			) ds ON drug_concept_code = concept_code_1
			AND irs_cnt != ds_cnt
		)

UNION

SELECT concept_code AS drug_concept_code,
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
FROM drug_concept_stage
WHERE concept_code NOT IN (
		SELECT concept_code_1
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Ingredient'
		)
	AND concept_code NOT IN (
		SELECT pack_concept_code
		FROM pc_stage
		)
	AND concept_class_id = 'Drug Product'

UNION

SELECT concept_code AS drug_concept_code,
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
	) s ON s.concept_code_1 = dcs.concept_code
WHERE dcs.concept_class_id = 'Drug Product'
	AND invalid_reason IS NULL;

ALTER TABLE dsfix ADD device VARCHAR(255);

ALTER TABLE dsfix ADD mapped_id int4;

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM dsfix
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT drug_concept_code
		FROM dsfix
		)
	AND concept_code_2 LIKE 'stof%';