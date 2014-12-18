--1. create copies of main files
truncate table concept;
truncate table concept_relationship;
truncate table concept_synonym;
insert into concept select * from v5dev.concept;
commit;
insert into concept_relationship select * from v5dev.concept_relationship;
commit;
insert into concept_synonym select * from v5dev.concept_synonym;
commit;

--1.1 clear *_stage tables and drop views
truncate table CONCEPT_STAGE;
truncate table concept_relationship_stage;
truncate table concept_synonym_stage;
drop view sct2_concept_full_merged;
drop view sct2_desc_full_merged;
drop view sct2_rela_full_merged;
drop view der2_cRefset_AssRefFull_merged;
drop table read_domains;

--2. create core files of Read
--3. fill CONCEPT_STAGE and concept_relationship_stage from Read
INSERT INTO CONCEPT_STAGE (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT DISTINCT
	      NULL,
          coalesce(kv2.description_long, kv2.description, kv2.description_short),
          NULL,
          'Read',
          'Read',
          NULL,
          kv2.readcode || kv2.termcode,
          TO_DATE ('20141001', 'yyyymmdd'),
          TO_DATE ('20991231', 'yyyymmdd'),
          NULL
     FROM keyv2 kv2;

COMMIT;

INSERT INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        relationship_id,
										vocabulary_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT
          NULL,
          NULL,
          RSCCT.ReadCode || RSCCT.TermCode,
          -- pick the best map: mapstatus=1, then is_assured=1, then target concept is fresh, then newest date
          FIRST_VALUE (
             RSCCT.conceptid)
          OVER (
             PARTITION BY RSCCT.readcode || RSCCT.termcode
             ORDER BY
                RSCCT.mapstatus DESC,
                RSCCT.is_assured DESC,
                RSCCT.effectivedate DESC),
          'Maps to',
		  'Read',
          TO_DATE ('20141001', 'yyyymmdd'),
          TO_DATE ('20991231', 'yyyymmdd'),
          NULL
     FROM RCSCTMAP2_UK RSCCT;
COMMIT;

--4. create core files of RxNorm
--5. fill CONCEPT_STAGE and concept_synonym_stage from RxNorm
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
   SELECT SUBSTR (str, 1, 256),
          'RxNorm',
          'Drug',
          CASE tty                    -- use RxNorm tty as for Concept Classes
             WHEN 'IN' THEN 'Ingredient'
             WHEN 'DF' THEN 'Dose Form'
             WHEN 'SCDC' THEN 'Clinical Drug Comp'
             WHEN 'SCDF' THEN 'Clinical Drug Form'
             WHEN 'SCD' THEN 'Clinical Drug'
             WHEN 'BN' THEN 'Brand Name'
             WHEN 'SBDC' THEN 'Branded Drug Comp'
             WHEN 'SBDF' THEN 'Branded Drug Form'
             WHEN 'SBD' THEN 'Branded Drug'
          END,
          CASE tty -- only Ingredients, drug components, drug forms, drugs and packs are standard concepts
                  WHEN 'DF' THEN NULL WHEN 'BN' THEN NULL ELSE 'S' END,
          rxcui,                                    -- the code used in RxNorm
          TO_DATE ('01.12.2014', 'dd.mm.yyyy'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM rxnconso
    WHERE     sab = 'RXNORM'
          AND tty IN ('IN',
                      'DF',
                      'SCDC',
                      'SCDF',
                      'SCD',
                      'BN',
                      'SBDC',
                      'SBDF',
                      'SBD');


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
   SELECT SUBSTR (str, 1, 256),
          'RxNorm',
          'Drug',
          CASE tty                    -- use RxNorm tty as for Concept Classes
             WHEN 'BPCK' THEN 'Branded Pack'
             WHEN 'GPCK' THEN 'Clinical Pack'
          END,
          'S',
          code,                                        -- Cannot use rxcui here
          TO_DATE ('01.12.2014', 'dd.mm.yyyy'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL          
     FROM rxnconso
    WHERE sab = 'RXNORM' AND tty IN ('BPCK', 'GPCK');

commit;	

--Add synonyms
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   language_concept_id)
   SELECT null,rxcui, SUBSTR (r.str, 1, 255), 4093769                    -- English
     FROM rxnconso r
          JOIN concept_stage c
             ON     c.concept_code = r.rxcui
                AND NOT c.concept_class_id IN ('Clinical Pack',
                                               'Branded Pack')
    WHERE sab = 'RXNORM' AND tty = 'SY';

INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   language_concept_id)
   SELECT null,rxcui, SUBSTR (r.str, 1, 255), 4093769                    -- English
     FROM rxnconso r
          JOIN concept_stage c
             ON     c.concept_code = r.code
                AND c.concept_class_id IN ('Clinical Pack', 'Branded Pack')
    WHERE sab = 'RXNORM' AND tty = 'SY';    

	
--6. create core files of SNOMED
--7. fill CONCEPT_STAGE and concept_synonym_stage from SNOMED	

create view sct2_concept_full_merged as select * from sct2_concept_full_int union select * from sct2_concept_full_uk;
create view sct2_desc_full_merged as select * from sct2_desc_full_en_int union select * from sct2_desc_full_uk;
create view sct2_rela_full_merged as select * from sct2_rela_full_int union select * from sct2_rela_full_uk;
create view der2_cRefset_AssRefFull_merged as select * from der2_cRefset_AssRefFull_INT union select * from der2_cRefset_AssRefFull_UK;

--Create core version of SNOMED without concept_id, domain_id, concept_class_id, standard_concept
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
	

-- Create temporary table with extracted class information and terms ordered by some good precedence
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
	
-- Create reduced set of classes 
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
	
DROP TABLE tmp_concept_class PURGE;
			
--Choice of concept_name in SNOMED and synonyms
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

	   
-- Get all the other ones in ('PT', 'PTGB', 'SY', 'SYGB', 'MTH_PT', 'FN', 'MTH_SY', 'SB') into concept_synonym_stage
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   language_concept_id)
   SELECT NULL,
          m.code,
          SUBSTR (m.str, 1, 256),
          4093769 -- English
     FROM mrconso m LEFT JOIN mrconso_tmp m_tmp ON m.aui = m_tmp.aui
    WHERE m.sab = 'SNOMEDCT_US' AND m_tmp.aui IS NULL;

