UPDATE gemscript_reference
   SET gemscriptcode = LPAD(gemscriptcode,8,'0')
WHERE gemscriptcode != LPAD(gemscriptcode,8,'0');

--new prodcode
CREATE OR REPLACE VIEW gsr 
AS

(-- 	select * from gemscript_reference2 -- 	where gemscriptcode not like '!%' -- union  SELECT * FROM gemscript_reference WHERE gemscriptcode NOT LIKE '!%');

--to do: 
--source priority, descending:
/*
	1. thin_gemsc_dmd -- THIN source
	2. gemscript_reference -- NN source
	3. gemscript_dmd_map -- unknown origin, never updated
*/ 
--use Gemscript reference where it's possible
--there's no need to run the real bug fix on gemscript before we updated dmd
--add the Brand name taken ingredient match
--
DROP SEQUENCE code_seq;

DO $$ DECLARE ex INTEGER;

BEGIN
SELECT MAX(REPLACE(concept_code,'OMOP','')::INT4) +1 INTO ex
FROM (SELECT concept_code
      FROM concept
      WHERE concept_code LIKE 'OMOP%'
      AND   concept_code NOT LIKE '% %'
      -- Last valid value of the OMOP123-type codes
      /*UNION ALL
		SELECT concept_code FROM drug_concept_stage where concept_code like 'OMOP%' and concept_code not like '% %' -- Last valid value of the OMOP123-type codes*/) AS s0;

DROP SEQUENCE IF EXISTS code_seq;

EXECUTE 'CREATE SEQUENCE code_seq INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';

END;

$$;

--1 Update latest_update field to new date 
DO $_$ BEGIN perform vocabulary_pack.setlatestupdate (pvocabularyname => 'Gemscript',pvocabularydate => TO_DATE('01082020','ddmmyyyy'),
-- pick the latest date between CPRD and THIN files
pvocabularyversion => 'Gemscript ' ||to_date ('01082020','ddmmyyyy'),pvocabularydevschema => 'DEV_GEMSCRIPT');

END;

$_$;

DROP TABLE IF EXISTS rel_to_conc_old;

CREATE TABLE rel_to_conc_old 
AS
SELECT c.concept_id AS concept_id_1,
       'Source - RxNorm eq'::VARCHAR AS relationship_id,
       concept_id_2
FROM (SELECT *
      FROM dev_dpd.relationship_to_concept
      WHERE precedence = 1
      UNION
      SELECT *
      FROM dev_aus.relationship_to_concept
      WHERE precedence = 1) a
  JOIN concept c
    ON c.concept_code = a.concept_code_1
   AND c.vocabulary_id = a.vocabulary_id_1
   AND c.invalid_reason IS NULL;

--thin_gemsc_dmd
INSERT INTO concept_stage
SELECT NULL AS concept_id,
       brand AS concept_name,
       'Drug' AS domain_id,
       'Gemscript' AS vocabulary_id,
       'Gemscript' AS concept_class_id,
       NULL AS standard_concept,
       gemscript_drugcode AS concept_code,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM thin_gemsc_dmd
WHERE gemscript_drugcode NOT IN (SELECT concept_code FROM concept_stage);

--add Gemscript concept set,
--take concepts from additional tables
--reference table from CPRD - goes first - NovoNordisk Need
TRUNCATE TABLE concept_stage;

INSERT INTO concept_stage
SELECT NULL AS concept_id,
       productname AS concept_name,
       'Drug' AS domain_id,
       'Gemscript' AS vocabulary_id,
       'Gemscript' AS concept_class_id,
       NULL AS standard_concept,
       gemscriptcode AS concept_code,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM gsr;

--dm+d map of unknown origin
INSERT INTO concept_stage
SELECT NULL AS concept_id,
       dmd_drug_name AS concept_name,
       'Drug' AS domain_id,
       'Gemscript' AS vocabulary_id,
       'Gemscript' AS concept_class_id,
       NULL AS standard_concept,
       gemscript_drug_code AS concept_code,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM gemscript_dmd_map
WHERE gemscript_drug_code NOT IN (SELECT concept_code
                                  FROM concept_stage
                                  WHERE concept_code IS NOT NULL);

--Gemscript THIN concepts 
INSERT INTO concept_stage
SELECT NULL AS concept_id,
       generic AS concept_name,
       'Drug' AS domain_id,
       'Gemscript' AS vocabulary_id,
       'Gemscript THIN' AS concept_class_id,
       NULL AS standard_concept,
       encrypted_drugcode AS concept_code,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       -- TRUNC(SYSDATE)
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM thin_gemsc_dmd;

--!codes remain as they are
--build concept_relationship_stage table
TRUNCATE TABLE concept_relationship_stage;

--Gemscript to dm+d
INSERT INTO concept_relationship_stage
SELECT NULL::INT AS concept_id_1,
       NULL::INT AS concept_id_2,
       gemscript_drugcode AS concept_code_1,
       c2.concept_code AS concept_code_2,
       'Gemscript' AS vocabulary_id_1,
       c2.vocabulary_id AS vocabulary_id_2,
       'Maps to' AS relationship_id,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM thin_gemsc_dmd t
  JOIN concept d
    ON d.concept_code = t.dmd_code
   AND d.vocabulary_id = 'dm+d'
  JOIN concept_relationship cr
    ON d.concept_id = cr.concept_id_1
   AND cr.relationship_id = 'Maps to'
  JOIN concept c2 ON c2.concept_id = cr.concept_id_2
UNION
SELECT NULL::INT AS concept_id_1,
       NULL::INT AS concept_id_2,
       gemscriptcode,
       c2.concept_code,
       'Gemscript' AS vocabulary_id_1,
       c2.vocabulary_id AS vocabulary_id_2,
       'Maps to' AS relationship_id,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM gsr t
  JOIN concept d
    ON d.concept_code = t.dmdcode
   AND d.vocabulary_id = 'dm+d'
  JOIN concept_relationship cr
    ON d.concept_id = cr.concept_id_1
   AND cr.relationship_id = 'Maps to'
  JOIN concept c2 ON c2.concept_id = cr.concept_id_2;

--delete mappings to non-existing dm+ds because they ruin further procedures result
--it allows to exist old mappings , they are relatively good but not very precise actually, and we know that if there was exising dm+d concept it'll go to better dm+d RxE way, and actually gives us for about 4000 relationships, 
-- so if we have time we can remap these concepts to RxE, give to medical coder to review them
--but for now let's keep them
DELETE
FROM concept_relationship_stage
WHERE vocabulary_id_2 = 'dm+d'
AND   concept_code_2 NOT IN (SELECT concept_code FROM concept WHERE vocabulary_id = 'dm+d');

/*--mapping to existing dm+d concepts
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
join concept on
	vocabulary_id = 'dm+d' and
	concept_code = dmd_code
WHERE gemscript_drug_code NOT IN (
		SELECT concept_code_1
		FROM concept_relationship_stage
		) 
-- 		and	concept.invalid_reason is not null*/

--mappings between THIN gemscript and Gemscript
INSERT INTO concept_relationship_stage
SELECT NULL AS concept_id_1,
       NULL AS concept_id_2,
       encrypted_drugcode AS concept_code_1,
       gemscript_drugcode AS concept_code_2,
       'Gemscript' AS vocabulary_id_1,
       'Gemscript' AS vocabulary_id_2,
       'Maps to' AS relationship_id,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM thin_gemsc_dmd;

--AVOF-350 source bug
--since source is not updated, fix it here
DELETE
FROM concept_relationship_stage
WHERE vocabulary_id_1 = 'Gemscript'
AND   vocabulary_id_2 = 'Gemscript'
AND   concept_code_1 = '87129998'
AND   relationship_id = 'Maps to';

--match using dm+d VMP's names is extrememly common
--Preserve AMP mappings first
INSERT INTO concept_relationship_stage
SELECT DISTINCT NULL::INT4 AS concept_id_1,
       NULL::INT4 AS concept_id_2,
       gemscript_drugcode AS concept_code_1,
       c2.concept_code AS concept_code_2,
       'Gemscript' AS vocabulary_id_1,
       c2.vocabulary_id AS vocabulary_id_2,
       'Maps to' AS relationship_id,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM thin_gemsc_dmd t
  JOIN
--snomed names are more 'correct'
 (SELECT c1.concept_id,
         COALESCE(c2.concept_name,c1.concept_name) AS concept_name
  FROM concept c1
    LEFT JOIN concept c2
           ON c2.vocabulary_id = 'SNOMED'
          AND c2.concept_code = c1.concept_code
          AND c2.concept_name != c1.concept_name
  WHERE c1.vocabulary_id = 'dm+d'
  AND   c1.concept_class_id = 'AMP') c ON REPLACE (lower (t.brand),' ','') = REPLACE (lower (c.concept_name),' ','')
--    AND c.vocabulary_id = 'dm+d'
--    AND c.concept_class_id = 'AMP'

  JOIN concept_relationship cr
    ON c.concept_id = cr.concept_id_1
   AND cr.relationship_id = 'Maps to'
  JOIN concept c2 ON c2.concept_id = cr.concept_id_2
WHERE t.gemscript_drugcode NOT IN (SELECT concept_code_1 FROM concept_relationship_stage);

--now VMPs from thin_gemsc_dmd
INSERT INTO concept_relationship_stage
SELECT DISTINCT NULL::INT4 AS concept_id_1,
       NULL::INT4 AS concept_id_2,
       encrypted_drugcode AS concept_code_1,
       c2.concept_code AS concept_code_2,
       'Gemscript' AS vocabulary_id_1,
       c2.vocabulary_id AS vocabulary_id_2,
       'Maps to' AS relationship_id,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM thin_gemsc_dmd t
  JOIN concept c
    ON REPLACE (lower (t.generic),' ','') = REPLACE (lower (c.concept_name),' ','')
   AND c.vocabulary_id = 'dm+d'
   AND c.concept_class_id = 'VMP'
   AND REPLACE (lower (t.brand),' ','') = REPLACE (lower (t.generic),' ','')
  JOIN concept_relationship cr
    ON c.concept_id = cr.concept_id_1
   AND cr.relationship_id = 'Maps to'
  JOIN concept c2 ON c2.concept_id = cr.concept_id_2
WHERE t.encrypted_drugcode NOT IN (SELECT concept_code_1 FROM concept_relationship_stage);

--both for THIN and Gemscript
INSERT INTO concept_relationship_stage
SELECT DISTINCT NULL::INT4 AS concept_id_1,
       NULL::INT4 AS concept_id_2,
       gemscript_drugcode AS concept_code_1,
       c2.concept_code AS concept_code_2,
       'Gemscript' AS vocabulary_id_1,
       c2.vocabulary_id AS vocabulary_id_2,
       'Maps to' AS relationship_id,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM thin_gemsc_dmd t
  JOIN concept c
    ON REPLACE (lower (t.generic),' ','') = REPLACE (lower (c.concept_name),' ','')
   AND c.vocabulary_id = 'dm+d'
   AND c.concept_class_id = 'VMP'
   AND REPLACE (lower (t.brand),' ','') = REPLACE (lower (t.generic),' ','')
   AND c.invalid_reason IS NULL
  JOIN concept_relationship cr
    ON c.concept_id = cr.concept_id_1
   AND cr.relationship_id = 'Maps to'
  JOIN concept c2 ON c2.concept_id = cr.concept_id_2
WHERE t.gemscript_drugcode NOT IN (SELECT concept_code_1 FROM concept_relationship_stage);

--also from gsr
INSERT INTO concept_relationship_stage
SELECT DISTINCT NULL::INT4 AS concept_id_1,
       NULL::INT4 AS concept_id_2,
       gemscriptcode AS concept_code_1,
       c2.concept_code AS concept_code_2,
       'Gemscript' AS vocabulary_id_1,
       c2.vocabulary_id AS vocabulary_id_2,
       'Maps to' AS relationship_id,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM gsr t
  JOIN concept c
    ON REPLACE (lower (t.productname),' ','') = REPLACE (lower (c.concept_name),' ','')
   AND c.vocabulary_id = 'dm+d'
   AND c.concept_class_id = 'VMP'
  JOIN concept_relationship cr
    ON c.concept_id = cr.concept_id_1
   AND cr.relationship_id = 'Maps to'
  JOIN concept c2 ON c2.concept_id = cr.concept_id_2
WHERE t.gemscriptcode NOT IN (SELECT concept_code_1 FROM concept_relationship_stage);

ANALYZE concept_stage;

ANALYZE concept_relationship_stage;

DELETE
--do not allow unupdated mappings
FROM concept_relationship_stage
WHERE vocabulary_id_2 = 'Gemscript'
AND   concept_code_2 NOT IN (SELECT concept_code_1 FROM concept_relationship_stage)
AND   invalid_reason IS NULL;

--delete from concept_stage where vocabulary_id = 'Gemscript' and concept_code not in (select concept_code_1 from concept_relationship_stage)

ANALYZE concept_stage;

ANALYZE concept_relationship_stage;

--wrong mapping from previous runs
--insert into concept_stage values (null, 'Strepsils dual action 2.6mg/spray Spray (Crookes Healthcare Ltd)','Drug','Gemscript','Gemscript',null,'79921020',to_date('20160401','YYYYMMDD'),to_date('20991231','YYYYMMDD'),null)

INSERT INTO concept_relationship_stage
VALUES
(
  NULL,
  NULL,
  '79921020',
  '1010782',
  'Gemscript',
  'RxNorm',
  'Maps to',
  TO_DATE('20160401','YYYYMMDD'),
  TO_DATE('20991231','YYYYMMDD'),
  NULL
);

-- Working with replacement mappings
DO $_$ BEGIN perform vocabulary_pack.checkreplacementmappings ();

END;

$_$;

-- Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$ BEGIN perform vocabulary_pack.deprecatewrongmapsto ();

END;

$_$;

-- Add mapping from deprecated to fresh concepts, and also from non-standard to standard concepts
DO $_$ BEGIN perform vocabulary_pack.addfreshmapsto ();

END;

$_$;

ANALYZE concept_relationship_stage;

-- Delete ambiguous 'Maps to' mappings
DO $_$ BEGIN perform vocabulary_pack.deleteambiguousmapsto ();

END;

$_$;

--deprecate relationship mappings to Non-standard concepts
--how's this possible?
UPDATE concept_relationship_stage
   SET invalid_reason = 'D',
       valid_end_date = (SELECT latest_update - 1
                         FROM vocabulary
                         WHERE vocabulary_id = 'Gemscript')
WHERE (concept_code_1,concept_code_2,vocabulary_id_2) NOT IN (SELECT concept_code_1,
                                                                     concept_code_2,
                                                                     vocabulary_id_2
                                                              FROM concept_relationship_stage
                                                                JOIN concept
                                                                  ON concept_code = concept_code_2
                                                                 AND vocabulary_id = vocabulary_id_2
                                                                 AND standard_concept = 'S');

--define drug domain (Drug set by default) based on target concept domain
UPDATE concept_stage cs
   SET domain_id = (SELECT domain_id
                    FROM (SELECT DISTINCT --beware of multiple mappings
                                 r.concept_code_1,
                                 r.vocabulary_id_1,
                                 c.domain_id
                          FROM concept_relationship_stage r
                          -- concept_code_1 = s1.concept_code and vocabulary_id_1 = vocabulary_id
                          
                            JOIN concept c
                              ON c.concept_code = r.concept_code_2
                             AND r.vocabulary_id_2 = c.vocabulary_id
                             AND r.invalid_reason IS NULL
                          -- and r.vocabulary_id_2 in ('dm+d', 'RxNorm', 'RxNorm Extension')
                          
                            JOIN (SELECT concept_code_1
                                  FROM (SELECT DISTINCT --beware of multiple mappings
                                               r.concept_code_1,
                                               r.vocabulary_id_1,
                                               c.domain_id
                                        FROM concept_relationship_stage r
                                        -- concept_code_1 = s1.concept_code and vocabulary_id_1 = vocabulary_id
                                        
                                          JOIN concept c
                                            ON c.concept_code = r.concept_code_2
                                           AND r.vocabulary_id_2 = c.vocabulary_id
                                           AND r.invalid_reason IS NULL
                                        -- and r.vocabulary_id_2 in ('dm+d', 'RxNorm', 'RxNorm Extension')) AS s0
                                  GROUP BY concept_code_1
                                  HAVING COUNT(*) = 1) zz
                          --exclude those mapped to several domains such as Inert ingredient is a device (wrong BTW), cartridge is a device, etc.
                          ON zz.concept_code_1 = r.concept_code_1) rr
                    WHERE rr.concept_code_1 = cs.concept_code
                    AND   rr.vocabulary_id_1 = cs.vocabulary_id);

