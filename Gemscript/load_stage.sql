
--select LATEST_UPDATE from devv5.vocabulary_conversion where VOCABULARY_ID_V5 ='Gemscript'

--1 Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'Gemscript',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'Gemscript '||CURRENT_DATE,
	pVocabularyDevSchema	=> 'DEV_GEMSCRIPT'
);
END $_$;

DROP TABLE IF EXISTS rel_to_conc_old;
CREATE TABLE rel_to_conc_old AS
SELECT c.concept_id AS concept_id_1,
	'Source - RxNorm eq'::varchar AS relationship_id,
	concept_id_2
FROM (
	SELECT *
	FROM dev_dpd.relationship_to_concept
	WHERE precedence = 1
	
	UNION
	
	SELECT *
	FROM dev_aus.relationship_to_concept
	WHERE precedence = 1
	) a
JOIN concept c ON c.concept_code = a.concept_code_1
	AND c.vocabulary_id = a.vocabulary_id_1
	AND c.invalid_reason IS NULL;

--add Gemscript concept set,
--dm+d variant is better 
TRUNCATE TABLE concept_stage;
INSERT INTO concept_stage
SELECT NULL AS concept_id,
	dmd_drug_name AS concept_name,
	'Drug' AS domain_id,
	'Gemscript' AS vocabulary_id,
	'Gemscript' AS concept_class_id,
	NULL AS standard_concept,
	gemscript_drug_code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		) AS valid_start_date,
	to_date('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM gemscript_dmd_map;--table we had before, only God knows how we got this table

--take concepts from additional tables
--reference table from CPRD
INSERT INTO concept_stage
SELECT NULL AS concept_id,
	productname AS concept_name,
	'Drug' AS domain_id,
	'Gemscript' AS vocabulary_id,
	'Gemscript' AS concept_class_id,
	NULL AS standard_concept,
	gemscriptcode AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		) AS valid_start_date,
	to_date('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM gemscript_reference
WHERE gemscriptcode NOT IN (
		SELECT concept_code
		FROM concept_stage
		);

--mappings from Urvi
INSERT INTO concept_stage
SELECT NULL AS concept_id,
	BRAND AS concept_name,
	'Drug' AS domain_id,
	'Gemscript' AS vocabulary_id,
	'Gemscript' AS concept_class_id,
	NULL AS standard_concept,
	gemscript_drugcode AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		) AS valid_start_date,
	to_date('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM thin_gemsc_dmd_0717
WHERE gemscript_drugcode NOT IN (
		SELECT concept_code
		FROM concept_stage
		);

--Gemscript THIN concepts 
INSERT INTO concept_stage
SELECT NULL AS concept_id,
	GENERIC AS concept_name,
	'Drug' AS domain_id,
	'Gemscript' AS vocabulary_id,
	'Gemscript THIN' AS concept_class_id,
	NULL AS standard_concept,
	encrypted_drugcode AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		) AS valid_start_date, -- TRUNC(SYSDATE)
	to_date('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM THIN_GEMSC_DMD_0717;

--CLEAN UP --in the future put the thing into insert (need to find out what those !code mean)
DELETE
FROM concept_stage
WHERE concept_name IS NULL
	OR concept_code ~ '\D';

--build concept_relationship_stage table
TRUNCATE TABLE concept_relationship_stage;

--Gemscript to dm+d
--new table from URVI
INSERT INTO concept_relationship_stage
SELECT NULL AS concept_id_1,
	NULL AS concept_id_2,
	gemscript_drugcode AS concept_code_1,
	dmd_code AS concept_code_2,
	'Gemscript' AS vocabulary_id_1,
	'dm+d' AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		) AS valid_start_date,
	to_date('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM THIN_GEMSC_DMD_0717;

--old table from Christian
INSERT INTO concept_relationship_stage
SELECT NULL AS concept_id_1,
	NULL AS concept_id_2,
	gemscript_drug_code AS concept_code_1,
	dmd_code AS concept_code_2,
	'Gemscript' AS vocabulary_id_1,
	'dm+d' AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		) AS valid_start_date,
	to_date('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM gemscript_dmd_map
WHERE gemscript_drug_code NOT IN (
		SELECT concept_code_1
		FROM concept_relationship_stage
		);

--mappings between THIN gemscript and Gemscript
INSERT INTO concept_relationship_stage
SELECT NULL AS concept_id_1,
	NULL AS concept_id_2,
	encrypted_drugcode AS concept_code_1,
	gemscript_drugcode AS concept_code_2,
	'Gemscript' AS vocabulary_id_1,
	'Gemscript' AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		) AS valid_start_date,
	to_date('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM THIN_GEMSC_DMD_0717;

--delete mappings to non-existing dm+ds because their ruin further procedures result
--it allows to exist old mappings , they are relatively good but not very precise actually, and we know that if there was exising dm+d concept it'll go to better dm+d RxE way, and actually gives us for about 4000 relationships, 
-- so if we have time we can remap these concepts to RxE, give to medical coder to review them
--but for now let's remain them
DELETE
FROM concept_relationship_stage
WHERE vocabulary_id_2 = 'dm+d'
	AND concept_code_2 NOT IN (
		SELECT concept_code
		FROM concept
		WHERE vocabulary_id = 'dm+d'
		);

ANALYZE concept_stage;
ANALYZE concept_relationship_stage;

-- Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;
/

-- Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;
/

-- Add mapping from deprecated to fresh concepts, and also from non-standard to standard concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;
/

-- Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;
/

--deprecate relationship mappings to Non-standard concepts
--how's this possible?
UPDATE concept_relationship_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		)
WHERE (
		concept_code_1,
		concept_code_2,
		vocabulary_id_2
		) NOT IN (
		SELECT concept_code_1,
			concept_code_2,
			vocabulary_id_2
		FROM concept_relationship_stage
		JOIN concept ON concept_code = concept_code_2
			AND vocabulary_id = vocabulary_id_2
			AND standard_concept = 'S'
		);

--define drug domain (Drug set by default) based on target concept domain
UPDATE concept_stage cs
SET domain_id = (
		SELECT domain_id
		FROM (
			SELECT DISTINCT --beware of multiple mappings
				r.concept_code_1,
				r.vocabulary_id_1,
				c.domain_id
			FROM concept_relationship_stage r -- concept_code_1 = s1.concept_code and vocabulary_id_1 = vocabulary_id
			JOIN concept c ON c.concept_code = r.concept_code_2
				AND r.vocabulary_id_2 = c.vocabulary_id
				AND r.invalid_reason IS NULL -- and r.vocabulary_id_2 in ('dm+d', 'RxNorm', 'RxNorm Extension')
			JOIN (
				SELECT concept_code_1
				FROM (
					SELECT DISTINCT --beware of multiple mappings
						r.concept_code_1,
						r.vocabulary_id_1,
						c.domain_id
					FROM concept_relationship_stage r -- concept_code_1 = s1.concept_code and vocabulary_id_1 = vocabulary_id
					JOIN concept c ON c.concept_code = r.concept_code_2
						AND r.vocabulary_id_2 = c.vocabulary_id
						AND r.invalid_reason IS NULL -- and r.vocabulary_id_2 in ('dm+d', 'RxNorm', 'RxNorm Extension')
					) AS s0
				GROUP BY concept_code_1
				HAVING count(*) = 1
				) zz --exclude those mapped to several domains such as Inert ingredient is a device (wrong BTW), cartridge is a device, etc.
				ON zz.concept_code_1 = r.concept_code_1
			) rr
		WHERE rr.concept_code_1 = cs.concept_code
			AND rr.vocabulary_id_1 = cs.vocabulary_id
		);

--not covered are Drugs for now
UPDATE concept_stage
SET domain_id = 'Drug'
WHERE domain_id IS NULL;

--select distinct domain_id from concept_stage;
--create table gemscript_reference as select * from gemscript_reference;


--why in this way????
--for development purpose use temporary thin_need_to_map table:  
DROP TABLE IF EXISTS thin_need_to_map;  --18457 the old version, 13965 --new version (join concept), well, really a big difference. not sure if those existing mappings are correct, 13877 - concept_relationship_stage version, why?
CREATE TABLE thin_need_to_map AS
SELECT --c.*
	t.ENCRYPTED_DRUGCODE AS THIN_code,
	t.GENERIC::varchar(255) AS THIN_name,
	coalesce(gr.GEMSCRIPTCODE, t.GEMSCRIPT_DRUGCODE) AS GEMSCRIPT_code,
	coalesce(gr.PRODUCTNAME, t.BRAND)::varchar(255) AS GEMSCRIPT_name,
	c.domain_id
FROM THIN_GEMSC_DMD_0717 t
FULL OUTER JOIN gemscript_reference gr ON gr.GEMSCRIPTCODE = t.GEMSCRIPT_DRUGCODE
LEFT JOIN concept_relationship_stage r ON coalesce(gr.GEMSCRIPTCODE, t.GEMSCRIPT_DRUGCODE) = r.concept_code_1
	AND r.invalid_reason IS NULL --and r.vocabulary_id_2 in ('dm+d', 'RxNorm', 'RxNorm Extension') and relationship_id = 'Maps to' 
JOIN concept_stage c -- join and left join gives us different results because of   !1360102 AND   !5264101 codes, so exclude those !!-CODES
	ON coalesce(gr.GEMSCRIPTCODE, t.GEMSCRIPT_DRUGCODE) = c.concept_code
	AND c.concept_class_id = 'Gemscript'
WHERE r.concept_code_2 IS NULL;

CREATE INDEX th_th_n_ix ON thin_need_to_map (lower (thin_name));
CREATE INDEX th_ge_n_ix ON thin_need_to_map (lower (gemscript_name));

UPDATE thin_need_to_map
SET thin_name = replace(thin_name, 'polymixin b ', 'polymyxin b');

UPDATE thin_need_to_map
SET thin_name = replace(thin_name, 'ipecacuhana', 'ipecacuanha');

UPDATE thin_need_to_map
SET thin_name = replace(thin_name, 'chloesterol', 'cholesterol');

UPDATE thin_need_to_map
SET thin_name = replace(thin_name, 'capsicin', 'capsaicin');

UPDATE thin_need_to_map
SET thin_name = replace(thin_name, 'glycolsalicylate', 'glycol salicylate');

UPDATE thin_need_to_map
SET thin_name = replace(thin_name, 'azatidine', 'azacytidine');

