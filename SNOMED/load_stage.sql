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
-- Use the later of the release dates of the international and UK versions. Usually, the UK is later.
-- If the international version is already loaded, updating will not affect it
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'SNOMED',
                                          pVocabularyDate        => TO_DATE ('20160131', 'yyyymmdd'),
                                          pVocabularyVersion     => 'SnomedCT Release 20160131',
                                          pVocabularyDevSchema   => 'DEV_SNOMED');
END;
COMMIT;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;

--3 Create core version of DM+D
--3.1. We need to create temporary table of DM+D with the same structure as concept_stage and pseudo-column 'insert_id'
--later it will be important
CREATE TABLE concept_stage_dmd NOLOGGING AS SELECT * FROM concept_stage WHERE 1=0;
ALTER TABLE concept_stage_dmd ADD insert_id NUMBER;          

INSERT /*+ APPEND */
      INTO  concept_stage_dmd (concept_id,
                               concept_name,
                               domain_id,
                               vocabulary_id,
                               concept_class_id,
                               standard_concept,
                               concept_code,
                               valid_start_date,
                               valid_end_date,
                               invalid_reason,
                               insert_id)
   -- UoM
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'INFO/DESC') AS concept_name,
          'Unit' AS domain_id,
          'SNOMED' AS vocabulary_id,
          'Qualifier Value' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'INFO/CD') AS concept_code,
          TO_DATE (NVL (EXTRACTVALUE (VALUE (t), 'INFO/CDDT'), '1970-01-01'),
                   'YYYY-MM-DD')
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason,
          1 AS insert_id
     FROM f_lookup2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('LOOKUP/UNIT_OF_MEASURE/INFO'))) t
   UNION ALL
   --deprecated UoM
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'INFO/DESC') AS concept_name,
          'Unit' AS domain_id,
          'SNOMED' AS vocabulary_id,
          'Qualifier Value' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE (EXTRACTVALUE (VALUE (t), 'INFO/CDDT'), 'YYYY-MM-DD') - 1
             AS valid_end_date,
          'U' AS invalid_reason,
          2 AS insert_id
     FROM f_lookup2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('LOOKUP/UNIT_OF_MEASURE/INFO'))) t
    WHERE EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') IS NOT NULL
   UNION ALL
   --Forms
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'INFO/DESC') AS concept_name,
          'Observation' AS domain_id,
          'SNOMED' AS vocabulary_id,
          'Pharma/Biol Product' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'INFO/CD') AS concept_code,
          TO_DATE (NVL (EXTRACTVALUE (VALUE (t), 'INFO/CDDT'), '1970-01-01'),
                   'YYYY-MM-DD')
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason,
          3 AS insert_id
     FROM f_lookup2 t_xml,
          TABLE (XMLSEQUENCE (t_xml.xmlfield.EXTRACT ('LOOKUP/FORM/INFO'))) t
   UNION ALL
   --deprecated Forms
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'INFO/DESC') AS concept_name,
          'Observation' AS domain_id,
          'SNOMED' AS vocabulary_id,
          'Pharma/Biol Product' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE (EXTRACTVALUE (VALUE (t), 'INFO/CDDT'), 'YYYY-MM-DD') - 1
             AS valid_end_date,
          'U' AS invalid_reason,
          4 AS insert_id
     FROM f_lookup2 t_xml,
          TABLE (XMLSEQUENCE (t_xml.xmlfield.EXTRACT ('LOOKUP/FORM/INFO'))) t
    WHERE EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') IS NOT NULL
   UNION ALL
   --Routes
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'INFO/DESC') AS concept_name,
          'Route' AS domain_id,
          'SNOMED' AS vocabulary_id,
          'Qualifier Value' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'INFO/CD') AS concept_code,
          TO_DATE (NVL (EXTRACTVALUE (VALUE (t), 'INFO/CDDT'), '1970-01-01'),
                   'YYYY-MM-DD')
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason,
          5 AS insert_id
     FROM f_lookup2 t_xml,
          TABLE (XMLSEQUENCE (t_xml.xmlfield.EXTRACT ('LOOKUP/ROUTE/INFO'))) t
   UNION ALL
   --Deprecated Routes
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'INFO/DESC') AS concept_name,
          'Route' AS domain_id,
          'SNOMED' AS vocabulary_id,
          'Qualifier Value' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE (EXTRACTVALUE (VALUE (t), 'INFO/CDDT'), 'YYYY-MM-DD') - 1
             AS valid_end_date,
          'U' AS invalid_reason,
          6 AS insert_id
     FROM f_lookup2 t_xml,
          TABLE (XMLSEQUENCE (t_xml.xmlfield.EXTRACT ('LOOKUP/ROUTE/INFO'))) t
    WHERE EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') IS NOT NULL
   /* Leave out because we don't know the proper concept class
   UNION ALL
   --Suppliers
  SELECT NULL AS concept_id,
         EXTRACTVALUE (VALUE (t), 'INFO/NM') AS concept_name, -----INFO/DESC????
         'Observation' AS domain_id,
         'SNOMED' AS vocabulary_id,
         'xxxx' AS concept_class_id,
         NULL AS standard_concept,
         EXTRACTVALUE (VALUE (t), 'INFO/CD') AS concept_code,
         TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
         CASE
            WHEN EXTRACTVALUE (VALUE (t), 'INFO/INVALID') = '1'
            THEN
               (SELECT latest_update - 1
                  FROM vocabulary
                 WHERE vocabulary_id = 'SNOMED')
            ELSE
               TO_DATE ('20991231', 'yyyymmdd')
         END
            AS valid_end_date,
         CASE
            WHEN EXTRACTVALUE (VALUE (t), 'INFO/INVALID') = '1' THEN 'D'
            ELSE NULL
         END
            AS invalid_reason
    FROM f_lookup2 t_xml,
         TABLE (XMLSEQUENCE (t_xml.xmlfield.EXTRACT ('LOOKUP/SUPPLIER/INFO'))) t
         WHERE EXTRACTVALUE (VALUE (t), 'INFO/NM') is not null
   UNION ALL
   --Deprecated Suppliers
  SELECT NULL AS concept_id,
         EXTRACTVALUE (VALUE (t), 'INFO/NM') AS concept_name, -----INFO/DESC????
         'xxxx' AS domain_id,
         'SNOMED' AS vocabulary_id,
         'xxxx' AS concept_class_id,
         NULL AS standard_concept,
         EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') AS concept_code,
         TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
         TO_DATE (EXTRACTVALUE (VALUE (t), 'INFO/CDDT'), 'YYYY-MM-DD') - 1
            AS valid_end_date,
         'U' AS invalid_reason
    FROM f_lookup2 t_xml,
         TABLE (XMLSEQUENCE (t_xml.xmlfield.EXTRACT ('LOOKUP/SUPPLIER/INFO'))) t
   WHERE EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') IS NOT NULL
   AND EXTRACTVALUE (VALUE (t), 'INFO/NM') is not null
  */
   UNION ALL
   --Ingredients
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'ING/NM') AS concept_name,
          'Drug' AS domain_id,
          'SNOMED' AS vocabulary_id,
          'Substance' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'ING/ISID') AS concept_code,
          TO_DATE (
             NVL (EXTRACTVALUE (VALUE (t), 'ING/ISIDDT'), '1970-01-01'),
             'YYYY-MM-DD')
             AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'ING/INVALID') = '1'
             THEN
                (SELECT latest_update - 1
                   FROM vocabulary
                  WHERE vocabulary_id = 'SNOMED')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'ING/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          7 AS insert_id
     FROM f_ingredient2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('INGREDIENT_SUBSTANCES/ING'))) t
   UNION ALL
   --deprecated Ingredients
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'ING/NM') AS concept_name,
          'Drug' AS domain_id,
          'SNOMED' AS vocabulary_id,
          'Substance' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'ING/ISIDPREV') AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE (EXTRACTVALUE (VALUE (t), 'ING/ISIDDT'), 'YYYY-MM-DD') - 1
             AS valid_end_date,
          'U' AS invalid_reason,
          8 AS insert_id
     FROM f_ingredient2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('INGREDIENT_SUBSTANCES/ING'))) t
    WHERE EXTRACTVALUE (VALUE (t), 'ING/ISIDPREV') IS NOT NULL
   UNION ALL
   --VTMs (Ingredients)
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'VTM/NM') AS concept_name,
          'Drug' AS domain_id,
          'SNOMED' AS vocabulary_id,
          'Pharma/Biol Product' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'VTM/VTMID') AS concept_code,
          TO_DATE (
             NVL (EXTRACTVALUE (VALUE (t), 'VTM/VTMIDDT'), '1970-01-01'),
             'YYYY-MM-DD')
             AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VTM/INVALID') = '1'
             THEN
                (SELECT latest_update - 1
                   FROM vocabulary
                  WHERE vocabulary_id = 'SNOMED')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VTM/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          9 AS insert_id
     FROM f_vtm2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('VIRTUAL_THERAPEUTIC_MOIETIES/VTM'))) t
   UNION ALL
   --deprecated VTMs
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'VTM/NM') AS concept_name,
          'Drug' AS domain_id,
          'SNOMED' AS vocabulary_id,
          'Pharma/Biol Product' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'VTM/VTMIDPREV') AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE (EXTRACTVALUE (VALUE (t), 'VTM/VTMIDDT'), 'YYYY-MM-DD') - 1
             AS valid_end_date,
          'U' AS invalid_reason,
          10 AS insert_id
     FROM f_vtm2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('VIRTUAL_THERAPEUTIC_MOIETIES/VTM'))) t
    WHERE EXTRACTVALUE (VALUE (t), 'VTM/VTMIDPREV') IS NOT NULL
   UNION ALL
   --VMPs (generic or clinical drugs)
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'VMP/NM') AS concept_name,
          'Drug' AS domain_id,
          'SNOMED' AS vocabulary_id,
          'Pharma/Biol Product' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'VMP/VPID') AS concept_code,
          TO_DATE (
             NVL (EXTRACTVALUE (VALUE (t), 'VMP/VTMIDDT'), '1970-01-01'),
             'YYYY-MM-DD')
             AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VMP/INVALID') = '1'
             THEN
                (SELECT latest_update - 1
                   FROM vocabulary
                  WHERE vocabulary_id = 'SNOMED')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VMP/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          11 AS insert_id
     FROM f_vmp2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('VIRTUAL_MED_PRODUCTS/VMPS/VMP'))) t
   UNION ALL
   --deprecated VMPs
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'VMP/NM') AS concept_name,
          'Drug' AS domain_id,
          'SNOMED' AS vocabulary_id,
          'Pharma/Biol Product' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'VMP/VPIDPREV') AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE (EXTRACTVALUE (VALUE (t), 'VMP/VPIDDT'), 'YYYY-MM-DD') - 1
             AS valid_end_date,
          'U' AS invalid_reason,
          12 AS insert_id
     FROM f_vmp2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('VIRTUAL_MED_PRODUCTS/VMPS/VMP'))) t
    WHERE EXTRACTVALUE (VALUE (t), 'VMP/VPIDPREV') IS NOT NULL
   UNION ALL
   -- AMPs (branded drugs)
   SELECT NULL AS concept_id,
          SUBSTR (EXTRACTVALUE (VALUE (t), 'AMP/DESC'), 1, 255)
             AS concept_name,
          'Drug' AS domain_id,
          'SNOMED' AS vocabulary_id,
          'Pharma/Biol Product' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'AMP/APID') AS concept_code,
          TO_DATE (NVL (EXTRACTVALUE (VALUE (t), 'AMP/NMDT'), '1970-01-01'),
                   'YYYY-MM-DD')
             AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'AMP/INVALID') = '1'
             THEN
                (SELECT latest_update - 1
                   FROM vocabulary
                  WHERE vocabulary_id = 'SNOMED')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'AMP/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          13 AS insert_id
     FROM f_amp2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('ACTUAL_MEDICINAL_PRODUCTS/AMPS/AMP'))) t
   UNION ALL
   --VMPPs (clinical packs)
   SELECT NULL AS concept_id,
          SUBSTR (EXTRACTVALUE (VALUE (t), 'VMPP/NM'), 1, 255)
             AS concept_name,
          'Drug' AS domain_id,
          'SNOMED' AS vocabulary_id,
          'Pharma/Biol Product' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'VMPP/VPPID') AS concept_code,
          TO_DATE ('1970-01-01', 'YYYY-MM-DD') AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VMPP/INVALID') = '1'
             THEN
                (SELECT latest_update - 1
                   FROM vocabulary
                  WHERE vocabulary_id = 'SNOMED')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VMPP/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          14 AS insert_id
     FROM f_vmpp2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT (
                   'VIRTUAL_MED_PRODUCT_PACK/VMPPS/VMPP'))) t
   UNION ALL
   --AMPPs (branded packs)
   SELECT NULL AS concept_id,
          SUBSTR (EXTRACTVALUE (VALUE (t), 'AMPP/NM'), 1, 255)
             AS concept_name,
          'Drug' AS domain_id,
          'SNOMED' AS vocabulary_id,
          'Pharma/Biol Product' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'AMPP/APPID') AS concept_code,
          TO_DATE ('1970-01-01', 'YYYY-MM-DD') AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'AMPP/INVALID') = '1'
             THEN
                (SELECT latest_update - 1
                   FROM vocabulary
                  WHERE vocabulary_id = 'SNOMED')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'AMPP/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          15 AS insert_id
     FROM f_ampp2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT (
                   'ACTUAL_MEDICINAL_PROD_PACKS/AMPPS/AMPP'))) t;
