DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'BDPM',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.bdpm_drug LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.bdpm_drug LIMIT 1),
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

--do vaccines and insulins manually 
DROP TABLE if exists bdpm_vaccine_manual;

CREATE TABLE bdpm_vaccine_manual 
AS
SELECT a.din_7,
  a.drug_code,
       form_code,
       ingredient,
       dosage,
       volume,
       drug_descr,
       packaging,
       manufacturer,
       NULL::INTEGER AS c_id,
       NULL::VARCHAR AS c_code,
       NULL::VARCHAR AS c_name 
from sources.bdpm_packaging a 
join sources.bdpm_drug	b using(drug_code)
join sources.bdpm_ingredient	c using(drug_code)
WHERE ingredient ~* 'POLYOSIDE|HAEMOPHILUS|VARICELLE|influenzae|virus|insulin|ANATOXINE|PAPILLOMAVIRUS|RABIQUE|BORDETELLA|PERTUSS|STREPTOCOCCUS PNEUMONIAE|ROTAVIRUS|POLIOMYELITIQUE'
OR    drug_descr ~* 'vacin|vaccin|infanrix|influvac|boostrix|menveo|HBVAXPRO'
or form_code in ('96983','85085','97363','76197','82142','99920')
;
 


--fill non_drug table with devices
DROP TABLE IF EXISTS non_drug;
CREATE TABLE non_drug AS
SELECT b.drug_code,
	drug_descr,
	ingredient,
	form,
	form_code
FROM sources.bdpm_ingredient a
JOIN sources.bdpm_drug b ON a.drug_code = b.drug_code
WHERE (form_code IN (
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
		'31035',
		'75145'
		)
	OR dosage LIKE '%Bq%'
	OR form LIKE '%dialyse%')
;
 
--add radiopharmaceutical drugs
INSERT INTO non_drug
(
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
AND   a.drug_code::INTEGER NOT IN (66364008)
AND   a.drug_code NOT IN (SELECT drug_code FROM non_drug);


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
WHERE (ingredient ILIKE '%IOXITALAM%'
	OR ingredient ILIKE '%GADOTÉR%'
	OR ingredient ILIKE '%AMIDOTRIZOATE%'
	OR ingredient ILIKE '%CARBOM%'
	or (ingredient ILIKE '%123%' --and ingredient ILIKE '%IOD%'
	)
	OR form_code='86327')
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


--nutrients 
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
	where  a.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		)
and form ~* ' entéral|tisane|émulsion pour perfusion'
;


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
JOIN sources.bdpm_ingredient b ON a.drug_code = b.drug_code
	where  a.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		)
and ingredient ~* 'ÉTHANOL|TYROSINE|PARAFFINE|COLLOÏDAL|GLUTAMINE|LYSINE|GLYCINE|CHLORE ACTIF|ALCOOL|ALANINE';

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
	where  a.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		)
and drug_descr ~* 'ULTRAVIST|IOPAMIRON|OMNISCAN|VISIPAQUE|PROTOXYDE D''AZOTE|OMNIPAQUE|ISOVOL|BIONOLYTE|OXYGENE MEDICINAL|PRIMENE|MEDNUTRIFLEX|AMINOPLASMAL'
;
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
JOIN sources.bdpm_ingredient b ON a.drug_code = b.drug_code
WHERE drug_descr ~* 'CELSIOR|PLASMALYTE|POLYIONIQUE|PLASMION|ISOPEDIA|ISOFUNDINE|hémofiltration|AMINOMIX|dialys|test|radiopharmaceutique|STRUCTOKABIVEN|NUMETAN|NUMETAH|REANUTRIFLEX|CLINIMIX|REVITALOSE|CONTROLE|IOMERON|HEXABRIX|XENETIX'
	AND a.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		)
		--exclude radiopharmacuetical approved drug and testosterone
and a.drug_code::integer not in (66364008,68804011,69909645,69690774,61637467)		
;



--create table with homeopathic drugs, they won't be processed
DROP TABLE IF EXISTS homeop_drug;

CREATE TABLE homeop_drug 
AS
SELECT a.*
FROM sources.bdpm_ingredient a
  JOIN sources.bdpm_drug b ON a.drug_code = b.drug_code
WHERE (ingredient LIKE '%HOMÉOPA%' OR drug_descr LIKE '%degré de dilution compris entre%' OR certifier LIKE '%Enreg homéo%')
AND   a.drug_code NOT IN (SELECT drug_code
                          FROM non_drug
                          UNION
                          SELECT drug_code
                          FROM bdpm_vaccine_manual);



--collect package information and start extract quantity of drugs
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
		When 	packaging ~ 'boîte\sde\s\d+|de\s\d*flacon' then substring(packaging, 'boîte\sde\s(\d+)|e\s(\d*)flacon')
		ELSE NULL
		END::INT AS box_size
FROM sources.bdpm_packaging
	where drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		) 
		and drug_code NOT IN (
		SELECT drug_code
		FROM bdpm_vaccine_manual
		) 
			and drug_code NOT IN (
		SELECT drug_code
		FROM homeop_drug
		) 
;
 
--remove spaces in amount
UPDATE packaging_pars_1
SET amount = regexp_replace(amount, '([[:digit:]]+) ([[:digit:]]+)', '\1\2')
--select * from packaging_pars_1 
WHERE amount ~ '[[:digit:]]+ [[:digit:]]+';


-- define box size and quantity factor of drugs
DROP TABLE IF EXISTS packaging_pars_2;
CREATE TABLE packaging_pars_2 AS
SELECT
	CASE 
			WHEN NOT p.amount ~* '[[:digit:].,]+\s*(ml|g|mg|l|UI|MBq/ml|GBq/ml|litre(s*)|à|mlavec|kg)(\s|$|\,)' 
		  and p.amount !~* 'dose'
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

-- find proper amount for inhalation drugs
drop table if exists pack_inh;
create table pack_inh as 
select box_size, case when amount in ('1 dose','1  dose') then null else amount end as amount ,din_7,drug_code,packaging 
from (
select box_size, substring(packaging, '(\d+\s*dose)') as amount,din_7,drug_code,packaging
from packaging_pars_2 
where  packaging ~* 'dose' and amount is null) a ;
 
delete from packaging_pars_2 where (din_7,drug_code) in (
select din_7,drug_code
from pack_inh);

insert into packaging_pars_2
select * from pack_inh;


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
LEFT JOIN LATERAL(SELECT unnest(regexp_matches(amount, '(ml|g|mg|l|UI|MBq/ml|GBq/ml|litre(?:s*)|kg|dose)', 'i')) AS amount_unit) l ON true;

--manual fix


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
 


--find relationships between ingredients within the one drug
DROP TABLE IF EXISTS drug_ingred_to_ingred;
CREATE TABLE drug_ingred_to_ingred AS
SELECT DISTINCT a.drug_code,
	a.form_code AS concept_code_1,
	a.ingredient AS concept_name_1,
	b.form_code AS concept_code_2,
	b.ingredient AS concept_name_2
FROM sources.bdpm_ingredient a
join sources.bdpm_packaging  using(drug_code)
JOIN sources.bdpm_ingredient b ON a.drug_code = b.drug_code
	AND a.comp_number = b.comp_number
	AND a.ingredient != b.ingredient
	AND a.ingr_nature = 'SA'
	AND b.ingr_nature = 'FT'
where a.drug_code NOT IN (
		SELECT drug_code
		FROM homeop_drug
		)
	AND a.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		)
	AND a.drug_code NOT IN (
		SELECT drug_code
		FROM bdpm_vaccine_manual)		


;

--exclude homeopic_drugs and precise ingredients
DROP TABLE IF EXISTS ingredient_step_1;
CREATE TABLE ingredient_step_1 AS
SELECT a.*
FROM sources.bdpm_ingredient a
join sources.bdpm_packaging  using(drug_code)
WHERE NOT EXISTS (
		SELECT 1
		FROM drug_ingred_to_ingred b
		WHERE a.drug_code = b.drug_code::varchar
			AND form_code = concept_code_1::varchar
		)
	AND drug_code NOT IN (
		SELECT drug_code
		FROM homeop_drug
		)
	AND drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		)
	AND drug_code NOT IN (
		SELECT drug_code
		FROM bdpm_vaccine_manual)		
;

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
SET dosage = '800000 UFC'
WHERE dosage = '2-8 x 10^5 UFC';

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
	

-- find form of salts
DROP TABLE if exists upd_calc;

CREATE TABLE upd_calc 
AS
SELECT distinct a.drug_code,
       a.drug_form,
       FIRST_VALUE(b.form_code) OVER (PARTITION BY a.drug_code ORDER BY b.form_code) AS form_code,
       FIRST_VALUE(b.ingredient) OVER (PARTITION BY a.drug_code ORDER BY b.form_code) AS ingredient,
       a.dosage,
       a.volume,
       a.ingr_nature,
       a.comp_number,
       a.dosage_value,
       a.dosage_unit,
       a.volume_value,
       a.volume_unit,
       a.form_Code AS old_code,
       a.ingredient
FROM ingredient_step_2 a
  JOIN sources.bdpm_ingredient b USING (drug_code)
WHERE a.ingredient in ('CALCIUM ÉLÉMENT','POTASSIUM')
and (b.ingredient like '%CALCIUM%' or b.ingredient like '%POTASSIUM%')
and  a.form_code != b.form_code;


DELETE
FROM ingredient_step_2
WHERE (drug_code,form_code) IN (SELECT drug_code, old_code FROM upd_calc);


INSERT INTO ingredient_step_2
(
  drug_code,
  drug_form,
  form_code,
  ingredient,
  dosage,
  volume,
  ingr_nature,
  comp_number,
  dosage_value,
  dosage_unit,
  volume_value,
  volume_unit
)
SELECT drug_code,
       drug_form,
       form_code,
       ingredient,
       dosage,
       volume,
       ingr_nature,
       comp_number,
       dosage_value,
       dosage_unit,
       volume_value,
       volume_unit
FROM upd_calc;



--recalculate all the possible combinations between packaging info and ingredient info
DROP TABLE if exists ds_1_1;

