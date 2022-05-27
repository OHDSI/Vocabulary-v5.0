--! OUTDATED!

DROP TABLE IF EXISTS drugs;
CREATE TABLE drugs AS
SELECT DISTINCT fo_prd_id,
	a.prd_name,
	a.mast_prd_name,
	a.dosage,
	a.unit,
	a.dosage2,
	a.unit2,
	a.mol_eid,
	a.mol_name,
	b.mol_name as mol_name_2,
	atccode,
	atc_name,
	nfc_code,
	manufacturer
FROM fo_product_1_vs_2 a
FULL OUTER JOIN drug_mapping_1_vs_2 b ON a.prd_eid = b.prd_eid;


--next manipulation requires correct numbers--
UPDATE drugs
SET PRD_NAME = replace(PRD_NAME, ',', '.')
WHERE PRD_NAME IS NOT NULL;

DROP TABLE IF EXISTS drugs_3;
CREATE TABLE drugs_3 AS
SELECT a.fo_prd_id,
	a.prd_name,
	a.mast_prd_name,
	dosage_as_text as dosage,
	b.unit,
	dosage2_as_text as dosage2,
	unit_id2 as unit2,
	a.mol_eid,
	a.mol_name,
	b.manufacturer,
	b.nfc_code,
	a.atccode,
	atc_name
FROM sources.aus_fo_product_3 a
LEFT JOIN sources.aus_drug_mapping_3 b ON a.prd_eid = b.prd_eid;
CREATE INDEX idx_fo_prd_id ON drugs_3 (fo_prd_id);
ANALYZE drugs_3;

UPDATE DRUGS
SET MANUFACTURER = (
		SELECT MANUFACTURER
		FROM DRUGS_3
		WHERE DRUGS_3.FO_PRD_ID = DRUGS.FO_PRD_ID
		);

UPDATE DRUGS
SET ATCCODE = (
		SELECT ATCCODE
		FROM DRUGS_3
		WHERE DRUGS_3.FO_PRD_ID = DRUGS.FO_PRD_ID
			AND DRUGS_3.ATCCODE NOT IN (
				'IMIQUIMOD',
				'-1',
				'??'
				)
		);

INSERT INTO DRUGS (
	fo_prd_id,
	prd_name,
	mast_prd_name,
	dosage,
	unit,
	dosage2,
	unit2,
	mol_eid,
	mol_name,
	atccode,
	atc_name,
	nfc_code,
	manufacturer
	)
SELECT fo_prd_id,
	prd_name,
	mast_prd_name,
	dosage,
	unit,
	dosage2,
	unit2,
	mol_eid,
	mol_name,
	atccode,
	atc_name,
	nfc_code,
	manufacturer
FROM drugs_3
WHERE fo_prd_id NOT IN (
		SELECT fo_prd_id
		FROM drugs
		);

INSERT INTO drugs (
	fo_prd_id,
	prd_name,
	mast_prd_name,
	dosage,
	unit,
	dosage2,
	unit2,
	mol_eid,
	mol_name,
	atccode,
	atc_name,
	manufacturer
	)
SELECT fo_prd_id,
	prd_name,
	mast_prd_name,
	dosage,
	unit,
	dosage2,
	unit2,
	mol_eid,
	mol_name,
	atccode,
	atc_name,
	manufacturer_name
FROM au_lpd
WHERE fo_prd_id NOT IN (
		SELECT fo_prd_id
		FROM drugs
		);

UPDATE drugs
SET MOL_NAME = REPLACE(mol_name, '"', '');

UPDATE drugs
SET mol_name = NULL
WHERE mol_name LIKE '%INIT%';


DROP TABLE IF EXISTS drugs_update_1;
CREATE TABLE drugs_update_1 AS
SELECT DISTINCT a.fo_prd_id,
	a.prd_name,
	a.mast_prd_name,
	a.dosage,
	a.unit,
	a.dosage2,
	a.unit2,
	b.mol_eid,
	b.mol_name,
	a.mol_name_2,
	a.atccode,
	a.atc_name,
	a.nfc_code,
	a.manufacturer
FROM drugs a
JOIN drugs b ON a.fo_prd_id != b.fo_prd_id
	AND a.prd_name = b.prd_name
	AND b.mol_name IS NOT NULL
	AND a.mol_name IS NULL;

/*
drop table drugs_update_2;
create table drugs_update_2 as
select distinct a.FO_PRD_ID,a.PRD_NAME,a.MAST_PRD_NAME,a.DOSAGE,a.UNIT,a.DOSAGE2,a.UNIT2,b.MOL_EID,b.MOL_NAME,A.MOL_NAME_2,b.ATCCODE,b.ATC_NAME,b.NFC_CODE,a.MANUFACTURER
from drugs a join
drugs b on a.fo_prd_id!=b.fo_prd_id and 
regexp_replace(a.prd_name, '(TABS|CAPS|VIAL|ACCUHALER|SOLUTION|JELLY|UNSPECIFIED|SUBLINGUAL|GEL|SYRUP|TOPICAL|CREAM|PATCH|TRANSD|DROPS|SUPP|AMP|\d).*','','g')=regexp_replace(b.prd_name, '(TABS|CAPS|VIAL|ACCUHALER|SOLUTION|JELLY|UNSPECIFIED|SUBLINGUAL|GEL|SYRUP|TOPICAL|CREAM|PATCH|TRANSD|DROPS|SUPP|AMP|\d).*','','g') 
and b.mol_name is not null and a.mol_name is null and a.fo_prd_id not in (select fo_prd_id from drugs_update_1)
;
*/
DELETE
FROM drugs
WHERE fo_prd_id IN (
		SELECT fo_prd_id
		FROM drugs_update_1
		);

INSERT INTO drugs
SELECT *
FROM drugs_update_1;

UPDATE drugs
SET PRD_NAME = replace(PRD_NAME, ',', '.')
WHERE PRD_NAME IS NOT NULL;

UPDATE drugs
SET PRD_NAME = REPLACE(PRD_NAME, '"', '');

DROP TABLE IF EXISTS non_drug;
CREATE TABLE non_drug AS
SELECT DISTINCT *
FROM drugs
WHERE ATCCODE IN (
		'V01AA07',
		'V03AK',
		'V04B',
		'V04CL',
		'V04CX',
		'V20',
		'D02A',
		'D02AD',
		'D09A',
		'D02AX',
		'D02BA',
		'D02AC'
		)
	OR ATCCODE LIKE 'V06%'
	OR ATCCODE LIKE 'V07%';

INSERT INTO non_drug
SELECT *
FROM drugs
WHERE PRD_NAME ~ '^TENA |S(\S)?26|STOCKING|ACCU-CHEK|ACCUTREND|STRIPS|WIPES|REMOVER|LOZENGE|KCAL|NUTRISION|BREATH-ALERT|CHAMBER|\sSTRP|REMOVAL|GAUZE|SUPPLY|PROTECTORS|SOUP|DRESS|CLEANSER|BANDAGE|BEVERAGE|RESOURCE|WEIGHT|ENDURA OPTIMIZER|UNDERWEAR|\sSTRP|\sROLL|\sKCAL|\sGAUZE|LENS\sPLUS|LEUKOPLAST|[^IN]TEST[^O]'
	AND fo_prd_id NOT IN (
		SELECT fo_prd_id
		FROM non_drug
		);

INSERT INTO non_drug
SELECT *
FROM drugs
WHERE PRD_NAME ~ 'CHEK|BIOTENE|CALOGEN|CETAPHIL|ENSURE|FREESTYLE|HAMILTON|LUBRI|MEDISENSE|CARESENS'
	AND fo_prd_id NOT IN (
		SELECT fo_prd_id
		FROM non_drug
		);

INSERT INTO non_drug
SELECT *
FROM drugs
WHERE (
		MAST_PRD_NAME LIKE '%SUN%'
		OR MAST_PRD_NAME LIKE '%ACCU-CHEK%'
		OR MAST_PRD_NAME LIKE '%ACCUTREND%'
		)
	AND MAST_PRD_NAME NOT LIKE '%SELSUN%'
	AND fo_prd_id NOT IN (
		SELECT fo_prd_id
		FROM non_drug
		);

INSERT INTO non_drug
SELECT *
FROM drugs
WHERE mol_name ~ 'IUD|LEUCOCYTES|AMIDOTRIZOATE|BANDAGE';

INSERT INTO non_drug
SELECT *
FROM drugs
WHERE nfc_code ~ 'VZT|VGB|VGA|VZY|VEA|VEK|VZV'
	AND fo_prd_id NOT IN (
		SELECT fo_prd_id
		FROM non_drug
		);

INSERT INTO non_drug
SELECT *
FROM drugs
WHERE fo_prd_id::INT IN (
		58557,
		605075,
		19298,
		19308,
		25214,
		19317,
		586445,
		18816,
		33606,
		2043629,
		26893,
		2042567,
		2042566,
		2043068,
		2043069,
		2040332,
		2047035,
		2040625,
		588960,
		2040344,
		586387,
		2044122,
		588399,
		588398,
		2041031,
		606459,
		2050029,
		2041619,
		2048638,
		2048639,
		2048642,
		2042520,
		2042519,
		2040093,
		33512,
		2046954,
		2046955,
		2041294,
		2041373,
		2042857,
		591584,
		586298,
		602040,
		602041,
		2049426,
		588380,
		586462,
		586463,
		88178,
		586441,
		88159,
		88162,
		88175,
		88176,
		2047881,
		2044399,
		2044254,
		2047085,
		88083,
		2043833,
		34825,
		34959,
		587498,
		588222,
		588432,
		588424,
		2046588,
		58557,
		2044042,
		2045706,
		2045707,
		2047191,
		2047298,
		2045998,
		590969,
		591417,
		32989,
		2045897,
		605545,
		2041685,
		2046849,
		2045269,
		33112,
		2041739,
		603439,
		603440,
		2043567,
		2039962,
		2044712,
		34497,
		2045725,
		2050730,
		2046632,
		2042292,
		2045041,
		2041396,
		2043896,
		2040362,
		2044727,
		2041375,
		2045040,
		2046267,
		2045462,
		2043020,
		22186,
		592070,
		592243,
		4454,
		4455,
		2042477,
		34639,
		2046505,
		2048158,
		3003,
		33861,
		2040442,
		2040443,
		2043132,
		588198,
		588199,
		588213,
		588214,
		2045537,
		2047003,
		2048682,
		2043029,
		2042110,
		2049484,
		6066,
		587833,
		590535,
		2050503,
		587949,
		588204,
		588205,
		587822,
		588207,
		2046494,
		586306,
		2045668,
		2043843,
		2042620,
		591627,
		605549,
		605550,
		604390,
		29291,
		2044402,
		2042870,
		586959,
		586960,
		2045457,
		2047083,
		2045458,
		2042724,
		33648,
		605548,
		22807,
		38919,
		587834,
		587835,
		587668,
		586460,
		586459,
		587836,
		2046938,
		2048554,
		2048555,
		2046645,
		2044964,
		2046937,
		586368,
		28263,
		8530,
		588350,
		596295,
		2043217,
		2047595,
		2041520,
		2042851,
		2041971,
		27633,
		588092,
		587563,
		2043458,
		588334,
		588333,
		588295,
		2047098,
		598487,
		2048439,
		27415,
		2043415,
		586377,
		588215,
		2045741,
		591367,
		11670,
		2049800,
		2046104,
		2925,
		38896,
		32110,
		588306,
		588282,
		2046493,
		2048763,
		2047433,
		592031,
		2044126,
		2042908,
		2047034,
		2050601,
		37372,
		33939,
		586570,
		587894,
		588200,
		2048608,
		2041798,
		588211,
		2047523,
		2045932,
		16247,
		34561,
		2048156,
		2047403,
		2045943,
		606044,
		2044652,
		5591,
		5593,
		28013,
		28012,
		36452,
		33759,
		589922,
		605083,
		2050328,
		605082,
		2050837,
		34352,
		2042067,
		2040345,
		2042767,
		2049047,
		2049049,
		2047087,
		2044051,
		2044052,
		2050217,
		2050218,
		589143,
		589144,
		2041193,
		592231,
		588373,
		2050051,
		2049662,
		2046869,
		2045261,
		2043307,
		34531,
		2042894,
		605664,
		586308,
		6429,
		2044683,
		2046806,
		2049377,
		2047681,
		34335,
		34339,
		34336,
		2040363,
		2046825,
		588549,
		588548,
		2042119
		)
	AND fo_prd_id NOT IN (
		SELECT fo_prd_id
		FROM non_drug
		);

