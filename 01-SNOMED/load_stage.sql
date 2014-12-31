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

10. download YYYYab-1-meta.nlm (for exemple 2014ab-1-meta.nlm)
--unpack MRCONSO.RRF.aa.gz and MRCONSO.RRF.ab.gz, then run:
--gunzip *.gz
--cat MRCONSO.RRF.aa MRCONSO.RRF.ab > MRCONSO.RRF
--load MRCONSO.RRF with RXNCONSO.ctl
-- DDL & ctl -> Vocabulary-v5.0\UMLS\

-- Update latest_update field to new date 
update vocabulary set latest_update=to_date('YYYYMMDD','yyyymmdd') where vocabulary_id='SNOMED'; commit;
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
          (select latest_update From vocabulary where vocabulary_id='SNOMED') AS valid_start_date,
          TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
          NULL AS invalid_reason
     FROM (SELECT SUBSTR (d.term, 1, 255) AS concept_name,
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
COMMIT;	
	

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
                                     ON d.conceptid = c.concept_code
									 where c.vocabulary_id='SNOMED')))
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
            WHERE cc.concept_code = cs.concept_code)
	WHERE cs.vocabulary_id='SNOMED';
			
--5.	Choice of concept_name in SNOMED and synonyms
--1st Fix concept_names using tmp table:
create table mrconso_tmp as
select DISTINCT
                  FIRST_VALUE (
                     n.AUI)
                  OVER (
                     PARTITION BY n.code
                     ORDER BY
                        DECODE (n.tty,
                                'PT', 1,
                                'PTGB', 2,
                                'SY', 3,
                                'SYGB', 4,
                                'MTH_PT', 5,
                                'FN', 6,
                                'MTH_SY', 7,
                                'SB', 8,
                                10            -- default for the obsolete ones
                                  )) AUI,  
                   FIRST_VALUE (
                     -- take the best str, and remove things like "(procedure)" 
                     REGEXP_REPLACE (n.str, ' \(.*?\)$', '')) 
                  OVER (
                     PARTITION BY n.code
                     ORDER BY
                        DECODE (n.tty,
                                'PT', 1,
                                'PTGB', 2,
                                'SY', 3,
                                'SYGB', 4,
                                'MTH_PT', 5,
                                'FN', 6,
                                'MTH_SY', 7,
                                'SB', 8,
                                10            -- default for the obsolete ones
                                  )) str,                                  
                  n.code                                                                
             FROM mrconso n
            WHERE n.sab = 'SNOMEDCT_US';
			
--then update
UPDATE concept c
   SET c.concept_name =
          (         
           SELECT str
             FROM mrconso_tmp m_tmp
            WHERE m_tmp.code = c.concept_code)
 WHERE     EXISTS
              (        -- the concept_name is identical to the str of a record
               SELECT 1
                 FROM mrconso m
                WHERE     m.code = c.concept_code
                      AND m.sab = 'SNOMEDCT_US'
                      AND c.vocabulary_id = 'SNOMED'
                      AND TRIM (c.concept_name) = TRIM (m.str)
                      AND m.tty <> 'PT' -- anything that is not the preferred term
                                       )
       AND c.invalid_reason IS NULL -- only active ones. The inactive ones often only have obsolete tty anyway
       AND c.vocabulary_id = 'SNOMED';
COMMIT;	   

--6 Get all the other ones in ('PT', 'PTGB', 'SY', 'SYGB', 'MTH_PT', 'FN', 'MTH_SY', 'SB') into concept_synonym_stage
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   language_concept_id)
   SELECT NULL,
          m.code,
          SUBSTR (m.str, 1, 1000),
          4093769 -- English
     FROM mrconso m LEFT JOIN mrconso_tmp m_tmp ON m.aui = m_tmp.aui
    WHERE m.sab = 'SNOMEDCT_US' AND m_tmp.aui IS NULL;
COMMIT;
DROP TABLE mrconso_tmp PURGE;