CREATE TABLE ds_1_1 
AS
select COUNT(ingredient_code) OVER (PARTITION BY concept_code) AS c1,* from 
(
SELECT DISTINCT din_7::VARCHAR AS concept_code,
       a.drug_code,
       drug_form,
       form_code AS ingredient_code,
       ingredient AS ingredient_name,
       packaging,
       d.drug_descr,
       dosage_value,
       dosage_unit,
              CASE
         WHEN volume_value IS NULL THEN 1
         ELSE volume_value
       END AS volume_value,
       volume_unit,
       CASE
         WHEN volume_value IS NULL AND amount_value IS NULL THEN dosage_value
         ELSE NULL
       END AS amount_value,
       CASE
         WHEN volume_value IS NULL AND amount_value IS NULL THEN dosage_unit
         ELSE NULL
       END AS amount_unit,
       CASE
         WHEN COUNT(ingredient) OVER (PARTITION BY a.din_7) > 1 AND (amount_value IS NOT NULL OR amount_unit NOT IN ('ml','mL','g')) THEN dosage_value::VARCHAR
         WHEN COUNT(ingredient) OVER (PARTITION BY a.din_7) > 1 AND amount_value IS  NULL then dosage_value::VARCHAR
         WHEN drug_descr ~ '%' THEN TRIM(REGEXP_REPLACE(REGEXP_REPLACE(SUBSTRING(drug_descr,'(\d+?\s?\,?\.?\d*\s?)%'),',','.'),' ',''))
         WHEN amount_unit ~ 'dose\(s\)' THEN dosage_value::VARCHAR
         WHEN drug_descr ~ '\/\d?\s?\,?\d+\s(mL|ml|l|heures)' AND COUNT(ingredient) OVER (PARTITION BY a.din_7) = 1 THEN TRIM(REGEXP_REPLACE(REGEXP_REPLACE(SUBSTRING(drug_descr,'(\d+?\s?\,?\.?\d*\s)(mg|g|microgrammes|UI|unités|U)\/\d?\s?\,?\d+\s?(ml|mL|l|dose|g|heures)'),',','.'),' ',''))
         ELSE TRIM(REGEXP_REPLACE(REGEXP_REPLACE(SUBSTRING(drug_descr,'(\d+?\s?\,?\.?\d*\s)(ppm mole|mg|g|microgrammes|UI|unités|U)\/(1)?\s?(ml|mL|dose|mole|l|g)'),',','.'),' ',''))
       END AS numerator_value,
       CASE
         WHEN COUNT(ingredient) OVER (PARTITION BY a.din_7) > 1 AND (amount_value IS NOT NULL OR amount_unit NOT IN ('ml','mL','g')) THEN dosage_unit
         WHEN COUNT(ingredient) OVER (PARTITION BY a.din_7) > 1 AND amount_value IS  NULL then dosage_unit
         WHEN drug_descr ~ '%' THEN TRIM(REGEXP_REPLACE(REGEXP_REPLACE(SUBSTRING(drug_descr,'\d+?\s?\,?\.?\d*\s?(%)'),',','.'),' ',''))
         WHEN amount_unit ~ 'dose\(s\)' THEN dosage_unit
         WHEN drug_descr ~ '\/\d?\s?\,?\d+\s(mL|ml|l|heures)' AND COUNT(ingredient) OVER (PARTITION BY a.din_7) = 1 THEN TRIM(REGEXP_REPLACE(REGEXP_REPLACE(SUBSTRING(drug_descr,'\d+?\s?\,?\.?\d*\s(mg|g|microgrammes|UI|unités|U)\/\d?\s?\,?\d+\s?(ml|mL||ldose|g|heures)'),',','.'),' ',''))
         ELSE SUBSTRING(drug_descr,'\d+?\s?\,?\.?\d*\s(ppm mole|mg|g|microgrammes|UI|unités|U)\/(1)?\s?(ml|mL|dose|mole|l|g)')
       END AS numerator_unit,
       CASE
         WHEN drug_descr ~ '\/\s?\d?\s?\,?\d+?\s(mL|ml|l|heures)' AND COUNT(ingredient) OVER (PARTITION BY a.din_7) = 1 THEN TRIM(/*REGEXP_REPLACE(*/REGEXP_REPLACE(SUBSTRING(drug_descr,'\/\s?(\d?\s?\,?\d+?)\s?(ml|mL|l|dose|g|heures)'),',','.')/*,' ','')*/)
         ELSE NULL
       END AS denom,
              CASE
         WHEN drug_descr ~ '\/\s?\d?\s?\,?\d+\s(mL|ml|l|heures)' AND COUNT(ingredient) OVER (PARTITION BY a.din_7) = 1 THEN TRIM(REGEXP_REPLACE(REGEXP_REPLACE(SUBSTRING(drug_descr,'\/\d?\s?\,?\d+\s?(ml|mL|l|dose|g|heures)'),',','.'),' ',''))
when drug_descr ~ '\d+?\s?\,?\.?\d*\s((ppm mole|mg|g|microgrammes|UI|unités|U))\/(1)?\s?(ml|mL|dose|mole|l|g)' then       SUBSTRING(drug_descr, '\/1?\s?(ml|mL|mole|l|dose|g)')
ELSE NULL
       END AS denom_unit,
       CASE
         WHEN amount_unit NOT IN ('ml','mL','g','dose') THEN NULL
         ELSE amount_value
       END AS fut_denominator_value,
       CASE
         WHEN amount_unit NOT IN ('ml','mL','g','dose') THEN NULL
         ELSE amount_unit
       END AS fut_denominator_unit,
       box_size
FROM packaging_pars_3 a
  JOIN ingredient_step_2 b ON a.drug_code = b.drug_code
  JOIN sources.bdpm_drug d
    ON b.drug_code = d.drug_code
   AND a.drug_code NOT IN (SELECT drug_code FROM non_drug
   union SELECT drug_code FROM bdpm_vaccine_manual
   union
			select drug_code 
			from homeop_drug)
   )d
;

DROP TABLE IF EXISTS ds_1;

CREATE TABLE ds_1 
AS
SELECT concept_code,
       c1,
       drug_code,
       drug_form,
       ingredient_code,
       ingredient_name,
       packaging,
       NULL AS pack_amount_value,
       NULL AS pack_amount_unit,
       drug_descr,
       dosage_value,
       dosage_unit,
       volume_value,
       volume_unit,
       CASE
         WHEN drug_form !~* 'ovule|collyre|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NULL AND amount_value IS NULL AND denom IS  NULL THEN dosage_value
         ELSE amount_value
       END AS amount_value,
       CASE
         WHEN drug_form !~* 'ovule|collyre|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NULL AND amount_value IS NULL AND denom IS  NULL THEN dosage_unit
         ELSE amount_unit
       END AS amount_unit,
       CASE
         WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NULL AND amount_value IS NULL AND numerator IS NOT NULL AND denom IS NOT NULL THEN TRIM(numerator)::FLOAT
         WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND drug_descr ~* 'MOMETASONE' THEN dosage_value*TRIM(SUBSTRING(packaging,'(\d+)\sdose'))::FLOAT
         WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND drug_descr ~* 'PROSTINE E2' THEN dosage_value
         ELSE numerator_value
       END AS numerator_value,
       CASE
         WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NULL AND amount_value IS NULL AND numerator IS NOT NULL AND denom IS NOT NULL THEN numerator_u
         WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND drug_descr ~* 'MOMETASONE' THEN dosage_unit
         WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND drug_descr ~* 'PROSTINE E2' THEN dosage_unit
         ELSE numerator_unit
       END AS numerator_unit,
       CASE
         WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NULL AND amount_value IS NULL AND numerator IS NOT NULL AND denom IS NOT NULL THEN TRIM(denom)::FLOAT
         WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND drug_descr ~* 'MOMETASONE' THEN TRIM(SUBSTRING(packaging,'(\d+)\sdose'))::FLOAT
         WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND drug_descr ~* 'PROSTINE E2' THEN fut_denominator_value
         ELSE denominator_value
       END AS denominator_value,
       CASE
         WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NULL AND amount_value IS NULL AND numerator IS NOT NULL AND denom IS NOT NULL THEN denom_unit
         WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND drug_descr ~* 'MOMETASONE' THEN 'dose'
         WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND drug_descr ~* 'PROSTINE E2' THEN fut_denominator_unit
         ELSE denominator_unit
       END AS denominator_unit,
       box_size
