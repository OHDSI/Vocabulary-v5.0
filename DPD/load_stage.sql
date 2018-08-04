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
* 
* Authors: Anna Ostropolets, Timur Vakhitov
* Date: 2017
**************************************************************************/

-- fix amount in packs
-- for base mapping use table rtc + pay attention to vaccines, insulines, brand names that are deprecated (some of them are ingredients, other need to be renovated in RxE)
-- manual: new_pack, new_pack_form, new_rtc, new_pc_stage_manual
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'DPD',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'DPD '||CURRENT_DATE,
	pVocabularyDevSchema	=> 'DEV_DPD'
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'RxNorm Extension',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'RxNorm Extension '||CURRENT_DATE,
	pVocabularyDevSchema	=> 'DEV_DPD',
	pAppendVocabulary		=> TRUE
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Input tables creation
DROP TABLE IF EXISTS DRUG_CONCEPT_STAGE;
CREATE TABLE DRUG_CONCEPT_STAGE
(
   CONCEPT_NAME             VARCHAR(255),
   VOCABULARY_ID            VARCHAR(20),
   CONCEPT_CLASS_ID         VARCHAR(25),
   SOURCE_CONCEPT_CLASS_ID  VARCHAR(25),
   STANDARD_CONCEPT         VARCHAR(1),
   CONCEPT_CODE             VARCHAR(50),
   POSSIBLE_EXCIPIENT       VARCHAR(1),
   DOMAIN_ID                VARCHAR(25),
   VALID_START_DATE         DATE,
   VALID_END_DATE           DATE,
   INVALID_REASON           VARCHAR(1)
);

DROP TABLE IF EXISTS DS_STAGE;
CREATE TABLE DS_STAGE
(
   DRUG_CONCEPT_CODE        VARCHAR(255),
   INGREDIENT_CONCEPT_CODE  VARCHAR(255),
   BOX_SIZE                 INTEGER,
   AMOUNT_VALUE             FLOAT,
   AMOUNT_UNIT              VARCHAR(255),
   NUMERATOR_VALUE          FLOAT,
   NUMERATOR_UNIT           VARCHAR(255),
   DENOMINATOR_VALUE        FLOAT,
   DENOMINATOR_UNIT         VARCHAR(255)
);

DROP TABLE IF EXISTS INTERNAL_RELATIONSHIP_STAGE;
CREATE TABLE INTERNAL_RELATIONSHIP_STAGE
(
   CONCEPT_CODE_1     VARCHAR(50),
   CONCEPT_CODE_2     VARCHAR(50)
);

DROP TABLE IF EXISTS RELATIONSHIP_TO_CONCEPT;
CREATE TABLE RELATIONSHIP_TO_CONCEPT
(
   CONCEPT_CODE_1     VARCHAR(255),
   VOCABULARY_ID_1    VARCHAR(20),
   CONCEPT_ID_2       INTEGER,
   PRECEDENCE         INTEGER,
   CONVERSION_FACTOR  FLOAT
);

DROP TABLE IF EXISTS PC_STAGE;
CREATE TABLE PC_STAGE
(
   PACK_CONCEPT_CODE  VARCHAR(255),
   DRUG_CONCEPT_CODE  VARCHAR(255),
   AMOUNT             INT4,
   BOX_SIZE           INT4
);

-- Sequence for omop-generated codes starting with the last code used in previous vocabulary
DO $_$
DECLARE
 ex INTEGER;
BEGIN
 SELECT MAX(replace(concept_code, 'OMOP','')::int4)+1 into ex FROM concept WHERE concept_code like 'OMOP%'  and concept_code not like '% %';
 DROP SEQUENCE IF EXISTS CONC_STAGE_SEQ;
 EXECUTE 'CREATE SEQUENCE CONC_STAGE_SEQ INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END $_$;



--4. create temporary tables
--use obvious classes to extract non_drugs
DROP TABLE IF EXISTS non_drug;
CREATE TABLE non_drug AS
SELECT DRUG_CODE AS OLD_CODE,
	PRODUCT_CATEGORIZATION,
	CLASS,
	LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') AS DRUG_CODE,
	BRAND_NAME,
	DESCRIPTOR,
	PEDIATRIC_FLAG,
	ACCESSION_NUMBER,
	NUMBER_OF_AIS,
	AI_GROUP_NO,
	NULL::VARCHAR AS INVALID_REASON
FROM sources.dpd_drug_all
WHERE UPPER(class) IN ('DISINFECTANT','VETERINARY','RADIOPHARMACEUTICAL');

--cosmetics: creams,sun protectors etc.
INSERT INTO non_drug
SELECT DRUG_CODE AS OLD_CODE,
	PRODUCT_CATEGORIZATION,
	CLASS,
	LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') AS DRUG_CODE,
	BRAND_NAME,
	DESCRIPTOR,
	PEDIATRIC_FLAG,
	ACCESSION_NUMBER,
	NUMBER_OF_AIS,
	AI_GROUP_NO,
	NULL::VARCHAR AS INVALID_REASON
FROM sources.dpd_drug_all
WHERE brand_name ~ 'FLOSS|ANTIPERSPIRANT|JOHNSON|MAKEUP|WRINKLE|NIVEA|ANTISEPTIQ|MAKE UP|BLEMISH|MAKE-UP|DEODORANT|\sLIP\s|\sSPF|SPF\s|SUNSCREEN|SUNCARE|MOISTURIZER|ANTIPERS|MOISTURIZING| CLEAR |WASH|SOAP|CATTLE|FOR DOGS|FOR CATS|BANANA|AVON|AVEENO'
	OR PRODUCT_CATEGORIZATION IN (
		'CAT IV - SUNBURN PROTECTANTS',
		'CAT IV - MED. SKIN CARE PROD./SUNBURN PROTECTANTS',
		'CAT IV - ANTIPERSPIRANTS'
		);

--hemodyalisis, antiseptics, cosmetics (split a query into 2)
INSERT INTO non_drug
SELECT DRUG_CODE AS OLD_CODE,
	PRODUCT_CATEGORIZATION,
	CLASS,
	LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') AS DRUG_CODE,
	BRAND_NAME,
	DESCRIPTOR,
	PEDIATRIC_FLAG,
	ACCESSION_NUMBER,
	NUMBER_OF_AIS,
	AI_GROUP_NO,
	NULL::VARCHAR AS INVALID_REASON
FROM sources.dpd_drug_all
WHERE brand_name ~ 'CATHETERIZATION| VENOUS |BIKINI|SANITIZER| SUN BLOCK|SKIN CLEANER|MOISTURE|SKIN CLEANSER| POUDRE|SPORTWEAR|DIALYSIS|SOLAIRE|DISCOLORATION|HAEMODIALYSIS|HAND SCRUB|SUNSCREEN|REVITALIZING|TRANSLUCENT|ANTIBACTERIAL|ANTIMICROBIAL| DRINK|MEDICATED BODY POWDER|CLEANSING|ANTISEPTIC|SHISEIDO|DISINFECTANT| TAPE '
	OR PRODUCT_CATEGORIZATION IN ('CAT IV - SUNBURN PROTECTANTS','CAT IV - MED. SKIN CARE PROD./SUNBURN PROTECTANTS','CAT IV - ANTIPERSPIRANTS');
--under consideration:  'CAT IV - ANTIDANDRUFF PRODUCTS', 

--use route that indicate non_drugs
INSERT INTO non_drug
SELECT dp.*
FROM (
	SELECT DRUG_CODE AS OLD_CODE,
		PRODUCT_CATEGORIZATION,
		CLASS,
		LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') AS DRUG_CODE,
		BRAND_NAME,
		DESCRIPTOR,
		PEDIATRIC_FLAG,
		ACCESSION_NUMBER,
		NUMBER_OF_AIS,
		AI_GROUP_NO,
		NULL::VARCHAR AS INVALID_REASON
	FROM sources.dpd_drug_all
	) dp
JOIN sources.dpd_route_all r ON r.drug_code = dp.old_code
WHERE r.route_of_administration ~ 'HOSPITAL|COMMERCIAL|DIALYSIS|UDDER WASH|ARTHOGRAPHY|HOUSEHOLD|LABORATORY|DISINFECTANT|CYSTOGRAPHY';

--contrast media
INSERT INTO non_drug
SELECT dp.*
FROM (
	SELECT DRUG_CODE AS OLD_CODE,
		PRODUCT_CATEGORIZATION,
		CLASS,
		LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') AS DRUG_CODE,
		BRAND_NAME,
		DESCRIPTOR,
		PEDIATRIC_FLAG,
		ACCESSION_NUMBER,
		NUMBER_OF_AIS,
		AI_GROUP_NO,
		NULL::VARCHAR AS INVALID_REASON
	FROM sources.dpd_drug_all
	) dp
JOIN sources.dpd_active_ingredients_all ai ON dp.old_code = ai.drug_code
WHERE ai.ingredient IN ('BARIUM SULFATE','IOHEXOL','IODIXANOL','IOXAGLATE MEGLUMINE','CYANOCOBALAMIN CO 57','IOXAGLATE SODIUM','IOVERSOL','IOTROLAN','IOPYDONE','IOPYDOL','IOTHALAMATE SODIUM',
'URANIUM NITRATE','IOTHALAMATE MEGLUMINE','IOPROMIDE','IOPANOIC ACID',	'IOPAMIDOL','DIATRIZOATE MEGLUMINE','DIATRIZOATE SODIUM','X-RAY','XENON 133 XE'
		);

--other non_drugs
INSERT INTO non_drug
SELECT dp.*
FROM (
	SELECT DRUG_CODE AS OLD_CODE,
		PRODUCT_CATEGORIZATION,
		CLASS,
		LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') AS DRUG_CODE,
		BRAND_NAME,
		DESCRIPTOR,
		PEDIATRIC_FLAG,
		ACCESSION_NUMBER,
		NUMBER_OF_AIS,
		AI_GROUP_NO,
		NULL AS INVALID_REASON
	FROM sources.dpd_drug_all
	) dp
JOIN sources.dpd_active_ingredients_all ai ON dp.old_code = ai.drug_code
WHERE ai.ingredient IN ('WIESBADEN','HUMAN PLASMA','HEMOGLOBIN (CRYSTALS ETC.)','MUSCLE (EXTRACT)','MASSA FERMENTATA MEDICINALIS','ANIMAL EXT HOMEOPATHIC');

--use drug forms that indicate non_drugs
INSERT INTO non_drug
SELECT dp.*
FROM (
	SELECT DRUG_CODE AS OLD_CODE,
		PRODUCT_CATEGORIZATION,
		CLASS,
		LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') AS DRUG_CODE,
		BRAND_NAME,
		DESCRIPTOR,
		PEDIATRIC_FLAG,
		ACCESSION_NUMBER,
		NUMBER_OF_AIS,
		AI_GROUP_NO,
		NULL AS INVALID_REASON
	FROM sources.dpd_drug_all
	) dp
JOIN sources.dpd_form_all f ON f.drug_code = dp.old_code
WHERE f.pharmaceutical_form IN ('STICK','WIPE','SWAB','FLOSS','CORD','BLOOD COLLECTION');

--create drug products
DROP TABLE IF EXISTS drug_product;
CREATE TABLE drug_product AS
SELECT *
FROM (
	SELECT DRUG_CODE AS OLD_CODE,
		PRODUCT_CATEGORIZATION,
		CLASS,
		LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') AS DRUG_CODE,
		BRAND_NAME,
		DESCRIPTOR,
		PEDIATRIC_FLAG,
		ACCESSION_NUMBER,
		NUMBER_OF_AIS,
		AI_GROUP_NO,
		CASE 
			WHEN DRUG_IDENTIFICATION_NUMBER IN (
					SELECT DRUG_IDENTIFICATION_NUMBER
					FROM sources.dpd_drug_all
					WHERE filler_column1 = 'marked_for_drug_ia'
					)
				THEN 'D'
			ELSE NULL
			END AS INVALID_REASON,
		row_number() OVER (
			PARTITION BY LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') ORDER BY DRUG_CODE
			) AS dupl_marker
	FROM sources.dpd_drug_all
	WHERE drug_code::VARCHAR NOT IN (
			--delete non-drug
			SELECT drug_code
			FROM non_drug
			)
	) AS s0
WHERE dupl_marker = 1; --remove duplicates

DROP TABLE IF EXISTS active_ingredients;
CREATE TABLE active_ingredients AS
SELECT b.DRUG_CODE,
	ACTIVE_INGREDIENT_CODE,
	INGREDIENT,
	STRENGTH,
	STRENGTH_UNIT,
	STRENGTH_TYPE,
	DOSAGE_VALUE,
	DOSAGE_UNIT,
	NOTES
FROM sources.dpd_active_ingredients_all a
JOIN drug_product b ON old_code = a.drug_code;

UPDATE active_ingredients
SET DOSAGE_UNIT = CASE 
		WHEN NOTES LIKE '%TAB%' THEN 'TAB'
		WHEN NOTES LIKE '%CAP%' THEN 'CAP'
		ELSE NULL END
