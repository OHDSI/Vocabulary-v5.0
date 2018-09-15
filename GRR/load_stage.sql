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
* Authors: Anna Ostropolets
* Date: 2017
**************************************************************************/ 
--adjusting date in GRR to source data date format
--create GRR table with  fcc||'_'||PRODUCT_LAUNCH_DATE as fcc
DROP TABLE IF EXISTS grr_new_3;
CREATE UNLOGGED TABLE grr_new_3 AS
SELECT DISTINCT fcc || '_' || to_char(TO_DATE(PACK_LNCH_DT, 'mm/dd/yyyy'), 'mmddyyyy') AS FCC,
	PZN,
	INTL_PACK_FORM_DESC,
	INTL_PACK_STRNT_DESC,
	INTL_PACK_SIZE_DESC,
	PACK_DESC,
	PACK_SUBSTN_CNT,
	MOLECULE,
	WGT_QTY,
	WGT_UOM_CD,
	PACK_ADDL_STRNT_DESC,
	PACK_WGT_QTY,
	PACK_WGT_UOM_CD,
	PACK_VOL_QTY,
	PACK_VOL_UOM_CD,
	PACK_SIZE_CNT,
	ABS_STRNT_QTY,
	ABS_STRNT_UOM_CD,
	RLTV_STRNT_QTY,
	HMO_DILUTION_CD,
	FORM_DESC,
	BRAND_NAME1,
	BRAND_NAME,
	PROD_LNCH_DT,
	PACK_LNCH_DT,
	PACK_OUT_OF_TRADE_DT,
	PRI_ORG_LNG_NM,
	PRI_ORG_CD,
	NFC_123_CD
FROM (
	SELECT d.*,
		NFC_123_CD
	FROM grr_pack a
	JOIN grr_pack_clas b ON b.PACK_ID = a.PACK_ID
	JOIN grr_class c ON c.clas_id = b.clas_id
	RIGHT JOIN grr_new_2 d ON a.fcc = d.fcc
	) AS s0;

UPDATE grr_new_3
SET pzn = pzn || '-' || to_char(TO_DATE(PACK_OUT_OF_TRADE_DT, 'mm/dd/yyyy'), 'mm/dd/yyyy')
WHERE pzn IN (
		SELECT pzn
		FROM (
			SELECT DISTINCT fcc,pzn
			FROM grr_new_3
			) AS s0
		GROUP BY pzn
		HAVING COUNT(1) > 1
		)
	AND PACK_OUT_OF_TRADE_DT IS NOT NULL;

--create source table with  fcc||'_'||PRODUCT_LAUNCH_DATE as fcc
DROP TABLE IF EXISTS source_data_1;
CREATE TABLE source_data_1 AS
SELECT CASE 
		WHEN product_launch_date IS NULL
			THEN fcc
		ELSE fcc || '_' || to_char(to_date(product_launch_date, 'dd.mm.yyyy'), 'mmddyyyy')
		END AS fcc,
	LTRIM(pzn, '0') AS pzn,therapy_name_code,therapy_name,product_no,product_launch_date,product_form,product_form_name,
	strength,strength_unit,volume,volume_unit,packsize,form_launch_date,out_of_trade_date,manufacturer,manufacturer_name,
	manufacturer_short_name,who_atc5_code,who_atc5_text,who_atc4_code,who_atc4_text,who_atc3_code,who_atc3_text,
	who_atc2_code,who_atc2_text,who_atc1_code,who_atc1_text,substance,no_of_substances,nfc_no,nfc,nfc_description
FROM source_data;

--non_drug
DROP TABLE IF EXISTS grr_non_drug;
CREATE TABLE grr_non_drug AS
SELECT DISTINCT FCC,
	CONCAT (
		BRAND_NAME,
		INTL_PACK_FORM_DESC
		) AS BRAND_NAME
FROM grr_new_3
WHERE molecule ~ 'ANTACIDS|BRAIN|\sTEST|\sTESTS|HOMOEOPATHIC MEDICINES|IOTROXIC ACID|BRANDY|AMIDOTRIZOATE|BONE|COUGH\sAND\sCOLD\sPREPARATIONS|REPELLENT|DIABETIC\sFOOD|BANDAGE|ELECTROLYTE\sSOLUTIONS|UREA\s13C|TOPICAL\sANALGESICS|APPLIANCES|INCONTINENCE|DRESSING|DISINFECTANT|KOMPRESS|BLOOD|DIALYSIS|DEVICE'
	OR brand_name ~ '\.VET|TEST$|VET\.|TEST\s|KOMKPRESS|PLAST$|PLAST\s'
	AND molecule NOT LIKE '%TESTOSTER%'
	OR INTL_PACK_FORM_DESC LIKE '%WO SUB%'
UNION ALL
SELECT DISTINCT FCC,
	CONCAT (
		BRAND_NAME,
		INTL_PACK_FORM_DESC
		) AS BRAND_NAME
FROM grr_new_3
WHERE molecule ~ 'WOUND|\sDIET\s|URINARY PREPARATION|MULTIVITAMINS AND MINERALS|NON\s|TECHNETIUM|IOTALAMIC ACID|TRADITIONAL\sINDIAN\sAYURVEDIC\sMEDICINE|WASHES|\sLENS\s|THROAT\sLOZENGES|SUN\sTAN\sLOTIONS/CREAMS'
	OR NFC_123_CD LIKE 'V%';

INSERT INTO grr_non_drug
SELECT DISTINCT fcc,
	CONCAT (
		IMS_PROD_LNG_NM,
		FORM_DESC
		)
FROM grr_class a
JOIN grr_pack_clas b USING (clas_id)
JOIN grr_pack USING (pack_id)
WHERE WHO_ATC_4_CD LIKE 'V09%'
	OR WHO_ATC_4_CD LIKE 'V08%'
	OR WHO_ATC_4_CD LIKE 'V04%'
	OR WHO_ATC_4_CD LIKE 'B05ZB%'
	OR WHO_ATC_4_CD LIKE 'B05AX'
	OR WHO_ATC_4_CD LIKE 'D03AX32%'
	OR WHO_ATC_4_CD LIKE 'V03AX%'
	OR WHO_ATC_4_CD LIKE 'V10%'
	OR WHO_ATC_4_CD LIKE 'V06%'
	OR WHO_ATC_4_CD LIKE 'T2%'
	AND fcc NOT IN (
		SELECT fcc
		FROM grr_non_drug
		);

INSERT INTO grr_non_drug
SELECT FCC,
	CONCAT (
		BRAND_NAME,
		INTL_PACK_FORM_DESC
		)
FROM grr_new_3
WHERE brand_name ~ 'WUND|KOMPRESS|VET\.|\.VET$|\sVET$'
	OR INTL_PACK_FORM_DESC LIKE '%FOOD%'
UNION ALL
SELECT fcc,
	therapy_name
FROM source_data_1
WHERE substance ~ 'HAIR |ELECTROLYTE SOLUTION|ANTACIDS|ANTI-PSORIASIS|TOPICAL ANALGESICS|NASAL DECONGESTANTS|EMOLLIENT|MEDICAL|MEDICINE|SHAMPOOS|INFANT|INCONTINENCE|REPELLENT|^NON |MULTIVITAMINS AND MINERALS|DRESSING|WIRE|BRANDY|PROTECTAN|PROMOTIONAL|MOUTH|OTHER|CONDOM|LUBRICANTS|CARE |PARASITIC|COMBINATION'
	OR substance ~ 'DEVICE|CLEANS|DISINFECTANT|TEST| LENS|URINARY PREPARATION|DEODORANT|CREAM|BANDAGE|MOUTH |KATHETER|NUTRI|LOZENGE|WOUND|LOTION|PROTECT|ARTIFICIAL|MULTI SUBSTANZ|DENTAL| FOOT|^FOOT|^BLOOD| FOOD| DIET|BLOOD|PREPARATION|DIABETIC|UNDECYLENAMIDOPROPYL|DIALYSIS|DISPOSABLE|DRUG'
	OR substance IN (
		'EYE',
		'ANTIDIARRHOEALS',
		'BATH OIL',
		'TONICS',
		'ENZYME (UNSPECIFIED)',
		'GADOBENIC ACID',
		'SWABS',
		'EYE BATHS',
		'POLYHEXAMETHYLBIGUANIDE',
		'AMBAZONE',
		'TOOTHPASTES',
		'GADOPENTETIC ACID',
		'GADOTERIC ACID',
		'KEINE ZUORDNUNG'
		)
	--or WHO_ATC5_TEXT='Keine Zuordnung'
	OR WHO_ATC4_CODE = 'V07A0'
	OR WHO_ATC5_CODE LIKE 'B05AX03%'
	OR WHO_ATC5_CODE LIKE 'B05AX02%'
	OR WHO_ATC5_CODE LIKE 'B05AX01%'
	OR WHO_ATC5_CODE LIKE 'V09%'
	OR WHO_ATC5_CODE LIKE 'V08%'
	OR WHO_ATC5_CODE LIKE 'V04%'
	OR WHO_ATC5_CODE LIKE 'B05AX04%'
	OR WHO_ATC5_CODE LIKE 'B05ZB%'
	OR WHO_ATC5_CODE LIKE '%B05AX %'
	OR WHO_ATC5_CODE LIKE '%D03AX32%'
	OR WHO_ATC5_CODE LIKE '%V03AX%'
	OR WHO_ATC5_CODE LIKE 'V10%'
	OR WHO_ATC5_CODE LIKE 'V %'
	OR WHO_ATC4_CODE LIKE 'X10%'
	OR WHO_ATC2_TEXT LIKE '%DIAGNOSTIC%'
	OR WHO_ATC1_TEXT LIKE '%DIAGNOSTIC%'
	OR NFC IN (
		'MQS',
		'DYH'
		)
	OR NFC LIKE 'V%';

INSERT INTO grr_non_drug
SELECT FCC,
	CONCAT (
		BRAND_NAME,
		INTL_PACK_FORM_DESC
		)
FROM grr_new_3
WHERE INITCAP(molecule) IN (
		'Anti-Dandruff Shampoo',
		'Kidney Stones',
		'Acrylic Resin',
		'Anti-Acne Soap',
		'Antifungal',
		'Antioxidants',
		'Arachnoidae',
		'Articulation',
		'Bath Oil',
		'Breath Freshners',
		'Catheters',
		'Clay',
		'Combination Products',
		'Corn Remover',
		'Creams (Basis)',
		'Cresol Sulfonic Acid Phenolsulfonic Acid Urea-Formaldehyde Complex',
		'Decongestant Rubs',
		'Electrolytes/Replacers',
		'Eye Make-Up Removers',
		'Fish',
		'Formaldehyde And Phenol Condensation Product',
		'Formosulfathiazole,Herbal',
		'Hydrocolloid',
		'Infant Food Modified',
		'Iocarmic Acid',
		'Ioglicic Acid',
		'Iopronic Acid',
		'Iopydol',
		'Iosarcol',
		'Ioxitalamic Acid',
		'Iud-Cu Wire & Au Core',
		'Lipides',
		'Lipids',
		'Low Calorie Food',
		'Massage Oil',
		'Medicinal Mud',
		'Minerals',
		'Misc.Allergens (Patient Requirement)',
		'Mumio',
		'Musculi',
		'Nasal Decongestants',
		'Non-Allergenic Soaps',
		'Nutritional Supplements',
		'Oligo Elements',
		'Other Oral Hygiene Preparations',
		'Paraformaldehyde-Sucrose Complex',
		'Polymethyl Methacrylate',
		'Polypeptides',
		'Purgative/Laxative',
		'Quaternary Ammonium Compounds',
		'Rock',
		'Saponine',
		'Shower Gel',
		'Skin Lotion',
		'Sleep Aid',
		'Slug',
		'Suxibuzone',
		'Systemic Analgesics',
		'Tonics',
		'Varroa Destructor',
		'Vasa',
		'Vegetables Extracts'
		)
UNION
SELECT fcc,
	therapy_name
FROM source_data_1
WHERE INITCAP(substance) IN (
		'Anti-Dandruff Shampoo',
		'Kidney Stones',
		'Acrylic Resin',
		'Anti-Acne Soap',
		'Antifungal',
		'Antioxidants',
		'Arachnoidae',
		'Articulation',
		'Bath Oil',
		'Breath Freshners',
		'Catheters',
		'Clay',
		'Combination Products',
		'Corn Remover',
		'Creams (Basis)',
		'Cresol Sulfonic Acid Phenolsulfonic Acid Urea-Formaldehyde Complex',
		'Decongestant Rubs',
		'Electrolytes/Replacers',
		'Eye Make-Up Removers',
		'Fish',
		'Formaldehyde And Phenol Condensation Product',
		'Formosulfathiazole,Herbal',
		'Hydrocolloid',
		'Infant Food Modified',
		'Iocarmic Acid',
		'Ioglicic Acid',
		'Iopronic Acid',
		'Iopydol',
		'Iosarcol',
		'Ioxitalamic Acid',
		'Iud-Cu Wire & Au Core',
		'Lipides',
		'Lipids',
		'Low Calorie Food',
		'Massage Oil',
		'Medicinal Mud',
		'Minerals',
		'Misc.Allergens (Patient Requirement)',
		'Mumio',
		'Musculi',
		'Nasal Decongestants',
		'Non-Allergenic Soaps',
		'Nutritional Supplements',
		'Oligo Elements',
		'Other Oral Hygiene Preparations',
		'Paraformaldehyde-Sucrose Complex',
		'Polymethyl Methacrylate',
		'Polypeptides',
		'Purgative/Laxative',
		'Quaternary Ammonium Compounds',
		'Rock',
		'Saponine',
		'Shower Gel',
		'Skin Lotion',
		'Sleep Aid',
		'Slug',
		'Suxibuzone',
		'Systemic Analgesics',
		'Tonics',
		'Varroa Destructor',
		'Vasa',
		'Vegetables Extracts'
		);

--deleting non-drugs from working tables
DELETE
FROM grr_new_3
WHERE fcc IN (
		SELECT fcc
		FROM grr_non_drug
		);

DELETE
FROM source_data_1
WHERE fcc IN (
		SELECT fcc
		FROM grr_non_drug
		);

--delete drugs without ingredients
DELETE
FROM grr_new_3
WHERE molecule IS NULL;

--creating table with packs
DROP TABLE IF EXISTS grr_pack_0;
CREATE TABLE grr_pack_0 AS
SELECT DISTINCT a.*,
	INTL_PACK_STRNT_DESC,
	FORM_DESC,
	REGEXP_REPLACE(brand_name, '\s\s+.*', '', 'g') AS brand_name
FROM grr_ds a
JOIN grr_new_3 b ON a.fcc = b.fcc
WHERE a.fcc IN (
		SELECT fcc
		FROM grr_ds
		GROUP BY fcc,
			molecule
		HAVING COUNT(1) > 1
		);

DELETE
FROM grr_pack_0
WHERE NOT FORM_DESC ~ '/|TAB.R.CHRONO|CHRONOS';

--choose not to take KOMBI PCKG
DROP TABLE IF EXISTS grr_pack_1;
CREATE TABLE grr_pack_1 AS
	WITH lng AS (
			SELECT fcc,
				MIN(LENGTH(brand_name)) AS lng
			FROM grr_pack_0
			GROUP BY fcc
			)
SELECT b.*
FROM grr_pack_0 b
JOIN lng ON b.fcc = lng.fcc
	AND lng.lng = (LENGTH(b.brand_name));

DROP TABLE IF EXISTS grr_pack_2;
CREATE TABLE grr_pack_2 AS
SELECT fcc,
	box_size,
	molecule,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT,
	AMOUNT_VALUE,
	AMOUNT_UNIT,
	brand_name,
	CONCAT (
		molecule,
		' ',
		AMOUNT_VALUE,
		AMOUNT_UNIT,
		' ',
		box_size,
		'[',
		brand_name,
		']'
		) AS drug_name
FROM grr_pack_1;

--fix existing bias from original data
DELETE
FROM GRR_NEW_3
WHERE FCC = '635693_09012008'
	AND MOLECULE = 'BENZOYL PEROXIDE';

--brand names
DROP TABLE IF EXISTS grr_bn
CREATE TABLE grr_bn AS
SELECT DISTINCT fcc,
	REGEXP_REPLACE(brand_name, '(\s\s+.*)|>>', '', 'g') AS bn,
	brand_name AS old_name
FROM grr_new_3;

INSERT INTO grr_bn (
	fcc,
	bn,
	old_name
	)
SELECT fcc,
	CASE 
		WHEN therapy_name LIKE '%  %'
			THEN REGEXP_REPLACE(therapy_name, '\s\s.*', '', 'g')
		ELSE REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(therapy_name, '\d+\.?\d+(%|C|CM|D|G|GR|IM|VIP|TABL|IU|K|K.|KG|L|LM|M|MG|ML|MO|NR|O|TU|Y|Y/H)+', '', 'g'), '\d+\.?\d?(%|C|CM|D|G|GR|IU|K|K.|KG|L|LM|M|MG|ML|MO|NR|O|TU|Y|Y/H)+', '', 'g'), '\(.*\)', '', 'g'), REGEXP_REPLACE(PRODUCT_FORM_NAME || '.*', '\s\s', '\s', 'g'), '', 'g')
		END,
	therapy_name
FROM source_data_1;

--start from source data patterns
UPDATE grr_bn
SET bn = REGEXP_REPLACE(REGEXP_REPLACE(TRIM(REGEXP_REPLACE(bn, '(\S)+(\.)+(\S)*(\s\S)*(\s\S)*', '', 'g')), '(TABL|>>|ALPHA|--)*', '', 'g'), '(\d)*(\s)*(\.)+(\S)*(\s\S)*(\s)*(\d)*', '', 'g')
WHERE bn LIKE '%.%';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(TRIM(REGEXP_REPLACE(bn, '(\S)*\+(\S|\d)*', '', 'g')), '(\d|D3|B12|IM|FT|AMP|INF| INJ|ALT$)*', '', 'g')
WHERE bn LIKE '%+%';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, '\s\s.*', '', 'g')
WHERE bn LIKE '%  %';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, '(\S)+(>>).*', '', 'g')
WHERE bn LIKE '%>>%';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, '(\S)+(/).*', '', 'g')
WHERE bn LIKE '%/%';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, '\(.*', '', 'g')
WHERE bn LIKE '%(%';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, '(INJ).*', '', 'g')
WHERE bn LIKE '% INJ %'
	OR bn ~ '^INJ';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(RTRIM(REGEXP_REPLACE(bn, '(\s)+(\S-\S)+', '', 'g'), '-'), '(TABL|ALT|AAA|ACC |CAPS|LOTION| SUPP)', '', 'g')