--not covered are Drugs for now
UPDATE concept_stage
   SET domain_id = 'Drug'
WHERE domain_id IS NULL;

--select distinct domain_id from concept_stage;
--create table gsr as select * from gsr;
--why in this way????
--for development purpose use temporary thin_need_to_map table:  
DROP TABLE IF EXISTS thin_need_to_map;

--18457 the old version, 13965 --new version (join concept), well, really a big difference. not sure if those existing mappings are correct, 13877 - concept_relationship_stage version, why?
CREATE TABLE thin_need_to_map 
AS
SELECT --c.*
       t.encrypted_drugcode AS thin_code,
       t.generic::VARCHAR(255) AS thin_name,
       COALESCE(gr.gemscriptcode,t.gemscript_drugcode) AS gemscript_code,
       COALESCE(gr.productname,t.brand)::VARCHAR(255) AS gemscript_name,
       c.domain_id
FROM thin_gemsc_dmd t
  FULL OUTER JOIN gsr gr ON gr.gemscriptcode = t.gemscript_drugcode
  LEFT JOIN concept_relationship_stage r
         ON COALESCE (gr.gemscriptcode,t.gemscript_drugcode) = r.concept_code_1
        AND r.invalid_reason IS NULL
        AND r.vocabulary_id_2 IN ('dm+d', 'RxNorm', 'RxNorm Extension', 'SNOMED') 
        AND relationship_id = 'Maps to'
  JOIN concept_stage c
-- join and left join gives us different results because of   !1360102 AND   !5264101 codes, so exclude those !!-CODES

   ON (COALESCE (gr.gemscriptcode,t.gemscript_drugcode,'') = c.concept_code
   AND c.concept_class_id = 'Gemscript')
    OR (t.encrypted_drugcode = c.concept_code
   AND c.concept_class_id = 'Gemscript THIN')
WHERE r.concept_code_2 IS NULL;

--insert missing thin concepts
INSERT INTO thin_need_to_map
SELECT c.concept_code,
       c.concept_name,
       t.gemscript_drugcode,
       t.brand,
       'Drug'
FROM concept_stage c
  JOIN thin_gemsc_dmd t ON c.concept_code = t.encrypted_drugcode
WHERE concept_code NOT IN (SELECT thin_code
                           FROM thin_need_to_map
                           WHERE thin_code IS NOT NULL)
AND   concept_code NOT IN (SELECT concept_code_1
                           FROM concept_relationship_stage
                           WHERE concept_code_1 IS NOT NULL)
AND   concept_code IN (SELECT encrypted_drugcode FROM thin_gemsc_dmd);

--insert concepts that are mapped to nonexistent dmd concepts from gemscript_dmd_map table for manual processing
INSERT INTO thin_need_to_map
SELECT NULL::VARCHAR,
       NULL::VARCHAR,
       c.concept_code,
       c.concept_name,
       'Drug' --will change
       FROM concept_stage c
WHERE concept_code NOT IN (SELECT gemscript_code
                           FROM thin_need_to_map
                           WHERE gemscript_code IS NOT NULL)
AND   concept_code NOT IN (SELECT concept_code_1
                           FROM concept_relationship_stage
                           WHERE concept_code_1 IS NOT NULL)
AND   concept_class_id = 'Gemscript'
AND   concept_code IN (SELECT gemscript_drug_code
                       FROM gemscript_dmd_map
                         LEFT JOIN concept
                                ON vocabulary_id = 'dm+d'
                               AND dmd_code = concept_code
                       WHERE concept_code IS NULL);

CREATE INDEX th_th_n_ix 
  ON thin_need_to_map (lower (thin_name));

CREATE INDEX th_ge_n_ix 
  ON thin_need_to_map (lower (gemscript_name));

UPDATE thin_need_to_map
   SET thin_name = REPLACE(thin_name,'polymixin b ','polymyxin b');

UPDATE thin_need_to_map
   SET thin_name = REPLACE(thin_name,'ipecacuhana','ipecacuanha');

UPDATE thin_need_to_map
   SET thin_name = REPLACE(thin_name,'chloesterol','cholesterol');

UPDATE thin_need_to_map
   SET thin_name = REPLACE(thin_name,'capsicin','capsaicin');

UPDATE thin_need_to_map
   SET thin_name = REPLACE(thin_name,'glycolsalicylate','glycol salicylate');

UPDATE thin_need_to_map
   SET thin_name = REPLACE(thin_name,'azatidine','azacytidine');

UPDATE thin_need_to_map
   SET thin_name = REPLACE(thin_name,'benzalkonium, chlorhexidine','benzalkonium / chlorhexidine');

--define domain_id --weird logic
--DRUGSUBSTANCE is null and lower
--!!! OK for gemscript part
UPDATE thin_need_to_map n
   SET domain_id = 'Device'
WHERE EXISTS (SELECT 1
              FROM gsr g
              WHERE (SELECT COUNT(*) FROM REGEXP_MATCHES(productname,'[a-z]','gi')) > 5
              -- sometime we have these non HCl, mg as a part of UPPER case concept_name
              AND   (drugsubstance IS NULL OR drugsubstance = 'Syringe For Injection')
              AND   g.gemscriptcode = n.gemscript_code);

--4758
--device by the name (taken from dmd?) part 1
--ok
UPDATE thin_need_to_map
   SET domain_id = 'Device'
WHERE gemscript_code IN (SELECT gemscript_code
                         FROM thin_need_to_map
                         WHERE thin_name ~* 'stoma caps|urinal systems|shampoo|sunscreen|amidotrizoate|dialysis|smoflipid|camino|maxamum|sno-pro|lubri|peptamen|pepti-junior|dressing|diagnostic|glove|supplement| rope|weight|resource|accu-chek|accutrend|procal|glytactin|gauze|keyomega|cystine|docomega|anamixcranberry|pedialyte|hydralyte|hcu cooler|pouch'
                         UNION ALL
                         SELECT gemscript_code
                         FROM thin_need_to_map
                         WHERE thin_name ~* 'burger|biscuits|stocking|strip|remover|chamber|gauze|supply|beverage|cleanser|soup|protector|nutrision|repellent|wipes|kilocalories|cake|roll|adhesive|milk|dessert|medium chain|prozero|amino acid supplement|long chain|low protein|pouches|ribbon|cannula|swabs|bandage|cylinder'
                         UNION ALL
                         SELECT gemscript_code
                         FROM thin_need_to_map
                         WHERE gemscript_name ~* 'amidotrizoate|burger|biscuits|stocking|strip|remover|chamber|gauze|supply|beverage|cleanser|soup|protector|nutrision|repellent|wipes|kilocalories|cake|roll|adhesive|milk|dessert|medium chain|prozero|amino acid supplement|long chain|low protein|pouches|ribbon|cannula|swabs|bandage|cylinder'
                         UNION ALL
                         SELECT gemscript_code
                         FROM thin_need_to_map
                         WHERE gemscript_name ~* 'dialysis|smoflipid|camino|maxamum|sno-pro|lubri|peptamen|pepti-junior|dressing|diagnostic|glove|supplement| rope|weight|resource|accu-chek|accutrend|procal|glytactin|gauze|keyomega|cystine|docomega|anamixcranberry|pedialyte|hydralyte|hcu cooler|pouch'
                         UNION ALL
                         SELECT gemscript_code
                         FROM thin_need_to_map
                         WHERE gemscript_name ~* '(dermablend|credalast|collar|latex|ensure|suture|convex|truss|incontinence|sterile|brush|fresubin|nutriflex)')
AND   domain_id = 'Drug';

--device by the name (taken from dmd?) part 2
--ok
UPDATE thin_need_to_map
   SET domain_id = 'Device'
--put these into script above
       WHERE gemscript_code IN (SELECT gemscript_code
                                FROM thin_need_to_map
                                WHERE thin_name ~* 'breath test|pizza|physical|diet food|sunscreen|tubing|nutrison|elasticated vest|oxygen|spaghetti|irrigation |sunscreen cream|sheaths|lancet| wash|contact lens|bag|gluten|plast|wax|catheter|device|needle|needle|emollient|feeding|colostomy| toe |rubber|flange|cotton|stockinette|urostomy|tube |ostomy|cracker|shield|larve|belt|pasta|garments|bread'
                                OR    gemscript_name ~* 'breath test|pizza|physical|diet food|sunscreen|tubing|nutrison|elasticated vest|oxygen|spaghetti|irrigation |sunscreen cream|sheaths|lancet| wash|contact lens|bag|gluten|plast|wax|catheter|device|needle|needle|emollient|feeding|colostomy| toe |rubber|flange|cotton|stockinette|urostomy|tube |ostomy|cracker|shield|larve|belt|pasta|garments|bread')
AND   domain_id = 'Drug';

--separate rules for drugs from gemscript_dmd_map concepts
UPDATE thin_need_to_map
   SET domain_id = 'Device'
WHERE gemscript_code IN (SELECT gemscript_code
                         FROM thin_need_to_map
                         WHERE gemscript_name ~* '(^Elasctic %)|sheath|sleeve|perspex|iryflex|elvarex|compression|maggots|Watch-spring|stocking|wafer|belt|catheter|ostomy')
AND   domain_id = 'Drug';

--these concepts are drugs anyway
--put this condition into concept above!!! 
--ok
UPDATE thin_need_to_map n
   SET domain_id = 'Drug'
WHERE EXISTS (SELECT 1
              FROM gsr g
              WHERE g.gemscriptcode = n.gemscript_code
              AND   n.domain_id = 'Device'
              AND   LOWER(formulation) IN ('capsule','chewable tablet',
              --'cream',
              'cutaneous solution','ear drops','ear/eye drops solution','emollient','emulsion','emulsion for infusion','enema','eye drops','eye ointment',
              --'gel',
              'granules','homeopathic drops','homeopathic pillule','homeopathic tablet','inhalation powder','injection','injection solution','lotion','ointment','oral gel','oral solution','oral suspension',
              --'plasters',
              'powder','sachets','solution for injection','suppository','tablet','infusion','solution','Suspension for injection','Spansule','lozenge','cream','Intravenous Infusion'));

--make standard representation of multicomponent drugs
UPDATE thin_need_to_map
   SET thin_name = REPLACE(thin_name,'%/','% / ')
WHERE thin_name ~ '%/'
AND   domain_id = 'Drug';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'( with )(\D)',' / \2','g')
WHERE thin_name LIKE '% with %'
AND   domain_id = 'Drug';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'( with )(\d)','+\2','g')
WHERE thin_name LIKE '% with %'
AND   domain_id = 'Drug';

UPDATE thin_need_to_map
   SET thin_name = REPLACE(thin_name,' & ',' / ')
WHERE thin_name LIKE '% & %'
AND   NOT thin_name ~ ' & \d'
AND   domain_id = 'Drug';

UPDATE thin_need_to_map
   SET thin_name = REPLACE(thin_name,' and ',' / ')
WHERE thin_name LIKE '% and %'
AND   NOT thin_name ~ ' and \d'
AND   domain_id = 'Drug';

UPDATE thin_need_to_map
   SET gemscript_name = REPLACE(gemscript_name,'%/','% / ')
WHERE gemscript_name ~ '%/'
AND   domain_id = 'Drug';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'( with )(\D)',' / \2','g')
WHERE gemscript_name LIKE '% with %'
AND   domain_id = 'Drug';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(gemscript_name,'( with )(\d)','+\2','g')
WHERE gemscript_name LIKE '% with %'
AND   domain_id = 'Drug';

UPDATE thin_need_to_map
   SET gemscript_name = REPLACE(gemscript_name,' & ',' / ')
WHERE gemscript_name LIKE '% & %'
AND   NOT gemscript_name ~ ' & \d'
AND   domain_id = 'Drug';

UPDATE thin_need_to_map
   SET gemscript_name = REPLACE(gemscript_name,' and ',' / ')
WHERE gemscript_name LIKE '% and %'
AND   NOT gemscript_name ~ ' and \d'
AND   domain_id = 'Drug';

UPDATE thin_need_to_map
   SET thin_name = REPLACE(thin_name,'i.u.','iu')
WHERE thin_name LIKE '%i.u.%';

UPDATE thin_need_to_map
   SET gemscript_name = REPLACE(gemscript_name,'i.u.','iu')
WHERE gemscript_name LIKE '%i.u.%';

--define what's a pack based on the concept_name, then manually parse this out, then add pack_component names as a codes (check the code replacing script) and add pack_components as a drug components in ds_stage creation algorithms
DROP TABLE IF EXISTS packs_out;

CREATE TABLE packs_out 
AS
SELECT thin_name,
       gemscript_code,
       gemscript_name,
       NULL::VARCHAR(250) AS pack_component,
       NULL::NUMERIC AS amount
FROM thin_need_to_map t
WHERE t.domain_id = 'Drug'
AND   gemscript_name NOT LIKE 'Becloforte%'
AND   (gemscript_name LIKE '% pack%' OR gemscript_code IN
--packs defined manually
('67678021','76122020','80033020','1637007','28956020','45046020','92001020','92009020') OR thin_name ~ '(\d\s*x\s*\d)|(estradiol.*\+)' OR (SELECT COUNT(*)
                                                                                                                                            FROM REGEXP_MATCHES(thin_name,'tablet| cream|capsule','g')) > 1);

DROP TABLE IF EXISTS pc_stage;

CREATE TABLE pc_stage 
(
  pack_concept_code   VARCHAR(550),
  drug_concept_code   VARCHAR(550),
  amount              SMALLINT,
  box_size            SMALLINT
);

/*WbImport -file=/home/ekorchmar/Documents/packs_in.csv
         -type=text
         -table=packs_in
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=thin_name,gemscript_code,gemscript_name,pack_component,amount
         -quoteCharEscaping=NONE
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000;*/ 
INSERT INTO pc_stage
(
  pack_concept_code,
  drug_concept_code,
  amount,
  box_size
)
SELECT gemscript_code,
       pack_component,
       amount,
       NULL
FROM packs_in;

--as we use not real concept_codes, let's make the longer fields for the codes
--why I'm not using gsr table??
ALTER TABLE thin_need_to_map ALTER COLUMN gemscript_code TYPE VARCHAR(250);

ALTER TABLE thin_need_to_map ALTER COLUMN thin_code TYPE VARCHAR(250);

INSERT INTO thin_need_to_map
(
  thin_code,
  thin_name,
  gemscript_code,
  gemscript_name,
  domain_id
)
SELECT NULL,
       drug_concept_code,
       'OMOP' || nextval('code_seq'),
       drug_concept_code,
       'Drug'
FROM (SELECT DISTINCT drug_concept_code FROM pc_stage) s0;

DROP TABLE if exists packcomp_wcodes;

CREATE TABLE packcomp_wcodes 
AS
SELECT DISTINCT gemscript_code AS concept_code,
       gemscript_name AS concept_name
FROM thin_need_to_map
WHERE gemscript_code LIKE 'OMOP%';

DROP TABLE IF EXISTS thin_comp;

CREATE TABLE thin_comp 
AS
SELECT SUBSTRING(lower(a.drug_comp),'(((\d)*[.,]*\d+)(\s)*(mg|%|ml|mcg|hr|hours|unit(s?)|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit(s?)|nanogram(s)*|x|ppm|million units| Kallikrein inactivator units|kBq|microlitres|MBq|molar|micromol)(/((\d)*[.,]*\d+)*(\s*)(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop))*)') AS dosage,
       REPLACE(TRIM(SUBSTRING(lower(thin_name),'((\s|\()[[:digit:]\.]+(\s*)(litre(s?)|ml))')),'(','') AS volume,
       a.*
FROM (SELECT DISTINCT UNNEST(STRING_TO_ARRAY(t.thin_name,' / ')) AS drug_comp,
             t.*
      FROM thin_need_to_map t) a
