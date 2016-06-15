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
   EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN latest_update';
EXCEPTION WHEN OTHERS THEN NULL;
END;
ALTER TABLE vocabulary ADD latest_update DATE;
update vocabulary set latest_update=to_date('20160318','yyyymmdd'), vocabulary_version='NHS READV2 21.0.0 20160401000001' where vocabulary_id='Read'; commit;

--2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
ALTER SESSION SET SKIP_UNUSABLE_INDEXES = TRUE; --disables error reporting of indexes and index partitions marked UNUSABLE
ALTER INDEX idx_cs_concept_code UNUSABLE;
ALTER INDEX idx_cs_concept_id UNUSABLE;
ALTER INDEX idx_concept_code_1 UNUSABLE;
ALTER INDEX idx_concept_code_2 UNUSABLE;

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
INSERT /*+ APPEND */ INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT * FROM CONCEPT_RELATIONSHIP_MANUAL;
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
ALTER INDEX idx_cs_concept_code UNUSABLE;				 

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

--9 Delete duplicate replacement mappings (one concept has multiply target concepts)
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

--10 Delete self-connected mappings ("A 'Concept replaced by' B" and "B 'Concept replaced by' A")
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

--11 Deprecate concepts if we have no active replacement record in the concept_relationship_stage
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

--12 Deprecate replacement records if target concept was depreceted 
MERGE INTO concept_relationship_stage r
     USING (WITH upgraded_concepts
                    AS (SELECT crs.concept_code_1,
                               crs.vocabulary_id_1,
                               crs.concept_code_2,
                               crs.vocabulary_id_2,
                               crs.relationship_id,
                               CASE WHEN COALESCE (cs.concept_code, c.concept_code) IS NULL THEN 'D' ELSE CASE WHEN cs.concept_code IS NOT NULL THEN cs.invalid_reason ELSE c.invalid_reason END END
                                  AS invalid_reason
                          FROM concept_relationship_stage crs
                               LEFT JOIN concept_stage cs ON crs.concept_code_2 = cs.concept_code AND crs.vocabulary_id_2 = cs.vocabulary_id
                               LEFT JOIN concept c ON crs.concept_code_2 = c.concept_code AND crs.vocabulary_id_2 = c.vocabulary_id
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

--13 Deprecate concepts if we have no active replacement record in the concept_relationship_stage (yes, again)
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

--14 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
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

--15 Add mapping from deprecated to fresh concepts
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

--16 Delete ambiguous 'Maps to' mappings following by rules:
--1. if we have 'true' mappings to Ingredient or Clinical Drug Comp, then delete all others mappings
--2. if we don't have 'true' mappings, then leave only one fresh mapping
--3. if we have 'true' mappings to Ingredients AND Clinical Drug Comps, then delete mappings to Ingredients, which have mappings to Clinical Drug Comp
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

--17 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;

--18 Clean up
DROP TABLE read_domain PURGE;
	
--19 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;	

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script