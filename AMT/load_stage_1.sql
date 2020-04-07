/*************************************************
* Set Latest Update *
*************************************************/
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.SetLatestUpdate(
                        pVocabularyName => 'AMT',
                        pVocabularyDate => (SELECT vocabulary_date FROM sources.product LIMIT 1),
                        pVocabularyVersion => (SELECT vocabulary_version FROM sources.product LIMIT 1),
                        pVocabularyDevSchema => 'DEV_AMT'
                    );
        PERFORM VOCABULARY_PACK.SetLatestUpdate(
                        pVocabularyName => 'RxNorm Extension',
                        pVocabularyDate => CURRENT_DATE,
                        pVocabularyVersion => 'RxNorm Extension ' || CURRENT_DATE,
                        pVocabularyDevSchema => 'DEV_AMT',
                        pAppendVocabulary => TRUE
                    );
    END
$_$;

/*************************************************
* SNOMED-AU conversion *
*************************************************/
DROP TABLE IF EXISTS concept_stage_sn;
CREATE TABLE concept_stage_sn
(
    LIKE concept_stage
);

--1. Create core version of SNOMED without concept_id, domain_id, concept_class_id, standard_concept
INSERT INTO concept_stage_sn (concept_name,
                              vocabulary_id,
                              concept_code,
                              valid_start_date,
                              valid_end_date,
                              invalid_reason)
SELECT regexp_replace(coalesce(umls.concept_name, sct2.concept_name), ' (\([^)]*\))$',
                      ''), -- pick the umls one first (if there) and trim something like "(procedure)"
       'SNOMED'                        AS vocabulary_id,
       sct2.concept_code,
       (
       SELECT latest_update
       FROM vocabulary_conversion
       WHERE vocabulary_id_v5 = 'SNOMED'
       )                               AS valid_start_date,
       TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
       NULL                            AS invalid_reason
FROM (
     SELECT SUBSTR(d.term, 1, 255) AS concept_name,
            d.conceptid::TEXT      AS concept_code,
            c.active,
            ROW_NUMBER() OVER (
                PARTITION BY d.conceptid
                -- Order of preference: newest in sct2_concept, in sct2_desc, synonym, does not contain class in parenthesis
                ORDER BY TO_DATE(c.effectivetime, 'YYYYMMDD') DESC,
                    TO_DATE(d.effectivetime, 'YYYYMMDD') DESC,
                    CASE
                        WHEN typeid = 900000000000013009
                            THEN 0
                        ELSE 1
                        END,
                    CASE
                        WHEN term LIKE '%(%)%'
                            THEN 1
                        ELSE 0
                        END,
                    LENGTH(TERM) DESC,
                    d.id DESC
                )                  AS rn
     FROM sources.amt_sct2_concept_full_au c,
          sources.amt_full_descr_drug_only d
     WHERE c.id = d.conceptid
       AND term IS NOT NULL
     ) sct2
     LEFT JOIN (
               -- get a better concept_name
               SELECT DISTINCT code  AS concept_code,
                               FIRST_VALUE(-- take the best str
                               SUBSTR(str, 1, 255)) OVER (
                                   PARTITION BY code ORDER BY CASE tty
                                       --formatter:off
                                              WHEN 'PT' THEN 1
                                              WHEN 'PTGB' THEN 2
                                              WHEN 'SY' THEN 3
                                              WHEN 'SYGB' THEN 4
                                              WHEN 'MTH_PT' THEN 5
                                              WHEN 'FN' THEN 6
                                              WHEN 'MTH_SY' THEN 7
                                              WHEN 'SB' THEN 8
                                              ELSE 10 -- default for the obsolete ones
                                       --formatter:on
                                       END
                                   ) AS concept_name
               FROM sources.mrconso
               WHERE sab = 'SNOMEDCT_US'
                 AND tty IN ('PT', 'PTGB', 'SY', 'SYGB', 'MTH_PT', 'FN', 'MTH_SY', 'SB')
               ) umls
     ON sct2.concept_code = umls.concept_code
WHERE sct2.rn = 1
  AND sct2.active = 1;

--2. Create temporary table with extracted class information and terms ordered by some good precedence
DROP TABLE IF EXISTS tmp_concept_class;
CREATE UNLOGGED TABLE tmp_concept_class AS
SELECT *
FROM (
     SELECT concept_code,
            f7, -- extracted class
            ROW_NUMBER() OVER (
                PARTITION BY concept_code
                -- order of precedence: active, by class relevance, by highest number of parentheses
                ORDER BY active DESC,
                    CASE f7
                        --formatter:off
                        WHEN 'disorder' THEN 1
                        WHEN 'finding' THEN 2
                        WHEN 'procedure' THEN 3
                        WHEN 'regime/therapy' THEN 4
                        WHEN 'qualifier value' THEN 5
                        WHEN 'contextual qualifier' THEN 6
                        WHEN 'body structure' THEN 7
                        WHEN 'cell' THEN 8
                        WHEN 'cell structure' THEN 9
                        WHEN 'external anatomical feature' THEN 10
                        WHEN 'organ component' THEN 11
                        WHEN 'organism' THEN 12
                        WHEN 'living organism' THEN 13
                        WHEN 'physical object' THEN 14
                        WHEN 'physical device' THEN 15
                        WHEN 'physical force' THEN 16
                        WHEN 'occupation' THEN 17
                        WHEN 'person' THEN 18
                        WHEN 'ethnic group' THEN 19
                        WHEN 'religion/philosophy' THEN 20
                        WHEN 'life style' THEN 21
                        WHEN 'social concept' THEN 22
                        WHEN 'racial group' THEN 23
                        WHEN 'event' THEN 24
                        WHEN 'life event - finding' THEN 25
                        WHEN 'product' THEN 26
                        WHEN 'substance' THEN 27
                        WHEN 'assessment scale' THEN 28
                        WHEN 'tumor staging' THEN 29
                        WHEN 'staging scale' THEN 30
                        WHEN 'specimen' THEN 31
                        WHEN 'special concept' THEN 32
                        WHEN 'observable entity' THEN 33
                        WHEN 'namespace concept' THEN 34
                        WHEN 'morphologic abnormality' THEN 35
                        WHEN 'foundation metadata concept' THEN 36
                        WHEN 'core metadata concept' THEN 37
                        WHEN 'metadata' THEN 38
                        WHEN 'environment' THEN 39
                        WHEN 'geographic location' THEN 40
                        WHEN 'situation' THEN 41
                        WHEN 'situation' THEN 42
                        WHEN 'context-dependent category' THEN 43
                        WHEN 'biological function' THEN 44
                        WHEN 'attribute' THEN 45
                        WHEN 'administrative concept' THEN 46
                        WHEN 'record artifact' THEN 47
                        WHEN 'navigational concept' THEN 48
                        WHEN 'inactive concept' THEN 49
                        WHEN 'linkage concept' THEN 50
                        WHEN 'link assertion' THEN 51
                        WHEN 'environment / location' THEN 52
                        WHEN 'AU substance' THEN 53
                        WHEN 'AU qualifier' THEN 54
                        WHEN 'medicinal product unit of use' THEN 55
                        WHEN 'medicinal product pack' THEN 56
                        WHEN 'medicinal product' THEN 57
                        WHEN 'trade product pack' THEN 58
                        WHEN 'trade product unit of use' THEN 59
                        WHEN 'trade product' THEN 60
                        WHEN 'containered trade product pack' THEN 61
                        ELSE 99
                        END,
                    --formatter:on
                    rnb
                ) AS rnc
     FROM (
          SELECT concept_code,
                 active,
                 pc1,
                 pc2,
                 CASE
                     WHEN pc1 = 0
                         OR pc2 = 0
                         THEN term -- when no term records with parentheses
                 -- extract class (called f7)
                     ELSE substring(term, '\(([^(]+)\)$')
                     END AS f7,
                 rna     AS rnb -- row number in SCT2_DESC_FULL_AU
          FROM (
               SELECT c.concept_code,
                      d.term,
                      d.active,
                      (
                      SELECT count(*)
                      FROM regexp_matches(d.term, '\(', 'g')
                      )     pc1, -- parenthesis open count
                      (
                      SELECT count(*)
                      FROM regexp_matches(d.term, '\)', 'g')
                      )     pc2, -- parenthesis close count
                      ROW_NUMBER() OVER (
                          PARTITION BY c.concept_code ORDER BY d.active DESC, -- first active ones
                              (
                              SELECT count(*)
                              FROM regexp_matches(d.term, '\(', 'g')
                              ) DESC -- first the ones with the most parentheses - one of them the class info
                          ) rna  -- row number in SCT2_DESC_FULL_AU
               FROM concept_stage_sn c
                    JOIN sources.amt_full_descr_drug_only d
                    ON d.conceptid::TEXT = c.concept_code
               WHERE c.vocabulary_id = 'SNOMED'
               ) AS s0
          ) AS s1
     ) AS s2
WHERE rnc = 1;
CREATE INDEX x_cc_2cd ON tmp_concept_class (concept_code);

--3. Create reduced set of classes
UPDATE concept_stage_sn cs
SET concept_class_id = CASE
    --formatter:off
           WHEN F7 = 'disorder' THEN 'Clinical Finding'
           WHEN F7 = 'procedure' THEN 'Procedure'
           WHEN F7 = 'finding' THEN 'Clinical Finding'
           WHEN F7 = 'organism' THEN 'Organism'
           WHEN F7 = 'body structure' THEN 'Body Structure'
           WHEN F7 = 'substance' THEN 'Substance'
           WHEN F7 = 'product' THEN 'Pharma/Biol Product'
           WHEN F7 = 'event' THEN 'Event'
           WHEN F7 = 'qualifier value' THEN 'Qualifier Value'
           WHEN F7 = 'observable entity' THEN 'Observable Entity'
           WHEN F7 = 'situation' THEN 'Context-dependent'
           WHEN F7 = 'occupation' THEN 'Social Context'
           WHEN F7 = 'regime/therapy' THEN 'Procedure'
           WHEN F7 = 'morphologic abnormality' THEN 'Morph Abnormality'
           WHEN F7 = 'physical object' THEN 'Physical Object'
           WHEN F7 = 'specimen' THEN 'Specimen'
           WHEN F7 = 'environment' THEN 'Location'
           WHEN F7 = 'environment / location' THEN 'Location'
           WHEN F7 = 'context-dependent category' THEN 'Context-dependent'
           WHEN F7 = 'attribute' THEN 'Attribute'
           WHEN F7 = 'linkage concept' THEN 'Linkage Concept'
           WHEN F7 = 'assessment scale' THEN 'Staging / Scales'
           WHEN F7 = 'person' THEN 'Social Context'
           WHEN F7 = 'cell' THEN 'Body Structure'
           WHEN F7 = 'geographic location' THEN 'Location'
           WHEN F7 = 'cell structure' THEN 'Body Structure'
           WHEN F7 = 'ethnic group' THEN 'Social Context'
           WHEN F7 = 'tumor staging' THEN 'Staging / Scales'
           WHEN F7 = 'religion/philosophy' THEN 'Social Context'
           WHEN F7 = 'record artifact' THEN 'Record Artifact'
           WHEN F7 = 'physical force' THEN 'Physical Force'
           WHEN F7 = 'foundation metadata concept' THEN 'Model Comp'
           WHEN F7 = 'namespace concept' THEN 'Namespace Concept'
           WHEN F7 = 'administrative concept' THEN 'Admin Concept'
           WHEN F7 = 'biological function' THEN 'Biological Function'
           WHEN F7 = 'living organism' THEN 'Organism'
           WHEN F7 = 'life style' THEN 'Social Context'
           WHEN F7 = 'contextual qualifier' THEN 'Qualifier Value'
           WHEN F7 = 'staging scale' THEN 'Staging / Scales'
           WHEN F7 = 'life event - finding' THEN 'Event'
           WHEN F7 = 'social concept' THEN 'Social Context'
           WHEN F7 = 'core metadata concept' THEN 'Model Comp'
           WHEN F7 = 'special concept' THEN 'Special Concept'
           WHEN F7 = 'racial group' THEN 'Social Context'
           WHEN F7 = 'therapy' THEN 'Procedure'
           WHEN F7 = 'external anatomical feature' THEN 'Body Structure'
           WHEN F7 = 'organ component' THEN 'Body Structure'
           WHEN F7 = 'physical device' THEN 'Physical Object'
           WHEN F7 = 'linkage concept' THEN 'Linkage Concept'
           WHEN F7 = 'link assertion' THEN 'Linkage Assertion'
           WHEN F7 = 'metadata' THEN 'Model Comp'
           WHEN F7 = 'navigational concept' THEN 'Navi Concept'
           WHEN F7 = 'inactive concept' THEN 'Inactive Concept'
           WHEN F7 = 'AU substance' THEN 'AU Substance'
           WHEN F7 = 'AU qualifier' THEN 'AU Qualifier'
           WHEN F7 = 'medicinal product unit of use' THEN 'Med Product Unit'
           WHEN F7 = 'medicinal product pack' THEN 'Med Product Pack'
           WHEN F7 = 'medicinal product' THEN 'Medicinal Product'
           WHEN F7 = 'trade product pack' THEN 'Trade Product Pack'
           WHEN F7 = 'trade product' THEN 'Trade Product'
           WHEN F7 = 'trade product unit of use' THEN 'Trade Product Unit'
           WHEN F7 = 'containered trade product pack' THEN 'Containered Pack'
           ELSE 'Undefined'
           --formatter:on
    END
FROM tmp_concept_class cc
WHERE cc.concept_code = cs.concept_code;


/*************************************************
* 0. non-drug *
*************************************************/
--create non_drug table backup
DO
$body$
    DECLARE
        version text;
    BEGIN
        SELECT vocabulary_version
        INTO version
        FROM devv5.vocabulary
        WHERE vocabulary_id = 'AMT'
        LIMIT 1;
        EXECUTE format('create table if not exists %I as select distinct * from non_drug',
                       'non_drug_backup_' || version);
    END
$body$;

DROP TABLE IF EXISTS non_drug;
CREATE TABLE non_drug AS
SELECT *
FROM concept_stage_sn
WHERE concept_name ~*
      --formatter:off
      ( /*general categories and terms which themselves or their related products are treated as devices*/
        'dialysis|sunscreen|dressing|diagnostic|(?<![\w])glove| rope|ribbon|' ||
        'gauze|pouch|wipes|lubri|roll(?!\w)|bone cement|adhesive|(?<![\s])milk|cannula|' ||
        'swabs|bandage|artificial saliva|juice|supplement|trace elements|' ||
        /*Miscellaneous Brand Names*/
        'palacos|duralock|immune reviver|hydraderm|aridol|mannitol 0|periolimel|' ||
        /*Dietary management of congenital errors of metabolism; malabsorption and malnutrition; vitamins and minerals*/
        'mma/pa|camino|maxamum|sno-pro|peptamen|pepti-junior|procal(?!\w)|' ||
        'glytactin|keyomega|cystine|docomega|anamix|xlys|xmtvi |pku |(?<!\w)tyr |' ||
        'msud|hcu |eaa |gluten|prozero|energivit|pro-phree|elecare|neocate|carbzero|' ||
        'medium chain|long chain|low protein|mineral mixture|amino acids|' ||
        'phlexy-10|wagner 1000|nutrition care|amino acid formula|elevit|bio magnesium|' ||
        'monogen powder|betaquik|liquigen|lipistart|fruitivits|ultivite|' ||
        /*Contrasts and Radiopharmaceuticals radiodiagnostics*/
        'pytest|helicap|bq|octreoscan|Ct Plus|optiray|ioversol|iomeprol|iomeron|' ||
        'iopamidol|isovue|ultravist|omnipaq|iohex|' ||

        'Crampeze|smoflipid|smofkabiven|sorbolene|' ||
        'cranberry|pedialyte|hydralyte|kilocalories|emulsifying ointment|paraffin|cotton|aqueous cream')

  AND concept_class_id IN ('AU Substance', 'AU Qualifier', 'Med Product Unit', 'Med Product Pack',
                           'Medicinal Product', 'Trade Product Pack', 'Trade Product', 'Trade Product Unit',
                           'Containered Pack');


/*add "containing/only" non_drugs. Specify amino acids to prevent drug ingredients from appearing in non_drugs*/
INSERT INTO non_drug
SELECT DISTINCT *
FROM concept_stage_sn sn
WHERE sn.concept_name ~*
      ('^(arginine|citrulline|glycine|isoleucine|phenylalanine|tyrosine|valine)[\w\s-]+(containing|only)')
  AND sn.concept_code NOT IN (
                             SELECT concept_code
                             FROM non_drug
                             );


INSERT INTO non_drug
SELECT DISTINCT a.*
FROM concept_stage_sn a
JOIN sources.amt_rf2_full_relationships b
    ON a.concept_code = destinationid::text
JOIN concept_stage_sn c
    ON c.concept_Code = sourceid::text
WHERE a.concept_name IN ('bar', 'can', 'roll', 'rope', 'sheet')
  AND a.concept_code NOT IN (
                            SELECT concept_code
                            FROM non_drug
                            );

INSERT INTO non_drug
SELECT DISTINCT c.*
FROM concept_stage_sn a
JOIN sources.amt_rf2_full_relationships b
    ON a.concept_code = destinationid::text
JOIN concept_stage_sn c
    ON c.concept_Code = sourceid::text
WHERE a.concept_name IN ('bar', 'can', 'roll', 'rope', 'sheet')
  AND c.concept_name NOT LIKE '%ointment%'
  AND c.concept_name != 'soap bar'--soap bar dose form
  AND c.concept_code NOT IN (
                            SELECT concept_code
                            FROM non_drug
                            );

INSERT INTO non_drug --contrast
SELECT DISTINCT a.*
FROM concept_stage_sn a
JOIN sources.amt_rf2_full_relationships b
    ON a.concept_code = sourceid::text
WHERE (destinationid IN (31108011000036106, 75889011000036104, 31109011000036103, 31527011000036107, 75888011000036107,
                         48143011000036102, 48144011000036100, 48145011000036101, 31956011000036101, 733181000168100,
                         732871000168102)
    OR concept_name LIKE '% kBq %'
    OR concept_name LIKE '%MBq%')
  AND a.concept_class_id <> 'AU Qualifier'
  AND a.concept_code NOT IN (
                            SELECT concept_code
                            FROM non_drug
                            );