WHERE a.domain_id = 'Drug'
--exclusions
--Bendroflumethiazide / potassium 2.5mg+7.7mmol modified release tablets 
AND   NOT thin_name ~* '[[:digit:]\,\.]+.*\+(\s*)[[:digit:]\,\.].*'
--Co-triamterzide 50mg/25mg tablets
--and not regexp_like (thin_name, '\dm(c*)g/[[:digit:]\,\.]+m(c*)g')
UNION
--Bendroflumethiazide / potassium 2.5mg+7.7mmol modified release tablets 
SELECT concat(TRIM(l.dosage),denom) AS dosage,
       volume,
       TRIM(l.drug_comp) AS drug_comp,
       thin_code,
       thin_name,
       gemscript_code,
       gemscript_name,
       domain_id
FROM (SELECT SUBSTRING(LOWER(thin_name),'(((\d)*[.,]*\d+)(\s)*(g|mg|%|mcg|iu|mmol|micrograms)(\s)*\+(\s)*[[:digit:]\,\.]+(g|mg|%|mcg|iu|mmol|micrograms|ku)((\s)*\+(\s)*((\d)*[.,]*\d+)*(\s)*(g|mg|%|mcg|iu|mmol|micrograms))*)') AS dosage_0,
             SUBSTRING(LOWER(thin_name),'(/[[:digit:]\,\.]+(ml| hr|g|mg))') AS denom,
             REPLACE(TRIM(SUBSTRING(thin_name,'((\s|\()[[:digit:]\.]+(\s*)(litre(s?)|ml))')),'(','') AS volume,
             t.*
      FROM thin_need_to_map t
      WHERE thin_name ~* '((\d)*[.,]*\d+)(\s)*(g|mg|%|mcg|iu|mmol|micrograms)(\s)*\+(\s)*[[:digit:]\,\.]+(g|mg|%|mcg|iu|mmol|micrograms|ku)((\s)*\+(\s)*((\d)*[.,]*\d+)*(\s)*(g|mg|%|mcg|iu|mmol|micrograms))*'
      AND   domain_id = 'Drug') t,
     LATERAL (SELECT *
              FROM UNNEST(STRING_TO_ARRAY(t.thin_name,' / '),STRING_TO_ARRAY(dosage_0,'+')) AS a (drug_comp,dosage)) l;

--/ampoule is treated as denominator then
UPDATE thin_comp
   SET dosage = REPLACE(dosage,'/ampoule','')
WHERE dosage LIKE '%/ampoule';

--',c is treated as dosage
UPDATE thin_comp
   SET dosage = NULL
WHERE dosage LIKE '\,%';

--select * from thin_comp;
INSERT INTO thin_comp
(
  dosage,
  volume,
  drug_comp,
  thin_code,
  thin_name,
  gemscript_code,
  gemscript_name,
  domain_id
)
SELECT SUBSTRING(gemscript_name,'\d+(\.\d+)?mc?g\/ml') AS dosage,
       NULL AS volume,
       SUBSTRING(gemscript_name,'^(\D+)(?=\s\d)') AS drug_comp,
       thin_code,
       thin_name,
       gemscript_code,
       gemscript_name,
       domain_id
FROM thin_need_to_map t
WHERE t.domain_id = 'Drug'
AND   t.gemscript_code NOT IN (SELECT gemscript_code FROM thin_comp)
AND   gemscript_name ~ 'mc?g\/ml';

INSERT INTO thin_comp
(
  dosage,
  volume,
  drug_comp,
  thin_code,
  thin_name,
  gemscript_code,
  gemscript_name,
  domain_id
)
SELECT SUBSTRING(gemscript_name,'[\d\.]+mg(?=\/)') AS dosage,
       REPLACE(SUBSTRING(gemscript_name,'\/[\d\.]+ml'),'/','') AS volume,
       SUBSTRING(gemscript_name,'^(\D+)(?=\s\d)') AS drug_comp,
       thin_code,
       thin_name,
       gemscript_code,
       gemscript_name,
       domain_id
FROM thin_need_to_map t
WHERE t.domain_id = 'Drug'
AND   t.gemscript_code NOT IN (SELECT gemscript_code FROM thin_comp)
AND   gemscript_name ~ '\d+(\.\d+)mc?g\/\d+(\.\d+)?ml';

/*
--insert into thin_comp (dosage,volume, drug_comp, thin_code, thin_name, gemscript_code, gemscript_name, domain_id)
insert into thin_comp (dosage,volume, drug_comp, thin_code, thin_name, gemscript_code, gemscript_name, domain_id)
select
	substring (gemscript_name, '[\d\.]+mg') as dosage,
	null as volume,
	substring (gemscript_name, '^(\D+)(?=\s\d)') as drug_comp,
	thin_code, thin_name, gemscript_code, gemscript_name, domain_id
from thin_need_to_map t
where
	t.domain_id = 'Drug' and
	t.gemscript_code not in (select gemscript_code from thin_comp)
	and gemscript_name ~ '[\d\.]+mg'
*/

CREATE INDEX drug_comp_ix 
  ON thin_comp  USING gin(drug_comp devv5.gin_trgm_ops);

CREATE INDEX drug_comp_ix2 
  ON thin_comp (lower (drug_comp));

ANALYZE thin_comp;

--we are only interested to find brand names that have 'stable' ingredient sets: with one possible ingredient combination
DROP TABLE if exists brand_rx;

CREATE TABLE brand_rx 
AS
WITH bn_to_i
AS
(SELECT c.concept_id AS b_id,
       r.concept_id_2 AS i_id,
       c.concept_name AS concept_name,
       COUNT(r.concept_id_2) OVER (PARTITION BY c.concept_id) AS cnt_direct
FROM concept c
  JOIN concept_relationship r
    ON r.relationship_id = 'Brand name of'
   AND c.concept_id = r.concept_id_1
  JOIN concept c2
    ON c2.concept_class_id = 'Ingredient'
   AND c2.concept_id = r.concept_id_2
   AND c2.standard_concept = 'S'
WHERE c.vocabulary_id IN ('RxNorm','RxNorm Extension')
AND   c.concept_class_id = 'Brand Name'
AND   c.invalid_reason IS NULL),bn_to_i_dp AS
--what possible ingredient sets drug products give us
(SELECT DISTINCT c.concept_id AS b_id,
        r.concept_id_2 AS dp_id,
        d.ingredient_concept_id AS i_id,
        COUNT(d.ingredient_concept_id) OVER (PARTITION BY r.concept_id_2) AS cnt_drug
 FROM concept c
   JOIN concept_relationship r
     ON r.relationship_id = 'Brand name of'
    AND c.concept_id = r.concept_id_1
   JOIN concept c2
     ON c2.concept_class_id != 'Ingredient'
    AND
 --only combinations and ingredient themselves can have brand names;
 c2.concept_id = r.concept_id_2
   JOIN drug_strength d ON c2.concept_id = d.drug_concept_id
   JOIN concept c3
     ON d.ingredient_concept_id = c3.concept_id
    AND c3.standard_concept = 'S'
 WHERE c.vocabulary_id IN ('RxNorm','RxNorm Extension')
 AND   c.concept_class_id = 'Brand Name'
 AND   c.invalid_reason IS NULL) SELECT DISTINCT b.b_id,b.concept_name,b.i_id FROM bn_to_i b LEFT JOIN bn_to_i_dp d ON d.b_id = b.b_id AND b.cnt_direct > d.cnt_drug WHERE d.b_id IS NULL;

INSERT INTO brand_rx
WITH bn_to_i
AS
(SELECT c.concept_id AS b_id,
       r.concept_id_2 AS i_id,
       c.concept_name AS concept_name,
       COUNT(r.concept_id_2) OVER (PARTITION BY c.concept_id) AS cnt_direct
FROM concept c
  JOIN concept_relationship r
    ON r.relationship_id = 'Brand name of'
   AND c.concept_id = r.concept_id_1
  JOIN concept c2
    ON c2.concept_class_id = 'Ingredient'
   AND c2.concept_id = r.concept_id_2
   AND c2.standard_concept = 'S'
WHERE c.concept_id NOT IN (SELECT b_id FROM brand_rx)
AND  
--avoid duplication
c.vocabulary_id = 'RxNorm'
AND   c.concept_class_id = 'Brand Name'
AND   c.invalid_reason IS NULL
AND   EXISTS
-- there are RxNorm Drug products with r.concept_id_2 as an ingredient
(SELECT
 FROM drug_strength d
   JOIN concept x
     ON d.drug_concept_id = x.concept_id
    AND x.vocabulary_id = 'RxNorm'
    AND x.concept_class_id != 'Ingredient'
    AND d.ingredient_concept_id = r.concept_id_2
 -- with that brand name and ingredient
 
   JOIN concept_relationship cr
     ON cr.concept_id_1 = x.concept_id
    AND relationship_id = 'Has brand name'
    AND cr.concept_id_2 = c.concept_id
 WHERE d.invalid_reason IS NULL)),bn_to_i_dp AS
--what possible ingredient sets drug RxN products give us
(SELECT DISTINCT c.concept_id AS b_id,
        r.concept_id_2 AS dp_id,
        d.ingredient_concept_id AS i_id,
        COUNT(d.ingredient_concept_id) OVER (PARTITION BY r.concept_id_2) AS cnt_drug
 FROM concept c
   JOIN concept_relationship r
     ON r.relationship_id = 'Brand name of'
    AND c.concept_id = r.concept_id_1
   JOIN concept c2
     ON c2.concept_class_id != 'Ingredient'
    AND
 --only combinations and ingredient themselves can have brand names;
 c2.concept_id = r.concept_id_2
   JOIN drug_strength d ON c2.concept_id = d.drug_concept_id
   JOIN concept c3
     ON d.ingredient_concept_id = c3.concept_id
    AND c3.standard_concept = 'S'
 WHERE c.concept_id NOT IN (SELECT b_id FROM brand_rx)
 AND  
 --avoid duplication
 c.vocabulary_id = 'RxNorm'
 AND   c.concept_class_id = 'Brand Name'
 AND   c.invalid_reason IS NULL
 AND   d.invalid_reason IS NULL) SELECT DISTINCT b.b_id,b.concept_name,b.i_id FROM bn_to_i b LEFT JOIN bn_to_i_dp d ON d.b_id = b.b_id AND b.cnt_direct > d.cnt_drug WHERE d.b_id IS NULL;

DELETE
FROM brand_rx
WHERE i_id IN (19123624);