WHERE bn NOT LIKE 'ALT%';

--make suppliers to a standard
UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'RATIOPH\.|RAT\.|RATIO\.|RATIO |\sRAT$', 'RATIOPHARM', 'g');

UPDATE grr_bn
SET bn = TRIM(REGEXP_REPLACE(bn, 'SUBLINGU\.|SUPPOSITOR\.|INJ\.', '', 'g'));

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'HEUM\.|HEU\.', 'HEUMANN', 'g');

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'SAND\.', 'SANDOZ', 'g');

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'NEURAXPH\.', 'NEURAXPHARM', 'g');

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'RATIOP$|RATIOP\s', 'RATIOPHARM', 'g');

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'WINTHR\.', 'WINTHROP', 'g');

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, '1A PH\.', '1A PHARMA', 'g');

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'INJEKTOP\.', 'INJEKTOPAS', 'g');

UPDATE grr_bn
SET BN = REGEXP_REPLACE(bn, '(HEUMANN HEU)|(HEUMAN HEU)| HEU$', 'HEUMANN', 'g');

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'KHP$', 'KOHLPHARMA', 'g')
WHERE bn LIKE '%KHP';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'E-M$', 'EURIM-PHARM', 'g')
WHERE bn LIKE '%E-M';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'MSD$', 'MERCK', 'g')
WHERE bn LIKE '%MSD';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'ZEN$', 'ZENTIVA', 'g')
WHERE bn LIKE '%ZEN';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'WTH$', 'WESTEN PHARMA', 'g')
WHERE bn LIKE '%WTH';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'ORI$', 'ORIFARM', 'g')
WHERE bn LIKE '%ORI';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'RDX$', 'REMEDIX', 'g')
WHERE bn LIKE '%RDX';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'PBA$', 'PB PHARMA', 'g')
WHERE bn LIKE '%PBA';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'ACCORD\s.*', '', 'g')
WHERE bn LIKE '% ACCORD%';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'ROTEXM', 'ROTEXMEDICA', 'g')
WHERE bn LIKE '%ROTEXM%';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'LICH', 'LICHTENSTEIN', 'g')
WHERE bn LIKE '% LICH'
	OR bn LIKE '% LICH %';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'WINTHR', 'WINTHROP', 'g')
WHERE bn LIKE '%WINTHR'
	OR bn LIKE '%WINTHR %';

--same with BN
UPDATE grr_bn
SET bn = 'ABILIFY MAINTENA'
WHERE bn LIKE '%ABILIFY MAIN%';

UPDATE grr_bn
SET bn = 'INFANRIX'
WHERE bn ~ '^INFA';

UPDATE grr_bn
SET bn = 'MYDOCALM'
WHERE bn LIKE '%MYDOCALM%';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'SPIRONOL.', 'SPIRONOLACTONE ', 'g')
WHERE bn LIKE '%SPIRONOL.%';

UPDATE grr_bn
SET bn = 'OVYSMEN'
WHERE bn LIKE '%OVYSM%';

UPDATE grr_bn
SET bn = 'ORTHO-NOVUM'
WHERE bn LIKE '%ORTHO-N%';

UPDATE grr_bn
SET bn = 'CYKLOKAPRON'
WHERE bn ~ '^CYKLOK';

UPDATE grr_bn
SET bn = 'ZADITEN'
WHERE bn LIKE '%ZADITEN%';

UPDATE grr_bn
SET bn = 'VOLTAREN'
WHERE bn ~ '%VOLTAREN%';

UPDATE grr_bn
SET bn = 'ALLEVYN'
WHERE bn LIKE '%ALLEVY%';

UPDATE grr_bn
SET bn = 'OTRIVEN'
WHERE bn LIKE '%OTRIVEN%'
	AND bn != 'OTRIVEN DUO';

UPDATE grr_bn
SET bn = 'SEEBRI'
WHERE bn LIKE '%SEEBRI%';

UPDATE grr_bn
SET bn = 'DIDRONEL'
WHERE bn LIKE '%DIDRONEL%';

UPDATE grr_bn
SET bn = 'ISCADOR'
WHERE bn LIKE '%ISCADOR%';

UPDATE grr_bn
SET bn = 'NOVIRELL'
WHERE bn LIKE '%NOVIRELL%';

UPDATE grr_bn
SET bn = 'QUINALICH'
WHERE bn LIKE '%QUINALICH%';

UPDATE grr_bn
SET bn = 'TENSOBON'
WHERE bn LIKE '%TENSOBON%';

UPDATE grr_bn
SET bn = 'PRESOMEN'
WHERE bn LIKE '%PRESOMEN%';

UPDATE grr_bn
SET bn = 'BLOPRESID'
WHERE bn LIKE '%BLOPRESID%';

UPDATE grr_bn
SET bn = 'NEO STEDIRIL'
WHERE bn LIKE '%NEO STEDIRIL%';

UPDATE grr_bn
SET bn = 'TETESEPT'
WHERE bn LIKE '%TETESEPT%';

UPDATE grr_bn
SET bn = 'ALKA SELTZER'
WHERE bn LIKE '%ALKA SELTZER%';

UPDATE grr_bn
SET bn = 'BISOPROLOL VITABALANS'
WHERE bn LIKE '%BISOPROLOL VITABALANS%';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, '(\.)?\sCOMP\.', ' ', 'g')
WHERE bn ~ '(\sCOMP$)|(\.COMP$)|COMP\.|RATIOPHARMCOMP';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, ' COMP', '', 'g')
WHERE bn LIKE '% COMP'
	OR bn LIKE '% COMP %';

UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'ML/$|CB/$|KL/$|\(SA/|\(OR/|\.IV|INHALAT|INHAL| INH|VAGINALE|SAFT|TONIKUM|TROPF| SALB| NO&| (NO$)', '', 'g');

UPDATE grr_bn
SET bn = TRIM(REGEXP_REPLACE(bn, 'TABL$|SCHMERZTABL| KAPS|SCHM.TABL.| SCHM.$|TABLETTEN|BET\.M|RETARDTABL|\sTABL.', '', 'g'));

UPDATE grr_bn
SET bn = TRIM(REGEXP_REPLACE(bn, '\(.*', '', 'g'));

UPDATE grr_bn
SET bn = TRIM(REGEXP_REPLACE(bn, '(\d+\.)?\d+\%.*', '', 'g'))
WHERE bn ~ '\d+\%';

--delete 5%;
UPDATE grr_bn
SET bn = REGEXP_REPLACE(bn, 'SUP|(\d$)| PW|( DRAG.*)|( ORAL.*)', '', 'g')
WHERE bn NOT LIKE 'SUP%';

UPDATE GRR_BN
SET BN = 'DEXAMONOZON'
WHERE BN = 'DEXAMONOZON SUPP.';

UPDATE grr_bn
SET BN = REGEXP_REPLACE(bn, '-', ' ', 'g');

UPDATE grr_bn
SET bn = TRIM(REGEXP_REPLACE(bn, '  ', ' ', 'g'));

DROP TABLE IF EXISTS grr_bn_2;
CREATE TABLE grr_bn_2 AS
	WITH lng AS (
			SELECT fcc,
				MAX(LENGTH(bn)) AS lng
			FROM grr_bn
			GROUP BY fcc
			)
SELECT DISTINCT b.*
FROM grr_bn b
JOIN lng ON b.fcc = lng.fcc
	AND lng.lng = (LENGTH(b.bn));

DELETE
FROM grr_bn_2
WHERE INITCAP(bn) IN (
		'Pantoprazol',
		'Parenteral',
		'Nifedipin',
		'Neostigmin',
		'Naloxon',
		'Metoclopramid',
		'Metronidazol',
		'Miconazol',
		'Methotrexat',
		'Mesalazin',
		'Loperamid',
		'Lidocain',
		'Laxative',
		'Hydrocortison',
		'Histamin',
		'Ginko',
		'Ephedrin',
		'Doxycyclin',
		'Dimenhydrinat',
		'Diclofen',
		'Cyclopentolat',
		'Complex',
		'Benzocain',
		'Atropin',
		'Amiodaron',
		'Aconit',
		'Pamidronat',
		'Pilocarpin',
		'Prednisolon',
		'Progesteron',
		'Promethazin',
		'Cetirizin',
		'Felodipin',
		'Glibenclamid',
		'Indapamid',
		'Cefuroxim',
		'Rabies',
		'Spironolacton',
		'Symphytum',
		'Sandoz Schmerzgel',
		'Testosteron',
		'Theophyllin',
		'Urtica',
		'Valproat',
		'Vincristin',
		'Vitis',
		'Omeprazol',
		'Paroxetin',
		'Ranitidin'
		);

DELETE
FROM grr_bn_2
WHERE INITCAP(bn) IN (
		'Oestradiol',
		'Nalorphin',
		'Oestriol',
		'Cholesterin',
		'Cephazolin',
		'Aspen',
		'Aristo',
		'Bausch & Lomb',
		'Lily'
		);

DELETE
FROM grr_bn_2
WHERE bn ~ 'BLAEHUNGSTABLETTEN|KOMPLEX|GALGANTTABL|PREDNISOL\.|LOESG|ALBUMIN|BABY|ANDERE|--|/|ACID.*\.|SCHLAFTABL\.|VIT.B12\+|RINGER|M8V|F4T|\. DHU|TABACUM|A8X|CA2|GALLE|BT5|KOCHSALZ|V3P|D4F|AC9|B9G|BC4|GALLE-DR\.|\+|SCHUESSL BIOCHEMIE|^BIO\.|BLAS\.|SILIC\.|KPK|CHAMOMILLA|ELEKTROLYT|AQUA|KNOBLAUCH|FOLSAEURE|VITAMINE|/|AQUA A|LOESUNG'
	AND NOT bn ~ 'PHARM|ABTEI|HEEL|INJEE|HEUMANN|MERCK|BLUESFISH|WESTERN|PHARMA|ZENTIVA|PFIZER|PHARMA|MEDE|MEDAC|FAIR|HAMELN|ACCORD|RATIO|AXCOUNT|STADA|SANDOZ|SOLVAY|GLENMARK|APOTHEKE|HEXAL|TEVA|AUROBINDO|ORION|SYXYL|NEURAX|KOHNE|ACTAVIS|CLARIS|NOVUM|ABZ|AXCOUNT|MYLAN|ARISTO|KABI|BENE|HORMOSAN|ZENTIVA|PUREN|BIOMO|ACIS|RATIOPH|SYNOMED|ALPHA|ROTEXMEDICA|BERCO|DURA|DAGO|GASTREU|FORTE|VITAL|VERLA|ONKOVIS|ONCOTRADE|NEOCORP';

DELETE
FROM grr_bn_2
WHERE bn ~ 'TROPFEN|TETANUS|FAKTOR| KAPSELN|RNV|COMPOSITUM| SC | CARBON|COMPLEX|SLR| PUR|OLEUM|FERRUM|ROSMARIN|SYND|NATRIUM|BIOCHEMIE|URTICA|VALERIANA|DULCAMARA|SALZ| LH| DHU|HERBA|SULFUR|TINKTUR|PRUNUS|ZEMENT|KALIUM|ALUMIN|SOLUM| AKH| A1X| SAL| DHU|B\d|FLOR| ANTIDOT|ˆARNICA|ˆKAMILLEN'
	AND NOT bn ~ 'PHARM|ABTEI|HEEL|INJEE|HEUMANN|MERCK|BLUESFISH|WESTERN|PHARMA|ZENTIVA|PFIZER|PHARMA|MEDE|MEDAC|FAIR|HAMELN|ACCORD|RATIO|AXCOUNT|STADA|SANDOZ|SOLVAY|GLENMARK|APOTHEKE|HEXAL|TEVA|AUROBINDO|ORION|SYXYL|NEURAX|KOHNE|ACTAVIS|CLARIS|NOVUM|ABZ|AXCOUNT|MYLAN|ARISTO|KABI|BENE|HORMOSAN|ZENTIVA|PUREN|BIOMO|ACIS|RATIOPH|SYNOMED|ALPHA|ROTEXMEDICA|BERCO|DURA|DAGO|GASTREU|FORTE|VITAL|VERLA|ONKOVIS|ONCOTRADE|NEOCORP|( AWD$)';

DELETE
FROM grr_bn_2
WHERE BN ~ 'SILICEA|STANNUM|SAURE|CAUSTICUM|CASCARA|FOLINATE|FOLATE|COLOCYNTHIS|CUPRUM|CALCIUM|SODIUM|BLUETEN|ACETYL|CHLORID|ACIDIDUM|ACIDUM|LIDOCAIN|ESTRADIOL|NACHTKERZENOE|NEOSTIGMIN|METALLICUM|SPAGYRISCHE|ARCANA|SULFURICUM|BERBERIS|BALDRIAN|TILIDIN| VIT '
	AND NOT bn ~ 'PHARM|ABTEI|HEEL|INJEE|HEUMANN|MERCK|BLUESFISH|WESTERN|PHARMA|ZENTIVA|PFIZER|PHARMA|MEDE|MEDAC|FAIR|HAMELN|ACCORD|RATIO|AXCOUNT|STADA|SANDOZ|SOLVAY|GLENMARK|APOTHEKE|HEXAL|TEVA|AUROBINDO|ORION|SYXYL|NEURAX|KOHNE|ACTAVIS|CLARIS|NOVUM|ABZ|AXCOUNT|MYLAN|ARISTO|KABI|BENE|HORMOSAN|ZENTIVA|PUREN|BIOMO|ACIS|RATIOPH|SYNOMED|ALPHA|ROTEXMEDICA|BERCO|DURA|DAGO|GASTREU|FORTE|VITAL|VERLA|ONKOVIS|ONCOTRADE|NEOCORP';

DELETE
FROM grr_bn_2
WHERE old_name ~ ' DIM | LH| DHU | SOH|LHRH'
	AND NOT bn ~ 'CO TRIMOXAZOL|APO GO|EFEU';

DELETE
FROM grr_bn_2
WHERE bn LIKE '%)%'
	OR bn LIKE '% SAND';

DELETE
FROM grr_bn
WHERE bn IN (
		'GAMMA',
		'ADENOSIN',
		'AGNUS',
		'MORPHIN',
		'MYCOPHENOLATMOFETIL',
		'MYRTILLUSNASENSPRAY',
		'NASENOEL',
		'TETRACAIN',
		'TETRACYCLIN',
		'TILIDIN',
		'TOLTERODIN',
		'ZOPICLON',
		'ZONISAMID',
		'ZINCUM',
		'TRIMIPRAMIN',
		'TOPIRAMAT',
		'TOLTERODIN',
		'TILIDIN',
		'TICLOPIDIN',
		'TERBINAFIN',
		'SULPIRID',
		'SULFUR JODATUM ARC',
		'SULFUR DERMATOPLEX',
		'SPIRONOTHIAZID',
		'SPIRONOLACTON IUN>',
		'SPIRONOLACTON AWD',
		'RISPERIDON',
		'RHEUMA LOGES N',
		'RABEPRAZOL',
		'QUETIAPIN',
		'PETROSELINUM',
		'PENTOXIFYLLIN',
		'PASSIFLORA',
		'PANKREATIN',
		'PACLITAXEL GRY BBF',
		'PACLITAXEL GRY',
		'OXCARBAZEPIN',
		'OXAZEPAM TAD',
		'OXAZEPAM K KPH',
		'OXAZEPAM AL',
		'MYCOPHENOLATMOFETIL',
		'MORPHIN',
		'MOCLOBEMID',
		'LEVISTICUM',
		'LEFLUNOMID',
		'LEDUM PALUSTRE S3G',
		'LEDUM PALUSTRE S',
		'LEDUM ARCANA',
		'LEDUM AMP',
		'LEDUM',
		'LANSOPRAZOL',
		'LAMOTRIGIN AWD',
		'LAMOTRIGIN',
		'LAMIVUDIN',
		'L TYROSINE',
		'L TYROSIN',
		'L TRYPTOPHAN',
		'L THYROXIN NA',
		'L THYROXIN JOD BET',
		'L THYROSIN',
		'L THREONIN',
		'L TAURIN',
		'L SERIN',
		'L PROLIN',
		'L PHENYLALANIN VBN',
		'L PHENYLALANIN NUT',
		'L PHENYLALANIN',
		'L ORNITHIN',
		'L METHIONIN',
		'L LYSINE',
		'L LYSIN HCL',
		'L LYSIN',
		'L LEUCIN',
		'L ISOLEUCIN',
		'L INSULIN',
		'L HISTIDIN',
		'L GLUTATHION',
		'L GLUTAMINE',
		'HEPARIN GEL',
		'HEPARIN AL',
		'HAEMONINE',
		'GLIMEPIRID',
		'GINKGO',
		'GELONIDA',
		'FUROSEMID',
		'FLUCONAZOL',
		'CACTUS ARCANA',
		'CACTUS',
		'BROMOCRIPTIN',
		'BISOPROLOL KSK',
		'BICALUTAMID',
		'BEZAFIBRAT',
		'BETAMETHASON',
		'BENAZEPRIL HCT KWZ',
		'BENAZEPRIL HCT AWD',
		'BARIUM MURIATICUM ARC',
		'BALDRIAN',
		'B INSULIN S',
		'B INSULIN',
		'B 12 L 9',
		'B 12 AS',
		'AURUM VALERIANA',
		'AURUM SULFURATUM ARC',
		'AURUM RC',
		'AURUM PHOSPHORICUM ARC',
		'AURUM MURIATICUM NATRONATUM GUD',
		'AURUM MURIATICUM GUD',
		'AURUM JODATUM PENTARKAN',
		'AURUM JODATUM ARCANA',
		'AURUM',
		'AUREOMYCIN N',
		'AUREOMYCIN CA',
		'AUREOMYCIN',
		'ATROPINUM',
		'ATRACURIUM CRM',
		'ANASTROZOL',
		'AMPICILLIN USP CKC',
		'AMPICILLIN UND SULBACTAM IBISQUS',
		'AMPICILLIN PLUS SULBACTAM EBERTH',
		'AMPICILLIN NJ',
		'AMOROLFIN',
		'AMLODIPIN',
		'AMITRIPTYLIN',
		'AMANTADIN',
		'AMANTA SULFAT',
		'AMANTA HCL',
		'AMANTA',
		'ALOE VERA MEP',
		'ALOE VERA I',
		'ALOE VERA AMS',
		'ALOE VERA A',
		'ALOE SOCOTRINA GUD',
		'ALOE GRANULAT SCHUCK',
		'ALENDRONSAEURE AL',
		'ALENDRONSAEURE ACCORD',
		'ACEROLA CHIPS',
		'MULTIVITAMIN',
		'ACEROLA C'
		);

