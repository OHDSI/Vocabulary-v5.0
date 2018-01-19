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
* Authors: Timur Vakhitov, Christian Reich
* Date: 2016
**************************************************************************/

-- 1. Update latest_update field to new date 
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'RxNorm',
                                          pVocabularyDate        => TO_DATE ('20170807', 'yyyymmdd'),
                                          pVocabularyVersion     => 'RxNorm Full 20170807',
                                          pVocabularyDevSchema   => 'DEV_RXNORM');
END;
COMMIT;

-- 2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Insert into concept_stage
-- Get drugs, components, forms and ingredients
INSERT INTO concept_stage (concept_name,
                           vocabulary_id,
                           domain_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT SUBSTR (str, 1, 255),
          'RxNorm',
          'Drug',
          -- use RxNorm tty as for Concept Classes
          CASE tty
             WHEN 'IN' THEN 'Ingredient'
             WHEN 'DF' THEN 'Dose Form'
             WHEN 'SCDC' THEN 'Clinical Drug Comp'
             WHEN 'SCDF' THEN 'Clinical Drug Form'
             WHEN 'SCD' THEN 'Clinical Drug'
             WHEN 'BN' THEN 'Brand Name'
             WHEN 'SBDC' THEN 'Branded Drug Comp'
             WHEN 'SBDF' THEN 'Branded Drug Form'
             WHEN 'SBD' THEN 'Branded Drug'
             WHEN 'PIN' THEN 'Precise Ingredient'
			 WHEN 'DFG' THEN 'Dose Form Group'
			 WHEN 'SCDG' THEN 'Clinical Dose Group'
			 WHEN 'SBDG' THEN 'Branded Dose Group'
          END,
          -- only Ingredients, drug components, drug forms, drugs and packs are standard concepts
          CASE tty WHEN 'PIN' THEN NULL WHEN 'DFG' THEN 'C' WHEN 'SCDG' THEN 'C' WHEN 'SBDG' THEN 'C' WHEN 'DF' THEN NULL WHEN 'BN' THEN NULL ELSE 'S' END,
          -- the code used in RxNorm
          rxcui,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'RxNorm'),
          CASE
             WHEN EXISTS
                     (SELECT 1
                        FROM rxnatomarchive arch
                       WHERE     arch.rxcui = rx.rxcui
                             AND sab = 'RXNORM'
                             AND tty IN ('IN',
                                         'DF',
                                         'SCDC',
                                         'SCDF',
                                         'SCD',
                                         'BN',
                                         'SBDC',
                                         'SBDF',
                                         'SBD',
                                         'PIN',
										 'DFG',
										 'SCDG',
										 'SBDG')
                             AND rxcui <> merged_to_rxcui)
             THEN
			  (SELECT latest_update - 1
				 FROM vocabulary
				WHERE vocabulary_id = 'RxNorm')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END AS valid_end_date,
          CASE
             WHEN EXISTS
                     (SELECT 1
                        FROM rxnatomarchive arch
                       WHERE     arch.rxcui = rx.rxcui
                             AND sab = 'RXNORM'
                             AND tty IN ('IN',
                                         'DF',
                                         'SCDC',
                                         'SCDF',
                                         'SCD',
                                         'BN',
                                         'SBDC',
                                         'SBDF',
                                         'SBD',
                                         'PIN',
										 'DFG',
										 'SCDG',
										 'SBDG')
                             AND rxcui <> merged_to_rxcui)
             THEN
                'U'
             ELSE
                NULL
          END
     FROM rxnconso rx
    WHERE     sab = 'RXNORM'
          AND tty IN ('IN',
                      'DF',
                      'SCDC',
                      'SCDF',
                      'SCD',
                      'BN',
                      'SBDC',
                      'SBDF',
                      'SBD',
                      'PIN',
					  'DFG',
					  'SCDG',
					  'SBDG');
COMMIT;					  

-- Packs share rxcuis with Clinical Drugs and Branded Drugs, therefore use code as concept_code
INSERT INTO concept_stage (concept_name,
                           vocabulary_id,
                           domain_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT SUBSTR (str, 1, 255),
          'RxNorm',
          'Drug',
          -- use RxNorm tty as for Concept Classes
          CASE tty WHEN 'BPCK' THEN 'Branded Pack' WHEN 'GPCK' THEN 'Clinical Pack' END,
          'S',
          -- Cannot use rxcui here
          code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'RxNorm'),
          CASE
             WHEN EXISTS
                     (SELECT 1
                        FROM rxnatomarchive arch
                       WHERE     arch.rxcui = rx.rxcui
                             AND sab = 'RXNORM'
                             AND tty IN ('IN',
                                         'DF',
                                         'SCDC',
                                         'SCDF',
                                         'SCD',
                                         'BN',
                                         'SBDC',
                                         'SBDF',
                                         'SBD',
                                         'PIN',
										 'DFG',
										 'SCDG',
										 'SBDG')
                             AND rxcui <> merged_to_rxcui)
             THEN
			  (SELECT latest_update - 1
				 FROM vocabulary
				WHERE vocabulary_id = 'RxNorm')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END AS valid_end_date,
          CASE
             WHEN EXISTS
                     (SELECT 1
                        FROM rxnatomarchive arch
                       WHERE     arch.rxcui = rx.code
                             AND sab = 'RXNORM'
                             AND tty IN ('IN',
                                         'DF',
                                         'SCDC',
                                         'SCDF',
                                         'SCD',
                                         'BN',
                                         'SBDC',
                                         'SBDF',
                                         'SBD',
                                         'PIN',
										 'DFG',
										 'SCDG',
										 'SBDG')
                             AND rxcui <> merged_to_rxcui)
             THEN
                'U'
             ELSE
                NULL
          END
     FROM rxnconso rx
    WHERE sab = 'RXNORM' AND tty IN ('BPCK', 'GPCK');
COMMIT;	
	