--how to define Ingredient, change scripts to COMPONENTS and use only (  lower (a.thin_name) like lower (b.concept_name)||' %' tomorrow!!!
--take the longest ingredient, if this works, rough dm+d is better, becuase it has Sodium bla-bla-nate and RxNorm has just bla-bla-nate 
--don't need to have two parts here
--Execution time: 57.41s
--Execution time: 1m 41s when more vocabularies added 
DROP TABLE IF EXISTS i_map;

CREATE TABLE i_map 
AS
-- enhanced algorithm added  lower (a.thin_name) like lower '% '||(b.concept_name)||' %'
SELECT *
FROM (SELECT DISTINCT i.dosage,
             i.thin_name,
             i.thin_code,
             i.drug_comp,
             i.gemscript_code,
             i.gemscript_name,
             i.volume,
             i.concept_id,
             i.concept_name,
             i.vocabulary_id,
             RANK() OVER (PARTITION BY i.drug_comp ORDER BY devv5.levenshtein (i.concept_name,i.drug_comp) DESC,i.vocabulary_id DESC,i.concept_id) AS rank1
      FROM (SELECT DISTINCT a.*,
                   rx.concept_id,
                   rx.concept_name,
                   rx.vocabulary_id
            FROM thin_comp a
              JOIN concept_synonym s
                ON (a.drug_comp ilike s.concept_synonym_name || ' %'
                OR LOWER (a.drug_comp) = LOWER (s.concept_synonym_name))
              JOIN concept_relationship r
                ON s.concept_id = r.concept_id_1
               AND r.invalid_reason IS NULL
               AND r.relationship_id = 'Maps to'
              JOIN concept cf
                ON
            --VTMs have multiple relations to ingredients which leads to some weird sssthings
            r.concept_id_1 = cf.concept_id
               AND cf.concept_class_id != 'VTM'
               AND cf.concept_code NOT LIKE '!%'
               AND cf.vocabulary_id != 'AMIS'
            --really BAD mappings
            
              JOIN concept rx
                ON r.concept_id_2 = rx.concept_id
               AND rx.vocabulary_id LIKE 'Rx%'
               AND rx.concept_class_id = 'Ingredient'
               AND rx.invalid_reason IS NULL
            WHERE
            --sodium *ate should never point to sodium
            NOT ((a.drug_comp ilike 'sodium %ate %' OR a.drug_comp ilike 'sodium %ide %') AND rx.concept_id = 19136048
            -- Sodium (RxNorm Ingredient)
            )) i) AS s0
--take the lev-closest ingredient
WHERE rank1 = 1;

INSERT INTO i_map
(
  dosage,
  thin_name,
  thin_code,
  drug_comp,
  gemscript_code,
  gemscript_name,
  volume,
  concept_id,
  concept_name,
  vocabulary_id,
  rank1
)
SELECT DISTINCT c.dosage,
       c.thin_name,
       c.thin_code,
       c.drug_comp,
       c.gemscript_code,
       c.gemscript_name,
       c.volume,
       x.concept_id,
       x.concept_name,
       x.vocabulary_id,
       1
FROM thin_comp c
  JOIN brand_rx b
    ON c.drug_comp ilike b.concept_name || '%'
   AND NOT EXISTS
-- no longer match
 (SELECT
  FROM brand_rx bx
  WHERE c.drug_comp ilike bx.concept_name || '%'
  AND   LENGTH(bx.concept_name) >LENGTH(b.concept_name))
  JOIN concept x ON x.concept_id = b.i_id
WHERE c.gemscript_code NOT IN (SELECT gemscript_code FROM i_map);

--map Ingredients derived from different vocabularies to RxNorm(E)
DROP TABLE IF EXISTS rel_to_ing_1;

CREATE TABLE rel_to_ing_1 
AS
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

CREATE TABLE thin_comp2 
AS
SELECT SUBSTRING(lower(a.drug_comp),'(((\d)*[.,]*\d+)(\s)*(mg|%|ml|mcg|hr|hours|unit(s?)|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit(s?)|nanogram(s)*|x|ppm|million units| Kallikrein inactivator units|kBq|microlitres|MBq|molar|micromol)(/((\d)*[.,]*\d+)*(\s*)(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop))*)') AS dosage,
       REPLACE(TRIM(SUBSTRING(lower(gemscript_name),'((\s|\()[[:digit:]\.]+(\s*)(litre(s?)|ml))')),'(','') AS volume,
       a.*
FROM (SELECT DISTINCT TRIM(UNNEST(STRING_TO_ARRAY(t.gemscript_name,' / '))) AS drug_comp,
             t.*
      FROM thin_need_to_map t) a
WHERE a.domain_id = 'Drug'
--exclusions
--Bendroflumethiazide / potassium 2.5mg+7.7mmol modified release tablets 
AND   NOT gemscript_name ~* '[[:digit:]\,\.]+.*\+(\s*)[[:digit:]\,\.].*'
AND   gemscript_code NOT IN (SELECT gemscript_code FROM rel_to_ing_1)
--Co-triamterzide 50mg/25mg tablets
--and not regexp_like (gemscript_name, '\dm(c*)g/[[:digit:]\,\.]+m(c*)g')
UNION
--Bendroflumethiazide / potassium 2.5mg+7.7mmol modified release tablets 
SELECT concat(TRIM(l.dosage),denom) AS dosage,
       volume,
       TRIM(l.drug_comp) AS drug_comp,
       thin_code,
       gemscript_name,
       gemscript_code,
       gemscript_name,
       domain_id
FROM (SELECT SUBSTRING(LOWER(gemscript_name),'(((\d)*[.,]*\d+)(\s)*(mg|%|mcg|iu|mmol|micrograms)(\s)*\+(\s)*[[:digit:]\,\.]+(mg|%|mcg|iu|mmol|micrograms)((\s)*\+(\s)*((\d)*[.,]*\d+)*(\s)*(mg|%|mcg|iu|mmol|micrograms))*)') AS dosage_0,
             SUBSTRING(LOWER(gemscript_name),'(/[[:digit:]\,\.]+(ml| hr|g|mg))') AS denom,
             REPLACE(TRIM(SUBSTRING(LOWER(gemscript_name),'((\s|\()[[:digit:]\.]+(\s*)(litre(s?)|ml))')),'(','') AS volume,
             t.*
      FROM thin_need_to_map t
      WHERE gemscript_name ~* '((\d)*[.,]*\d+)(\s)*(mg|%|mcg|iu|mmol|micrograms)(\s)*\+(\s)*[[:digit:]\,\.]+(mg|%|mcg|iu|mmol|micrograms)((\s)*\+(\s)*((\d)*[.,]*\d+)*(\s)*(mg|%|mcg|iu|mmol|micrograms))*'
      AND   domain_id = 'Drug'
      AND   gemscript_code NOT IN (SELECT gemscript_code FROM rel_to_ing_1)) t,
     LATERAL (SELECT *
              FROM UNNEST(STRING_TO_ARRAY(t.gemscript_name,' / '),STRING_TO_ARRAY(dosage_0,'+')) AS a (drug_comp,dosage)) l;

--/ampoule is treated as denominator then
UPDATE thin_comp2
   SET dosage = REPLACE(dosage,'/ampoule','')
WHERE dosage LIKE '%/ampoule';

--',c is treated as dosage
UPDATE thin_comp2
   SET dosage = NULL
WHERE dosage LIKE '\,%';

CREATE INDEX drug_comp_ix_2 
  ON thin_comp2  USING gin(drug_comp devv5.gin_trgm_ops);

CREATE INDEX drug_comp_ix2_2 
  ON thin_comp2 (lower (drug_comp));

ANALYZE thin_comp2;

DROP TABLE if exists rx_synonym CASCADE;

CREATE TABLE rx_synonym 
AS
SELECT *
FROM concept_synonym r
  JOIN concept rx USING (concept_id)
-- 	rx.concept_id = r.concept_id
WHERE vocabulary_id IN ('RxNorm','RxNorm Extension')
AND   rx.standard_concept = 'S'
AND   rx.concept_class_id IN ('Ingredient','Brand Name')
AND   rx.invalid_reason IS NULL;

CREATE INDEX idx_sn 
  ON rx_synonym (concept_synonym_name);

ANALYZE rx_synonym;

DROP TABLE IF EXISTS i_map_2;

CREATE TABLE i_map_2 
AS
-- enhanced algorithm added  lower (a.thin_name) like lower '% '||(b.concept_name)||' %'
SELECT *
FROM (SELECT DISTINCT i.dosage,
             i.thin_name,
             i.thin_code,
             i.drug_comp,
             i.gemscript_code,
             i.gemscript_name,
             i.volume,
             i.concept_id,
             i.concept_name,
             i.vocabulary_id,
             RANK() OVER (PARTITION BY i.drug_comp ORDER BY devv5.levenshtein (i.concept_name,i.drug_comp) DESC,i.vocabulary_id DESC,i.concept_id) AS rank1
      FROM (SELECT DISTINCT a.*,
                   s.concept_id,
                   s.concept_name,
                   s.vocabulary_id
            FROM thin_comp2 a
              JOIN rx_synonym s
                ON (a.drug_comp ilike s.concept_synonym_name || ' %'
                OR LOWER (a.drug_comp) = LOWER (s.concept_synonym_name))
              JOIN concept_relationship r
                ON s.concept_id = r.concept_id_1
               AND r.invalid_reason IS NULL
            WHERE
            --sodium *ate should never point to sodium
            NOT ((a.drug_comp ilike 'sodium %ate %' OR a.drug_comp ilike 'sodium %ide %') AND s.concept_id = 19136048
            -- Sodium (RxNorm Ingredient)
            )) i) AS s0
--take the longest ingredient
WHERE rank1 = 1;

DELETE
FROM thin_comp2 x
WHERE dosage IS NULL
AND   EXISTS (SELECT
              FROM thin_comp2
              WHERE gemscript_code = x.gemscript_code
              AND   dosage IS NOT NULL)
AND   drug_comp LIKE '%)';

INSERT INTO i_map_2
(
  dosage,
  thin_name,
  thin_code,
  drug_comp,
  gemscript_code,
  gemscript_name,
  volume,
  concept_id,
  concept_name,
  vocabulary_id,
  rank1
)
SELECT DISTINCT c.dosage,
       c.thin_name,
       c.thin_code,
       c.drug_comp,
       c.gemscript_code,
       c.gemscript_name,
       c.volume,
       x.concept_id,
       x.concept_name,
       x.vocabulary_id,
       1
FROM thin_comp2 c
  JOIN brand_rx b
    ON c.drug_comp ilike b.concept_name || '%'
   AND NOT EXISTS
-- no longer match
 (SELECT
  FROM brand_rx bx
  WHERE c.drug_comp ilike bx.concept_name || '%'
  AND   LENGTH(bx.concept_name) >LENGTH(b.concept_name))
  JOIN concept x ON x.concept_id = b.i_id
WHERE c.gemscript_code NOT IN (SELECT gemscript_code FROM i_map_2);

--map Ingredients derived from different vocabularies to RxNorm(E)
DROP TABLE IF EXISTS rel_to_ing_2;

CREATE TABLE rel_to_ing_2 
AS
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

CREATE TABLE ds_all_tmp 
AS
SELECT dosage,
       drug_comp,
       thin_name AS concept_name,
       gemscript_code AS concept_code,
       target_name AS ingredient_concept_code,
       target_name AS ingredient_concept_name,
       TRIM(volume) AS volume,
       target_id AS ingredient_id
FROM rel_to_ing_1
UNION
SELECT dosage,
       drug_comp,
       thin_name AS concept_name,
       gemscript_code AS concept_code,
       target_name AS ingredient_concept_code,
       target_name AS ingredient_concept_name,
       TRIM(volume) AS volume,
       target_id AS ingredient_id
FROM rel_to_ing_2;

--!!! manual table
/*
--drop table full_manual;

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
WbImport -file=/home/ekorchmar/Documents/full_manual_gemscript.csv
         -type=text
         -table=full_manual
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=dosage,volume,thin_name,gemscript_name,ingredient_id,thin_code,gemscript_code,ingredient_concept_code,domain_id
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000;
;
Update full_manual set ingredient_concept_code=regexp_replace(ingredient_concept_code, '"', '')
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
  update full_manual set dosage = lower (dosage)
 -- ;
  commit
  */

/*
INSERT INTO full_manual
(
  dosage,
  volume,
  thin_name,
  gemscript_name,
  ingredient_id,
  thin_code,
  gemscript_code,
  ingredient_concept_code,
  domain_id
)
VALUES
(
  '20 mg',
  '1 ml',
  'Lidocaine hydrochloride 2% throat spray',
  'Strepsils dual action 2.6mg/spray Spray (Crookes Healthcare Ltd)',
  989878,
  '91174997',
  '79921020',
  'Lidocaine',
  'Drug'
);
UPDATE full_manual
   SET ingredient_id = 19129638,
       ingredient_concept_code = 'Orotic Acid'
WHERE thin_code = '97003992'
AND   gemscript_code = '02996007';
UPDATE full_manual
   SET ingredient_id = 19129638,
       ingredient_concept_code = 'Orotic Acid'
WHERE thin_code IS NULL
AND   gemscript_code = '02997007';
INSERT INTO full_manual
(
  dosage,
  volume,
  thin_name,
  gemscript_name,
  ingredient_id,
  thin_code,
  gemscript_code,
  ingredient_concept_code,
  domain_id
)
VALUES
(
  NULL,
  NULL,
  NULL,
  'ACTIVATED DIMETHICONE /ALUM HYDROX MIXT/ 125 MG MIX',
  985247,
  NULL,
  NULL,
  'Aluminum Hydroxide',
  NULL
);
UPDATE full_manual
   SET ingredient_id = 529303,
       ingredient_concept_code = 'diphtheria toxoid vaccine, inactivated'
WHERE thin_code = '93314992'
AND   gemscript_code = '06685007';
UPDATE full_manual
   SET ingredient_id = NULL,
       ingredient_concept_code = null
WHERE thin_code IS NULL
AND   gemscript_code = '44231020';
UPDATE full_manual
   SET dosage = '35 mg/ml',
       ingredient_id = 19069049,
       ingredient_concept_code = 'Collagen'
WHERE thin_code = '96788992'
AND   gemscript_code = '03211007';

*/

/*
UPDATE full_manual
   SET ingredient_concept_code = 'Ibuprofen',
   ingredient_id = 1177480
WHERE thin_code IS NULL
AND   gemscript_code = '05589007';
UPDATE full_manual
   SET ingredient_concept_code = 'Piracetam',
   ingredient_id =  19046654
WHERE thin_code IS NULL
AND   gemscript_code = '03149007';
*/

CREATE INDEX if not exists dcs_idx_code 
  ON drug_concept_stage (concept_code varchar_pattern_ops);

ANALYZE drug_concept_stage /*;
update full_manual f
set gemscript_code = lpad (gemscript_code,8,'0')
where gemscript_code != lpad (gemscript_code,8,'0')
*/;

DELETE
FROM ds_all_tmp
WHERE concept_code IN (SELECT gemscript_code
                       FROM full_manual
                       WHERE ingredient_concept_code IS NOT NULL);

DELETE
FROM ds_all_tmp
WHERE concept_code NOT IN (SELECT concept_code FROM drug_concept_stage);

INSERT INTO ds_all_tmp
(
  dosage,
  drug_comp,
  concept_name,
  concept_code,
  ingredient_concept_code,
  ingredient_concept_name,
  volume,
  ingredient_id
)
SELECT DISTINCT dosage,
       NULL,
       COALESCE(thin_name,gemscript_name),
       gemscript_code,
       ingredient_concept_code,
       ingredient_concept_code,
       volume,
       ingredient_id
FROM full_manual
WHERE ingredient_concept_code IS NOT NULL
AND   gemscript_code IN (SELECT concept_code FROM drug_concept_stage);

--domain_id definition
UPDATE thin_need_to_map t
   SET domain_id = (SELECT DISTINCT domain_id
                    FROM full_manual m
                    WHERE t.gemscript_code = m.gemscript_code)
WHERE EXISTS (SELECT 1
              FROM full_manual m
              WHERE t.gemscript_code = m.gemscript_code
              AND   domain_id IS NOT NULL);

--packs after manual table in case if in manual table there will be packs
DELETE
FROM ds_all_tmp
WHERE concept_code IN (SELECT pack_concept_code FROM pc_stage);

--then merge it with ds_all_tmp, for now temporary decision - make dosages NULL to avoid bug
--remove ' ' inside the dosage to make the same as it was before in dmd
UPDATE ds_all_tmp
   SET dosage = REPLACE(dosage,' ','');

--clean up
UPDATE ds_all_tmp
   SET dosage = REPLACE(dosage,'/','')
WHERE dosage LIKE '%/';

--assign proper OMOP codes to ingredients
DROP TABLE if exists i_coded;

CREATE TABLE i_coded 
AS
(SELECT 'OMOP' || nextval('code_seq') AS concept_code,
       ingredient_concept_name
FROM (SELECT DISTINCT ingredient_concept_name FROM ds_all_tmp) si);

UPDATE ds_all_tmp d
   SET ingredient_concept_code = (SELECT concept_code
                                  FROM i_coded
                                  WHERE ingredient_concept_name = d.ingredient_concept_code);

--dosage distribution along the ds_stage
DROP TABLE IF EXISTS ds_all;

CREATE TABLE ds_all 
AS
SELECT DISTINCT CASE
         WHEN SUBSTRING(lower(dosage),'([[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units|unit dose|drop))') = lower(dosage) AND NOT dosage ~ '%' THEN REPLACE(SUBSTRING(dosage,'[[:digit:]\,\.]+'),',','')
         ELSE NULL
       END AS amount_value,
       CASE
         WHEN SUBSTRING(lower(dosage),'([[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units|unit dose|drop))') = lower(dosage) AND NOT dosage ~ '%' THEN REGEXP_REPLACE(lower(dosage),'[[:digit:]\,\.]+','','g')
         ELSE NULL
       END AS amount_unit,
       CASE
         WHEN (SUBSTRING(lower(dosage),'([[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop))') = lower(dosage) AND SUBSTRING(volume,'[[:digit:]\,\.]+') IS NULL OR dosage ~ '%') THEN REPLACE(SUBSTRING(dosage,'^[[:digit:]\,\.]+'),',','')
         WHEN SUBSTRING(lower(dosage),'([[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop))') = lower(dosage) AND SUBSTRING(volume,'[[:digit:]\,\.]+') IS NOT NULL THEN (SUBSTRING(volume,'[[:digit:]\,\.]+')::NUMERIC*REPLACE(SUBSTRING(dosage,'^[[:digit:]\,\.]+'),',','')::NUMERIC/COALESCE(REPLACE(SUBSTRING(dosage,'/([[:digit:]\,\.]+)'),',','')::NUMERIC,1))::VARCHAR
         ELSE NULL
       END AS numerator_value,
       CASE
         WHEN SUBSTRING(lower(dosage),'([[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop))') = lower(dosage) OR dosage ~ '%' THEN SUBSTRING(lower(dosage),'(mg|%|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|microlitres)')
         ELSE NULL
       END AS numerator_unit,
       CASE
         WHEN (SUBSTRING(dosage,'([[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)|h|square cm|microlitres|unit dose|drop))') = dosage OR dosage ~ '%') AND volume IS NULL THEN REPLACE(SUBSTRING(dosage,'/([[:digit:]\,\.]+)'),',','')
         WHEN volume IS NOT NULL THEN SUBSTRING(volume,'[[:digit:]\,\.]+')
         ELSE NULL
       END AS denominator_value,
       CASE
         WHEN (SUBSTRING(dosage,'([[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|microlitres|hour(s)*|h|square cm|unit dose|drop))') = dosage OR dosage ~ '%') AND volume IS NULL THEN SUBSTRING(dosage,'(g|dose|ml|mg|ampoule|litre|hour(s)*|h*|square cm|microlitres|unit dose|drop)$')
         WHEN volume IS NOT NULL THEN REGEXP_REPLACE(volume,'[[:digit:]\,\.]+','','g')
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
   SET (denominator_value,denominator_unit) = (SELECT DISTINCT b.denominator_value,
                                                      b.denominator_unit
                                               FROM ds_all b
                                               WHERE a.concept_code = b.concept_code
                                               AND   a.denominator_unit IS NULL
                                               AND   (b.denominator_unit IS NOT NULL AND b.denominator_unit != ''))
-- a.numerator_value= a.amount_value,a.numerator_unit= a.amount_unit,a.amount_value = null, a.amount_unit = null
       WHERE EXISTS (SELECT 1
                     FROM ds_all b
                     WHERE a.concept_code = b.concept_code
                     AND   (a.denominator_unit IS NULL OR a.denominator_unit = '')
                     AND   b.denominator_unit IS NOT NULL);

--somehow we get amount +denominator
UPDATE ds_all a
   SET numerator_value = a.amount_value,
       numerator_unit = a.amount_unit,
       amount_value = NULL,
       amount_unit = NULL
WHERE a.denominator_unit IS NOT NULL
AND   numerator_unit IS NULL;

UPDATE ds_all
   SET amount_value = NULL
WHERE amount_value = '.';

/*
CREATE TABLE DS_STAGE
(
   DRUG_CONCEPT_CODE        VARCHAR(255 ),
   INGREDIENT_CONCEPT_CODE  VARCHAR(255 ),
   AMOUNT_VALUE             numeric,
   AMOUNT_UNIT              VARCHAR(255 ),
   NUMERATOR_VALUE          numeric,
   NUMERATOR_UNIT           VARCHAR(255 ),
   DENOMINATOR_VALUE        numeric,
   DENOMINATOR_UNIT         VARCHAR(255 ),
   BOX_SIZE                 int
)
;
*/

UPDATE ds_all
   SET amount_value = NULL,
       amount_unit = NULL
WHERE amount_unit = 'molar';

TRUNCATE TABLE ds_stage;

INSERT INTO ds_stage
(
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
       concept_code,
       ingredient_concept_code,
       amount_value::NUMERIC,
       amount_unit,
       numerator_value::NUMERIC,
       numerator_unit,
       denominator_value::NUMERIC,
       denominator_unit
FROM ds_all;

-- update denominator with existing value for concepts having empty and non-emty denominator value/unit
--fix wierd units
UPDATE ds_stage
   SET amount_unit = 'unit'
WHERE amount_unit IN ('u','iu');

UPDATE ds_stage
   SET numerator_unit = 'unit'
WHERE numerator_unit IN ('u','iu');

UPDATE ds_stage
   SET denominator_unit = NULL
WHERE denominator_unit = 'ampoule';

UPDATE ds_stage
   SET denominator_unit = REPLACE(denominator_unit,' ','')
WHERE denominator_unit LIKE '% %';

DELETE
FROM ds_stage
WHERE ingredient_concept_code = 'Syrup';

DELETE
FROM ds_stage
WHERE 0 IN (numerator_value,amount_value,denominator_value);

--sum up the Zinc undecenoate 20% / Undecenoic acid 5% cream
/*DELETE
FROM ds_stage
WHERE DRUG_CONCEPT_CODE = '1637007'
	AND INGREDIENT_CONCEPT_CODE = 'OMOP1021956'
	AND NUMERATOR_VALUE = 50;

UPDATE ds_stage
SET NUMERATOR_VALUE = 250
WHERE DRUG_CONCEPT_CODE = '1637007'
	AND INGREDIENT_CONCEPT_CODE = 'OMOP1021956'
	AND NUMERATOR_VALUE = 200;*/ 
--percents
--update ds_stage changing % to mg/ml, mg/g, etc.
--simple, when we have denominator_unit so we can define numerator based on denominator_unit
UPDATE ds_stage
   SET numerator_value = denominator_value*numerator_value*10,
       numerator_unit = 'mg'
WHERE numerator_unit = '%'
AND   denominator_unit IN ('ml','gram','g');

UPDATE ds_stage
   SET numerator_value = denominator_value*numerator_value*0.01,
       numerator_unit = 'mg'
WHERE numerator_unit = '%'
AND   denominator_unit IN ('mg');

UPDATE ds_stage
   SET numerator_value = denominator_value*numerator_value*10,
       numerator_unit = 'g'
WHERE numerator_unit = '%'
AND   denominator_unit IN ('litre');

--let's make only %-> mg/ml if denominator is null
UPDATE ds_stage ds
   SET numerator_value = numerator_value*10,
       numerator_unit = 'mg',
       denominator_unit = 'ml'
WHERE numerator_unit = '%'
AND   denominator_unit IS NULL
AND   denominator_value IS NULL;

DELETE
FROM ds_stage
WHERE drug_concept_code IN (SELECT pack_concept_code FROM pc_stage);

/*
--check for non ds_stage cover
select * from thin_need_to_map where gemscript_code not in (select drug_concept_code from ds_stage where drug_concept_code is not null)
 and gemscript_code not in (select gemscript_code from full_manual where gemscript_code is not null) and domain_id = 'Drug' 
and gemscript_code not in (select pack_concept_code from pc_stage where pack_concept_code is not null )
;
*/ 
--apply the dose form updates then to extract them from the original names
--make a proper dose form from the short terms used in a concept_names
UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'oin$','ointment','gi')
WHERE thin_name ilike '%oin';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'ear$','otic solution','gi')
WHERE thin_name ilike '% ear';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'inh$','Metered Dose Inhaler','gi')
WHERE thin_name ilike '%aerosol';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'emulsifying$','ointment','gi')
WHERE thin_name ilike '%emulsifying';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'tab$','tablet','gi')
WHERE thin_name ilike '%tab';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'inj$','injection','gi')
WHERE thin_name ilike '%inj';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'cre$','topical cream','gi')
WHERE thin_name ilike '%cre';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'lin$','linctus','gi')
WHERE thin_name ilike '%lin';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'sol$','solution','gi')
WHERE thin_name ilike '%sol';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'cap$','capsule','gi')
WHERE thin_name ilike '%cap';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'loz$','lozenge','gi')
WHERE thin_name ilike '%loz';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'lozenge$','lozenges','gi')
WHERE thin_name ilike '%lozenge';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'sus$','suspension','gi')
WHERE thin_name ilike '%sus';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'eli$','elixir','gi')
WHERE thin_name ilike '%eli';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'sup$','suppositories','gi')
WHERE thin_name ilike '%sup';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'gra$','granules','gi')
WHERE thin_name ilike '%gra';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'pow$','powder','gi')
WHERE thin_name ilike '%pow';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'pel$','pellets','gi')
WHERE thin_name ilike '%pel';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'lot$','lotion','gi')
WHERE thin_name ilike '%lot';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'pre-filled syr$','pre-filled syringe','gi')
WHERE thin_name ilike '%pre-filled syr';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'syr$','syrup','gi')
WHERE thin_name ilike '%syr';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'app$','applicator','gi')
WHERE thin_name ilike '%app';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'dro$','drops','gi')
WHERE thin_name ilike '%dro';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'aer$','aerosol','gi')
WHERE thin_name ilike '%aer';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'liq$','liquid','gi')
WHERE thin_name ilike '%liq';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'homeopathic pillules$','pillules','gi')
WHERE thin_name ilike '%homeopathic pillules';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'spa$','spansules','gi')
WHERE thin_name ilike '%spa';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'emu$','emulsion','gi')
WHERE thin_name ilike '%emu';