ALTER TABLE non_drug RENAME COLUMN fo_prd_id TO concept_code;

UPDATE drugs
SET unit = 'MCG'
WHERE unit = 'µg';

UPDATE drugs
SET unit2 = 'MCG'
WHERE unit2 = 'µg';

UPDATE drugs
SET MOL_NAME = 'DIPHTHERIA VACCINE/PERTUSSIS VACCINE/POLIOMYELITIS VACCINE - INACTIVATED/TETANUS VACCINE'
WHERE fo_prd_id IN (
		'590079',
		'595524',
		'590082',
		'587459',
		'587464'
		);

UPDATE drugs
SET MOL_NAME = 'CITRIC ACID/MACROGOL/MAGNESIUM OXIDE/PICOSULFATE/POTASSIUM CHLORIDE/SODIUM CHLORIDE/SODIUM SULFATE'
WHERE fo_prd_id = '586468';

UPDATE drugs
SET MOL_NAME = 'MENINGOCOCCAL VACCINE'
WHERE fo_prd_id = '586227';

UPDATE drugs
SET MOL_NAME = 'AVENA SATIVA/CAFFEINE/CAMELLIA SINENSIS/CARNITINE/CHROMIUM/GARCINIA QUAESITA/GYMNEMA SYLVESTRE/THIOCTIC ACID'
WHERE fo_prd_id = '59136';

UPDATE drugs
SET MOL_NAME = 'CALCIUM/COPPER/ELEUTHEROCOCCUS SENTICOSUS/GINKGO BILOBA/IODINE/MANGANESE/NICOTINIC ACID/PANTOTHENATE/PYRIDOXINE/RIBOFLAVIN/SELENIUM/THIAMINE/ZINC'
WHERE fo_prd_id = '24024';

UPDATE drugs
SET MOL_NAME = 'ALLIUM SATIVUM/ASCORBATE/BETACAROTENE/BIOFLAVONOIDS/CYSTEINE/MANGANESE/NICOTINAMIDE/PANTOTHENATE/PYRIDOXINE/RETINOL/RIBOFLAVIN/SELENIUM/THIOCTIC ACID/TOCOPHEROL/ZINC'
WHERE fo_prd_id = '33708';

UPDATE DRUGS
SET FO_PRD_ID = TRIM(FO_PRD_ID),
	PRD_NAME = TRIM(PRD_NAME),
	MAST_PRD_NAME = TRIM(MAST_PRD_NAME),
	DOSAGE = TRIM(DOSAGE),
	UNIT = TRIM(UNIT),
	DOSAGE2 = TRIM(DOSAGE2),
	MOL_NAME = TRIM(MOL_NAME),
	ATCCODE = TRIM(ATCCODE),
	ATC_NAME = TRIM(ATC_NAME),
	NFC_CODE = TRIM(NFC_CODE),
	MANUFACTURER = TRIM(MANUFACTURER);

UPDATE drugs
SET prd_name = 'SALICYLIC ACID & SULFUR AQUEOUS CREAM APF'
WHERE mast_prd_name = 'SALICYLIC ACID & SULFUR AQUEOUS CREAM APF';

--ingredients
DROP TABLE IF EXISTS ingredients;
CREATE TABLE ingredients AS
SELECT DISTINCT unnest(regexp_matches(MOL_NAME, '[^/]+', 'g')) AS ingredient,
	FO_PRD_ID
FROM DRUGS
WHERE MOL_NAME IS NOT NULL;

INSERT INTO ingredients
SELECT DISTINCT upper(concept_name),
	fo_prd_id
FROM i_map_postprocess
WHERE fo_prd_id NOT IN (
		SELECT fo_prd_id
		FROM ingredients
		);

UPDATE ingredients
SET INGREDIENT = 'NICOTINAMIDE'
WHERE INGREDIENT = 'NICOTINIC ACID';

DELETE
FROM ingredients
WHERE fo_prd_id IN (
		SELECT fo_prd_id
		FROM no_ds_done
		WHERE ingredient_name IS NOT NULL
		);

INSERT INTO ingredients
SELECT DISTINCT ingredient_name,
	fo_prd_id
FROM no_ds_done
WHERE ingredient_name IS NOT NULL;

DELETE
FROM ingredients
WHERE trim(replace(ingredient, '#', '')) IN (
		SELECT trim(replace(concept_name, '#', ''))
		FROM RELATIONSHIP_MANUAL_INGREDIENT_DONE
		WHERE DUMMY IS NOT NULL
		);

/*
create table ingr_2 as (select prd_name, regexp_replace(trim(regexp_replace(regexp_replace(regexp_replace(prd_name,'(CAPSULE|DEVICE|VOLUME|NEBUHALER|SPRAY|CREAM|LOZENGE|MENT|TABLET|NASAL|ROTAHALER|ELEXIR|DROP|INHALER|DAILY|AQ. SUS|EXTRA|OINT|SHAMPOO|BABY|GEL|POWDER|FACE|WASH|SYRUP|AMPOULE|OILY|LIQUI|POWDE|CLEAR SKIN ACNE CONTROL|KIT|ALLERGEN EXTRACTS|BAR|SOAP|CAPSU|SOLUTION|EYE|ORAL|LIQUID|SUPPOS.|AQUEOUS|BP|BPC|APF|LOTION|OINTMENT|SPINHALER)?'),'\s-.*'),'[0-9].*')),'\(.*')
as ingredient,fo_prd_id
from drugs where mol_name is null and fo_prd_id not in (select fo_prd_id from non_drug));
delete ingr_2 where ingredient like '%MULTI%' or ingredient like '%DERM%' or ingredient like '%NEILMED%' or ingredient like '%PAIN%' or ingredient like '%PANADOL%' or ingredient like '%/%' or ingredient like '%RELIEF%'  or ingredient like '%PREGNANCY%'  or ingredient like '%STRESS%'
;
--ingredeients3-manual table from ingr_2
*/

CREATE TABLE dose_form_test AS

SELECT fo_prd_id AS fo_prd_id,
	prd_name AS prd_name,
	nfc_code AS nfc_code,
	(regexp_matches(prd_name, 'CFC-free inhaler|Capsule|IV dressings|Rectube|adhesive plaster|alcoholic lotion|ampoule|applicator|bandage|bath emulsion|bath oil', 'i')) [1] AS dose_form
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'bath solution|buccal tablet|caplet|capsule|chesty cough linctus|chewable tablet|chewing gum|collodion BP|colourless cream|cream|crystal', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'dental lacquer|diabetic linctus|disks plus disk inhaler|disks refill|dispersible tablet|douche plus fitting|dropper|dry powder spray|dusting powder', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'ear drop|ear spray|effervescent granule|effervescent tablet|emollient cream|eye drop|eye irrigation solution|eye/ear ointment|film|foam|gastro-resistant capsule', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'gastro-resistant tablet|gauze|gauze swab|gel kit|gel plus dressing|gel-forming eye drop|granule|granule.* for suspension|implant|infant suppositorie', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'infusion .*powder for reconstitution|infusion plus diluent|inhalation|inhalation capsule|inhalator|inhaler|inhaler plus spacer|inhaler refill|inhaler solution', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'injection|injection powder|injection .*powder for reconstitution|injection cartridge|injection plus diluent|injection refills|injection solution|injection vial', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'insufflator|intra articular/ intradermal injection|intra articular/intramuscular injection|intra-muscular injection|intramuscular injection .*pdr for recon.*|intranasal solution', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'intrathecal injection|intravenous infusion|intravenous infusion concentrate|intravenous infusion plus buffer|intravenous solution|irrigation solution|junior capsule|junior lozenge', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'linctus|lip protector|lipocream|liquid|lotio-gel|lozenge|maintenance set|matrigel capsule|melt tablet|modified release granule|modified release tablet|mouthwash and gargle', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'multi-dose vial|nail lacquer|nasal gel|nasal ointment|nebuliser solution|nose drop|nose gel|ocular insert|oil|oily cream|oily injection|ointment|ointment & suppositorie|ophthalmic solution', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'oral drop|oral emulsion|oral liquid|oral paint|oral powder|oral syringe|oro-dispersible film|paediatric capsule|paediatric drop|paediatric mixture|paediatric solution', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'paediatric sugar free suspension|paediatric suspension|paediatric syrup|paint|paper|patche|pellet|periodontal gel|pessary plus cream|plaster|poultice|powder|powder for reconstitution', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'prefilled pen|rectal foam|rectal solution|retention enema|sachet|scalp and skin cleanser solution|scalp application|scalp lotion|scalp solution|semi-solid|single dose injection vial', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'single dose unit eye drop|single dose unit eye gel|skin cleanser solution|soluble tablet|spincap|spray|spray application|spray solution|sterile solution|sterile suspension', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'sterile swab|stocking|subcutaneous injection|sublingual tablet|sugar free chewable tablet|sugar free dispersible tablet|sugar free granule|sugar free linctus|sugar free lozenge', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'sugar free mixture|sugar free paediatric linctus|sugar free paediatric syrup|sugar free suspension|supposit|surgical scrub|swab|tablet|tablet pack|tablet .* pessaries|tablet.* plus granule', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, '\stampon|throat spray|toothpaste|topical gel|topical liquid|tube|unit dose blister|unit dose vial|vaginal capsule|vaginal cleansing kit|vaginal cream|vaginal ring|vial|vitrellae', 'i')) [1]
FROM drugs

UNION

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'volatile liquid|vortex metered dose inhaler|wax|PENFILL.*INJECTION', 'i')) [1]
FROM drugs;