UPDATE thin_need_to_map
SET thin_name = replace(thin_name, 'benzalkonium, chlorhexidine', 'benzalkonium / chlorhexidine');

--define domain_id
--DRUGSUBSTANCE is null and lower
--!!! OK for gemscript part
UPDATE thin_need_to_map n
SET domain_id = 'Device'
WHERE EXISTS (
		SELECT 1
		FROM gemscript_reference g
		WHERE (
				SELECT count(*)
				FROM regexp_matches(PRODUCTNAME, '[a-z]', 'g')
				) > 5 -- sometime we have these non HCl, mg as a part of UPPER case concept_name
			AND (
				DRUGSUBSTANCE IS NULL
				OR DRUGSUBSTANCE = 'Syringe For Injection'
				)
			AND g.GEMSCRIPTCODE = n.GEMSCRIPT_CODE
		);
--4758

--device by the name (taken from dmd?) part 1
--ok
UPDATE thin_need_to_map
SET domain_id = 'Device'
WHERE GEMSCRIPT_CODE IN (
		SELECT GEMSCRIPT_CODE
		FROM thin_need_to_map
		WHERE THIN_name ~* 'stoma caps|urinal systems|shampoo|sunscreen|amidotrizoate|dialysis|smoflipid|camino|maxamum|sno-pro|lubri|peptamen|pepti-junior|dressing|diagnostic|glove|supplement| rope|weight|resource|accu-chek|accutrend|procal|glytactin|gauze|keyomega|cystine|docomega|anamixcranberry|pedialyte|hydralyte|hcu cooler|pouch'
		
		UNION ALL
		
		SELECT GEMSCRIPT_CODE
		FROM thin_need_to_map
		WHERE THIN_name ~* 'burger|biscuits|stocking|strip|remover|chamber|gauze|supply|beverage|cleanser|soup|protector|nutrision|repellent|wipes|kilocalories|cake|roll|adhesive|milk|dessert|medium chain|prozero|amino acid supplement|long chain|low protein|pouches|ribbon|cannula|swabs|bandage|cylinder'
		
		UNION ALL
		
		SELECT GEMSCRIPT_CODE
		FROM thin_need_to_map
		WHERE gemscript_name ~* 'amidotrizoate|burger|biscuits|stocking|strip|remover|chamber|gauze|supply|beverage|cleanser|soup|protector|nutrision|repellent|wipes|kilocalories|cake|roll|adhesive|milk|dessert|medium chain|prozero|amino acid supplement|long chain|low protein|pouches|ribbon|cannula|swabs|bandage|cylinder'
		
		UNION ALL
		
		SELECT GEMSCRIPT_CODE
		FROM thin_need_to_map
		WHERE gemscript_name ~* 'dialysis|smoflipid|camino|maxamum|sno-pro|lubri|peptamen|pepti-junior|dressing|diagnostic|glove|supplement| rope|weight|resource|accu-chek|accutrend|procal|glytactin|gauze|keyomega|cystine|docomega|anamixcranberry|pedialyte|hydralyte|hcu cooler|pouch'
		)
	AND domain_id = 'Drug';


--device by the name (taken from dmd?) part 2
--ok
UPDATE thin_need_to_map
SET domain_id = 'Device'
--put these into script above
WHERE gemscript_code IN (
		SELECT gemscript_code
		FROM thin_need_to_map
		WHERE THIN_name ~* 'breath test|pizza|physical|diet food|sunscreen|tubing|nutrison|elasticated vest|oxygen|spaghetti|irrigation |sunscreen cream|sheaths|lancet| wash|contact lens|bag|gluten|plast|wax|catheter|device|needle|needle|emollient|feeding|colostomy| toe |rubber|flange|cotton|stockinette|urostomy|tube |ostomy|cracker|shield|larve|belt|pasta|garments|bread'
			OR gemscript_name ~* 'breath test|pizza|physical|diet food|sunscreen|tubing|nutrison|elasticated vest|oxygen|spaghetti|irrigation |sunscreen cream|sheaths|lancet| wash|contact lens|bag|gluten|plast|wax|catheter|device|needle|needle|emollient|feeding|colostomy| toe |rubber|flange|cotton|stockinette|urostomy|tube |ostomy|cracker|shield|larve|belt|pasta|garments|bread'
		)
	AND domain_id = 'Drug';

--these concepts are drugs anyway
--put this condition into concept above!!! 
--ok
UPDATE thin_need_to_map n
SET domain_id = 'Drug'
WHERE EXISTS (
		SELECT 1
		FROM gemscript_reference g
		WHERE g.GEMSCRIPTCODE = n.GEMSCRIPT_CODE
			AND n.domain_id = 'Device'
			AND lower(formulation) IN (
				'capsule',
				'chewable tablet',
				--'cream',
				'cutaneous solution',
				'ear drops',
				'ear/eye drops solution',
				'emollient',
				'emulsion',
				'emulsion for infusion',
				'enema',
				'eye drops',
				'eye ointment',
				--'gel',
				'granules',
				'homeopathic drops',
				'homeopathic pillule',
				'homeopathic tablet',
				'inhalation powder',
				'injection',
				'injection solution',
				'lotion',
				'ointment',
				'oral gel',
				'oral solution',
				'oral suspension',
				--'plasters',
				'powder',
				'sachets',
				'solution for injection',
				'suppository',
				'tablet',
				'infusion',
				'solution',
				'Suspension for injection',
				'Spansule',
				'lozenge',
				'cream',
				'Intravenous Infusion'
				)
		);

--make standard representation of multicomponent drugs
UPDATE thin_need_to_map
SET THIN_NAME = replace(THIN_NAME, '%/', '% / ')
WHERE thin_name ~ '%/'
	AND domain_id = 'Drug';

UPDATE thin_need_to_map
SET THIN_NAME = regexp_replace(thin_name, '( with )(\D)', ' / \2', 'g')
WHERE thin_name LIKE '% with %'
	AND domain_id = 'Drug';

UPDATE thin_need_to_map
SET THIN_NAME = regexp_replace(thin_name, '( with )(\d)', '+\2', 'g')
WHERE thin_name LIKE '% with %'
	AND domain_id = 'Drug';

UPDATE thin_need_to_map
SET THIN_NAME = replace(THIN_NAME, ' & ', ' / ')
WHERE thin_name LIKE '% & %'
	AND NOT thin_name ~ ' & \d'
	AND domain_id = 'Drug';

UPDATE thin_need_to_map
SET THIN_NAME = replace(THIN_NAME, ' and ', ' / ')
WHERE thin_name LIKE '% and %'
	AND NOT thin_name ~ ' and \d'
	AND domain_id = 'Drug';

UPDATE thin_need_to_map
SET gemscript_name = replace(gemscript_name, '%/', '% / ')
WHERE gemscript_name ~ '%/'
	AND domain_id = 'Drug';

UPDATE thin_need_to_map
SET gemscript_name = regexp_replace(gemscript_name, '( with )(\D)', ' / \2', 'g')
WHERE gemscript_name LIKE '% with %'
	AND domain_id = 'Drug';

UPDATE thin_need_to_map
SET THIN_NAME = regexp_replace(gemscript_name, '( with )(\d)', '+\2', 'g')
WHERE gemscript_name LIKE '% with %'
	AND domain_id = 'Drug';

UPDATE thin_need_to_map
SET gemscript_name = replace(gemscript_name, ' & ', ' / ')
WHERE gemscript_name LIKE '% & %'
	AND NOT gemscript_name ~ ' & \d'
	AND domain_id = 'Drug';

UPDATE thin_need_to_map
SET gemscript_name = replace(gemscript_name, ' and ', ' / ')
WHERE gemscript_name LIKE '% and %'
	AND NOT gemscript_name ~ ' and \d'
	AND domain_id = 'Drug';

UPDATE thin_need_to_map
SET THIN_NAME = replace(THIN_NAME, 'i.u.', 'iu')
WHERE thin_name LIKE '%i.u.%';

UPDATE thin_need_to_map
SET gemscript_name = replace(gemscript_name, 'i.u.', 'iu')
WHERE gemscript_name LIKE '%i.u.%';

--define what's a pack based on the concept_name, then manually parse this out, then add pack_component names as a codes (check the code replacing script) and add pack_components as a drug components in ds_stage creation algorithms
DROP TABLE IF EXISTS packs_out;
CREATE TABLE packs_out AS
SELECT THIN_NAME,
	GEMSCRIPT_CODE,
	GEMSCRIPT_NAME,
	NULL::VARCHAR(250) AS pack_component,
	NULL::FLOAT AS amount
FROM thin_need_to_map t
WHERE t.domain_id = 'Drug'
	AND gemscript_name NOT LIKE 'Becloforte%'
	AND (
		gemscript_name LIKE '% pack%'
		OR gemscript_code IN
		--packs defined manually
		(
			'67678021',
			'76122020',
			'80033020',
			'1637007'
			)
		OR thin_name ~ '(\d\s*x\s*\d)|(estradiol.*\+)'
		OR (
			SELECT count(*)
			FROM regexp_matches(thin_name, 'tablet| cream|capsule', 'g')
			) > 1
		);

INSERT INTO pc_stage (
	PACK_CONCEPT_CODE,
	DRUG_CONCEPT_CODE,
	AMOUNT,
	BOX_SIZE
	)
SELECT GEMSCRIPT_CODE,
	PACK_COMPONENT,
	AMOUNT,
	NULL
FROM packs_in;

INSERT INTO thin_need_to_map (
	THIN_CODE,
	THIN_NAME,
	GEMSCRIPT_CODE,
	GEMSCRIPT_NAME,
	DOMAIN_ID
	)
SELECT DISTINCT NULL,
	DRUG_CONCEPT_CODE,
	DRUG_CONCEPT_CODE,
	DRUG_CONCEPT_CODE,
	'Drug'
FROM pc_stage;

DROP TABLE IF EXISTS thin_comp;
CREATE TABLE thin_comp AS
SELECT substring(lower(a.drug_comp), '(((\d)*[.,]*\d+)(\s)*(mg|%|ml|mcg|hr|hours|unit(s?)|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit(s?)|nanogram(s)*|x|ppm|million units| Kallikrein inactivator units|kBq|microlitres|MBq|molar|micromol)(/((\d)*[.,]*\d+)*(\s*)(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop))*)') AS dosage,
	REPLACE(trim(substring(lower(thin_name), '((\s|\()[[:digit:]\.]+(\s*)(litre(s?)|ml))')), '(', '') AS volume,
	A.*
