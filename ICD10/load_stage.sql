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
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'ICD10',
                                          pVocabularyDate        => TO_DATE ('20151109', 'yyyymmdd'),
                                          pVocabularyVersion     => '2015 Release',
                                          pVocabularyDevSchema   => 'DEV_ICD10');
END;
COMMIT;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;

--3. Load CONCEPT_STAGE from the existing one. The reason is that there is no good source for these concepts
INSERT INTO CONCEPT_STAGE (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT concept_id,
          concept_name,
          domain_id,
          vocabulary_id,
          concept_class_id,
          standard_concept,
          concept_code,
          valid_start_date,
          valid_end_date,
          invalid_reason
     FROM concept
    WHERE vocabulary_id = 'ICD10' AND invalid_reason IS NULL;
COMMIT;	

--4. Create file with mappings for medical coder from the existing one
SELECT *
  FROM concept c, concept_relationship r
 WHERE     c.concept_id = r.concept_id_1
       AND c.vocabulary_id = 'ICD10'
       AND r.invalid_reason IS NULL;

--5. Append file from medical coder to concept_relationship_stage
BEGIN
   DEVV5.VOCABULARY_PACK.ProcessManualRelationships;
END;
COMMIT;

--6. Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
COMMIT;

--7. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;	

--8. Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;		 

--9. Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

--10. Add "subsumes" relationship between concepts where the concept_code is like of another
INSERT INTO concept_relationship_stage (concept_code_1,
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
          c1.vocabulary_id AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = c1.vocabulary_id)
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM concept_stage c1, concept_stage c2
    WHERE     c2.concept_code LIKE c1.concept_code || '%'
          AND c1.concept_code <> c2.concept_code
          AND NOT EXISTS
                 (SELECT 1
                    FROM concept_relationship_stage r_int
                   WHERE     r_int.concept_code_1 = c1.concept_code
                         AND r_int.concept_code_2 = c2.concept_code
                         AND r_int.relationship_id = 'Subsumes');
COMMIT;

--11. update domain_id for ICD10 from SNOMED
--create 1st temporary table ICD10_domain with direct mappings
create table filled_domain NOLOGGING as
	with domain_map2value as (--ICD10 have direct "Maps to value" mapping
		SELECT c1.concept_code, c2.domain_id
		FROM concept_relationship_stage r, concept_stage c1, concept c2
		WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
		AND c1.vocabulary_id=r.vocabulary_id_1 AND c2.vocabulary_id=r.vocabulary_id_2
		AND r.vocabulary_id_1='ICD10' AND r.vocabulary_id_2='SNOMED'
		AND r.relationship_id='Maps to value'
		AND r.invalid_reason is null
	)
	select 
	d.concept_code,
	--some rules for domain_id
	case    when d.domain_id in ('Procedure', 'Measurement') 
				and exists (select 1 from domain_map2value t where t.concept_code=d.concept_code and t.domain_id in ('Meas Value' , 'Spec Disease Status'))
				then 'Measurement'
			when d.domain_id = 'Procedure' and exists (select 1 from domain_map2value t where t.concept_code=d.concept_code and t.domain_id = 'Condition')
				then 'Condition'
			when d.domain_id = 'Condition' and exists (select 1 from domain_map2value t where t.concept_code=d.concept_code and t.domain_id = 'Procedure')
				then 'Condition' 
			when d.domain_id = 'Observation' 
				then 'Observation'                 
			else d.domain_id
	end domain_id
	FROM 
	( select concept_code, --simplify domain_id
		case when domain_id='Condition/Measurement' then 'Condition'
			 when domain_id='Condition/Procedure' then 'Condition'
			 when domain_id='Condition/Observation' then 'Observation'
			 when domain_id='Observation/Procedure' then 'Observation'
			 when domain_id='Measurement/Observation' then 'Observation'
			 when domain_id='Measurement/Procedure' then 'Measurement'
			 else domain_id
		end domain_id
		from (--ICD10 have direct "Maps to" mapping
			select concept_code, listagg(domain_id,'/') within group (order by domain_id) domain_id from (
				SELECT distinct c1.concept_code, c2.domain_id
				FROM concept_relationship_stage r, concept_stage c1, concept c2
				WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
				AND c1.vocabulary_id=r.vocabulary_id_1 AND c2.vocabulary_id=r.vocabulary_id_2
				AND r.vocabulary_id_1='ICD10' AND r.vocabulary_id_2='SNOMED'
				AND r.relationship_id='Maps to'
				AND r.invalid_reason is null
			)
			group by concept_code
		)
	) d;

--create 2d temporary table with ALL ICD10 domains	
--if domain_id is empty we use previous and next domain_id or its combination	
create table ICD10_domain NOLOGGING as
    select concept_code, 
    case when domain_id is not null then domain_id 
    else 
        case when prev_domain=next_domain then prev_domain --prev and next domain are the same (and of course not null both)
            when prev_domain is not null and next_domain is not null then  
                case when prev_domain<next_domain then prev_domain||'/'||next_domain 
                else next_domain||'/'||prev_domain 
                end -- prev and next domain are not same and not null both, with order by name
            else coalesce (prev_domain,next_domain,'Unknown')
        end
    end domain_id
    from (
            select concept_code, LISTAGG(domain_id, '/') WITHIN GROUP (order by domain_id) domain_id, prev_domain, next_domain from (

                        select distinct c1.concept_code, r1.domain_id,
                            (select MAX(fd.domain_id) KEEP (DENSE_RANK LAST ORDER BY fd.concept_code) from filled_domain fd where fd.concept_code<c1.concept_code and r1.domain_id is null) prev_domain,
                            (select MIN(fd.domain_id) KEEP (DENSE_RANK FIRST ORDER BY fd.concept_code) from filled_domain fd where fd.concept_code>c1.concept_code and r1.domain_id is null) next_domain
                        from concept_stage c1
                        left join filled_domain r1 on r1.concept_code=c1.concept_code
                        where c1.vocabulary_id='ICD10'
            )
            group by concept_code,prev_domain, next_domain
    );
	
-- INDEX was set as UNIQUE to prevent concept_code duplication
CREATE UNIQUE INDEX idx_ICD10_domain ON ICD10_domain (concept_code) NOLOGGING;

--16 Simplify the list by removing Observations
update ICD10_domain set domain_id=trim('/' FROM replace('/'||domain_id||'/','/Observation/','/'))
where '/'||domain_id||'/' like '%/Observation/%'
and instr(domain_id,'/')<>0;

--reducing some domain_id if his length>20
update ICD10_domain set domain_id='Condition/Meas' where domain_id='Condition/Measurement';
update ICD10_domain set domain_id='Procedure' where domain_id = 'Procedure/Spec Disease Status';
update ICD10_domain set domain_id='Measurement' where domain_id='Measurement/Procedure/Spec Disease Status';
update ICD10_domain set domain_id='Measurement' where domain_id='Measurement/Spec Disease Status';
update ICD10_domain set domain_id='Measurement' where domain_id='Meas Value/Measurement/Procedure';
update ICD10_domain set domain_id='Measurement' where domain_id='Meas Value/Measurement';
update ICD10_domain set domain_id='Condition' where domain_id='Condition/Spec Disease Status';
COMMIT;

--12. update each domain_id with the domains field from ICD10_domain.
UPDATE concept_stage c
   SET (domain_id) =
          (SELECT domain_id
             FROM ICD10_domain rd
            WHERE rd.concept_code = c.concept_code)
 WHERE c.vocabulary_id = 'ICD10';
COMMIT;

--13. Clean up
DROP TABLE ICD10_domain PURGE;
DROP TABLE filled_domain PURGE;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		