DROP TABLE mrconso_tmp PURGE;


--8. fill concept_relationship_stage from SNOMED	
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        relationship_id,
										vocabulary_id,
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
          TO_DATE ('01.12.2014', 'dd.mm.yyyy'),--release date
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM (SELECT * FROM tmp_rel);

COMMIT;	 
--add replacement relationships. They are handled in a different SNOMED table
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        relationship_id,
										vocabulary_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT concept_code_1,
          concept_code_2,
          relationship_id,
		  'SNOMED',
          TO_DATE ('01.12.2014', 'dd.mm.yyyy'),                 --release date
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

--Make sure all records are symmetrical and turn if necessary

INSERT INTO concept_relationship_stage
   SELECT crs.concept_id_2 AS concept_id_1,
          crs.concept_id_1 AS concept_id_2,
          CRS.CONCEPT_CODE_2 AS CONCEPT_CODE_1,
          CRS.CONCEPT_CODE_1 AS CONCEPT_CODE_2,
          r.reverse_relationship_id AS relationship_id,
		  crs.vocabulary_id,
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
					 AND crs.vocabulary_id=i.vocabulary_id)
    AND crs.vocabulary_id='SNOMED';

COMMIT;

	
--9. start building the hierarchy (snomed-only)
exec PKG_CONCEPT_ANCESTOR.CALC;
commit;

--10. start creating domain_id (Vocabulary-v5.0\01-SNOMED\Update_domain_snomed.sql)			   
-- 10.1. Manually create table with "Peaks" = ancestors of records that are all of the same domain
drop table peak;
create table peak (
	peak_code varchar(20), --the id of the top ancestor
	peak_domain_id varchar(20), -- the domain to assign to all its children
	ranked integer -- number for the order in which to assign
);

