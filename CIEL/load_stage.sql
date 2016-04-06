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
UPDATE vocabulary SET latest_update=to_date('20150227','yyyymmdd'), vocabulary_version='Openmrs 1.11.0 20150227' WHERE vocabulary_id='CIEL'; 
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

--3. Load into concept_stage
INSERT INTO concept_stage (concept_id,
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
	null as concept_id,
	FIRST_VALUE (
             cn."name")
          OVER (
             PARTITION BY c.concept_id
             ORDER BY
                CASE
                   WHEN LENGTH (cn."name") <= 255 THEN LENGTH (cn."name")
                   ELSE 0
                END DESC,
                LENGTH (cn."name")
             ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
             AS concept_name,
 case ccl."name" 
    when 'Test' then 'Measurement'
    when 'Procedure' then 'Procedure'
    when 'Drug' then 'Drug' 
    when 'Diagnosis' then 'Condition'
    when 'Finding' then 'Condition'
    when 'Anatomy' then 'Spec Anatomic Site'
    when 'Question' then 'Observation'
    when 'LabSet' then 'Measurement'
    when 'MedSet' then 'Drug'
    when 'ConvSet' then 'Observation' 
    when 'Misc' then 'Observation'
    when 'Symptom' then 'Condition'
    when 'Symptom/Finding' then 'Condition'
    when 'Specimen' then 'Specimen'
    when 'Misc Order' then 'Observation'
    when 'Workflow' then 'Observation' -- no concepts of this class in table
    when 'State' then 'Observation'
    when 'Program' then 'Observation'
    when 'Aggregate Measurement' then 'Measurement'
    when 'Indicator' then 'Observation' -- no concepts of this class in table
    when 'Health Care Monitoring Topics' then 'Observation' -- no concepts of this class in table
    when 'Radiology/Imaging Procedure' then 'Procedure' -- there are LOINC codes which are Measurement, but results are not connected
    when 'Frequency' then 'Observation' -- this is SIG in CDM, which is not normalized today
    when 'Pharmacologic Drug Class' then 'Drug'
    when 'Units of Measure' then 'Unit'
    when 'Organism' then 'Observation'
    when 'Drug form' then 'Drug'
    when 'Medical supply' then 'Device'
  end as domain_id, 
  'CIEL' as vocabulary_id,
  case ccl."name" -- shorten the ones that won't fit the 20 char limit
    when 'Aggregate Measurement' then 'Aggregate Meas'
    when 'Health Care Monitoring Topics' then 'Monitoring' -- no concepts of this class in table
    when 'Radiology/Imaging Procedure' then 'Radiology' -- there are LOINC codes which are Measurement, but results are not connected
    when 'Pharmacologic Drug Class' then 'Drug Class'
    else ccl."name"  
  end as concept_class_id, 
  null as standard_concept,
  c.concept_id as concept_code,
  coalesce(trunc(c.date_created), TO_DATE ('19700101', 'yyyymmdd')) as valid_start_date,
  case c.retired
    when 0 then TO_DATE ('20991231', 'yyyymmdd') 
    else (select latest_update from vocabulary where vocabulary_id='CIEL')
  end as valid_end_date,
  case c.retired
    when 0 then null
    else 'D' -- we might change that.
  end as invalid_reason
from concept_ciel c
left join concept_class_ciel ccl on c.class_id=ccl.concept_class_id
-- left join drug d on d.drug_id=c.concept_id
left join concept_name cn on cn.concept_id=c.concept_id and cn.locale='en';
COMMIT;			

--START TEMPORARY FIX--
--for strange reason we have 4 concepts without concept_name
UPDATE concept_stage
   SET concept_name = 'Concept ||c.concept_id'
 WHERE concept_name IS NULL;
COMMIT;
--END TEMPORARY FIX--

--4 Create chain between CIEL and the best OMOP concept and create map
create table ciel_to_concept_map nologging as
with r as (
-- create connections between CIEL and RxNorm/SNOMED, and then from SNOMED to RxNorm Ingredient and from RxNorm MIN to RxNorm Ingredient
  select distinct
    FIRST_VALUE (
             cn."name")
          OVER (
             PARTITION BY c.concept_id
             ORDER BY
                CASE
                   WHEN LENGTH (cn."name") <= 255 THEN LENGTH (cn."name")
                   ELSE 0
                END DESC,
                LENGTH (cn."name")
             ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
             AS concept_name_1,
    cast (c.concept_id as varchar(40)) as concept_code_1,
    'CIEL' as vocabulary_id_1,
    '' as concept_name_2,
    crt."code" as concept_code_2,
    case crs."name"
-- The name of the vocabularies is composed of the OMOP vocabulary_id, and the suffix '-c' for "chained" and the number of precedence it should be used (ordered by in a partition statement)
      when 'SNOMED CT' then 'SNOMED-c1'
      when 'SNOMED NP' then 'SNOMED-c2'
      when 'SNOMED US' then 'SNOMED-c3'
      when 'RxNORM' then 'RxNorm-c'
      when 'ICD-10-WHO' then 'XICD10-c1' -- X so it will be ordered by after SNOMED
      when 'ICD-10-WHO 2nd' then 'XICD10-c2'
      when 'ICD-10-WHO NP' then 'XICD10-c3'
      when 'ICD-10-WHO NP2' then 'XICD10-c4'
      when 'NDF-RT NUI' then 'NDFRT-c'
      else null
    end as vocabulary_id_2
  from concept_ciel c
  join concept_class_ciel ccl on c.class_id=ccl.concept_class_id
  join concept_name cn on cn.concept_id=c.concept_id and cn.locale='en'
  join concept_reference_map crm on crm.concept_id=c.concept_id
  join concept_reference_term crt on crt.concept_reference_term_id=crm.concept_reference_term_id
  join concept_reference_source crs on crs.concept_source_id=crt.concept_source_id
  where crt.retired=0
  and crs."name" in ('RxNORM', 'SNOMED CT', 'SNOMED NP', 'ICD-10-WHO', 'ICD-10-WHO NP', 'ICD-10-WHO 2nd', 'ICD-10-WHO NP2', 'SNOMED US', 'NDF-RT NUI')
union
-- resolve RxNorm MIN to RxNorm IN (not currently in Vocabularies)
  select distinct
    first_value(rx_min.str) over (partition by rx_min.rxcui order by 
    CASE
       WHEN LENGTH (rx_min.str) <= 255 THEN LENGTH (rx_min.str)
       ELSE 0
    END DESC,
    LENGTH (rx_min.str)
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as concept_name_1,
    rx_min.rxcui as concept_code_1,
    'RxNorm-c' as vocabulary_id_1,
    first_value(ing.str) over (partition by ing.rxcui order by 
    CASE
       WHEN LENGTH (ing.str) <= 255 THEN LENGTH (ing.str)
       ELSE 0
    END DESC,
    LENGTH (ing.str)
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as concept_name_2,
    ing.rxcui as concept_code_2,
    'RxNorm-c' as vocabulary_id_2
  from rxnconso rx_min
  join rxnrel r on r.rxcui1=rx_min.rxcui
  join rxnconso ing on ing.rxcui=r.rxcui2 and ing.sab='RXNORM' and ing.tty='IN'
  where rx_min.sab='RXNORM' and rx_min.tty='MIN'
union
-- add concept_relationships between SNOMED and RxNorm
  select 
    c1.concept_name as concept_name_1, c1.concept_code as concept_code_1, c1.vocabulary_id||'-c' as vocabulary_id_1, 
    c2.concept_name as concept_name_2, c2.concept_code as concept_code_2, c2.vocabulary_id||'-c' as vocabulary_id_2
  from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id
  join concept c2 on c2.concept_id=r.concept_id_2
  where r.invalid_reason is null
  and c1.vocabulary_id = 'SNOMED' and c2.vocabulary_id = 'RxNorm'
  and r.relationship_id = 'Maps to'
  and c1.concept_id!=c2.concept_id
union
-- add concept_relationships between NDFRT and RxNorm
  select 
    c1.concept_name as concept_name_1, c1.concept_code as concept_code_1, c1.vocabulary_id||'-c' as vocabulary_id_1, 
    c2.concept_name as concept_name_2, c2.concept_code as concept_code_2, c2.vocabulary_id||'-c' as vocabulary_id_2
  from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id
  join concept c2 on c2.concept_id=r.concept_id_2
  where r.invalid_reason is null
  and c1.vocabulary_id = 'NDFRT' and c2.vocabulary_id = 'RxNorm'
  and r.relationship_id = 'NDFRT - RxNorm eq'
  
union
-- add concept_relationships within SNOMED to decomponse multiple ingredients and map from procedure to drug
  select 
    c1.concept_name as concept_name_1, c1.concept_code as concept_code_1, c1.vocabulary_id||'-c' as vocabulary_id_1, 
    c2.concept_name as concept_name_2, c2.concept_code as concept_code_2, c2.vocabulary_id||'-c' as vocabulary_id_2
  from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id
  join concept c2 on c2.concept_id=r.concept_id_2
  where r.invalid_reason is null
  and c1.vocabulary_id = 'SNOMED' and c2.vocabulary_id = 'SNOMED'
  and r.relationship_id in ('Has active ing', 'Has dir subst')
union
-- add concept_relationships within RxNorm from Ingredient to Ingredient
  select 
    c1.concept_name as concept_name_1, c1.concept_code as concept_code_1, c1.vocabulary_id||'-c' as vocabulary_id_1, 
    c2.concept_name as concept_name_2, c2.concept_code as concept_code_2, c2.vocabulary_id||'-c' as vocabulary_id_2
  from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id
  join concept c2 on c2.concept_id=r.concept_id_2
  where r.invalid_reason is null
  and c1.vocabulary_id = 'RxNorm' and c2.vocabulary_id = 'RxNorm'
  and r.relationship_id in ('Form of')
union
-- connect deprecated RxNorm ingredients to fresh ones by first word in concept_name
  select 
  dep.concept_name as concept_name_1,
      dep.concept_code as concept_code_1, 'RxNorm-c' as vocabulary_id_1,
  fre.concept_name as concept_name_2,
      fre.concept_code as concept_code_2, 'RxNorm-c' as vocabulary_id_2 
  from concept dep
  join concept fre on regexp_substr(lower(dep.concept_name), '\w+') = regexp_substr(lower(fre.concept_name), '\w+') and fre.vocabulary_id='RxNorm' and fre.concept_class_id='Ingredient' and fre.invalid_reason is null
  join (
    select fir, count(8) from (
      select concept_name, regexp_substr(lower(dep.concept_name), '\w+') as fir from concept dep where vocabulary_id='RxNorm' and concept_class_id='Ingredient' 
    ) group by fir having count(8) < 4 
  ) ns on fir = regexp_substr(lower(dep.concept_name), '\w+')
  where dep.vocabulary_id='RxNorm' and dep.concept_class_id='Ingredient' and dep.invalid_reason = 'D'
union
-- connect SNOMED ingredients to RxNorm by first word in concept_name
  select 
  dep.concept_name as concept_name_1,
      dep.concept_code as concept_code_1, 'SNOMED-c' as vocabulary_id_1,
  fre.concept_name as concept_name_2,
      fre.concept_code as concept_code_2, 'RxNorm-c' as vocabulary_id_2 
  from concept dep
  join concept fre on regexp_substr(lower(dep.concept_name), '\w+') = regexp_substr(lower(fre.concept_name), '\w+') and fre.vocabulary_id='RxNorm' and fre.concept_class_id='Ingredient' and fre.invalid_reason is null
  join (
    select fir, count(8) from (
      select concept_name, regexp_substr(lower(dep.concept_name), '\w+') as fir from concept dep where vocabulary_id='RxNorm' and concept_class_id='Ingredient' 
    ) group by fir having count(8) < 4 
  ) ns on fir = regexp_substr(lower(dep.concept_name), '\w+')
  where dep.vocabulary_id='SNOMED' and dep.domain_id='Drug' and lower(dep.concept_name) not like '% with %' and dep.concept_name not like '% + %' and lower(dep.concept_name) not like '% and %'
union
-- add concept_relationships between ICD10 and SNOMED 
  select 
    c1.concept_name as concept_name_1, c1.concept_code as concept_code_1, c1.vocabulary_id||'-c' as vocabulary_id_1, 
    c2.concept_name as concept_name_2, c2.concept_code as concept_code_2, c2.vocabulary_id as vocabulary_id_2 -- SNOMED mappings are final, so no suffix
  from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id
  join concept c2 on c2.concept_id=r.concept_id_2
  where r.invalid_reason is null
  and c1.vocabulary_id = 'ICD10' and c2.vocabulary_id = 'SNOMED'
  and r.relationship_id = 'Maps to'
union
-- add concept_relationships between ICD10 and SNOMED 
  select 
    c1.concept_name as concept_name_1, c1.concept_code as concept_code_1, c1.vocabulary_id||'-c' as vocabulary_id_1, 
    c2.concept_name as concept_name_2, c2.concept_code as concept_code_2, c2.vocabulary_id as vocabulary_id_2 -- Mappings are final, so no suffix
  from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id
  join concept c2 on c2.concept_id=r.concept_id_2
  where r.invalid_reason is null
  and c1.vocabulary_id = 'SNOMED' and c2.vocabulary_id in ('Specialty', 'Place of Service')
  and r.relationship_id = 'Maps to'
union
-- add concept_relationships between SNOMED Drug classes and NDFRT
  select 
    c1.concept_name as concept_name_1, c1.concept_code as concept_code_1, c1.vocabulary_id||'-c' as vocabulary_id_1,
    c2.concept_name as concept_name_2, c2.concept_code as concept_code_2, c2.vocabulary_id||'-c' as vocabulary_id_2
  from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id
  join concept c2 on c2.concept_id=r.concept_id_2
  where r.invalid_reason is null
  and c1.vocabulary_id = 'SNOMED' and c2.vocabulary_id = 'NDFRT'
  and c1.domain_id='Drug'
union
-- Mapping from SNOMED to UCUM
  select 
    c1.concept_name as concept_name_1, c1.concept_code as concept_code_1, c1.vocabulary_id||'-c' as vocabulary_id_1,
    c2.concept_name as concept_name_2, c2.concept_code as concept_code_2, c2.vocabulary_id as vocabulary_id_2 -- UCUM mappings are final, so no suffix
  from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id
  join concept c2 on c2.concept_id=r.concept_id_2
  where r.invalid_reason is null
  and c1.vocabulary_id in 'SNOMED' and c2.vocabulary_id = 'UCUM'
union
-- Add replacement mappings
  select 
    c1.concept_name as concept_name_1, c1.concept_code as concept_code_1, c1.vocabulary_id||'-c' as vocabulary_id_1, 
    c2.concept_name as concept_name_2, c2.concept_code as concept_code_2, c2.vocabulary_id||'-c' as vocabulary_id_2
  from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id
  join concept c2 on c2.concept_id=r.concept_id_2
  where r.invalid_reason is null
-- and c1.vocabulary_id in ('SNOMED', 'RxNorm', 'ICD10', 'LOINC', 'NDFRT'
  and c1.vocabulary_id in ('SNOMED', 'ICD10', 'RxNorm', 'LOINC') and c2.vocabulary_id in ('SNOMED', 'ICD10', 'RxNorm', 'LOINC')
  and relationship_id in (
             'Concept replaced by',
            'Concept same_as to',
            'Concept alt_to to',
            'Concept poss_eq to',
            'Concept was_a to',
            'LOINC replaced by',
            'RxNorm replaced by'
  )
union
-- Final terminators for RxNorm Ingredients
  select 
concept_name as concept_name_1,
    concept_code as concept_code_1, 'RxNorm-c' as vocabulary_id_1,
concept_name as concept_name_2,
    concept_code as concept_code_2, 'RxNorm' as vocabulary_id_2 -- RxNorm ingredient mappings are final
  from concept
  where vocabulary_id='RxNorm' and concept_class_id='Ingredient' and invalid_reason is null
union
-- Final terminators for standard_concept SNOMEDs 
  select concept_name as concept_name_1,
    concept_code as concept_code_1, 'SNOMED-c' as vocabulary_id_1, -- map from interim with suffix "-c" to blessed concept
concept_name as concept_name_2,
    concept_code as concept_code_2, 'SNOMED' as vocabulary_id_2 -- SNOMED mappings are final
  from concept
  where vocabulary_id='SNOMED' 
  and standard_concept = 'S' 
  and invalid_reason is null
union
-- Final terminators for LOINC
  select concept_name as concept_name_1,
    concept_code as concept_code_1, 'LOINC-c' as vocabulary_id_1, -- map from interim with suffix "-c" to blessed concept
concept_name as concept_name_2,
    concept_code as concept_code_2, 'LOINC' as vocabulary_id_2 -- SNOMED mappings are final
  from concept
  where vocabulary_id='LOINC' 
  and invalid_reason is null
)
-- Finally let the connect by find a path between the CIEL concept and an OMOP stnadard_concept='S'
select *
from (
  select 
case when vocabulary_id_2 like '%-c%' then 0 else 1 end as found,
    connect_by_root r.concept_name_1 as concept_name_1,
    connect_by_root r.concept_code_1 as concept_code_1,
    connect_by_root r.vocabulary_id_1 as vocabulary_id_1,
    sys_connect_by_path(r.vocabulary_id_2||'-'||r.concept_code_2, ':') as path,
r.concept_name_2,
    r.concept_code_2,
    r.vocabulary_id_2
  from r
-- nocycle shouldn't be necessary, but for some reason it won't do it without, even though I can't find a loop
-- The logic is to thread them up by matching the ending concept_code to the beginning of the next relationship, and to make sure the vocabulary of the next fits into the previous one
-- The latter is necessary because we use suffixes in the definition of the vocabulary_id for the first relationship from the CIEL concept for the purpose of distinguishing 
-- intermediate steps from the final and then pick the best path from a possible list
  connect by nocycle prior r.concept_code_2 = r.concept_code_1 and instr(prior r.vocabulary_id_2, r.vocabulary_id_1) > 0
)
where vocabulary_id_1='CIEL' -- start with the CIELs
and vocabulary_id_2 not like '%-c%' -- the terminating relationshp should have no suffix, indicating it is a proper standard concept.
;
COMMIT;	   

--5 Create temporary table of CIEL concepts that have mapping to some useful vocabulary, even though if it doesn't work. This is for debugging, in the final release we won't need that
create table ciel_concept_with_map nologging as
select distinct 
--   cdt."name" as datatype_nm, 
--   cn.concept_name_id as cnid,
    FIRST_VALUE (
         cn."name")
      OVER (
         PARTITION BY c.concept_id
         ORDER BY
            CASE
               WHEN LENGTH (cn."name") <= 255 THEN LENGTH (cn."name")
               ELSE 0
            END DESC,
            LENGTH (cn."name")
         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
  as concept_name,
  ccl."name" as domain_id,
  c.concept_id as concept_code,
  case c.retired when 0 then null else 'D' end as invalid_reason
from concept_ciel c
-- left join concept_datatype cdt on c.datatype_id=cdt.concept_datatype_id
left join concept_class_ciel ccl on c.class_id=ccl.concept_class_id
-- left join concept_description cd on cd.concept_id=c.concept_id
-- left join drug d on d.drug_id=c.concept_id
left join concept_name cn on cn.concept_id=c.concept_id and cn.locale='en'
left join concept_reference_map crm on crm.concept_id=c.concept_id
left join concept_reference_term crt on crt.concept_reference_term_id=crm.concept_reference_term_id
left join concept_reference_source crs on crs.concept_source_id=crt.concept_source_id
where crs."name" in ('SNOMED CT', 'SNOMED NP', 'ICD-10-WHO', 'RxNORM', 'ICD-10-WHO NP', 'ICD-10-WHO 2nd', 'ICD-10-WHO NP2', 'SNOMED US', 'NDF-RT NUI');
COMMIT;

--6 Create concept_relationship_stage records
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
	select distinct
	  cm.concept_code_1 as concept_code_1,
	  case c.domain_id
		when 'Drug' then cm.concept_code_2
		else first_value(cm.concept_code_2) over (partition by c.concept_code order by cm.path ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
	  end as concept_code_2,
	'CIEL' as vocabulary_id_1,
	  case c.domain_id
		when 'Drug' then cm.vocabulary_id_2
		else first_value(cm.vocabulary_id_2) over (partition by c.concept_code order by cm.path ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
	  end as vocabulary_id_2,
	  'Maps to' as relationship_id,
	  TO_DATE ('19700101', 'yyyymmdd') as valid_start_date,
	  TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
	  null as invalid_reason
	from ciel_concept_with_map c
	join ciel_to_concept_map cm on c.concept_code=cm.concept_code_1;
COMMIT;


--7 Delete duplicate mappings (one concept has multiply target concepts)
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

--8 Delete self-connected mappings ("A 'Concept replaced by' B" and "B 'Concept replaced by' A")
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

--9 Deprecate concepts if we have no active replacement record in the concept_relationship_stage
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

--10 Deprecate replacement records if target concept was depreceted 
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

--11 Deprecate concepts if we have no active replacement record in the concept_relationship_stage (yes, again)
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

--12 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
UPDATE concept_relationship_stage crs
   SET crs.valid_end_date =
          (SELECT latest_update - 1
             FROM vocabulary
            WHERE vocabulary_id IN (crs.vocabulary_id_1, crs.vocabulary_id_2)),
       crs.invalid_reason = 'D'
 WHERE     crs.relationship_id = 'Maps to'
       AND crs.invalid_reason IS NULL
       AND EXISTS
              (SELECT 1
                 FROM concept_stage cs
                WHERE cs.concept_code = crs.concept_code_2 AND cs.vocabulary_id = crs.vocabulary_id_2 AND cs.invalid_reason IN ('U', 'D'));
COMMIT;		

--13 Add mapping from deprecated to fresh concepts
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

--14 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;

--15 Clean up
DROP TABLE ciel_concept_with_map PURGE;
DROP TABLE ciel_to_concept_map PURGE;
	
--16 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		