WHERE drug_code IN ('763047','690082');

--update original data to remove inaccuracy (googled the drugs)
UPDATE active_ingredients SET DOSAGE_UNIT = 'G' WHERE DRUG_CODE = '2237089' AND INGREDIENT = 'POTASSIUM (POTASSIUM CARBONATE)';
UPDATE active_ingredients SET DOSAGE_UNIT = 'ML' WHERE DRUG_CODE = '42676' AND INGREDIENT = 'NEOMYCIN (NEOMYCIN SULFATE)';
UPDATE active_ingredients SET DOSAGE_UNIT = 'G' WHERE DRUG_CODE = '358177' AND INGREDIENT = 'NEOMYCIN (NEOMYCIN SULFATE)';
UPDATE active_ingredients SET STRENGTH = '0.1', STRENGTH_UNIT = '%' WHERE DRUG_CODE = '2023326' AND INGREDIENT = 'EPINEPHRINE';
UPDATE active_ingredients SET STRENGTH_UNIT = 'MG', DOSAGE_UNIT = 'G' WHERE DRUG_CODE = '358177' AND INGREDIENT = 'DEXAMETHASONE';

--homeopathy

UPDATE active_ingredients   SET dosage_value = '13.5',       dosage_unit = 'ML' WHERE drug_code = '2237356' AND   ingredient = 'GALACTOSE';
UPDATE active_ingredients SET DOSAGE_UNIT = NULL, DOSAGE_VALUE = NULL WHERE DRUG_CODE IN ('2232194','2232560','2233721','2233291','711470');
UPDATE active_ingredients SET DOSAGE_UNIT = 'ML', DOSAGE_VALUE = NULL  WHERE DRUG_CODE IN ('1927841','2232643','2232626','2232604','2232583','2232582');
UPDATE active_ingredients SET DOSAGE_VALUE = NULL, DOSAGE_UNIT = NULL WHERE DRUG_CODE = '2238526';
UPDATE active_ingredients SET STRENGTH = NULL, STRENGTH_UNIT = NULL, DOSAGE_UNIT = NULL WHERE DRUG_CODE = '2211017';
UPDATE active_ingredients SET ingredient = 'VITAMIN D' WHERE ingredient = 'VITAMIN D (DEXPANTHENOL)';
UPDATE active_ingredients SET dosage_value = NULL,dosage_unit = NULL WHERE drug_code = '2239121';
UPDATE active_ingredients SET ingredient = 'Melphalan' WHERE ingredient = 'BUFFER SOLUTION';
UPDATE active_ingredients   SET strength = '22',       dosage_value = NULL,       dosage_unit = 'ML' WHERE drug_code = '2405024' AND   ingredient = 'TRASTUZUMAB';
UPDATE active_ingredients SET dosage_unit = 'G' WHERE drug_code = '2248193' AND ingredient = 'POTASSIUM (POTASSIUM BICARBONATE)';
UPDATE active_ingredients SET STRENGTH = '27.5' WHERE DRUG_CODE = '2245464' AND INGREDIENT = 'PHOSPHOLIPID';
UPDATE active_ingredients SET STRENGTH = '50' WHERE DRUG_CODE = '1900609' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXINE HYDROCHLORIDE)';
UPDATE active_ingredients SET STRENGTH = '5' WHERE DRUG_CODE = '1901109' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXINE HYDROCHLORIDE)';
UPDATE active_ingredients SET STRENGTH = '125' WHERE DRUG_CODE = '1901117' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXINE HYDROCHLORIDE)';
UPDATE active_ingredients SET STRENGTH = '31.6' WHERE DRUG_CODE = '2231701' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXINE HYDROCHLORIDE)';
UPDATE active_ingredients SET STRENGTH = '31' WHERE DRUG_CODE = '678961' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXINE HYDROCHLORIDE)';
UPDATE active_ingredients SET STRENGTH = '12.5' WHERE DRUG_CODE = '839167' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXINE HYDROCHLORIDE)';
UPDATE active_ingredients SET STRENGTH = '50' WHERE DRUG_CODE = '849863' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXINE HYDROCHLORIDE)';
UPDATE active_ingredients SET STRENGTH = '10' WHERE DRUG_CODE = '899917' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXINE HYDROCHLORIDE)';
UPDATE active_ingredients SET strength_unit = 'CH' WHERE drug_code = '2243633';
DELETE FROM active_ingredients WHERE drug_code = '2237356' AND   ingredient = 'GALACTOSE';
DELETE FROM active_ingredients WHERE DRUG_CODE = '1905023' AND INGREDIENT = 'GLYCERINE';
DELETE FROM active_ingredients WHERE DRUG_CODE = '319341' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXAL-5-PHOSPHATE)';
DELETE FROM active_ingredients WHERE DRUG_CODE = '1900609' AND INGREDIENT = 'CASEIN HYDROLYSATE';
DELETE FROM active_ingredients WHERE DRUG_CODE = '1901109' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXAL-5-PHOSPHATE)';
DELETE FROM active_ingredients WHERE DRUG_CODE = '1901117' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXAL-5-PHOSPHATE)';
DELETE FROM active_ingredients WHERE DRUG_CODE = '2231701' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXAL-5-PHOSPHATE)';
DELETE FROM active_ingredients WHERE DRUG_CODE = '678961' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXAL-5-PHOSPHATE)';
DELETE FROM active_ingredients WHERE DRUG_CODE = '839167' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXAL-5-PHOSPHATE)';
DELETE FROM active_ingredients WHERE DRUG_CODE = '849863' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXAL-5-PHOSPHATE)';
DELETE FROM active_ingredients WHERE DRUG_CODE = '899917' AND INGREDIENT = 'VITAMIN B6 (PYRIDOXAL-5-PHOSPHATE)';
DELETE FROM active_ingredients WHERE INGREDIENT = 'SURFACTANT-ASSOCIATED PROTEINS SP-B AND SP-C';
DELETE FROM active_ingredients WHERE drug_code = '2087286' AND   ingredient = 'Melphalan';
DELETE FROM active_ingredients WHERE drug_code = '2202034' AND   ingredient = 'D-ALPHA TOCOPHERYL ACID SUCCINATE';
DELETE FROM active_ingredients WHERE strength_unit='TRACE';

--delete and update inert ingredients
DELETE FROM active_ingredients WHERE drug_code = '792942' AND   ingredient = 'ALCOHOL ANHYDROUS';
DELETE FROM active_ingredients WHERE drug_code = '779539' AND   ingredient = 'GUMWEED';
DELETE FROM active_ingredients WHERE drug_code = '779539' AND   ingredient = 'AMMONIUM ACETATE';
DELETE FROM active_ingredients WHERE drug_code = '779539' AND   ingredient = 'SQUILL';
DELETE FROM active_ingredients WHERE drug_code = '770418' AND   ingredient = 'SODIUM CHLORIDE';
DELETE FROM active_ingredients WHERE drug_code = '616117' AND   ingredient = 'PROPYLENE GLYCOL';
DELETE FROM active_ingredients WHERE drug_code = '593605' AND   ingredient = 'ALCOHOL ANHYDROUS';
DELETE FROM active_ingredients WHERE drug_code = '560227' AND   ingredient = 'PROPYLENE GLYCOL';
DELETE FROM active_ingredients WHERE drug_code = '560170' AND   ingredient = 'PROPYLENE GLYCOL';
DELETE FROM active_ingredients WHERE drug_code = '551864' AND   ingredient = 'EVENING PRIMROSE OIL';
DELETE FROM active_ingredients WHERE drug_code = '542873' AND   ingredient = 'CLOVE OIL';
DELETE FROM active_ingredients WHERE drug_code = '507407' AND   ingredient = 'ALCOHOL ANHYDROUS';
DELETE FROM active_ingredients WHERE drug_code = '342408' AND   ingredient = 'BOVINE PLASMA';
DELETE FROM active_ingredients WHERE drug_code = '342394' AND   ingredient = 'BOVINE PLASMA';
DELETE FROM active_ingredients WHERE drug_code = '338265' AND   ingredient = 'BOVINE PLASMA';
DELETE FROM active_ingredients WHERE drug_code = '307548' AND   ingredient = 'ALCOHOL ANHYDROUS';
DELETE FROM active_ingredients WHERE drug_code = '2439476' AND   ingredient = 'PROPYLENE GLYCOL';
DELETE FROM active_ingredients WHERE drug_code = '2355973' AND   ingredient = 'STERILE WATER (DILUENT)';
DELETE FROM active_ingredients WHERE drug_code = '2242073' AND   ingredient = 'STERILE WATER (DILUENT)';
DELETE FROM active_ingredients WHERE drug_code = '223956' AND   ingredient = 'PROPYLENE GLYCOL';
DELETE FROM active_ingredients WHERE drug_code = '2231656' AND   ingredient = 'SODIUM CHLORIDE';
DELETE FROM active_ingredients WHERE drug_code = '2231655' AND   ingredient = 'SODIUM CHLORIDE';
DELETE FROM active_ingredients WHERE drug_code = '2231516' AND   ingredient = 'SODIUM CHLORIDE';
DELETE FROM active_ingredients WHERE drug_code = '2231142' AND   ingredient = 'SODIUM CHLORIDE';
DELETE FROM active_ingredients WHERE drug_code = '2231515' AND   ingredient = 'SODIUM CHLORIDE';
DELETE FROM active_ingredients WHERE drug_code = '2231141' AND   ingredient = 'SODIUM CHLORIDE';
DELETE FROM active_ingredients WHERE drug_code = '2231140' AND   ingredient = 'SODIUM CHLORIDE';
DELETE FROM active_ingredients WHERE drug_code = '2231139' AND   ingredient = 'SODIUM CHLORIDE';
DELETE FROM active_ingredients WHERE drug_code = '2231138' AND   ingredient = 'SODIUM CHLORIDE';
DELETE FROM active_ingredients WHERE drug_code = '2230769' AND   ingredient = 'ALCOHOL ANHYDROUS';
DELETE FROM active_ingredients WHERE drug_code = '1962930' AND   ingredient = 'SODIUM CHLORIDE';
DELETE FROM active_ingredients WHERE drug_code = '1962922' AND   ingredient = 'SODIUM CHLORIDE';
DELETE FROM active_ingredients WHERE drug_code = '1962914' AND   ingredient = 'SODIUM CHLORIDE';
DELETE FROM active_ingredients WHERE drug_code = '1915517' AND   ingredient = 'SORBITOL';
DELETE FROM active_ingredients WHERE drug_code = '2215136' AND   ingredient = 'SODIUM CHLORIDE';
DELETE FROM active_ingredients WHERE drug_code = '2047799' AND   ingredient = 'ALCOHOL ANHYDROUS';
DELETE FROM active_ingredients WHERE drug_code = '151254' AND   ingredient = 'SORBITOL';
DELETE FROM active_ingredients WHERE drug_code = '2237317' AND   ingredient = 'SODIUM CHLORIDE';
UPDATE active_ingredients   SET strength_type = '',       dosage_value = '2',       dosage_unit = 'ML' WHERE drug_code = '2237317' AND   ingredient = 'INTERFERON BETA-1A';
UPDATE active_ingredients   SET dosage_value = '5',       dosage_unit = 'ML' WHERE drug_code = '2215136';
UPDATE active_ingredients   SET dosage_value = '20',       dosage_unit = 'ML' WHERE drug_code = '2231142' AND   ingredient = 'THROMBIN (BOVINE)';
UPDATE active_ingredients   SET dosage_value = '10',       dosage_unit = 'ML' WHERE drug_code = '2231141' AND   ingredient = 'THROMBIN (BOVINE)';
UPDATE active_ingredients   SET dosage_value = '20',       dosage_unit = 'ML' WHERE drug_code = '2231140' AND   ingredient = 'THROMBIN (BOVINE)';
UPDATE active_ingredients   SET dosage_value = '10',       dosage_unit = 'ML' WHERE drug_code = '2231139' AND   ingredient = 'THROMBIN (BOVINE)';
UPDATE active_ingredients   SET dosage_value = '5',       dosage_unit = 'ML' WHERE drug_code = '2231138' AND   ingredient = 'THROMBIN (BOVINE)';
UPDATE active_ingredients   SET strength_unit = '%' WHERE drug_code = '2009080' AND   ingredient = 'EPINEPHRINE';
UPDATE active_ingredients   SET dosage_value = '25',       dosage_unit = 'ML' WHERE drug_code = '1962930' AND   ingredient = 'MENINGOCOCCAL POLYSACCHARIDE ANTIGEN GROUP A';
UPDATE active_ingredients   SET dosage_value = '25',       dosage_unit = 'ML' WHERE drug_code = '1962930' AND   ingredient = 'MENINGOCOCCAL POLYSACCHARIDE ANTIGEN GROUP C';
UPDATE active_ingredients   SET dosage_value = '5',       dosage_unit = 'ML' WHERE drug_code = '1962922' AND   ingredient = 'MENINGOCOCCAL POLYSACCHARIDE ANTIGEN GROUP A';
UPDATE active_ingredients   SET dosage_value = '5',       dosage_unit = 'ML' WHERE drug_code = '1962922' AND   ingredient = 'MENINGOCOCCAL POLYSACCHARIDE ANTIGEN GROUP C';
UPDATE active_ingredients   SET dosage_value = '0.5',       dosage_unit = 'ML' WHERE drug_code = '1962914' AND   ingredient = 'MENINGOCOCCAL POLYSACCHARIDE ANTIGEN GROUP A';
UPDATE active_ingredients   SET dosage_value = '0.5',       dosage_unit = 'ML' WHERE drug_code = '1962914' AND   ingredient = 'MENINGOCOCCAL POLYSACCHARIDE ANTIGEN GROUP C';

