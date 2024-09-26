/**************************************************************************
    this script collects ATC - RxNorm connections FROM different sources
**************************************************************************/

/* Sources for building table

   1. dm+d - https://github.com/OHDSI/Vocabulary-v5.0/blob/master/dmd/load_stage.sql#L445
   2. BDPM - https://github.com/OHDSI/Vocabulary-v5.0/tree/master/BDPM + Manual table, that contains ATC codes, built on data from the official site https://base-donnees-publique.medicaments.gouv.fr/telechargement.php
   3. GRR - https://github.com/OHDSI/Vocabulary-v5.0/tree/master/GRR
   4. UMLS - https://github.com/OHDSI/Vocabulary-v5.0/tree/master/UMLS
   5. VANDF -https://github.com/OHDSI/Vocabulary-v5.0/tree/master/VANDF
   6. JMDC - https://github.com/OHDSI/Vocabulary-v5.0/tree/master/JMDC
   7. Z-index - proprietary source
   8. Norske Drug  - Manual table, built from https://www.legemiddelsok.no/ and processed in BuildRXE.
   9. KDC - Manual table.

 */

-- DROP TABLE IF EXISTS dmd2atc;
-- CREATE TABLE IF NOT EXISTS dmd2atc AS
-- SELECT unnest(xpath('/VMP/VPID/text()', i.xmlfield))::VARCHAR VPID,
-- 	unnest(xpath('/VMP/ATC/text()', i.xmlfield))::VARCHAR ATC
-- FROM (
-- 	SELECT unnest(xpath('/BNF_DETAILS/VMPS/VMP', i.xmlfield)) xmlfield
-- 	FROM sources.dmdbonus i
-- 	) AS i;

--1. Create temporary table to store source data to ATC relationships
DROP TABLE IF EXISTS class_ATC_RXN_huge_temp;
CREATE TABLE class_ATC_RXN_huge_temp AS -- without ancestor
SELECT source,
       c.concept_id AS concept_id,
       c.concept_name,
       c.concept_class_id,
       atc.class_code,
       atc.class_name