-- Fill in the various peak concepts
insert into peak (peak_code, peak_domain_id) values (243796009, 'Observation'); -- 'Context-dependent category' that has no ancestor
insert into peak (peak_code, peak_domain_id) values (138875005, 'Observation'); -- root
insert into peak (peak_code, peak_domain_id) values (223366009, 'Provider Specialty');
insert into peak (peak_code, peak_domain_id) values (43741000, 'Place of Service');	  -- Site of care
insert into peak (peak_code, peak_domain_id) values (420056007, 'Drug'); -- Aromatherapy agent
insert into peak (peak_code, peak_domain_id) values (373873005, 'Drug'); -- Pharmaceutical / biologic product
insert into peak (peak_code, peak_domain_id) values (410942007, 'Drug'); --	Drug or medicament
insert into peak (peak_code, peak_domain_id) values (49062001, 'Device');
insert into peak (peak_code, peak_domain_id) values (289964002, 'Device'); -- Surgical material
insert into peak (peak_code, peak_domain_id) values (260667007, 'Device'); -- Graft
insert into peak (peak_code, peak_domain_id) values (418920007, 'Device'); -- Adhesive agent
insert into peak (peak_code, peak_domain_id) values (404684003, 'Condition'); -- Clinical Finding
insert into peak (peak_code, peak_domain_id) values (218496004, 'Condition'); -- Adverse reaction to primarily systemic agents
insert into peak (peak_code, peak_domain_id) values (313413008, 'Condition'); -- Calculus observation
insert into peak (peak_code, peak_domain_id) values (118245000, 'Measurement'); -- 'Finding by measurement'
insert into peak (peak_code, peak_domain_id) values (365854008, 'Observation'); -- 'History finding'
insert into peak (peak_code, peak_domain_id) values (118233009, 'Observation'); -- 'Finding of activity of daily living'
insert into peak (peak_code, peak_domain_id) values (307824009, 'Observation');-- 'Administrative statuses'
		-- 40416814, 'Observation'); Causes of injury and poisoning'
		-- 40418184,  -- '[X]External causes of morbidity and mortality'
insert into peak (peak_code, peak_domain_id) values (162408000, 'Observation'); -- Symptom description
-- insert into peak (peak_code, peak_domain_id) values (4084137,	'Observation');-- Sample observation
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
-- insert into peak (peak_code, peak_domain_id) values (4025202, 'Condition'); --Elimination pattern
-- insert into peak (peak_code, peak_domain_id) values (4186437, 'Condition'); -- Urinary elimination alteration
--		4266236, 'Observation'); --'Cancer-related substance' - 4228508
insert into peak (peak_code, peak_domain_id) values (108252007, 'Measurement'); --'Laboratory procedures'
insert into peak (peak_code, peak_domain_id) values (122869004, 'Measurement'); --'Measurement'
-- 		4236002, 'Observation'); --'Allergen class'
-- 		4019381, 'Observation'); --'Biological substance'
--		4240422 -- 'Human body substance'
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

