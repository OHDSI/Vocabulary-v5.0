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
* Authors: Christian Reich, Anna Ostropolets
* Date: 06-05-2019
**************************************************************************/


-- SET LATEST UPDATE
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.SetLatestUpdate(
                        pVocabularyName => 'JMDC',
                        pVocabularyDate => CURRENT_DATE,
                        pVocabularyVersion => 'JMDC ' || to_date('20200430', 'YYYYMMDD'),
                        pVocabularyDevSchema => 'DEV_JMDC'
                    );
        PERFORM VOCABULARY_PACK.SetLatestUpdate(
                        pVocabularyName => 'RxNorm Extension',
                        pVocabularyDate => CURRENT_DATE,
                        pVocabularyVersion => 'RxNorm Extension ' || CURRENT_DATE,
                        pVocabularyDevSchema => 'DEV_JMDC',
                        pAppendVocabulary => TRUE
                    );
    END
$_$;


/*************************************************
* Create sequence for entities that do not have source codes *
*************************************************/
TRUNCATE TABLE non_drug;
TRUNCATE TABLE drug_concept_stage;
TRUNCATE TABLE ds_stage;
TRUNCATE TABLE internal_relationship_stage;
TRUNCATE TABLE pc_stage;

DROP SEQUENCE IF EXISTS new_vocab;
CREATE SEQUENCE new_vocab INCREMENT BY 1 START WITH 1 CACHE 20;

/*************************************************
* 0. Clean the data and extract non drugs *
*************************************************/
-- Preliminary work: manually identify new packs and add them to aut_pc_stage table (ingredients,dose forms and dosages; brand names and suplliers if applicable)

-- DROP TABLE IF EXISTS aut_pc_stage;
-- CREATE TABLE aut_pc_stage AS
-- SELECT *
-- FROM jmdc
-- WHERE formulation_small_classification_name = 'Pack';


-- Radiopharmaceuticals, scintigraphic material and blood products
INSERT INTO non_drug
SELECT DISTINCT
    CASE
        WHEN brand_name IS NOT NULL
            THEN REPLACE(
                SUBSTR(general_name || ' ' || CONCAT(standardized_unit, NULL) || ' [' || brand_name || ']', 1, 255),
                '  ', ' ')
        ELSE TRIM(SUBSTR(general_name || ' ' || CONCAT(standardized_unit, NULL), 1, 255)) END AS concept_name,
    'JMDC', 'Device', 'S', jmdc_drug_code, NULL, 'Device', TO_DATE('19700101', 'YYYYMMDD'),
    TO_DATE('20991231', 'YYYYMMDD'), NULL
FROM jmdc
WHERE general_name ~*
      ('(99mTc)|(131I)|(89Sr)|capsule|iodixanol|iohexol|ioxilan|ioxaglate|iopamidol|iothalamate|(123I)|(9 Cl)|(111In)|(13C)|' ||
       '(123I)|(51Cr)|(201Tl)|(133Xe)|(90Y)|(81mKr)|(90Y)|(67Ga)|gadoter|gadopent|manganese chloride tetrahydrate|amino acid|' ||
       'barium sulfate|cellulose,oxidized|purified tuberculin|blood|plasma|diagnostic|nutrition|patch test|free milk|vitamin/|' ||
       'white ointment|simple syrup|electrolyte|allergen extract(therapeutic)|simple ointment|absorptive|hydrophilic') -- cellulose = Surgicel Absorbable Hemostat
  AND NOT general_name ~* 'coagulation|an extract from hemolysed blood'; -- coagulation factors


INSERT INTO non_drug
SELECT DISTINCT
    CASE
        WHEN brand_name IS NOT NULL
            THEN REPLACE(
                SUBSTR(general_name || ' ' || CONCAT(standardized_unit, NULL) || ' [' || brand_name || ']', 1, 255),
                '  ', ' ')
        ELSE TRIM(SUBSTR(general_name || ' ' || CONCAT(standardized_unit, NULL), 1, 255)) END AS concept_name,
    'JMDC', 'Device', 'S', jmdc_drug_code, NULL, 'Device', TO_DATE('19700101', 'YYYYMMDD'),
    TO_DATE('20991231', 'YYYYMMDD'), NULL
FROM jmdc
WHERE who_atc_code LIKE 'V08%'
   OR formulation_medium_classification_name IN ('Diagnostic Use');

INSERT INTO non_drug
SELECT DISTINCT
    CASE
        WHEN brand_name IS NOT NULL
            THEN REPLACE(
                SUBSTR(general_name || ' ' || CONCAT(standardized_unit, NULL) || ' [' || brand_name || ']', 1, 255),
                '  ', ' ')
        ELSE TRIM(SUBSTR(general_name || ' ' || CONCAT(standardized_unit, NULL), 1, 255)) END AS concept_name,
    'JMDC', 'Device', 'S', jmdc_drug_code, NULL, 'Device', TO_DATE('19700101', 'YYYYMMDD'),
    TO_DATE('20991231', 'YYYYMMDD'), NULL
FROM jmdc
WHERE LOWER(general_name) IN
      ('maintenance solution', 'maintenance solution with acetic acid',
       'maintenance solution with acetic acid(with glucose)', 'maintenance solution(with glucose)',
       'artificial kidney dialysis preparation',
       'benzoylmercaptoacetylglycylglycylglycine', 'diethylenetriamine pentaacetate',
       'ethyelenebiscysteinediethylester dichloride', 'hydroxymethylene diphosphonate',
       'postoperative recovery solution',
       'tetrakis(methoxyisobutylisonitrile)cu(i)tetrafluoroborate', 'witepsol', 'peritoneal dialysis solution',
       'intravenous hyperalimentative basic solution', 'macroaggregated human serum albumin');


-- Create copy of input data
DROP TABLE IF EXISTS j;
CREATE TABLE j AS
SELECT *
FROM jmdc
WHERE jmdc_drug_code NOT IN (
                            SELECT concept_code
                            FROM non_drug
                            );

DELETE
FROM j
WHERE LOWER(general_name) IN
      ('allergen extract(therapeutic)', 'therapeutic allergen extract', 'allergen disk', 'initiating solution',
       'white soft sugar');


DROP TABLE IF EXISTS supplier;
CREATE TABLE supplier
AS
SELECT TRIM(SUBSTRING(brand_name, ' \w+$')) AS concept_name, jmdc_drug_code
FROM j -- upper case suppliers in the end of the line
WHERE SUBSTRING(brand_name, ' \w+$') = UPPER(SUBSTRING(brand_name, ' \w+$'))
  AND LENGTH(SUBSTRING(brand_name, ' \w+$')) > 4
  AND TRIM(SUBSTRING(brand_name, ' \w+$')) NOT IN ('A240', 'VIII')