FROM (SELECT concept_code,
             c1,
             drug_code,
             drug_form,
             ingredient_code,
             ingredient_name,
             packaging,
             NULL AS pack_amount_value,
             NULL AS pack_amount_unit,
             drug_descr,
             dosage_value,
             dosage_unit,
             volume_value,
             volume_unit,
             numerator_value AS numerator,
             numerator_unit AS numerator_u,
             amount_value AS amount,
             denom,
             denom_unit,
             fut_denominator_value,
             fut_denominator_unit,
             CASE
               WHEN drug_form ~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat' THEN dosage_value
               WHEN drug_form ~* 'emplâtre' AND volume_unit IS NULL AND drug_descr !~* '%' THEN dosage_value
               WHEN drug_form !~* 'ovule|collyre|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NOT NULL AND fut_denominator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr !~* '\/\s?(ml|ML|mL)' AND drug_descr !~* 'unidose' AND fut_denominator_unit ~* 'g' THEN dosage_value
               WHEN drug_form !~* 'ovule|collyre|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NOT NULL AND fut_denominator_value IS NULL AND denom IS NULL AND volume_unit IS NULL THEN dosage_value
               WHEN drug_form !~* 'ovule|collyre|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NULL AND fut_denominator_value IS NULL AND denom IS NULL AND volume_unit IS NULL THEN dosage_value
               WHEN dosage_unit != 'g' AND volume_unit IS NULL AND fut_denominator_unit NOT IN ('ml','mL') AND numerator_value IS NULL THEN dosage_value
               WHEN drug_form !~* 'ovule|collyre|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND dosage_unit IS NOT NULL AND volume_unit = 'g' AND fut_denominator_unit IS NULL AND volume_value NOT IN (100,10,1) THEN dosage_value
             END AS amount_value,
             CASE
               WHEN drug_form ~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat' THEN dosage_unit
               WHEN drug_form ~* 'emplâtre' AND volume_unit IS NULL AND drug_descr !~* '%' THEN dosage_unit
               WHEN drug_form !~* 'ovule|collyre|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NOT NULL AND fut_denominator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr !~* '\/\s?(ml|ML|mL)' AND drug_descr !~* 'unidose' AND fut_denominator_unit ~* 'g' THEN dosage_unit
               WHEN drug_form !~* 'ovule|collyre|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NOT NULL AND fut_denominator_value IS NULL AND denom IS NULL AND volume_unit IS NULL THEN dosage_unit
               WHEN drug_form !~* 'ovule|collyre|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NULL AND fut_denominator_value IS NULL AND denom IS NULL AND volume_unit IS NULL THEN dosage_unit
               WHEN dosage_unit != 'g' AND volume_unit IS NULL AND fut_denominator_unit NOT IN ('ml','mL') AND numerator_value IS NULL THEN dosage_unit
               WHEN drug_form !~* 'ovule|collyre|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND dosage_unit IS NOT NULL AND volume_unit = 'g' AND fut_denominator_unit IS NULL AND volume_value NOT IN (100,10,1) THEN dosage_unit
             END AS amount_unit,
             CASE
               WHEN drug_form ~* 'emplâtre' AND volume_unit = 'g' AND drug_descr !~* '%' THEN (dosage_value / volume_value) / 1000
               WHEN drug_form ~* 'emplâtre' AND drug_descr ~* '%' THEN ((TRIM(SUBSTRING(drug_descr,'(\d+)\s?\%'))::FLOAT)*10) / 1000
               WHEN dosage_unit = 'g' AND volume_unit = 'ml' AND fut_denominator_unit IN ('ml','mL') THEN ((dosage_value*1000) / volume_value)*fut_denominator_value
               WHEN dosage_unit = 'g' AND volume_unit = 'g' AND fut_denominator_unit IN ('ml','mL') THEN ((dosage_value / volume_value)*1000)*fut_denominator_value
               WHEN dosage_unit != 'g' AND volume_unit = 'ml' AND fut_denominator_unit IN ('ml','mL') THEN (dosage_value / volume_value)*fut_denominator_value
               WHEN dosage_unit != 'g' AND volume_unit != 'ml' AND fut_denominator_unit NOT IN ('ml','mL') THEN (dosage_value / volume_value)*fut_denominator_value
               WHEN dosage_unit = 'g' AND volume_unit = 'g' AND fut_denominator_unit = 'g' THEN (dosage_value / volume_value)*fut_denominator_value
               WHEN dosage_unit != 'g' AND volume_unit = 'ml' AND fut_denominator_unit NOT IN ('ml','mL') THEN dosage_value
               WHEN dosage_unit != 'g' AND volume_unit = 'g' AND fut_denominator_unit IN ('ml','mL') THEN dosage_value /(volume_value*1000)
               WHEN dosage_unit != 'g' AND volume_unit IS NULL AND fut_denominator_unit IN ('ml','mL') AND numerator_value IS NULL THEN dosage_value
               WHEN dosage_unit IS NOT NULL AND volume_unit = 'ml' AND fut_denominator_unit IS NULL THEN dosage_value
               WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND dosage_unit IS NOT NULL AND volume_unit = 'g' AND fut_denominator_unit IS NULL AND volume_value IN (100,10,1) THEN dosage_value / volume_value
               WHEN drug_form !~* 'ovule|collyre|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND dosage_unit != 'g' AND volume_unit IS NOT NULL AND fut_denominator_unit IS NULL AND numerator_value IS NULL THEN dosage_value
               WHEN drug_descr ~* '%' AND volume_unit IS NULL THEN (TRIM(REGEXP_REPLACE(SUBSTRING(drug_descr,'(\d*\,?\d+?)\s?\%'),',','.'))::FLOAT)*10*fut_denominator_value
               WHEN volume_unit IS NULL AND numerator_value IS NOT NULL AND denom IS NOT NULL THEN (TRIM(numerator_value)::FLOAT/TRIM(denom)::FLOAT)*fut_denominator_value
               WHEN numerator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr ~* '\/\s?(ml|ML|mL)' AND fut_denominator_value IS NOT NULL AND fut_denominator_unit != 'g' THEN (TRIM(numerator_value)::FLOAT)*fut_denominator_value
               WHEN numerator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr ~* '\/\s?(ml|ML|mL)' AND fut_denominator_value IS NOT NULL AND fut_denominator_unit = 'g' THEN (TRIM(numerator_value)::FLOAT)
               WHEN drug_descr ~* 'unidose' AND volume_unit IS NULL AND denom IS NULL AND drug_descr !~* '%' AND fut_denominator_unit !~* 'dose' THEN dosage_value
               WHEN drug_descr ~* 'unidose' AND volume_unit IS NULL AND denom IS NULL AND drug_descr !~* '%' AND fut_denominator_unit ~* 'dose' THEN dosage_value*fut_denominator_value
               WHEN drug_form ~* 'collyre' AND drug_descr ~* 'TOBRABACT' THEN (TRIM(REGEXP_REPLACE(SUBSTRING(drug_descr,'(\d+\,\d+)\s?\%'),',','.'))::FLOAT)*10*fut_denominator_value
               WHEN drug_form ~* 'collyre' AND drug_descr ~* 'LUMIGAN|OPHTASILOXANE' THEN dosage_value
               WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NOT NULL AND fut_denominator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr !~* '\/\s?(ml|ML|mL)' AND drug_descr !~* 'unidose' AND fut_denominator_unit !~* 'dose|g' AND drug_descr !~* 'g\/l' THEN TRIM(numerator_value)::FLOAT
               WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NOT NULL AND fut_denominator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr !~* '\/\s?(ml|ML|mL)' AND drug_descr !~* 'unidose' AND fut_denominator_unit !~* 'dose|g' AND drug_descr ~* 'g\/l' THEN TRIM(numerator_value)::FLOAT*fut_denominator_value
               WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NOT NULL AND fut_denominator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr !~* '\/\s?(ml|ML|mL)' AND drug_descr !~* 'unidose' AND fut_denominator_unit ~* 'dose' THEN TRIM(numerator_value)::FLOAT*fut_denominator_value
             END AS numerator_value,
             CASE
               WHEN drug_form ~* 'emplâtre' AND volume_unit = 'g' AND drug_descr !~* '%' AND dosage_unit = 'g' THEN 'mg'
               WHEN drug_form ~* 'emplâtre' AND volume_unit = 'g' AND drug_descr !~* '%' AND dosage_unit != 'g' THEN dosage_unit
               WHEN drug_form ~* 'emplâtre' AND drug_descr ~* '%' THEN 'mg'
               WHEN dosage_unit = 'g' AND volume_unit = 'ml' AND fut_denominator_unit IN ('ml','mL') THEN 'mg'
               WHEN dosage_unit = 'g' AND volume_unit = 'g' AND fut_denominator_unit IN ('ml','mL') THEN 'mg'
               WHEN dosage_unit != 'g' AND volume_unit = 'ml' AND fut_denominator_unit IN ('ml','mL') THEN dosage_unit
               WHEN dosage_unit != 'g' AND volume_unit != 'ml' AND fut_denominator_unit NOT IN ('ml','mL') THEN dosage_unit
               WHEN dosage_unit = 'g' AND volume_unit = 'g' AND fut_denominator_unit = 'g' THEN dosage_unit
               WHEN dosage_unit != 'g' AND volume_unit = 'ml' AND fut_denominator_unit NOT IN ('ml','mL') THEN dosage_unit
               WHEN dosage_unit != 'g' AND volume_unit = 'g' AND fut_denominator_unit IN ('ml','mL') THEN dosage_unit
               WHEN dosage_unit != 'g' AND volume_unit IS NULL AND fut_denominator_unit IN ('ml','mL') AND numerator_value IS NULL THEN dosage_unit
               WHEN dosage_unit IS NOT NULL AND volume_unit = 'ml' AND fut_denominator_unit IS NULL THEN dosage_unit
               WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND dosage_unit IS NOT NULL AND volume_unit = 'g' AND fut_denominator_unit IS NULL AND volume_value IN (100,10,1) THEN dosage_unit
               WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND dosage_unit != 'g' AND volume_unit IS NOT NULL AND fut_denominator_unit IS NULL AND numerator_value IS NULL THEN dosage_unit
               WHEN drug_descr ~* '%' AND volume_unit IS NULL THEN 'mg'
               WHEN volume_unit IS NULL AND numerator_value IS NOT NULL AND denom IS NOT NULL THEN dosage_unit
               WHEN numerator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr ~* '\/\s?(ml|ML|mL)' AND fut_denominator_value IS NOT NULL AND fut_denominator_unit != 'g' THEN numerator_unit
               WHEN numerator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr ~* '\/\s?(ml|ML|mL)' AND fut_denominator_value IS NOT NULL AND fut_denominator_unit = 'g' THEN numerator_unit
               WHEN drug_descr ~* 'unidose' AND volume_unit IS NULL AND denom IS NULL AND drug_descr !~* '%' THEN dosage_unit
               WHEN drug_form ~* 'collyre' AND drug_descr ~* 'TOBRABACT' THEN 'mg'
               WHEN drug_form ~* 'collyre' AND drug_descr ~* 'LUMIGAN|OPHTASILOXANE' THEN dosage_unit
               WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NOT NULL AND fut_denominator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr !~* '\/\s?(ml|ML|mL)' AND drug_descr !~* 'unidose' AND fut_denominator_unit !~* 'dose|g' AND drug_descr !~* 'g\/l' THEN numerator_unit
               WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NOT NULL AND fut_denominator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr !~* '\/\s?(ml|ML|mL)' AND drug_descr !~* 'unidose' AND fut_denominator_unit !~* 'dose|g' AND drug_descr ~* 'g\/l' THEN 'mg'
               WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NOT NULL AND fut_denominator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr !~* '\/\s?(ml|ML|mL)' AND drug_descr !~* 'unidose' AND fut_denominator_unit ~* 'dose' THEN numerator_unit
             END AS numerator_unit,
             CASE
               WHEN drug_form ~* 'emplâtre' AND volume_unit = 'g' AND drug_descr !~* '%' THEN NULL
               WHEN drug_form ~* 'emplâtre' AND drug_descr ~* '%' THEN NULL
               WHEN dosage_unit != 'g' AND volume_unit = 'ml' AND fut_denominator_unit NOT IN ('ml','mL') THEN volume_value
               WHEN dosage_unit != 'g' AND volume_unit = 'g' AND fut_denominator_unit IN ('ml','mL') THEN NULL
               WHEN dosage_unit != 'g' AND volume_unit = 'ml' AND fut_denominator_unit IN ('ml','mL') THEN fut_denominator_value
               WHEN dosage_unit IS NOT NULL AND volume_unit = 'ml' AND fut_denominator_unit IS NULL THEN volume_value
               WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND dosage_unit != 'g' AND volume_unit IS NOT NULL AND fut_denominator_unit IS NULL AND numerator_value IS NULL THEN volume_value
               WHEN numerator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr ~* '\/\s?(ml|ML|mL)' AND fut_denominator_value IS NOT NULL AND fut_denominator_unit = 'g' THEN NULL
               WHEN drug_form ~* 'collyre' AND drug_descr ~* 'LUMIGAN|OPHTASILOXANE' THEN NULL
               WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NOT NULL AND fut_denominator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr !~* '\/\s?(ml|ML|mL)' AND drug_descr !~* 'unidose' AND fut_denominator_unit ~* 'g' THEN NULL
               WHEN dosage_unit != 'g' AND volume_unit IS NULL AND fut_denominator_unit NOT IN ('ml','mL') AND numerator_value IS NULL THEN NULL
               ELSE fut_denominator_value
             END AS denominator_value,
             CASE
               WHEN drug_form ~* 'emplâtre' AND volume_unit = 'g' AND drug_descr !~* '%' THEN 'mg'
               WHEN drug_form ~* 'emplâtre' AND drug_descr ~* '%' THEN 'mg'
               WHEN dosage_unit != 'g' AND volume_unit = 'ml' AND fut_denominator_unit NOT IN ('ml','mL') THEN volume_unit
               WHEN dosage_unit IS NOT NULL AND volume_unit = 'ml' AND fut_denominator_unit IS NULL THEN volume_unit
               WHEN dosage_unit != 'g' AND volume_unit = 'g' AND fut_denominator_unit IN ('ml','mL') THEN 'mg'
               WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND dosage_unit IS NOT NULL AND volume_unit = 'g' AND fut_denominator_unit IS NULL AND volume_value IN (100,10,1) THEN volume_unit
               WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND dosage_unit != 'g' AND volume_unit IS NOT NULL AND fut_denominator_unit IS NULL AND numerator_value IS NULL THEN volume_unit
               WHEN numerator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr ~* '\/\s?(ml|ML|mL)' AND fut_denominator_value IS NOT NULL AND fut_denominator_unit = 'g' THEN denom_unit
               WHEN drug_form ~* 'collyre' AND drug_descr ~* 'LUMIGAN|OPHTASILOXANE' THEN volume_unit
               WHEN drug_form !~* 'ovule|comprimé|suppositoire|microsphère|microgranule|gélule|granulé|gomme|capsule|pastille|film|lyophilisat|emplâtre' AND numerator_value IS NOT NULL AND fut_denominator_value IS NOT NULL AND denom IS NULL AND volume_unit IS NULL AND drug_descr !~* '%' AND drug_descr !~* '\/\s?(ml|ML|mL)' AND drug_descr !~* 'unidose' AND fut_denominator_unit ~* 'g' THEN NULL
               WHEN dosage_unit != 'g' AND volume_unit IS NULL AND fut_denominator_unit NOT IN ('ml','mL') AND numerator_value IS NULL THEN NULL
               ELSE fut_denominator_unit
             END AS denominator_unit,
             CASE
               WHEN box_size = 1 THEN NULL
               ELSE box_size
             END AS box_size
      FROM ds_1_1) a;

-- manual fix 
update ds_1
set numerator_value = numerator_value/denominator_value,
denominator_value = null
where packaging ~* 'avec cuillère-mesure'
and denominator_value = 5
and denominator_unit in ('ml','mL')
;

update ds_1
set numerator_value = 50
where concept_code = '2750567'
;

update ds_1 
set numerator_value = 20,
numerator_unit = 'mg'
where concept_code = '3646843';

update ds_1 
set numerator_value = 20,
numerator_unit = 'mg'
where concept_code = '3646837';


 	
update ds_1
set numerator_value = (dosage_value*10)*denominator_value,
numerator_unit = 'mg'
where concept_code in ('3894707','3894713','3894736','3006088');

update ds_1 
set denominator_value = 1 
where denominator_unit ='g' and denominator_value is null
 ;

update ds_1
set numerator_value = 100
where concept_code = '3140486'
;


UPDATE ds_1
   SET amount_value = NULL,
       amount_unit = NULL
WHERE amount_value IS NOT NULL
AND   numerator_value IS NOT NULL
AND   denominator_unit IS NOT NULL;

UPDATE ds_1
   SET numerator_value = NULL,
       numerator_unit = NULL
WHERE amount_value IS NOT NULL
AND   numerator_value IS NOT NULL
AND   denominator_unit IS NULL;


-- give clear dosage for oxygen
UPDATE ds_1 a
   SET numerator_value = b.amount_value,
       numerator_unit = b.amount_unit,
       amount_value = NULL,
       amount_unit = NULL,
       denominator_unit = NULL
FROM ds_1 b
WHERE a.concept_code = b.concept_code
AND   a.drug_code = b.drug_code
AND   a.drug_form = b.drug_form
AND   a.ingredient_code = b.ingredient_code
AND   a.ingredient_name = b.ingredient_name
AND   a.amount_unit IN ('% ','%','ppm mole');


-- update dosage for multidrugs
DROP TABLE if exists ds_1_2;

CREATE TABLE ds_1_2 
AS
SELECT DISTINCT concept_code,
       drug_code,
       ingredient_code,
       CASE
         WHEN numerator_value IS NOT NULL THEN NULL
         ELSE amount_value
       END AS amount_value,
       CASE
         WHEN numerator_value IS NOT NULL THEN NULL
         ELSE amount_unit
       END AS amount_unit,
       numerator_value,
       numerator_unit,
       denominator_value,
       denominator_unit,
       box_size