INSERT INTO non_drug
SELECT DISTINCT a.*
FROM concept_stage_sn a
WHERE concept_code IN
      ('31108011000036106', '75889011000036104', '31109011000036103', '31527011000036107', '75888011000036107',
       '48143011000036102', '48144011000036100', '48145011000036101', '31956011000036101', '733181000168100',
       '732871000168102')
  AND concept_code NOT IN (
                          SELECT concept_code
                          FROM non_drug
                          );

-- Insert non-drugs from ingredient_mapped (target_concept_id = 17)
INSERT INTO non_drug
SELECT DISTINCT dcs2.*
FROM drug_concept_stage dcs1
JOIN sources.amt_rf2_full_relationships fr
    ON dcs1.concept_code = fr.destinationid::text
JOIN concept_stage_sn dcs2
    ON dcs2.concept_code = fr.sourceid::text
WHERE dcs1.concept_name IN (
                           SELECT name
                           FROM ingredient_mapped
                           WHERE concept_id_2 = 17
                             AND name IS NOT NULL
                           );

--non-drugs related to non-drug ingredients, which will appear in ds_stage. (Coxiella, Tuberculin)
INSERT INTO non_drug
SELECT *
FROM concept_stage_sn
WHERE concept_code IN ('955111000168100', '955121000168107', '955101000168103',
                       '74328011000036106', '73859011000036102', '75434011000036102',
                       '74841011000036101', '75054011000036107')
  AND concept_code NOT IN (
                          SELECT concept_code
                          FROM non_drug
                          );


INSERT INTO non_drug
SELECT DISTINCT dcs2.*
FROM drug_concept_stage dcs1
JOIN sources.amt_rf2_full_relationships fr
    ON dcs1.concept_code = fr.destinationid::text
JOIN concept_stage_sn dcs2
    ON dcs2.concept_code = fr.sourceid::text
WHERE dcs1.concept_name IN (
                           SELECT name
                           FROM brand_name_mapped
                           WHERE concept_id_2 = 17
                             AND name IS NOT NULL
                           );

INSERT INTO non_drug --add non_drugs that are related to already found
SELECT c.*
FROM non_drug a
JOIN sources.amt_rf2_full_relationships b
    ON b.destinationid::text = a.concept_code
JOIN concept_stage_sn c
    ON b.sourceid::text = c.concept_code
WHERE c.concept_code NOT IN (
                            SELECT concept_code
                            FROM non_drug
                            )
;

INSERT INTO non_drug --add non_drugs that are related to already found
SELECT DISTINCT c.*
FROM non_drug a
JOIN sources.amt_rf2_full_relationships b
    ON sourceid::text = a.concept_code
JOIN concept_stage_sn c
    ON destinationid::text = c.concept_code
WHERE c.concept_code NOT IN (
                            SELECT concept_code
                            FROM non_drug
                            )
    AND c.concept_class_id IN ('Trade Product Pack', 'Trade Product', 'Med Product Unit', 'Med Product Pack')
   OR c.concept_name LIKE '%TP%'; -- Tpp, Tp(Trade product, Trade product pack)


INSERT INTO non_drug --add supplement
SELECT DISTINCT c.*
FROM non_drug a
JOIN sources.amt_rf2_full_relationships b
    ON sourceid::text = a.concept_code
JOIN concept_stage_sn c
    ON destinationid::text = c.concept_code
WHERE c.concept_code NOT IN (
                            SELECT concept_code
                            FROM non_drug
                            )
  AND (c.concept_name LIKE '%tape%' OR c.concept_name LIKE '%amino acid%' OR c.concept_name LIKE '%carbohydrate%' OR
       c.concept_name LIKE '%protein %')
  AND c.concept_code NOT IN ('31530011000036109', '32170011000036100', '31034011000036102');

INSERT INTO non_drug --add supplement
SELECT DISTINCT a.*
FROM concept_stage_sn a
JOIN sources.amt_rf2_full_relationships b
    ON b.sourceid::text = a.concept_code
JOIN sources.amt_rf2_full_relationships e
    ON b.destinationid = e.sourceid
JOIN concept_stage_sn c
    ON c.concept_code = e.destinationid::text
WHERE c.concept_class_id IN ('AU Qualifier', 'AU Substance')
  AND c.concept_name ~ 'dressing|amino acid|trace elements'
  AND NOT c.concept_name ~ 'copper|manganese|zinc|magnesium'
  AND a.concept_code NOT IN (
                            SELECT concept_code
                            FROM non_drug
                            )
;

DELETE
FROM non_drug
WHERE concept_code = '159011000036105'   --soap bar
   OR concept_code = '87047011000036100' -- cranberry extract ingredient
   OR concept_name LIKE '%lignocaine%'
   OR concept_name LIKE '%Xylocaine%'
   OR concept_name LIKE '%vaccine%'
   OR concept_name ~* '(?<=ural\s)cranberry';

-- MPP, CTPP, TPP, TPUU
DELETE
FROM non_drug nd
WHERE nd.concept_code IN ('30513011000036104', '30537011000036101',
                          '30404011000036106', '30425011000036101');


--== get new non_drugs for review (difference between last backup and current version)==--
/*SELECT DISTINCT *
FROM non_drug
WHERE concept_code NOT IN (
                          SELECT concept_code
                          FROM "non_drug_backup_AMT 01-SEP-17"
                          );
*/

/*************************************************
* 1. drug_concept_stage *
*************************************************/
DROP TABLE IF EXISTS supplier;
CREATE TABLE supplier AS
SELECT DISTINCT initcap(substring(concept_name, '\((.*)\)')) AS supplier, NULL AS sup_new_name--, concept_code
FROM concept_stage_sn
WHERE concept_class_id IN ('Trade Product Unit', 'Trade Product Pack', 'Containered Pack')
  AND substring(concept_name, '\((.*)\)') IS NOT NULL
  AND NOT substring(concept_name, '\((.*)\)') ~ '[0-9]'
  AND NOT substring(concept_name, '\((.*)\)') ~
          'blood|virus|inert|[Cc]apsule|vaccine|D|accidental|CSL|paraffin|once|extemporaneous|long chain|perindopril|triglycerides|Night Tablet'
  AND length(substring(concept_name, '\(.*\)')) > 5
  AND substring(lower(concept_name), '\((.*)\)') != 'night';

UPDATE supplier s
SET sup_new_name = v.supplier_new
FROM (
     VALUES ('%Pfizer%', 'Pfizer'),
            ('%Sanofi%', 'Sanofi'),
            ('%B Braun%', 'B Braun'),
            ('%Fresenius Kabi%', 'Fresenius Kabi'),
            ('%Baxter%', 'Baxter'),
            ('%Priceline%', 'Priceline'),
            ('%Pharmacist%', 'Pharmacist'),
            ('%Black & Gold%', 'Black And Gold')
     ) AS v (supplier_old, supplier_new)
WHERE s.supplier LIKE v.supplier_old;


--add suppliers with abbreviations
DROP TABLE IF EXISTS supplier_2;
--== adding suppliers with new_names ==--
CREATE TABLE supplier_2 AS
SELECT DISTINCT supplier, sup_new_name
FROM supplier
WHERE sup_new_name IS NOT NULL;

--== add non-repeating suppliers without new_names ==--
INSERT INTO supplier_2
SELECT DISTINCT supplier, NULL
FROM supplier
WHERE supplier NOT IN (
                      SELECT sup_new_name
                      FROM supplier_2
                      )
  AND sup_new_name IS NULL;

INSERT INTO supplier_2 (supplier)
--formatter:off
VALUES ('Apo'), ('Sun'), ('David Craig'), ('Parke Davis'), ('Ipc'), ('Rbx'), ('Dakota'),
       ('Dbl'), ('Scp'), ('Myx'), ('Aft'), ('Douglas'), ('Omega'), ('Bnm'), ('Qv'), ('Gxp'),
       ('Fbm'), ('Drla'), ('Csl'), ('Briemar'), ('Sau'), ('Drx');
--formatter:on

--== check for duplication of suppliers after manual insertion; should be empty ==--
/*SELECT supplier
FROM supplier_2
GROUP BY supplier
HAVING count(*) > 1;*/

ALTER TABLE supplier_2
    ADD concept_code varchar(255);

--using old codes from previous runs that have OMOP-codes
UPDATE supplier_2 s2
SET concept_code=i.concept_code
FROM (
     SELECT concept_code, concept_name
     FROM concept
     WHERE concept_class_id = 'Supplier'
       AND vocabulary_id = 'AMT'
     ) i
WHERE i.concept_name = coalesce(s2.sup_new_name, s2.supplier);


UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'IPC'
                 ),
    sup_new_name='IPC'
WHERE supplier = 'Ipc';

UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'Sun'
                 )
WHERE supplier = 'Sun';

UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'Boucher & Muir'
                 ),
    sup_new_name='Boucher & Muir'
WHERE supplier = 'Bnm';

UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'GXP'
                 ),
    sup_new_name='GXP'
WHERE supplier = 'Gxp';

UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'FBM'
                 ),
    sup_new_name='FBM'
WHERE supplier = 'Fbm';

UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'Douglas'
                 )
WHERE supplier = 'Douglas';

UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'DRX'
                 ),
    sup_new_name='DRX'
WHERE supplier = 'Drx';

UPDATE supplier_2
SET concept_code=(
                 SELECT DISTINCT concept_code
                 FROM concept
                 WHERE concept_class_id = 'Supplier'
                   AND vocabulary_id = 'AMT'
                   AND concept_name = 'Saudi'
                 ),
    sup_new_name='Saudi'
WHERE supplier = 'Sau';

--find OMOP codes that aren't used in concept table
DO
$$
    DECLARE
        ex INTEGER;
    BEGIN
        SELECT MAX(REPLACE(concept_code, 'OMOP', '')::INT4) + 1
        INTO ex
        FROM concept
        WHERE concept_code LIKE 'OMOP%'
          AND concept_code NOT LIKE '% %';
        DROP SEQUENCE IF EXISTS new_voc;
        EXECUTE 'CREATE SEQUENCE new_voc INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
    END
$$;


--== set unique code for the same supplier with multiple variants of one's name ==--
WITH tab AS (
            WITH t AS (
                      SELECT DISTINCT sup_new_name
                      FROM supplier_2
                      WHERE sup_new_name IN (
                                            SELECT sup_new_name
                                            FROM supplier_2
                                            GROUP BY sup_new_name
                                            HAVING count(*) > 1
                                            )
                        AND concept_code IS NULL
                      )
            SELECT sup_new_name, 'OMOP' || nextval('new_voc') AS concept_code
            FROM t
            )
UPDATE supplier_2
SET concept_code = tab.concept_code
FROM tab
WHERE supplier_2.sup_new_name = tab.sup_new_name;

-- generate codes for those suppliers that haven't existed in the previous release
UPDATE supplier_2
SET concept_code='OMOP' || nextval('new_voc')
WHERE concept_code IS NULL;

--creating first table for drug_strength
DROP TABLE IF EXISTS ds_0;
CREATE TABLE ds_0 AS
SELECT DISTINCT rel.sourceid, rel.destinationid, str.unitid, str.value
FROM sources.amt_rf2_ss_strength_refset str
JOIN sources.amt_rf2_full_relationships rel
    ON str.referencedComponentId = rel.id
WHERE sourceid::text NOT IN (
                            SELECT concept_code
                            FROM non_drug
                            )
;

--== remove duplicate ingredients with different dosages, presented in drug_strength, but actually absent in drugs ==--
--== got that drugs at QA check ds_stage duplicate ingredients per drug ==--
DELETE
FROM ds_0
WHERE (sourceid = '1154351000168104' AND value <> '0.833')
   OR (sourceid = '1154361000168102' AND value <> '0.833');


-- parse units
-- nested regexp_replace replaces "per" with "/"
-- enclosing regexp_replace removes "unit|each|application|dose" with occasionally trailing "unit" after "/"
-- UNNEST(regexp_matches) matches units to the left and to the right from "/" and UNNESTs them
DROP TABLE IF EXISTS unit;
CREATE TABLE unit AS
SELECT concept_name,
       concept_class_id,
       new_concept_class_id,
       concept_name AS concept_code,
       unitid
FROM (
     SELECT DISTINCT
--          UNNEST(regexp_matches(regexp_replace(cs.concept_name, '(/)(unit|each|application|dose)', '', 'g'),
--                             '[^/]+', 'g')) concept_name,
UNNEST(regexp_matches(
        regexp_replace(
                regexp_replace(cs.concept_name, '( per )', '/', 'g'),
                '(/)((unit|each|application|dose)( unit)?)|((?<=(millilitre|microgram|gram|centimetre|hour|square)) unit)',
                '', 'g'),
        '[^/]+', 'g')) concept_name,
'Unit' AS new_concept_class_id,
cs.concept_class_id,
ds.unitid
     FROM ds_0 ds
     JOIN concept_stage_sn cs
         ON ds.unitid::TEXT = cs.concept_code
     ) AS s0;

--== add per cent concept manually as it is not presented in source but will be created later ==--
INSERT INTO unit
SELECT '%' AS concept_name, NULL AS concept_class_id, 'Unit' AS new_concept_class_id, '%' AS concept_code,
       NULL AS unitid
WHERE NOT exists(SELECT concept_name
                 FROM unit
                 WHERE concept_name = '%');


DROP TABLE IF EXISTS form;
CREATE TABLE form AS
SELECT DISTINCT a.concept_name, 'Dose Form' AS new_concept_class_id, a.concept_code, a.concept_class_id
FROM concept_stage_sn a
JOIN sources.amt_rf2_full_relationships b
    ON a.concept_code = b.sourceid::text
JOIN concept_stage_sn c
    ON c.concept_code = destinationid::text
WHERE a.concept_class_id = 'AU Qualifier'
  AND a.concept_code NOT IN
      (
      SELECT DISTINCT a.concept_code
      FROM concept_stage_sn a
      JOIN sources.amt_rf2_full_relationships b
          ON a.concept_code = b.sourceid::text
      JOIN concept_stage_sn c
          ON c.concept_code = destinationid::text
      WHERE a.concept_class_id = 'AU Qualifier'
        AND initcap(c.concept_name) IN
            ('Area Unit Of Measure', 'Biological Unit Of Measure', 'Composite Unit Of Measure',
             'Descriptive Unit Of Measure', 'Mass Unit Of Measure', 'Microbiological Culture Unit Of Measure',
             'Radiation Activity Unit Of Measure', 'Time Unit Of Measure', 'Volume Unit Of Measure',
             'Type Of International Unit', 'Type Of Pharmacopoeial Unit')
      )
  AND lower(a.concept_name) NOT IN (
                                   SELECT lower(concept_name)
                                   FROM unit
                                   );

DROP TABLE IF EXISTS dcs_bn;
CREATE TABLE dcs_bn AS
SELECT DISTINCT *
FROM concept_stage_sn
WHERE concept_class_id = 'Trade Product';

UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, '\d+(\.\d+)?(\s\w+)?/\d+\s\w+$', '', 'g')
WHERE concept_name ~ '\d+(\s\w+)?/\d+\s\w+$';

UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, '\d+(\.\d+)?(\s\w+)?/\d+\s\w+$', '', 'g')
WHERE concept_name ~ '\d+(\s\w+)?/\d+\s\w+$';

UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, '(\d+/)?(\d+\.)?\d+/\d+(\.\d+)?$', '', 'g')
WHERE concept_name ~ '(\d+/)?(\d+\.)?\d+/\d+(\.\d+)?$'
  AND NOT concept_name ~ '-(\d+\.)?\d+/\d+$';

UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, '\d+(\.\d+)?/\d+(\.\d+)?(\s)?\w+$', '', 'g')
WHERE concept_name ~ '\d+(\.\d+)?/\d+(\.\d+)?(\s)?\w+$';

UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, '\d+(\.\d+)?(\s)?(\w+)?(\s\w+)?/\d+(\.\d+)?(\s)?\w+$', '', 'g')
WHERE concept_name ~ '\d+(\.\d+)?(\s)?(\w+)?(\s\w+)?/\d+(\.\d+)?(\s)?\w+$';


UPDATE dcs_bn
SET concept_name='Biostate'
WHERE concept_name LIKE '%Biostate%';
UPDATE dcs_bn
SET concept_name='Feiba-NF'
WHERE concept_name LIKE '%Feiba-NF%';
UPDATE dcs_bn
SET concept_name='Xylocaine'
WHERE concept_name LIKE '%Xylocaine%';
UPDATE dcs_bn
SET concept_name='Canesten'
WHERE concept_name LIKE '%Canesten%';


UPDATE dcs_bn
SET concept_name=rtrim(substring(concept_name, '([^0-9]+)[0-9]?'), '-')
WHERE concept_name LIKE '%/%'
  AND concept_name NOT LIKE '%Neutrogena%';
UPDATE dcs_bn
SET concept_name=replace(concept_name, '(Pfizer (Perth))', 'Pfizer');
UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, ' IM$| IV$', '', 'g');
UPDATE dcs_bn
SET concept_name=regexp_replace(concept_name, '\(Day\)|\(Night\)|(Day and Night)$|(Day$)', '', 'g');
UPDATE dcs_bn
SET concept_name=trim(replace(regexp_replace(concept_name, '\d+|\.|%|\smg\s|\smg$|\sIU\s|\sIU$', '', 'g'), '  ', ' '))
WHERE NOT concept_name ~ '-\d+'
  AND length(concept_name) > 3
  AND concept_name NOT LIKE '%Years%';


UPDATE dcs_bn
SET concept_name=trim(replace(concept_name, '  ', ' '));

--the same names
UPDATE dcs_bn
SET concept_name = 'Friar''s Balsam'
WHERE CONCEPT_CODE IN ('696391000168106', '688371000168108');


DELETE
FROM dcs_bn
WHERE CONCEPT_CODE IN (
                      SELECT CONCEPT_CODE
                      FROM non_drug
                      );