UNION
SELECT TRIM(SUBSTRING(brand_name, '^\w+ ')) AS concept_name, jmdc_drug_code
FROM j -- upper case suppliers in the beginning of the line
WHERE SUBSTRING(brand_name, '^\w+ ') = UPPER(SUBSTRING(brand_name, '^\w+ '))
  AND LENGTH(SUBSTRING(brand_name, '^\w+ ')) > 4
  AND TRIM(SUBSTRING(brand_name, '^\w+ ')) NOT IN ('A240', 'VIII')
UNION
SELECT DISTINCT
    REPLACE(REPLACE(SUBSTRING(brand_name, '\[\w+\]'), '[', ''), ']', '') AS concept_name,
    jmdc_drug_code -- the position doesn't matter since it's in brackets
FROM j
WHERE LENGTH(REPLACE(REPLACE(SUBSTRING(brand_name, '\[\w+\]'), '[', ''), ']', '')) >
      1 -- something like [F] that we do not need
;

--ingredient
DELETE
FROM supplier
WHERE jmdc_drug_code = '100000049525'
  AND concept_name = 'GHRP'; --GHRP KAKEN 100 for Injection

DELETE
FROM supplier
WHERE concept_name = 'WATER';


update supplier
set concept_name = upper(concept_name)
where concept_name in ('Matsuura', 'Nichifun', 'Honzo');


UPDATE j
SET brand_name = REPLACE(brand_name, SUBSTRING(brand_name, ' \w+$'), '')
WHERE SUBSTRING(brand_name, ' \w+$') = UPPER(SUBSTRING(brand_name, ' \w+$'))
  AND LENGTH(SUBSTRING(brand_name, ' \w+$')) > 4
  AND TRIM(SUBSTRING(brand_name, ' \w+$')) NOT IN ('A240', 'VIII')
;

UPDATE j
SET brand_name = REPLACE(brand_name, SUBSTRING(brand_name, '^\w+ '), '')
WHERE SUBSTRING(brand_name, '^\w+ ') = UPPER(SUBSTRING(brand_name, '^\w+ '))
  AND LENGTH(SUBSTRING(brand_name, '^\w+ ')) > 4
  AND TRIM(SUBSTRING(brand_name, '^\w+ ')) NOT IN ('A240', 'VIII')
;

-- all new items with [] are generics by their nature
UPDATE j
SET brand_name = NULL
WHERE brand_name LIKE '%[%]%'
;

-- Remove pseudo brands
UPDATE j
SET brand_name = NULL
WHERE brand_name IN (
                     '5-FU',
                     'Acrinol and Zinc Oxide Oil',
                     'Biogen',
                     'Caffeine and Sodium Benzoate',
                     'Calcium L-Aspartate',
                     'Compound Oxycodone and Atropine',
                     'Crude Drugs',
                     'Deleted NHI price',
                     'Gel',
                     'Glycerin and Potash',
                     'Horizon',
                     'Morphine and Atropine',
                     'Nor-Adrenalin',
                     'Opium Alkaloids and Atropine',
                     'Opium Alkaloids and Scopolamine',
                     'Phenol and Zinc Oxide Liniment',
                     'Scopolia Extract and Tannic Acid',
                     'Sulfur and Camphor',
                     'Sulfur,Salicylic Acid and Thianthol',
                     'Swertia and Sodium Bicarbonate',
                     'Unknown Brand Name in English',
                     'Vega',
                     'Wasser',
                     'Weak Opium Alkaloids and Scopolamine'
    )
   OR LOWER(brand_name) = LOWER(general_name)
   OR brand_name ~*
      'Sulfate|Nitrate|Acetat|Oxide|Saponated|Salicylat|Chloride|/|Acid|Sodium|Aluminum|Potassium|Ammonia|Ringer|Invert Soap|Dried Yeast|Fluidextract|Kakko| RTU|Infusion Solution| KO$|Globulin|Absorptive Ointment|Allergen|Water'
;

UPDATE j
SET brand_name = NULL
WHERE brand_name IN (
                    SELECT DISTINCT brand_name
                    FROM j
                    JOIN devv5.concept c
                        ON LOWER(j.brand_name) = LOWER(c.concept_name)
                    WHERE c.concept_class_id LIKE '%Ingredient'
                    );


UPDATE j
SET brand_name = NULL
WHERE LOWER(brand_name) IN (
                           SELECT LOWER(concept_name)
                           FROM supplier
                           );

UPDATE j
SET brand_name = NULL
WHERE LOWER(brand_name) || ' extract' IN (
                                         SELECT LOWER(general_name)
                                         FROM j
                                         );

UPDATE j
SET brand_name = NULL
WHERE LENGTH(brand_name) < 3;

UPDATE j
SET brand_name = NULL
WHERE brand_name LIKE '% %'
  AND brand_name ~*
      'NIPPON-ZOKI|KANADA|BIKEN|Antivenom|KITASATO|NICHIIKO|JPS | Equine|Otsujito|Bitter Tincture|Syrup| SW|Concentrate| MED| DSP$| DK$| KN$| KY$| YP$| UJI$| TTS$| MDP$| JG$| KN$|SEIKA|KYOWA|SHOWA|NikP| JCR| NK$| HK$|Japanese Strain| CH$| TCK| FM| Na | Na$| AFP|Gargle|Injection| Ca | Ca$|KOBAYASI| TYK| NIKKO| YD| KOG| FFP| NP| NS| TSU| KOG| SN| TS| NP| YD';

UPDATE j
SET brand_name = NULL
WHERE brand_name ~*
      'Tosufloxacin Tosilate|Succinate|OTSUKA|Kenketsu|Ethanol|Powder|JANSSEN|Disinfection|Oral|Gluconate| TN$|FUSO|Sugar| TOA$|Prednisolone Acetate T|I''ROM| BMD$|^KTS |Taunus Aqua|Cefamezin alfa|Bromide|Vaccine';

UPDATE j
SET brand_name = NULL
WHERE brand_name ~*
      'ASAHI| CMX|Lawter Leaf|Kakkontokasenkyushin| HMT|Saikokeishito|Dibasic Calcium Phosphate| Hp$| F$| HT$| TC$| AA$| MP$|Freeze-dried| AY$| KTB| CEO|Ethyl Aminobenzoate| QQ$|Viscous|Tartrate|NIPPON| EE$|Tincture';

-- multi-ingredients fixes
UPDATE j
SET general_name = 'ampicillin sodium/sulbactam sodium'
WHERE LOWER(general_name) = 'sultamicillin tosilate hydrate';

UPDATE j
SET general_name = 'follicle stimulating hormone/luteinizing hormone'
WHERE LOWER(general_name) = 'human menopausal gonadotrophin';

UPDATE j
SET general_name = 'human normal immunoglobulin/histamine'
WHERE LOWER(general_name) = 'immunoglobulin with histamine';