DROP TABLE IF EXISTS route;
CREATE TABLE route AS
SELECT b.DRUG_CODE,
	ROUTE_OF_ADMINISTRATION
FROM sources.dpd_route_all a
JOIN drug_product b ON old_code = a.drug_code;

DROP TABLE IF EXISTS form;
CREATE TABLE form AS
SELECT b.DRUG_CODE,
	PHARMACEUTICAL_FORM
FROM sources.dpd_form_all a
JOIN drug_product b ON old_code = a.drug_code;

DROP TABLE IF EXISTS packaging;
CREATE TABLE packaging AS
SELECT b.DRUG_CODE,
	PACKAGE_SIZE_UNIT,
	PACKAGE_TYPE,
	PACKAGE_SIZE,
	PRODUCT_INFORMATION
FROM sources.dpd_packaging_all a
JOIN drug_product b ON old_code = a.drug_code;

DROP TABLE IF EXISTS status;
CREATE TABLE status AS
SELECT b.DRUG_CODE,
	STATUS,
	HISTORY_DATE,
	CURRENT_STATUS_FLAG
FROM sources.dpd_status_all a
JOIN drug_product b ON old_code = a.drug_code;

DROP TABLE IF EXISTS companies;
CREATE TABLE companies AS
SELECT b.DRUG_CODE,
	MFR_CODE,
	COMPANY_CODE,
	COMPANY_NAME,
	COMPANY_TYPE,
	ADDRESS_MAILING_FLAG,
	ADDRESS_BILLING_FLAG,
	ADDRESS_NOTIFICATION_FLAG,
	ADDRESS_OTHER,
	SUITE_NUMBER,
	STREET_NAME,
	CITY_NAME,
	PROVINCE,
	COUNTRY,
	POSTAL_CODE,
	POST_OFFICE_BOX
FROM sources.dpd_companies_all a
JOIN drug_product b ON old_code = a.drug_code;

UPDATE companies SET COMPANY_NAME = 'BLAIREX LABORATORIES INC.' WHERE COMPANY_NAME = 'BLAIREX LABORATORIES, INC.';
UPDATE companies SET COMPANY_NAME='BAYER INC' WHERE DRUG_CODE='2130238';

--update a single inaccuracy in the manufacturers
UPDATE companies SET company_name = 'BAXTER AG' WHERE company_name = 'OSTERREICHISCHES INSTITUT FUR HAEMODERIVATE GES M.B.H.';

DROP TABLE IF EXISTS therapeutic_class;
CREATE TABLE therapeutic_class AS
SELECT b.DRUG_CODE,
	TC_ATC_NUMBER,
	TC_ATC,
	TC_AHFS_NUMBER,
	TC_AHFS
FROM sources.dpd_therapeutic_class_all a
JOIN drug_product b ON old_code = a.drug_code;

--Table with units for drug_concept_stage
DROP TABLE IF EXISTS unit;
CREATE TABLE unit AS
SELECT DISTINCT UPPER(strength_unit) AS concept_name,
	UPPER(strength_unit) AS concept_code,
	'Unit' AS concept_class_id
FROM active_ingredients
WHERE strength_unit IS NOT NULL
	AND strength_unit != 'NIL';

INSERT INTO unit (concept_name,concept_code, concept_class_id)
VALUES ('SQ CM','SQ CM', 'Unit');
INSERT INTO unit (concept_name,concept_code, concept_class_id)
VALUES ('L','L', 'Unit');
INSERT INTO unit (concept_name,concept_code, concept_class_id)
VALUES ('HOUR','HOUR', 'Unit');
INSERT INTO unit (concept_name,concept_code, concept_class_id)
VALUES ('ACT','ACT', 'Unit');

--Drug manufacturer
DROP TABLE IF EXISTS manufacturer;
CREATE TABLE manufacturer AS
SELECT DISTINCT drug_code,
	company_name AS concept_name,
	trim(regexp_replace(regexp_replace(regexp_replace(regexp_replace(company_name, '( INC(\.)?)$|CORPORATION|LIMITED|( CORP$)|( L\.P\.)|( GMBH)|( CO)$|( CORP\.)|( CO\.)|( PLC)|( LTD)|( LTEE)', '','g'), '(\.|,)$', '','g'), '\(\D+\)|\(\d+\)', '','g'),'\s\s',' ','g')) AS new_name,
	'Supplier' AS concept_class_id
FROM companies;

UPDATE manufacturer
SET new_name='Alk Abello A/S'
WHERE INITCAP(new_name) = 'Alk - Abello A/S';
UPDATE manufacturer
SET new_name='Biogen Canada'
WHERE INITCAP(new_name) = 'Bioverativ Canada';
UPDATE manufacturer
SET new_name='Shiseido Americas'
WHERE INITCAP(new_name) = 'Shiseido Americas Dist';
UPDATE manufacturer
SET new_name='Les Laboratoires Swisse'
WHERE INITCAP(new_name) = 'Les Laboratoires Suisse';

--Ingredient
DROP TABLE IF EXISTS ingr;
CREATE TABLE ingr AS
SELECT drug_code,
	active_ingredient_code AS AIC,
	ingredient AS concept_name,
	'Ingredient'::VARCHAR AS concept_class_id
FROM active_ingredients;

--Updating ingredients in order to delete all unnecessary information
UPDATE ingr
SET concept_name = REGEXP_REPLACE(concept_name, ' \(.*\)', '','g')
WHERE concept_name ~ '\(.*\)$'
	AND NOT concept_name ~ '(\()HUMAN|RABBIT|RECOMBINANT|SYNTHETIC|ACTIVATED|OVINE|ANHYDROUS|VICTORIA|YAMAGATA|PMSG|H3N2|H1N1|NPH|8|V.C.O|D.C.O|FIM|PRP-T|FSH|BCG|R-METHUG-CSF|MCT|JERYL LYNN STRAIN|EQUINE|DILUENT|WISTAR RA27/3 STRAIN|EDMONSTON B STRAIN|HAEMAGGLUTININ-STRAIN B|Neisseria meningitidis group B NZ98/254 strain|2|DOLOMITE|TUBERCULIN TINE TEST|LEAVESKELP, POTASSIUM IODIDE|TI 201|\[CUMIB4\]BF4|ETHYLENEOXY|CALCIFEROL|MA HUANG|BASIC|EXT\.|CALF|LIVER|PAW|PORK(\))';

UPDATE ingr
SET concept_name = REGEXP_REPLACE(concept_name, ' \(.*\)', '','g')
WHERE concept_name LIKE '%(%BASIC%)'
	AND concept_name NOT LIKE '%(DIBASIC)'
	AND concept_name NOT LIKE '%(TRIBASIC)';

--Create table with precise name taken from original table to use later
DROP TABLE IF EXISTS ingr_OMOP;
CREATE TABLE ingr_OMOP AS
SELECT DISTINCT drug_code,
	active_ingredient_Code AS AIC,
	ingredient AS concept_name,
	'Ingredient'::VARCHAR AS concept_class_id
FROM active_ingredients;

UPDATE ingr_OMOP
SET concept_name = SUBSTRING(concept_name, '\(.*\)')
WHERE (
		NOT concept_name ~* '(\()HUMAN|RABBIT|RECOMBINANT|SYNTHETIC|ACTIVATED|OVINE|ANHYDROUS|BASIC|VICTORIA|YAMAGATA|PMSG|H3N2|H1N1|NPH|8|V.C.O|D.C.O|FIM|PRP-T|FSH|BCG|R-METHUG-CSF|MCT|JERYL LYNN STRAIN|EQUINE|DILUENT|WISTAR RA27/3 STRAIN|SACUBITRIL VALSARTAN SODIUM HYDRATE COMPLEX|EDMONSTON B STRAIN|HAEMAGGLUTININ-STRAIN B(\))'
		AND NOT concept_name ~ '(\()Neisseria meningitidis group B NZ98/254 strain|2|DOLOMITE|TUBERCULIN TINE TEST|BONE MEAL|FISH OIL|LEMON GRASS|LEAVES|ACETATE|YEAST|KELP|TI 201|COD LIVER OIL|\[CU\(MIB\)4\]BF4|ETHYLENEOXY|PAPAYA|CALCIFEROL|MA HUANG|HORSETAIL|FLAXSEED|EXT\.|ROTH|CALF|PINEAPPLE|LIVER|PAW|PORK(\))'
		)
	OR (
		concept_name LIKE '%(%BASIC%)'
		AND concept_name NOT LIKE '%(DIBASIC)'
		AND concept_name NOT LIKE '%(TRIBASIC)'
		);

DELETE
FROM ingr_OMOP
WHERE NULLIF(concept_name, '') IS NULL
	OR concept_name ~ '(\()MCT|HUMAN|RABBIT|RECOMBINANT|SYNTHETIC|ACTIVATED|OVINE|ANHYDROUS|VICTORIA|YAMAGATA|PMSG|H3N2|H1N1|NPH|8|V.C.O|D.C.O|FIM|PRP-T|FSH|BCG|R-METHUG-CSF|JERYL LYNN STRAIN|EQUINE|DILUENT|WISTAR RA27/3 STRAIN|SACUBITRIL VALSARTAN SODIUM HYDRATE COMPLEX(\))'
	OR concept_name ~ '(\()EDMONSTON B STRAIN|HAEMAGGLUTININ-STRAIN B|Neisseria meningitidis group B NZ98/254 strain|2|DOLOMITE|TUBERCULIN TINE TEST|BONE|LEMON GRASS|LEAVES|ACETATE|YEAST|KELP|TI 201|\[CU|MIB4\]BF4|ETHYLENEOXY|PAPAYA|CALCIFEROL|MA HUANG|HORSETAIL|FLAXSEED|EXT\.|ROTH|CALF|PINEAPPLE|PAW|PORK(\))';

UPDATE ingr_OMOP
SET concept_name = REGEXP_REPLACE(concept_name, '\(', '','g');
UPDATE ingr_OMOP
SET concept_name = REGEXP_REPLACE(concept_name, '\)', '','g');

DELETE
FROM ingr_OMOP
WHERE concept_name ~ 'OIL|EGG|BONE|CRYSTALS|ACEROLA|ROSE HIPS|BUCKWHEAT|CHLORDAN|1-PIPERIDYLTHIOCARBONYL|RHIZOPUS|DRIED|ALOE|SENNA|OYSTER|WHEAT|VITAMIN |ASPERGILLUS|ANANAS|BARLEY|BORAGO';

DELETE
FROM ingr_OMOP
WHERE concept_name LIKE '%,%'
	AND concept_name NOT LIKE '%KELP%';

DELETE
FROM ingr_OMOP
WHERE concept_name IN (
		'D.C.O.',
		'BCG',
		'DEXTROSE',
		'EPHEDRA',
		'CIG',
		'S',
		'BLACK CURRANT',
		'ATTENUAT. STRAIN SA14-14-2 PRODUCED IN VERO CELLS',
		'FEVERFEW',
		'EXTRACT',
		'H1N1V-LIKE STRAIN X-179A',
		'H5N1',
		'HOMEO',
		'III',
		'INS',
		'LIVER EXTRACT',
		'PRP',
		'NUTMEG',
		'RHPDGF-BB',
		'SAGO PALM',
		'SEA PROTEINATE',
		'SOYBEAN',
		'VIRIDANS AND NON-HEMOLYTIC',
		'PURIFIED CHICK EMBRYO CELL CULTURE',
		'DURAPATITE',
		'OXYCARBONATE',
		'BENZOTHIAZOLE',
		'BENZOTHIAZOLE',
		'MORPHOLINOTHIO',
		'OKA/MERCK STRAIN'
		);

DELETE FROM INGR_OMOP WHERE DRUG_CODE = '782971' AND AIC = '10225' AND CONCEPT_NAME = 'POVIDONE-IODINE';
DELETE FROM INGR_OMOP WHERE DRUG_CODE = '593710' AND AIC = '105' AND CONCEPT_NAME = 'MAGNESIUM OXIDE';
DELETE FROM INGR_OMOP WHERE DRUG_CODE = '94498' AND AIC = '778' AND CONCEPT_NAME = 'MAGNESIUM CITRATE';

UPDATE ingr
SET concept_name = REGEXP_REPLACE(concept_name, ' \(.*\)', '','g')
WHERE concept_name LIKE '%(%,%)%'
	AND drug_code IN (
		SELECT drug_code
		FROM ingr_OMOP
		);

