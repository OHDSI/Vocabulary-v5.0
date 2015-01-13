-- 1. Update latest_update field to new date 
update vocabulary set latest_update=to_date('20140731','yyyymmdd') where vocabulary_id='SNOMED'; commit;

-- 2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
ALTER SESSION SET SKIP_UNUSABLE_INDEXES = TRUE; --disables error reporting of indexes and index partitions marked UNUSABLE
ALTER INDEX idx_cs_concept_code UNUSABLE;
ALTER INDEX idx_cs_concept_id UNUSABLE;
ALTER INDEX idx_concept_code_1 UNUSABLE;
ALTER INDEX idx_concept_code_2 UNUSABLE;

-- 3. Create core version of SNOMED without concept_id, domain_id, concept_class_id, standard_concept
INSERT INTO concept_stage (concept_name,
                           vocabulary_id,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT regexp_replace(coalesce(umls.concept_name, sct2.concept_name), ' \(.*?\)$', ''), -- pick the umls one first (if there) and trim something like "(procedure)"
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
                        CASE WHEN term LIKE '%(%)%' THEN 1 ELSE 0 END)
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
             FROM mrconso
            WHERE sab = 'SNOMEDCT_US'
              AND tty in ('PT', 'PTGB', 'SY', 'SYGB', 'MTH_PT', 'FN', 'MTH_SY', 'SB')
        ) umls
          ON sct2.concept_code = umls.concept_code
    WHERE sct2.rn = 1 AND sct2.active = 1;
COMMIT;	
	
-- 4. Create temporary table with extracted class information and terms ordered by some good precedence
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
	
CREATE INDEX x_cc_2cd ON tmp_concept_class (concept_code);

-- 5. Create reduced set of classes 
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
	WHERE cs.vocabulary_id='SNOMED';

-- Clean up
DROP TABLE tmp_concept_class PURGE;

-- Assign top SNOMED concept
UPDATE concept_stage set concept_class_id='Model Comp' WHERE concept_code=138875005 and vocabulary_id='SNOMED';
			
-- 6. Get all the other ones in ('PT', 'PTGB', 'SY', 'SYGB', 'MTH_PT', 'FN', 'MTH_SY', 'SB') into concept_synonym_stage
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_vocabulary_id,
                                   synonym_name,
                                   language_concept_id)
   SELECT DISTINCT 
          NULL,
          m.code,
          'SNOMED',
          SUBSTR (m.str, 1, 1000),
          4093769 -- English
     FROM mrconso m
    WHERE m.sab = 'SNOMEDCT_US' AND m.tty in ('PT', 'PTGB', 'SY', 'SYGB', 'MTH_PT', 'FN', 'MTH_SY', 'SB')
;

COMMIT;

-- 7. Fill concept_relationship_stage from SNOMED	
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
								                    		vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
WITH tmp_rel AS (   -- get relationships from latest records that are active
      SELECT DISTINCT sourceid, destinationid, replace(term,' (attribute)','') term
        FROM (SELECT r.sourceid,
                     r.destinationid,
                     d.term,
                     ROW_NUMBER ()
                     OVER (
                        PARTITION BY r.id
                        ORDER BY TO_DATE (r.effectivetime, 'YYYYMMDD') DESC
                     ) AS rn, -- get the latest in a sequence of relationships, to decide wether it is still active
                    r.active
                FROM sct2_rela_full_merged r
                     JOIN sct2_desc_full_merged d ON r.typeid = d.conceptid
              )
       WHERE rn = 1
             AND active = 1
             AND sourceid IS NOT NULL
             AND destinationid IS NOT NULL
             AND term<>'PBCL flag true'
)
 --convert SNOMED to OMOP-type relationship_id   
 SELECT DISTINCT
        sourceid,
        destinationid,
        'SNOMED',
        'SNOMED',
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
            WHEN term = 'Intent' THEN 'Has intent'
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
            ELSE 'non-existing'      
        END AS relationship_id,
        (select latest_update From vocabulary where vocabulary_id='SNOMED'),
        TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
        NULL
   FROM (SELECT * FROM tmp_rel)