--paste
UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'pas$','paste','gi')
WHERE thin_name ilike '%pas';

--pillules
UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'pills$','pillules','gi')
WHERE thin_name ilike '%pills';

--spray
UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'spr$','spray','gi')
WHERE thin_name ilike '%spr';

--inhalation
UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'inh$','Metered Dose Inhaler','gi')
WHERE thin_name ilike '%inh';

--suppositories
UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'suppository$','rectal suppository','gi')
WHERE thin_name ilike '%suppository';

--oitnment
UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'oitnment$','ointment','gi')
WHERE thin_name ilike '%oitnment';

--pessary
UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'pes$','pessary','gi')
WHERE thin_name ilike '%pes';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'pessary$','pessaries','gi')
WHERE thin_name ilike '%pessary';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'spansules$','capsule','gi')
WHERE thin_name ilike '%spansules';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'globuli$','granules','gi')
WHERE thin_name ilike '%globuli';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'sach$','sachet','gi')
WHERE thin_name ilike '%sach';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'oin$','ointment','gi')
WHERE thin_name ilike '%oin';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'tab$','tablet','gi')
WHERE thin_name ilike '%tab';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'inj$','injection','gi')
WHERE thin_name ilike '%inj';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'cre$','topical cream','gi')
WHERE thin_name ilike '%cre';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'lin$','oral solution','gi')
WHERE thin_name ilike '%lin';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'sol$','solution','gi')
WHERE thin_name ilike '%sol';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'cap$','capsule','gi')
WHERE thin_name ilike '%cap';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'loz$','lozenge','gi')
WHERE thin_name ilike '%loz';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'lozenge$','lozenges','gi')
WHERE thin_name ilike '%lozenge';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'sus$','suspension','gi')
WHERE thin_name ilike '%sus';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'eli$','elixir','gi')
WHERE thin_name ilike '%eli';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'sup$','suppositories','gi')
WHERE thin_name ilike '%sup';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'gra$','granules','gi')
WHERE thin_name ilike '%gra';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'pow$','powder','gi')
WHERE thin_name ilike '%pow';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'pel$','pellets','gi')
WHERE thin_name ilike '%pel';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'lot$','lotion','gi')
WHERE thin_name ilike '%lot';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'pre-filled syr$','pre-filled syringe','gi')
WHERE thin_name ilike '%pre-filled syr';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'syr$','syrup','gi')
WHERE thin_name ilike '%syr';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'app$','applicator','gi')
WHERE thin_name ilike '%app';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'dro$','drops','gi')
WHERE thin_name ilike '%dro';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'aer$','aerosol','gi')
WHERE thin_name ilike '%aer';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'liq$','liquid','gi')
WHERE thin_name ilike '%liq';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'homeopathic pillules$','pillules','gi')
WHERE thin_name ilike '%homeopathic pillules';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'spa$','spansules','gi')
WHERE thin_name ilike '%spa';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'emu$','emulsion','gi')
WHERE thin_name ilike '%emu';

--paste
UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'pas$','paste','gi')
WHERE thin_name ilike '%pas';

--pillules
UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'pills$','pillules','gi')
WHERE thin_name ilike '%pills';

--spray
UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'spr$','spray','gi')
WHERE thin_name ilike '%spr';

--inhalation
UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'inh$','Metered Dose Inhaler','gi')
WHERE thin_name ilike '%inh';

--suppositories
UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'suppository$','rectal suppository','gi')
WHERE thin_name ilike '%suppository';

--oitnment
UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'oitnment$','ointment','gi')
WHERE thin_name ilike '%oitnment';

--pessary
UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'pes$','pessary','gi')
WHERE thin_name ilike '%pes';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'pessary$','pessaries','gi')
WHERE thin_name ilike '%pessary';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'spansules$','capsule','gi')
WHERE thin_name ilike '%spansules';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'globuli$','granules','gi')
WHERE thin_name ilike '%globuli';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'sach$','sachet','gi')
WHERE thin_name ilike '%sach';

UPDATE thin_need_to_map
   SET thin_name = REGEXP_REPLACE(thin_name,'eye$','ophtalmic solution','gi')
WHERE thin_name ilike '% eye';

--now same, gemscript_name
UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'oin$','ointment','gi')
WHERE gemscript_name ilike '%oin';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'ear$','otic solution','gi')
WHERE gemscript_name ilike '% ear';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'inh$','Metered Dose Inhaler','gi')
WHERE gemscript_name ilike '%aerosol';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'tab$','tablet','gi')
WHERE gemscript_name ilike '%tab';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'inj$','injection','gi')
WHERE gemscript_name ilike '%inj';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'cre$','topical cream','gi')
WHERE gemscript_name ilike '%cre';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'lin$','oral solution','gi')
WHERE gemscript_name ilike '%lin';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'sol$','solution','gi')
WHERE gemscript_name ilike '%sol';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'cap$','capsule','gi')
WHERE gemscript_name ilike '%cap';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'loz$','lozenge','gi')
WHERE gemscript_name ilike '%loz';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'lozenge$','lozenges','gi')
WHERE gemscript_name ilike '%lozenge';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'sus$','suspension','gi')
WHERE gemscript_name ilike '%sus';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'eli$','elixir','gi')
WHERE gemscript_name ilike '%eli';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'sup$','suppositories','gi')
WHERE gemscript_name ilike '%sup';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'gra$','granules','gi')
WHERE gemscript_name ilike '%gra';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'pow$','powder','gi')
WHERE gemscript_name ilike '%pow';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'pel$','pellets','gi')
WHERE gemscript_name ilike '%pel';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'lot$','lotion','gi')
WHERE gemscript_name ilike '%lot';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'pre-filled syr$','pre-filled syringe','gi')
WHERE gemscript_name ilike '%pre-filled syr';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'syr$','syrup','gi')
WHERE gemscript_name ilike '%syr';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'app$','applicator','gi')
WHERE gemscript_name ilike '%app';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'dro$','drops','gi')
WHERE gemscript_name ilike '%dro';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'aer$','aerosol','gi')
WHERE gemscript_name ilike '%aer';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'liq$','liquid','gi')
WHERE gemscript_name ilike '%liq';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'homeopathic pillules$','pillules','gi')
WHERE gemscript_name ilike '%homeopathic pillules';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'spa$','spansules','gi')
WHERE gemscript_name ilike '%spa';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'emu$','emulsion','gi')
WHERE gemscript_name ilike '%emu';

--paste
UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'pas$','paste','gi')
WHERE gemscript_name ilike '%pas';

--pillules
UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'pills$','pillules','gi')
WHERE gemscript_name ilike '%pills';

--spray
UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'spr$','spray','gi')
WHERE gemscript_name ilike '%spr';

--inhalation
UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'inh$','Metered Dose Inhaler','gi')
WHERE gemscript_name ilike '%inh';

--suppositories
UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'suppository$','suppositories','gi')
WHERE gemscript_name ilike '%suppository';

--oitnment
UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'oitnment$','ointment','gi')
WHERE gemscript_name ilike '%oitnment';

--pessary
UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'pes$','pessary','gi')
WHERE gemscript_name ilike '%pes';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'pessary$','pessaries','gi')
WHERE gemscript_name ilike '%pessary';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'spansules$','capsule','gi')
WHERE gemscript_name ilike '%spansules';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'globuli$','granules','gi')
WHERE gemscript_name ilike '%globuli';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'sach$','sachet','gi')
WHERE gemscript_name ilike '%sach';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'oin$','ointment','gi')
WHERE gemscript_name ilike '%oin';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'emulsifying$','ointment','gi')
WHERE gemscript_name ilike '%emulsifying';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'tab$','tablet','gi')
WHERE gemscript_name ilike '%tab';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'inj$','injection','gi')
WHERE gemscript_name ilike '%inj';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'cre$','topical cream','gi')
WHERE gemscript_name ilike '%cre';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'lin$','linctus','gi')
WHERE gemscript_name ilike '%lin';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'sol$','solution','gi')
WHERE gemscript_name ilike '%sol';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'cap$','capsule','gi')
WHERE gemscript_name ilike '%cap';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'loz$','lozenge','gi')
WHERE gemscript_name ilike '%loz';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'lozenge$','lozenges','gi')
WHERE gemscript_name ilike '%lozenge';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'sus$','suspension','gi')
WHERE gemscript_name ilike '%sus';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'eli$','elixir','gi')
WHERE gemscript_name ilike '%eli';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'sup$','suppositories','gi')
WHERE gemscript_name ilike '%sup';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'gra$','granules','gi')
WHERE gemscript_name ilike '%gra';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'pow$','powder','gi')
WHERE gemscript_name ilike '%pow';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'pel$','pellets','gi')
WHERE gemscript_name ilike '%pel';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'lot$','lotion','gi')
WHERE gemscript_name ilike '%lot';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'pre-filled syr$','pre-filled syringe','gi')
WHERE gemscript_name ilike '%pre-filled syr';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'syr$','syrup','gi')
WHERE gemscript_name ilike '%syr';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'app$','applicator','gi')
WHERE gemscript_name ilike '%app';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'dro$','drops','gi')
WHERE gemscript_name ilike '%dro';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'aer$','aerosol','gi')
WHERE gemscript_name ilike '%aer';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'liq$','liquid','gi')
WHERE gemscript_name ilike '%liq';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'homeopathic pillules$','pillules','gi')
WHERE gemscript_name ilike '%homeopathic pillules';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'spa$','spansules','gi')
WHERE gemscript_name ilike '%spa';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'emu$','emulsion','gi')
WHERE gemscript_name ilike '%emu';

--paste
UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'pas$','paste','gi')
WHERE gemscript_name ilike '%pas';

--pillules
UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'pills$','pillules','gi')
WHERE gemscript_name ilike '%pills';

--spray
UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'spr$','spray','gi')
WHERE gemscript_name ilike '%spr';

--inhalation
UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'inh$','Metered Dose Inhaler','gi')
WHERE gemscript_name ilike '%inh';

--suppositories
UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'suppository$','suppositories','gi')
WHERE gemscript_name ilike '%suppository';

--oitnment
UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'oitnment$','ointment','gi')
WHERE gemscript_name ilike '%oitnment';

--pessary
UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'pes$','pessary','gi')
WHERE gemscript_name ilike '%pes';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'pessary$','pessaries','gi')
WHERE gemscript_name ilike '%pessary';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'spansules$','capsule','gi')
WHERE gemscript_name ilike '%spansules';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'globuli$','granules','gi')
WHERE gemscript_name ilike '%globuli';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'sach$','sachet','gi')
WHERE gemscript_name ilike '%sach';

UPDATE thin_need_to_map
   SET gemscript_name = REGEXP_REPLACE(gemscript_name,'eye$','ophtalmic solution','gi')
WHERE gemscript_name ilike '% eye';

--Execution time: 3m 28s when "mm" is used

ANALYZE thin_need_to_map;

CREATE INDEX idx_tnm 
  ON thin_need_to_map (thin_name varchar_pattern_ops, gemscript_name varchar_pattern_ops);

CREATE INDEX idx_di 
  ON thin_need_to_map (domain_id);

ANALYZE thin_need_to_map;

DROP TABLE if exists f_map_var;