--Creating table with final ingredient names, also will be used in drug_strength_stage.picn stands for precise ingredient concept name
DROP TABLE IF EXISTS ingr_2;
CREATE TABLE ingr_2 AS
SELECT DISTINCT a.concept_name AS PICN,
	c.drug_code,
	c.AIC,
	c.CONCEPT_NAME,
	STRENGTH,
	STRENGTH_UNIT,
	STRENGTH_TYPE,
	DOSAGE_VALUE,
	DOSAGE_UNIT,
	NOTES
FROM ingr c
JOIN active_ingredients b ON c.aic = b.active_ingredient_code
	AND b.drug_code = c.drug_code
LEFT JOIN ingr_OMOP a ON a.AIC = c.AIC
	AND a.drug_code = c.drug_code
	AND INGREDIENT ~ a.concept_name;

UPDATE ingr_2 SET concept_name = PICN WHERE PICN IS NOT NULL;

UPDATE ingr_2
SET concept_name = REGEXP_REPLACE(concept_name, ' \(.*\)', '','g')
WHERE concept_name LIKE '%(%,%)%'
	OR concept_name LIKE '%(DOLOMITE)%'
	OR concept_name LIKE '%(LIVER)%'
	OR concept_name LIKE '%(CALCIFEROL)%'
	OR concept_name LIKE '%(ACETATE)%';

UPDATE ingr_2
SET STRENGTH = '10'
WHERE STRENGTH = ' 10'
	AND STRENGTH_UNIT = '%'
	AND DOSAGE_VALUE IS NULL
	AND DOSAGE_UNIT = '%'
	AND drug_code = '2229776';

UPDATE ingr_2
SET CONCEPT_NAME = 'SENNOSIDES B'
WHERE CONCEPT_NAME = 'B';

DELETE
FROM ingr_2 -- delete water as unimportant ingredient
WHERE CONCEPT_NAME = 'x'
	OR (
		drug_code IN (
			SELECT DRUG_CODE
			FROM ingr
			WHERE drug_code IN (
					SELECT DRUG_CODE
					FROM ingr
					WHERE aic IN ('8826','893')
					)
			GROUP BY drug_code
			HAVING COUNT(1) > 1
			)
		AND aic IN ('8826','893')
		);

--Deleting all pseudo-units
UPDATE ingr_2
SET strength_unit = NULL
WHERE STRENGTH_UNIT = 'NIL';

UPDATE ingr_2
SET strength = NULL
WHERE STRENGTH = '0';

UPDATE ingr_2
SET dosage_unit = NULL
WHERE dosage_unit IN (
'TAB','CAP','BLISTER','LOZ','PCK','PIECE','SUP','ECT','NS','EVT','TSP','GUM','SRC','WAF','SRT','SUT','SLT','SRD','DOSE','DROP','SPRAY','VIAL','CARTRIDGE','INSERT',
'PAD','PATCH','PCK','PEN','SUT','SYR','TBS','W/W','W/V','V/V','V/W','CYLR','ECT','IMP','SUP','JAR','SYR','SRT','PAIL','VTAB','CH','CAN','D','DH','TABL','EVT','ECC','ECT','XMK','X',
'LOZ','BLISTER','PIECE','WAF','SRC','TSP','SLT','NS','PAD','AMP','BOTTLE','TEA','KIT','STRIP','NIL','GM'
		);

--Forms
DROP TABLE IF EXISTS forms;
CREATE TABLE forms AS (
	SELECT DISTINCT CASE 
		WHEN ROUTE_OF_ADMINISTRATION || ' ' || PHARMACEUTICAL_FORM = '0-UNASSIGNED SOLUTION' THEN 'SOLUTION'
		WHEN ROUTE_OF_ADMINISTRATION = 'NIL' THEN PHARMACEUTICAL_FORM
		WHEN DRUG_CODE IN ('724041','1955330','1983776') THEN 'ORAL SOLUTION'
		ELSE ROUTE_OF_ADMINISTRATION || ' ' || PHARMACEUTICAL_FORM
		END AS concept_name,
	'Dose Form' AS concept_class_id,
	drug_code FROM (
	SELECT DRUG_CODE,
		PHARMACEUTICAL_FORM,
		ROUTE_OF_ADMINISTRATION
	FROM form
	JOIN drug_product USING (drug_code)
	LEFT JOIN route USING (drug_code)
	) AS s0 WHERE drug_code NOT IN (
		SELECT concept_code
		FROM new_pack
		));

--Delete form duplicates
DELETE FROM forms f WHERE EXISTS (SELECT 1 FROM forms f_int WHERE f_int.drug_code = f.drug_code AND f_int.ctid > f.ctid);

--Table with forms for drug_concept_stage
DROP TABLE IF EXISTS forms_2;
CREATE TABLE forms_2 AS
SELECT DISTINCT concept_name,
	concept_class_id
FROM forms;

--Brand Names
DROP TABLE IF EXISTS brand_name;
CREATE TABLE brand_name AS
SELECT DISTINCT drug_code,
	brand_name,
	REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(brand_name, '(\s|-)(CAPSULES|STERILE|POWDER|INTRATHECAL|DESINFECTANT|CAPSULE|CAPLETS|CAPLET|CAPS|CAP|ONT|SOLTN|SHP|INJECTABLE|SHAMPOO|INFUSION|CONCENTRATE|LOZENGES|SUPPOSITORY|INTRAVENOUS|DISPERSIBLE|LOZENGE|VAGINAL|INJ\.|CHEWABLE|CHEW|SUPPOSITORIES|LIQUID|LIQ|OPHTHALMIC|OPH|SUSPENSION|SUS|SRT|ORAL|RINSE|ORL|SOLUTION|SOLTN|SOL|LETS|PWS|SYR|PWR|GRANULE|SUPPOSITOIRE|DROPS|SYRUP|VIAL|IMPLANT|STK|GRAN|TABLETS|TABLET|TAB|FOR|INJECTION|INJ)(\s|,)', ' ','g'), '\(.*\)', '','g'), '\s-\s.*', '','g') AS new_name
FROM drug_product
WHERE (
		NOT brand_name ~ '(\((D\d|S#|R))|(\dDH)|(\s\dD)|(\d+X)|((\dCH))|(\sUSP)|(AVEC)|(\sCATH)|(COMPOS)|(ACID CONCENTRATE)|(CONCENTRATED)|(STANDARDIZED)|(HOMEOPATHIC MEDICINE)|(HAEMODIALYSIS)|(HAND SCRUB)|(SUNSCREEN)|(\sFPS)|(\sSPF)'
		OR brand_name ~ 'INJEEL|FORTE|HEEL'
		);

--updating bunch of BN that have different patterns but are divided from a single BN
UPDATE brand_name
SET new_name = 'ROFERON-A'
WHERE new_name LIKE '%ROFERON%';

UPDATE brand_name
SET new_name = 'BENZAGEL'
WHERE new_name LIKE '%BENZAGEL%';

UPDATE brand_name
SET new_name = 'TYLENOL'
WHERE new_name LIKE '%TYLENOL%';

UPDATE brand_name
SET new_name = 'NEUTROGENA'
WHERE new_name LIKE '%NEUTROGENA%';

UPDATE brand_name
SET new_name = 'TRAVASOL'
WHERE new_name LIKE '%TRAVASOL%';

UPDATE brand_name
SET new_name = 'OGEN'
WHERE new_name LIKE '%OGEN%';

UPDATE brand_name
SET new_name = 'VICKS'
WHERE new_name LIKE '%VICKS%';

UPDATE brand_name
SET new_name = 'ADALAT'
WHERE new_name LIKE '%ADALAT%';

UPDATE brand_name
SET new_name = 'HEAD & SHOULDERS'
WHERE new_name LIKE '%HEAD & SHOULDERS%';

UPDATE brand_name
SET new_name = 'HAEMOSOL'
WHERE new_name LIKE '%HAEMOSOL%';

UPDATE brand_name
SET new_name = 'HAEMOSOL'
WHERE new_name LIKE '%HEMASATE%'
	OR new_name LIKE '%HEMOSATE%';

UPDATE brand_name
SET new_name = 'RELISORM'
WHERE new_name LIKE '%RELISORM%';

UPDATE brand_name
SET new_name = 'DELFLEX'
WHERE new_name LIKE '%DELFLEX%';

UPDATE brand_name
SET new_name = 'DELFLEX'
WHERE new_name LIKE '%NATURALYTE%';

UPDATE brand_name
SET new_name = 'GYNECURE'
WHERE new_name LIKE '%GYNECURE%';

UPDATE brand_name
SET new_name = 'NITRO-DUR'
WHERE new_name LIKE '%NITRO-DUR%';

UPDATE brand_name
SET new_name = 'MYLAN-NITRO PATCH'
WHERE new_name LIKE '%MYLAN-NITRO PATCH%';

UPDATE brand_name
SET new_name = 'TRANSDERM-NITRO'
WHERE new_name LIKE '%TRANSDERM-NITRO%';

UPDATE brand_name
SET new_name = 'AMINOSYN'
WHERE new_name LIKE '%AMINOSYN%';

UPDATE brand_name
SET new_name = 'BALMINIL'
WHERE new_name LIKE '%BALMINIL%';

UPDATE brand_name
SET new_name = 'BEMINAL'
WHERE new_name LIKE '%BEMINAL%';

UPDATE brand_name
SET new_name = 'BENYLIN'
WHERE new_name LIKE '%BENYLIN%';

UPDATE brand_name
SET new_name = 'DIANEAL'
WHERE new_name LIKE '%DIANEAL%';

UPDATE brand_name
SET new_name = 'MAALOX'
WHERE new_name LIKE '%MAALOX%';

UPDATE brand_name
SET new_name = 'ROBITUSSIN'
WHERE new_name LIKE '%ROBITUSSIN%';

UPDATE brand_name
SET new_name = 'RODAN & FIELDS'
WHERE new_name LIKE '%RODAN & FIELDS%';

UPDATE brand_name
SET new_name = 'SUDAFED'
WHERE new_name LIKE '%SUDAFED%';

UPDATE brand_name
SET new_name = 'CLEAN & CLEAR'
WHERE new_name LIKE '%CLEAN & CLEAR%'
	OR new_name LIKE '%CLEAN AND CLEAR%';

UPDATE brand_name
SET new_name = 'COUGH & CHEST'
WHERE new_name LIKE '%COUGH & CHEST%'
	OR new_name LIKE '%COUGH AND CHEST%';

UPDATE brand_name
SET new_name = 'KOFFEX DM'
WHERE new_name LIKE '%KOFFEX DM%';

UPDATE brand_name
SET new_name = 'OPTION +'
WHERE new_name LIKE '%OPTION +%';

UPDATE brand_name
SET new_name = 'OMNI-PAK'
WHERE new_name LIKE '%OMNI-PAK%';

UPDATE brand_name
SET new_name = 'SOLUPREP'
WHERE new_name LIKE '%SOLUPREP%';

UPDATE brand_name
SET new_name = 'VAGINEX'
WHERE new_name LIKE '%VAGINEX%';

UPDATE brand_name
SET new_name = 'DAMYLIN'
WHERE new_name LIKE '%DAMYLIN%';

UPDATE brand_name
SET new_name = 'INPERSOL'
WHERE new_name LIKE '%INPERSOL%';

UPDATE brand_name
SET new_name = 'T/GEL'
WHERE new_name LIKE '%T/GEL%';

UPDATE brand_name
SET new_name = 'PRO-LECARB'
WHERE new_name LIKE '%PRO-LECARB%';

UPDATE brand_name
SET new_name = 'PRISM0CAL'
WHERE new_name LIKE '%PRISM0CAL%';

UPDATE brand_name
SET new_name = 'ACCUSOL'
WHERE new_name LIKE '%ACCUSOL%';

UPDATE brand_name
SET new_name = 'ADENOCARD'
WHERE new_name LIKE '%ADENOCARD%';

UPDATE brand_name
SET new_name = 'ADVIL'
WHERE new_name LIKE '%ADVIL%';

UPDATE brand_name
SET new_name = 'FLOVENT'
WHERE new_name LIKE '%FLOVENT%';

UPDATE brand_name
SET new_name = 'MARCAINE'
WHERE new_name LIKE '%MARCAINE%';

UPDATE brand_name
SET new_name = 'PEPTO-BISMOL'
WHERE new_name LIKE '%PEPTO-BISMOL%';

UPDATE brand_name
SET new_name = 'BUGS BUNNY'
WHERE new_name LIKE '%BUGS BUNNY%';

UPDATE brand_name
SET new_name = 'MAXIPIME'
WHERE new_name LIKE '%MAXIPIME%';

UPDATE brand_name
SET new_name = 'OMNIPLEX'
WHERE new_name LIKE '%OMNIPLEX%';

UPDATE brand_name
SET new_name = 'AQUAFRESH'
WHERE new_name LIKE '%AQUAFRESH%';

UPDATE brand_name
SET new_name = 'LAPIDAR'
WHERE new_name LIKE '%LAPIDAR%';

