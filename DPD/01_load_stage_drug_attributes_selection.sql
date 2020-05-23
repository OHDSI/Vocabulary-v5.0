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
* Authors: Anna Ostropolets, Timur Vakhitov, Oleg Zhuk
* Date: 2020
**************************************************************************/

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

--STEP 0: Preparation and duplicates removal
--Decision making process for duplicates:
-- Take non-veterinary valid drugs first
DROP TABLE IF EXISTS temp_duplicates_removal;
CREATE TABLE temp_duplicates_removal AS (
with a AS (SELECT LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') as drug_id
FROM sources.dpd_drug_all
GROUP BY LTRIM(DRUG_IDENTIFICATION_NUMBER, '0')
HAVING count(*) > 1)

SELECT drug_code, class, LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') AS drug_id, brand_name, last_update_date, filler_column1,
       row_number() over (partition BY LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') ORDER BY filler_column1, class, last_update_date, length(brand_name)) AS rank
FROM sources.dpd_drug_all
WHERE LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') IN (SELECT drug_id FROM a)
AND LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') != 'Not Applicable/non applicable'
ORDER BY drug_identification_number)
;

--Step 1: Separation drugs and devices
--All disinfectants, veterinary medicine, radiopharmaceuticals, cosmetic materials, dietary supplements, etc. based on product categorization
DROP TABLE IF EXISTS non_drug;
CREATE TABLE non_drug AS
SELECT DISTINCT s.DRUG_CODE,
	PRODUCT_CATEGORIZATION,
	CLASS,
	LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') AS DRUG_ID,
	BRAND_NAME,
	DESCRIPTOR,
	PEDIATRIC_FLAG,
	ACCESSION_NUMBER,
	NUMBER_OF_AIS,
	AI_GROUP_NO,
	NULL::VARCHAR AS INVALID_REASON,
    NULL::DATE AS valid_start_date,
    NULL::DATE AS valid_end_date
FROM sources.dpd_drug_all s
JOIN sources.dpd_active_ingredients_all ai
ON ai.drug_code = s.drug_code
WHERE (upper(trim(class)) IN ('DISINFECTANT','VETERINARY','RADIOPHARMACEUTICAL') OR
      (upper(trim(product_categorization)) IN ('CAT IV - ANTIPERSPIRANTS') AND s.drug_code NOT IN (SELECT drug_code FROM sources.dpd_active_ingredients_all WHERE upper(trim(ingredient)) ~ 'TROLAMINE')) OR
      (upper(trim(product_categorization)) IN ('CAT IV - ANTISEPTIC SKIN CLEANSERS') AND s.drug_code NOT IN (SELECT drug_code FROM sources.dpd_active_ingredients_all WHERE upper(trim(ingredient)) ~ 'CHLORHEXIDINE|CHLOROXYLENOL|NAPROXEN')) OR
      (upper(trim(product_categorization)) IN ('CAT IV - CONTACT LENS DISINFECTANTS', 'CAT IV - TOILET BOWL DISINFECTANT CLEANERS', 'LS - ETHYLENE OXIDE GASEOUS STERILANT', 'CAT IV - HARD SURFACE DISINFECTANTS')) OR
      (upper(trim(product_categorization)) IN ('CAT IV - DIAPER RASH PRODUCTS', 'LS - UBIQUINONE')) OR
      (upper(trim(product_categorization)) IN ('CAT IV - FLUORIDE CONTAINING ANTI-CARIES PRODUCTS', 'LS - DENTAL AND ORAL CARE PRODUCTS FOR PROF. USE', 'LS - PEROXIDE ORAL CARE PRODUCTS')) OR
      (upper(trim(product_categorization)) IN ('CAT IV - MED. SKIN CARE PROD./SUNBURN PROTECTANTS', 'CAT IV - MEDICATED SKIN CARE PRODUCTS', 'CAT IV - SUNBURN PROTECTANTS')) OR
      (upper(trim(product_categorization)) IN ('LS - FLUORIDE-CONT. TREAT. GELS & RINSES FOR CONS.')) OR
      (upper(trim(product_categorization)) IN ('CAT IV - DIETARY MIN/DIETARY VIT. SUPPLEMENTS', 'CAT IV - DIETARY MINERAL SUPPLEMENTS', 'CAT IV - DIETARY VITAMIN SUPPLEMENTS', 'LS - VIT. SUPPLEMENTS/MIN SUPPLEMENTS', 'LS - MINERAL SUPPLEMENTS', 'LS - VITAMIN SUPPLEMENTS', 'LS - VIT. SUPPL./MIN. SUPPL./UBIQUINONE', 'LS - VIT. SUPPLEMENTS/UBIQUINONE')))
AND s.drug_code NOT IN (SELECT drug_code FROM temp_duplicates_removal WHERE rank > 1)
;

--Cosmetics, scrubs, make up, sunscreen, disinfectants, soaps, diapers, dialysis, catheters, etc.
INSERT INTO non_drug(DRUG_CODE, PRODUCT_CATEGORIZATION, CLASS, DRUG_ID, BRAND_NAME, DESCRIPTOR, PEDIATRIC_FLAG, ACCESSION_NUMBER, NUMBER_OF_AIS, AI_GROUP_NO, INVALID_REASON)
SELECT DISTINCT s.DRUG_CODE,
	PRODUCT_CATEGORIZATION,
	CLASS,
	LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') AS DRUG_ID,
	BRAND_NAME,
	DESCRIPTOR,
	PEDIATRIC_FLAG,
	ACCESSION_NUMBER,
	NUMBER_OF_AIS,
	AI_GROUP_NO,
	NULL::VARCHAR AS INVALID_REASON
FROM sources.dpd_drug_all s
JOIN sources.dpd_active_ingredients_all ai
ON ai.drug_code = s.drug_code
WHERE upper(trim(brand_name)) ~ ('2IN1 MEN ADVANCED|ARRID|SPRAY ON|FLOSS|JOHNSON|MAKE.?UP|WRINKLE|NIVEA|ANTISEPTIQ|BLEMISH|DEODORANT|\.?SPF\.?|(\sFPS)|\sLIP\s|MOISTUR(E|IZ)|SUNSCREEN|\s?SUN\s?BLOCK|ANTI(-?)PERS|\sCLEAR\s|' ||
    'WASH|SOAP|AVEENO|SANITIZ|SKIN\s?CLEAN|SPORT|SCRUB|AVON|VITALIZ|DISINFECT|ANTI(SEPTIC|BACTERIAL|MICROBIAL)|\sTAPESHISEIDO|SHISEIDO|CLEANSING|SOLAIRE|BIKINI|POUDRE|BODY POWDER|DIAPER|DIALYSIS|COLORATION|CAT(H?)ET')
AND s.drug_code NOT IN (SELECT drug_code FROM non_drug)
AND s.drug_code NOT IN (SELECT drug_code FROM sources.dpd_active_ingredients_all WHERE upper(trim(ingredient)) ~ 'CAINE|DOMIPHEN|HYDROCORTISONE|INTERFERON|HEPATIT')
AND s.drug_code NOT IN (SELECT drug_code FROM temp_duplicates_removal WHERE rank > 1)
ORDER BY drug_code;

--use routes and forms that indicate non_drugs
INSERT INTO non_drug(drug_code, PRODUCT_CATEGORIZATION, CLASS, DRUG_ID, BRAND_NAME, DESCRIPTOR, PEDIATRIC_FLAG, ACCESSION_NUMBER, NUMBER_OF_AIS, AI_GROUP_NO, INVALID_REASON)
SELECT DISTINCT dp.DRUG_CODE, PRODUCT_CATEGORIZATION, CLASS, DRUG_ID, BRAND_NAME, DESCRIPTOR, PEDIATRIC_FLAG, ACCESSION_NUMBER, NUMBER_OF_AIS, AI_GROUP_NO, INVALID_REASON
FROM (
	SELECT DRUG_CODE,
		PRODUCT_CATEGORIZATION,
		CLASS,
		LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') AS DRUG_ID,
		BRAND_NAME,
		DESCRIPTOR,
		PEDIATRIC_FLAG,
		ACCESSION_NUMBER,
		NUMBER_OF_AIS,
		AI_GROUP_NO,
		NULL::VARCHAR AS INVALID_REASON
	FROM sources.dpd_drug_all
	) dp
JOIN sources.dpd_route_all r
    ON r.drug_code = dp.drug_code
JOIN sources.dpd_form_all f
    ON f.drug_code = dp.drug_code
WHERE (r.route_of_administration ~ 'HOSPITAL|COMMERCIAL|DIALYSIS|LABORATORY|ARTHOGRAPHY|HOUSEHOLD|CYSTOGRAPHY|FOOD PREMISES'
OR f.pharmaceutical_form IN ('STICK','WIPE','SWAB','FLOSS','CORD','BLOOD COLLECTION'))
AND dp.drug_code NOT IN (SELECT drug_code FROM non_drug)
AND dp.drug_code NOT IN (SELECT drug_code FROM temp_duplicates_removal WHERE rank > 1);

--contrast media, excluding real drugs
INSERT INTO non_drug(DRUG_CODE, PRODUCT_CATEGORIZATION, CLASS, DRUG_ID, BRAND_NAME, DESCRIPTOR, PEDIATRIC_FLAG, ACCESSION_NUMBER, NUMBER_OF_AIS, AI_GROUP_NO, INVALID_REASON)
SELECT DISTINCT dp.DRUG_CODE, PRODUCT_CATEGORIZATION, CLASS, dp.DRUG_ID, BRAND_NAME, DESCRIPTOR, PEDIATRIC_FLAG, ACCESSION_NUMBER, NUMBER_OF_AIS, AI_GROUP_NO, INVALID_REASON
FROM (
	SELECT DRUG_CODE,
		PRODUCT_CATEGORIZATION,
		CLASS,
		LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') AS DRUG_ID,
		BRAND_NAME,
		DESCRIPTOR,
		PEDIATRIC_FLAG,
		ACCESSION_NUMBER,
		NUMBER_OF_AIS,
		AI_GROUP_NO,
		NULL::VARCHAR AS INVALID_REASON
	FROM sources.dpd_drug_all
	) dp
JOIN sources.dpd_active_ingredients_all ai
    ON dp.drug_code = ai.drug_code
WHERE upper(trim(ai.ingredient)) IN ('BARIUM SULFATE', 'IOHEXOL', 'IODIXANOL', 'IOXAGLATE MEGLUMINE', 'CYANOCOBALAMIN CO 57', 'IOXAGLATE SODIUM', 'IOVERSOL', 'IOTROLAN', 'IOPYDONE', 'IOPYDOL', 'IOTHALAMATE SODIUM',
'URANIUM NITRATE', 'IOTHALAMATE MEGLUMINE', 'IOPROMIDE', 'IOPANOIC ACID', 'IOPAMIDOL', 'DIATRIZOATE MEGLUMINE','DIATRIZOATE SODIUM', 'X-RAY', 'XENON 133 XE', 'IODINE (IOHEXOL)')
AND dp.drug_code NOT IN (SELECT drug_code FROM non_drug)
AND dp.drug_code NOT IN (SELECT drug_code FROM temp_duplicates_removal WHERE rank > 1)
;

--New masks: linements, dietary supplements, creams, lotions, directly derived from blood products, excluding real drugs etc.
INSERT INTO non_drug(DRUG_CODE, PRODUCT_CATEGORIZATION, CLASS, DRUG_ID, BRAND_NAME, DESCRIPTOR, PEDIATRIC_FLAG, ACCESSION_NUMBER, NUMBER_OF_AIS, AI_GROUP_NO, INVALID_REASON)
SELECT DISTINCT s.DRUG_CODE,
	PRODUCT_CATEGORIZATION,
	CLASS,
	LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') AS DRUG_ID,
	BRAND_NAME,
	DESCRIPTOR,
	PEDIATRIC_FLAG,
	ACCESSION_NUMBER,
	NUMBER_OF_AIS,
	AI_GROUP_NO,
	NULL::VARCHAR AS INVALID_REASON
FROM sources.dpd_drug_all s
JOIN sources.dpd_active_ingredients_all ai
ON ai.drug_code = s.drug_code
WHERE upper(trim(brand_name)) ~ ('COLGATE|AQUAFRESH|CLINIQUE|TISSEEL|\sSUPP|TEETH|LOTION|NUTRIENT|CREAM|LIQUIDE|LINIMENT|TEST|DIET SUPP|POMMADE|SUPPLEMENT|SHAMPOO|DELFLEX|BARRIER|PROTECTION|\sRUB\s|Q(-?)10|HALLS|TEARS|CONDITIONER|BÉBÉ HEALING OINTMENT|DOVE|HEAD & SHOULDERS|LIP GLOSS|FLAWLESS|CLEAR FACE|ORAL( ?)(-?)B')
AND s.drug_code NOT IN (SELECT drug_code FROM non_drug)
AND s.drug_code NOT IN (SELECT drug_code FROM sources.dpd_active_ingredients_all WHERE upper(trim(ingredient)) ~ 'NAPHAZOLINE|TYROTHRICIN|POVIDONE|LINDANE|FLUOCINOLONE|TOXOID|LACTOBACILLUS|VACCINE|TESTOSTERONE|PROMETHAZINE|KETOCONAZOLE|GENTAMICIN|CHLORPHENESIN|FLUOCINONIDE|FUSIDIC|CLOBETASOL|BECLOMETHASONE|DIPHENHYDRAMINE|CAINE|NEOMYCIN|PHENYLEPHRINE|TROLAMINE|DIETHYLAMINE|FLUOROURACIL|TRIAMCINOLONE|EDOXUDINE|ECONAZOLE|UNDECYLEN|METHASONE|CAPSAICIN|MICONAZOLE|GRAMICIDIN|CORTISONE|CHLOROXYLENOL|CLOTRIMAZOLE|DOXEPIN|DROMETRIZOLE')
AND s.drug_code NOT IN (SELECT drug_code FROM temp_duplicates_removal WHERE rank > 1)
ORDER BY drug_code;

--Update non-drug (device) invalid_reason and assign valid_start_date and valid_end_date
with latest_drug_status AS
    (
SELECT DISTINCT drug_code, status, history_date, row_number() over (partition by drug_code ORDER BY history_date DESC) AS rank
FROM sources.dpd_status_all
GROUP BY drug_code, status, history_date
    ),
     valid_start_date AS
    (
SELECT drug_code, min(history_date) as valid_start_date
FROM sources.dpd_status_all
WHERE upper(trim(status)) IN ('MARKETED', 'APPROVED')
GROUP BY drug_code
    ),
     valid_end_date AS
    (
SELECT drug_code, max(history_date) as valid_end_date, min(history_date) as valid_start_date_for_not_approved
FROM sources.dpd_status_all
WHERE (upper(trim(status)) = 'DORMANT' OR upper(trim(status)) ~ 'CANCELLED')
GROUP BY drug_code
    )

UPDATE non_drug
    SET valid_start_date = coalesce(vs.valid_start_date, ve.valid_start_date_for_not_approved),
        valid_end_date = coalesce(CASE WHEN vs.valid_start_date > ve.valid_end_date THEN to_date('20991231', 'yyyymmdd')
           ELSE ve.valid_end_date END, to_date('20991231', 'yyyymmdd')),
        invalid_reason = CASE WHEN ((upper(ls.status) ~ 'CANCELLED') OR upper(ls.status) = 'DORMANT') OR ve.valid_end_date < current_date THEN 'D'
            END
FROM latest_drug_status ls
LEFT JOIN valid_start_date vs
ON ls.drug_code = vs.drug_code
LEFT JOIN valid_end_date ve
ON ls.drug_code = ve.drug_code
WHERE ls.rank = 1
AND ls.drug_code = non_drug.drug_code;

--create drug products with valid_start_date and valid_end_date
DROP TABLE IF EXISTS drug_product;
CREATE TABLE drug_product AS
with latest_drug_status AS
    (
SELECT DISTINCT drug_code, status, history_date, row_number() over (partition by drug_code ORDER BY history_date DESC) AS rank
FROM sources.dpd_status_all
GROUP BY drug_code, status, history_date
    ),
     valid_start_date AS
    (
SELECT drug_code, min(history_date) as valid_start_date
FROM sources.dpd_status_all
WHERE upper(trim(status)) IN ('MARKETED', 'APPROVED')
GROUP BY drug_code
    ),
     valid_end_date AS
    (
SELECT drug_code, max(history_date) as valid_end_date, min(history_date) as valid_start_date_for_not_approved
FROM sources.dpd_status_all
WHERE (upper(trim(status)) = 'DORMANT' OR upper(trim(status)) ~ 'CANCELLED')
GROUP BY drug_code
    )

    SELECT s.drug_code,
       product_categorization,
       class,
       LTRIM(DRUG_IDENTIFICATION_NUMBER, '0') AS DRUG_ID,
       brand_name,
       descriptor,
       pediatric_flag,
       accession_number,
       number_of_ais,
       ai_group_no,
       filler_column1,
       filler_column2,
       filler_column3,
       coalesce(vs.valid_start_date, ve.valid_start_date_for_not_approved) AS valid_start_date,
       coalesce(CASE WHEN vs.valid_start_date > ve.valid_end_date THEN to_date('20991231', 'yyyymmdd')
           ELSE ve.valid_end_date END, to_date('20991231', 'yyyymmdd')) AS valid_end_date,
    CASE WHEN ((upper(ls.status) ~ 'CANCELLED') OR upper(ls.status) = 'DORMANT') OR ve.valid_end_date < current_date THEN 'D'
        ELSE NULL END AS invalid_reason
FROM sources.dpd_drug_all s
LEFT JOIN latest_drug_status ls
ON ls.drug_code = s.drug_code
LEFT JOIN valid_start_date vs
ON vs.drug_code = s.drug_code
LEFT JOIN valid_end_date ve
ON ve.drug_code = s.drug_code
WHERE ls.rank = 1
AND s.drug_code NOT IN (SELECT drug_code FROM non_drug)
AND s.drug_code NOT IN (SELECT drug_code FROM temp_duplicates_removal WHERE rank > 1);

--Not longer needed
DROP TABLE temp_duplicates_removal;

--Step 2: Create service tables

--This table left for ds_stage generation
DROP TABLE IF EXISTS active_ingredients;
CREATE TABLE active_ingredients AS
SELECT DISTINCT drug_code,
	active_ingredient_code,
	ingredient,
	strength,
	strength_unit,
	strength_type,
	dosage_value,
	dosage_unit,
	notes
FROM sources.dpd_active_ingredients_all;

/*
    Put inserts and updates here if required
*/

DROP TABLE IF EXISTS route;
CREATE TABLE route AS
SELECT DISTINCT drug_code,
	route_of_administration
FROM sources.dpd_route_all
;

DROP TABLE IF EXISTS packaging;
CREATE TABLE packaging AS
SELECT drug_code,
	package_size_unit,
	package_type,
	package_size,
	product_information
FROM sources.dpd_packaging_all a
;

DROP TABLE IF EXISTS companies;
CREATE TABLE companies AS
SELECT DISTINCT drug_code,
	mfr_code,
	company_code,
	company_name,
    trim(regexp_replace(regexp_replace(company_name, '\,?( INC(\.)?)|CORPORATION|(\,? LIMITED\.?)|( CORP$)|( L\.P\.)|( GMBH\s?\&?)|( CO(\.)?)$|( CORP(\.)?)$|( CO\.)|(& CO )|( PLC(\.)?)|(\,?\s?\/?LTD(\.)?)|(\s?\/?LT(E|ÉE)\.?)|(\,)$|\(\D+\)|\(\d+\)', '', 'g'), '\s\s', ' ','g')) AS edited_name,
	company_type,
	address_mailing_flag,
	address_billing_flag,
	address_notification_flag,
	address_other,
	suite_number,
	street_name,
	city_name,
	province,
	country,
	postal_code,
	post_office_box
FROM sources.dpd_companies_all a
;

DROP TABLE IF EXISTS therapeutic_class;
CREATE TABLE therapeutic_class AS
SELECT drug_code,
	tc_atc_number,
	tc_atc,
	tc_ahfs_number,
	tc_ahfs
FROM sources.dpd_therapeutic_class_all a
;

--Table with units for drug_concept_stage
DROP TABLE IF EXISTS unit;
CREATE TABLE unit AS
SELECT DISTINCT UPPER(strength_unit) AS concept_name,
	UPPER(strength_unit) AS concept_code,
	'Unit' AS concept_class_id
FROM active_ingredients
WHERE strength_unit IS NOT NULL
	AND strength_unit != 'NIL';

ALTER TABLE unit ADD constraint unique_units UNIQUE (concept_name, concept_code);

INSERT INTO unit (concept_name, concept_code, concept_class_id)
VALUES ('SQ CM','SQ CM', 'Unit') ON CONFLICT DO NOTHING;
INSERT INTO unit (concept_name,concept_code, concept_class_id)
VALUES ('HOUR','HOUR', 'Unit') ON CONFLICT DO NOTHING;
INSERT INTO unit (concept_name,concept_code, concept_class_id)
VALUES ('ACT','ACT', 'Unit') ON CONFLICT DO NOTHING;

--Ingredient
DROP TABLE IF EXISTS ingr;
CREATE TABLE ingr AS
SELECT drug_code,
	active_ingredient_code,
	ingredient AS initial_name,
    ingredient AS modified_name,
    ingredient AS precise_ingredient_name,
	'Ingredient'::varchar AS concept_class_id
FROM active_ingredients;

--Updating ingredients in order to delete all unnecessary information
UPDATE ingr
SET modified_name = trim(regexp_replace(modified_name, ' \(.*\)', '','g'))
WHERE modified_name ~ '\(.*\)$'
	AND modified_name !~ '(\()HUMAN|RABBIT|RECOMBINANT|SYNTHETIC|ACTIVATED|OVINE|ANHYDROUS|VICTORIA|YAMAGATA|PMSG|H\dN\d|NPH|8|FIM|PRP-T|FSH|MCT|JERYL LYNN STRAIN|EQUINE|DILUENT|WISTAR RA27/3 STRAIN|EDMONSTON B STRAIN|B2|DOLOMITE|TUBERCULIN TINE TEST|TI 201|ETHYLENEOXY|CALCIFEROL|MA HUANG|BASIC|CALF|LIVER|PAW|PORK(\))';


UPDATE ingr
SET modified_name = trim(regexp_replace(modified_name, ' \(.*\)', '','g'))
WHERE modified_name LIKE '%(%BASIC%)'
	AND modified_name NOT LIKE '%(DIBASIC)'
	AND modified_name NOT LIKE '%(TRIBASIC)';

--Working out precise ingredients
UPDATE ingr
SET precise_ingredient_name = trim(regexp_replace(substring(initial_name, '\(.*\)'), '\(|\)', '', 'g'))
WHERE (
		initial_name !~* '(\()HUMAN|RABBIT|RECOMBINANT|SYNTHETIC|ACTIVATED|OVINE|ANHYDROUS|BASIC|VICTORIA|YAMAGATA|PMSG|H\dN\d|NPH|8|V.C.O|D.C.O|FIM|PRP-T|FSH|BCG|R-METHUG-CSF|MCT|JERYL LYNN STRAIN|EQUINE|DILUENT|WISTAR RA27/3 STRAIN|SACUBITRIL VALSARTAN SODIUM HYDRATE COMPLEX|EDMONSTON B STRAIN|HAEMAGGLUTININ-STRAIN B(\))'
		AND initial_name !~ '(\()Neisseria meningitidis group B NZ98\/254 strain|2|DOLOMITE|TUBERCULIN TINE TEST|BONE MEAL|FISH OIL|LEMON GRASS|LEAVES|ACETATE|YEAST|KELP|TI 201|COD LIVER OIL|\[CU\(MIB\)4\]BF4|ETHYLENEOXY|PAPAYA|CALCIFEROL|MA HUANG|HORSETAIL|FLAXSEED|EXT\.|ROTH|CALF|PINEAPPLE|LIVER|PAW|PORK(\))'
		)
	OR (
		initial_name LIKE '%(%BASIC%)'
		AND initial_name NOT LIKE '%(DIBASIC)'
		AND initial_name NOT LIKE '%(TRIBASIC)'
		);

UPDATE ingr
SET precise_ingredient_name = NULL
WHERE precise_ingredient_name = modified_name OR
      (precise_ingredient_name ~ ('FLAXSEED|ROTH|YEAST|BONE MEAL|OYSTER SHELLS|FISH OIL|LINSEED OIL|BORAGE OIL|KELP|SEA PROTEINATE|PAPAYA|HORSETAIL|ROSE HIPS|BLACK CURRANT|DOG ROSE|CAPSICUM|CHERRY|ACEROLA')) OR
(drug_code = '10845' AND active_ingredient_code = '10225' AND precise_ingredient_name = 'POVIDONE-IODINE') OR
(drug_code = '5855' AND active_ingredient_code = '105' AND precise_ingredient_name = 'MAGNESIUM OXIDE') OR
(drug_code = '140' AND active_ingredient_code = '778' AND precise_ingredient_name = 'MAGNESIUM CITRATE');

--Taking precise ingredients from the brackets
UPDATE ingr
SET precise_ingredient_name = regexp_replace(substring(precise_ingredient_name, '\(.*\)'), '\(|\)', '', 'g')
WHERE precise_ingredient_name ~ '\(.*\)';

--Parsing ingredients with ','
--Temp table with
CREATE TABLE ingr_2 AS
    (SELECT drug_code, active_ingredient_code, initial_name, modified_name, precise_ingredient_name, trim(regexp_split_to_table(precise_ingredient_name, ',')) AS new_modified_precise_ingredient_name, 'Ingredient' AS concept_class_id
    FROM ingr

    UNION ALL

    SELECT drug_code, active_ingredient_code, initial_name, modified_name, precise_ingredient_name, NULL AS new_modified_precise_ingredient_name, 'Ingredient' AS concept_class_id
    FROM ingr
    WHERE precise_ingredient_name IS NULL
        );

TRUNCATE TABLE ingr;
INSERT INTO ingr(drug_code, active_ingredient_code, initial_name, modified_name, precise_ingredient_name, concept_class_id)
SELECT drug_code,
       active_ingredient_code,
       initial_name,
       modified_name,
       new_modified_precise_ingredient_name,
       concept_class_id
FROM ingr_2
;

DROP TABLE ingr_2;

--Small bugs
UPDATE ingr
SET precise_ingredient_name = NULL
WHERE precise_ingredient_name IN (
		'DEXTROSE',
		'EPHEDRA',
		'CIG',
		'BLACK CURRANT',
		'FEVERFEW',
		'EXTRACT',
		'HOMEO',
		'III',
		'INS',
		'PRP',
		'NUTMEG',
		'RHPDGF-BB',
		'SAGO PALM',
		'SEA PROTEINATE',
		'SOYBEAN',
		'VIRIDANS AND NON-HEMOLYTIC',
		'DURAPATITE',
		'OXYCARBONATE',
		'BENZOTHIAZOLE',
		'MORPHOLINOTHIO',
		'OKA/MERCK STRAIN',
        'DODECYLISOQUINOLINIUM BROMIDE (2)',
        'PINENE (2)',
        'MIBI',
        'DIPLOCOCCUS'
		);

DROP TABLE IF EXISTS forms;
CREATE TABLE forms AS
    (
SELECT DISTINCT drug_code,
                initcap(trim(regexp_replace(regexp_replace(pharmaceutical_form, '\(|\)|\,', '', 'g'), '\s{2,}', ' ', 'g'))) AS form_name
FROM sources.dpd_form_all
        WHERE initcap(trim(regexp_replace(regexp_replace(pharmaceutical_form, '\(|\)|\,', '', 'g'), '\s{2,}', ' ', 'g'))) NOT IN ('0-Unassigned', 'Bolus')
    );


--Brand Names
DROP TABLE IF EXISTS brand_name;
CREATE TABLE brand_name AS
SELECT DISTINCT drug_code,
	brand_name,
	regexp_replace(regexp_replace(regexp_replace(brand_name, '(\s|-)(CAPSULES|STERILE|POWDER|INTRATHECAL|DESINFECTANT|CAPSULE|CAPLETS|CAPLET|CAPS|CAP|ONT|SOLTN|SHP|INJECTABLE|SHAMPOO|INFUSION|CONCENTRATE|LOZENGES|SUPPOSITORY|INTRAVENOUS|DISPERSIBLE|LOZENGE|VAGINAL|INJ\.|CHEWABLE|CHEW|SUPPOSITORIES|LIQUID|LIQ|OPHTHALMIC|OPH|SUSPENSION|SUS|SRT|ORAL|RINSE|ORL|SOLUTION|SOL|LETS|PWS|SYR|PWR|GRANULE|SUPPOSITOIRE|DROPS|SYRUP|VIAL|IMPLANT|STK|GRAN|TABLETS|TABLET|TAB|FOR|INJECTION|INJ)(\s|,)', ' ','g'), '\(.*\)', '','g'), '\s-\s.*', '','g') AS new_name
FROM drug_product
WHERE brand_name !~ '(\((D\d|S#|R))|(\dDH)|(\s\dD)|(\d+X)|((\dCH))|(\sUSP)|(AVEC)|(\sCATH)|(COMPOS)|(ACID CONCENTRATE)|(CONCENTRATED)|(STANDARDIZED)|(HOMEOPATHIC MEDICINE)|INJEEL|FORTE'
;

--TODO: this mask doesn't work properly according to regex101, but does work here
UPDATE brand_name
SET new_name = regexp_replace(new_name, '\s(d+)?(/)?\d+(\.\d+)?(\s?)(\w+)?/(\d+)?(\.\d+)?(\w+)?(/)?(\d+)?(\w+)?', '','g');

--TODO: this mask doesn't work properly according to regex101, but does work here
UPDATE brand_name
SET new_name = regexp_replace(new_name, '(\s|-)\d+(([.,])\d+)?(\s)?(MG|MCG|GM|UI|IU|I\.U\.)(/)?(ML)?|\d+$', '','g')
WHERE brand_name !~ 'STELABID';

UPDATE brand_name
SET new_name = regexp_replace(new_name, '(NEBULES.*)|PAKS|((\d+)?:.*)|(AVEC.*)|(\d+(\.\d+)?%)|(\sIV)', '','g')
WHERE brand_name !~ 'STELABID';

--cut all the forms (Step 1 of 2)
UPDATE brand_name
SET new_name = regexp_replace(new_name, '(\s|-)(CAPSULES|CAPSULE|CAPLETS|CAPLET|CAPS| CRM|CAP|ONT|SOLTN|SHP|INJECTABLE|SHAMPOO|INFUSION|CONCENTRATE|LOZENGES|PELLETS|PELLET|COMPRIMES|LOZ|SUPPOSITORY|INTRAVENOUS|DISPERSIBLE|LOZENGE|VAGINAL|INJ\.|CHEWABLE|CHEW|BUVABLES|SUPPOSITORIES|LIQUID|SOLUTION|CR?ME|CREAM|LOTION|TOOTHPASTE|LIQ|OPHTHALMIC|OPH|SUSPENSION|SUS|SRT|INHALER|ORAL|RINSE|ORL|SOL|LETS|PWS|SYR|PWR|GRANULE|SUPPOSITOIRE|DROPS|SYRUP|VIAL|IMPLANT|STK|GRAN|TABLETS|TRANSDERMAL SYSTEM|TABLET|TAB|FOR|INJECTION|INJ$|(\d+-)?\s?\d+)$', ' ','g')
WHERE brand_name !~ 'STELABID';

--cut all the forms (Step 2 of 2)
UPDATE brand_name
SET new_name = regexp_replace(new_name, '\(.*\)', '','g');

--cut the forms+route+flavours
UPDATE brand_name
SET new_name = regexp_replace(new_name, 'APPLE|FOAM|POWDER|MEDICATED|HONEY|GINGER|CINNAMON|CITRUS|TYRANNA|BUBBLE GUM|WITCHY CANDY|GRAPE|KOALA BERRY|LEMON|SYSTEM |GRANULES|SCALP APPLICATION|CARTRIDGE|FLAVOURED|FLAVORED|MULTIFLAVOUR|FLAVOUR|BUTTERSCOTCH|ORANGE|CHERRY|MINT|PACKET|MENTHOLATED|INHALATION SOLUTON|PHARMACY BULK|ENEMA|ELIXIR|SYRINGE|IRRIGATING|TOPICAL|NASAL SPRAY', '','g')
WHERE NOT new_name ~ '(^MINT-)';

--cut the forms+route
UPDATE brand_name
SET new_name = regexp_replace(new_name, 'AUTO(-)?INJECTOR|INJECTION|INJECTABLE|ANTIFUNGAL|NON-PRESCRIPTION|NON PRESCRIPTION|ANTI-FUNGAL|LINIMENT|AROMATIQUE|OINTMENT|AQUAGEL|RESPIRATOR|CHEWS|REMINERALIZING|BLACK CURRANT|PEACH|AQUEOUS|PINK FRUIT|CRYSTAL|FRAGRANCE FREE|SUGAR FREE|ALCOHOL FREE| YEAST FREE| CFC FREE|ASSORTED|ENTERIC COATED', '','g');

--cut units
UPDATE brand_name
SET new_name = regexp_replace(new_name, '( MCG$)|(\d+UNIT)|( SUP$)|( TOP$)|( AMP$)|( MG$)|( CRM$)|( PREP$)|( VAG$)|( EYE$)|( EAR$)|( SOLN$)|( ORAL$)|( SUSP$)|\d*?\s?MG/ML', '', 'g');

--cut %,coma etc
UPDATE brand_name
SET new_name = regexp_replace(replace(new_name, '%', ''), '(-|,|\.| INH|#)$', '', 'g');

UPDATE brand_name
SET new_name = trim(regexp_replace(new_name, '\s?\d*?\s?\.?\d*?(MILLION|M) (I.?U.?|UNIT)\/(\d?.?\d?ML|VIAL)|IM SC|FOR SUSPENSION\s?\d\s?ML|INJ,USP|\sSUSP$|SUSPENSION\s?\dML', ' ', 'g'));

--brand name trimming and removing unnecessary white spaces
UPDATE brand_name
SET new_name = trim(regexp_replace(new_name, '\s{2,}|\s\,\s|,$|INTRA(VENOUS|MUSCULAR|LESIONAL|NASAL|VITREAL)', ' ', 'g'));

--DELETE

DELETE FROM brand_name
WHERE length(new_name) < 4;

--deleting homeopathy drugs (form instance, apis milleflora 4D)
DELETE
FROM brand_name
WHERE new_name ~ '(\d+D)|(D\d+)|(\sC\d+\s)|(\s\d+X\s)|(\s\d+X-(\d+)?C\d+\s)|(\sC\d+-(\d+)?C\d+\s)|\(';

--deleting ingredients
DELETE
FROM brand_name
WHERE new_name ~ 'PRAEPARATUM|CONDITIONING|METALLICUM|COMPOUND|CHARCOAL|BEECH|^\d+|\.|USP|CITRASATE|COENZYME Q10|^FORMULA|^VITAMIN'

--deleting vitamins, salts (except ing + supplier name)
DELETE
FROM brand_name
WHERE new_name ~ 'CODEINE|CHLORIDE|SODIUM|DILUENT|VACCIN|/|SULFATE|B COMPLEX/BETA-CAROTENE|CAL-MAG|CAL MAG|CALAMINE|CALCIUM|CHELATED|ACIDE|POTASSIUM|MAGNESIUM|\sZINC|ZINC\s|CARBONATE|HYDROCHLOROTHIAZIDE|VANADIUM|DEXTROSE|PRIMROSE|GINGIBRAID|IRON|LIDOCAINE|FLORA |FLORASUN|LEAVES|LEVONORGESTREL|ALUMINA|HEEL (\d)+|HP(\d)+ DPS|R(\d)+ DPS|D(\d)+ - DPS|R (\d)+ DPS|R-(\d)+ DPS|D (\d)+ DPS|D-(\d)+ DPS|(\d)+MM PLS|AC?TAMINOPH?NE|ACETAMINOPHEN|LACTATE|MIXTURE|NIACINAMIDE|NATRIUM|PETROLEUM|SATIVUM|CEANOTHUS|BEECH'
	AND new_name !~ 'ACH|ACT|GD-|NTP|FTP-|^BCI |AJ-|NOVO|NAT-|NU-|TARO-|ZINDA-|MUSCLE|MED-|ODAN-|PDP-|PENTA-|^Q-|RHO-|RHOXAL|SEPTA-|-ODAN|SYN-|^MED |MDK-|PRO-|ZYM-|ABBOTT|VITA-|VAN-|VAL-|ROCKY|RAN-|GEN-|BEECH|ALTI-|MYL-|MAR-|AA-|JAMP|ACCEL|AURO|INJEEL|APO|AVA|BIO|DOM|RIVA|TORRENT-|MINIMS|T/GEL|MINT|MYLAN|NTPORB|PAL|PAT|PHL|PMS|PORT|RATIO|SANDOZ|TEVA';

--deleting vitamins, salts (except ing + supplier name)
DELETE
FROM brand_name
WHERE new_name ~ 'ALLERGENIC|FLOS|AMMONIA|MURICATUM|CERTIFIED|IBUPROFEN DAYTIME|ONE ALPHA|ONE-ALPHA|SCLERATUS|NATRUM|ISONIAZIDE|COMPLEX|HOMEO-|BRASILIENSIS|LIQUID|- COUGH|HOMEOPATHIC|GUAIFENSINE|IODUM|IODIUM|CHEWABLE|MULTIMINERALS|MULTIPLE|MULTIVITAMIN|ENZYME|ANTIBIOTIC|CHILDREN'
	AND new_name !~ 'BENYLIN|ACH|ACT|GD-|NTP|FTP-|^BCI |AJ-|NOVO|NAT-|NU-|FLINTSTONES|TARO-|ZINDA-|RELIEF|GAVISCON|MUSCLE|MED-|ODAN-|PDP-|PENTA-|^Q-|RHO-|RHOXAL|SEPTA-|-ODAN|SYN-|^MED |MDK-|PRO-|ZYM-|ABBOTT|VITA-|VAN-|VAL-|ROCKY|RAN-|GEN-|BEECH|ALTI-|MYL-|MAR-|AA-|JAMP|ACCEL|AURO|INJEEL|APO|AVA|BIO|DOM|RIVA|MINIMS|T/GEL|MINT|MYLAN|NTPORB|PAL|PAT|PHL|PMS|PORT|RATIO|SANDOZ|TEVA';


--deleting acids, salts, enzymes (except ing + supplier name)
DELETE
FROM brand_name
WHERE new_name ~ 'COD LIVER|CC II|VC II|(^DECONGESTANT )|(^COOLING )|RELEASED|BACITRACIN|INJECTION|CISPLATIN|ACIDUM|CAROTENE|ECHINACEA| ACID| VACC|INACTIVATED|ACONIT|NITRATE|CALMINE|CANDIDA|CARBOPLATIN|^FORMULE|EPSOM|CITRATE|CANADENSIS|ABELMOSCHUS|BIFIDUM|ACIDOPHILUS|ACIDE|AMBROSIA|HYDROXYAPATITE|ALPHACOPHEROL|ENZYME|ALLIUM|AMOXICILLIN|THERAPEUTIC|#|SWAB|COMBINATION'
	AND new_name !~ 'ACH|ACT|GD-|NTP|FTP-|^BCI |AJ-|NOVO|NAT-|NU-|FLINTSTONES|TARO-|ZINDA-|RELIEF|GAVISCON|MUSCLE|MED-|ODAN-|PDP-|PENTA-|^Q-|RHO-|RHOXAL|SEPTA-|-ODAN|SYN-|^MED |MDK-|PRO-|ZYM-|ABBOTT|VITA-|VAN-|VAL-|ROCKY|RAN-|GEN-|BEECH|ALTI-|MYL-|MAR-|AA-|JAMP|ACCEL|AURO|INJEEL|APO|AVA|BIO|DOM|RIVA|MINIMS|T/GEL|MINT|MYLAN|NTPORB|PAL|PAT|PHL|PMS|PORT|RATIO|SANDOZ|TEVA';

DELETE
FROM brand_name
WHERE new_name ~ ' AND | W |\+|&'
	AND NOT new_name ~ 'HEAD & SHOULDERS|MUSCLE|COLD|FLU|RODAN & FIELDS|SINUS|PAIN|TRIAMINIC|FRESH & GO|DANDRUFF|FLINTSTONES|EX-LAX|TUSS|DEFEND|DAY|NIGHT';

DELETE
FROM brand_name
WHERE new_name ~ ' COMP$| 30 UNITS$|HEMORRHOIDAL|RISPERIDON'
OR new_name IN ('ALLERGY', 'DANDRUFF');

--Deleting from basic source ingredients
DELETE FROM brand_name s
WHERE drug_code IN (SELECT s.drug_code
FROM brand_name s
    JOIN ingr i
    ON i.drug_code = s.drug_code
    WHERE s.new_name ~ i.precise_ingredient_name
    OR s.new_name ~ i.modified_name);

--Deleting from devv5 ingredients
DELETE
FROM brand_name
WHERE upper(new_name) IN (
		SELECT upper(concept_name)
		FROM devv5.concept
		WHERE concept_class_id IN ('Ingredient', 'Precise Ingredient')
    AND vocabulary_id IN ('RxNorm', 'RxNorm Extension')
		);


DELETE
FROM brand_name
WHERE drug_code IN
(
 with a AS (
    SELECT upper(regexp_replace(concept_name, 'e$', '')) AS concept_name
	FROM devv5.concept
	WHERE concept_class_id IN ('Ingredient', 'Precise Ingredient')
    AND vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND concept_name NOT IN ('ASTER', 'BARBITAL', 'HERBAL', 'HYLAN')
    GROUP BY concept_name
    HAVING length(concept_name) > 4
)
SELECT s.drug_code
FROM brand_name s
FULL OUTER JOIN a
ON true
WHERE upper(new_name) LIKE ('%' || a.concept_name|| '%')
    )
;

--Final update of brand names
UPDATE brand_name
SET new_name = trim(regexp_replace(regexp_replace(new_name, 'PWS$| INJ$| SOLN$|SOLN 6 MILLION$', '', 'g'), '\s{2,}', ' ', 'g'));

DO
$$
BEGIN
UPDATE brand_name SET new_name = 'BENZAGEL'
WHERE new_name LIKE '%BENZAGEL%';
UPDATE brand_name SET new_name = 'TYLENOL'
WHERE new_name LIKE '%TYLENOL%';
UPDATE brand_name SET new_name = 'NEUTROGENA'
WHERE new_name LIKE '%NEUTROGENA%';
UPDATE brand_name SET new_name = 'TRAVASOL'
WHERE new_name LIKE '%TRAVASOL%';
UPDATE brand_name SET new_name = 'ADALAT'
WHERE new_name LIKE '%ADALAT%';
UPDATE brand_name SET new_name = 'NITRO-DUR'
WHERE new_name LIKE '%NITRO-DUR%';
UPDATE brand_name SET new_name = 'MYLAN-NITRO PATCH'
WHERE new_name LIKE '%MYLAN-NITRO PATCH%';
UPDATE brand_name SET new_name = 'TRANSDERM-NITRO'
WHERE new_name LIKE '%TRANSDERM-NITRO%';
UPDATE brand_name SET new_name = 'AMINOSYN'
WHERE new_name LIKE '%AMINOSYN%';
UPDATE brand_name SET new_name = 'BALMINIL'
WHERE new_name LIKE '%BALMINIL%';
UPDATE brand_name SET new_name = 'BEMINAL'
WHERE new_name LIKE '%BEMINAL%';
UPDATE brand_name SET new_name = 'BENYLIN'
WHERE new_name LIKE '%BENYLIN%';
UPDATE brand_name SET new_name = 'MAALOX'
WHERE new_name LIKE '%MAALOX%';
UPDATE brand_name SET new_name = 'ROBITUSSIN'
WHERE new_name LIKE '%ROBITUSSIN%';
UPDATE brand_name SET new_name = 'SUDAFED'
WHERE new_name LIKE '%SUDAFED%';
UPDATE brand_name SET new_name = 'KOFFEX DM'
WHERE new_name LIKE '%KOFFEX DM%';
UPDATE brand_name SET new_name = 'T/GEL'
WHERE new_name LIKE '%T/GEL%';
UPDATE brand_name SET new_name = 'PRO-LECARB'
WHERE new_name LIKE '%PRO-LECARB%';
UPDATE brand_name SET new_name = 'ADENOCARD'
WHERE new_name LIKE '%ADENOCARD%';
UPDATE brand_name SET new_name = 'ADVIL'
WHERE new_name LIKE '%ADVIL%';
UPDATE brand_name SET new_name = 'FLOVENT'
WHERE new_name LIKE '%FLOVENT%';
UPDATE brand_name SET new_name = 'MARCAINE'
WHERE new_name LIKE '%MARCAINE%';
UPDATE brand_name SET new_name = 'PEPTO-BISMOL'
WHERE new_name LIKE '%PEPTO-BISMOL%';
UPDATE brand_name SET new_name = 'MAXIPIME'
WHERE new_name LIKE '%MAXIPIME%';
UPDATE brand_name SET new_name = 'LAPIDAR'
WHERE new_name LIKE '%LAPIDAR%';
UPDATE brand_name SET new_name = 'E-PILO'
WHERE new_name LIKE '%E-PILO%';
UPDATE brand_name SET new_name = 'ARISTOCORT'
WHERE new_name LIKE '%ARISTOCORT%';
UPDATE brand_name SET new_name = 'GEL-KAM FLUOROCARE'
WHERE new_name LIKE '%GEL-KAM FLUOROCARE%';
UPDATE brand_name SET new_name = 'SELSUN'
WHERE new_name LIKE '%SELSUN%';
UPDATE brand_name SET new_name = 'IMOVAX'
WHERE new_name LIKE '%IMOVAX%';
UPDATE brand_name SET new_name = 'PARIET'
WHERE new_name LIKE '%PARIET%';
UPDATE brand_name SET new_name = 'BUCKLEY''S COMPLETE'
WHERE new_name LIKE '%BUCKLEY''S COMPLETE%';
UPDATE brand_name SET new_name = 'VITRASERT'
WHERE new_name LIKE '%VITRASERT%';
UPDATE brand_name SET new_name = 'VENOMIL'
WHERE new_name LIKE '%VENOMIL%';
UPDATE brand_name SET new_name = 'DRISTAN'
WHERE new_name LIKE '%DRISTAN%';
UPDATE brand_name SET new_name = 'CORICIDIN'
WHERE new_name LIKE '%CORICIDIN%';
UPDATE brand_name SET new_name = 'EFFIDOSE'
WHERE new_name LIKE '%EFFIDOSE%';
UPDATE brand_name SET new_name = 'ACNOPUR'
WHERE new_name LIKE '%ACNOPUR%';
END
$$;