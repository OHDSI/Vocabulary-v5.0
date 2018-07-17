DROP TABLE IF EXISTS s_to_c_map;
CREATE TABLE s_to_c_map AS
SELECT d.prd_id,
	d.prd_name,
	c.*
FROM source_data d
LEFT JOIN map_drug m ON m.from_code = d.prd_id
LEFT JOIN concept c ON m.to_id = c.concept_id

UNION

SELECT d.prd_id,
	d.prd_name,
	NULL,
	NULL,
	'Device',
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL
FROM source_data d
JOIN devices_mapped m ON m.prd_name = d.prd_name;


INSERT INTO s_to_c_map
SELECT prd_id,
	prd_name,
	b.*
FROM lost_ing a
JOIN concept b ON a.concept_id = b.concept_id;

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077547,
	CONCEPT_NAME = 'gabapentin 100 MG Oral Capsule',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Clinical Drug',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '310430',
	VALID_START_DATE = TO_DATE('19700101', 'YYYYMMDD'),
	VALID_END_DATE = TO_DATE('20991231', 'YYYYMMDD')
WHERE PRD_ID = '161312';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077547,
	CONCEPT_NAME = 'gabapentin 100 MG Oral Capsule',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Clinical Drug',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '310430',
	VALID_START_DATE = TO_DATE('19700101', 'YYYYMMDD'),
	VALID_END_DATE = TO_DATE('20991231', 'YYYYMMDD')
WHERE PRD_ID = '161312';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077548,
	CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Clinical Drug',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '310431',
	VALID_START_DATE = TO_DATE('19700101', 'YYYYMMDD'),
	VALID_END_DATE = TO_DATE('20991231', 'YYYYMMDD')
WHERE PRD_ID = '187234';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077548,
	CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Clinical Drug',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '310431',
	VALID_START_DATE = TO_DATE('19700101', 'YYYYMMDD'),
	VALID_END_DATE = TO_DATE('20991231', 'YYYYMMDD')
WHERE PRD_ID = '187234';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077548,
	CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Clinical Drug',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '310431',
	VALID_START_DATE = TO_DATE('19700101', 'YYYYMMDD'),
	VALID_END_DATE = TO_DATE('20991231', 'YYYYMMDD')
WHERE PRD_ID = '161311';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077548,
	CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Clinical Drug',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '310431',
	VALID_START_DATE = TO_DATE('19700101', 'YYYYMMDD'),
	VALID_END_DATE = TO_DATE('20991231', 'YYYYMMDD')
WHERE PRD_ID = '161311';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077549,
	CONCEPT_NAME = 'gabapentin 400 MG Oral Capsule',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Clinical Drug',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '310432',
	VALID_START_DATE = TO_DATE('19700101', 'YYYYMMDD'),
	VALID_END_DATE = TO_DATE('20991231', 'YYYYMMDD')
WHERE PRD_ID = '187233';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077549,
	CONCEPT_NAME = 'gabapentin 400 MG Oral Capsule',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Clinical Drug',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '310432',
	VALID_START_DATE = TO_DATE('19700101', 'YYYYMMDD'),
	VALID_END_DATE = TO_DATE('20991231', 'YYYYMMDD')
WHERE PRD_ID = '187233';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077549,
	CONCEPT_NAME = 'gabapentin 400 MG Oral Capsule',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Clinical Drug',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '310432',
	VALID_START_DATE = TO_DATE('19700101', 'YYYYMMDD'),
	VALID_END_DATE = TO_DATE('20991231', 'YYYYMMDD')
WHERE PRD_ID = '161310';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077549,
	CONCEPT_NAME = 'gabapentin 400 MG Oral Capsule',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Clinical Drug',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '310432',
	VALID_START_DATE = TO_DATE('19700101', 'YYYYMMDD'),
	VALID_END_DATE = TO_DATE('20991231', 'YYYYMMDD')
WHERE PRD_ID = '161310';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077548,
	CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',
	CONCEPT_CLASS_ID = 'Clinical Drug',
	CONCEPT_CODE = '310431'
WHERE PRD_ID = '159210';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077548,
	CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',
	CONCEPT_CLASS_ID = 'Clinical Drug',
	CONCEPT_CODE = '310431'
WHERE PRD_ID = '160281';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077548,
	CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',
	CONCEPT_CLASS_ID = 'Clinical Drug',
	CONCEPT_CODE = '310431'
WHERE PRD_ID = '160280';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077549,
	CONCEPT_NAME = 'gabapentin 400 MG Oral Capsule',
	CONCEPT_CODE = '310432'
WHERE PRD_ID = '159209';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077549,
	CONCEPT_NAME = 'gabapentin 400 MG Oral Capsule',
	CONCEPT_CODE = '310432'
WHERE PRD_ID = '160283';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077547,
	CONCEPT_NAME = 'gabapentin 100 MG Oral Capsule',
	CONCEPT_CLASS_ID = 'Clinical Drug',
	CONCEPT_CODE = '310430'
WHERE PRD_ID = '197610';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077548,
	CONCEPT_NAME = 'gabapentin 300 MG Oral Capsule',
	CONCEPT_CLASS_ID = 'Clinical Drug',
	CONCEPT_CODE = '310431'