FROM (SELECT concept_code,
             drug_code,
             ingredient_code,
             TRIM(REGEXP_REPLACE(REGEXP_REPLACE(SUBSTRING(drug_descr,'(\d+?\s?\,?\.?\d*\s)(ppm mole|mg|g|microgrammes|UI|unités|U)'),',','.'),' ','')) AS amount_value,
             TRIM(REGEXP_REPLACE(REGEXP_REPLACE(SUBSTRING(drug_descr,'\d+?\s?\,?\.?\d*\s(ppm mole|mg|g|microgrammes|UI|unités|U)'),',','.'),' ','')) AS amount_unit,
             CASE
               WHEN drug_descr ~ '\/\d?\s?\,?\d+\s(mL|ml|l|heures)' THEN TRIM(REGEXP_REPLACE(REGEXP_REPLACE(SUBSTRING(drug_descr,'(\d+?\s?\,?\.?\d*\s)(mg|g|microgrammes|UI|unités|U)\/\d?\s?\,?\d+\s?(ml|mL|l|dose|g|heures)'),',','.'),' ',''))
               ELSE TRIM(REGEXP_REPLACE(REGEXP_REPLACE(SUBSTRING(drug_descr,'(\d+?\s?\,?\.?\d*\s)(ppm mole|mg|g|microgrammes|UI|unités|U)\/(1)?\s?(ml|mL|dose|mole|l|g)'),',','.'),' ',''))
             END AS numerator_value,
             CASE
               WHEN drug_descr ~ '\/\d?\s?\,?\d+\s(mL|ml|l|heures)' THEN TRIM(REGEXP_REPLACE(REGEXP_REPLACE(SUBSTRING(drug_descr,'\d+?\s?\,?\.?\d*\s(mg|g|microgrammes|UI|unités|U)\/\d?\s?\,?\d+\s?(ml|mL||ldose|g|heures)'),',','.'),' ',''))
               ELSE SUBSTRING(drug_descr,'\d+?\s?\,?\.?\d*\s(ppm mole|mg|g|microgrammes|UI|unités|U)\/(1)?\s?(ml|mL|dose|mole|l|g)')
             END AS numerator_unit,
             TRIM(REGEXP_REPLACE(REGEXP_REPLACE(SUBSTRING(drug_descr,'\/(\d?\s?\,?\d+)\s?(ml|mL|l|dose|g|heures)'),',','.'),' ','')) AS denominator_value,
             CASE
               WHEN drug_descr ~ '\/\d?\s?\,?\d+\s(mL|ml|l|heures)' THEN TRIM(REGEXP_REPLACE(REGEXP_REPLACE(SUBSTRING(drug_descr,'\/\d?\s?\,?\d+\s?(ml|mL|l|dose|g|heures)'),',','.'),' ',''))
               ELSE SUBSTRING(drug_descr,'\/1?\s?(ml|mL|mole|l|dose|g)')
             END AS denominator_unit,
             box_size
      FROM (SELECT COUNT(1) OVER (PARTITION BY concept_code,drug_code,ingredient_code,drug_form) AS c2,
                   *
            FROM ds_1) a
      WHERE c2 > 1) az;


DELETE
FROM ds_1
WHERE concept_code IN (SELECT concept_code FROM ds_1_2);

INSERT INTO ds_1
(
  concept_code,
  ingredient_code,
  amount_value,
  amount_unit,
  numerator_value,
  numerator_unit,
  denominator_value,
  denominator_unit,
  box_size
)
SELECT concept_code,
       ingredient_code,
       amount_value::FLOAT,
       amount_unit,
       numerator_value::FLOAT,
       numerator_unit,
       denominator_value::FLOAT,
       denominator_unit,
       box_size
FROM ds_1_2;

-- update with standard units
UPDATE ds_1
   SET amount_unit = attr_name
FROM rtc_1
WHERE TRIM(UPPER(amount_unit)) = UPPER(original_name);

UPDATE ds_1
   SET numerator_unit = attr_name
--from unit_translation 
       FROM rtc_1
WHERE TRIM(UPPER(numerator_unit)) = UPPER(original_name);

UPDATE ds_1
   SET denominator_unit = attr_name
--from unit_translation 
       FROM rtc_1
WHERE TRIM(UPPER(denominator_unit)) = UPPER(original_name);



--manual fixes
 
UPDATE ds_1
SET numerator_unit = 'mg'
WHERE concept_code = '5654597'
	AND ingredient_code = '01080';
	
update ds_1 
set amount_value = amount_value*1000,
amount_unit = 'mg'
where amount_unit = 'g';

update ds_1 
set numerator_value = numerator_value*1000,
numerator_unit = 'mg'
where numerator_unit = 'g';

update ds_1 
set denominator_value = denominator_value*1000,
denominator_unit = 'mg'
where denominator_unit = 'g';

update  ds_1
set denominator_value = null,
denominator_unit = null
WHERE drug_form = 'gaz'
;


update ds_1
set numerator_value =  numerator_value*0.0001, 
numerator_unit = '%'
where numerator_unit = 'ppm mole';

update  ds_1
set numerator_value = amount_value,
numerator_unit = amount_unit, 
amount_value = null,
amount_unit = null  
where amount_value is not null and denominator_value is not null and drug_descr ~* '\/\d*\,?\d*?\s?ml';

update  ds_1 
set denominator_value = null,
denominator_unit = null
where amount_value is not null and denominator_value is not null;

update  ds_1 
set numerator_unit = null
where amount_value is not  null 
and numerator_unit is not null
;

-- create table for packs
DROP TABLE pack_st_1;

CREATE TABLE pack_st_1 
AS
SELECT drug_code,
       drug_form,
       form_code
FROM ingredient_step_2
WHERE drug_code IN (SELECT drug_code
                    FROM (SELECT DISTINCT drug_code, drug_form FROM ingredient_step_2) AS s0
                    GROUP BY drug_code
                    HAVING COUNT(1) > 1)
AND   drug_code NOT IN (SELECT drug_code FROM non_drug)
AND   drug_code NOT IN (SELECT drug_code FROM homeop_drug)
AND   drug_code NOT IN ('64122611','67657035')
AND   drug_code NOT IN (SELECT drug_code
                        FROM sources.bdpm_packaging
                        WHERE din_7 IN (3012520,5754637,5611085,3007865,3007867,3008279,3012518,3048384,3209686));





--sequence will be used in pack component definition
DROP SEQUENCE IF EXISTS pack_sequence;
CREATE SEQUENCE pack_sequence MINVALUE 1 MAXVALUE 1000000 START WITH 1 INCREMENT BY 1 CACHE 100;

--collect all pack components 
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
			union
			select drug_code 
			from bdpm_vaccine_manual
			union
			select drug_code 
			from homeop_drug
			)
	) A;
	


--fill pack content, but need to be changed amounts manually
DROP TABLE IF EXISTS pack_cont_1;
CREATE TABLE pack_cont_1 AS
SELECT DISTINCT concept_code,
	pack_component_code,
	a.drug_descr AS pack_name,a.drug_form,
 CONCAT (
		a.drug_descr,
		' ',
		a.drug_form
		) AS pack_component_name,
	packaging , pack_amount_value,a.denominator_value,a.denominator_unit
FROM pack_comp_list B
JOIN ds_1 A ON a.drug_code = b.drug_code
	AND a.drug_form = b.drug_form
	AND a.drug_descr = b.drug_descr
	AND coalesce(a.denominator_value, '0') = coalesce(b.denominator_value, '0')
	AND coalesce(a.denominator_unit, '0') = coalesce(b.denominator_unit, '0');
	

;

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
 

UPDATE ds_stage
SET numerator_value = power(10, numerator_value),
	numerator_unit = 'CCID_50'
WHERE numerator_unit = 'log CCID_50';



-- extract Suppliers
DROP TABLE IF EXISTS dcs_manufacturer;
CREATE TABLE dcs_manufacturer AS
SELECT DISTINCT LTRIM(manufacturer,' ') AS concept_name,
       drug_code,
       'Supplier'::VARCHAR AS concept_class_id
FROM sources.bdpm_drug
  JOIN sources.bdpm_packaging USING (drug_code)
WHERE drug_code NOT IN 
(
  SELECT drug_code 
  FROM non_drug
UNION 
  SELECT drug_code 
  FROM bdpm_vaccine_manual
UNION
  SELECT drug_code
  FROM homeop_drug
)
;

-- find suppliers automaticly and fit names to standard 
drop table if exists dcs_manufacturer_1;
create table dcs_manufacturer_1 as 
with az as (
select a.concept_name as attr_name, a.concept_class_id as attr_class, a.drug_code, c.*
from dcs_manufacturer  a
join devv5.concept  c on uppeR(a.concept_name) = upper(c.concept_name) 
where c.concept_class_id = 'Supplier'
and c.vocabulary_id like 'Rx%'
and c.invalid_reason is null
),
ab as (
select a.concept_name as attr_name, a.concept_class_id as attr_class, a.drug_code, c.*
from dcs_manufacturer  a
join devv5.concept  c on uppeR(substring(a.concept_name, '^\w+')) = upper(c.concept_name) 
where c.concept_class_id = 'Supplier'
and c.invalid_reason is null
and c.vocabulary_id like 'Rx%'
and a.drug_code not in (select drug_code from az)
), 
ac as (
select a.concept_name as attr_name, a.concept_class_id as attr_class, a.drug_code, c.*
from dcs_manufacturer  a
join devv5.concept  c on uppeR(substring(a.concept_name, '^\w+\s\w+')) = upper(c.concept_name) 
where c.concept_class_id = 'Supplier'
and c.invalid_reason is null
and c.vocabulary_id like 'Rx%'
and a.drug_code not in (select drug_code from az union select drug_code from ab)
)

select * from az
union
select * from ab
union
select * from ac
;


insert into dcs_manufacturer_1
with upd as(
select m.concept_name as attr_name, m.concept_class_id as attr_class, m.drug_code, c.concept_id from dcs_manufacturer m, concept c 
where drug_code not in (select drug_code from dcs_manufacturer_1)
and m.concept_name like c.concept_name||'%'
and c.vocabulary_id in ('RxNorm','RxNorm Extension')
and c.concept_class_id = 'Supplier'
and c.invalid_reason != 'D'
and length(c.concept_name) > 3
and c.concept_name not in ('PHARMA')
)


select attr_name,attr_class,drug_code, cc.*
from concept_relationship r, upd, concept cc
where r.concept_id_1 = upd.concept_id
and cc.concept_id =  r.concept_id_2
and r.invalid_reason is null
and cc.vocabulary_id in ('RxNorm','RxNorm Extension')
and cc.invalid_reason is null
;



--Parsing drug description extracting brand names 
DROP TABLE IF EXISTS brand_name;
CREATE TABLE brand_name AS
SELECT rtrim(substring(drug_descr, '^(([A-Z]+(\s)?-?/?[A-Z]+(\s)?[A-Z]?)+)'), ' ') AS brand_name,
	drug_code
FROM sources.bdpm_drug
join sources.bdpm_packaging  using(drug_code)
WHERE drug_descr NOT LIKE '%degré de dilution compris entre%'
	AND substring(drug_descr, '^(([A-Z]+(\s)?-?[A-Z]+)+)') IS NOT NULL
	and drug_code not in (select drug_code 
from non_drug
union 
select drug_code 
from bdpm_vaccine_manual
union
select drug_code 
from homeop_drug
)

;

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

-- delete Brand name that equal as Ingredient name (RxNorm)
DELETE
FROM brand_name
WHERE upper(brand_name) IN (
		SELECT upper(concept_name)
		FROM concept
		WHERE concept_class_id = 'Ingredient'
		);


-- delete Brand name that equal as Ingredient name (BDPM original)
DELETE
FROM brand_name
WHERE lower(substring(brand_name,'^\w+')) IN (
		SELECT lower(original_name)
		FROM rtc_1 
		where attr_class = 'Ingredient'
		);

--Brand name = Ingredient (BDPM translated)
DELETE
FROM brand_name
WHERE lower(substring(brand_name,'^\w+')) IN (
		SELECT lower(attr_name)
		FROM rtc_1 
		where attr_class = 'Ingredient'
		);
		

delete
FROM brand_name
WHERE lower(substring(brand_name,'^\w+\s\w+')) IN (
		SELECT lower(original_name)
		FROM rtc_1 
		where attr_class = 'Ingredient'
		);
		
delete
FROM brand_name
WHERE lower(substring(brand_name,'^\w+\s\w+')) IN (
		SELECT lower(attr_name)
		FROM rtc_1 
		where attr_class = 'Ingredient'
		);





-- manual delete
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

drop table if exists bn;
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
WHERE SUBSTRING(UPPER(brand_name),'(\w+)E ') IN (SELECT UPPER(concept_name)
                                             FROM concept
                                             WHERE concept_Class_id = 'Ingredient')
