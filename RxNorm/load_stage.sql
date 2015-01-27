-- 1. Update latest_update field to new date 
ALTER TABLE vocabulary ADD latest_update DATE;
UPDATE vocabulary SET latest_update=to_date('20141201','yyyymmdd') WHERE vocabulary_id='RxNorm'; 
COMMIT;

-- 2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
ALTER SESSION SET SKIP_UNUSABLE_INDEXES = TRUE; --disables error reporting of indexes and index partitions marked UNUSABLE
ALTER INDEX idx_cs_concept_code UNUSABLE;
ALTER INDEX idx_cs_concept_id UNUSABLE;
ALTER INDEX idx_concept_code_1 UNUSABLE;
ALTER INDEX idx_concept_code_2 UNUSABLE;

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
          (SELECT latest_update FROM vocabulary WHERE vocabulary_id='RxNorm'),
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
          CASE tty                    -- use RxNorm tty as for Concept Classes
             WHEN 'BPCK' THEN 'Branded Pack'
             WHEN 'GPCK' THEN 'Clinical Pack'
          END,
          'S',
          code,                                        -- Cannot use rxcui here
          (select latest_update From vocabulary where vocabulary_id='RxNorm'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL          
     FROM rxnconso
    WHERE sab = 'RXNORM' AND tty IN ('BPCK', 'GPCK');
COMMIT;	
	
--4. Add synonyms - for all classes except the packs (they use code as concept_code)
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   SELECT NULL ,rxcui, SUBSTR (r.str, 1, 1000), 'RxNorm', 4093769                    -- English
     FROM rxnconso r
          JOIN concept_stage c
             ON     c.concept_code = r.rxcui
                AND NOT c.concept_class_id IN ('Clinical Pack',
                                               'Branded Pack')
    WHERE sab = 'RXNORM' AND tty = 'SY'
	AND c.vocabulary_id='RxNorm';

-- Add synonyms for packs
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   SELECT null,rxcui, SUBSTR (r.str, 1, 1000), 'RxNorm', 4093769                    -- English
     FROM rxnconso r
          JOIN concept_stage c
             ON     c.concept_code = r.code
                AND c.concept_class_id IN ('Clinical Pack', 'Branded Pack')
    WHERE sab = 'RXNORM' AND tty = 'SY'
	AND c.vocabulary_id='RxNorm';
COMMIT;	

--5 Add inner-RxNorm relationships
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;

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
             WHEN rela = 'consists_of' THEN 'Consists of'
             WHEN rela = 'ingredient_of' THEN 'RxNorm ing of'
             WHEN rela = 'precise_ingredient_of' THEN 'Precise ing of'
             WHEN rela = 'dose_form_of' THEN 'Dose form of'
             WHEN rela = 'isa' THEN 'RxNorm is a'
             WHEN rela = 'contained_in' THEN 'Contained in'
             WHEN rela = 'form_of' THEN 'Form of'
             WHEN rela = 'reformulation_of' THEN 'Reformulation of'
             WHEN rela = 'tradename_of' THEN 'Tradename of'
             WHEN rela = 'quantified_form_of' THEN 'Quantified form of'
             ELSE 'non-existing'
          END
             AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'RxNorm')
             AS valid_start_date,
          TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
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

--6 Add upgrade relationships
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT rxcui AS concept_code_1,
          merged_to_rxcui AS concept_code_2,
          'RxNorm' AS vocabulary_id_1,
          'RxNorm' AS vocabulary_id_2,
          'Replaced by' AS relationship_id,
          latest_update AS valid_start_date,
          TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
          NULL AS invalid_reason
     FROM rxnatomarchive, vocabulary
    WHERE     sab = 'RXNORM'
          AND vocabulary_id = 'RxNorm' -- for getting the latest_update
          AND tty IN ('IN',
                      'DF',
                      'SCDC',
                      'SCDF',
                      'SCD',
                      'BN',
                      'SBDC',
                      'SBDF',
                      'SBD')
          AND rxcui <> merged_to_rxcui
          AND NOT EXISTS
                 (SELECT 1
                    FROM concept
                   WHERE vocabulary_id = 'RxNorm' AND concept_code = rxcui
                  UNION ALL
                  SELECT 1
                    FROM concept_stage
                   WHERE vocabulary_id = 'RxNorm' AND concept_code = rxcui)
          AND EXISTS
                 (SELECT 1
                    FROM concept
                   WHERE     vocabulary_id = 'RxNorm'
                         AND concept_code = merged_to_rxcui
                  UNION ALL
                  SELECT 1
                    FROM concept_stage
                   WHERE     vocabulary_id = 'RxNorm'
                         AND concept_code = merged_to_rxcui);
COMMIT;

--7 Make sure all records are symmetrical and turn if necessary
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT crs.concept_code_2,
          crs.concept_code_1,
          crs.vocabulary_id_2,
          crs.vocabulary_id_1,
          r.reverse_relationship_id,
          crs.valid_start_date,
          crs.valid_end_date,
          crs.invalid_reason
     FROM concept_relationship_stage crs
          JOIN relationship r ON r.relationship_id = crs.relationship_id
    WHERE NOT EXISTS
             (                                           -- the inverse record
              SELECT 1
                FROM concept_relationship_stage i
               WHERE     crs.concept_code_1 = i.concept_code_2
                     AND crs.concept_code_2 = i.concept_code_1
                     AND crs.vocabulary_id_1 = i.vocabulary_id_2
                     AND crs.vocabulary_id_2 = i.vocabulary_id_1
                     AND r.reverse_relationship_id = i.relationship_id);
COMMIT;					 

--8 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL
;
COMMIT;

--9 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		