INSERT INTO dose_form_test
SELECT fo_prd_id,
	prd_name,
	nfc_code,
	(regexp_matches(prd_name, 'SUPP\s|SUPPO|CAPSULE|SYRUP|SYRINGE|ORALDISTAB|AMPOULE|AUTOHA|INHALE|HALER|CHEW.*GUM|CHEW.*TAB|DISP.*TAB|TABSULE|AUTOINJ|\sPENFILL|PRE-FILLED|SUSPEN|REPETAB|LOTION|VAG.*GEL|GEL.*ORAL|ORAL.*GEL|EYE.*GEL', 'i')) [1]
FROM drugs

UNION ALL

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	substring(prd_name, 'EYE.*OINT|ANAL.*\sOINT|EAR/*\sOINT|\sOINT|\sORAL.*SOL|\sSOL.*ORAL|\sMICROENEMA|\sENEMA|\sNASAL.*DROP|\sDROP|EYE.*DRO|\sEAR.*DRO|\sMOUTHWASH|\sMOUTHWASH.*SOL|\sELIXI|PATCH|\sTABL|\sSHAMPOO|CAPSEAL|\sINJ')
FROM drugs

UNION ALL

SELECT fo_prd_id,
	prd_name,
	nfc_code,
	substring(PRD_NAME, 'NEB.*SOL|PESSARY|INFUSION|WAFER|LINIMENT|MIXTURE|CAPSU|TAB-\d+|\s.*ABLE.*TAB|SOLUTION|PASTE|\sPEN\s|GEL|\sSOLUT\s|\sPOWDE|\sCAP\s|\sPASTILE|\sLOZE\s|EMULSION|MOUTHRINSE|NASAL SPRAY|EYE/EAR DROP|SOFTGELCAP')
FROM drugs;

DELETE
FROM dose_form_test
WHERE dose_form IS NULL;

DELETE
FROM dose_form_test
WHERE fo_prd_id IN (
		SELECT concept_code
		FROM non_drug
		);

INSERT INTO dose_form_test
SELECT fo_prd_id,
	prd_name,
	nfc_code,
	substring(prd_name, '(\sSYR|EYE.*DR|SUSP|AERO|\sCRM|BALM|INH|CREA|ELIXIR|NASAL SPR|PRE.?FILL SYR|SUSP|CAP|AMP|TAB|SHAMPOO|LOZ|OINT|PENFILL)(S)?(\s|$)')
FROM drugs
WHERE fo_prd_id NOT IN (
		SELECT fo_prd_id
		FROM dose_form_test
		)
	AND substring(prd_name, '(\sSYR|EYE.*DRP|SUSP|AERO|\sCRM|BALM|INH|CREA|ELIXIR|NASAL SPR|PRE.?FILL SYR|SUSP|CAP|AMP|TAB|SHAMPOO|LOZ|OINT|PENFILL)(S)?(\s|$)') IS NOT NULL
	AND fo_prd_id NOT IN (
		SELECT concept_code
		FROM non_drug
		);

INSERT INTO dose_form_test
SELECT fo_prd_id,
	prd_name,
	nfc_code,
	substring(prd_name, '\sSYR|EYE.*DR|SUSP|AERO|\sCRM|BALM|INH|CREA|ELIXIR|NASAL SPR|SOLN')
FROM drugs
WHERE fo_prd_id NOT IN (
		SELECT fo_prd_id
		FROM dose_form_test
		)
	AND substring(prd_name, '\sSYR|EYE.*DRP|SUSP|AERO|\sCRM|BALM|INH|CREA|ELIXIR|NASAL SPR|SOLN') IS NOT NULL
	AND fo_prd_id NOT IN (
		SELECT concept_code
		FROM non_drug
		);

DELETE
FROM dose_form_test
WHERE fo_prd_id IN (
		SELECT fo_prd_id
		FROM pack_drug_product_2
		);

INSERT INTO dose_form_test (
	prd_name,
	dose_form
	)
SELECT DISTINCT prd_name,
	coalesce(substring(substring(upper(prd_name), '_.*'), 'CAP|TAB|CREAM|PATCH|POWDER|SACHET|SUSP|INJ'), substring(upper(prd_name), 'CAP|TABLET|CREAM|SYRUP|INJ|VAGINAL SUPPOSITORY'))
FROM pack_drug_product_2
WHERE coalesce(substring(substring(upper(prd_name), '_.*'), 'CAP|TAB|CREAM|PATCH|POWDER|SACHET|SUSP|INJ'), substring(upper(prd_name), 'CAP|TABLET|CREAM|SYRUP|INJ|VAGINAL SUPPOSITORY')) IS NOT NULL;

UPDATE dose_form_test
SET dose_form = TRIM(upper(dose_form));

DELETE
FROM dose_form_test
WHERE dose_form IS NULL;

UPDATE dose_form_test
SET dose_form = 'TABLET'
WHERE dose_form LIKE 'TAB-%'
	OR dose_form = 'TABSULE'
	OR dose_form LIKE 'TABLET%'
	OR DOSE_FORM LIKE '%REPETAB%'
	OR DOSE_FORM LIKE '%TABL'
	OR DOSE_FORM ~ 'PAINT|TAB(S)?';

UPDATE dose_form_test
SET dose_form = 'EFFERVESCENT TABLET'
WHERE dose_form LIKE '%EFFERVESCENT%TABLET%';

UPDATE dose_form_test
SET dose_form = 'CHEWABLE TABLET'
WHERE dose_form LIKE '%CHEW%TAB%'
	OR DOSE_FORM LIKE '%ABLE%TAB%';

UPDATE dose_form_test
SET dose_form = 'CHEWING GUM'
WHERE dose_form LIKE '%CHEW%GUM%';

UPDATE dose_form_test
SET dose_form = 'DISPERSIBLE TABLET'
WHERE dose_form LIKE '%DISP%TAB%'
	OR DOSE_FORM LIKE '%ORALDISTAB%';

UPDATE dose_form_test
SET dose_form = 'SUPPOSITORY'
WHERE dose_form LIKE '%SUPP%';

UPDATE dose_form_test
SET dose_form = 'NASAL DROP'
WHERE dose_form LIKE '%NASAL RELIEF SALINE NASAL DROP%'
	OR dose_form = 'NOSE DROP';

UPDATE dose_form_test
SET dose_form = 'ORAL GEL'
WHERE dose_form LIKE '%ORAL %GEL%';

UPDATE dose_form_test
SET dose_form = 'CAPSULE'
WHERE dose_form LIKE '%CAPS%'
	OR dose_form = 'CAP'
	OR DOSE_FORM = 'SOFTGELCAP';

UPDATE dose_form_test
SET dose_form = 'INJECTION'
WHERE dose_form = 'INJ';

UPDATE dose_form_test
SET dose_form = 'EYE DROP'
WHERE dose_form LIKE '%EYE%DR'
	OR dose_form IN (
		'EYE DRP',
		'EYE DRPS',
		'EYE /DRP'
		)
	OR dose_form ~ 'EYE.*DR';

UPDATE dose_form_test
SET dose_form = 'EYE OINTMENT'
WHERE dose_form LIKE '%EYE%OINT';

UPDATE dose_form_test
SET dose_form = 'VAGINAL GEL'
WHERE dose_form LIKE '%VAG%GEL%';

UPDATE dose_form_test
SET dose_form = 'LOTION'
WHERE dose_form LIKE '%LOT%';

UPDATE dose_form_test
SET dose_form = 'ELIXIR'
WHERE dose_form LIKE '%ELIXI%';

UPDATE dose_form_test
SET dose_form = 'SOLUTION'
WHERE dose_form = 'SOLUTION'
	OR dose_form = 'SOLUT'
	OR dose_form = 'SOLN';

UPDATE dose_form_test
SET dose_form = 'ORAL SOLUTION'
WHERE dose_form LIKE '%SOLUTION%ORAL%'
	OR dose_form = 'ORAL SOL';

UPDATE dose_form_test
SET dose_form = 'ORAL GEL'
WHERE dose_form = 'GEL ORAL'
	OR dose_form = 'GEL-ORAL';

UPDATE dose_form_test
SET dose_form = 'INHALATION'
WHERE dose_form = 'INHALATOR'
	OR dose_form = 'INHALE'
	OR dose_form = 'HALER'
	OR dose_form = 'INH'
	OR dose_form = 'AERO';

UPDATE dose_form_test
SET dose_form = 'ENEMA'
WHERE dose_form LIKE '%ENEMA%';

UPDATE dose_form_test
SET dose_form = 'INHALATION SOLUTION'
WHERE dose_form LIKE '%NEB%SOL%';

UPDATE dose_form_test
SET dose_form = 'PENFILL INJECTION'
WHERE dose_form LIKE '%PENFILL%';

UPDATE dose_form_test
SET dose_form = 'OINTMENT'
WHERE dose_form = 'OINT';

UPDATE dose_form_test
SET dose_form = 'LOZENGE'
WHERE dose_form LIKE 'LOZ%';

UPDATE dose_form_test
SET dose_form = 'ORAL DROP'
WHERE dose_form = 'ORAL DROPS ORAL SOL';

UPDATE dose_form_test
SET dose_form = 'PATCH'
WHERE dose_form = 'PATCHE';

UPDATE dose_form_test
SET dose_form = 'POWDER'
WHERE dose_form = 'POWDE';

UPDATE dose_form_test
SET dose_form = 'ORAL GEL'
WHERE dose_form = 'ORALBALANCE DRY MOUTH MOISTURISING GEL';

UPDATE dose_form_test
SET dose_form = 'AMPOULE'
WHERE dose_form LIKE 'AMP%';

UPDATE dose_form_test
SET dose_form = 'PRE-FILLED'
WHERE dose_form IN (
		'PRE-FILL SYR',
		'PREFILL SYR'
		);

UPDATE dose_form_test
SET dose_form = 'SUSPEN'
WHERE dose_form = 'SUSP';

UPDATE dose_form_test
SET dose_form = 'CREAM'
WHERE dose_form = 'CREA'
	OR dose_form = 'CRM';

UPDATE dose_form_test
SET dose_form = 'NASAL SPRAY'
WHERE dose_form = 'NASAL SPR';

UPDATE dose_form_test
SET dose_form = 'AUTOHALER'
WHERE dose_form LIKE 'AUTOHA%';

UPDATE dose_form_test
SET dose_form = 'SYRINGE'
WHERE dose_form = 'SYR';

