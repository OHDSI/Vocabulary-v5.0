--change the dates according to the release date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'BDPM',
	pVocabularyDate			=> TO_DATE ('20180622', 'yyyymmdd'),
	pVocabularyVersion		=> 'BDPM 20180622',
	pVocabularyDevSchema	=> 'DEV_BDPM'
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'RxNorm Extension',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'RxNorm Extension '||CURRENT_DATE,
	pVocabularyDevSchema	=> 'DEV_BDPM',
	pAppendVocabulary		=> TRUE
);
END $_$;

TRUNCATE TABLE drug_concept_stage;
TRUNCATE TABLE ds_stage;
TRUNCATE TABLE internal_relationship_stage;
TRUNCATE TABLE relationship_to_concept;
TRUNCATE TABLE pc_stage;
TRUNCATE TABLE concept_synonym_stage;

DROP TABLE IF EXISTS non_drug;
CREATE TABLE non_drug AS
SELECT b.drug_code,
	drug_descr,
	ingredient,
	form,
	form_code
FROM sources.bdpm_ingredient a
JOIN sources.bdpm_drug b ON a.drug_code = b.drug_code
WHERE form_code IN (
		'4307',
		'9354',
		'77898',
		'87188',
		'94901',
		'41804',
		'14832',
		'72310',
		'89969',
		'49487',
		'24033',
		'31035',
		'66548',
		'16621',
		'31035'
		)
	OR dosage LIKE '%Bq%'
	OR form LIKE '%dialyse%';

--insert radiopharmaceutical drugs
INSERT INTO non_drug (
	drug_code,
	drug_descr,
	ingredient,
	form,
	form_code
	)
SELECT a.drug_code,
	drug_descr,
	ingredient,
	form,
	form_code
FROM sources.bdpm_drug a
JOIN sources.bdpm_ingredient b ON a.drug_code = b.drug_code
WHERE form LIKE '%radio%'
	AND a.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		);

--ingredients used in diagnostics
INSERT INTO non_drug (
	drug_code,
	drug_descr,
	ingredient,
	form,
	form_code
	)
SELECT a.drug_code,
	drug_descr,
	ingredient,
	form,
	form_code
FROM sources.bdpm_drug a
JOIN sources.bdpm_ingredient b ON a.drug_code = b.drug_code
WHERE ingredient LIKE '%IOXITALAM%'
	OR ingredient LIKE '%GADOTÉR%'
	OR ingredient LIKE '%AMIDOTRIZOATE%'
	OR form_code='86327'
	AND a.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		);

--patterns for dosages
INSERT INTO non_drug (
	drug_code,
	ingredient,
	form_code
	)
SELECT DISTINCT drug_code,
	ingredient,
	form_code
FROM sources.bdpm_ingredient a
WHERE a.drug_code IN (
		SELECT drug_code
		FROM sources.bdpm_packaging
		WHERE packaging LIKE '%compartiment%'
		)
	AND (
		drug_form LIKE '%compartiment%'
		OR drug_form = '%émulsion%'
		)
	AND drug_form NOT LIKE '%compartiment A%'
	AND drug_form NOT LIKE '%compartiment B%'
	AND drug_form NOT LIKE '%compartiment C%'
	AND drug_form NOT LIKE '%compartiment (A)%'
	AND drug_form NOT LIKE '%compartiment (B)%'
	AND a.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		);

--some patterns
INSERT INTO non_drug (
	drug_code,
	drug_descr,
	ingredient,
	form,
	form_code
	)
SELECT a.drug_code,
	drug_descr,
	ingredient,
	form,
	form_code
FROM sources.bdpm_drug a
LEFT JOIN sources.bdpm_ingredient b ON a.drug_code = b.drug_code
WHERE drug_descr ~* 'hémofiltration|AMINOMIX|dialys|test|radiopharmaceutique|MIBG|STRUCTOKABIVEN|NUMETAN|NUMETAH|REANUTRIFLEX|CLINIMIX|REVITALOSE|CONTROLE|IOMERON|HEXABRIX|XENETIX'
	AND a.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		);
--exclude Xofigo		
DELETE FROM non_drug
	WHERE ingredient LIKE '%RADIUM%223%';		
		
--create table with homeopathic drugs as they will be proceeded in different way
DROP TABLE IF EXISTS homeop_drug;
CREATE TABLE homeop_drug AS
SELECT a.*
FROM sources.bdpm_ingredient a
JOIN sources.bdpm_drug b ON a.drug_code = b.drug_code
WHERE ingredient LIKE '%HOMÉOPA%'
	OR drug_descr LIKE '%degré de dilution compris entre%';

DROP TABLE IF EXISTS packaging_pars_1;
CREATE TABLE packaging_pars_1 AS
SELECT din_7,
	drug_code,
	packaging,
	CASE 
		WHEN packaging ~ '^[[:digit:].,]+\s*(mg|g|ml|litre|l)(\s|$|\,)'
			THEN substring(packaging, '(^[[:digit:].,]+\s*(mg|g|ml|litre|l))')
		ELSE substring(packaging, 'de.*')
		END AS amount,
	CASE 
		WHEN NOT packaging ~ '^\d+\s*(mg|g|ml|litre|l)(\s|$|\,)'
	    	     AND substring(packaging, '^\d+')!='0'
			THEN substring(packaging, '^\d+')
		ELSE NULL
		END::INT AS box_size
FROM sources.bdpm_packaging;

--remove spaces in amount
UPDATE packaging_pars_1
SET amount = regexp_replace(amount, '([[:digit:]]+) ([[:digit:]]+)', '\1\2')
WHERE amount ~ '[[:digit:]]+ [[:digit:]]+';

---!!need to check inhalers
--select * from packaging_pars_1 WHERE amount LIKE '%dose(s)%';
--ignore "dose"
UPDATE packaging_pars_1
SET amount = NULL
WHERE amount LIKE '%dose(s)%';

--!!!! do not catch comprime etc
-- define box size and amount (Quant factor mostly)
DROP TABLE IF EXISTS packaging_pars_2;
CREATE TABLE packaging_pars_2 AS
SELECT
	CASE 
		WHEN NOT p.amount ~* '[[:digit:].,]+\s*(ml|g|mg|l|UI|MBq/ml|GBq/ml|litre(s*)|à|mlavec|kg)(\s|$|\,)'
			AND (replace(substring(p.amount, '[[:digit:].,]+'), ',', '.')) IS NOT NULL
			THEN substring(p.amount, '\d+')::INT * coalesce(box_size, 1)
		ELSE box_size
		END AS box_size,
	l.amount,			     
	din_7,
	drug_code,
	packaging
FROM packaging_pars_1 p
LEFT JOIN LATERAL(
	SELECT unnest(regexp_matches(p.amount, '([[:digit:].,]+\s*(?:ml|g|mg|l|UI|MBq/ml|GBq/ml|litres|kg))(?:\s|$|\,)', 'i')) 
				     AS amount) l ON true
;

--pars amount to value and unit
DROP TABLE IF EXISTS packaging_pars_3;
CREATE TABLE packaging_pars_3 AS
SELECT replace(substring(amount, '[[:digit:].,]+'), ',', '.')::FLOAT AS amount_value,
	l.amount_unit,
	box_size,
	din_7,
	drug_code,
	packaging
FROM packaging_pars_2
LEFT JOIN LATERAL(SELECT unnest(regexp_matches(amount, '(ml|g|mg|l|UI|MBq/ml|GBq/ml|litre(?:s*)|kg)', 'i')) AS amount_unit) l ON true;

--manual fix
UPDATE packaging_pars_3
SET amount_value = 5.5,
	amount_unit = 'ml'
WHERE din_7 = 3328273
	AND packaging = 'poudre en flacon(s) en verre + 5,5 ml de solvant en flacon(s) en verre';

UPDATE packaging_pars_3
SET amount_value = '1',
	amount_unit = 'ml'
WHERE din_7 = 5500089
	AND packaging = 'système à double seringues (polypropylène) 1 * 2 ml (1 ml + 1 ml) avec piston, clippées dans un double porte-seringue et munies de capuchons, avec un set de dispositifs d''application constitué de 2 pièces de raccordement et de 4 canules d''application';

UPDATE packaging_pars_3
SET amount_value = '2',
	amount_unit = 'ml'
WHERE din_7 = 5500091
	AND packaging = 'système à double seringues (polypropylène) 1 * 4 ml (2 ml + 2 ml) avec piston, clippées dans un double porte-seringue et munies de capuchons, avec un set de dispositifs d''application constitué de 2 pièces de raccordement et de 4 canules d''application';

UPDATE packaging_pars_3
SET amount_value = '5',
	amount_unit = 'ml'
WHERE din_7 = 5500092
	AND packaging = 'système à double seringues (polypropylène) 1 * 10 ml (5 ml + 5 ml) avec piston, clippées dans un double porte-seringue et munies de capuchons, avec un set de dispositifs d''application constitué de 2 pièces de raccordement et de 4 canules d''application';

UPDATE packaging_pars_3
SET amount_value = '20',
	amount_unit = 'ml'
WHERE din_7 = 5645150
	AND packaging = 'Poudre en flacon(s) en verre + 20 ml de solvant flacon(s) en verre avec aiguille(s), une seringue à usage unique (polypropylène) et un nécessaire d''injection + un dispositif de transfert BAXJECT II HI-Flow';

UPDATE packaging_pars_3
SET amount_value = '5.5',
	amount_unit = 'ml'
WHERE din_7 = 3328310
	AND packaging = 'poudre en flacon(s) en verre + 5,5 ml de solvant en flacon(s) en verre';

UPDATE packaging_pars_3
SET amount_value = '20',
	amount_unit = 'ml'
WHERE din_7 = 5645144
	AND packaging = 'Poudre en flacon(s) en verre + 20 ml de solvant flacon(s) en verre avec aiguille(s), une seringue à usage unique (polypropylène) et un nécessaire d''injection + un dispositif de transfert BAXJECT II HI-Flow';

UPDATE packaging_pars_3
SET amount_value = '0.5',
	amount_unit = 'ml'
WHERE din_7 = 5611085
	AND packaging = '2 poudres en flacons en verre et 2 fois 0,5 ml de solution en flacons en verre avec nécessaire d''application';

UPDATE packaging_pars_3
SET amount_value = '1',
	amount_unit = 'ml'
WHERE din_7 = 5611091
	AND packaging = '2 poudres en flacons en verre et 2 fois 1 ml de solution en flacons en verre avec nécessaire d''application';

UPDATE packaging_pars_3
SET amount_value = '3',
	amount_unit = 'ml'
WHERE din_7 = 5611116
	AND packaging = '2 poudres en flacons en verre et 2 fois 3 ml de solution en flacons en verre avec nécessaire d''application';

--mistakes in the orinal table fixing
-- <<moved to sources.load_input_tables>>

--find relationships between ingredients within the one drug
DROP TABLE IF EXISTS drug_ingred_to_ingred;
CREATE TABLE drug_ingred_to_ingred AS
SELECT DISTINCT a.drug_code,
	a.form_code AS concept_code_1,
	a.ingredient AS concept_name_1,
	b.form_code AS concept_code_2,
	b.ingredient AS concept_name_2
FROM sources.bdpm_ingredient a
JOIN sources.bdpm_ingredient b ON a.drug_code = b.drug_code
	AND a.comp_number = b.comp_number
	AND a.ingredient != b.ingredient
	AND a.ingr_nature = 'SA'
	AND b.ingr_nature = 'FT';

--exclude homeopic_drugs and precise ingredients
DROP TABLE IF EXISTS ingredient_step_1;
CREATE TABLE ingredient_step_1 AS
SELECT *
FROM sources.bdpm_ingredient a
WHERE NOT EXISTS (
		SELECT 1
		FROM drug_ingred_to_ingred b
		WHERE a.drug_code = b.drug_code
			AND form_code = concept_code_1
		)
	AND drug_code NOT IN (
		SELECT drug_code
		FROM homeop_drug
		);