DELETE
FROM dcs_bn
WHERE lower(concept_name) IN (
                             SELECT lower(concept_name)
                             FROM concept_stage_sn
                             WHERE concept_class_id = 'AU Substance'
                             );
DELETE
FROM dcs_bn
WHERE lower(concept_name) IN (
                             SELECT lower(concept_name)
                             FROM concept
                             WHERE concept_class_id = 'Ingredient'
                             );

--all kinds of compounds
DELETE
FROM dcs_bn
WHERE CONCEPT_CODE IN
      ('654241000168106', '770691000168104', '51957011000036109', '65048011000036101', '86596011000036106',
       '43151000168105', '60221000168109', '734591000168106', '59261000168100', '3637011000036108',
       '53153011000036106', '664311000168109', '65011011000036100', '60481000168107', '40851000168105',
       '65135011000036103', '53159011000036109', '65107011000036104', '76000011000036107', '846531000168104',
       '45161000168106', '45161000168106', '7061000168108', '38571000168102')
;


TRUNCATE TABLE drug_concept_stage;
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                possible_excipient, domain_id, valid_start_date, valid_end_date, invalid_reason,
                                source_concept_class_id)
SELECT concept_name, 'AMT', new_concept_class_id, NULL, concept_code, NULL, 'Drug',
       TO_DATE('20161101', 'yyyymmdd') AS valid_start_date, TO_DATE('20991231', 'yyyymmdd') AS valid_end_date, NULL,
       concept_class_id
FROM (
     SELECT concept_name, 'Ingredient' AS new_concept_class_id, concept_code, concept_class_id
     FROM concept_stage_sn
     WHERE concept_class_id = 'AU Substance'
       AND concept_code NOT IN ('52990011000036102')-- Aqueous Cream
     UNION
     SELECT concept_name, 'Brand Name' AS new_concept_class_id, concept_code, concept_class_id
     FROM dcs_bn
     UNION
     SELECT concept_name, new_concept_class_id, concept_code, concept_class_id
     FROM form
     UNION
     SELECT DISTINCT coalesce(sup_new_name, supplier), 'Supplier' AS new_concept_class_id, concept_code, NULL
     FROM supplier_2
     UNION
     SELECT concept_name, new_concept_class_id, initcap(concept_name), concept_class_id
     FROM unit
     UNION
     SELECT concept_name, 'Drug Product', concept_code, concept_class_id
     FROM concept_stage_sn
     WHERE concept_class_id IN
           ('Containered Pack', 'Med Product Pack', 'Trade Product Pack', 'Med Product Unit', 'Trade Product Unit')
       AND concept_name NOT LIKE '%(&)%'
       AND (
           SELECT count(*)
           FROM regexp_matches(concept_name, '\sx\s', 'g')
           ) <= 1
       AND concept_name !~* '(containing|only) product'
     UNION
     SELECT concat(substr(concept_name, 1, 242), ' [Drug Pack]') AS concept_name, 'Drug Product', concept_code,
            concept_class_id
     FROM concept_stage_sn
     WHERE concept_class_id IN
           ('Containered Pack', 'Med Product Pack', 'Trade Product Pack', 'Med Product Unit', 'Trade Product Unit')
       AND (concept_name LIKE '%(&)%' OR (
                                         SELECT count(*)
                                         FROM regexp_matches(concept_name, '\sx\s', 'g')
                                         ) > 1)
     ) AS s0;


--== get packs where drugs separator '(&)' is more than 250 symbols deep and the pack is treated as a drug ==--
DROP TABLE IF EXISTS undetected_packs;
CREATE TABLE undetected_packs AS
SELECT DISTINCT ON (conceptid) position('(&)' IN dd.term) AS sep_position, dd.term, dd.conceptid
FROM sources.amt_full_descr_drug_only dd
JOIN drug_concept_stage dcs
    ON dd.conceptid::text = dcs.concept_code -- sometimes codes are equal, but names are different
        AND substring(lower(dd.term) FROM 1 FOR 240) = substring(lower(dcs.concept_name) FROM 1 FOR 240)
WHERE dd.term LIKE '%(&)%'
  AND position('(&)' IN dd.term) > 250
ORDER BY conceptid;

--== update dcs with undetected packs ==--
UPDATE drug_concept_stage
SET concept_name = concat(substr(concept_name, 1, 242), ' [Drug Pack]')
WHERE concept_code IN (
                      SELECT conceptid::text
                      FROM undetected_packs
                      );


-- set new_names for ingredients from ingredient_mapped
UPDATE drug_concept_stage dcs
SET concept_name = names.new_name
FROM (
     SELECT name, new_name
     FROM ingredient_mapped
     WHERE new_name <> ''
     ) AS names
WHERE lower(dcs.concept_name) = lower(names.name)
;

-- set new_names for brand names from brand_name_mapped
UPDATE drug_concept_stage dcs
SET concept_name = names.new_name
FROM (
     SELECT name, new_name
     FROM brand_name_mapped
     WHERE new_name <> ''
     ) AS names
WHERE lower(dcs.concept_name) = lower(names.name)
;

-- set new_names for suppliers from supplier_mapped
UPDATE drug_concept_stage dcs
SET concept_name = names.new_name
FROM (
     SELECT name, new_name
     FROM supplier_mapped
     WHERE new_name <> ''
     ) AS names
WHERE lower(dcs.concept_name) = lower(names.name)
;

-- set new_names for dose forms from dose_form_mapped
UPDATE drug_concept_stage dcs
SET concept_name = names.new_name
FROM (
     SELECT name, new_name
     FROM dose_form_mapped
     WHERE new_name <> ''
     ) AS names
WHERE lower(dcs.concept_name) = lower(names.name)
;


-- delete from dcs concepts, mapped to 0 in ingredient_mapped
DELETE
FROM drug_concept_stage dcs
WHERE lower(concept_name) IN (
                             SELECT lower(name)
                             FROM ingredient_mapped
                             WHERE concept_id_2 = 0
                               AND name IS NOT NULL
                             )
  AND concept_class_id = 'Ingredient';

-- delete from dcs concepts, mapped to 0 in brand_name_mapped
DELETE
FROM drug_concept_stage dcs
WHERE lower(concept_name) IN (
                             SELECT lower(name)
                             FROM brand_name_mapped
                             WHERE concept_id_2 = 0
                                AND name IS NOT NULL
                             )
  AND concept_class_id = 'Brand Name';

-- delete from dcs concepts, mapped to 0 in supplier_mapped
DELETE
FROM drug_concept_stage dcs
WHERE lower(concept_name) IN (
                             SELECT lower(name)
                             FROM supplier_mapped
                             WHERE concept_id_2 = 0
                               AND name IS NOT NULL
                      )
AND concept_class_id = 'Supplier';

-- delete from dcs concepts, mapped to 0 in dose_form_mapped
DELETE
FROM drug_concept_stage dcs
WHERE lower(concept_name) IN (
                             SELECT lower(name)
                             FROM dose_form_mapped
                             WHERE concept_id_2 = 0
                               AND name IS NOT NULL
                             )
AND concept_class_id = 'Dose Form';

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
                      SELECT concept_code
                      FROM non_drug
                      );

INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                possible_excipient, domain_id, valid_start_date, valid_end_date, invalid_reason,
                                source_concept_class_id)
SELECT DISTINCT concept_name, 'AMT', 'Device', 'S', concept_code, NULL, 'Device',
                TO_DATE('20161101', 'yyyymmdd') AS valid_start_date, TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                NULL, concept_class_id
FROM non_drug
WHERE concept_class_id NOT IN ('AU Qualifier', 'AU Substance', 'Trade Product');

UPDATE drug_concept_stage
SET concept_name=INITCAP(concept_name)
WHERE NOT (concept_class_id = 'Supplier' AND length(concept_name) < 4);--to fix chloride\Chloride

DELETE
FROM drug_concept_stage --delete containers
WHERE concept_code IN (
                      SELECT destinationid::text
                      FROM concept_stage_sn a
                      JOIN sources.amt_rf2_full_relationships b
                          ON destinationid::text = a.concept_code
                      JOIN concept_stage_sn c
                          ON c.concept_code = sourceid::text
                      WHERE typeid = '30465011000036106'
                      );


UPDATE drug_concept_stage dcs
SET standard_concept = 'S'
FROM (
     SELECT dcs2.concept_name, MIN(dcs2.concept_code) AS concept_code
     FROM drug_concept_stage dcs2
     JOIN concept c
         ON dcs2.concept_code = c.concept_code AND c.vocabulary_id = 'AMT'
     WHERE dcs2.concept_class_id IN
           ('Ingredient', 'Dose Form', 'Brand Name', 'Unit') --and  source_concept_class_id not in ('Medicinal Product','Trade Product')
     GROUP BY dcs2.concept_name, dcs2.concept_class_id
     ) d
WHERE d.concept_code = dcs.concept_code;

UPDATE drug_concept_stage dcs
SET standard_concept = 'S'
FROM (
     SELECT concept_name, MIN(concept_code) AS concept_code
     FROM drug_concept_stage
     WHERE concept_class_id IN ('Ingredient', 'Dose Form', 'Brand Name', 'Unit')
     GROUP BY concept_name
     ) d
WHERE d.concept_code = dcs.concept_code
  AND dcs.concept_name
    NOT IN (
           SELECT dcs2.concept_name
           FROM drug_concept_stage dcs2
           JOIN concept c
               ON dcs2.concept_code = c.concept_code
                   AND c.vocabulary_id = 'AMT'
           WHERE dcs2.concept_class_id IN ('Ingredient', 'Dose Form', 'Brand Name', 'Unit')
           );


UPDATE drug_concept_stage
SET possible_excipient='1'
WHERE concept_name = 'Aqueous Cream';

DELETE
FROM drug_concept_stage
WHERE lower(concept_name) IN
      ('containered trade product pack', 'Ctpp - Containered Trade Product Pack', 'trade product pack',
       'medicinal product unit of use', 'trade product unit of use', 'Tpuu - Trade Product Unit Of Use',
       'form', 'medicinal product pack', 'Mpp - Medicinal Product Pack', 'unit of use',
       'unit of measure');

DELETE
FROM drug_concept_stage
WHERE initcap(concept_name) IN --delete all unnecessary concepts
      ('Alternate Strength Followed By Numerator/Denominator Strength', 'Alternate Strength Only',
       'Australian Qualifier', 'Numerator/Denominator Strength',
       'Numerator/Denominator Strength Followed By Alternate Strength', 'Preferred Strength Representation Type',
       'Area Unit Of Measure', 'Square', 'Kbq', 'Dispenser Pack', 'Diluent', 'Tube', 'Tub', 'Carton', 'Unit Dose',
       'Vial', 'Strip',
       'Biological Unit Of Measure', 'Composite Unit Of Measure', 'Descriptive Unit Of Measure', 'Medicinal Product',
       'Mass Unit Of Measure', 'Microbiological Culture Unit Of Measure', 'Radiation Activity Unit Of Measure',
       'Time Unit Of Measure', 'Australian Substance', 'Medicinal Substance', 'Volume Unit Of Measure',
       'Measure', 'Continuous', 'Dose', 'Bag', 'Bead', 'Bottle', 'Ampoule', 'Type Of International Unit',
       'Type Of Pharmacopoeial Unit');

DELETE
FROM drug_concept_stage --as RxNorm doesn't have diluents in injectable drugs we will also delete them
WHERE (lower(concept_name) LIKE '%inert%' OR lower(concept_name) LIKE '%diluent%')
  AND concept_class_id = 'Drug Product'
  AND lower(concept_name) NOT LIKE '%tablet%';

ANALYZE drug_concept_stage;

--create relationship from non-standard ingredients to standard ingredients
DROP TABLE IF EXISTS non_S_ing_to_S;
CREATE TABLE non_S_ing_to_S AS
SELECT DISTINCT b.concept_code, a.concept_code AS s_concept_code
FROM drug_concept_stage a
JOIN drug_concept_stage b
    ON lower(a.concept_name) = lower(b.concept_name)
WHERE a.standard_concept = 'S'
  AND a.concept_class_id = 'Ingredient'
  AND b.standard_concept IS NULL
  AND b.concept_class_id = 'Ingredient';

--create relationship from non-standard forms to standard forms
DROP TABLE IF EXISTS non_S_form_to_S;
CREATE TABLE non_S_form_to_S AS
SELECT DISTINCT b.concept_code, a.concept_code AS s_concept_Code
FROM drug_concept_stage a
JOIN drug_concept_stage b
    ON lower(a.concept_name) = lower(b.concept_name)
WHERE a.STANDARD_CONCEPT = 'S'
  AND a.concept_class_id = 'Dose Form'
  AND b.STANDARD_CONCEPT IS NULL
  AND b.concept_class_id = 'Dose Form';

--create relationship from non-standard bn to standard bn
DROP TABLE IF EXISTS non_S_bn_to_S;
CREATE TABLE non_S_bn_to_S AS
SELECT DISTINCT b.concept_code, a.concept_code AS s_concept_Code
FROM drug_concept_stage a
JOIN drug_concept_stage b
    ON lower(a.concept_name) = lower(b.concept_name)
WHERE a.STANDARD_CONCEPT = 'S'
  AND a.concept_class_id = 'Brand Name'
  AND b.STANDARD_CONCEPT IS NULL
  AND b.concept_class_id = 'Brand Name';

--== trim concepts_names ending in a space after truncation ==--
UPDATE drug_concept_stage
SET concept_name = trim(concept_name);

/*************************************************
* 2. ds_stage *
*************************************************/
DROP TABLE IF EXISTS ds_0_1_1;
CREATE TABLE ds_0_1_1 AS -- still only MP
SELECT DISTINCT sourceid::text AS drug_concept_code,
                destinationid AS ingredient_concept_Code,
                dcs.concept_name,
                CASE
                    WHEN lower(sn.concept_name) LIKE '%/each%'
                        OR lower(sn.concept_name) LIKE '%/application%'
                        OR lower(sn.concept_name) LIKE '%/dose%'
                        OR lower(sn.concept_name) LIKE '%/square'
                        OR lower(sn.concept_name) LIKE '%per each%'
                        OR lower(sn.concept_name) LIKE '%per application%'
                        OR lower(sn.concept_name) LIKE '%per dose%'
                        OR lower(sn.concept_name) LIKE '%per square'
                        OR lower(sn.concept_name) LIKE '%per square unit%'
                        THEN ds.value
                    ELSE NULL
                END AS amount_value,
                CASE
                    WHEN lower(sn.concept_name) LIKE '%/each%'
                        OR lower(sn.concept_name) LIKE '%/application%'
                        OR lower(sn.concept_name) LIKE '%/dose%'
                        OR lower(sn.concept_name) LIKE '%/square'
                        OR lower(sn.concept_name) LIKE '%per each%'
                        OR lower(sn.concept_name) LIKE '%per application%'
                        OR lower(sn.concept_name) LIKE '%per dose%'
                        OR lower(sn.concept_name) LIKE '%per square'
                        OR lower(sn.concept_name) LIKE '%per square unit%'
                        THEN regexp_replace(lower(regexp_replace(sn.concept_name, '( per )', '/', 'g')),
                                            '(/)((each|application|dose|square)( unit)?)|((?<=(millilitre|microgram|gram|centimetre|hour|square)) unit)',
                                            '', 'gi')
                    ELSE NULL
                END AS amount_unit,
                CASE
                    WHEN lower(sn.concept_name) NOT LIKE '%/each%'
                        AND lower(sn.concept_name) NOT LIKE '%/application%'
                        AND lower(sn.concept_name) NOT LIKE '%/dose%'
                        AND lower(sn.concept_name) NOT LIKE '%/square'
                        AND lower(sn.concept_name) NOT LIKE '%per each%'
                        AND lower(sn.concept_name) NOT LIKE '%per application%'
                        AND lower(sn.concept_name) NOT LIKE '%per dose%'
                        AND lower(sn.concept_name) NOT LIKE '%per square'
                        AND lower(sn.concept_name) NOT LIKE '%per square unit%'
                        THEN ds.value
                    ELSE NULL
                END AS numerator_value,
                CASE
                    WHEN lower(sn.concept_name) NOT LIKE '%/each%'
                        AND lower(sn.concept_name) NOT LIKE '%/application%'
                        AND lower(sn.concept_name) NOT LIKE '%/dose%'
                        AND lower(sn.concept_name) NOT LIKE '%/square'
                        AND lower(sn.concept_name) NOT LIKE '%per each%'
                        AND lower(sn.concept_name) NOT LIKE '%per application%'
                        AND lower(sn.concept_name) NOT LIKE '%per dose%'
                        AND lower(sn.concept_name) NOT LIKE '%per square'
                        AND lower(sn.concept_name) NOT LIKE '%per square unit%'
                        THEN regexp_replace(
                            regexp_replace(
                                    regexp_replace(sn.concept_name, '( per )', '/', 'g')
                                , '/.*', '', 'g')
                        , '((?<=millilitre|gram|milligram|microgram|hour) unit)', '', 'g')
                    ELSE NULL
                END AS numerator_unit,
                CASE
                    WHEN lower(sn.concept_name) NOT LIKE '%/each%'
                        AND lower(sn.concept_name) NOT LIKE '%/application%'
                        AND lower(sn.concept_name) NOT LIKE '%/dose%'
                        AND lower(sn.concept_name) NOT LIKE '%/square'
                        AND lower(sn.concept_name) NOT LIKE '%per each%'
                        AND lower(sn.concept_name) NOT LIKE '%per application%'
                        AND lower(sn.concept_name) NOT LIKE '%per dose%'
                        AND lower(sn.concept_name) NOT LIKE '%per square'
                        AND lower(sn.concept_name) NOT LIKE '%per square unit%'
                        THEN replace(
                            regexp_replace(
                                    substring(
                                            regexp_replace(sn.concept_name, '( per )', '/', 'g')
                                        , '/.*')
                                , '((?<=millilitre|gram|milligram|microgram|hour|centimetre) unit)', '', 'g')
                        , '/', '')
                    ELSE NULL
                END AS denominator_unit
FROM ds_0 ds
JOIN concept_stage_sn sn
    ON sn.concept_code = ds.unitid::text
JOIN drug_concept_stage dcs
    ON ds.sourceid::text = dcs.concept_code