COMMIT;				   
				   
--3.2 delete duplicates, first of all concepts with invalid_reason='D', then 'U', last of all 'NULL'
DELETE FROM concept_stage_dmd
      WHERE ROWID NOT IN (SELECT LAST_VALUE (
                                    ROWID)
                                 OVER (
                                    PARTITION BY concept_code
                                    ORDER BY invalid_reason, ROWID
                                    ROWS BETWEEN UNBOUNDED PRECEDING
                                         AND     UNBOUNDED FOLLOWING)
                            FROM concept_stage_dmd);				   
COMMIT;	

--3.3 copy DM+D to concept_stage
INSERT /*+ APPEND */
      INTO  concept_stage (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT concept_id,
          concept_name,
          domain_id,
          vocabulary_id,
          concept_class_id,
          standard_concept,
          concept_code,
          valid_start_date,
          valid_end_date,
          invalid_reason
     FROM concept_stage_dmd;  
COMMIT;

-- 4. Create core version of SNOMED without concept_id, domain_id, concept_class_id, standard_concept
INSERT  /*+ APPEND */  INTO concept_stage (concept_name,
                           vocabulary_id,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT regexp_replace(coalesce(umls.concept_name, sct2.concept_name), ' (\([^)]*\))$', ''), -- pick the umls one first (if there) and trim something like "(procedure)"
          'SNOMED' AS vocabulary_id,
          sct2.concept_code,
          (SELECT latest_update FROM vocabulary WHERE vocabulary_id='SNOMED') AS valid_start_date,
          TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
          NULL AS invalid_reason
     FROM (
          SELECT SUBSTR(d.term, 1, 255) AS concept_name,
                  d.conceptid AS concept_code,
                  c.active,
                  ROW_NUMBER ()
                  OVER (
                     PARTITION BY d.conceptid
                     -- Order of preference: newest in sct2_concept, in sct2_desc, synonym, does not contain class in parenthesis
                     ORDER BY
                        TO_DATE (c.effectivetime, 'YYYYMMDD') DESC,
                        TO_DATE (d.effectivetime, 'YYYYMMDD') DESC,
                        CASE
                           WHEN typeid = '900000000000013009' THEN 0
                           ELSE 1
                        END,
                        CASE WHEN term LIKE '%(%)%' THEN 1 ELSE 0 END,
						LENGTH(TERM) DESC)
                     AS rn
             FROM sct2_concept_full_merged c, sct2_desc_full_merged d
            WHERE c.id = d.conceptid AND term IS NOT NULL
          ) sct2
        LEFT JOIN ( -- get a better concept_name
              SELECT DISTINCT code AS concept_code,
                  FIRST_VALUE ( -- take the best str 
                     SUBSTR(str, 1, 255)) 
                  OVER (
                     PARTITION BY code
                     ORDER BY
                        DECODE (tty,
                                'PT', 1,
                                'PTGB', 2,
                                'SY', 3,
                                'SYGB', 4,
                                'MTH_PT', 5,
                                'FN', 6,
                                'MTH_SY', 7,
                                'SB', 8,
                                10            -- default for the obsolete ones
                              )) as concept_name
             FROM umls.mrconso
            WHERE sab = 'SNOMEDCT_US'
              AND tty in ('PT', 'PTGB', 'SY', 'SYGB', 'MTH_PT', 'FN', 'MTH_SY', 'SB')
        ) umls
          ON sct2.concept_code = umls.concept_code
    WHERE sct2.rn = 1 AND sct2.active = 1
	AND NOT EXISTS (
		--DM+D first, SNOMED last
		SELECT 1 FROM concept_stage cs_int WHERE cs_int.concept_code=sct2.concept_code
	);
COMMIT;	
	
-- 5. Create temporary table with extracted class information and terms ordered by some good precedence
CREATE TABLE tmp_concept_class
AS
   SELECT *
     FROM (SELECT concept_code,
                  f7,                                       -- extracted class
                  ROW_NUMBER ()
                  OVER (
                     PARTITION BY concept_code
                     -- order of precedence: active, by class relevance, by highest number of parentheses
                     ORDER BY
                        active DESC,
                        DECODE (f7,
                                'disorder', 1,
                                'finding', 2,
                                'procedure', 3,
                                'regime/therapy', 4,
                                'qualifier value', 5,
                                'contextual qualifier', 6,
                                'body structure', 7,
                                'cell', 8,
                                'cell structure', 9,
                                'external anatomical feature', 10,
                                'organ component', 11,
                                'organism', 12,
                                'living organism', 13,
                                'physical object', 14,
                                'physical device', 15,
                                'physical force', 16,
                                'occupation', 17,
                                'person', 18,
                                'ethnic group', 19,
                                'religion/philosophy', 20,
                                'life style', 21,
                                'social concept', 22,
                                'racial group', 23,
                                'event', 24,
                                'life event - finding', 25,
                                'product', 26,
                                'substance', 27,
                                'assessment scale', 28,
                                'tumor staging', 29,
                                'staging scale', 30,
                                'specimen', 31,
                                'special concept', 32,
                                'observable entity', 33,
                                'namespace concept', 34,
                                'morphologic abnormality', 35,
                                'foundation metadata concept', 36,
                                'core metadata concept', 37,
                                'metadata', 38,
                                'environment', 39,
                                'geographic location', 40,
                                'situation', 41,
                                'situation', 42,
                                'context-dependent category', 43,
                                'biological function', 44,
                                'attribute', 45,
                                'administrative concept', 46,
                                'record artifact', 47,
                                'navigational concept', 48,
                                'inactive concept', 49,
                                'linkage concept', 50,
                                'link assertion', 51,
                                'environment / location', 52,
                                99),
                        rnb)
                     AS rnc
             FROM (SELECT concept_code,
                          active,
                          pc1,
                          pc2,
                          CASE
                             WHEN pc1 = 0 OR pc2 = 0
                             THEN
                                term  -- when no term records with parentheses
                             -- extract class (called f7)
                             ELSE
                                SUBSTR (
                                   term,
                                   REGEXP_INSTR (term, '\(', 1, REGEXP_COUNT (term, '\(')) + 1,
                                   REGEXP_INSTR (term, '\)', 1, REGEXP_COUNT (term, '\)')) - REGEXP_INSTR (term, '\(', 1, REGEXP_COUNT (term, '\(')) - 1
                                )
                          END
                             AS f7,
                          rna AS rnb    -- row number in sct2_desc_full_merged
                     FROM (SELECT c.concept_code,
                                  d.term,
                                  d.active,
                                  REGEXP_COUNT (d.term, '\(') pc1, -- parenthesis open count
                                  REGEXP_COUNT (d.term, '\)') pc2, -- parenthesis close count
                                  ROW_NUMBER ()
                                  OVER (
                                     PARTITION BY c.concept_code
                                     ORDER BY
                                        d.active DESC,    -- first active ones
                                        REGEXP_COUNT (d.term, '\(') DESC -- first the ones with the most parentheses - one of them the class info
                                                                        )
                                     rna -- row number in sct2_desc_full_merged
                             FROM concept_stage c
                             JOIN sct2_desc_full_merged d ON d.conceptid = c.concept_code
									 where c.vocabulary_id='SNOMED')))
    WHERE rnc = 1;	
	
CREATE INDEX x_cc_2cd ON tmp_concept_class (concept_code);

-- 6. Create reduced set of classes 
UPDATE concept_stage cs
   SET concept_class_id =
          (SELECT CASE
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
                 ELSE 'Undefined'
                 END
             FROM tmp_concept_class cc
            WHERE cc.concept_code = cs.concept_code)
	WHERE cs.vocabulary_id='SNOMED'
	AND cs.concept_code IN (SELECT concept_code FROM tmp_concept_class);

-- Clean up
DROP TABLE tmp_concept_class PURGE;

-- Assign top SNOMED concept
UPDATE concept_stage set concept_class_id='Model Comp' WHERE concept_code=138875005 and vocabulary_id='SNOMED';

--7 Add DM+D into concept_synonym_stage
INSERT /*+ APPEND */
      INTO  concept_synonym_stage (synonym_concept_code,
                                   synonym_vocabulary_id,
                                   synonym_name,
                                   language_concept_id)
   SELECT DISTINCT synonym_concept_code,
                   synonym_vocabulary_id,
                   synonym_name,
                   language_concept_id
     FROM (SELECT EXTRACTVALUE (VALUE (t), 'ING/ISID')
                     AS synonym_concept_code,
                  'SNOMED' AS synonym_vocabulary_id,
                  EXTRACTVALUE (VALUE (t), 'ING/NM') AS synonym_name,
                  4180186 AS language_concept_id                    -- English
             FROM f_ingredient2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT ('INGREDIENT_SUBSTANCES/ING'))) t
           UNION ALL
           SELECT EXTRACTVALUE (VALUE (t), 'VTM/VTMID')
                     AS synonym_concept_code,
                  'SNOMED' AS synonym_vocabulary_id,
                  EXTRACTVALUE (VALUE (t), 'VTM/NM') AS synonym_name,
                  4180186 AS language_concept_id                    -- English
             FROM f_vtm2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_THERAPEUTIC_MOIETIES/VTM'))) t
           UNION ALL
           SELECT EXTRACTVALUE (VALUE (t), 'VTM/VTMID')
                     AS synonym_concept_code,
                  'SNOMED' AS synonym_vocabulary_id,
                  EXTRACTVALUE (VALUE (t), 'VTM/ABBREVNM') AS synonym_name,
                  4180186 AS language_concept_id                    -- English
             FROM f_vtm2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_THERAPEUTIC_MOIETIES/VTM'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'VTM/ABBREVNM') IS NOT NULL
           UNION ALL
           SELECT EXTRACTVALUE (VALUE (t), 'VMP/VPID')
                     AS synonym_concept_code,
                  'SNOMED' AS synonym_vocabulary_id,
                  EXTRACTVALUE (VALUE (t), 'VMP/NM') AS synonym_name,
                  4180186 AS language_concept_id                    -- English
             FROM f_vmp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_MED_PRODUCTS/VMPS/VMP'))) t
           UNION ALL
           SELECT EXTRACTVALUE (VALUE (t), 'VMP/VPID')
                     AS synonym_concept_code,
                  'SNOMED' AS synonym_vocabulary_id,
                  EXTRACTVALUE (VALUE (t), 'VMP/ABBREVNM') AS synonym_name,
                  4180186 AS language_concept_id                    -- English
             FROM f_vmp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_MED_PRODUCTS/VMPS/VMP'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'VMP/ABBREVNM') IS NOT NULL
           UNION ALL
           SELECT EXTRACTVALUE (VALUE (t), 'VMP/VPID')
                     AS synonym_concept_code,
                  'SNOMED' AS synonym_vocabulary_id,
                  EXTRACTVALUE (VALUE (t), 'VMP/NMPREV') AS synonym_name,
                  4180186 AS language_concept_id                    -- English
             FROM f_vmp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_MED_PRODUCTS/VMPS/VMP'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'VMP/NMPREV') IS NOT NULL
           UNION ALL
           SELECT EXTRACTVALUE (VALUE (t), 'AMP/APID')
                     AS synonym_concept_code,
                  'SNOMED' AS synonym_vocabulary_id,
                  EXTRACTVALUE (VALUE (t), 'AMP/DESC') AS synonym_name,
                  4180186 AS language_concept_id                    -- English
             FROM f_amp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'ACTUAL_MEDICINAL_PRODUCTS/AMPS/AMP'))) t
           UNION ALL
           SELECT EXTRACTVALUE (VALUE (t), 'AMP/APID')
                     AS synonym_concept_code,
                  'SNOMED' AS synonym_vocabulary_id,
                  EXTRACTVALUE (VALUE (t), 'AMP/ABBREVNM') AS synonym_name,
                  4180186 AS language_concept_id                    -- English
             FROM f_amp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'ACTUAL_MEDICINAL_PRODUCTS/AMPS/AMP'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'AMP/ABBREVNM') IS NOT NULL
           UNION ALL
           SELECT EXTRACTVALUE (VALUE (t), 'AMP/APID')
                     AS synonym_concept_code,
                  'SNOMED' AS synonym_vocabulary_id,
                  EXTRACTVALUE (VALUE (t), 'AMP/NMPREV') AS synonym_name,
                  4180186 AS language_concept_id                    -- English
             FROM f_amp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'ACTUAL_MEDICINAL_PRODUCTS/AMPS/AMP'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'AMP/NMPREV') IS NOT NULL
           UNION ALL
           SELECT EXTRACTVALUE (VALUE (t), 'VMPP/VPPID')
                     AS synonym_concept_code,
                  'SNOMED' AS synonym_vocabulary_id,
                  EXTRACTVALUE (VALUE (t), 'VMPP/NM') AS synonym_name,
                  4180186 AS language_concept_id                    -- English
             FROM f_vmpp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_MED_PRODUCT_PACK/VMPPS/VMPP'))) t
           UNION ALL
           SELECT EXTRACTVALUE (VALUE (t), 'AMPP/APPID')
                     AS synonym_concept_code,
                  'SNOMED' AS synonym_vocabulary_id,
                  EXTRACTVALUE (VALUE (t), 'AMPP/NM') AS synonym_name,
                  4180186 AS language_concept_id                    -- English
             FROM f_ampp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'ACTUAL_MEDICINAL_PROD_PACKS/AMPPS/AMPP'))) t
           UNION ALL
           SELECT EXTRACTVALUE (VALUE (t), 'AMPP/APPID')
                     AS synonym_concept_code,
                  'SNOMED' AS synonym_vocabulary_id,
                  EXTRACTVALUE (VALUE (t), 'AMPP/ABBREVNM') AS synonym_name,
                  4180186 AS language_concept_id                    -- English
             FROM f_ampp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'ACTUAL_MEDICINAL_PROD_PACKS/AMPPS/AMPP'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'AMPP/ABBREVNM') IS NOT NULL);
