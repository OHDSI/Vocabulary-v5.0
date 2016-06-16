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
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'GPI',
                                          pVocabularyDate        => TO_DATE ('20150506', 'yyyymmdd'),
                                          pVocabularyVersion     => 'RXNORM CROSS REFERENCE 15.2.1.002',
                                          pVocabularyDevSchema   => 'DEV_GPI');
END;
COMMIT;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;

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
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;

--7. Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;

--8. Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
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

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		