UPDATE brand_name
SET new_name = 'E-PILO'
WHERE new_name LIKE '%E-PILO%';

UPDATE brand_name
SET new_name = 'ARISTOCORT'
WHERE new_name LIKE '%ARISTOCORT%';

UPDATE brand_name
SET new_name = 'GEL-KAM FLUOROCARE'
WHERE new_name LIKE '%GEL-KAM FLUOROCARE%';

UPDATE brand_name
SET new_name = 'NAPROXEN'
WHERE new_name LIKE '%NAPROXEN%';

UPDATE brand_name
SET new_name = 'MUCINEX'
WHERE new_name LIKE '%MUCINEX%';

UPDATE brand_name
SET new_name = 'SELSUN'
WHERE new_name LIKE '%SELSUN%';

UPDATE brand_name
SET new_name = 'IMOVAX'
WHERE new_name LIKE '%IMOVAX%';

UPDATE brand_name
SET new_name = 'PARIET'
WHERE new_name LIKE '%PARIET%';

UPDATE brand_name
SET new_name = 'POLYCIDIN'
WHERE new_name LIKE '%POLYCIDIN%';

UPDATE brand_name
SET new_name = 'BUCKLEY''S COMPLETE'
WHERE new_name LIKE '%BUCKLEY''S COMPLETE%';

UPDATE brand_name
SET new_name = 'VITRASERT'
WHERE new_name LIKE '%VITRASERT%';

UPDATE brand_name
SET new_name = 'REACH ACT FLUORIDE'
WHERE new_name LIKE '%REACH ACT FLUORIDE%';

UPDATE brand_name
SET new_name = 'PHARMALGEN'
WHERE new_name LIKE '%PHARMALGEN%';

UPDATE brand_name
SET new_name = 'VENOMIL'
WHERE new_name LIKE '%VENOMIL%';

UPDATE brand_name
SET new_name = 'BREVIBLOC'
WHERE new_name LIKE '%BREVIBLOC%';

UPDATE brand_name
SET new_name = 'DRISTAN'
WHERE new_name LIKE '%DRISTAN%';

UPDATE brand_name
SET new_name = 'CORICIDIN'
WHERE new_name LIKE '%CORICIDIN%';

UPDATE brand_name
SET new_name = 'CONTAC'
WHERE new_name LIKE '%CONTAC%';

UPDATE brand_name
SET new_name = 'CONTAC'
WHERE new_name LIKE '%COLGATE%';

UPDATE brand_name
SET new_name = 'HALLS'
WHERE new_name LIKE '%HALLS%';

UPDATE brand_name
SET new_name = 'EFFIDOSE'
WHERE new_name LIKE '%EFFIDOSE%';

UPDATE brand_name
SET new_name = 'ACNOPUR'
WHERE new_name LIKE '%ACNOPUR%';

UPDATE brand_name
SET new_name = 'M-ESLON'
WHERE new_name LIKE '%M-ESLON%';

UPDATE brand_name
SET new_name = 'WEBBER VITAMIN E'
WHERE new_name LIKE '%WEBBER VITAMIN E%';

UPDATE brand_name
SET new_name = 'DOM-CYCLOPENTOLATE'
WHERE new_name LIKE '%DOM-CYCLOPENTOLATE%';

--remove all the mg/ml
UPDATE brand_name
SET new_name = REGEXP_REPLACE(REGEXP_REPLACE(new_name, '\s(d+)?(/)?\d+(\.\d+)?(\s?)(\w+)?/(\d+)?(\.\d+)?(\w+)?(/)?(\d+)?(\w+)?', '','g'), '(\s|-)\d+((\.|,)\d+)?(\s)?(MG|MCG|GM|UI|IU|I\.U\.)(/)?(ML)?|\d+$', '','g');

--remove all the minerals and vitamins
UPDATE brand_name
SET new_name = REGEXP_REPLACE(new_name, '(DIETARY|MULTIVITAMIN|MULTIVIT & MINERAL|VITAMIN AND MINERAL|MULTI-VITAMIN|VITAMIN|VITAMIN MINERAL|MINERAL|MULTIVITAMIN AND MULTIMINERAL)?\s(SUPPLEMENT|SUPPLEMEN|SUPPLE|SUPPL|SUPP|SUPPLY)(\s|$)((\s)DE VITAMINES ET MINERAL)?', ' ','g');

UPDATE brand_name
SET new_name = REGEXP_REPLACE(new_name, '(NEBULES.*)|PAKS|((\d+)?:.*)|(AVEC.*)|(\d+(\.\d+)?%)|(\sIV)', '','g');

--cut all the forms
UPDATE brand_name
SET new_name = REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(new_name, '(\s|-)(CAPSULES|CAPSULE|CAPLETS|CAPLET|CAPS| CRM|CAP|ONT|SOLTN|SHP|INJECTABLE|SHAMPOO|INFUSION|CONCENTRATE|LOZENGES|PELLETS|PELLET|COMPRIMES|LOZ|SUPPOSITORY|INTRAVENOUS|DISPERSIBLE|LOZENGE|VAGINAL|INJ\.|CHEWABLE|CHEW|BUVABLES|SUPPOSITORIES|LIQUID|SOLUTION|CR?ME|CREAM|LOTION|TOOTHPASTE|LIQ|OPHTHALMIC|OPH|SUSPENSION|SUS|SRT|INHALER|ORAL|RINSE|ORL|SOLUTION|SOLTN|SOL|LETS|PWS|SYR|PWR|GRANULE|SUPPOSITOIRE|DROPS|SYRUP|VIAL|IMPLANT|STK|GRAN|TABLETS|TRANSDERMAL SYSTEM|TABLET|TAB|FOR|INJECTION|INJ$|(\d+-)?\s?\d+)$', ' ','g'), '\(.*\)', '','g'), '\s-\s.*', '','g'), '\s(II)|(I)$', '','g')
WHERE brand_name NOT LIKE '%TISSEEL%';

--cut the forms+route+flavours 
UPDATE brand_name
SET new_name = regexp_replace(new_name, 'APPLE|FOAM|POWDER|MEDICATED|HONEY|GINGER|CINNAMON|CITRUS|TYRANNA|BUBBLE GUM|WITCHY CANDY|GRAPE|KOALA BERRY|LEMON|SYSTEM |GRANULES|SCALP APPLICATION|ELIXIR|CARTRIDGE|FLAVOURED|FLAVORED|MULTIFLAVOUR|FLAVOUR|BUTTERSCOTCH|ORANGE|CHERRY|MINT|PACKET|MENTHOLATED|INHALATION SOLUTON|PHARMACY BULK|ENEMA|ELIXIR|SYRINGE|IRRIGATING|TOPICAL|NASAL SPRAY', '','g')
WHERE NOT new_name ~ '(^MINT-)';

--cut the forms+route
UPDATE brand_name
SET new_name = regexp_replace(new_name, 'INJECTABLE|ANTIFUNGAL|NON-PRESCRIPTION|NON PRESCRIPTION|ANTI-FUNGAL|LINIMENT|AROMATIQUE|OINTMENT|AQUAGEL|RESPIRATOR|CHEWS|REMINERALIZING|BLACK CURRANT|PEACH|AQUEOUS|PINK FRUIT|CRYSTAL|FRAGRANCE FREE|SUGAR FREE|ALCOHOL FREE| YEAST FREE| CFC FREE|ASSORTED|ENTERIC COATED', '','g');

--cut units
UPDATE brand_name
SET new_name = regexp_replace(new_name, '( MCG$)|(\d+UNIT)|( SUP$)|( TOP$)|( AMP$)|( MG$)|( CRM$)|( PREP$)|( VAG$)|( EYE$)|( EAR$)|( SOLN$)|( ORAL$)', '', 'g');

UPDATE brand_name
SET new_name = REGEXP_REPLACE(new_name, '-', ' ','g')
WHERE drug_code IN (
		SELECT a.drug_code
		FROM brand_name a
		JOIN brand_name b ON REGEXP_REPLACE(a.new_name, '-', ' ','g') = b.new_name
		);

UPDATE brand_name
SET new_name = REGEXP_REPLACE(new_name, '\s\s', ' ','g');

--cut %,coma etc
UPDATE brand_name
SET new_name = TRIM(REGEXP_REPLACE(REGEXP_REPLACE(REPLACE(new_name, '%', ''), '(-|,|\.| INH|#)$', '', 'g'), '  ', ' ', 'g'));

--deleting homeopathy drugs (form instance, apis milleflora 4D)
DELETE
FROM brand_name
WHERE new_name ~ '(\d+D)|(D\d+)|(\sC\d+\s)|(\s\d+X\s)|(\s\d+X-(\d+)?C\d+\s)|(\sC\d+-(\d+)?C\d+\s)|\(';

--deleting ingredients
DELETE
FROM brand_name
WHERE new_name ~ 'PRAEPARATUM|CONDITIONING|METALLICUM|COMPOUND|CHARCOAL|BEECH|^\d+|\.|USP|CITRASATE|COENZYME Q10|^FORMULA|^VITAMIN'
	AND NOT new_name ~ 'TISSEEL';

--deleting vitamins, satls (except ing+supplier name)
DELETE
FROM brand_name
WHERE new_name ~ 'CODEINE|CHLORIDE|SODIUM|DILUENT|VACCIN|/|SULFATE|B COMPLEX/BETA-CAROTENE|CAL-MAG|CAL MAG|CALAMINE|CALCIUM|CHELATED|ACIDE|POTASSIUM|MAGNESIUM|\sZINC|ZINC\s|CARBONATE|HYDROCHLOROTHIAZIDE|VANADIUM|DEXTROSE|PRIMROSE|GINGIBRAID|IRON|LIDOCAINE|FLORA |FLORASUN|LEAVES|LEVONORGESTREL|ALUMINA|HEEL (\d)+|HP(\d)+ DPS|R(\d)+ DPS|D(\d)+ - DPS|R (\d)+ DPS|R-(\d)+ DPS|D (\d)+ DPS|D-(\d)+ DPS|(\d)+MM PLS|AC?TAMINOPH?NE|ACETAMINOPHEN|LACTATE|CHLORIDE|MIXTURE|NIACINAMIDE|NATRIUM|PETROLEUM|SATIVUM|CEANOTHUS|BEECH'
	AND NOT new_name ~ 'ACH|ACT|GD-|NTP|FTP-|^BCI |AJ-|NOVO|NAT-|NU-|TARO-|ZINDA-|MUSCLE|MED-|ODAN-|PDP-|PENTA-|^Q-|RHO-|RHOXAL|SEPTA-|-ODAN|SYN-|^MED |MDK-|PRO-|ZYM-|ABBOTT|VITA-|VAN-|VAL-|ROCKY|RAN-|GEN-|BEECH|ALTI-|MYL-|MAR-|AA-|JAMP|ACCEL|AURO|INJEEL|APO|AVA|BIO|DOM|RIVA|TORRENT-|MINIMS|T/GEL|MINT|MYLAN|NTPORB|PAL|PAT|PHL|PMS|PORT|RATIO|SANDOZ|TEVA';

--deleting vitamins, satls (except ing+supplier name)
DELETE
FROM brand_name
WHERE new_name ~ 'ALLERGENIC|FLOS|AMMONIA|ALLERGENIC|MURICATUM|CERTIFIED|IBUPROFEN DAYTIME|ONE ALPHA|ONE-ALPHA|SCLERATUS|NATRUM|ISONIAZIDE|COMPLEX|HOMEO-|BRASILIENSIS|LIQUID|- COUGH|HOMEOPATHIC|GUAIFENSINE|IODUM|IODIUM|CHEWABLE|MULTIMINERALS|MULTIPLE|MULTIVITAMIN|ENZYME|ANTIBIOTIC|CHILDREN'
	AND NOT new_name ~ 'ACH|ACT|GD-|NTP|FTP-|^BCI |AJ-|NOVO|NAT-|NU-|FLINTSTONES|TARO-|ZINDA-|RELIEF|GAVISCON|MUSCLE|MED-|ODAN-|PDP-|PENTA-|^Q-|RHO-|RHOXAL|SEPTA-|-ODAN|SYN-|^MED |MDK-|PRO-|ZYM-|ABBOTT|VITA-|VAN-|VAL-|ROCKY|RAN-|GEN-|BEECH|ALTI-|MYL-|MAR-|AA-|JAMP|ACCEL|AURO|INJEEL|APO|AVA|BIO|DOM|RIVA|MINIMS|T/GEL|MINT|MYLAN|NTPORB|PAL|PAT|PHL|PMS|PORT|RATIO|SANDOZ|TEVA';