--4. Add synonyms - for all classes except the packs (they use code as concept_code)
INSERT INTO concept_synonym_stage (synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
    SELECT DISTINCT rxcui,
                    SUBSTR (r.str, 1, 1000),
                    'RxNorm',
                    4180186 -- English
      FROM rxnconso r JOIN concept_stage c ON c.concept_code = r.rxcui AND c.concept_class_id NOT IN ('Clinical Pack', 'Branded Pack')
     WHERE     sab = 'RXNORM'
           AND tty IN ('IN',
                       'DF',
                       'SCDC',
                       'SCDF',
                       'SCD',
                       'BN',
                       'SBDC',
                       'SBDF',
                       'SBD',
                       'PIN',
                       'DFG',
                       'SCDG',
                       'SBDG',
                       'SY')
           AND c.vocabulary_id = 'RxNorm';

-- Add synonyms for packs
INSERT INTO concept_synonym_stage (synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
    SELECT DISTINCT code,
                    SUBSTR (r.str, 1, 1000),
                    'RxNorm',
                    4180186 -- English
      FROM rxnconso r JOIN concept_stage c ON c.concept_code = r.code AND c.concept_class_id IN ('Clinical Pack', 'Branded Pack')
     WHERE sab = 'RXNORM' AND tty IN ('BPCK', 'GPCK', 'SY') AND c.vocabulary_id = 'RxNorm';
COMMIT;	

--5 Add inner-RxNorm relationships
INSERT /*+ APPEND */ INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT rxcui2 AS concept_code_1, -- !! The RxNorm source files have the direction the opposite than OMOP
          rxcui1 AS concept_code_2,
          'RxNorm' AS vocabulary_id_1,
          'RxNorm' AS vocabulary_id_2,
          CASE -- 
             WHEN rela = 'has_precise_ingredient' THEN 'Has precise ing'
             WHEN rela = 'has_tradename' THEN 'Has tradename'
             WHEN rela = 'has_dose_form' THEN 'RxNorm has dose form'
             WHEN rela = 'has_form' THEN 'Has form' -- links Ingredients to Precise Ingredients
             WHEN rela = 'has_ingredient' THEN 'RxNorm has ing'
             WHEN rela = 'constitutes' THEN 'Constitutes'
             WHEN rela = 'contains' THEN 'Contains'
             WHEN rela = 'reformulated_to' THEN 'Reformulated in'
             WHEN rela = 'inverse_isa' THEN 'RxNorm inverse is a'
             WHEN rela = 'has_quantified_form' THEN 'Has quantified form' -- links extended release tablets to 12 HR extended release tablets
			 WHEN rela = 'quantified_form_of' THEN 'Quantified form of'
             WHEN rela = 'consists_of' THEN 'Consists of'
             WHEN rela = 'ingredient_of' THEN 'RxNorm ing of'
             WHEN rela = 'precise_ingredient_of' THEN 'Precise ing of'
             WHEN rela = 'dose_form_of' THEN 'RxNorm dose form of'
             WHEN rela = 'isa' THEN 'RxNorm is a'
             WHEN rela = 'contained_in' THEN 'Contained in'
             WHEN rela = 'form_of' THEN 'Form of'
             WHEN rela = 'reformulation_of' THEN 'Reformulation of'
             WHEN rela = 'tradename_of' THEN 'Tradename of'
             WHEN rela = 'doseformgroup_of' THEN 'Dose form group of'
			 WHEN rela = 'has_doseformgroup' THEN 'Has dose form group'
             ELSE 'non-existing'
          END
             AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'RxNorm')
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM (SELECT rxcui1, rxcui2, rela
             FROM rxnrel
            WHERE     sab = 'RXNORM'
                  AND rxcui1 IS NOT NULL
                  AND rxcui2 IS NOT NULL
                  AND EXISTS
                         (SELECT 1
                            FROM concept
                           WHERE     vocabulary_id = 'RxNorm'
                                 AND concept_code = rxcui1
                          UNION ALL
                          SELECT 1
                            FROM concept_stage
                           WHERE     vocabulary_id = 'RxNorm'
                                 AND concept_code = rxcui1)
                  AND EXISTS
                         (SELECT 1
                            FROM concept
                           WHERE     vocabulary_id = 'RxNorm'
                                 AND concept_code = rxcui2
                          UNION ALL
                          SELECT 1
                            FROM concept_stage
                           WHERE     vocabulary_id = 'RxNorm'
                                 AND concept_code = rxcui2));
COMMIT;

--Rename "RxNorm has ing" to "Has brand name" if concept_code_2 has the concept_class_id='Brand Name' and reverse
UPDATE concept_relationship_stage
   SET RELATIONSHIP_ID = 'Has brand name'
 WHERE ROWID IN (SELECT crs.ROWID
                   FROM concept_relationship_stage crs
                        LEFT JOIN concept_stage cs ON cs.concept_code = crs.concept_code_2 AND cs.vocabulary_id = crs.vocabulary_id_2 AND cs.concept_class_id = 'Brand Name'
                        LEFT JOIN concept c ON c.concept_code = crs.concept_code_2 AND c.vocabulary_id = crs.vocabulary_id_2 AND c.concept_class_id = 'Brand Name'
                  WHERE crs.invalid_reason IS NULL AND crs.relationship_id = 'RxNorm has ing' AND COALESCE (cs.concept_code, c.concept_code) IS NOT NULL);
--reverse
UPDATE concept_relationship_stage
   SET RELATIONSHIP_ID = 'Brand name of'
 WHERE ROWID IN (SELECT crs.ROWID
                   FROM concept_relationship_stage crs
                        LEFT JOIN concept_stage cs ON cs.concept_code = crs.concept_code_1 AND cs.vocabulary_id = crs.vocabulary_id_1 AND cs.concept_class_id = 'Brand Name'
                        LEFT JOIN concept c ON c.concept_code = crs.concept_code_1 AND c.vocabulary_id = crs.vocabulary_id_1 AND c.concept_class_id = 'Brand Name'
                  WHERE crs.invalid_reason IS NULL AND crs.relationship_id = 'RxNorm ing of' AND COALESCE (cs.concept_code, c.concept_code) IS NOT NULL);
COMMIT;

-- Add missing relationships between Branded Packs and their Brand Names
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   WITH pb
           AS (SELECT *
                 FROM (SELECT pack_code,
                              pack_brand,
                              brand_code,
                              brand_name
                         FROM (                                              -- The brand names are either listed as tty PSN (prescribing name) or SY (synonym). If they are not listed they don't exist
                               SELECT p.rxcui AS pack_code, NVL (b.str, s.str) AS pack_brand
                                 FROM rxnconso p
                                      LEFT JOIN rxnconso b ON p.rxcui = b.rxcui AND b.sab = 'RXNORM' AND b.tty = 'PSN'
                                      LEFT JOIN rxnconso s ON p.rxcui = s.rxcui AND s.sab = 'RXNORM' AND s.tty = 'SY'
                                WHERE p.sab = 'RXNORM' AND p.tty = 'BPCK')
                              JOIN (SELECT concept_code AS brand_code, concept_name AS brand_name
                                      FROM concept_stage
                                     WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Brand Name')
                                 ON INSTR (LOWER (REPLACE (pack_brand, '-', ' ')), LOWER (REPLACE (brand_name, '-', ' '))) > 0)
                -- apply the slow regexp only to the ones preselected by instr
                WHERE REGEXP_LIKE (REPLACE (pack_brand, '-', ' '), '(^|\s|\W)' || REPLACE (brand_name, '-', ' ') || '($|\s|\W)', 'i'))
     SELECT pack_code AS concept_code_1,
            brand_code AS concept_code_2,
            'RxNorm' AS vocabulary_id_1,
            'RxNorm' AS vocabulary_id_2,
            'Has brand name' AS relationship_id,
            (SELECT latest_update
               FROM vocabulary
              WHERE vocabulary_id = 'RxNorm')
               AS valid_start_date,
            TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
            NULL AS invalid_reason
       FROM pb p
      -- kick out those duplicates where one is part of antoher brand name (like 'Demulen' in 'Demulen 1/50', or those that cannot be part of each other.
      WHERE     NOT EXISTS
                   (SELECT 1
                      FROM pb q
                     WHERE     q.brand_code != p.brand_code
                           AND p.pack_code = q.pack_code
                           AND (INSTR (q.brand_name, p.brand_name) > 0 OR INSTR (q.brand_name, p.brand_name) = 0 AND INSTR (p.brand_name, q.brand_name) = 0))
            AND NOT EXISTS
                   (SELECT 1
                      FROM concept_relationship_stage crs
                     WHERE crs.concept_code_1 = pack_code AND crs.concept_code_2 = brand_code AND crs.relationship_id = 'Has brand name')
            AND NOT EXISTS
                   (SELECT 1
                      FROM concept_relationship_stage crs
                     WHERE crs.concept_code_2 = pack_code AND crs.concept_code_1 = brand_code AND crs.relationship_id = 'Brand name of')
   GROUP BY pack_code, brand_code;	   
COMMIT;				   

-- Remove shortcut 'RxNorm has ing' relationship between 'Clinical Drug', 'Quant Clinical Drug', 'Clinical Pack' and 'Ingredient'
DELETE FROM concept_relationship_stage r
      WHERE     EXISTS
                   (SELECT 1
                      FROM concept_stage d
                     WHERE r.concept_code_1 = d.concept_code AND r.vocabulary_id_1 = d.vocabulary_id AND d.concept_class_id IN ('Clinical Drug', 'Quant Clinical Drug', 'Clinical Pack'))
            AND EXISTS
                   (SELECT 1
                      FROM concept_stage d
                     WHERE r.concept_code_2 = d.concept_code AND r.vocabulary_id_2 = d.vocabulary_id AND d.concept_class_id = 'Ingredient')
            AND relationship_id = 'RxNorm has ing';
-- and same for reverse
DELETE FROM concept_relationship_stage r
      WHERE     EXISTS
                   (SELECT 1
                      FROM concept_stage d
                     WHERE r.concept_code_2 = d.concept_code AND r.vocabulary_id_1 = d.vocabulary_id AND d.concept_class_id IN ('Clinical Drug', 'Quant Clinical Drug', 'Clinical Pack'))
            AND EXISTS
                   (SELECT 1
                      FROM concept_stage d
                     WHERE r.concept_code_1 = d.concept_code AND r.vocabulary_id_2 = d.vocabulary_id AND d.concept_class_id = 'Ingredient')
            AND relationship_id = 'RxNorm ing of';
COMMIT;

--Rename 'Has tradename' to 'Has brand name'  where concept_id_1='Ingredient' and concept_id_2='Brand Name'
update concept_relationship_stage set relationship_id='Has brand name' 
where rowid in (
    select r.rowid from concept_relationship_stage r
    where r.relationship_id='Has tradename'
    and exists (
        select 1 from concept_stage cs where cs.concept_code=r.concept_code_1 and cs.vocabulary_id=r.vocabulary_id_1 and cs.concept_class_id='Ingredient'
        union all
        select 1 from concept c where c.concept_code=r.concept_code_1 and c.vocabulary_id=r.vocabulary_id_1 and c.concept_class_id='Ingredient'
    )
    and exists (
        select 1 from concept_stage cs where cs.concept_code=r.concept_code_2 and cs.vocabulary_id=r.vocabulary_id_2 and cs.concept_class_id='Brand Name'
        union all
        select 1 from concept c where c.concept_code=r.concept_code_2 and c.vocabulary_id=r.vocabulary_id_2 and c.concept_class_id='Brand Name'
    )
);
--and same for reverse
update concept_relationship_stage set relationship_id='Brand name of'
where rowid in (
    select r.rowid from concept_relationship_stage r
    where r.relationship_id='Tradename of'
    and exists (
        select 1 from concept_stage cs where cs.concept_code=r.concept_code_1 and cs.vocabulary_id=r.vocabulary_id_1 and cs.concept_class_id='Brand Name'
        union all
        select 1 from concept c where c.concept_code=r.concept_code_1 and c.vocabulary_id=r.vocabulary_id_1 and c.concept_class_id='Brand Name'
    )
    and exists (
        select 1 from concept_stage cs where cs.concept_code=r.concept_code_2 and cs.vocabulary_id=r.vocabulary_id_2 and cs.concept_class_id='Ingredient'
        union all
        select 1 from concept c where c.concept_code=r.concept_code_2 and c.vocabulary_id=r.vocabulary_id_2 and c.concept_class_id='Ingredient'
    ) 
);
COMMIT;

--6 Add cross-link and mapping table between SNOMED and RxNorm
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'SNOMED' AS vocabulary_id_1,
                   'RxNorm' AS vocabulary_id_2,				   
                   'SNOMED - RxNorm eq' AS relationship_id,
                   d.valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM concept d
          JOIN rxnconso r ON r.code = d.concept_code AND r.sab = 'SNOMEDCT_US' AND r.code != 'NOCODE'
          JOIN concept e ON r.rxcui = e.concept_code AND e.vocabulary_id = 'RxNorm' AND e.invalid_reason IS NULL
    WHERE d.vocabulary_id = 'SNOMED' AND d.invalid_reason IS NULL
   -- Mapping table between SNOMED to RxNorm. SNOMED is both an intermediary between RxNorm AND DM+D, AND a source code
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'SNOMED' AS vocabulary_id_1,
                   'RxNorm' AS vocabulary_id_2,
                   'Maps to' AS relationship_id,
                   d.valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM concept d
          JOIN rxnconso r ON r.code = d.concept_code AND r.sab = 'SNOMEDCT_US' AND r.code != 'NOCODE'
          JOIN concept e ON r.rxcui = e.concept_code AND e.vocabulary_id = 'RxNorm' AND e.invalid_reason IS NULL
    WHERE d.vocabulary_id = 'SNOMED' AND d.invalid_reason IS NULL AND d.concept_class_id NOT IN ('Dose Form', 'Brand Name');
COMMIT;
	
--7 Add upgrade relationships (concept_code_2 shouldn't exists in rxnsat with atn = 'RXN_QUALITATIVE_DISTINCTION')
INSERT /*+ APPEND */
      INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
    SELECT DISTINCT raa.rxcui AS concept_code_1,
                    raa.merged_to_rxcui AS concept_code_2,
                    'RxNorm' AS vocabulary_id_1,
                    'RxNorm' AS vocabulary_id_2,
                    'Concept replaced by' AS relationship_id,
                    v.latest_update AS valid_start_date,
                    TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                    NULL AS invalid_reason
      FROM rxnatomarchive raa
           JOIN vocabulary v ON v.vocabulary_id = 'RxNorm'  -- for getting the latest_update
           LEFT JOIN rxnsat rxs ON rxs.rxcui = raa.merged_to_rxcui AND rxs.atn = 'RXN_QUALITATIVE_DISTINCTION' AND rxs.sab = raa.sab
     WHERE     raa.sab = 'RXNORM'
           AND raa.tty IN ('IN',
                           'DF',
                           'SCDC',
                           'SCDF',
                           'SCD',
                           'BN',
                           'SBDC',
                           'SBDF',
                           'SBD',
                           'PIN',
                           'DFG',
                           'SCDG',
                           'SBDG')
           AND raa.rxcui <> raa.merged_to_rxcui
           AND rxs.rxcui IS NULL;
COMMIT;

--7.1 Add 'Maps to' between RXN_QUALITATIVE_DISTINCTION and fresh concepts (AVOF-457)
INSERT /*+ APPEND */
      INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
    SELECT raa.merged_to_rxcui AS concept_code_1,
           crs.concept_code_2 AS concept_code_2,
           'RxNorm' AS vocabulary_id_1,
           'RxNorm' AS vocabulary_id_2,
           'Maps to' AS relationship_id,
           v.latest_update AS valid_start_date,
           TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
           NULL AS invalid_reason
      FROM concept_relationship_stage crs
           JOIN rxnatomarchive raa
               ON     raa.sab = 'RXNORM'
                  AND raa.tty IN ('IN',
                                  'DF',
                                  'SCDC',
                                  'SCDF',
                                  'SCD',
                                  'BN',
                                  'SBDC',
                                  'SBDF',
                                  'SBD',
                                  'PIN',
                                  'DFG',
                                  'SCDG',
                                  'SBDG')
                  AND raa.rxcui = crs.concept_code_1
                  AND raa.merged_to_rxcui <> crs.concept_code_2
           JOIN rxnsat rxs ON rxs.rxcui = raa.merged_to_rxcui AND rxs.atn = 'RXN_QUALITATIVE_DISTINCTION' AND rxs.sab = raa.sab
           JOIN vocabulary v ON v.vocabulary_id = 'RxNorm'
     WHERE crs.relationship_id = 'Concept replaced by' AND crs.invalid_reason IS NULL AND crs.vocabulary_id_1 = 'RxNorm' AND crs.vocabulary_id_2 = 'RxNorm';
COMMIT;

--7.2 Set standard_concept = NULL for all affected codes with RXN_QUALITATIVE_DISTINCTION (AVOF-457)
UPDATE concept_stage
   SET standard_concept = NULL
 WHERE (concept_code, vocabulary_id) IN (SELECT raa.merged_to_rxcui, crs.vocabulary_id_2
                                           FROM concept_relationship_stage crs
                                                JOIN rxnatomarchive raa
                                                    ON     raa.sab = 'RXNORM'
                                                       AND raa.tty IN ('IN',
                                                                       'DF',
                                                                       'SCDC',
                                                                       'SCDF',
                                                                       'SCD',
                                                                       'BN',
                                                                       'SBDC',
                                                                       'SBDF',
                                                                       'SBD',
                                                                       'PIN',
                                                                       'DFG',
                                                                       'SCDG',
                                                                       'SBDG')
                                                       AND raa.rxcui = crs.concept_code_1
                                                       AND raa.merged_to_rxcui <> crs.concept_code_2
                                                JOIN rxnsat rxs ON rxs.rxcui = raa.merged_to_rxcui AND rxs.atn = 'RXN_QUALITATIVE_DISTINCTION' AND rxs.sab = raa.sab
                                          WHERE crs.relationship_id = 'Concept replaced by' AND crs.invalid_reason IS NULL AND crs.vocabulary_id_1 = 'RxNorm' AND crs.vocabulary_id_2 = 'RxNorm');
COMMIT;

--8 Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
COMMIT;

--9 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;	

--10 Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;

--11 Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

--12 Create mapping to self for fresh concepts
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
	SELECT concept_code AS concept_code_1,
		   concept_code AS concept_code_2,
		   c.vocabulary_id AS vocabulary_id_1,
		   c.vocabulary_id AS vocabulary_id_2,
		   'Maps to' AS relationship_id,
		   v.latest_update AS valid_start_date,
		   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
		   NULL AS invalid_reason
	  FROM concept_stage c, vocabulary v
	 WHERE     c.vocabulary_id = v.vocabulary_id
		   AND c.standard_concept = 'S'
		   AND NOT EXISTS -- only new mapping we don't already have
				  (SELECT 1
					 FROM concept_relationship_stage i
					WHERE     c.concept_code = i.concept_code_1
						  AND c.concept_code = i.concept_code_2
						  AND c.vocabulary_id = i.vocabulary_id_1
						  AND c.vocabulary_id = i.vocabulary_id_2
						  AND i.relationship_id = 'Maps to');
COMMIT;

--13 Turn "Clinical Drug" to "Quant Clinical Drug" and "Branded Drug" to "Quant Branded Drug"
UPDATE concept_stage c
   SET concept_class_id =
          CASE
             WHEN concept_class_id = 'Branded Drug' THEN 'Quant Branded Drug'
             ELSE 'Quant Clinical Drug'
          END
 WHERE     concept_class_id IN ('Branded Drug', 'Clinical Drug')
       AND EXISTS
              (SELECT 1
                 FROM concept_relationship_stage r
                WHERE     r.relationship_id = 'Quantified form of'
                      and r.concept_code_1 = c.concept_code
                      and r.vocabulary_id_1=c.vocabulary_id);
COMMIT;

--14 Create pack_content_stage table
TRUNCATE TABLE pack_content_stage;
INSERT /*+ APPEND */ INTO  pack_content_stage
     SELECT pc.pack_code AS pack_concept_code,
            'RxNorm' AS pack_vocabulary_id,
            cont.concept_code AS drug_concept_code,
            'RxNorm' AS drug_vocabulary_id,
            pc.amount,                                                                                                                                                      -- of drug units in the pack
            CAST (NULL AS NUMBER) AS box_size                                                                                                                -- number of the overall combinations units
       FROM (SELECT pack_code,
                    -- Parse the number at the beginning of each drug string as the amount
                    REGEXP_SUBSTR (pack_name, '^[0-9]+') AS amount,
                    -- Parse the number in parentheses on the second position of the drug string as the quantity factor of a quantified drug (usually not listed in the concept table), not used right now
                    TRANSLATE (REGEXP_SUBSTR (pack_name, '\([0-9]+ [A-Za-z]+\)'), 'a()', 'a') AS quant,
                    -- Don't parse the drug name, because it will be found through instr() with the known name of the component (see below)
                    pack_name AS drug
               FROM (SELECT DISTINCT pack_code,
                                     -- This is the sequence to split the concept_name of the packs by the semicolon, which replaces the parentheses plus slash (see below)
                                     TRIM (REGEXP_SUBSTR (pack_name,
                                                          '[^;]+',
                                                          1,
                                                          levels.COLUMN_VALUE))
                                        AS pack_name
                       FROM (-- This takes a Pack name, replaces the sequence ') / ' with a semicolon for splitting, and removes the word Pack and everything thereafter (the brand name usually)
                             SELECT rxcui AS pack_code, REGEXP_REPLACE (REPLACE (REPLACE (str, ') / ', ';'), '{'), '\) } Pack( \[.+\])?') AS pack_name
                               FROM rxnconso
                              WHERE sab = 'RXNORM' AND tty LIKE '%PCK'                                                                                            -- Clinical (=Generic) or Branded Pack
                                                                      ),
                            -- second half of fast Oracle split sequence
                            TABLE (CAST (MULTISET (    SELECT LEVEL
                                                         FROM DUAL
                                                   CONNECT BY LEVEL <= LENGTH (REGEXP_REPLACE (pack_name, '[^;]+')) + 1) AS SYS.OdciNumberList)) levels)) pc
            -- match by name with the component drug obtained through the 'Contains' relationship
            LEFT JOIN (SELECT concept_code_1,
                              concept_code_2,
                              concept_code,
                              concept_name
                         FROM concept_relationship_stage r JOIN concept_stage ON concept_code = r.concept_code_2
                        WHERE r.relationship_id = 'Contains') cont
               ON cont.concept_code_1 = pc.pack_code AND INSTR (pc.drug, cont.concept_name) > 0               -- this is where the component name is fit into the parsed drug name from the Pack string;
   GROUP BY pc.pack_code, cont.concept_code, pc.amount;
COMMIT;

--15 Run drug_strength_stage.sql from current directory

--16 Run generic_update.sql from working directory

--17 After previous step disable indexes and truncate tables again
UPDATE vocabulary SET (latest_update, vocabulary_version, dev_schema_name)=
(select latest_update, vocabulary_version, dev_schema_name from vocabulary WHERE vocabulary_id = 'RxNorm')
	WHERE vocabulary_id in ('NDFRT','VA Product', 'VA Class', 'ATC');
UPDATE vocabulary SET latest_update=null, dev_schema_name=null WHERE vocabulary_id = 'RxNorm';
COMMIT;

TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--18 Add NDFRT, VA Product, VA Class and ATC
--create temporary table drug_vocs
CREATE TABLE drug_vocs
NOLOGGING
AS
   SELECT rxcui,
          code,
          concept_name,
          CASE
             WHEN concept_class_id LIKE 'VA%' THEN concept_class_id
             ELSE 'NDFRT'
          END
             AS vocabulary_id,
          CASE concept_class_id
             WHEN 'VA Product' THEN NULL
             WHEN 'Dose Form' THEN NULL
             WHEN 'Pharma Preparation' THEN NULL
             ELSE 'C'
          END
             AS standard_concept,
          concept_code,
          concept_class_id
     FROM (SELECT rxcui,
                  code,
                  CASE
                     WHEN INSTR (str, '[') > 1
                     THEN
                        SUBSTR (str, 1, INSTR (str, '[') - 1)
                     WHEN INSTR (str, '[') = 1
                     THEN
                        SUBSTR (str, INSTR (str, ']') + 2, 256)
                     ELSE
                        SUBSTR (str, 1, 255)
                  END
                     AS concept_name,
                  CASE
                     WHEN INSTR (str, '[') = 1
                     THEN
                        SUBSTR (str, 2, INSTR (str, ']') - 2)
                     ELSE
                        code
                  END
                     AS concept_code,
                  CASE
                     WHEN INSTR (str, '[') > 1
                     THEN
                        CASE REGEXP_REPLACE (str,
                                             '([^\[]+)\[([^]]+)\]',
                                             '\2')
                           WHEN 'PK'
                           THEN
                              'PK'
                           WHEN 'Dose Form'
                           THEN
                              'Dose Form'
                           WHEN 'TC'
                           THEN
                              'Therapeutic Class'
                           WHEN 'MoA'
                           THEN
                              'Mechanism of Action'
                           WHEN 'PE'
                           THEN
                              'Physiologic Effect'
                           WHEN 'VA Product'
                           THEN
                              'VA Product'
                           WHEN 'EPC'
                           THEN
                              'Pharmacologic Class'
                           WHEN 'Chemical/Ingredient'
                           THEN
                              'Chemical Structure'
                           WHEN 'Disease/Finding'
                           THEN
                              'Ind / CI'
                        END
                     WHEN INSTR (str, '[') = 1
                     THEN
                        'VA Class'
                     ELSE
                        'Pharma Preparation'
                  END
                     AS concept_class_id
             FROM rxnconso
            WHERE     sab = 'NDFRT'
                  AND tty IN ('FN', 'HT', 'MTH_RXN_RHT')
				  AND code != 'NOCODE')
    WHERE concept_class_id IS NOT NULL -- kick out "preparations", which really are the useless 1st initial of pharma preparations
   -- Add ATC
   UNION ALL
   SELECT rxcui,
          code,
          concept_name,
          'ATC' AS vocabulary_id,
          'C' AS standard_concept,
          concept_code,
          concept_class_id
     FROM (SELECT DISTINCT
                  rxcui,
                  code,
                  SUBSTR (str, 1, 255) AS concept_name,
                  code AS concept_code,
                  CASE
                     WHEN LENGTH (code) = 1 THEN 'ATC 1st'
                     WHEN LENGTH (code) = 3 THEN 'ATC 2nd'
                     WHEN LENGTH (code) = 4 THEN 'ATC 3rd'
                     WHEN LENGTH (code) = 5 THEN 'ATC 4th'
                     WHEN LENGTH (code) = 7 THEN 'ATC 5th'
                  END
                     AS concept_class_id
             FROM rxnconso
            WHERE sab = 'ATC' AND tty IN ('PT', 'IN') AND code != 'NOCODE');

--19 Add drug_vocs to concept_stage
INSERT INTO concept_stage (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT NULL AS concept_id,
          concept_name,
          'Drug' AS domain_id,
          dv.vocabulary_id,
          concept_class_id,
          standard_concept,
          concept_code,
          v.latest_update AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM drug_vocs dv, vocabulary v
    WHERE v.vocabulary_id = dv.vocabulary_id;
COMMIT;	

--20 Rename the top NDFRT concept
UPDATE concept_stage
   SET concept_name =
             'NDF-RT release '
          || (SELECT latest_update
                FROM vocabulary
               WHERE vocabulary_id = 'NDFRT'),
       domain_id = 'Metadata'
 WHERE concept_code = 'N0000000001';
 COMMIT;

--21 Create all sorts of relationships to self, RxNorm and SNOMED
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'VA Class to ATC eq' AS relationship_id,
                   'VA Class' AS vocabulary_id_1,
                   'ATC' AS vocabulary_id_2,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM drug_vocs d
          JOIN rxnconso r ON r.rxcui = d.rxcui AND r.code != 'NOCODE'
          JOIN drug_vocs e ON r.rxcui = e.rxcui AND r.code = e.concept_code
          JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
    WHERE     d.concept_class_id LIKE 'VA Class'
          AND e.concept_class_id LIKE 'ATC%'
   -- Cross-link between drug class Chemical Structure AND ATC
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'NDFRT to ATC eq' AS relationship_id,
                   'NDFRT' AS vocabulary_id_1,
                   'ATC' AS vocabulary_id_2,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM drug_vocs d
          JOIN rxnconso r ON r.rxcui = d.rxcui AND r.code != 'NOCODE'
          JOIN drug_vocs e ON r.rxcui = e.rxcui AND r.code = e.concept_code
          JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
    WHERE     d.concept_class_id IN 'Chemical Structure'
          AND e.concept_class_id IN ('ATC 1st',
                                     'ATC 2nd',
                                     'ATC 3rd',
                                     'ATC 4th')
   -- Cross-link between drug class ATC AND Therapeutic Class
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'NDFRT to ATC eq' AS relationship_id,
                   'NDFRT' AS vocabulary_id_1,
                   'ATC' AS vocabulary_id_2,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM drug_vocs d
          JOIN rxnconso r ON r.rxcui = d.rxcui AND r.code != 'NOCODE'
          JOIN drug_vocs e ON r.rxcui = e.rxcui AND r.code = e.concept_code
          JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
    WHERE     d.concept_class_id LIKE 'Therapeutic Class'
          AND e.concept_class_id LIKE 'ATC%'
   -- Cross-link between drug class VA Class AND Chemical Structure
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'VA Class to NDFRT eq' AS relationship_id,
                   'VA Class' AS vocabulary_id_1,
                   'NDFRT' AS vocabulary_id_2,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM drug_vocs d
          JOIN rxnconso r ON r.rxcui = d.rxcui AND r.code != 'NOCODE'
          JOIN drug_vocs e ON r.rxcui = e.rxcui AND r.code = e.concept_code
          JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
    WHERE     d.concept_class_id LIKE 'VA Class'
          AND e.concept_class_id = 'Chemical Structure'
   -- Cross-link between drug class VA Class AND Therapeutic Class
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'VA Class to NDFRT eq' AS relationship_id,
                   'VA Class' AS vocabulary_id_1,
                   'NDFRT' AS vocabulary_id_2,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM drug_vocs d
          JOIN rxnconso r ON r.rxcui = d.rxcui AND r.code != 'NOCODE'
          JOIN drug_vocs e ON r.rxcui = e.rxcui AND r.code = e.concept_code
          JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
    WHERE     d.concept_class_id LIKE 'VA Class'
          AND e.concept_class_id = 'Therapeutic Class'
   -- Cross-link between drug class Chemical Structure AND Pharmaceutical Preparation
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'Chem to Prep eq' AS relationship_id, -- this is one to substitute "NDFRT has ing", is hierarchical AND defines ancestry.
                   'NDFRT' AS vocabulary_id_1,
                   'NDFRT' AS vocabulary_id_2,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM drug_vocs d
          JOIN rxnconso r ON r.rxcui = d.rxcui AND r.code != 'NOCODE'
          JOIN drug_vocs e ON r.rxcui = e.rxcui AND r.code = e.concept_code
          JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
    WHERE     d.concept_class_id LIKE 'Chemical Structure'
          AND e.concept_class_id = 'Pharma Preparation'
   -- Cross-link between drug class SNOMED AND NDF-RT
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'SNOMED - NDFRT eq' AS relationship_id,
                   'SNOMED' AS vocabulary_id_1,
                   'NDFRT' AS vocabulary_id_2,
                   d.valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM concept d
          JOIN rxnconso r
             ON r.code = d.concept_code AND r.sab = 'SNOMEDCT_US' AND r.code != 'NOCODE'
          JOIN rxnconso r2 ON r.rxcui = r2.rxcui AND r2.sab = 'NDFRT' AND r2.code != 'NOCODE'
          JOIN drug_vocs e
             ON r2.code = e.concept_code AND e.vocabulary_id = 'NDFRT'
    WHERE     d.vocabulary_id = 'SNOMED'
          AND invalid_reason IS NULL
          -- exclude all the Pharmaceutical Preps that are duplicates for RxNorm Ingredients
          AND NOT EXISTS
                 (SELECT 1
                    FROM drug_vocs pp
                   WHERE     pp.rxcui = r.rxcui
                         AND pp.concept_class_id = 'Pharma Preparation')
   -- Cross-link between drug class SNOMED AND VA Class
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'SNOMED - VA Class eq' AS relationship_id,
                   'SNOMED' AS vocabulary_id_1,
                   'VA Class' AS vocabulary_id_2,
                   d.valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM concept d
          JOIN rxnconso r
             ON r.code = d.concept_code AND r.sab = 'SNOMEDCT_US' AND r.code != 'NOCODE'
          JOIN rxnconso r2 ON r.rxcui = r2.rxcui AND r2.sab = 'NDFRT' AND r2.code != 'NOCODE'
          JOIN drug_vocs e
             ON r2.code = e.code AND e.vocabulary_id = 'VA Class' -- code AND concept_code are different for VA Class
    WHERE d.vocabulary_id = 'SNOMED' AND d.invalid_reason IS NULL
   -- Cross-link between drug class SNOMED AND ATC classes (not ATC 5th)
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'SNOMED - ATC eq' AS relationship_id,
                   'SNOMED' AS vocabulary_id_1,
                   'ATC' AS vocabulary_id_2,
                   d.valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM concept d
          JOIN rxnconso r
             ON r.code = d.concept_code AND r.sab = 'SNOMEDCT_US' AND r.code != 'NOCODE'
          JOIN rxnconso r2 ON r.rxcui = r2.rxcui AND r2.sab = 'ATC' AND r2.code != 'NOCODE'
          JOIN drug_vocs e
             ON r2.code = e.concept_code AND e.concept_class_id != 'ATC 5th' -- Ingredients only to RxNorm
    WHERE d.vocabulary_id = 'SNOMED' AND d.invalid_reason IS NULL
   -- Cross-link between any NDF-RT (mostly Pharmaceutical Preps AND Chemical Structure) to RxNorm
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'NDFRT - RxNorm eq' AS relationship_id,
                   'NDFRT' AS vocabulary_id_1,
                   'RxNorm' AS vocabulary_id_2,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM drug_vocs d
          JOIN rxnconso r ON r.rxcui = d.rxcui AND r.code != 'NOCODE'
          JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
          JOIN concept e
             ON     r.rxcui = e.concept_code
                AND e.vocabulary_id = 'RxNorm'
                AND e.invalid_reason IS NULL
    WHERE d.vocabulary_id = 'NDFRT'
   -- Cross-link between any NDF-RT to RxNorm by name, but exclude the ones the previous query did already
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'NDFRT - RxNorm name' AS relationship_id,
                   'NDFRT' AS vocabulary_id_1,
                   'RxNorm' AS vocabulary_id_2,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM drug_vocs d
          JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
          JOIN concept e
             ON     LOWER (d.concept_name) = LOWER (e.concept_name)
                AND e.vocabulary_id = 'RxNorm'
                AND e.invalid_reason IS NULL
    WHERE     d.vocabulary_id = 'NDFRT'
          AND NOT EXISTS
                 (SELECT 1
                    FROM drug_vocs d_int
                         JOIN rxnconso r_int ON r_int.rxcui = d_int.rxcui AND r_int.code != 'NOCODE'
                         JOIN concept e_int
                            ON     r_int.rxcui = e_int.concept_code
                               AND e_int.vocabulary_id = 'RxNorm'
                               AND e_int.invalid_reason IS NULL
                   WHERE     d_int.vocabulary_id = 'NDFRT'
                         AND d_int.concept_code = d.concept_code
                         AND e_int.concept_code = e.concept_code)
   -- Cross-link between VA Product AND RxNorm
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'VAProd - RxNorm eq' AS relationship_id,
                   'VA Product' AS vocabulary_id_1,
                   'RxNorm' AS vocabulary_id_2,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM drug_vocs d
          JOIN rxnconso r ON r.rxcui = d.rxcui AND r.code != 'NOCODE'
          JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
          JOIN concept e
             ON     r.rxcui = e.concept_code
                AND e.vocabulary_id = 'RxNorm'
                AND e.invalid_reason IS NULL
    WHERE d.vocabulary_id = 'VA Product'
   -- Mapping table between VA Product to RxNorm. VA Product is both an intermediary between RxNorm AND VA class, AND a source code
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'Maps to' AS relationship_id,
                   'VA Product' AS vocabulary_id_1,
                   'RxNorm' AS vocabulary_id_2,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM drug_vocs d
          JOIN rxnconso r ON r.rxcui = d.rxcui AND r.code != 'NOCODE'
          JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
          JOIN concept e
             ON     r.rxcui = e.concept_code
                AND e.vocabulary_id = 'RxNorm'
                AND e.invalid_reason IS NULL
    WHERE d.vocabulary_id = 'VA Product'
   -- add ATC to RxNorm
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'ATC - RxNorm' AS relationship_id, -- this is one to substitute "NDFRF has ing", is hierarchical AND defines ancestry.
                   'ATC' AS vocabulary_id_1,
                   'RxNorm' AS vocabulary_id_2,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM drug_vocs d
          JOIN rxnconso r ON r.rxcui = d.rxcui AND r.code != 'NOCODE'
          JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
          JOIN concept e
             ON     r.rxcui = e.concept_code
                AND e.vocabulary_id = 'RxNorm'
                AND e.invalid_reason IS NULL
    WHERE d.vocabulary_id = 'ATC' AND d.concept_class_id = 'ATC 5th' -- there are some weird 4th level links, LIKE D11AC 'Medicated shampoos' to an RxNorm Dose Form
   -- DO NOT add ATC to RxNorm mapping, because of bad min/max levels of separation [AVOF-82]
   /*
   -- add ATC to RxNorm mapping. ATC is both a classification (ATC 1-4) AND a source (ATC 5th)
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
                   e.concept_code AS concept_code_2,
                   'Maps to' AS relationship_id, -- this is one to substitute "NDFRF has ing", is hierarchical AND defines ancestry.
                   'ATC' AS vocabulary_id_1,
                   'RxNorm' AS vocabulary_id_2,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM drug_vocs d
          JOIN rxnconso r ON r.rxcui = d.rxcui AND r.code != 'NOCODE'
          JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
          JOIN concept e
             ON     r.rxcui = e.concept_code
                AND e.vocabulary_id = 'RxNorm'
                AND e.invalid_reason IS NULL
    WHERE d.vocabulary_id = 'ATC' AND d.concept_class_id = 'ATC 5th' -- there are some weird 4th level links, LIKE D11AC 'Medicated shampoos' to an RxNorm Dose Form
	*/
   -- add ATC to RxNorm by name, but exclude the ones the previous query did already
   UNION ALL
   SELECT DISTINCT d.concept_code AS concept_code_1,
					e.concept_code AS concept_code_2,
					'ATC - RxNorm name' AS relationship_id, -- this is one to substitute "NDFRF has ing", is hierarchical AND defines ancestry.
					'ATC' AS vocabulary_id_1,
					'RxNorm' AS vocabulary_id_2,
					v.latest_update AS valid_start_date,
					TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
					NULL AS invalid_reason
	  FROM drug_vocs d
		   JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
		   JOIN concept e
			  ON     LOWER (d.concept_name) = LOWER (e.concept_name)
				 AND e.vocabulary_id = 'RxNorm'
				 AND e.invalid_reason IS NULL
	WHERE     d.vocabulary_id = 'ATC'
		   AND d.concept_class_id = 'ATC 5th' -- there are some weird 4th level links, LIKE D11AC 'Medicated shampoos' to an RxNorm Dose Form
		   AND NOT EXISTS
				  (SELECT 1
					 FROM drug_vocs d_int
						  JOIN rxnconso r_int
							 ON     r_int.rxcui = d_int.rxcui
								AND r_int.code != 'NOCODE'
						  JOIN concept e_int
							 ON     r_int.rxcui = e_int.concept_code
								AND e_int.vocabulary_id = 'RxNorm'
								AND e_int.invalid_reason IS NULL
					WHERE     d_int.vocabulary_id = 'ATC'
						  AND d_int.concept_class_id = 'ATC 5th'
						  AND d_int.concept_code = d.concept_code
						  AND e_int.concept_code = e.concept_code)
   -- NDF-RT-defined relationships
   UNION ALL
   SELECT concept_code_1,
          concept_code_2,
          relationship_id,
          vocabulary_id_1,
          vocabulary_id_2,
          valid_start_date,
          valid_end_date,
          invalid_reason
     FROM (SELECT DISTINCT
                  e.concept_code AS concept_code_1,
                  d.concept_code AS concept_code_2,
                  CASE
                     WHEN r.rel = 'PAR'
                     THEN
                        'Subsumes'
                     WHEN r.rela = 'active_metabolites_of'
                     THEN
                        'Metabolite of'
                     WHEN r.rela = 'chemical_structure_of'
                     THEN
                        'Chem structure of'
                     WHEN r.rela = 'contraindicated_with_disease'
                     THEN
                        'CI by'
                     WHEN r.rela = 'contraindicating_class_of'
                     THEN
                        'CI chem class of'
                     WHEN r.rela = 'contraindicating_mechanism_of_action_of'
                     THEN
                        'CI MoA of'
                     WHEN r.rela = 'contraindicating_physiologic_effect_of'
                     THEN
                        'CI physiol effect by'
                     WHEN r.rela = 'dose_form_of'
                     THEN
                        'NDFRT dose form of'
                     WHEN r.rela = 'effect_may_be_inhibited_by'
                     THEN
                        'May be inhibited by'
                     WHEN r.rela = 'ingredient_of'
                     THEN
                        'NDFRT ing of'
                     WHEN r.rela = 'mechanism_of_action_of'
                     THEN
                        'MoA of'
                     WHEN r.rela = 'member_of'
                     THEN
                        'Is a'
                     WHEN r.rela = 'pharmacokinetics_of'
                     THEN
                        'PK of'
                     WHEN r.rela = 'physiologic_effect_of'
                     THEN
                        'Physiol effect by'
                     WHEN r.rela = 'product_component_of'
                     THEN
                        'Product comp of'
                     WHEN r.rela = 'therapeutic_class_of'
                     THEN
                        'Therap class of'
                     WHEN r.rela = 'induced_by'
                     THEN
                        'Induced by'
                     WHEN r.rela = 'inverse_isa'
                     THEN
                        'Subsumes'
                     WHEN r.rela = 'may_be_diagnosed_by'
                     THEN
                        'Diagnosed through'
                     WHEN r.rela = 'may_be_prevented_by'
                     THEN
                        'May be prevented by'
                     WHEN r.rela = 'may_be_treated_by'
                     THEN
                        'May be treated by'
                     WHEN r.rela = 'metabolic_site_of'
                     THEN
                        'Metabolism of'
                  END
                     AS relationship_id,
                  e.vocabulary_id AS vocabulary_id_1,
                  d.vocabulary_id AS vocabulary_id_2,
                  v.latest_update AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM drug_vocs d
                  JOIN rxnconso r1 ON r1.rxcui = d.rxcui AND r1.code = d.code AND r1.code != 'NOCODE'
                  JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
                  JOIN rxnrel r ON r.rxaui1 = r1.rxaui
                  JOIN rxnconso r2 ON r2.rxaui = r.rxaui2 AND r2.code != 'NOCODE'
                  JOIN drug_vocs e ON r2.code = e.code AND e.rxcui = r2.rxcui)
    WHERE relationship_id IS NOT NULL
	UNION
	-- Hierarchy inside ATC
	SELECT uppr.concept_code AS concept_code_1,
		   lowr.concept_code AS concept_code_2,
		   'Is a' AS relationship_id,
		   'ATC' AS vocabulary_id_1,
		   'ATC' AS vocabulary_id_2,
		   v.latest_update AS valid_start_date,
		   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
		   NULL AS invalid_reason
	  FROM concept_stage uppr, concept_stage lowr, vocabulary v
	 WHERE     (   (LENGTH (uppr.concept_code) IN (4, 5) AND lowr.concept_code = SUBSTR (uppr.concept_code, 1, LENGTH (uppr.concept_code) - 1))
				OR (LENGTH (uppr.concept_code) IN (3, 7) AND lowr.concept_code = SUBSTR (uppr.concept_code, 1, LENGTH (uppr.concept_code) - 2)))
		   AND uppr.vocabulary_id = 'ATC'
		   AND lowr.vocabulary_id = 'ATC'
		   AND v.vocabulary_id = 'ATC';	
	

COMMIT;

--22 Add manual relationships
BEGIN
   DEVV5.VOCABULARY_PACK.ProcessManualRelationships;
END;
COMMIT;

--23 Remove direct links to RxNorm Ingredients for all those ATC5 concepts that are ambiguous and likely are either defined as combinations or with certain Drug Forms only
DELETE FROM concept_relationship_stage
  WHERE ROWID IN
		   (SELECT crs.ROWID
			  FROM concept_stage c1, concept c2, concept_relationship_stage crs
			 WHERE     c1.concept_code = crs.concept_code_1
				   AND c1.vocabulary_id = crs.vocabulary_id_1
				   AND c2.concept_code = crs.concept_code_2
				   AND c2.vocabulary_id = crs.vocabulary_id_2
				   AND c1.vocabulary_id = 'ATC'
				   AND c1.concept_class_id = 'ATC 5th'
				   AND c1.invalid_reason IS NULL
				   AND c2.vocabulary_id = 'RxNorm'
				   --AND c2.concept_class_id IN ('Ingredient','Precise Ingredient') /*AVOF-322*/
				   AND crs.relationship_id in ('ATC - RxNorm','ATC - RxNorm name')
				   AND crs.invalid_reason IS NULL
				   AND c1.concept_name IN (  SELECT c_int.concept_name
											   FROM concept_stage c_int
											  WHERE c_int.vocabulary_id = 'ATC' AND c_int.concept_class_id = 'ATC 5th' AND c_int.invalid_reason IS NULL AND c_int.concept_name <> 'combinations'
										   GROUP BY c_int.concept_name
											 HAVING COUNT (*) > 1));
COMMIT;

--24 Remove ATC's duplicates (AVOF-322)
--diphtheria immunoglobulin
DELETE FROM concept_relationship_stage WHERE concept_code_1 = 'J06BB10' AND concept_code_2 = '3510' AND relationship_id = 'ATC - RxNorm';
--hydroquinine
DELETE FROM concept_relationship_stage WHERE concept_code_1 = 'M09AA01' AND concept_code_2 = '27220' AND relationship_id = 'ATC - RxNorm';
COMMIT;

--25 Deprecate relationships between multi ingredient drugs and a single ATC 5th, because it should have either an ATC for each ingredient or an ATC that is a combination of them
--25.1 Create temporary table drug_strength_ext (same code as in concept_ancestor, but we exclude ds for ingredients (because we use count(*)>1 and ds for ingredients having count(*)=1) and only for RxNorm)
CREATE TABLE drug_strength_ext as
        SELECT *
          FROM (WITH ingredient_unit
                     AS (SELECT DISTINCT
                                -- pick the most common unit for an ingredient. If there is a draw, pick always the same by sorting by unit_concept_id
                                ingredient_concept_code, vocabulary_id, FIRST_VALUE (unit_concept_id) OVER (PARTITION BY ingredient_concept_code ORDER BY cnt DESC, unit_concept_id) AS unit_concept_id
                           FROM (  -- sum the counts coming from amount and numerator
                                   SELECT ingredient_concept_code,
                                          vocabulary_id,
                                          unit_concept_id,
                                          SUM (cnt) AS cnt
                                     FROM (
                                           -- count ingredients, their units and the frequency
                                           SELECT   c2.concept_code AS ingredient_concept_code,
                                                    c2.vocabulary_id,
                                                    ds.amount_unit_concept_id AS unit_concept_id,
                                                    COUNT (*) AS cnt
                                               FROM drug_strength ds
                                                    JOIN concept c1 ON c1.concept_id = ds.drug_concept_id AND c1.vocabulary_id = 'RxNorm'
                                                    JOIN concept c2 ON c2.concept_id = ds.ingredient_concept_id AND c2.vocabulary_id = 'RxNorm'
                                              WHERE ds.amount_value <> 0
                                           GROUP BY c2.concept_code, c2.vocabulary_id, ds.amount_unit_concept_id
                                           UNION
                                             SELECT c2.concept_code AS ingredient_concept_code,
                                                    c2.vocabulary_id,
                                                    ds.numerator_unit_concept_id AS unit_concept_id,
                                                    COUNT (*) AS cnt
                                               FROM drug_strength ds
                                                    JOIN concept c1 ON c1.concept_id = ds.drug_concept_id AND c1.vocabulary_id = 'RxNorm'
                                                    JOIN concept c2 ON c2.concept_id = ds.ingredient_concept_id AND c2.vocabulary_id = 'RxNorm'
                                              WHERE ds.numerator_value <> 0
                                           GROUP BY c2.concept_code, c2.vocabulary_id, ds.numerator_unit_concept_id)
                                 GROUP BY ingredient_concept_code, vocabulary_id, unit_concept_id))
                -- Create drug_strength for drug forms
                SELECT de.concept_code AS drug_concept_code,
                       an.concept_code AS ingredient_concept_code
                  FROM concept an
                       JOIN rxnorm_ancestor a ON a.ancestor_concept_code = an.concept_code and a.ancestor_vocabulary_id=an.vocabulary_id
                       JOIN concept de ON de.concept_code = a.descendant_concept_code and de.vocabulary_id=a.descendant_vocabulary_id
                       JOIN ingredient_unit iu ON iu.ingredient_concept_code = an.concept_code AND iu.vocabulary_id = an.vocabulary_id
                 WHERE     an.vocabulary_id = 'RxNorm'
                       AND an.concept_class_id = 'Ingredient'
                       AND de.vocabulary_id = 'RxNorm'
                       AND de.concept_class_id IN ('Clinical Drug Form', 'Branded Drug Form'));
--25.2 Do deprecation
delete from concept_relationship_stage
  where rowid in (
    select drug2atc.row_id from (
        select drug_concept_code from (
			select c1.concept_code as drug_concept_code, c2.concept_code from drug_strength ds
			join concept c1 on c1.concept_id=ds.drug_concept_id and c1.vocabulary_id='RxNorm'
			join concept c2 on c2.concept_id=ds.ingredient_concept_id
			union
			select drug_concept_code, ingredient_concept_code from drug_strength_ext
		)
        group by drug_concept_code having count(*)>1
    ) all_drugs
    join (
        select * from (
            select crs.rowid row_id, crs.concept_code_2, count(*) over(partition by crs.concept_code_2) cnt_atc 
            from concept_relationship_stage crs
            join concept_stage cs on cs.concept_code=crs.concept_code_1 and cs.vocabulary_id=crs.vocabulary_id_1 and cs.vocabulary_id='ATC' and cs.concept_class_id='ATC 5th'
            and not regexp_like (cs.concept_name,'preparations|virus|antigen|-|/|organisms|insulin|etc\.|influenza|human menopausal gonadotrophin|combination|amino acids|electrolytes| and |excl\.| with |others|various')  
            join concept c on  c.concept_code=crs.concept_code_2 and c.vocabulary_id=crs.vocabulary_id_2 and c.vocabulary_id='RxNorm'  
            where crs.relationship_id='ATC - RxNorm' and crs.invalid_reason is null
        ) where cnt_atc=1
    ) drug2atc on drug2atc.concept_code_2=all_drugs.drug_concept_code
);
commit;

--26 Add synonyms to concept_synonym stage for each of the rxcui/code combinations in drug_vocs
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
SELECT DISTINCT
       NULL AS synonym_concept_id,
       dv.concept_code AS synonym_concept_code,
       CASE
          WHEN dv.vocabulary_id = 'VA Class'
          THEN
             SUBSTR (REPLACE (r.str, '[' || dv.concept_code || '] ', NULL),
                     1,
                     1000)
          WHEN     dv.vocabulary_id IN ('NDFRT', 'VA Product')
               AND INSTR (r.str, '[') <> 0
          THEN
             SUBSTR (r.str, 1, LEAST (INSTR (r.str, '[') - 2, 1000))
          ELSE
             SUBSTR (r.str, 1, 1000)
       END
          AS synonym_name,
       dv.vocabulary_id AS synonym_vocabulary_id,
       4180186 AS language_concept_id
  FROM drug_vocs dv
       JOIN rxnconso r
          ON     dv.code = r.code
             AND dv.rxcui = r.rxcui
             AND r.code != 'NOCODE'
             AND r.lat = 'ENG';
COMMIT;

--27 Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
COMMIT;

--28 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;	

--29 Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;		 

--30 Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

--31 Clean up
DROP TABLE drug_vocs PURGE;
DROP TABLE rxnorm_ancestor PURGE;
DROP TABLE drug_strength_ext PURGE;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		