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
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'Read',
                                          pVocabularyDate        => TO_DATE ('20160318', 'yyyymmdd'),
                                          pVocabularyVersion     => 'NHS READV2 21.0.0 20160401000001',
                                          pVocabularyDevSchema   => 'DEV_READ');
END;
COMMIT;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;

--3. fill CONCEPT_STAGE and concept_relationship_stage from Read
INSERT /*+ APPEND */ INTO CONCEPT_STAGE (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT DISTINCT
          coalesce(kv2.description_long, kv2.description, kv2.description_short) as concept_name,
          NULL as domain_id,
          'Read' as vocabulary_id,
          'Read' as concept_class_id,
          NULL as standard_concept,
          kv2.readcode || kv2.termcode as concept_code,
          (select latest_update from vocabulary where vocabulary_id='Read') as valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
          NULL as invalid_reason
     FROM keyv2 kv2;
COMMIT;

--Add 'Maps to' from Read to SNOMED
INSERT /*+ APPEND */ INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        relationship_id,
										vocabulary_id_1,
										vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT
          RSCCT.ReadCode || RSCCT.TermCode as concept_code_1,
          -- pick the best map: mapstatus=1, then is_assured=1, then target concept is fresh, then newest date
          FIRST_VALUE (
             RSCCT.conceptid)
          OVER (
             PARTITION BY RSCCT.readcode || RSCCT.termcode
             ORDER BY
                RSCCT.mapstatus DESC,
                RSCCT.is_assured DESC,
                RSCCT.effectivedate DESC) as concept_code_2,
          'Maps to' as relationship_id,
		  'Read' as vocabulary_id_1,
		  'SNOMED' as vocabulary_id_2,
          (select latest_update from vocabulary where vocabulary_id='Read') as valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
          NULL as invalid_reason
     FROM RCSCTMAP2_UK RSCCT;
COMMIT;

--Add manual 'Maps to' from Read to RxNorm
BEGIN
   DEVV5.VOCABULARY_PACK.ProcessManualRelationships;
END;
COMMIT;

--4 Create mapping to self for fresh concepts
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
	SELECT concept_code AS concept_code_1,
		   concept_code AS concept_code_2,
		   c.vocabulary_id AS vocabulary_id_1,
		   c.vocabulary_id AS vocabulary_id_2,
		   'Maps to' AS relationship_id,
		   v.latest_update AS valid_start_date,
		   TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
		   NULL AS invalid_reason
	  FROM concept_stage c, vocabulary v
	 WHERE     c.vocabulary_id = v.vocabulary_id
		   AND c.standard_concept = 'S'
		   AND NOT EXISTS -- only new mapping we don't already have
				  (SELECT 1
					 FROM concept_relationship_stage i
					WHERE     c.concept_code = i.concept_code_1
						  AND c.concept_code = i.concept_code_2
						  AND c.vocabulary_id = i.vocabulary_id_1
						  AND c.vocabulary_id = i.vocabulary_id_2
						  AND i.relationship_id = 'Maps to');
COMMIT;

--5 Add "subsumes" relationship between concepts where the concept_code is like of another
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
INSERT /*+ APPEND */ INTO concept_relationship_stage (concept_code_1,
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
          AND NOT EXISTS -- only new mapping we don't already have
                 (SELECT 1
                    FROM concept_relationship_stage r_int
                   WHERE     r_int.concept_code_1 = c1.concept_code
                         AND r_int.concept_code_2 = c2.concept_code
                         AND r_int.relationship_id = 'Subsumes');
COMMIT;

--6 update domain_id for Read from SNOMED
--create temporary table read_domain
--if domain_id is empty we use previous and next domain_id or its combination
create table read_domain NOLOGGING as
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
			select concept_code, LISTAGG(domain_id, '/') WITHIN GROUP (order by domain_id) domain_id, prev_domain, next_domain, concept_class_id from (
			with filled_domain as
						( -- get Read concepts with direct mappings to SNOMED
							select c1.concept_code, c2.domain_id
							FROM concept_relationship_stage r, concept_stage c1, concept c2
							WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
							AND c1.vocabulary_id=r.vocabulary_id_1 AND c2.vocabulary_id=r.vocabulary_id_2
							AND r.vocabulary_id_1='Read' AND r.vocabulary_id_2='SNOMED'
							AND r.invalid_reason is null
						)

						select distinct c1.concept_code, r1.domain_id, c1.concept_class_id,
							(select MAX(fd.domain_id) KEEP (DENSE_RANK LAST ORDER BY fd.concept_code) from filled_domain fd where fd.concept_code<c1.concept_code and r1.domain_id is null) prev_domain,
							(select MIN(fd.domain_id) KEEP (DENSE_RANK FIRST ORDER BY fd.concept_code) from filled_domain fd where fd.concept_code>c1.concept_code and r1.domain_id is null) next_domain
						from concept_stage c1
						left join (
							select r.concept_code_1, r.vocabulary_id_1, c2.domain_id from concept_relationship_stage r, concept c2 
							where c2.concept_code=r.concept_code_2 
							and r.vocabulary_id_2=c2.vocabulary_id 
							and c2.vocabulary_id='SNOMED'
						) r1 on r1.concept_code_1=c1.concept_code and r1.vocabulary_id_1=c1.vocabulary_id
						where c1.vocabulary_id='Read'
			)
			group by concept_code,prev_domain, next_domain, concept_class_id
    );

-- INDEX was set as UNIQUE to prevent concept_code duplication    
CREATE UNIQUE INDEX idx_read_domain ON read_domain (concept_code) NOLOGGING;

--7 Simplify the list by removing Observations, Metadata and Type Concept
update read_domain set domain_id=trim('/' FROM replace('/'||domain_id||'/','/Observation/','/'))
where '/'||domain_id||'/' like '%/Observation/%'
and instr(domain_id,'/')<>0;

update read_domain set domain_id=trim('/' FROM replace('/'||domain_id||'/','/Metadata/','/'))
where '/'||domain_id||'/' like '%/Metadata/%'
and instr(domain_id,'/')<>0;

update read_domain set domain_id=trim('/' FROM replace('/'||domain_id||'/','/Type Concept/','/'))
where '/'||domain_id||'/' like '%/Type Concept/%'
and instr(domain_id,'/')<>0;

--reducing some domain_id if his length>20
update read_domain set domain_id='Meas/Procedure' where domain_id='Measurement/Procedure';
update read_domain set domain_id='Condition/Meas' where domain_id='Condition/Measurement';
update read_domain set domain_id='Specimen' where domain_id='Measurement/Specimen';

COMMIT;

--8 update each domain_id with the domains field from read_domain.
UPDATE concept_stage c
   SET (domain_id) =
          (SELECT domain_id
             FROM read_domain rd
            WHERE rd.concept_code = c.concept_code)
 WHERE c.vocabulary_id = 'Read';
COMMIT;

--9 Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
COMMIT;

--10 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;	

--11 Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;		 

--12 Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

--13 Clean up
DROP TABLE read_domain PURGE;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script