FROM (
	SELECT DISTINCT unnest(string_to_array(t.thin_name, ' / ')) AS drug_comp,
		t.*
	FROM thin_need_to_map t
	) a
WHERE a.domain_id = 'Drug'
	--exclusions
	--Bendroflumethiazide / potassium 2.5mg+7.7mmol modified release tablets 
	AND NOT thin_name ~* '[[:digit:]\,\.]+.*\+(\s*)[[:digit:]\,\.].*'
--Co-triamterzide 50mg/25mg tablets
--and not regexp_like (thin_name, '\dm(c*)g/[[:digit:]\,\.]+m(c*)g')

UNION

--Bendroflumethiazide / potassium 2.5mg+7.7mmol modified release tablets 
SELECT CONCAT (
		trim(l.dosage),
		denom
		) AS dosage,
	volume,
	trim(l.drug_comp) AS drug_comp,
	thin_code,
	thin_name,
	gemscript_code,
	gemscript_name,
	domain_id
FROM (
	SELECT substring(lower(thin_name), '(((\d)*[.,]*\d+)(\s)*(g|mg|%|mcg|iu|mmol|micrograms)(\s)*\+(\s)*[[:digit:]\,\.]+(g|mg|%|mcg|iu|mmol|micrograms|ku)((\s)*\+(\s)*((\d)*[.,]*\d+)*(\s)*(g|mg|%|mcg|iu|mmol|micrograms))*)') AS dosage_0,
		substring(lower(THIN_NAME), '(/[[:digit:]\,\.]+(ml| hr|g|mg))') AS denom,
		REPLACE(trim(substring(thin_name, '((\s|\()[[:digit:]\.]+(\s*)(litre(s?)|ml))')), '(', '') AS volume,
		t.*
	FROM thin_need_to_map t
	WHERE thin_name ~* '((\d)*[.,]*\d+)(\s)*(g|mg|%|mcg|iu|mmol|micrograms)(\s)*\+(\s)*[[:digit:]\,\.]+(g|mg|%|mcg|iu|mmol|micrograms|ku)((\s)*\+(\s)*((\d)*[.,]*\d+)*(\s)*(g|mg|%|mcg|iu|mmol|micrograms))*'
		AND domain_id = 'Drug'
	) t,
	LATERAL(SELECT * FROM unnest(string_to_array(t.thin_name, ' / '), string_to_array(dosage_0, '+')) AS a(drug_comp, dosage)) l;

--/ampoule is treated as denominator then
UPDATE thin_comp
SET dosage = replace(dosage, '/ampoule', '')
WHERE dosage LIKE '%/ampoule';

--',c is treated as dosage
UPDATE thin_comp
SET dosage = NULL
WHERE dosage LIKE '\,%';

--select * from thin_comp;

CREATE INDEX drug_comp_ix ON thin_comp USING GIN (drug_comp devv5.gin_trgm_ops);
CREATE INDEX drug_comp_ix2 ON thin_comp (lower (drug_comp));
ANALYZE thin_comp;