UPDATE dose_form_test
SET dose_form = 'EYE/EAR DROP'
WHERE fo_prd_id IN (
		'16913',
		'19667',
		'23512'
		);

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '11899'
	AND DOSE_FORM = 'SACHET';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '11898'
	AND DOSE_FORM = 'SACHET';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '11897'
	AND DOSE_FORM = 'SACHET';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '13542'
	AND DOSE_FORM = 'SACHET';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '17923'
	AND DOSE_FORM = 'SACHET';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '17915'
	AND DOSE_FORM = 'SACHET';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '603129'
	AND DOSE_FORM = 'CAPLET';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '36452'
	AND DOSE_FORM = 'SACHET';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '32915'
	AND DOSE_FORM = 'SACHET';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '25543'
	AND DOSE_FORM = 'LIQUID';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '24931'
	AND DOSE_FORM = 'POWDER';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '22528'
	AND DOSE_FORM = 'SACHET';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '2143'
	AND DOSE_FORM = 'LIQUID';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '19938'
	AND DOSE_FORM = 'LIQUID';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '19937'
	AND DOSE_FORM = 'LIQUID';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '604426'
	AND DOSE_FORM = 'SACHET';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '6286'
	AND DOSE_FORM = 'LIQUID';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '17982'
	AND DOSE_FORM = 'POWDER';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '15975'
	AND DOSE_FORM = 'POWDER';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '29539'
	AND DOSE_FORM = 'OIL';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '2043413'
	AND DOSE_FORM = 'OINTMENT';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '2044107'
	AND DOSE_FORM = 'OINTMENT';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '2040040'
	AND DOSE_FORM = 'OIL';

DELETE
FROM DOSE_FORM_TEST
WHERE FO_PRD_ID = '2050048'
	AND DOSE_FORM = 'SACHET';


DELETE
FROM dose_form_test d
WHERE EXISTS (
		SELECT 1
		FROM dose_form_test d_int
		WHERE coalesce(d_int.FO_PRD_ID, 'X') = coalesce(d.FO_PRD_ID, 'X')
			AND coalesce(d_int.NFC_CODE, 'X') = coalesce(d.NFC_CODE, 'X')
			AND d_int.PRD_NAME = d.PRD_NAME
			AND d_int.DOSE_FORM = d.DOSE_FORM
			AND d_int.ctid > d.ctid
		);


DROP TABLE IF EXISTS dose_form_test_2;
CREATE TABLE dose_form_test_2 AS
SELECT A.FO_PRD_ID,
	A.PRD_NAME,
	A.NFC_CODE,
	A.DOSE_FORM
FROM dose_form_test A
INNER JOIN dose_form_test B ON A.FO_PRD_ID = B.FO_PRD_ID
INNER JOIN dose_form_test C ON A.FO_PRD_ID = C.FO_PRD_ID
WHERE LENGTH(A.DOSE_FORM) > LENGTH(B.DOSE_FORM)
	AND LENGTH(A.DOSE_FORM) > LENGTH(C.DOSE_FORM)
	AND B.DOSE_FORM != C.DOSE_FORM
	AND A.FO_PRD_ID IN (
		SELECT FO_PRD_ID
		FROM dose_form_test
		GROUP BY FO_PRD_ID
		HAVING COUNT(FO_PRD_ID) > 2
		)

UNION

SELECT A.FO_PRD_ID,
	A.PRD_NAME,
	A.NFC_CODE,
	A.DOSE_FORM
FROM dose_form_test A
INNER JOIN dose_form_test B ON A.FO_PRD_ID = B.FO_PRD_ID
WHERE LENGTH(A.DOSE_FORM) > LENGTH(B.DOSE_FORM)
	AND A.FO_PRD_ID IN (
		SELECT FO_PRD_ID
		FROM dose_form_test
		GROUP BY FO_PRD_ID
		HAVING COUNT(FO_PRD_ID) = 2
		);

DELETE
FROM dose_form_test
WHERE FO_PRD_ID IN (
		SELECT FO_PRD_ID
		FROM dose_form_test_2
		);

INSERT INTO dose_form_test
SELECT *
FROM dose_form_test_2;

UPDATE dose_form_test
SET dose_form = 'TABLET'
WHERE fo_prd_id = '2044386';

--bn
DROP TABLE IF EXISTS bn;
CREATE TABLE bn AS
SELECT DISTINCT FO_PRD_ID,
	MAST_PRD_NAME,
	MAST_PRD_NAME AS new_name
FROM drugs
WHERE NOT MAST_PRD_NAME ~ '(\D)+/(\D)+'
	AND FO_PRD_ID NOT IN (
		SELECT concept_code
		FROM non_drug
		)
	AND MAST_PRD_NAME IS NOT NULL;

UPDATE bn
SET new_name = regexp_replace(new_name, '\(.*\)', '', 'g')
WHERE new_name ~ '\(.*\)';

UPDATE bn
SET new_name = regexp_replace(new_name, '[ ,]+(Eye drops|solution|Injection|syrup|SURGICAL SCRUBSWABSTICKS|ANTISEPTIC||VAGINAL|CHEWABLE|TINCTURE|ointment|FILM-COATED TABLETS|spray|nasal|inhaler|dressing|sterile|sachet|lotion|oily|Tablet|vial|Suspension|Cream|Suppository|capsule).*$', '', 'gi')
WHERE new_name ~* '[ ,]+(Eye drops|solution|Injection|syrup|SURGICAL SCRUBSWABSTICKS|ANTISEPTIC|ointment|FILM-COATED TABLETS|VAGINAL|spray|TINCTURE|CHEWABLE|nasal|inhaler|dressing|sterile|sachet|lotion|oily|Tablet|vial|Suspension|Cream|Suppository|capsule).*$'
	AND NOT new_name ~* '[ ,]+(Eye drops|solution|Injection|syrup|SURGICAL SCRUBSWABSTICKS|CHEWABLE|ANTISEPTIC|ointment|VAGINAL|TINCTURE|FILM-COATED TABLETS|spray|nasal|inhaler|dressing|sterile|sachet|lotion|oily|Tablet|vial|Suspension|Cream|Suppository|capsule).*(1[ \-]{0,3}A[ \-]{0,3}BLACKMORES|GENERICHEALTH|JENAPHARM|Actavis|Pharma|Berlin-Chemie|Braun|Baxter|Rotexmedica|EGO|Ratiopharm|Hexal|medica M|APOTEX|ANTEMET-EBS|ASTRAZENECA|SANODOZ|ZENITH|SUSTAIN|PFIZER|ASCENT PHARMA|EGO|VALEANT|MAYNE PHARMA).*$';

DELETE
FROM bn
WHERE new_name LIKE '%IRRIGATION%'
	OR new_name LIKE '%+%'
	AND NOT new_name ~ 'FESS|VITAPLEX|APTAMIL|HAMILTON|DIMETAPP|AQUASUN|FESS|BIO-|TUSSIN|CODRAL|CITRACAL|CENTRUM|SUDAFED|PANADOL|PRONOSAN|STREPSILS|PENT|NYAL|NUROFEN|OSTEVIT-D|SALINE|CALSOURCE|BEROCCA';

DELETE
FROM bn
WHERE (
		new_name LIKE '%ZINC %'
		OR new_name LIKE '% BP%'
		OR new_name LIKE '% APF'
		OR new_name LIKE '%VACCINE%'
		)
	AND new_name NOT LIKE '%[%'
	AND new_name NOT LIKE '%NATURE%';

UPDATE bn
SET new_name = regexp_replace(new_name, '-\s.*', '', 'g')
WHERE new_name LIKE '%- %'
	AND new_name NOT LIKE '%[%';

UPDATE bn
SET new_name = regexp_replace(new_name, '\s*\(*\d+[,./]*\d*[,./]*\d*[,./]*\d*\s*(UA|IR|Anti-Xa|Heparin-Antidot I\.U\.|Million IU|IU|Mio.? I.U.|Mega I.U.|SU|dpp|GBq|SQ-E|SE|ppm|mg|ml|g|%|I.U.|microg|mcg|Microgram|mmol|ug|u).*', '', 'gi')
WHERE new_name NOT LIKE '%[%';

DELETE
FROM bn
WHERE upper(trim(new_name)) IN (
		SELECT upper(trim(concept_name))
		FROM devv5.concept
		WHERE concept_class_id = 'Ingredient'
		);

DELETE
FROM bn
WHERE upper(trim(new_name)) IN (
		SELECT upper(trim(INGREDIENT))
		FROM INGREDIENTS
		);

DELETE
FROM bn
WHERE new_name IN (
		'MULTIVITAMIN',
		'VITAMIN',
		'ISOSORBIDE MONONITRATE-BC',
		'D3'
		);

DELETE
FROM bn
WHERE new_name ~ '(HYDROCHLORIDE|ACETATE|SULFATE|HYDROXIDE)';

DELETE
FROM bn
WHERE new_name IN (
		SELECT concept_name
		FROM RELATIONSHIP_MANUAL_BRAND_DONE
		WHERE DUMMY IS NOT NULL
		);

UPDATE bn
SET new_name = regexp_replace(new_name, '(MOUTHWASH|PESSARY|\sENEMA|\[.*\])', '', 'g')
WHERE new_name ~ '(MOUTHWASH|PESSARY|\sENEMA|\[.*\])';

UPDATE bn
SET new_name = 'MS CONTIN'
WHERE new_name = 'MS';

UPDATE bn
SET new_name = 'IN A WINK'
WHERE new_name = 'IN';

DELETE
FROM bn
WHERE upper(trim(new_name)) IN (
		SELECT upper(trim(concept_name))
		FROM devv5.concept
		WHERE concept_class_id = 'Ingredient'
		);

DELETE
FROM bn
WHERE upper(trim(new_name)) IN (
		SELECT upper(trim(INGREDIENT))
		FROM INGREDIENTS
		);

--manufacturer
DROP TABLE IF EXISTS manufacturer;
CREATE TABLE manufacturer AS
SELECT FO_PRD_ID,
	trim(manufacturer) manufacturer
FROM drugs
WHERE manufacturer != 'UNBRANDED'
	AND upper(manufacturer) <> 'GENERIC'
	AND manufacturer IS NOT NULL
	AND fo_prd_id NOT IN (
		SELECT concept_code
		FROM non_drug
		);

DELETE
FROM manufacturer
WHERE manufacturer IN (
		SELECT concept_name
		FROM RELATIONSHIP_MANUAL_SUPPLIER_DONE
		WHERE DUMMY IS NOT NULL
		);

DROP TABLE IF EXISTS list;
CREATE TABLE list AS
SELECT trim(manufacturer) AS concept_name,
	'Supplier'::VARCHAR(20) AS concept_class_id
FROM manufacturer

UNION

SELECT trim(INGREDIENT) AS concept_name,
	'Ingredient'::VARCHAR(20) AS concept_class_id
FROM INGREDIENTS
WHERE INGREDIENT IS NOT NULL

UNION

SELECT trim(NEW_NAME),
	'Brand Name'::VARCHAR(20) AS concept_class_id
FROM bn

UNION

SELECT trim(PRD_NAME) AS concept_name,
	'Drug Product'::VARCHAR(20) AS concept_class_id
FROM pack_drug_product_2

UNION

SELECT trim(dose_form) AS concept_name,
	'Dose Form'::VARCHAR(20) AS concept_class_id
FROM dose_form_test;

ALTER TABLE list ADD concept_code VARCHAR(255);

DO $$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(replace(concept_code, 'OMOP','')::int4)+1 into ex FROM devv5.concept WHERE concept_code like 'OMOP%'  and concept_code not like '% %'; -- Last valid value of the OMOP123-type codes
	DROP SEQUENCE IF EXISTS nv1;
	EXECUTE 'CREATE SEQUENCE nv1 INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END$$;

