--Before we can update the domain_id, we need to build the hierarchy, and for that we need to get the internal relationships

--0. prepare work
--DROP INDEX idx_concept_code_1;
--DROP INDEX idx_concept_code_2;
--DROP INDEX idx_concept_id_1;
--DROP INDEX idx_concept_id_2;


--1. Build concept_relationship_stage
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        relationship_id,
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
				   AND d.term<>'PBCL flag true')
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
             ELSE
                'non-existing'                           -- this will break it
          END
             AS relationship_id, term,
             
          TO_DATE ('01.12.2014', 'dd.mm.yyyy'),--release date
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM (SELECT * FROM tmp_rel);


--2. add replacement relationships. They are handled in a different SNOMED table
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT concept_code_1,
          concept_code_2,
          relationship_id,
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


--3. Make sure all records are symmetrical and turn if necessary

INSERT INTO concept_relationship_stage
   SELECT crs.concept_id_2 AS concept_id_1,
          crs.concept_id_1 AS concept_id_2,
          CRS.CONCEPT_CODE_2 AS CONCEPT_CODE_1,
          CRS.CONCEPT_CODE_1 AS CONCEPT_CODE_2,
          r.reverse_relationship_id AS relationship_id,
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
                     AND r.reverse_relationship_id = i.relationship_id);
                     


commit;

--4. start building the hierarchy
exec PKG_CONCEPT_ANCESTOR.CALC;

--5. start creating domain_id (Vocabulary-v5.0\01-SNOMED\Update_domain_snomed.sql)

--6. fill in all concept_id_1 and _2 in concept_relationship_stage
CREATE INDEX idx_concept_code_1
   ON concept_relationship_stage (concept_code_1);
CREATE INDEX idx_concept_code_2
   ON concept_relationship_stage (concept_code_2);
   
UPDATE concept_relationship_stage crs
   SET (crs.concept_id_1, crs.concept_id_2) =
          (SELECT DISTINCT
                  COALESCE (cs1.concept_id, c1.concept_id),
                  COALESCE (cs2.concept_id, c2.concept_id)
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
 
 --7. update domains (Vocabulary-v5.0\17-Read\Add_domain_id_and_concept_class_id_to_concept_stage.sql)
 --8. update concept from concept_stage (Vocabulary-v5.0\Update\Concept_Update_Full.sql)