--how to define Ingredient, change scripts to COMPONENTS and use only (  lower (a.thin_name) like lower (b.concept_name)||' %' tomorrow!!!
--take the longest ingredient, if this works, rough dm+d is better, becuase it has Sodium bla-bla-nate and RxNorm has just bla-bla-nate 
--don't need to have two parts here
--Execution time: 57.41s
--Execution time: 1m 41s when more vocabularies added 

DROP TABLE IF EXISTS i_map;
CREATE TABLE i_map AS -- enhanced algorithm added  lower (a.thin_name) like lower '% '||(b.concept_name)||' %'
SELECT *
FROM (
	SELECT DISTINCT i.dosage,
		i.thin_name,
		i.thin_code,
		i.drug_comp,
		i.gemscript_code,
		i.gemscript_name,
		i.volume,
		i.concept_id,
		i.concept_name,
		i.vocabulary_id,
		RANK() OVER (
			PARTITION BY i.drug_comp ORDER BY LENGTH(i.concept_name) DESC,
				i.vocabulary_id DESC,
				i.concept_id
			) AS rank1
	FROM (
		SELECT DISTINCT a.*,
			rx.concept_id,
			rx.concept_name,
			rx.vocabulary_id
		FROM thin_comp a
		JOIN concept_synonym s ON (
				a.drug_comp ILIKE s.concept_synonym_name || ' %'
				OR LOWER(a.drug_comp) = LOWER(s.concept_synonym_name)
				)
		JOIN concept_relationship r ON s.concept_id = r.concept_id_1
			AND r.invalid_reason IS NULL
		JOIN concept rx ON r.concept_id_2 = rx.concept_id
			AND rx.vocabulary_id LIKE 'Rx%'
			AND rx.concept_class_id = 'Ingredient'
			AND rx.invalid_reason IS NULL
		) i
	) AS s0
--take the longest ingredient
WHERE rank1 = 1;

--map Ingredients derived from different vocabularies to RxNorm(E)
DROP TABLE IF EXISTS rel_to_ing_1;
CREATE TABLE rel_to_ing_1 AS
SELECT DISTINCT i.dosage,
	i.drug_comp,
	i.thin_code,
	i.thin_name,
	i.gemscript_code,
	i.gemscript_name,
	i.volume,
	concept_id AS target_id,
	concept_name AS target_name,
	vocabulary_id AS target_vocab
FROM i_map i;

--the same but with gemscript_name
--make standard representation of multicomponent drugs
--select count(*) from thin_comp2 ; select * from thin_comp where thin_code = '97245997'; select * from rel_to_ing_1 where thin_code is null;

DROP TABLE IF EXISTS thin_comp2; 
CREATE TABLE thin_comp2 AS

SELECT substring(lower(a.drug_comp), '(((\d)*[.,]*\d+)(\s)*(mg|%|ml|mcg|hr|hours|unit(s?)|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit(s?)|nanogram(s)*|x|ppm|million units| Kallikrein inactivator units|kBq|microlitres|MBq|molar|micromol)(/((\d)*[.,]*\d+)*(\s*)(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop))*)') AS dosage,
	replace(trim(substring(lower(gemscript_name), '((\s|\()[[:digit:]\.]+(\s*)(litre(s?)|ml))')), '(', '') AS volume,
	A.*
FROM (
	SELECT DISTINCT trim(unnest(string_to_array(t.gemscript_name, ' / '))) AS drug_comp,
		t.*
	FROM thin_need_to_map t
	) a
WHERE a.domain_id = 'Drug'
	--exclusions
	--Bendroflumethiazide / potassium 2.5mg+7.7mmol modified release tablets 
	AND NOT gemscript_name ~* '[[:digit:]\,\.]+.*\+(\s*)[[:digit:]\,\.].*'
	AND gemscript_code NOT IN (
		SELECT gemscript_code
		FROM rel_to_ing_1
		)
--Co-triamterzide 50mg/25mg tablets
--and not regexp_like (gemscript_name, '\dm(c*)g/[[:digit:]\,\.]+m(c*)g')

UNION

--Bendroflumethiazide / potassium 2.5mg+7.7mmol modified release tablets 
SELECT CONCAT (
		trim(l.dosage),
		denom
		) AS dosage,
	volume,
	trim(l.drug_comp) AS drug_comp,
	thin_code,
	gemscript_name,
	gemscript_code,
	gemscript_name,
	domain_id
FROM (
	SELECT substring(lower(gemscript_name), '(((\d)*[.,]*\d+)(\s)*(mg|%|mcg|iu|mmol|micrograms)(\s)*\+(\s)*[[:digit:]\,\.]+(mg|%|mcg|iu|mmol|micrograms)((\s)*\+(\s)*((\d)*[.,]*\d+)*(\s)*(mg|%|mcg|iu|mmol|micrograms))*)') AS dosage_0,
		substring(lower(gemscript_name), '(/[[:digit:]\,\.]+(ml| hr|g|mg))') AS denom,
		replace(trim(substring(lower(gemscript_name), '((\s|\()[[:digit:]\.]+(\s*)(litre(s?)|ml))')), '(', '') AS volume,
		t.*
	FROM thin_need_to_map t
	WHERE gemscript_name ~* '((\d)*[.,]*\d+)(\s)*(mg|%|mcg|iu|mmol|micrograms)(\s)*\+(\s)*[[:digit:]\,\.]+(mg|%|mcg|iu|mmol|micrograms)((\s)*\+(\s)*((\d)*[.,]*\d+)*(\s)*(mg|%|mcg|iu|mmol|micrograms))*'
		AND domain_id = 'Drug'
		AND gemscript_code NOT IN (
			SELECT gemscript_code
			FROM rel_to_ing_1
			)
	) t,
	LATERAL(SELECT * FROM unnest(string_to_array(t.gemscript_name, ' / '), string_to_array(dosage_0, '+')) AS a(drug_comp, dosage)) l;

--/ampoule is treated as denominator then
UPDATE thin_comp2
SET dosage = replace(dosage, '/ampoule', '')
WHERE dosage LIKE '%/ampoule';

--',c is treated as dosage
UPDATE thin_comp2
SET dosage = NULL
WHERE dosage LIKE '\,%';

CREATE INDEX drug_comp_ix_2 ON thin_comp2 USING GIN (drug_comp devv5.gin_trgm_ops);
CREATE INDEX drug_comp_ix2_2 ON thin_comp2 (lower (drug_comp));
ANALYZE thin_comp2;

DROP TABLE IF EXISTS i_map_2;
CREATE TABLE i_map_2 AS -- enhanced algorithm added  lower (a.thin_name) like lower '% '||(b.concept_name)||' %'
SELECT *
FROM (
	SELECT DISTINCT i.dosage,
		i.thin_name,
		i.thin_code,
		i.drug_comp,
		i.gemscript_code,
		i.gemscript_name,
		i.volume,
		i.concept_id,
		i.concept_name,
		i.vocabulary_id,
		RANK() OVER (
			PARTITION BY i.drug_comp ORDER BY LENGTH(i.concept_name) DESC,
				i.vocabulary_id DESC,
				i.concept_id
			) AS rank1
	FROM (
		SELECT DISTINCT a.*,
			rx.concept_id,
			rx.concept_name,
			rx.vocabulary_id
		FROM thin_comp2 a
		JOIN concept_synonym s ON (
				a.drug_comp ILIKE s.concept_synonym_name || ' %'
				OR LOWER(a.drug_comp) = LOWER(s.concept_synonym_name)
				)
		JOIN concept_relationship r ON s.concept_id = r.concept_id_1
			AND r.invalid_reason IS NULL
		JOIN concept rx ON r.concept_id_2 = rx.concept_id
			AND rx.vocabulary_id LIKE 'Rx%'
			AND rx.concept_class_id = 'Ingredient'
			AND rx.invalid_reason IS NULL
		) i
	) AS s0
--take the longest ingredient
WHERE rank1 = 1;

--map Ingredients derived from different vocabularies to RxNorm(E)
DROP TABLE IF EXISTS rel_to_ing_2;
CREATE TABLE rel_to_ing_2 AS
SELECT DISTINCT i.dosage,
	i.drug_comp,
	i.thin_code,
	i.thin_name,
	i.gemscript_code,
	i.gemscript_name,
	i.volume,
	concept_id AS target_id,
	concept_name AS target_name,
	vocabulary_id AS target_vocab
FROM i_map_2 i;

--make temp tables as it was in dmd drug procedure
DROP TABLE IF EXISTS ds_all_tmp;
CREATE TABLE ds_all_tmp AS
SELECT dosage,
	drug_comp,
	thin_name AS concept_name,
	gemscript_code AS concept_code,
	target_name AS INGREDIENT_CONCEPT_CODE,
	target_name AS ingredient_concept_name,
	trim(volume) AS volume,
	TARGET_ID AS ingredient_id
FROM rel_to_ing_1

UNION

SELECT dosage,
	drug_comp,
	thin_name AS concept_name,
	gemscript_code AS concept_code,
	target_name AS INGREDIENT_CONCEPT_CODE,
	target_name AS ingredient_concept_name,
	trim(volume) AS volume,
	TARGET_ID AS ingredient_id
FROM rel_to_ing_2;

--!!! manual table
 
--drop table full_manual;
/*
create table full_manual 
(
DOSAGE varchar (50),	VOLUME  varchar (50),	THIN_NAME	 varchar (550), GEMSCRIPT_NAME  varchar (550),	ingredient_id	 int, THIN_CODE  varchar (50),	gemscript_code  varchar (50),	INGREDIENT_CONCEPT_CODE  varchar (250),	DOMAIN_ID  varchar (50)
)
;
WbImport -file=C:/work/gemscript_manual/full_manual.txt
         -type=text
         -table=FULL_MANUAL
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -decimal=.
         -fileColumns=DOSAGE,VOLUME,THIN_NAME,GEMSCRIPT_NAME,INGREDIENT_ID,THIN_CODE,GEMSCRIPT_CODE,INGREDIENT_CONCEPT_CODE,DOMAIN_ID
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=1000;
;
Update full_manual set ingredient_concept_code=regexp_replace(ingredient_concept_code, '"')
;
MERGE INTO full_manual fm
     USING (SELECT distinct  first_value (c.concept_id) over (PARTITION BY c.concept_name order by c.concept_id ) as concept_id, lower (c.concept_name) as concept_name
              FROM concept a join concept_relationship cr
              on a.concept_id = cr.concept_id_1 
              JOIN CONCEPT C on c.concept_id = cr.concept_id_2 and relationship_id in ('Maps to', 'Source - RxNorm eq', 'Concept replaced by' ) 

 where  c.vocabulary_id like 'RxNorm%' and c.concept_class_id = 'Ingredient' and c.invalid_reason is null) i
        ON ( replace (lower(fm.ingredient_concept_code), '"') = lower (i.concept_name))
WHEN MATCHED
THEN
   UPDATE SET fm.INGREDIENT_ID = i.concept_id;
COMMIT;

MERGE INTO full_manual fm
     USING (SELECT distinct   c.concept_name  , c.concept_id 
              FROM concept c where  c.vocabulary_id like 'RxNorm%' and c.concept_class_id = 'Ingredient' and c.invalid_reason is null) i
        ON (fm.INGREDIENT_ID = i.concept_id)
WHEN MATCHED
THEN
   UPDATE SET fm.ingredient_concept_code = i.concept_name;
COMMIT;

 -- update full_manual set ingredient_concept_code = initcap (ingredient_concept_code)
--  ;
--  update full_manual set dosage = lower (dosage)
 -- ;
  commit
 ;
drop table full_manual;
create table full_manual as select * from full_manual;--?????
*/

DELETE
FROM ds_all_tmp
WHERE concept_code IN (
		SELECT gemscript_code
		FROM full_manual
		WHERE ingredient_concept_code IS NOT NULL
		);

INSERT INTO ds_all_tmp (
	DOSAGE,
	DRUG_COMP,
	CONCEPT_NAME,
	CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	INGREDIENT_CONCEPT_NAME,
	VOLUME,
	ingredient_id
	)
SELECT DISTINCT DOSAGE,
	NULL,
	coalesce(thin_name, gemscript_name),
	gemscript_CODE,
	INGREDIENT_CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	volume,
	INGREDIENT_ID
FROM full_manual
WHERE ingredient_concept_code IS NOT NULL;

--domain_id definition
UPDATE thin_need_to_map t
SET domain_id = (
		SELECT DISTINCT domain_id
		FROM full_manual m
		WHERE t.gemscript_code = m.gemscript_code
		)
WHERE EXISTS (
		SELECT 1
		FROM full_manual m
		WHERE t.gemscript_code = m.gemscript_code
			AND domain_id IS NOT NULL
		);

--packs after manual table in case if in manual table there will be packs
DELETE
FROM ds_all_tmp
WHERE concept_code IN (
		SELECT pack_concept_code
		FROM pc_stage
		);

--then merge it with ds_all_tmp, for now temporary decision - make dosages NULL to avoid bug
--remove ' ' inside the dosage to make the same as it was before in dmd
UPDATE ds_all_tmp
SET dosage = replace(dosage, ' ', '');

--clean up
UPDATE ds_all_tmp
SET dosage = replace(dosage, '/', '')
WHERE dosage LIKE '%/';

--dosage distribution along the ds_stage
DROP TABLE IF EXISTS ds_all;
CREATE TABLE ds_all AS

SELECT DISTINCT CASE 
		WHEN substring(lower(dosage), '([[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units|unit dose|drop))') = lower(dosage)
			AND NOT dosage ~ '%'
			THEN replace(substring(dosage, '[[:digit:]\,\.]+'), ',', '')
		ELSE NULL
		END AS amount_value,
	CASE 
		WHEN substring(lower(dosage), '([[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units|unit dose|drop))') = lower(dosage)
			AND NOT dosage ~ '%'
			THEN regexp_replace(lower(dosage), '[[:digit:]\,\.]+', '', 'g')
		ELSE NULL
		END AS amount_unit,
	CASE 
		WHEN (
				substring(lower(dosage), '([[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop))') = lower(dosage)
				AND substring(volume, '[[:digit:]\,\.]+') IS NULL
				OR dosage ~ '%'
				)
			THEN replace(substring(dosage, '^[[:digit:]\,\.]+'), ',', '')
		WHEN substring(lower(dosage), '([[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop))') = lower(dosage)
			AND substring(volume, '[[:digit:]\,\.]+') IS NOT NULL
			THEN (substring(volume, '[[:digit:]\,\.]+')::FLOAT * replace(substring(dosage, '^[[:digit:]\,\.]+'), ',', '')::FLOAT / coalesce(replace(substring(dosage, '/([[:digit:]\,\.]+)'), ',', '')::FLOAT, 1))::VARCHAR
		ELSE NULL
		END AS numerator_value,
	CASE 
		WHEN substring(lower(dosage), '([[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop))') = lower(dosage)
			OR dosage ~ '%'
			THEN substring(lower(dosage), '(mg|%|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|microlitres)')
		ELSE NULL
		END AS numerator_unit,
	CASE 
		WHEN (
				substring(dosage, '([[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)|h|square cm|microlitres|unit dose|drop))') = dosage
				OR dosage ~ '%'
				)
			AND volume IS NULL
			THEN replace(substring(dosage, '/([[:digit:]\,\.]+)'), ',', '')
		WHEN volume IS NOT NULL
			THEN substring(volume, '[[:digit:]\,\.]+')
		ELSE NULL
		END AS denominator_value,
	CASE 
		WHEN (
				substring(dosage, '([[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|microlitres|hour(s)*|h|square cm|unit dose|drop))') = dosage
				OR dosage ~ '%'
				)
			AND volume IS NULL
			THEN substring(dosage, '(g|dose|ml|mg|ampoule|litre|hour(s)*|h*|square cm|microlitres|unit dose|drop)$')
		WHEN volume IS NOT NULL
			THEN regexp_replace(volume, '[[:digit:]\,\.]+', '', 'g')
		ELSE NULL
		END AS denominator_unit,
	concept_code,
	concept_name,
	dosage,
	drug_comp,
	ingredient_concept_code,
	ingredient_concept_name
FROM ds_all_tmp;

--!!!check the previous script for dmd -patterns should be similar here
--add missing denominator if for the other combination it exist
UPDATE ds_all a
SET (
		DENOMINATOR_VALUE,
		DENOMINATOR_unit
		) = (
		SELECT DISTINCT b.DENOMINATOR_VALUE,
			b.DENOMINATOR_unit
		FROM ds_all b
		WHERE a.CONCEPT_CODE = b.CONCEPT_CODE
			AND a.DENOMINATOR_unit IS NULL
			AND b.DENOMINATOR_unit IS NOT NULL
		)
-- a.numerator_value= a.amount_value,a.numerator_unit= a.amount_unit,a.amount_value = null, a.amount_unit = null
WHERE EXISTS (
		SELECT 1
		FROM ds_all b
		WHERE a.CONCEPT_CODE = b.CONCEPT_CODE
			AND a.DENOMINATOR_unit IS NULL
			AND b.DENOMINATOR_unit IS NOT NULL
		);

--somehow we get amount +denominator
UPDATE ds_all a
SET numerator_value = a.amount_value,
	numerator_unit = a.amount_unit,
	amount_value = NULL,
	amount_unit = NULL
WHERE a.denominator_unit IS NOT NULL
	AND numerator_unit IS NULL;

UPDATE ds_all
SET amount_VALUE = NULL
WHERE amount_VALUE = '.';


TRUNCATE TABLE ds_stage;
INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
	)
