-- 1. Update latest_update field to new date 
ALTER TABLE vocabulary ADD latest_update DATE;
UPDATE vocabulary SET latest_update=to_date('20141001','yyyymmdd'), vocabulary_version='ICD9CM v32 master descriptions' WHERE vocabulary_id='ICD9CM'; 
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

--3. Load into concept_stage from CMS_DESC_LONG_DX
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
   SELECT NULL AS concept_id,
          NAME AS concept_name,
          NULL AS domain_id,
          'ICD9CM' AS vocabulary_id,
          CASE
             WHEN SUBSTR (code, 1, 1) = 'V' THEN length(code)||'-dig billing V code'
             WHEN SUBSTR (code, 1, 1) = 'E' THEN length(code)||'-dig billing E code'
             ELSE length(code)||'-dig billing code'
          END
             AS concept_class_id,
          NULL AS standard_concept,
          CASE                                        -- add dots to the codes
             WHEN SUBSTR (code, 1, 1) = 'V'
             THEN
                REGEXP_REPLACE (code, 'V([0-9]{2})([0-9]+)', 'V\1.\2') -- Dot after 2 digits for V codes
             WHEN SUBSTR (code, 1, 1) = 'E'
             THEN
                REGEXP_REPLACE (code, 'E([0-9]{3})([0-9]+)', 'E\1.\2') -- Dot after 3 digits for E codes
             ELSE
                REGEXP_REPLACE (code, '^([0-9]{3})([0-9]+)', '\1.\2') -- Dot after 3 digits for normal codes
          END
             AS concept_code,
          (select latest_update from vocabulary where vocabulary_id='ICD9CM') AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM CMS_DESC_LONG_DX;
COMMIT;					  

--4 Add codes which are not in the CMS_DESC_LONG_DX table
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
   SELECT NULL AS concept_id,
          SUBSTR (str, 1, 256) AS concept_name,
          NULL AS domain_id,
          'ICD9CM' AS vocabulary_id,
          CASE
             WHEN SUBSTR (code, 1, 1) = 'V' THEN length(replace(code,'.'))||'-dig nonbill V code'
             WHEN SUBSTR (code, 1, 1) = 'E' THEN length(replace(code,'.'))||'-dig nonbill E code'
             ELSE length(replace(code,'.'))||'-dig nonbill code'
          END 
			AS concept_class_id,
          NULL AS standard_concept,
          code AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'ICD9CM')
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM UMLS.mrconso
    WHERE     sab = 'ICD9CM'
          AND NOT code LIKE '%-%'
          AND tty = 'HT'
          AND INSTR (code, '.') != 3 -- Dot in 3rd position in Procedure codes, in UMLS also called ICD9CM
          AND LENGTH (code) != 2                             -- Procedure code
          AND code NOT IN (SELECT concept_code
                             FROM concept_stage
                            WHERE vocabulary_id = 'ICD9CM')
          AND suppress = 'N';
COMMIT;	   

--5 load into concept_synonym_stage name from both CMS_DESC_LONG_DX.txt and CMS_DESC_SHORT_DX
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   (SELECT NULL AS synonym_concept_id,
           CASE                                       -- add dots to the codes
              WHEN SUBSTR (code, 1, 1) = 'V'
              THEN
                 REGEXP_REPLACE (code, 'V([0-9]{2})([0-9]+)', 'V\1.\2') -- Dot after 2 digits for V codes
              WHEN SUBSTR (code, 1, 1) = 'E'
              THEN
                 REGEXP_REPLACE (code, 'E([0-9]{3})([0-9]+)', 'E\1.\2') -- Dot after 3 digits for E codes
              ELSE
                 REGEXP_REPLACE (code, '^([0-9]{3})([0-9]+)', '\1.\2') -- Dot after 3 digits for normal codes
           END
              AS synonym_concept_code,
           NAME AS synonym_name,
		   'ICD9CM' as synonym_vocabulary_id,
           4093769 AS language_concept_id                           -- English
      FROM (SELECT * FROM CMS_DESC_LONG_DX
            UNION
            SELECT * FROM CMS_DESC_SHORT_DX));
COMMIT;

--6 Add codes which are not in the cms_desc_long_dx table as a synonym
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   SELECT NULL AS synonym_concept_id,
          code AS synonym_concept_code,
          SUBSTR (str, 1, 256) AS synonym_name,
          'ICD9CM' AS vocabulary_id,
          4093769 AS language_concept_id                            -- English
     FROM UMLS.mrconso
    WHERE     sab = 'ICD9CM'
          AND NOT code LIKE '%-%'
          AND tty = 'HT'
          AND INSTR (code, '.') != 3 -- Dot in 3rd position in Procedure codes, in UMLS also called ICD9CM
          AND LENGTH (code) != 2                             -- Procedure code
          AND code NOT IN (SELECT concept_code
                             FROM concept_stage
                            WHERE vocabulary_id = 'ICD9CM')
          AND suppress = 'N';