;

UPDATE ds_0_1_1
SET amount_value=NULL,
    amount_unit=NULL
WHERE lower(amount_unit) = 'ml';

--3-leg dogs (QA error) correction
UPDATE ds_0_1_1
SET numerator_value  = amount_value,
    numerator_unit   = amount_unit,
    amount_unit      = NULL,
    amount_value     = NULL,
    denominator_unit = 'gram'
WHERE concept_name IN ('Invite E High Potency Vitamin E Cream',
                       'Dl-Alpha-Tocopherol Acetate 10% + Glycerol 5% Cream')
  AND denominator_unit IS NULL;

DROP TABLE IF EXISTS ds_0_1_3;
CREATE TABLE ds_0_1_3 AS
SELECT c.concept_code AS drug_concept_code,
       ingredient_concept_code, amount_value,
       amount_unit, numerator_value, numerator_unit,
       denominator_unit, c.concept_name
FROM ds_0_1_1 a
JOIN sources.amt_rf2_full_relationships b
    ON a.drug_concept_code = destinationid::text
JOIN drug_concept_stage c
    ON b.sourceid::text = c.concept_code
WHERE c.source_concept_class_id IN
      ('Med Product Pack', 'Med Product Unit', 'Trade Product Unit', 'Trade Product Pack', 'Containered Pack')
  AND c.concept_name NOT LIKE '%[Drug Pack]%'
  AND c.concept_code NOT IN (
                            SELECT drug_concept_code
                            FROM ds_0_1_1
                            )
;

--== remove duplicate ingredients with different dosages, presented in drug_strength but actually are absent in drugs ==--
--== got that drugs at QA check ds_stage duplicate ingredients per drug ==--
DELETE
FROM ds_0_1_3
WHERE (drug_concept_code = '1167051000168104' AND numerator_value <> '0.05')
   OR (drug_concept_code = '1167041000168101' AND numerator_value <> '0.05');

DROP TABLE IF EXISTS ds_0_1_4;
CREATE TABLE ds_0_1_4 AS
SELECT c.concept_code AS drug_concept_code,
       ingredient_concept_code, amount_value,
       amount_unit, numerator_value, numerator_unit,
       denominator_unit, c.concept_name
FROM ds_0_1_1 a
JOIN sources.amt_rf2_full_relationships b
    ON a.drug_concept_code = destinationid::text
JOIN sources.amt_rf2_full_relationships b2
    ON b.sourceid = b2.destinationid
JOIN drug_concept_stage c
    ON b2.sourceid::text = concept_code
WHERE c.source_concept_class_id IN
      ('Med Product Pack', 'Med Product Unit', 'Trade Product Unit', 'Trade Product Pack', 'Containered Pack')
  AND c.CONCEPT_NAME NOT LIKE '%[Drug Pack]%'
;

DELETE
FROM ds_0_1_4
WHERE drug_concept_Code IN (
                           SELECT drug_concept_code
                           FROM ds_0_1_1
                           UNION
                           SELECT drug_concept_code
                           FROM ds_0_1_3
                           );

DROP TABLE IF EXISTS ds_0_2_0;
CREATE TABLE ds_0_2_0 AS
SELECT drug_concept_code, ingredient_concept_code, concept_name, amount_value, amount_unit, numerator_value,
       numerator_unit, denominator_unit
FROM ds_0_1_1
UNION
SELECT drug_concept_code, ingredient_concept_code, concept_name, amount_value, amount_unit, numerator_value,
       numerator_unit, denominator_unit
FROM ds_0_1_3
UNION
SELECT drug_concept_code, ingredient_concept_code, concept_name, amount_value, amount_unit, numerator_value,
       numerator_unit, denominator_unit
FROM ds_0_1_4
;


DROP TABLE IF EXISTS ds_0_2;
CREATE TABLE ds_0_2 AS
SELECT drug_concept_code, ingredient_concept_code, amount_value, amount_unit, numerator_value, numerator_unit,
       denominator_unit, concept_name,
       substring(concept_name,
                 '[,X]\s[0-9.]+\s(Mg|Ml|millilitre|G|L|Actuation)') AS new_denom_unit, --add real volume (, 50 Ml Vial)
       substring(concept_name, '[,X]\s([0-9.]+)\s(Mg|Ml|millilitre|G|L|Actuation)') AS new_denom_value
FROM ds_0_2_0
;


UPDATE ds_0_2
SET new_denom_value=substring(concept_name, ',\s[0-9.]+\sX\s([0-9.]+)\s(Mg|Ml|G|L|Actuation)'),
    new_denom_unit=substring(concept_name, ',\s[0-9.]+\sX\s[0-9.]+\s(Mg|Ml|G|L|Actuation)') --(5 X 50 Ml Vial)
WHERE new_denom_value IS NULL
  AND substring(concept_name, ',\s[0-9.]+\sX\s([0-9.]+)\s(Mg|Ml|G|L|Actuation)') IS NOT NULL;

UPDATE ds_0_2
SET numerator_value=amount_value,
    numerator_unit=amount_unit,
    amount_unit=NULL,
    amount_value=NULL
WHERE amount_value IS NOT NULL
  AND NEW_DENOM_UNIT IS NOT NULL
  AND NEW_DENOM_UNIT NOT IN ('Mg', 'G');

UPDATE ds_0_2
SET new_denom_value=NULL
WHERE drug_concept_code IN (
                           SELECT concept_code
                           FROM drug_concept_stage
                           WHERE concept_name LIKE '%Oral%'
                             AND concept_name ~ '\s5\sMl$'
                           );


UPDATE ds_0_2
SET numerator_value=CASE
                        WHEN new_denom_value IS NOT NULL AND (lower(new_denom_unit) = lower(denominator_unit) OR
                                                              (denominator_unit = 'actuation' AND new_denom_unit = 'Actuation'))
                            THEN numerator_value::FLOAT * new_denom_value::FLOAT
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('g') AND
                             lower(denominator_unit) IN ('mg') AND lower(numerator_unit) = 'mg'
                            THEN numerator_value::FLOAT * new_denom_value::FLOAT * 1000
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('g') AND
                             lower(denominator_unit) IN ('ml', 'millilitre') AND lower(numerator_unit) = 'mg'
                            THEN numerator_value::FLOAT * new_denom_value::FLOAT
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('g') AND
                             lower(denominator_unit) IN ('mg') AND lower(numerator_unit) = 'microgram'
                            THEN numerator_value::FLOAT * new_denom_value::FLOAT * 1000000
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('g') AND
                             lower(denominator_unit) IN ('ml', 'millilitre') AND lower(numerator_unit) = 'microgram'
                            THEN numerator_value::FLOAT * new_denom_value::FLOAT
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('mg') AND
                             lower(denominator_unit) IN ('g') AND lower(numerator_unit) = 'mg'
                            THEN (numerator_value::FLOAT * new_denom_value::FLOAT) / 1000
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('ml') AND
                             lower(denominator_unit) IN ('g') AND lower(numerator_unit) = 'mg'
                            THEN numerator_value::FLOAT * new_denom_value::FLOAT
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('ml') AND
                             denominator_unit IS NULL
                            THEN numerator_value::float * new_denom_value::float

                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('ml') AND
                             lower(denominator_unit) IN ('ml', 'millilitre') AND lower(numerator_unit) = 'microgram'
                            THEN numerator_value::float * new_denom_value::float
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('ml') AND
                             lower(denominator_unit) IN ('ml', 'millilitre') AND
                             lower(numerator_unit) IN ('ml', 'millilitre')
                            THEN numerator_value::float * new_denom_value::float
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('ml') AND
                             lower(denominator_unit) IN ('ml', 'millilitre') AND
                             lower(numerator_unit) IN ('index of reactivity unit')
                            THEN numerator_value::float * new_denom_value::float
                        WHEN new_denom_value IS NOT NULL AND lower(new_denom_unit) IN ('g') AND
                             lower(denominator_unit) IN ('g', 'gram') AND lower(numerator_unit) = 'mg'
                            THEN numerator_value::FLOAT * new_denom_value::FLOAT
                        ELSE numerator_value::FLOAT
                    END
WHERE concept_name NOT LIKE '%Medicinal Gas%';


UPDATE ds_0_2
SET denominator_unit=new_denom_unit
WHERE new_denom_unit IS NOT NULL
  AND amount_unit IS NULL
  AND concept_name NOT LIKE '%Medicinal Gas%';


UPDATE ds_0_2
SET amount_value=round(amount_value::numeric, 5),
    numerator_value=round(numerator_value::numeric, 5),
    new_denom_value=round(new_denom_value::numeric, 5);

UPDATE ds_0_2
SET amount_unit=initcap(amount_unit),
    numerator_unit=initcap(numerator_unit),
    denominator_unit=initcap(denominator_unit);


UPDATE ds_0_2
SET new_denom_value=NULL
WHERE denominator_unit = '24 Hours'
   OR denominator_unit = '16 Hours';

DROP TABLE IF EXISTS ds_0_3;
CREATE TABLE ds_0_3
AS
SELECT a.*, substring(concept_name, '([0-9]+)\sX\s[0-9]+')::int4 AS box_size
FROM ds_0_2 a;

UPDATE ds_0_3
SET box_size=substring(concept_name, ',\s(\d+)(,\s([^0-9])*)*$')::int4
WHERE amount_value IS NOT NULL
  AND box_size IS NULL;

UPDATE ds_0_3
SET new_denom_value=NULL
WHERE amount_unit IS NOT NULL;

--transform gases dosages into %
UPDATE ds_0_3
SET numerator_value=CASE
                        WHEN denominator_unit IN ('Ml', 'Millilitre') AND numerator_unit IN ('Ml', 'Millilitre')
                            THEN numerator_value::FLOAT * 100
                        WHEN denominator_unit IN ('L') AND numerator_unit IN ('L')
                            THEN numerator_value::FLOAT * 100
                        WHEN denominator_unit IN ('L') AND numerator_unit IN ('Ml', 'Millilitre')
                            THEN numerator_value::FLOAT / 10
                        ELSE numerator_value::FLOAT
                    END,
    numerator_unit=CASE
                       WHEN denominator_unit IN ('Ml', 'Millilitre', 'L') AND numerator_unit IN ('Ml', 'Millilitre')
                           THEN '%'
                       ELSE numerator_unit
                   END,
    denominator_unit=CASE WHEN new_denom_value IS NOT NULL THEN denominator_unit ELSE 'Ml' END,
    new_denom_value = NULL
WHERE concept_name LIKE '%Medicinal Gas%';

TRUNCATE TABLE ds_stage;
INSERT INTO ds_stage --add box size
(drug_concept_code, ingredient_concept_code, box_size, amount_value, amount_unit, numerator_value, numerator_unit,
 denominator_value, denominator_unit)
SELECT DISTINCT drug_concept_code, ingredient_concept_code, box_size, amount_value::float, amount_unit,
                numerator_value::float, numerator_unit, new_denom_value::float, denominator_unit
FROM ds_0_3;


INSERT INTO ds_stage (drug_concept_code, ingredient_concept_code) -- add drugs that don't have dosages
SELECT DISTINCT a.sourceid, a.destinationid
FROM sources.amt_rf2_full_relationships a
JOIN drug_concept_stage b
    ON b.concept_code = a.sourceid::text
JOIN drug_concept_stage c
    ON c.concept_code = a.destinationid::text
WHERE b.concept_class_id = 'Drug Product'
  AND c.concept_class_id = 'Ingredient'
  AND c.concept_name NOT LIKE '%Inert%'
  AND sourceid::text NOT IN (
                            SELECT drug_concept_code
                            FROM ds_stage
                            )
  AND sourceid::text NOT IN (
                            SELECT pack_concept_code
                            FROM pc_stage
                            );

INSERT INTO ds_stage (drug_concept_code, ingredient_concept_code)
SELECT DISTINCT a.sourceid, d.destinationid
FROM sources.amt_rf2_full_relationships a
JOIN drug_concept_stage b
    ON b.concept_code = a.sourceid::text
JOIN sources.amt_rf2_full_relationships d
    ON d.sourceid = a.destinationid
JOIN drug_concept_stage c
    ON c.concept_code = d.destinationid::text
WHERE b.concept_class_id = 'Drug Product'
  AND c.concept_class_id = 'Ingredient'
  AND c.concept_name NOT LIKE '%Inert%'
  AND a.sourceid::text NOT IN (
                              SELECT drug_concept_code
                              FROM ds_stage
                              )
  AND b.concept_name NOT LIKE '%Drug Pack%';

--add dosage of 1000mg/ml to concepts like water for injections, water for irrigation
UPDATE ds_stage
SET numerator_unit   = 'Mg',
    numerator_value  = 1000,
    denominator_unit = 'Ml'
WHERE drug_concept_code IN (
                           SELECT ds.drug_concept_code
                           FROM ds_stage ds
                           JOIN drug_concept_stage dcs
                               ON ds.drug_concept_code = dcs.concept_code
                           WHERE dcs.concept_name ILIKE '%water for%'
                             AND (amount_value IS NULL
                               AND numerator_value IS NULL
                               AND denominator_value IS NULL)
                           );


UPDATE ds_stage
SET numerator_unit='Mg',
    numerator_value=numerator_value / 1000
WHERE drug_concept_code IN
      (
      SELECT DISTINCT a.drug_concept_code
      FROM (
           SELECT DISTINCT a.amount_unit, a.numerator_unit, cs.concept_code, cs.concept_name AS canada_name,
                           rc.concept_name AS RxName,
                           a.drug_concept_code
           FROM ds_stage a
           JOIN relationship_to_concept b
               ON a.ingredient_concept_code = b.concept_code_1
           JOIN drug_concept_stage cs
               ON cs.concept_code = a.ingredient_concept_code
           JOIN devv5.concept rc
               ON rc.concept_id = b.concept_id_2
           JOIN drug_concept_stage rd
               ON rd.concept_code = a.drug_concept_code
           JOIN (
                SELECT a.drug_concept_code, b.concept_id_2
                FROM ds_stage a
                JOIN relationship_to_concept b
                    ON a.ingredient_concept_code = b.concept_code_1
                GROUP BY a.drug_concept_code, b.concept_id_2
                HAVING count(1) > 1
                ) c
               ON c.drug_concept_code = a.drug_concept_code AND c.concept_id_2 = b.concept_id_2
           WHERE precedence = 1
           ) a
      JOIN
          (
          SELECT DISTINCT a.amount_unit, a.numerator_unit, cs.concept_name AS canada_name,
                          rc.concept_name AS RxName, a.drug_concept_code
          FROM ds_stage a
          JOIN relationship_to_concept b
              ON a.ingredient_concept_code = b.concept_code_1
          JOIN drug_concept_stage cs
              ON cs.concept_code = a.ingredient_concept_code
          JOIN devv5.concept rc
              ON rc.concept_id = b.concept_id_2
          JOIN drug_concept_stage rd
              ON rd.concept_code = a.drug_concept_code
          JOIN (
               SELECT a.drug_concept_code, b.concept_id_2
               FROM ds_stage a
               JOIN relationship_to_concept b
                   ON a.ingredient_concept_code = b.concept_code_1
               GROUP BY a.drug_concept_code, b.concept_id_2
               HAVING count(1) > 1
               ) c
              ON c.drug_concept_code = a.drug_concept_code AND c.concept_id_2 = b.concept_id_2
          WHERE precedence = 1
          ) b
          ON a.RxName = b.RxName AND a.drug_concept_code = b.drug_concept_code AND
             (a.amount_unit != b.amount_unit OR a.numerator_unit != b.numerator_unit OR
              a.numerator_unit IS NULL AND b.numerator_unit IS NOT NULL
                 OR a.amount_unit IS NULL AND b.amount_unit IS NOT NULL)
      )
  AND numerator_unit = 'Microgram';

UPDATE ds_stage
SET numerator_value=numerator_value / 1000,
    numerator_unit='Mg'
WHERE numerator_unit = 'Microgram'
  AND numerator_value > 999;
UPDATE ds_stage
SET amount_value=amount_value / 1000,
    amount_unit='Mg'
WHERE amount_unit = 'Microgram'
  AND amount_value > 999;

UPDATE ds_stage
SET denominator_value=NULL,
    numerator_value=numerator_value / 5
WHERE drug_concept_code IN
      (
      SELECT drug_concept_code
      FROM ds_stage a
      JOIN drug_concept_stage
          ON drug_concept_code = concept_code
      WHERE denominator_value = '5'
        AND concept_name LIKE '%Oral%Measure%'
      );


UPDATE ds_stage
SET denominator_unit='Ml',
    denominator_value=denominator_value * 1000
WHERE denominator_unit = 'L'
  AND drug_concept_code NOT IN
      (
      SELECT SOURCEID::text
      FROM sources.amt_rf2_full_relationships a
      WHERE DESTINATIONID IN (122011000036104, 187011000036109)
      );

UPDATE ds_stage a
SET ingredient_concept_code=(
                            SELECT s_concept_code
                            FROM non_S_ing_to_S
                            WHERE CONCEPT_CODE = ingredient_concept_code
                            )
WHERE ingredient_concept_code IN (
                                 SELECT CONCEPT_CODE
                                 FROM non_S_ing_to_S
                                 );

UPDATE ds_stage --fix patches
SET denominator_unit='Hour',
    denominator_value=24
WHERE denominator_unit = '24 Hours';
UPDATE ds_stage
SET denominator_unit='Hour',
    denominator_value=16
WHERE denominator_unit = '16 Hours';

DROP TABLE IF EXISTS ds_sum;
CREATE TABLE ds_sum AS
SELECT DISTINCT drug_concept_code, ingredient_concept_code, box_size,
                sum(amount_value) AS amount_value,
                amount_unit, numerator_value, numerator_unit, denominator_value, denominator_unit
FROM ds_stage
GROUP BY drug_concept_code, ingredient_concept_code, box_size, amount_unit, numerator_value, numerator_unit,
         denominator_value, denominator_unit
;

TRUNCATE TABLE ds_stage;
INSERT INTO ds_stage
SELECT *
FROM ds_sum;