SELECT DISTINCT
	--add distinct here because of Paracetamol / pseudoephedrine / paracetamol / diphenhydramine tablet
	CONCEPT_CODE,
	INGREDIENT_CONCEPT_CODE,
	AMOUNT_VALUE::FLOAT,
	AMOUNT_UNIT,
	NUMERATOR_VALUE::FLOAT,
	NUMERATOR_UNIT,
	DENOMINATOR_VALUE::FLOAT,
	DENOMINATOR_UNIT
FROM ds_all;


-- update denominator with existing value for concepts having empty and non-emty denominator value/unit
 --fix wierd units
UPDATE ds_stage
SET amount_unit = 'unit'
WHERE amount_unit IN (
		'u',
		'iu'
		);

UPDATE ds_stage
SET NUMERATOR_UNIT = 'unit'
WHERE NUMERATOR_UNIT IN (
		'u',
		'iu'
		);

UPDATE ds_stage
SET DENOMINATOR_UNIT = NULL
WHERE DENOMINATOR_UNIT = 'ampoule';

UPDATE ds_stage
SET DENOMINATOR_UNIT = replace(DENOMINATOR_UNIT, ' ', '')
WHERE DENOMINATOR_UNIT LIKE '% %';

DELETE
FROM ds_stage
WHERE ingredient_concept_code = 'Syrup';

DELETE
FROM ds_stage
WHERE 0 IN (
		numerator_value,
		amount_value,
		denominator_value
		);

--sum up the Zinc undecenoate 20% / Undecenoic acid 5% cream
DELETE
FROM ds_stage
WHERE DRUG_CONCEPT_CODE = '1637007'
	AND INGREDIENT_CONCEPT_CODE = 'OMOP1021956'
	AND NUMERATOR_VALUE = 50;

UPDATE ds_stage
SET NUMERATOR_VALUE = 250
WHERE DRUG_CONCEPT_CODE = '1637007'
	AND INGREDIENT_CONCEPT_CODE = 'OMOP1021956'
	AND NUMERATOR_VALUE = 200;

--percents
--update ds_stage changing % to mg/ml, mg/g, etc.
--simple, when we have denominator_unit so we can define numerator based on denominator_unit
UPDATE ds_stage
SET numerator_value = DENOMINATOR_VALUE * NUMERATOR_VALUE * 10,
	numerator_unit = 'mg'
WHERE numerator_unit = '%'
	AND DENOMINATOR_UNIT IN (
		'ml',
		'gram',
		'g'
		);

UPDATE ds_stage
SET numerator_value = DENOMINATOR_VALUE * NUMERATOR_VALUE * 0.01,
	numerator_unit = 'mg'
WHERE numerator_unit = '%'
	AND DENOMINATOR_UNIT IN ('mg');

UPDATE ds_stage
SET numerator_value = DENOMINATOR_VALUE * NUMERATOR_VALUE * 10,
	numerator_unit = 'g'
WHERE numerator_unit = '%'
	AND DENOMINATOR_UNIT IN ('litre');

--let's make only %-> mg/ml if denominator is null
UPDATE ds_stage ds
SET numerator_value = NUMERATOR_VALUE * 10,
	numerator_unit = 'mg',
	denominator_unit = 'ml'
WHERE numerator_unit = '%'
	AND denominator_unit IS NULL
	AND denominator_value IS NULL;

DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT pack_concept_code
		FROM pc_stage
		);

--check for non ds_stage cover
select * from thin_need_to_map where gemscript_code not in (select drug_concept_code from ds_stage where drug_concept_code is not null)
 and gemscript_code not in (select gemscript_code from full_manual where gemscript_code is not null) and domain_id = 'Drug' 
and gemscript_code not in (select pack_concept_code from pc_stage where pack_concept_code is not null )
;
--apply the dose form updates then to extract them from the original names
--make a proper dose form from the short terms used in a concept_names

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'oin$', 'ointment', 'gi')
WHERE thin_name LIKE '%oin';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'tab$', 'tablet', 'gi')
WHERE thin_name LIKE '%tab';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'inj$', 'injection', 'gi')
WHERE thin_name LIKE '%inj';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'cre$', 'cream', 'gi')
WHERE thin_name LIKE '%cre';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'lin$', 'linctus', 'gi')
WHERE thin_name LIKE '%lin';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'sol$', 'solution', 'gi')
WHERE thin_name LIKE '%sol';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'cap$', 'capsule', 'gi')
WHERE thin_name LIKE '%cap';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'loz$', 'lozenge', 'gi')
WHERE thin_name LIKE '%loz';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'lozenge$', 'lozenges', 'gi')
WHERE thin_name LIKE '%lozenge';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'sus$', 'suspension', 'gi')
WHERE thin_name LIKE '%sus';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'eli$', 'elixir', 'gi')
WHERE thin_name LIKE '%eli';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'sup$', 'suppositories', 'gi')
WHERE thin_name LIKE '%sup';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'gra$', 'granules', 'gi')
WHERE thin_name LIKE '%gra';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'pow$', 'powder', 'gi')
WHERE thin_name LIKE '%pow';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'pel$', 'pellets', 'gi')
WHERE thin_name LIKE '%pel';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'lot$', 'lotion', 'gi')
WHERE thin_name LIKE '%lot';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'pre-filled syr$', 'pre-filled syringe', 'gi')
WHERE thin_name LIKE '%pre-filled syr';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'syr$', 'syrup', 'gi')
WHERE thin_name LIKE '%syr';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'app$', 'applicator', 'gi')
WHERE thin_name LIKE '%app';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'dro$', 'drops', 'gi')
WHERE thin_name LIKE '%dro';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'aer$', 'aerosol', 'gi')
WHERE thin_name LIKE '%aer';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'liq$', 'liquid', 'gi')
WHERE thin_name LIKE '%liq';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'homeopathic pillules$', 'pillules', 'gi')
WHERE thin_name LIKE '%homeopathic pillules';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'spa$', 'spansules', 'gi')
WHERE thin_name LIKE '%spa';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'emu$', 'emulsion', 'gi')
WHERE thin_name LIKE '%emu';

--paste
UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'pas$', 'paste', 'gi')
WHERE thin_name LIKE '%pas';

--pillules
UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'pills$', 'pillules', 'gi')
WHERE thin_name LIKE '%pills';

--spray
UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'spr$', 'spray', 'gi')
WHERE thin_name LIKE '%spr';

--inhalation
UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'inh$', 'inhalation', 'gi')
WHERE thin_name LIKE '%inh';

--suppositories
UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'suppository$', 'suppositories', 'gi')
WHERE thin_name LIKE '%suppository';

--oitnment
UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'oitnment$', 'ointment', 'gi')
WHERE thin_name LIKE '%oitnment';

--pessary
UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'pes$', 'pessary', 'gi')
WHERE thin_name LIKE '%pes';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'pessary$', 'pessaries', 'gi')
WHERE thin_name LIKE '%pessary';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'spansules$', 'capsule', 'gi')
WHERE thin_name LIKE '%spansules';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'globuli$', 'granules', 'gi')
WHERE thin_name LIKE '%globuli';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'sach$', 'sachet', 'gi')
WHERE thin_name LIKE '%sach';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'oin$', 'ointment', 'gi')
WHERE thin_name LIKE '%oin';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'tab$', 'tablet', 'gi')
WHERE thin_name LIKE '%tab';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'inj$', 'injection', 'gi')
WHERE thin_name LIKE '%inj';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'cre$', 'cream', 'gi')
WHERE thin_name LIKE '%cre';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'lin$', 'linctus', 'gi')
WHERE thin_name LIKE '%lin';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'sol$', 'solution', 'gi')
WHERE thin_name LIKE '%sol';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'cap$', 'capsule', 'gi')
WHERE thin_name LIKE '%cap';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'loz$', 'lozenge', 'gi')
WHERE thin_name LIKE '%loz';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'lozenge$', 'lozenges', 'gi')
WHERE thin_name LIKE '%lozenge';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'sus$', 'suspension', 'gi')
WHERE thin_name LIKE '%sus';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'eli$', 'elixir', 'gi')
WHERE thin_name LIKE '%eli';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'sup$', 'suppositories', 'gi')
WHERE thin_name LIKE '%sup';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'gra$', 'granules', 'gi')
WHERE thin_name LIKE '%gra';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'pow$', 'powder', 'gi')
WHERE thin_name LIKE '%pow';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'pel$', 'pellets', 'gi')
WHERE thin_name LIKE '%pel';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'lot$', 'lotion', 'gi')
WHERE thin_name LIKE '%lot';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'pre-filled syr$', 'pre-filled syringe', 'gi')
WHERE thin_name LIKE '%pre-filled syr';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'syr$', 'syrup', 'gi')
WHERE thin_name LIKE '%syr';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'app$', 'applicator', 'gi')
WHERE thin_name LIKE '%app';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'dro$', 'drops', 'gi')
WHERE thin_name LIKE '%dro';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'aer$', 'aerosol', 'gi')
WHERE thin_name LIKE '%aer';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'liq$', 'liquid', 'gi')
WHERE thin_name LIKE '%liq';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'homeopathic pillules$', 'pillules', 'gi')
WHERE thin_name LIKE '%homeopathic pillules';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'spa$', 'spansules', 'gi')
WHERE thin_name LIKE '%spa';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'emu$', 'emulsion', 'gi')
WHERE thin_name LIKE '%emu';

--paste
UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'pas$', 'paste', 'gi')
WHERE thin_name LIKE '%pas';

--pillules
UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'pills$', 'pillules', 'gi')
WHERE thin_name LIKE '%pills';

--spray
UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'spr$', 'spray', 'gi')
WHERE thin_name LIKE '%spr';

--inhalation
UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'inh$', 'inhalation', 'gi')
WHERE thin_name LIKE '%inh';

--suppositories
UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'suppository$', 'suppositories', 'gi')
WHERE thin_name LIKE '%suppository';

--oitnment
UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'oitnment$', 'ointment', 'gi')
WHERE thin_name LIKE '%oitnment';

--pessary
UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'pes$', 'pessary', 'gi')
WHERE thin_name LIKE '%pes';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'pessary$', 'pessaries', 'gi')
WHERE thin_name LIKE '%pessary';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'spansules$', 'capsule', 'gi')
WHERE thin_name LIKE '%spansules';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'globuli$', 'granules', 'gi')
WHERE thin_name LIKE '%globuli';