-- 10.2. Ancestors inherit the domain_id and standard_concept of their Peaks. However, the ancestors of Peaks are overlapping.
-- Therefore, the order by which the inheritance is passed depends on the "height" in the hierarchy: The lower the peak, the later it should be run
-- The following creates the right order by counting the number of ancestors: The more ancestors the lower in the hierarchy.
-- This could go wrong if a parallel fork happens
UPDATE peak p
   SET p.ranked =
          (SELECT rnk
             FROM (  SELECT ranked.pd AS peak_code, COUNT (*) AS rnk
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

-- 10.3. Find clashes, where one child has two or more Peak concepts as ancestors and display them with ordered by levels of separation
-- Currently these clashes are dealt with by precedence, not through rank. This might need to change
-- Also, this script needs to do this within a rank. Not done yet.
SELECT conflict.concept_name AS child,
         min_levels_of_separation AS MIN,
         d.peak_domain_id,
         c.concept_name AS peak,
         c.concept_class_id AS peak_class_id
    FROM snomed_ancestor a,
         concept_stage c,
         peak d,
         concept_stage conflict
   WHERE     a.descendant_concept_code IN (SELECT concept_code
                                             FROM (  SELECT child.concept_code,
                                                            COUNT (*)
                                                       FROM (SELECT DISTINCT
                                                                    p.peak_domain_id,
                                                                    a.descendant_concept_code
                                                                       AS concept_code
                                                               FROM peak p,
                                                                    snomed_ancestor a
                                                              WHERE a.ancestor_concept_code =
                                                                    p.peak_code)
                                                            child
                                                   GROUP BY child.concept_code
                                                     HAVING COUNT (*) > 1)
                                                  clash)
         AND c.concept_code = a.ancestor_concept_code
         AND c.concept_code = d.peak_code
		 AND c.vocabulary_id='SNOMED'
         AND conflict.concept_code = a.descendant_concept_code
ORDER BY conflict.concept_name, min_levels_of_separation, c.concept_name;

-- 10.4. Find other peak concepts (orphans) that are missed from the above manual list, and assign them a domain_id based on heuristic. 
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
                'Manual'
          END
             AS peak_domain_id,
          NULL AS ranked
     FROM snomed_ancestor a, concept_stage c
    WHERE     a.ancestor_concept_code NOT IN (SELECT DISTINCT
                                                     descendant_concept_code
                                                FROM snomed_ancestor
                                               WHERE ancestor_concept_code !=
                                                        descendant_concept_code)
          AND c.concept_code = a.ancestor_concept_code
          AND c.vocabulary_id='SNOMED';


-- 10.5. Start building domains, preassign all them with "Not assigned"
DROP TABLE domain_snomed purge;

CREATE TABLE domain_snomed
AS
   SELECT concept_code, CAST ('Not assigned' AS VARCHAR2 (20)) AS domain_id
     FROM concept_stage
    WHERE vocabulary_id = 'SNOMED';

-- 10.6. Pass out domain_ids
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

   COMMIT;
END;


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

-- 10.7. Update concept_stage from newly created domains.

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
   SET c.domain_id = 'Spec Disease Status'
 WHERE     concept_code IN ('21594007', '17621005', '263654008')
       AND C.VOCABULARY_ID = 'SNOMED';

COMMIT;
-- 10.8. Set standard_concept based on domain_id
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

------------------need rewrite code below!!----------

--11. fill in all concept_id_1 and _2 in concept_relationship_stage
CREATE INDEX idx_concept_code_1
   ON concept_relationship_stage (concept_code_1);
CREATE INDEX idx_concept_code_2
   ON concept_relationship_stage (concept_code_2);

/*   depricate
UPDATE concept_relationship_stage crs
   SET (crs.concept_id_1, crs.concept_id_2) =
          (SELECT DISTINCT
                  COALESCE (cs1.concept_id, c1.concept_id,crs.concept_id_1),
                  COALESCE (cs2.concept_id, c2.concept_id,crs.concept_id_2)
             FROM concept_relationship_stage r
                  LEFT JOIN concept_stage cs1
                     ON cs1.concept_code = r.concept_code_1
                  LEFT JOIN concept c1 ON c1.concept_code = r.concept_code_1
                  LEFT JOIN concept_stage cs2
                     ON cs2.concept_code = r.concept_code_2
                  LEFT JOIN concept c2 ON c2.concept_code = r.concept_code_2
            WHERE     c1.vocabulary_id = cs1.vocabulary_id
                  AND crs.concept_code_1 = r.concept_code_1
                  AND c2.vocabulary_id = cs2.vocabulary_id
                  AND crs.concept_code_2 = r.concept_code_2
                  AND c1.vocabulary_id = c2.vocabulary_id)
 WHERE crs.concept_id_1 IS NULL OR crs.concept_id_2 IS NULL;
 */
 
 --probably requires to be rewritten
 UPDATE concept_relationship_stage crs
   SET (crs.concept_id_1, crs.concept_id_2) =
          (SELECT DISTINCT
                  COALESCE (cs1.concept_id, c1.concept_id,crs.concept_id_1),
                  COALESCE (cs2.concept_id, c2.concept_id,crs.concept_id_2)
             FROM concept_relationship_stage r
                  LEFT JOIN concept_stage cs1
                     ON cs1.concept_code = r.concept_code_1 and cs1.vocabulary_id=r.vocabulary_id
                  LEFT JOIN concept c1 ON c1.concept_code = r.concept_code_1 and c1.vocabulary_id=r.vocabulary_id
                  LEFT JOIN concept_stage cs2
                     ON cs2.concept_code = r.concept_code_2 and cs2.vocabulary_id=r.vocabulary_id
                  LEFT JOIN concept c2 ON c2.concept_code = r.concept_code_2 and c2.vocabulary_id=r.vocabulary_id
            WHERE      nvl(crs.concept_code_1,-1) = nvl(r.concept_code_1,-1)
                  AND nvl(crs.concept_code_2,-1) = nvl(r.concept_code_2,-1)
                  
         )
 WHERE crs.concept_id_1 IS NULL OR crs.concept_id_2 IS NULL; 
 COMMIT;
 
 --12. update domains

 --12.1. create temporary table read_domains
create table read_domains as
    select concept_code,   
    case when domains='Measurement/Procedure' then 'Meas/Procedure'
        when domains='Condition/Measurement' then 'Condition/Meas'
        when domains='Condition/Observation/Spec Anatomic Site' then 'Condition'
        when domains='Condition/Spec Anatomic Site' then 'Condition'
        when domains='Device/Observation/Procedure/Spec Anatomic Site' then 'Procedure'
        when domains='Observation/Procedure/Spec Anatomic Site' then 'Procedure'
        else domains
    end domains from (
        select concept_code, LISTAGG(domain_id, '/') WITHIN GROUP (order by domain_id) domains from (
               SELECT c1.concept_code, c2.domain_id
                FROM concept_relationship_stage r, concept_stage c1, concept c2
                WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
                AND c1.vocabulary_id='Read' AND c2.vocabulary_id='SNOMED'
				AND r.vocabulary_id in ('Read','SNOMED')
                UNION
                SELECT SUBSTR(c1.concept_code, 1, 6) AS concept_code, c2.domain_id
                FROM concept_relationship_stage r, concept_stage c1, concept c2
                WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
                AND c1.vocabulary_id='Read' AND c2.vocabulary_id='SNOMED'
				AND r.vocabulary_id in ('Read','SNOMED')
                UNION
                SELECT SUBSTR(c1.concept_code, 1, 5) AS concept_code, c2.domain_id
                FROM concept_relationship_stage r, concept_stage c1, concept c2
                WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
                AND c1.vocabulary_id='Read' AND c2.vocabulary_id='SNOMED'
				AND r.vocabulary_id in ('Read','SNOMED')
                UNION
                SELECT SUBSTR(c1.concept_code, 1, 4) AS concept_code, c2.domain_id
                FROM concept_relationship_stage r, concept_stage c1, concept c2
                WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
                AND c1.vocabulary_id='Read' AND c2.vocabulary_id='SNOMED'
				AND r.vocabulary_id in ('Read','SNOMED')
                UNION
                SELECT SUBSTR(c1.concept_code, 1, 3) AS concept_code, c2.domain_id
                FROM concept_relationship_stage r, concept_stage c1, concept c2
                WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
                AND c1.vocabulary_id='Read' AND c2.vocabulary_id='SNOMED'
				AND r.vocabulary_id in ('Read','SNOMED')
        )
        group by concept_code
);      

CREATE INDEX idx_read_domains ON read_domains (concept_code);

--12.2. Simplify the list by removing Observations where is Measurement, Meas Value, Speciment, Spec Anatomic Site, Relationship
update read_domains set domains=trim('/' FROM replace('/'||domains||'/','/Observation/','/'))
where '/'||domains||'/' like '%/Observation/%'
and instr(domains,'/')<>0;


--check for new domains:
select domains from read_domains 
minus
select domain_id from domain;

--12.3. update each domain_id with the domains field from read_domains. If null take the 6-letter code, if still null take the 5-letter code etc.
update concept_stage cs set (domain_id)=
    (select coalesce(d7.domains, d6.domains, d5.domains, d4.domains, d3.domains, 'Observation')
    from concept_stage c
    left join read_domains d7 on d7.concept_code=c.concept_code
    left join read_domains d6 on d6.concept_code=substr(c.concept_code, 1, 6)
    left join read_domains d5 on d5.concept_code=substr(c.concept_code, 1, 5)
    left join read_domains d4 on d4.concept_code=substr(c.concept_code, 1, 4)
    left join read_domains d3 on d3.concept_code=substr(c.concept_code, 1, 3)
    where c.CONCEPT_CODE=cs.CONCEPT_CODE
    and c.vocabulary_id=cs.vocabulary_id
) where cs.vocabulary_id='Read';   

COMMIT;

--13. update concept from concept_stage 
 -- Fill concept_id where concept exists
update concept_stage cs
set cs.concept_id=(select c.concept_id from concept c where c.concept_code=cs.concept_code and c.vocabulary_id=cs.vocabulary_id)
where cs.concept_id is null;
commit;

-- Add existing concept_names to synonym (unless already exists) if being overwritten with a new one
insert into concept_synonym
select
    c.concept_id,
    c.concept_name concept_synonym_name,
    4093769 language_concept_id -- English
from concept_stage cs, concept c
where c.concept_id=cs.concept_id and c.concept_name<>cs.concept_name
and not exists (select 1 from concept_synonym where concept_synonym_name=c.concept_name); -- synonym already exists

commit;

-- Update concepts
UPDATE concept c
SET (concept_name, domain_id,concept_class_id,standard_concept,valid_end_date) = (
  SELECT coalesce(cs.concept_name, c.concept_name), coalesce(cs.domain_id, c.domain_id),
  coalesce(cs.concept_class_id, c.concept_class_id),coalesce(cs.standard_concept, c.standard_concept), 
  coalesce(cs.valid_end_date, c.valid_end_date)
  FROM concept_stage cs
  WHERE c.concept_id=cs.concept_id)
where  concept_id in (select concept_id from concept_stage);
commit;

-- Deprecate missing concepts
update concept c set
c.valid_end_date = c.valid_start_date-1
where not exists (select 1 from concept_stage cs where cs.concept_id=c.concept_id and cs.vocabulary_id=c.vocabulary_id);
commit;

-- set invalid_reason for active concepts
update concept set
invalid_reason=null
where valid_end_date = to_date('31.12.2099','dd.mm.yyyy');
commit;

-- set invalid_reason for deprecated concepts
update concept set
invalid_reason='D'
where invalid_reason is null -- unless is already set
and valid_end_date <> to_date('31.12.2099','dd.mm.yyyy');
commit;

-- Add new concepts
INSERT INTO concept (concept_id,
                     concept_name,
                     domain_id,
                     vocabulary_id,
                     concept_class_id,
                     standard_concept,
                     concept_code,
                     valid_start_date,
                     valid_end_date,
                     invalid_reason)
   SELECT v5_concept.NEXTVAL,
          cs.concept_name,
          cs.domain_id,
          cs.vocabulary_id,
          cs.concept_class_id,
          cs.standard_concept,
          cs.concept_code,
          COALESCE (cs.valid_start_date,
                    TO_DATE ('01.01.1970', 'dd.mm.yyyy')),
          COALESCE (cs.valid_end_date, TO_DATE ('31.12.2099', 'dd.mm.yyyy')),
          NULL
     FROM concept_stage cs
    WHERE cs.concept_id IS NULL;
	


 --Update all relationships existing in concept_relationship_stage, including undeprecation of formerly deprecated ones
 CREATE INDEX idx_concept_id_1
   ON concept_relationship_stage (concept_id_1);
CREATE INDEX idx_concept_id_2
   ON concept_relationship_stage (concept_id_2);

UPDATE concept_relationship d
   SET (d.valid_end_date, d.invalid_reason) =
          (SELECT distinct crs.valid_end_date, crs.invalid_reason
             FROM concept_relationship_stage crs
            WHERE     crs.concept_id_1 = d.concept_id_1
                  AND crs.concept_id_2 = d.concept_id_2
                  AND crs.relationship_id = d.relationship_id)
 WHERE EXISTS
          (SELECT 1
             FROM concept_relationship_stage r
            -- test whether either the concept_ids match
            WHERE     d.concept_id_1 = r.concept_id_1
                  AND d.concept_id_2 = r.concept_id_2
                  AND d.relationship_id = r.relationship_id);
 
commit; 
--Deprecate missing relationships, but only if the concepts exist.
-- If relationships are missing because of deprecated concepts, leave them intact
--Do it with all vocabulary (Read, SNOMED, RxNorm), but with his own release day
--SNOMED
UPDATE concept_relationship d
   SET valid_end_date = to_date('20141130', 'YYYYMMDD'), -- day before release day
       invalid_reason = 'D'
 WHERE     NOT EXISTS
              (SELECT 1
                 FROM concept_relationship_stage r
                -- test whether either the concept_ids match, or the concept_ids matched to the concept_codes in either stage or dev
                WHERE     d.concept_id_1 = r.concept_id_1
                      AND d.concept_id_2 = r.concept_id_2
                      AND d.relationship_id = r.relationship_id)

       AND d.valid_end_date = TO_DATE ('20991231', 'YYYYMMDD') -- deprecate those that are fresh and active
       AND d.valid_start_date < TO_DATE ('20141130', 'YYYYMMDD') -- started before release date
       -- exclude replacing relationships, usually they are not maintained after a concept died
       AND d.relationship_id NOT IN ('UCUM replaced by',
                                     'UCUM replaces',
                                     'Concept replaced by',
                                     'Concept replaces',
                                     'Concept same_as to',
                                     'Concept same_as from',
                                     'Concept alt_to to',
                                     'Concept alt_to from',
                                     'Concept poss_eq to',
                                     'Concept poss_eq from',
                                     'Concept was_a to',
                                     'Concept was_a from',
                                     'LOINC replaced by',
                                     'LOINC replaces',
                                     'RxNorm replaced by',
                                     'RxNorm replaces',
                                     'SNOMED replaced by',
                                     'SNOMED replaces',
                                     'ICD9P replaced by',
                                     'ICD9P replaces') -- check for existence of both concept_id_1 and concept_id_2
       AND EXISTS
              (SELECT 1
                 FROM concept_stage c
                WHERE c.concept_id = d.concept_id_1 and C.VOCABULARY_ID='SNOMED' )
       AND EXISTS
              (SELECT 1
                 FROM concept_stage c
                WHERE c.concept_id = d.concept_id_2 and C.VOCABULARY_ID='SNOMED');            

--Read
UPDATE concept_relationship d
   SET valid_end_date = to_date('20141130', 'YYYYMMDD'), -- day before release day
       invalid_reason = 'D'
 WHERE     NOT EXISTS
              (SELECT 1
                 FROM concept_relationship_stage r
                -- test whether either the concept_ids match, or the concept_ids matched to the concept_codes in either stage or dev
                WHERE     d.concept_id_1 = r.concept_id_1
                      AND d.concept_id_2 = r.concept_id_2
                      AND d.relationship_id = r.relationship_id)

       AND d.valid_end_date = TO_DATE ('20991231', 'YYYYMMDD') -- deprecate those that are fresh and active
       AND d.valid_start_date < TO_DATE ('20140930', 'YYYYMMDD') -- started before release date
       -- exclude replacing relationships, usually they are not maintained after a concept died
       AND d.relationship_id NOT IN ('UCUM replaced by',
                                     'UCUM replaces',
                                     'Concept replaced by',
                                     'Concept replaces',
                                     'Concept same_as to',
                                     'Concept same_as from',
                                     'Concept alt_to to',
                                     'Concept alt_to from',
                                     'Concept poss_eq to',
                                     'Concept poss_eq from',
                                     'Concept was_a to',
                                     'Concept was_a from',
                                     'LOINC replaced by',
                                     'LOINC replaces',
                                     'RxNorm replaced by',
                                     'RxNorm replaces',
                                     'SNOMED replaced by',
                                     'SNOMED replaces',
                                     'ICD9P replaced by',
                                     'ICD9P replaces') -- check for existence of both concept_id_1 and concept_id_2
       AND EXISTS
              (SELECT 1
                 FROM concept_stage c
                WHERE c.concept_id = d.concept_id_1 and C.VOCABULARY_ID='Read' )
       AND EXISTS
              (SELECT 1
                 FROM concept_stage c
                WHERE c.concept_id = d.concept_id_2 and C.VOCABULARY_ID='Read');                  
				

commit;				
--insert new relationships
INSERT INTO concept_relationship (concept_id_1,
                                  concept_id_2,
                                  relationship_id,
                                  valid_start_date,
                                  valid_end_date,
                                  invalid_reason)
   SELECT distinct crs.concept_id_1,
          crs.concept_id_2,
          crs.relationship_id,
          TO_DATE ('20141201', 'YYYYMMDD') AS valid_start_date,
          TO_DATE ('20991231', 'YYYYMMDD') AS valid_end_date,
          NULL AS invalid_reason
     FROM concept_relationship_stage crs
    WHERE NOT EXISTS
             (SELECT 1
                FROM concept_relationship r
               -- test whether either the concept_ids match, or the concept_ids matched to the concept_codes in either stage or dev
               WHERE     crs.concept_id_1 = r.concept_id_1
                     AND crs.concept_id_2 = r.concept_id_2
                     AND crs.relationship_id = r.relationship_id);

commit;	
	
 