DELETE
FROM grr_bn_2
WHERE LENGTH(bn) < 4
	OR bn IS NULL;

DELETE
FROM grr_bn_2
WHERE LENGTH(bn) = 4
	AND substring(bn, '\w') != substring(old_name, '\w');

DELETE
FROM grr_bn_2
WHERE LENGTH(bn) < 6
	AND bn LIKE '% %'
	AND bn NOT IN (
		'OME Q',
		'O PUR',
		'IUP T',
		'GO ON',
		'AZA Q'
		);

--deleting all sorts of ingredients
DELETE
FROM grr_bn_2
WHERE UPPER(bn) IN (
		SELECT UPPER(molecule)
		FROM grr_new_3
		);

DELETE
FROM grr_bn_2
WHERE UPPER(bn) IN (
		SELECT UPPER(SUBSTANCE)
		FROM source_data_1
		);

DELETE
FROM grr_bn_2
WHERE UPPER(bn) IN (
		SELECT UPPER(concept_name)
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

DELETE
FROM grr_bn_2
WHERE bn IN (
		SELECT BN
		FROM bn_to_del
		);

--deleting repeating BN
DELETE
FROM grr_bn_2 g
WHERE EXISTS (
		SELECT 1
		FROM grr_bn_2 g_int
		WHERE g_int.fcc = g.fcc
			AND g_int.ctid > g.ctid
		);

--manufacturers
DROP TABLE IF EXISTS grr_manuf_0;
CREATE TABLE grr_manuf_0 AS
SELECT DISTINCT a.fcc,
	EFF_FR_DT,
	EFF_TO_DT,
	PRI_ORG_CD,
	TRIM(REGEXP_REPLACE(PRI_ORG_LNG_NM, '>>', '', 'g')) AS PRI_ORG_LNG_NM,
	CUR_REC_IND
FROM GRR_PACK a
JOIN GRR_PACK_CLAS b ON a.pack_id = b.pack_id
JOIN grr_new_3 c ON c.fcc = a.fcc
WHERE CUR_REC_IND = '1';

--inserting suppliers from source data
INSERT INTO grr_manuf_0 (
	fcc,
	PRI_ORG_LNG_NM
	)
SELECT DISTINCT fcc,
	manufacturer_name
FROM source_data_1;

DROP TABLE IF EXISTS grr_manuf;
CREATE TABLE grr_manuf AS
SELECT DISTINCT fcc,
	REGEXP_REPLACE(PRI_ORG_LNG_NM, '\s\s+>>', '', 'g') AS PRI_ORG_LNG_NM
FROM grr_manuf_0;

--take
UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'TAKEDA'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%TAKEDA%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'BAYER'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%BAYER%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'ABBOTT'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%ABBOTT%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'PFIZER'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%PFIZER%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'BOEHRINGER'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%BEHR%'
			OR PRI_ORG_LNG_NM LIKE '%BOEH%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'MERCK DURA'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%MERCK%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'RATIOPHARM'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%RATIO%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'MERCK DURA'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%MERCK%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'GEDEON RICHTER'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%RICHT%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'SANOFI'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%SANOFI%'
			OR PRI_ORG_LNG_NM LIKE '%SYNTHELABO%'
			OR PRI_ORG_LNG_NM LIKE '%AVENTIS%'
			OR PRI_ORG_LNG_NM LIKE '%ZENTIVA%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'NOVARTIS'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%NOVART%'
			OR PRI_ORG_LNG_NM LIKE '%SANDOZ%'
			OR PRI_ORG_LNG_NM LIKE '%HEXAL%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'ACTAVIS'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%ACTAVIS%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'ASTRA ZENECA'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%ASTRA%'
			OR PRI_ORG_LNG_NM LIKE '%ZENECA%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'GLAXOSMITHKLINE'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%SMITHKL%'
			OR PRI_ORG_LNG_NM LIKE '%GLAXO%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'WESTEN PHARMA'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%WESTEN%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'ASTELLAS'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%ASTELLAS%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'ASTA PHARMA'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%ASTA%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'ABZ PHARMA'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%ABZ%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'HORMOSAN PHARMA'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%HORMOSAN%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'LUNDBECK'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%LUNDBECK%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'EU RHO ARZNEI'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%EU RHO%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'B.BRAUN'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%.BRAUN%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'BIOGLAN'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%BIOGLAN%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'MEPHA-PHARMA'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%MEPHA%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'PIERRE FABRE'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%PIERRE%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'FOURNIER PHARMA'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%FOURNIER%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'JOHNSON&JOHNSON'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%JOHNSON%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'AASTON HEALTH'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%AASTON%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'HAEMATO PHARM'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%HAEMATO PHARM%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'STRATHMANN'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%STRATHMANN%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = 'ACA MUELLER'
WHERE fcc IN (
		SELECT fcc
		FROM grr_manuf
		WHERE PRI_ORG_LNG_NM LIKE '%MUELLER%'
		);

UPDATE grr_manuf
SET PRI_ORG_LNG_NM = replace(PRI_ORG_LNG_NM, '>', '');

--ingredient
DELETE
FROM grr_manuf
WHERE PRI_ORG_LNG_NM IN (
		'OLIBANUM',
		'EIGENHERSTELLUNG'
		);

DELETE
FROM grr_manuf
WHERE LOWER(PRI_ORG_LNG_NM) IN (
		SELECT LOWER(concept_name)
		FROM concept
		WHERE concept_class_id = 'Ingredient'
		);

--delete strange manufacturers
DELETE
FROM grr_manuf
WHERE PRI_ORG_LNG_NM LIKE '%/%'
	OR PRI_ORG_LNG_NM LIKE '%.%'
	OR PRI_ORG_LNG_NM LIKE '%APOTHEKE%'
	OR PRI_ORG_LNG_NM LIKE '%IMPORTE AUS%';

DELETE
FROM grr_manuf
WHERE LENGTH(PRI_ORG_LNG_NM) < 4;

--deleting BNs that looks like suppliers
DELETE
FROM grr_bn_2
WHERE UPPER(bn) IN (
		SELECT UPPER(PRI_ORG_LNG_NM)
		FROM grr_manuf
		);

--dose form
DROP TABLE IF EXISTS grr_form;
CREATE TABLE grr_form AS
SELECT fcc,
	INTL_PACK_FORM_DESC,
	NFC_123_CD
FROM grr_new_3
UNION
SELECT fcc,
	PRODUCT_FORM_NAME,
	CASE 
		WHEN NFC = 'ZZZ'
			THEN NULL
		ELSE nfc
		END
FROM source_data_1;

DO $_$
BEGIN
	UPDATE grr_form
	SET NFC_123_CD = 'BAA'
	WHERE INTL_PACK_FORM_DESC ~ '(CT TAB)|(EC TAB)|(FC TAB)|(RT TAB)';

	UPDATE grr_form
	SET NFC_123_CD = 'BCA'
	WHERE INTL_PACK_FORM_DESC ~ '(RT CAP)|(EC CAP)';

	UPDATE grr_form
	SET NFC_123_CD = 'ACA'
	WHERE INTL_PACK_FORM_DESC = 'CAP';

	UPDATE grr_form
	SET NFC_123_CD = 'AAA'
	WHERE INTL_PACK_FORM_DESC = '%LOZ';

	UPDATE grr_form
	SET NFC_123_CD = 'DEP'
	WHERE INTL_PACK_FORM_DESC IN (
			' ORL UD PWD',
			' ORL SLB PWD',
			' ORL PWD'
			);

	UPDATE grr_form
	SET NFC_123_CD = 'DGB'
	WHERE INTL_PACK_FORM_DESC IN (
			' ORL DRP',
			' ORAL LIQ',
			' ORL MD LIQ',
			' ORL RT LIQ',
			' ORL UD LIQ',
			' ORL SYR',
			' ORL SUSP',
			' ORL SPIRIT'
			);

	UPDATE grr_form
	SET NFC_123_CD = 'TAA'
	WHERE INTL_PACK_FORM_DESC IN (
			'VAG COMB TAB',
			'VAG TAB'
			);

	UPDATE grr_form
	SET NFC_123_CD = 'TGA'
	WHERE INTL_PACK_FORM_DESC IN (
			'VAG UD LIQ',
			'VAG LIQ',
			'VAG IUD'
			);

	UPDATE grr_form
	SET NFC_123_CD = 'MSA'
	WHERE INTL_PACK_FORM_DESC IN (
			'TOP OINT',
			'TOP OIL'
			);

	UPDATE grr_form
	SET NFC_123_CD = 'MGW'
	WHERE INTL_PACK_FORM_DESC = 'TOP LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'FMA'
	WHERE INTL_PACK_FORM_DESC LIKE '%AMP%';

	UPDATE grr_form
	SET NFC_123_CD = 'MWA'
	WHERE INTL_PACK_FORM_DESC LIKE '%PLAST%';

	UPDATE grr_form
	SET NFC_123_CD = 'FNA'
	WHERE INTL_PACK_FORM_DESC LIKE '%PF %SG%'
		OR INTL_PACK_FORM_DESC LIKE '%PF %PEN%';

	UPDATE grr_form
	SET NFC_123_CD = 'FPA'
	WHERE INTL_PACK_FORM_DESC LIKE '%VIAL%';

	UPDATE grr_form
	SET NFC_123_CD = 'FQE'
	WHERE INTL_PACK_FORM_DESC LIKE '%INF BAG%';

	UPDATE grr_form
	SET NFC_123_CD = 'RHP'
	WHERE INTL_PACK_FORM_DESC LIKE '%LUNG%';

	UPDATE grr_form
	SET NFC_123_CD = 'MHA'
	WHERE INTL_PACK_FORM_DESC LIKE '%SPRAY%';

	UPDATE grr_form
	SET NFC_123_CD = 'MJY'
	WHERE INTL_PACK_FORM_DESC = 'BAD';

	UPDATE grr_form
	SET NFC_123_CD = 'MJH'
	WHERE INTL_PACK_FORM_DESC = 'BAD OEL';

	UPDATE grr_form
	SET NFC_123_CD = 'MJY'
	WHERE INTL_PACK_FORM_DESC = 'BATH';

	UPDATE grr_form
	SET NFC_123_CD = 'MJL'
	WHERE INTL_PACK_FORM_DESC = 'BATH EMUL';

	UPDATE grr_form
	SET NFC_123_CD = 'MJT'
	WHERE INTL_PACK_FORM_DESC = 'BATH FOAM';

	UPDATE grr_form
	SET NFC_123_CD = 'MJH'
	WHERE INTL_PACK_FORM_DESC = 'BATH OIL';

	UPDATE grr_form
	SET NFC_123_CD = 'MJY'
	WHERE INTL_PACK_FORM_DESC = 'BATH OTH';

	UPDATE grr_form
	SET NFC_123_CD = 'MJB'
	WHERE INTL_PACK_FORM_DESC = 'BATH SOLID';

	UPDATE grr_form
	SET NFC_123_CD = 'ADQ'
	WHERE INTL_PACK_FORM_DESC = 'BISCUIT';

	UPDATE grr_form
	SET NFC_123_CD = 'ACF'
	WHERE INTL_PACK_FORM_DESC = 'BITE CAP';

	UPDATE grr_form
	SET NFC_123_CD = 'MYP'
	WHERE INTL_PACK_FORM_DESC = 'BONE CMT W SUB';

	UPDATE grr_form
	SET NFC_123_CD = 'AAE'
	WHERE INTL_PACK_FORM_DESC = 'BUC TAB';

	UPDATE grr_form
	SET NFC_123_CD = 'FRA'
	WHERE INTL_PACK_FORM_DESC = 'CART';

	UPDATE grr_form
	SET NFC_123_CD = 'ACG'
	WHERE INTL_PACK_FORM_DESC = 'CHEW CAP';

	UPDATE grr_form
	SET NFC_123_CD = 'AAG'
	WHERE INTL_PACK_FORM_DESC = 'CHEW TAB';

	UPDATE grr_form
	SET NFC_123_CD = 'ACZ'
	WHERE INTL_PACK_FORM_DESC = 'COMB CAP';

	UPDATE grr_form
	SET NFC_123_CD = 'ADZ'
	WHERE INTL_PACK_FORM_DESC = 'COMB SPC SLD';

	UPDATE grr_form
	SET NFC_123_CD = 'AAZ'
	WHERE INTL_PACK_FORM_DESC = 'COMB TAB';

	UPDATE grr_form
	SET NFC_123_CD = 'FQD'
	WHERE INTL_PACK_FORM_DESC = 'DRY INF BTL';

	UPDATE grr_form
	SET NFC_123_CD = 'MEC'
	WHERE INTL_PACK_FORM_DESC = 'DUST PWD';

	UPDATE grr_form
	SET NFC_123_CD = 'AAH'
	WHERE INTL_PACK_FORM_DESC = 'EFF TAB';

	UPDATE grr_form
	SET NFC_123_CD = 'DGA'
	WHERE INTL_PACK_FORM_DESC = 'FLUESSIG';

	UPDATE grr_form
	SET NFC_123_CD = 'MYT'
	WHERE INTL_PACK_FORM_DESC = 'FOAM';

	UPDATE grr_form
	SET NFC_123_CD = 'DGR'
	WHERE INTL_PACK_FORM_DESC = 'FRANZBR.WEIN';

	UPDATE grr_form
	SET NFC_123_CD = 'MWB'
	WHERE INTL_PACK_FORM_DESC = 'GAUZE W SUB';

	UPDATE grr_form
	SET NFC_123_CD = 'MZK'
	WHERE INTL_PACK_FORM_DESC = 'GEL DRESS';

	UPDATE grr_form
	SET NFC_123_CD = 'ADR'
	WHERE INTL_PACK_FORM_DESC = 'GLOBULE';

	UPDATE grr_form
	SET NFC_123_CD = 'AEB'
	WHERE INTL_PACK_FORM_DESC = 'GRAN';

	UPDATE grr_form
	SET NFC_123_CD = 'KDF'
	WHERE INTL_PACK_FORM_DESC = 'GUM';

	UPDATE grr_form
	SET NFC_123_CD = 'GYV'
	WHERE INTL_PACK_FORM_DESC = 'IMPLANT';

	UPDATE grr_form
	SET NFC_123_CD = 'FQC'
	WHERE INTL_PACK_FORM_DESC = 'INF BTL';

	UPDATE grr_form
	SET NFC_123_CD = 'FQF'
	WHERE INTL_PACK_FORM_DESC = 'INF CART';

	UPDATE grr_form
	SET NFC_123_CD = 'RCT'
	WHERE INTL_PACK_FORM_DESC = 'INH CAP';

	UPDATE grr_form
	SET NFC_123_CD = 'FNH'
	WHERE INTL_PACK_FORM_DESC = 'INJEKTOR NA';

	UPDATE grr_form
	SET NFC_123_CD = 'DKJ'
	WHERE INTL_PACK_FORM_DESC = 'INSTANT TEA';

	UPDATE grr_form
	SET NFC_123_CD = 'MQS'
	WHERE INTL_PACK_FORM_DESC = 'IRRIGAT FLUID';

	UPDATE grr_form
	SET NFC_123_CD = 'ACA'
	WHERE INTL_PACK_FORM_DESC = 'KAPS';

	UPDATE grr_form
	SET NFC_123_CD = 'AAJ'
	WHERE INTL_PACK_FORM_DESC = 'LAYER TAB';

	UPDATE grr_form
	SET NFC_123_CD = 'MGW'
	WHERE INTL_PACK_FORM_DESC = 'LIQ SOAP';

	UPDATE grr_form
	SET NFC_123_CD = 'DGA'
	WHERE INTL_PACK_FORM_DESC = 'LIQU';

	UPDATE grr_form
	SET NFC_123_CD = 'DGA'
	WHERE INTL_PACK_FORM_DESC = 'LOESG N';

	UPDATE grr_form
	SET NFC_123_CD = 'DGA'
	WHERE INTL_PACK_FORM_DESC = 'LOESUNG';

	UPDATE grr_form
	SET NFC_123_CD = 'ADE'
	WHERE INTL_PACK_FORM_DESC = 'LOZ';

	UPDATE grr_form
	SET NFC_123_CD = 'TYQ'
	WHERE INTL_PACK_FORM_DESC = 'MCH PES W SUB';

	UPDATE grr_form
	SET NFC_123_CD = 'DKA'
	WHERE INTL_PACK_FORM_DESC = 'MED TEA';

	UPDATE grr_form
	SET NFC_123_CD = 'QGC'
	WHERE INTL_PACK_FORM_DESC = 'NH AERO';

	UPDATE grr_form
	SET NFC_123_CD = 'DGA'
	WHERE INTL_PACK_FORM_DESC = 'NH LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'DEK'
	WHERE INTL_PACK_FORM_DESC = 'NH SLB PWD';

	UPDATE grr_form
	SET NFC_123_CD = 'AAH'
	WHERE INTL_PACK_FORM_DESC = 'NH SLB TAB';

	UPDATE grr_form
	SET NFC_123_CD = 'DEK'
	WHERE INTL_PACK_FORM_DESC = 'NH SLD SUB';

	UPDATE grr_form
	SET NFC_123_CD = 'FPA'
	WHERE INTL_PACK_FORM_DESC = 'NH TST X STK';

	UPDATE grr_form
	SET NFC_123_CD = 'MGN'
	WHERE INTL_PACK_FORM_DESC = 'NH UD LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'RHQ'
	WHERE INTL_PACK_FORM_DESC = 'NON CFC MDI';

	UPDATE grr_form
	SET NFC_123_CD = 'IGP'
	WHERE INTL_PACK_FORM_DESC = 'NS MD LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'IGN'
	WHERE INTL_PACK_FORM_DESC = 'NS UD LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'QTA'
	WHERE INTL_PACK_FORM_DESC = 'NT CRM';

	UPDATE grr_form
	SET NFC_123_CD = 'QGB'
	WHERE INTL_PACK_FORM_DESC = 'NT DRP';

	UPDATE grr_form
	SET NFC_123_CD = 'QGP'
	WHERE INTL_PACK_FORM_DESC = 'NT MD LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'QGH'
	WHERE INTL_PACK_FORM_DESC = 'NT OIL';

	UPDATE grr_form
	SET NFC_123_CD = 'QYM'
	WHERE INTL_PACK_FORM_DESC = 'NT STICK';

	UPDATE grr_form
	SET NFC_123_CD = 'QGN'
	WHERE INTL_PACK_FORM_DESC = 'NT UD LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'NDN'
	WHERE INTL_PACK_FORM_DESC = 'OCULAR SYS';

	UPDATE grr_form
	SET NFC_123_CD = 'MGH'
	WHERE INTL_PACK_FORM_DESC = 'OEL';

	UPDATE grr_form
	SET NFC_123_CD = 'PGB'
	WHERE INTL_PACK_FORM_DESC = 'OHRENTROPFEN';

	UPDATE grr_form
	SET NFC_123_CD = 'NGZ'
	WHERE INTL_PACK_FORM_DESC = 'OPH COMB LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'NTA'
	WHERE INTL_PACK_FORM_DESC = 'OPH CRM';

	UPDATE grr_form
	SET NFC_123_CD = 'NGB'
	WHERE INTL_PACK_FORM_DESC = 'OPH DRP';

	UPDATE grr_form
	SET NFC_123_CD = 'NVB'
	WHERE INTL_PACK_FORM_DESC = 'OPH GEL DRP';

	UPDATE grr_form
	SET NFC_123_CD = 'NSA'
	WHERE INTL_PACK_FORM_DESC = 'OPH OINT';

	UPDATE grr_form
	SET NFC_123_CD = 'MZY'
	WHERE INTL_PACK_FORM_DESC = 'OPH OTH M.AID';

	UPDATE grr_form
	SET NFC_123_CD = 'NGQ'
	WHERE INTL_PACK_FORM_DESC = 'OPH PRSV-F MU-D LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'NGA'
	WHERE INTL_PACK_FORM_DESC = 'OPH SOL';

	UPDATE grr_form
	SET NFC_123_CD = 'NGK'
	WHERE INTL_PACK_FORM_DESC = 'OPH SUSP';

	UPDATE grr_form
	SET NFC_123_CD = 'NGN'
	WHERE INTL_PACK_FORM_DESC = 'OPH UD LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'AAB'
	WHERE INTL_PACK_FORM_DESC = ' ORAL SLD ODT';

	UPDATE grr_form
	SET NFC_123_CD = 'DGZ'
	WHERE INTL_PACK_FORM_DESC = ' ORL COMB LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'DGJ'
	WHERE INTL_PACK_FORM_DESC = ' ORL DRY SUSP';

	UPDATE grr_form
	SET NFC_123_CD = 'DGJ'
	WHERE INTL_PACK_FORM_DESC = ' ORL DRY SYR';

	UPDATE grr_form
	SET NFC_123_CD = 'DGL'
	WHERE INTL_PACK_FORM_DESC = ' ORL EMUL';

	UPDATE grr_form
	SET NFC_123_CD = 'AEB'
	WHERE INTL_PACK_FORM_DESC = ' ORL GRAN';

	UPDATE grr_form
	SET NFC_123_CD = 'KSA'
	WHERE INTL_PACK_FORM_DESC = ' ORL OIL';

	UPDATE grr_form
	SET NFC_123_CD = 'DDY'
	WHERE INTL_PACK_FORM_DESC = ' ORL SPC FORM';

	UPDATE grr_form
	SET NFC_123_CD = 'AEB'
	WHERE INTL_PACK_FORM_DESC = ' ORL UD GRAN';

	UPDATE grr_form
	SET NFC_123_CD = 'JGB'
	WHERE INTL_PACK_FORM_DESC = 'OS DRP';

	UPDATE grr_form
	SET NFC_123_CD = 'JVA'
	WHERE INTL_PACK_FORM_DESC = 'OS GEL';

	UPDATE grr_form
	SET NFC_123_CD = 'JFA'
	WHERE INTL_PACK_FORM_DESC = 'OS INH GAS';

	UPDATE grr_form
	SET NFC_123_CD = 'JGE'
	WHERE INTL_PACK_FORM_DESC = 'OS INH LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'JSA'
	WHERE INTL_PACK_FORM_DESC = 'OS OINT';

	UPDATE grr_form
	SET NFC_123_CD = 'JEY'
	WHERE INTL_PACK_FORM_DESC = 'OS OTH PWD';

	UPDATE grr_form
	SET NFC_123_CD = 'JWN'
	WHERE INTL_PACK_FORM_DESC = 'OS TD SYS';

	UPDATE grr_form
	SET NFC_123_CD = 'JCV'
	WHERE INTL_PACK_FORM_DESC = 'OS TOP CAP';

	UPDATE grr_form
	SET NFC_123_CD = 'JVN'
	WHERE INTL_PACK_FORM_DESC = 'OS UD GEL';

	UPDATE grr_form
	SET NFC_123_CD = 'KAE'
	WHERE INTL_PACK_FORM_DESC = 'OT BUC TAB';

	UPDATE grr_form
	SET NFC_123_CD = 'KGD'
	WHERE INTL_PACK_FORM_DESC = 'OT COLLODION';

	UPDATE grr_form
	SET NFC_123_CD = 'KGB'
	WHERE INTL_PACK_FORM_DESC = 'OT DRP';

	UPDATE grr_form
	SET NFC_123_CD = 'KVA'
	WHERE INTL_PACK_FORM_DESC = 'OT GEL';

	UPDATE grr_form
	SET NFC_123_CD = 'KGD'
	WHERE INTL_PACK_FORM_DESC = 'OT LACQUER';

	UPDATE grr_form
	SET NFC_123_CD = 'KGA'
	WHERE INTL_PACK_FORM_DESC = 'OT LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'KDE'
	WHERE INTL_PACK_FORM_DESC = 'OT LOZ';

	UPDATE grr_form
	SET NFC_123_CD = 'KSA'
	WHERE INTL_PACK_FORM_DESC = 'OT OINT';

	UPDATE grr_form
	SET NFC_123_CD = 'KHA'
	WHERE INTL_PACK_FORM_DESC = 'OT P.AERO';

	UPDATE grr_form
	SET NFC_123_CD = 'KSB'
	WHERE INTL_PACK_FORM_DESC = 'OT PASTE';

	UPDATE grr_form
	SET NFC_123_CD = 'KEK'
	WHERE INTL_PACK_FORM_DESC = 'OT SLB PWD';

	UPDATE grr_form
	SET NFC_123_CD = 'ACA'
	WHERE INTL_PACK_FORM_DESC = 'OT SPC FORM';

	UPDATE grr_form
	SET NFC_123_CD = 'KYK'
	WHERE INTL_PACK_FORM_DESC = 'OT STYLI';

	UPDATE grr_form
	SET NFC_123_CD = 'KDG'
	WHERE INTL_PACK_FORM_DESC = 'OT SWEET';

	UPDATE grr_form
	SET NFC_123_CD = 'KVN'
	WHERE INTL_PACK_FORM_DESC = 'OT UD GEL';

	UPDATE grr_form
	SET NFC_123_CD = 'KGN'
	WHERE INTL_PACK_FORM_DESC = 'OT UD LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'ACA'
	WHERE INTL_PACK_FORM_DESC = 'OTH CAP';

	UPDATE grr_form
	SET NFC_123_CD = 'PGB'
	WHERE INTL_PACK_FORM_DESC = 'OTIC DRP';

	UPDATE grr_form
	SET NFC_123_CD = 'PSA'
	WHERE INTL_PACK_FORM_DESC = 'OTIC OINT';

	UPDATE grr_form
	SET NFC_123_CD = 'MWD'
	WHERE INTL_PACK_FORM_DESC = 'PAD W SUB';

	UPDATE grr_form
	SET NFC_123_CD = 'FNH'
	WHERE INTL_PACK_FORM_DESC = 'PARENT ORD PF AUTINJ';

	UPDATE grr_form
	SET NFC_123_CD = 'ADD'
	WHERE INTL_PACK_FORM_DESC = 'PELLET';

	UPDATE grr_form
	SET NFC_123_CD = 'AAA'
	WHERE INTL_PACK_FORM_DESC = 'PILLEN N';

	UPDATE grr_form
	SET NFC_123_CD = 'MWS'
	WHERE INTL_PACK_FORM_DESC = 'POULTICE';

	UPDATE grr_form
	SET NFC_123_CD = 'AEA'
	WHERE INTL_PACK_FORM_DESC = 'PULVER';

	UPDATE grr_form
	SET NFC_123_CD = 'MEA'
	WHERE INTL_PACK_FORM_DESC = 'PULVER T';

	UPDATE grr_form
	SET NFC_123_CD = 'HCA'
	WHERE INTL_PACK_FORM_DESC = 'RS CAP';

	UPDATE grr_form
	SET NFC_123_CD = 'HGX'
	WHERE INTL_PACK_FORM_DESC = 'RS ENEMA LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'HHP'
	WHERE INTL_PACK_FORM_DESC = 'RS MD AERO';

	UPDATE grr_form
	SET NFC_123_CD = 'HLX'
	WHERE INTL_PACK_FORM_DESC = 'RS MICRO ENEMA';

	UPDATE grr_form
	SET NFC_123_CD = 'HLA'
	WHERE INTL_PACK_FORM_DESC = 'RS SUP';

	UPDATE grr_form
	SET NFC_123_CD = 'HLA'
	WHERE INTL_PACK_FORM_DESC = 'RS SUP ADLT';

	UPDATE grr_form
	SET NFC_123_CD = 'HLA'
	WHERE INTL_PACK_FORM_DESC = 'RS SUP PAED';

	UPDATE grr_form
	SET NFC_123_CD = 'FRA'
	WHERE INTL_PACK_FORM_DESC = 'RT CART';

	UPDATE grr_form
	SET NFC_123_CD = 'ACD'
	WHERE INTL_PACK_FORM_DESC = 'RT UD PWD';

	UPDATE grr_form
	SET NFC_123_CD = 'MSA'
	WHERE INTL_PACK_FORM_DESC = 'SALBE WEISS';

	UPDATE grr_form
	SET NFC_123_CD = 'MYT'
	WHERE INTL_PACK_FORM_DESC = 'SCHAUM';

	UPDATE grr_form
	SET NFC_123_CD = 'MGT'
	WHERE INTL_PACK_FORM_DESC = 'SHAKING MIX';

	UPDATE grr_form
	SET NFC_123_CD = 'AAK'
	WHERE INTL_PACK_FORM_DESC = 'SLB TAB';

	UPDATE grr_form
	SET NFC_123_CD = 'DGF'
	WHERE INTL_PACK_FORM_DESC = 'SUBL LIQ';

	UPDATE grr_form
	SET NFC_123_CD = 'AAF'
	WHERE INTL_PACK_FORM_DESC = 'SUBL TAB';

	UPDATE grr_form
	SET NFC_123_CD = 'MSA'
	WHERE INTL_PACK_FORM_DESC = 'SUBSTANZ';

	UPDATE grr_form
	SET NFC_123_CD = 'DGK'
	WHERE INTL_PACK_FORM_DESC = 'SUSP';

	UPDATE grr_form
	SET NFC_123_CD = 'DGK'
	WHERE INTL_PACK_FORM_DESC = 'SUSP PALMIT.';

	UPDATE grr_form
	SET NFC_123_CD = 'ADG'
	WHERE INTL_PACK_FORM_DESC = 'SWEET';

	UPDATE grr_form
	SET NFC_123_CD = 'AAA'
	WHERE INTL_PACK_FORM_DESC = 'TAB';

	UPDATE grr_form
	SET NFC_123_CD = 'AAA'
	WHERE INTL_PACK_FORM_DESC = 'TABL';

	UPDATE grr_form
	SET NFC_123_CD = 'AAA'
	WHERE INTL_PACK_FORM_DESC = 'TABL VIT+MIN';

	UPDATE grr_form
	SET NFC_123_CD = 'JWN'
	WHERE INTL_PACK_FORM_DESC = 'TD PATCH';

	UPDATE grr_form
	SET NFC_123_CD = 'DKP'
	WHERE INTL_PACK_FORM_DESC = 'TEA BAG';

	UPDATE grr_form
	SET NFC_123_CD = 'DGK'
	WHERE INTL_PACK_FORM_DESC = 'TINKT';

	UPDATE grr_form
	SET NFC_123_CD = 'HLA'
	WHERE INTL_PACK_FORM_DESC = 'TMP W SUB';

	UPDATE grr_form
	SET NFC_123_CD = 'DGA'
	WHERE INTL_PACK_FORM_DESC = 'TONIKUM';

	UPDATE grr_form
	SET NFC_123_CD = 'MSZ'
	WHERE INTL_PACK_FORM_DESC = 'TOP COMB OINT';

	UPDATE grr_form
	SET NFC_123_CD = 'MHZ'
	WHERE INTL_PACK_FORM_DESC = 'TOP COMB P.AERO';

	UPDATE grr_form
	SET NFC_123_CD = 'MTA'
	WHERE INTL_PACK_FORM_DESC = 'TOP CRM';

	UPDATE grr_form
	SET NFC_123_CD = 'MGB'
	WHERE INTL_PACK_FORM_DESC = 'TOP DRP';

	UPDATE grr_form
	SET NFC_123_CD = 'MGJ'
	WHERE INTL_PACK_FORM_DESC = 'TOP DRY SUSP';

	UPDATE grr_form
	SET NFC_123_CD = 'MGL'
	WHERE INTL_PACK_FORM_DESC = 'TOP EMUL';

	UPDATE grr_form
	SET NFC_123_CD = 'MVL'
	WHERE INTL_PACK_FORM_DESC = 'TOP EMUL GEL';

	UPDATE grr_form
	SET NFC_123_CD = 'MVA'
	WHERE INTL_PACK_FORM_DESC = 'TOP GEL';

	UPDATE grr_form
	SET NFC_123_CD = 'MGS'
	WHERE INTL_PACK_FORM_DESC = 'TOP LOT';

	UPDATE grr_form
	SET NFC_123_CD = 'MHP'
	WHERE INTL_PACK_FORM_DESC = 'TOP MD AERO';

	UPDATE grr_form
	SET NFC_123_CD = 'MLX'
	WHERE INTL_PACK_FORM_DESC = 'TOP MICRO ENEMA';

	UPDATE grr_form
	SET NFC_123_CD = 'MTY'
	WHERE INTL_PACK_FORM_DESC = 'TOP OTH CRM';

	UPDATE grr_form
	SET NFC_123_CD = 'MVY'
	WHERE INTL_PACK_FORM_DESC = 'TOP OTH GEL';

	UPDATE grr_form
	SET NFC_123_CD = 'MHA'
	WHERE INTL_PACK_FORM_DESC = 'TOP P.AERO';

	UPDATE grr_form
	SET NFC_123_CD = 'MHT'
	WHERE INTL_PACK_FORM_DESC = 'TOP P.FOAM';

	UPDATE grr_form
	SET NFC_123_CD = 'MHS'
	WHERE INTL_PACK_FORM_DESC = 'TOP P.OINT';

	UPDATE grr_form
	SET NFC_123_CD = 'MHC'
	WHERE INTL_PACK_FORM_DESC = 'TOP P.PWD';

	UPDATE grr_form
	SET NFC_123_CD = 'MSB'
	WHERE INTL_PACK_FORM_DESC = 'TOP PASTE';

	UPDATE grr_form
	SET NFC_123_CD = 'MEA'
	WHERE INTL_PACK_FORM_DESC = 'TOP PWD';

	UPDATE grr_form
	SET NFC_123_CD = 'MEK'
	WHERE INTL_PACK_FORM_DESC = 'TOP SLB PWD';

	UPDATE grr_form
	SET NFC_123_CD = 'MYK'
	WHERE INTL_PACK_FORM_DESC = 'TOP STK';

	UPDATE grr_form
	SET NFC_123_CD = 'MYK'
	WHERE INTL_PACK_FORM_DESC = 'TOP STYLI';

	UPDATE grr_form
	SET NFC_123_CD = 'MLA'
	WHERE INTL_PACK_FORM_DESC = 'TOP SUP ADULT';

	UPDATE grr_form
	SET NFC_123_CD = 'MGK'
	WHERE INTL_PACK_FORM_DESC = 'TOP SUSP';

	UPDATE grr_form
	SET NFC_123_CD = 'DGB'
	WHERE INTL_PACK_FORM_DESC = 'TROPF';

	UPDATE grr_form
	SET NFC_123_CD = 'JRP'
	WHERE INTL_PACK_FORM_DESC = 'UD CART';

	UPDATE grr_form
	SET NFC_123_CD = 'AEB'
	WHERE INTL_PACK_FORM_DESC = 'UD GRAN';

	UPDATE grr_form
	SET NFC_123_CD = 'DEP'
	WHERE INTL_PACK_FORM_DESC = 'UD PWD';

	UPDATE grr_form
	SET NFC_123_CD = 'TCA'
	WHERE INTL_PACK_FORM_DESC = 'VAG CAP';

	UPDATE grr_form
	SET NFC_123_CD = 'TTZ'
	WHERE INTL_PACK_FORM_DESC = 'VAG COMB CRM';

	UPDATE grr_form
	SET NFC_123_CD = 'TLZ'
	WHERE INTL_PACK_FORM_DESC = 'VAG COMB SUP';

	UPDATE grr_form
	SET NFC_123_CD = 'TTA'
	WHERE INTL_PACK_FORM_DESC = 'VAG CRM';

	UPDATE grr_form
	SET NFC_123_CD = 'TVA'
	WHERE INTL_PACK_FORM_DESC = 'VAG FOAM';

	UPDATE grr_form
	SET NFC_123_CD = 'TVA'
	WHERE INTL_PACK_FORM_DESC = 'VAG GEL';

	UPDATE grr_form
	SET NFC_123_CD = 'TVA'
	WHERE INTL_PACK_FORM_DESC = 'VAG P.FOAM';

	UPDATE grr_form
	SET NFC_123_CD = 'TLS'
	WHERE INTL_PACK_FORM_DESC = 'VAG SUP';

	UPDATE grr_form
	SET NFC_123_CD = 'TWE'
	WHERE INTL_PACK_FORM_DESC = 'VAG TMP W SUB';

	UPDATE grr_form
	SET NFC_123_CD = 'TTN'
	WHERE INTL_PACK_FORM_DESC = 'VAG UD CRM';

	UPDATE grr_form
	SET NFC_123_CD = 'TVN'
	WHERE INTL_PACK_FORM_DESC = 'VAG UD GEL';

	UPDATE grr_form
	SET NFC_123_CD = 'MTA'
	WHERE INTL_PACK_FORM_DESC = 'VASELINE';

END $_$;

DROP TABLE IF EXISTS grr_form_2;
CREATE TABLE grr_form_2 AS
SELECT DISTINCT fcc,
	concept_code,
	concept_name,
	intl_pack_form_desc
FROM grr_form a
JOIN concept b ON nfc_123_cd = concept_code
WHERE vocabulary_id = 'NFC';

--delete grr_form_2 where concept_code like 'V%' or concept_code in ('ZZZ','MQS','JGH') and fcc in (select fcc from grr_new_3);
DELETE
FROM grr_form_2 g
WHERE EXISTS (
		SELECT 1
		FROM grr_form_2 g_int
		WHERE g_int.fcc = g.fcc
			AND g_int.ctid > g.ctid
		);

DROP TABLE IF EXISTS grr_ing;
CREATE TABLE grr_ing AS
--just created this
SELECT ingredient,
	fcc
FROM (
	SELECT DISTINCT TRIM(UNNEST(regexp_matches(t.substance, '[^\+]+', 'g'))) AS ingredient,
		fcc
	FROM source_data_1 t
	) AS s
WHERE ingredient NOT IN (
		'MULTI SUBSTANZ',
		'ENZYME (UNSPECIFIED)',
		'NASAL DECONGESTANTS',
		'ANTACIDS',
		'ELECTROLYTE SOLUTIONS',
		'ANTI-PSORIASIS',
		'TOPICAL ANALGESICS'
		);

INSERT INTO grr_ing
SELECT molecule,
	fcc
FROM grr_new_3;

--introduced parsed ingredients
DROP TABLE IF EXISTS grr_ing_2;
CREATE TABLE grr_ing_2 AS
SELECT DISTINCT fcc,
	CASE 
		WHEN ingredient = ingr
			THEN ingr_2
		ELSE ingredient
		END AS ingredient
FROM grr_ing a
LEFT JOIN ingr_parsing ON ingredient = ingr;

DROP SEQUENCE IF EXISTS new_vocab;
CREATE SEQUENCE new_vocab MINVALUE 1962397 MAXVALUE 9000000 START WITH 1962397 INCREMENT BY 1 CACHE 100;

--put OMOP||numbers
--creating table with all concepts that need to have OMOP
DROP TABLE IF EXISTS list;
CREATE TABLE list AS
SELECT DISTINCT bn AS concept_name,
	'Brand Name' AS concept_class_id,
	NULL::VARCHAR(255) AS concept_code
FROM grr_bn_2
UNION
SELECT DISTINCT PRI_ORG_LNG_NM,
	'Supplier',
	NULL::VARCHAR(255)
FROM grr_manuf
UNION
SELECT DISTINCT ingredient,
	'Ingredient',
	NULL::VARCHAR(255)
FROM grr_ing_2
WHERE ingredient IS NOT NULL
UNION
SELECT DISTINCT drug_name,
	'Drug Product',
	NULL::VARCHAR(255)
FROM grr_pack_2;

UPDATE list
SET concept_code = 'OMOP' || nextval('new_vocab');

DROP TABLE IF EXISTS dcs_drugs;
CREATE TABLE dcs_drugs AS
SELECT INITCAP(CONCAT (
			brand_name,
			' ',
			form_desc
			)) AS concept_name,
	fcc
FROM grr_new_3
UNION
SELECT INITCAP(therapy_name),
	fcc
FROM source_data_1;

DELETE
FROM dcs_drugs d
WHERE EXISTS (
		SELECT 1
		FROM dcs_drugs d_int
		WHERE d_int.fcc = d.fcc
			AND d_int.ctid > d.ctid
		);

DROP TABLE IF EXISTS dcs_unit;
CREATE TABLE dcs_unit AS
SELECT DISTINCT REPLACE(WGT_UOM_CD, '.', '') AS concept_code,
	'Unit' AS concept_class_id,
	REPLACE(WGT_UOM_CD, '.', '') AS concept_name
FROM (
	SELECT WGT_UOM_CD
	FROM grr_new_3
	UNION ALL
	SELECT PACK_VOL_UOM_CD
	FROM grr_new_3
	UNION ALL
	SELECT STRENGTH_UNIT
	FROM source_data_1
	UNION ALL
	SELECT VOLUME_UNIT
	FROM source_data_1
	UNION ALL
	SELECT 'ACTUAT'
	UNION ALL
	SELECT 'HOUR'
	) AS s0
WHERE WGT_UOM_CD IS NOT NULL
	AND WGT_UOM_CD NOT IN (
		'--',
		'Y/H'
		);

TRUNCATE TABLE drug_concept_stage;
INSERT INTO drug_concept_stage (
	CONCEPT_NAME,
	VOCABULARY_ID,
	CONCEPT_CLASS_ID,
	STANDARD_CONCEPT,
	CONCEPT_CODE,
	POSSIBLE_EXCIPIENT,
	domain_id,
	VALID_START_DATE,
	VALID_END_DATE,
	INVALID_REASON,
	SOURCE_CONCEPT_CLASS_ID
	)
SELECT DISTINCT CONCEPT_NAME,
	'GRR',
	CONCEPT_CLASS_ID,
	NULL,
	CONCEPT_CODE,
	NULL,
	'Drug',
	TO_DATE('20170718', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL,
	NULL
FROM (
	SELECT concept_name,
		concept_class_id,
		concept_code
	FROM dcs_unit
	UNION ALL
	SELECT INITCAP(concept_name),
		concept_class_id,
		concept_code
	FROM list
	UNION ALL
	SELECT concept_name,
		'Drug Product',
		fcc
	FROM dcs_drugs --drugs with pack drugs
	UNION ALL
	SELECT concept_name,
		'Dose Form',
		concept_code
	FROM grr_form_2
	) AS s0;

UPDATE drug_concept_stage
SET standard_concept = 'S'
WHERE concept_class_id = 'Ingredient';

DROP TABLE IF EXISTS grr_new_3_for_ds;
CREATE TABLE grr_new_3_for_ds AS
SELECT DISTINCT FCC,
	INTL_PACK_FORM_DESC,
	INTL_PACK_STRNT_DESC,
	INTL_PACK_SIZE_DESC,
	PACK_DESC,
	PACK_SUBSTN_CNT,
	MOLECULE,
	CASE 
		WHEN WGT_UOM_CD = 'NG'
			THEN WGT_QTY::FLOAT / 1000000
		WHEN WGT_UOM_CD = 'MCG'
			THEN WGT_QTY::FLOAT / 1000
		WHEN WGT_UOM_CD = 'G'
			THEN WGT_QTY::FLOAT * 1000
		ELSE WGT_QTY::FLOAT
		END AS WGT_QTY,
	CASE 
		WHEN WGT_UOM_CD IN (
				'NG',
				'MCG',
				'G'
				)
			THEN 'MG'
		ELSE WGT_UOM_CD
		END AS WGT_UOM_CD,
	PACK_ADDL_STRNT_DESC,
	CASE 
		WHEN PACK_WGT_UOM_CD = 'G'
			THEN PACK_WGT_QTY::FLOAT * 1000
		ELSE PACK_WGT_QTY::FLOAT
		END AS PACK_WGT_QTY,
	CASE 
		WHEN PACK_WGT_UOM_CD = 'G'
			THEN 'MG'
		ELSE PACK_WGT_UOM_CD
		END AS PACK_WGT_UOM_CD,
	CASE 
		WHEN PACK_VOL_UOM_CD = 'G'
			THEN PACK_VOL_QTY::FLOAT * 1000
		ELSE PACK_VOL_QTY::FLOAT
		END AS PACK_VOL_QTY,
	CASE 
		WHEN PACK_VOL_UOM_CD = 'G'
			THEN 'MG'
		ELSE PACK_VOL_UOM_CD
		END AS PACK_VOL_UOM_CD,
	PACK_SIZE_CNT,
	ABS_STRNT_QTY::FLOAT AS ABS_STRNT_QTY,
	ABS_STRNT_UOM_CD,
	RLTV_STRNT_QTY
FROM grr_new_3
WHERE FCC NOT IN (
		SELECT FCC
		FROM grr_new_3
		WHERE WGT_QTY LIKE '-%'
		);

-- exclude dosages<0
--inteferon 1.5/0.5 ml
DELETE
FROM grr_new_3_for_ds
WHERE MOLECULE IN (
		'INTERFERON BETA-1A',
		'ETANERCEPT',
		'COLECALCIFEROL',
		'DALTEPARIN SODIUM',
		'DROPERIDOL',
		'ENOXAPARIN SODIUM',
		'EPOETIN ALFA',
		'FOLLITROPIN ALFA',
		'FULVESTRANT',
		'SALBUTAMOL',
		'TRAMADOL'
		)
	AND WGT_QTY / PACK_VOL_QTY != ABS_STRNT_QTY
	AND FCC IN (
		SELECT a.fcc
		FROM grr_new_3_for_ds a
		JOIN grr_new_3_for_ds b ON a.fcc = b.fcc
			AND (
				a.PACK_VOL_QTY != b.PACK_VOL_QTY
				OR a.PACK_VOL_UOM_CD != b.PACK_VOL_UOM_CD
				)
		);

--delete 3-leg dogs
DELETE
FROM grr_new_3_for_ds
WHERE fcc IN (
		SELECT fcc
		FROM grr_new_3_for_ds
		WHERE WGT_QTY = 0
		
		UNION ALL
		
		SELECT fcc
		FROM grr_new_3_for_ds
		WHERE WGT_QTY IS NULL
		);

--octreotide
UPDATE grr_new_3_for_ds
SET wgt_qty = CASE 
		WHEN wgt_qty = '44.1'
			THEN 30
		WHEN wgt_qty = '11.76'
			THEN 10
		WHEN wgt_qty IN (
				'29.4',
				'23.52'
				)
			THEN 20
		ELSE wgt_qty
		END,
	pack_vol_qty = CASE 
		WHEN pack_vol_qty IN (
				'2',
				'2.5'
				)
			THEN 2
		ELSE pack_vol_qty
		END
WHERE molecule = 'OCTREOTIDE';

UPDATE GRR_NEW_3_FOR_DS
SET WGT_QTY = 500,
	PACK_WGT_QTY = NULL,
	PACK_WGT_UOM_CD = NULL
WHERE FCC = '875055_06152015';

--DEXRAZOXANE INJECTION
UPDATE GRR_NEW_3_FOR_DS
SET WGT_QTY = 30
WHERE FCC = '904091_04152016'
	AND MOLECULE = 'BETAMETHASONE'
	AND WGT_QTY = 38.568
	AND PACK_VOL_QTY IS NULL;

UPDATE GRR_NEW_3_FOR_DS
SET PACK_WGT_QTY = NULL,
	PACK_WGT_UOM_CD = NULL
WHERE FCC IN (
		'769391_10012008',
		'769392_10012008',
		'769393_09012009',
		'769394_09012009',
		'769395_09012009'
		);

--CITRAFLEET, PULVER
DELETE
FROM GRR_NEW_3_FOR_DS
WHERE FCC = '904091_04152016'
	AND MOLECULE = 'BETAMETHASONE'
	AND WGT_QTY = 38.568
	AND PACK_VOL_QTY IS NULL;

DELETE
FROM GRR_NEW_3_FOR_DS
WHERE FCC = '728203_03152011'
	AND MOLECULE = 'CALCIUM'
	AND WGT_QTY = 4.4
	AND PACK_VOL_QTY = 5000;

DELETE
FROM GRR_NEW_3_FOR_DS
WHERE FCC = '728203_03152011'
	AND MOLECULE = '2-OXOGLUTARIC ACID'
	AND WGT_QTY = 368
	AND PACK_VOL_QTY = 5000;

DELETE
FROM GRR_NEW_3_FOR_DS
WHERE FCC = '742103_08012011'
	AND PACK_VOL_QTY = 0.4;

DELETE
FROM GRR_NEW_3_FOR_DS
WHERE FCC = '908278_05152016'
	AND PACK_VOL_QTY = 2.399;

DELETE
FROM GRR_NEW_3_FOR_DS
WHERE FCC = '518889_04012005'
	AND PACK_VOL_QTY = 0.3;

DELETE
FROM GRR_NEW_3_FOR_DS
WHERE FCC = '671753_08152009'
	AND PACK_VOL_QTY = 16.7;

DELETE
FROM GRR_NEW_3_FOR_DS
WHERE FCC LIKE '80771%_05152013'
	AND PACK_VOL_QTY = 5;

DELETE
FROM GRR_NEW_3_FOR_DS
WHERE FCC LIKE '65821%_04012009'
	AND PACK_VOL_QTY IN (
		5,
		0.5
		);

--vaccine hepatitis b
DELETE
FROM GRR_NEW_3_FOR_DS
WHERE FCC = '879735_08152015'
	AND PACK_VOL_QTY = 15;

DELETE
FROM GRR_NEW_3_FOR_DS
WHERE FCC = '728203_03152011'
	AND PACK_VOL_QTY = 5000;

DELETE
FROM GRR_NEW_3_FOR_DS
WHERE FCC = '860022_12152014'
	AND PACK_WGT_QTY = 250000;

DELETE
FROM GRR_NEW_3_FOR_DS
WHERE FCC = '904091_04152016'
	AND PACK_WGT_QTY = 120000;

--deleting drugs with cm
DELETE
FROM grr_new_3_for_ds
WHERE 'CM' IN (
		WGT_UOM_CD,
		PACK_VOL_UOM_CD,
		PACK_WGT_UOM_CD
		);

--delete duplicate ingredients one of which =0
DELETE
FROM grr_new_3_for_ds
WHERE fcc IN (
		SELECT a.fcc
		FROM grr_new_3_for_ds a
		JOIN grr_new_3_for_ds b ON a.fcc = b.fcc
			AND a.MOLECULE = b.MOLECULE
			AND a.WGT_QTY = 0
			AND b.WGT_QTY != 0
		)
	AND WGT_QTY = 0;

--create table to use right dosages from ABS_STRNT_QTY
DROP TABLE IF EXISTS grr_ds_abstr_qnt;
CREATE TABLE grr_ds_abstr_qnt AS
SELECT *
FROM grr_new_3_for_ds
WHERE fcc IN (
		SELECT a.fcc
		FROM grr_new_3_for_ds a
		JOIN grr_new_3_for_ds b ON a.fcc = b.fcc
			AND a.molecule = b.molecule
		WHERE a.WGT_QTY != b.WGT_QTY
			AND a.ABS_STRNT_QTY = b.ABS_STRNT_QTY
			AND a.ABS_STRNT_UOM_CD NOT IN (
				'G',
				'%'
				)
		);

INSERT INTO grr_ds_abstr_qnt
SELECT *
FROM grr_new_3_for_ds
WHERE fcc IN (
		SELECT fcc
		FROM grr_new_3_for_ds
		WHERE WGT_QTY != ABS_STRNT_QTY
			AND SUBSTRING(INTL_PACK_STRNT_DESC, '\d+')::FLOAT = ABS_STRNT_QTY
			AND NOT INTL_PACK_STRNT_DESC ~ '%|/|\+'
			AND NOT INTL_PACK_STRNT_DESC ~ '%'
			AND ABS_STRNT_UOM_CD NOT IN (
				'M',
				'K'
				)
		);

UPDATE grr_ds_abstr_qnt
SET WGT_QTY = ABS_STRNT_QTY,
	WGT_UOM_CD = CASE 
		WHEN ABS_STRNT_UOM_CD = 'Y'
			THEN 'MCG'
		ELSE ABS_STRNT_UOM_CD
		END
WHERE PACK_WGT_QTY IS NULL
	AND PACK_VOL_QTY IS NULL;

DELETE
FROM grr_ds_abstr_qnt
WHERE fcc IN (
		'772057_01011988',
		'243285'
		);

--100%
DROP TABLE IF EXISTS grr_ds_abstr_qnt_2;
CREATE TABLE grr_ds_abstr_qnt_2 AS
SELECT *
FROM grr_ds_abstr_qnt
WHERE fcc IN (
		SELECT a.fcc
		FROM grr_ds_abstr_qnt a
		JOIN grr_ds_abstr_qnt b ON a.fcc = b.fcc
			AND a.molecule = b.molecule
		WHERE a.WGT_QTY != b.WGT_QTY
		);

UPDATE grr_ds_abstr_qnt_2
--remove %
SET WGT_QTY = ABS_STRNT_QTY * 10 * PACK_WGT_QTY
WHERE ABS_STRNT_UOM_CD = '%'
	AND PACK_WGT_QTY IS NOT NULL;

UPDATE grr_ds_abstr_qnt_2
SET WGT_QTY = ABS_STRNT_QTY * 10 * PACK_VOL_QTY
WHERE ABS_STRNT_UOM_CD = '%'
	AND PACK_VOL_QTY IS NOT NULL;

UPDATE grr_ds_abstr_qnt_2
SET WGT_QTY = ABS_STRNT_QTY / RLTV_STRNT_QTY::FLOAT * PACK_VOL_QTY::FLOAT
WHERE RLTV_STRNT_QTY IS NOT NULL;

UPDATE grr_ds_abstr_qnt_2
SET WGT_QTY = ABS_STRNT_QTY,
	WGT_UOM_CD = CASE 
		WHEN ABS_STRNT_UOM_CD = 'Y'
			THEN 'MCG'
		ELSE ABS_STRNT_UOM_CD
		END
WHERE ABS_STRNT_UOM_CD != '%'
	AND fcc IN (
		SELECT DISTINCT a.fcc
		FROM grr_ds_abstr_qnt_2 a
		JOIN grr_ds_abstr_qnt_2 b ON a.fcc = b.fcc
			AND a.molecule = b.molecule
		WHERE a.WGT_QTY != b.WGT_QTY
		);

DELETE
FROM grr_ds_abstr_qnt
WHERE fcc IN (
		SELECT fcc
		FROM grr_ds_abstr_qnt_2
		);

INSERT INTO grr_ds_abstr_qnt
SELECT *
FROM grr_ds_abstr_qnt_2;

DROP TABLE IF EXISTS grr_ds_abstr_qnt_3;
CREATE TABLE grr_ds_abstr_qnt_3 AS
SELECT DISTINCT FCC,
	INTL_PACK_FORM_DESC,
	INTL_PACK_STRNT_DESC,
	INTL_PACK_SIZE_DESC AS BOX_SIZE,
	PACK_DESC,
	PACK_SUBSTN_CNT AS INGREDIENTS_CNT,
	MOLECULE,
	PACK_ADDL_STRNT_DESC,
	WGT_QTY AS AMOUNT_VALUE,
	WGT_UOM_CD AS AMOUNT_UNIT,
	COALESCE(PACK_WGT_QTY, PACK_VOL_QTY) AS DENOMINATOR_VALUE,
	COALESCE(PACK_WGT_UOM_CD, PACK_VOL_UOM_CD) AS DENOMINATOR_UNIT,
	PACK_SIZE_CNT
FROM grr_ds_abstr_qnt;

DROP TABLE IF EXISTS grr_ds_abstr_rel;
CREATE TABLE grr_ds_abstr_rel AS
SELECT FCC,
	INTL_PACK_FORM_DESC,
	INTL_PACK_STRNT_DESC,
	INTL_PACK_SIZE_DESC AS BOX_SIZE,
	PACK_DESC,
	PACK_SUBSTN_CNT AS ingredients_cnt,
	MOLECULE,
	PACK_ADDL_STRNT_DESC,
	ABS_STRNT_QTY AS AMOUNT_VALUE,
	CASE 
		WHEN ABS_STRNT_UOM_CD = 'Y'
			THEN 'MCG'
		ELSE ABS_STRNT_UOM_CD
		END AS AMOUNT_UNIT,
	CASE
		WHEN RLTV_STRNT_QTY::FLOAT = 1 
			THEN NULL 
		ELSE RLTV_STRNT_QTY::FLOAT 
		END AS DENOMINATOR_VALUE,
	'HOUR'::TEXT AS DENOMINATOR_UNIT,
	PACK_SIZE_CNT
FROM grr_new_3_for_ds
WHERE RLTV_STRNT_QTY IS NOT NULL
	AND INTL_PACK_STRNT_DESC LIKE '%HR%';

DROP TABLE IF EXISTS grr_new_3_1;
CREATE TABLE grr_new_3_1 AS
SELECT DISTINCT FCC,
	INTL_PACK_FORM_DESC,
	INTL_PACK_STRNT_DESC,
	INTL_PACK_SIZE_DESC AS BOX_SIZE,
	PACK_DESC,
	PACK_SUBSTN_CNT AS INGREDIENTS_CNT,
	MOLECULE,
	PACK_ADDL_STRNT_DESC,
	WGT_QTY AS AMOUNT_VALUE,
	WGT_UOM_CD AS AMOUNT_UNIT,
	COALESCE(PACK_WGT_QTY, PACK_VOL_QTY) AS DENOMINATOR_VALUE,
	COALESCE(PACK_WGT_UOM_CD, PACK_VOL_UOM_CD) AS DENOMINATOR_UNIT,
	PACK_SIZE_CNT
FROM grr_new_3_for_ds;

DELETE
FROM grr_new_3_1
WHERE fcc IN (
		SELECT fcc
		FROM grr_ds_abstr_qnt_3
		
		UNION ALL
		
		SELECT fcc
		FROM grr_ds_abstr_rel
		);

INSERT INTO grr_new_3_1
SELECT *
FROM grr_ds_abstr_qnt_3
UNION
SELECT *
FROM grr_ds_abstr_rel;

--add more dosage from source data
DROP TABLE IF EXISTS grr_new_3_2;
CREATE TABLE grr_new_3_2 AS
SELECT DISTINCT a.fcc,
	a.BOX_SIZE,
	a.MOLECULE,
	a.DENOMINATOR_VALUE,
	a.DENOMINATOR_unit,
	a.AMOUNT_VALUE,
	a.AMOUNT_UNIT,
	a.INGREDIENTS_CNT
FROM grr_new_3_1 a
JOIN grr_new_3_1 b ON a.fcc = b.fcc
JOIN source_data_1 c ON a.fcc = c.fcc
WHERE a.DENOMINATOR_VALUE != b.DENOMINATOR_VALUE
	AND a.DENOMINATOR_VALUE = VOLUME::FLOAT;

DROP TABLE IF EXISTS grr_new_3_3;
CREATE TABLE grr_new_3_3 AS
SELECT DISTINCT a.fcc,
	BOX_SIZE,
	MOLECULE,
	CASE 
		WHEN VOLUME = '0'
			THEN NULL
		ELSE VOLUME::FLOAT
		END AS DENOMINATOR_VALUE,
	VOLUME_UNIT AS DENOMINATOR_UNIT,
	STRENGTH::FLOAT AS AMOUNT_VALUE,
	STRENGTH_UNIT AS AMOUNT_UNIT,
	INGREDIENTS_CNT
FROM grr_new_3_1 a
JOIN source_data b ON a.fcc = b.fcc
WHERE (
		AMOUNT_VALUE IS NULL
		OR AMOUNT_VALUE = 0
		)
	AND STRENGTH != '0'
	AND INGREDIENTS_CNT = '1';

--ABS_STRNT_QTY
DROP TABLE IF EXISTS grr_new_3_4;
CREATE TABLE grr_new_3_4 AS
SELECT DISTINCT FCC,
	INTL_PACK_FORM_DESC,
	INTL_PACK_STRNT_DESC,
	INTL_PACK_SIZE_DESC AS BOX_SIZE,
	PACK_DESC,
	PACK_SUBSTN_CNT AS INGREDIENTS_CNT,
	MOLECULE,
	PACK_ADDL_STRNT_DESC,
	WGT_QTY AS AMOUNT_VALUE,
	WGT_UOM_CD AS AMOUNT_UNIT,
	COALESCE(PACK_WGT_QTY, PACK_VOL_QTY) AS DENOMINATOR_VALUE,
	COALESCE(PACK_WGT_UOM_CD, PACK_VOL_UOM_CD) AS DENOMINATOR_UNIT,
	PACK_SIZE_CNT
FROM grr_new_3_for_ds
WHERE WGT_QTY IS NULL
	AND ABS_STRNT_QTY IS NOT NULL;

UPDATE GRR_NEW_3_4
SET AMOUNT_VALUE = '10',
	AMOUNT_UNIT = 'MG'
WHERE fcc = '196057_01151993'
	AND MOLECULE = 'SILICON DIOXIDE';

--googled
UPDATE GRR_NEW_3_4
SET AMOUNT_VALUE = '10',
	AMOUNT_UNIT = 'MG'
WHERE fcc = '196057_01151993'
	AND MOLECULE = 'IRON FERROUS';

UPDATE GRR_NEW_3_4
SET AMOUNT_VALUE = '6310',
	AMOUNT_UNIT = 'G'
WHERE fcc = '601177_10012007'
	AND MOLECULE = '2-PROPANOL';

TRUNCATE TABLE grr_ds;
INSERT INTO grr_ds
SELECT DISTINCT *
FROM (
	SELECT FCC,
		BOX_SIZE,
		MOLECULE,
		DENOMINATOR_VALUE,
		DENOMINATOR_UNIT,
		AMOUNT_VALUE,
		AMOUNT_UNIT,
		INGREDIENTS_CNT
	FROM grr_new_3_1
	WHERE fcc NOT IN (
			SELECT fcc
			FROM grr_new_3_2
			UNION ALL
			SELECT fcc
			FROM grr_new_3_3
			UNION ALL
			SELECT fcc
			FROM grr_new_3_4
			)
	UNION ALL
	SELECT FCC,
		BOX_SIZE,
		MOLECULE,
		DENOMINATOR_VALUE,
		DENOMINATOR_UNIT,
		AMOUNT_VALUE,
		AMOUNT_UNIT,
		INGREDIENTS_CNT
	FROM grr_new_3_2
	WHERE fcc NOT IN (
			SELECT fcc
			FROM grr_new_3_3
			UNION ALL
			SELECT fcc
			FROM grr_new_3_4
			)
	UNION ALL
	SELECT FCC,
		BOX_SIZE,
		MOLECULE,
		DENOMINATOR_VALUE,
		DENOMINATOR_UNIT,
		AMOUNT_VALUE,
		AMOUNT_UNIT,
		INGREDIENTS_CNT
	FROM grr_new_3_3
	WHERE fcc NOT IN (
			SELECT fcc
			FROM grr_new_3_4
			)
	UNION ALL
	SELECT FCC,
		BOX_SIZE,
		MOLECULE,
		DENOMINATOR_VALUE,
		DENOMINATOR_UNIT,
		AMOUNT_VALUE,
		AMOUNT_UNIT,
		INGREDIENTS_CNT
	FROM grr_new_3_4
	) AS s0;

DELETE
FROM grr_ds
WHERE fcc IN (
		SELECT a.fcc
		FROM grr_ds a
		JOIN grr_ds b ON a.fcc = b.fcc
		WHERE a.DENOMINATOR_VALUE != b.DENOMINATOR_VALUE
			OR a.DENOMINATOR_VALUE IS NULL
			AND b.DENOMINATOR_VALUE IS NOT NULL
		)
	AND DENOMINATOR_VALUE IS NULL;

UPDATE grr_ds
--water
SET AMOUNT_UNIT = 'G',
	AMOUNT_VALUE = DENOMINATOR_VALUE
WHERE molecule LIKE '%WATER%'
	AND (
		AMOUNT_VALUE IS NULL
		OR AMOUNT_VALUE = 0
		);

UPDATE grr_ds
SET BOX_SIZE = NULL,
	AMOUNT_VALUE = NULL,
	AMOUNT_UNIT = NULL,
	DENOMINATOR_VALUE = NULL,
	DENOMINATOR_UNIT = NULL
WHERE fcc IN (
		SELECT fcc
		FROM grr_ds a
		WHERE AMOUNT_VALUE = 0
			OR DENOMINATOR_VALUE = 0
			OR a.AMOUNT_VALUE IS NULL
			OR AMOUNT_UNIT = '--'
		);

UPDATE grr_ds
SET box_size = NULL -- remove different box sizes
WHERE fcc IN (
		SELECT a.fcc
		FROM grr_ds a
		JOIN grr_ds b ON a.fcc = b.fcc
		WHERE a.box_size != b.box_size
			OR (
				a.box_size IS NULL
				AND b.box_size IS NOT NULL
				)
		);
UPDATE grr_ds
--remove solid forms with denominator
SET DENOMINATOR_VALUE = NULL,
	DENOMINATOR_UNIT = NULL
WHERE fcc IN (
		SELECT a.fcc
		FROM grr_ds a
		JOIN grr_new_3 b ON a.fcc = b.fcc
		WHERE DENOMINATOR_UNIT IS NOT NULL
			AND INTL_PACK_FORM_DESC ~ 'TAB|CAP'
		);

UPDATE grr_ds
SET AMOUNT_UNIT = 'MCG'
WHERE AMOUNT_UNIT = 'Y';

UPDATE grr_ds
SET AMOUNT_UNIT = 'IU'
WHERE AMOUNT_UNIT = 'K';

UPDATE grr_ds
-- big part of sprays and aerosols + update box sizes like '%X%'
SET amount_value = amount_value * REGEXP_REPLACE(BOX_SIZE, 'X\d+', '', 'g')::FLOAT,
	DENOMINATOR_VALUE = REGEXP_REPLACE(BOX_SIZE, 'X\d+', '', 'g')::FLOAT,
	DENOMINATOR_UNIT = 'ACTUAT',
	box_size = NULL
WHERE box_size LIKE '%X%'
	AND denominator_unit IS NULL;

UPDATE grr_ds
SET amount_value = amount_value * REGEXP_REPLACE(BOX_SIZE, 'X\d+', '', 'g')::FLOAT,
	box_size = NULL
WHERE box_size LIKE '%X%'
	AND denominator_unit = 'ML'
	AND (
		amount_unit NOT IN (
			'MG',
			'G'
			)
		OR (
			amount_unit = 'MG'
			AND amount_value < 1.1
			)
		);

UPDATE grr_ds
SET amount_value = amount_value * REGEXP_REPLACE(BOX_SIZE, 'X\d+', '', 'g')::FLOAT,
	box_size = NULL
WHERE box_size LIKE '%X%'
	AND molecule != 'HYDROCORTISONE'
	AND (
		amount_unit != 'MG'
		OR (
			amount_unit = 'MG'
			AND amount_value < 1.1
			)
		);

UPDATE grr_ds
SET box_size = '200'
WHERE fcc IN (
		'02.01.1988-112349',
		'02.01.1988-121916',
		'02.01.1988-237066'
		);

UPDATE grr_ds
--updating inhalers
SET amount_value = amount_value * BOX_SIZE::FLOAT,
	DENOMINATOR_VALUE = BOX_SIZE::FLOAT,
	DENOMINATOR_UNIT = 'ACTUAT'
WHERE fcc IN (
		SELECT DISTINCT a.fcc
		FROM grr_ds a
		JOIN grr_new_3 b ON a.fcc = b.fcc
		WHERE PACK_DESC LIKE '%AER%'
			AND denominator_unit IS NULL
		)
	AND box_size IS NOT NULL;

UPDATE grr_ds
SET box_size = NULL
WHERE box_size LIKE '%X%';

UPDATE grr_ds
--update unit od duplicated ingredeints in order to sum them up
SET amount_value = amount_value * 1000,
	amount_unit = 'MG'
WHERE fcc IN (
		SELECT a.fcc
		FROM grr_ds a
		JOIN grr_ds b ON a.fcc = b.fcc
			AND a.molecule = b.molecule
			AND (a.AMOUNT_UNIT != b.AMOUNT_UNIT)
			AND a.fcc IN (
				SELECT fcc
				FROM grr_ds
				GROUP BY fcc,
					molecule
				HAVING COUNT(1) > 1
				)
			AND a.AMOUNT_UNIT = 'G'
		)
	AND AMOUNT_UNIT = 'G';

UPDATE grr_ds
SET amount_value = amount_value / 1000,
	amount_unit = 'MG'
WHERE fcc IN (
		SELECT a.fcc
		FROM grr_ds a
		JOIN grr_ds b ON a.fcc = b.fcc
			AND a.molecule = b.molecule
			AND (a.AMOUNT_UNIT != b.AMOUNT_UNIT)
			AND a.fcc IN (
				SELECT fcc
				FROM grr_ds
				GROUP BY fcc,
					molecule
				HAVING COUNT(1) > 1
				)
			AND a.AMOUNT_UNIT = 'MCG'
		)
	AND AMOUNT_UNIT = 'MCG';

UPDATE grr_ds
SET amount_value = AMOUNT_VALUE * DENOMINATOR_VALUE * 10,
	amount_unit = 'MG' --update %
WHERE AMOUNT_UNIT = '%'
	AND DENOMINATOR_UNIT = 'ML';

UPDATE grr_ds
SET amount_value = DENOMINATOR_VALUE,
	amount_unit = 'G'
WHERE AMOUNT_UNIT = '%'
	AND DENOMINATOR_UNIT = 'G';

UPDATE grr_ds
SET amount_value = AMOUNT_VALUE * 10,
	amount_unit = 'MG',
	DENOMINATOR_UNIT = 'ML'
WHERE AMOUNT_UNIT = '%'
	AND DENOMINATOR_UNIT IS NULL;

--updating bias in original data
UPDATE GRR_DS
SET AMOUNT_VALUE = 500,
	AMOUNT_UNIT = 'MG'
WHERE fcc = '08.15.2015-879797'
	AND MOLECULE = 'DEXPANTHENOL';

UPDATE GRR_DS
SET AMOUNT_VALUE = 10,
	AMOUNT_UNIT = 'MG'
WHERE fcc = '08.15.2015-879797'
	AND MOLECULE = 'XYLOMETAZOLINE';

UPDATE GRR_DS
SET AMOUNT_VALUE = 500,
	AMOUNT_UNIT = 'MG'
WHERE fcc = '08.15.2015-879798'
	AND MOLECULE = 'DEXPANTHENOL';

UPDATE GRR_DS
SET AMOUNT_VALUE = 10,
	AMOUNT_UNIT = 'MG'
WHERE fcc = '08.15.2015-879798'
	AND MOLECULE = 'XYLOMETAZOLINE';

UPDATE GRR_DS
SET DENOMINATOR_UNIT = 'ML'
WHERE fcc = '12.15.2013-825791'
	AND MOLECULE = 'XYLOMETAZOLINE';

UPDATE GRR_DS
SET DENOMINATOR_UNIT = 'ML',
	AMOUNT_VALUE = 10,
	AMOUNT_UNIT = 'MG'
WHERE fcc = '10.15.2006-567057'
	AND MOLECULE = 'XYLOMETAZOLINE';

UPDATE GRR_DS
SET DENOMINATOR_UNIT = 'ML',
	AMOUNT_VALUE = 50,
	AMOUNT_UNIT = 'MG'
WHERE fcc = '01.01.2007-572166'
	AND MOLECULE = 'DEXPANTHENOL';

UPDATE GRR_DS
SET DENOMINATOR_UNIT = 'ML',
	AMOUNT_VALUE = 1,
	AMOUNT_UNIT = 'MG'
WHERE fcc = '01.01.2007-572166'
	AND MOLECULE = 'XYLOMETAZOLINE';

UPDATE GRR_DS
SET AMOUNT_UNIT = NULL,
	AMOUNT_VALUE = NULL,
	DENOMINATOR_VALUE = NULL,
	DENOMINATOR_UNIT = NULL,
	box_size = NULL
WHERE fcc IN (
		'09.01.2006-563583',
		'12.01.2004-508584',
		'01.01.1111-284413'
		);

UPDATE GRR_DS
SET amount_value = 500
WHERE fcc = '11.15.1997-282894';

UPDATE GRR_DS
SET AMOUNT_UNIT = 'MG'
WHERE fcc = '05.15.2005-520745'
	AND MOLECULE = 'SODIUM'
	AND DENOMINATOR_UNIT = 'ML';

DELETE
FROM GRR_DS
WHERE fcc = '12.15.2014-860022'
	AND MOLECULE = 'IMIQUIMOD'
	AND DENOMINATOR_UNIT = 'G';

DELETE
FROM GRR_DS
WHERE fcc = '05.15.2005-520745'
	AND MOLECULE = 'SODIUM'
	AND DENOMINATOR_UNIT = 'G';

--delete molecules with weird dosages
DELETE
FROM GRR_DS
WHERE fcc LIKE '12.15.2003-47697%'
	AND MOLECULE = 'POTASSIUM'
	AND AMOUNT_VALUE = 100;

DELETE
FROM GRR_DS
WHERE fcc LIKE '12.15.2003-47697%'
	AND MOLECULE = 'MYRISTICA FRAGANS'
	AND AMOUNT_VALUE = 100;

DELETE
FROM GRR_DS
WHERE fcc LIKE '12.15.2003-47697%'
	AND MOLECULE = 'IGNATIA AMARA'
	AND AMOUNT_VALUE = 100;

DELETE
FROM GRR_DS
WHERE fcc LIKE '12.15.2003-47697%'
	AND MOLECULE = 'FERULA ASSA FOETIDA'
	AND AMOUNT_VALUE = 100;

DELETE
FROM GRR_DS
WHERE fcc = '12.15.2003-476978'
	AND MOLECULE = 'VALERIANA OFFICINALIS'
	AND AMOUNT_VALUE = 100;

DELETE
FROM GRR_DS
WHERE fcc IN (
		'06.01.1995-236293',
		'06.01.1995-896478'
		);

--deleting ingerdients because 1 pzn represents 2 fcc thus we do not need to do it anymore
DELETE
FROM GRR_DS
WHERE fcc = '02.01.1988-112492'
	AND MOLECULE = 'ORNITHINE';

--update empty ingredients 
DELETE
FROM grr_ds
WHERE fcc IN (
		SELECT a.fcc
		FROM grr_ds a
		JOIN grr_ds b ON a.fcc = b.fcc
		WHERE a.molecule IS NULL
			AND b.molecule IS NOT NULL
		)
	AND molecule IS NULL;

INSERT INTO grr_ds (
	FCC,
	BOX_SIZE,
	MOLECULE,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT,
	AMOUNT_VALUE,
	AMOUNT_UNIT
	)
SELECT DISTINCT CONCEPT_CODE,
	BOX_SIZE,
	MOLECULE,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT,
	AMOUNT_VALUE,
	AMOUNT_UNIT
FROM grr_pack_2 a
JOIN drug_concept_stage b ON UPPER(drug_name) = UPPER(concept_name);

DROP TABLE IF EXISTS grr_ds_1;
CREATE TABLE grr_ds_1 AS
SELECT DISTINCT a.FCC,
	BOX_SIZE,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT,
	AMOUNT_VALUE,
	AMOUNT_UNIT,
	CASE 
		WHEN molecule IS NULL
			AND NOT SUBSTANCE ~ 'HEALING|KEINE|\+|DIET|MEDICATED|MULTI'
			THEN substance
		ELSE molecule
		END AS molecule
FROM source_data b
RIGHT JOIN GRR_DS a ON a.fcc = b.fcc;

DROP TABLE IF EXISTS ds_stage_sum;
CREATE TABLE ds_stage_sum AS
SELECT FCC,
	MOLECULE,
	BOX_SIZE,
	SUM(AMOUNT_VALUE) AS amount_value,
	AMOUNT_UNIT,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT
FROM grr_ds_1
GROUP BY fcc,
	molecule,
	BOX_SIZE,
	AMOUNT_UNIT,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT;

UPDATE DS_STAGE_SUM
SET BOX_SIZE = NULL,
	DENOMINATOR_VALUE = NULL,
	DENOMINATOR_UNIT = NULL,
	AMOUNT_VALUE = NULL,
	AMOUNT_UNIT = NULL
WHERE fcc IN (
		SELECT fcc
		FROM grr_ds
		WHERE DENOMINATOR_UNIT LIKE '%KG%'
			OR AMOUNT_UNIT LIKE '%KG%'
		);

DROP TABLE IF EXISTS ds_stage_0;
CREATE TABLE ds_stage_0 AS
SELECT DISTINCT fcc AS drug_concept_code,
	b.concept_Code AS ingredient_concept_code,
	molecule,
	CASE 
		WHEN DENOMINATOR_UNIT IS NULL
			AND AMOUNT_UNIT NOT IN ('DH','C','CH','D','TM','X','XMK')
			THEN AMOUNT_VALUE
		ELSE NULL
		END AS AMOUNT_VALUE,
	-- put homeopathy into numerator
	CASE 
		WHEN DENOMINATOR_UNIT IS NULL
			AND AMOUNT_UNIT NOT IN ('DH','C','CH','D','TM','X','XMK')
			THEN AMOUNT_UNIT
		ELSE NULL
		END AS AMOUNT_UNIT,
	CASE 
		WHEN DENOMINATOR_UNIT IS NOT NULL
			OR AMOUNT_UNIT ('DH','C','CH','D','TM','X','XMK')
			THEN AMOUNT_VALUE
		ELSE NULL
		END AS NUMERATOR_VALUE,
	CASE 
		WHEN DENOMINATOR_UNIT IS NOT NULL
			OR AMOUNT_UNIT IN ('DH','C','CH','D','TM','X','XMK')
			THEN AMOUNT_UNIT
		ELSE NULL
		END AS NUMERATOR_UNIT,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT,
	BOX_SIZE
FROM DS_STAGE_SUM a
JOIN drug_concept_stage b ON UPPER(molecule) = UPPER(concept_name)
	AND concept_class_id = 'Ingredient';

INSERT INTO ds_stage (
	DRUG_CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	AMOUNT_VALUE,
	AMOUNT_UNIT,
	NUMERATOR_VALUE,
	NUMERATOR_UNIT,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT,
	BOX_SIZE
	)
SELECT DISTINCT DRUG_CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	AMOUNT_VALUE,
	AMOUNT_UNIT,
	NUMERATOR_VALUE,
	NUMERATOR_UNIT,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT,
	BOX_SIZE::int4
FROM ds_stage_0
WHERE drug_concept_code NOT IN (
		SELECT fcc
		FROM grr_pack_2
		);

--ds_stage for source_data
DROP TABLE IF EXISTS ds_0_sd;
CREATE TABLE ds_0_sd AS
SELECT DISTINCT a.fcc,
	substance,
	CASE 
		WHEN STRENGTH = '0'
			THEN NULL
		ELSE STRENGTH
		END AS STRENGTH,
	CASE 
		WHEN STRENGTH_UNIT = 'Y/H'
			THEN 'MCG'
		WHEN STRENGTH_UNIT = 'K.'
			THEN 'K'
		ELSE STRENGTH_UNIT
		END AS STRENGTH_UNIT,
	CASE 
		WHEN VOLUME = '0'
			THEN NULL
		ELSE VOLUME
		END AS VOLUME,
	CASE 
		WHEN STRENGTH_UNIT = 'Y/H'
			THEN 'HOUR'
		WHEN VOLUME_UNIT = 'K.'
			THEN 'K'
		ELSE VOLUME_UNIT
		END AS VOLUME_UNIT,
	b.concept_name,
	PACKSIZE::INT4 AS box_size,
	PRODUCT_FORM_NAME
FROM source_data_1 a
LEFT JOIN grr_form_2 b ON a.fcc = b.fcc
WHERE NO_OF_SUBSTANCES = '1'
	OR (
		NO_OF_SUBSTANCES != '1'
		AND STRENGTH != '0'
		);

UPDATE ds_0_sd
SET volume = NULL,
	VOLUME_UNIT = NULL
WHERE (
		volume IS NOT NULL
		AND strength IS NULL
		)
	OR (
		volume IS NOT NULL
		AND concept_name ~ 'Globule|Pellet|Tablet|Suppos'
		);

UPDATE ds_0_sd
SET STRENGTH = STRENGTH::FLOAT * 10,
	VOLUME_UNIT = CASE 
		WHEN VOLUME_UNIT IS NULL
			THEN 'ML'
		ELSE VOLUME_UNIT
		END,
	STRENGTH_UNIT = 'MG'
WHERE STRENGTH_UNIT = '%';

--sprays with wrong dosages
UPDATE ds_0_sd
SET STRENGTH = substring(PRODUCT_FORM_NAME, '\d+')::FLOAT * STRENGTH::FLOAT
WHERE fcc IN (
		SELECT fcc
		FROM source_data_1
		WHERE THERAPY_NAME LIKE '%DOS.%'
			AND STRENGTH_UNIT IN (
				'MG',
				'Y'
				)
			AND VOLUME IS NOT NULL
			AND VOLUME != '0.0'
		)
	AND substring(PRODUCT_FORM_NAME, '\d+') IS NOT NULL;

--delete all the drugs that do not have dosages
DELETE
FROM ds_0_sd
WHERE substance LIKE '%+%';

DELETE
FROM ds_0_sd
WHERE fcc IN (
		SELECT fcc
		FROM ds_0_sd
		WHERE strength = '0.0'
		);

INSERT INTO ds_stage (
	DRUG_CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	BOX_SIZE,
	AMOUNT_VALUE,
	AMOUNT_UNIT,
	NUMERATOR_VALUE,
	NUMERATOR_UNIT,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT
	)
SELECT FCC,
	CONCEPT_CODE,
	a.BOX_SIZE,
	STRENGTH::FLOAT,
	STRENGTH_UNIT,
	NULL::FLOAT,
	NULL,
	NULL::FLOAT,
	NULL
FROM ds_0_sd a
JOIN drug_concept_stage b ON UPPER(b.concept_name) = UPPER(substance)
	AND concept_class_id = 'Ingredient'
WHERE (
		volume_unit IS NULL
		AND strength_unit NOT IN ('DH','C','CH','D','TM','X','XMK')
		)
	AND fcc NOT IN (
		SELECT drug_concept_code
		FROM ds_stage
		)
UNION
SELECT FCC,
	CONCEPT_CODE,
	a.BOX_SIZE,
	NULL,
	NULL,
	STRENGTH::FLOAT,
	STRENGTH_UNIT,
	CASE WHEN VOLUME = '0.0' THEN NULL
	     ELSE VOLUME::FLOAT END,
	VOLUME_UNIT
FROM ds_0_sd a
JOIN drug_concept_stage b ON UPPER(b.concept_name) = UPPER(substance)
	AND concept_class_id = 'Ingredient'
WHERE (
		volume_unit IS NOT NULL
		OR strength_unit IN ('DH','C','CH','D','TM','X','XMK')
		)
	AND fcc NOT IN (
		SELECT drug_concept_code
		FROM ds_stage
		);


--work with ds_stage, strarting with grr pattern
UPDATE DS_STAGE
SET NUMERATOR_VALUE = 500
WHERE DRUG_CONCEPT_CODE IN (
		'235152_05151995',
		'307287_05151995'
		)
	AND NUMERATOR_VALUE = 576
	AND NUMERATOR_UNIT = 'MG';

UPDATE DS_STAGE
SET NUMERATOR_VALUE = 950
WHERE DRUG_CONCEPT_CODE = '280104_09151997'
	AND NUMERATOR_VALUE = 9500000
	AND NUMERATOR_UNIT = 'MG';

UPDATE DS_STAGE
SET NUMERATOR_VALUE = 100
WHERE DRUG_CONCEPT_CODE = '274138_07011997'
	AND NUMERATOR_VALUE = 100000
	AND NUMERATOR_UNIT = 'MG';

UPDATE DS_STAGE
SET NUMERATOR_VALUE = 5
WHERE DRUG_CONCEPT_CODE = '871469_05152015'
	AND NUMERATOR_VALUE = 500
	AND NUMERATOR_UNIT = 'MG';

UPDATE DS_STAGE
SET NUMERATOR_VALUE = 1900
WHERE DRUG_CONCEPT_CODE = '280105_09151997'
	AND NUMERATOR_VALUE = 19000000
	AND NUMERATOR_UNIT = 'MG';

UPDATE DS_STAGE
SET amount_unit = 'G'
WHERE amount_unit = 'GR';

UPDATE DS_STAGE
SET amount_unit = 'MG'
WHERE amount_unit = 'O';

UPDATE DS_STAGE
SET NUMERATOR_UNIT = 'MG'
WHERE NUMERATOR_UNIT = 'O';

UPDATE DS_STAGE
SET BOX_SIZE = NULL,
	NUMERATOR_VALUE = 15
WHERE DRUG_CONCEPT_CODE = '601236_10012007';

UPDATE DS_STAGE
SET BOX_SIZE = NULL,
	NUMERATOR_VALUE = 250
WHERE DRUG_CONCEPT_CODE = '19576_01011972';

UPDATE DS_STAGE
SET BOX_SIZE = NULL,
	NUMERATOR_VALUE = 0.2
WHERE DRUG_CONCEPT_CODE = '758494_01012012';

UPDATE DS_STAGE
SET NUMERATOR_VALUE = 0.01
WHERE DRUG_CONCEPT_CODE = '561280_08012006';

UPDATE DS_STAGE
SET NUMERATOR_VALUE = 500
WHERE DRUG_CONCEPT_CODE = '307287_05151995';

UPDATE ds_stage
--remove tablet's denominators 
SET denominator_unit = NULL,
	denominator_value = NULL,
	AMOUNT_UNIT = NUMERATOR_UNIT,
	AMOUNT_VALUE = NUMERATOR_VALUE,
	NUMERATOR_VALUE = NULL,
	NUMERATOR_UNIT = NULL
WHERE drug_concept_code IN (
		SELECT fcc
		FROM grr_new_3 a
		JOIN DS_STAGE b ON drug_concept_code = fcc
		WHERE (
				PACK_DESC LIKE '%KAPS%'
				OR PACK_DESC LIKE '%TABL%'
				OR PACK_DESC LIKE '%PELLET%'
				)
			AND denominator_unit IS NOT NULL
			AND numerator_unit NOT IN ('DH','C','CH','D','TM','X','XMK')
		);

--creating table to improve dosages in inhalers
DROP TABLE IF EXISTS spray_upd;
CREATE TABLE spray_upd AS
SELECT a.*,
	b.INTL_PACK_FORM_DESC,
	INTL_PACK_STRNT_DESC
FROM ds_stage a
JOIN grr_new_3 b ON DRUG_CONCEPT_CODE = fcc
WHERE DRUG_CONCEPT_CODE IN (
		SELECT DRUG_CONCEPT_CODE
		FROM ds_stage
		WHERE numerator_unit = 'MCG'
			AND box_size IS NOT NULL
		)
	AND INTL_PACK_STRNT_DESC LIKE '%DOSE%';

UPDATE spray_upd
SET NUMERATOR_VALUE = NUMERATOR_VALUE * box_size,
	box_size = NULL
WHERE DRUG_CONCEPT_CODE IN (
		SELECT DRUG_CONCEPT_CODE
		FROM spray_upd
		WHERE substring(INTL_PACK_STRNT_DESC, '\d+')::FLOAT = NUMERATOR_VALUE
		);

UPDATE spray_upd
SET box_size = NULL
WHERE DENOMINATOR_UNIT = 'ACTUAT';

DELETE
FROM ds_stage
WHERE DRUG_CONCEPT_CODE IN (
		SELECT DRUG_CONCEPT_CODE
		FROM spray_upd
		);

INSERT INTO ds_stage (
	DRUG_CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	BOX_SIZE,
	AMOUNT_VALUE,
	AMOUNT_UNIT,
	NUMERATOR_VALUE,
	NUMERATOR_UNIT,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT
	)
SELECT DISTINCT DRUG_CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	BOX_SIZE,
	AMOUNT_VALUE,
	AMOUNT_UNIT,
	NUMERATOR_VALUE,
	NUMERATOR_UNIT,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT
FROM spray_upd;

DROP TABLE IF EXISTS ds_vol_upd;
CREATE TABLE ds_vol_upd AS
SELECT DISTINCT a.*,
	INTL_PACK_STRNT_DESC,
	ABS_STRNT_QTY,
	ABS_STRNT_UOM_CD,
	RLTV_STRNT_QTY
FROM ds_stage a
JOIN grr_new_3 ON drug_concept_code = fcc
JOIN drug_concept_stage d ON a.ingredient_concept_code = d.concept_code
	AND UPPER(d.concept_name) = UPPER(molecule)
WHERE AMOUNT_VALUE IS NOT NULL
	AND RLTV_STRNT_QTY IS NOT NULL
	AND ABS_STRNT_QTY != '%';

UPDATE ds_vol_upd
SET amount_unit = NULL,
	amount_value = NULL,
	NUMERATOR_VALUE = CASE 
		WHEN ABS_STRNT_UOM_CD = 'Y'
			THEN 1.75
		ELSE ABS_STRNT_QTY::FLOAT
		END,
	NUMERATOR_UNIT = CASE 
		WHEN ABS_STRNT_UOM_CD = 'Y'
			THEN 'MCG'
		WHEN ABS_STRNT_UOM_CD = 'K'
			THEN 'IU'
		ELSE ABS_STRNT_UOM_CD
		END,
	DENOMINATOR_UNIT = 'ML';

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_vol_upd
		);

INSERT INTO ds_stage (
	DRUG_CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	BOX_SIZE,
	AMOUNT_VALUE,
	AMOUNT_UNIT,
	NUMERATOR_VALUE,
	NUMERATOR_UNIT,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT
	)
SELECT DISTINCT DRUG_CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	BOX_SIZE,
	AMOUNT_VALUE,
	AMOUNT_UNIT,
	NUMERATOR_VALUE,
	NUMERATOR_UNIT,
	DENOMINATOR_VALUE,
	DENOMINATOR_UNIT
FROM ds_vol_upd;

UPDATE ds_stage
SET numerator_unit = 'MG',
	numerator_value = CASE 
		WHEN UPPER(denominator_unit) = 'MG'
			THEN (numerator_value / 100) * COALESCE(denominator_value, 1)
		WHEN UPPER(denominator_unit) = 'ML'
			THEN numerator_value * 10 * COALESCE(denominator_value, 1)
		ELSE numerator_value
		END
WHERE numerator_unit = '%';

DELETE
FROM DS_STAGE
WHERE DRUG_CONCEPT_CODE = '797966_02152012'
	AND DENOMINATOR_VALUE = 0.5;

DELETE
FROM DS_STAGE
WHERE DRUG_CONCEPT_CODE = '762378_02152012'
	AND DENOMINATOR_VALUE = 1.5;

DELETE
FROM DS_STAGE
WHERE DRUG_CONCEPT_CODE = '797968_02152012'
	AND DENOMINATOR_VALUE = 1.5;

DELETE
FROM DS_STAGE
WHERE DRUG_CONCEPT_CODE = '52184_03011974'
	AND NUMERATOR_VALUE = 350
	AND NUMERATOR_UNIT = 'MG';

--coal tar
--delete drugs with impossible dosages
DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE (
				LOWER(numerator_unit) IN ('g')
				AND LOWER(denominator_unit) IN ('ml')
				AND numerator_value / COALESCE(denominator_value, 1) > 1
				)
		);

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE (
				LOWER(numerator_unit) IN ('mg')
				AND LOWER(denominator_unit) IN (
					'ml',
					'g'
					)
				OR LOWER(numerator_unit) IN ('g')
				AND LOWER(denominator_unit) IN ('l')
				)
			AND numerator_value / COALESCE(denominator_value, 1) > 1000
		);

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE amount_unit IS NULL
			AND numerator_unit IS NULL
		);