--7 fill concept_relationship_stage from SNOMED	
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        relationship_id,
										vocabulary_id_1,
										vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
  WITH tmp_rel
        AS (                             --get active and latest relationships
            SELECT sourceid, destinationid, replace(term,' (attribute)','') term
              FROM (SELECT r.sourceid,
                           r.destinationid,
                           d.term,
                           ROW_NUMBER ()
                           OVER (
                              PARTITION BY r.id
                              ORDER BY
                                 TO_DATE (r.effectivetime, 'YYYYMMDD') DESC)
                              rn,
                           r.active
                      FROM sct2_rela_full_merged r
                           JOIN sct2_desc_full_merged d
                              ON r.typeid = d.conceptid)
             WHERE     rn = 1
                   AND active = 1
                   AND sourceid IS NOT NULL
                   AND destinationid IS NOT NULL
                   AND term<>'PBCL flag true')
   --convert SNOMED to OMOP-type relationship_id
   SELECT sourceid,
          destinationid,
          CASE
             WHEN TERM = 'Is a'
             THEN
                'Is a'
             WHEN term = 'Recipient category'
             THEN
                'Has recipient cat'
             WHEN term = 'Procedure site'
             THEN
                'Has proc site'
             WHEN term = 'Priority'
             THEN
                'Has priority'
             WHEN term = 'Pathological process'
             THEN
                'Has pathology'
             WHEN term = 'Part of'
             THEN
                'Has part of'
             WHEN term = 'Severity'
             THEN
                'Has severity'
             WHEN term = 'Revision status'
             THEN
                'Has revision status'
             WHEN term = 'Access'
             THEN
                'Has access'
             WHEN term = 'Occurrence'
             THEN
                'Has occurrence'
             WHEN term = 'Method'
             THEN
                'Has method'
             WHEN term = 'Laterality'
             THEN
                'Has laterality'
             WHEN term = 'Interprets'
             THEN
                'Has interprets'
             WHEN term = 'Indirect morphology'
             THEN
                'Has indir morph'
             WHEN term = 'Indirect device'
             THEN
                'Has indir device'
             WHEN term = 'Has specimen'
             THEN
                'Has specimen'
             WHEN term = 'Has interpretation'
             THEN
                'Has interpretation'
             WHEN term = 'Has intent'
             THEN
                'Has intent'
             WHEN term = 'Has focus'
             THEN
                'Has focus'
             WHEN term = 'Has definitional manifestation'
             THEN
                'Has manifestation'
             WHEN term = 'Has active ingredient'
             THEN
                'Has active ing'
             WHEN term = 'Finding site'
             THEN
                'Has finding site'
             WHEN term = 'Episodicity'
             THEN
                'Has episodicity'
             WHEN term = 'Direct substance'
             THEN
                'Has dir subst'
             WHEN term = 'Direct morphology'
             THEN
                'Has dir morph'
             WHEN term = 'Direct device'
             THEN
                'Has dir device'
             WHEN term = 'Component'
             THEN
                'Has component'
             WHEN term = 'Causative agent'
             THEN
                'Has causative agent'
             WHEN term = 'Associated morphology'
             THEN
                'Has asso morph'
             WHEN term = 'Associated finding'
             THEN
                'Has asso finding'
             WHEN term = 'Measurement Method'
             THEN
                'Has measurement'
             WHEN term = 'Property'
             THEN
                'Has property'
             WHEN term = 'Scale type'
             THEN
                'Has scale type'
             WHEN term = 'Time aspect'
             THEN
                'Has time aspect'
             WHEN term = 'Specimen procedure'
             THEN
                'Has specimen proc'
             WHEN term = 'Specimen source identity'
             THEN
                'Has specimen source'
             WHEN term = 'Specimen source morphology'
             THEN
                'Has specimen morph'
             WHEN term = 'Specimen source topography'
             THEN
                'Has specimen topo'
             WHEN term = 'Specimen substance'
             THEN
                'Has specimen subst'
             WHEN term = 'Due to'
             THEN
                'Has due to'
             WHEN term = 'Subject relationship context'
             THEN
                'Has relat context'
             WHEN term = 'Has dose form'
             THEN
                'Has dose form'
             WHEN term = 'After'
             THEN
                'Occurs after'
             WHEN term = 'Associated procedure'
             THEN
                'Has asso proc'
             WHEN term = 'Procedure site - Direct'
             THEN
                'Has dir proc site'
             WHEN term = 'Procedure site - Indirect'
             THEN
                'Has indir proc site'
             WHEN term = 'Procedure device'
             THEN
                'Has proc device'
             WHEN term = 'Procedure morphology'
             THEN
                'Has proc morph'
             WHEN term = 'Finding context'
             THEN
                'Has finding context'
             WHEN term = 'Procedure context'
             THEN
                'Has proc context'
             WHEN term = 'AW'
             THEN
                'Finding asso with'
             WHEN term = 'Clinical course'
             THEN
                'Has clinical course'  
             WHEN term = 'Finding informer'
             THEN
                'Using finding inform'   
             WHEN term = 'Finding method'
             THEN
                'Using finding method'    
             WHEN term = 'Measurement method'
             THEN
                'Has method'     
             WHEN term = 'Route of administration - attribute'
             THEN
                'Has route of admin'
             WHEN term = 'Surgical approach'
             THEN
                'Has surgical appr'  
             WHEN term = 'Temporal context'
             THEN
                'Has temporal context'   
             WHEN term = 'Using access device'
             THEN
                'Using acc device'  
             WHEN term = 'Using device'
             THEN
                'Using device'   
             WHEN term = 'Using energy'
             THEN
                'Using energy'   
             WHEN term = 'Using substance'
             THEN
                'Using subst'                      
             ELSE
                'non-existing'                           -- this will break it
          END
             AS relationship_id,
		  'SNOMED',
		  'SNOMED',
          (select latest_update From vocabulary where vocabulary_id='SNOMED'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM (SELECT * FROM tmp_rel);
COMMIT;	 

--8 add replacement relationships. They are handled in a different SNOMED table
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        relationship_id,
										vocabulary_id_1,
										vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT concept_code_1,
          concept_code_2,
          relationship_id,
		  'SNOMED',
		  'SNOMED',
          (select latest_update From vocabulary where vocabulary_id='SNOMED'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM (SELECT referencedcomponentid AS concept_code_1,
                  targetcomponent AS concept_code_2,
                  CASE refsetid
                     WHEN 900000000000526001 THEN 'SNOMED replaced by'
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
                               900000000000526001,
                               900000000000523009,
                               900000000000528000,
                               900000000000527005,
                               900000000000530003))
    WHERE rn = 1 AND active = 1;
COMMIT;

--9 Make sure all records are symmetrical and turn if necessary
INSERT INTO concept_relationship_stage
   SELECT crs.concept_id_2 AS concept_id_1,
          crs.concept_id_1 AS concept_id_2,
          CRS.CONCEPT_CODE_2 AS CONCEPT_CODE_1,
          CRS.CONCEPT_CODE_1 AS CONCEPT_CODE_2,
          r.reverse_relationship_id AS relationship_id,
		  crs.vocabulary_id_2,
		  crs.vocabulary_id_1,
          crs.valid_start_date,
          crs.valid_end_date,
          crs.invalid_reason
     FROM concept_relationship_stage crs
          JOIN relationship r ON r.relationship_id = crs.relationship_id
    WHERE NOT EXISTS
             (                                           -- the inverse record
              SELECT 1
                FROM concept_relationship_stage i
               WHERE     crs.CONCEPT_CODE_1 = i.CONCEPT_CODE_2
                     AND crs.CONCEPT_CODE_2 = i.CONCEPT_CODE_1
                     AND r.reverse_relationship_id = i.relationship_id
					 AND crs.vocabulary_id_1=i.vocabulary_id_2
					 AND crs.vocabulary_id_2=i.vocabulary_id_1)
    AND crs.vocabulary_id_1='SNOMED';
COMMIT;

	
--10. create the ancestor's package (01-SNOMED\PKG_CONCEPT_ANCESTOR.sql) and start building the hierarchy (snomed-only)
exec PKG_CONCEPT_ANCESTOR.CALC;
COMMIT;

--11. Create domain_id
-- 11.1. Manually create table with "Peaks" = ancestors of records that are all of the same domain
create table peak (
	peak_code varchar(20), --the id of the top ancestor
	peak_domain_id varchar(20), -- the domain to assign to all its children
	ranked integer -- number for the order in which to assign
);
			   
-- 11.2 Fill in the various peak concepts
insert into peak (peak_code, peak_domain_id) values (243796009, 'Observation'); -- 'Context-dependent category' that has no ancestor
insert into peak (peak_code, peak_domain_id) values (138875005, 'Observation'); -- root
insert into peak (peak_code, peak_domain_id) values (223366009, 'Provider Specialty');
insert into peak (peak_code, peak_domain_id) values (43741000, 'Place of Service');	  -- Site of care
insert into peak (peak_code, peak_domain_id) values (420056007, 'Drug'); -- Aromatherapy agent
insert into peak (peak_code, peak_domain_id) values (373873005, 'Drug'); -- Pharmaceutical / biologic product
insert into peak (peak_code, peak_domain_id) values (410942007, 'Drug'); --	Drug or medicament
insert into peak (peak_code, peak_domain_id) values (419572002, 'Observation'); -- alcohol agent, exception of drug
insert into peak (peak_code, peak_domain_id) values (373782009, 'Observation'); -- diagnostic substance, exception of drug
insert into peak (peak_code, peak_domain_id) values (404684003, 'Condition'); -- Clinical Finding
insert into peak (peak_code, peak_domain_id) values (218496004, 'Condition'); -- Adverse reaction to primarily systemic agents
insert into peak (peak_code, peak_domain_id) values (313413008, 'Condition'); -- Calculus observation
insert into peak (peak_code, peak_domain_id) values (118245000, 'Measurement'); -- 'Finding by measurement'
insert into peak (peak_code, peak_domain_id) values (365854008, 'Observation'); -- 'History finding'
insert into peak (peak_code, peak_domain_id) values (118233009, 'Observation'); -- 'Finding of activity of daily living'
insert into peak (peak_code, peak_domain_id) values (307824009, 'Observation');-- 'Administrative statuses'
insert into peak (peak_code, peak_domain_id) values (162408000, 'Observation'); -- Symptom description
insert into peak (peak_code, peak_domain_id) values (105729006, 'Observation'); -- 'Health perception, health management pattern'
insert into peak (peak_code, peak_domain_id) values (162566001, 'Observation'); --'Patient not aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (65367001, 'Observation'); --'Victim status'
insert into peak (peak_code, peak_domain_id) values (162565002, 'Observation'); --'Patient aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (418138009, 'Observation'); --Patient condition finding
insert into peak (peak_code, peak_domain_id) values (405503005, 'Observation'); --'Staff member inattention'
insert into peak (peak_code, peak_domain_id) values (405536006, 'Observation'); --'Staff member ill'
insert into peak (peak_code, peak_domain_id) values (405502000, 'Observation'); --'Staff member distraction'
insert into peak (peak_code, peak_domain_id) values (398051009, 'Observation'); --Staff member fatigued
insert into peak (peak_code, peak_domain_id) values (398087002, 'Observation'); --Staff member inadequately assisted
insert into peak (peak_code, peak_domain_id) values (397976005, 'Observation'); --Staff member inadequately supervised
insert into peak (peak_code, peak_domain_id) values (162568000, 'Observation');--'Family not aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (162567005, 'Observation'); --'Family aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (42045007, 'Observation'); --Acceptance of illness
insert into peak (peak_code, peak_domain_id) values (108329005, 'Observation'); --	Social context condition
insert into peak (peak_code, peak_domain_id) values (309298003, 'Observation'); -- Drug therapy observations
insert into peak (peak_code, peak_domain_id) values (48340000, 'Condition'); --Incontinence
insert into peak (peak_code, peak_domain_id) values (108252007, 'Measurement'); --'Laboratory procedures'
insert into peak (peak_code, peak_domain_id) values (122869004, 'Measurement'); --'Measurement'
insert into peak (peak_code, peak_domain_id) values (118246004, 'Measurement');	-- 'Laboratory test finding' - child of excluded Sample observation
insert into peak (peak_code, peak_domain_id) values (71388002, 'Procedure'); --'Procedure'
insert into peak (peak_code, peak_domain_id) values (304252001, 'Procedure'); -- Resuscitate
insert into peak (peak_code, peak_domain_id) values (304253006, 'Procedure'); --DNR
insert into peak (peak_code, peak_domain_id) values (113021009, 'Procedure'); -- Cardiovascular measurement
insert into peak (peak_code, peak_domain_id) values (297249002, 'Observation'); --Family history of procedure
insert into peak (peak_code, peak_domain_id) values (14734007, 'Observation'); --Administrative procedure
insert into peak (peak_code, peak_domain_id) values (416940007, 'Observation'); --Past history of procedure
insert into peak (peak_code, peak_domain_id) values (183932001, 'Observation');-- Procedure contraindicated
insert into peak (peak_code, peak_domain_id) values (438833006, 'Observation');-- Administration of drug or medicament contraindicated
insert into peak (peak_code, peak_domain_id) values (442564008, 'Observation'); --Evaluation of urine specimen
insert into peak (peak_code, peak_domain_id) values (410684002, 'Observation'); -- Drug therapy status
insert into peak (peak_code, peak_domain_id) values (64108007, 'Procedure'); --Blood unit processing - inside Measurements
insert into peak (peak_code, peak_domain_id) values (17636008, 'Procedure'); -- Specimen collection treatments and procedures - - bad child of 4028908	Laboratory procedure
insert into peak (peak_code, peak_domain_id) values (365873007, 'Gender'); -- Gender
insert into peak (peak_code, peak_domain_id) values (372148003, 'Race'); --Ethnic group
insert into peak (peak_code, peak_domain_id) values (415229000, 'Race'); -- Racial group
insert into peak (peak_code, peak_domain_id) values (900000000000441003, 'Metadata'); -- SNOMED CT Model Component
insert into peak (peak_code, peak_domain_id) values (106237007, 'Observation'); -- Linkage concept
insert into peak (peak_code, peak_domain_id) values (258666001, 'Unit'); -- Top unit
insert into peak (peak_code, peak_domain_id) values (260245000, 'Meas Value'); -- Meas Value
insert into peak (peak_code, peak_domain_id) values (125677006, 'Relationship'); -- Relationship
insert into peak (peak_code, peak_domain_id) values (264301008, 'Observation'); -- psychoactive substance of abuse - non-pharmaceutical
insert into peak (peak_code, peak_domain_id) values (226465004, 'Observation'); -- drinks
insert into peak (peak_code, peak_domain_id) values (289964002, 'Device'); -- Surgical material
insert into peak (peak_code, peak_domain_id) values (260667007, 'Device'); -- Graft
insert into peak (peak_code, peak_domain_id) values (418920007, 'Device'); -- Adhesive agent
insert into peak (peak_code, peak_domain_id) values (255922001, 'Device'); -- Dental material
insert into peak (peak_code, peak_domain_id) values (413674002, 'Device'); -- Body material
insert into peak (peak_code, peak_domain_id) values (118417008, 'Device'); -- Filling material
insert into peak (peak_code, peak_domain_id) values (418920007, 'Device'); -- Adhesive agent
insert into peak (peak_code, peak_domain_id) values (255922001, 'Device'); -- dental material,
insert into peak (peak_code, peak_domain_id) values (118417008, 'Device'); -- filling material,
insert into peak (peak_code, peak_domain_id) values (289964002, 'Device'); -- surgical material, 
insert into peak (peak_code, peak_domain_id) values (445214009, 'Device'); -- corneal storage medium
insert into peak (peak_code, peak_domain_id) values (369443003, 'Device'); -- bedpan
insert into peak (peak_code, peak_domain_id) values (398146001, 'Device'); -- armband
insert into peak (peak_code, peak_domain_id) values (272181003, 'Device'); -- clinical equipment and/or device
insert into peak (peak_code, peak_domain_id) values (445316008, 'Device'); -- component of optical microscope
insert into peak (peak_code, peak_domain_id) values (419818001, 'Device'); -- Contact lens storage case
insert into peak (peak_code, peak_domain_id) values (228167008, 'Device'); -- Corset
insert into peak (peak_code, peak_domain_id) values (42380001, 'Device'); -- Ear plug, device
insert into peak (peak_code, peak_domain_id) values (1333003, 'Device'); -- Emesis basin, device
insert into peak (peak_code, peak_domain_id) values (360306007, 'Device'); -- Environmental control system
insert into peak (peak_code, peak_domain_id) values (33894003, 'Device'); -- Experimental device
insert into peak (peak_code, peak_domain_id) values (116250002, 'Device'); -- filter
insert into peak (peak_code, peak_domain_id) values (59432006, 'Device'); -- ligature
insert into peak (peak_code, peak_domain_id) values (360174002, 'Device'); -- nabeya capsule
insert into peak (peak_code, peak_domain_id) values (311767007, 'Device'); -- special bed
insert into peak (peak_code, peak_domain_id) values (360173008, 'Device'); -- watson capsule
insert into peak (peak_code, peak_domain_id) values (367561004, 'Device'); -- xenon arc photocoagulator

COMMIT;
-- 11.3. Ancestors inherit the domain_id and standard_concept of their Peaks. However, the ancestors of Peaks are overlapping.
-- Therefore, the order by which the inheritance is passed depends on the "height" in the hierarchy: The lower the peak, the later it should be run
-- The following creates the right order by counting the number of ancestors: The more ancestors the lower in the hierarchy.
-- This could go wrong if a parallel fork happens
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
   WHERE ranked is null
;
COMMIT;

-- 11.4. Find other peak concepts (orphans) that are missed from the above manual list, and assign them a domain_id based on heuristic. 
-- Peak concepts are those ancestors that are not also descendants somewhere, except in their own record
-- If there are mistakes, the manual list needs be updated and everything re-run
INSERT INTO peak -- before doing that check first out without the insert
   SELECT DISTINCT
          c.concept_code AS peak_code,
          CASE
             WHEN c.concept_class_id = 'Clinical finding'
             THEN
                'Condition'
             WHEN c.concept_class_id = 'Model component'
             THEN
                'Metadata'
             WHEN c.concept_class_id = 'Observable entity'
             THEN
                'Observation'
             WHEN c.concept_class_id = 'Organism'
             THEN
                'Observation'
             WHEN c.concept_class_id = 'Pharmaceutical / biologic product'
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

-- 11.5. Start building domains, preassign all them with "Not assigned"

CREATE TABLE domain_snomed
AS
   SELECT concept_code, CAST ('Not assigned' AS VARCHAR2 (20)) AS domain_id
     FROM concept_stage
    WHERE vocabulary_id = 'SNOMED';

-- 11.6. Pass out domain_ids
-- Method 1: Assign domains to children of peak concepts in the order rank, and within rank by order of precedence
-- Do that for all peaks by order of ranks. The highest first, the lower ones second, etc.

BEGIN
   FOR A IN (  SELECT DISTINCT ranked
                 FROM peak
                WHERE ranked IS NOT NULL
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
END;	
COMMIT;		

-- Method 2: For those that slipped through the cracks assign domains by using the class_concept_id
-- Check out which these are and potentially fix and re-run Method 1
UPDATE domain_snomed d
   SET d.domain_id =
          (SELECT CASE c.concept_class_id
                     WHEN 'Clinical Finding' THEN 'Condition'
                     WHEN 'Procedure' THEN 'Procedure'
                     WHEN 'Pharma/Biol Product' THEN 'Drug'
                     WHEN 'Physical Object' THEN 'Device'
                     WHEN 'Model comp' THEN 'Metadata'
                     ELSE 'Observation'
                  END
             FROM concept_stage c
            WHERE     c.concept_code = d.concept_code
                  AND C.VOCABULARY_ID = 'SNOMED')
 WHERE d.domain_id = 'Not assigned';
 COMMIT;
 
 -- 11.7. Update concept_stage from newly created domains.
CREATE INDEX idx_domain_cc
   ON domain_snomed (concept_code);
   
UPDATE concept_stage c
   SET c.domain_id =
          (SELECT d.domain_id
             FROM domain_snomed d
            WHERE d.concept_code = c.concept_code)
 WHERE C.VOCABULARY_ID = 'SNOMED';


UPDATE concept_stage c
   SET c.domain_id = 'Route'
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
       AND C.VOCABULARY_ID = 'SNOMED';

UPDATE concept_stage c
   SET c.domain_id = 'Spec Anatomic Site'
 WHERE concept_class_id = 'Body Structure' AND C.VOCABULARY_ID = 'SNOMED';

UPDATE concept_stage c
   SET c.domain_id = 'Specimen'
 WHERE concept_class_id = 'Specimen' AND C.VOCABULARY_ID = 'SNOMED';

UPDATE concept_stage c
   SET c.domain_id = 'Meas Value Operator'
 WHERE     concept_code IN ('276136004',
                            '276140008',
                            '276137008',
                            '276138003',
                            '276139006')
       AND C.VOCABULARY_ID = 'SNOMED';

UPDATE concept_stage c
   SET c.domain_id = 'Spec Disease Status'
 WHERE     concept_code IN ('21594007', '17621005', '263654008')
       AND C.VOCABULARY_ID = 'SNOMED';

COMMIT;

-- 11.8. Set standard_concept based on domain_id
UPDATE concept_stage c
   SET c.standard_concept =
          CASE c.domain_id
             WHEN 'Drug' THEN NULL                         -- Drugs are RxNorm
             WHEN 'Metadata' THEN NULL                      -- Not used in CDM
             WHEN 'Race' THEN NULL                             -- Race are CDC
             WHEN 'Provider Specialty' THEN NULL
             WHEN 'Place of Service' THEN NULL
             WHEN 'Unit' THEN NULL                           -- Units are UCUM
             ELSE 'S'
          END
 WHERE C.VOCABULARY_ID = 'SNOMED';
COMMIT;

--12------ run Vocabulary-v5.0\generic_update.sql ---------------