-- remove junk from standard_unit
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(forGeneralDiagnosis\)', '')
WHERE standardized_unit LIKE '%(forGeneralDiagnosis)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(forGeneralDiagnosis/forOnePerson\)', '')
WHERE standardized_unit LIKE '%(forGeneralDiagnosis/forOnePerson)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(forStrongResponsePerson\)', '')
WHERE standardized_unit LIKE '%(forStrongResponsePerson)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(MixedPreparedInjection\)', '')
WHERE standardized_unit LIKE '%(MixedPreparedInjection)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'w/NS', '')
WHERE standardized_unit LIKE '%w/NS%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(w/Soln\)', '')
WHERE standardized_unit LIKE '%(w/Soln)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(asSoln\)', '')
WHERE standardized_unit LIKE '%(asSoln)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(w/DrainageBag\)', '')
WHERE standardized_unit LIKE '%(w/DrainageBag)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(w/Sus\)', '')
WHERE standardized_unit LIKE '%(w/Sus)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(asgoserelin\)', '')
WHERE standardized_unit LIKE '%(asgoserelin)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(Amountoftegafur\)', '')
WHERE standardized_unit LIKE '%(Amountoftegafur)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(as levofloxacin\)', '')
WHERE standardized_unit LIKE '%(as levofloxacin)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(as phosphorus\)', '')
WHERE standardized_unit LIKE '%(as phosphorus)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(asActivatedform\)', '')
WHERE standardized_unit LIKE '%(asActivatedform)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'teriparatideacetate', '')
WHERE standardized_unit LIKE '%teriparatideacetate%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'Elcatonin', '')
WHERE standardized_unit LIKE '%Elcatonin%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(asSuspendedLiquid\)', '')
WHERE standardized_unit LIKE '%(asSuspendedLiquid)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(mixedOralLiquid\)', '')
WHERE standardized_unit LIKE '%(mixedOralLiquid)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(w/Soln,Dil\)', '')
WHERE standardized_unit LIKE '%(w/Soln,Dil)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'DomesticStandard', '')
WHERE standardized_unit LIKE '%DomesticStandard%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'million', '000000')
WHERE standardized_unit LIKE '%million%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'U\.S\.P\.', '')
WHERE standardized_unit LIKE '%U.S.P.%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'about', '')
WHERE standardized_unit LIKE '%about%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'iron', '')
WHERE standardized_unit LIKE '%iron%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, ':240times', '')
WHERE standardized_unit LIKE '%:240times%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'low-molecularheparin', '')
WHERE standardized_unit LIKE '%low-molecularheparin%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(asCalculatedamountofD-arabinose\)', '')
WHERE standardized_unit LIKE '%(asCalculatedamountofD-arabinose)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'w/5%GlucoseInjection', '')
WHERE standardized_unit LIKE '%w/5\%GlucoseInjection%' ESCAPE '\';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'w/WaterforInjection', '')
WHERE standardized_unit LIKE '%w/WaterforInjection%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(w/SodiumBicarbonate\)', '')
WHERE standardized_unit LIKE '%(w/SodiumBicarbonate)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'potassium', '')
WHERE standardized_unit LIKE '%potassium%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(Amountoftrifluridine\)', '')
WHERE standardized_unit LIKE '%(Amountoftrifluridine)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'FRM', '')
WHERE standardized_unit LIKE '%FRM%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'NormalHumanPlasma', '')
WHERE standardized_unit LIKE '%NormalHumanPlasma%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'Anti-factorXa', '')
WHERE standardized_unit LIKE '%Anti-factorXa%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(w/SodiumBicarbonateSoln\)', '')
WHERE standardized_unit LIKE '%(w/SodiumBicarbonateSoln)%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, ',CorSoln', '')
WHERE standardized_unit LIKE '%,CorSoln%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '1Set', '')
WHERE standardized_unit LIKE '%1Set%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, 'AmountforOnce', '')
WHERE standardized_unit LIKE '%AmountforOnce%';
UPDATE j
SET standardized_unit = REGEXP_REPLACE(standardized_unit, '\(w/Dil\)', '')
WHERE standardized_unit LIKE '%(w/Dil)%';

/*************************************************
* 1. Create parsed Ingredients and relationships *
*************************************************/

DROP TABLE IF EXISTS PI;
CREATE TABLE pi
AS
SELECT jmdc_drug_code, TRIM(ing_name) AS ing_name
FROM (
     SELECT jmdc_drug_code, LOWER(general_name) AS ing_name
     FROM j
     WHERE general_name NOT LIKE '%/%'
       AND general_name NOT LIKE '% and %'
     UNION
     SELECT jmdc_drug_code, LOWER(ing_name)
     FROM (
          SELECT jmdc_drug_code, REPLACE(general_name, ' and ', '/') AS concept_name
          FROM j
          ) j,
          UNNEST(STRING_TO_ARRAY(j.concept_name, '/')) AS ing_name
     ) a
WHERE jmdc_drug_code NOT IN
      (
      SELECT jmdc_drug_code
      FROM aut_pc_stage
      );


DELETE
FROM pi
WHERE LOWER(ing_name) IN ('rhizome', 'water extract')--eliminating wrong parsing
;

UPDATE pi
SET ing_name = TRIM(REGEXP_REPLACE(ing_name, '\(genetical recombination\)', ''))
WHERE ing_name ~* 'genetical recombination';
UPDATE pi
SET ing_name = TRIM(REGEXP_REPLACE(ing_name, 'adhesive plaster', ''))
WHERE ing_name ~* 'adhesive plaster';


INSERT INTO pi
SELECT jmdc_drug_code, LOWER(concept_name)
FROM pi
JOIN aut_parsed_ingr
    USING (ing_name);

DELETE
FROM pi
WHERE ing_name IN
      (
      SELECT ing_name
      FROM aut_parsed_ingr
      );

/************************************
* 2. Populate drug concept stage *
*************************************/
-- Drugs
INSERT INTO drug_concept_stage
SELECT DISTINCT
    CASE
        WHEN brand_name IS NOT NULL
            THEN REPLACE(
                SUBSTR(general_name || ' ' || CONCAT(standardized_unit, NULL) || ' [' || brand_name || ']', 1, 255),
                '  ', ' ')
        ELSE TRIM(SUBSTR(general_name || ' ' || CONCAT(standardized_unit, NULL), 1, 255)) END AS concept_name,
    'JMDC'                                                                                    AS vocabulary_id,
    'Drug Product'                                                                            AS concept_class_id,
    NULL                                                                                      AS standard_concept,
    jmdc_drug_code                                                                            AS concept_code,
    NULL                                                                                      AS possible_excipient,
    'Drug'                                                                                    AS domain_id,
    TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'),
    NULL                                                                                      AS invalid_reason
FROM j;


-- Drugs from packs
INSERT INTO drug_concept_stage
SELECT
    concept_name,
    'JMDC'                         AS vocabulary_id,
    'Drug Product'                 AS concept_class_id,
    NULL                           AS standard_concept,
    'JMDC' || NEXTVAL('new_vocab') AS concept_code,
    NULL                           AS possible_excipient,
    'Drug',
    TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'),
    NULL                           AS invalid_reason