UPDATE thin_need_to_map
SET thin_name = regexp_replace(thin_name, 'sach$', 'sachet', 'gi')
WHERE thin_name LIKE '%sach';

--Execution time: 3m 28s when "mm" is used

/*
drop table f_map_var;
create table f_map_var as ( -- enhanced algorithm added  lower (a.thin_name) like lower '% '||(b.concept_name)||' %'
select * from 
(
select distinct a.*, b.concept_id, b.concept_name,  b.vocabulary_id, b.concept_code , RANK() OVER (PARTITION BY a.gemscript_code ORDER BY  length(b.concept_name) desc, 


case when b.vocabulary_id = 'dm+d' then 1
when b.vocabulary_id = 'GRR' then 2
when b.vocabulary_id = 'AMT' then 3
when  b.vocabulary_id = 'DPD' then 4
when b.vocabulary_id = 'BDPM' then 5
when b.vocabulary_id = 'LPD_Australia' then 6
when b.vocabulary_id = 'AMIS' then 7
else 10 end

 asc) as rank1
 
from  thin_need_to_map a 
 join  concept b
on (
regexp_like (
 lower (coalesce (a.thin_name, a.GEMSCRIPT_NAME)),
 lower  (' '||b.concept_name||'( |$|s|es)')
 ) 
or regexp_like (
 lower (coalesce (a.thin_name, a.GEMSCRIPT_NAME)), lower  (' '||regexp_replace  (b.concept_name, 'y$', 'ies') ||'( |$)')
 ) 
)
and vocabulary_id in( 'dm+d', 'AMT', 'BDPM', 'AMIS', 'DPD', 'LPD_Australia', 'GRR', 'RxNorm', 'RxNorm Extension') and concept_class_id in ( 'Dose Form', 'Form', 'AU Qualifier')   and invalid_reason is null
 
where a.domain_id ='Drug'
)
--take the longest ingredient
where rank1 = 1 
)
;
--mappings 
drop table forms_mapping;
--use old relationship_to_concept tables to define form mappings with precedence
create table forms_mapping as
select distinct f.concept_name as concept_code_1, map.concept_id_2, precedence, x.concept_name as concept_name_2   from f_map_var f
join concept c on c.concept_id = f.concept_id
left join 
(
select concept_code_1, concept_id_2, precedence, 'AMIS' as vocabulary_id_1 from dev_amis.relationship_to_concept 
union
select concept_code_1, concept_id_2, precedence, 'DPD' from dev_dpd.relationship_to_concept 
union
select concept_code_1, concept_id_2, precedence, 'dm+d' from dev_dmd.relationship_to_concept 
union
select concept_code_1, concept_id_2, precedence, 'AMT' from dev_amt.relationship_to_concept 
union
select concept_code_1, concept_id_2, precedence, 'GRR' from dev_grr.relationship_to_concept
union
select concept_code_1, concept_id_2, precedence, 'LPD_Australia' from dev_aus.relationship_to_concept 
union
select concept_code_1, concept_id_2, precedence, 'BDPM' from dev_bdpm.relationship_to_concept 
) map on c.concept_code = map.concept_code_1 and c.vocabulary_id = vocabulary_id_1
left join concept x on x.concept_id = map.concept_id_2
--where x.concept_id is null
;
--update mappings with precedence using forms equivalents that have multiple mappings
insert into forms_mapping
select old_name, concept_id_2, precedence, concept_name_2 from forms_mapping join (
select 'Prefilled Syringe' as old_name , 'Pen' as new_name  from dual
union
select 'Dry Powder Inhaler', 'Inhalation powder' from dual
union 
select  'Inhalant', 'Inhalation Solution' from dual
union
select  'Powder Spray', 'Inhalation powder' from dual
) aa 
on aa.new_name  = forms_mapping.concept_code_1
;

delete from forms_mapping where concept_code_1 in (select old_name from (
select 'Prefilled Syringe' as old_name , 'Pen' as new_name  from dual
union
select 'Dry Powder Inhaler', 'Inhalation powder' from dual
union 
select  'Inhalant', 'Inhalation Solution' from dual
union
select  'Powder Spray', 'Inhalation powder' from dual
) aa ) and concept_id_2 is null
;
commit
;
select * from forms_mapping where concept_code_1 =
'Gel'
;
--fix inacurracies
UPDATE FORMS_MAPPING
   SET PRECEDENCE = 4  WHERE CONCEPT_CODE_1 = 'Gel'
AND   concept_id_2 = 19010880;
INSERT INTO FORMS_MAPPING
(
  CONCEPT_CODE_1,  concept_id_2,  PRECEDENCE,  CONCEPT_NAME_2
)
VALUES
(
  'Gel',  19095973,  1,  'Topical Gel');
--algorithm for forms make ambiguities when there are two forms with the same length in within one vocabulary
DELETE
FROM F_MAP_VAR
WHERE GEMSCRIPT_CODE = '104007'
AND   concept_id = 21215788;
DELETE
FROM F_MAP_VAR
WHERE GEMSCRIPT_CODE = '54128020'
AND   concept_id = 43360666;
DELETE
FROM F_MAP_VAR
WHERE GEMSCRIPT_CODE = '58583020'
AND   concept_id = 43360666;
DELETE
FROM F_MAP_VAR
WHERE GEMSCRIPT_CODE = '61770020'
AND   concept_id = 21308470;
DELETE
FROM F_MAP_VAR
WHERE GEMSCRIPT_CODE = '76284020'
AND   concept_id = 21308470;

commit
;
*/
--make Suppliers, some clean up
UPDATE thin_need_to_map
SET GEMSCRIPT_NAME = GEMSCRIPT_NAME || ')'
WHERE GEMSCRIPT_NAME LIKE '%(Neon Diagnostics';

DROP TABLE IF EXISTS s_rel;
CREATE TABLE s_rel AS
SELECT substring(GEMSCRIPT_NAME, '\(([A-Z].+)\)$') AS Supplier,
	n.*
FROM thin_need_to_map n
WHERE domain_id = 'Drug';

DROP TABLE IF EXISTS s_map;
CREATE TABLE s_map AS
SELECT DISTINCT s.gemscript_code,
	s.GEMSCRIPT_NAME,
	sss.concept_id_2,
	concept_name_2,
	vocabulary_id_2
FROM s_rel s
JOIN concept c ON lower(s.Supplier) = lower(c.concept_name)
JOIN (
	SELECT c.concept_id AS source_id,
		coalesce(d.concept_name, c.concept_name) AS concept_name_2,
		coalesce(d.concept_id, c.concept_id) AS concept_id_2,
		coalesce(d.vocabulary_id, c.vocabulary_id) AS vocabulary_id_2
	FROM concept c
	LEFT JOIN (
		SELECT concept_id_1,
			relationship_id,
			concept_id_2
		FROM concept_relationship
		WHERE invalid_reason IS NULL
		
		UNION
		
		SELECT concept_id_1,
			relationship_id,
			concept_id_2
		FROM rel_to_conc_old
		) r ON c.concept_id = r.concept_id_1
		AND relationship_id = 'Source - RxNorm eq'
	LEFT JOIN concept d ON d.concept_id = r.concept_id_2
		AND d.vocabulary_id LIKE 'RxNorm%'
		AND d.invalid_reason IS NULL
		AND d.concept_class_id = 'Supplier'
	WHERE c.concept_class_id IN ('Supplier')
		AND c.invalid_reason IS NULL
	) sss ON sss.source_id = c.concept_id
	AND sss.vocabulary_id_2 IN (
		'RxNorm',
		'RxNorm Extension'
		) --not clear, need to fix in the future
WHERE c.concept_class_id = 'Supplier';

--make Brand Names
--select * from thin_need_to_map where thin_name like 'Generic%';
CREATE INDEX gemscript_name_idx ON thin_need_to_map USING GIN (gemscript_name devv5.gin_trgm_ops);
CREATE INDEX thin_name_idx ON thin_need_to_map USING GIN (thin_name devv5.gin_trgm_ops);
ANALYZE thin_need_to_map;

DROP TABLE IF EXISTS b_map_0;
CREATE TABLE b_map_0 AS
SELECT T.GEMSCRIPT_CODE,
	T.GEMSCRIPT_NAME,
	T.THIN_CODE,
	T.THIN_NAME,
	C.concept_id,
	C.CONCEPT_NAME,
	C.vocabulary_id
FROM thin_need_to_map T
JOIN concept c ON gemscript_name ilike c.concept_name || ' %'
WHERE c.concept_class_id = 'Brand Name'
	AND invalid_reason IS NULL
	AND vocabulary_id IN (
		'RxNorm',
		'RxNorm Extension'
		)
	--exclude ingredients that accindentally got into Brand Names massive
	AND lower(c.concept_name) NOT IN (
		SELECT lower(concept_name)
		FROM concept
		WHERE concept_class_id = 'Ingredient'
			AND invalid_reason IS NULL
		)
	AND t.domain_id = 'Drug'
	AND C.CONCEPT_NAME NOT IN (
		'Gamma',
		'Mst',
		'Gx',
		'Simple',
		'Saline',
		'DF',
		'Stibium'
		);

DROP TABLE IF EXISTS b_map_1;
CREATE TABLE b_map_1 AS
SELECT T.GEMSCRIPT_CODE,
	T.GEMSCRIPT_NAME,
	T.THIN_CODE,
	T.THIN_NAME,
	C.concept_id,
	C.CONCEPT_NAME,
	C.vocabulary_id
FROM thin_need_to_map T
JOIN concept c ON thin_name ilike c.concept_name || ' %'
LEFT JOIN b_map_0 b ON b.gemscript_code = t.gemscript_code
WHERE c.concept_class_id = 'Brand Name'
	AND c.invalid_reason IS NULL
	AND c.vocabulary_id IN (
		'RxNorm',
		'RxNorm Extension'
		)
	--exclude ingredients that accindally got into Brand Names massive
	AND lower(c.concept_name) NOT IN (
		SELECT lower(concept_name)
		FROM concept
		WHERE concept_class_id = 'Ingredient'
			AND invalid_reason IS NULL
		)
	AND t.domain_id = 'Drug'
	AND b.gemscript_code IS NULL
	AND C.CONCEPT_NAME NOT IN (
		'Natrum muriaticum',
		'Pulsatilla nigricans',
		'Multivitamin',
		'Saline',
		'Simple'
		);

