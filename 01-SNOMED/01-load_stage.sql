/*
Download the international SNOMED file SnomedCT_Release_INT_YYYYMMDD.zip from http://www.nlm.nih.gov/research/umls/licensedcontent/snomedctfiles.html.
2. Extract the release date from the file name.
3. Extract the following files from the folder SnomedCT_Release_INT_YYYYMMDD\RF2Release\Full\Terminology\ into a working folder:
- sct2_Concept_Full_INT_YYYYMMDD.txt
- sct2_Description_Full-en_INT_YYYYMMDD.txt
- sct2_Relationship_Full_INT_YYYYMMDD.txt
4. Load them into SCT2_CONCEPT_FULL_INT, SCT2_DESC_FULL_EN_INT and SCT2_RELA_FULL_INT. Use the control files in Vocabulary-v5.0\01-SNOMED.

5. Download the British SNOMED file SNOMEDCT2_XX.0.0_YYYYMMDD000001.zip from https://isd.hscic.gov.uk/trud3/user/authenticated/group/0/pack/26/subpack/102/releases.
6. Extract the release date from the file name.
7. Extract the following files from the folder SnomedCT2_GB1000000_YYYYMMDD\RF2Release\Full\Terminology into a working folder:
- sct2_Concept_Full_GB1000000_YYYYMMDD.txt
- sct2_Description_Full-en-GB_GB1000000_YYYYMMDD.txt
- sct2_Description_Full-en-GB_GB1000000_YYYYMMDD.txt
8. Load them into SCT2_CONCEPT_FULL_UK, SCT2_DESC_FULL_UK, SCT2_RELA_FULL_UK. Use the control files in Vocabulary-v5.0\01-SNOMED

9. der2_cRefset_AssociationReferenceFull_INT_YYYYMMDD.txt from SnomedCT_Release_INT_YYYYMMDD\RF2Release\Full\Refset\Content 
and der2_cRefset_AssociationReferenceFull_GB1000000_YYYYMMDD.txt from SnomedCT2_GB1000000_YYYYMMDD\RF2Release\Full\Refset\Content (ctl files in 10-SNOMED)
*/

--1 create views
create view sct2_concept_full_merged as select * from sct2_concept_full_int union select * from sct2_concept_full_uk;
create view sct2_desc_full_merged as select * from sct2_desc_full_en_int union select * from sct2_desc_full_uk;
create view sct2_rela_full_merged as select * from sct2_rela_full_int union select * from sct2_rela_full_uk;
create view der2_cRefset_AssRefFull_merged as select * from der2_cRefset_AssRefFull_INT union select * from der2_cRefset_AssRefFull_UK;

--2 Create core version of SNOMED without concept_id, domain_id, concept_class_id, standard_concept
INSERT INTO concept_stage (concept_name,
                           vocabulary_id,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT regexp_replace(concept_name, ' \(.*?\)$', ''),
          'SNOMED' AS vocabulary_id,
          concept_code,
          TO_DATE ('01.12.2014', 'dd.mm.yyyy') AS valid_start_date,
          TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
          NULL AS invalid_reason
     FROM (SELECT SUBSTR (d.term, 1, 256) AS concept_name,
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
                        CASE WHEN term LIKE '%(%)%' THEN 1 ELSE 0 END)
                     rn
             FROM sct2_concept_full_merged c, sct2_desc_full_merged d
            WHERE c.id = d.conceptid AND term IS NOT NULL)
    WHERE rn = 1 AND active = 1;
	

--3 Create temporary table with extracted class information and terms ordered by some good precedence
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
                                     REGEXP_INSTR (term,
                                                   '\(',
                                                   1,
                                                   REGEXP_COUNT (term, '\('))
                                   + 1,
                                     REGEXP_INSTR (term,
                                                   '\)',
                                                   1,
                                                   REGEXP_COUNT (term, '\)'))
                                   - REGEXP_INSTR (term,
                                                   '\(',
                                                   1,
                                                   REGEXP_COUNT (term, '\('))
                                   - 1)
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
                                  JOIN sct2_desc_full_merged d
                                     ON d.conceptid = c.concept_code)))
    WHERE rnc = 1;	
	
	create index x_cc_2cd on tmp_concept_class (concept_code);
	