-- Movicol
DO
$_$
    BEGIN
        --formatter:off
        UPDATE ds_stage
        SET numerator_value = 8000, numerator_unit = 'Unit', denominator_value = 20, denominator_unit = 'Ml'
        WHERE drug_concept_code = '94311000036106' AND ingredient_concept_code = '1981011000036104';
        UPDATE ds_stage
        SET numerator_value = 8000, numerator_unit = 'Unit', denominator_value = 20, denominator_unit = 'Ml'
        WHERE drug_concept_code = '94321000036104' AND ingredient_concept_code = '1981011000036104';
        UPDATE ds_stage
        SET numerator_value = 100000, numerator_unit = 'Unit', denominator_value = 50, denominator_unit = 'Ml'
        WHERE drug_concept_code = '94331000036102' AND ingredient_concept_code = '1981011000036104';
        UPDATE ds_stage
        SET numerator_value = 100000, numerator_unit = 'Unit', denominator_value = 50, denominator_unit  = 'Ml'
        WHERE drug_concept_code = '94341000036107' AND ingredient_concept_code = '1981011000036104';
        UPDATE ds_stage
        SET numerator_value = 46.6, numerator_unit = 'Mg', denominator_value = 25, denominator_unit = 'Ml'
        WHERE drug_concept_code = '652501000168101' AND ingredient_concept_code = '2500011000036101';
        UPDATE ds_stage
        SET numerator_value = 46.6, numerator_unit = 'Mg', denominator_unit = 'Ml'
        WHERE drug_concept_code = '652511000168103' AND ingredient_concept_code = '2500011000036101';
        UPDATE ds_stage
        SET numerator_value = 932, numerator_unit = 'Mg', denominator_value = 500, denominator_unit = 'Ml'
        WHERE drug_concept_code = '652521000168105' AND ingredient_concept_code = '2500011000036101';
        UPDATE ds_stage
        SET numerator_value = 350.7, numerator_unit = 'Mg', denominator_value = 25, denominator_unit  = 'Ml'
        WHERE drug_concept_code = '652501000168101' AND ingredient_concept_code = '2591011000036106';
        UPDATE ds_stage
        SET numerator_value = 350.7, numerator_unit = 'Mg', denominator_value = 25, denominator_unit  = 'Ml'
        WHERE drug_concept_code = '652511000168103' AND ingredient_concept_code = '2591011000036106';
        UPDATE ds_stage
        SET numerator_value = 7014, numerator_unit = 'Mg', denominator_value = 500, denominator_unit  = 'Ml'
        WHERE drug_concept_code = '652521000168105' AND ingredient_concept_code = '2591011000036106';
        UPDATE ds_stage
        SET denominator_value = 25, denominator_unit  = 'Ml'
        WHERE drug_concept_code = '652501000168101' AND ingredient_concept_code = '2735011000036100';
        UPDATE ds_stage
        SET denominator_value = 25, denominator_unit  = 'Ml'
        WHERE drug_concept_code = '652511000168103' AND ingredient_concept_code = '2735011000036100';
        UPDATE ds_stage
        SET denominator_value = 500, denominator_unit  = 'Ml'
        WHERE drug_concept_code = '652521000168105' AND ingredient_concept_code = '2735011000036100';
        UPDATE ds_stage
        SET numerator_value = 178.5, numerator_unit = 'Mg', denominator_value = 25, denominator_unit = 'Ml'
        WHERE drug_concept_code = '652501000168101' AND ingredient_concept_code = '2736011000036107';
        UPDATE ds_stage
        SET numerator_value = 178.5, numerator_unit = 'Mg', denominator_value = 25, denominator_unit  = 'Ml'
        WHERE drug_concept_code = '652511000168103' AND ingredient_concept_code = '2736011000036107';
        UPDATE ds_stage
        SET numerator_value = 3570, numerator_unit = 'Mg', denominator_value = 500, denominator_unit  = 'Ml'
        WHERE drug_concept_code = '652521000168105' AND ingredient_concept_code = '2736011000036107';
        UPDATE ds_stage
        SET numerator_value = 13125, numerator_unit = 'Mg', denominator_value = 25, denominator_unit  = 'Ml'
        WHERE drug_concept_code = '652501000168101' AND ingredient_concept_code = '2799011000036106';
        UPDATE ds_stage
        SET numerator_value = 13125, numerator_unit = 'Mg', denominator_value = 25, denominator_unit  = 'Ml'
        WHERE drug_concept_code = '652511000168103' AND ingredient_concept_code = '2799011000036106';
        UPDATE ds_stage
        SET amount_unit       = NULL, --'',  that's what caused an error
            numerator_value   = 262.5,
            numerator_unit    = 'G',
            denominator_value = 500,
            denominator_unit  = 'Ml'
        WHERE drug_concept_code = '652521000168105' AND ingredient_concept_code = '2799011000036106';
        --Mucoclear
        UPDATE ds_stage
        SET box_size = 60, numerator_value = 120, denominator_value = 4
        WHERE drug_concept_code in ('1437511000168104', '1437531000168109', '1437521000168106');
        --formatter:on
    END;
$_$;

--inserting Inert Tablets with '0' for amount
INSERT INTO ds_stage (drug_concept_code, ingredient_concept_code, amount_value, amount_unit)
SELECT concept_code, '920012011000036105', '0', 'Mg'
FROM drug_concept_stage
WHERE concept_name LIKE '%Inert%'
  AND concept_name NOT LIKE '%Drug Pack%'
  AND concept_class_id = 'Drug Product';

--bicarbonate
DELETE
FROM ds_stage
WHERE drug_concept_code IN ('652521000168105', '652501000168101', '652511000168103')
  AND ingredient_concept_code = '2735011000036100';

UPDATE ds_stage
SET denominator_value = 25
WHERE drug_concept_code = '652511000168103'
  AND ingredient_concept_code = '2500011000036101';


DELETE
FROM ds_stage
WHERE drug_concept_code IN (
                           SELECT concept_code
                           FROM non_drug
                           );

DO
$_$
    BEGIN
        --formatter:off
        UPDATE ds_stage SET amount_unit = 'Mg' WHERE amount_unit = 'Milligram';
        UPDATE ds_stage SET numerator_unit = 'Mg' WHERE numerator_unit = 'Milligram';
        UPDATE ds_stage SET numerator_unit = 'Ml' WHERE numerator_unit = 'Millilitre';
        UPDATE ds_stage SET denominator_unit = 'Ml' WHERE denominator_unit = 'Millilitre';
        UPDATE ds_stage SET denominator_unit = 'G' WHERE denominator_unit = 'Gram';
        UPDATE ds_stage SET denominator_unit = 'Square Cm' WHERE denominator_unit = 'Square Centimetre';
        --formatter:on
    END;
$_$;

/*************************************************
* 3. internal_relationship_stage *
*************************************************/
DROP TABLE IF EXISTS drug_to_supplier;
CREATE INDEX idx_drug_ccid ON drug_concept_stage (concept_class_id);
ANALYZE drug_concept_stage;

CREATE TABLE drug_to_supplier AS
WITH a AS (
          SELECT concept_code, concept_name, initcap(concept_name) init_name
          FROM drug_concept_stage
          WHERE concept_class_id = 'Drug Product'
          )
SELECT DISTINCT a.concept_code, mf.concept_code AS supplier, coalesce(mf.sup_new_name, mf.supplier) AS s_name
FROM a
JOIN supplier_2 mf
    ON substring(init_name, '\(.*\)+') ILIKE '(' || mf.sup_new_name || ')'
        OR substring(init_name, '\(.*\)+') ILIKE '(' || mf.supplier || ')';

DELETE
FROM drug_to_supplier dts
WHERE dts.concept_code IN
      ('86621011000036102', '729271000168108', '1436931000168101', '86739011000036109', '1436911000168106',
       '729281000168106', '86613011000036105', '1435421000168103', '87113011000036108', '86842011000036102',
       '1436941000168105', '87065011000036102', '1435441000168109', '729261000168102', '1436871000168108',
       '1435451000168106', '86843011000036109', '1436861000168102', '1436881000168106', '1327601000168106',
       '86741011000036106', '87180011000036102', '86840011000036101', '86740011000036104');


DROP INDEX idx_drug_ccid;
ANALYZE drug_concept_stage;

DROP TABLE IF EXISTS supp_upd;
CREATE TABLE supp_upd AS
SELECT a.concept_code, a.supplier
FROM drug_to_supplier a
JOIN drug_to_supplier d
    ON d.concept_Code = a.concept_Code
WHERE a.supplier != d.supplier
  AND length(d.s_name) < length(a.s_name);

DELETE
FROM drug_to_supplier
WHERE concept_code IN (
                      SELECT concept_code
                      FROM supp_upd
                      );
INSERT INTO drug_to_supplier (concept_code, supplier)
SELECT concept_code, supplier
FROM supp_upd;

TRUNCATE TABLE internal_relationship_stage;
INSERT INTO internal_relationship_stage (concept_code_1, concept_code_2)

-- drug to ingr
SELECT a.drug_concept_code AS concept_code_1,
       CASE
           WHEN a.ingredient_concept_Code IN (
                                             SELECT concept_Code
                                             FROM non_S_ing_to_S
                                             )
               THEN s_concept_code
           ELSE a.ingredient_concept_code
       END
           AS concept_code_2
FROM ds_stage a
LEFT JOIN non_S_ing_to_S b
    ON a.ingredient_concept_code = b.concept_code

UNION

--drug to supplier
SELECT concept_code, supplier
FROM drug_to_supplier

UNION

--drug to form
SELECT b.concept_Code,
       CASE
           WHEN c.concept_code IN (
                                  SELECT concept_Code
                                  FROM non_S_form_to_S
                                  )
               THEN s_concept_Code
           ELSE c.concept_code
       END AS concept_Code_2
FROM sources.amt_rf2_full_relationships a
JOIN drug_concept_stage b
    ON a.sourceid::text = b.concept_code
JOIN drug_concept_stage c
    ON a.destinationid::text = c.concept_code
LEFT JOIN non_S_form_to_S d
    ON d.concept_code = c.concept_code
WHERE b.concept_class_id = 'Drug Product'
  AND b.concept_name NOT LIKE '%[Drug Pack]'
  AND c.concept_class_id = 'Dose Form'

UNION

SELECT a.sourceid::text,
       CASE
           WHEN c.concept_code IN (
                                  SELECT concept_Code
                                  FROM non_S_form_to_S
                                  )
               THEN s_concept_Code
           ELSE c.concept_code
       END AS concept_Code_2
FROM sources.amt_rf2_full_relationships a
JOIN drug_concept_stage d2
    ON d2.concept_code = a.sourceid::text
JOIN sources.amt_rf2_full_relationships b
    ON a.destinationid = b.sourceid
JOIN drug_concept_stage c
    ON b.destinationid::text = c.concept_code
LEFT JOIN non_S_form_to_S d
    ON d.concept_code = c.concept_code
WHERE c.concept_class_id = 'Dose Form'
  AND a.sourceid::text NOT IN (
                              SELECT concept_code
                              FROM drug_concept_stage
                              WHERE concept_name LIKE '%[Drug Pack]'
                              )

--drug to BN
UNION

SELECT b.concept_Code,
       CASE
           WHEN c.concept_code IN (
                                  SELECT concept_Code
                                  FROM non_S_bn_to_S
                                  )
               THEN s_concept_Code
           ELSE c.concept_code
       END AS concept_Code_2
FROM sources.amt_rf2_full_relationships a
JOIN drug_concept_stage b
    ON a.sourceid::text = b.concept_code
JOIN drug_concept_stage c
    ON a.destinationid::text = c.concept_code
LEFT JOIN non_S_bn_to_S d
    ON d.concept_code = c.concept_code
WHERE b.source_concept_class_id IN ('Trade Product Unit', 'Trade Product Pack', 'Containered Pack')
  AND c.concept_class_id = 'Brand Name'

UNION

SELECT a.sourceid::text,
       CASE
           WHEN c.concept_code IN (
                                  SELECT concept_Code
                                  FROM non_S_bn_to_S
                                  )
               THEN s_concept_Code
           ELSE c.concept_code
       END AS concept_Code_2
FROM sources.amt_rf2_full_relationships a
JOIN drug_concept_stage d2
    ON d2.concept_code = a.sourceid::text
JOIN sources.amt_rf2_full_relationships b
    ON a.destinationid = b.sourceid
JOIN drug_concept_stage c
    ON b.destinationid::text = c.concept_code
LEFT JOIN non_S_bn_to_S d
    ON d.concept_code = c.concept_code
WHERE c.concept_class_id = 'Brand Name'
  AND a.sourceid::text NOT IN (
                              SELECT concept_code
                              FROM drug_concept_stage
                              WHERE concept_name LIKE '%[Drug Pack]'
                              )
  AND d2.source_concept_class_id IN ('Trade Product Unit', 'Trade Product Pack', 'Containered Pack')

UNION

--drugs from packs
SELECT DRUG_CONCEPT_CODE,
       CASE
           WHEN c.concept_code IN (
                                  SELECT concept_Code
                                  FROM non_S_bn_to_S
                                  )
               THEN s_concept_Code
           ELSE c.concept_code
       END AS concept_Code_2
FROM pc_stage a
JOIN internal_relationship_stage b
    ON pack_concept_code = concept_Code_1
JOIN drug_Concept_stage c
    ON concept_Code_2 = c.concept_Code AND concept_class_id = 'Brand Name'
LEFT JOIN non_S_bn_to_S d
    ON d.concept_code = c.concept_code
;

--non standard concepts to standard
INSERT INTO internal_relationship_stage
    (concept_code_1, concept_code_2)
SELECT concept_code, s_concept_code
FROM non_S_ing_to_S
UNION
SELECT concept_code, s_concept_code
FROM non_S_form_to_S
UNION
SELECT concept_code, s_concept_code
FROM non_S_bn_to_S;

--fix drugs with 2 forms like capsule and enteric capsule

DROP TABLE IF EXISTS irs_upd;
CREATE TABLE irs_upd AS
SELECT a.concept_code_1, c.concept_code
FROM internal_relationship_stage a
JOIN drug_concept_stage b
    ON b.concept_Code = a.concept_Code_2 AND b.concept_Class_id = 'Dose Form'
JOIN internal_relationship_stage d
    ON d.concept_Code_1 = a.concept_Code_1
JOIN drug_concept_stage c
    ON c.concept_Code = d.concept_Code_2 AND c.concept_Class_id = 'Dose Form'
WHERE b.concept_code != c.concept_code
  AND length(b.concept_name) < length(c.concept_name);

INSERT INTO irs_upd
SELECT a.concept_code_1, c.concept_code
FROM internal_Relationship_stage a
JOIN drug_concept_stage b
    ON b.concept_Code = a.concept_Code_2 AND b.concept_Class_id = 'Dose Form'
JOIN internal_Relationship_stage d
    ON d.concept_Code_1 = a.concept_Code_1
JOIN drug_concept_stage c
    ON c.concept_Code = d.concept_Code_2 AND c.concept_Class_id = 'Dose Form'
WHERE b.concept_code != c.concept_code
  AND length(b.concept_name) = length(c.concept_name)
  AND b.concept_code < c.concept_code;

--fix those drugs that have 3 similar forms (like Tablet,Coated Tablet and Film Coated Tablet)
DROP TABLE IF EXISTS irs_upd_2;
CREATE TABLE irs_upd_2 AS
SELECT a.concept_code_1, a.concept_code
FROM irs_upd a
JOIN irs_upd b
    ON a.concept_code_1 = b.concept_Code_1
WHERE a.concept_code_1 IN (
                          SELECT concept_code_1
                          FROM irs_upd
                          GROUP BY concept_code_1, concept_code
                          HAVING count(1) > 1
                          )
  AND a.concept_code > b.concept_code;

DELETE
FROM irs_upd
WHERE concept_code_1 IN (
                        SELECT concept_code_1
                        FROM irs_upd_2
                        );
INSERT INTO irs_upd
SELECT *
FROM irs_upd_2;

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN
      (
      SELECT a.concept_code
      FROM drug_concept_stage a
      JOIN internal_relationship_stage s
          ON a.concept_code = s.concept_code_1
      JOIN drug_concept_stage b
          ON b.concept_code = s.concept_code_2
              AND b.concept_class_id = 'Dose Form'
      WHERE a.concept_code IN (
                              SELECT a.concept_code
                              FROM drug_concept_stage a
                              JOIN internal_relationship_stage s
                                  ON a.concept_code = s.concept_code_1
                              JOIN drug_concept_stage b
                                  ON b.concept_code = s.concept_code_2
                                      AND b.concept_class_id = 'Dose Form'
                              GROUP BY a.concept_code
                              HAVING count(1) > 1
                              )
      )
  AND concept_code_2 IN (
                        SELECT concept_Code
                        FROM drug_concept_stage
                        WHERE concept_class_id = 'Dose Form'
                        );

INSERT INTO internal_Relationship_stage (concept_code_1, concept_code_2)
SELECT DISTINCT concept_code_1, concept_code
FROM irs_upd;

DELETE
FROM drug_concept_stage
WHERE concept_code IN ( --dose forms that dont relate to any drug
                      SELECT concept_code
                      FROM drug_concept_stage a
                      LEFT JOIN internal_relationship_stage b
                          ON a.concept_code = b.concept_code_2
                      WHERE a.concept_class_id = 'Dose Form'
                        AND b.concept_code_1 IS NULL
                      )
  AND STANDARD_CONCEPT = 'S';

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
                        SELECT concept_code
                        FROM non_drug
                        );

DELETE
FROM internal_relationship_stage
WHERE internal_relationship_stage.concept_code_1 IN
      (
      SELECT concept_code
      FROM dev_amt.drug_concept_stage
      WHERE (concept_class_id, domain_id) != ('Drug Product', 'Drug')
      );

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 = '701581000168103'; --2 BN
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 IN ('770161000168102', '770171000168108', '770191000168109', '770201000168107')
  AND CONCEPT_CODE_2 = '769981000168106';

--estragest, estracombi, estraderm
DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = '933225691000036100'
  AND concept_code_2 = '13821000168101';
DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = '933225691000036100'
  AND concept_code_2 = '4174011000036102';
DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = '933231511000036106'
  AND concept_code_2 = '13821000168101';
DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = '933231511000036106'
  AND concept_code_2 = '4174011000036102';

/*************************************************
* 4. pc_stage *
*************************************************/
TRUNCATE TABLE concept_synonym_stage;

--== insert long pack names into concept_synonym_stage to avoid name trimming ==--
INSERT INTO concept_synonym_stage
SELECT DISTINCT NULL::int,
                concat(regexp_replace(descr.term, ' \(trade product pack\)| \(containered trade product pack\)', '',
                                      'g'),
                       ' [Drug Pack]') AS concept_name,
                concept_code,
                'AMT',
                4180186
FROM concept_stage_sn sn
JOIN sources.amt_full_descr_drug_only descr
    ON descr.term LIKE sn.concept_name || '%'
        AND sn.concept_code = descr.conceptid::text
WHERE concept_class_id IN
      ('Containered Pack', 'Med Product Pack', 'Trade Product Pack', 'Med Product Unit', 'Trade Product Unit')
  AND (
        concept_name LIKE '%(&)%'
        OR (
           SELECT count(*)
           FROM
               regexp_matches(concept_name, '\sx\s', 'g')
           ) > 1
    )
  AND length(concept_name) > 242
  AND length(descr.term) > 242
  AND sn.concept_name NOT LIKE '%dialysis%'
  AND sn.concept_name NOT LIKE '%Menveo%';


DROP TABLE IF EXISTS pc_0_initial;
--== get packs and constituent drugs ==--
/* Assure to get full pack_name (via synonyms) to provide correct parsing */
CREATE TABLE pc_0_initial
AS
SELECT DISTINCT dcs1.concept_code AS pack_code,
                coalesce(syn.synonym_name, dcs1.concept_name) AS pack_name,
                dcs2.concept_name::varchar,
                dcs2.concept_code,
                dcs2.concept_class_id,
                dcs2.source_concept_class_id
FROM drug_concept_stage dcs1
JOIN sources.amt_rf2_full_relationships frel
    ON dcs1.concept_code = frel.sourceid::text
JOIN drug_concept_stage dcs2
    ON dcs2.concept_code = frel.destinationid::text
LEFT JOIN concept_synonym_stage syn
    ON dcs1.concept_code = syn.synonym_concept_code
WHERE (dcs1.concept_name LIKE '%[Drug Pack]'
    AND dcs2.concept_class_id = 'Drug Product'
    AND typeid != '116680003'
    AND dcs2.source_concept_class_id IN ('Trade Product Unit', 'Med Product Unit'));
--M Prod Pack and Cont Tr Prod Pack need to be excluded

--== update pack_names in pc_0_initial with terms from undetected packs because they don't fit into synonyms ==--
UPDATE pc_0_initial
SET pack_name = undetected.term || ' [Drug Pack]'
FROM (
     SELECT term, conceptid
     FROM undetected_packs
     ) AS undetected
WHERE pack_code = undetected.conceptid::text;


--== remove wrong pack_names that were obtained at concept_stage_sn and add them manually later ==--
DROP TABLE IF EXISTS pc_wrong;
CREATE TEMP TABLE pc_wrong AS
SELECT *
FROM pc_0_initial
WHERE pack_code IN ('1071621000168106', '1071631000168109', '1073961000168106', '1073971000168100');

DELETE
FROM pc_0_initial
WHERE pack_code IN (
                   SELECT pack_code
                   FROM pc_wrong
                   );

DROP TABLE IF EXISTS pc_1_ampersand_sep;
--== extract pack_comp info from packs with drug names separated by '(&)' ==--
CREATE TABLE pc_1_ampersand_sep AS
SELECT pack_code,
       pack_name,
       lower(concept_name) AS concept_name,
       concept_code,
       lower(unnest(
               regexp_matches(
                       regexp_replace(
                               regexp_replace(
                                       regexp_replace(PACK_NAME, '(,\s\d.+\[Drug Pack\])', '', 'g'), -- remove trailing [Drug Pack] with box info
                                       '\([a-zA-Z\s)]+(?=\(.+&\))', '', 'g'), -- remove occasional supplier info
                               '^[a-zA-Z \d\/-]*(?=\()', '', 'g'), -- remove pack name
                       '\(*[a-zA-Z][^&]+\]', 'g') -- match constituent drugs enclosed in parentheses separated by '(&)'
           )) AS pack_comp
FROM pc_0_initial
WHERE pack_name LIKE '%(&)%';

--== DO NOT PROCEED UNTIL THE FOLLOWING CHECK RETURNS EMPTY RESULT ==--
--== check for packs from pc_0_initial that aren't in pc_1_ampersand_sep ==--
SELECT *
FROM pc_0_initial pc0
WHERE pc0.pack_name LIKE '%(&)%'
  AND pack_code NOT IN (
                       SELECT DISTINCT pack_code
                       FROM pc_1_ampersand_sep
                       );

--== identical pack constituents ==--
/*Since any pack has at least 2 drugs, each pack has to have at least four records.
  A pack which occurs only twice either has different amount of the same drug drug or a bug*/
DROP TABLE IF EXISTS pc_identical_drugs;
CREATE TEMP TABLE pc_identical_drugs AS
SELECT *
FROM pc_1_ampersand_sep pc1
WHERE pc1.pack_code IN (
                       SELECT pack_code
                       FROM pc_1_ampersand_sep
                       GROUP BY pack_code
                       HAVING count(*) = 2
                       )
;

--== pc_1_ampersand_sep tuning for further correct matching (intersection counts) ==--
DO
$_$
    BEGIN
        UPDATE pc_1_ampersand_sep
        SET concept_name = concept_name || ' codeine'
        WHERE concept_name ~* 'Cold And Flu.+\(Day\).*';

        UPDATE pc_1_ampersand_sep
        SET concept_name = concept_name || ' inert'
        WHERE concept_name ILIKE '%inert substance%';

        UPDATE pc_1_ampersand_sep
        SET concept_name = replace(concept_name,
                                   'antifungal clotrimazole women''s combination treatment (soul pattinson) ', '')
        WHERE concept_name ILIKE '%antifungal clotrimazole women''s combination treatment (soul pattinson)%';

        UPDATE pc_1_ampersand_sep
        SET concept_name = concept_name || ' succinate'
        WHERE concept_name ~* 'dimetapp daytime\/nightime \(night.*|dimetapp cold cough and flu \(night.*';

        UPDATE pc_1_ampersand_sep
        SET concept_name = concept_name || ' succinate'
        WHERE concept_name ~* 'dolased pain relief \(night.*';

        UPDATE pc_1_ampersand_sep
        SET concept_name = concept_name || ' triprolidine'
        WHERE concept_name ~*
              'codral original day and night cold and flu \(night.*|sudafed sinus day plus night relief \(night';
    END;
$_$;


--== pc_1_ampersand_sep and intersection of words counts between pack_comp and concept_name of a drug - pack constituent ==--
DROP TABLE IF EXISTS ampersand_sep_intersection_check;
CREATE TEMP TABLE ampersand_sep_intersection_check AS
SELECT DISTINCT pc1.pack_code,
                pc1.pack_name,
                pc1.concept_name,
                pc1.concept_code,
                pc1.pack_comp,
                cardinality(array(
                        SELECT unnest(regexp_split_to_array(pc1.concept_name, ' '))
                        INTERSECT
                        SELECT unnest(regexp_split_to_array(regexp_replace(pc1.pack_comp, '\)|\(|s\)', ''), ' '))
                    )) AS intersection
FROM pc_1_ampersand_sep pc1
WHERE pc1.pack_code NOT IN (
                           SELECT pack_code
                           FROM pc_identical_drugs
                           )
ORDER BY pack_code
;

DROP TABLE IF EXISTS ampersand_sep_intersection_ambig;
--== get those drugs whose max intersections occur more than once for single pack (ambiguous constituent drug) ==--
CREATE TEMP TABLE ampersand_sep_intersection_ambig AS
WITH tab AS
         (
         SELECT pack_code,
                concept_code,
                max(intersection) AS intersection
         FROM ampersand_sep_intersection_check
         GROUP BY pack_code, concept_code
         )
SELECT ic.pack_code, ic.pack_name, ic.concept_name, ic.concept_code, ic.intersection
FROM tab t
JOIN ampersand_sep_intersection_check ic
    ON t.pack_code = ic.pack_code
        AND t.concept_code = ic.concept_code
        AND t.intersection = ic.intersection
GROUP BY ic.pack_code, ic.pack_name, ic.concept_name, ic.concept_code, ic.intersection
HAVING count(*) > 1;


DROP TABLE IF EXISTS pc_2_ampersand_sep_amount;
--== get amounts for drugs from pc_1_ampersand_sep (separated by '(&)') ==--
/*match by intersection of words between concept_name and pack_comp
  exclude pack_code concept_code pair from ampersand_sep_intersection_ambig*/
CREATE TABLE pc_2_ampersand_sep_amount AS
WITH tab AS (
            SELECT DISTINCT pc1.pack_code,
                            pc1.pack_name,
                            pc1.concept_name,
                            pc1.concept_code,
                            cardinality(array(
                                    SELECT unnest(regexp_split_to_array(concept_name, ' '))
                                    INTERSECT
                                    SELECT unnest(
                                                   regexp_split_to_array(
                                                           regexp_replace(pack_comp, '\)|\(|s\)', ''), ' ')
                                               )
                                )
                                ) AS intersection,
                            pack_comp
            FROM pc_1_ampersand_sep pc1
            )
SELECT pack_code,
       pack_name,
       concept_name,
       concept_code,
       pack_comp,
       CASE
           WHEN pack_comp ~ 'syringe\]|device\]|vial\]|chamber\]|implant\]|sachet\]'
               THEN '1'
           ELSE
               SUBSTRING(pack_comp, '(?<=\[)\d+')
       END AS amount,
       'initial' AS source
FROM tab
WHERE intersection = (
                     SELECT max(intersection)
                     FROM tab tab2
                     WHERE tab2.pack_code = tab.pack_code
                       AND tab2.concept_code = tab.concept_code
                     )
  AND (pack_code, concept_code) NOT IN (
                                       SELECT pack_code, concept_code
                                       FROM ampersand_sep_intersection_ambig
                                       )
  AND pack_code NOT IN (
                       SELECT pack_code
                       FROM pc_identical_drugs
                       );

--== add ambiguous drugs where ambiguity was resolved by consistent match of another drug from a pack, while pack is already in pc_2 ==--
INSERT
INTO pc_2_ampersand_sep_amount
SELECT aa.pack_code, aa.pack_name, aa.concept_name, aa.concept_code, ach.pack_comp,
       SUBSTRING(ach.pack_comp, '(?<=\[)\d+') AS amount, 'ambig_resolved'
FROM ampersand_sep_intersection_ambig aa
JOIN ampersand_sep_intersection_check ach
    ON aa.pack_code = ach.pack_code
        AND aa.concept_code = ach.concept_code
WHERE (aa.pack_code, ach.pack_comp) NOT IN (
                                           SELECT pack_code, pack_comp
                                           FROM pc_2_ampersand_sep_amount
                                           )
  AND aa.pack_code IN (
                      SELECT pack_code
                      FROM pc_2_ampersand_sep_amount
                      )
  AND aa.pack_code NOT IN (
                          SELECT pack_code
                          FROM pc_identical_drugs
                          )
  AND aa.pack_code IN (
                      SELECT pack_code
                      FROM ampersand_sep_intersection_ambig
                      GROUP BY pack_code
                      HAVING count(*) = 1
                      );

--== insert packs with identical drug constituents ==--
INSERT INTO pc_2_ampersand_sep_amount
SELECT *, SUBSTRING(pack_comp, '(?<=\[)\d+') AS amount, 'identical'
FROM pc_identical_drugs;

--== insert wrong packs, deleted from pc_0_initial and set correct amounts for them ==--
INSERT INTO pc_2_ampersand_sep_amount
SELECT pack_code, pack_name, concept_name, concept_code, 'manually_wrong', NULL, 'manual_wrong_source'
FROM pc_wrong;
DO
$_$
    BEGIN
        --formatter:off
        UPDATE pc_2_ampersand_sep_amount SET amount = '16' WHERE pack_code = '1071621000168106' AND concept_code = '1071601000168102';
        UPDATE pc_2_ampersand_sep_amount SET amount = '8' WHERE pack_code = '1071621000168106' AND concept_code = '1071611000168104';
        UPDATE pc_2_ampersand_sep_amount SET amount = '16' WHERE pack_code = '1071631000168109' AND concept_code = '1071601000168102';
        UPDATE pc_2_ampersand_sep_amount SET amount = '8' WHERE pack_code = '1071631000168109' AND concept_code = '1071611000168104';
        UPDATE pc_2_ampersand_sep_amount SET amount = '18' WHERE pack_code = '1073961000168106' AND concept_code = '1073941000168107';
        UPDATE pc_2_ampersand_sep_amount SET amount = '6' WHERE pack_code = '1073961000168106' AND concept_code = '1073951000168109';
        UPDATE pc_2_ampersand_sep_amount SET amount = '18' WHERE pack_code = '1073971000168100' AND concept_code = '1073941000168107';
        UPDATE pc_2_ampersand_sep_amount SET amount = '6' WHERE pack_code = '1073971000168100' AND concept_code = '1073951000168109';
        --formatter:on
    END
$_$;

--== insert drugs left in ampersand_sep_intersection_ambig and then set correct amounts for them ==--
INSERT INTO pc_2_ampersand_sep_amount
SELECT aa.pack_code, aa.pack_name, aa.concept_name, aa.concept_code, 'manually_ambig', NULL, 'manual_ambig'
FROM ampersand_sep_intersection_ambig aa
WHERE (aa.pack_code, aa.concept_code) NOT IN (
                                             SELECT pack_code, concept_code
                                             FROM pc_2_ampersand_sep_amount
                                             );
DO
$_$
    BEGIN
        --formatter:off
        UPDATE pc_2_ampersand_sep_amount SET amount = '5' WHERE pack_code = '86414011000036105' AND concept_code = '86215011000036108';
        UPDATE pc_2_ampersand_sep_amount SET amount = '2' WHERE pack_code = '86414011000036105' AND concept_code = '86214011000036109';
        UPDATE pc_2_ampersand_sep_amount SET amount = '5' WHERE pack_code = '85643011000036101' AND concept_code = '85317011000036106';
        UPDATE pc_2_ampersand_sep_amount SET amount = '2' WHERE pack_code = '85643011000036101' AND concept_code = '85314011000036100';
        UPDATE pc_2_ampersand_sep_amount SET amount = '5' WHERE pack_code = '86060011000036107' AND concept_code = '85317011000036106';
        UPDATE pc_2_ampersand_sep_amount SET amount = '2' WHERE pack_code = '86060011000036107' AND concept_code = '85314011000036100';
        UPDATE pc_2_ampersand_sep_amount SET amount = '5' WHERE pack_code = '684291000168107' AND concept_code = '85317011000036106';
        UPDATE pc_2_ampersand_sep_amount SET amount = '2' WHERE pack_code = '684291000168107' AND concept_code = '85314011000036100';
        UPDATE pc_2_ampersand_sep_amount SET amount = '5' WHERE pack_code = '684301000168108' AND concept_code = '85317011000036106';
        UPDATE pc_2_ampersand_sep_amount SET amount = '2' WHERE pack_code = '684301000168108' AND concept_code = '85314011000036100';
        UPDATE pc_2_ampersand_sep_amount SET amount = '6' WHERE pack_code = '27125011000036108' AND concept_code = '22491011000036102';
        UPDATE pc_2_ampersand_sep_amount SET amount = '12' WHERE pack_code = '27125011000036108' AND concept_code = '23115011000036108';
        UPDATE pc_2_ampersand_sep_amount SET amount = '5' WHERE pack_code = '684281000168109' AND concept_code = '86215011000036108';
        UPDATE pc_2_ampersand_sep_amount SET amount = '2' WHERE pack_code = '684281000168109' AND concept_code = '86214011000036109';
        UPDATE pc_2_ampersand_sep_amount SET amount = '6' WHERE pack_code = '12446011000036104' AND concept_code = '4801011000036103';
        UPDATE pc_2_ampersand_sep_amount SET amount = '12' WHERE pack_code = '12446011000036104' AND concept_code = '5193011000036100';
        UPDATE pc_2_ampersand_sep_amount SET amount = '6' WHERE pack_code = '19147011000036107' AND concept_code = '4801011000036103';
        UPDATE pc_2_ampersand_sep_amount SET amount = '12' WHERE pack_code = '19147011000036107' AND concept_code = '5193011000036100';
--== Viekira Pak ==--
        UPDATE pc_2_ampersand_sep_amount SET amount = '168' WHERE pack_code = '733921000168101' AND concept_code = '733661000168100';
        UPDATE pc_2_ampersand_sep_amount SET amount = '56' WHERE pack_code = '733921000168101' AND concept_code = '726051000168100';
        UPDATE pc_2_ampersand_sep_amount SET amount = '56' WHERE pack_code = '733921000168101' AND concept_code = '726021000168108';
        UPDATE pc_2_ampersand_sep_amount SET amount = '168' WHERE pack_code = '733931000168103' AND concept_code = '733661000168100';
        UPDATE pc_2_ampersand_sep_amount SET amount = '56' WHERE pack_code = '733931000168103' AND concept_code = '726051000168100';
        UPDATE pc_2_ampersand_sep_amount SET amount = '56' WHERE pack_code = '733931000168103' AND concept_code = '726021000168108';
        UPDATE pc_2_ampersand_sep_amount SET amount = '56' WHERE pack_code = '734481000168109' AND concept_code = '734361000168105';
        UPDATE pc_2_ampersand_sep_amount SET amount = '56' WHERE pack_code = '734481000168109' AND concept_code = '726051000168100';
        UPDATE pc_2_ampersand_sep_amount SET amount = '56' WHERE pack_code = '734481000168109' AND concept_code = '726021000168108';
        UPDATE pc_2_ampersand_sep_amount SET amount = '56' WHERE pack_code = '734491000168107' AND concept_code = '734361000168105';
        UPDATE pc_2_ampersand_sep_amount SET amount = '56' WHERE pack_code = '734491000168107' AND concept_code = '726051000168100';
        UPDATE pc_2_ampersand_sep_amount SET amount = '56' WHERE pack_code = '734491000168107' AND concept_code = '726021000168108';
        UPDATE pc_2_ampersand_sep_amount SET amount = '14' WHERE pack_code = '726071000168109' AND concept_code = '726051000168100';
        UPDATE pc_2_ampersand_sep_amount SET amount = '14' WHERE pack_code = '726071000168109' AND concept_code = '726021000168108';
        UPDATE pc_2_ampersand_sep_amount SET amount = '14' WHERE pack_code = '726081000168107' AND concept_code = '726051000168100';
        UPDATE pc_2_ampersand_sep_amount SET amount = '14' WHERE pack_code = '726081000168107' AND concept_code = '726021000168108';
        UPDATE pc_2_ampersand_sep_amount SET amount = '56' WHERE pack_code = '726551000168105' AND concept_code = '726051000168100';
        UPDATE pc_2_ampersand_sep_amount SET amount = '56' WHERE pack_code = '726551000168105' AND concept_code = '726021000168108';
        UPDATE pc_2_ampersand_sep_amount SET amount = '56' WHERE pack_code = '726561000168107' AND concept_code = '726051000168100';
        UPDATE pc_2_ampersand_sep_amount SET amount = '56' WHERE pack_code = '726561000168107' AND concept_code = '726021000168108';
        --formatter:on
    END
