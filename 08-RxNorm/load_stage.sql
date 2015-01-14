-- 1. Update latest_update field to new date 
ALTER TABLE vocabulary ADD latest_update DATE;
UPDATE vocabulary SET latest_update=to_date('20141201','yyyymmdd') WHERE vocabulary_id='RxNorm'; 
COMMIT;

-- 2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
--ALTER SESSION SET SKIP_UNUSABLE_INDEXES = TRUE; --disables error reporting of indexes and index partitions marked UNUSABLE
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
          (select latest_update From vocabulary where vocabulary_id='RxNorm'),
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
	
--4. Add synonyms
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   SELECT null,rxcui, SUBSTR (r.str, 1, 1000), 'RxNorm', 4093769                    -- English
     FROM rxnconso r
          JOIN concept_stage c
             ON     c.concept_code = r.rxcui
                AND NOT c.concept_class_id IN ('Clinical Pack',
                                               'Branded Pack')
    WHERE sab = 'RXNORM' AND tty = 'SY'
	AND c.vocabulary_id='RxNorm';

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

	   
--5 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		