;

UPDATE brand_name
   SET brand_name = 'FERVEX'
WHERE brand_name ~* 'fervex'
;
UPDATE brand_name
   SET brand_name = 'ALYOSTAL'
WHERE brand_name ~* 'ALYOSTAL'
;
UPDATE brand_name
   SET brand_name = 'DRILL MAUX DE GORGE'
WHERE brand_name ~* 'DRILL MAUX DE GORGE'
;
UPDATE brand_name
   SET brand_name = 'MICROLAX'
WHERE brand_name ~* 'MICROLAX'
;
UPDATE brand_name
   SET brand_name = 'RHINADVIL'
WHERE brand_name ~* 'RHINADVIL'
;
UPDATE brand_name
   SET brand_name = 'ARKOGELULES'
WHERE brand_name ~* 'ARKOGELULES'
;
UPDATE brand_name
   SET brand_name = 'OLIGOSTIM'
WHERE brand_name ~* 'OLIGOSTIM'
;
UPDATE brand_name
   SET brand_name = 'ELUSANES'
WHERE brand_name ~* 'ELUSANES'
;
UPDATE brand_name
   SET brand_name = 'ANGI SPRAY'
WHERE brand_name ~* 'ANGI\-SPRAY'
;
UPDATE brand_name
   SET brand_name = 'ELEVIT'
WHERE brand_name ~* 'ELEVIT'
;

with a as 
(
select drug_code, brand_name, ingredient , position(upper(regexp_replace(ingredient, 'É' , 'E')) in upper(brand_name)) as p1 
from brand_name
join sources.bdpm_ingredient using(drug_code)
where length (ingredient) > 4
), 
b as ( 
select drug_code, brand_name, ingredient , position(upper(substring(regexp_replace(ingredient, 'É' , 'E'),'^\w+\s\w+\s\w+')) in upper(brand_name)) as p1 
from brand_name
join sources.bdpm_ingredient using(drug_code)
where length (ingredient) > 4
and drug_code not in (select drug_code from a where p1 >0)
),
c as (
select drug_code, brand_name, ingredient , position(upper(substring(regexp_replace(ingredient, 'É' , 'E'),'^\w+\s\w+')) in upper(brand_name)) as p1 
from brand_name
join sources.bdpm_ingredient using(drug_code)
where length (ingredient) > 4
and drug_code not in (select drug_code from a where p1 >0 union select drug_code from b where p1 >0 )
),
d as (
select * from (
select drug_code, brand_name, ingredient , position(upper(substring(regexp_replace(ingredient, 'É' , 'E'),'^\w+')) in upper(brand_name)) as p1 
from brand_name
join sources.bdpm_ingredient using(drug_code)
where length (ingredient) > 4
and drug_code not in 
(
select drug_code from a where p1 >0 
union 
select drug_code from b where p1 >0
union 
select drug_code from c where p1 >0
)
) ds where p1>0
)





delete  from brand_name 
where drug_code  in (
select drug_code from a where p1 >0 
union 
select drug_code from b where p1 >0
union 
select drug_code from c where p1 >0
union 
select drug_code from d where p1 >0
)
and drug_code not in 
(
select drug_code from brand_name where upper(substring(brand_name,'^\w+')) in (select upper(concept_name) from devv5.concept where concept_class_id = 'Brand Name' and vocabulary_id like 'Rx%' and invalid_reason is null)
)
;


delete from brand_name where brand_name ~* 'GOMENOL|GOMENOL SOLUBLE|GOMENOLEO|HEPATOUM';
			   


--list for drug_concept_stage
DROP TABLE IF EXISTS dcs_bn;
CREATE TABLE dcs_bn AS
SELECT DISTINCT brand_name AS concept_name,
	'Brand Name'::VARCHAR AS concept_class_id
FROM brand_name
WHERE drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		) 
;

--list of Dose Form (translated before)
DROP TABLE IF EXISTS list;
CREATE TABLE list AS
SELECT distinct trim(initcap(attr_name)) AS concept_name,
	'Dose Form'::VARCHAR AS concept_class_id,
	NULL::VARCHAR AS concept_code
FROM rtc_1  
where upper(trim(original_name)) in 
(
select distinct upper(replace(CONCAT(trim(form),' ',trim(route)),'  ',' '))
from sources.bdpm_drug 
join sources.bdpm_packaging  using(drug_code)
where drug_code not in 
(select drug_code from non_drug
    union 
    select drug_code
    from bdpm_vaccine_manual
    union 
    SELECT drug_code
    FROM homeop_drug
)
)


UNION

--Brand Names
SELECT trim(concept_name),
	concept_class_id,
	NULL
FROM dcs_bn

UNION

--manufacturers
SELECT distinct uppeR(trim(concept_name)),
	concept_class_id,
	NULL
from dcs_manufacturer_1

union

SELECT distinct  uppeR(trim(concept_name)),
	concept_class_id,
	NULL
FROM dcs_manufacturer
where concept_name not in (select 
attr_name from dcs_manufacturer_1)
;

DELETE
FROM list
WHERE concept_name LIKE '%Enteric Oral Capsule%';
/*
INSERT INTO list
VALUES (
	'inert ingredients',
	'Ingredient',
	NULL
	);*/

DO $$ DECLARE ex INTEGER;

BEGIN
SELECT MAX(REPLACE(concept_code,'OMOP','')::INT4) +1 INTO ex
FROM devv5.concept
WHERE concept_code LIKE 'OMOP%'
AND   concept_code NOT LIKE '% %';

DROP SEQUENCE IF EXISTS new_vocab;

EXECUTE 'CREATE SEQUENCE new_vocab INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';