--manual fix of dosages
UPDATE ingredient_step_1
SET dosage = '1000000 Ul'
WHERE drug_code = '68039248'
	AND ingredient = 'SULFATE DE POLYMYXINE B';

UPDATE ingredient_step_1
SET dosage = '100000 UI'
WHERE form_code = '04031'
	AND dosage = '100  000 UI';

UPDATE ingredient_step_1
SET dosage = '30000000 U'
WHERE drug_code='60973899';

--spaces in dosages
UPDATE ingredient_step_1
SET dosage = regexp_replace(dosage, '(?<=[[:digit:],])\s(?=[[:digit:],])', '', 'g')
WHERE dosage ~ '[[:digit:],]+ [[:digit:],]+';

--spaces in volume
UPDATE ingredient_step_1
SET volume = regexp_replace(volume, '(?<=[[:digit:],])\s(?=[[:digit:],])', '', 'g')
WHERE volume ~ '[[:digit:],]+ [[:digit:],]+';

--manual fix of dosages
UPDATE ingredient_step_1
SET dosage = '31250000000 U'
WHERE dosage like '31,25 * 10^9%';

UPDATE ingredient_step_1
SET dosage = '1000 DICC50'
WHERE dosage = 'au minimum 10^^3,0 DICC50';

UPDATE ingredient_step_1
SET dosage = '800000 UFC'
WHERE dosage = '2-8 x 10^5 UFC';

UPDATE ingredient_step_1
SET dosage = '2000 DICC50'
WHERE dosage = 'au minimum 10^^3,3 DICC50';

UPDATE ingredient_step_1
SET dosage = '5000 DICC50'
WHERE dosage = 'au minimum 10^^3,7 DICC50';

UPDATE ingredient_step_1
SET dosage = '10000000 U'
WHERE dosage = '10^(7+/- 0,5)';

UPDATE ingredient_step_1
SET dosage = '1 millions UI'
WHERE dosage LIKE '1 million d%unités internationales (UI)';

--parsing dosages taking exact digit - unit pares 
DROP TABLE IF EXISTS ingredient_step_2;
CREATE TABLE ingredient_step_2 AS
SELECT drug_code,
	drug_form,
	form_code,
	ingredient,
	dosage,
	volume,
	ingr_nature,
	comp_number,
	--fix inaccuracies coming from original data
	CASE dosage_value
		WHEN '.5'
			THEN '0.5'
		WHEN '200.000.000'
			THEN '200000000'
		WHEN '1.000.000'
			THEN '1000000'
		WHEN '19.000.000'
			THEN '19000'
		ELSE dosage_value
		END::FLOAT dosage_value,
	dosage_unit,
	volume_value,
	volume_unit
FROM (
	SELECT a.*,
		replace(substring(dosage, '([[:digit:].,]+)\s*(UI|UFC|IU|micromoles|µmol|g|mg|mcg|microgramme(s*)|µg|millions UI|MBq|DICC50|UIK|unités FEIBA|Gbq|UFP|U\.CEIP|ml|U|IR|unités Antihéparine|log  DICC50|nanogrammes|M(\.|\s)U\.I\.|UD (unité antigène D)|MU|Ul|unités|%|U\.I\.|ATU|mmol|mEq|DL50|U\.l\.|unités|MUI|U\.|unités antigène D|Millions UI|ppm mole|UI|kBq|SQ-T|milliard|microlitres|nanokatals|UD \(unité antigène D\)|unité antigène D|M UI|DICT50|micrcrogrammes|GBq|mg.|M.UI|MBq/ml|UD|UIK.|Mq|millions d.UI|U.I|U.D.|ng)(\s|$)'), ',', '.') AS dosage_value,
		substring(dosage, '[[:digit:].,]+\s*((UI|UFC|micromoles|IU|µmol|g|mg|mcg|microgramme(s*)|µg|millions UI|MBq|DICC50|UIK|unités FEIBA|Gbq|UFP|U\.CEIP|ml|U|IR|unités Antihéparine|log  DICC50|nanogrammes|M(\.|\s)U\.I\.|UD (unité antigène D)|MU|Ul|unités|%|U\.I\.|ATU|mmol|mEq|DL50|U\.l\.|unités|MUI|U\.|unités antigène D|Millions UI|ppm mole|UI|kBq|SQ-T|milliard|microlitres|nanokatals|UD \(unité antigène D\)|unité antigène D|M UI|DICT50|micrcrogrammes|GBq|mg.|M.UI|MBq/ml|UD|UIK.|Mq|millions d.UI|U.I|U.D.|ng)(\s|$))') AS dosage_unit,
		replace(substring(volume, '([[:digit:].,]+)\s*(cm *²|g|ml|cm\^2)') -- for denominartor
			, ',', '.')::FLOAT AS volume_value,
		substring(volume, '[[:digit:].,]+\s*(cm *²|g|ml|cm\^2)') AS volume_unit
	FROM ingredient_step_1 a
	) AS s;

--recalculate all the possible combinations between packaging info and ingredient info
DROP TABLE IF EXISTS ds_1;
CREATE TABLE ds_1 AS
SELECT DISTINCT din_7::varchar AS concept_code,
	a.drug_code,
	drug_form,
	form_code AS ingredient_code,
	ingredient AS ingredient_name,
	packaging,
	d.drug_descr,
	dosage_value,
	dosage_unit,
	volume_value,
	volume_unit,
	amount_value AS pack_amount_value,
	amount_unit AS pack_amount_unit,
	CASE 
		WHEN volume_value IS NULL
			AND amount_value IS NULL
			AND dosage_unit != '%'
			THEN dosage_value
		ELSE NULL
		END AS amount_value,
	CASE 
		WHEN volume_value IS NULL
			AND amount_value IS NULL
			AND dosage_unit != '%'
			THEN dosage_unit
		ELSE NULL
		END AS amount_unit,
	CASE 
		WHEN volume_value IS NOT NULL
			AND amount_value IS NOT NULL
			AND dosage_unit != '%'
			AND (
				lower(coalesce(volume_unit, amount_unit)) = lower(coalesce(amount_unit, volume_unit))
				OR volume_unit = 'g'
				AND amount_unit = 'ml'
				)
			THEN dosage_value / volume_value * amount_value
		WHEN volume_value IS NOT NULL
			AND amount_value IS NULL
			AND dosage_unit != '%'
			AND lower(coalesce(volume_unit, amount_unit)) = lower(coalesce(amount_unit, volume_unit))
			THEN dosage_value
		WHEN volume_value IS NULL
			AND amount_value IS NOT NULL
			AND dosage_unit != '%'
			AND lower(coalesce(volume_unit, amount_unit)) = lower(coalesce(amount_unit, volume_unit))
			THEN dosage_value
		WHEN (
				volume_value IS NOT NULL
				OR amount_value IS NOT NULL
				)
			AND dosage_unit != '%'
			AND lower(volume_unit) = CONCAT (
				'm',
				lower(amount_unit)
				)
			THEN dosage_value / coalesce(volume_value, 1) * coalesce(amount_value, 1) * 1000
		WHEN (
				volume_value IS NOT NULL
				OR amount_value IS NOT NULL
				)
			AND dosage_unit != '%'
			AND lower(amount_unit) = CONCAT (
				'k',
				lower(volume_unit)
				)
			THEN dosage_value / coalesce(volume_value, 1) * coalesce(amount_value, 1) * 1000
				/*volume (7g) / (sum (125 mg) * dosage - this is numerator
1 ml * volume (7g) / (sum (dosage) group by within one drug) - this is denumerator
*/
				--not so simple
		WHEN lower(volume_unit) = 'ml'
			AND (
				lower(amount_unit) LIKE '%g%'
				OR amount_unit = 'UI'
				)
			THEN amount_value / dos_sum * dosage_value
		WHEN dosage_unit = '%'
			THEN dosage_value
		ELSE NULL
		END AS numerator_value,
	CASE 
		WHEN (
				volume_value IS NOT NULL
				OR amount_value IS NOT NULL
				)
			THEN dosage_unit
		WHEN dosage_unit = '%'
			THEN '%'
		WHEN lower(volume_unit) = 'ml'
			AND (
				lower(amount_unit) LIKE '%g%'
				OR amount_unit = 'UI'
				)
			THEN amount_unit
		ELSE NULL
		END AS numerator_unit,
	CASE 
		WHEN lower(volume_unit) = 'ml'
			AND (
				lower(amount_unit) LIKE '%g%'
				OR amount_unit = 'UI'
				)
			THEN volume_value * amount_value / dos_sum
		ELSE coalesce(amount_value, volume_value)
		END AS denominator_value,
	CASE 
		WHEN lower(volume_unit) = 'ml'
			AND (
				lower(amount_unit) LIKE '%g%'
				OR amount_unit = 'UI'
				)
			THEN volume_unit
		ELSE coalesce(amount_unit, volume_unit)
		END AS denominator_unit,
	box_size
FROM packaging_pars_3 a
JOIN ingredient_step_2 b ON a.drug_code = b.drug_code
JOIN sources.bdpm_drug d ON b.drug_code = d.drug_code
JOIN (
	SELECT drug_code,
		sum((dosage_value)) AS dos_sum
	FROM ingredient_step_2
	GROUP BY drug_code
	) s ON s.drug_code = a.drug_code;

--update when we have drug description containing dosage (unit!= %)
UPDATE ds_1
SET amount_value = replace(substring(drug_descr, '([[:digit:].,]+)\s*(UI|IU|µmol|g|mg|mcg|microgramme(s*)|µg|millions UI|MBq|DICC50|UIK|unités FEIBA|Gbq|UFP|U\.CEIP|ml|U|IR|unités Antihéparine|log  DICC50|nanogrammes|M(\.|\s)U\.I\.|UD (unité antigène D)|MU|Ul|unités|U\.I\.|ATU|mmol|mEq|DL50|U\.l\.|unités|MUI|U\.|unités antigène D|Millions UI|ppm mole|UI|kBq|SQ-T|milliard|microlitres|nanokatals|UD \(unité antigène D\)|unité antigène D|M UI|DICT50|micrcrogrammes|GBq|mg.|M.UI|MBq/ml|UD|UIK.|Mq|millions d.UI|U.I|U.D.|ng)(\s|$|\,)'), ',', '.')::FLOAT,
	amount_unit = substring(drug_descr, '[[:digit:].,]+\s*(UI|IU|µmol|g|mg|mcg|microgramme(s*)|µg|millions UI|MBq|DICC50|UIK|unités FEIBA|Gbq|UFP|U\.CEIP|ml|U|IR|unités Antihéparine|log  DICC50|nanogrammes|M(\.|\s)U\.I\.|UD (unité antigène D)|MU|Ul|unités|U\.I\.|ATU|mmol|mEq|DL50|U\.l\.|unités|MUI|U\.|unités antigène D|Millions UI|ppm mole|UI|kBq|SQ-T|milliard|microlitres|nanokatals|UD \(unité antigène D\)|unité antigène D|M UI|DICT50|micrcrogrammes|GBq|mg.|M.UI|MBq/ml|UD|UIK.|Mq|millions d.UI|U.I|U.D.|ng)(\s|$|\,)')
WHERE drug_descr ~ '[[:digit:].,]+\s*(UI|IU|µmol|g|mg|mcg|microgramme(s*)|µg|millions UI|MBq|DICC50|UIK|unités FEIBA|Gbq|UFP|U\.CEIP|ml|U|IR|unités Antihéparine|log  DICC50|nanogrammes|M(\.|\s)U\.I\.|UD (unité antigène D)|MU|Ul|unités|U\.I\.|ATU|mmol|mEq|DL50|U\.l\.|unités|MUI|U\.|unités antigène D|Millions UI|ppm mole|UI|kBq|SQ-T|milliard|microlitres|nanokatals|UD \(unité antigène D\)|unité antigène D|M UI|DICT50|micrcrogrammes|GBq|mg.|M.UI|MBq/ml|UD|UIK.|Mq|millions d.UI|U.I|U.D.|ng)(\s|$|\,)'
	AND amount_value IS NULL
	AND numerator_value IS NULL;

