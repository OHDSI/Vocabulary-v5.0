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

--1. Update latest_update field to new date 
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'CIEL',
                                          pVocabularyDate        => TO_DATE ('20150227', 'yyyymmdd'),
                                          pVocabularyVersion     => 'Openmrs 1.11.0 20150227',
                                          pVocabularyDevSchema   => 'DEV_CIEL');
END;
COMMIT;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;

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


--7 Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
COMMIT;

--8 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;	

--9 Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;		 

--10 Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

--11 Clean up
DROP TABLE ciel_concept_with_map PURGE;
DROP TABLE ciel_to_concept_map PURGE;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		