;

COMMIT;

-- 8. add replacement relationships. They are handled in a different SNOMED table
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                    		vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT
          concept_code_1,
          concept_code_2,
          'SNOMED',
          'SNOMED',
          relationship_id,
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
                               900000000000523009,
                               900000000000528000,
                               900000000000527005,
                               900000000000530003))
    WHERE rn = 1 AND active = 1;

COMMIT;

-- 9. Create mapping to self for fresh concepts
INSERT INTO concept_relationship_stage (
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
SELECT 
  concept_code,
  concept_code,
  'SNOMED',
  'SNOMED',
  'Maps to',
  (SELECT latest_update FROM vocabulary WHERE vocabulary_id='SNOMED'),
  TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
  NULL
FROM concept_stage
;

-- 10. Add mapping from deprecated to fresh concepts
INSERT INTO concept_relationship_stage (
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
SELECT 
  root,
  concept_code_2,
  'SNOMED',
  'SNOMED',
  'Maps to',
  (SELECT latest_update FROM vocabulary WHERE vocabulary_id='SNOMED'),
  TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
  NULL
FROM (
      SELECT root, concept_code_2 FROM (
          SELECT root, concept_code_2, dt,  ROW_NUMBER() OVER (PARTITION BY root ORDER BY dt DESC) rn
            FROM (
                SELECT 
                      rownum AS rn, 
                      LEVEL AS lv, 
                      concept_code_1, 
                      concept_code_2, 
                      relationship_id,
                      valid_start_date AS dt,
                      CONNECT_BY_ISCYCLE AS iscy,
                      CONNECT_BY_ROOT concept_code_1 AS root,
                      CONNECT_BY_ISLEAF AS lf
                FROM concept_relationship_stage
                WHERE 1 = 1
                      AND relationship_id IN ( 'UCUM replaced by',
                                               'Concept replaced by',
                                               'Concept same_as to',
                                               'Concept alt_to to',
                                               'Concept poss_eq to',
                                               'Concept was_a to',
                                               'LOINC replaced by',
                                               'RxNorm replaced by',
                                               'SNOMED replaced by',
                                               'ICD9P replaced by'
                                             )
                      and NVL(invalid_reason, 'X') <> 'D'
                CONNECT BY  
                NOCYCLE  
                PRIOR concept_code_2 = concept_code_1
                      AND relationship_id IN ( 'UCUM replaced by',
                                               'Concept replaced by',
                                               'Concept same_as to',
                                               'Concept alt_to to',
                                               'Concept poss_eq to',
                                               'Concept was_a to',
                                               'LOINC replaced by',
                                               'RxNorm replaced by',
                                               'SNOMED replaced by',
                                               'ICD9P replaced by'
                                             )
                        AND NVL(invalid_reason, 'X') <> 'D'
                START WITH relationship_id IN ('UCUM replaced by',
                                               'Concept replaced by',
                                               'Concept same_as to',
                                               'Concept alt_to to',
                                               'Concept poss_eq to',
                                               'Concept was_a to',
                                               'LOINC replaced by',
                                               'RxNorm replaced by',
                                               'SNOMED replaced by',
                                               'ICD9P replaced by'
                                              )
                      AND NVL(invalid_reason, 'X') <> 'D'
          ) sou 
          WHERE lf = 1
      ) 
      WHERE rn = 1
);

COMMIT;

-- 11. Make sure all records are symmetrical and turn if necessary
INSERT INTO concept_relationship_stage (
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
   SELECT crs.concept_code_2,
          crs.concept_code_1,
          crs.vocabulary_id_2,
          crs.vocabulary_id_1,
          r.reverse_relationship_id ,
          crs.valid_start_date,
          crs.valid_end_date,
          crs.invalid_reason
     FROM concept_relationship_stage crs
          JOIN relationship r ON r.relationship_id = crs.relationship_id
    WHERE NOT EXISTS
             (                                           -- the inverse record
              SELECT 1
                FROM concept_relationship_stage i
                WHERE crs.concept_code_1 = i.concept_code_2
                  AND crs.concept_code_2 = i.concept_code_1
    					 AND crs.vocabulary_id_1=i.vocabulary_id_2
               AND crs.vocabulary_id_2=i.vocabulary_id_1
               AND r.reverse_relationship_id = i.relationship_id
    )
;

COMMIT;
	
-- 10. start building the hierarchy (snomed-only)
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
      EXECUTE IMMEDIATE 'drop table snomed_ancestor_calc purge';
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
      'create table snomed_ancestor_calc as
    select 
      r.concept_code_1 as ancestor_concept_code,
      r.concept_code_2 as descendant_concept_code,
      case when s.is_hierarchical=1 then 1 else 0 end as min_levels_of_separation,
      case when s.is_hierarchical=1 then 1 else 0 end as max_levels_of_separation
    from concept_relationship_stage r 
    join relationship s on s.relationship_id=r.relationship_id and s.defines_ancestry=1
    and r.vocabulary_id_1=''SNOMED''';

   /********** Repeat till no new records are written *********/
   FOR i IN 1 .. 100
   LOOP
      -- create all new combinations

      EXECUTE IMMEDIATE
         'create table new_snomed_ancestor_calc as
        select 
            uppr.ancestor_concept_code,
            lowr.descendant_concept_code,
            uppr.min_levels_of_separation+lowr.min_levels_of_separation as min_levels_of_separation,
            uppr.min_levels_of_separation+lowr.min_levels_of_separation as max_levels_of_separation    
        from snomed_ancestor_calc uppr 
        join snomed_ancestor_calc lowr on uppr.descendant_concept_code=lowr.ancestor_concept_code
        union all select * from snomed_ancestor_calc';

      --execute immediate 'select count(*) as cnt from new_snomed_ancestor_calc' into vCnt;
      vCnt := SQL%ROWCOUNT;

      EXECUTE IMMEDIATE 'drop table snomed_ancestor_calc purge';

      -- Shrink and pick the shortest path for min_levels_of_separation, and the longest for max

      EXECUTE IMMEDIATE
         'create table snomed_ancestor_calc as
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
            'create table snomed_ancestor_calc_bkp as select * from snomed_ancestor_calc ';

         vIsOverLoop := TRUE;
      END IF;

      vCnt_old := vCnt;
      vSumMax_old := vSumMax;
   END LOOP;     /********** Repeat till no new records are written *********/

   EXECUTE IMMEDIATE 'truncate table snomed_ancestor';

   -- drop snomed_ancestor indexes before mass insert.
   EXECUTE IMMEDIATE
      'alter table snomed_ancestor disable constraint XPKSNOMED_ANCESTOR';

   EXECUTE IMMEDIATE 'ALTER INDEX XPKSNOMED_ANCESTOR UNUSABLE';


   EXECUTE IMMEDIATE
      'insert /*+ APPEND */ into snomed_ancestor
    select a.* from snomed_ancestor_calc a
    join concept_stage c1 on a.ancestor_concept_code=c1.concept_code and c1.vocabulary_id=''SNOMED''
    join concept_stage c2 on a.descendant_concept_code=c2.concept_code and c2.vocabulary_id=''SNOMED''
    ';

   COMMIT;

   -- Create snomed_ancestor indexes after mass insert.
   EXECUTE IMMEDIATE 'ALTER INDEX XPKSNOMED_ANCESTOR REBUILD NOLOGGING';
   
   EXECUTE IMMEDIATE
      'alter table snomed_ancestor enable constraint XPKSNOMED_ANCESTOR';

   -- Clean up
   EXECUTE IMMEDIATE 'drop table snomed_ancestor_calc purge';

   EXECUTE IMMEDIATE 'drop table snomed_ancestor_calc_bkp purge';
END;

--11. Create domain_id
-- 11.1. Manually create table with "Peaks" = ancestors of records that are all of the same domain
CREATE TABLE peak (
	peak_code VARCHAR(20), --the id of the top ancestor
	peak_domain_id VARCHAR(20), -- the domain to assign to all its children
	ranked INTEGER -- number for the order in which to assign
);

-- 11.2 Fill in the various peak concepts
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
INSERT INTO peak (peak_code, peak_domain_id) VALUES (419891008, 'Note Type'); -- Record artifact
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
INSERT INTO peak (peak_code, peak_domain_id) VALUES (373783004, 'Observation'); -- dietary product, exception of Pharmaceutical / biologic product
INSERT INTO peak (peak_code, peak_domain_id) VALUES (419572002, 'Observation'); -- alcohol agent, exception of drug
INSERT INTO peak (peak_code, peak_domain_id) VALUES (373782009, 'Observation'); -- diagnostic substance, exception of drug
INSERT INTO peak (peak_code, peak_domain_id) VALUES (404684003, 'Condition'); -- Clinical Finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (218496004, 'Condition'); -- Adverse reaction to primarily systemic agents
INSERT INTO peak (peak_code, peak_domain_id) VALUES (313413008, 'Condition'); -- Calculus observation
INSERT INTO peak (peak_code, peak_domain_id) VALUES (405533003, 'Observation'); -- 'adverse incident outcome categories'
INSERT INTO peak (peak_code, peak_domain_id) VALUES (365854008, 'Observation'); -- 'History finding'
INSERT INTO peak (peak_code, peak_domain_id) VALUES (118233009, 'Observation'); -- 'Finding of activity of daily living'
INSERT INTO peak (peak_code, peak_domain_id) VALUES (307824009, 'Observation');-- 'Administrative statuses'
INSERT INTO peak (peak_code, peak_domain_id) VALUES (162408000, 'Observation'); -- Symptom description
INSERT INTO peak (peak_code, peak_domain_id) VALUES (105729006, 'Observation'); -- 'Health perception, health management pattern'
INSERT INTO peak (peak_code, peak_domain_id) VALUES (162566001, 'Observation'); --'Patient not aware of diagnosis'
INSERT INTO peak (peak_code, peak_domain_id) VALUES (71388002, 'Procedure'); --'Procedure'
INSERT INTO peak (peak_code, peak_domain_id) VALUES (304252001, 'Observation'); -- Resuscitate
INSERT INTO peak (peak_code, peak_domain_id) VALUES (304253006, 'Observation'); --DNR
INSERT INTO peak (peak_code, peak_domain_id) VALUES (297249002, 'Observation'); --Family history of procedure
INSERT INTO peak (peak_code, peak_domain_id) VALUES (14734007, 'Observation'); --Administrative procedure
INSERT INTO peak (peak_code, peak_domain_id) VALUES (416940007, 'Observation'); --Past history of procedure
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
INSERT INTO peak (peak_code, peak_domain_id) VALUES (264301008, 'Observation'); -- psychoactive substance of abuse - non-pharmaceutical
INSERT INTO peak (peak_code, peak_domain_id) VALUES (226465004, 'Observation'); -- drinks
INSERT INTO peak (peak_code, peak_domain_id) VALUES (289964002, 'Device'); -- Surgical material
INSERT INTO peak (peak_code, peak_domain_id) VALUES (260667007, 'Device'); -- Graft
INSERT INTO peak (peak_code, peak_domain_id) VALUES (418920007, 'Device'); -- Adhesive agent
INSERT INTO peak (peak_code, peak_domain_id) VALUES (255922001, 'Device'); -- Dental material
INSERT INTO peak (peak_code, peak_domain_id) VALUES (413674002, 'Observation'); -- Body material
INSERT INTO peak (peak_code, peak_domain_id) VALUES (118417008, 'Device'); -- Filling material
INSERT INTO peak (peak_code, peak_domain_id) VALUES (445214009, 'Device'); -- corneal storage medium
INSERT INTO peak (peak_code, peak_domain_id) VALUES (369443003, 'Device'); -- bedpan
INSERT INTO peak (peak_code, peak_domain_id) VALUES (398146001, 'Device'); -- armband
INSERT INTO peak (peak_code, peak_domain_id) VALUES (272181003, 'Device'); -- clinical equipment and/or device
INSERT INTO peak (peak_code, peak_domain_id) VALUES (445316008, 'Device'); -- component of optical microscope
INSERT INTO peak (peak_code, peak_domain_id) VALUES (419818001, 'Device'); -- Contact lens storage case
INSERT INTO peak (peak_code, peak_domain_id) VALUES (228167008, 'Device'); -- Corset
INSERT INTO peak (peak_code, peak_domain_id) VALUES (42380001, 'Device'); -- Ear plug, device
INSERT INTO peak (peak_code, peak_domain_id) VALUES (1333003, 'Device'); -- Emesis basin, device
INSERT INTO peak (peak_code, peak_domain_id) VALUES (360306007, 'Device'); -- Environmental control system
INSERT INTO peak (peak_code, peak_domain_id) VALUES (33894003, 'Device'); -- Experimental device
INSERT INTO peak (peak_code, peak_domain_id) VALUES (116250002, 'Device'); -- filter
INSERT INTO peak (peak_code, peak_domain_id) VALUES (59432006, 'Device'); -- ligature
INSERT INTO peak (peak_code, peak_domain_id) VALUES (360174002, 'Device'); -- nabeya capsule
INSERT INTO peak (peak_code, peak_domain_id) VALUES (311767007, 'Device'); -- special bed
INSERT INTO peak (peak_code, peak_domain_id) VALUES (360173008, 'Device'); -- watson capsule
INSERT INTO peak (peak_code, peak_domain_id) VALUES (367561004, 'Device'); -- xenon arc photocoagulator
INSERT INTO peak (peak_code, peak_domain_id) VALUES (80631005, 'Observation'); -- 'clinical stage finding'
INSERT INTO peak (peak_code, peak_domain_id) VALUES (69449002, 'Observation'); -- drug action
INSERT INTO peak (peak_code, peak_domain_id) VALUES (79899007, 'Observation'); -- drug interaction
INSERT INTO peak (peak_code, peak_domain_id) VALUES (365858006, 'Observation'); -- prognosis/outlook finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (444332001, 'Observation'); -- aware of prognosis
INSERT INTO peak (peak_code, peak_domain_id) VALUES (444143004, 'Observation'); -- carries emergency treatment
INSERT INTO peak (peak_code, peak_domain_id) VALUES (281037003, 'Observation'); -- child health observations
INSERT INTO peak (peak_code, peak_domain_id) VALUES (284530008, 'Observation'); -- communication, speech and language finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (13197004, 'Observation'); -- contraception
INSERT INTO peak (peak_code, peak_domain_id) VALUES (105499002, 'Observation'); -- convalescence
INSERT INTO peak (peak_code, peak_domain_id) VALUES (251859005, 'Observation'); -- dialysis finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (422704000, 'Observation'); -- difficulty obtaining contraception
INSERT INTO peak (peak_code, peak_domain_id) VALUES (301886001, 'Observation'); -- drawing up knees
INSERT INTO peak (peak_code, peak_domain_id) VALUES (250869005, 'Observation'); -- equipment finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (298304004, 'Observation'); -- finding of balance
INSERT INTO peak (peak_code, peak_domain_id) VALUES (298339004, 'Observation'); -- finding of body control
INSERT INTO peak (peak_code, peak_domain_id) VALUES (300577008, 'Observation'); -- finding of lesion
INSERT INTO peak (peak_code, peak_domain_id) VALUES (298325004, 'Observation'); -- finding of movement
INSERT INTO peak (peak_code, peak_domain_id) VALUES (427955007, 'Observation'); -- finding related to status of agreement with prior finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (118222006, 'Observation'); -- general finding of observation of patient
INSERT INTO peak (peak_code, peak_domain_id) VALUES (249857004, 'Observation'); -- loss of midline awareness
INSERT INTO peak (peak_code, peak_domain_id) VALUES (397745006, 'Observation'); -- medical contraindication
INSERT INTO peak (peak_code, peak_domain_id) VALUES (217315002, 'Observation'); -- onset of illness
INSERT INTO peak (peak_code, peak_domain_id) VALUES (300232005, 'Observation'); -- oral cavity, dental and salivary finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (364830008, 'Observation'); -- position of body and posture - finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (248982007, 'Observation'); -- pregnancy, childbirth and puerperium finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (424092004, 'Observation'); -- questionable explanation of injury
INSERT INTO peak (peak_code, peak_domain_id) VALUES (162511002, 'Observation'); -- rare history finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (128254003, 'Observation'); -- respiratory auscultation finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (397773008, 'Observation'); -- surgical contraindication
INSERT INTO peak (peak_code, peak_domain_id) VALUES (413296003, 'Condition'); -- depression requiring intervention
INSERT INTO peak (peak_code, peak_domain_id) VALUES (72670004, 'Condition'); -- sign
INSERT INTO peak (peak_code, peak_domain_id) VALUES (124083000, 'Condition'); -- urobilinogenemia
INSERT INTO peak (peak_code, peak_domain_id) VALUES (65367001, 'Condition'); -- victim status
INSERT INTO peak (peak_code, peak_domain_id) VALUES (59524001, 'Observation'); -- blood bank procedure
INSERT INTO peak (peak_code, peak_domain_id) VALUES (389067005, 'Observation'); -- community health procedure
INSERT INTO peak (peak_code, peak_domain_id) VALUES (225288009, 'Observation'); -- environmental care procedure
INSERT INTO peak (peak_code, peak_domain_id) VALUES (308335008, 'Observation'); -- patient encounter procedure
INSERT INTO peak (peak_code, peak_domain_id) VALUES (389084004, 'Observation'); -- staff related procedure
INSERT INTO peak (peak_code, peak_domain_id) VALUES (110461004, 'Observation'); -- adjunctive care
INSERT INTO peak (peak_code, peak_domain_id) VALUES (372038002, 'Observation'); -- advocacy
INSERT INTO peak (peak_code, peak_domain_id) VALUES (225365006, 'Observation'); -- care regime
INSERT INTO peak (peak_code, peak_domain_id) VALUES (228114008, 'Observation'); -- child health procedures
INSERT INTO peak (peak_code, peak_domain_id) VALUES (309466006, 'Observation'); -- clinical observation regime
INSERT INTO peak (peak_code, peak_domain_id) VALUES (225318000, 'Observation'); -- personal and environmental management regime
INSERT INTO peak (peak_code, peak_domain_id) VALUES (133877004, 'Observation'); -- therapeutic regimen
INSERT INTO peak (peak_code, peak_domain_id) VALUES (225367003, 'Observation'); -- toileting regime
INSERT INTO peak (peak_code, peak_domain_id) VALUES (303163003, 'Observation'); -- treatments administered under the provisions of the law
INSERT INTO peak (peak_code, peak_domain_id) VALUES (429159005, 'Procedure'); -- child psychotherapy
INSERT INTO peak (peak_code, peak_domain_id) VALUES (386053000, 'Measurement'); -- evaluation procedure
INSERT INTO peak (peak_code, peak_domain_id) VALUES (127789004, 'Measurement'); -- laboratory procedure categorized by method
INSERT INTO peak (peak_code, peak_domain_id) VALUES (15220000, 'Measurement'); -- laboratory test
INSERT INTO peak (peak_code, peak_domain_id) VALUES (441742003, 'Measurement'); -- evaluation finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (365605003, 'Measurement'); -- body measurement finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (106019003, 'Condition'); -- elimination pattern
INSERT INTO peak (peak_code, peak_domain_id) VALUES (395557000, 'Observation'); -- tumor finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (422989001, 'Condition'); -- appendix with tumor involvement, with perforation not at tumor
INSERT INTO peak (peak_code, peak_domain_id) VALUES (384980008, 'Condition'); -- atelectasis AND/OR obstructive pneumonitis of entire lung associated with direct extension of malignant neoplasm
INSERT INTO peak (peak_code, peak_domain_id) VALUES (396895006, 'Condition'); -- endocrine pancreas tumor finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (422805009, 'Condition'); -- erosion of esophageal tumor into bronchus
INSERT INTO peak (peak_code, peak_domain_id) VALUES (423018005, 'Condition'); -- erosion of esophageal tumor into trachea
INSERT INTO peak (peak_code, peak_domain_id) VALUES (399527001, 'Condition'); -- invasive ovarian tumor omental implants present
INSERT INTO peak (peak_code, peak_domain_id) VALUES (399600009, 'Condition'); -- lymphoma finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (405928008, 'Condition'); -- renal sinus vessel involved by tumor
INSERT INTO peak (peak_code, peak_domain_id) VALUES (405966006, 'Condition'); -- renal tumor finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (385356007, 'Condition'); -- tumor stage finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (13104003, 'Observation'); -- clinical stage I
INSERT INTO peak (peak_code, peak_domain_id) VALUES (60333009, 'Observation'); -- clinical stage II
INSERT INTO peak (peak_code, peak_domain_id) VALUES (50283003, 'Observation'); -- clinical stage III
INSERT INTO peak (peak_code, peak_domain_id) VALUES (2640006, 'Observation'); -- clinical stage IV
INSERT INTO peak (peak_code, peak_domain_id) VALUES (385358008, 'Observation'); -- dukes stage finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (385362002, 'Observation'); -- FIGO stage finding for gynecological malignancy
INSERT INTO peak (peak_code, peak_domain_id) VALUES (405917009, 'Observation'); -- intergroup rhabdomyosarcoma study post-surgical clinical group finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (409721000, 'Observation'); -- international neuroblastoma staging system stage finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (385389007, 'Observation'); -- lymphoma stage finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (396532004, 'Observation'); -- stage I: Tumor confined to gland, 5 cm or less (adrenal cortical carcinoma)
INSERT INTO peak (peak_code, peak_domain_id) VALUES (396533009, 'Observation'); -- stage II: Tumor confined to gland, greater than 5 cm (adrenal cortical carcinoma)
INSERT INTO peak (peak_code, peak_domain_id) VALUES (396534003, 'Observation'); -- stage III: Extraglandular extension of tumor without other organ involvement (adrenal cortical carcinoma)
INSERT INTO peak (peak_code, peak_domain_id) VALUES (396535002, 'Observation'); -- stage IV: Distant metastasis or extension into other organs (adrenal cortical carcinoma)
INSERT INTO peak (peak_code, peak_domain_id) VALUES (399517007, 'Observation'); -- tumor stage cannot be determined
INSERT INTO peak (peak_code, peak_domain_id) VALUES (67101007, 'Observation'); -- TX category
INSERT INTO peak (peak_code, peak_domain_id) VALUES (385385001, 'Observation'); -- pT category finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (385382003, 'Observation'); -- node category finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (385380006, 'Observation'); -- metastasis category finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (386702006, 'Condition'); -- victim of abuse
INSERT INTO peak (peak_code, peak_domain_id) VALUES (95930005, 'Condition'); -- victim of neglect
INSERT INTO peak (peak_code, peak_domain_id) VALUES (106146005, 'Condition'); -- reflex finding
INSERT INTO peak (peak_code, peak_domain_id) VALUES (103020000, 'Condition'); -- adrenarche 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (405729008, 'Condition'); -- hematochezia 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (165816005, 'Condition'); -- HIV positive 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (300391003, 'Condition'); -- finding of appearance of stool 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (300393000, 'Condition'); -- finding of odor of stool 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (239516002, 'Observation'); -- monitoring procedure 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (243114000, 'Observation'); -- support 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (300893006, 'Observation'); -- nutritional finding 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (248536006, 'Observation'); -- finding of functional performance and activity 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (116336009, 'Observation'); -- eating / feeding / drinking finding 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (448717002, 'Measurement'); -- decline in Edinburgh postnatal depression scale score
INSERT INTO peak (peak_code, peak_domain_id) VALUES (449413009, 'Measurement'); -- decline in Edinburgh postnatal depression scale score at 8 months
INSERT INTO peak (peak_code, peak_domain_id) VALUES (37448008, 'Observation'); -- disturbance in intuition 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (12200008, 'Observation'); -- impaired insight 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (5988002, 'Observation'); -- lack of intuition 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (1230003, 'Observation'); -- no diagnosis on Axis I 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (10125004, 'Observation'); -- no diagnosis on Axis II 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (51112002, 'Observation'); -- no diagnosis on Axis III 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (54427008, 'Observation'); -- no diagnosis on Axis IV 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (37768003, 'Observation'); -- no diagnosis on Axis V 
INSERT INTO peak (peak_code, peak_domain_id) VALUES (6811007, 'Observation'); -- prejudice 

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

-- 11.5. Build domains, preassign all them with "Not assigned"
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
UPDATE domain_snomed d
  SET d.domain_id = (
    SELECT p.peak_domain_id FROM peak p WHERE p.peak_code = d.concept_code
  )
  WHERE d.concept_code in (SELECT DISTINCT peak_code FROM peak)
;

COMMIT;

-- Update top guy
UPDATE domain_snomed SET domain_id = 'Metadata' WHERE concept_code = 138875005;

-- Method 2: For those that slipped through the cracks assign domains by using the class_concept_id
-- This is a crude method, and Method 1 should be revised to cover all concepts.
UPDATE domain_snomed d
   SET d.domain_id =
          (SELECT CASE c.concept_class_id
                  WHEN 'Admin Concept' THEN 'Note Type'
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
                  WHEN 'Record Artifact' THEN 'Note Type'
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

-- 11.6. Update concept_stage from newly created domains.
CREATE INDEX idx_domain_cc
   ON domain_snomed (concept_code);
   
UPDATE concept_stage c
   SET c.domain_id =
          (SELECT d.domain_id
             FROM domain_snomed d
            WHERE d.concept_code = c.concept_code)
 WHERE c.vocabulary_id = 'SNOMED';

-- 11.7. Make manual changes according to rules
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
                  WHEN 'Admin Concept' THEN 'Note Type'
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
                  WHEN 'Record Artifact' THEN 'Note Type'
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

-- 11.8. Set standard_concept based on domain_id
UPDATE concept_stage
   SET standard_concept =
          CASE domain_id
             WHEN 'Drug' THEN NULL                         -- Drugs are RxNorm
             WHEN 'Metadata' THEN NULL                      -- Not used in CDM
             WHEN 'Race' THEN NULL                             -- Race are CDC
             WHEN 'Provider Specialty' THEN NULL
             WHEN 'Place of Service' THEN NULL
             WHEN 'Note Type' THEN NULL   -- Note types in own OMOP vocabulary
             WHEN 'Unit' THEN NULL                           -- Units are UCUM
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

-- 13. Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;
    
-- 15. Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- 16. Clean up
DROP TABLE peak PURGE;
DROP TABLE domain_snomed PURGE;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script