WHERE PRD_ID = '197611';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 19077549,
	CONCEPT_NAME = 'gabapentin 400 MG Oral Capsule',
	CONCEPT_CODE = '310432'
WHERE PRD_ID = '197668';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 44042852,
	CONCEPT_NAME = 'iodoform Topical Solution',
	CONCEPT_CODE = 'OMOP1037483'
WHERE PRD_ID = '96921';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 44042852,
	CONCEPT_NAME = 'iodoform Topical Solution',
	CONCEPT_CODE = 'OMOP1037483'
WHERE PRD_ID = '96922';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 40148731,
	CONCEPT_NAME = 'Rubella Virus Vaccine Live (Wistar RA 27-3 Strain) Injectable Solution',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CODE = '762819'
WHERE PRD_ID = '5274';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 40213184,
	CONCEPT_NAME = 'measles, mumps, rubella, and varicella virus vaccine',
	VOCABULARY_ID = 'CVX',
	CONCEPT_CLASS_ID = 'CVX',
	CONCEPT_CODE = '94'
WHERE PRD_ID = '80231';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 40213184,
	CONCEPT_NAME = 'measles, mumps, rubella, and varicella virus vaccine',
	VOCABULARY_ID = 'CVX',
	CONCEPT_CLASS_ID = 'CVX',
	CONCEPT_CODE = '94'
WHERE PRD_ID = '188123';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 40213198,
	CONCEPT_NAME = 'pneumococcal conjugate vaccine, 13 valent',
	VOCABULARY_ID = 'CVX',
	CONCEPT_CLASS_ID = 'CVX',
	CONCEPT_CODE = '133'
WHERE PRD_ID = '109054';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 40213198,
	CONCEPT_NAME = 'pneumococcal conjugate vaccine, 13 valent',
	VOCABULARY_ID = 'CVX',
	CONCEPT_CLASS_ID = 'CVX',
	CONCEPT_CODE = '133'
WHERE PRD_ID = '2102285';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 40213198,
	CONCEPT_NAME = 'pneumococcal conjugate vaccine, 13 valent',
	VOCABULARY_ID = 'CVX',
	CONCEPT_CLASS_ID = 'CVX',
	CONCEPT_CODE = '133'
WHERE PRD_ID = '61987';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 40213198,
	CONCEPT_NAME = 'pneumococcal conjugate vaccine, 13 valent',
	VOCABULARY_ID = 'CVX',
	CONCEPT_CLASS_ID = 'CVX',
	CONCEPT_CODE = '133'
WHERE PRD_ID = '98764';

UPDATE S_TO_C_MAP
SET CONCEPT_ID = 46275090,
	CONCEPT_NAME = 'Bordetella pertussis filamentous hemagglutinin vaccine, inactivated 0.05 MG/ML / Bordetella pertussis pertactin vaccine, inactivated 0.016 MG/ML / Bordetella pertussis toxoid vaccine, inactivated 0.05 MG/ML / diphtheria toxoid vaccine, inactivated 50 UNT/ML / tetanus toxoid vaccine, inactivated 20 UNT/ML Injection [Infanrix]',
	CONCEPT_CLASS_ID = ' Branded Drug',
	CONCEPT_CODE = '1657881'
WHERE PRD_ID = '109727';

UPDATE s_to_c_map
SET CONCEPT_ID = 19015636,
	CONCEPT_NAME = 'Bryonia preparation',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Ingredient',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '319815',
	VALID_START_DATE = to_date('19700101', 'yyyymmdd'),
	VALID_END_DATE = to_date('20991231', 'yyyymmdd')
WHERE PRD_NAME LIKE '%BRYONIA%'
	AND concept_id IS NULL;

UPDATE s_to_c_map
SET CONCEPT_ID = 36878960,
	CONCEPT_NAME = 'Acerola',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm Extension',
	CONCEPT_CLASS_ID = 'Ingredient',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = 'OMOP992630',
	VALID_START_DATE = to_date('19700101', 'yyyymmdd'),
	VALID_END_DATE = to_date('20991231', 'yyyymmdd')
WHERE PRD_NAME LIKE 'ACEROLA%'
	AND concept_id IS NULL;

UPDATE s_to_c_map
SET CONCEPT_ID = 46276344,
	CONCEPT_NAME = 'Citrullus colocynthis whole extract',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Ingredient',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '1663393',
	VALID_START_DATE = to_date('19700101', 'yyyymmdd'),
	VALID_END_DATE = to_date('20991231', 'yyyymmdd')
WHERE PRD_NAME LIKE '%COLOCYNTHIS%'
	AND concept_id IS NULL;

UPDATE s_to_c_map
SET CONCEPT_ID = 19071833,
	CONCEPT_NAME = 'Arnica montana Extract',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Ingredient',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '285208',
	VALID_START_DATE = to_date('19700101', 'yyyymmdd'),
	VALID_END_DATE = to_date('20991231', 'yyyymmdd')
WHERE PRD_NAME LIKE 'ARNICA%'
	AND concept_id IS NULL;