--4 Create reduced set of classes 
UPDATE concept_stage cs
   SET concept_class_id =
          (SELECT CASE
                     WHEN F7 = 'disorder'
                     THEN
                        'Clinical Finding'
                     WHEN F7 = 'procedure'
                     THEN
                        'Procedure'
                     WHEN F7 = 'finding'
                     THEN
                        'Clinical Finding'
                     WHEN F7 = 'organism'
                     THEN
                        'Organism'
                     WHEN F7 = 'body structure'
                     THEN
                        'Body Structure'
                     WHEN F7 = 'substance'
                     THEN
                        'Substance'
                     WHEN F7 = 'product'
                     THEN
                        'Pharma/Biol Product'
                     WHEN F7 = 'event'
                     THEN
                        'Event'
                     WHEN F7 = 'qualifier value'
                     THEN
                        'Qualifier Value'
                     WHEN F7 = 'observable entity'
                     THEN
                        'Observable Entity'
                     WHEN F7 = 'situation'
                     THEN
                        'Context-dependent'
                     WHEN F7 = 'occupation'
                     THEN
                        'Social Context'
                     WHEN F7 = 'regime/therapy'
                     THEN
                        'Procedure'
                     WHEN F7 = 'morphologic abnormality'
                     THEN
                        'Morph Abnormality'
                     WHEN F7 = 'physical object'
                     THEN
                        'Physical Object'
                     WHEN F7 = 'specimen'
                     THEN
                        'Specimen'
                     WHEN F7 = 'environment'
                     THEN
                        'Location'
                     WHEN F7 = 'context-dependent category'
                     THEN
                        'Context-dependent'
                     WHEN F7 = 'attribute'
                     THEN
                        'Attribute'
                     WHEN F7 = 'assessment scale'
                     THEN
                        'Staging / Scales'
                     WHEN F7 = 'person'
                     THEN
                        'Social Context'
                     WHEN F7 = 'cell'
                     THEN
                        'Body Structure'
                     WHEN F7 = 'geographic location'
                     THEN
                        'Location'
                     WHEN F7 = 'cell structure'
                     THEN
                        'Body Structure'
                     WHEN F7 = 'ethnic group'
                     THEN
                        'Social Context'
                     WHEN F7 = 'tumor staging'
                     THEN
                        'Staging / Scales'
                     WHEN F7 = 'religion/philosophy'
                     THEN
                        'Social Context'
                     WHEN F7 = 'record artifact'
                     THEN
                        'Record Artifact'
                     WHEN F7 = 'physical force'
                     THEN
                        'Physical Force'
                     WHEN F7 = 'foundation metadata concept'
                     THEN
                        'Model Comp'
                     WHEN F7 = 'namespace concept'
                     THEN
                        'Namespace Concept'
                     WHEN F7 = 'administrative concept'
                     THEN
                        'Admin Concept'
                     WHEN F7 = 'biological function'
                     THEN
                        'Biological Function'
                     WHEN F7 = 'living organism'
                     THEN
                        'Organism'
                     WHEN F7 = 'life style'
                     THEN
                        'Social Context'
                     WHEN F7 = 'contextual qualifier'
                     THEN
                        'Qualifier Value'
                     WHEN F7 = 'staging scale'
                     THEN
                        'Staging / Scales'
                     WHEN F7 = 'life event - finding'
                     THEN
                        'Event'
                     WHEN F7 = 'social concept'
                     THEN
                        'Social Context'
                     WHEN F7 = 'core metadata concept'
                     THEN
                        'Model Comp'
                     WHEN F7 = 'special concept'
                     THEN
                        'Special Concept'
                     WHEN F7 = 'racial group'
                     THEN
                        'Social Context'
                     WHEN F7 = 'therapy'
                     THEN
                        'Procedure'
                     WHEN F7 = 'external anatomical feature'
                     THEN
                        'Body Structure'
                     WHEN F7 = 'organ component'
                     THEN
                        'Body Structure'
                     WHEN F7 = 'physical device'
                     THEN
                        'Physical Object'
                     WHEN F7 = 'linkage concept'
                     THEN
                        'Linkage Concept'
                     WHEN F7 = 'metadata'
                     THEN
                        'Model Comp'
                     ELSE
                        'Undefined'
                  END
             FROM tmp_concept_class cc
            WHERE cc.concept_code = cs.concept_code);
			
			