UPDATE list
SET concept_code = 'OMOP' || nextval('nv1');

TRUNCATE TABLE drug_concept_stage;

INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT concept_name,
	'LPD_Australia',
	concept_class_id,
	NULL,
	concept_code,
	NULL,
	'Drug',
	TO_DATE('20161001', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL
FROM (
	SELECT concept_name,
		concept_class_id,
		concept_code
	FROM list
	
	UNION
	
	SELECT PRD_NAME,
		'Drug Product' AS CONCEPT_CLASS_ID,
		fo_prd_id
	FROM drugs
	WHERE fo_prd_id NOT IN (
			SELECT concept_code
			FROM non_drug
			)
	) AS s0;

INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT concept_name,
	'LPD_Australia',
	concept_class_id,
	'S',
	concept_code,
	NULL,
	'Device',
	TO_DATE('20161001', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL
FROM (
	SELECT DISTINCT PRD_NAME AS concept_name,
		'Device' AS CONCEPT_CLASS_ID,
		concept_code AS concept_code
	FROM non_drug
	) AS s0;

UPDATE drug_concept_stage
SET standard_concept = 'S'
WHERE concept_class_id = 'Ingredient';

DROP TABLE IF EXISTS drugs_for_strentgh;
CREATE TABLE drugs_for_strentgh AS
SELECT fo_prd_id,
	prd_name,
	dosage,
	unit,
	dosage2,
	unit2,
	mol_name
FROM drugs
WHERE fo_prd_id NOT IN (
		SELECT concept_code
		FROM non_drug
		)
	AND fo_prd_id NOT IN (
		SELECT fo_prd_id
		FROM PACK_DRUG_PRODUCT_2
		);

UPDATE drugs_for_strentgh
SET PRD_NAME = replace(PRD_NAME, ',', '.')
WHERE PRD_NAME IS NOT NULL;

UPDATE drugs_for_strentgh
SET PRD_NAME = 'DEXSAL ANTACID LIQUID 1.25G-20MG/15'
WHERE prd_name = 'DEXSAL ANTACID LIQUID 1.25G-20MG/1';

DROP TABLE IF EXISTS ds_strength_trainee;
CREATE TABLE ds_strength_trainee (
	DRUG_CONCEPT_CODE VARCHAR(255),
	INGREDIENT_NAME VARCHAR(255),
	BOX_SIZE INT4,
	AMOUNT_VALUE FLOAT,
	AMOUNT_UNIT VARCHAR(255),
	NUMERATOR_VALUE FLOAT,
	NUMERATOR_UNIT VARCHAR(255),
	DENOMINATOR_VALUE FLOAT,
	DENOMINATOR_UNIT VARCHAR(255)
	);

UPDATE drugs_for_strentgh
SET unit = 'MCG'
WHERE unit LIKE 'µg';

UPDATE drugs_for_strentgh
SET unit2 = 'MCG'
WHERE unit2 LIKE 'µg';

--1 molecule denominator in Hours--
INSERT INTO ds_strength_trainee (
	drug_concept_code,
	ingredient_name,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
	)
SELECT DISTINCT fo_prd_id,
	mol_name,
	substring(prd_name, '(\d+(\.\d+)*)(MG|MCG|Y)\s?/')::FLOAT,
	substring(prd_name, '\d+(?:\.\d+)*(MG|MCG|Y)\s?/'),
	substring(prd_name, '(\d+(\.\d+)*)H')::FLOAT,
	'H'
FROM drugs_for_strentgh
WHERE prd_name ~ '\d+(\.\d+)*(H|HRS|HOUR|HOURS|HR)(\)|$)'
	AND mol_name NOT LIKE '%/%';

--1 molecule where %--
INSERT INTO ds_strength_trainee (
	drug_concept_code,
	ingredient_name,
	numerator_value,
	numerator_unit,
	denominator_unit
	)
SELECT fo_prd_id AS drug_concept_code,
	MOL_NAME AS ingredient_name,
	dosage::FLOAT * 10 AS numerator_value,
	'mg' AS numerator_unit,
	'ml' AS denominator_unit
FROM drugs_for_strentgh
WHERE mol_name NOT LIKE '%/%'
	AND unit2 IS NULL
	AND unit LIKE '%!%%' ESCAPE '!'
	AND fo_prd_id NOT IN (
		SELECT drug_concept_code
		FROM ds_strength_trainee
		);

--1 molecule not %--
INSERT INTO ds_strength_trainee (
	drug_concept_code,
	ingredient_name,
	amount_value,
	amount_unit
	)
SELECT fo_prd_id,
	mol_name,
	dosage::FLOAT,
	unit
FROM drugs_for_strentgh
WHERE mol_name NOT LIKE '%/%'
	AND unit2 IS NULL
	AND unit NOT LIKE '%!%%' ESCAPE '!'
	AND dosage2 IS NULL
	AND NOT prd_name ~ '(/(ACTUAT|SPRAY|PUMP|DOSE|INHAL))|MG/(G|ML)'
	AND fo_prd_id NOT IN (
		SELECT drug_concept_code
		FROM ds_strength_trainee
		);

--1 molecule not % where dosage 2 not null--
INSERT INTO ds_strength_trainee (
	drug_concept_code,
	ingredient_name,
	amount_value,
	amount_unit
	)
SELECT fo_prd_id,
	mol_name,
	dosage::FLOAT,
	unit
FROM drugs_for_strentgh
WHERE mol_name NOT LIKE '%/%'
	AND unit2 IS NULL
	AND unit NOT LIKE '%!%%' ESCAPE '!'
	AND dosage2 IS NOT NULL
	AND (
		prd_name LIKE '%/__H%'
		OR prd_name LIKE '%(%MG)'
		OR dosage2 = '-1'
		)
	AND fo_prd_id NOT IN (
		SELECT drug_concept_code
		FROM ds_strength_trainee
		);

--NEED MANUAL PROCEDURE( NEARLY 20 ROWS) WHERE CONCEPT_CLASS_ID = 'Drug Product' and mol_name not like '%/%' and unit2 is null and unit not like '%!%%' escape '!' and dosage2 is not null and NOT NULL  (prd_name like '%/__H%' or prd_name like '%(%MG)' or dosage2 = '-1')--

--liquid ingr with 1 molecule and no % anywhere--
INSERT INTO ds_strength_trainee (
	drug_concept_code,
	ingredient_name,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
	)
SELECT fo_prd_id,
	mol_name,
	dosage::FLOAT,
	unit,
	dosage2::FLOAT,
	unit2
FROM drugs_for_strentgh
WHERE mol_name NOT LIKE '%/%'
	AND unit2 IS NOT NULL
	AND unit NOT LIKE '%!%%' ESCAPE '!'
	AND unit2 NOT LIKE '%!%%' ESCAPE '!'
	AND fo_prd_id NOT IN (
		SELECT drug_concept_code
		FROM ds_strength_trainee
		);

INSERT INTO ds_strength_trainee (
	drug_concept_code,
	ingredient_name,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
	)
SELECT fo_prd_id,
	mol_name,
	substring(prd_name, '(\d+(\.\d+)*)(MCG|MG)/')::FLOAT AS numerator_value,
	substring(prd_name, '\d+(?:\.\d+)*(MCG|MG)/') AS numerator_unit,
	1 AS denominator_value,
	substring(prd_name, '/(ACTUAT|SPRAY|PUMP|DOSE|INHAL)') AS denominator_unit
FROM drugs
WHERE fo_prd_id NOT IN (
		SELECT drug_concept_code
		FROM ds_strength_trainee
		)
	AND mol_name NOT LIKE '%/%'
	AND prd_name ~ '/(ACTUAT|SPRAY|PUMP|DOSE|INHAL)'
	AND fo_prd_id NOT IN (
		SELECT concept_code
		FROM non_drug
		);

INSERT INTO ds_strength_trainee (
	drug_concept_code,
	ingredient_name,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
	)
SELECT fo_prd_id,
	mol_name,
	substring(prd_name, '(\d+(\.\d+)*)(MCG|MG)/')::FLOAT AS numerator_value,
	substring(prd_name, '(MCG|MG|G)/') AS numerator_unit,
	1 AS denominator_value,
	substring(prd_name, '/(MCG|MG|ML|L|G)') AS denominator_unit
FROM drugs
WHERE fo_prd_id NOT IN (
		SELECT drug_concept_code
		FROM ds_strength_trainee
		)
	AND mol_name NOT LIKE '%/%'
	AND prd_name ~ '(MCG|MG|G)/(G|ML|L)'
	AND fo_prd_id NOT IN (
		SELECT concept_code
		FROM non_drug
		);

--NEED MANUAL PROCEDURE( NEARLY 40 ROWS) WHERE CONCEPT_CLASS_ID = 'Drug Product' and FO_PRODUCT.MOL_NAME  not like '%/%' and unit2 is not null and (unit like '%!%%' escape '!' or unit2  like '%!%%' escape '!')--
--multiple ingr--
--multiple with pattern ' -%-%-/'--
CREATE OR replace VIEW multiple_liquid AS
SELECT fo_prd_id,
	prd_name,
	substring(prd_name, '((\d+(\.\d+)?\D*-)+\d+(\.\d+)?[^/]*)') AS AA,
	coalesce(substring(prd_name, '(?:\d+(?:\.\d+)?\D*-)+\d+(?:\.\d+)?\D*/([\d.]+).*')::FLOAT, 1) AS denominator_value,
	substring(prd_name, '(?:\d+(?:\.\d+)?\D*-)+\d+(?:\.\d+)?\D*/[\d.]*(ACTUAT|MG|IU|%|G|ML|DROP|MCG|MMOL|DOSE|BILLION.*|MILLION.*|\D*UNITS.|LOZ|LOZENGE|µg|U|L|M){1}') AS denominator_unit,
	mol_name
FROM drugs_for_strentgh
WHERE prd_name ~ '(\d+(\.\d+)?\D*-)+\d+(\.\d+)?\D*/{1}\d?(\.\d+)?\D*'
	AND mol_name LIKE '%/%';


CREATE OR replace VIEW ds_multiple_liquid AS
SELECT fo_prd_id,
	prd_name,
	l.g,
	substring(l.w, '[\d.]+')::FLOAT AS numerator_value,
	substring(l.w, 'ACTUAT|MG|IU|%|G|ML|DROP|MCG|MMOL|DOSE|BILLION.*|MILLION.*|\D*UNITS.|LOZ|LOZENGE|µg|U|L|M') AS numerator_unit,
	denominator_value,
	denominator_unit
FROM multiple_liquid,
	LATERAL(SELECT * FROM unnest(string_to_array(aa, '-'), string_to_array(MOL_NAME, '/')) AS a(w, g)) l;

--multiple with pattern '/' --
CREATE OR replace VIEW ds_multiple1 AS
SELECT fo_prd_id,
	prd_name,
	a,
	mol_name
FROM (
	SELECT substring(prd_name, '(\d+.?\d*(ACTUAT|MG|IU|%|G|ML|DROP|MCG|MMOL|DOSE|BILLION.*|MILLION.*|\D*.*UNITS.|LOZ|LOZENGE|µg|U|L|M){1}/\d+.*)') AS A,
		prd_name,
		fo_prd_id,
		mol_name
	FROM drugs_for_strentgh
	WHERE mol_name LIKE '%/%'
		AND FO_PRD_ID NOT IN (
			SELECT DISTINCT fo_prd_id
			FROM ds_multiple_liquid
			)
	) AS s0
WHERE A IS NOT NULL;

--multiple with pattern '-'--
CREATE OR replace VIEW ds_multiple2 AS
SELECT fo_prd_id,
	prd_name,
	b,
	mol_name
FROM (
	SELECT substring(prd_name, '(\d.?\d*(ACTUAT|MG|IU|%|G|ML|DROP|MCG|MMOL|DOSE|BILLION.*|MILLION.*|\D*UNITS.|LOZ|LOZENGE|µg|U|L|M){1}-\d.*)') AS b,
		prd_name,
		fo_prd_id,
		mol_name
	FROM drugs_for_strentgh
	WHERE mol_name LIKE '%/%'
		AND fo_prd_id NOT IN (
			SELECT DISTINCT fo_prd_id
			FROM ds_multiple_liquid
			)
	) AS s0
WHERE b IS NOT NULL;

--connecticng ingredient to comp. dosage--
DROP TABLE IF EXISTS multiple_ingredients;
CREATE TABLE multiple_ingredients AS
SELECT fo_prd_id,
	prd_name,
	l.w,
	l.g
FROM ds_multiple1,
	LATERAL(SELECT * FROM unnest(string_to_array(a, '/'), string_to_array(MOL_NAME, '/')) AS a(w, g)) l

UNION

SELECT fo_prd_id,
	prd_name,
	l.w,
	l.g
FROM ds_multiple2,
	LATERAL(SELECT * FROM unnest(string_to_array(b, '-'), string_to_array(MOL_NAME, '/')) AS a(w, g)) l;

INSERT INTO ds_strength_trainee (
	drug_concept_code,
	ingredient_name
	)
SELECT concept_code,
	BB.mol_name
FROM drug_concept_stage
JOIN (
	SELECT fo_prd_id,
		prd_name,
		substring(W, '(\d+(\.\d*)?)') AS dosage,
		substring(W, 'ACTUAT|MG|IU|%|G|ML|DROP|MCG|MMOL|DOSE|BILLION.*|MILLION.*|\D*UNITS.|LOZ|LOZENGE|µg|U|L|M') AS unit,
		g AS mol_name
	FROM multiple_ingredients
	) BB ON concept_code = fo_prd_id
WHERE concept_class_id = 'Drug Product'
	AND (
		dosage IS NULL
		OR unit IS NULL
		);

INSERT INTO ds_strength_trainee (
	drug_concept_code,
	ingredient_name,
	numerator_value,
	numerator_unit,
	denominator_unit
	)
SELECT concept_code AS drug_concept_code,
	aa.mol_name AS ingredient_name,
	aa.dosage::FLOAT * 10 AS numerator_value,
	'mg' AS numerator_unit,
	'ml' AS denominator_unit
FROM drug_concept_stage
JOIN (
	SELECT fo_prd_id,
		prd_name,
		substring(W, '(\d+(\.\d*)?)') AS dosage,
		substring(W, 'ACTUAT|MG|IU|%|G|ML|DROP|MCG|MMOL|DOSE|BILLION.*|MILLION.*|\D*UNITS.|LOZ|LOZENGE|µg|U|L|M') AS unit,
		g AS mol_name
	FROM multiple_ingredients
	) aa ON concept_code = fo_prd_id
WHERE concept_class_id = 'Drug Product'
	AND unit LIKE '%!%%' ESCAPE '!';

INSERT INTO ds_strength_trainee (
	drug_concept_code,
	ingredient_name,
	amount_value,
	amount_unit
	)
SELECT concept_code,
	bb.mol_name,
	bb.dosage::FLOAT,
	bb.unit
FROM drug_concept_stage
JOIN (
	SELECT fo_prd_id,
		prd_name,
		substring(W, '(\d+(\.\d*)?)') AS dosage,
		substring(W, 'ACTUAT|MG|IU|%|G|ML|DROP|MCG|MMOL|DOSE|BILLION.*|MILLION.*|\D*UNITS.|LOZ|LOZENGE|µg|U|L|M') AS unit,
		g AS mol_name
	FROM multiple_ingredients
	) bb ON concept_code = fo_prd_id
WHERE concept_class_id = 'Drug Product'
	AND unit NOT LIKE '%!%%' ESCAPE '!';

INSERT INTO ds_strength_trainee (
	drug_concept_code,
	ingredient_name,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
	)
SELECT fo_prd_id AS drug_concept_code,
	g AS ingredient_name,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
FROM ds_multiple_liquid;

DROP TABLE IF EXISTS ds_trainee_upd;
CREATE TABLE ds_trainee_upd AS
SELECT drug_concept_code,
	ingredient_name,
	prd_name,
	substring(prd_name, '(\d+\w+)/(\d)?(\.)?(\d)?\w+') AS numerator,
	substring(prd_name, '\d+\w+/((\d)?(\.)?(\d)?\w+)') AS denominator
FROM ds_strength_trainee a
JOIN drugs_for_strentgh b ON fo_prd_id = drug_concept_code
WHERE prd_name LIKE '%/%'
	AND amount_value IS NOT NULL
	AND mol_name NOT LIKE '%/%'
	AND NOT substring(prd_name, '((\d)+\w+/(\d)?(\.)?(\d)?\w+)') ~ 'SPRAY|PUMP|SACHET|INHAL|PUFF|DROP|DOSE|CAP|DO|SQUARE|LOZ|ELECTROLYTES|APPLICATI|BLIS|VIAL|BLIST';


DROP TABLE IF EXISTS ds_trainee_upd_2;
CREATE TABLE ds_trainee_upd_2 AS
SELECT drug_concept_code,
	ingredient_name,
	CASE 
		WHEN denominator = 'STRAIN'
			THEN '0.1'
		WHEN denominator = '33'
			THEN '33.6'
		WHEN denominator LIKE '%2%'
			THEN '24'
		ELSE substring(denominator, '\d+')
		END::FLOAT AS denominator_value,
	CASE 
		WHEN denominator LIKE '%H%'
			THEN 'HOUR'
		WHEN denominator LIKE '%L%'
			THEN 'L'
		WHEN denominator = '33'
			THEN 'MG'
		WHEN denominator = 'STRAIN'
			THEN 'ML'
		WHEN denominator LIKE '%ACTUA%'
			THEN 'ACTUATION'
		WHEN denominator LIKE '%2%'
			THEN 'HOUR'
		ELSE regexp_replace(denominator, '\d+', '', 'g')
		END AS denominator_unit,
	regexp_replace(numerator, '\d+', '', 'g') AS numerator_unit,
	substring(numerator, '\d+')::FLOAT AS numerator_value
FROM ds_trainee_upd;

INSERT INTO ds_strength_trainee (
	drug_concept_code,
	ingredient_name,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
	)
SELECT DISTINCT concept_code,
	mol_name,
	amount_value,
	amount_unit,
	numerator_value,
	nimeratot_unit,
	denominator_value,
	denominator_unit
FROM pack_drug_product_2 a
JOIN drug_concept_stage b ON prd_name = concept_name;

DELETE
FROM ds_strength_trainee
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage_manual_all
		);

INSERT INTO ds_strength_trainee
SELECT *
FROM ds_stage_manual_all;

UPDATE ds_strength_trainee
SET DENOMINATOR_UNIT = 'ACTUATION'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_strength_trainee
		JOIN drugs ON drug_concept_code = fo_prd_id
		WHERE PRD_NAME LIKE '%DOSE'
		)
	AND NUMERATOR_UNIT IS NOT NULL
	AND DENOMINATOR_VALUE IS NULL;