UPDATE s_to_c_map
SET CONCEPT_ID = 19071836,
	CONCEPT_NAME = 'Calendula officinalis extract',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Ingredient',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '285222',
	VALID_START_DATE = to_date('19700101', 'yyyymmdd'),
	VALID_END_DATE = to_date('20991231', 'yyyymmdd')
WHERE PRD_NAME LIKE '%CALENDULA%'
	AND concept_id IS NULL;

UPDATE s_to_c_map
SET CONCEPT_ID = 19070926,
	CONCEPT_NAME = 'Drosera rotundifolia extract',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Ingredient',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '283557',
	VALID_START_DATE = to_date('19700101', 'yyyymmdd'),
	VALID_END_DATE = to_date('20991231', 'yyyymmdd')
WHERE PRD_NAME LIKE '%DROSERA%'
	AND concept_id IS NULL;

UPDATE s_to_c_map
SET CONCEPT_ID = 42904014,
	CONCEPT_NAME = 'Solanum dulcamara top extract',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Ingredient',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '1331702',
	VALID_START_DATE = to_date('19700101', 'yyyymmdd'),
	VALID_END_DATE = to_date('20991231', 'yyyymmdd')
WHERE PRD_NAME LIKE '%DULCAMARA%'
	AND concept_id IS NULL;

UPDATE s_to_c_map
SET CONCEPT_ID = 19014026,
	CONCEPT_NAME = 'Nux Vomica extract',
	DOMAIN_ID = 'Drug',
	VOCABULARY_ID = 'RxNorm',
	CONCEPT_CLASS_ID = 'Ingredient',
	STANDARD_CONCEPT = 'S',
	CONCEPT_CODE = '314743',
	VALID_START_DATE = to_date('19700101', 'yyyymmdd'),
	VALID_END_DATE = to_date('20991231', 'yyyymmdd')
WHERE PRD_NAME LIKE '%NUX VOMICA%'
	AND concept_id IS NULL;

DROP TABLE IF EXISTS lost_ing;
CREATE TABLE lost_ing AS
SELECT DISTINCT b.prd_id,
	b.prd_name
FROM s_to_c_map a
JOIN s_to_c_map b ON substring(a.prd_name, '\w+') = substring(b.prd_name, '\w+')
WHERE a.domain_id = 'Drug'
	AND b.domain_id IS NULL
	AND NOT b.prd_name ~ 'ELUSAN|DUCRAY|BRYONIA|NUX VOMICA|ALENCO|ACEROLA|COLOCYNTHIS|ALTISA|GAMMADYN|DULCAMARA|LEHNING|ANTI |AESCULUS|LRP |MPH |NOVIDERM|OMEGA|OMNIBIONTA|PHYSIOLOGICA|COMPOSOR|AQUA|ACIDE |BAUME|BIO |MERCURIUS|MOREPA|VITAFYTEA|VOGEL|WIDMER|GLYCERINE|NATRUM|PURE |SENSODYNE|SORIA|STELLA|VANOCOMPLEX|TESTIS|TENA|GILBERT|SORICAPSULE';


DELETE
FROM s_to_c_map
WHERE prd_id IN (
		SELECT prd_id
		FROM gripp
		);

INSERT INTO s_to_c_map
SELECT prd_id,
	prd_name,
	c.*
FROM gripp g
JOIN concept c ON c.concept_id = g.concept_id;

--delete all unnecessary concepts
TRUNCATE TABLE concept_relationship_stage;

TRUNCATE TABLE pack_content_stage;

TRUNCATE TABLE drug_strength_stage;


INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT prd_id,
	m.concept_code,
	dc.vocabulary_id,
	m.vocabulary_id,
	'Maps to',
	CURRENT_DATE,
	to_date('20991231', 'yyyymmdd')
FROM s_to_c_map m
JOIN drug_concept_stage dc ON dc.concept_code = m.prd_id
WHERE concept_id IS NOT NULL
	AND m.vocabulary_id IS NOT NULL

UNION

SELECT concept_code,
	concept_code,
	vocabulary_id,
	vocabulary_id,
	'Maps to',
	CURRENT_DATE,
	to_date('20991231', 'yyyymmdd')
FROM drug_concept_stage
WHERE domain_id = 'Device';

DELETE
FROM concept_stage
WHERE concept_code LIKE 'OMOP%';--save devices and unmapped drug

DELETE
FROM concept_stage
WHERE concept_class_id IN (
		'Dose Form',
		'Brand Name',
		'Supplier',
		'Ingredient'
		);--save devices and unmapped drug

UPDATE concept_stage
SET standard_concept = NULL
WHERE concept_code IN (
		SELECT a.concept_code
		FROM concept_stage a
		LEFT JOIN concept_relationship_stage ON concept_code_1 = a.concept_code
			AND vocabulary_id_1 = a.vocabulary_id
		LEFT JOIN concept c ON c.concept_code = concept_code_2
			AND c.vocabulary_id = vocabulary_id_2
		WHERE a.standard_concept = 'S'
			AND c.concept_id IS NULL
		);

UPDATE concept_stage
SET standard_concept = 'S'
WHERE concept_class_id = 'Device';