--delete drugs with wrong units
DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE amount_unit IN ('--','LM','NR')
			OR numerator_unit IN ('--','LM','NR')
			OR denominator_unit IN ('--','LM','NR')
		);

--can't calculate dosages in parsed drugs
DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT fcc
		FROM grr_new_3
		WHERE molecule IN (
				SELECT ingr FROM ingr_parsing
				)
		);

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		'804437_01042013',
		'63186_01051969',
		'240215_10151995',
		'476978_12152003'
		);

DELETE
FROM ds_stage
WHERE drug_concept_code = '769391_10012008'
	AND denominator_value = 15100;

--due to liquid->solid update
DELETE
FROM DS_STAGE d
WHERE EXISTS (
		SELECT 1
		FROM DS_STAGE d_int
		WHERE d_int.drug_concept_code = d.drug_concept_code
			and d_int.ingredient_concept_code = d.ingredient_concept_code
			and d_int.box_size = d.box_size
			and d_int.amount_value = d.amount_value
			and d_int.amount_unit = d.amount_unit
			and d_int.numerator_value = d.numerator_value
			and d_int.numerator_unit = d.numerator_unit
			and d_int.denominator_value = d.denominator_value
			and d_int.denominator_unit = d.denominator_unit
			AND d_int.ctid > d.ctid
		);