DROP INDEX gemscript_name_idx;
DROP INDEX thin_name_idx;

DROP TABLE IF EXISTS b_map;
CREATE TABLE b_map AS
SELECT *
FROM (
	SELECT z.*,
		RANK() OVER (
			PARTITION BY gemscript_code ORDER BY length(concept_name) DESC
			) AS rank1
	FROM (
		SELECT *
		FROM b_map_0
		
		UNION
		
		SELECT *
		FROM b_map_1
		) z
	WHERE z.vocabulary_id IN (
			'RxNorm',
			'RxNorm Extension'
			) --not clear, need to fix in the future
	) x
WHERE x.rank1 = 1;

--making input tables
--drug_concept_stage
TRUNCATE TABLE drug_concept_stage;

--Drug Product
INSERT INTO drug_concept_stage (
	CONCEPT_NAME,
	DOMAIN_ID,
	VOCABULARY_ID,
	CONCEPT_CLASS_ID,
	STANDARD_CONCEPT,
	CONCEPT_CODE,
	VALID_START_DATE,
	VALID_END_DATE,
	INVALID_REASON,
	SOURCE_CONCEPT_CLASS_ID
	)
SELECT DISTINCT gemscript_name,
	domain_id,
	'Gemscript',
	'Drug Product',
	NULL,
	gemscript_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		) AS valid_start_date, -- TRUNC(SYSDATE)
	to_date('20991231', 'yyyymmdd') AS valid_end_date,
	NULL,
	'Gemscript'
FROM thin_need_to_map
WHERE domain_id = 'Drug';

--Device
INSERT INTO drug_concept_stage (
	CONCEPT_NAME,
	DOMAIN_ID,
	VOCABULARY_ID,
	CONCEPT_CLASS_ID,
	STANDARD_CONCEPT,
	CONCEPT_CODE,
	VALID_START_DATE,
	VALID_END_DATE,
	INVALID_REASON,
	SOURCE_CONCEPT_CLASS_ID
	)
SELECT DISTINCT gemscript_name,
	domain_id,
	'Gemscript',
	'Device',
	'S',
	gemscript_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		) AS valid_start_date, -- TRUNC(SYSDATE)
	to_date('20991231', 'yyyymmdd') AS valid_end_date,
	NULL,
	'Gemscript'
FROM thin_need_to_map
WHERE domain_id = 'Device';

--Ingredient
INSERT INTO drug_concept_stage (
	CONCEPT_NAME,
	DOMAIN_ID,
	VOCABULARY_ID,
	CONCEPT_CLASS_ID,
	STANDARD_CONCEPT,
	CONCEPT_CODE,
	VALID_START_DATE,
	VALID_END_DATE,
	INVALID_REASON,
	SOURCE_CONCEPT_CLASS_ID
	)
SELECT DISTINCT Ingredient_concept_code,
	'Drug',
	'Gemscript',
	'Ingredient',
	NULL,
	Ingredient_concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		) AS valid_start_date, -- TRUNC(SYSDATE)
	to_date('20991231', 'yyyymmdd') AS valid_end_date,
	NULL,
	'Gemscript'
FROM ds_all_tmp;
	--only 1041 --looks susprecious

--Supplier
INSERT INTO drug_concept_stage (
	CONCEPT_NAME,
	DOMAIN_ID,
	VOCABULARY_ID,
	CONCEPT_CLASS_ID,
	STANDARD_CONCEPT,
	CONCEPT_CODE,
	VALID_START_DATE,
	VALID_END_DATE,
	INVALID_REASON,
	SOURCE_CONCEPT_CLASS_ID
	)
SELECT DISTINCT CONCEPT_NAME_2,
	'Drug',
	'Gemscript',
	'Supplier',
	NULL,
	CONCEPT_NAME_2,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		) AS valid_start_date, -- TRUNC(SYSDATE)
	to_date('20991231', 'yyyymmdd') AS valid_end_date,
	NULL,
	'Gemscript'
FROM s_map;

--Dose Form
INSERT INTO drug_concept_stage (
	CONCEPT_NAME,
	DOMAIN_ID,
	VOCABULARY_ID,
	CONCEPT_CLASS_ID,
	STANDARD_CONCEPT,
	CONCEPT_CODE,
	VALID_START_DATE,
	VALID_END_DATE,
	INVALID_REASON,
	SOURCE_CONCEPT_CLASS_ID
	)
SELECT DISTINCT CONCEPT_CODE_1,
	'Drug',
	'Gemscript',
	'Dose Form',
	NULL,
	CONCEPT_CODE_1,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		) AS valid_start_date, -- TRUNC(SYSDATE)
	to_date('20991231', 'yyyymmdd') AS valid_end_date,
	NULL,
	'Gemscript'
FROM forms_mapping;

--Brand Name
INSERT INTO drug_concept_stage (
	CONCEPT_NAME,
	DOMAIN_ID,
	VOCABULARY_ID,
	CONCEPT_CLASS_ID,
	STANDARD_CONCEPT,
	CONCEPT_CODE,
	VALID_START_DATE,
	VALID_END_DATE,
	INVALID_REASON,
	SOURCE_CONCEPT_CLASS_ID
	)
SELECT DISTINCT CONCEPT_NAME,
	'Drug',
	'Gemscript',
	'Brand Name',
	NULL,
	CONCEPT_NAME,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		) AS valid_start_date, -- TRUNC(SYSDATE)
	to_date('20991231', 'yyyymmdd') AS valid_end_date,
	NULL,
	'Gemscript'
FROM b_map;

INSERT INTO drug_concept_stage (
	CONCEPT_NAME,
	DOMAIN_ID,
	VOCABULARY_ID,
	CONCEPT_CLASS_ID,
	STANDARD_CONCEPT,
	CONCEPT_CODE,
	VALID_START_DATE,
	VALID_END_DATE,
	INVALID_REASON,
	SOURCE_CONCEPT_CLASS_ID
	)
SELECT DISTINCT CONCEPT_NAME,
	'Drug',
	'Gemscript',
	'Unit',
	NULL,
	CONCEPT_NAME,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		) AS valid_start_date, -- TRUNC(SYSDATE)
	to_date('20991231', 'yyyymmdd') AS valid_end_date,
	NULL,
	'Gemscript'
FROM dev_dmd.DRUG_CONCEPT_STAGE_042017
WHERE concept_class_id = 'Unit'
	AND concept_code != 'ml ';

--internal_relationship_stage
INSERT INTO internal_relationship_stage
SELECT GEMSCRIPT_CODE,
	CONCEPT_NAME
FROM b_map

UNION

SELECT GEMSCRIPT_CODE,
	CONCEPT_NAME
FROM f_map_var

UNION

SELECT GEMSCRIPT_CODE,
	CONCEPT_NAME_2
FROM s_map

UNION

SELECT DISTINCT CONCEPT_CODE,
	ingredient_concept_code
FROM ds_all_tmp;