--update when we have drug description containing dosage (unit = %)
UPDATE ds_1
SET numerator_value = replace(substring(drug_descr, '([[:digit:].,]+)\s*%'), ',', '.')::FLOAT,
	numerator_unit = substring(drug_descr, '[[:digit:].,]+\s*(%)(\s|$|\,)')
WHERE drug_descr ~ '[[:digit:].,]+\s*%'
	AND amount_value IS NULL
	AND numerator_value IS NULL;

--UPDATE unitS WITH translation OF unitS
--HERE SHOULD BE KIND OF MANUAL TABLES DESCRIPTION, BECAUSE unit_translation WE GOT FROM ds_1 BEFORE THIS UPDATE
DROP TABLE IF EXISTS unit_translation;
CREATE TABLE unit_translation (
	unit VARCHAR(100),
	translation VARCHAR(100)
	);

INSERT INTO unit_translation
VALUES
	('%','%'),
	('ATU',	'ATU'),
	('DICC50',	'CCID_50'),
	('DICT50',	'tcid_50'),
	('DL50',	'DL50'),
	('G',	'g'),
	('IR',	'IR'),
	('IU',	'IU'),
	('M U.I.',	'Million IU'),
	('M UI',	'Million IU'),
	('M.U.I.',	'Million IU'),
	('M.UI',	'Million IU'),
	('MU',	'Million U'),
	('Millions UI',	'Million IU'),
	('Mq',	'Mq'),
	('SQ-T',	'SQ-T'),
	('U',	'U'),
	('U.CEIP',	'U.CEIP'),
	('UFP',	'UFP'),
	('UI',	'IU'),
	('unités FEIBA',	'unit FEIBA'),
	('cm ²',	'cm²'),
	('cm^2',	'cm²'),
	('cm²',	'cm²'),
	('kg',	'kg'),
	('l',	'l'),
	('log  DICC50',	'log CCID_50'),
	('mEq',	'mEq'),
	('mL',	'ml'),
	('mg',	'mg'),
	('micrcrogrammes',	'mcg'),
	('microgramme',	'mcg'),
	('microgrammes',	'mcg'),
	('microlitres',	'microliter'),
	('micromoles',	'microliter'),
	('milliard',	'U'),
	('millions UI',	'Million IU'),
	('millions d''UI',	'Million IU'),
	('mmol',	'mmol'),
	('nanogrammes',	'ng'),
	('nanokatals',	'nanokatal'),
	('ng',	'ng'),
	('ppm mole',	'ppm mole'),
	('unités',	'U'),
	('µg',	'mcg'),
	('µmol',	'mcmol')
	('UIK',	'U'),
	('UIK.',	'U'),
	('U.D',	'U'),
	('Unités',	'U'),
	('Unité',	'U'),
	('UD (Unité antigène D)',	'U'),
	('Unités antigène D',	'U'),
	('Unités Antihéparine',	'U'),
	('Ul',	'U'),
	('U.I',	'U'),
	('U.D.',	'U'),
	('Unité antigène D',	'U'), ;

UPDATE ds_1
SET amount_unit = (
		SELECT translation
		FROM unit_translation --manual table
		WHERE trim(upper(amount_unit)) = upper(unit)
		)
WHERE EXISTS (
		SELECT 1
		FROM unit_translation
		WHERE trim(upper(amount_unit)) = upper(unit)
		);			   

UPDATE ds_1
SET numerator_unit = (
		SELECT translation
		FROM unit_translation
		WHERE trim(upper(numerator_unit)) = upper(unit)
		)
WHERE EXISTS (
		SELECT 1
		FROM unit_translation
		WHERE trim(upper(numerator_unit)) = upper(unit)
		);

UPDATE ds_1
SET denominator_unit = (
		SELECT translation
		FROM unit_translation
		WHERE trim(upper(denominator_unit)) = upper(unit)
		)
WHERE EXISTS (
		SELECT 1
		FROM unit_translation
		WHERE trim(upper(denominator_unit)) = upper(unit)
		);

--make sure we don't include non-drug into ds_stage
DELETE
FROM ds_1
WHERE drug_code IN (
		SELECT drug_code
		FROM non_drug
		);
--manual ds_1 fixes
UPDATE ds_1
	SET amount_value = 20,
	    amount_unit = 'mg'
WHERE concept_code = '3646843';			   

UPDATE ds_1
SET numerator_unit = 'mg'
WHERE concept_code = '5654597'
	AND ingredient_code = '01080';

--for gazes consider whole volume as amount
UPDATE ds_1
SET amount_value = denominator_value,
	amount_unit = denominator_unit,
	numerator_value = NULL,
	numerator_unit = NULL,
	denominator_value = NULL,
	denominator_unit = NULL
WHERE drug_form = 'gaz'
	AND amount_value IS NULL
	AND amount_unit IS NULL;

DROP TABLE pack_st_1;
CREATE TABLE pack_st_1 AS
SELECT drug_code,
	drug_form,
	form_code
FROM ingredient_step_1
WHERE drug_code IN (
		SELECT drug_code
		FROM (
			SELECT DISTINCT drug_code,
				drug_form
			FROM ingredient_step_1
			) AS s0
		GROUP BY drug_code
		HAVING count(1) > 1
		)
	AND drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		)
	AND drug_code NOT IN (
		SELECT drug_code
		FROM homeop_drug
		)
	AND drug_code NOT IN (
		'64122611',
		'67657035'
		);

--sequence will be used in pack component definition
DROP SEQUENCE IF EXISTS pack_sequence;
CREATE SEQUENCE pack_sequence MINVALUE 1 MAXVALUE 1000000 START WITH 1 INCREMENT BY 1 CACHE 100;

--take all the pack components 
DROP TABLE IF EXISTS pack_comp_list;
CREATE TABLE pack_comp_list AS
SELECT 'PACK' || nextval('pack_sequence') AS pack_component_code,
	a.*
FROM (
	SELECT DISTINCT a.drug_code,
		a.drug_form,
		drug_descr,
		denominator_value,
		denominator_unit
	FROM ds_1 a
	JOIN pack_st_1 b ON a.drug_code = b.drug_code
		AND a.drug_form = b.drug_form
		AND a.ingredient_code = form_code
	WHERE a.drug_code NOT IN (
			SELECT drug_code
			FROM non_drug
			)
	) A;

--pack content, but need to put amounts manualy
DROP TABLE IF EXISTS pack_cont_1;
CREATE TABLE pack_cont_1 AS
SELECT DISTINCT concept_code,
	pack_component_code,
	a.drug_descr AS pack_name,
	CONCAT (
		a.drug_descr,
		' ',
		a.drug_form
		) AS pack_component_name,
	packaging --, amount_value, amount_drug_code,drug_form,drug_descr,denominator_value,denominator_unit
FROM pack_comp_list B
JOIN ds_1 A ON a.drug_code = b.drug_code
	AND a.drug_form = b.drug_form
	AND a.drug_descr = b.drug_descr
	AND coalesce(a.denominator_value, '0') = coalesce(b.denominator_value, '0')
	AND coalesce(a.denominator_unit, '0') = coalesce(b.denominator_unit, '0');

UPDATE pack_cont_1
SET pack_component_name = 'INERT INGREDIENT Metered Dose Inhaler'
WHERE concept_code = '5731866'
	AND pack_component_name LIKE '%ARIDOL, poudre pour inhalation en gélule gélule transparente%';

--ds_stage for Pack_components 
DROP TABLE IF EXISTS ds_pack_1;
CREATE TABLE ds_pack_1 AS
SELECT pack_component_code,
	a.drug_form,
	ingredient_code,
	ingredient_name,
	packaging,
	a.drug_descr,
	dosage_value,
	dosage_unit,
	volume_value,
	volume_unit,
	pack_amount_value,
	PACK_amount_unit,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	a.denominator_value,
	a.denominator_unit,
	NULL::INT AS box_size
FROM ds_1 a
JOIN pack_comp_list b ON coalesce(a.denominator_value, '0') = coalesce(b.denominator_value, '0')
	AND coalesce(a.denominator_unit, '0') = coalesce(b.denominator_unit, '0')
	AND a.drug_form = b.drug_form
	AND a.drug_code = b.drug_code;

--pack components forms 
DROP TABLE IF EXISTS pf_from_pack_comp_list;
CREATE TABLE pf_from_pack_comp_list AS
SELECT DISTINCT pack_component_code, -- ROUTE,drug_form,
	CASE 
		WHEN drug_form LIKE '%comprimé%'
			THEN 'Oral Tablet'
		WHEN (
				drug_form LIKE '%sachet%'
				OR drug_form LIKE '%solution%'
				OR drug_form LIKE '%poche%'
				OR drug_form LIKE '%poudre%'
				OR drug_form LIKE '%solvant%'
				)
			AND ROUTE = 'orale'
			THEN 'Oral Solution'
		WHEN drug_form LIKE '%granulés%'
			THEN 'Oral Granules'
		WHEN drug_form LIKE '%gélule%'
			AND ROUTE = 'orale'
			THEN 'Oral Capsule'
		WHEN drug_form LIKE '%gélule%'
			AND ROUTE = 'inhalée'
			THEN 'Metered Dose Inhaler'
		WHEN drug_form LIKE '%poudre%'
			AND ROUTE = 'inhalée'
			THEN 'Inhalant Powder'
		WHEN (
				drug_form LIKE '%solution%'
				OR drug_form LIKE '%poudre%'
				OR drug_form LIKE '%solvant%'
				)
			AND ROUTE = 'nasale'
			THEN 'Nasal Solution'
		WHEN drug_form LIKE '%solution%'
			OR drug_form LIKE '%poudre%'
			OR drug_form LIKE '%solvant%'
			THEN 'Injectable Solution'
		WHEN drug_form LIKE '%suspension%'
			OR drug_form LIKE 'émulsion%'
			THEN 'Injectable Suspension'
		WHEN drug_form LIKE '%dispositif%'
			THEN 'Transdermal Patch'
		ELSE 'Injectable Solution'
		END AS pack_form
FROM pack_comp_list pcl
JOIN sources.bdpm_drug d ON d.drug_code = pcl.drug_code;

--ds_1 for drugs and ds_pack_1 for packs
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
SELECT concept_code::VARCHAR,
	ingredient_code,
	box_size,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
FROM ds_1
WHERE concept_code NOT IN (
		SELECT concept_code
		FROM pack_cont_1
		)

UNION

SELECT pack_component_code,
	ingredient_code,
	box_size,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
FROM ds_pack_1;

--sum up the same ingredients manualy
DELETE
FROM ds_stage
WHERE drug_concept_code = '3087355'
	AND ingredient_concept_code = '5356'
	AND box_size = 20
	AND amount_value IS NULL
	AND amount_unit IS NULL
	AND numerator_value = 1.4
	AND numerator_unit = 'g'
	AND denominator_value = 10
	AND denominator_unit = 'g';

DELETE
FROM ds_stage
WHERE drug_concept_code = '3200509'
	AND ingredient_concept_code = '1261'
	AND box_size = 1
	AND amount_value IS NULL
	AND amount_unit IS NULL
	AND numerator_value = 5
	AND numerator_unit = 'mg'
	AND denominator_value = 1
	AND denominator_unit = 'ml';

DELETE
FROM ds_stage
WHERE drug_concept_code = '3205777'
	AND ingredient_concept_code = '1261'
	AND box_size = 1
	AND amount_value IS NULL
	AND amount_unit IS NULL
	AND numerator_value = 3
	AND numerator_unit = 'mg'
	AND denominator_value = 1
	AND denominator_unit = 'ml';