COMMIT;			
			
-- 8. Get all the other ones in ('PT', 'PTGB', 'SY', 'SYGB', 'MTH_PT', 'FN', 'MTH_SY', 'SB') into concept_synonym_stage
INSERT  /*+ APPEND */  INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_vocabulary_id,
                                   synonym_name,
                                   language_concept_id)
   SELECT DISTINCT 
          NULL,
          m.code,
          'SNOMED',
          SUBSTR (m.str, 1, 1000),
          4180186 -- English
     FROM UMLS.mrconso m
    WHERE m.sab = 'SNOMEDCT_US' AND m.tty in ('PT', 'PTGB', 'SY', 'SYGB', 'MTH_PT', 'FN', 'MTH_SY', 'SB')
	AND NOT EXISTS (
		SELECT 1 FROM concept_synonym_stage css_int WHERE css_int.synonym_concept_code=m.code AND css_int.synonym_name=SUBSTR (m.str, 1, 1000)
	)
;
COMMIT;

-- 9. Fill concept_relationship_stage from DM+D
INSERT /*+ APPEND */
      INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT concept_code_1,
                   concept_code_2,
                   vocabulary_id_1,
                   vocabulary_id_2,
                   relationship_id,
                   valid_start_date,
                   valid_end_date,
                   invalid_reason
     FROM (--Upgrade links for UoM
           SELECT EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'INFO/CD') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Concept replaced by' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_lookup2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'LOOKUP/UNIT_OF_MEASURE/INFO'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') IS NOT NULL
           UNION ALL
           --Upgrade links for Forms
           SELECT EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'INFO/CD') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Concept replaced by' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_lookup2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT ('LOOKUP/FORM/INFO'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') IS NOT NULL
           UNION ALL
           --Upgrade links for Route
           SELECT EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'INFO/CD') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Concept replaced by' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_lookup2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT ('LOOKUP/ROUTE/INFO'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') IS NOT NULL
           /*Leave out because we don't know the proper concept class
		   UNION ALL
			-- add upgrade links for Suppliers 
           SELECT EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'INFO/CD') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Concept replaced by' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_lookup2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT ('LOOKUP/SUPPLIER/INFO'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') IS NOT NULL
			*/
			UNION ALL		   
           --upgrade links for iss
           SELECT EXTRACTVALUE (VALUE (t), 'ING/ISIDPREV') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'ING/ISID') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Concept replaced by' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_ingredient2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT ('INGREDIENT_SUBSTANCES/ING'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'ING/ISIDPREV') IS NOT NULL
           UNION ALL
           --upgrade links for VTMs
           SELECT EXTRACTVALUE (VALUE (t), 'VTM/VTMIDPREV') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'VTM/VTMID') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Concept replaced by' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_vtm2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_THERAPEUTIC_MOIETIES/VTM'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'VTM/VTMIDPREV') IS NOT NULL
           UNION ALL
           --upgrade links for VMPs
           SELECT EXTRACTVALUE (VALUE (t), 'VMP/VPIDPREV') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'VMP/VPID') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Concept replaced by' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_vmp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_MED_PRODUCTS/VMPS/VMP'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'VMP/VPIDPREV') IS NOT NULL
           UNION ALL
           --add Unit dose form units for VMP
           --linking VMPs to the unit of the form, for example "Sodium chloride 3% infusion 100ml bags" to "ml"
           SELECT EXTRACTVALUE (VALUE (t), 'VMP/VPID') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'VMP/UDFS_UOMCD')
                     AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Has dose form unit' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_vmp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_MED_PRODUCTS/VMPS/VMP'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'VMP/UDFS_UOMCD') IS NOT NULL
           UNION ALL
           -- add Unit dose unit of measure for VMP
           -- linking VMPs to the unit of the form, for example "Sodium chloride 3% infusion 100ml bags" to "bag"
           SELECT EXTRACTVALUE (VALUE (t), 'VMP/VPID') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'VMP/UNIT_DOSE_UOMCD')
                     AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Has unit of prod use' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_vmp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_MED_PRODUCTS/VMPS/VMP'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'VMP/UNIT_DOSE_UOMCD') IS NOT NULL
           UNION ALL
           -- link VMPs to VTMs
           SELECT EXTRACTVALUE (VALUE (t), 'VMP/VPID') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'VMP/VTMID') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Is a' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_vmp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_MED_PRODUCTS/VMPS/VMP'))) t
           UNION ALL
           -- link VMPs to Ingredients
           SELECT EXTRACTVALUE (VALUE (t), 'VPI/VPID') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'VPI/ISID') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Has spec active ing' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_vmp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_MED_PRODUCTS/VIRTUAL_PRODUCT_INGREDIENT/VPI'))) t
           UNION ALL
           -- link VMPs to Basis Ingredients (Atorvastatin instead of Atorvastatin calcium trihydrate)
           SELECT EXTRACTVALUE (VALUE (t), 'VPI/VPID') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'VPI/BS_SUBID') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Has basis str subst' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_vmp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_MED_PRODUCTS/VIRTUAL_PRODUCT_INGREDIENT/VPI'))) t
            WHERE EXTRACTVALUE (VALUE (t), 'VPI/BS_SUBID') IS NOT NULL
           UNION ALL
           -- link VMPs to their drug forms
           SELECT EXTRACTVALUE (VALUE (t), 'DFORM/VPID') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'DFORM/FORMCD') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Has disp dose form' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_vmp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_MED_PRODUCTS/DRUG_FORM/DFORM'))) t
           UNION ALL
           -- link VMPs to their routes
           SELECT EXTRACTVALUE (VALUE (t), 'DROUTE/VPID') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'DROUTE/ROUTECD')
                     AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Has route' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_vmp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_MED_PRODUCTS/DRUG_ROUTE/DROUTE'))) t
           UNION ALL
           -- link AMPs to VMPs
           SELECT EXTRACTVALUE (VALUE (t), 'AMP/APID') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'AMP/VPID') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Is a' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_amp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'ACTUAL_MEDICINAL_PRODUCTS/AMPS/AMP'))) t
           UNION ALL
           -- inherit 'Has specific active ingredient' relationship from VMP
           SELECT a.APID AS concept_code_1,
                  b.ISID AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Has spec active ing' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM (SELECT EXTRACTVALUE (VALUE (t), 'AMP/APID') AS APID,
                          EXTRACTVALUE (VALUE (t), 'AMP/VPID') AS VPID,
                          ROWNUM rn
                     FROM f_amp2 t_xml,
                          TABLE (
                             XMLSEQUENCE (
                                t_xml.xmlfield.EXTRACT (
                                   'ACTUAL_MEDICINAL_PRODUCTS/AMPS/AMP'))) t)
                  a,
                  (SELECT EXTRACTVALUE (VALUE (t), 'VPI/ISID') AS ISID,
                          EXTRACTVALUE (VALUE (t), 'VPI/VPID') AS VPID,
                          ROWNUM rn
                     FROM f_vmp2 t_xml,
                          TABLE (
                             XMLSEQUENCE (
                                t_xml.xmlfield.EXTRACT (
                                   'VIRTUAL_MED_PRODUCTS/VIRTUAL_PRODUCT_INGREDIENT/VPI'))) t)
                  b
            WHERE a.VPID = b.VPID
           UNION ALL
           -- Inherit Basis Ingredients relationships from VMP
           SELECT a.APID AS concept_code_1,
                  b.BS_SUBID AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Has basis str subst' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM (SELECT EXTRACTVALUE (VALUE (t), 'AMP/APID') AS APID,
                          EXTRACTVALUE (VALUE (t), 'AMP/VPID') AS VPID,
                          ROWNUM rn
                     FROM f_amp2 t_xml,
                          TABLE (
                             XMLSEQUENCE (
                                t_xml.xmlfield.EXTRACT (
                                   'ACTUAL_MEDICINAL_PRODUCTS/AMPS/AMP'))) t)
                  a,
                  (SELECT EXTRACTVALUE (VALUE (t), 'VPI/BS_SUBID')
                             AS BS_SUBID,
                          EXTRACTVALUE (VALUE (t), 'VPI/VPID') AS VPID,
                          ROWNUM rn
                     FROM f_vmp2 t_xml,
                          TABLE (
                             XMLSEQUENCE (
                                t_xml.xmlfield.EXTRACT (
                                   'VIRTUAL_MED_PRODUCTS/VIRTUAL_PRODUCT_INGREDIENT/VPI'))) t)
                  b
            WHERE a.VPID = b.VPID AND b.BS_SUBID IS NOT NULL
           UNION ALL
           -- Inherit link drug forms from VMP
           SELECT a.APID AS concept_code_1,
                  b.FORMCD AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Has disp dose form' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM (SELECT EXTRACTVALUE (VALUE (t), 'AMP/APID') AS APID,
                          EXTRACTVALUE (VALUE (t), 'AMP/VPID') AS VPID,
                          ROWNUM rn
                     FROM f_amp2 t_xml,
                          TABLE (
                             XMLSEQUENCE (
                                t_xml.xmlfield.EXTRACT (
                                   'ACTUAL_MEDICINAL_PRODUCTS/AMPS/AMP'))) t)
                  a,
                  (SELECT EXTRACTVALUE (VALUE (t), 'DFORM/FORMCD') AS FORMCD,
                          EXTRACTVALUE (VALUE (t), 'DFORM/VPID') AS VPID,
                          ROWNUM rn
                     FROM f_vmp2 t_xml,
                          TABLE (
                             XMLSEQUENCE (
                                t_xml.xmlfield.EXTRACT (
                                   'VIRTUAL_MED_PRODUCTS/DRUG_FORM/DFORM'))) t)
                  b
            WHERE a.VPID = b.VPID
           UNION ALL
           -- link AMPs to Incipients
           SELECT EXTRACTVALUE (VALUE (t), 'AP_ING/APID') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'AP_ING/ISID') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Has excipient' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_amp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'ACTUAL_MEDICINAL_PRODUCTS/AP_INGREDIENT/AP_ING'))) t
           UNION ALL
           -- link AMPs to their licensed routes
           SELECT EXTRACTVALUE (VALUE (t), 'LIC_ROUTE/APID')
                     AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'LIC_ROUTE/ROUTECD')
                     AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Has licensed route' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_amp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'ACTUAL_MEDICINAL_PRODUCTS/LICENSED_ROUTE/LIC_ROUTE'))) t
           UNION ALL
           --link VMPPs to their contained VMPs
           SELECT EXTRACTVALUE (VALUE (t), 'VMPP/VPPID') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'VMPP/VPID') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Has VMP' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_vmpp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_MED_PRODUCT_PACK/VMPPS/VMPP'))) t
           UNION ALL
           --link VMPPs containing VMPPs
           SELECT EXTRACTVALUE (VALUE (t), 'CCONTENT/PRNTVPPID')
                     AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'CCONTENT/CHLDVPPID')
                     AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Is a' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_vmpp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'VIRTUAL_MED_PRODUCT_PACK/COMB_CONTENT/CCONTENT'))) t
           UNION ALL
           --link AMPPs to their equivalent VMPPs
           SELECT EXTRACTVALUE (VALUE (t), 'AMPP/APPID') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'AMPP/VPPID') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Is a' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_ampp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'ACTUAL_MEDICINAL_PROD_PACKS/AMPPS/AMPP'))) t
           UNION ALL
           -- link AMPPs to their contained AMPs
           SELECT EXTRACTVALUE (VALUE (t), 'AMPP/APPID') AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'AMPP/APID') AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Has AMP' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_ampp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'ACTUAL_MEDICINAL_PROD_PACKS/AMPPS/AMPP'))) t
           UNION ALL
           --link AMPPs to containing AMPPs
           SELECT EXTRACTVALUE (VALUE (t), 'CCONTENT/PRNTVPPID')
                     AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'CCONTENT/CHLDVPPID')
                     AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'SNOMED' AS vocabulary_id_2,
                  'Is a' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM f_ampp2 t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'ACTUAL_MEDICINAL_PROD_PACKS/COMB_CONTENT/CCONTENT'))) t
            WHERE     EXTRACTVALUE (VALUE (t), 'CCONTENT/PRNTVPPID')
                         IS NOT NULL
                  AND EXTRACTVALUE (VALUE (t), 'CCONTENT/CHLDVPPID')
                         IS NOT NULL
           UNION ALL
		   --Add SNOMED to ATC relationships
           SELECT EXTRACTVALUE (VALUE (t), 'VMP/VPID')
                     AS concept_code_1,
                  EXTRACTVALUE (VALUE (t), 'VMP/ATC')
                     AS concept_code_2,
                  'SNOMED' AS vocabulary_id_1,
                  'ATC' AS vocabulary_id_2,
                  'SNOMED - ATC eq' AS relationship_id,
                  (SELECT latest_update
                     FROM vocabulary
                    WHERE vocabulary_id = 'SNOMED')
                     AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason
             FROM dmdbonus t_xml,
                  TABLE (
                     XMLSEQUENCE (
                        t_xml.xmlfield.EXTRACT (
                           'BNF_DETAILS/VMPS/VMP'))) t
            WHERE     EXTRACTVALUE (VALUE (t), 'VMP/ATC')
                         IS NOT NULL);