COMMIT;	  

--7  Load concept_relationship_stage from the existing one. The reason is that there is no good source for these relationships, and we have to build the ones for new codes from UMLS and manually
/*
INSERT INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT NULL AS concept_id_1,
          NULL AS concept_id_2,
          c1.concept_code AS concept_code_1,
          c2.concept_code AS concept_code_2,
          c1.vocabulary_id AS vocabulary_id_1,
          c2.vocabulary_id AS vocabulary_id_2,
          r.relationship_id AS relationship_id,
          r.valid_start_date,
          r.valid_end_date,
          r.invalid_reason
     FROM concept_relationship r, concept c1, concept c2
    WHERE     c1.concept_id = r.concept_id_1
          AND (
              c1.vocabulary_id = 'ICD9CM' OR c2.vocabulary_id = 'ICD9CM'
          )
          AND C2.CONCEPT_ID = r.concept_id_2  
          AND r.invalid_reason IS NULL -- only fresh ones
          AND r.relationship_id NOT IN ('Domain subsumes', 'Is domain', 'Maps to', 'Mapped from') 
;
COMMIT;		  
*/

--8 Create text for Medical Coder with new codes and mappings
SELECT NULL AS concept_id_1,
       NULL AS concept_id_2,
       c.concept_code AS concept_code_1,
       u2.scui AS concept_code_2,
       'Maps to' AS relationship_id, -- till here strawman for concept_relationship to be checked and filled out, the remaining are supportive information to be truncated in the return file
       c.concept_name AS icd9_name,
       u2.str AS snomed_str,
       sno.concept_id AS snomed_concept_id,
       sno.concept_name AS snomed_name
  FROM concept_stage c
       LEFT JOIN
       (                                          -- UMLS record for ICD9 code
        SELECT DISTINCT cui, scui
          FROM UMLS.mrconso
         WHERE sab = 'ICD9CM' AND suppress NOT IN ('E', 'O', 'Y')) u1
          ON u1.scui = concept_code                  -- join UMLS for code one
       LEFT JOIN
       (                        -- UMLS record for SNOMED code of the same cui
        SELECT DISTINCT
               cui,
               scui,
               FIRST_VALUE (
                  str)
               OVER (PARTITION BY scui
                     ORDER BY DECODE (tty,  'PT', 1,  'PTGB', 2,  10))
                  AS str
          FROM UMLS.mrconso
         WHERE sab IN ('SNOMEDCT_US') AND suppress NOT IN ('E', 'O', 'Y')) u2
          ON u2.cui = u1.cui
       LEFT JOIN concept sno
          ON sno.vocabulary_id = 'SNOMED' AND sno.concept_code = u2.scui -- SNOMED concept
 WHERE     c.vocabulary_id = 'ICD9CM'
       AND NOT EXISTS
              (SELECT 1
                 FROM concept co
                WHERE     co.concept_code = c.concept_code
                      AND co.vocabulary_id = 'ICD9CM'); -- only new codes we don't already have

--9 Append resulting file from Medical Coder (in concept_relationship_stage format) to concept_relationship_stage
INSERT INTO concept_relationship_stage (concept_code_1,
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
            WHERE vocabulary_id = 'ICD9CM')
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM concept_relationship_manual9cm;
COMMIT;
	 