END $$; 
--put OMOP||numbers
UPDATE list
SET concept_code = 'OMOP' || nextval('new_vocab');

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
	'S',
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
SELECT DISTINCT initcap(concept_name),
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
INSERT INTO drug_concept_stage
(
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
SELECT DISTINCT attr_name,
       'BDPM',
       'Unit',
       NULL,
       attr_name,
       NULL,
       'Drug',
       TO_DATE('19700101','yyyymmdd'),
       TO_DATE('20991231','yyyymmdd'),
       NULL
FROM rtc_1
WHERE attr_name IN (SELECT amount_unit
                      FROM ds_stage
                      UNION
                      SELECT numerator_unit
                      FROM ds_stage
                      UNION
                      SELECT denominator_unit
                      FROM ds_stage)
and attr_class = 'Unit'
;

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
SELECT DISTINCT --initcap(trim(original_name)),
initcap(trim(first_value (attr_name) over(partition by form_code))),
	'BDPM',
	'Ingredient',
	NULL,
	form_code,
	NULL,
	'Drug',
	TO_DATE('19700101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM (select original_name,attr_name from rtc_ingred union  select original_name,attr_name from rtc_1 where attr_class = 'Ingredient') a 
join ingredient_step_2 on  trim(upper(original_name)) = trim(upper(ingredient))
where drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
    union 
    select drug_code
    from bdpm_vaccine_manual
    union 
    SELECT drug_code
    FROM homeop_drug
)
		;

--Forms mapping
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT distinct concept_code,
	'BDPM',
	to_id,
	precedence,
	NULL::float
FROM rtc_1 --manual table
JOIN drug_concept_stage d ON lower(d.concept_name) = lower(attr_name)
where attr_class = 'Dose Form' and to_id is not null
;

--units
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT distinct concept_code,
	'BDPM',
	to_id,
	precedence,
	conversion_factor
FROM rtc_1 --manual table
join drug_concept_stage ON lower( concept_name) = lower(attr_name)
where attr_class = 'Unit' and to_id is not null
;   



INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT distinct d.concept_code , 
	'BDPM',
	to_id,
	case when precedence is null then 1 else precedence end ,
	NULL::float
from  (select original_name,attr_name,to_id,precedence from rtc_ingred union  select original_name,attr_name,to_id,precedence  from rtc_1 where attr_class = 'Ingredient') a
join drug_concept_stage d ON lower( concept_name) = lower(attr_name)
where d.concept_class_id = 'Ingredient' and to_id is not null
--FROM RxE_Ing_st_0 -- RxNormExtension name equivalence
	;


--suppliers found manually
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
select c.concept_code,
c.vocabulary_id,
a.concept_id,
1,
NULL::float 
from devv5.concept a
join drug_concept_stage c  on upper(c.concept_name) = upper(a.concept_name)
where c.concept_class_id = 'Supplier'
and a.concept_class_id = 'Supplier'
and a.invalid_reason is null 
and a.vocabulary_id like 'Rx%'
;

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT distinct concept_code ,
	'BDPM',
	to_id,
	precedence,
	NULL::float
from rtc_1
join drug_concept_stage ON lower( concept_name) = lower(attr_name)
where concept_class_id = 'Supplier' and to_id is not null
and concept_code   not in ( select concept_code_1 from relationship_to_concept)
;  

--Brands from RxE

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT distinct concept_code ,
	'BDPM',
	to_id,
	precedence,
	NULL::float
from rtc_1
join drug_concept_stage ON lower( concept_name) = lower(attr_name)
where concept_class_id = 'Brand Name' and to_id is not null;-- RxNormExtension name equivalence

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT distinct dc.concept_code ,
	'BDPM',
	c.concept_id,
	1 as precedence,
	NULL::float
from /*rtc_1*/ concept c 
join drug_concept_stage dc ON lower(dc.concept_name) = lower(c.concept_name)
where c.concept_class_id = dc.concept_class_id and c.concept_class_id = 'Brand Name' --and to_id is not null
and dc.concept_code   not in ( select concept_code_1 from relationship_to_concept)
and c.vocabulary_id like 'Rx%'
and c.invalid_reason is null  
;-- RxNormExtension name equivalence



/*
drop table if exists relationship_concept_to_map;
create table relationship_concept_to_map_1 as 
SELECT coalesce(ingredient,unit) as original_name, coalesce (a.concept_name,ingredient,unit) as attr_name, a.concept_class_id as attr_class, null::integer as concept_id_2, null::integer as precedenece, null::float  as conversion_factor, null::varchar as  indicator_rxe 
FROM drug_concept_stage a
  LEFT JOIN relationship_to_concept c ON c.concept_code_1 = a.concept_code
  LEFT JOIN (SELECT amount_unit AS unit
             FROM ds_stage
             UNION
             SELECT numerator_unit
             FROM ds_stage
             UNION
             SELECT denominator_unit
             FROM ds_stage) d ON d.unit = a.concept_code
  LEFT JOIN (SELECT DISTINCT form_code,
                    ingredient
             FROM sources.bdpm_ingredient
             WHERE drug_code NOT IN (SELECT drug_code
                                     FROM bdpm_vaccine_manual
                                     UNION
                                     SELECT drug_code
                                     FROM non_drug
                                     UNION
                                     SELECT drug_code
                                     FROM homeop_drug)
             --AND   UPPER(ingredient) NOT IN (SELECT UPPER(original_name) FROM rtc_1)
             ) e ON a.concept_code = e.form_code
WHERE a.concept_class_id IN ('Ingredient','Brand Name','Supplier','Dose Form','Unit')
and c.concept_code_1 is null
;
*/


 

---manual work
/*drop table if exists pack_amount_manual;
create table pack_amount_manual as 
--insert into pack_amount_manual
select concept_code,pack_component_code,packaging,pack_amount_value,drug_form
from pack_cont_1
--where concept_code not in (select concept_code from pack_amount_manual)
order by concept_code, pack_component_code
;
*/

*************************
 
 
update pack_cont_1 a 
set pack_amount_value = c.pack_amount_value
from pack_amount_manual c 
where a.concept_code = c.concept_code 
and a.packaging = c.packaging 
and a.drug_form = c.drug_form
;
UPDATE pack_cont_1
   SET pack_amount_value = '2'
WHERE concept_code = '3016965'
AND   pack_name = 'APREPITANT ZENTIVA 125 mg, gélule et APREPITANT ZENTIVA 80 mg, gélule'
AND   drug_form = 'gélule blanche'
AND   pack_component_name = 'APREPITANT ZENTIVA 125 mg, gélule et APREPITANT ZENTIVA 80 mg, gélule gélule blanche'
AND   packaging = 'plaquette(s) polyamide aluminium PVC de 1 gélule de 125 mg et de 2 gélule(s) blanches'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '3016965'
AND   pack_name = 'APREPITANT ZENTIVA 125 mg, gélule et APREPITANT ZENTIVA 80 mg, gélule'
AND   drug_form = 'gélule blanche et rose'
AND   pack_component_name = 'APREPITANT ZENTIVA 125 mg, gélule et APREPITANT ZENTIVA 80 mg, gélule gélule blanche et rose'
AND   packaging = 'plaquette(s) polyamide aluminium PVC de 1 gélule de 125 mg et de 2 gélule(s) blanches'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '14'
WHERE concept_code = '3584622'
AND   pack_name = 'NAEMIS, comprimé'
AND   drug_form = 'comprimé blanc'
AND   pack_component_name = 'NAEMIS, comprimé comprimé blanc'
AND   packaging = '1 plaquette(s) PVC polyéthylène aluminium-ACLAR de 24 comprimés (10 comprimés roses et 14 comprimés blancs)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '10'
WHERE concept_code = '3584622'
AND   pack_name = 'NAEMIS, comprimé'
AND   drug_form = 'comprimé rose'
AND   pack_component_name = 'NAEMIS, comprimé comprimé rose'
AND   packaging = '1 plaquette(s) PVC polyéthylène aluminium-ACLAR de 24 comprimés (10 comprimés roses et 14 comprimés blancs)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;


UPDATE pack_cont_1
   SET pack_amount_value = '5'
WHERE concept_code = '3008105'
AND   pack_name = 'TRINORDIOL, comprimé enrobé'
AND   drug_form = 'comprimé blanc'
AND   pack_component_name = 'TRINORDIOL, comprimé enrobé comprimé blanc'
AND   packaging = '1 plaquette(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '6'
WHERE concept_code = '3008105'
AND   pack_name = 'TRINORDIOL, comprimé enrobé'
AND   drug_form = 'comprimé brique'
AND   pack_component_name = 'TRINORDIOL, comprimé enrobé comprimé brique'
AND   packaging = '1 plaquette(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '10'
WHERE concept_code = '3008105'
AND   pack_name = 'TRINORDIOL, comprimé enrobé'
AND   drug_form = 'comprimé jaune'
AND   pack_component_name = 'TRINORDIOL, comprimé enrobé comprimé jaune'
AND   packaging = '1 plaquette(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '6'
WHERE concept_code = '3008106'
AND   pack_name = 'TRINORDIOL, comprimé enrobé'
AND   drug_form = 'comprimé blanc'
AND   pack_component_name = 'TRINORDIOL, comprimé enrobé comprimé blanc'
AND   packaging = '3 plaquette(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '5'
WHERE concept_code = '3008106'
AND   pack_name = 'TRINORDIOL, comprimé enrobé'
AND   drug_form = 'comprimé brique'
AND   pack_component_name = 'TRINORDIOL, comprimé enrobé comprimé brique'
AND   packaging = '3 plaquette(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '10'
WHERE concept_code = '3008106'
AND   pack_name = 'TRINORDIOL, comprimé enrobé'
AND   drug_form = 'comprimé jaune'
AND   pack_component_name = 'TRINORDIOL, comprimé enrobé comprimé jaune'
AND   packaging = '3 plaquette(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '7'
WHERE concept_code = '3184064'
AND   pack_name = 'ADEPAL, comprimé enrobé'
AND   drug_form = 'comprimé blanc'
AND   pack_component_name = 'ADEPAL, comprimé enrobé comprimé blanc'
AND   packaging = '1 plaquette(s) thermoformée(s) PVC aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '14'
WHERE concept_code = '3184064'
AND   pack_name = 'ADEPAL, comprimé enrobé'
AND   drug_form = 'comprimé rose orangé'
AND   pack_component_name = 'ADEPAL, comprimé enrobé comprimé rose orangé'
AND   packaging = '1 plaquette(s) thermoformée(s) PVC aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '7'
WHERE concept_code = '3184087'
AND   pack_name = 'ADEPAL, comprimé enrobé'
AND   drug_form = 'comprimé blanc'
AND   pack_component_name = 'ADEPAL, comprimé enrobé comprimé blanc'
AND   packaging = '3 plaquette(s) thermoformée(s) PVC aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '14'
WHERE concept_code = '3184087'
AND   pack_name = 'ADEPAL, comprimé enrobé'
AND   drug_form = 'comprimé rose orangé'
AND   pack_component_name = 'ADEPAL, comprimé enrobé comprimé rose orangé'
AND   packaging = '3 plaquette(s) thermoformée(s) PVC aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '6'
WHERE concept_code = '3280709'
AND   pack_name = 'TRINORDIOL, comprimé enrobé'
AND   drug_form = 'comprimé blanc'
AND   pack_component_name = 'TRINORDIOL, comprimé enrobé comprimé blanc'
AND   packaging = '1 plaquette(s) PVC-Aluminium suremballée(s)/surpochée(s) de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '5'
WHERE concept_code = '3280709'
AND   pack_name = 'TRINORDIOL, comprimé enrobé'
AND   drug_form = 'comprimé brique'
AND   pack_component_name = 'TRINORDIOL, comprimé enrobé comprimé brique'
AND   packaging = '1 plaquette(s) PVC-Aluminium suremballée(s)/surpochée(s) de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '10'
WHERE concept_code = '3280709'
AND   pack_name = 'TRINORDIOL, comprimé enrobé'
AND   drug_form = 'comprimé jaune'
AND   pack_component_name = 'TRINORDIOL, comprimé enrobé comprimé jaune'
AND   packaging = '1 plaquette(s) PVC-Aluminium suremballée(s)/surpochée(s) de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '6'
WHERE concept_code = '3280715'
AND   pack_name = 'TRINORDIOL, comprimé enrobé'
AND   drug_form = 'comprimé blanc'
AND   pack_component_name = 'TRINORDIOL, comprimé enrobé comprimé blanc'
AND   packaging = '3 plaquette(s) PVC-Aluminium suremballée(s)/surpochée(s) de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '5'
WHERE concept_code = '3280715'
AND   pack_name = 'TRINORDIOL, comprimé enrobé'
AND   drug_form = 'comprimé brique'
AND   pack_component_name = 'TRINORDIOL, comprimé enrobé comprimé brique'
AND   packaging = '3 plaquette(s) PVC-Aluminium suremballée(s)/surpochée(s) de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '10'
WHERE concept_code = '3280715'
AND   pack_name = 'TRINORDIOL, comprimé enrobé'
AND   drug_form = 'comprimé jaune'
AND   pack_component_name = 'TRINORDIOL, comprimé enrobé comprimé jaune'
AND   packaging = '3 plaquette(s) PVC-Aluminium suremballée(s)/surpochée(s) de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '5'
WHERE concept_code = '3588413'
AND   pack_name = 'DAILY, comprimé enrobé'
AND   drug_form = 'comprimé blanc'
AND   pack_component_name = 'DAILY, comprimé enrobé comprimé blanc'
AND   packaging = '1 plaquette thermoformée (aluminium/PVC/PVDC) de 21 comprimés'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '10'
WHERE concept_code = '3588413'
AND   pack_name = 'DAILY, comprimé enrobé'
AND   drug_form = 'comprimé jaune'
AND   pack_component_name = 'DAILY, comprimé enrobé comprimé jaune'
AND   packaging = '1 plaquette thermoformée (aluminium/PVC/PVDC) de 21 comprimés'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '6'
WHERE concept_code = '3588413'
AND   pack_name = 'DAILY, comprimé enrobé'
AND   drug_form = 'comprimé rose'
AND   pack_component_name = 'DAILY, comprimé enrobé comprimé rose'
AND   packaging = '1 plaquette thermoformée (aluminium/PVC/PVDC) de 21 comprimés'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '5'
WHERE concept_code = '3588436'
AND   pack_name = 'DAILY, comprimé enrobé'
AND   drug_form = 'comprimé blanc'
AND   pack_component_name = 'DAILY, comprimé enrobé comprimé blanc'
AND   packaging = '3 plaquettes thermoformées (aluminium/PVC/PVDC) de 21 comprimés'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '10'
WHERE concept_code = '3588436'
AND   pack_name = 'DAILY, comprimé enrobé'
AND   drug_form = 'comprimé jaune'
AND   pack_component_name = 'DAILY, comprimé enrobé comprimé jaune'
AND   packaging = '3 plaquettes thermoformées (aluminium/PVC/PVDC) de 21 comprimés'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '6'
WHERE concept_code = '3588436'
AND   pack_name = 'DAILY, comprimé enrobé'
AND   drug_form = 'comprimé rose'
AND   pack_component_name = 'DAILY, comprimé enrobé comprimé rose'
AND   packaging = '3 plaquettes thermoformées (aluminium/PVC/PVDC) de 21 comprimés'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '12'
WHERE concept_code = '3698604'
AND   pack_name = 'DOLIRHUMEPRO PARACETAMOL, PSEUDOEPHEDRINE ET DOXYLAMINE, comprimé'
AND   drug_form = 'comprimé jour'
AND   pack_component_name = 'DOLIRHUMEPRO PARACETAMOL, PSEUDOEPHEDRINE ET DOXYLAMINE, comprimé comprimé jour'
AND   packaging = 'plaquette(s) thermoformée(s) PVC-Aluminium de 16 comprimés'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '4'
WHERE concept_code = '3698604'
AND   pack_name = 'DOLIRHUMEPRO PARACETAMOL, PSEUDOEPHEDRINE ET DOXYLAMINE, comprimé'
AND   drug_form = 'comprimé nuit'
AND   pack_component_name = 'DOLIRHUMEPRO PARACETAMOL, PSEUDOEPHEDRINE ET DOXYLAMINE, comprimé comprimé nuit'
AND   packaging = 'plaquette(s) thermoformée(s) PVC-Aluminium de 16 comprimés'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '5'
WHERE concept_code = '3899975'
AND   pack_name = 'EVANECIA, comprimé enrobé'
AND   drug_form = 'comprimé blanc'
AND   pack_component_name = 'EVANECIA, comprimé enrobé comprimé blanc'
AND   packaging = '1 plaquette(s) thermoformée(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '10'
WHERE concept_code = '3899975'
AND   pack_name = 'EVANECIA, comprimé enrobé'
AND   drug_form = 'comprimé jaune'
AND   pack_component_name = 'EVANECIA, comprimé enrobé comprimé jaune'
AND   packaging = '1 plaquette(s) thermoformée(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '6'
WHERE concept_code = '3899975'
AND   pack_name = 'EVANECIA, comprimé enrobé'
AND   drug_form = 'comprimé rouge brique'
AND   pack_component_name = 'EVANECIA, comprimé enrobé comprimé rouge brique'
AND   packaging = '1 plaquette(s) thermoformée(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '5'
WHERE concept_code = '3899981'
AND   pack_name = 'EVANECIA, comprimé enrobé'
AND   drug_form = 'comprimé blanc'
AND   pack_component_name = 'EVANECIA, comprimé enrobé comprimé blanc'
AND   packaging = '3 plaquette(s) thermoformée(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '10'
WHERE concept_code = '3899981'
AND   pack_name = 'EVANECIA, comprimé enrobé'
AND   drug_form = 'comprimé jaune'
AND   pack_component_name = 'EVANECIA, comprimé enrobé comprimé jaune'
AND   packaging = '3 plaquette(s) thermoformée(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '6'
WHERE concept_code = '3899981'
AND   pack_name = 'EVANECIA, comprimé enrobé'
AND   drug_form = 'comprimé rouge brique'
AND   pack_component_name = 'EVANECIA, comprimé enrobé comprimé rouge brique'
AND   packaging = '3 plaquette(s) thermoformée(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '7'
WHERE concept_code = '3918106'
AND   pack_name = 'PACILIA, comprimé enrobé'
AND   drug_form = 'comprimé blanc'
AND   pack_component_name = 'PACILIA, comprimé enrobé comprimé blanc'
AND   packaging = '1 plaquette(s) thermoformée(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '14'
WHERE concept_code = '3918106'
AND   pack_name = 'PACILIA, comprimé enrobé'
AND   drug_form = 'comprimé rose'
AND   pack_component_name = 'PACILIA, comprimé enrobé comprimé rose'
AND   packaging = '1 plaquette(s) thermoformée(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '7'
WHERE concept_code = '3918112'
AND   pack_name = 'PACILIA, comprimé enrobé'
AND   drug_form = 'comprimé blanc'
AND   pack_component_name = 'PACILIA, comprimé enrobé comprimé blanc'
AND   packaging = '3 plaquette(s) thermoformée(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '14'
WHERE concept_code = '3918112'
AND   pack_name = 'PACILIA, comprimé enrobé'
AND   drug_form = 'comprimé rose'
AND   pack_component_name = 'PACILIA, comprimé enrobé comprimé rose'
AND   packaging = '3 plaquette(s) thermoformée(s) PVC-Aluminium de 21 comprimé(s)'
AND   pack_amount_value IS NULL
AND   denominator_value IS NULL
AND   denominator_unit IS NULL;
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5500089'
AND   pack_name = 'TISSEEL, solutions pour colle'
AND   drug_form = 'composant 1'
AND   pack_component_name = 'TISSEEL, solutions pour colle composant 1'
AND   packaging = 'système à double seringues (polypropylène) 1 * 2 ml (1 ml + 1 ml) avec piston, clippées dans un double porte-seringue et munies de capuchons, avec un set de dispositifs d''application constitué de 2 pièces de raccordement et de 4 canules d''application'
AND   pack_amount_value IS NULL
AND   denominator_value = 1.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5500089'
AND   pack_name = 'TISSEEL, solutions pour colle'
AND   drug_form = 'composant 2'
AND   pack_component_name = 'TISSEEL, solutions pour colle composant 2'
AND   packaging = 'système à double seringues (polypropylène) 1 * 2 ml (1 ml + 1 ml) avec piston, clippées dans un double porte-seringue et munies de capuchons, avec un set de dispositifs d''application constitué de 2 pièces de raccordement et de 4 canules d''application'
AND   pack_amount_value IS NULL
AND   denominator_value = 1.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5500091'
AND   pack_name = 'TISSEEL, solutions pour colle'
AND   drug_form = 'composant 1'
AND   pack_component_name = 'TISSEEL, solutions pour colle composant 1'
AND   packaging = 'système à double seringues (polypropylène) 1 * 4 ml (2 ml + 2 ml) avec piston, clippées dans un double porte-seringue et munies de capuchons, avec un set de dispositifs d''application constitué de 2 pièces de raccordement et de 4 canules d''application'
AND   pack_amount_value IS NULL
AND   denominator_value = 2.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5500091'
AND   pack_name = 'TISSEEL, solutions pour colle'
AND   drug_form = 'composant 2'
AND   pack_component_name = 'TISSEEL, solutions pour colle composant 2'
AND   packaging = 'système à double seringues (polypropylène) 1 * 4 ml (2 ml + 2 ml) avec piston, clippées dans un double porte-seringue et munies de capuchons, avec un set de dispositifs d''application constitué de 2 pièces de raccordement et de 4 canules d''application'
AND   pack_amount_value IS NULL
AND   denominator_value = 2.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5500092'
AND   pack_name = 'TISSEEL, solutions pour colle'
AND   drug_form = 'composant 1'
AND   pack_component_name = 'TISSEEL, solutions pour colle composant 1'
AND   packaging = 'système à double seringues (polypropylène) 1 * 10 ml (5 ml + 5 ml) avec piston, clippées dans un double porte-seringue et munies de capuchons, avec un set de dispositifs d''application constitué de 2 pièces de raccordement et de 4 canules d''application'
AND   pack_amount_value IS NULL
AND   denominator_value = 5.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5500092'
AND   pack_name = 'TISSEEL, solutions pour colle'
AND   drug_form = 'composant 2'
AND   pack_component_name = 'TISSEEL, solutions pour colle composant 2'
AND   packaging = 'système à double seringues (polypropylène) 1 * 10 ml (5 ml + 5 ml) avec piston, clippées dans un double porte-seringue et munies de capuchons, avec un set de dispositifs d''application constitué de 2 pièces de raccordement et de 4 canules d''application'
AND   pack_amount_value IS NULL
AND   denominator_value = 5.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5503190'
AND   pack_name = 'TISSEEL, solutions pour colle'
AND   drug_form = 'composant 1'
AND   pack_component_name = 'TISSEEL, solutions pour colle composant 1'
AND   packaging = '1 seringue (polypropylène) à double compartiment de 1 * 2 ml (1 ml + 1 ml) fermée par un capuchons avec un dispositif constitué de 2 pièces de raccordement et de 4 canules'
AND   pack_amount_value IS NULL
AND   denominator_value = 2.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5503190'
AND   pack_name = 'TISSEEL, solutions pour colle'
AND   drug_form = 'composant 2'
AND   pack_component_name = 'TISSEEL, solutions pour colle composant 2'
AND   packaging = '1 seringue (polypropylène) à double compartiment de 1 * 2 ml (1 ml + 1 ml) fermée par un capuchons avec un dispositif constitué de 2 pièces de raccordement et de 4 canules'
AND   pack_amount_value IS NULL
AND   denominator_value = 2.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5503191'
AND   pack_name = 'TISSEEL, solutions pour colle'
AND   drug_form = 'composant 1'
AND   pack_component_name = 'TISSEEL, solutions pour colle composant 1'
AND   packaging = '1 seringue (polypropylène) à double compartiment de 1 * 4 ml (2 ml + 2 ml) fermée par un capuchons avec un dispositif constitué de 2 pièces de raccordement et de 4 canules'
AND   pack_amount_value IS NULL
AND   denominator_value = 4.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5503191'
AND   pack_name = 'TISSEEL, solutions pour colle'
AND   drug_form = 'composant 2'
AND   pack_component_name = 'TISSEEL, solutions pour colle composant 2'
AND   packaging = '1 seringue (polypropylène) à double compartiment de 1 * 4 ml (2 ml + 2 ml) fermée par un capuchons avec un dispositif constitué de 2 pièces de raccordement et de 4 canules'
AND   pack_amount_value IS NULL
AND   denominator_value = 4.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5503192'
AND   pack_name = 'TISSEEL, solutions pour colle'
AND   drug_form = 'composant 1'
AND   pack_component_name = 'TISSEEL, solutions pour colle composant 1'
AND   packaging = '1 seringue (polypropylène) à double compartiment de 1 * 10 ml (5 ml + 5 ml) fermée par un capuchons avec un dispositif constitué de 2 pièces de raccordement et de 4 canules'
AND   pack_amount_value IS NULL
AND   denominator_value = 10.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5503192'
AND   pack_name = 'TISSEEL, solutions pour colle'
AND   drug_form = 'composant 2'
AND   pack_component_name = 'TISSEEL, solutions pour colle composant 2'
AND   packaging = '1 seringue (polypropylène) à double compartiment de 1 * 10 ml (5 ml + 5 ml) fermée par un capuchons avec un dispositif constitué de 2 pièces de raccordement et de 4 canules'
AND   pack_amount_value IS NULL
AND   denominator_value = 10.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5620894'
AND   pack_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle'
AND   drug_form = 'poudre 1'
AND   pack_component_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle poudre 1'
AND   packaging = 'poudre 1 en flacon (verre) contenant un barreau magnétique (acier inoxydable) + poudre 2 en flacon (verre) + 2 ml de solution + 2 ml de solvant en flacons (verre) + nécessaire de préparation et d''application'
AND   pack_amount_value IS NULL
AND   denominator_value = 2.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5620894'
AND   pack_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle'
AND   drug_form = 'poudre 2'
AND   pack_component_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle poudre 2'
AND   packaging = 'poudre 1 en flacon (verre) contenant un barreau magnétique (acier inoxydable) + poudre 2 en flacon (verre) + 2 ml de solution + 2 ml de solvant en flacons (verre) + nécessaire de préparation et d''application'
AND   pack_amount_value IS NULL
AND   denominator_value = 2.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5620894'
AND   pack_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle'
AND   drug_form = 'solution de reconstitution de la poudre 1'
AND   pack_component_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle solution de reconstitution de la poudre 1'
AND   packaging = 'poudre 1 en flacon (verre) contenant un barreau magnétique (acier inoxydable) + poudre 2 en flacon (verre) + 2 ml de solution + 2 ml de solvant en flacons (verre) + nécessaire de préparation et d''application'
AND   pack_amount_value IS NULL
AND   denominator_value = 2.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5620902'
AND   pack_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle'
AND   drug_form = 'poudre 1'
AND   pack_component_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle poudre 1'
AND   packaging = 'poudre 1 en flacon (verre) contenant un barreau magnétique (acier inoxydable) + poudre 2 en flacon (verre) + 5 ml de solution + 5 ml de solvant en flacons (verre) + nécessaire de préparation et d''application'
AND   pack_amount_value IS NULL
AND   denominator_value = 5.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5620902'
AND   pack_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle'
AND   drug_form = 'poudre 2'
AND   pack_component_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle poudre 2'
AND   packaging = 'poudre 1 en flacon (verre) contenant un barreau magnétique (acier inoxydable) + poudre 2 en flacon (verre) + 5 ml de solution + 5 ml de solvant en flacons (verre) + nécessaire de préparation et d''application'
AND   pack_amount_value IS NULL
AND   denominator_value = 5.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5620902'
AND   pack_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle'
AND   drug_form = 'solution de reconstitution de la poudre 1'
AND   pack_component_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle solution de reconstitution de la poudre 1'
AND   packaging = 'poudre 1 en flacon (verre) contenant un barreau magnétique (acier inoxydable) + poudre 2 en flacon (verre) + 5 ml de solution + 5 ml de solvant en flacons (verre) + nécessaire de préparation et d''application'
AND   pack_amount_value IS NULL
AND   denominator_value = 5.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5620925'
AND   pack_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle'
AND   drug_form = 'poudre 1'
AND   pack_component_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle poudre 1'
AND   packaging = 'poudre 1 en flacon (verre) contenant un barreau magnétique (acier inoxydable) + poudre 2 en flacon (verre) + 1 ml de solution + 1 ml de solvant en flacons (verre) + nécessaire de préparation et d''application'
AND   pack_amount_value IS NULL
AND   denominator_value = 1.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5620925'
AND   pack_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle'
AND   drug_form = 'poudre 2'
AND   pack_component_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle poudre 2'
AND   packaging = 'poudre 1 en flacon (verre) contenant un barreau magnétique (acier inoxydable) + poudre 2 en flacon (verre) + 1 ml de solution + 1 ml de solvant en flacons (verre) + nécessaire de préparation et d''application'
AND   pack_amount_value IS NULL
AND   denominator_value = 1.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5620925'
AND   pack_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle'
AND   drug_form = 'solution de reconstitution de la poudre 1'
AND   pack_component_name = 'TISSUCOL KIT, poudres, solution et solvant pour colle intralésionnelle solution de reconstitution de la poudre 1'
AND   packaging = 'poudre 1 en flacon (verre) contenant un barreau magnétique (acier inoxydable) + poudre 2 en flacon (verre) + 1 ml de solution + 1 ml de solvant en flacons (verre) + nécessaire de préparation et d''application'
AND   pack_amount_value IS NULL
AND   denominator_value = 1.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5645167'
AND   pack_name = 'WILSTART, poudres et solvants pour solution injectable'
AND   drug_form = 'poudre du composant 1'
AND   pack_component_name = 'WILSTART, poudres et solvants pour solution injectable poudre du composant 1'
AND   packaging = '1 flacon(s) en verre de 1000 UI - 1 flacon(s) en verre de 10 ml - 1 flacon(s) en verre de 500 UI - 1 flacon(s) en verre de 5 ml avec dispositif(s) de transfert'
AND   pack_amount_value IS NULL
AND   denominator_value = 1.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5645167'
AND   pack_name = 'WILSTART, poudres et solvants pour solution injectable'
AND   drug_form = 'poudre du composant 2'
AND   pack_component_name = 'WILSTART, poudres et solvants pour solution injectable poudre du composant 2'
AND   packaging = '1 flacon(s) en verre de 1000 UI - 1 flacon(s) en verre de 10 ml - 1 flacon(s) en verre de 500 UI - 1 flacon(s) en verre de 5 ml avec dispositif(s) de transfert'
AND   pack_amount_value IS NULL
AND   denominator_value = 1.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5755766'
AND   pack_name = 'ARTISS, solutions pour colle'
AND   drug_form = 'solution de protéines pour colle'
AND   pack_component_name = 'ARTISS, solutions pour colle solution de protéines pour colle'
AND   packaging = '1 seringue(s) préremplie(s) polypropylène à double compartiment (1 ml + 1 ml) avec dispositif double piston pour seringue + 2 pièces de raccordement et 4 canules dapplication'
AND   pack_amount_value IS NULL
AND   denominator_value = 1.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5755766'
AND   pack_name = 'ARTISS, solutions pour colle'
AND   drug_form = 'solution de thrombine'
AND   pack_component_name = 'ARTISS, solutions pour colle solution de thrombine'
AND   packaging = '1 seringue(s) préremplie(s) polypropylène à double compartiment (1 ml + 1 ml) avec dispositif double piston pour seringue + 2 pièces de raccordement et 4 canules dapplication'
AND   pack_amount_value IS NULL
AND   denominator_value = 1.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5755772'
AND   pack_name = 'ARTISS, solutions pour colle'
AND   drug_form = 'solution de protéines pour colle'
AND   pack_component_name = 'ARTISS, solutions pour colle solution de protéines pour colle'
AND   packaging = '1 seringue(s) préremplie(s) polypropylène à double compartiment (2 ml + 2 ml) avec dispositif double piston pour seringue + 2 pièces de raccordement et 4 canules dapplication'
AND   pack_amount_value IS NULL
AND   denominator_value = 1.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5755772'
AND   pack_name = 'ARTISS, solutions pour colle'
AND   drug_form = 'solution de thrombine'
AND   pack_component_name = 'ARTISS, solutions pour colle solution de thrombine'
AND   packaging = '1 seringue(s) préremplie(s) polypropylène à double compartiment (2 ml + 2 ml) avec dispositif double piston pour seringue + 2 pièces de raccordement et 4 canules dapplication'
AND   pack_amount_value IS NULL
AND   denominator_value = 1.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5755789'
AND   pack_name = 'ARTISS, solutions pour colle'
AND   drug_form = 'solution de protéines pour colle'
AND   pack_component_name = 'ARTISS, solutions pour colle solution de protéines pour colle'
AND   packaging = '1 seringue(s) préremplie(s) polypropylène à double compartiment (5 ml + 5 ml) avec dispositif double piston pour seringue + 2 pièces de raccordement et 4 canules dapplication'
AND   pack_amount_value IS NULL
AND   denominator_value = 1.0
AND   denominator_unit = 'ml';
UPDATE pack_cont_1
   SET pack_amount_value = '1'
WHERE concept_code = '5755789'
AND   pack_name = 'ARTISS, solutions pour colle'
AND   drug_form = 'solution de thrombine'
AND   pack_component_name = 'ARTISS, solutions pour colle solution de thrombine'
AND   packaging = '1 seringue(s) préremplie(s) polypropylène à double compartiment (5 ml + 5 ml) avec dispositif double piston pour seringue + 2 pièces de raccordement et 4 canules dapplication'
AND   pack_amount_value IS NULL
AND   denominator_value = 1.0
AND   denominator_unit = 'ml';



/*
delete from drug_concept_stage 
where concept_code in (
select pack_component_code from pack_cont_1
where concept_code in (select concept_code from pack_amount_manual where pack_amount_value is null)
)
;
delete from ds_stage
where drug_concept_code in 
(
select pack_component_code from pack_cont_1
where concept_code in (select concept_code from pack_amount_manual where pack_amount_value is null)
)
;


delete from pack_cont_1
where concept_code in (select concept_code from pack_amount_manual where pack_amount_value is null);
*/

insert into relationship_to_concept 
(
concept_code_1,
vocabulary_id_1,
concept_id_2,
precedence
)
select distinct concept_code, vocabulary_id, concept_id_2 , precedenece
from (select * from relationship_concept_to_mapped_1 union select * from relationship_concept_to_map_1) rt
join drug_concept_stage 
on upper(concept_name) = upper(attr_name) 
and concept_class_id= attr_class
where concept_id_2 is not null
;


delete from drug_concept_stage where concept_code  in (
select concept_code 
from relationship_concept_to_mapped_1
join drug_concept_stage 
on upper(concept_name) = upper(attr_name) 
and concept_class_id= attr_class
where indicator_rxe = 'd')
;

delete from drug_concept_stage where concept_code  in (
select concept_code 
from relationship_concept_to_map_1
join drug_concept_stage 
on upper(concept_name) = upper(attr_name) 
and concept_class_id= attr_class
where indicator_rxe != '+' and concept_id_2 is null)
;




DELETE
FROM drug_concept_stage
WHERE concept_code IN (SELECT concept_code
                       FROM drug_concept_stage
                         LEFT JOIN relationship_to_concept ON concept_code_1 = concept_code
                       WHERE concept_code_1 IS NULL
                       AND   concept_class_id = 'Ingredient'
                       AND   concept_name ~* 'Homeopathic Preparation');





ALTER TABLE ds_stage
-- add mapped ingredient's concept_id to aid next step in dealing with dublicates
ADD concept_id INT4;

UPDATE ds_stage
   SET concept_id = (SELECT concept_id_2
                     FROM relationship_to_concept
                     WHERE concept_code_1 = ingredient_concept_code
                     AND   precedence = 1);


--Fix ingredients that got replaced/mapped as same one (e.g. Sodium ascorbate + Ascorbic acid => Ascorbic acid)
DROP TABLE if exists ds_split;

CREATE TABLE ds_split 
AS
SELECT DISTINCT drug_concept_code,
       MIN(ingredient_concept_code) OVER (PARTITION BY drug_concept_code,concept_id)::VARCHAR AS ingredient_concept_code,
       --one at random
       SUM(amount_value) OVER (PARTITION BY drug_concept_code,concept_id) AS amount_value,
       amount_unit,
       SUM(numerator_value) OVER (PARTITION BY drug_concept_code,concept_id) AS numerator_value,
       numerator_unit,
       denominator_value,
       denominator_unit,
       NULL::INT4 AS box_size,
       concept_id
FROM ds_stage
WHERE (drug_concept_code,concept_id) IN (SELECT drug_concept_code,
                                                concept_id
                                         FROM ds_stage
                                         GROUP BY drug_concept_code,
                                                  concept_id
                                         HAVING COUNT(*) > 1);

DELETE
FROM ds_stage
WHERE (drug_concept_code,concept_id) IN (SELECT drug_concept_code, concept_id FROM ds_split);


INSERT INTO ds_stage
(
  drug_concept_code,
  ingredient_concept_code,
  box_size,
  amount_value,
  amount_unit,
  numerator_value,
  numerator_unit,
  denominator_value,
  denominator_unit,
  concept_id
)
SELECT drug_concept_code,
       ingredient_concept_code,
       box_size,
       amount_value,
       amount_unit,
       numerator_value,
       numerator_unit,
       denominator_value,
       denominator_unit,
       concept_id
FROM ds_split;

ALTER TABLE ds_stage DROP COLUMN concept_id;









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
		)		