--explain
CREATE TABLE f_map_var 
AS
(
-- enhanced algorithm added  lower (a.thin_name) like lower '% '||(b.concept_name)||' %'
SELECT *
FROM (SELECT DISTINCT a.*,
             b.concept_id,
             b.concept_name,
             b.vocabulary_id,
             b.concept_code,
             RANK() OVER (PARTITION BY a.gemscript_code ORDER BY LENGTH(b.concept_name) DESC,CASE WHEN b.vocabulary_id = 'dm+d' THEN 1 WHEN b.vocabulary_id = 'GRR' THEN 2 WHEN b.vocabulary_id = 'AMT' THEN 3 WHEN b.vocabulary_id = 'DPD' THEN 4 WHEN b.vocabulary_id = 'BDPM' THEN 5 WHEN b.vocabulary_id = 'LPD_Australia' THEN 6 WHEN b.vocabulary_id = 'AMIS' THEN 7 ELSE 10 END ASC) AS rank1
      FROM thin_need_to_map a
        JOIN concept b
          ON
      --Slow, for some reason?
      --lower (coalesce (a.thin_name, a.GEMSCRIPT_NAME)) ~ ('(' || lower  (' '||b.concept_name||'( |$|s|es)') || ')|(' || lower  (' '||regexp_replace  (b.concept_name, 'y$', 'ies') ||'( |$)') || ')') and 
       (COALESCE (a.thin_name,a.gemscript_name) ilike '% ' ||b.concept_name|| ' %'
          OR COALESCE (a.thin_name,a.gemscript_name) ilike '% ' ||b.concept_name
          OR COALESCE (a.thin_name,a.gemscript_name) ilike '% ' ||b.concept_name || 's%'
          OR COALESCE (a.thin_name,a.gemscript_name) ilike '% ' ||b.concept_name || 'es%'
          OR COALESCE (a.thin_name,a.gemscript_name) ilike '% ' ||regexp_replace (b.concept_name,'y$','ies')
          OR COALESCE (a.thin_name,a.gemscript_name) ilike '% ' ||regexp_replace (b.concept_name,'y$','ies') || ' %')
         AND vocabulary_id IN ('dm+d', 'AMT', 'BDPM', /*'AMIS',*/ /*'DPD',*/ /*'LPD_Australia',*/ 'GRR', 'RxNorm', 'RxNorm Extension') 
         AND concept_class_id IN ('Dose Form', 'Form', 'AU Qualifier') 
         AND a.domain_id = 'Drug'
         AND b.domain_id = 'Drug'
         AND invalid_reason IS NULL
         AND CASE
      --if RxN/E form, make sure it's used in drugs! If it's not, it's guaranteed to have good mappings
      WHEN vocabulary_id NOT IN ('RxNorm', 'RxNorm Extension') THEN TRUE ELSE EXISTS (SELECT FROM concept_relationship r
							JOIN concept c ON
								r.relationship_id = 'RxNorm dose form of' AND
								r.invalid_reason IS NULL AND
								r.concept_id_1 = b.concept_id AND
								r.concept_id_2 = c.concept_id AND
								c.vocabulary_id IN ('RxNorm', 'RxNorm Extension') AND
								c.standard_concept = 'S'
						)
			END) a
--take the longest form
WHERE rank1 = 1);

--mappings 
DROP TABLE if exists forms_mapping;

--use old relationship_to_concept tables to define form mappings with precedence
CREATE TABLE forms_mapping 
AS
SELECT DISTINCT f.concept_name AS concept_code_1,
       map.concept_id_2,
       precedence,
       x.concept_name AS concept_name_2
FROM f_map_var f
  JOIN concept c ON c.concept_id = f.concept_id
  LEFT JOIN form_map_old
-- manual table
map
         ON c.concept_code = LPAD (map.concept_code_1,8,'0')
        AND c.vocabulary_id = vocabulary_id_1
  LEFT JOIN concept x ON x.concept_id = map.concept_id_2
--where x.concept_id is null;

UPDATE forms_mapping
   SET precedence = 1,
       (concept_id_2,
       concept_name_2) = (SELECT concept_id,
                                 concept_name
                          FROM concept
                          WHERE invalid_reason IS NULL
                          AND   LOWER(concept_name) = LOWER(concept_code_1)
                          AND   concept_class_id = 'Dose Form'
                          AND   vocabulary_id IN ('RxNorm','RxNorm Extension'))
WHERE concept_id_2 IS NULL;

UPDATE forms_mapping x
   SET (concept_id_2,concept_name_2) = (SELECT c2.concept_id,
                                               c2.concept_name
                                        FROM concept c
                                          JOIN concept_relationship r
                                            ON c.invalid_reason IS NULL
                                           AND r.invalid_reason IS NULL
                                           AND LOWER (c.concept_name) = LOWER (x.concept_code_1)
                                           AND c.concept_class_id IN ('Dose Form', 'Form', 'AU Qualifier') 
                                           AND r.concept_id_1 = c.concept_id
                                           AND r.relationship_id = 'Source - RxNorm eq'
                                          JOIN concept c2
                                            ON c2.concept_id = r.concept_id_2
                                           AND c2.concept_id NOT IN (19082109, 1592486, 21014177) 
                                           AND c2.invalid_reason IS NULL
                                        ORDER BY devv5.levenshtein(x.concept_name_2,c2.concept_name) ASC LIMIT 1)
WHERE concept_id_2 IS NULL;

--update mappings with precedence using forms equivalents that have multiple mappings
INSERT INTO forms_mapping
SELECT old_name,
       concept_id_2,
       precedence,
       concept_name_2
FROM forms_mapping
  JOIN (SELECT 'Prefilled Syringe' AS old_name,
               'Pen' AS new_name UNION SELECT 'Dry Powder Inhaler',
               'Inhalation powder' UNION SELECT 'Inhalant',
               'Inhalation Solution' UNION SELECT 'Powder Spray',
               'Inhalation powder') aa ON aa.new_name = forms_mapping.concept_code_1;

DELETE
FROM forms_mapping
WHERE concept_code_1 IN (SELECT old_name
                         FROM (SELECT 'Prefilled Syringe' AS old_name,
                                      'Pen' AS new_name UNION SELECT 'Dry Powder Inhaler',
                                      'Inhalation powder' UNION SELECT 'Inhalant',
                                      'Inhalation Solution' UNION SELECT 'Powder Spray',
                                      'Inhalation powder') aa)
AND   concept_id_2 IS NULL;

/*
select * from forms_mapping where concept_code_1 =
'Gel'*/

UPDATE forms_mapping
   SET concept_id_2 = 19082228
WHERE concept_code_1 = 'Application'
AND   precedence = 1;

--fix inacurracies
UPDATE forms_mapping
   SET precedence = 4
WHERE concept_code_1 = 'Gel'
AND   concept_id_2 = 19010880;

INSERT INTO forms_mapping
(
  concept_code_1,
  concept_id_2,
  precedence,
  concept_name_2
)
VALUES
(
  'Gel',
  19095973,
  1,
  'Topical Gel'
);

--algorithm for forms make ambiguities when there are two forms with the same length in within one vocabulary
DELETE
FROM f_map_var
WHERE gemscript_code = '104007'
AND   concept_id = 21215788;

DELETE
FROM f_map_var
WHERE gemscript_code = '54128020'
AND   concept_id = 43360666;

DELETE
FROM f_map_var
WHERE gemscript_code = '58583020'
AND   concept_id = 43360666;

DELETE
FROM f_map_var
WHERE gemscript_code = '61770020'
AND   concept_id = 21308470;

DELETE
FROM f_map_var
WHERE gemscript_code = '76284020'
AND   concept_id = 21308470;

COMMIT;

--make Suppliers, some clean up
UPDATE thin_need_to_map
   SET gemscript_name = gemscript_name || ')'
WHERE gemscript_name LIKE '%(Neon Diagnostics';

DROP TABLE IF EXISTS s_rel;

CREATE TABLE s_rel 
AS
SELECT SUBSTRING(gemscript_name,'\(([A-Z].+)\)$') AS supplier,
       n.*
FROM thin_need_to_map n
WHERE domain_id = 'Drug';

DROP TABLE IF EXISTS s_map;

CREATE TABLE s_map 
AS
WITH pick_one
AS
(SELECT DISTINCT s.gemscript_code,
       s.gemscript_name,
       sss.concept_id_2,
       concept_name_2,
       vocabulary_id_2
FROM s_rel s
  JOIN concept c ON lower (s.supplier) = lower (c.concept_name)
  JOIN (SELECT c.concept_id AS source_id,
               COALESCE(d.concept_name,c.concept_name) AS concept_name_2,
               COALESCE(d.concept_id,c.concept_id) AS concept_id_2,
               COALESCE(d.vocabulary_id,c.vocabulary_id) AS vocabulary_id_2
        FROM concept c
          LEFT JOIN (SELECT concept_id_1,
                            relationship_id,
                            concept_id_2
                     FROM concept_relationship
                     WHERE invalid_reason IS NULL
                     UNION
                     SELECT concept_id_1,
                            relationship_id,
                            concept_id_2
                     FROM rel_to_conc_old) r
                 ON c.concept_id = r.concept_id_1
                AND relationship_id = 'Source - RxNorm eq'
          LEFT JOIN concept d
                 ON d.concept_id = r.concept_id_2
                AND d.vocabulary_id LIKE 'RxNorm%'
                AND d.invalid_reason IS NULL
                AND d.concept_class_id = 'Supplier'
        WHERE c.concept_class_id IN ('Supplier')
        AND   c.invalid_reason IS NULL) sss
    ON sss.source_id = c.concept_id
   AND sss.vocabulary_id_2 IN ('RxNorm', 'RxNorm Extension') 
--not clear, need to fix in the future
WHERE c.concept_class_id = 'Supplier'),preferred AS (SELECT DISTINCT s.gemscript_code,
                                                            s.gemscript_name,
                                                            --s.concept_id_2,
                                                            FIRST_VALUE(s.concept_id_2) OVER (PARTITION BY s.gemscript_code ORDER BY LENGTH(s.concept_name_2) DESC) AS concept_id_2
                                                     FROM pick_one s) SELECT DISTINCT i.*FROM pick_one i JOIN preferred p USING (gemscript_code,concept_id_2);

--make Brand Names
--select * from thin_need_to_map where thin_name like 'Generic%';
CREATE INDEX gemscript_name_idx 
  ON thin_need_to_map  USING gin(gemscript_name devv5.gin_trgm_ops);

CREATE INDEX thin_name_idx 
  ON thin_need_to_map  USING gin(thin_name devv5.gin_trgm_ops);

ANALYZE thin_need_to_map;

DROP TABLE IF EXISTS b_map_0;

CREATE TABLE b_map_0 
AS
SELECT t.gemscript_code,
       t.gemscript_name,
       t.thin_code,
       t.thin_name,
       c.concept_id,
       c.concept_name,
       c.vocabulary_id
FROM thin_need_to_map t
  JOIN concept c ON gemscript_name ilike c.concept_name || ' %'
WHERE c.concept_class_id = 'Brand Name'
AND   invalid_reason IS NULL
AND   vocabulary_id IN ('RxNorm','RxNorm Extension')
--exclude ingredients that accindentally got into Brand Names massive
AND   lower(c.concept_name) NOT IN (SELECT LOWER(concept_name)
                                    FROM concept
                                    WHERE concept_class_id = 'Ingredient'
                                    AND   invalid_reason IS NULL)
AND   t.domain_id = 'Drug'
AND   c.concept_name NOT IN ('Gamma','Mst','Gx','Simple','Saline','DF','Stibium');

DROP TABLE IF EXISTS b_map_1;

CREATE TABLE b_map_1 
AS
SELECT t.gemscript_code,
       t.gemscript_name,
       t.thin_code,
       t.thin_name,
       c.concept_id,
       c.concept_name,
       c.vocabulary_id
FROM thin_need_to_map t
  JOIN concept c ON thin_name ilike c.concept_name || ' %'
  LEFT JOIN b_map_0 b ON b.gemscript_code = t.gemscript_code
WHERE c.concept_class_id = 'Brand Name'
AND   c.invalid_reason IS NULL
AND   c.vocabulary_id IN ('RxNorm','RxNorm Extension')
--exclude ingredients that accindally got into Brand Names massive
AND   lower(c.concept_name) NOT IN (SELECT LOWER(concept_name)
                                    FROM concept
                                    WHERE concept_class_id = 'Ingredient'
                                    AND   invalid_reason IS NULL)
AND   t.domain_id = 'Drug'
AND   b.gemscript_code IS NULL
AND   c.concept_name NOT IN ('Natrum muriaticum','Pulsatilla nigricans','Multivitamin','Saline','Simple');

DROP INDEX gemscript_name_idx;

DROP INDEX thin_name_idx;

DROP TABLE IF EXISTS b_map;

CREATE TABLE b_map 
AS
SELECT *
FROM (SELECT z.*,
             RANK() OVER (PARTITION BY gemscript_code ORDER BY LENGTH(concept_name) DESC) AS rank1
      FROM (SELECT * FROM b_map_0 UNION SELECT * FROM b_map_1) z
      WHERE z.vocabulary_id IN ('RxNorm','RxNorm Extension')
      --not clear, need to fix in the future) x
WHERE x.rank1 = 1;

--making input tables
TRUNCATE TABLE drug_concept_stage;

--Drug Product
INSERT INTO drug_concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date,
  invalid_reason,
  source_concept_class_id
)
SELECT DISTINCT gemscript_name,
       domain_id,
       'Gemscript',
       'Drug Product',
       NULL,
       gemscript_code,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       -- TRUNC(SYSDATE)
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL,
       'Gemscript'
FROM thin_need_to_map
WHERE domain_id = 'Drug'
AND   gemscript_code NOT LIKE 'OMOP%'
UNION ALL
SELECT DISTINCT concept_name,
       'Drug',
       'Gemscript',
       'Drug Product',
       NULL,
       concept_code,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       -- TRUNC(SYSDATE)
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL,
       'Gemscript'
FROM packcomp_wcodes;

--Device
INSERT INTO drug_concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date,
  invalid_reason,
  source_concept_class_id
)
SELECT DISTINCT gemscript_name,
       domain_id,
       'Gemscript',
       'Device',
       'S',
       gemscript_code,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       -- TRUNC(SYSDATE)
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL,
       'Gemscript'
FROM thin_need_to_map
WHERE domain_id = 'Device';

--replace pc_stage component codes with their assigned OMOP% codes
UPDATE pc_stage p
   SET drug_concept_code = (SELECT concept_code
                            FROM drug_concept_stage
                            WHERE concept_name = p.drug_concept_code
                            AND   concept_code LIKE 'OMOP%'
                            AND   concept_class_id = 'Drug Product');

--Ingredient
INSERT INTO drug_concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date,
  invalid_reason,
  source_concept_class_id
)
SELECT DISTINCT ingredient_concept_name,
       'Drug',
       'Gemscript',
       'Ingredient',
       NULL,
       ingredient_concept_code,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       -- TRUNC(SYSDATE)
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL,
       'Gemscript'
FROM ds_all_tmp;

--only 1041 --looks susprecious
--Supplier
INSERT INTO drug_concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date,
  invalid_reason,
  source_concept_class_id
)
SELECT DISTINCT concept_name_2,
       'Drug',
       'Gemscript',
       'Supplier',
       NULL,
       concept_name_2,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       -- TRUNC(SYSDATE)
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL,
       'Gemscript'
FROM s_map;

--Dose Form
INSERT INTO drug_concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date,
  invalid_reason,
  source_concept_class_id
)
SELECT DISTINCT concept_code_1,
       'Drug',
       'Gemscript',
       'Dose Form',
       NULL,
       concept_code_1,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       -- TRUNC(SYSDATE)
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL,
       'Dose Form'
FROM forms_mapping;

DROP TABLE if exists b_coded;

CREATE TABLE b_coded 
AS
SELECT 'OMOP' || nextval('code_seq') AS concept_code,
       concept_name
FROM (SELECT DISTINCT concept_name FROM b_map) b0;

--Brand Name
INSERT INTO drug_concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date,
  invalid_reason,
  source_concept_class_id
)
SELECT concept_name,
       'Drug',
       'Gemscript',
       'Brand Name',
       NULL,
       concept_code,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       -- TRUNC(SYSDATE)
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL,
       'Gemscript'
FROM b_coded;

INSERT INTO drug_concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date,
  invalid_reason,
  source_concept_class_id
)
SELECT DISTINCT concept_name,
       'Drug',
       'Gemscript',
       'Unit',
       NULL,
       concept_name,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'Gemscript') AS valid_start_date,
       -- TRUNC(SYSDATE)
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL,
       'Gemscript'
FROM unit_list;

DROP TABLE if exists internal_relationship_stage;

