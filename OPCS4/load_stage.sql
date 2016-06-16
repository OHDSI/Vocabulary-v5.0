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
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'OPCS4',
                                          pVocabularyDate        => TO_DATE ('20151001', 'yyyymmdd'),
                                          pVocabularyVersion     => 'OPCS4 nhs_dmwb_20.0.1_20151001000001',
                                          pVocabularyDevSchema   => 'DEV_OPCS4');
END;
COMMIT;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;

--3. Load into concept_stage from opcs
 --remove long dashes
UPDATE opcs
   SET cui = REPLACE (cui, '–', '-')
 WHERE cui LIKE '%–%';

COMMIT;

INSERT /*+ APPEND */ INTO  concept_stage (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT term AS concept_name,            -- probably limit to 255 characters
          'Procedure' AS domain_id,
          'OPCS4' AS vocabulary_id,
          'Procedure' AS concept_class_id,
          'S' AS standard_concept,
          REGEXP_REPLACE (CUI, '([[:print:]]{3})([[:print:]]+)', '\1.\2') -- Dot after 3 characters
             AS concept_code,
          v.latest_update AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM opcs o, vocabulary v
    WHERE     cui NOT LIKE '%-%'                         -- don't use chapters
          AND term NOT LIKE 'CHAPTER %'
          AND v.vocabulary_id = 'OPCS4';
COMMIT;					  

--4 Create concept_relationship_stage
-- We have to invert the direction of the mapping. The source gives us high OPCS4 to lower SNOMED we need to find the nearest common ancestor of all those lower SNOMED codes
INSERT /*+ APPEND */ INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
select distinct 
  REGEXP_REPLACE (concept_code, '([[:print:]]{3})([[:print:]]+)', '\1.\2') as concept_code_1,
  first_value(ancestor_code) over (partition by concept_code order by cnt desc, averg rows between unbounded preceding and unbounded following) as concept_code_2, -- pick the ancestor with the highest number and the lowest average min_levels_of_separation
  'OPCS4 - SNOMED' as relationship_id,
  'OPCS4' as vocabulary_id_1,
  'SNOMED' as vocabulary_id_2,
  TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date, ---- latest_update starting at 1.1.1970 this time.
  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
  NULL AS invalid_reason  
from (
  select distinct concept_code, ancestor_code, count(*) as cnt, avg(min_levels_of_separation) as averg -- get for each code all the ancestors, their distance and number
  from (
    select opcs.scui as concept_code, anc.concept_code as ancestor_code, a.min_levels_of_separation
    from opcssctmap opcs
    join concept snomed on snomed.vocabulary_id='SNOMED' and snomed.concept_code=opcs.tcui -- convert SNOMED code to SNOMED ID
    join ( -- get all the ancestors of the SNOMED IDs
      select min_levels_of_separation, ancestor_concept_id, descendant_concept_id from concept_ancestor where ancestor_concept_id not in (
        select descendant_concept_id from concept_ancestor where ancestor_concept_id=4008453 and min_levels_of_separation<3 -- remove very high up concepts in the hierarchy
      )
    ) a on a.descendant_concept_id=snomed.concept_id
    join concept anc on anc.concept_id=a.ancestor_concept_id and anc.vocabulary_id='SNOMED' -- don't get into MedDRA
  )
  group by concept_code, ancestor_code
)
where concept_code in ( -- only codes that are valid
  select cui from opcs 
  where cui not like '%-%' -- don't use chapters
  and term not like 'CHAPTER %'
);
COMMIT;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		