DELETE
FROM ds_stage
WHERE drug_concept_code = '3698389'
	AND ingredient_concept_code = '563'
	AND box_size = 10
	AND amount_value IS NULL
	AND amount_unit IS NULL
	AND numerator_value = 0.695
	AND numerator_unit = 'g'
	AND denominator_value = 500
	AND denominator_unit = 'ml';

DELETE
FROM ds_stage
WHERE drug_concept_code = '3698426'
	AND ingredient_concept_code = '563'
	AND box_size = 10
	AND amount_value IS NULL
	AND amount_unit IS NULL
	AND numerator_value = 1.2
	AND numerator_unit = 'g'
	AND denominator_value = 500
	AND denominator_unit = 'ml';

DELETE
FROM ds_stage
WHERE drug_concept_code = '5536774'
	AND ingredient_concept_code = '1261'
	AND box_size = 25
	AND amount_value IS NULL
	AND amount_unit IS NULL
	AND numerator_value = 3
	AND numerator_unit = 'mg'
	AND denominator_value = 1
	AND denominator_unit = 'ml';

UPDATE ds_stage
SET numerator_value = 2.5
WHERE drug_concept_code = '3087355'
	AND ingredient_concept_code = '5356'
	AND box_size = 20
	AND amount_value IS NULL
	AND amount_unit IS NULL
	AND numerator_value = 1.1
	AND numerator_unit = 'g'
	AND denominator_value = 10
	AND denominator_unit = 'g';

UPDATE ds_stage
SET numerator_value = 7
WHERE drug_concept_code = '3200509'
	AND ingredient_concept_code = '1261'
	AND box_size = 1
	AND amount_value IS NULL
	AND amount_unit IS NULL
	AND numerator_value = 2
	AND numerator_unit = 'mg'
	AND denominator_value = 1
	AND denominator_unit = 'ml';

UPDATE ds_stage
SET numerator_value = 5.7
WHERE drug_concept_code = '3205777'
	AND ingredient_concept_code = '1261'
	AND box_size = 1
	AND amount_value IS NULL
	AND amount_unit IS NULL
	AND numerator_value = 2.7
	AND numerator_unit = 'mg'
	AND denominator_value = 1
	AND denominator_unit = 'ml';

UPDATE ds_stage
SET numerator_value = 1.715
WHERE drug_concept_code = '3698389'
	AND ingredient_concept_code = '563'
	AND box_size = 10
	AND amount_value IS NULL
	AND amount_unit IS NULL
	AND numerator_value = 1.015
	AND numerator_unit = 'g'
	AND denominator_value = 500
	AND denominator_unit = 'ml';

UPDATE ds_stage
SET numerator_value = 2.795
WHERE drug_concept_code = '3698426'
	AND ingredient_concept_code = '563'
	AND box_size = 10
	AND amount_value IS NULL
	AND amount_unit IS NULL
	AND numerator_value = 1.595
	AND numerator_unit = 'g'
	AND denominator_value = 500
	AND denominator_unit = 'ml';

UPDATE ds_stage
SET numerator_value = 5.7
WHERE drug_concept_code = '5536774'
	AND ingredient_concept_code = '1261'
	AND box_size = 25
	AND amount_value IS NULL
	AND amount_unit IS NULL
	AND numerator_value = 2.7
	AND numerator_unit = 'mg'
	AND denominator_value = 1
	AND denominator_unit = 'ml';

DELETE
FROM ds_stage
WHERE drug_concept_code = '3284943'
	AND ingredient_concept_code = '29848'
	AND box_size = 5
	AND amount_value = 0.23
	AND amount_unit = 'mg';

DELETE
FROM ds_stage
WHERE drug_concept_code = '3354164'
	AND ingredient_concept_code = '1023'
	AND box_size = 24
	AND amount_value = 300
	AND amount_unit = 'mg';

DELETE
FROM ds_stage
WHERE drug_concept_code = '3404695'
	AND ingredient_concept_code = '2202'
	AND box_size = 24
	AND amount_value = 62.5
	AND amount_unit = 'mg';

DELETE
FROM ds_stage
WHERE drug_concept_code = '5758486'
	AND ingredient_concept_code = '29848'
	AND box_size = 30
	AND amount_value = 0.23
	AND amount_unit = 'mg';

DELETE
FROM ds_stage
WHERE drug_concept_code = '3584846'
	AND ingredient_concept_code = '1023'
	AND box_size = 30
	AND amount_value = 500
	AND amount_unit = 'mg';

UPDATE ds_stage
SET amount_value = 1.53
WHERE drug_concept_code = '3284943'
	AND ingredient_concept_code = '29848'
	AND box_size = 5
	AND amount_value = 1.31
	AND amount_unit = 'mg';

UPDATE ds_stage
SET amount_value = 500
WHERE drug_concept_code = '3354164'
	AND ingredient_concept_code = '1023'
	AND box_size = 24
	AND amount_value = 200
	AND amount_unit = 'mg';

UPDATE ds_stage
SET amount_value = 250
WHERE drug_concept_code = '3404695'
	AND ingredient_concept_code = '2202'
	AND box_size = 24
	AND amount_value = 187.5
	AND amount_unit = 'mg';

UPDATE ds_stage
SET amount_value = 700
WHERE drug_concept_code = '3584846'
	AND ingredient_concept_code = '1023'
	AND box_size = 30
	AND amount_value = 200
	AND amount_unit = 'mg';

UPDATE ds_stage
SET amount_value = 1.53
WHERE drug_concept_code = '5758486'
	AND ingredient_concept_code = '29848'
	AND box_size = 30
	AND amount_value = 1.31
	AND amount_unit = 'mg';

--sometimes denominator is just a sum of components, so in this case we need to ignore denominators
UPDATE ds_stage
SET amount_value = numerator_value,
	amount_unit = numerator_unit,
	numerator_value = NULL,
	numerator_unit = NULL,
	denominator_value = NULL,
	denominator_unit = NULL
WHERE drug_concept_code IN (
		SELECT a.drug_concept_code
		FROM ds_stage a
		JOIN (
			SELECT drug_concept_code,
				sum(numerator_value) AS summ,
				numerator_unit
			FROM ds_stage
			GROUP BY drug_concept_code,
				denominator_value,
				denominator_unit,
				numerator_unit
			) b ON a.drug_concept_code = b.drug_concept_code
			AND summ / denominator_value < 1.2
			AND summ / denominator_value > 0.8
			AND a.numerator_unit = b.numerator_unit
		WHERE a.numerator_unit = a.denominator_unit
		);

--drug with no din7
INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
	)
VALUES (
	'60253264',
	'612',
	2.5,
	'IU',
	1,
	'ml'
	);

UPDATE ds_stage
SET numerator_value = numerator_value * 10 * denominator_value,
    numerator_unit = 'mg'
WHERE numerator_unit = '%';
			   
--update drugs that have amount+denominator
UPDATE ds_stage
SET numerator_value = amount_value,
    numerator_unit = amount_unit,
    amount_value = NULL,
    amount_unit = NULL
WHERE denominator_unit IS NOT NULL
	AND numerator_unit IS NULL
	AND amount_unit IS NOT NULL;			   

UPDATE ds_stage
SET denominator_value = NULL,
    denominator_unit = NULL
WHERE denominator_unit IS NOT NULL
	AND numerator_unit IS NULL;

UPDATE ds_stage a
SET amount_value = b.amount_value,
	amount_unit = b.amount_unit,
	numerator_value = b.numerator_value,
	numerator_unit = b.numerator_unit,
	denominator_value = b.denominator_value,
	denominator_unit = b.denominator_unit
FROM ds_stage_update b
WHERE a.drug_concept_code = b.drug_concept_code
	AND a.ingredient_concept_code = b.ingredient_concept_code
	AND a.box_size = b.box_size;

UPDATE ds_stage
SET numerator_value = amount_value * 30,
	numerator_unit = amount_unit,
	denominator_value = 30,
	denominator_unit = 'ACTUAT',
	amount_value = NULL,
	amount_unit = NULL
WHERE drug_concept_code IN (
		'2761996',
		'3000459'
		);

UPDATE ds_stage
SET numerator_value = power(10, numerator_value),
	numerator_unit = 'CCID_50'
WHERE numerator_unit = 'log CCID_50';

UPDATE ds_stage
SET numerator_value = 10
WHERE drug_concept_code = '5704697'
	AND ingredient_concept_code = '51742';

UPDATE ds_stage
SET numerator_value = 20
WHERE drug_concept_code = '5704711'
	AND ingredient_concept_code = '51742';

UPDATE ds_stage
SET numerator_value = 10
WHERE drug_concept_code = '5750852'
	AND ingredient_concept_code = '51742';

UPDATE ds_stage
SET numerator_value = 20
WHERE drug_concept_code = '5750875'
	AND ingredient_concept_code = '51742';

UPDATE ds_stage
SET numerator_value = 10
WHERE drug_concept_code = '5756211'
	AND ingredient_concept_code = '51742';

UPDATE ds_stage
SET numerator_value = 20
WHERE drug_concept_code = '5756228'
	AND ingredient_concept_code = '51742';

DELETE
FROM ds_stage
WHERE ingredient_concept_code = '3011'
	AND amount_value = 0;

--update dosages for inhalers
DROP TABLE IF EXISTS ds_inhaler;
CREATE TABLE ds_inhaler AS
	WITH a AS (
			SELECT drug_concept_code,
				ingredient_concept_code,
				box_size,
				amount_value,
				amount_unit,
				numerator_value,
				numerator_unit,
				denominator_value,
				denominator_unit,
				packaging,
				substring(packaging, '(\d+)(\s*) dose')::INT AS num_coef,
				substring(packaging, '(\d+) (plaquette|cartouche|flacon|inhalateur)')::INT AS box_coef
			FROM ds_stage a
			JOIN sources.bdpm_packaging b ON drug_concept_code = din_7::VARCHAR
			WHERE packaging LIKE '%dose%inhal%'
				OR packaging LIKE '%inhal%dose%'
			)

SELECT DISTINCT drug_concept_code,
	ingredient_concept_code,
	box_coef AS box_size,
	NULL AS amount_value,
	NULL AS amount_unit,
	a.amount_value * num_coef AS numerator_value,
	a.amount_unit AS numerator_unit,
	num_coef AS denominator_value,
	'ACTUAT' AS denominator_unit
FROM a;

UPDATE ds_stage a
SET box_size = b.box_size,
	amount_value = NULL,
	amount_unit = NULL,
	numerator_value = b.numerator_value,
	numerator_unit = b.numerator_unit,
	denominator_value = b.denominator_value,
	denominator_unit = b.denominator_unit
FROM ds_inhaler b
WHERE a.drug_concept_code = b.drug_concept_code
	AND a.ingredient_concept_code = b.ingredient_concept_code;

--manufacturers
DROP TABLE IF EXISTS dcs_manufacturer;
CREATE TABLE dcs_manufacturer AS
SELECT DISTINCT ltrim(manufacturer, ' ') AS concept_name,
	'Supplier'::varchar AS concept_class_id
FROM sources.bdpm_drug;

--Parsing drug description extracting brand names 
DROP TABLE IF EXISTS brand_name;
CREATE TABLE brand_name AS
SELECT rtrim(substring(drug_descr, '^(([A-Z]+(\s)?-?/?[A-Z]+(\s)?[A-Z]?)+)'), ' ') AS brand_name,
	drug_code
FROM sources.bdpm_drug
WHERE drug_descr NOT LIKE '%degré de dilution compris entre%'
	AND substring(drug_descr, '^(([A-Z]+(\s)?-?[A-Z]+)+)') IS NOT NULL;


UPDATE brand_name
SET brand_name = 'NP100 PREMATURES AP-HP'
WHERE drug_code = '60208447';

UPDATE brand_name
SET brand_name = 'NP2 ENFANTS AP-HP'
WHERE drug_code = '66809426';