--delete ingredients from IRS that were sumed up
DELETE
FROM internal_relationship_stage
WHERE (
		concept_code_1,
		concept_code_2
		) IN (
		SELECT drug_concept_code,
			ingredient_concept_code
		FROM DS_SUM_2
		WHERE COALESCE(AMOUNT_VALUE, NUMERATOR_VALUE) IS NULL
		);

TRUNCATE TABLE internal_relationship_stage;
INSERT INTO internal_relationship_stage
--drug to form
SELECT fcc,
	concept_code
FROM grr_form_2
WHERE fcc NOT IN (
		SELECT fcc
		FROM grr_pack_2
		)
UNION
--pack drug to form
SELECT c.concept_code,
	a.concept_code
FROM grr_form_2 a
JOIN grr_pack_2 b ON a.fcc = b.fcc
JOIN drug_concept_stage c ON UPPER(drug_name) = UPPER(c.concept_name)
UNION
--drug to bn
SELECT fcc,
	concept_code
FROM grr_bn_2
JOIN drug_concept_stage ON UPPER(bn) = UPPER(concept_name)
WHERE concept_class_id = 'Brand Name'
UNION
--pack_drug to bn
SELECT c.concept_code,
	d.concept_code
FROM grr_bn_2 a
JOIN grr_pack_2 b ON a.fcc = b.fcc
JOIN drug_concept_stage c ON UPPER(drug_name) = UPPER(c.concept_name)
JOIN drug_concept_stage d ON UPPER(bn) = UPPER(d.concept_name)
WHERE d.concept_class_id = 'Brand Name'
UNION
--drug to supp
SELECT fcc,
	concept_code