FROM (
     SELECT DISTINCT
         SUBSTR(ingredient || ' ' || dosage || ' ' || LOWER(form), 1, 255) AS concept_name
     FROM aut_pc_stage
     ) a
;

-- Devices
INSERT INTO drug_concept_stage
SELECT DISTINCT *
FROM non_drug;

-- Ingredients
INSERT INTO drug_concept_stage
SELECT
    TRIM(ing_name)                 AS concept_name,
    'JMDC'                         AS vocabulary_id,
    'Ingredient'                   AS concept_class_id,
    NULL                           AS standard_concept,
    'JMDC' || NEXTVAL('new_vocab') AS concept_code,
    NULL                           AS possible_excipient,
    'Drug',
    TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'),
    NULL                           AS invalid_reason
FROM (
     SELECT DISTINCT ing_name
     FROM pi
     ) a;

-- Brand Name
INSERT INTO drug_concept_stage
SELECT
    brand_name                     AS concept_name,
    'JMDC'                         AS vocabulary_id,
    'Brand Name'                   AS concept_class_id,
    NULL                           AS standard_concept,
    'JMDC' || NEXTVAL('new_vocab') AS concept_code,
    NULL                           AS possible_excipient,
    'Drug',
    TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'),
    NULL                           AS invalid_reason
FROM (
     SELECT DISTINCT brand_name
     FROM j
     WHERE brand_name IS NOT NULL
     ) a
;

-- Dose Forms
-- is populated based on manual tables
INSERT INTO drug_concept_stage
SELECT
    concept_name,
    'JMDC'                         AS vocabulary_id,
    'Dose Form'                    AS concept_class_id,
    NULL                           AS standard_concept,
    'JMDC' || NEXTVAL('new_vocab') AS concept_code,
    NULL                           AS possible_excipient,
    'Drug',
    TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'),
    NULL                           AS invalid_reason
FROM (
     SELECT DISTINCT COALESCE(new_name, concept_name) AS concept_name FROM aut_form_mapped
     ) a
;

-- Units
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                domain_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('u', 'JMDC', 'Unit', NULL, 'u', 'Drug', TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), NULL);
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                domain_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('iu', 'JMDC', 'Unit', NULL, 'iu', 'Drug', TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'),
        NULL);
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                domain_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('g', 'JMDC', 'Unit', NULL, 'g', 'Drug', TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), NULL);
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                domain_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('mg', 'JMDC', 'Unit', NULL, 'mg', 'Drug', TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'),
        NULL);
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                domain_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('mlv', 'JMDC', 'Unit', NULL, 'mlv', 'Drug', TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'),
        NULL);
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                domain_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('ml', 'JMDC', 'Unit', NULL, 'ml', 'Drug', TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'),
        NULL);
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                domain_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('%', 'JMDC', 'Unit', NULL, '%', 'Drug', TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), NULL);
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                domain_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('ug', 'JMDC', 'Unit', NULL, 'ug', 'Drug', TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'),
        NULL);
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                domain_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('actuat', 'JMDC', 'Unit', NULL, 'actuat', 'Drug', TO_DATE('19700101', 'YYYYMMDD'),
        TO_DATE('20991231', 'YYYYMMDD'), NULL);
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                domain_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('mol', 'JMDC', 'Unit', NULL, 'mol', 'Drug', TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'),
        NULL);
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                domain_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('mEq', 'JMDC', 'Unit', NULL, 'mEq', 'Drug', TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'),
        NULL);
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                domain_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('ku', 'JMDC', 'Unit', NULL, 'ku', 'Drug', TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'),
        NULL);
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                domain_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('ul', 'JMDC', 'Unit', NULL, 'ul', 'Drug', TO_DATE('19700101', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'),
        NULL);


--Supplier
INSERT INTO drug_concept_stage (concept_name, vocabulary_id, concept_class_id, standard_concept, concept_code,
                                domain_id, valid_start_date, valid_end_date, invalid_reason)
SELECT
    concept_name,
    'JMDC'                         AS vocabulary_id,
    'Supplier'                     AS concept_class_id,
    NULL                           AS standard_concept,
    'JMDC' || NEXTVAL('new_vocab') AS concept_code,
    'Drug',
    TO_DATE('19700101', 'YYYYMMDD'),
    TO_DATE('20991231', 'YYYYMMDD'),
    NULL                           AS invalid_reason
FROM (
     SELECT DISTINCT s.concept_name
     FROM supplier s
     LEFT JOIN aut_suppliers_mapped sm
         ON UPPER(sm.source_name) = UPPER(s.concept_name)
     ) s;


/*************************************************
* 3. Populate IRS *
*************************************************/

-- 3.1 create relationship between products and ingredients
INSERT INTO internal_relationship_stage
SELECT DISTINCT
    pi.jmdc_drug_code AS concept_code_1,
    dcs.concept_code  AS concept_code_2
FROM pi
JOIN drug_concept_stage dcs
    ON dcs.concept_name = pi.ing_name AND dcs.concept_class_id = 'Ingredient'
;

-- 3.1.1 drugs from packs
INSERT INTO internal_relationship_stage
SELECT DISTINCT
    dcs2.concept_code AS concept_code_1,
    dcs.concept_code  AS concept_code_2
FROM aut_pc_stage
JOIN drug_concept_stage dcs
    ON dcs.concept_name = ingredient AND dcs.concept_class_id = 'Ingredient'
JOIN drug_concept_stage dcs2
    ON dcs2.concept_name = SUBSTR(ingredient || ' ' || dosage || ' ' || LOWER(form), 1, 255)
;

-- 3.2 create relationship between products and BN
INSERT INTO internal_relationship_stage
SELECT DISTINCT
    j.jmdc_drug_code AS concept_code_1,
    dcs.concept_code AS concept_code_2
FROM j
JOIN drug_concept_stage dcs
    ON dcs.concept_name = j.brand_name AND dcs.concept_class_id = 'Brand Name'
;

-- 3.3 create relationship between products and DF
INSERT INTO internal_relationship_stage
SELECT DISTINCT jmdc_drug_code, dc.concept_code
FROM aut_form_mapped a
JOIN j
    ON TRIM(formulation_small_classification_name) = a.concept_name
--     ON TRIM(formulation_large_classification_name) = a.concept_name
JOIN drug_concept_stage dc
    ON dc.concept_name = COALESCE(a.new_name, a.concept_name)
WHERE dc.concept_class_id = 'Dose Form'
;

-- 3.3.1 drugs from packs
INSERT INTO internal_relationship_stage
SELECT DISTINCT
    dcs2.concept_code AS concept_code_1,
    dcs.concept_code  AS concept_code_2
FROM aut_pc_stage
JOIN drug_concept_stage dcs
    ON dcs.concept_name = form AND dcs.concept_class_id = 'Dose Form'
JOIN drug_concept_stage dcs2
    ON dcs2.concept_name = SUBSTR(ingredient || ' ' || dosage || ' ' || LOWER(form), 1, 255)
;

-- 3.4 Suppliers
-- INSERT INTO internal_relationship_stage (concept_code_1, concept_code_2)
-- SELECT DISTINCT jmdc_drug_code, concept_code
-- FROM supplier s
-- LEFT JOIN aut_suppliers_mapped a
--     ON UPPER(a.source_name) = UPPER(s.concept_name)
-- JOIN drug_concept_stage dc
--     ON dc.concept_name = COALESCE(a.concept_name, s.concept_name)
-- WHERE concept_class_id = 'Supplier';

INSERT INTO internal_relationship_stage (concept_code_1, concept_code_2)
select s.jmdc_drug_code, dcs.concept_code
    from supplier s
join drug_concept_stage dcs
on upper(s.concept_name) = UPPER(dcs.concept_name)
where dcs.concept_class_id = 'Supplier';


/*********************************
* 4. Create and link Drug Strength
*********************************/

-- 4.1 g|mg|ug|mEq|MBq|IU|KU|U
INSERT INTO ds_stage
SELECT DISTINCT
    j.jmdc_drug_code,
    dcs.concept_code,
    CAST(SUBSTRING(REGEXP_REPLACE(standardized_unit, '[,()]', '', 'g') FROM
                   '^(\d+\.*\d*)(?=(g|mg|ug|mEq|MBq|IU|KU|U)(|1T|1Syg|1A|1V|1Bag|each/V|1C|1Pack|1Pc|1Kit|1Sheet|1Bot|1Bls|1P|(\d+\.*\d*)(cm|mm)(2|\*(\d+\.*\d*)(cm|mm)))(|1Sheet)($))') AS double precision),
    SUBSTRING(REGEXP_REPLACE(standardized_unit, '[,()]', '', 'g') FROM
              '(?<=^(\d+\.*\d*))(g|mg|ug|mEq|MBq|IU|KU|U)(?=(|1T|1Syg|1A|1V|1Bag|each/V|1C|1Pack|1Pc|1Kit|1Sheet|1Bot|1Bls|1P|(\d+\.*\d*)(cm|mm)(2|\*(\d+\.*\d*)(cm|mm)))(|1Sheet)($))')
FROM j
JOIN pi
    ON j.jmdc_drug_code = pi.jmdc_drug_code
JOIN drug_concept_stage dcs
    ON pi.ing_name = dcs.concept_name
WHERE general_name !~ '\/'
  AND REGEXP_REPLACE(standardized_unit, '[,()]', '', 'g') ~
      '^(\d+\.*\d*)(g|mg|ug|mEq|MBq|IU|KU|U)(|1T|1Syg|1A|1V|1Bag|each/V|1C|1Pack|1Pc|1Kit|1Sheet|1Bot|1Bls|1P|(\d+\.*\d*)(cm|mm)(2|\*(\d+\.*\d*)(cm|mm)))(|1Sheet)($)'
  AND dcs.concept_class_id = 'Ingredient';

--4.2 liquid % / ml|l
INSERT INTO ds_stage
SELECT DISTINCT
    j.jmdc_drug_code,
    dcs.concept_code,
    CAST(NULL AS double precision),
    NULL,
    CAST(SUBSTRING(standardized_unit FROM
                   '^(\d+\.*\d*)(?=(%)(\d+\.*\d*)(mL|L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($))') AS double precision)
        * CAST(SUBSTRING(standardized_unit FROM
                         '(?<=^(\d+\.*\d*)(%))(\d+\.*\d*)(?=(mL|L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($))') AS double precision)
        * CASE
              WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mL)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($)'
                  THEN 10
              WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($)'
                  THEN 10000 END,
    'mg',
    CAST(SUBSTRING(standardized_unit FROM
                   '(?<=^(\d+\.*\d*)(%))(\d+\.*\d*)(?=(mL|L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($))') AS double precision)
        * CASE
              WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mL)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($)'
                  THEN 1
              WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($)'
                  THEN 1000 END,
    'ml'