--deleting acids, satls,enzymes (except ing+supplier name)
DELETE
FROM brand_name
WHERE new_name ~ 'COD LIVER|CC II|VC II|(^DECONGESTANT )|(^COOLING )|RELEASED|BACITRACIN|INJECTION|CISPLATIN|ACIDUM|CAROTENE|ECHINACEA| ACID| VACC|INACTIVATED|ACONIT|NITRATE|CALMINE|CANDIDA|CARBOPLATIN|^FORMULE|EPSOM|CITRATE|CANADENSIS|ABELMOSCHUS|BIFIDUM|ACIDOPHILUS|ACIDE|AMBROSIA|HYDROXYAPATITE|ALPHACOPHEROL|ENZYME|ALLIUM|AMOXICILLIN|THERAPEUTIC|#|SWAB|COMBINATION'
	AND NOT new_name ~ 'ACH|ACT|GD-|NTP|FTP-|^BCI |AJ-|NOVO|NAT-|NU-|FLINTSTONES|TARO-|ZINDA-|RELIEF|GAVISCON|MUSCLE|MED-|ODAN-|PDP-|PENTA-|^Q-|RHO-|RHOXAL|SEPTA-|-ODAN|SYN-|^MED |MDK-|PRO-|ZYM-|ABBOTT|VITA-|VAN-|VAL-|ROCKY|RAN-|GEN-|BEECH|ALTI-|MYL-|MAR-|AA-|JAMP|ACCEL|AURO|INJEEL|APO|AVA|BIO|DOM|RIVA|MINIMS|T/GEL|MINT|MYLAN|NTPORB|PAL|PAT|PHL|PMS|PORT|RATIO|SANDOZ|TEVA';

DELETE
FROM brand_name
WHERE new_name ~ ' AND | W |\+|&'
	AND NOT new_name ~ 'HEAD & SHOULDERS|MUSCLE|COLD|FLU|RODAN & FIELDS|SINUS|PAIN|TRIAMINIC|FRESH & GO|DANDRUFF|FLINTSTONES|EX-LAX|TUSS|DEFEND|DAY|NIGHT';

DELETE
FROM brand_name
WHERE (
		length(new_name) < 5
		OR new_name ~ ' COMP$'
		OR new_name IN (
			'ALLERGY',
			'DANDRUFF')
		)
	AND NOT new_name ~ 'SERC|OVOL|QVAR|MUSE';

--deleting bn that resemble ingredients
DELETE
FROM brand_name
WHERE drug_code IN (
		SELECT drug_code
		FROM brand_name bn
		JOIN ingr_2 i USING (drug_code)
		WHERE new_name LIKE '%' || CONCEPT_NAME || '%'
			AND NOT new_name ~ 'ACH|ACT|GD-|NTP|FTP-|^BCI |AJ-|NOVO|NAT-|NU-|TARO-|ZINDA-|COMBI|PACK|MUSCLE|MED-|ODAN-|PDP-|PENTA-|^Q-|RHO-|RHOXAL|SEPTA-|-ODAN|SYN-|^MED |MDK-|PRO-|ZYM-|ABBOTT|VITA-|VAN-|VAL-|ROCKY|RAN-|GEN-|BEECH|ALTI-|MYL-|MAR-|AA-|JAMP|ACCEL|AURO|INJEEL|APO|AVA|BIO|DOM|RIVA|MINIMS|T/GEL|MINT|MYLAN|NTPORB|PAL|PAT|PHL|PMS|PORT|RATIO|SANDOZ|TEVA'
		);

--deleting bn that resemble ingredients in concept
DELETE
FROM brand_name
WHERE LOWER(new_name) IN (
		SELECT LOWER(concept_name)
		FROM concept
		WHERE concept_class_id IN (
				'Ingredient',
				'AU Substance',
				'ATC 5th',
				'Chemical Structure',
				'Substance',
				'Pharma/Biol Product',
				'Pharma Preparation',
				'Clinical Drug Form',
				'Dose Form',
				'Precise Ingredient'
				)
		);

--Table with omop-generated codes
DROP TABLE IF EXISTS list_temp;
CREATE TABLE list_temp AS
SELECT DISTINCT a.*,
	NEXTVAL('conc_stage_seq') AS concept_code
FROM (
	SELECT lower(concept_name) AS concept_name,'Ingredient' AS concept_class_id,'S' AS standard_concept
	FROM ingr_2
	WHERE concept_name IS NOT NULL
	
	UNION
	
	SELECT new_name,'Brand Name',NULL
	FROM brand_name
	WHERE new_name IS NOT NULL
	
	UNION
	
	SELECT brand_name,	'Brand Name',NULL
	FROM new_pack
	WHERE brand_name IS NOT NULL
	
	UNION
	
	SELECT concept_name,concept_class_id,NULL
	FROM forms_2
	WHERE concept_name IS NOT NULL
	
	UNION
	
	SELECT concept_name_2,'Dose Form',NULL
	FROM pack_form
	
	UNION
		
	SELECT lower(ingredient),	'Ingredient' , 'S'
	FROM new_pack
	
	UNION
		
	SELECT concept_name,	'Drug Product',NULL
	FROM new_pack
	
	UNION
	
	SELECT new_name,	concept_class_id,NULL
	FROM manufacturer
	WHERE concept_name IS NOT NULL
	) AS a;

--Concept-stage creation
INSERT INTO drug_concept_stage (
	CONCEPT_NAME,
	VOCABULARY_ID,
	CONCEPT_CLASS_ID,
	STANDARD_CONCEPT,
	CONCEPT_CODE,
	POSSIBLE_EXCIPIENT,
	DOMAIN_ID,
	VALID_START_DATE,
	VALID_END_DATE,
	INVALID_REASON
	)
SELECT DISTINCT CONCEPT_NAME,'DPD',
	CONCEPT_CLASS_ID,
	STANDARD_CONCEPT,
	CONCEPT_CODE,
	NULL,
	'Drug',
	CURRENT_DATE - 1,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL
FROM (
	SELECT INITCAP(CONCEPT_NAME) AS CONCEPT_NAME,CONCEPT_CLASS_ID,STANDARD_CONCEPT,'DPD' || CONCEPT_CODE AS concept_code
	FROM list_temp --ADD 'OMOP' to all OMOP-generated concepts	
UNION	
	SELECT CONCEPT_NAME,CONCEPT_CLASS_ID,NULL,CONCEPT_CODE
	FROM unit
UNION	
	SELECT INITCAP(BRAND_NAME || ' [Drug]'),'Drug Product',NULL,DRUG_CODE
	FROM drug_product	
UNION  
  SELECT brand_name, 'Drug Product',NULL,cast (old_code as varchar (25))
  FROM non_drug where upper(brand_name) like '%XOFIGO%'	
	) AS s0;