FROM grr_manuf
JOIN drug_concept_stage ON UPPER(PRI_ORG_LNG_NM) = UPPER(concept_name)
WHERE concept_class_id = 'Supplier'
UNION
--pack_drug to supp
SELECT c.concept_code,
	d.concept_code
FROM grr_manuf a
JOIN grr_pack_2 b ON a.fcc = b.fcc
JOIN drug_concept_stage c ON UPPER(drug_name) = UPPER(c.concept_name)
JOIN drug_concept_stage d ON UPPER(PRI_ORG_LNG_NM) = UPPER(d.concept_name)
--where d.concept_class_id='Supplier'
UNION
--drug to ingr
SELECT fcc,
	concept_code
FROM grr_ing_2
JOIN drug_concept_stage b ON UPPER(ingredient) = UPPER(concept_name)
	AND concept_class_id = 'Ingredient'
UNION
--pack to ing
SELECT c.concept_code,
	d.concept_code
FROM grr_pack_2 b
JOIN drug_concept_stage c ON UPPER(drug_name) = UPPER(c.concept_name)
JOIN drug_concept_stage d ON UPPER(molecule) = UPPER(d.concept_name);

--delete relationship to supplier from Drug Comp or Drug Forms
DELETE
FROM internal_relationship_stage
WHERE (
		concept_code_1,
		concept_code_2
		) IN (
		SELECT concept_code_1,
			concept_code_2
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Supplier'
		)
	AND concept_code_1 NOT IN (
		SELECT concept_code_1
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Dose Form'
		);

