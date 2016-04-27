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
   EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN latest_update';
EXCEPTION WHEN OTHERS THEN NULL;
END;
ALTER TABLE vocabulary ADD latest_update DATE;
UPDATE vocabulary SET latest_update=to_date('20150901','yyyymmdd'), vocabulary_version='MedDRA version 18.1' WHERE vocabulary_id = 'MedDRA';
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
INSERT INTO concept_stage (concept_name,
                           vocabulary_id,
                           domain_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT soc_name AS concept_name,
          'MedDRA' AS vocabulary_id,
          NULL AS domain_id,
          'SOC' AS concept_class_id,
          'C' AS standard_concept,
          soc_code AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM soc_term
   UNION ALL
   SELECT hlgt_name AS concept_name,
          'MedDRA' AS vocabulary_id,
          NULL AS domain_id,
          'HLGT' AS concept_class_id,
          'C' AS standard_concept,
          hlgt_code AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM hlgt_pref_term
   UNION ALL
   SELECT hlt_name AS concept_name,
          'MedDRA' AS vocabulary_id,
          NULL AS domain_id,
          'HLT' AS concept_class_id,
          'C' AS standard_concept,
          hlt_code AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM hlt_pref_term
   UNION ALL
   SELECT pt_name AS concept_name,
          'MedDRA' AS vocabulary_id,
          NULL AS domain_id,
          'PT' AS concept_class_id,
          'C' AS standard_concept,
          pt_code AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM pref_term
   UNION ALL
   SELECT llt_name AS concept_name,
          'MedDRA' AS vocabulary_id,
          NULL AS domain_id,
          'LLT' AS concept_class_id,
          'C' AS standard_concept,
          llt_code AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM low_level_term
    WHERE llt_currency = 'Y' AND llt_code <> pt_code;
COMMIT;					  

--4 Update domain_id
CREATE TABLE t_domains nologging AS
--create temporary table with domain_id defined by rules
(
    SELECT distinct
      l.llt_code AS concept_code,
      CASE
       WHEN h.hlgt_code = 10064289 THEN 'Observation' -- Medication errors
       WHEN h.hlt_code = 10071951 THEN 'Measurement' -- Acquired gene mutations and other alterations
       WHEN h.hlt_code = 10022528 THEN 'Observation' -- Interactions
       WHEN h.hlgt_code = 10069171 THEN 'Observation' -- Product quality issues
       WHEN h.hlgt_code = 10069782 THEN 'Observation' -- Device issues 
       WHEN h.hlt_code = 10007566 THEN 'Measurement' -- Cardiac function diagnostic procedures with result
       WHEN h.hlt_code = 10007570 THEN 'Procedure' -- Cardiac histopathology procedures
       WHEN h.hlt_code = 10007574 THEN 'Procedure' -- Cardiac imaging procedures
       WHEN h.hlt_code = 10047044 THEN 'Procedure' -- Vascular and lymphatic histopathology procedures
       WHEN h.hlt_code = 10047078 THEN 'Procedure' -- Vascular imaging procedures NEC
       WHEN h.hlt_code = 10053105 THEN 'Observation' -- Vascular auscultatory investigations
       WHEN h.hlt_code = 10001355 THEN 'Procedure' -- Adrenal gland histopathology procedures
       WHEN h.hlt_code = 10017962 THEN 'Procedure' -- Gastrointestinal histopathology procedures
       WHEN h.hlt_code = 10068276 THEN 'Procedure' -- Bone marrow and immune tissue histopathology procedures
       WHEN h.hlt_code = 10019807 THEN 'Procedure' -- Hepatobiliary histopathology procedures
       WHEN h.hlt_code = 10019808 THEN 'Procedure' -- Hepatobiliary imaging procedures  
       WHEN h.hlt_code = 10028385 THEN 'Procedure' -- Musculoskeletal and soft tissue histopathology procedures
       WHEN h.hlt_code = 10028386 THEN 'Procedure' -- Musculoskeletal and soft tissue imaging procedures
       WHEN h.hlt_code = 10003784 THEN 'Procedure' -- Auditory function diagnostic procedures
       WHEN h.hlt_code = 10007949 THEN 'Procedure' -- Central nervous system histopathology procedures
       WHEN h.hlt_code = 10007950 THEN 'Procedure' -- Central nervous system imaging procedures
       WHEN h.hlt_code = 10013994 THEN 'Procedure' -- Ear and labyrinth histopathology procedures
       WHEN h.hlt_code = 10029285 THEN 'Procedure' -- Neurologic diagnostic procedures
       WHEN h.hlt_code = 10030864 THEN 'Procedure' -- Ophthalmic function diagnostic procedures
       WHEN h.hlt_code = 10030866 THEN 'Procedure' -- Ophthalmic histopathology and imaging procedures
       WHEN h.hlt_code = 10064463 THEN 'Procedure' -- Special sense investigations NEC
       WHEN h.hlt_code = 10067226 THEN 'Procedure' -- Psychiatric investigations
       WHEN h.hlt_code = 10046569 THEN 'Procedure' -- Urinary tract histopathology procedures
       WHEN h.hlt_code = 10046570 THEN 'Procedure' -- Urinary tract imaging procedures
       WHEN h.hlt_code = 10038601 THEN 'Procedure' -- Reproductive organ and breast histopathology procedures
       WHEN h.hlt_code = 10038602 THEN 'Procedure' -- Reproductive organ and breast imaging procedures
       WHEN h.hlt_code = 10006472 THEN 'Procedure' -- Respiratory tract and thoracic histopathology procedures
       WHEN h.hlt_code = 10006476 THEN 'Procedure' -- Respiratory tract and thoracic imaging procedures
       WHEN h.hlt_code = 10040862 THEN 'Procedure' -- Skin histopathology procedures
       WHEN h.hlt_code = 10053100 THEN 'Procedure' -- Foetal and neonatal diagnostic procedures
       WHEN h.hlt_code = 10053102 THEN 'Procedure' -- Foetal and neonatal histopathology procedures
       WHEN h.pt_code in (10062552, 10056850, 10002944, 10056849) THEN 'Measurement' -- Apgar
       WHEN h.pt_code in (10005891, 10056822, 10056810, 10056811, 10056812, 10056813, 10056821, 10073541) THEN 'Measurement' -- Body height
       WHEN h.pt_code in (10005894, 10074506, 10005895, 10005897, 10072073) THEN 'Measurement' -- Body mass
       WHEN h.pt_code in (10050311, 10071307, 10071306) THEN 'Measurement' -- Body surface
       WHEN h.pt_code in (10005906, 10075265, 10005910, 10063488, 10005911, 10069600, 10053359, 10056852, 10056851) THEN 'Measurement' -- Body Temperature
       WHEN h.pt_code in (10060025, 10060043, 10060042) THEN 'Measurement' -- Head circumference
       WHEN h.pt_code in (10060080, 10060082, 10060081) THEN 'Measurement' -- Intelligence test
       WHEN h.pt_code in (10054755, 10054756, 10054754) THEN 'Measurement' -- Karnofsky
       WHEN h.pt_code in (10047890, 10056814, 10047895, 10047899, 10056817) THEN 'Measurement' -- Weight
       WHEN h.pt_code in (10038709, 10038710, 10038712) THEN 'Measurement' -- Respiratory rate 
       WHEN h.hlt_code = 10071941 THEN 'Observation' -- Physical examination procedures and organ system status
       WHEN h.hlgt_code = 10007512 THEN 'Measurement' -- Cardiac and vascular investigations (excl enzyme tests)
       WHEN h.soc_code = 10041244 THEN 'Observation' -- Social circumstances
       WHEN h.soc_code = 10042613 THEN 'Procedure' -- Surgical and medical procedures
       ELSE 'Condition'
      END AS domain_id
    FROM md_hierarchy h
    JOIN low_level_term l on l.pt_code = h.pt_code
    WHERE h.primary_soc_fg='Y' and l.llt_code != l.pt_code
    UNION
    -- Preferred term domains
    SELECT distinct
      pt_code AS concept_code,
      CASE
       WHEN hlgt_code = 10064289 THEN 'Observation' -- Medication errors
       WHEN hlt_code = 10071951 THEN 'Measurement' -- Acquired gene mutations and other alterations
       WHEN hlt_code = 10022528 THEN 'Observation' -- Interactions
       WHEN hlgt_code = 10069171 THEN 'Observation' -- Product quality issues
       WHEN hlgt_code = 10069782 THEN 'Observation' -- Device issues 
       WHEN hlt_code = 10007566 THEN 'Measurement' -- Cardiac function diagnostic procedures with result
       WHEN hlt_code = 10007570 THEN 'Procedure' -- Cardiac histopathology procedures
       WHEN hlt_code = 10007574 THEN 'Procedure' -- Cardiac imaging procedures
       WHEN hlt_code = 10047044 THEN 'Procedure' -- Vascular and lymphatic histopathology procedures
       WHEN hlt_code = 10047078 THEN 'Procedure' -- Vascular imaging procedures NEC
       WHEN hlt_code = 10053105 THEN 'Observation' -- Vascular auscultatory investigations
       WHEN hlt_code = 10001355 THEN 'Procedure' -- Adrenal gland histopathology procedures
       WHEN hlt_code = 10017962 THEN 'Procedure' -- Gastrointestinal histopathology procedures
       WHEN hlt_code = 10068276 THEN 'Procedure' -- Bone marrow and immune tissue histopathology procedures
       WHEN hlt_code = 10019807 THEN 'Procedure' -- Hepatobiliary histopathology procedures
       WHEN hlt_code = 10019808 THEN 'Procedure' -- Hepatobiliary imaging procedures  
       WHEN hlt_code = 10028385 THEN 'Procedure' -- Musculoskeletal and soft tissue histopathology procedures
       WHEN hlt_code = 10028386 THEN 'Procedure' -- Musculoskeletal and soft tissue imaging procedures
       WHEN hlt_code = 10003784 THEN 'Procedure' -- Auditory function diagnostic procedures
       WHEN hlt_code = 10007949 THEN 'Procedure' -- Central nervous system histopathology procedures
       WHEN hlt_code = 10007950 THEN 'Procedure' -- Central nervous system imaging procedures
       WHEN hlt_code = 10013994 THEN 'Procedure' -- Ear and labyrinth histopathology procedures
       WHEN hlt_code = 10029285 THEN 'Procedure' -- Neurologic diagnostic procedures
       WHEN hlt_code = 10030864 THEN 'Procedure' -- Ophthalmic function diagnostic procedures
       WHEN hlt_code = 10030866 THEN 'Procedure' -- Ophthalmic histopathology and imaging procedures
       WHEN hlt_code = 10064463 THEN 'Procedure' -- Special sense investigations NEC
       WHEN hlt_code = 10067226 THEN 'Procedure' -- Psychiatric investigations
       WHEN hlt_code = 10046569 THEN 'Procedure' -- Urinary tract histopathology procedures
       WHEN hlt_code = 10046570 THEN 'Procedure' -- Urinary tract imaging procedures
       WHEN hlt_code = 10038601 THEN 'Procedure' -- Reproductive organ and breast histopathology procedures
       WHEN hlt_code = 10038602 THEN 'Procedure' -- Reproductive organ and breast imaging procedures
       WHEN hlt_code = 10006472 THEN 'Procedure' -- Respiratory tract and thoracic histopathology procedures
       WHEN hlt_code = 10006476 THEN 'Procedure' -- Respiratory tract and thoracic imaging procedures
       WHEN hlt_code = 10040862 THEN 'Procedure' -- Skin histopathology procedures
       WHEN hlt_code = 10053100 THEN 'Procedure' -- Foetal and neonatal diagnostic procedures
       WHEN hlt_code = 10053102 THEN 'Procedure' -- Foetal and neonatal histopathology procedures
       WHEN pt_code in (10062552, 10056850, 10002944, 10056849) THEN 'Measurement' -- Apgar
       WHEN pt_code in (10005891, 10056822, 10056810, 10056811, 10056812, 10056813, 10056821, 10073541) THEN 'Measurement' -- Body height
       WHEN pt_code in (10005894, 10074506, 10005895, 10005897, 10072073) THEN 'Measurement' -- Body mass
       WHEN pt_code in (10050311, 10071307, 10071306) THEN 'Measurement' -- Body surface
       WHEN pt_code in (10005906, 10075265, 10005910, 10063488, 10005911, 10069600, 10053359, 10056852, 10056851) THEN 'Measurement' -- Body Temperature
       WHEN pt_code in (10060025, 10060043, 10060042) THEN 'Measurement' -- Head circumference
       WHEN pt_code in (10060080, 10060082, 10060081) THEN 'Measurement' -- Intelligence test
       WHEN pt_code in (10054755, 10054756, 10054754) THEN 'Measurement' -- Karnofsky
       WHEN pt_code in (10047890, 10056814, 10047895, 10047899, 10056817) THEN 'Measurement' -- Weight
       WHEN pt_code in (10038709, 10038710, 10038712) THEN 'Measurement' -- Respiratory rate 
       WHEN hlt_code = 10071941 THEN 'Observation' -- Physical examination procedures and organ system status
       WHEN hlgt_code = 10007512 THEN 'Measurement' -- Cardiac and vascular investigations (excl enzyme tests)
       WHEN soc_code = 10041244 THEN 'Observation' -- Social circumstances
       WHEN soc_code = 10042613 THEN 'Procedure' -- Surgical and medical procedures
       ELSE 'Condition'
      END AS domain_id
    FROM md_hierarchy
    WHERE primary_soc_fg='Y' 
    UNION
    -- High level term domains
    SELECT distinct
      hlt_code AS concept_code,
      CASE
       WHEN hlgt_code = 10064289 THEN 'Observation' -- Medication errors
       WHEN hlt_code = 10071951 THEN 'Measurement' -- Acquired gene mutations and other alterations
       WHEN hlt_code = 10022528 THEN 'Observation' -- Interactions
       WHEN hlgt_code = 10069171 THEN 'Observation' -- Product quality issues
       WHEN hlgt_code = 10069782 THEN 'Observation' -- Device issues 
       WHEN hlt_code = 10007566 THEN 'Measurement' -- Cardiac function diagnostic procedures with result
       WHEN hlt_code = 10007570 THEN 'Procedure' -- Cardiac histopathology procedures
       WHEN hlt_code = 10007574 THEN 'Procedure' -- Cardiac imaging procedures
       WHEN hlt_code = 10047044 THEN 'Procedure' -- Vascular and lymphatic histopathology procedures
       WHEN hlt_code = 10047078 THEN 'Procedure' -- Vascular imaging procedures NEC
       WHEN hlt_code = 10053105 THEN 'Observation' -- Vascular auscultatory investigations
       WHEN hlt_code = 10001355 THEN 'Procedure' -- Adrenal gland histopathology procedures
       WHEN hlt_code = 10017962 THEN 'Procedure' -- Gastrointestinal histopathology procedures
       WHEN hlt_code = 10068276 THEN 'Procedure' -- Bone marrow and immune tissue histopathology procedures
       WHEN hlt_code = 10019807 THEN 'Procedure' -- Hepatobiliary histopathology procedures
       WHEN hlt_code = 10019808 THEN 'Procedure' -- Hepatobiliary imaging procedures  
       WHEN hlt_code = 10028385 THEN 'Procedure' -- Musculoskeletal and soft tissue histopathology procedures
       WHEN hlt_code = 10028386 THEN 'Procedure' -- Musculoskeletal and soft tissue imaging procedures
       WHEN hlt_code = 10003784 THEN 'Procedure' -- Auditory function diagnostic procedures
       WHEN hlt_code = 10007949 THEN 'Procedure' -- Central nervous system histopathology procedures
       WHEN hlt_code = 10007950 THEN 'Procedure' -- Central nervous system imaging procedures
       WHEN hlt_code = 10013994 THEN 'Procedure' -- Ear and labyrinth histopathology procedures
       WHEN hlt_code = 10029285 THEN 'Procedure' -- Neurologic diagnostic procedures
       WHEN hlt_code = 10030864 THEN 'Procedure' -- Ophthalmic function diagnostic procedures
       WHEN hlt_code = 10030866 THEN 'Procedure' -- Ophthalmic histopathology and imaging procedures
       WHEN hlt_code = 10064463 THEN 'Procedure' -- Special sense investigations NEC
       WHEN hlt_code = 10067226 THEN 'Procedure' -- Psychiatric investigations
       WHEN hlt_code = 10046569 THEN 'Procedure' -- Urinary tract histopathology procedures
       WHEN hlt_code = 10046570 THEN 'Procedure' -- Urinary tract imaging procedures
       WHEN hlt_code = 10038601 THEN 'Procedure' -- Reproductive organ and breast histopathology procedures
       WHEN hlt_code = 10038602 THEN 'Procedure' -- Reproductive organ and breast imaging procedures
       WHEN hlt_code = 10006472 THEN 'Procedure' -- Respiratory tract and thoracic histopathology procedures
       WHEN hlt_code = 10006476 THEN 'Procedure' -- Respiratory tract and thoracic imaging procedures
       WHEN hlt_code = 10040862 THEN 'Procedure' -- Skin histopathology procedures
       WHEN hlt_code = 10053100 THEN 'Procedure' -- Foetal and neonatal diagnostic procedures
       WHEN hlt_code = 10053102 THEN 'Procedure' -- Foetal and neonatal histopathology procedures
       WHEN hlt_code = 10071941 THEN 'Observation' -- Physical examination procedures and organ system status
       WHEN hlgt_code = 10007512 THEN 'Measurement' -- Cardiac and vascular investigations (excl enzyme tests)
       WHEN soc_code = 10041244 THEN 'Observation' -- Social circumstances
       WHEN soc_code = 10042613 THEN 'Procedure' -- Surgical and medical procedures
       ELSE 'Condition'
      END AS domain_id
    FROM md_hierarchy
    UNION
    -- High level group term domains
    SELECT distinct
      hlgt_code AS concept_code,
      CASE
       WHEN hlgt_code = 10064289 THEN 'Observation' -- Medication errors
       WHEN hlgt_code = 10069171 THEN 'Observation' -- Product quality issues
       WHEN hlgt_code = 10069782 THEN 'Observation' -- Device issues 
       WHEN hlgt_code = 10007512 THEN 'Measurement' -- Cardiac and vascular investigations (excl enzyme tests)
       WHEN soc_code = 10041244 THEN 'Observation' -- Social circumstances
       WHEN soc_code = 10042613 THEN 'Procedure' -- Surgical and medical procedures
       ELSE 'Condition'
      END AS domain_id
    FROM md_hierarchy
    UNION
    -- System organ class domains
    SELECT distinct
      soc_code AS concept_code,
      CASE
       WHEN soc_code = 10041244 THEN 'Observation' -- Social circumstances
       WHEN soc_code = 10042613 THEN 'Procedure' -- Surgical and medical procedures
       ELSE 'Condition'
      END AS domain_id
    FROM md_hierarchy
);

CREATE INDEX tmp_idx_cs
   ON t_domains (concept_code)
   NOLOGGING;

--update concept_stage from temporary table   
UPDATE concept_stage c
   SET domain_id =
          (SELECT t.domain_id
             FROM t_domains t
            WHERE c.concept_code = t.concept_code);

COMMIT;
DROP TABLE t_domains PURGE;			

--5 Create internal hierarchical relationships
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT soc_code AS concept_code_1,
          hlgt_code AS concept_code_2,
          'MedDRA' AS vocabulary_id_1,
          'MedDRA' AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM soc_hlgt_comp
   UNION ALL
   SELECT hlgt_code AS concept_code_1,
          hlt_code AS concept_code_2,
          'MedDRA' AS vocabulary_id_1,
          'MedDRA' AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM hlgt_hlt_comp
   UNION ALL
   SELECT hlt_code AS concept_code_1,
          pt_code AS concept_code_2,
          'MedDRA' AS vocabulary_id_1,
          'MedDRA' AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM hlt_pref_comp
   UNION ALL
   SELECT pt_code AS concept_code_1,
          llt_code AS concept_code_2,
          'MedDRA' AS vocabulary_id_1,
          'MedDRA' AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM low_level_term
    WHERE llt_currency = 'Y' AND llt_code <> pt_code;
COMMIT;

--6 Copy existing relationships
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT c1.concept_code AS concept_code_1,
          c2.concept_code AS concept_code_2,
          c1.vocabulary_id AS vocabulary_id_1,
          c2.vocabulary_id AS vocabulary_id_2,
          r.relationship_id AS relationship_id,
          r.valid_start_date AS valid_start_date,
          r.valid_end_date AS valid_end_date,
          r.invalid_reason AS invalid_reason
     FROM concept_relationship r, concept c1, concept c2
    WHERE     c1.concept_id = r.concept_id_1
          AND c2.concept_id = r.concept_id_2
          AND r.relationship_id IN ('MedDRA - SNOMED eq',
                                    'MedDRA - SMQ',
                                    'MedDRA - ICD9CM');
COMMIT;

									
--7 Delete ambiguous 'Maps to' mappings if target concept have domain_id='Drug' and concept_class_id NOT IN ('Ingredient', 'Clinical Drug Comp')
DELETE FROM concept_relationship_stage r
WHERE (concept_code_1, vocabulary_id_1, relationship_id, concept_code_2, vocabulary_id_2) IN (
    SELECT concept_code_1, vocabulary_id_1, relationship_id, concept_code_2, vocabulary_id_2 FROM (      
        SELECT concept_code_1, vocabulary_id_1, relationship_id, concept_code_2, vocabulary_id_2, 
        COUNT(DISTINCT concept_code_2) OVER (PARTITION BY concept_code_1, vocabulary_id_1, vocabulary_id_2) AS cnt
            FROM concept_relationship_stage cs, concept c
           WHERE     relationship_id = 'Maps to'
                 AND cs.invalid_reason IS NULL
                 AND cs.concept_code_2 = c.concept_code
                 AND cs.vocabulary_id_2 = c.vocabulary_id
                 AND c.domain_id = 'Drug'
                 AND c.concept_class_id NOT IN ('Ingredient', 'Clinical Drug Comp')
        GROUP BY concept_code_1, vocabulary_id_1, relationship_id, concept_code_2, vocabulary_id_2
    ) WHERE cnt > 1 
);
COMMIT;

--8 Delete duplicate replacement mappings (one concept has multiply target concepts)
DELETE FROM concept_relationship_stage
      WHERE (concept_code_1, relationship_id) IN
               (  SELECT concept_code_1, relationship_id
                    FROM concept_relationship_stage
                   WHERE     relationship_id IN ('Concept replaced by',
                                                 'Concept same_as to',
                                                 'Concept alt_to to',
                                                 'Concept poss_eq to',
                                                 'Concept was_a to')
                         AND invalid_reason IS NULL
                         AND vocabulary_id_1 = vocabulary_id_2
                GROUP BY concept_code_1, relationship_id
                  HAVING COUNT (DISTINCT concept_code_2) > 1);
COMMIT;

--9 Delete self-connected mappings ("A 'Concept replaced by' B" and "B 'Concept replaced by' A")
DELETE FROM concept_relationship_stage
      WHERE ROWID IN (SELECT cs1.ROWID
                        FROM concept_relationship_stage cs1, concept_relationship_stage cs2
                       WHERE     cs1.invalid_reason IS NULL
                             AND cs2.invalid_reason IS NULL
                             AND cs1.concept_code_1 = cs2.concept_code_2
                             AND cs1.concept_code_2 = cs2.concept_code_1
                             AND cs1.vocabulary_id_1 = cs2.vocabulary_id_1
                             AND cs2.vocabulary_id_2 = cs2.vocabulary_id_2
                             AND cs1.vocabulary_id_1 = cs1.vocabulary_id_2
                             AND cs1.relationship_id = cs2.relationship_id
                             AND cs1.relationship_id IN ('Concept replaced by',
                                                         'Concept same_as to',
                                                         'Concept alt_to to',
                                                         'Concept poss_eq to',
                                                         'Concept was_a to'));
COMMIT;

--10 Deprecate concepts if we have no active replacement record in the concept_relationship_stage
UPDATE concept_stage cs
   SET cs.valid_end_date =
          (SELECT v.latest_update - 1
             FROM VOCABULARY v
            WHERE v.vocabulary_id = cs.vocabulary_id),
       cs.invalid_reason = 'D',
       cs.standard_concept = NULL
 WHERE     NOT EXISTS
              (SELECT 1
                 FROM concept_relationship_stage crs
                WHERE     crs.concept_code_1 = cs.concept_code
                      AND crs.vocabulary_id_1 = cs.vocabulary_id
                      AND crs.invalid_reason IS NULL
                      AND crs.relationship_id IN ('Concept replaced by',
                                                  'Concept same_as to',
                                                  'Concept alt_to to',
                                                  'Concept poss_eq to',
                                                  'Concept was_a to'))
       AND cs.invalid_reason = 'U';		
COMMIT;	

--11 Deprecate replacement records if target concept was depreceted 
MERGE INTO concept_relationship_stage r
     USING (WITH upgraded_concepts
                    AS (SELECT crs.concept_code_1,
                               crs.vocabulary_id_1,
                               crs.concept_code_2,
                               crs.vocabulary_id_2,
                               crs.relationship_id,
                               CASE WHEN cs.concept_code IS NULL THEN 'D' ELSE cs.invalid_reason END AS invalid_reason
                          FROM concept_relationship_stage crs 
                          LEFT JOIN concept_stage cs ON crs.concept_code_2 = cs.concept_code AND crs.vocabulary_id_2 = cs.vocabulary_id
                         WHERE     crs.relationship_id IN ('Concept replaced by',
                                                           'Concept same_as to',
                                                           'Concept alt_to to',
                                                           'Concept poss_eq to',
                                                           'Concept was_a to')
                               AND crs.vocabulary_id_1 = crs.vocabulary_id_2
                               AND crs.concept_code_1 <> crs.concept_code_2
                               AND crs.invalid_reason IS NULL)
                SELECT DISTINCT u.concept_code_1,
                                u.vocabulary_id_1,
                                u.concept_code_2,
                                u.vocabulary_id_2,
                                u.relationship_id
                  FROM upgraded_concepts u
            CONNECT BY NOCYCLE PRIOR concept_code_1 = concept_code_2
            START WITH concept_code_2 IN (SELECT concept_code_2
                                            FROM upgraded_concepts
                                           WHERE invalid_reason = 'D')) i
        ON (    r.concept_code_1 = i.concept_code_1
            AND r.vocabulary_id_1 = i.vocabulary_id_1
            AND r.concept_code_2 = i.concept_code_2
            AND r.vocabulary_id_2 = i.vocabulary_id_2
            AND r.relationship_id = i.relationship_id)
WHEN MATCHED
THEN
   UPDATE SET r.invalid_reason = 'D',
              r.valid_end_date =
                 (SELECT latest_update - 1
                    FROM vocabulary
                   WHERE vocabulary_id IN (r.vocabulary_id_1, r.vocabulary_id_2));
COMMIT;

--12 Deprecate concepts if we have no active replacement record in the concept_relationship_stage (yes, again)
UPDATE concept_stage cs
   SET cs.valid_end_date =
          (SELECT v.latest_update - 1
             FROM VOCABULARY v
            WHERE v.vocabulary_id = cs.vocabulary_id),
       cs.invalid_reason = 'D',
       cs.standard_concept = NULL
 WHERE     NOT EXISTS
              (SELECT 1
                 FROM concept_relationship_stage crs
                WHERE     crs.concept_code_1 = cs.concept_code
                      AND crs.vocabulary_id_1 = cs.vocabulary_id
                      AND crs.invalid_reason IS NULL
                      AND crs.relationship_id IN ('Concept replaced by',
                                                  'Concept same_as to',
                                                  'Concept alt_to to',
                                                  'Concept poss_eq to',
                                                  'Concept was_a to'))
       AND cs.invalid_reason = 'U';				 
COMMIT;

--13 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
UPDATE concept_relationship_stage crs
   SET crs.valid_end_date =
          (SELECT latest_update - 1
             FROM vocabulary
            WHERE vocabulary_id IN (crs.vocabulary_id_1, crs.vocabulary_id_2) AND latest_update IS NOT NULL),
       crs.invalid_reason = 'D'
 WHERE     crs.relationship_id = 'Maps to'
       AND crs.invalid_reason IS NULL
       AND EXISTS
              (SELECT 1
                 FROM concept_stage cs
                WHERE cs.concept_code = crs.concept_code_2 AND cs.vocabulary_id = crs.vocabulary_id_2 AND cs.invalid_reason IN ('U', 'D'));
COMMIT;		

--14 Add mapping from deprecated to fresh concepts
MERGE INTO concept_relationship_stage crs
     USING (WITH upgraded_concepts
                    AS (SELECT DISTINCT concept_code_1,
                                        FIRST_VALUE (concept_code_2) OVER (PARTITION BY concept_code_1 ORDER BY rel_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2
                          FROM (SELECT crs.concept_code_1,
                                       crs.concept_code_2,
                                       crs.vocabulary_id_1,
                                       crs.vocabulary_id_2,
                                       --if concepts have more than one relationship_id, then we take only the one with following precedence
                                       CASE
                                          WHEN crs.relationship_id = 'Concept replaced by' THEN 1
                                          WHEN crs.relationship_id = 'Concept same_as to' THEN 2
                                          WHEN crs.relationship_id = 'Concept alt_to to' THEN 3
                                          WHEN crs.relationship_id = 'Concept poss_eq to' THEN 4
                                          WHEN crs.relationship_id = 'Concept was_a to' THEN 5
                                          WHEN crs.relationship_id = 'Maps to' THEN 6
                                       END
                                          AS rel_id
                                  FROM concept_relationship_stage crs, concept_stage cs
                                 WHERE     (   crs.relationship_id IN ('Concept replaced by',
                                                                       'Concept same_as to',
                                                                       'Concept alt_to to',
                                                                       'Concept poss_eq to',
                                                                       'Concept was_a to')
                                            OR (crs.relationship_id = 'Maps to' AND cs.invalid_reason = 'U'))
                                       AND crs.invalid_reason IS NULL
                                       AND ( (crs.vocabulary_id_1 = crs.vocabulary_id_2 AND crs.relationship_id <> 'Maps to') OR crs.relationship_id = 'Maps to')
                                       AND crs.concept_code_2 = cs.concept_code
                                       AND crs.vocabulary_id_2 = cs.vocabulary_id
                                       AND crs.concept_code_1 <> crs.concept_code_2
                                UNION ALL
                                --some concepts might be in 'base' tables, but information about 'U' - in 'stage'
                                SELECT c1.concept_code,
                                       c2.concept_code,
                                       c1.vocabulary_id,
                                       c2.vocabulary_id,
                                       6 AS rel_id
                                  FROM concept c1,
                                       concept c2,
                                       concept_relationship r,
                                       concept_stage cs
                                 WHERE     c1.concept_id = r.concept_id_1
                                       AND c2.concept_id = r.concept_id_2
                                       AND r.concept_id_1 <> r.concept_id_2
                                       AND r.invalid_reason IS NULL
                                       AND r.relationship_id = 'Maps to'
                                       AND cs.vocabulary_id = c2.vocabulary_id
                                       AND cs.concept_code = c2.concept_code
                                       AND cs.invalid_reason = 'U'))
                SELECT CONNECT_BY_ROOT concept_code_1 AS root_concept_code_1,
                       u.concept_code_2,
                       CONNECT_BY_ROOT vocabulary_id_1 AS root_vocabulary_id_1,
                       vocabulary_id_2,
                       'Maps to' AS relationship_id,
                       (SELECT latest_update
                          FROM vocabulary
                         WHERE vocabulary_id = vocabulary_id_2)
                          AS valid_start_date,
                       TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
                       NULL AS invalid_reason
                  FROM upgraded_concepts u
                 WHERE CONNECT_BY_ISLEAF = 1
            CONNECT BY NOCYCLE PRIOR concept_code_2 = concept_code_1
            START WITH concept_code_1 IN (SELECT concept_code_1 FROM upgraded_concepts
                                          MINUS
                                          SELECT concept_code_2 FROM upgraded_concepts)) i
        ON (    crs.concept_code_1 = i.root_concept_code_1
            AND crs.concept_code_2 = i.concept_code_2
            AND crs.vocabulary_id_1 = i.root_vocabulary_id_1
            AND crs.vocabulary_id_2 = i.vocabulary_id_2
            AND crs.relationship_id = i.relationship_id)
WHEN NOT MATCHED
THEN
   INSERT     (concept_code_1,
               concept_code_2,
               vocabulary_id_1,
               vocabulary_id_2,
               relationship_id,
               valid_start_date,
               valid_end_date,
               invalid_reason)
       VALUES (i.root_concept_code_1,
               i.concept_code_2,
               i.root_vocabulary_id_1,
               i.vocabulary_id_2,
               i.relationship_id,
               i.valid_start_date,
               i.valid_end_date,
               i.invalid_reason)
WHEN MATCHED
THEN
   UPDATE SET crs.invalid_reason = NULL, crs.valid_end_date = i.valid_end_date
           WHERE crs.invalid_reason IS NOT NULL;
COMMIT;			 

--15 Create a relationship file for the Medical Coder
select c.concept_code, c.concept_name, c.domain_id, c.concept_class_id, c1.concept_code concept_code_snomed 
from concept_stage c
left join concept_relationship_stage r on c.concept_code=r.concept_code_1 and r.relationship_id = 'MedDRA - SNOMED eq'
left join concept c1 on c1.concept_code=r.concept_code_2 and c1.vocabulary_id='SNOMED';

--16 Append result to concept_relationship_stage table

--17 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL
;
COMMIT;

--18 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		