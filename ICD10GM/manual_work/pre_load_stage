-- delete from concept_manual table "dead" concepts
DELETE FROM concept_manual
WHERE concept_code NOT IN (SELECT concept_code FROM sources.icd10gm);

--add COVID and E-cig concepts
INSERT INTO concept_synonym_manual (
	synonym_name,
	synonym_concept_code,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT concept_name,
	concept_code,
	'ICD10GM',
	4182504
FROM ddymshyts.sources_icd10gm
WHERE concept_code IN (
		'U07.1',
		'U07.2',
		'U07.0',
		'U99.0'
		);

INSERT INTO concept_manual (
	vocabulary_id,
	concept_code,
	valid_start_date,
	valid_end_date
	)
SELECT 'ICD10GM',
	concept_code,
	to_date('20191101', 'yyyymmdd'),
	to_date('20991231', 'yyyymmdd')
FROM ddymshyts.sources_icd10gm
WHERE concept_code IN ('U07.0');

INSERT INTO concept_manual (
	vocabulary_id,
	concept_code,
	valid_start_date,
	valid_end_date
	)
SELECT 'ICD10GM',
	concept_code,
	to_date('20200213', 'yyyymmdd'),
	to_date('20991231', 'yyyymmdd')
FROM ddymshyts.sources_icd10gm
WHERE concept_code IN ('U07.1');

INSERT INTO concept_manual (
	vocabulary_id,
	concept_code,
	valid_start_date,
	valid_end_date
	)
SELECT 'ICD10GM',
	concept_code,
	to_date('20200323', 'yyyymmdd'),
	to_date('20991231', 'yyyymmdd')
FROM ddymshyts.sources_icd10gm
WHERE concept_code IN ('U07.2');

INSERT INTO concept_manual (
	vocabulary_id,
	concept_code,
	valid_start_date,
	valid_end_date
	)
SELECT 'ICD10GM',
	concept_code,
	to_date('20200525', 'yyyymmdd'),
	to_date('20991231', 'yyyymmdd')
FROM ddymshyts.sources_icd10gm
WHERE concept_code IN ('U99.0');

UPDATE concept_manual
SET concept_name = 'Emergency use of U07.0 | Vaping-related disorder'
WHERE concept_code = 'U07.0';

UPDATE concept_manual
SET concept_name = 'Emergency use of U07.1 | COVID-19, virus identified'
WHERE concept_code = 'U07.1';

UPDATE concept_manual
SET concept_name = 'Emergency use of U07.2 | COVID-19, virus not identified'
WHERE concept_code = 'U07.2';

UPDATE concept_manual
SET concept_name = 'Special procedures for testing for SARS-CoV-2'
WHERE concept_code = 'U99.0';

UPDATE concept_manual
SET concept_class_id = 'ICD10 code'
WHERE concept_code = 'U99.0';

--create output for tranlation
SELECT c.concept_code,
	synonym_name
FROM concept_synonym_stage s
JOIN concept_stage c ON s.synonym_concept_code = c.concept_code
WHERE c.concept_name IS NULL;

--upload translated version
CREATE TABLE new_concepts_en (
	concept_code VARCHAR,
	concept_name VARCHAR
	);

--import translations
WbImport -file=C:/work/ICD10GM/new_concepts_en_GT.txt
         -type=text
         -table=new_concepts_en
         -encoding=Cp1251
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -decimal=.
         -fileColumns=concept_code,concept_name
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=1000;


--add translations to the concept_manual
INSERT INTO concept_manual (
	concept_name,
	vocabulary_id,
	concept_code,
	concept_class_id
	)
SELECT concept_name,
	'ICD10GM',
	concept_code,
	CASE 
		WHEN LENGTH(concept_code) = 3
			THEN 'ICD10 Hierarchy'
		ELSE 'ICD10 code'
		END AS concept_class_id
FROM new_concepts_en;

UPDATE concept_manual m
SET concept_name = (
		SELECT concept_name
		FROM concept_stage c
		WHERE m.concept_code = c.concept_code
		)
WHERE m.concept_name IS NULL;

--create file for medical coder which will used for mapping
SELECT g.concept_code,
	s.synonym_name AS german_name,
	c.concept_name AS english_name
FROM concept_synonym_stage s
JOIN concept_stage g ON g.concept_code = s.synonym_concept_code
LEFT JOIN concept c ON c.concept_code = g.concept_code
	AND c.vocabulary_id IN (
		'ICD10',
		'ICD10GM'
		);