DELETE
FROM internal_relationship_stage
WHERE (
		concept_code_1,
		concept_code_2
		) IN (
		SELECT concept_code_1,
			concept_code_2
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Supplier'
		)
	AND concept_code_1 NOT IN (
		SELECT drug_concept_code
		FROM ds_stage
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = '52184_03011974'
	AND concept_code_2 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_name = 'Coal Tar'
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = '912928_07152016'
	AND concepT_code_2 IN (
		SELECT concept_code_2
		FROM drug_concepT_stage
		WHERE concept_name = 'Methyl-5-Aminolevulinic Acid'
		);

TRUNCATE TABLE pc_stage;
INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount,
	box_size
	)
SELECT DISTINCT fcc,
	concept_code,
	NULL::FLOAT,
	box_size::int4
FROM grr_pack_2 a
JOIN drug_concept_stage b ON a.DRUG_NAME = UPPER(b.concept_name);

TRUNCATE TABLE relationship_to_concept;
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT concept_code,
	'GRR',
	CONCEPT_id,
	precedence,
	NULL
FROM relationship_to_concept_old r
JOIN drug_concept_stage d ON UPPER(d.concept_name) = UPPER(r.concept_name)
UNION
SELECT concept_code,
	'GRR',
	CONCEPT_id_2,
	precedence,
	conversion_factor