;


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
		)

;


--Drug to Supplier 
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT din_7,
	d.concept_code
FROM dcs_manufacturer_1  b
JOIN drug_concept_stage d ON lower(b.concept_name) = lower(d.concept_name)
	AND d.concept_class_id = 'Supplier'
JOIN sources.bdpm_packaging p ON p.drug_code = b.drug_code
WHERE b.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		);
	

INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT din_7,
	d.concept_code
FROM dcs_manufacturer  b
JOIN drug_concept_stage d ON lower(b.concept_name) = lower(d.concept_name)
	AND d.concept_class_id = 'Supplier'
JOIN sources.bdpm_packaging p ON p.drug_code = b.drug_code
WHERE b.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		union 
		select drug_code 
		from dcs_manufacturer_1
		);


--Drug to Dose Form
--separately for packs and drugs 
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT din_7,
	concept_code
FROM sources.bdpm_drug d
JOIN rtc_1 ON upper(replace(CONCAT(trim(form),' ',trim(route)),'  ',' ')) = upper(trim(original_name))
JOIN drug_concept_stage ON uppeR(attr_name) = uppeR(concept_name)
	AND concept_class_id = 'Dose Form'
JOIN sources.bdpm_packaging p ON p.drug_code = d.drug_code
WHERE d.drug_code NOT IN (
		SELECT drug_code
		FROM non_drug
		)
	AND d.drug_code NOT IN (
		SELECT concept_code::VARCHAR
		FROM pack_cont_1)
		and d.drug_code not in (select drug_code from bdpm_vaccine_manual
		);