$_$;

--== DO NOT PROCEED UNTIL THE FOLLOWING CHECK RETURNS EMPTY RESULT ==--
--== ampersand_sep that didn't find their way to pc_2; should be empty==--
SELECT DISTINCT pc1.pack_code,
                pc1.pack_name,
                pc1.concept_name,
                pc1.concept_code,
                pc1.pack_comp
FROM pc_1_ampersand_sep pc1
WHERE pc1.pack_code NOT IN (
                           SELECT pack_code
                           FROM pc_2_ampersand_sep_amount
                           );


--== remap packs constituents to more specific drugs to prevent mapping to the same drug more than once ==--
DO
$_$
    BEGIN
        UPDATE pc_2_ampersand_sep_amount
        SET concept_code = '1037031000168109'
        WHERE pack_comp ~* 'diclofenac diethylammonium 1\.?1\.?6'
          AND amount = '20';
        UPDATE pc_2_ampersand_sep_amount
        SET concept_code = '1037061000168101'
        WHERE pack_comp ~* 'diclofenac diethylammonium 1\.?1\.?6'
          AND amount = '50';
        UPDATE pc_2_ampersand_sep_amount
        SET concept_code = '1037001000168102'
        WHERE pack_comp ~* 'diclofenac diethylammonium 1\.?1\.?6'
          AND amount = '100';
        UPDATE pc_2_ampersand_sep_amount
        SET concept_code = '1093361000168102'
        WHERE pack_comp ~* 'diclofenac diethylammonium 1\.?1\.?6'
          AND amount = '120';
        UPDATE pc_2_ampersand_sep_amount
        SET concept_code = '1096781000168102'
        WHERE pack_comp ~* 'diclofenac diethylammonium 1\.?1\.?6'
          AND amount = '180';
        UPDATE pc_2_ampersand_sep_amount
        SET concept_code = '1200401000168106'
        WHERE pack_comp ~* 'Venetoclax 100'
          AND amount = '7';
        UPDATE pc_2_ampersand_sep_amount
        SET concept_code = '1200431000168104'
        WHERE pack_comp ~* 'Venetoclax 100'
          AND amount = '14';
        UPDATE pc_2_ampersand_sep_amount
        SET concept_code = '1179931000168105'
        WHERE pack_comp ~* 'Fish Oil 1\.5 G Capsule'
          AND amount = '200';
        UPDATE pc_2_ampersand_sep_amount
        SET concept_code = '1192701000168101'
        WHERE pack_comp ~* 'Fish Oil 1\.5 G Capsule'
          AND amount = '400';
    END;
$_$;


--== different count of constituents in pc_1_ampersand and pc_2_ampersand for same packs ==--
SELECT *
FROM pc_2_ampersand_sep_amount
WHERE pack_code IN (
                   SELECT pc.pack_code
                   FROM pc_2_ampersand_sep_amount pc
                   GROUP BY pc.pack_code
                   HAVING count(pc.pack_code) <> (
                                                 SELECT count(pack_code)
                                                 FROM (
                                                      SELECT DISTINCT pc1.pack_code,
                                                                      pc1.concept_code
                                                      FROM pc_1_ampersand_sep pc1
                                                      ) t
                                                 WHERE pack_code = pc.pack_code
                                                 )
                   )
  AND pack_code NOT IN (
                       SELECT pack_code
                       FROM pc_identical_drugs
                       )
  AND pack_code NOT IN (
                       SELECT pack_code
                       FROM pc_wrong
                       );

--== get pc2_ampersand_sep for review ==--
-- SELECT pack_code, concept_code, pack_name, concept_name, pack_comp, amount, source
-- FROM pc_2_ampersand_sep_amount
-- ORDER BY pack_code;

--==============================================================================================================
--==============================================================================================================
DROP TABLE IF EXISTS pc_1_comma_sep;
--== extract pack_comp info from drugs separated by ',' ==--
/*substring gets drugs enclosed in parentheses (like some_drug(28 x 30 Mg Tablets, 28 x 60 Mg Tablets)),
then regexp_matches splits it into individual drugs
regexp_replace removes occasionally appearing BN in parentheses in front of the substring*/
CREATE TABLE pc_1_comma_sep
AS
SELECT DISTINCT pack_code,
                pack_name,
                concept_name,
                concept_code,
                trim(regexp_replace(unnest(
                                            regexp_matches(substring(pack_name, '\(.*[0-9].*\)'), '[^,]+', 'g')),
                                    '\(([A-Za-z\s'']*)\)', '', 'g')) AS pack_comp
FROM pc_0_initial
WHERE pack_code NOT IN (
                       SELECT pack_code
                       FROM pc_1_ampersand_sep
                       );

--== DO NOT PROCEED UNTIL THE FOLLOWING CHECK RETURNS EMPTY RESULT ==--
--== check for packs from pc_0_initial that aren't in pc_1_comma_sep ==--
SELECT *
FROM pc_0_initial
WHERE pack_code NOT IN (
                       SELECT pack_code
                       FROM pc_1_ampersand_sep
                       )
  AND pack_code NOT IN (
                       SELECT pack_code
                       FROM pc_1_comma_sep
                       );


DROP TABLE IF EXISTS pc_2_comma_sep_amount;
--== get amounts for drugs from pc_1_comma_sep (separated by ',') ==--
/*get one unique string for each drug in a pack, since regexp_matches created multiple options for pack_comp.
  Match by "amount X dosage"*/
CREATE TABLE pc_2_comma_sep_amount AS
SELECT DISTINCT pc1.pack_code,
                pc1.pack_name,
                pc1.concept_name,
                pc1.concept_code,
                'amount X dosage' AS pack_comp,
                substring(pc2.pack_comp, '\d+') AS amount
FROM pc_1_comma_sep pc1
JOIN pc_1_comma_sep pc2
    ON ' ' || pc1.concept_name LIKE -- compensate for space, left in pack_comp at the beginning,
       '%' || regexp_replace(substring(pc2.pack_comp, '\sX\s.*Mg |\sX\s.*Ml |\sX\s.*G |\sX\s.*Ir '), 'X\s', '', 'g') ||
       '%'
        AND pc1.pack_code = pc2.pack_code;

--== manual insertions based on the results of the return of the following check (should be empty) ==--
DROP TABLE IF EXISTS pc_2_comma_sep_amount_insertion;
CREATE TEMP TABLE pc_2_comma_sep_amount_insertion
(
    pack_code    varchar(50),
    concept_code varchar(50),
    amount       text
);

INSERT INTO pc_2_comma_sep_amount_insertion (pack_code, concept_code, amount)
VALUES ('1228401000168101', '1228251000168103', '1'),
       ('1228411000168103', '1228251000168103', '1'),
       ('1377951000168104', '1008481000168107', '2'),
       ('1377961000168102', '1008481000168107', '2'),
       ('1378011000168102', '1008481000168107', '4'),
       ('1378021000168109', '1008481000168107', '4'),
       ('1378031000168107', '1008481000168107', '12'),
       ('1378041000168103', '1008481000168107', '12'),
       ('1378051000168101', '1008481000168107', '16'),
       ('1378061000168104', '1008481000168107', '16'),
       ('765011000168104', '764971000168107', '1'),
       ('765021000168106', '764971000168107', '1'),
       ('902181000168109', '902141000168104', '2'),
       ('902191000168107', '902141000168104', '2'),
       ('902221000168101', '902211000168108', '2'),
       ('902231000168103', '902211000168108', '2');


INSERT INTO pc_2_comma_sep_amount
SELECT DISTINCT pi.pack_code, pc.pack_name, pc.concept_name, pi.concept_code, 'manual', pi.amount
FROM pc_2_comma_sep_amount_insertion pi
JOIN pc_1_comma_sep pc
    ON pi.pack_code = pc.pack_code
        AND pi.concept_code = pc.concept_code;


DROP TABLE IF EXISTS comma_sep_intersection_check;
--== Check for constituents of pack with equal intersection counts which leads to ambiguity ==--
CREATE TEMP TABLE comma_sep_intersection_check AS
SELECT DISTINCT pc1.pack_code,
                pc1.pack_name,
                pc1.concept_name,
                pc1.concept_code,
                pc1.pack_comp,
                cardinality(array(
                        SELECT unnest(regexp_split_to_array(pc1.concept_name, ' '))
                        INTERSECT
                        SELECT unnest(regexp_split_to_array(regexp_replace(pc1.pack_comp, '\)|\(|s\)', ''), ' '))
                    )) AS intersection
FROM pc_1_comma_sep pc1
JOIN pc_1_comma_sep pc2
    ON pc1.pack_code = pc2.pack_code
        AND pc1.concept_code = pc2.concept_code
WHERE (pc1.pack_code, pc1.concept_code) NOT IN (
                                               SELECT pack_code, concept_code
                                               FROM pc_2_comma_sep_amount
                                               )
ORDER BY pack_code;

--== Do not proceed until the following query is empty. ==--
--== If not - add corresponding amounts for constituents into pc_2_comma_sep_amount_insertion manually located above ==--
--== get constituents from pc_1_comma_sep which have the same max intersection count for several pack_components. ==--
WITH tab AS (
            SELECT pack_code, concept_code, max(intersection) AS intersection
            FROM comma_sep_intersection_check
            GROUP BY pack_code, concept_code
            )
SELECT ic.pack_code, ic.pack_name, ic.concept_name, ic.concept_code, ic.intersection
FROM tab t
JOIN comma_sep_intersection_check ic
    ON t.pack_code = ic.pack_code
        AND t.concept_code = ic.concept_code
        AND t.intersection = ic.intersection
GROUP BY ic.pack_code, ic.pack_name, ic.concept_name, ic.concept_code, ic.intersection
HAVING count(*) > 1;


--== insert unmatched by "amount X dosage" into pc_2_comma_sep_amount ==--
/*match by intersection of words between concept_name and pack_comp*/
WITH tab AS (
            SELECT DISTINCT pc1.pack_code,
                            pc1.pack_name,
                            pc1.concept_name,
                            pc1.concept_code,
                            cardinality(array(
                                    SELECT unnest(regexp_split_to_array(concept_name, ' '))
                                    INTERSECT
                                    SELECT unnest(
                                                   regexp_split_to_array(
                                                           regexp_replace(pack_comp, '\)|\(|s\)', ''), ' ')
                                               )
                                )
                                ) AS intersection,
                            pack_comp
            FROM pc_1_comma_sep pc1
            WHERE (pc1.pack_code, pc1.concept_code) NOT IN (
                                                           SELECT pack_code, concept_code
                                                           FROM pc_2_comma_sep_amount
                                                           )
            )
INSERT
INTO pc_2_comma_sep_amount
SELECT pack_code,
       pack_name,
       concept_name,
       concept_code,
       pack_comp,
       SUBSTRING(pack_comp, '\d+') AS amount
FROM tab
WHERE intersection = (
                     SELECT max(intersection)
                     FROM tab tab2
                     WHERE tab2.pack_code = tab.pack_code
                       AND tab2.concept_code = tab.concept_code
                     );

-- CHECK --
--== comma_sep that didn't find their way to pc_2; should be empty==--
SELECT DISTINCT pc1.pack_code,
                pc1.pack_name,
                pc1.concept_name,
                pc1.concept_code,
                pc1.pack_comp
FROM pc_1_comma_sep pc1
WHERE pc1.pack_code NOT IN (
                           SELECT pack_code
                           FROM pc_2_comma_sep_amount
                           );


--== remap packs constituents to more specific drugs to prevent mapping to the same drug more than once ==--
DO
$_$
    BEGIN
        UPDATE pc_2_comma_sep_amount
        SET concept_code = '1351781000168102' -- Odourless fish oil 1.5g 200
        WHERE concept_name ~* 'odourless fish oil'
          AND amount = '200';
        UPDATE pc_2_comma_sep_amount
        SET concept_code = '1351801000168103' -- Odourless fish oil 1.5g 400
        WHERE concept_name ~* 'odourless fish oil'
          AND amount = '400';
        UPDATE pc_2_comma_sep_amount
        SET concept_code = '1200441000168108' -- Venclexa 14x100Mg
        WHERE concept_name ~* 'Venclexta 100'
          AND amount = '14';
        UPDATE pc_2_comma_sep_amount
        SET concept_code = '1200411000168109' -- Venclexa 7x100Mg
        WHERE concept_name ~* 'Venclexta 100'
          AND amount = '7';
    END;
$_$;


--== get packs where some of the constituent drugs have not been matched ==--
/*count of constituents in pc_2_comma_sep_amount differs from count of constituents in pc_1_comma_sep*/
SELECT *
FROM pc_2_comma_sep_amount
WHERE pack_code IN (
                   SELECT pc.pack_code
                   FROM pc_2_comma_sep_amount pc
                   GROUP BY pc.pack_code
                   HAVING count(pc.pack_code) <> (
                                                 SELECT count(pack_code)
                                                 FROM (
                                                      SELECT DISTINCT pc1.pack_code,
                                                                      pc1.concept_code
                                                      FROM pc_1_comma_sep pc1
                                                      ) t
                                                 WHERE pack_code = pc.pack_code
                                                 )
                   );

--== get pc2_comma_sep for review ==--
-- SELECT pack_code, concept_code, pack_name, concept_name, pack_comp, amount
-- FROM pc_2_comma_sep_amount
-- ORDER BY pack_code;


--==============================================================================================================
--==============================================================================================================
DROP TABLE IF EXISTS pc_3_box_size;
--== create table with box_size info ==--
CREATE TABLE pc_3_box_size AS
SELECT pack_code, pack_name, concept_name, concept_code, amount,
       substring(
               substring(pack_name,
                         '[0-9]+\sX\s[0-9]+\s\[Drug Pack\]|[0-9]+\sX\s[0-9]+\sTablets\s\[Drug Pack\]|[0-9]+\sX\s[0-9]+\sTablets,\sBlister\sPacks\s\[Drug Pack\]|[0-9]+\sX\s[0-9]+,\sBlister\sPacks\s\[Drug Pack\]'),
               '[0-9]+') AS box_size
FROM (
     SELECT pack_code, pack_name, concept_name, concept_code, amount
     FROM pc_2_ampersand_sep_amount
     UNION
     SELECT pack_code, pack_name, concept_name, concept_code, amount
     FROM pc_2_comma_sep_amount
     ) pc_2;

--== set box_sizes for special cases ==--
UPDATE pc_3_box_size
SET box_size = NULL
WHERE pack_name LIKE '%Viekira Pak%';


TRUNCATE TABLE pc_stage;
INSERT INTO pc_stage (pack_concept_code, drug_concept_code, amount, box_size)
SELECT DISTINCT pack_code, concept_code, amount::float, box_size::int4
FROM pc_3_box_size;


/*************************************************
* 5. relationship_to_concept *
*************************************************/
--create relationship_to_concept table backup
DO
$body$
    DECLARE
        version text;
    BEGIN
        SELECT vocabulary_version
        INTO version
        FROM devv5.vocabulary
        WHERE vocabulary_id = 'AMT'
        LIMIT 1;
        EXECUTE format('create table if not exists %I as select * from relationship_to_concept',
                       'relationship_to_concept_backup_' || version);
    END
$body$;


DO
$$
    BEGIN
        ALTER TABLE relationship_to_concept
            ADD COLUMN mapping_type varchar(255);
    EXCEPTION
        WHEN duplicate_column THEN RAISE NOTICE 'column mapping_type already exists in relationship_to_concept.';
    END;
$$;


--create a temporary storage of units conversion info before truncating rtc
DROP TABLE IF EXISTS unit_conversions;
CREATE TEMP TABLE unit_conversions AS
SELECT DISTINCT rtc.concept_code_1,
                rtc.conversion_factor
FROM relationship_to_concept rtc
JOIN dev_amt.drug_concept_stage dcs
    ON rtc.concept_code_1 = dcs.concept_code
WHERE dcs.concept_class_id = 'Unit';


TRUNCATE TABLE relationship_to_concept;

/***********************************/
--1. Ingredient
-- insert auto-mapping into rtc by concept_name match
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'AMT',
                c.concept_id,     --c.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id),
                NULL::double precision,
                'am_name_match'
FROM drug_concept_stage dcs
JOIN concept c
    ON lower(c.concept_name) = lower(dcs.concept_name)
        AND c.concept_class_id = 'Ingredient'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND c.invalid_reason IS NULL
        AND c.standard_concept = 'S'
WHERE dcs.concept_class_id = 'Ingredient'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
;

-- insert auto-mapping into rtc by Precise Ingredient name match
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'AMT',
                cc.concept_id,    --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id),
                NULL::double precision,
                'am_precise_ing_name_match' AS mapping_type
FROM drug_concept_stage dcs
JOIN concept c
    ON lower(c.concept_name) = lower(dcs.concept_name)
        AND c.concept_class_id = 'Precise Ingredient'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND c.invalid_reason IS NULL