FROM j
JOIN pi
    ON j.jmdc_drug_code = pi.jmdc_drug_code
JOIN drug_concept_stage dcs
    ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mL|L)(|1Syg|1V|1A|1Bag|1Bot|1Kit|1Pack|V|1Pc)($)'
  AND dcs.concept_class_id = 'Ingredient';

--4.3 solid % / g|mg
INSERT INTO ds_stage
SELECT DISTINCT
    j.jmdc_drug_code,
    dcs.concept_code,
    CAST(NULL AS double precision),
    NULL,
    CAST(SUBSTRING(standardized_unit FROM
                   '^(\d+\.*\d*)(?=(%)(\d+\.*\d*)(mg|g)(|1Pack|1Bot|1can|1V|1Pc)($))') AS double precision)
        * CAST(SUBSTRING(standardized_unit FROM
                         '(?<=^(\d+\.*\d*)(%))(\d+\.*\d*)(?=(mg|g)(|1Pack|1Bot|1can|1V|1Pc)($))') AS double precision)
        * CASE
              WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(g)(|1Pack|1Bot|1can|1V|1Pc)($)'
                  THEN 10
              WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mg)(|1Pack|1Bot|1can|1V|1Pc)($)'
                  THEN 0.01 END,
    'mg',
    CAST(SUBSTRING(standardized_unit FROM
                   '(?<=^(\d+\.*\d*)(%))(\d+\.*\d*)(?=(mg|g)(|1Pack|1Bot|1can|1V|1Pc)($))') AS double precision)
        * CASE
              WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(g)(|1Pack|1Bot|1can|1V|1Pc)($)'
                  THEN 1000
              WHEN standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mg)(|1Pack|1Bot|1can|1V|1Pc)($)'
                  THEN 1 END,
    'mg'
FROM j
JOIN pi
    ON j.jmdc_drug_code = pi.jmdc_drug_code
JOIN drug_concept_stage dcs
    ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND standardized_unit ~ '^(\d+\.*\d*)(\%)(\d+\.*\d*)(mg|g)(|1Pack|1Bot|1can|1V|1Pc)($)'
  AND dcs.concept_class_id = 'Ingredient';

--4.4 mg|mol|ug|g|IU|U|mEq / mL|uL|g
INSERT INTO ds_stage
SELECT DISTINCT
    j.jmdc_drug_code,
    dcs.concept_code,
    CAST(NULL AS double precision),
    NULL,
    CAST(SUBSTRING(REGEXP_REPLACE(standardized_unit, ',', '', 'g') FROM
                   '^(\d+\.*\d*)(?=(mg|mol|ug|g|IU|U|mEq)(\d+\.*\d*)(mL|uL|g)(|1A|1Pc|1Syg|1Kit|1Bot|V|1V|1Bag|1Pack)($))') AS double precision),
    SUBSTRING(REGEXP_REPLACE(standardized_unit, ',', '', 'g') FROM
              '(?<=^(\d+\.*\d*))(mg|mol|ug|g|IU|U|mEq)(?=(\d+\.*\d*)(mL|uL|g)(|1A|1Pc|1Syg|1Kit|1Bot|V|1V|1Bag|1Pack)($))'),
    CAST(SUBSTRING(REGEXP_REPLACE(standardized_unit, ',', '', 'g') FROM
                   '(?<=^(\d+\.*\d*)(mg|mol|ug|g|IU|U|mEq))(\d+\.*\d*)(?=(mL|uL|g)(|1A|1Pc|1Syg|1Kit|1Bot|V|1V|1Bag|1Pack)($))') AS double precision),
    SUBSTRING(REGEXP_REPLACE(standardized_unit, ',', '', 'g') FROM
              '(?<=^(\d+\.*\d*)(mg|mol|ug|g|IU|U|mEq)(\d+\.*\d*))(mL|uL|g)(?=(|1A|1Pc|1Syg|1Kit|1Bot|V|1V|1Bag|1Pack)($))')