FROM (SELECT *
      FROM
          ------dm+d------
          (WITH base AS (SELECT t1.concept_id,
                                t1.concept_name,
                                t3.class_code,
                                t3.class_name
                         FROM (SELECT *
                               FROM devv5.concept
                               WHERE concept_code IN (SELECT vpid
                                                      FROM dev_atc.dmd2atc
                                                      WHERE LENGTH(atc) = 7)
                                 AND vocabulary_id = 'dm+d') t1
                                  JOIN
                              (SELECT *
                               FROM dev_atc.dmd2atc -- TODO: can be transferred to sources
                               WHERE LENGTH(atc) = 7) t2 ON concept_code = vpid
                                  JOIN
                              sources.atc_codes t3 ON t2.atc = t3.class_code)
           SELECT t1.concept_id_2::INT AS concept_id,
                  base.class_code      AS class_code,
                  'dmd'                AS source
           FROM devv5.concept_relationship t1
                    JOIN base ON t1.concept_id_1 = base.concept_id
                    JOIN devv5.concept t2 ON t1.concept_id_2 = t2.concept_id
           WHERE t1.relationship_id = 'Maps to'
             AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')) t1

      UNION

      ------BDPM------
      (SELECT t4.concept_id,
              t2.atc_code,
              'BDPM' AS source
       FROM sources.bdpm_packaging t1
                JOIN dev_atc.bdpm_atc_codes t2 ON t1.drug_code = t2.id::VARCHAR --TODO: In future, scraper could be transferred to sources
                JOIN devv5.concept t3 ON t1.din_7::VARCHAR = t3.concept_code AND t3.vocabulary_id = 'BDPM'
                JOIN devv5.concept_relationship cr ON cr.concept_id_1 = t3.concept_id AND cr.relationship_id = 'Maps to'
                JOIN devv5.concept t4 ON cr.concept_id_2 = t4.concept_id AND t4.invalid_reason IS NULL
                                                                         AND t4.stANDard_concept = 'S')

      UNION

      ------GRR-------
      (WITH base_up AS (WITH base AS (SELECT CASE
                                                 WHEN product_launch_date IS NULL THEN CAST(fcc AS VARCHAR)
                                                 ELSE fcc || '_' ||
                                                      TO_CHAR(TO_DATE(product_launch_date, 'dd.mm.yyyy'), 'mmddyyyy')
                                                 END AS concept_code,
                                             therapy_name,
                                             who_atc5_code
                                      FROM dev_grr.source_data
                                      WHERE (LENGTH(who_atc5_code) = 7 AND who_atc5_code != '???????'
                                                                       AND who_atc5_code NOT LIKE '%..'))

                        SELECT t1.concept_id,
                               t1.concept_code,
                               t1.concept_name,
                               t2.therapy_name,
                               t2.who_atc5_code AS who_atc5_code
                        FROM devv5.concept t1
                                 JOIN base t2 ON t1.concept_code = t2.concept_code
                        WHERE t1.vocabulary_id = 'GRR')
       SELECT t1.concept_id_2::INT  AS concept_id,
              base_up.who_atc5_code AS class_code,
              'grr' AS source
       FROM devv5.concept_relationship t1
                JOIN base_up ON t1.concept_id_1 = base_up.concept_id
                JOIN concept t2 ON t1.concept_id_2 = t2.concept_id
       WHERE t1.relationship_id = 'Maps to'
         AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension'))

      UNION

      ------UMLS------
      (SELECT t3.concept_id::INT AS concept_id,
              t1.code  AS class_code,
              'umls' AS source --||t4.sab as source
       FROM sources.rxnrel main
                JOIN sources.rxnconso t1 ON main.rxcui1 = t1.rxcui
                JOIN sources.rxnconso t2 ON main.rxcui2 = t2.rxcui
                JOIN devv5.concept t3 ON t2.code = t3.concept_code
       WHERE t1.sab = 'ATC'
         AND LENGTH(t1.code) = 7
         AND t2.sab = 'RXNORM'
         AND t3.vocabulary_id = 'RxNorm')

      UNION

      ------VANDF------
      (SELECT t5.concept_id::INT,
              t2.code,
              'VANDF' AS source
       FROM sources.rxnrel t1
                JOIN sources.rxnconso t2 ON t1.rxcui1 = t2.rxcui
                JOIN sources.rxnconso t3 ON t1.rxcui2 = t3.rxcui
                JOIN devv5.concept t4 ON t3.code = t4.concept_code AND t4.vocabulary_id = 'VANDF'
                JOIN devv5.concept_relationship cr ON cr.concept_id_1 = t4.concept_id AND cr.relationship_id = 'Maps to'
                JOIN devv5.concept t5 ON cr.concept_id_2 = t5.concept_id
       WHERE t2.sab = 'ATC'
         AND LENGTH(t2.code) = 7
         AND t3.sab = 'VANDF')

      UNION

      ------JMDC------
      (SELECT c.concept_id,
              t2.who_atc_code,
              'jmdc' AS source
       FROM devv5.concept t1
                JOIN dev_jmdc.jmdc t2 ON t1.concept_code = t2.jmdc_drug_code
                JOIN devv5.concept_relationship cr ON cr.concept_id_1 = t1.concept_id
                JOIN devv5.concept c ON cr.concept_id_2 = c.concept_id

       WHERE t1.concept_code IN (SELECT jmdc_drug_code
                                 FROM dev_jmdc.jmdc
                                 WHERE LENGTH(who_atc_code) = 7)
         AND t1.vocabulary_id = 'JMDC'
         AND LENGTH(t2.who_atc_code) = 7
         AND cr.relationship_id = 'Maps to'
         AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension'))


      --The following sources are excluded FROM the data collection due to multiple mistakenly assigned ATC codes

--             UNION
--
--                 (
--                     SELECT
--                         distinct t3.code::int, t1.code,
--                                  'Other' as sources
--                         --t1.str,
--                         --t3.str
--                     FROM sources.rxnrel rel
--                          JOIN sources.rxnconso t1 on rel.rxcui1 = t1.rxcui
--                          JOIN sources.rxnconso t2 on rel.rxcui2 = t2.rxcui AND t2.sab in ('DRUGBANK','USP','MTHSPL','MMX','MMSL','GS','NDDF','SNOMEDCT_US')
--                          JOIN sources.rxnrel rel2 on rel2.rxcui1 = t2.rxcui
--                          JOIN sources.rxnconso t3 on rel2.rxcui2 = t3.rxcui
--                     WHERE
--                         t1.sab = 'ATC'
--                         AND length (t1.code) = 7
--                         AND t3.sab = 'RXNORM'
--
--              )

      UNION

      ------Z-index------
      (SELECT targetid,
              atc,
              'z-index' AS source
       FROM dev_atc.zindex_full)

      UNION

      ------Norske Drug Bank------
      (SELECT rx_ids,
              atc_code,
              'Norway' AS source
       FROM dev_atc.norske_result)

      UNION

      ------KDC------
      (SELECT t3.concept_id,
              atc.concept_code_2,
              'KDC'
       FROM dev_atc.kdc_atc atc
                JOIN devv5.concept t1 ON atc.concept_code::VARCHAR = t1.concept_code AND t1.vocabulary_id = 'KDC'
                JOIN devv5.concept t2 ON atc.concept_code_2 = t2.concept_code AND t2.vocabulary_id = 'ATC'
                JOIN devv5.concept_relationship cr ON t1.concept_id = cr.concept_id_1 AND cr.relationship_id = 'Maps to'
                JOIN devv5.concept t3 ON cr.concept_id_2 = t3.concept_id AND t3.vocabulary_id IN ('RxNorm', 'RxNorm Extension'))

      UNION

      ---- Add existent in devv5.codes (to use step_aside_approach for them)
      (SELECT c2.concept_id,
              c1.concept_code,
              'devv5' AS source
       FROM devv5.concept_relationship cr
                JOIN devv5.concept c1 ON cr.concept_id_1 = c1.concept_id AND c1.vocabulary_id = 'ATC'
                                                                         AND c1.invalid_reason IS NULL
                JOIN devv5.concept c2 ON cr.concept_id_2 = c2.concept_id AND cr.relationship_id = 'ATC - RxNorm'
                                                                         AND cr.invalid_reason IS NULL
                                                                         AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                                                         AND c2.invalid_reason IS NULL
       WHERE (c1.concept_code, c2.concept_id) NOT IN
                                                     (SELECT atc_code, concept_id
                                                      FROM dev_atc.existent_atc_rxnorm_to_drop
                                                      WHERE to_drop = 'D')
          OR (c1.concept_code, c2.concept_id) NOT IN
                                                     (SELECT concept_code_atc, concept_id_rx
                                                      FROM dev_atc.atc_rxnorm_to_drop_in_sources
                                                      WHERE drop = 'D'))

      UNION

      -----Manual GCS-----
      (SELECT concept_id,
              UNNEST(STRING_TO_ARRAY(TRIM(atc_code), ',')) AS atc_code,
              'manual_gcs'                                 AS source
       FROM dev_atc.gcs_manual_curated)

      UNION

      ------DPD------
      (SELECT c2.concept_id,
              dpd.tc_atc_number,
              'dpd' AS source
       FROM devv5.concept c1
                JOIN sources.dpd_drug_all t1 ON c1.concept_code = (t1.drug_identification_number::INT)::VARCHAR AND t1.drug_identification_number ~ '^\d+$'
                JOIN sources.dpd_therapeutic_class_all dpd ON t1.drug_code = dpd.drug_code
                JOIN devv5.concept_relationship cr ON cr.concept_id_1 = c1.concept_id
                JOIN devv5.concept c2 ON cr.concept_id_2 = c2.concept_id

       WHERE LENGTH(tc_atc_number) = 7
         AND c1.vocabulary_id = 'DPD'
         AND cr.relationship_id = 'Maps to'
         AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension'))) t2

         JOIN devv5.concept c ON t2.concept_id = c.concept_id AND c.invalid_reason IS NULL
         JOIN sources.atc_codes atc ON t2.class_code = atc.class_code AND atc.active = 'NA'
WHERE c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
  AND c.concept_class_id NOT IN
                              ('Ingredient',
                               'Precise Ingredient',
                               'Multiple Ingredients',
                               'Brand Name',
                               'Brand',
                               'Branded Drug Comp',
                               'Branded Dose Group',
                               'Branded Drug Box',
                               'Branded Pack',
                               'Branded Drug Form',
                               'Branded Pack Box',
                               'Branded Drug',
                               'Branded Drug Component',
                               'Quant Branded Box',
                               'Quant Branded Drug',
                               'Drug',
                               'Clinical Drug Comp',
                               'Clinical Dose Group',
                               'Clinical Drug Component',
                               'Dose Form',
                               'Dose Form Group',
                               'Clinical Pack',
                               'Clinical Pack Box',
                               'Marketed Product')
ORDER BY class_code;

--2. Build custom ancestor table
DROP TABLE IF EXISTS class_ATC_RXN_huge_ancestor_temp;
CREATE TABLE class_ATC_RXN_huge_ancestor_temp AS
SELECT c.concept_id,
       c.concept_name,
       c2.concept_id   AS ids,
       c2.concept_name AS names,
       c2.concept_class_id
FROM devv5.concept_ancestor ca
         JOIN devv5.concept c ON ca.descendant_concept_id = c.concept_id AND c.invalid_reason IS NULL
         JOIN devv5.concept c2 ON ca.ancestor_concept_id = c2.concept_id AND c2.invalid_reason IS NULL
WHERE c2.concept_class_id NOT IN
                              ('Ingredient',
                               'Precise Ingredient',
                               'Multiple Ingredients',
                               'Brand Name',
                               'Brand',
                               'Branded Drug Comp',
                               'Branded Dose Group',
                               'Branded Drug Box',
                               'Branded Pack',
                               'Branded Drug Form',
                               'Branded Pack Box',
                               'Branded Drug',
                               'Branded Drug Component',
                               'Quant Branded Box',
                               'Quant Branded Drug',
                               'Drug',
                               'Clinical Drug Comp',
                               'Clinical Dose Group',
                               'Clinical Drug Component',
                               'Dose Form',
                               'Dose Form Group',
                               'Clinical Pack',
                               'Clinical Pack Box',
                               'Marketed Product')
  AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
  AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension');

--3. Build new ATC - RxNorm links
DROP TABLE IF EXISTS class_ATC_RXN_huge_fin__;
CREATE TABLE class_ATC_RXN_huge_fin__ AS
SELECT DISTINCT t2.class_code,
                t2.class_name,
                'ATC - RxNorm' AS relationship_id,
                t1.concept_class_id,
                ids,
                names,
                source
FROM class_ATC_RXN_huge_temp t2
         JOIN class_ATC_RXN_huge_ancestor_temp t1 ON t2.concept_id = t1.concept_id;

--4. Taking step aside AND adding relationships to all related forms through Dose Form Groups
--Eg. Adding relationships to Oral Capsules if relationships to Oral Tablets exist
DROP TABLE IF EXISTS step_aside_source;
CREATE TABLE step_aside_source AS
SELECT DISTINCT t1.concept_id,
                t1.concept_name,
                ARRAY_AGG(t5.concept_id ORDER BY t5.concept_name)   AS array_ing_id,
                ARRAY_AGG(t5.concept_name ORDER BY t5.concept_name) AS array_ing,
                t2.concept_id AS dose_form_id,
                t2.concept_name AS dose_form_name,
                t3.concept_id AS dose_form_group_id,
                t3.concept_name AS dose_form_group_name,
                t4.concept_id AS potential_dose_form_id,
                t4.concept_name AS potential_dose_form_name
FROM devv5.concept t1
         --Dose Form
         JOIN devv5.concept_relationship cr ON cr.concept_id_1 = t1.concept_id AND t1.concept_class_id = 'Clinical Drug Form'
                                                                               AND cr.relationship_id = 'RxNorm has dose form'
                                                                               AND cr.invalid_reason IS NULL
                                                                               AND t1.invalid_reason IS NULL
                                                                               AND t1.concept_id IN (SELECT DISTINCT ids
                                                                                                    FROM class_ATC_RXN_huge_fin__ --Source table
                                                                                                    WHERE concept_class_id = 'Clinical Drug Form')
         JOIN devv5.concept t2 ON cr.concept_id_2 = t2.concept_id AND t2.invalid_reason IS NULL
                                                                  AND t2.concept_class_id IN ('Dose Form')
    --Dose Form Group
         JOIN devv5.concept_relationship cr2 ON cr2.concept_id_1 = t2.concept_id AND cr2.relationship_id = 'RxNorm is a'
                                                                                 AND cr2.invalid_reason IS NULL
    AND t2.invalid_reason IS NULL
         JOIN devv5.concept t3 ON cr2.concept_id_2 = t3.concept_id AND t3.invalid_reason IS NULL
                                                                   AND t3.concept_class_id = 'Dose Form Group'
    --all potential forms in the group
         JOIN devv5.concept_relationship cr3 ON cr3.concept_id_1 = t3.concept_id AND cr3.relationship_id = 'RxNorm inverse is a'
                                                                                 AND cr3.invalid_reason IS NULL
                                                                                 AND t3.invalid_reason IS NULL
         JOIN devv5.concept t4 ON cr3.concept_id_2 = t4.concept_id AND t4.invalid_reason IS NULL
                                                                   AND t4.concept_class_id = 'Dose Form'

    --Ingredients
         JOIN devv5.concept_relationship cr4 ON cr4.concept_id_1 = t1.concept_id AND cr4.invalid_reason IS NULL
                                                                                 AND t1.concept_class_id = 'Clinical Drug Form'
                                                                                 AND cr4.relationship_id = 'RxNorm has ing'

         JOIN devv5.concept t5 ON cr4.concept_id_2 = t5.concept_id AND t5.invalid_reason IS NULL
                                                                   AND t5.concept_class_id = 'Ingredient'

WHERE t3.concept_id NOT IN (
                            36217216 --Pill
                            )

GROUP BY t1.concept_id, t1.concept_name, t2.concept_id, t2.concept_name, t3.concept_id,
         t3.concept_name, t4.concept_id, t4.concept_name;

DROP TABLE IF EXISTS step_aside_target;
CREATE TABLE step_aside_target AS
SELECT DISTINCT t1.concept_id,
                t1.concept_name,
                ARRAY_AGG(t5.concept_id ORDER BY t5.concept_name)   AS array_ing_id,
                ARRAY_AGG(t5.concept_name ORDER BY t5.concept_name) AS array_ing,
                t2.concept_id AS dose_form_id,
                t2.concept_name AS dose_form_name
FROM devv5.concept t1
         --Dose Form
         JOIN devv5.concept_relationship cr ON cr.concept_id_1 = t1.concept_id AND t1.concept_class_id = 'Clinical Drug Form'
                                                                               AND cr.relationship_id = 'RxNorm has dose form'
                                                                               AND cr.invalid_reason IS NULL
                                                                               AND t1.invalid_reason IS NULL
         JOIN devv5.concept t2 ON cr.concept_id_2 = t2.concept_id AND t2.invalid_reason IS NULL
                                                                  AND t2.concept_class_id IN ('Dose Form')

    --Ingredients
         JOIN devv5.concept_relationship cr4 ON cr4.concept_id_1 = t1.concept_id AND t1.concept_class_id = 'Clinical Drug Form'
                                                                                 AND cr4.relationship_id = 'RxNorm has ing'
                                                                                 AND cr4.invalid_reason IS NULL
         JOIN devv5.concept t5 ON cr4.concept_id_2 = t5.concept_id AND t5.invalid_reason IS NULL
                                                                   AND t5.concept_class_id = 'Ingredient'

GROUP BY t1.concept_id, t1.concept_name, t2.concept_id, t2.concept_name;

DROP TABLE IF EXISTS atc_step_aside_final;
CREATE TABLE atc_step_aside_final AS
SELECT s.concept_id   AS source_concept_id,
       s.concept_name AS source_concept_name,
       t.concept_id   AS target_concept_id,
       t.concept_name AS target_concept_name
FROM step_aside_source s
         JOIN step_aside_target t ON s.array_ing = t.array_ing AND t.dose_form_id != s.dose_form_id
                                                               AND s.concept_id != t.concept_id
                                                               AND t.dose_form_id = s.potential_dose_form_id
ORDER BY s.concept_id;

--5. Resulting table
DROP TABLE IF EXISTS new_atc_codes_rxnorm;
CREATE TABLE new_atc_codes_rxnorm AS
SELECT *
FROM (SELECT t1.class_code,
             t1.class_name,
             t1.relationship_id,
             t1.concept_class_id,
             t2.target_concept_id    AS ids,
             t2.target_concept_name  AS names,
             t1.source || ' - aside' AS source
      FROM class_ATC_RXN_huge_fin__ t1
               JOIN atc_step_aside_final t2 ON t1.ids = t2.source_concept_id AND t1.concept_class_id = 'Clinical Drug Form'

      WHERE (t1.class_code, t2.target_concept_id) NOT IN --- remove all 'bad' mappings according manual check
                                                        (SELECT DISTINCT concept_code_atc, concept_id_rx
                                                         FROM dev_atc.atc_rxnorm_to_drop_in_sources
                                                         WHERE drop = 'D')) t1

UNION

(SELECT *
 FROM class_ATC_RXN_huge_fin__
 WHERE (class_code, ids) NOT IN --- remove all 'bad' mappings according manual check
                               (SELECT DISTINCT concept_code_atc, concept_id_rx
                                FROM dev_atc.atc_rxnorm_to_drop_in_sources
                                WHERE drop = 'D'));
-------------------------------------------------------------

--6. Clean up the temporary tables
DROP TABLE IF EXISTS class_ATC_RXN_huge_fin__;
DROP TABLE IF EXISTS step_aside_source;
DROP TABLE IF EXISTS step_aside_target;
DROP TABLE IF EXISTS atc_step_aside_final;
DROP TABLE IF EXISTS class_ATC_RXN_huge_fin;
DROP TABLE IF EXISTS class_ATC_RXN_huge_temp;
DROP TABLE IF EXISTS class_ATC_RXN_huge_ancestor_temp;