TRUNCATE TABLE relationship_to_concept;
INSERT INTO relationship_to_concept (
	concept_code_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
--existing concepts used in mappings
--bug in RxE, so take the first_value of concept_id_2
SELECT DISTINCT concept_code_1,
	first_value(concept_id_2) OVER (
		PARTITION BY concept_code_1,
		precedence,
		conversion_factor ORDER BY concept_id_2
		) AS concept_id_2,
	precedence,
	conversion_factor
FROM (
	SELECT CONCEPT_NAME AS concept_code_1,
		concept_id AS concept_id_2,
		1 AS precedence,
		1 AS conversion_factor
	FROM b_map
	
	UNION
	
	SELECT CONCEPT_CODE_1,
		concept_id_2,
		precedence,
		1
	FROM forms_mapping
	
	UNION
	
	SELECT CONCEPT_NAME_2,
		concept_id_2,
		1,
		1
	FROM s_map
	
	UNION
	
	SELECT INGREDIENT_CONCEPT_CODE,
		INGREDIENT_ID,
		1,
		1
	FROM ds_all_tmp
	WHERE INGREDIENT_ID IS NOT NULL
	
	UNION
	
	--add units from dm+D
	SELECT concept_code_1,
		concept_id_2,
		precedence,
		conversion_factor
	FROM dev_dmd.relationship_to_concept
	JOIN dev_dmd.DRUG_CONCEPT_STAGE_042017 ON concept_code = concept_code_1
	WHERE concept_class_id = 'Unit'
		AND precedence = 1
	) AS s0;
	--need to change the mapping from mcg to 0.001 mg

UPDATE RELATIONSHIP_TO_CONCEPT
SET concept_id_2 = 8576,
	CONVERSION_FACTOR = 0.001
WHERE CONCEPT_CODE_1 = 'mcg';

UPDATE relationship_to_concept
SET concept_id_2 = 19069149
WHERE concept_id_2 = 46274409;

--mapping to U instead of iU
UPDATE relationship_to_concept
SET concept_id_2 = 8510
WHERE concept_id_2 = 8718;

--RxE builder requires Ingredients used in relationships to be a standard
UPDATE drug_concept_stage
SET Standard_concept = 'S'
WHERE concept_class_id = 'Ingredient';

--ds_stage shouldn't have empty dosage
DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE coalesce(amount_value, numerator_value, 0) = 0 -- needs to have at least one value, zeros don't count
			OR coalesce(amount_unit, numerator_unit) IS NULL -- needs to have at least one unit
			OR (
				amount_value IS NOT NULL
				AND amount_unit IS NULL
				) -- if there is an amount record, there must be a unit
			OR (
				coalesce(numerator_value, 0) != 0
				AND coalesce(numerator_unit, denominator_unit) IS NULL
				) -- if there is a concentration record there must be a unit in both numerator and denominator
			OR amount_unit = '%' -- % should be in the numerator_unit
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = '4915007'
	AND concept_code_2 = 'Chewing Gum';

--drop sequence code_seq
DO $$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(replace(concept_code, 'OMOP','')::int4)+1 into ex FROM (
		SELECT concept_code FROM concept WHERE concept_code like 'OMOP%'  and concept_code not like '% %' -- Last valid value of the OMOP123-type codes
		UNION ALL
		SELECT concept_code FROM drug_concept_stage where concept_code like 'OMOP%' and concept_code not like '% %' -- Last valid value of the OMOP123-type codes
	) AS s0;
	DROP SEQUENCE IF EXISTS code_seq;
	EXECUTE 'CREATE SEQUENCE code_seq INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END$$;


DROP TABLE IF EXISTS code_replace;
CREATE TABLE code_replace AS
SELECT 'OMOP' || nextval('code_seq') AS new_code,
	concept_code AS old_code
FROM (
	SELECT DISTINCT concept_code
	FROM drug_concept_stage
	WHERE concept_class_id IN (
			'Ingredient',
			'Brand Name',
			'Supplier',
			'Dose Form'
			)
		OR concept_code IN (
			SELECT drug_concept_code
			FROM pc_stage
			)
	) AS s0;

UPDATE drug_concept_stage a
SET concept_code = b.new_code
FROM code_replace b
WHERE a.concept_code = b.old_code
	AND a.concept_class_id IN (
		'Ingredient',
		'Brand Name',
		'Supplier',
		'Dose Form'
		)
	OR concept_code IN (
		SELECT drug_concept_code
		FROM pc_stage
		);

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

--Marketed Product must have strength and dose form otherwise Supplier needs to be removed
DELETE
FROM internal_relationship_stage
WHERE (
		concept_code_1,
		concept_code_2
		) IN (
		SELECT irs.concept_code_1,
			irs.concept_code_2
		FROM internal_relationship_stage irs
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Supplier'
		LEFT JOIN ds_stage ds ON drug_concept_code = irs.concept_code_1
		LEFT JOIN (
			SELECT concept_code_1
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Dose Form'
			) rf ON rf.concept_code_1 = irs.concept_code_1
		WHERE ds.drug_concept_code IS NULL
			OR rf.concept_code_1 IS NULL
		);

--some ds_stage update
UPDATE ds_stage a
SET DENOMINATOR_unit = (
		SELECT DISTINCT b.DENOMINATOR_unit
		FROM ds_stage b
		WHERE a.drug_CONCEPT_CODE = b.drug_CONCEPT_CODE
			AND a.DENOMINATOR_unit IS NULL
			AND b.DENOMINATOR_unit IS NOT NULL
		)
WHERE EXISTS (
		SELECT 1
		FROM ds_stage b
		WHERE a.drug_CONCEPT_CODE = b.drug_CONCEPT_CODE
			AND a.DENOMINATOR_unit IS NULL
			AND b.DENOMINATOR_unit IS NOT NULL
		);

UPDATE ds_stage a
SET numerator_value = a.amount_value,
	numerator_unit = a.amount_unit,
	amount_value = NULL,
	amount_unit = NULL
WHERE a.denominator_unit IS NOT NULL
	AND numerator_unit IS NULL;

--for further work with CNDV and then mapping creation roundabound, make copies of existing concept_stage and concept_relationship_stage
DROP TABLE IF EXISTS basic_concept_stage;
CREATE TABLE basic_concept_stage AS
SELECT *
FROM concept_stage;

DROP TABLE IF EXISTS basic_con_rel_stage;
CREATE TABLE basic_con_rel_stage AS
SELECT *
FROM concept_relationship_stage;

UPDATE ds_stage
SET DENOMINATOR_VALUE = 30
WHERE DRUG_CONCEPT_CODE = '4231007'
	AND DENOMINATOR_VALUE IS NULL;

SELECT *
FROM drug_concept_stage
WHERE concept_name IN (
		'Eftrenonacog alfa 250unit powder / solvent for solution for injection vials',
		'Odefsey 200mg/25mg/25mg tablets (Gilead Sciences International Ltd)',
		'Insuman rapid 100iu/ml Injection (Aventis Pharma)',
		'Engerix b 10microgram/0.5ml Paediatric vaccination (GlaxoSmithKline UK Ltd)',
		'Ethyloestranol 2mg Tablet'
		);

--clean up
--ds_stage was parsed wrongly by some reasons
UPDATE ds_stage
SET NUMERATOR_VALUE = 10,
	NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '6912007'
	AND NUMERATOR_VALUE = 5
	AND NUMERATOR_UNIT = 'ml';

UPDATE ds_stage
SET NUMERATOR_VALUE = 20,
	NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '6916007'
	AND NUMERATOR_VALUE = 10
	AND NUMERATOR_UNIT = 'ml';

UPDATE ds_stage
SET AMOUNT_VALUE = NULL,
	AMOUNT_UNIT = NULL,
	NUMERATOR_VALUE = 10000000,
	NUMERATOR_UNIT = 'unit',
	DENOMINATOR_VALUE = 1,
	DENOMINATOR_UNIT = 'ml'
WHERE DRUG_CONCEPT_CODE = '94291020'
	AND NUMERATOR_VALUE IS NULL
	AND NUMERATOR_UNIT IS NULL;

UPDATE ds_stage
SET NUMERATOR_VALUE = 4,
	NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '49537020'
	AND NUMERATOR_VALUE = 8
	AND NUMERATOR_UNIT = 'ml';

UPDATE ds_stage
SET NUMERATOR_VALUE = 20,
	NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '3252007'
	AND NUMERATOR_VALUE = 10
	AND NUMERATOR_UNIT = 'ml';

UPDATE ds_stage
SET NUMERATOR_VALUE = 30,
	NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '81443020'
	AND NUMERATOR_VALUE = 10
	AND NUMERATOR_UNIT = 'ml';

UPDATE ds_stage
SET AMOUNT_VALUE = NULL,
	AMOUNT_UNIT = NULL,
	NUMERATOR_VALUE = 6000000,
	NUMERATOR_UNIT = 'unit',
	DENOMINATOR_VALUE = 1,
	DENOMINATOR_UNIT = 'ml'
WHERE DRUG_CONCEPT_CODE = '80015020'
	AND NUMERATOR_VALUE IS NULL
	AND NUMERATOR_UNIT IS NULL;

UPDATE ds_stage
SET NUMERATOR_VALUE = 40,
	NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '58170020'
	AND NUMERATOR_VALUE = 20
	AND NUMERATOR_UNIT = 'ml';

UPDATE ds_stage
SET NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '58166020'
	AND NUMERATOR_VALUE = 50
	AND NUMERATOR_UNIT = 'ml';

UPDATE ds_stage
SET NUMERATOR_VALUE = 60,
	NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '2113007'
	AND NUMERATOR_VALUE = 10
	AND NUMERATOR_UNIT = 'ml';

UPDATE ds_stage
SET AMOUNT_VALUE = NULL,
	AMOUNT_UNIT = NULL,
	NUMERATOR_VALUE = 50,
	NUMERATOR_UNIT = 'mcg',
	DENOMINATOR_VALUE = 5,
	DENOMINATOR_UNIT = 'ml'
WHERE DRUG_CONCEPT_CODE = '67456020'
	AND NUMERATOR_VALUE IS NULL
	AND NUMERATOR_UNIT IS NULL;

UPDATE ds_stage
SET NUMERATOR_VALUE = 10,
	NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE = '58165020'
	AND NUMERATOR_VALUE = 20
	AND NUMERATOR_UNIT = 'ml';

DELETE
FROM ds_stage
WHERE drug_concept_Code IN (
		SELECT drug_concept_Code
		FROM ds_stage
		JOIN thin_need_to_map ON gemscript_code = DRUG_CONCEPT_CODE
		WHERE lower(numerator_unit) IN ('ml')
			OR lower(amount_unit) IN ('ml')
		);

DELETE
FROM ds_stage
WHERE DRUG_CONCEPT_CODE IN (
		SELECT DRUG_CONCEPT_CODE
		FROM ds_stage s
		JOIN drug_concept_stage a ON a.concept_code = s.drug_concept_code
			AND a.concept_class_id = 'Device'
		);
DELETE
FROM drug_concept_stage
WHERE concept_name = 'Syrup'
	AND concept_class_id = 'Ingredient';

DELETE
FROM drug_concept_stage
WHERE concept_name = 'Stibium'
	AND concept_class_id = 'Brand Name';

--Marketed Drugs without the dosage or Drug Form are not allowed
DELETE
FROM internal_relationship_stage
WHERE (
		concept_code_1,
		concept_code_2
		) IN (
		SELECT concept_code_1,
			concept_code_2
		FROM drug_concept_stage dcs
		JOIN (
			SELECT concept_code_1,
				concept_code_2
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Supplier'
			LEFT JOIN ds_stage ON drug_concept_code = concept_code_1
			WHERE drug_concept_code IS NULL
			
			UNION
			
			SELECT concept_code_1,
				concept_code_2
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
		);

--not smart clean up
UPDATE RELATIONSHIP_TO_CONCEPT
SET concept_id_2 = 44012620
WHERE concept_id_2 = 43125877;

UPDATE RELATIONSHIP_TO_CONCEPT
SET concept_id_2 = 1505346
WHERE concept_id_2 = 36878682;

UPDATE RELATIONSHIP_TO_CONCEPT
SET concept_id_2 = 36879003
WHERE concept_id_2 = 21014145;

UPDATE RELATIONSHIP_TO_CONCEPT
SET concept_id_2 = 44784806
WHERE concept_id_2 = 36878894;

DELETE
FROM ds_stage
WHERE drug_concept_code = '63620020';

UPDATE RELATIONSHIP_TO_CONCEPT
SET concept_id_2 = 21020188
WHERE concept_id_2 = 19131170;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 IN (
		SELECT concept_id_2
		FROM relationship_to_concept
		JOIN concept ON concept_id = concept_id_2
		WHERE invalid_reason IS NOT NULL
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		'74777020',
		'66641020',
		'74778020'
		)
	AND concept_code_2 IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_name = 'Colgate'
			AND concept_class_id = 'Brand Name'
		);

DELETE
FROM ds_stage
WHERE DRUG_CONCEPT_CODE = '80989020'
	AND NUMERATOR_VALUE = 10.8;

DELETE
FROM ds_stage
WHERE DRUG_CONCEPT_CODE = '98751020'
	AND NUMERATOR_VALUE = 30;

UPDATE ds_stage
SET NUMERATOR_VALUE = 35.2
WHERE DRUG_CONCEPT_CODE = '80989020'
	AND NUMERATOR_VALUE = 24.4;

UPDATE ds_stage
SET NUMERATOR_VALUE = 110
WHERE DRUG_CONCEPT_CODE = '98751020'
	AND NUMERATOR_VALUE = 80;

DELETE
FROM drug_concept_stage
WHERE concept_name = 'Colgate'
	AND concept_class_id = 'Brand Name';