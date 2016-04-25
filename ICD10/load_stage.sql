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
UPDATE vocabulary SET latest_update=to_date('20151109','yyyymmdd'), vocabulary_version='2015 Release' WHERE vocabulary_id='ICD10'; 
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
INSERT /*+ APPEND */
      INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT concept_code_1,
          concept_code_2,
          vocabulary_id_1,
          vocabulary_id_2,
          relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'ICD10')
             AS valid_start_date,
          TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
          NULL AS invalid_reason
     FROM concept_relationship_manual;
COMMIT;	 

--6 Delete ambiguous 'Maps to' mappings if target concept have domain_id='Drug' and concept_class_id NOT IN ('Ingredient', 'Clinical Drug Comp')
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

--7 Delete duplicate replacement mappings (one concept has multiply target concepts)
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
            WHERE vocabulary_id IN (crs.vocabulary_id_1, crs.vocabulary_id_2) AND latest_update IS NOT NULL),
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

--14 Add "subsumes" relationship between concepts where the concept_code is like of another
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

--15 update domain_id for ICD10 from SNOMED
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

--17 update each domain_id with the domains field from ICD10_domain.
UPDATE concept_stage c
   SET (domain_id) =
          (SELECT domain_id
             FROM ICD10_domain rd
            WHERE rd.concept_code = c.concept_code)
 WHERE c.vocabulary_id = 'ICD10';
COMMIT;

DROP TABLE ICD10_domain PURGE;
DROP TABLE filled_domain PURGE;

--18 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;


--19 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		