FROM j
JOIN pi
    ON j.jmdc_drug_code = pi.jmdc_drug_code
JOIN drug_concept_stage dcs
    ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND REGEXP_REPLACE(standardized_unit, ',', '', 'g') ~
      '^(\d+\.*\d*)(mg|mol|ug|g|IU|U|mEq)(\d+\.*\d*)(mL|uL|g)(|1A|1Pc|1Syg|1Kit|1Bot|V|1V|1Bag|1Pack)($)'
  AND dcs.concept_class_id = 'Ingredient';

-- 4.5 ug/actuat1
INSERT INTO ds_stage
SELECT DISTINCT
    j.jmdc_drug_code,
    dcs.concept_code,
    CAST(NULL AS double precision),
    NULL,
    CAST(SUBSTRING(standardized_unit FROM '^(\d+\.*\d*)(?=(ug)(\d+\.*\d*)(Bls)(1Pc|1Kit)($))') AS double precision)
        * CAST(SUBSTRING(standardized_unit FROM
                         '(?<=^(\d+\.*\d*)(ug))(\d+\.*\d*)(?=(Bls)(1Pc|1Kit)($))') AS double precision),
    SUBSTRING(standardized_unit FROM '(?<=^(\d+\.*\d*))(ug)(?=(\d+\.*\d*)(Bls)(1Pc|1Kit)($))'),
    CAST(SUBSTRING(standardized_unit FROM
                   '(?<=^(\d+\.*\d*)(ug))(\d+\.*\d*)(?=(Bls)(1Pc|1Kit)($))') AS double precision),
    'actuat'
FROM j
JOIN pi
    ON j.jmdc_drug_code = pi.jmdc_drug_code
JOIN drug_concept_stage dcs
    ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND standardized_unit ~ '^(\d+\.*\d*)(ug)(\d+\.*\d*)(Bls)(1Pc|1Kit)($)'
  AND dcs.concept_class_id = 'Ingredient';

-- 4.6 ug/actuat2
INSERT INTO ds_stage
SELECT DISTINCT
    j.jmdc_drug_code,
    dcs.concept_code,
    CAST(NULL AS double precision),
    NULL,
    CAST(SUBSTRING(REGEXP_REPLACE(standardized_unit, '[()]', '', 'g') FROM
                   '^(\d+\.*\d*)(?=(mg|ug)(1Bot|1Kit)(\d+\.*\d*)(ug)($))') AS double precision),
    SUBSTRING(REGEXP_REPLACE(standardized_unit, '[()]', '', 'g') FROM
              '(?<=^(\d+\.*\d*))(mg|ug)(?=(1Bot|1Kit)(\d+\.*\d*)(ug)($))'),
    CAST(SUBSTRING(REGEXP_REPLACE(standardized_unit, '[()]', '', 'g') FROM
                   '^(\d+\.*\d*)(?=(mg|ug)(1Bot|1Kit)(\d+\.*\d*)(ug)($))') AS double precision)
        * CASE
              WHEN REGEXP_REPLACE(standardized_unit, '[()]', '', 'g') ~ '^(\d+\.*\d*)(ug)(1Bot|1Kit)(\d+\.*\d*)(ug)($)'
                  THEN 1
              WHEN REGEXP_REPLACE(standardized_unit, '[()]', '', 'g') ~ '^(\d+\.*\d*)(mg)(1Bot|1Kit)(\d+\.*\d*)(ug)($)'
                  THEN 1000 END
        / CAST(SUBSTRING(REGEXP_REPLACE(standardized_unit, '[()]', '', 'g') FROM
                         '(?<=^(\d+\.*\d*)(mg|ug)(1Bot|1Kit))(\d+\.*\d*)(?=(ug)($))') AS double precision),
    'actuat'
FROM j
JOIN pi
    ON j.jmdc_drug_code = pi.jmdc_drug_code
JOIN drug_concept_stage dcs
    ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND REGEXP_REPLACE(standardized_unit, '[()]', '', 'g') ~ '^(\d+\.*\d*)(mg|ug)(1Bot|1Kit)(\d+\.*\d*)(ug)($)'
  AND dcs.concept_class_id = 'Ingredient';

-- 4.7 g|mg from kits
INSERT INTO ds_stage
SELECT DISTINCT
    j.jmdc_drug_code,
    dcs.concept_code,
    CAST(SUBSTRING(REGEXP_REPLACE(standardized_unit, '[()]', '', 'g') FROM
                   '^(\d+\.*\d*)(?=(g|mg)(1Kit)(\d+\.*\d*)(mL))') AS double precision),
    SUBSTRING(REGEXP_REPLACE(standardized_unit, '[()]', '', 'g') FROM
              '(?<=^(\d+\.*\d*))(g|mg)(?=(1Kit)(\d+\.*\d*)(mL))')
FROM j
JOIN pi
    ON j.jmdc_drug_code = pi.jmdc_drug_code
JOIN drug_concept_stage dcs
    ON pi.ing_name = dcs.concept_name

WHERE general_name !~ '\/'
  AND REGEXP_REPLACE(standardized_unit, '[()]', '', 'g') ~ '^(\d+\.*\d*)(g|mg)(1Kit)(\d+\.*\d*)(mL)'
  AND dcs.concept_class_id = 'Ingredient';


-- 4.8 drugs from packs
INSERT INTO ds_stage
SELECT DISTINCT
    dcs2.concept_code,
    dcs.concept_code,
    CAST(SUBSTRING(dosage, '\d+') AS double precision),
    SUBSTRING(dosage, 'mg')
FROM aut_pc_stage
JOIN drug_concept_stage dcs
    ON dcs.concept_name = ingredient AND dcs.concept_class_id = 'Ingredient'
JOIN drug_concept_stage dcs2
    ON dcs2.concept_name = SUBSTR(ingredient || ' ' || dosage || ' ' || LOWER(form), 1, 255)
;

-- 4.9
UPDATE ds_stage
SET amount_unit      = LOWER(amount_unit),
    numerator_unit   = LOWER(numerator_unit),
    denominator_unit = LOWER(denominator_unit);