UPDATE brand_name
SET brand_name = 'PO 12 2 POUR CENT'
WHERE drug_code = '64593595';

UPDATE brand_name
SET brand_name = 'HUMEXLIB'
WHERE brand_name LIKE 'HUMEXLIB%';

UPDATE brand_name
SET brand_name = 'HUMEX'
WHERE brand_name LIKE 'HUMEX %';

UPDATE brand_name
SET brand_name = 'CLARIX'
WHERE brand_name LIKE 'CLARIX %';

UPDATE brand_name
SET brand_name = 'ACTIVOX'
WHERE brand_name LIKE 'ACTIVOX %';

--Brand name = Ingredient (RxNorm)
DELETE
FROM brand_name
WHERE upper(brand_name) IN (
		SELECT upper(concept_name)
		FROM concept
		WHERE concept_class_id = 'Ingredient'
		);

--Brand name = Ingredient (BDPM translated)
DELETE
FROM brand_name
WHERE lower(brand_name) IN (
		SELECT lower(translation)
		FROM ingr_translation_all
		);

--Brand name = Ingredient (BDPM original)
DELETE
FROM brand_name
WHERE lower(brand_name) IN (
		SELECT lower(concept_name)
		FROM ingr_translation_all
		);

DELETE
FROM brand_name
WHERE brand_name IN (
		'ARGENTUM COMPLEXE N',
		'ESTERS ETHYLIQUES D',
		'ACIDUM PHOSPHORICUM COMPLEXE N',
		'POTASSIUM H',
		'FUCUS COMPLEXE N',
		'CREME AU CALENDULA',
		'CRATAEGUS COMPLEXE N',
		'BADIAGA COMPLEXE N',
		'BERBERIS COMPLEXE N'
		);

UPDATE brand_name
SET brand_name = regexp_replace(brand_name, 'ADULTES|ENFANTS|NOURRISSONS', '', 'g')
WHERE brand_name ilike 'SUPPOSITOIRE%';

CREATE TABLE bn 
AS
SELECT *
FROM brand_name
  JOIN concept
    ON UPPER (brand_name) = UPPER (concept_name)
   AND vocabulary_id = 'RxNorm Extension'
   AND invalid_reason = 'D';

DELETE
FROM bn
WHERE brand_name IN (SELECT brand_name
                     FROM bn
                       JOIN concept c
                         ON brand_name = UPPER (c.concept_name)
                        AND c.concept_class_id = 'Brand Name'
                        AND c.invalid_reason IS NULL
                        AND c.vocabulary_id LIKE 'Rx%');

DELETE
FROM bn
WHERE brand_name IN ('ADEPAL','AMARANCE','AVADENE','BIAFINE','BORIPHARM N','CARBOSYLANE ENFANT','CARBOSYMAG','CLINIMIX N','CRESOPHENE','DETURGYLONE','EVANECIA','FEMSEPTCOMBI','HEPARGITOL','JASMINE','LEUCODININE B','NOVOFEMME','NUMETAH G','PACILIA','PERMIXON','PHAEVA','REVITALOSE');

DELETE
FROM brand_name
WHERE brand_name IN (SELECT brand_name FROM bn);

DELETE
FROM brand_name
WHERE SUBSTRING(UPPER(brand_name),'\w+') IN (SELECT UPPER(concept_name)
                                             FROM concept
                                             WHERE concept_Class_id = 'Ingredient')
AND   brand_name NOT IN (SELECT UPPER(concept_name)
                         FROM concept
                         WHERE concept_Class_id = 'Brand Name'
                         AND   invalid_reason IS NULL
                         AND   vocabulary_id LIKE 'Rx%');
			   
--list for drug_concept_stage
DROP TABLE IF EXISTS dcs_bn;
CREATE TABLE dcs_bn AS
SELECT DISTINCT brand_name AS concept_name,
	'Brand Name'::VARCHAR AS concept_class_id
FROM brand_name
WHERE drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		);

--list of Dose Form (translated before)
DROP TABLE IF EXISTS list;
CREATE TABLE list AS
SELECT trim(translation) AS concept_name,
	'Dose Form'::VARCHAR AS concept_class_id,
	NULL::VARCHAR AS concept_code
FROM form_translation --manual table

UNION

--Brand Names
SELECT trim(concept_name),
	concept_class_id,
	NULL
FROM dcs_bn

UNION

--manufacturers
SELECT trim(concept_name),
	concept_class_id,
	NULL
FROM dcs_manufacturer;

DELETE
FROM list
WHERE concept_name LIKE '%Enteric Oral Capsule%';

INSERT INTO list
VALUES (
	'inert ingredients',
	'Ingredient',
	NULL
	);

--temporary sequence
DROP SEQUENCE IF EXISTS new_vocc;
CREATE SEQUENCE new_vocc MINVALUE 1 MAXVALUE 1000000 START WITH 1 INCREMENT BY 1 CACHE 100;
--put OMOP||numbers
UPDATE list
SET concept_code = 'OMOP' || nextval('new_vocc');

--Fill drug_concept_stage
--Drug Product
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
SELECT SUBSTR(d.drug_descr, 1, 240),
	'BDPM',
	'Drug Product',
	NULL,
	din_7::VARCHAR,
	NULL,
	'Drug',
	approval_date,
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM sources.bdpm_drug d
JOIN sources.bdpm_packaging p ON p.drug_code = d.drug_code
WHERE d.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		)
	AND d.drug_code NOT IN (
		SELECT drug_code
		FROM pack_st_1
		);

--Device
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
SELECT SUBSTR(d.drug_descr, 1, 240),
	'BDPM',
	'Device',
	NULL,
	din_7::VARCHAR,
	NULL,
	'Device',
	approval_date,
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM sources.bdpm_drug d
JOIN sources.bdpm_packaging p ON p.drug_code = d.drug_code
WHERE d.drug_code IN (
		SELECT drug_code
		FROM non_drug
		);