-- Drug to Dose Form for Pack components 
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT pack_component_code,
	concept_code
FROM pf_from_pack_comp_list pf
JOIN drug_concept_stage dcs ON pack_form = concept_name
where pack_component_code in (select pack_component_code from pack_cont_1)
;

update ds_stage 
set box_size = null 
where drug_concept_code in (
	SELECT drug_concept_code
	FROM ds_stage
	WHERE drug_concept_code NOT IN (
			SELECT drug_concept_code
			FROM ds_stage ds
			JOIN internal_relationship_stage i ON concept_code_1 = drug_concept_code
			JOIN drug_concept_stage ON concept_code = concept_code_2
				AND concept_class_id = 'Dose Form'
			WHERE box_size IS NOT NULL
			)
		AND box_size IS NOT NULL
);


-- remove from ds_stage drugs without dosage 
DELETE
FROM ds_stage
WHERE drug_concepT_code IN (SELECT drug_concept_code
                            FROM ds_stage
                            WHERE numerator_value IS NULL
                            AND   amount_value IS NULL);

-- remove from ds_stage drugs with volume only
DELETE
FROM ds_stage
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage
                            WHERE numerator_unit = 'ml'
                            OR    amount_unit = 'ml');



--remove suppliers where Dose form or dosage doesn't exist
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


--insert results into pack_content table
INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount,
	box_size
	)
SELECT concept_code,
	pack_component_code,
	pack_amount_value::int,
	null as box_size 
FROM pack_cont_1
 ;

-- add in concept_synonym_stage French name
INSERT INTO concept_synonym_stage (
	synonym_name,
	synonym_concept_code,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT original_name,
	concept_code,
	'BDPM',
	4180190 -- French language 
FROM rtc_1 
join drug_concept_stage on upper(attr_name) = upper(concept_name)
where original_name is not null 
;

--
update drug_concept_stage d 
set concept_name = trim(regexp_replace (c.concept_name, '\(\w+\-?\s?\w+?\)|EU$|A\/S\s\(\w+\-?\s?\w+?\)',''))
from drug_concept_stage c 
where c.concept_code= d.concept_code
and d.concept_code in (
select concept_code from drug_concept_stage
left join relationship_to_concept on concept_code = concept_code_1 
where concept_class_id = 'Supplier'
and concept_code_1 is null
);

--find code for attributes from previous iteration
DROP TABLE IF EXISTS code_replace;
CREATE TABLE code_replace AS
SELECT distinct case when c.invalid_reason is null then min(c.concept_code) over (partition by c.concept_name) else min(c.concept_code) over (partition by c.concept_name) end AS new_code,
	s0.concept_code AS old_code
FROM (
	SELECT concept_code, concept_name, vocabulary_id, concept_class_id
	FROM drug_concept_stage
	WHERE concept_code LIKE 'OMOP%'-- or concept_code like '%PACK%'
	) AS s0
join 	devv5.concept c on upper(s0.concept_name)  = upper(c.concept_name)
where c.vocabulary_id = s0.vocabulary_id
and  c.concept_class_id = s0.concept_class_id
union
 select distinct  'OMOP' || nextval('new_vocab') as new_code,
dcs.concept_code as old_code 
 from drug_concept_stage  dcs
 where  dcs.concept_code like 'PACK%'
; 


UPDATE drug_concept_stage a
SET concept_code = b.new_code
FROM code_replace b
WHERE a.concept_code = b.old_code;

UPDATE internal_relationship_stage c
   SET concept_code_2 = new_code
FROM code_replace de
WHERE c.concept_code_2 = de.old_code;

UPDATE internal_relationship_stage c
   SET concept_code_1 = new_code
FROM code_replace de
WHERE c.concept_code_1 = de.old_code;

UPDATE relationship_to_concept c
   SET concept_code_1 = new_code
FROM code_replace de
WHERE c.concept_code_1 = de.old_code;

UPDATE ds_stage c
   SET drug_concept_code = new_code
FROM code_replace de
WHERE drug_concept_code = de.old_code;

UPDATE pc_stage c
   SET drug_concept_code = new_code
FROM code_replace de
WHERE drug_concept_code = de.old_code;


UPDATE drug_concept_stage
SET concept_class_id = 'Drug Product'
WHERE concept_class_id = 'Drug Pack';