FROM aut_unit_all_mapped
UNION
SELECT concept_code,
	'GRR',
	concept_id,
	precedence,
	NULL
FROM aut_form_1;

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence
	)
SELECT DISTINCT dcs.concept_code,
	'GRR',
	cc.concept_id,
	1
FROM drug_concept_stage dcs
JOIN concept cc ON LOWER(cc.concept_name) = LOWER(dcs.concept_name)
	AND cc.concept_class_id = dcs.concept_class_id
	AND cc.vocabulary_id LIKE 'RxNorm%'
LEFT JOIN relationship_to_concept cr ON dcs.concept_code = cr.concept_code_1
WHERE concept_code_1 IS NULL
	AND cc.invalid_reason IS NULL
	AND dcs.concept_class_id IN (
		'Ingredient',
		'Brand Name',
		'Dose Form',
		'Supplier'
		);

--delete invalid mappings
DELETE
FROM relationship_to_concept
WHERE concept_id_2 IN (
		SELECT concept_id
		FROM concept
		WHERE invalid_reason = 'D'
		);

--insert relationships to ATC
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence
	)
SELECT fcc,'GRR',c.concept_id,RANK() OVER (PARTITION BY fcc ORDER BY who_atc1_code DESC)
FROM (
	SELECT fcc,who_atc1_code
	FROM source_data_1
	UNION
	SELECT fcc,who_atc2_code
	FROM source_data_1
	UNION
	SELECT fcc,who_atc3_code
	FROM source_data_1
	UNION
	SELECT fcc,who_atc4_code
	FROM source_data_1
	UNION
	SELECT fcc,who_atc5_code
	FROM source_data_1
	) a
JOIN concept c ON c.concept_code = a.who_atc1_code
	AND vocabulary_id = 'ATC'
	AND invalid_reason IS NULL;

DROP TABLE IF EXISTS rtc_upd;
CREATE TABLE rtc_upd AS
SELECT concept_code_1,
	vocabulary_id_1,
	precedence,
	conversion_factor,
	c.concept_id_2
FROM relationship_to_concept a
JOIN devv5.concept b ON concept_id = a.concept_id_2
JOIN devv5.concept_relationship c ON concept_id = concept_id_1
WHERE b.invalid_reason IS NOT NULL
	AND relationship_id = 'Concept replaced by';

DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
		SELECT concept_code_1
		FROM rtc_upd
		);

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
FROM rtc_upd;

--updating ingredients that create duplicates after mapping to RxNorm
DROP TABLE IF EXISTS ds_sum_2;
CREATE TABLE ds_sum_2 AS
	WITH a AS (
			SELECT DISTINCT ds.drug_concept_code,
				ds.ingredient_concept_code,
				ds.box_size,
				ds.amount_value,
				ds.amount_unit,
				ds.numerator_value,
				ds.numerator_unit,
				ds.denominator_value,
				ds.denominator_unit,
				rc.concept_id_2
			FROM ds_stage ds
			JOIN ds_stage ds2 ON ds.drug_concept_code = ds2.drug_concept_code
				AND ds.ingredient_concept_code != ds2.ingredient_concept_code
			JOIN relationship_to_concept rc ON ds.ingredient_concept_code = rc.concept_code_1
			JOIN relationship_to_concept rc2 ON ds2.ingredient_concept_code = rc2.concept_code_1
			WHERE rc.concept_id_2 = rc2.concept_id_2
			)
SELECT drug_concept_code,
	MAX(ingredient_concept_code) OVER (
		PARTITION BY DRUG_CONCEPT_CODE,
		concept_id_2
		)::VARCHAR(255) AS ingredient_concept_code,
	box_size,
	SUM(amount_value) OVER (PARTITION BY drug_concept_code) AS amount_value,
	amount_unit::VARCHAR(255),
	SUM(NUMERATOR_VALUE) OVER (
		PARTITION BY drug_concept_code,
		concept_id_2
		) AS NUMERATOR_VALUE,
	numerator_unit::VARCHAR(255),
	denominator_value,
	denominator_unit::VARCHAR(255)
FROM a
UNION
SELECT drug_concept_code,
	ingredient_concept_code::VARCHAR(255),
	box_size,
	NULL AS amount_value,
	NULL::VARCHAR(255) AS amount_unit,
	NULL AS NUMERATOR_VALUE,
	NULL::VARCHAR(255) AS numerator_unitv,
	NULL AS denominator_value,
	NULL::VARCHAR(255) AS denominator_unit
FROM a
WHERE (drug_concept_code,ingredient_concept_code) NOT IN (
		SELECT drug_concept_code,MAX(ingredient_concept_code)
		FROM a
		GROUP BY drug_concept_code
		);

DELETE
FROM ds_stage
WHERE (drug_concept_code, ingredient_concept_code) IN (
		SELECT drug_concept_code, ingredient_concept_code
		FROM ds_sum_2
		);

INSERT INTO DS_STAGE (
	drug_concept_code,
	ingredient_concept_code,
	box_size,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
	)
SELECT DISTINCT drug_concept_code,
	ingredient_concept_code,
	box_size,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
FROM ds_sum_2
WHERE COALESCE(amount_value, numerator_value) IS NOT NULL;

--delete relationship to ingredients that we removed
DELETE
FROM internal_relationship_stage
WHERE (concept_code_1,concept_code_2) IN (
		SELECT drug_concept_code, ingredient_concept_code
		FROM ds_sum_2
		WHERE COALESCE(amount_value, numerator_value) IS NULL
		);

UPDATE drug_concept_stage
SET concept_name = REPLACE(REPLACE(concept_name, '  ', ' '), '(>)', '')
WHERE concept_code NOT IN (
		SELECT drug_concept_code
		FROM ds_stage
		)
	AND concept_class_id = 'Drug Product';

DROP TABLE IF EXISTS ds_stage_cnc;
CREATE TABLE ds_stage_cnc AS
SELECT CONCAT (denominator_value,' ',denominator_unit) AS quant,
	drug_concept_code,
	CONCAT (i.concept_name,' ',COALESCE(amount_value, numerator_value / COALESCE(denominator_value, 1)),' ',COALESCE(amount_unit, numerator_unit)) AS dosage_name
FROM ds_stage
JOIN drug_concept_stage i ON i.concept_code = ingredient_concept_code;

DROP TABLE IF EXISTS ds_stage_cnc2;
CREATE TABLE ds_stage_cnc2 AS
SELECT quant,
	drug_concept_code,
	string_agg(dosage_name, ' / ' ORDER BY DOSAGE_NAME ASC) AS dos_name_cnc
FROM ds_stage_cnc
GROUP BY quant,
	drug_concept_code;

DROP TABLE IF EXISTS ds_stage_cnc3;
CREATE TABLE ds_stage_cnc3 AS
SELECT quant,
	drug_concept_code,
	CASE 
		WHEN quant ~ '^\d.*'
			THEN CONCAT (quant,' ',dos_name_cnc)
		ELSE dos_name_cnc
		END AS strength_name
FROM ds_stage_cnc2;

DROP TABLE IF EXISTS rel_to_name;
CREATE TABLE rel_to_name AS
SELECT ri.*,
	d.concept_name,
	d.concept_class_id
FROM internal_relationship_stage ri
JOIN drug_concept_stage d ON concept_code = concept_code_2;

DROP TABLE IF EXISTS new_name;
CREATE TABLE new_name AS
SELECT DISTINCT c.drug_concept_code,
	CONCAT (
		strength_name,
		CASE 
			WHEN f.concept_name IS NOT NULL
				THEN CONCAT (' ',f.concept_name)
			ELSE NULL END,
		CASE 
			WHEN b.concept_name IS NOT NULL
				THEN CONCAT (' [',b.concept_name,']')
			ELSE NULL END,
		CASE 
			WHEN s.concept_name IS NOT NULL
				THEN CONCAT (' by ',s.concept_name)
			ELSE NULL END,
		CASE 
			WHEN ds.box_size IS NOT NULL
				THEN CONCAT (' Box of ',ds.box_size)
			ELSE NULL END
		) AS concept_name
FROM ds_stage_cnc3 c
LEFT JOIN rel_to_name f ON c.drug_concept_code = f.concept_code_1
	AND f.concept_class_id = 'Dose Form'
LEFT JOIN rel_to_name b ON c.drug_concept_code = b.concept_code_1
	AND b.concept_class_id = 'Brand Name'
LEFT JOIN rel_to_name s ON c.drug_concept_code = s.concept_code_1
	AND s.concept_class_id = 'Supplier'
LEFT JOIN ds_stage ds ON c.drug_concept_code = ds.drug_concept_code;

UPDATE drug_concept_stage a
SET concept_name = SUBSTR(n.concept_name, 1, 255)
FROM new_name n
WHERE n.drug_concept_code = a.concept_code

--up to rxfix
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT pack_concept_code
		FROM pc_stage
		);

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT drug_concept_code
		FROM pc_stage
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT pack_concept_code
		FROM pc_stage
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT drug_concept_code
		FROM pc_stage
		);

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM pc_stage
		);

TRUNCATE TABLE pc_stage;

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE numerator_unit IN ('DH','C','CH','D','TM','X','XMK')
			AND denominator_value IS NOT NULL
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE numerator_unit IN ('DH','C','CH','D','TM','X','XMK')
			AND denominator_value IS NOT NULL
		);

DELETE
FROM ds_stage
WHERE numerator_unit IN ('DH','C','CH','D','TM','X','XMK')
	AND denominator_value IS NOT NULL;