--Brand Names and Dose forms and manufacturers
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
SELECT DISTINCT concept_name,
	'BDPM',
	concept_class_id,
	NULL,
	concept_code,
	NULL,
	'Drug',
	TO_DATE('19700101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM list;

-- units 
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
SELECT DISTINCT concept_code,
	'BDPM',
	'unit',
	NULL,
	concept_code,
	NULL,
	'Drug',
	TO_DATE('19700101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM aut_unit_all_mapped;

-- Pack_components 
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
SELECT DISTINCT SUBSTR(PACK_COMPONENT_NAME, 1, 240),
	'BDPM',
	'Drug Product',
	NULL,
	pack_component_code,
	NULL,
	'Drug',
	TO_DATE('19700101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM pack_cont_1;

--Packs
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
SELECT DISTINCT SUBSTR(PACK_NAME, 1, 240),
	'BDPM',
	'Drug Pack',
	NULL,
	concept_code,
	NULL,
	'Drug',
	TO_DATE('19700101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM pack_cont_1;

--ingredients 
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
SELECT DISTINCT translation,
	'BDPM',
	'Ingredient',
	NULL,
	concept_code,
	NULL,
	'Drug',
	TO_DATE('19700101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM ingr_translation_all;

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		'89969',
		'49487',
		'24033',
		'72310',
		'31035',
		'66548',
		'16621',
		'31035'
		);

--standard concept definition, not sure if we need this
UPDATE drug_concept_stage dcs
SET standard_concept = 'S'
FROM (
	SELECT concept_code
	FROM drug_concept_stage
	WHERE concept_class_id NOT IN (
			'Brand Name',
			'Dose Form',
			'unit',
			'Ingredient',
			'Supplier'
			)
	) d
WHERE d.concept_code = dcs.concept_code;

--standard concept definition, not sure if we need this
UPDATE drug_concept_stage dcs
SET standard_concept = 'S'
FROM (
	SELECT concept_name,
		MIN(concept_code) m
	FROM drug_concept_stage
	WHERE concept_class_id = 'Ingredient'
	GROUP BY concept_name
	HAVING count(concept_name) > 1
	) d
WHERE d.m = dcs.concept_code;

UPDATE drug_concept_stage
SET standard_concept = 'S'
WHERE concept_class_id = 'Ingredient'
	AND concept_name NOT IN (
		SELECT concept_name
		FROM drug_concept_stage
		WHERE concept_class_id = 'Ingredient'
		GROUP BY concept_name
		HAVING count(concept_name) > 1
		);

--drug with no din7
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
VALUES (
	'VACCIN RABIQUE INACTIVE MERIEUX, poudre et solvant pour suspension injectable. Vaccin rabique préparé sur cellules diploïdes humaines',
	'BDPM',
	'Drug Product',
	'S',
	'60253264',
	NULL,
	'Drug',
	TO_DATE('19960107', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
	);

--Drug to ingredients
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT drug_concept_code,
	ingredient_concept_code
FROM ds_stage d
WHERE d.drug_concept_code NOT IN (
		SELECT drug_code
		FROM non_drug
		)
	AND d.drug_concept_code NOT IN (
		SELECT pack_component_code
		FROM pack_cont_1
		);

--Homeop. drug to ingredients
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT din_7,
	form_code
FROM sources.bdpm_packaging
JOIN homeop_drug using (drug_code);

--Pack Component to Ingredient
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT drug_concept_code,
	ingredient_concept_code
FROM ds_stage d
WHERE d.drug_concept_code IN (
		SELECT pack_component_code
		FROM pack_cont_1
		);

INSERT INTO internal_relationship_stage (concept_code_1)
SELECT concept_code
FROM drug_concept_stage
WHERE concept_name LIKE '%INERT INGREDIENT Metered Dose Inhaler%';

UPDATE internal_relationship_stage
SET concept_code_2 = (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_name LIKE '%inert ingredients%'
		)
WHERE concept_code_1 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_name LIKE '%INERT INGREDIENT Metered Dose Inhaler%'
		)
	AND concept_code_2 IS NULL;

--Drug to Brand Name
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT din_7,
	concept_code
FROM brand_name b
JOIN drug_concept_stage d ON lower(brand_name) = lower(concept_name)
	AND d.concept_class_id = 'Brand Name'
JOIN sources.bdpm_packaging p ON p.drug_code = b.drug_code
WHERE b.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		);

--Drug to Supplier 
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT din_7,
	concept_code
FROM sources.bdpm_drug b
JOIN drug_concept_stage d ON lower(manufacturer) = ' ' || lower(concept_name)
	AND d.concept_class_id = 'Supplier'
JOIN sources.bdpm_packaging p ON p.drug_code = b.drug_code
WHERE b.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		);

--Drug to Dose Form
--separately for packs and drugs 
--for drugs, excluding packs and non_drugs
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT din_7,
	concept_code
FROM sources.bdpm_drug d
JOIN form_translation ON replace(CONCAT (
			form,
			' ',
			route
			), '  ', ' ') = form_route
JOIN drug_concept_stage ON translation = concept_name
	AND concept_class_id = 'Dose Form'
JOIN sources.bdpm_packaging p ON p.drug_code = d.drug_code
WHERE d.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		)
	AND d.drug_code NOT IN (
		SELECT concept_code::VARCHAR
		FROM pack_cont_1
		);

-- Drug to Dose Form for Pack components 
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT pack_component_code,
	concept_code
FROM pf_from_pack_comp_list pf
JOIN drug_concept_stage dcs ON pack_form = concept_name;

--manual update of code_ingred_to_ingred
DELETE
FROM code_ingred_to_ingred
WHERE concept_code_1 IN (
		SELECT form_code
		FROM non_drug
		);

--Ingredient to Ingredient
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT *
FROM code_ingred_to_ingred;

--manualy defined same ingredients
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT b.concept_code concept_code_1,
	a.concept_code concept_code_2
FROM drug_concept_stage a
JOIN drug_concept_stage b ON a.concept_name = b.concept_name
WHERE a.concept_name IN (
		SELECT concept_name
		FROM drug_concept_stage
		GROUP BY concept_name
		HAVING count(8) > 1
		)
	AND a.concept_class_id = 'Ingredient'
	AND a.standard_concept = 'S'
	AND b.standard_concept IS NULL
	AND b.concept_code NOT IN (
		SELECT concept_code_2
		FROM code_ingred_to_ingred
		);

--drug doesn't have packaging
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT '60253264',
	concept_code
FROM drug_concept_stage
WHERE concept_name = 'Injectable Solution';

INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT '60253264',
	concept_code
FROM drug_concept_stage
WHERE concept_name = 'VACCIN RABIQUE INACTIVE MERIEUX';

INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT '60253264',
	concept_code
FROM drug_concept_stage
WHERE concept_name = 'SANOFI PASTEUR';

--Forms mapping
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT concept_code,
	'BDPM',
	concept_id,
	precedence,
	NULL
FROM aut_form_all_mapped --manual table
JOIN drug_concept_stage d ON lower(d.concept_name) = lower(translation);

--Brand names
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT concept_code,
	'BDPM',
	concept_id,
	precedence,
	NULL
FROM aut_bn_mapped_all a --manual table
JOIN drug_concept_stage d ON lower(d.concept_name) = lower(a.brand_name);

--units
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT concept_code,
	'BDPM',
	concept_id_2,
	precedence,
	conversion_factor
FROM aut_unit_all_mapped; --manual table

--ingredients 
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT concept_code,
	'BDPM',
	concept_id,
	precedence,
	NULL
FROM aut_ingr_mapped_all; --manual table

DROP TABLE IF EXISTS ingr_map_update;
CREATE TABLE ingr_map_update AS
	WITH a AS (
			SELECT a.concept_code,
				a.concept_name,
				vocabulary_id_1,
				precedence,
				rank() OVER (
					PARTITION BY a.concept_code ORDER BY c2.concept_id
					) AS rank,
				c2.concept_id,
				c2.standard_concept
			FROM drug_concept_stage a
			JOIN relationship_to_concept rc ON a.concept_code = rc.concept_code_1
			JOIN concept c1 ON c1.concept_id = concept_id_2
			JOIN concept c2 ON trim(regexp_replace(lower(c1.concept_name), 'for homeopathic preparations|tartrate|phosphate', '', 'g')) = trim(regexp_replace(lower(c2.concept_name), 'for homeopathic preparations', '', 'g'))
				AND c2.standard_concept = 'S'
				AND c2.concept_class_id = 'Ingredient'
			WHERE c1.invalid_reason IS NOT NULL
			)

SELECT concept_code,
	concept_name,
	vocabulary_id_1,
	precedence,
	concept_id,
	standard_concept
FROM a
WHERE concept_code IN (
		SELECT concept_code
		FROM a
		GROUP BY concept_code
		HAVING count(concept_code) = 1
		)

UNION

SELECT concept_code,
	concept_name,
	vocabulary_id_1,
	rank,
	concept_id,
	standard_concept
FROM a
WHERE concept_code IN (
		SELECT concept_code
		FROM a
		GROUP BY concept_code
		HAVING count(concept_code) != 1
		);

DELETE
FROM relationship_to_concept
WHERE (
		concept_code_1,
		concept_id_2
		) IN (
		SELECT concept_code_1,
			concept_id_2
		FROM relationship_to_concept
		JOIN drug_concept_stage s ON s.concept_code = concept_code_1
		JOIN concept c ON c.concept_id = concept_id_2
		WHERE c.standard_concept IS NULL
			AND s.concept_class_id = 'Ingredient'
		);

INSERT INTO relationship_to_concept
SELECT concept_code,
	vocabulary_id_1,
	concept_id,
	precedence,
	NULL
FROM ingr_map_update;

--add RxNorm Extension
DROP TABLE IF EXISTS RxE_Ing_st_0;
CREATE TABLE RxE_Ing_st_0 AS
SELECT a.concept_code AS concept_code_1,
	a.concept_name AS concept_name_1,
	c.concept_id,
	c.concept_name
FROM drug_concept_stage a
JOIN concept c ON lower(a.concept_name) = lower(c.concept_name)
WHERE a.concept_class_id = 'Ingredient'
	AND a.concept_code NOT IN (
		SELECT concept_code_1
		FROM relationship_to_concept
		)
	AND c.vocabulary_id = 'RxNorm Extension'
	AND c.concept_class_id = 'Ingredient'
	AND c.invalid_reason IS NULL;

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT concept_code_1,
	'BDPM',
	concept_id,
	1,
	NULL
FROM RxE_Ing_st_0 -- RxNormExtension name equivalence
	;

--one ingredient found manualy
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
VALUES (
	'538',
	'BDPM',
	21014151,
	1,
	NULL
	);

INSERT INTO relationship_to_concept
SELECT concept_code,
	'BDPM',
	19127890,
	1,
	NULL
FROM drug_concept_stage
WHERE concept_name LIKE '%inert ingredients%';
--need to add manufacturer lately

--manufacturer
DROP TABLE IF EXISTS RxE_Man_st_0;
CREATE TABLE RxE_Man_st_0 AS
SELECT a.concept_code AS concept_code_1,
	a.concept_name AS concept_name_1,
	c.concept_id,
	c.concept_name concept,
	rank() OVER (
		PARTITION BY a.concept_code ORDER BY c.concept_id
		) AS precedence
FROM drug_concept_stage a
JOIN concept c ON regexp_replace(lower(a.concept_name), ' ltd| plc| uk| \(.*\)| pharmaceuticals| pharma| gmbh| laboratories| ab| international| france| imaging', '', 'g') = regexp_replace(lower(c.concept_name), ' ltd| plc| uk| \(.*\)| pharmaceuticals| pharma| gmbh| laboratories| ab| international| france| imaging', '', 'g')
WHERE a.concept_class_id = 'Supplier'
	AND a.concept_code NOT IN (
		SELECT concept_code_1
		FROM relationship_to_concept
		)
	AND c.vocabulary_id LIKE 'RxNorm%'
	AND c.concept_class_id = 'Supplier'
	AND c.invalid_reason IS NULL;

INSERT INTO relationship_to_concept
SELECT concept_code,
	'BDPM',
	concept_id,
	precedence,
	NULL
FROM aut_supp_mapped a
JOIN drug_concept_stage b using (concept_name);--suppliers found manually

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT concept_code_1,
	'BDPM',
	concept_id,
	precedence,
	NULL
FROM RxE_Man_st_0; -- RxNormExtension name equivalence

--Brands from RxE

DROP TABLE IF EXISTS RxE_BR_n_st_0;
CREATE TABLE RxE_BR_n_st_0 AS

SELECT a.concept_code AS concept_code_1,
	a.concept_name AS concept_name_1,
	c.concept_id,
	c.concept_name
FROM drug_concept_stage a
JOIN concept c ON lower(a.concept_name) = lower(c.concept_name)
WHERE a.concept_class_id = 'Brand Name'
	AND a.concept_code NOT IN (
		SELECT concept_code_1
		FROM relationship_to_concept
		)
	AND c.vocabulary_id LIKE 'RxNorm%'
	AND c.concept_class_id = 'Brand Name'
	AND c.invalid_reason IS NULL;

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT concept_code_1,
	'BDPM',
	concept_id,
	1,
	NULL
FROM RxE_BR_n_st_0 ;-- RxNormExtension name equivalence

DELETE
FROM relationship_to_concept
WHERE ctid IN (
		SELECT MAX(ctid)
		FROM relationship_to_concept
		GROUP BY concept_code_1,
			precedence
		HAVING count(1) > 1
		);

DELETE
FROM internal_relationship_stage
WHERE ctid IN (
		SELECT MAX(ctid)
		FROM internal_relationship_stage
		GROUP BY concept_code_1,
			concept_code_2
		HAVING count(1) > 1
		);

UPDATE ds_stage
SET amount_value = numerator_value,
	amount_unit = numerator_unit,
	numerator_value = NULL,
	numerator_unit = NULL,
	denominator_value = NULL,
	denominator_unit = NULL
WHERE (
		ingredient_concept_code = '16736'
		AND drug_concept_code IN (
			SELECT concept_code
			FROM drug_concept_stage
			WHERE concept_name IN (
					'JINARC 30 mg, comprimé, JINARC 90 mg, comprimé comprimé de 90 mg',
					'JINARC 15 mg, comprimé, JINARC 45 mg, comprimé comprimé de 45 mg',
					'JINARC 30 mg, comprimé, JINARC 60 mg, comprimé comprimé de 60 mg'
					)
			)
		)
	OR (
		ingredient_concept_code = '41238'
		AND drug_concept_code IN (
			SELECT concept_code
			FROM drug_concept_stage
			WHERE concept_name IN (
					'OTEZLA 10 mg, comprimé pelliculé, OTEZLA 20 mg, comprimé pelliculé, OTEZLA 30 mg, comprimé pelliculé, comprimé 30 mg',
					'OTEZLA 10 mg, comprimé pelliculé, OTEZLA 20 mg, comprimé pelliculé, OTEZLA 30 mg, comprimé pelliculé, comprimé 20 mg'
					)
			)
		);

--delete non-relevant brand names
DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
		SELECT concept_code
		FROM drug_concept_stage a
		LEFT JOIN internal_relationship_stage b ON a.concept_code = b.concept_code_2
		WHERE a.concept_class_id = 'Brand Name'
			AND b.concept_code_1 IS NULL
		);

--update ds_stage after relationship_to concept found identical ingredients
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage a
		LEFT JOIN internal_relationship_stage b ON a.concept_code = b.concept_code_2
		WHERE a.concept_class_id = 'Brand Name'
			AND b.concept_code_1 IS NULL
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

SELECT drug_concept_code,
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

SELECT drug_concept_code,
	ingredient_concept_code,
	box_size,
	NULL AS amount_value,
	NULL AS amount_unit,
	NULL AS numerator_value,
	NULL AS numerator_unit,
	NULL AS denominator_value,
	NULL AS denominator_unit
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

INSERT INTO ds_stage
SELECT *
FROM ds_sum
WHERE coalesce(amount_value, numerator_value) IS NOT NULL;

--update irs after relationship_to concept found identical ingredients
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

--update IRS -remove suppliers where Dose form or dosage doesn't exist
DELETE
FROM internal_relationship_stage
WHERE (
		concept_code_1,
		concept_code_2
		) IN (
		SELECT DISTINCT concept_code_1,
			concept_code_2
		FROM internal_relationship_stage
		JOIN drug_concept_stage a ON concept_code_2 = a.concept_code
			AND a.concept_class_id = 'Supplier'
		JOIN drug_concept_stage b ON concept_code_1 = b.concept_code
			AND b.concept_class_id IN (
				'Drug Product',
				'Drug Pack'
				)
		WHERE (
				b.concept_code NOT IN (
					SELECT concept_code_1
					FROM internal_relationship_stage
					JOIN drug_concept_stage ON concept_code_2 = concept_code
						AND concept_class_id = 'Dose Form'
					)
				OR b.concept_code NOT IN (
					SELECT drug_concept_code
					FROM ds_stage
					)
				)
		);

--manualy define packs amounts
DROP TABLE IF EXISTS p_c_amount;
CREATE TABLE p_c_amount AS
SELECT DISTINCT a.pack_component_code,
	a.packaging,
	a.concept_code::varchar,
	b.drug_form,
	99 AS amount,
	99 AS box_size
FROM pack_cont_1 a
JOIN pack_comp_list b ON a.pack_component_code = b.pack_component_code;