CREATE TABLE internal_relationship_stage 
(
  concept_code_1   VARCHAR(550),
  concept_code_2   VARCHAR(550)
);

--internal_relationship_stage
INSERT INTO internal_relationship_stage
SELECT gemscript_code,
       concept_name
FROM b_map
UNION
SELECT gemscript_code,
       concept_name
FROM f_map_var
UNION
SELECT gemscript_code,
       concept_name_2
FROM s_map
UNION
SELECT DISTINCT concept_code,
       ingredient_concept_code
FROM ds_all_tmp;

TRUNCATE TABLE relationship_to_concept;

INSERT INTO relationship_to_concept
(
  concept_code_1,
  concept_id_2,
  precedence,
  conversion_factor
)
--existing concepts used in mappings
--bug in RxE, so take the first_value of concept_id_2
SELECT DISTINCT concept_code_1,
       FIRST_VALUE(concept_id_2) OVER (PARTITION BY concept_code_1,precedence,conversion_factor ORDER BY concept_id_2) AS concept_id_2,
       precedence,
       conversion_factor
FROM (SELECT concept_name AS concept_code_1,
             concept_id AS concept_id_2,
             1 AS precedence,
             1 AS conversion_factor
      FROM b_map
      UNION
      SELECT concept_code_1,
             concept_id_2,
             precedence,
             1
      FROM forms_mapping
      UNION
      SELECT concept_name_2,
             concept_id_2,
             1,
             1
      FROM s_map
        JOIN drug_concept_stage
          ON concept_name_2 = concept_code
         AND concept_class_id = 'Supplier'
      UNION
      SELECT ingredient_concept_code,
             ingredient_id,
             1,
             1
      FROM ds_all_tmp
      WHERE ingredient_id IS NOT NULL
      UNION
      --add units from dm+D
      SELECT concept_code_1,
             concept_id_2,
             precedence,
             conversion_factor
      FROM unit_map) AS s0;

--need to change the mapping from mcg to 0.001 mg
UPDATE relationship_to_concept
   SET concept_id_2 = 8576,
       conversion_factor = 0.001
WHERE concept_code_1 = 'mcg';

UPDATE relationship_to_concept
   SET concept_id_2 = 19069149
WHERE concept_id_2 = 46274409;

--mapping to U instead of iU
UPDATE relationship_to_concept
   SET concept_id_2 = 8510
WHERE concept_id_2 = 8718;

--RxE builder requires Ingredients used in relationships to be a standard
UPDATE drug_concept_stage
   SET standard_concept = 'S'
WHERE concept_class_id = 'Ingredient';

--ds_stage shouldn't have empty dosage
DELETE
FROM ds_stage
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage
                            WHERE COALESCE(amount_value,numerator_value,0) = 0
                            -- needs to have at least one value, zeros don't count
                            OR    COALESCE(amount_unit,numerator_unit) IS NULL
                            -- needs to have at least one unit
                            OR    (amount_value IS NOT NULL AND amount_unit IS NULL)
                            -- if there is an amount record, there must be a unit
                            OR    (COALESCE(numerator_value,0) != 0 AND COALESCE(numerator_unit,denominator_unit) IS NULL)
                            -- if there is a concentration record there must be a unit in both numerator and denominator
                            OR    amount_unit = '%'
                            -- % should be in the numerator_unit);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = '4915007'
AND   concept_code_2 = 'Chewing Gum';

/*
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
*/ 
--Marketed Product must have strength and dose form otherwise Supplier needs to be removed
DELETE
FROM internal_relationship_stage
WHERE (concept_code_1,concept_code_2) IN (SELECT irs.concept_code_1,
                                                 irs.concept_code_2
                                          FROM internal_relationship_stage irs
                                            JOIN drug_concept_stage
                                              ON concept_code_2 = concept_code
                                             AND concept_class_id = 'Supplier'
                                            LEFT JOIN ds_stage ds ON drug_concept_code = irs.concept_code_1
                                            LEFT JOIN (SELECT concept_code_1
                                                       FROM internal_relationship_stage
                                                         JOIN drug_concept_stage
                                                           ON concept_code_2 = concept_code
                                                          AND concept_class_id = 'Dose Form') rf ON rf.concept_code_1 = irs.concept_code_1
                                          WHERE ds.drug_concept_code IS NULL
                                          OR    rf.concept_code_1 IS NULL);

--some ds_stage update
UPDATE ds_stage a
   SET denominator_unit = (SELECT DISTINCT b.denominator_unit
                           FROM ds_stage b
                           WHERE a.drug_concept_code = b.drug_concept_code
                           AND   a.denominator_unit IS NULL
                           AND   b.denominator_unit IS NOT NULL)
WHERE EXISTS (SELECT 1
              FROM ds_stage b
              WHERE a.drug_concept_code = b.drug_concept_code
              AND   a.denominator_unit IS NULL
              AND   b.denominator_unit IS NOT NULL);

UPDATE ds_stage a
   SET numerator_value = a.amount_value,
       numerator_unit = a.amount_unit,
       amount_value = NULL,
       amount_unit = NULL
WHERE a.denominator_unit IS NOT NULL
AND   numerator_unit IS NULL;

--for further work with CNDV and then mapping creation roundabound, make copies of existing concept_stage and concept_relationship_stage
DROP TABLE IF EXISTS basic_concept_stage;

CREATE TABLE basic_concept_stage 
AS
SELECT *
FROM concept_stage;

DROP TABLE IF EXISTS basic_con_rel_stage;

CREATE TABLE basic_con_rel_stage 
AS
SELECT *
FROM concept_relationship_stage;

-- UPDATE ds_stage
-- SET DENOMINATOR_VALUE = 30
-- WHERE DRUG_CONCEPT_CODE = '4231007'
-- 	AND DENOMINATOR_VALUE IS NULL;
/*
SELECT *
FROM drug_concept_stage
WHERE concept_name IN (
		'Eftrenonacog alfa 250unit powder / solvent for solution for injection vials',
		'Odefsey 200mg/25mg/25mg tablets (Gilead Sciences International Ltd)',
		'Insuman rapid 100iu/ml Injection (Aventis Pharma)',
		'Engerix b 10microgram/0.5ml Paediatric vaccination (GlaxoSmithKline UK Ltd)',
		'Ethyloestranol 2mg Tablet'
		);
*/ 
--clean up
--ds_stage was parsed wrongly by some reasons
UPDATE ds_stage
   SET amount_value = NULL,
       amount_unit = NULL,
       numerator_value = 10000000,
       numerator_unit = 'unit',
       denominator_value = 1,
       denominator_unit = 'ml'
WHERE drug_concept_code = '94291020'
AND   numerator_value IS NULL
AND   numerator_unit IS NULL;

UPDATE ds_stage
   SET numerator_value = 4,
       numerator_unit = 'mg'
WHERE drug_concept_code = '49537020'
AND   numerator_value = 8
AND   numerator_unit = 'ml';

UPDATE ds_stage
   SET numerator_value = 30,
       numerator_unit = 'mg'
WHERE drug_concept_code = '81443020'
AND   numerator_value = 10
AND   numerator_unit = 'ml';

UPDATE ds_stage
   SET amount_value = NULL,
       amount_unit = NULL,
       numerator_value = 6000000,
       numerator_unit = 'unit',
       denominator_value = 1,
       denominator_unit = 'ml'
WHERE drug_concept_code = '80015020'
AND   numerator_value IS NULL
AND   numerator_unit IS NULL;

UPDATE ds_stage
   SET numerator_value = 40,
       numerator_unit = 'mg'
WHERE drug_concept_code = '58170020'
AND   numerator_value = 20
AND   numerator_unit = 'ml';

UPDATE ds_stage
   SET numerator_unit = 'mg'
WHERE drug_concept_code = '58166020'
AND   numerator_value = 50
AND   numerator_unit = 'ml';

UPDATE ds_stage
   SET amount_value = NULL,
       amount_unit = NULL,
       numerator_value = 50,
       numerator_unit = 'mcg',
       denominator_value = 5,
       denominator_unit = 'ml'
WHERE drug_concept_code = '67456020'
AND   numerator_value IS NULL
AND   numerator_unit IS NULL;

UPDATE ds_stage
   SET numerator_value = 10,
       numerator_unit = 'mg'
WHERE drug_concept_code = '58165020'
AND   numerator_value = 20
AND   numerator_unit = 'ml';

DELETE
FROM ds_stage
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage
                              JOIN thin_need_to_map ON gemscript_code = drug_concept_code
                            WHERE LOWER(numerator_unit) IN ('ml')
                            OR    LOWER(amount_unit) IN ('ml'));

DELETE
FROM ds_stage
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage s
                              JOIN drug_concept_stage a
                                ON a.concept_code = s.drug_concept_code
                               AND a.concept_class_id = 'Device');

DELETE
FROM drug_concept_stage
WHERE concept_name = 'Syrup'
AND   concept_class_id = 'Ingredient';

DELETE
FROM drug_concept_stage
WHERE concept_name = 'Stibium'
AND   concept_class_id = 'Brand Name';

DELETE
FROM ds_stage
WHERE drug_concept_code = '63620020';

UPDATE relationship_to_concept
   SET concept_id_2 = 21020188
WHERE concept_id_2 = 19131170;

DELETE
FROM relationship_to_concept
WHERE concept_id_2 IN (SELECT concept_id_2
                       FROM relationship_to_concept
                         JOIN concept ON concept_id = concept_id_2
                       WHERE invalid_reason IS NOT NULL);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN ('74777020','66641020','74778020')
AND   concept_code_2 IN (SELECT concept_code
                         FROM drug_concept_stage
                         WHERE concept_name = 'Colgate'
                         AND   concept_class_id = 'Brand Name');

/*DELETE
FROM ds_stage
WHERE DRUG_CONCEPT_CODE = '80989020'
	AND NUMERATOR_VALUE = 10.8;*/ 
DELETE
FROM ds_stage
WHERE drug_concept_code = '98751020'
AND   numerator_value = 30;

/*UPDATE ds_stage
SET NUMERATOR_VALUE = 35.2
WHERE DRUG_CONCEPT_CODE = '80989020'
	AND NUMERATOR_VALUE = 24.4;*/ 
UPDATE ds_stage
   SET numerator_value = 110
WHERE drug_concept_code = '98751020'
AND   numerator_value = 80;

DELETE
FROM drug_concept_stage
WHERE concept_name = 'Colgate'
AND   concept_class_id = 'Brand Name';

DELETE
FROM ds_stage
WHERE drug_concept_code IN (SELECT ds.drug_concept_code
                            FROM concept c
                              JOIN relationship_to_concept rc2 ON concept_id_2 = concept_id
                              JOIN internal_relationship_stage irs ON rc2.concept_code_1 = irs.concept_code_2
                              JOIN ds_stage ds ON ds.drug_concept_code = irs.concept_code_1
                              JOIN relationship_to_concept rtc
                                ON amount_unit = rtc.concept_code_1
                               AND rtc.concept_id_2 IN (9324, 9325)
	WHERE NOT (c.concept_name LIKE '%Tablet%' OR c.concept_name LIKE '%Capsule%' OR c.concept_name LIKE '%Lozenge%')
                            AND   c.concept_class_id = 'Dose Form'
                            AND   c.vocabulary_id LIKE 'Rx%');

UPDATE relationship_to_concept
   SET concept_id_2 = 8587,
       conversion_factor = 1000
WHERE concept_code_1 = 'litre';

DELETE
FROM drug_concept_stage
WHERE concept_class_id = 'Unit'
AND   NOT EXISTS (SELECT
                  FROM ds_stage
                  WHERE concept_code IN (amount_unit,numerator_unit,denominator_unit));

UPDATE ds_stage
   SET amount_unit = 'g'
WHERE amount_unit = 'gm';

DELETE
FROM drug_concept_stage
WHERE concept_name = 'BioCare'
AND   concept_class_id = 'Brand Name'
-- not a brand name, supplier;;

UPDATE relationship_to_concept
   SET concept_id_2 = 21014279
WHERE concept_code_1 IN (SELECT concept_code
                         FROM drug_concept_stage
                         WHERE concept_name = 'BioCare');

--fix gonadotropins
DELETE
FROM ds_stage
WHERE ingredient_concept_code = (SELECT concept_code
                                 FROM drug_concept_stage
                                 WHERE concept_class_id = 'Ingredient'
                                 AND   concept_name = 'Menotrophin');

INSERT INTO internal_relationship_stage
SELECT concept_code_1,
       'Chorionic Gonadotropin'
FROM internal_relationship_stage
WHERE concept_code_2 = (SELECT concept_code
                        FROM drug_concept_stage
                        WHERE concept_class_id = 'Ingredient'
                        AND   concept_name = 'Menotrophin')
UNION
SELECT concept_code_1,
       'Luteinizing Hormone'
FROM internal_relationship_stage
WHERE concept_code_2 = (SELECT concept_code
                        FROM drug_concept_stage
                        WHERE concept_class_id = 'Ingredient'
                        AND   concept_name = 'Menotrophin');

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 = (SELECT concept_code
                        FROM drug_concept_stage
                        WHERE concept_class_id = 'Ingredient'
                        AND   concept_name = 'Menotrophin');

DELETE
FROM drug_concept_stage
WHERE concept_class_id = 'Ingredient'
AND   concept_name IN ('Menotrophin');

UPDATE relationship_to_concept
   SET concept_id_2 = (SELECT concept_id_2
                       FROM relationship_to_concept
                       WHERE concept_code_1 = (SELECT concept_code
                                               FROM drug_concept_stage
                                               WHERE concept_class_id = 'Ingredient'
                                               AND   concept_name = 'Luteinizing Hormone'))
WHERE concept_code_1 = (SELECT concept_code
                        FROM drug_concept_stage
                        WHERE concept_class_id = 'Ingredient'
                        AND   concept_name = 'human menopausal gonadotrophin');

--fix precise ingredients
UPDATE relationship_to_concept r
   SET concept_id_2 = (SELECT concept_id_2
                       FROM concept_relationship
                       WHERE concept_id_1 = r.concept_id_2
                       AND   relationship_id = 'Form of'
                       AND   invalid_reason IS NULL)
WHERE EXISTS (SELECT
              FROM concept c
              WHERE c.concept_id = r.concept_id_2
              AND   c.concept_class_id = 'Precise Ingredient');

DROP TABLE if exists dsinsert;

CREATE TABLE dsinsert 
AS
SELECT DISTINCT drug_concept_code,
       ingredient_concept_code,
       SUM(amount_value) OVER (PARTITION BY drug_concept_code,ingredient_concept_code) AS amount_value,
       amount_unit,
       SUM(numerator_value) OVER (PARTITION BY drug_concept_code,ingredient_concept_code) AS numerator_value,
       numerator_unit,
       denominator_value,
       denominator_unit,
       box_size
FROM ds_stage
WHERE (drug_concept_code,ingredient_concept_code) IN (SELECT drug_concept_code,
                                                             ingredient_concept_code
                                                      FROM ds_stage
                                                      GROUP BY drug_concept_code,
                                                               ingredient_concept_code
                                                      HAVING COUNT(1) > 1);

DELETE
FROM ds_stage
WHERE (drug_concept_code,ingredient_concept_code) IN (SELECT drug_concept_code,
                                                             ingredient_concept_code
                                                      FROM ds_stage
                                                      GROUP BY drug_concept_code,
                                                               ingredient_concept_code
                                                      HAVING COUNT(1) > 1);

INSERT INTO ds_stage
SELECT *
FROM dsinsert;

/*UPDATE ds_stage
   SET ingredient_concept_code = ( select concept_code from drug_concept_stage where concept_class_id = 'Ingredient' and concept_name = 'sodium phosphate')
WHERE drug_concept_code = '80989020';

UPDATE internal_relationship_stage
   SET concept_code_2 = ( select concept_code from drug_concept_stage where concept_class_id = 'Ingredient' and concept_name = 'sodium phosphate')
WHERE concept_code_1 = '80989020' and concept_code_2 in (select concept_code from drug_concept_stage where concept_class_id = 'Ingredient')*/

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = '04231007'
AND   concept_code_2 IN (SELECT concept_code
                         FROM drug_concept_stage
                         WHERE concept_class_id = 'Ingredient'
                         AND   concept_name = 'Prilocaine');