--10 update domain_id for ICD9CM from SNOMED
--create temporary table ICD9CM_domain
--if domain_id is empty we use previous and next domain_id or its combination
create table ICD9CM_domain NOLOGGING as
    select concept_code, 
    case when domain_id is not null then domain_id 
    else 
        case when prev_domain=next_domain then prev_domain --prev and next domain are the same (and of course not null both)
            when prev_domain is not null and next_domain is not null then  
                case when prev_domain<next_domain then prev_domain||'/'||next_domain 
                else next_domain||'/'||prev_domain 
                end -- prev and next domain are not same and not null both, with order by name
            else coalesce (prev_domain,next_domain,
                case concept_class_id
                    when 'ICD9CM E code' then 'Observation'
                    else 'Condition'
                end
            )
        end
    end domain_id
    from (
			select concept_code, LISTAGG(domain_id, '/') WITHIN GROUP (order by domain_id) domain_id, prev_domain, next_domain, concept_class_id from (
			with filled_domain as
						(
							select c1.concept_code, c2.domain_id
							FROM concept_relationship_stage r, concept_stage c1, concept c2
							WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
							AND c1.vocabulary_id=r.vocabulary_id_1 AND c2.vocabulary_id=r.vocabulary_id_2
							AND r.vocabulary_id_1='ICD9CM' AND r.vocabulary_id_2='SNOMED'
							AND relationship_id = 'Maps to'
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
						where c1.vocabulary_id='ICD9CM'
			)
			group by concept_code,prev_domain, next_domain, concept_class_id
    );

-- INDEX was set as UNIQUE to prevent concept_code duplication
CREATE UNIQUE INDEX idx_ICD9CM_domain ON ICD9CM_domain (concept_code) NOLOGGING;

--11. Simplify the list by removing Observations
update ICD9CM_domain set domain_id=trim('/' FROM replace('/'||domain_id||'/','/Observation/','/'))
where '/'||domain_id||'/' like '%/Observation/%'
and instr(domain_id,'/')<>0;

--reducing some domain_id if his length>20
update ICD9CM_domain set domain_id='Meas/Procedure' where domain_id='Measurement/Procedure';
update ICD9CM_domain set domain_id='Condition/Meas' where domain_id='Condition/Measurement';
--Provisional removal of Spec Disease Status, will need review
update ICD9CM_domain set domain_id='Procedure' where domain_id='Procedure/Spec Disease Status';
COMMIT;

--12. update each domain_id with the domains field from ICD9CM_domain.
UPDATE concept_stage c
   SET (domain_id) =
          (SELECT domain_id
             FROM ICD9CM_domain rd
            WHERE rd.concept_code = c.concept_code)
 WHERE c.vocabulary_id = 'ICD9CM';
COMMIT;

--13. Add mapping from deprecated to fresh concepts
INSERT  /*+ APPEND */  INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
    SELECT 
      root,
      concept_code_2,
      root_vocabulary_id,
      vocabulary_id_2,
      'Maps to',
      (SELECT latest_update FROM vocabulary WHERE vocabulary_id=root_vocabulary_id),
      TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
      NULL
    FROM 
    (
        SELECT root_vocabulary_id, root, concept_code_2, vocabulary_id_2 FROM (
          SELECT root_vocabulary_id, root, concept_code_2, vocabulary_id_2, dt,  ROW_NUMBER() OVER (PARTITION BY root_vocabulary_id, root ORDER BY dt DESC) rn
            FROM (
                SELECT 
                      concept_code_2, 
                      vocabulary_id_2,
                      valid_start_date AS dt,
                      CONNECT_BY_ROOT concept_code_1 AS root,
                      CONNECT_BY_ROOT vocabulary_id_1 AS root_vocabulary_id,
                      CONNECT_BY_ISLEAF AS lf
                FROM concept_relationship_stage
                WHERE relationship_id IN ( 'Concept replaced by',
                                               'Concept same_as to',
                                               'Concept alt_to to',
                                               'Concept poss_eq to',
                                               'Concept was_a to',
                                               'Original maps to'
                                             )
                      and NVL(invalid_reason, 'X') <> 'D'
                CONNECT BY  
                NOCYCLE  
                PRIOR concept_code_2 = concept_code_1
                      AND relationship_id IN ( 'Concept replaced by',
                                               'Concept same_as to',
                                               'Concept alt_to to',
                                               'Concept poss_eq to',
                                               'Concept was_a to',
                                               'Original maps to'
                                             )
                       AND vocabulary_id_2=vocabulary_id_1                     
                       AND NVL(invalid_reason, 'X') <> 'D'
                                   
                START WITH relationship_id IN ('Concept replaced by',
                                               'Concept same_as to',
                                               'Concept alt_to to',
                                               'Concept poss_eq to',
                                               'Concept was_a to',
                                               'Original maps to'
                                              )
                      AND NVL(invalid_reason, 'X') <> 'D'
          ) sou 
          WHERE lf = 1
        ) 
        WHERE rn = 1
    ) int_rel WHERE NOT EXISTS
    (select 1 from concept_relationship_stage r where
        int_rel.root=r.concept_code_1
        and int_rel.concept_code_2=r.concept_code_2
        and int_rel.root_vocabulary_id=r.vocabulary_id_1
        and int_rel.vocabulary_id_2=r.vocabulary_id_2
        and r.relationship_id='Maps to'
    );

COMMIT;

--14 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;

--15. Clean up
DROP TABLE ICD9CM_domain PURGE;
	
--16 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		