DO $_$
BEGIN
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '2170290' AND   drug_form = 'poudre';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '2170290' AND   drug_form = 'solution';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '2219116' AND   drug_form = 'solution 1';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '2219116' AND   drug_form = 'solution 2';
	UPDATE p_c_amount   SET amount = 14 WHERE concept_code = '2733209' AND   drug_form = 'comprimé à 1 mg';
	UPDATE p_c_amount   SET amount = 11 WHERE concept_code = '2733209' AND   drug_form = '"comprimé à 0,5 mg"';
	UPDATE p_c_amount   SET amount = 12 WHERE concept_code = '2742556' AND   drug_form = 'comprimé jour';
	UPDATE p_c_amount   SET amount = 4 WHERE concept_code = '2742556' AND   drug_form = 'comprimé nuit';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '2794926' AND   drug_form = 'solution de 63 microgrammes';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '2794926' AND   drug_form = 'solution de 94 microgrammes';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3001051' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 84 WHERE concept_code = '3001051' AND   drug_form = 'comprimé rose';
	UPDATE p_c_amount   SET amount = 20 WHERE concept_code = '3048384' AND   drug_form = 'poche A';
	UPDATE p_c_amount   SET amount = 20 WHERE concept_code = '3048384' AND   drug_form = 'poche B';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '3209686' AND   drug_form = 'solvant';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '3209686' AND   drug_form = 'poudre';
	UPDATE p_c_amount   SET amount = 12 WHERE concept_code = '3254882' AND   drug_form = 'comprimé bleu';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '3254882' AND   drug_form = 'comprimé rouge';
	UPDATE p_c_amount   SET amount = 10 WHERE concept_code = '3254882' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3254913' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3254913' AND   drug_form = 'comprimé orange';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3254913' AND   drug_form = 'comprimé orange pâle';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3254936' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3254936' AND   drug_form = 'comprimé orange';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3254936' AND   drug_form = 'comprimé orange pâle';
	UPDATE p_c_amount   SET amount = 4 WHERE concept_code = '3263651' AND   drug_form = 'comprimé';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '3263651' AND   drug_form = 'solution';
	UPDATE p_c_amount   SET amount = 4 WHERE concept_code = '3269642' AND   drug_form = 'comprimé';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '3269642' AND   drug_form = 'solution';
	UPDATE p_c_amount   SET amount = 48 WHERE concept_code = '3272443' AND   drug_form = 'gélule bleue';
	UPDATE p_c_amount   SET amount = 48 WHERE concept_code = '3272443' AND   drug_form = 'gélule rouge gastro-résistante';
	UPDATE p_c_amount   SET amount = 24 WHERE concept_code = '3273129' AND   drug_form = 'gélule bleue';
	UPDATE p_c_amount   SET amount = 24 WHERE concept_code = '3273129' AND   drug_form = 'gélule rouge gastro-résistante';
	UPDATE p_c_amount   SET amount = 20 WHERE concept_code = '3292546' AND   drug_form = 'solution en ampoule B';
	UPDATE p_c_amount   SET amount = 20 WHERE concept_code = '3292546' AND   drug_form = 'solution en ampoule A';
	UPDATE p_c_amount   SET amount = 48 WHERE concept_code = '3295438' AND   drug_form = 'gélule bleue gastro-soluble';
	UPDATE p_c_amount   SET amount = 48 WHERE concept_code = '3295438' AND   drug_form = 'gélule rouge gastro-résistante';
	UPDATE p_c_amount   SET amount = 24 WHERE concept_code = '3299548' AND   drug_form = 'gélule bleue gastro-soluble';
	UPDATE p_c_amount   SET amount = 24 WHERE concept_code = '3299548' AND   drug_form = 'gélule rouge gastro-résistante';
	UPDATE p_c_amount   SET amount = 5 WHERE concept_code = '3305065' AND   drug_form = 'comprimé marron foncé';
	UPDATE p_c_amount   SET amount = 10 WHERE concept_code = '3305065' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '3305065' AND   drug_form = 'comprimé beige';
	UPDATE p_c_amount   SET amount = 5 WHERE concept_code = '3305071' AND   drug_form = 'comprimé marron foncé';
	UPDATE p_c_amount   SET amount = 10 WHERE concept_code = '3305071' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '3305071' AND   drug_form = 'comprimé beige';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '3305088' AND   drug_form = 'comprimé beige';
	UPDATE p_c_amount   SET amount = 10 WHERE concept_code = '3305088' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 5 WHERE concept_code = '3305088' AND   drug_form = 'comprimé marron foncé';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '3305094' AND   drug_form = 'comprimé beige';
	UPDATE p_c_amount   SET amount = 10 WHERE concept_code = '3305094' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 5 WHERE concept_code = '3305094' AND   drug_form = 'comprimé marron foncé';
	UPDATE p_c_amount   SET amount = 11 WHERE concept_code = '3344355' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 10 WHERE concept_code = '3344355' AND   drug_form = 'comprimé bleu';
	UPDATE p_c_amount   SET amount = 14 WHERE concept_code = '3357300' AND   drug_form = 'solution A';
	UPDATE p_c_amount   SET amount = 14 WHERE concept_code = '3357300' AND   drug_form = 'solution B';
	UPDATE p_c_amount   SET amount = 11 WHERE concept_code = '3360437' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 10 WHERE concept_code = '3360437' AND   drug_form = 'comprimé rose';
	UPDATE p_c_amount   SET amount = 3 WHERE concept_code = '3386477' AND   drug_form = 'comprimé bleu';
	UPDATE p_c_amount   SET amount = 3 WHERE concept_code = '3386477' AND   drug_form = 'comprimé rose';
	UPDATE p_c_amount   SET amount = 14 WHERE concept_code = '3438524' AND   drug_form = 'comprimé jaune';
	UPDATE p_c_amount   SET amount = 14 WHERE concept_code = '3438524' AND   drug_form = 'comprimé rose';
	UPDATE p_c_amount   SET amount = 4 WHERE concept_code = '3447463' AND   drug_form = 'gélule';
	UPDATE p_c_amount   SET amount = 12 WHERE concept_code = '3447463' AND   drug_form = 'comprimé';
	UPDATE p_c_amount   SET amount = 24 WHERE concept_code = '3490370' AND   drug_form = 'gélule orange';
	UPDATE p_c_amount   SET amount = 24 WHERE concept_code = '3490370' AND   drug_form = 'gélule verte';
	UPDATE p_c_amount   SET amount = 24 WHERE concept_code = '3490387' AND   drug_form = 'gélule orange';
	UPDATE p_c_amount   SET amount = 24 WHERE concept_code = '3490387' AND   drug_form = 'gélule verte';
	UPDATE p_c_amount   SET amount = 14 WHERE concept_code = '3526435' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 14 WHERE concept_code = '3526435' AND   drug_form = 'comprimé gris';
	UPDATE p_c_amount   SET amount = 4 WHERE concept_code = '3542871' AND   drug_form = 'solution 2 : glucose avec calcium';
	UPDATE p_c_amount   SET amount = 4 WHERE concept_code = '3542871' AND   drug_form = 'solution 1 : acides aminés avec électrolytes';
	UPDATE p_c_amount   SET amount = 4 WHERE concept_code = '3542919' AND   drug_form = 'solution d''acides aminés';
	UPDATE p_c_amount   SET amount = 4 WHERE concept_code = '3542919' AND   drug_form = 'solution de glucose';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '3549583' AND   drug_form = 'suspension';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '3549583' AND   drug_form = 'poudre';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '3552473' AND   drug_form = 'poudre';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '3552473' AND   drug_form = 'suspension';
	UPDATE p_c_amount   SET amount = 8 WHERE concept_code = '3563583' AND   drug_form = 'solution 2 : glucose avec calcium';
	UPDATE p_c_amount   SET amount = 8 WHERE concept_code = '3563583' AND   drug_form = 'solution 1 : acides aminés avec électrolytes';
	UPDATE p_c_amount   SET amount = 8 WHERE concept_code = '3563608' AND   drug_form = 'solution 1 : acides aminés avec électrolytes';
	UPDATE p_c_amount   SET amount = 8 WHERE concept_code = '3563608' AND   drug_form = 'solution 2 : glucose avec calcium';
	UPDATE p_c_amount   SET amount = 8 WHERE concept_code = '3563695' AND   drug_form = 'solution d''acides aminés';
	UPDATE p_c_amount   SET amount = 8 WHERE concept_code = '3563695' AND   drug_form = 'solution de glucose';
	UPDATE p_c_amount   SET amount = 14 WHERE concept_code = '3575304' AND   drug_form = 'sachet 1';
	UPDATE p_c_amount   SET amount = 14 WHERE concept_code = '3575304' AND   drug_form = 'sachet 2';
	UPDATE p_c_amount   SET amount = 4 WHERE concept_code = '3575327' AND   drug_form = 'comprimé bleu';
	UPDATE p_c_amount   SET amount = 12 WHERE concept_code = '3575327' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 16 WHERE concept_code = '3583947' AND   drug_form = 'comprimé beige';
	UPDATE p_c_amount   SET amount = 12 WHERE concept_code = '3583947' AND   drug_form = 'comprimé bleu';
	UPDATE p_c_amount   SET amount = 10 WHERE concept_code = '3584622' AND   drug_form = 'comprimé rose';
	UPDATE p_c_amount   SET amount = 14 WHERE concept_code = '3584622' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 16 WHERE concept_code = '3584792' AND   drug_form = 'comprimé rouge';
	UPDATE p_c_amount   SET amount = 12 WHERE concept_code = '3584792' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3589938' AND   drug_form = 'comprimé bleu ciel';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3589938' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3589938' AND   drug_form = 'comprimé bleu foncé';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3589944' AND   drug_form = 'comprimé bleu ciel';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3589944' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3589944' AND   drug_form = 'comprimé bleu foncé';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3589950' AND   drug_form = 'comprimé bleu foncé';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3589950' AND   drug_form = 'comprimé bleu ciel';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3589950' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3589967' AND   drug_form = 'comprimé bleu foncé';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3589967' AND   drug_form = 'comprimé bleu ciel';
	UPDATE p_c_amount   SET amount = 7 WHERE concept_code = '3589967' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '3603791' AND   drug_form = 'poudre';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '3603791' AND   drug_form = 'solution';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '3635118' AND   drug_form = 'gélule blanche';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '3635118' AND   drug_form = 'gélule blanche et rose';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '3687434' AND   drug_form = 'poudre';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '3687434' AND   drug_form = 'suspension';
	UPDATE p_c_amount   SET amount = 3 WHERE concept_code = '3689516' AND   drug_form = 'comprimé 300 IR';
	UPDATE p_c_amount   SET amount = 28 WHERE concept_code = '3689516' AND   drug_form = 'comprimé 100 IR';
	UPDATE p_c_amount   SET amount = 5 WHERE concept_code = '3715811' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 10 WHERE concept_code = '3715811' AND   drug_form = 'comprimé vert';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '3715811' AND   drug_form = 'comprimé beige';
	UPDATE p_c_amount   SET amount = 5 WHERE concept_code = '3715828' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 10 WHERE concept_code = '3715828' AND   drug_form = 'comprimé vert';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '3715828' AND   drug_form = 'comprimé beige';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '3759027' AND   drug_form = 'solution à 22 microgrammes';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '3759027' AND   drug_form = '"solution à 8,8 microgrammes"';
	UPDATE p_c_amount   SET amount = 10 WHERE concept_code = '3770000' AND   drug_form = 'comprimé jaune';
	UPDATE p_c_amount   SET amount = 5 WHERE concept_code = '3770000' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '3770000' AND   drug_form = 'comprimé brique';
	UPDATE p_c_amount   SET amount = 11 WHERE concept_code = '3771809' AND   drug_form = 'comprimé à 1 mg';
	UPDATE p_c_amount   SET amount = 14 WHERE concept_code = '3771809' AND   drug_form = '"comprimé à 0,5 mg"';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '3788164' AND   drug_form = 'poudre du sachet B';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '3788164' AND   drug_form = 'poudre du sachet A';
	UPDATE p_c_amount   SET amount = 24 WHERE concept_code = '3813057' AND   drug_form = 'granulés';
	UPDATE p_c_amount   SET amount = 4 WHERE concept_code = '3813057' AND   drug_form = 'comprimé';
	UPDATE p_c_amount   SET amount = 72 WHERE concept_code = '3828455' AND   drug_form = 'granulés';
	UPDATE p_c_amount   SET amount = 12 WHERE concept_code = '3828455' AND   drug_form = 'comprimé';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '3909484' AND   drug_form = 'comprimé rouge foncé';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '3909484' AND   drug_form = 'comprimé jaune foncé';
	UPDATE p_c_amount   SET amount = 17 WHERE concept_code = '3909484' AND   drug_form = 'comprimé jaune clair';
	UPDATE p_c_amount   SET amount = 5 WHERE concept_code = '3909484' AND   drug_form = 'comprimé rouge';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '3909490' AND   drug_form = 'comprimé rouge foncé';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '3909490' AND   drug_form = 'comprimé jaune foncé';
	UPDATE p_c_amount   SET amount = 17 WHERE concept_code = '3909490' AND   drug_form = 'comprimé jaune clair';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '3909490' AND   drug_form = 'comprimé rouge';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '4166252' AND   drug_form = 'compartiment de la solution de glucose';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '4166252' AND   drug_form = 'compartiment de l''émulsion lipidique';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '4166252' AND   drug_form = 'compartiment des acides aminés';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5500089' AND   drug_form = 'composant 2';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5500089' AND   drug_form = 'composant 1';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5500091' AND   drug_form = 'composant 1';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5500091' AND   drug_form = 'composant 2';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5500092' AND   drug_form = 'composant 2';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5500092' AND   drug_form = 'composant 1';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '5611085' AND   drug_form = 'solvant (flacon 2)';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '5611085' AND   drug_form = 'poudre (flacon 3)';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '5611085' AND   drug_form = 'solvant (flacon 4)';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '5611085' AND   drug_form = 'poudre (flacon 1)';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '5611091' AND   drug_form = 'poudre (flacon 1)';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '5611091' AND   drug_form = 'solvant (flacon 2)';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '5611091' AND   drug_form = 'solvant (flacon 4)';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '5611091' AND   drug_form = 'poudre (flacon 3)';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '5611116' AND   drug_form = 'solvant (flacon 4)';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '5611116' AND   drug_form = 'poudre (flacon 3)';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '5611116' AND   drug_form = 'solvant (flacon 2)';
	UPDATE p_c_amount   SET amount = 2 WHERE concept_code = '5611116' AND   drug_form = 'poudre (flacon 1)';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5620894' AND   drug_form = 'solution de reconstitution de la poudre 1';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5620894' AND   drug_form = 'poudre 2';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5620894' AND   drug_form = 'poudre 1';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5620902' AND   drug_form = 'poudre 2';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5620902' AND   drug_form = 'solution de reconstitution de la poudre 1';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5620902' AND   drug_form = 'poudre 1';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5620925' AND   drug_form = 'poudre 1';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5620925' AND   drug_form = 'poudre 2';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5620925' AND   drug_form = 'solution de reconstitution de la poudre 1';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5645167' AND   drug_form = 'poudre du composant 1';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5645167' AND   drug_form = 'poudre du composant 2';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5650932' AND   drug_form = 'solution 2';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5650932' AND   drug_form = 'solution 1';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5650949' AND   drug_form = 'solution 1';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5650949' AND   drug_form = 'solution 2';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5731866' AND   drug_form = 'gélule transparente';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5754637' AND   drug_form = 'solution 2';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5754637' AND   drug_form = 'solution 1';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5754643' AND   drug_form = 'solution 1';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5754643' AND   drug_form = 'solution 2';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5754666' AND   drug_form = 'solution 2';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5754666' AND   drug_form = 'solution 1';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5755766' AND   drug_form = 'solution de protéines pour colle';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5755766' AND   drug_form = 'solution de thrombine';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5755772' AND   drug_form = 'solution de thrombine';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5755772' AND   drug_form = 'solution de protéines pour colle';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5755789' AND   drug_form = 'solution de protéines pour colle';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '5755789' AND   drug_form = 'solution de thrombine';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '2794903' AND   drug_form = 'solution de 94 microgrammes';
	UPDATE p_c_amount   SET amount = 1 WHERE concept_code = '2794903' AND   drug_form = 'solution de 63 microgrammes';
	UPDATE p_c_amount   SET amount = 4 WHERE concept_code = '3000888' AND   drug_form = 'comprimé 20 mg';
	UPDATE p_c_amount   SET amount = 4 WHERE concept_code = '3000888' AND   drug_form = 'comprimé 10 mg';
	UPDATE p_c_amount   SET amount = 19 WHERE concept_code = '3000888' AND   drug_form = 'comprimé 30 mg';
	UPDATE p_c_amount   SET amount = 28 WHERE concept_code = '3001606' AND   drug_form = 'comprimé de 15 mg';
	UPDATE p_c_amount   SET amount = 28 WHERE concept_code = '3001606' AND   drug_form = 'comprimé de 45 mg';
	UPDATE p_c_amount   SET amount = 28 WHERE concept_code = '3001609' AND   drug_form = 'comprimé de 60 mg';
	UPDATE p_c_amount   SET amount = 28 WHERE concept_code = '3001609' AND   drug_form = 'comprimé de 30 mg';
	UPDATE p_c_amount   SET amount = 28 WHERE concept_code = '3001611' AND   drug_form = 'comprimé de 90 mg';
	UPDATE p_c_amount   SET amount = 28 WHERE concept_code = '3001611' AND   drug_form = 'comprimé de 30 mg';
	UPDATE p_c_amount   SET amount = 10 WHERE concept_code = '3004510' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '3004510' AND   drug_form = 'comprimé beige';
	UPDATE p_c_amount   SET amount = 5 WHERE concept_code = '3004510' AND   drug_form = 'comprimé marron foncé';
	UPDATE p_c_amount   SET amount = 10 WHERE concept_code = '3004511' AND   drug_form = 'comprimé blanc';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '3004511' AND   drug_form = 'comprimé beige';
	UPDATE p_c_amount   SET amount = 5 WHERE concept_code = '3004511' AND   drug_form = 'comprimé marron foncé';
	UPDATE p_c_amount   SET amount = 48 WHERE concept_code = '3272443' AND   drug_form = 'gélule bleue gastro-soluble';
	UPDATE p_c_amount   SET amount = 24 WHERE concept_code = '3273129' AND   drug_form = 'gélule bleue gastro-soluble';
	UPDATE p_c_amount   SET amount = 6 WHERE concept_code = '3759027' AND   drug_form = 'solution à 8,8 microgrammes';
	UPDATE p_c_amount   SET amount = NULL WHERE amount=99;
	--fixed box_size
	UPDATE p_c_amount   SET box_size = 1 WHERE concept_code = '2761996';
	UPDATE p_c_amount   SET box_size = 1 WHERE concept_code = '3184064';
	UPDATE p_c_amount   SET box_size = 3 WHERE concept_code = '3184087';
	UPDATE p_c_amount   SET box_size = 1 WHERE concept_code = '3254913';
	UPDATE p_c_amount   SET box_size = 3 WHERE concept_code = '3254936';
	UPDATE p_c_amount   SET box_size = 1 WHERE concept_code = '3280709';
	UPDATE p_c_amount   SET box_size = 3 WHERE concept_code = '3280715';
	UPDATE p_c_amount   SET box_size = 1 WHERE concept_code = '3305065';
	UPDATE p_c_amount   SET box_size = 3 WHERE concept_code = '3305071';
	UPDATE p_c_amount   SET box_size = 1 WHERE concept_code = '3305088';
	UPDATE p_c_amount   SET box_size = 3 WHERE concept_code = '3305094';
	UPDATE p_c_amount   SET box_size = 1 WHERE concept_code = '3584622';
	UPDATE p_c_amount   SET box_size = 1 WHERE concept_code = '3588413';
	UPDATE p_c_amount   SET box_size = 3 WHERE concept_code = '3588436';
	UPDATE p_c_amount   SET box_size = 1 WHERE concept_code = '3589938';
	UPDATE p_c_amount   SET box_size = 3 WHERE concept_code = '3589944';
	UPDATE p_c_amount   SET box_size = 1 WHERE concept_code = '3589950';
	UPDATE p_c_amount   SET box_size = 3 WHERE concept_code = '3589967';
	UPDATE p_c_amount   SET box_size = 1 WHERE concept_code = '3715811';
	UPDATE p_c_amount   SET box_size = 3 WHERE concept_code = '3715828';
	UPDATE p_c_amount   SET box_size = 3 WHERE concept_code = '3770000';
	UPDATE p_c_amount   SET box_size = 1 WHERE concept_code = '3899975';
	UPDATE p_c_amount   SET box_size = 3 WHERE concept_code = '3899981';
	UPDATE p_c_amount   SET box_size = 1 WHERE concept_code = '3909484';
	UPDATE p_c_amount   SET box_size = 1 WHERE concept_code = '3918106';
	UPDATE p_c_amount   SET box_size = 3 WHERE concept_code = '3918112';
	UPDATE p_c_amount   SET box_size = NULL WHERE box_size=99;
