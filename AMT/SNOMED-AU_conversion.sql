CREATE TABLE CONCEPT_STAGE_SN
(
   CONCEPT_ID        NUMBER,
   CONCEPT_NAME      VARCHAR2(255 Byte),
   DOMAIN_ID         VARCHAR2(200 Byte),
   VOCABULARY_ID     VARCHAR2(20 Byte)    NOT NULL,
   CONCEPT_CLASS_ID  VARCHAR2(20 Byte),
   STANDARD_CONCEPT  VARCHAR2(1 Byte),
   CONCEPT_CODE      VARCHAR2(40 Byte)    NOT NULL,
   VALID_START_DATE  DATE                 NOT NULL,
   VALID_END_DATE    DATE                 NOT NULL,
   INVALID_REASON    VARCHAR2(1 Byte)
)
TABLESPACE USERS;

-- 1. Create core version of SNOMED without concept_id, domain_id, concept_class_id, standard_concept
INSERT  /*+ APPEND */  INTO concept_stage_sn (concept_name,
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
             FROM sct2_Concept_Full_AU c, FULL_DESCR_DRUG_ONLY d
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
    WHERE sct2.rn = 1 AND sct2.active = 1;
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
'AU substance',53,
'AU qualifier',54,
'medicinal product unit of use',55,
'medicinal product pack',56,
'medicinal product',57,
'trade product pack',58,
'trade product unit of use',59,
'trade product',60,
'containered trade product pack',61,
                                

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
                          rna AS rnb    -- row number in SCT2_DESC_FULL_AU
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
                                     rna -- row number in SCT2_DESC_FULL_AU
                             FROM concept_stage_sn c
                             JOIN FULL_DESCR_DRUG_ONLY d ON d.conceptid = c.concept_code
									 where c.vocabulary_id='SNOMED')))
    WHERE rnc = 1;	
	
CREATE INDEX x_cc_2cd ON tmp_concept_class (concept_code);

-- 6. Create reduced set of classes 
UPDATE concept_stage_sn cs
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
WHEN F7 = 'AU substance' THEN 'AU Substance'
WHEN F7 = 'AU qualifier' THEN 'AU Qualifier'
WHEN F7 = 'medicinal product unit of use' THEN 'Med Product Unit'
WHEN F7 = 'medicinal product pack' THEN 'Med Product Pack'
WHEN F7 = 'medicinal product' THEN 'Medicinal Product'
WHEN F7 = 'trade product pack' THEN 'Trade Product Pack'
WHEN F7 = 'trade product' THEN 'Trade Product'
WHEN F7 = 'trade product unit of use' THEN 'Trade Product Unit'
WHEN F7 = 'containered trade product pack' THEN 'Contain Trade Pack'
                 ELSE 'Undefined'
                 END
             FROM tmp_concept_class cc
            WHERE cc.concept_code = cs.concept_code)
	WHERE cs.vocabulary_id='SNOMED'
	AND cs.concept_code IN (SELECT concept_code FROM tmp_concept_class);

--change source concept_class_id
update concept_stage_sn
set concept_class_id='Containered Pack'
where concept_class_id='Contain Trade Pack';