UPDATE ds_strength_trainee
SET DENOMINATOR_UNIT = 'ACTUATION',
	NUMERATOR_VALUE = AMOUNT_VALUE,
	NUMERATOR_UNIT = AMOUNT_UNIT,
	AMOUNT_VALUE = NULL,
	AMOUNT_UNIT = NULL
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_strength_trainee
		JOIN drugs ON drug_concept_code = fo_prd_id
		WHERE PRD_NAME LIKE '%DOSE'
			AND denominator_unit IS NULL
		);

UPDATE ds_strength_trainee
SET DENOMINATOR_UNIT = 'ml'
WHERE drug_concept_code IN (
		SELECT DRUG_CONCEPT_CODE
		FROM ds_strength_trainee
		JOIN drugs ON drug_concept_code = fo_prd_id
		WHERE regexp_like(prd_name, '-\d+\w+/\d+$')
			AND mol_name LIKE '%/%'
		);

UPDATE ds_strength_trainee
SET DENOMINATOR_UNIT = 'ml'
WHERE DENOMINATOR_UNIT = 'ML';

UPDATE ds_strength_trainee
SET AMOUNT_VALUE = NULL,
	AMOUNT_UNIT = NULL
WHERE AMOUNT_VALUE = '0'
	AND INGREDIENT_NAME != 'INERT INGREDIENTS';

UPDATE DS_STRENGTH_TRAINEE
SET DENOMINATOR_UNIT = 'HOUR'
WHERE DENOMINATOR_VALUE = '24';

UPDATE DS_STRENGTH_TRAINEE
SET DENOMINATOR_UNIT = 'HOUR'
WHERE DENOMINATOR_UNIT = 'H';

UPDATE DS_STRENGTH_TRAINEE
SET INGREDIENT_NAME = 'NICOTINAMIDE'
WHERE INGREDIENT_NAME = 'NICOTINIC ACID';

DELETE
FROM DS_STRENGTH_TRAINEE
WHERE DRUG_CONCEPT_CODE = '28058'
	AND INGREDIENT_NAME = 'NICOTINAMIDE'
	AND AMOUNT_VALUE = '20';

UPDATE DS_STRENGTH_TRAINEE
SET AMOUNT_VALUE = '520'
WHERE DRUG_CONCEPT_CODE = '28058'
	AND INGREDIENT_NAME = 'NICOTINAMIDE';

DELETE
FROM DS_STRENGTH_TRAINEE
WHERE DRUG_CONCEPT_CODE = '27625'
	AND INGREDIENT_NAME = 'NICOTINAMIDE'
	AND AMOUNT_VALUE = '25';

UPDATE DS_STRENGTH_TRAINEE
SET AMOUNT_VALUE = '125'
WHERE DRUG_CONCEPT_CODE = '27625'
	AND INGREDIENT_NAME = 'NICOTINAMIDE';

DELETE
FROM DS_STRENGTH_TRAINEE
WHERE DRUG_CONCEPT_CODE = '15248'
	AND INGREDIENT_NAME = 'SILYBUM MARIANUM'
	AND AMOUNT_VALUE = '1';

UPDATE DS_STRENGTH_TRAINEE
SET AMOUNT_VALUE = '8'
WHERE DRUG_CONCEPT_CODE = '15248'
	AND INGREDIENT_NAME = 'SILYBUM MARIANUM';