-- 4.10 convert meq to mmol
UPDATE ds_stage
SET amount_value = '595',
    amount_unit  = 'mg'
WHERE ingredient_concept_code IN (
                                 SELECT concept_code
                                 FROM drug_concept_stage
                                 WHERE concept_name = 'potassium gluconate'
                                 )
  AND amount_value = '2.5'
  AND amount_unit = 'meq';
UPDATE ds_stage
SET denominator_unit='ml'
WHERE ingredient_concept_code IN (
                                 SELECT concept_code
                                 FROM drug_concept_stage
                                 WHERE concept_name = 'potassium gluconate'
                                 )
  AND numerator_unit = 'meq';

-- 4.11 fixing inhalers

UPDATE ds_stage
SET numerator_unit   = amount_unit,
    numerator_value  = amount_value,
    amount_unit      = NULL,
    amount_value     = NULL,
    denominator_unit = 'actuat'
WHERE (drug_concept_code, ingredient_concept_code) IN
      (
      SELECT drug_concept_code, ingredient_concept_code
      FROM j
      JOIN ds_stage ds
          ON jmdc_drug_code = drug_concept_code
      WHERE who_atc_code ~ 'R01|R03'
        AND formulation_small_classification_name ~ 'Inhal'
        AND formulation_small_classification_name !~ 'Sol|Aeros'
        AND amount_unit = 'ug'
      );

UPDATE ds_stage
SET numerator_unit    = amount_unit,
    numerator_value   = amount_value,
    amount_unit       = NULL,
    amount_value      = NULL,
    denominator_value = amount_value * 100,
    denominator_unit  = 'actuat'
WHERE (drug_concept_code, ingredient_concept_code) IN
      (
      SELECT drug_concept_code, ingredient_concept_code
      FROM j
      JOIN ds_stage ds
          ON jmdc_drug_code = drug_concept_code
      WHERE who_atc_code ~ 'R01|R03'
        AND formulation_small_classification_name ~ 'Inhal'
        AND formulation_small_classification_name !~ 'Sol|Aeros'
        AND brand_name = 'Meptin'
      );

UPDATE ds_stage
SET numerator_unit    = 'ug',
    numerator_value   = '200',
    amount_unit       = NULL,
    amount_value      = NULL,
    denominator_value = '28',
    denominator_unit  = 'actuat'
WHERE (drug_concept_code, ingredient_concept_code) IN
      (
      SELECT drug_concept_code, ingredient_concept_code
      FROM j
      JOIN ds_stage ds
          ON jmdc_drug_code = drug_concept_code
      WHERE who_atc_code ~ 'R01|R03'
        AND formulation_small_classification_name ~ 'Inhal'
        AND formulation_small_classification_name !~ 'Sol|Aeros'
        AND brand_name = 'Erizas'
      );

UPDATE ds_stage
SET numerator_unit    = 'ug',
    numerator_value   = '32',
    denominator_value = NULL,
    denominator_unit  = 'actuat'
WHERE (drug_concept_code, ingredient_concept_code) IN
      (
      SELECT drug_concept_code, ingredient_concept_code
      FROM j
      JOIN ds_stage ds
          ON jmdc_drug_code = drug_concept_code
      WHERE who_atc_code ~ 'R01|R03'
        AND formulation_small_classification_name ~ 'Inhal'
        AND formulation_small_classification_name !~ 'Sol|Aeros'
        AND standardized_unit = '1.50mg0.9087g1Bot'
      );

/************************************************
* 5. Mappings for RTC *
************************************************/

-- create rtc for future releases
-- CREATE TABLE relationship_to_concept_bckp_@date
-- AS
-- SELECT *
-- FROM relationship_to_concept;

TRUNCATE TABLE relationship_to_concept;

-- 5.1 Write mappings to RxNorm Dose Forms
-- delete invalid forms
DELETE
FROM aut_form_mapped
WHERE concept_id_2 IN
      (
      SELECT concept_id
      FROM concept
      WHERE invalid_reason IS NOT NULL
      )
;

-- get the list of forms to map
DROP TABLE IF EXISTS aut_form_to_map;
CREATE TABLE aut_form_to_map
AS
SELECT *
FROM drug_concept_stage
WHERE concept_name NOT IN
      (
      SELECT COALESCE(new_name, concept_name)
      FROM aut_form_mapped
      )
  AND concept_class_id = 'Dose Form';


-- 5.2 Write mappings to real units
-- get list of units
DROP TABLE IF EXISTS aut_unit_to_map;
CREATE TABLE aut_unit_to_map
AS
SELECT *
FROM drug_concept_stage
WHERE concept_name NOT IN
      (
      SELECT concept_code_1
      FROM aut_unit_mapped
      )
  AND concept_class_id = 'Unit';

-- 5.3 Ingredients
-- for ingredients the ATC codes provided by the source jmdc table can be used

INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT
    dc.concept_code, 'JMDC', c2.concept_id, RANK() OVER (PARTITION BY dc.concept_code ORDER BY c2.concept_id)
FROM drug_concept_stage dc
LEFT JOIN relationship_to_concept r
    ON concept_code = concept_code_1
JOIN concept c2
    ON LOWER(C2.concept_name) = LOWER(dc.concept_name)
WHERE dc.concept_class_id = 'Ingredient'
  AND concept_id_2 IS NULL
  AND c2.standard_concept = 'S'
  AND c2.concept_class_id = 'Ingredient'
  AND c2.vocabulary_id LIKE 'RxNorm%'
;

--precise ingredients
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
-- select * from precise_temp
-- where concept_code_1 not in (select concept_code_1 from relationship_to_concept);
SELECT DISTINCT dc.concept_code, 'JMDC', c3.concept_id, 1
FROM drug_concept_stage dc
LEFT JOIN relationship_to_concept r
    ON concept_code = concept_code_1
JOIN devv5.concept c2
    ON LOWER(C2.concept_name) = LOWER(dc.concept_name)
JOIN devv5.concept_relationship cr
    ON cr.concept_id_1 = c2.concept_id
JOIN devv5.concept c3
    ON c3.concept_id = cr.concept_id_2
WHERE dc.concept_class_id = 'Ingredient'
  AND r.concept_id_2 IS NULL
  AND c2.concept_class_id = 'Precise Ingredient'
  AND c3.concept_class_id = 'Ingredient'
  AND cr.invalid_reason IS NULL
  AND c3.standard_concept = 'S'
  AND c3.vocabulary_id LIKE 'RxNorm%'
;

-- delete/update invalid ingredients

DELETE
FROM aut_ingredient_mapped
WHERE CAST(concept_id_2 AS int)
          IN (
             SELECT concept_id
             FROM concept
             WHERE invalid_reason = 'D'
             );

UPDATE aut_ingredient_mapped aim
SET concept_id_2 = c.concept_id_2
FROM (
     SELECT concept_id_2, concept_id_1
     FROM concept_relationship cr
     JOIN concept c
         ON c.concept_id = concept_id_1 AND c.invalid_reason = 'U' AND relationship_id = 'Maps to' AND
            cr.invalid_reason IS NULL
     ) c