INSERT INTO drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
VALUES ('{1 (CLOTRIMAZOLE 1% VAGINAL CREAM [CANESTEN 6 INSERT COMBI-PAK]) / 6 (CLOTRIMAZOLE 100 MG VAGINAL SUPPOSITORY [CANESTEN 6 INSERT COMBI-PAK]) } Pack [CANESTEN 6 INSERT COMBI-PAK]','DPD','Drug Product',NULL,'2150913',NULL,'Drug',	
CURRENT_DATE - 1,TO_DATE('20991231', 'yyyymmdd'),NULL);
INSERT INTO drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
VALUES ('{(ETHINYL ESTRADIOL .035 MG / NORETHINDRONE .5 MG ORAL TABLET [PHASIC(21-D)]) / (ETHINYL ESTRADIOL .035 MG / NORETHINDRONE 1 MG ORAL TABLET [PHASIC(21-D)]) } Pack [NORETHINDRONE/ETHINYL ESTRADIOL PHASIC(21-D)]','DPD','Drug Product',
NULL,'2217384',NULL,'Drug',	CURRENT_DATE - 1,TO_DATE('20991231', 'yyyymmdd'),NULL);
INSERT INTO drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
VALUES ('Pegasys Rbv [Drug]','DPD','Drug Product',NULL,'2253410',NULL,'Drug',	
CURRENT_DATE - 1,TO_DATE('20991231', 'yyyymmdd'),NULL);
INSERT INTO drug_concept_stage (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
VALUES ('Pegasys Rbv [Drug]','DPD','Drug Product',NULL,'2253429',NULL,'Drug',	
CURRENT_DATE - 1,TO_DATE('20991231', 'yyyymmdd'),NULL);

UPDATE DRUG_CONCEPT_STAGE
SET CONCEPT_NAME = 'Boehringer Ingelheim'
WHERE CONCEPT_NAME = 'Boehringer Ingelheim  Ltee';

--Flag indicating inert ingredients
UPDATE drug_concept_stage
SET POSSIBLE_EXCIPIENT = 1
WHERE UPPER(concept_name) = 'NEON';

UPDATE drug_concept_stage dc
SET concept_code=a.concept_code
FROM (
select max(c.concept_code) over (partition by c.concept_name) as concept_code,dc.concept_class_id,dc.concept_name 
from drug_concept_stage dc
join concept c on dc.concept_name=c.concept_name and dc.concept_code like 'DPD%' and c.vocabulary_id = 'DPD' and dc.concept_class_id=c.concept_class_id
) a
WHERE (a.concept_name = dc.concept_name and a.concept_class_id = dc.concept_class_id);

UPDATE drug_concept_stage dc
SET concept_code=a.concept_code
FROM (
select max(c.concept_code) over (partition by upper(c.concept_name)) as concept_code,d.concept_name 
from brand_name b 
join drug_concept_stage d on upper(d.concept_name)=upper(b.new_name)
join concept c on upper(b.brand_name)=upper(c.concept_name) and c.vocabulary_id = 'DPD' and c.concept_class_id='Brand Name'
where d.concept_code not in (select concept_code from concept where vocabulary_id='DPD') 
) a
WHERE (a.concept_name = dc.concept_name and dc.concept_class_id = 'Brand Name');

UPDATE drug_concept_stage dc
SET concept_code=a.concept_code
FROM (
select max(c.concept_code) over (partition by upper(c.concept_name)) as concept_code,d.concept_name 
from manufacturer b 
join drug_concept_stage d on upper(d.concept_name)=upper(b.new_name)
join concept c on upper(b.concept_name)=upper(c.concept_name) and c.vocabulary_id = 'DPD' and c.concept_class_id='Supplier'
where d.concept_code not in (select concept_code from concept where vocabulary_id='DPD') 
) a
WHERE (a.concept_name = dc.concept_name and dc.concept_class_id = 'Supplier');


/*
--script to check codes
with suppl_mapp as (select c.concept_code,cr3.concept_id_1 as rxid,c2.concept_code as suppl_code,c2.concept_name as suppl_name
from concept c 
join concept_relationship cr on cr.concept_id_1 = c.concept_id and c.vocabulary_id='DPD' and cr.relationship_id='Maps to'
join concept_relationship cr2 on cr2.concept_id_1=cr.concept_id_2 and cr2.relationship_id='Has supplier'
join concept_relationship cr3 on cr3.concept_id_1=cr2.concept_id_2 and cr3.relationship_id='RxNorm - Source eq'
join concept c2 on c2.concept_id = cr3.concept_id_2 and c2.vocabulary_id='DPD'
)
select * from suppl_mapp s
join internal_relationship_stage i on s.concept_code=i.concept_code_1
join drug_concept_stage d on d.concept_code=i.concept_code_2 and d.concept_class_id='Supplier'
where s.suppl_name!=d.concept_name
and d.concept_code not in (select concept_code from concept where vocabulary_id='DPD')
;
drop table bn_mapp;
create table bn_mapp as 
(select c.concept_code,cr3.concept_id_1 as rxid,c2.concept_code as bn_code,c2.concept_name as bn_name
from concept c 
join concept_relationship cr on cr.concept_id_1 = c.concept_id and c.vocabulary_id='DPD' and cr.relationship_id='Maps to'
join concept_relationship cr2 on cr2.concept_id_1=cr.concept_id_2 and cr2.relationship_id='Has brand name'
join concept_relationship cr3 on cr3.concept_id_1=cr2.concept_id_2 and cr3.relationship_id='RxNorm - Source eq'
join concept c2 on c2.concept_id = cr3.concept_id_2 and c2.vocabulary_id='DPD'
);

select * from bn_mapp s
join internal_relationship_stage i on s.concept_code=i.concept_code_1
join drug_concept_stage d on d.concept_code=i.concept_code_2 and d.concept_class_id='Brand Name'
where s.bn_name!=d.concept_name
and d.concept_code not in (select concept_code from concept where vocabulary_id='DPD')
;


select distinct relationship_id from relationship;

*/
--Updating valid dates using info in original tables
DROP TABLE IF EXISTS dates;
CREATE TABLE dates AS
SELECT DISTINCT d.DRUG_CODE,
	valid_date
FROM drug_product d
JOIN (
	SELECT min(HISTORY_DATE) AS valid_date,
		drug_code
	FROM STATUS
	GROUP BY drug_code
	) a ON a.drug_code = d.old_code::VARCHAR;

UPDATE drug_concept_stage a
SET VALID_START_DATE = (
		SELECT valid_date
		FROM dates b
		WHERE a.concept_code = b.drug_code
		);

UPDATE drug_concept_stage
SET VALID_START_DATE = TO_DATE('19700101', 'yyyymmdd')
WHERE valid_start_date IS NULL
	OR valid_start_date > CURRENT_DATE;


INSERT INTO internal_relationship_stage (concept_code_1,concept_code_2)
--drug to manufacturer
SELECT drug_code,concept_code
FROM manufacturer m
JOIN drug_concept_stage d ON INITCAP(m.new_name) = INITCAP(d.concept_name)
	AND d.concept_class_id = 'Supplier'

--add pack components
UNION

SELECT dcs2.concept_code,dcs.concept_code
FROM manufacturer m
JOIN drug_concept_stage dcs ON INITCAP(new_name) = INITCAP(dcs.concept_name)
	AND dcs.concept_class_id = 'Supplier'
JOIN new_pack np ON np.concept_code = m.drug_code
JOIN drug_concept_stage dcs2 ON INITCAP(np.concept_name) = INITCAP(dcs2.concept_name)
	AND dcs2.concept_class_id = 'Drug Product'

UNION

--drug to ingredient
SELECT drug_code,concept_code
FROM ingr_2 i
JOIN drug_concept_stage dcs ON INITCAP(dcs.concept_name) = INITCAP(i.concept_name)
	AND concept_class_id = 'Ingredient'
WHERE drug_code NOT IN (
		SELECT concept_code
		FROM new_pack)

--add pack components
UNION

SELECT dcs.concept_code,dcs2.concept_code
FROM new_pack np
JOIN drug_concept_stage dcs ON INITCAP(np.concept_name) = INITCAP(dcs.concept_name)
	AND dcs.concept_class_id = 'Drug Product'
JOIN drug_concept_stage dcs2 ON INITCAP(np.INGREDIENT) = INITCAP(dcs2.concept_name)
	AND dcs2.concept_class_id = 'Ingredient'

UNION

--drug to form
SELECT drug_code,concept_code
FROM forms f
JOIN drug_concept_stage dcs ON INITCAP(f.concept_name) = INITCAP(dcs.concept_name)
	AND dcs.concept_class_id = 'Dose Form'
WHERE drug_code NOT IN (
		SELECT concept_code
		FROM new_pack)

UNION

--add pack components
SELECT dcs.concept_code,dcs2.concept_code
FROM new_pack p
JOIN drug_concept_stage dcs ON INITCAP(dcs.concept_name) = INITCAP(p.concept_name)
	AND dcs.concept_class_id = 'Drug Product'
JOIN drug_concept_stage dcs2 ON INITCAP(dcs2.concept_name) = INITCAP(p.concept_name)
	AND dcs2.concept_class_id = 'Dose Form'

UNION

SELECT drug_code,concept_code
FROM brand_name
JOIN drug_concept_stage dcs ON INITCAP(new_name) = INITCAP(dcs.concept_name)
	AND concept_class_id = 'Brand Name'

UNION

--pack components BN
SELECT dcs2.concept_code,dcs.concept_code
FROM drug_concept_stage dcs
JOIN new_pack np ON INITCAP(brand_name) = INITCAP(dcs.concept_name)
	AND dcs.concept_class_id = 'Brand Name'
JOIN drug_concept_stage dcs2 ON INITCAP(np.concept_name) = INITCAP(dcs2.concept_name)
	AND dcs2.concept_class_id = 'Drug Product';

--Inserting ingredients that are absent in original data
INSERT INTO internal_relationship_stage (concept_code_1,concept_code_2)
WITH a AS (
		SELECT MAX(LENGTH(concept_name)) OVER (PARTITION BY drug_code) AS l1,dp.drug_code,dcs.concept_code
		FROM drug_product dp
		JOIN drug_concept_stage dcs ON upper(brand_name) LIKE '%' || upper(concept_name) || '%'
			AND dcs.concept_class_id = 'Ingredient'
			AND NOT brand_name ~ ' AND |/|WITH|HCTZ|\+| &'
		WHERE dp.drug_code NOT IN (
				SELECT concept_code_1
				FROM internal_relationship_stage
				JOIN drug_concept_stage ON concept_code_2 = concept_code
					AND concept_class_id = 'Ingredient'
				)
		ORDER BY drug_code
		),
	b AS (
		SELECT drug_code,concept_name,brand_name,LENGTH(concept_name) AS l2
		FROM drug_product dp
		JOIN drug_concept_stage dcs ON upper(brand_name) LIKE '%' || upper(concept_name) || '%'
			AND dcs.concept_class_id = 'Ingredient'
			AND NOT brand_name ~ ' AND |/|WITH|HCTZ|\+| &'
		WHERE dp.drug_code NOT IN (
				SELECT concept_code_1
				FROM internal_relationship_stage
				JOIN drug_concept_stage ON concept_code_2 = concept_code
					AND concept_class_id = 'Ingredient'
				)
		)
SELECT DISTINCT a.drug_code,concept_code
FROM a
JOIN b ON a.drug_code = b.drug_code
	AND l1 = l2
	AND concept_name NOT IN ('Air','Gold','Fir','Cina','Tin','Aloe','Cocoa')

UNION

SELECT dp.drug_code,dcs.concept_code
FROM drug_product dp
JOIN drug_concept_stage dcs ON upper(brand_name) LIKE '%' || upper(concept_name) || '%'
	AND dcs.concept_class_id = 'Ingredient'
	AND brand_name ~ 'HCTZ'
WHERE dp.drug_code NOT IN (
		SELECT concept_code_1
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Ingredient')

UNION

SELECT dp.drug_code,dcs2.concept_code
FROM drug_product dp
JOIN drug_concept_stage dcs ON upper(brand_name) LIKE '%' || upper(concept_name) || '%'
	AND dcs.concept_class_id = 'Ingredient'
	AND brand_name ~ 'HCTZ|AND HYDROCHLOROTHIAZIDE'
LEFT JOIN drug_concept_stage dcs2 ON upper(dcs2.concept_name) = 'HYDROCHLOROTHIAZIDE'
WHERE dp.drug_code NOT IN (
		SELECT concept_code_1
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Ingredient')

UNION

SELECT dp.drug_code,dcs.concept_code
FROM drug_product dp
JOIN drug_concept_stage dcs ON upper(brand_name) LIKE '%' || upper(concept_name) || '%'
	AND dcs.concept_class_id = 'Ingredient'
	AND brand_name ~ '&|WITH'
	AND NOT brand_name ~ 'COLD STIX|ERASER|HCTZ|HYDROCHLOROTHIAZIDE|DILUENT'
--  LEFT JOIN drug_concept_stage dcs2 ON upper(dcs2.concept_name)='HYDROCHLOROTHIAZIDE'
WHERE dp.drug_code NOT IN (
		SELECT concept_code_1
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Ingredient'
		)
	AND concept_name NOT IN ('Air','Zinc','Muscle','Citrus');

--Creating ds_stage with unit conversion
DROP TABLE IF EXISTS ds_stage_0;
CREATE TABLE ds_stage_0 AS
SELECT DISTINCT drug_code AS drug_concept_code,
	concept_code AS ingredient_concept_code,
	CASE 
		WHEN (dosage_unit IS NULL OR dosage_unit in ('CM'))
			AND strength_unit not in ('%','ML') -- not to let ML live in amounts
			THEN strength
		ELSE NULL
		END::FLOAT AS amount_value,
	CASE 
		WHEN (dosage_unit IS NULL OR dosage_unit in ('CM'))
			AND strength_unit not in ('%','ML')
			THEN strength_unit
		ELSE NULL
		END AS amount_unit,
	CASE 
		WHEN (strength_unit in ('TM','CM','ML') OR dosage_unit in ('CM'))
			THEN NULL
		WHEN dosage_unit = 'CCID50'
			THEN (strength::FLOAT) * 0.7
		WHEN (dosage_unit IS NOT NULL AND dosage_unit != 'CCID50')
			OR strength_unit = '%' 
			THEN strength::FLOAT
		ELSE NULL
		END::FLOAT AS numerator_value,
	CASE
		WHEN (strength_unit in ('TM','CM','ML') OR dosage_unit in ('CM'))
			THEN NULL	 
		WHEN dosage_unit = 'CCID50'
			THEN 'PFU'
		WHEN (dosage_unit IS NOT NULL AND dosage_unit != 'CCID50')
			OR strength_unit = '%'
			THEN strength_unit
		ELSE NULL
		END AS numerator_unit,
	CASE 
		WHEN dosage_unit in ('TM','CM')	OR strength_unit in ('TM','CM','ML')
			THEN NULL
		WHEN dosage_unit IS NOT NULL
			THEN dosage_value			
		ELSE NULL
		END::FLOAT AS denominator_value,
	CASE 
		WHEN dosage_unit in ('TM','CM') OR strength_unit in ('TM','CM','ML')
			THEN NULL
		WHEN dosage_unit IS NOT NULL
			THEN dosage_unit			
		ELSE NULL
		END AS denominator_unit
FROM ingr_2 d
JOIN drug_concept_stage e ON INITCAP(d.concept_name) = INITCAP(e.concept_name)
	AND e.concept_class_id = 'Ingredient'
WHERE drug_code NOT IN (
		SELECT drug_code
		FROM new_pack
		)
	AND drug_code NOT IN ('658332','702633');

--build up ds_stage with up-to-date codes
INSERT INTO ds_stage_0 (
	DRUG_CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	AMOUNT_VALUE,
	AMOUNT_UNIT,
	NUMERATOR_VALUE,
	NUMERATOR_UNIT,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT
	)
SELECT dcs.concept_code,
	dcs2.concept_code,
	amount_value::FLOAT,
	amount_unit,
numerator_value::FLOAT,
	numerator_unit,
denominator_value::FLOAT,
	denominator_unit
FROM new_pack np
JOIN drug_concept_stage dcs ON INITCAP(np.concept_name) = INITCAP(dcs.concept_name)
	AND dcs.concept_class_id = 'Drug Product'
JOIN drug_concept_stage dcs2 ON INITCAP(np.ingredient) = INITCAP(dcs2.concept_name)
	AND dcs2.concept_class_id = 'Ingredient';

--deleting drugs with impossible dosages
DELETE
FROM ds_stage_0
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage_0
		WHERE (
				(
					LOWER(numerator_unit) = 'mg'
					AND LOWER(denominator_unit) IN ('ml','g')
					)
				AND numerator_value / denominator_value > 1000
				)
			OR (
				LOWER(numerator_unit) = 'g'
				AND LOWER(denominator_unit) = 'ml'
				AND numerator_value / denominator_value > 1
				)
			OR (
				numerator_value IS NULL
				AND amount_value IS NULL
				AND denominator_value IS NULL
				)
		);

DROP TABLE IF EXISTS DS_STAGE_1;
CREATE TABLE DS_STAGE_1 (LIKE DS_STAGE);

--Updating drugs from ds_stage that have %
INSERT INTO ds_stage_1 (
	DRUG_CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	AMOUNT_VALUE,
	AMOUNT_UNIT,
	NUMERATOR_VALUE,
	NUMERATOR_UNIT,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT
	) (
	SELECT DISTINCT DRUG_CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	CASE 
		WHEN (
				NUMERATOR_UNIT = '%'
				OR DENOMINATOR_UNIT IS NOT NULL
				)
			AND CONCEPT_NAME ~ 'CAPSULE|TABLET'
			THEN NUMERATOR_VALUE
		ELSE AMOUNT_VALUE
		END,
	CASE 
		WHEN (
				NUMERATOR_UNIT = '%'
				OR DENOMINATOR_UNIT IS NOT NULL
				)
			AND CONCEPT_NAME ~ 'CAPSULE|TABLET'
			THEN 'MG'
		WHEN AMOUNT_UNIT = 'Kg'
			THEN 'KG'
		WHEN AMOUNT_UNIT = 'mEq'
			THEN 'MEQ'
		ELSE AMOUNT_UNIT
		END,
	CASE 
		WHEN (
				NUMERATOR_UNIT = '%'
				OR DENOMINATOR_UNIT IS NOT NULL
				)
			AND CONCEPT_NAME ~ 'CAPSULE|TABLET'
			THEN NULL
		WHEN NUMERATOR_UNIT = '%'
			AND DENOMINATOR_VALUE IS NULL
			THEN NUMERATOR_VALUE / 100 -- remove 2n cond AND DENOMINATOR_UNIT in ('ML','G') + as we use 'MG' as denominator than we need to multiple by 10 and / by 1000
		WHEN NUMERATOR_UNIT = '%'
			AND DENOMINATOR_VALUE IS NOT NULL
			THEN NUMERATOR_VALUE * 10 * DENOMINATOR_VALUE
		ELSE NUMERATOR_VALUE
		END,
	CASE 
		WHEN (
				NUMERATOR_UNIT = '%'
				OR DENOMINATOR_UNIT IS NOT NULL
				)
			AND CONCEPT_NAME ~ 'CAPSULE|TABLET'
			THEN NULL
		WHEN NUMERATOR_UNIT = '%'
			AND NOT CONCEPT_NAME ~ 'CAPSULE|TABLET'
			THEN 'MG'
		WHEN NUMERATOR_UNIT = 'Kg'
			THEN 'KG'
		WHEN NUMERATOR_UNIT = 'mEq'
			THEN 'MEQ'
		ELSE NUMERATOR_UNIT
		END,
	CASE 
		WHEN (
				NUMERATOR_UNIT = '%'
				OR DENOMINATOR_UNIT IS NOT NULL
				)
			AND CONCEPT_NAME ~ 'CAPSULE|TABLET'
			THEN NULL
		ELSE DENOMINATOR_VALUE
		END,
	CASE 
		WHEN (
				NUMERATOR_UNIT = '%'
				OR DENOMINATOR_UNIT IS NOT NULL
				)
			AND CONCEPT_NAME ~ 'CAPSULE|TABLET'
			THEN NULL
		WHEN NUMERATOR_UNIT = '%'
			AND (
				DENOMINATOR_UNIT IS NULL
				OR DENOMINATOR_UNIT = '%'
				)
			AND CONCEPT_NAME ~ 'STICK|POWDER|CAPSULE|TABLET|JELLY'
			THEN 'MG'
		WHEN NUMERATOR_UNIT = '%'
			AND (
				DENOMINATOR_UNIT IS NULL
				OR DENOMINATOR_UNIT = '%'
				)
			AND NOT CONCEPT_NAME ~ 'STICK|POWDER|CAPSULE|TABLET|JELLY'
			THEN 'ML'
		WHEN DENOMINATOR_UNIT = 'Kg'
			THEN 'KG'
		WHEN DENOMINATOR_UNIT = 'mEq'
			THEN 'MEQ'
		ELSE DENOMINATOR_UNIT
		END FROM ds_stage_0 ds JOIN forms ON drug_concept_code = drug_code
	);

--Introduce box size
--Use package_size to get box_size
UPDATE ds_stage_1 ds
SET box_size = bs.package_size::INT
FROM (
	SELECT DISTINCT package_size, drug_code
	FROM packaging
	WHERE drug_code IN (
			SELECT drug_code
			FROM (
				SELECT DISTINCT drug_code, package_size
				FROM packaging
				WHERE package_size IS NOT NULL
					AND package_size_unit IN (	'LOZENGE','CAPLET','CAPSULE','SUPPOSITORY','TABLET','PATCH','PAD')
				) AS s0
			GROUP BY drug_code
			HAVING COUNT(1) = 1
			)
		AND drug_code NOT IN (
			SELECT drug_code
			FROM packaging
			GROUP BY drug_code
			HAVING COUNT(1) > 1
			)
	) bs
WHERE bs.drug_code = ds.drug_concept_code;

--use PRODUCT_INFORMATION to get box_size
UPDATE ds_stage_1 ds
SET box_size = bs.pc::INT
FROM (
	SELECT DISTINCT SUBSTRING(PRODUCT_INFORMATION, '(\d)+(TAB|CAP|X)') AS pc,
		drug_code
	FROM packaging
	WHERE PRODUCT_INFORMATION ~ 'TAB|CAP|X|BLISTER'
		AND package_size IS NULL
		AND SUBSTRING(PRODUCT_INFORMATION, '(\d)+(TAB|CAP|X)') IS NOT NULL
		AND NOT PRODUCT_INFORMATION ~ '/|AMOXICILLIN|\+|DAY|\(|\,|&|-|(X.*X)'
		AND drug_code NOT IN (
			SELECT drug_code
			FROM packaging
			GROUP BY drug_code
			HAVING COUNT(1) > 1
			)
	) bs
WHERE bs.drug_code = ds.drug_concept_code;

UPDATE ds_stage_1
SET numerator_unit = '%',
	numerator_value = amount_value / 10000,
	amount_value = NULL,
	amount_unit = NULL
WHERE AMOUNT_UNIT = 'PPM';

DELETE
FROM ds_stage_1
WHERE amount_unit IS NULL
	AND numerator_unit IS NULL
	AND denominator_unit IS NULL;
	
DELETE
FROM ds_stage_1
WHERE drug_concept_code='2399229'; -- delete vaccine with Log10 TCID50 and Log10 PFU

UPDATE ds_stage_1
SET amount_value = numerator_value,
	amount_unit = numerator_unit,
	numerator_unit = NULL,
	numerator_value = NULL,
	denominator_unit = NULL,
	denominator_value = NULL
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage_1
		WHERE denominator_unit = numerator_unit
			AND numerator_value / coalesce(denominator_value, 1) > 1
		)
	OR drug_concept_code IN (
		SELECT a.drug_concept_code
		FROM ds_stage_1 a
		JOIN ds_stage_1 b ON a.drug_concept_code = b.drug_concept_code
			AND a.amount_unit IS NOT NULL
			AND b.numerator_unit IS NOT NULL
		);

DELETE
FROM ds_stage_1
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE amount_unit = 'ML'
			OR numerator_unit = 'ML'
		)
	OR drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage_1
		WHERE amount_unit IS NULL
			AND numerator_unit IS NULL
		);
		