DELETE
FROM ds_stage
WHERE drug_concept_code = '04231007'
AND   ingredient_concept_code IN (SELECT concept_code
                                  FROM drug_concept_stage
                                  WHERE concept_class_id = 'Ingredient'
                                  AND   concept_name = 'Prilocaine');

UPDATE ds_stage d
   SET numerator_value = d.numerator_value / 10,
       denominator_unit = 'g'
WHERE denominator_unit = 'ml'
AND   EXISTS (SELECT
              FROM ds_stage x
              WHERE x.drug_concept_code = d.drug_concept_code
              AND   denominator_unit = 'g');

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (SELECT concept_code
                         FROM drug_concept_stage
                         WHERE concept_name = 'n');

DELETE
FROM drug_concept_stage
WHERE concept_name = 'n';

--RxE duplicate
DELETE
FROM internal_relationship_stage
WHERE concept_code_2 = (SELECT concept_code
                        FROM drug_concept_stage
                        WHERE concept_name = 'Novomix');

DELETE
FROM drug_concept_stage
WHERE concept_name = 'Novomix';

--duplicating forms, delete non-preferrable
DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (SELECT concept_code_1
                         FROM drug_concept_stage,
                              internal_relationship_stage
                         WHERE concept_code = concept_code_2
                         AND   concept_name IN ('Injection','Cream')
                         AND   concept_class_id = 'Dose Form')
AND   concept_code_2 IN (SELECT concept_code
                         FROM drug_concept_stage
                         WHERE concept_class_id = 'Dose Form'
                         AND   concept_name NOT IN ('Injection','Cream'));

DELETE
FROM relationship_to_concept x
WHERE EXISTS (SELECT
              FROM relationship_to_concept
              WHERE concept_code_1 = x.concept_code_1
              AND   concept_id_2 = x.concept_id_2
              AND   precedence > x.precedence);

UPDATE internal_relationship_stage i
   SET concept_code_2 = (SELECT concept_code
                         FROM b_coded
                         WHERE concept_name = i.concept_code_2)
WHERE concept_code_2 IN (SELECT concept_name FROM b_coded);

UPDATE relationship_to_concept
   SET concept_code_1 = (SELECT concept_code
                         FROM b_coded
                         WHERE concept_name = concept_code_1)
WHERE concept_code_1 IN (SELECT concept_name FROM b_coded);

DELETE
FROM drug_concept_stage
WHERE concept_name IS NULL;

UPDATE relationship_to_concept
   SET concept_id_2 = (SELECT concept_id
                       FROM concept
                       WHERE concept_name = 'Arjun'
                       AND   concept_class_id = 'Brand Name'
                       AND   vocabulary_id = 'RxNorm Extension'
                       AND   invalid_reason IS NULL)
WHERE concept_code_1 = (SELECT concept_code
                        FROM drug_concept_stage
                        WHERE concept_name = 'Arjun'
                        AND   concept_class_id = 'Brand Name');

DELETE
FROM ds_stage
WHERE drug_concept_code IN ('80989020','46313020');

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN ('80989020','46313020')
AND   concept_code_2 IN (SELECT concept_code
                         FROM drug_concept_stage
                         WHERE concept_class_id = 'Ingredient');

INSERT INTO internal_relationship_stage
SELECT '80989020',
       concept_code
FROM drug_concept_stage
WHERE concept_name LIKE 'Sodium Phosphate,%'
AND   concept_class_id = 'Ingredient'
UNION
SELECT '46313020',
       concept_code
FROM drug_concept_stage
WHERE concept_name LIKE 'Sodium Phosphate,%'
AND   concept_class_id = 'Ingredient';

DELETE
FROM drug_concept_stage
WHERE concept_class_id IN ('Ingredient','Brand Name','Dose Form','Supplier')
AND   concept_code NOT IN (SELECT concept_code_2 FROM internal_relationship_stage);

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 NOT IN (SELECT concept_code FROM drug_concept_stage);

DELETE
FROM relationship_to_concept
WHERE concept_code_1 NOT IN (SELECT concept_code FROM drug_concept_stage);

UPDATE relationship_to_concept
   SET concept_id_2 = 19010880
WHERE concept_code_1 = 'Jelly';

INSERT INTO internal_relationship_stage
SELECT concept_code,
       'Tablet'
FROM drug_concept_stage
WHERE concept_name = 'inert ingredient tablet';

/*
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
values
	(
		'Inert Ingredients',
		'Drug',
		'Gemscript',
		'Ingredient',
		'S',
		'OMOP' || nextval('code_seq'),
		(
			SELECT latest_update
			FROM vocabulary
			WHERE vocabulary_id = 'Gemscript'
			), -- TRUNC(SYSDATE)
		to_date('20991231', 'yyyymmdd'),
		NULL,
		'Gemscript'
	)
;*/ 
-- select * from drug_concept_stage where concept_name = 'Inert Ingredients'

INSERT INTO internal_relationship_stage
VALUES
(
  (SELECT concept_code
   FROM drug_concept_stage
   WHERE concept_name = 'inert ingredient tablet'),
  (SELECT concept_code
   FROM drug_concept_stage
   WHERE concept_name = 'Inert Ingredients');

INSERT INTO ds_stage
VALUES
(
  (SELECT concept_code
   FROM drug_concept_stage
   WHERE concept_name = 'inert ingredient tablet'),
  (SELECT concept_code
   FROM drug_concept_stage
   WHERE concept_name = 'Inert Ingredients'),
  0,
  'mg',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL
);

/*insert into relationship_to_concept
values
(
	(
		select concept_code from drug_concept_stage where concept_name = 'Inert Ingredients'
	),
	'dm+d',
	19127890,
	1,
	1
)
;*/ 
--fixes for unused RxN forms

UPDATE relationship_to_concept
   SET concept_id_2 = 19082229
WHERE concept_code_1 = 'Patch';

UPDATE relationship_to_concept
   SET concept_id_2 = 19082170
WHERE concept_code_1 = 'Syrup';

UPDATE relationship_to_concept
   SET concept_id_2 = 19082168
WHERE concept_code_1 = 'Capsule';

UPDATE relationship_to_concept
   SET concept_id_2 = 19082170
WHERE concept_code_1 = 'Elixir';

UPDATE relationship_to_concept
   SET concept_id_2 = 19082227
WHERE concept_code_1 = 'Ointment';

UPDATE relationship_to_concept
   SET concept_id_2 = 19082103
WHERE concept_code_1 = 'Solution';

UPDATE relationship_to_concept
   SET concept_id_2 = 19082258
WHERE concept_code_1 = 'Gas';

UPDATE relationship_to_concept
   SET concept_id_2 = 19082200
WHERE concept_code_1 = 'Suppository';

UPDATE relationship_to_concept
   SET concept_id_2 = 19082225
WHERE concept_code_1 = 'Lotion';

UPDATE relationship_to_concept
   SET concept_id_2 = 19082573
WHERE concept_code_1 = 'Tablet';

UPDATE relationship_to_concept
   SET concept_id_2 = 19082170
WHERE concept_code_1 = 'Liquid';

UPDATE relationship_to_concept
   SET concept_id_2 = 19082574
WHERE concept_code_1 = 'Foam';

UPDATE relationship_to_concept
   SET concept_id_2 = 19095912
WHERE concept_code_1 = 'Spray';

UPDATE relationship_to_concept
   SET concept_id_2 = 19082224
WHERE concept_code_1 = 'Cream';

INSERT INTO relationship_to_concept
(
  concept_code_1,
  vocabulary_id_1,
  concept_id_2,
  precedence,
  conversion_factor
)
VALUES
(
  'Capsule',
  NULL,
  19082255,
  2,
  1
);

INSERT INTO relationship_to_concept
(
  concept_code_1,
  vocabulary_id_1,
  concept_id_2,
  precedence,
  conversion_factor
)
VALUES
(
  'Capsule',
  NULL,
  19082077,
  3,
  1
);

INSERT INTO relationship_to_concept
(
  concept_code_1,
  vocabulary_id_1,
  concept_id_2,
  precedence,
  conversion_factor
)
VALUES
(
  'Tablet',
  NULL,
  19001949,
  2,
  1
);

INSERT INTO relationship_to_concept
(
  concept_code_1,
  vocabulary_id_1,
  concept_id_2,
  precedence,
  conversion_factor
)
VALUES
(
  'Tablet',
  NULL,
  19082079,
  3,
  1
);

--x mg / 5 ml is suspicious and rarely correct
UPDATE ds_stage
   SET numerator_value = numerator_value / 5,
       denominator_value = NULL
WHERE denominator_value = 5
AND   denominator_unit = 'ml';

DROP TABLE if exists bdf2b;

--forms guessing: ingredient +, brand name +, dose form -
CREATE TABLE bdf2b 
AS
SELECT DISTINCT c0.concept_code AS drug_concept_code,
       c0.concept_name AS drug_concept_name,
       cx.concept_id AS brand_id,
       cx.concept_name AS brand_name
FROM internal_relationship_stage r1
  JOIN drug_concept_stage ci
    ON ci.concept_class_id = 'Ingredient'
   AND ci.concept_code = r1.concept_code_2
  JOIN drug_concept_stage c0 ON c0.concept_code = r1.concept_code_1
  JOIN internal_relationship_stage r2 ON r2.concept_code_1 = r1.concept_code_1
  JOIN drug_concept_stage cb
    ON cb.concept_code = r2.concept_code_2
   AND cb.concept_class_id = 'Brand Name'
  JOIN relationship_to_concept t
    ON t.concept_code_1 = cb.concept_code
   AND t.precedence = 1
  JOIN concept cx ON t.concept_id_2 = cx.concept_id
  LEFT JOIN (SELECT r3.concept_code_1
             FROM internal_relationship_stage r3
               JOIN drug_concept_stage cd
                 ON cd.concept_code = r3.concept_code_2
                AND cd.concept_class_id = 'Dose Form') cdr3 ON cdr3.concept_code_1 = r1.concept_code_1
WHERE cdr3.concept_code_1 IS NULL;

--to do: use hierarchy to allow similar forms (cream/ointment, inj solution/injection)
--for now, only 1 completely unique form per BN is processed
WITH forms_per_brand
AS
(SELECT b.brand_id
FROM bdf2b b
  JOIN concept_relationship cr
    ON cr.concept_id_1 = b.brand_id
   AND cr.relationship_id = 'Brand name of'
   AND cr.invalid_reason IS NULL
  JOIN concept c
    ON c.concept_class_id = 'Branded Drug Form'
   AND cr.concept_id_2 = c.concept_id
GROUP BY b.brand_id
HAVING COUNT(DISTINCT c.concept_id) = 1) DELETE FROM bdf2b WHERE brand_id NOT IN (SELECT brand_id FROM forms_per_brand);

INSERT INTO internal_relationship_stage
SELECT DISTINCT b.drug_concept_code,
       FIRST_VALUE(rc.concept_code_1) OVER (PARTITION BY b.drug_concept_code)
FROM bdf2b b
  JOIN concept_relationship cr
    ON cr.concept_id_1 = b.brand_id
   AND cr.relationship_id = 'Brand name of'
   AND cr.invalid_reason IS NULL
  JOIN concept c
    ON c.concept_class_id = 'Branded Drug Form'
   AND cr.concept_id_2 = c.concept_id
  JOIN concept_relationship rd
    ON rd.concept_id_1 = c.concept_id
   AND rd.invalid_reason IS NULL
   AND rd.relationship_id = 'RxNorm has dose form'
  JOIN relationship_to_concept rc
    ON rc.concept_id_2 = rd.concept_id_2
   AND rc.precedence = 1
--to make sure boiler catches it;

--Marketed Drugs without the dosage or Drug Form are not allowed
DELETE
FROM internal_relationship_stage
WHERE (concept_code_1,concept_code_2) IN (SELECT concept_code_1,
                                                 concept_code_2
                                          FROM drug_concept_stage dcs
                                            JOIN (SELECT concept_code_1,
                                                         concept_code_2
                                                  FROM internal_relationship_stage
                                                    JOIN drug_concept_stage
                                                      ON concept_code_2 = concept_code
                                                     AND concept_class_id = 'Supplier'
                                                    LEFT JOIN ds_stage ON drug_concept_code = concept_code_1
                                                  WHERE drug_concept_code IS NULL
                                                  UNION
                                                  SELECT concept_code_1,
                                                         concept_code_2
                                                  FROM internal_relationship_stage
                                                    JOIN drug_concept_stage
                                                      ON concept_code_2 = concept_code
                                                     AND concept_class_id = 'Supplier'
                                                  WHERE concept_code_1 NOT IN (SELECT concept_code_1
                                                                               FROM internal_relationship_stage
                                                                                 JOIN drug_concept_stage
                                                                                   ON concept_code_2 = concept_code
                                                                                  AND concept_class_id = 'Dose Form')) s ON s.concept_code_1 = dcs.concept_code
                                          WHERE dcs.concept_class_id = 'Drug Product'
                                          AND   invalid_reason IS NULL);

--dirty hack to get dose_form precedences from dm+d

DROP TABLE if exists new_form_insert;

CREATE TABLE new_form_insert 
AS
SELECT DISTINCT g.concept_code_1,
       NULL::VARCHAR,
       x.concept_id_2,
       x.precedence,
       x.conversion_factor
FROM relationship_to_concept g
  JOIN drug_concept_stage s
    ON g.concept_code_1 = s.concept_code
   AND s.concept_class_id = 'Dose Form'
  JOIN dev_dmd.drug_concept_stage d
    ON d.concept_name = s.concept_name
   AND d.concept_class_id = 'Dose Form'
  JOIN dev_dmd.relationship_to_concept x ON x.concept_code_1 = d.concept_code;

DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (SELECT concept_code_1 FROM new_form_insert);

INSERT INTO relationship_to_concept
SELECT *
FROM new_form_insert;

DO $d$ BEGIN IF (NOT EXISTS (SELECT
FROM relationship_to_concept
WHERE (concept_code_1,precedence) = ('Sachet',2))) THEN
-- if Sachet has at least one other map
INSERT INTO relationship_to_concept VALUES ('Sachet',NULL,19082651,2,1);

END IF;

END;

$d$;

DO $d$ BEGIN IF (NOT EXISTS (SELECT
FROM relationship_to_concept
WHERE (concept_code_1,precedence) = ('Paste',4))) THEN
-- if Paste has at least one other map
INSERT INTO relationship_to_concept VALUES ('Paste',NULL,19082224,4,1);

END IF;

END;

$d$;

/*
--Why is 'Paracetamol' mapped to Aspirin? Investigate in i_map sequence, fix RxE
--it's in AMIS, nobody is going to fix that
update internal_relationship_stage i
set concept_code_2 = (select concept_code from drug_concept_stage where concept_name = 'Acetaminophen' and concept_class_id = 'Ingredient')
where
	i.concept_code_1 in (select concept_code from drug_concept_stage where concept_name ilike '%pArAcEtAmOl%') and
	i.concept_code_2 = (select concept_code from drug_concept_stage where concept_name = 'Aspirin' and concept_class_id = 'Ingredient') and
	i.concept_code_1 not in (select concept_code from )*/

DELETE
FROM internal_relationship_stage i
WHERE i.concept_code_2 = 'Powder'
AND   EXISTS (SELECT
              FROM internal_relationship_stage
              WHERE concept_code_1 = i.concept_code_1
              AND   concept_code_2 = 'Tablet');

DELETE
FROM internal_relationship_stage i
WHERE concept_code_1 IS NULL
OR    concept_code_2 IS NULL;

DELETE
FROM ds_stage
WHERE drug_concept_code IS NULL
OR    ingredient_concept_code IS NULL;

INSERT INTO relationship_to_concept
SELECT dcs.concept_code,
       NULL,
       cc.concept_id,
       2,
       NULL
FROM drug_concept_stage dcs
  JOIN concept cc
    ON LOWER (cc.concept_name) = LOWER (dcs.concept_name)
   AND cc.concept_class_id = dcs.concept_class_id
   AND cc.vocabulary_id LIKE 'RxNorm%'
   AND cc.invalid_reason IS NULL
  LEFT JOIN relationship_to_concept cr ON cr.concept_code_1 = dcs.concept_code
WHERE cr.concept_code_1 IS NULL
AND   dcs.concept_class_id IN ('Ingredient','Brand Name','Dose Form','Supplier');

DELETE
FROM relationship_to_concept
WHERE concept_id_2 IS NULL;