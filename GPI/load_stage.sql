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
UPDATE vocabulary SET latest_update=to_date('20150506','yyyymmdd'), vocabulary_version='RXNORM CROSS REFERENCE 15.2.1.002' WHERE vocabulary_id='GPI'; 
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

--3. Load into concept_stage from ndw_v_product

INSERT /*+ APPEND */ INTO  concept_stage (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
     SELECT MAX (gpi_desc) AS concept_name,
            'Drug' AS domain_id,
            'GPI' AS vocabulary_id,
            'GPI' AS concept_class_id,
            NULL AS standard_concept,
            gpi AS concept_code,
            (SELECT latest_update
               FROM vocabulary
              WHERE vocabulary_id = 'GPI')
               AS valid_start_date,
            TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
            NULL AS invalid_reason
       FROM ndw_v_product
      WHERE gpi IS NOT NULL
   GROUP BY gpi;
COMMIT;					  

--4 Load into concept_relationship_stage name from ndw_v_product
INSERT /*+ APPEND */ INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
with map as (
-- Get all possible chains through NDC and "Maps to" to RxNorm
  select
    n.gpi, 
    rx.concept_id as rx_id, 
    rx.concept_class_id as rx_class
  from ndw_v_product n
  join concept ndc on ndc.concept_code=n.ndc and ndc.vocabulary_id='NDC'-- and nvl(n.obsolete_dt, '31-Dec-2099')>ndc.valid_start_date
  join concept_relationship r on r.invalid_reason is null and r.concept_id_1=ndc.concept_id and r.relationship_id='Maps to'
  join concept rx on rx.concept_id=r.concept_id_2 and rx.concept_class_id in ('Branded Pack', 'Clinical Pack', 'Branded Drug', 'Clinical Drug', 'Quant Branded Drug', 'Quant Clinical Drug') and rx.vocabulary_id='RxNorm'
  where n.gpi is not null
    group by n.gpi, 
    rx.concept_id, 
    rx.concept_class_id
),
all_class as (
-- Count the various concept_classes of the resulting concepts, and every ancestor, to find out if it is the same thing with different level of granularity
  select map.gpi, c.concept_id, c.concept_class_id
  from map
  join concept_ancestor a on a.descendant_concept_id=map.rx_id
  join concept c on c.concept_id=a.ancestor_concept_id and c.vocabulary_id='RxNorm' and c.concept_class_id in ('Branded Pack', 'Clinical Pack', 'Branded Drug', 'Clinical Drug', 'Quant Branded Drug', 'Quant Clinical Drug')
union
  select gpi, rx_id, rx_class from map
),
clean_class as (
-- Pick only those where the concept_class_id count is 1 (which means unique target concept)
  select gpi, concept_class_id, count(*) as cnt
  from all_class
  group by gpi, concept_class_id having count(*)=1
)
select distinct 
  ac.gpi as concept_code_1,
-- Pick the one which is the lowest but still unique
  first_value(c.concept_code) over (partition by ac.gpi order by decode(ac.concept_class_id, 'Branded Pack', 1, 'Clinical Pack', 2, 'Quant Branded Drug', 3, 'Quant Clinical Drug', 4, 'Branded Drug', 5, 6)) as concept_code_2,
  'Maps to' as relationship_id,
  'GPI' as vocabulary_id_1,
  'RxNorm' as vocabulary_id_2,
  (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'GPI')
             AS valid_start_date,
  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
  NULL AS invalid_reason
from clean_class cc
join all_class ac on cc.gpi=ac.gpi and cc.concept_class_id=ac.concept_class_id
join concept c on c.concept_id=ac.concept_id
-- exclude all those that don't merge at a single Clinical Drug, i.e. coding for different target concepts
where exists (select 1 from clean_class where gpi=cc.gpi and concept_class_id='Clinical Drug');

COMMIT;

--6. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
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

--7. Add mapping from deprecated to fresh concepts
MERGE INTO concept_relationship_stage crs
     USING (  SELECT root_concept_code_1,
                     concept_code_2,
                     root_vocabulary_id_1,
                     vocabulary_id_2,
                     relationship_id,
                     (SELECT MAX (latest_update)
                        FROM vocabulary
                       WHERE latest_update IS NOT NULL)
                        AS valid_start_date,
                     TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
                     invalid_reason
                FROM (WITH upgraded_concepts
                              AS (SELECT DISTINCT
                                         concept_code_1,
                                         CASE
                                            WHEN rel_id <> 6
                                            THEN
                                               FIRST_VALUE (concept_code_2) OVER (PARTITION BY concept_code_1 ORDER BY rel_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
                                            ELSE
                                               concept_code_2
                                         END
                                            AS concept_code_2,
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
                                            FROM concept_relationship_stage crs
                                           WHERE     crs.relationship_id IN ('Concept replaced by',
                                                                             'Concept same_as to',
                                                                             'Concept alt_to to',
                                                                             'Concept poss_eq to',
                                                                             'Concept was_a to',
                                                                             'Maps to')
                                                 AND crs.invalid_reason IS NULL
                                                 AND ( (crs.vocabulary_id_1 = crs.vocabulary_id_2 AND crs.relationship_id <> 'Maps to') OR crs.relationship_id = 'Maps to')
                                                 AND crs.concept_code_1 <> crs.concept_code_2
                                          UNION ALL
                                          --some concepts might be in 'base' tables
                                          SELECT c1.concept_code,
                                                 c2.concept_code,
                                                 c1.vocabulary_id,
                                                 c2.vocabulary_id,
                                                 6 AS rel_id
                                            FROM concept c1, concept c2, concept_relationship r
                                           WHERE     c1.concept_id = r.concept_id_1
                                                 AND c2.concept_id = r.concept_id_2
                                                 AND r.concept_id_1 <> r.concept_id_2
                                                 AND r.invalid_reason IS NULL
                                                 AND r.relationship_id = 'Maps to'))
                          SELECT CONNECT_BY_ROOT concept_code_1 AS root_concept_code_1,
                                 u.concept_code_2,
                                 CONNECT_BY_ROOT vocabulary_id_1 AS root_vocabulary_id_1,
                                 vocabulary_id_2,
                                 'Maps to' AS relationship_id,
                                 NULL AS invalid_reason
                            FROM upgraded_concepts u
                           WHERE CONNECT_BY_ISLEAF = 1
                      CONNECT BY NOCYCLE PRIOR concept_code_2 = concept_code_1 AND PRIOR vocabulary_id_2 = vocabulary_id_1) i
               WHERE EXISTS
                        (SELECT 1
                           FROM concept_relationship_stage crs
                          WHERE crs.concept_code_1 = root_concept_code_1 AND crs.vocabulary_id_1 = root_vocabulary_id_1)
            GROUP BY root_concept_code_1,
                     concept_code_2,
                     root_vocabulary_id_1,
                     vocabulary_id_2,
                     relationship_id,
                     invalid_reason) i
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

--8. Delete ambiguous 'Maps to' mappings following by rules:
--1. if we have 'true' mappings to Ingredient or Clinical Drug Comp, then delete all others mappings
--2. if we don't have 'true' mappings, then leave only one fresh mapping
--3. if we have 'true' mappings to Ingredients AND Clinical Drug Comps, then delete mappings to Ingredients, which have mappings to Clinical Drug Comp
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;
DELETE FROM concept_relationship_stage
      WHERE ROWID IN
               (SELECT rid
                  FROM (SELECT rid,
                               concept_code_1,
                               concept_code_2,
                               pseudo_class_id,
                               rn,
                               MIN (pseudo_class_id) OVER (PARTITION BY concept_code_1, vocabulary_id_1, vocabulary_id_2) have_true_mapping,
                               has_rel_with_comp
                          FROM (SELECT cs.ROWID rid,
                                       concept_code_1,
                                       concept_code_2,
                                       vocabulary_id_1,
                                       vocabulary_id_2,
                                       CASE WHEN c.concept_class_id IN ('Ingredient', 'Clinical Drug Comp') THEN 1 ELSE 2 END pseudo_class_id,
                                       ROW_NUMBER () OVER (PARTITION BY concept_code_1, vocabulary_id_1, vocabulary_id_2 
                                       ORDER BY cs.valid_start_date DESC, c.valid_start_date DESC, c.concept_id DESC) rn, --fresh mappings first
                                       (
                                        SELECT 1
                                          FROM concept_relationship cr_int, concept_relationship_stage crs_int, concept c_int
                                         WHERE     cr_int.invalid_reason IS NULL
                                               AND cr_int.relationship_id = 'RxNorm ing of'
                                               AND cr_int.concept_id_1 = c.concept_id
                                               AND c.concept_class_id = 'Ingredient'
                                               AND crs_int.relationship_id = 'Maps to'
                                               AND crs_int.invalid_reason IS NULL
                                               AND crs_int.concept_code_1 = cs.concept_code_1
                                               AND crs_int.vocabulary_id_1 = cs.vocabulary_id_1
                                               AND crs_int.concept_code_2 = c_int.concept_code
                                               AND crs_int.vocabulary_id_2 = c_int.vocabulary_id
                                               AND c_int.domain_id = 'Drug'
                                               AND c_int.concept_class_id = 'Clinical Drug Comp'
                                               AND cr_int.concept_id_2 = c_int.concept_id                                      
                                       ) has_rel_with_comp
                                  FROM concept_relationship_stage cs, concept c
                                 WHERE     relationship_id = 'Maps to'
                                       AND cs.invalid_reason IS NULL
                                       AND cs.concept_code_2 = c.concept_code
                                       AND cs.vocabulary_id_2 = c.vocabulary_id
                                       AND c.domain_id = 'Drug'))
                 WHERE ( 
                     (have_true_mapping = 1 AND pseudo_class_id = 2) OR --if we have 'true' mappings to Ingredients or Clinical Drug Comps (pseudo_class_id=1), then delete all others mappings (pseudo_class_id=2)
                     (have_true_mapping <> 1 AND rn > 1) OR --if we don't have 'true' mappings, then leave only one fresh mapping
                     has_rel_with_comp=1 --if we have 'true' mappings to Ingredients AND Clinical Drug Comps, then delete mappings to Ingredients, which have mappings to Clinical Drug Comp
                 ));
COMMIT;	

--9. Add synonyms
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   SELECT DISTINCT NULL,
                   concept_code,
                   concept_name,
                   'GPI',
                   4180186                                          -- English
     FROM (SELECT cs.concept_code, cs.concept_name
             FROM concept_stage cs
           UNION ALL
           SELECT cs.concept_code, gn.drug_string
             FROM gpi_name gn, concept_stage cs
            WHERE gn.gpi_code = cs.concept_code)
    WHERE TRIM (concept_name) IS NOT NULL;
COMMIT;

--10. Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;


--11. Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		