JOIN concept_relationship cr
    ON c.concept_id = cr.concept_id_1 AND cr.invalid_reason IS NULL
JOIN concept cc
    ON cr.concept_id_2 = cc.concept_id
        AND cc.concept_class_id = 'Ingredient'
        AND cc.vocabulary_id LIKE 'RxNorm%'
        AND cc.invalid_reason IS NULL
        AND cc.standard_concept = 'S'
WHERE dcs.concept_class_id = 'Ingredient'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
--   AND dcs.concept_code not in (select concept_code from vaccines)
;

-- insert mapping into rtc by concept_name match through U/D ingredients and 'Maps to' link
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'AMT',
                cc.concept_id,    --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY cc.vocabulary_id, cc.concept_id),
                NULL::double precision,
                'am_U/D_name_match + link to Valid' AS mapping_type
FROM drug_concept_stage dcs
JOIN concept c
    ON lower(c.concept_name) = lower(dcs.concept_name)
        AND c.concept_class_id = 'Ingredient'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND (c.standard_concept IS NULL OR c.invalid_reason IS NOT NULL)
JOIN concept_relationship cr
    ON c.concept_id = cr.concept_id_1 AND cr.relationship_id = 'Maps to' AND cr.invalid_reason IS NULL
JOIN concept cc
    ON cr.concept_id_2 = cc.concept_id
        AND cc.concept_class_id = 'Ingredient'
        AND cc.vocabulary_id LIKE 'RxNorm%'
        AND cc.invalid_reason IS NULL
        AND cc.standard_concept = 'S'
WHERE dcs.concept_class_id = 'Ingredient'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
--   AND dcs.concept_code not in (select concept_code from vaccines_ing)
;

-- update 'U/D' in ingredient_mapped
WITH to_be_updated AS (
                      SELECT DISTINCT im.name,
                                      im.concept_id_2 AS concept_id_2,
                                      c2.concept_id AS new_concept_id_2,
                                      c2.concept_name AS new_concept_name_2
                      FROM ingredient_mapped im
                      JOIN concept c1
                          ON im.concept_id_2 = c1.concept_id
                              AND c1.invalid_reason IN ('U', 'D')
                      JOIN concept_relationship cr
                          ON cr.concept_id_1 = c1.concept_id
                              AND cr.relationship_id = 'Maps to' AND cr.invalid_reason IS NULL
                      JOIN concept c2
                          ON c2.concept_id = cr.concept_id_2
                              AND c2.concept_class_id = 'Ingredient'
                              AND c2.vocabulary_id LIKE 'RxNorm%'
                              AND c2.invalid_reason IS NULL
                              AND c2.standard_concept = 'S'
                      WHERE
--excluding names mapped to > 1 concept
im.name NOT IN (
               SELECT im2.name
               FROM ingredient_mapped im2
               GROUP BY im2.name
               HAVING count(*) > 1
               )
                      )
UPDATE ingredient_mapped im
SET concept_id_2 = to_be_updated.new_concept_id_2,
    mapping_type = 'rtc_backup_U/D + link to Valid'
FROM to_be_updated
WHERE im.name = to_be_updated.name;


--delete from ingredient mapped if target concept is still U/D
WITH to_be_deleted AS (
                      SELECT *
                      FROM ingredient_mapped
                      WHERE concept_id_2 IN (
                                            SELECT concept_id
                                            FROM concept
                                            WHERE invalid_reason IS NOT NULL
                                            )
                      )
DELETE
FROM ingredient_mapped
WHERE name IN (
              SELECT name
              FROM to_be_deleted
              )
;

DROP TABLE IF EXISTS ingredient_to_map;

--ingredients to_map
CREATE TABLE IF NOT EXISTS ingredient_to_map AS
SELECT DISTINCT dcs.concept_name AS name,
                '' AS new_name
FROM drug_concept_stage dcs
WHERE concept_class_id = 'Ingredient'
  AND dcs.concept_code NOT IN (
                              SELECT DISTINCT concept_code_1
                              FROM relationship_to_concept
                              )
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM ingredient_mapped
                              WHERE name IS NOT NULL
                              )
ORDER BY dcs.concept_name
;

--== ingredient to map ==--
SELECT DISTINCT name,
                '' AS new_name,
                '' AS comment,
                NULL AS precedence,
                NULL AS target_concept_id,
                NULL AS concept_code,
                NULL AS concept_name,
                NULL AS concept_class_id,
                NULL AS standard_concept,
                NULL AS invalid_reason,
                NULL AS domain_id,
                NULL AS target_vocabulary_id
FROM ingredient_to_map itm
WHERE lower(itm.name) NOT IN (
                             SELECT lower(new_name)
                             FROM ingredient_mapped
                             WHERE new_name IS NOT NULL
                             )
ORDER BY itm.name;


/****************************************/
--2. Brand Names
-- insert auto-mapping into rtc by concept_name match
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'AMT',
                c.concept_id,     --c.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id),
                NULL::double precision,
                'am_name_match'
FROM drug_concept_stage dcs
JOIN concept c
    ON lower(c.concept_name) = lower(dcs.concept_name)
        AND c.concept_class_id = 'Brand Name'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND c.invalid_reason IS NULL
WHERE dcs.concept_class_id = 'Brand Name'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
;

-- insert mapping into rtc by concept_name match through U/D ingredients and 'Concept replaced by' link
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'AMT',
                cc.concept_id,    --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY cc.vocabulary_id, cc.concept_id),
                NULL::double precision,
                'am_U/D_name_match + link to Valid' AS mapping_type
FROM drug_concept_stage dcs
JOIN concept c
    ON lower(c.concept_name) = lower(dcs.concept_name)
        AND c.concept_class_id = 'Brand Name'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND c.invalid_reason IS NOT NULL
JOIN concept_relationship cr
    ON c.concept_id = cr.concept_id_1 AND cr.relationship_id = 'Concept replaced by' AND cr.invalid_reason IS NULL
JOIN concept cc
    ON cr.concept_id_2 = cc.concept_id
        AND cc.concept_class_id = 'Brand Name'
        AND cc.vocabulary_id LIKE 'RxNorm%'
        AND cc.invalid_reason IS NULL
        AND
       cc.concept_name NOT ILIKE '%alustal%' --remove still valid "Alustal House" from mapping. Can be deleted later
WHERE dcs.concept_class_id = 'Brand Name'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
;


-- update 'U/D' in brand_name_mapped
WITH to_be_updated AS (
                      SELECT DISTINCT bnm.name,
                                      bnm.concept_id_2 AS concept_id_2,
                                      c2.concept_id AS new_concept_id_2,
                                      c2.concept_name AS new_concept_name_2
                      FROM brand_name_mapped bnm
                      JOIN concept c1
                          ON bnm.concept_id_2 = c1.concept_id
                              AND c1.invalid_reason = 'U'
                      JOIN concept_relationship cr
                          ON cr.concept_id_1 = c1.concept_id
                              AND cr.relationship_id = 'Concept replaced by' AND cr.invalid_reason IS NULL
                      JOIN concept c2
                          ON c2.concept_id = cr.concept_id_2
                              AND c2.concept_class_id = 'Brand Name'
                              AND c2.vocabulary_id LIKE 'RxNorm%'
                              AND c2.invalid_reason IS NULL
                      WHERE
--excluding names mapped to > 1 concept
bnm.name NOT IN (
                SELECT bnm2.name
                FROM brand_name_mapped bnm2
                GROUP BY bnm2.name
                HAVING count(*) > 1
                )
                      )
UPDATE brand_name_mapped bnm
SET concept_id_2 = to_be_updated.new_concept_id_2,
    mapping_type = 'rtc_backup_U/D + link to Valid'
FROM to_be_updated
WHERE bnm.name = to_be_updated.name;

--delete from brand_name_mapped if target concept is still U/D
WITH to_be_deleted AS (
                      SELECT *
                      FROM brand_name_mapped
                      WHERE concept_id_2 IN (
                                            SELECT concept_id
                                            FROM concept
                                            WHERE invalid_reason IS NOT NULL
                                            )
                      )
DELETE
FROM brand_name_mapped
WHERE name IN (
              SELECT name
              FROM to_be_deleted
              )
;


DROP TABLE IF EXISTS brand_name_to_map;

--brand_name to_map
CREATE TABLE IF NOT EXISTS brand_name_to_map AS
SELECT DISTINCT dcs.concept_name AS name
FROM drug_concept_stage dcs
WHERE concept_class_id = 'Brand Name'
  AND dcs.concept_code NOT IN (
                              SELECT DISTINCT concept_code_1
                              FROM relationship_to_concept
                              )
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM brand_name_mapped
                              WHERE name IS NOT NULL
                              )
ORDER BY dcs.concept_name
;

--== brand_name_to_map ==--
SELECT DISTINCT tm.name,
                '' AS new_name,
                '' AS comment,
                NULL AS precedence,
                NULL AS target_concept_id,
                NULL AS concept_code,
                NULL AS concept_name,
                NULL AS concept_class_id,
                NULL AS standard_concept,
                NULL AS invalid_reason,
                NULL AS domain_id,
                NULL AS target_vocabulary_id
FROM brand_name_to_map tm
WHERE lower(tm.name) NOT IN (
                            SELECT lower(new_name)
                            FROM brand_name_mapped
                            WHERE new_name IS NOT NULL
                            )
ORDER BY tm.name;

/****************************************/
--3. Supplier
-- insert auto-mapping into rtc by concept_name match
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'AMT',
                c.concept_id,     --c.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id),
                NULL::double precision,
                'am_name_match'
FROM drug_concept_stage dcs
JOIN concept c
    ON lower(c.concept_name) = lower(dcs.concept_name)
        AND c.concept_class_id = 'Supplier'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND c.invalid_reason IS NULL
WHERE dcs.concept_class_id = 'Supplier'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
;

-- insert mapping into rtc by concept_name match through U/D ingredients and 'Concept replaced by' link
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'AMT',
                cc.concept_id,    --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY cc.vocabulary_id, cc.concept_id),
                NULL::double precision,
                'am_U/D_name_match + link to Valid' AS mapping_type
FROM drug_concept_stage dcs
JOIN concept c
    ON lower(c.concept_name) = lower(dcs.concept_name)
        AND c.concept_class_id = 'Supplier'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND c.invalid_reason IS NOT NULL
JOIN concept_relationship cr
    ON c.concept_id = cr.concept_id_1 AND cr.relationship_id = 'Concept replaced by' AND cr.invalid_reason IS NULL
JOIN concept cc
    ON cr.concept_id_2 = cc.concept_id
        AND cc.concept_class_id = 'Supplier'
        AND cc.vocabulary_id LIKE 'RxNorm%'
        AND cc.invalid_reason IS NULL
WHERE dcs.concept_class_id = 'Supplier'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
;

-- update 'U/D' in supplier_mapped
WITH to_be_updated AS (
                      SELECT DISTINCT sm.name,
                                      sm.concept_id_2 AS concept_id_2,
                                      c2.concept_id AS new_concept_id_2,
                                      c2.concept_name AS new_concept_name_2
                      FROM supplier_mapped sm
                      JOIN concept c1
                          ON sm.concept_id_2 = c1.concept_id
                              AND c1.invalid_reason = 'U'
                      JOIN concept_relationship cr
                          ON cr.concept_id_1 = c1.concept_id
                              AND cr.relationship_id = 'Concept replaced by' AND cr.invalid_reason IS NULL
                      JOIN concept c2
                          ON c2.concept_id = cr.concept_id_2
                              AND c2.concept_class_id = 'Supplier'
                              AND c2.vocabulary_id LIKE 'RxNorm%'
                              AND c2.invalid_reason IS NULL
                      WHERE
--excluding names mapped to > 1 concept
sm.name NOT IN (
               SELECT sm2.name
               FROM supplier_mapped sm2
               GROUP BY sm2.name
               HAVING count(*) > 1
               )
                      )
UPDATE supplier_mapped sm
SET concept_id_2 = to_be_updated.new_concept_id_2,
    mapping_type = 'rtc_backup_U/D + link to Valid'
FROM to_be_updated
WHERE sm.name = to_be_updated.name;

--delete from supplier_mapped if target concept is still U/D
WITH to_be_deleted AS (
                      SELECT *
                      FROM supplier_mapped
                      WHERE concept_id_2 IN (
                                            SELECT concept_id
                                            FROM concept
                                            WHERE invalid_reason IS NOT NULL
                                            )
                      )
DELETE
FROM supplier_mapped
WHERE name IN (
              SELECT name
              FROM to_be_deleted
              )
;


DROP TABLE IF EXISTS supplier_to_map;

--supplier to_map
CREATE TABLE IF NOT EXISTS supplier_to_map AS
SELECT DISTINCT dcs.concept_name AS name
FROM drug_concept_stage dcs
WHERE concept_class_id = 'Supplier'
  AND dcs.concept_code NOT IN (
                              SELECT DISTINCT concept_code_1
                              FROM relationship_to_concept
                              )
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM supplier_mapped
                              WHERE name IS NOT NULL
                              )
ORDER BY dcs.concept_name
;

--== supplier_to_map ==--
SELECT DISTINCT tm.name,
                '' AS new_name,
                '' AS comment,
                NULL AS precedence,
                NULL AS target_concept_id,
                NULL AS concept_code,
                NULL AS concept_name,
                NULL AS concept_class_id,
                NULL AS standard_concept,
                NULL AS invalid_reason,
                NULL AS domain_id,
                NULL AS target_vocabulary_id
FROM supplier_to_map tm
WHERE lower(tm.name) NOT IN (
                            SELECT lower(new_name)
                            FROM supplier_mapped
                            WHERE new_name IS NOT NULL
                            )
ORDER BY tm.name;


/****************************************/
--4. Dose Form

-- update 'U/D' in dose_form_mapped
WITH to_be_updated AS (
                      SELECT DISTINCT dfm.name,
                                      dfm.concept_id_2 AS concept_id_2,
                                      c2.concept_id AS new_concept_id_2,
                                      c2.concept_name AS new_concept_name_2
                      FROM dose_form_mapped dfm
                      JOIN concept c1
                          ON dfm.concept_id_2 = c1.concept_id
                              AND c1.invalid_reason = 'U'
                      JOIN concept_relationship cr
                          ON cr.concept_id_1 = c1.concept_id
                              AND cr.relationship_id = 'Concept replaced by' AND cr.invalid_reason IS NULL
                      JOIN concept c2
                          ON c2.concept_id = cr.concept_id_2
                              AND c2.concept_class_id = 'Dose Form'
                              AND c2.vocabulary_id LIKE 'RxNorm%'
                              AND c2.invalid_reason IS NULL
                      WHERE
--excluding names mapped to > 1 concept
dfm.name NOT IN (
                SELECT dfm2.name
                FROM dose_form_mapped dfm2
                GROUP BY dfm2.name
                HAVING count(*) > 1
                )
                      )
UPDATE dose_form_mapped dfm
SET concept_id_2 = to_be_updated.new_concept_id_2,
    mapping_type = 'rtc_backup_U/D + link to Valid'
FROM to_be_updated
WHERE dfm.name = to_be_updated.name;

--delete from dose_form_mapped if target concept is still U/D
WITH to_be_deleted AS (
                      SELECT *
                      FROM dose_form_mapped
                      WHERE concept_id_2 IN (
                                            SELECT concept_id
                                            FROM concept
                                            WHERE invalid_reason IS NOT NULL
                                            )
                      )
DELETE
FROM dose_form_mapped
WHERE name IN (
              SELECT name
              FROM to_be_deleted
              )
;


DROP TABLE IF EXISTS dose_form_to_map;

--dose_form to_map
CREATE TABLE IF NOT EXISTS dose_form_to_map AS
SELECT DISTINCT dcs.concept_name AS name
FROM drug_concept_stage dcs
WHERE concept_class_id = 'Dose Form'
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM dose_form_mapped
                              WHERE name IS NOT NULL
                              )
ORDER BY dcs.concept_name
;
--== dose_form_to_map ==--
SELECT DISTINCT tm.name,
                '' AS new_name,
                '' AS comment,
                NULL AS precedence,
                NULL AS target_concept_id,
                NULL AS concept_code,
                NULL AS concept_name,
                NULL AS concept_class_id,
                NULL AS standard_concept,
                NULL AS invalid_reason,
                NULL AS domain_id,
                NULL AS target_vocabulary_id
FROM dose_form_to_map tm
WHERE lower(tm.name) NOT IN (
                            SELECT lower(new_name)
                            FROM dose_form_mapped
                            WHERE new_name IS NOT NULL
                            )
ORDER BY tm.name;


/****************************************/
--5. Unit

--delete from unit_mapped if target concept is U/D
WITH to_be_deleted AS (
                      SELECT *
                      FROM unit_mapped
                      WHERE concept_id_2 IN (
                                            SELECT concept_id
                                            FROM concept
                                            WHERE invalid_reason IS NOT NULL
                                            )
                      )
DELETE
FROM unit_mapped
WHERE name IN (
              SELECT name
              FROM to_be_deleted
              )
;


DROP TABLE IF EXISTS unit_to_map;

--unit to_map
CREATE TABLE IF NOT EXISTS unit_to_map AS
SELECT DISTINCT dcs.concept_name AS name
FROM drug_concept_stage dcs
WHERE concept_class_id = 'Unit'
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM unit_mapped
                              WHERE name IS NOT NULL
                              )
ORDER BY dcs.concept_name
;

--== unit_to_map ==--
SELECT DISTINCT tm.name,
                '' AS new_name,
                '' AS comment,
                NULL AS precedence,
                NULL AS conversion_factor,
                NULL AS target_concept_id,
                NULL AS concept_code,
                NULL AS concept_name,
                NULL AS concept_class_id,
                NULL AS standard_concept,
                NULL AS invalid_reason,
                NULL AS domain_id,
                NULL AS target_vocabulary_id
FROM unit_to_map tm
WHERE lower(tm.name) NOT IN (
                            SELECT lower(new_name)
                            FROM unit_mapped
                            WHERE new_name IS NOT NULL
                            )
ORDER BY tm.name;

-- populate manually mapped tables with new concepts before proceeding with load_stage_2.