WHERE (CAST(aim.concept_id_2 AS int) = c.concept_id_1);

-- get the list of ingredients to map
DROP TABLE IF EXISTS aut_ingredient_to_map;
CREATE TABLE aut_ingredient_to_map
AS
SELECT *
FROM drug_concept_stage
WHERE LOWER(concept_name) NOT IN
      (
      SELECT LOWER(concept_name)
      FROM aut_ingredient_mapped
      UNION
      SELECT LOWER(ing_name)
      FROM aut_parsed_ingr
      UNION
      SELECT LOWER(concept_name)
      FROM aut_parsed_ingr
      )
  AND concept_code NOT IN
      (
      SELECT concept_code_1
      FROM relationship_to_concept
      )
  AND concept_class_id = 'Ingredient';


-- 5.4 Brand Names
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT
    dc.concept_code, 'JMDC', c.concept_id, RANK() OVER (PARTITION BY dc.concept_code ORDER BY c.concept_id)
FROM drug_concept_stage dc
JOIN devv5.concept c
    ON REGEXP_REPLACE(LOWER(TRIM(dc.concept_name)), '(\s|\W)', '', 'g') =
       REGEXP_REPLACE(LOWER(TRIM(c.concept_name)), '(\s|\W)', '', 'g')
WHERE dc.concept_class_id = 'Brand Name'
  AND c.concept_class_id = 'Brand Name'
  AND c.vocabulary_id LIKE 'Rx%'
  AND c.invalid_reason IS NULL
  AND c.concept_id NOT IN (42912198, 44022957, 21018872, 40819872)
;

INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT
    dc.concept_code, 'JMDC', c2.concept_id, RANK() OVER (PARTITION BY dc.concept_code ORDER BY c2.concept_id)
FROM drug_concept_stage dc
JOIN devv5.concept c
    ON LOWER(c.concept_name) = LOWER(dc.concept_name) AND c.invalid_reason = 'U' AND c.concept_class_id = 'Brand Name'
JOIN devv5.concept_relationship cr
    ON cr.concept_id_1 = c.concept_id AND cr.invalid_reason IS NULL
JOIN devv5.concept c2
    ON cr.concept_id_2 = c2.concept_id AND relationship_id = 'Concept replaced by'
WHERE dc.concept_class_id = 'Brand Name'
  AND dc.concept_code NOT IN (
                             SELECT concept_code_1
                             FROM relationship_to_concept
                             );
;

-- delete/update invalid BN
DELETE
FROM aut_bn_mapped
WHERE CAST(concept_id_2 AS int)
          IN (
             SELECT concept_id
             FROM concept
             WHERE invalid_reason = 'D'
             );

UPDATE aut_bn_mapped aim
SET concept_id_2 = c.concept_id_2
FROM (
     SELECT concept_id_2, concept_id_1
     FROM concept_relationship cr
     JOIN concept c
         ON c.concept_id = concept_id_1 AND c.invalid_reason = 'U' AND relationship_id = 'Concept replaced by' AND
            cr.invalid_reason IS NULL
     ) c
WHERE (CAST(aim.concept_id_2 AS int) = c.concept_id_1);

-- get the list of BN to map
DROP TABLE IF EXISTS aut_bn_to_map;
CREATE TABLE aut_bn_to_map
AS
SELECT *
FROM drug_concept_stage
WHERE concept_code NOT IN
      (
      SELECT concept_code_1
      FROM relationship_to_concept
      )
  AND concept_class_id = 'Brand Name';


-- 5.5 Supplier
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT
    dc.concept_code, 'JMDC', c.concept_id, RANK() OVER (PARTITION BY dc.concept_code ORDER BY c.concept_id)
FROM drug_concept_stage dc
JOIN devv5.concept c
    ON LOWER(c.concept_name) = LOWER(dc.concept_name) AND c.concept_class_id = 'Supplier'
        AND c.invalid_reason IS NULL AND c.vocabulary_id = 'RxNorm Extension'
WHERE dc.concept_class_id = 'Supplier'
  AND dc.concept_code NOT IN (
                             SELECT concept_code_1
                             FROM relationship_to_concept
                             );

-- delete/update invalid suppliers
DELETE
FROM aut_suppliers_mapped
WHERE CAST(concept_id_2 AS int)
          IN (
             SELECT concept_id
             FROM concept
             WHERE invalid_reason = 'D'
             );

UPDATE aut_suppliers_mapped aim
SET concept_id_2 = c.concept_id_2
FROM (
     SELECT concept_id_2, concept_id_1
     FROM concept_relationship cr
     JOIN concept c
         ON c.concept_id = concept_id_1 AND c.invalid_reason = 'U' AND relationship_id = 'Concept replaced by' AND
            cr.invalid_reason IS NULL
     ) c
WHERE (CAST(aim.concept_id_2 AS int) = c.concept_id_1);

-- get the list of suppliers to map
DROP TABLE IF EXISTS aut_suppliers_to_map;
CREATE TABLE aut_suppliers_to_map
AS
SELECT *
FROM drug_concept_stage
WHERE LOWER(concept_name) NOT IN
      (
      SELECT LOWER(source_name)
      FROM aut_suppliers_mapped
      )
  AND concept_code NOT IN
      (
      SELECT concept_code_1
      FROM relationship_to_concept
      )
  AND concept_class_id = 'Supplier';

/****************************
*     7. POPULATE PC_STAGE   *
*****************************/

INSERT INTO pc_stage
SELECT jmdc_drug_code, dcs.concept_code, quantity, NULL
FROM aut_pc_stage
JOIN drug_concept_stage dcs
    ON dcs.concept_name = SUBSTR(ingredient || ' ' || dosage || ' ' || LOWER(form), 1, 255)
;

/****************************
*     8. POST-PROCESSING.   *
*****************************/

-- 8.1 Delete Suppliers where DF or strength doesn't exist

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN
      (
      SELECT concept_code_1
      FROM internal_relationship_stage
      JOIN drug_concept_stage
          ON concept_code_2 = concept_code
              AND concept_class_id = 'Supplier'
      LEFT JOIN ds_stage
          ON drug_concept_code = concept_code_1
      WHERE drug_concept_code IS NULL

      UNION

      SELECT concept_code_1
      FROM internal_relationship_stage
      JOIN drug_concept_stage
          ON concept_code_2 = concept_code
              AND concept_class_id = 'Supplier'
      WHERE concept_code_1 NOT IN (
                                  SELECT concept_code_1
                                  FROM internal_relationship_stage
                                  JOIN drug_concept_stage
                                      ON concept_code_2 = concept_code
                                          AND concept_class_id = 'Dose Form'
                                  )
      )
  AND concept_code_2 IN
      (
      SELECT concept_code FROM drug_concept_stage WHERE concept_class_id = 'Supplier'
      )
;


-- populate manual_mapping tables