DELETE
FROM DS_STRENGTH_TRAINEE
WHERE DRUG_CONCEPT_CODE = '88716'
	AND INGREDIENT_NAME = 'NICOTINAMIDE';

INSERT INTO DS_STRENGTH_TRAINEE (
	DRUG_CONCEPT_CODE,
	INGREDIENT_NAME
	)
VALUES (
	'88716',
	'NICOTINAMIDE'
	);

UPDATE DS_STRENGTH_TRAINEE
SET AMOUNT_UNIT = TRIM(regexp_replace(AMOUNT_UNIT, 'S$'))
WHERE regexp_like(AMOUNT_UNIT, '^\s');

UPDATE DS_STRENGTH_TRAINEE
SET NUMERATOR_UNIT = TRIM(regexp_replace(NUMERATOR_UNIT, 'S$'))
WHERE regexp_like(NUMERATOR_UNIT, '^\s');

UPDATE DS_STRENGTH_TRAINEE
SET DENOMINATOR_UNIT = TRIM(regexp_replace(DENOMINATOR_UNIT, 'S$'))
WHERE regexp_like(DENOMINATOR_UNIT, '^\s');

DELETE
FROM ds_strength_trainee
WHERE NUMERATOR_UNIT = 'unknown';



TRUNCATE TABLE ds_stage;
INSERT INTO ds_stage (
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
	concept_code,
	box_size,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
FROM ds_strength_trainee
JOIN drug_concept_stage ON ingredient_name = concept_name
WHERE concept_class_id = 'Ingredient';

INSERT INTO ds_stage (
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
SELECT fo_prd_id,
	concept_code,
	box_size,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
FROM i_map_postprocess a
JOIN drug_concept_stage b ON upper(a.concept_name) = upper(b.concept_name)
WHERE concept_class_id = 'Ingredient'
	AND coalesce(amount_value, numerator_value) IS NOT NULL
	AND fo_prd_id NOT IN (
		SELECT drug_concept_code
		FROM ds_stage
		);

INSERT INTO ds_stage (
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
SELECT fo_prd_id,
	concept_code,
	round(box_size::FLOAT),
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
FROM no_ds_done a
JOIN drug_concept_stage b ON upper(a.ingredient_name) = upper(b.concept_name)
WHERE concept_class_id = 'Ingredient'
	AND coalesce(amount_value, numerator_value) IS NOT NULL
	AND fo_prd_id NOT IN (
		SELECT drug_concept_code
		FROM ds_stage
		);

UPDATE ds_stage
SET amount_unit = trim(UPPER(amount_unit)),
	NUMERATOR_UNIT = trim(UPPER(NUMERATOR_UNIT)),
	DENOMINATOR_UNIT = trim(UPPER(DENOMINATOR_UNIT));

UPDATE ds_stage
SET amount_unit = 'U'
WHERE amount_unit IN (
		'UNITS',
		'BILLION CFU',
		'BILLION',
		'BILLION ORGANISMS'
		);

UPDATE ds_stage
SET NUMERATOR_UNIT = 'U'
WHERE NUMERATOR_UNIT IN (
		'UNITS',
		'BILLION CFU',
		'BILLION',
		'BILLION ORGANISMS'
		);

UPDATE ds_stage
SET amount_unit = 'MG'
WHERE amount_unit IN ('M');

UPDATE ds_stage
SET amount_unit = 'MCG'
WHERE amount_unit IN (
		'?G',
		'ÂΜG',
		'Y'
		);

UPDATE ds_stage
SET NUMERATOR_UNIT = 'MCG'
WHERE NUMERATOR_UNIT IN (
		'?G',
		'ÂΜG',
		'Y'
		);

UPDATE ds_stage
SET DENOMINATOR_UNIT = 'MCG'
WHERE DENOMINATOR_UNIT IN (
		'?G',
		'ÂΜG',
		'Y'
		);

UPDATE ds_stage
SET DENOMINATOR_UNIT = 'HOUR'
WHERE DENOMINATOR_UNIT IN ('H');

UPDATE ds_stage
SET DENOMINATOR_UNIT = 'ACTUATION'
WHERE DENOMINATOR_UNIT IN (
		'DOSE',
		'INHAL',
		'PUMP',
		'SPRAY',
		'ACTUAT'
		);

UPDATE ds_stage
SET NUMERATOR_VALUE = NUMERATOR_VALUE * DENOMINATOR_VALUE * 10,
	NUMERATOR_UNIT = 'MG',
	DENOMINATOR_UNIT = 'ML'
WHERE NUMERATOR_UNIT = '%';

DELETE
FROM DS_STAGE
WHERE DRUG_CONCEPT_CODE IN (
		SELECT cast(FO_PRD_ID AS VARCHAR(20))
		FROM DS_TO_DELETE_DONE
		);

INSERT INTO ds_stage
SELECT fo_prd_id,
	concept_code,
	box_size,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
FROM DS_TO_DELETE_DONE A
JOIN DRUG_CONCEPT_STAGE B ON UPPER(A.CONCEPT_NAME) = UPPER(B.CONCEPT_NAME)
	AND B.CONCEPT_CLASS_ID = 'Ingredient'
WHERE valid_ds IS NULL
	AND fo_prd_id NOT IN (
		SELECT concept_code
		FROM non_drug
		);


DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Device'
		);

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT fo_prd_id
		FROM pack_drug_product_2
		);

DELETE
FROM ds_stage
WHERE coalesce(amount_value, numerator_value) IS NULL;


DELETE
FROM ds_stage d
WHERE EXISTS (
		SELECT 1
		FROM ds_stage d_int
		WHERE d_int.drug_concept_code = d.drug_concept_code
			AND d_int.ingredient_concept_code = d.ingredient_concept_code
			AND d_int.ctid > d.ctid
		);

--units appeared--
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	domain_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT amount_unit,
	'LPD_Australia',
	'Unit',
	NULL,
	amount_unit,
	'Drug',
	TO_DATE('20161001', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM (
	SELECT amount_unit
	FROM ds_stage
	
	UNION
	
	SELECT NUMERATOR_UNIT
	FROM ds_stage
	
	UNION
	
	SELECT DENOMINATOR_UNIT
	FROM ds_stage
	) AS s0
WHERE amount_unit IS NOT NULL;

DROP TABLE IF EXISTS relation_brandname_1;
CREATE TABLE relation_brandname_1 AS
SELECT DISTINCT d.concept_name,
	concept_id,
	r.concept_name AS R
FROM drug_concept_stage d
INNER JOIN devv5.concept r ON trim(lower(d.concept_name)) = trim(lower(r.concept_name))
WHERE d.concept_class_id LIKE '%Brand%'
	AND r.vocabulary_id LIKE '%Rx%'
	AND r.invalid_reason IS NULL
	AND r.concept_class_id LIKE '%Brand Name%';

INSERT INTO relation_brandname_1
SELECT concept_name,
	concept_id_2,
	concept_name_2
FROM relation_manual_bn;

DROP TABLE IF EXISTS relation_ingr_1;
CREATE TABLE relation_ingr_1 AS
SELECT d.concept_name,
	concept_id,
	r.concept_name AS R
FROM drug_concept_stage d
INNER JOIN devv5.concept r ON trim(lower(d.concept_name)) = trim(lower(r.concept_name))
WHERE d.concept_class_id LIKE '%Ingredient%'
	AND r.vocabulary_id LIKE '%Rx%'
	AND r.invalid_reason IS NULL
	AND r.concept_class_id LIKE 'Ingredient%';

INSERT INTO relation_ingr_1
SELECT DISTINCT a.concept_name,
	d.concept_id,
	d.concept_name
FROM drug_concept_stage a
JOIN devv5.concept b ON upper(a.concept_name) = upper(b.concept_name)
	AND b.concept_class_id = 'Ingredient'
JOIN devv5.concept_relationship c ON b.concept_id = c.concept_id_1
JOIN devv5.concept d ON d.concept_id = concept_id_2
	AND d.concept_class_id = 'Ingredient'
	AND d.standard_concept = 'S'
WHERE a.concept_class_id = 'Ingredient'
	AND a.concept_name NOT IN (
		SELECT concept_name
		FROM relation_ingr_1
		);

INSERT INTO relation_ingr_1
SELECT d.concept_name,
	concept_id,
	concept_synonym_name AS R
FROM drug_concept_stage d
INNER JOIN devv5.concept_synonym r ON trim(lower(d.concept_name)) = trim(lower(CONCEPT_SYNONYM_NAME))
WHERE d.concept_class_id LIKE '%Ingredient%'
	AND concept_id IN (
		SELECT concept_id
		FROM devv5.concept
		WHERE VOCABULARY_ID LIKE '%Rx%'
			AND invalid_reason IS NULL
			AND concept_class_id LIKE 'Ingredient%'
		)
	AND concept_code NOT IN (
		SELECT concept_code
		FROM RELATION_INGR_1
		);

DELETE
FROM RELATION_INGR_1
WHERE concept_name = 'PARACETAMOL'
	AND concept_id = 1112807;

DELETE
FROM RELATION_INGR_1
WHERE CONCEPT_NAME = 'RETINOL'
	AND CONCEPT_ID = 19009540;

INSERT INTO RELATION_INGR_1
VALUES (
	'FOLATE',
	'19111620',
	'Folic Acid'
	);

--adding all to realtionship_to_concept--

TRUNCATE TABLE relationship_to_concept;

INSERT INTO relationship_to_concept (
	CONCEPT_CODE_1,
	VOCABULARY_ID_1,
	CONCEPT_ID_2,
	PRECEDENCE
	)
SELECT DISTINCT b.concept_code,
	'LPD_Australia',
	a.concept_id,
	a.precedence
FROM aus_dose_forms_done a
JOIN drug_concept_stage b ON a.dose_form = b.concept_name;

INSERT INTO relationship_to_concept (
	CONCEPT_CODE_1,
	VOCABULARY_ID_1,
	CONCEPT_ID_2,
	PRECEDENCE
	)
SELECT DISTINCT CONCEPT_CODE,
	'LPD_Australia',
	CONCEPT_ID,
	rank() OVER (
		PARTITION BY concept_code ORDER BY concept_id
		)
FROM RELATION_INGR_1 a
JOIN drug_concept_stage b ON a.concept_name = b.concept_name
WHERE b.concept_class_id = 'Ingredient';

INSERT INTO relationship_to_concept (
	CONCEPT_CODE_1,
	VOCABULARY_ID_1,
	CONCEPT_ID_2,
	PRECEDENCE
	)
SELECT DISTINCT concept_code AS concept_code_1,
	'LPD_Australia',
	CONCEPT_ID AS concept_id_2,
	coalesce(precedence, 1)
FROM RELATIONSHIP_MANUAL_INGREDIENT_DONE a
JOIN drug_concept_stage b ON a.concept_name = b.concept_name
	AND CONCEPT_ID IS NOT NULL
	AND b.concept_class_id = 'Ingredient';

INSERT INTO relationship_to_concept (
	CONCEPT_CODE_1,
	VOCABULARY_ID_1,
	CONCEPT_ID_2,
	PRECEDENCE
	)
SELECT DISTINCT CONCEPT_CODE,
	'LPD_Australia',
	CONCEPT_ID,
	rank() OVER (
		PARTITION BY CONCEPT_CODE ORDER BY concept_id
		)
FROM relation_brandname_1 a
JOIN drug_concept_stage b ON a.concept_name = b.concept_name
WHERE b.concept_class_id = 'Brand Name'
	AND concept_code NOT IN (
		SELECT concept_code_1
		FROM relationship_to_concept
		);

INSERT INTO relationship_to_concept (
	CONCEPT_CODE_1,
	VOCABULARY_ID_1,
	CONCEPT_ID_2,
	PRECEDENCE
	)
SELECT DISTINCT concept_code AS concept_code_1,
	'LPD_Australia',
	CONCEPT_ID AS concept_id_2,
	coalesce(precedence, 1)
FROM RELATIONSHIP_MANUAL_BRAND_DONE a
JOIN drug_concept_stage b ON a.concept_name = b.concept_name
	AND CONCEPT_ID IS NOT NULL
	AND b.concept_class_id = 'Brand Name';

INSERT INTO relationship_to_concept (
	CONCEPT_CODE_1,
	VOCABULARY_ID_1,
	CONCEPT_ID_2,
	PRECEDENCE
	)
SELECT DISTINCT a.concept_code a,
	'LPD_Australia',
	b.concept_id,
	1
FROM drug_concept_stage a
JOIN devv5.concept b ON lower(a.concept_name) = lower(b.concept_name)
WHERE b.concept_class_id = 'Supplier'
	AND a.concept_class_id = 'Supplier'
	AND b.invalid_reason IS NULL
	AND b.vocabulary_id LIKE 'Rx%';

INSERT INTO relationship_to_concept (
	CONCEPT_CODE_1,
	VOCABULARY_ID_1,
	CONCEPT_ID_2,
	PRECEDENCE
	)
SELECT DISTINCT concept_code AS concept_code_1,
	'LPD_Australia',
	CONCEPT_ID AS concept_id_2,
	coalesce(precedence, 1)
FROM RELATIONSHIP_MANUAL_SUPPLIER_DONE a
JOIN drug_concept_stage b ON a.concept_name = b.concept_name
	AND CONCEPT_ID IS NOT NULL
	AND b.concept_class_id = 'Supplier';

INSERT INTO relationship_to_concept (
	CONCEPT_CODE_1,
	VOCABULARY_ID_1,
	CONCEPT_ID_2,
	PRECEDENCE
	)
SELECT DISTINCT b.CONCEPT_CODE,
	'LPD_Australia',
	c.CONCEPT_ID,
	rank() OVER (
		PARTITION BY b.CONCEPT_CODE ORDER BY c.concept_id
		)
FROM manual_supp a
JOIN drug_concept_stage b ON a.concept_name = b.concept_name
JOIN devv5.concept c ON a.concept_id = c.concept_id
WHERE b.concept_class_id = 'Supplier'
	AND c.invalid_reason IS NULL
	AND (
		b.concept_code,
		c.concept_id
		) NOT IN (
		SELECT concept_code_1,
			concept_id_2
		FROM relationship_to_concept
		);

INSERT INTO relationship_to_concept (
	CONCEPT_CODE_1,
	VOCABULARY_ID_1,
	CONCEPT_ID_2,
	PRECEDENCE,
	CONVERSION_FACTOR
	)
SELECT DISTINCT CONCEPT_CODE_1,
	'LPD_Australia',
	CONCEPT_ID_2,
	PRECEDENCE,
	CONVERSION_FACTOR
FROM aus_unit_done;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 43126201
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 43126196
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 21019309
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 21019140
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 21020637
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 19131388
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 21020344
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 21020318
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 21019596
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 21019581
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 43132698
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 43132581
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 21020344
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 21020318
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 21019596
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 43132698
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 21020360
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 43132496
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 19052251
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 43132849
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 43132829
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 43132600
	AND precedence = 1;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 43132357
	AND precedence = 1;

UPDATE relationship_to_concept
SET precedence = 2
WHERE concept_id_2 = 43012668
	AND precedence = 3;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 IN (
		SELECT concept_id
		FROM devv5.concept
		WHERE invalid_reason IS NOT NULL
		);

DROP TABLE IF EXISTS ds_sum;
CREATE TABLE ds_sum AS
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

SELECT DISTINCT drug_concept_code,
	max(ingredient_concept_code) OVER (
		PARTITION BY drug_concept_code,
		concept_id_2
		) AS ingredient_concept_code,
	box_size,
	sum(amount_value) OVER (PARTITION BY drug_concept_code) AS amount_value,
	amount_unit,
	sum(numerator_value) OVER (
		PARTITION BY drug_concept_code,
		concept_id_2
		) AS numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
FROM a

UNION

SELECT DRUG_CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	box_size,
	NULL AS AMOUNT_VALUE,
	NULL AS AMOUNT_UNIT,
	NULL AS NUMERATOR_VALUE,
	NULL AS NUMERATOR_UNIT,
	NULL AS DENOMINATOR_VALUE,
	NULL AS DENOMINATOR_UNIT
FROM a
WHERE (
		drug_concept_code,
		ingredient_concept_code
		) NOT IN (
		SELECT drug_concept_code,
			max(ingredient_concept_code)
		FROM a
		GROUP BY drug_concept_code
		);

DELETE
FROM ds_stage
WHERE (
		drug_concept_code,
		ingredient_concept_code
		) IN (
		SELECT drug_concept_code,
			ingredient_concept_code
		FROM ds_sum
		);

INSERT INTO DS_STAGE
SELECT *
FROM DS_SUM
WHERE coalesce(AMOUNT_VALUE, NUMERATOR_VALUE) IS NOT NULL;

--pc stage--
TRUNCATE TABLE pc_stage;

INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount
	)
SELECT DISTINCT fo_prd_id,
	concept_code,
	amount_pack
FROM pack_drug_product_2
JOIN drug_concept_stage ON prd_name = concept_name;

TRUNCATE TABLE internal_relationship_stage;

--drug to ingredient
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT fo_prd_id,
	concept_code
FROM ingredients
JOIN (
	SELECT concept_name,
		concept_code
	FROM drug_concept_stage
	WHERE concept_class_id = 'Ingredient'
	) s ON ingredient = concept_name
WHERE fo_prd_id NOT IN (
		SELECT fo_prd_id
		FROM pack_drug_product_2
		)

UNION

SELECT b.concept_code,
	c.concept_code
FROM pack_drug_product_2 a
JOIN drug_concept_stage b ON a.prd_name = b.concept_name
	AND b.concept_class_id = 'Drug Product'
JOIN drug_concept_stage c ON a.mol_name = c.concept_name
	AND c.concept_class_id = 'Ingredient';

INSERT INTO internal_relationship_stage
SELECT DISTINCT drug_concept_code,
	ingredient_concept_code
FROM ds_stage
WHERE (
		drug_concept_code,
		ingredient_concept_code
		) NOT IN (
		SELECT concept_code_1,
			concept_code_2
		FROM internal_relationship_stage
		);

--drug to bn
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT fo_prd_id,
	concept_code
FROM bn
JOIN (
	SELECT concept_name,
		concept_code
	FROM drug_concept_stage
	WHERE concept_class_id = 'Brand Name'
	) s ON trim(new_name) = concept_name

UNION

SELECT b.concept_code,
	d.concept_code
FROM pack_drug_product_2 a
JOIN drug_concept_stage b ON a.prd_name = b.concept_name
	AND b.concept_class_id = 'Drug Product'
JOIN bn c ON a.fo_prd_id = c.fo_prd_id
JOIN (
	SELECT concept_name,
		concept_code
	FROM drug_concept_stage
	WHERE concept_class_id = 'Brand Name'
	) d ON trim(new_name) = d.concept_name
WHERE a.prd_name != 'INACTIVE TABLET';


--drug to supp
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT fo_prd_id AS concept_code_1,
	concept_code AS concept_code_2
FROM manufacturer
INNER JOIN (
	SELECT concept_name,
		concept_code
	FROM drug_concept_stage
	WHERE concept_class_id = 'Supplier'
	) s ON manufacturer = concept_name

UNION

SELECT b.concept_code,
	d.concept_code
FROM pack_drug_product_2 a
JOIN drug_concept_stage b ON a.prd_name = b.concept_name
	AND b.concept_class_id = 'Drug Product'
JOIN manufacturer c ON a.fo_prd_id = c.fo_prd_id
JOIN (
	SELECT concept_name,
		concept_code
	FROM drug_concept_stage
	WHERE concept_class_id = 'Supplier'
	) d ON trim(manufacturer) = d.concept_name
WHERE a.prd_name != 'INACTIVE TABLET';

--drug to dose form
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT fo_prd_id,
	concept_code
FROM dose_form_test
JOIN (
	SELECT concept_name,
		concept_code
	FROM drug_concept_stage
	WHERE concept_class_id = 'Dose Form'
	) s ON dose_form = concept_name
WHERE fo_prd_id NOT IN (
		SELECT fo_prd_id
		FROM pack_drug_product_2
		);

INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT a.concept_code,
	c.concept_code
FROM drug_concept_stage a
JOIN dose_form_test b ON a.concept_name = b.prd_name
JOIN drug_concept_stage c ON c.concept_name = b.dose_form
	AND c.concept_class_id = 'Dose Form'
WHERE a.concept_code IN (
		SELECT drug_concept_code
		FROM pc_stage
		);

--drug to nfc_code

INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT concept_code AS concept_code_1,
	nfc_code AS concept_code_2
FROM drugs a
JOIN drug_concept_stage b ON a.fo_prd_id = b.concept_code
WHERE fo_prd_id NOT IN (
		SELECT fo_prd_id
		FROM pack_drug_product_2
		)
	AND nfc_code IS NOT NULL;

DELETE
FROM internal_relationship_stage
WHERE (
		concept_code_1,
		concept_code_2
		) IN (
		SELECT concept_code_1,
			concept_code_2
		FROM (
			SELECT DISTINCT concept_code_1,
				concept_code_2,
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
	AND (
		concept_code_1,
		concept_code_2
		) NOT IN (
		SELECT drug_concept_code,
			ingredient_concept_code
		FROM ds_stage
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT concept_code
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
			AND invalid_reason IS NULL
		)
	AND concept_code_2 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Supplier'
		);

CREATE INDEX idx_drug_concept_code ON ds_stage (drug_concept_code);
analyze ds_stage;

UPDATE ds_stage
SET box_size = NULL
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage ds
		JOIN internal_relationship_stage i ON concept_code_1 = drug_concept_code
		LEFT JOIN drug_concept_stage ON concept_code = concept_code_2
			AND concept_class_id = 'Dose Form'
		WHERE box_size IS NOT NULL
			AND concept_name IS NULL
		);

DROP INDEX idx_drug_concept_code;
analyze ds_stage;