-- liquid homeopathy should be in numerator
UPDATE ds_stage_1
   SET numerator_unit = amount_unit,
       numerator_value = amount_value,
       amount_unit = NULL,
       amount_value = NULL
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage_1
                              JOIN forms ON drug_code = drug_concept_code
                            WHERE numerator_unit IN ('DH','C','CH','D','TM','X','XMK')
                            AND   concept_name !~ 'TAB|CAP|LOZ|SUPP|FILM|POWDER|JELLY');

--Updating drugs that have ingredients with 2 or more dosages that need to be sum up
INSERT INTO ds_stage (
	DRUG_CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	AMOUNT_VALUE,
	AMOUNT_UNIT,
	NUMERATOR_VALUE,
	NUMERATOR_UNIT,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT
	)
SELECT DISTINCT drug_concept_code,
	ingredient_concept_code,
	SUM(AMOUNT_VALUE) OVER (
		PARTITION BY DRUG_CONCEPT_CODE,
		ingredient_concept_code,
		AMOUNT_UNIT),
	amount_unit,
	SUM(NUMERATOR_VALUE) OVER (
		PARTITION BY DRUG_CONCEPT_CODE,
		ingredient_concept_code,
		NUMERATOR_UNIT),
	numerator_unit,
	denominator_value,
	denominator_unit
FROM (
	SELECT drug_concept_code,	ingredient_concept_code,box_size,
		CASE 
			WHEN amount_unit = 'G'	THEN amount_value * 1000
			WHEN amount_unit = 'MCG'THEN amount_value / 1000
			ELSE amount_value
			END AS amount_value, -- make amount units similar
		CASE 
			WHEN amount_unit IN (	'G',	'MCG') THEN 'MG'
			ELSE amount_unit
			END AS amount_unit,
		CASE 
			WHEN numerator_unit = 'G' THEN numerator_value * 1000
			WHEN numerator_unit = 'MCG'	THEN numerator_value / 1000
			ELSE numerator_value
			END AS numerator_value,
		CASE 
			WHEN numerator_unit IN ('G','MCG') THEN 'MG'
			ELSE numerator_unit
			END AS numerator_unit,
		denominator_value,
		denominator_unit
	FROM ds_stage_1 a
	WHERE (
			drug_concept_code,
			ingredient_concept_code
			) IN (
			SELECT drug_concept_code,
				ingredient_concept_code
			FROM ds_stage_1
			GROUP BY drug_concept_code,
				ingredient_concept_code
			HAVING COUNT(1) > 1
			)
	
	UNION
	
	SELECT *
	FROM ds_stage_1
	WHERE (
			drug_concept_code,
			ingredient_concept_code
			) NOT IN (
			SELECT drug_concept_code,
				ingredient_concept_code
			FROM ds_stage_1
			GROUP BY drug_concept_code,
				ingredient_concept_code
			HAVING COUNT(1) > 1
			)
	) a;

--Inserting ingredients that are absent in original data
INSERT INTO ds_stage (drug_concept_code,ingredient_concept_code)
WITH a AS (
		SELECT MAX(LENGTH(concept_name)) OVER (PARTITION BY drug_code) AS l1,dp.drug_code,dcs.concept_code
		FROM drug_product dp
		JOIN drug_concept_stage dcs ON brand_name LIKE '%' || concept_name || '%'
			AND dcs.concept_class_id = 'Ingredient'
			AND NOT brand_name ~ ' AND |/|WITH|HCTZ|\+| &'
		WHERE dp.drug_code NOT IN (
				SELECT drug_code
				FROM active_ingredients
				) ORDER BY drug_code
		),
	b AS (
		SELECT drug_code,concept_name,	brand_name,LENGTH(concept_name) AS l2
		FROM drug_product dp
		JOIN drug_concept_stage dcs ON brand_name LIKE '%' || concept_name || '%'
			AND dcs.concept_class_id = 'Ingredient'
			AND NOT brand_name ~ ' AND |/|WITH|HCTZ|\+| &'
		WHERE dp.drug_code NOT IN (
				SELECT drug_code
				FROM active_ingredients
				)
		)
SELECT DISTINCT a.drug_code, concept_code
FROM a
JOIN b ON a.drug_code = b.drug_code
	AND l1 = l2
	AND concept_name NOT IN (
		'Air','Gold','Fir','Cina','Tin','Aloe','Cocoa'
		)
UNION
SELECT dp.drug_code,
	dcs.concept_code
FROM drug_product dp
JOIN drug_concept_stage dcs ON brand_name LIKE '%' || concept_name || '%'
	AND dcs.concept_class_id = 'Ingredient'
	AND brand_name LIKE '%HCTZ%'
WHERE dp.drug_code NOT IN (
		SELECT drug_code
		FROM active_ingredients
		)
UNION
SELECT dp.drug_code, dcs2.concept_code
FROM drug_product dp
JOIN drug_concept_stage dcs ON brand_name LIKE '%' || concept_name || '%'
	AND dcs.concept_class_id = 'Ingredient'
	AND brand_name ~ 'HCTZ|AND HYDROCHLOROTHIAZIDE'
LEFT JOIN drug_concept_stage dcs2 ON upper(dcs2.concept_name) = 'HYDROCHLOROTHIAZIDE'
WHERE dp.drug_code NOT IN (
		SELECT drug_code
		FROM active_ingredients
		);

--insert packs
INSERT INTO ds_stage (
	DRUG_CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	AMOUNT_VALUE,
	AMOUNT_UNIT,
	NUMERATOR_VALUE,
	NUMERATOR_UNIT,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT
	)
SELECT DISTINCT dcs.concept_code,
	dcs2.concept_code,
	AMOUNT_VALUE::FLOAT,
	AMOUNT_UNIT,
	NUMERATOR_VALUE::FLOAT,
	NUMERATOR_UNIT,
	DENOMINATOR_VALUE::FLOAT,
	DENOMINATOR_UNIT
FROM new_pack np
JOIN drug_concept_stage dcs ON INITCAP(np.concept_name) = INITCAP(dcs.concept_name)
	AND dcs.concept_class_id = 'Drug Product'
JOIN drug_concept_stage dcs2 ON INITCAP(np.ingredient) = INITCAP(dcs2.concept_name)
	AND dcs2.concept_class_id = 'Ingredient';

--pc_stage
INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount
	)
SELECT DISTINCT p.concept_code,
	dcs.concept_code,
	amount::INT
FROM new_pack p
JOIN drug_concept_stage dcs ON dcs.concept_name = INITCAP(p.concept_name)
	AND dcs.concept_class_id = 'Drug Product';

--drug to ATC checked
INSERT INTO relationship_to_concept (
	CONCEPT_CODE_1,
	VOCABULARY_ID_1,
	CONCEPT_ID_2,
	PRECEDENCE,
	CONVERSION_FACTOR
	)
SELECT DISTINCT dcs.concept_code,
	'DPD',
	CASE 
		WHEN c.concept_id = 21600173
			THEN 43534743
		WHEN c.concept_id = 21601031
			THEN 43534761
		WHEN c.concept_id = 21601233
			THEN 45893456
		WHEN c.concept_id = 21603154
			THEN 43534798
		WHEN c.concept_id = 21603606
			THEN 21603013
		WHEN c.concept_id = 21604209
			THEN 21604523
		ELSE c.concept_id
		END,
	precedence,
	conversion_factor
FROM prev_rtc
JOIN drug_concept_stage dcs ON concept_code_1 = concept_code
	AND concept_class_id_1 = 'Drug Product'
	AND concept_class_id = 'Drug Product'
JOIN concept c ON concept_code_2 = c.concept_code
	AND c.vocabulary_id = 'ATC';
	

INSERT INTO relationship_to_concept (
	CONCEPT_CODE_1,
	VOCABULARY_ID_1,
	CONCEPT_ID_2,
	PRECEDENCE,
	CONVERSION_FACTOR
	)
SELECT DISTINCT concept_code,	'DPD', concept_id_2, precedence, conversion_factor
from new_rtc
join drug_concept_stage on upper(concept_name_1)=upper(concept_name) and concept_class_id_1 = concept_class_id;

--remove unnecessary [Drug] from names
update drug_concept_stage
set concept_name = regexp_replace (concept_name, ' \[Drug\]', '','g')
where concept_name like '%[Drug]';

--Give unmapped concepts to medical coders
--At the end, all tables should be ready to be fed into the working\Build_RxE.sql.sql script