COMMIT;						 

-- 10. Fill concept_relationship_stage from SNOMED	
CREATE TABLE tmp_rel
NOLOGGING
AS
   (                  -- get relationships from latest records that are active
    SELECT DISTINCT
           sourceid, destinationid, REPLACE (term, ' (attribute)', '') term
      FROM (SELECT r.sourceid,
                   r.destinationid,
                   d.term,
                   ROW_NUMBER ()
                   OVER (PARTITION BY r.id
                         ORDER BY TO_DATE (r.effectivetime, 'YYYYMMDD') DESC)
                      AS rn, -- get the latest in a sequence of relationships, to decide wether it is still active
                   r.active
              FROM sct2_rela_full_merged r
                   JOIN sct2_desc_full_merged d ON r.typeid = d.conceptid)
     WHERE     rn = 1
           AND active = 1
           AND sourceid IS NOT NULL
           AND destinationid IS NOT NULL
           AND term <> 'PBCL flag true');

INSERT  /*+ APPEND */  INTO concept_relationship_stage (
										concept_code_1,
                                        concept_code_2,
								        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
SELECT 
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM (
	 --convert SNOMED to OMOP-type relationship_id   
	 SELECT DISTINCT
			sourceid as concept_code_1,
			destinationid as concept_code_2,
			'SNOMED' as vocabulary_id_1,
			'SNOMED' as vocabulary_id_2,
			CASE
				WHEN term = 'Access' THEN 'Has access'
				WHEN term = 'Associated aetiologic finding' THEN 'Has etiology'
				WHEN term = 'After' THEN 'Occurs after'
				WHEN term = 'Approach' THEN 'Has surgical appr' -- looks like old version
				WHEN term = 'Associated finding' THEN 'Has asso finding'
				WHEN term = 'Associated morphology' THEN 'Has asso morph'
				WHEN term = 'Associated procedure' THEN 'Has asso proc'
				WHEN term = 'Associated with' THEN 'Finding asso with'
				WHEN term = 'AW' THEN 'Finding asso with'
				WHEN term = 'Causative agent' THEN 'Has causative agent'
				WHEN term = 'Clinical course' THEN 'Has clinical course'  
				WHEN term = 'Component' THEN 'Has component'
				WHEN term = 'Direct device' THEN 'Has dir device'
				WHEN term = 'Direct morphology' THEN 'Has dir morph'
				WHEN term = 'Direct substance' THEN 'Has dir subst'
				WHEN term = 'Due to' THEN 'Has due to'
				WHEN term = 'Episodicity' THEN 'Has episodicity'
				WHEN term = 'Extent' THEN 'Has extent'
				WHEN term = 'Finding context' THEN 'Has finding context'
				WHEN term = 'Finding informer' THEN 'Using finding inform'   
				WHEN term = 'Finding method' THEN 'Using finding method'    
				WHEN term = 'Finding site' THEN 'Has finding site'
				WHEN term = 'Has active ingredient' THEN 'Has active ing'
				WHEN term = 'Has definitional manifestation' THEN 'Has manifestation'
				WHEN term = 'Has dose form' THEN 'Has dose form'
				WHEN term = 'Has focus' THEN 'Has focus'
				WHEN term = 'Has interpretation' THEN 'Has interpretation'
				WHEN term = 'Has measured component' THEN 'Has meas component'
				WHEN term = 'Has specimen' THEN 'Has specimen'
				WHEN term = 'Stage' THEN 'Has stage'
				WHEN term = 'Indirect device' THEN 'Has indir device'
				WHEN term = 'Indirect morphology' THEN 'Has indir morph'
				WHEN term = 'Instrumentation' THEN 'Using device' -- looks like an old version
				WHEN term IN ('Intent', 'Has intent') THEN 'Has intent'
				WHEN term = 'Interprets' THEN 'Has interprets'
				WHEN term = 'Is a' THEN 'Is a'
				WHEN term = 'Laterality' THEN 'Has laterality'
				WHEN term = 'Measurement method' THEN 'Has measurement'
				WHEN term = 'Measurement Method' THEN 'Has measurement' -- looks like misspelling
				WHEN term = 'Method' THEN 'Has method'
				WHEN term = 'Morphology' THEN 'Has morphology'
				WHEN term = 'Occurrence' THEN 'Has occurrence'
				WHEN term = 'Onset' THEN 'Has clinical course' -- looks like old version
				WHEN term = 'Part of' THEN 'Has part of'
				WHEN term = 'Pathological process' THEN 'Has pathology'
				WHEN term = 'Pathological process (qualifier value)' THEN 'Has pathology'
				WHEN term = 'Priority' THEN 'Has priority'
				WHEN term = 'Procedure context' THEN 'Has proc context'
				WHEN term = 'Procedure device' THEN 'Has proc device'
				WHEN term = 'Procedure morphology' THEN 'Has proc morph'
				WHEN term = 'Procedure site - Direct' THEN 'Has dir proc site'
				WHEN term = 'Procedure site - Indirect' THEN 'Has indir proc site'
				WHEN term = 'Procedure site' THEN 'Has proc site'
				WHEN term = 'Property' THEN 'Has property'
				WHEN term = 'Recipient category' THEN 'Has recipient cat'
				WHEN term = 'Revision status' THEN 'Has revision status'
				WHEN term = 'Route of administration' THEN 'Has route of admin'
				WHEN term = 'Route of administration - attribute' THEN 'Has route of admin'
				WHEN term = 'Scale type' THEN 'Has scale type'
				WHEN term = 'Severity' THEN 'Has severity'
				WHEN term = 'Specimen procedure' THEN 'Has specimen proc'
				WHEN term = 'Specimen source identity' THEN 'Has specimen source'
				WHEN term = 'Specimen source morphology' THEN 'Has specimen morph'
				WHEN term = 'Specimen source topography' THEN 'Has specimen topo'
				WHEN term = 'Specimen substance' THEN 'Has specimen subst'
				WHEN term = 'Subject relationship context' THEN 'Has relat context'
				WHEN term = 'Surgical approach' THEN 'Has surgical appr'  
				WHEN term = 'Temporal context' THEN 'Has temporal context'   
				WHEN term = 'Temporally follows' THEN 'Occurs after' -- looks like an old version
				WHEN term = 'Time aspect' THEN 'Has time aspect'
				WHEN term = 'Using access device' THEN 'Using acc device'  
				WHEN term = 'Using device' THEN 'Using device'   
				WHEN term = 'Using energy' THEN 'Using energy'   
				WHEN term = 'Using substance' THEN 'Using subst'
				WHEN term = 'Following' THEN 'Followed by'
				WHEN term = 'VMP non-availability indicator' THEN 'Has non-avail ind'
				WHEN term = 'Has ARP' THEN 'Has ARP'
				WHEN term = 'Has VRP' THEN 'Has VRP'
				WHEN term = 'Has trade family group' THEN 'Has trade family grp'
				WHEN term = 'Flavour' THEN 'Has flavor'
				WHEN term = 'Discontinued indicator' THEN 'Has disc indicator'
				WHEN term = 'VRP prescribing status' THEN 'VRP has prescr stat'
				WHEN term = 'Has specific active ingredient' THEN 'Has spec active ing'
				WHEN term = 'Has excipient' THEN 'Has excipient'
				WHEN term = 'Has basis of strength substance' THEN 'Has basis str subst'
				WHEN term = 'Has VMP' THEN 'Has VMP'
				WHEN term = 'Has AMP' THEN 'Has AMP'
				WHEN term = 'Has dispensed dose form' THEN 'Has disp dose form'
				WHEN term = 'VMP prescribing status' THEN 'VMP has prescr stat'
				WHEN term = 'Legal category' THEN 'Has legal category'
				WHEN term = 'Caused by' THEN 'Caused by'
				ELSE 'non-existing'      
			END AS relationship_id,
			(select latest_update From vocabulary where vocabulary_id='SNOMED') as valid_start_date,
			TO_DATE ('31.12.2099', 'dd.mm.yyyy') as valid_end_date,
			NULL as invalid_reason
	   FROM (SELECT * FROM tmp_rel)
) sn WHERE NOT EXISTS (
	SELECT 1 FROM concept_relationship_stage crs WHERE crs.concept_code_1=sn.concept_code_1
	AND crs.concept_code_2=sn.concept_code_2
	AND crs.relationship_id=sn.relationship_id
);
COMMIT;

-- 11. add replacement relationships. They are handled in a different SNOMED table
INSERT  /*+ APPEND */ INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                    		vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT
          sn.concept_code_1,
          sn.concept_code_2,
          'SNOMED',
          'SNOMED',
          sn.relationship_id,
          (select latest_update From vocabulary where vocabulary_id='SNOMED'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM (SELECT to_char(referencedcomponentid) AS concept_code_1,
                  to_char(targetcomponent) AS concept_code_2,
                  CASE refsetid
                     WHEN 900000000000526001 THEN 'Concept replaced by'
                     WHEN 900000000000523009 THEN 'Concept poss_eq to'
                     WHEN 900000000000528000 THEN 'Concept was_a to'
                     WHEN 900000000000527005 THEN 'Concept same_as to'
                     WHEN 900000000000530003 THEN 'Concept alt_to to'
                  END
                     AS relationship_id,
                  ROW_NUMBER ()
                  OVER (PARTITION BY referencedcomponentid
                        ORDER BY TO_DATE (effectivetime, 'YYYYMMDD') DESC)
                     rn,
                  active
             FROM der2_crefset_assreffull_merged sc
            WHERE refsetid IN (900000000000526001,
                               900000000000523009,
                               900000000000528000,
                               900000000000527005,
                               900000000000530003)
	) sn
    WHERE sn.rn = 1 AND sn.active = 1
	AND NOT EXISTS (
		SELECT 1 FROM concept_relationship_stage crs WHERE crs.concept_code_1=sn.concept_code_1
		AND crs.concept_code_2=sn.concept_code_2
		AND crs.relationship_id=sn.relationship_id	
	);
COMMIT;

--12 Working with replacement mappings
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_stage', estimate_percent  => null, cascade  => true);
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_relationship_stage', estimate_percent  => null, cascade  => true);

BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
COMMIT;

--13 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;	

--14 Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;		 

--15 Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

-- 16 start building the hierarchy for progagating domain_ids from toop to bottom
DECLARE
   vCnt          INTEGER;
   vCnt_old      INTEGER;
   vSumMax       INTEGER;
   vSumMax_old   INTEGER;
   vSumMin       INTEGER;
   vIsOverLoop   BOOLEAN;

   FUNCTION IsSameTableData (pTable1 IN VARCHAR2, pTable2 IN VARCHAR2)
      RETURN BOOLEAN
   IS
      vRefCursor   SYS_REFCURSOR;
      vDummy       CHAR (1);

      res          BOOLEAN;
   BEGIN
      OPEN vRefCursor FOR
            'select null as col1 from ( select * from '
         || pTable1
         || ' minus select * from '
         || pTable2
         || ' )';

      FETCH vRefCursor INTO vDummy;

      res := vRefCursor%NOTFOUND;

      CLOSE vRefCursor;

      RETURN res;
   END;
BEGIN
   -- Clean up before
   BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE snomed_ancestor_calc PURGE';
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END;

   BEGIN
      EXECUTE IMMEDIATE 'drop table snomed_ancestor_calc_bkp purge';
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END;

   BEGIN
      EXECUTE IMMEDIATE 'drop table new_snomed_ancestor_calc purge';
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END;

   -- Seed the table by loading all first-level (parent-child) relationships

   EXECUTE IMMEDIATE
      'create table snomed_ancestor_calc NOLOGGING as
    select 
      concept_code_2 as ancestor_concept_code,
      concept_code_1 as descendant_concept_code,
      1 as min_levels_of_separation,
      1 as max_levels_of_separation
    from concept_relationship_stage 
    where relationship_id = ''Is a'' -- usually subsumes is used for ancestry construction, but it has not been created from Is a
    and vocabulary_id_1 = ''SNOMED''';

   /********** Repeat till no new records are written *********/
   FOR i IN 1 .. 100
   LOOP
      -- create all new combinations

      EXECUTE IMMEDIATE
         'create table new_snomed_ancestor_calc NOLOGGING as
        select 
            uppr.ancestor_concept_code,
            lowr.descendant_concept_code,
            uppr.min_levels_of_separation+lowr.min_levels_of_separation as min_levels_of_separation,
            uppr.min_levels_of_separation+lowr.min_levels_of_separation as max_levels_of_separation    
        from snomed_ancestor_calc uppr 
        join snomed_ancestor_calc lowr on uppr.descendant_concept_code=lowr.ancestor_concept_code
        union all select * from snomed_ancestor_calc';

      vCnt := SQL%ROWCOUNT;

      EXECUTE IMMEDIATE 'drop table snomed_ancestor_calc purge';

      -- Shrink and pick the shortest path for min_levels_of_separation, and the longest for max

      EXECUTE IMMEDIATE
         'create table snomed_ancestor_calc NOLOGGING as
        select 
            ancestor_concept_code,
            descendant_concept_code,
            min(min_levels_of_separation) as min_levels_of_separation,
            max(max_levels_of_separation) as max_levels_of_separation
        from new_snomed_ancestor_calc
        group by ancestor_concept_code, descendant_concept_code ';

      EXECUTE IMMEDIATE
         'select count(*), sum(max_levels_of_separation), sum(min_levels_of_separation) from snomed_ancestor_calc'
         INTO vCnt, vSumMax, vSumMin;

      EXECUTE IMMEDIATE 'drop table new_snomed_ancestor_calc purge';

      IF vIsOverLoop
      THEN
         IF vCnt = vCnt_old AND vSumMax = vSumMax_old
         THEN
            IF IsSameTableData (pTable1   => 'snomed_ancestor_calc',
                                pTable2   => 'snomed_ancestor_calc_bkp')
            THEN
               EXIT;
            ELSE
               RETURN;
            END IF;
         ELSE
            RETURN;
         END IF;
      ELSIF vCnt = vCnt_old
      THEN
         EXECUTE IMMEDIATE
            'create table snomed_ancestor_calc_bkp NOLOGGING as select * from snomed_ancestor_calc ';

         vIsOverLoop := TRUE;
      END IF;

      vCnt_old := vCnt;
      vSumMax_old := vSumMax;
   END LOOP;     /********** Repeat till no new records are written *********/

   EXECUTE IMMEDIATE 'truncate table snomed_ancestor';

   -- drop snomed_ancestor indexes before mass insert.
   EXECUTE IMMEDIATE
      'alter table snomed_ancestor disable constraint XPKSNOMED_ANCESTOR';
	  
   EXECUTE IMMEDIATE
    'insert /*+ APPEND */ into snomed_ancestor
    select a.* from snomed_ancestor_calc a
    join concept_stage c1 on a.ancestor_concept_code=c1.concept_code and c1.vocabulary_id=''SNOMED''
    join concept_stage c2 on a.descendant_concept_code=c2.concept_code and c2.vocabulary_id=''SNOMED''
    ';

   COMMIT;

   EXECUTE IMMEDIATE
      'alter table snomed_ancestor enable constraint XPKSNOMED_ANCESTOR';

   -- Clean up
   EXECUTE IMMEDIATE 'drop table snomed_ancestor_calc purge';

   EXECUTE IMMEDIATE 'drop table snomed_ancestor_calc_bkp purge';
   
   DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'snomed_ancestor', estimate_percent  => null, cascade  => true);
END;

--17. Create domain_id
-- 17.1. Manually create table with "Peaks" = ancestors of records that are all of the same domain
CREATE TABLE peak (
	peak_code VARCHAR(20), --the id of the top ancestor
	peak_domain_id VARCHAR(20), -- the domain to assign to all its children
	ranked INTEGER -- number for the order in which to assign
);

-- 17.2 Fill in the various peak concepts
BEGIN
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (138875005, 'Metadata'); -- root
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (900000000000441003, 'Metadata'); -- SNOMED CT Model Component
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (105590001, 'Observation'); -- Substances
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (123038009, 'Specimen'); -- Specimen
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (48176007, 'Observation'); -- Social context
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (243796009, 'Observation'); -- Situation with explicit context
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (272379006, 'Observation'); -- Events
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (260787004, 'Observation'); -- Physical object
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (362981000, 'Observation'); -- Qualifier value
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (363787002, 'Observation'); -- Observable entity
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (410607006, 'Observation'); -- Organism
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (419891008, 'Type Concept'); -- Record artifact
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (78621006, 'Observation'); -- Physical force
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (123037004, 'Spec Anatomic Site'); -- Body structure
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (118956008, 'Observation'); -- Body structure, altered from its original anatomical structure, reverted from 123037004
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (254291000, 'Observation'); -- Staging / Scales
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (370115009, 'Metadata'); -- Special Concept
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (308916002, 'Observation'); -- Environment or geographical location
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (223366009, 'Provider Specialty');
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (43741000, 'Place of Service'); -- Site of care
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (420056007, 'Drug'); -- Aromatherapy agent
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (373873005, 'Drug'); -- Pharmaceutical / biologic product
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (410942007, 'Drug'); -- Drug or medicament
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (385285004, 'Drug'); -- dialysis dosage form
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (421967003, 'Drug'); -- drug dose form
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (424387007, 'Drug'); -- dose form by site prepared for 
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (421563008, 'Drug'); -- complementary medicine dose form
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (284009009, 'Drug');  -- Route of administration value
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (373783004, 'Observation'); -- dietary product, exception of Pharmaceutical / biologic product
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (419572002, 'Observation'); -- alcohol agent, exception of drug
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (373782009, 'Observation'); -- diagnostic substance, exception of drug
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (2949005, 'Observation'); -- diagnostic aid (exclusion from drugs)
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (404684003, 'Condition'); -- Clinical Finding
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (218496004, 'Condition'); -- Adverse reaction to primarily systemic agents
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (313413008, 'Condition'); -- Calculus observation
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (405533003, 'Observation'); -- Adverse incident outcome categories
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (365854008, 'Observation'); -- History finding
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (118233009, 'Observation'); -- Finding of activity of daily living
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (307824009, 'Observation');-- Administrative statuses
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (162408000, 'Observation'); -- Symptom description
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (105729006, 'Observation'); -- Health perception, health management pattern
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (162566001, 'Observation'); --Patient not aware of diagnosis
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (122869004, 'Measurement'); --Measurement
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (71388002, 'Procedure'); -- Procedure
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (304252001, 'Observation'); -- Resuscitate
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (304253006, 'Observation'); -- DNR
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (113021009, 'Procedure'); -- Cardiovascular measurement
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (297249002, 'Observation'); -- Family history of procedure
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (14734007, 'Observation'); -- Administrative procedure
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (416940007, 'Observation'); -- Past history of procedure
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (183932001, 'Observation');-- Procedure contraindicated
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (438833006, 'Observation');-- Administration of drug or medicament contraindicated
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (410684002, 'Observation'); -- Drug therapy status
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (17636008, 'Procedure'); -- Specimen collection treatments and procedures - - bad child of 4028908 Laboratory procedure
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (365873007, 'Gender'); -- Gender
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (372148003, 'Race'); --Ethnic group
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (415229000, 'Race'); -- Racial group
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (106237007, 'Observation'); -- Linkage concept
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (258666001, 'Unit'); -- Top unit
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (260245000, 'Meas Value'); -- Meas Value
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (125677006, 'Relationship'); -- Relationship
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (264301008, 'Observation'); -- Psychoactive substance of abuse - non-pharmaceutical
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (226465004, 'Observation'); -- Drinks
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (49062001, 'Device'); -- Device
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (289964002, 'Device'); -- Surgical material
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (260667007, 'Device'); -- Graft
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (418920007, 'Device'); -- Adhesive agent
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (255922001, 'Device'); -- Dental material
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (413674002, 'Observation'); -- Body material
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (118417008, 'Device'); -- Filling material
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (445214009, 'Device'); -- corneal storage medium
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (69449002, 'Observation'); -- Drug action
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (79899007, 'Observation'); -- Drug interaction
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (365858006, 'Observation'); -- Prognosis/outlook finding
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (444332001, 'Observation'); -- Aware of prognosis
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (444143004, 'Observation'); -- Carries emergency treatment
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (13197004, 'Observation'); -- Contraception
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (251859005, 'Observation'); -- Dialysis finding
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (422704000, 'Observation'); -- Difficulty obtaining contraception
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (250869005, 'Observation'); -- Equipment finding
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (217315002, 'Observation'); -- Onset of illness
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (127362006, 'Observation'); -- Previous pregnancies
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (57797005, 'Procedure'); -- Termination of pregnancy
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (162511002, 'Observation'); -- Rare history finding
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (413296003, 'Condition'); -- Depression requiring intervention
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (72670004, 'Condition'); -- Sign
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (124083000, 'Condition'); -- Urobilinogenemia
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (59524001, 'Observation'); -- Blood bank procedure
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (389067005, 'Observation'); -- Community health procedure
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (225288009, 'Observation'); -- Environmental care procedure
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (308335008, 'Observation'); -- Patient encounter procedure
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (389084004, 'Observation'); -- Staff related procedure
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (110461004, 'Observation'); -- Adjunctive care
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (372038002, 'Observation'); -- Advocacy
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (225365006, 'Observation'); -- Care regime
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (228114008, 'Observation'); -- Child health procedures
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (309466006, 'Observation'); -- Clinical observation regime
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (225318000, 'Observation'); -- Personal and environmental management regime
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (133877004, 'Observation'); -- Therapeutic regimen
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (225367003, 'Observation'); -- Toileting regime
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (303163003, 'Observation'); -- Treatments administered under the provisions of the law
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (429159005, 'Procedure'); -- Child psychotherapy
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (15220000, 'Measurement'); -- Laboratory test
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (441742003, 'Measurement'); -- Evaluation finding
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (365605003, 'Measurement'); -- Body measurement finding
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (106019003, 'Condition'); -- Elimination pattern
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (65367001, 'Observation'); -- Victim status
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (106146005, 'Condition'); -- Reflex finding
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (103020000, 'Condition'); -- Adrenarche
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (405729008, 'Condition'); -- Hematochezia
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (165816005, 'Condition'); -- HIV positive
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (300391003, 'Condition'); -- Finding of appearance of stool
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (300393000, 'Condition'); -- Finding of odor of stool
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (239516002, 'Observation'); -- Monitoring procedure
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (243114000, 'Observation'); -- Support
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (300893006, 'Observation'); -- Nutritional finding
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (116336009, 'Observation'); -- Eating / feeding / drinking finding
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (448717002, 'Measurement'); -- Decline in Edinburgh postnatal depression scale score
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (449413009, 'Measurement'); -- Decline in Edinburgh postnatal depression scale score at 8 months
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (46680005, 'Measurement'); -- Vital signs
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (363259005, 'Observation'); -- Patient management procedure
	INSERT INTO peak (peak_code, peak_domain_id) VALUES (278414003, 'Procedure'); -- Pain management
END;
COMMIT;

-- 17.3. Ancestors inherit the domain_id and standard_concept of their Peaks. However, the ancestors of Peaks are overlapping.
-- Therefore, the order by which the inheritance is passed depends on the "height" in the hierarchy: The lower the peak, the later it should be run
-- The following creates the right order by counting the number of ancestors: The more ancestors the lower in the hierarchy.
-- This could cause trouble if a parallel fork happens at the same height
UPDATE peak p
   SET p.ranked =
          (SELECT rnk
             FROM (  SELECT ranked.pd AS peak_code, COUNT(*)+1 AS rnk -- +1 so the top most who have an ancestor are ranked 2, and the ancestor can be ranked 1 (see below)
                       FROM (SELECT DISTINCT
                                    pa.peak_code AS pa, pd.peak_code AS pd
                               FROM peak pa,
                                    snomed_ancestor a,
                                    peak pd
                              WHERE     a.ancestor_concept_code = pa.peak_code
                                    AND a.descendant_concept_code = pd.peak_code
                                    ) ranked
                   GROUP BY ranked.pd) r
            WHERE r.peak_code = p.peak_code);

-- For those that have no ancestors, the rank is 1
UPDATE peak
   SET ranked = 1 
   WHERE ranked is null;
COMMIT;

-- 17.4. Find other peak concepts (orphans) that are missed from the above manual list, and assign them a domain_id based on heuristic. 
-- This is a crude catch for those circumstances if the SNOMED hierarchy as changed and the peak list is no longer complete
-- The result should say "0 rows inserted"
INSERT INTO peak -- before doing that check first out without the insert
   SELECT DISTINCT
          c.concept_code AS peak_code,
          CASE
             WHEN c.concept_class_id = 'Clinical finding'
             THEN
                'Condition'
             WHEN c.concept_class_id = 'Model Comp'
             THEN
                'Metadata'
             WHEN c.concept_class_id = 'Namespace Concept'
             THEN
                'Metadata'
             WHEN c.concept_class_id = 'Observable Entity'
             THEN
                'Observation'
             WHEN c.concept_class_id = 'Organism'
             THEN
                'Observation'
             WHEN c.concept_class_id = 'Pharma/Biol Product'
             THEN
                'Drug'
             ELSE
                'Observation'
          END
             AS peak_domain_id,
          NULL AS ranked
     FROM snomed_ancestor a, concept_stage c
    WHERE c.concept_code = a.ancestor_concept_code
          AND a.ancestor_concept_code NOT IN (SELECT DISTINCT -- find those where ancestors are not also a descendant, i.e. a top of a tree
                                                     descendant_concept_code
                                                FROM snomed_ancestor)
          AND a.ancestor_concept_code NOT IN (SELECT DISTINCT peak_code from peak) -- but exclude those we already have
          AND c.vocabulary_id='SNOMED';
COMMIT;

-- 17.5. Build domains, preassign all them with "Not assigned"
CREATE TABLE domain_snomed
AS
   SELECT concept_code, CAST ('Not assigned' AS VARCHAR2(20)) AS domain_id
     FROM concept_stage
    WHERE vocabulary_id = 'SNOMED';

-- Pass out domain_ids
-- Method 1: Assign domains to children of peak concepts in the order rank, and within rank by order of precedence
-- Do that for all peaks by order of ranks. The highest first, the lower ones second, etc.

BEGIN
   FOR A IN (  SELECT DISTINCT ranked
                 FROM peak
             ORDER BY ranked)
   LOOP
      UPDATE domain_snomed d
         SET d.domain_id =
                (SELECT child.peak_domain_id
                   FROM (SELECT DISTINCT
                                -- if there are two conflicting domains in the rank (both equally distant from the ancestor) then use precedence
                                FIRST_VALUE (
                                   p.peak_domain_id)
                                OVER (
                                   PARTITION BY a.descendant_concept_code
                                   ORDER BY
                                      DECODE (peak_domain_id,
                                              'Measurement', 1,
                                              'Procedure', 2,
                                              'Device', 3,
                                              'Condition', 4,
                                              'Provider', 5,
                                              'Drug', 6,
                                              'Gender', 7,
                                              'Race', 8,
                                              10) -- everything else is Observation
                                                 )
                                   AS peak_domain_id,
                                a.descendant_concept_code AS concept_code
                           FROM peak p, snomed_ancestor a
                          WHERE     a.ancestor_concept_code = p.peak_code
                                AND p.ranked = A.ranked) child
                  WHERE child.concept_code = d.concept_code)
       WHERE     d.concept_code IN (SELECT a.descendant_concept_code
                                      FROM peak p, snomed_ancestor a
                                     WHERE a.ancestor_concept_code =
                                              p.peak_code)
             AND EXISTS
                    (SELECT 1
                       FROM peak p, snomed_ancestor a
                      WHERE     a.ancestor_concept_code = p.peak_code
                            AND p.ranked = A.ranked
                            AND a.descendant_concept_code = d.concept_code);
   END LOOP;
END
;

-- Assign domains of peaks themselves (snomed_ancestor doesn't include self-descendants)
MERGE INTO domain_snomed d
     USING (SELECT peak_code, peak_domain_id FROM peak) v
        ON (v.peak_code = d.concept_code)
WHEN MATCHED
THEN
   UPDATE SET d.domain_id = v.peak_domain_id;
COMMIT;

-- Update top guy
UPDATE domain_snomed SET domain_id = 'Metadata' WHERE concept_code = 138875005;

-- Method 2: For those that slipped through the cracks assign domains by using the class_concept_id
-- This is a crude method, and Method 1 should be revised to cover all concepts.
UPDATE domain_snomed d
   SET d.domain_id =
          (SELECT CASE c.concept_class_id
                  WHEN 'Admin Concept' THEN 'Type Concept'
                  WHEN 'Attribute' THEN 'Observation'
                  WHEN 'Body Structure' THEN 'Spec Anatomic Site'
                  WHEN 'Clinical Finding' THEN 'Condition'
                  WHEN 'Context-dependent' THEN 'Observation'
                  WHEN 'Event' THEN 'Observation'
                  WHEN 'Inactive Concept' THEN 'Metadata'
                  WHEN 'Linkage Assertion' THEN 'Observation'
                  WHEN 'Location' THEN 'Observation'
                  WHEN 'Model Comp' THEN 'Metadata'
                  WHEN 'Morph Abnormality' THEN 'Observation'
                  WHEN 'Namespace Concept' THEN 'Metadata'
                  WHEN 'Navi Concept' THEN 'Metadata'
                  WHEN 'Observable Entity' THEN 'Observation'
                  WHEN 'Organism' THEN 'Observation'
                  WHEN 'Pharma/Biol Product' THEN 'Drug'
                  WHEN 'Physical Force' THEN 'Observation'
                  WHEN 'Physical Object' THEN 'Device'
                  WHEN 'Procedure' THEN 'Procedure'
                  WHEN 'Qualifier Value' THEN 'Observation'
                  WHEN 'Record Artifact' THEN 'Type Concept'
                  WHEN 'Social Context' THEN 'Observation'
                  WHEN 'Special Concept' THEN 'Metadata'
                  WHEN 'Specimen' THEN 'Specimen'
                  WHEN 'Staging / Scales' THEN 'Observation'
                  WHEN 'Substance' THEN 'Observation'
                  ELSE 'Observation'
                END
             FROM concept_stage c
            WHERE     c.concept_code = d.concept_code
                  AND C.VOCABULARY_ID = 'SNOMED')
 WHERE d.domain_id = 'Not assigned';

COMMIT;

-- 17.6. Update concept_stage from newly created domains.
CREATE INDEX idx_domain_cc
   ON domain_snomed (concept_code);
   
UPDATE concept_stage c
   SET c.domain_id =
          (SELECT d.domain_id
             FROM domain_snomed d
            WHERE d.concept_code = c.concept_code)
 WHERE c.vocabulary_id = 'SNOMED';
 COMMIT;

-- 17.7. Make manual changes according to rules
-- Create Route of Administration
UPDATE concept_stage
   SET domain_id = 'Route'
 WHERE     concept_code IN ('255560000',
                            '255582007',
                            '258160008',
                            '260540009',
                            '260548002',
                            '264049007',
                            '263887005',
                            '372468001',
                            '72607000',
                            '359540000',
                            '90028008')
       AND vocabulary_id = 'SNOMED';

-- Create Specimen Anatomical Site
UPDATE concept_stage
   SET domain_id = 'Spec Anatomic Site'
 WHERE concept_class_id = 'Body Structure' AND vocabulary_id = 'SNOMED';

-- Create Specimen
UPDATE concept_stage
   SET domain_id = 'Specimen'
 WHERE concept_class_id = 'Specimen' AND vocabulary_id = 'SNOMED';

-- Create Measurement Value Operator
UPDATE concept_stage
   SET domain_id = 'Meas Value Operator'
 WHERE     concept_code IN ('276136004',
                            '276140008',
                            '276137008',
                            '276138003',
                            '276139006')
       AND vocabulary_id = 'SNOMED';

-- Create Speciment Disease Status
UPDATE concept_stage
  SET domain_id = 'Spec Disease Status'
WHERE concept_code IN ('21594007', '17621005', '263654008')
  AND vocabulary_id = 'SNOMED';

-- Fix navigational concepts
UPDATE concept_stage
  SET domain_id = CASE concept_class_id
                    WHEN 'Admin Concept' THEN 'Type Concept'
                    WHEN 'Attribute' THEN 'Observation'
                    WHEN 'Body Structure' THEN 'Spec Anatomic Site'
                    WHEN 'Clinical Finding' THEN 'Condition'
                    WHEN 'Context-dependent' THEN 'Observation'
                    WHEN 'Event' THEN 'Observation'
                    WHEN 'Inactive Concept' THEN 'Metadata'
                    WHEN 'Linkage Assertion' THEN 'Observation'
                    WHEN 'Location' THEN 'Observation'
                    WHEN 'Model Comp' THEN 'Metadata'
                    WHEN 'Morph Abnormality' THEN 'Observation'
                    WHEN 'Namespace Concept' THEN 'Metadata'
                    WHEN 'Navi Concept' THEN 'Metadata'
                    WHEN 'Observable Entity' THEN 'Observation'
                    WHEN 'Organism' THEN 'Observation'
                    WHEN 'Pharma/Biol Product' THEN 'Drug'
                    WHEN 'Physical Force' THEN 'Observation'
                    WHEN 'Physical Object' THEN 'Device'
                    WHEN 'Procedure' THEN 'Procedure'
                    WHEN 'Qualifier Value' THEN 'Observation'
                    WHEN 'Record Artifact' THEN 'Type Concept'
                    WHEN 'Social Context' THEN 'Observation'
                    WHEN 'Special Concept' THEN 'Metadata'
                    WHEN 'Specimen' THEN 'Specimen'
                    WHEN 'Staging / Scales' THEN 'Observation'
                    WHEN 'Substance' THEN 'Observation'
                    ELSE 'Observation'
                  END
  WHERE vocabulary_id = 'SNOMED'
    AND concept_code in (
      SELECT descendant_concept_code from snomed_ancestor where ancestor_concept_code='363743006' -- Navigational Concept, contains all sorts of orphan codes
    )
;

COMMIT;

-- 17.8. Set standard_concept based on domain_id
UPDATE concept_stage
   SET standard_concept =
          CASE domain_id
             WHEN 'Drug' THEN NULL                         -- Drugs are RxNorm
             WHEN 'Gender' THEN NULL                       -- Gender are OMOP
             WHEN 'Metadata' THEN NULL                     -- Not used in CDM
             WHEN 'Race' THEN NULL                         -- Race are CDC
             WHEN 'Provider Specialty' THEN NULL           -- got CMS and ABMS specialty
             WHEN 'Place of Service' THEN NULL             -- got own place of service
             WHEN 'Type Concept' THEN NULL                 -- Type Concept in own OMOP vocabulary
             WHEN 'Unit' THEN NULL                         -- Units are UCUM
             ELSE 'S'
          END
WHERE vocabulary_id = 'SNOMED';

-- And de-standardize navigational concepts
UPDATE concept_stage
   SET standard_concept = null
WHERE vocabulary_id = 'SNOMED'
  AND concept_code in (
      SELECT descendant_concept_code from snomed_ancestor where ancestor_concept_code='363743006' -- Navigational Concept
  )
;

COMMIT;

-- 18 Return domain_id and concept_class_id for some concepts according to our rules
-- 18.1 Return domain_id
MERGE INTO concept_stage c
     USING (SELECT dmd_int.domain_id, dmd_int.concept_code
              FROM concept_stage_dmd dmd_int, concept_stage c_int
             WHERE     dmd_int.concept_code = c_int.concept_code
                   AND dmd_int.domain_id <> c_int.domain_id
                   AND dmd_int.insert_id IN (1,
                                             2,
                                             3,
                                             4,
                                             5,
                                             6)) dmd
        ON (dmd.concept_code = c.concept_code)
WHEN MATCHED
THEN
   UPDATE SET c.domain_id = dmd.domain_id;
COMMIT;   

-- 18.2 Return concept_class_id
--for AMPPs (branded packs), AMPs (branded drugs) and VMPPs (clinical packs)
MERGE INTO concept_stage c
     USING (SELECT dmd_int.concept_class_id, dmd_int.concept_code
              FROM concept_stage_dmd dmd_int, concept_stage c_int
             WHERE     dmd_int.concept_code = c_int.concept_code
                   AND dmd_int.concept_class_id = 'Pharma/Biol Product'
                   AND c_int.concept_class_id IS NULL
                   AND dmd_int.insert_id IN (13, 14, 15)) dmd
        ON (dmd.concept_code = c.concept_code)
WHEN MATCHED
THEN
   UPDATE SET c.concept_class_id = dmd.concept_class_id;

--for Ingredients and deprecated Ingredients
MERGE INTO concept_stage c
     USING (SELECT dmd_int.concept_class_id, dmd_int.concept_code
              FROM concept_stage_dmd dmd_int, concept_stage c_int
             WHERE     dmd_int.concept_code = c_int.concept_code
                   AND dmd_int.concept_class_id = 'Substance'
                   AND COALESCE (c_int.concept_class_id, 'unknown') NOT IN ('Substance')
                   AND dmd_int.insert_id IN (7, 8)) dmd
        ON (dmd.concept_code = c.concept_code)
WHEN MATCHED
THEN
   UPDATE SET c.concept_class_id = dmd.concept_class_id;  

--for Route, deprecated Routes, UoMs and deprecated UoMs    
MERGE INTO concept_stage c
     USING (SELECT dmd_int.concept_class_id, dmd_int.concept_code
              FROM concept_stage_dmd dmd_int, concept_stage c_int
             WHERE     dmd_int.concept_code = c_int.concept_code
                   AND dmd_int.concept_class_id = 'Qualifier Value'
                   AND COALESCE (c_int.concept_class_id, 'unknown') NOT IN ('Qualifier Value')
                   AND dmd_int.insert_id IN (1, 2, 5, 6)) dmd
        ON (dmd.concept_code = c.concept_code)
WHEN MATCHED
THEN
   UPDATE SET c.concept_class_id = dmd.concept_class_id;     
COMMIT;

-- 19 Clean up
DROP TABLE peak PURGE;
DROP TABLE domain_snomed PURGE;
DROP TABLE concept_stage_dmd PURGE;
DROP TABLE tmp_rel PURGE;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script