END $_$;

--insert results into pack_content table
INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount,
	box_size
	)
SELECT concept_code,
	pack_component_code,
	amount,
	box_size
FROM p_c_amount;

--concept_synonym_stage 
INSERT INTO concept_synonym_stage (
	synonym_name,
	synonym_concept_code,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT concept_name,
	concept_code,
	'BDPM',
	4180190 -- French language 
FROM ingr_translation_all

UNION

SELECT form_route,
	concept_code,
	'BDPM',
	4180190
FROM form_translation ft
JOIN drug_concept_stage dcs ON ft.translation = dcs.concept_name

UNION

SELECT concept_name,
	concept_code,
	'BDPM',
	4180186
FROM drug_concept_stage
WHERE concept_class_id != 'unit';

-- Create sequence for new OMOP-created standard concepts
DO $_$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(replace(concept_code, 'OMOP','')::int4)+1 into ex FROM concept WHERE concept_code like 'OMOP%'  and concept_code not like '% %';
	DROP SEQUENCE IF EXISTS new_vocab;
	EXECUTE 'CREATE SEQUENCE new_vocab INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END$_$;

DROP TABLE IF EXISTS code_replace;
CREATE TABLE code_replace AS
SELECT 'OMOP' || nextval('new_vocab') AS new_code,
	concept_code AS old_code
FROM (
	SELECT concept_code
	FROM drug_concept_stage
	WHERE concept_code LIKE 'OMOP%' or concept_code like '%PACK%'
	GROUP BY concept_code
	ORDER BY LPAD(concept_code, 50, '0')
	) AS s0;

UPDATE drug_concept_stage a
SET concept_code = b.new_code
FROM code_replace b
WHERE a.concept_code = b.old_code;

UPDATE relationship_to_concept a
SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE ds_stage a
SET ingredient_concept_code = b.new_code
FROM code_replace b
WHERE a.ingredient_concept_code = b.old_code;

UPDATE ds_stage a
SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;

UPDATE internal_relationship_stage a
SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE internal_relationship_stage a
SET concept_code_2 = b.new_code
FROM code_replace b
WHERE a.concept_code_2 = b.old_code;

UPDATE pc_stage a
SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;

UPDATE drug_concept_stage
SET standard_concept = NULL
WHERE concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		JOIN internal_relationship_stage ON concept_code_1 = concept_code
		WHERE concept_class_id = 'Ingredient'
			AND standard_concept IS NOT NULL
		);

UPDATE drug_concept_stage
SET concept_class_id = 'Drug Product'
WHERE concept_class_id = 'Drug Pack';

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT pack_concept_code
		FROM pc_stage
		
		UNION ALL
		
		SELECT drug_concept_code
		FROM pc_stage
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT pack_concept_code
		FROM pc_stage
		
		UNION ALL
		
		SELECT drug_concept_code
		FROM pc_stage
		);

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM pc_stage
		);
