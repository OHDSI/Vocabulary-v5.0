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
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'ICD9CM',
                                          pVocabularyDate        => TO_DATE ('20141001', 'yyyymmdd'),
                                          pVocabularyVersion     => 'ICD9CM v32 master descriptions',
                                          pVocabularyDevSchema   => 'DEV_ICD9CM');
END;
COMMIT;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;

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
             WHEN SUBSTR (code, 1, 1) = 'E' THEN length(code)-1||'-dig billing E code'
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
             WHEN SUBSTR (code, 1, 1) = 'E' THEN length(replace(code,'.'))-1||'-dig nonbill E code'
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
           4180186 AS language_concept_id                           -- English
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
          4180186 AS language_concept_id                            -- English
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

--7 Create text for Medical Coder with new codes and mappings
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

--8 Append resulting file from Medical Coder (in concept_relationship_stage format) to concept_relationship_stage
BEGIN
   DEVV5.VOCABULARY_PACK.ProcessManualRelationships;
END;
COMMIT;


--9 Add "subsumes" relationship between concepts where the concept_code is like of another
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
	 
--10 update domain_id for ICD9CM from SNOMED
--create 1st temporary table ICD9CM_domain with direct mappings
create table filled_domain NOLOGGING as
	with domain_map2value as (--ICD9CM have direct "Maps to value" mapping
		SELECT c1.concept_code, c2.domain_id
		FROM concept_relationship_stage r, concept_stage c1, concept c2
		WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
		AND c1.vocabulary_id=r.vocabulary_id_1 AND c2.vocabulary_id=r.vocabulary_id_2
		AND r.vocabulary_id_1='ICD9CM' AND r.vocabulary_id_2='SNOMED'
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
	FROM --simplify domain_id
	( select concept_code,
		case when domain_id='Condition/Measurement' then 'Condition'
			 when domain_id='Condition/Procedure' then 'Condition'
			 when domain_id='Condition/Observation' then 'Observation'
			 when domain_id='Observation/Procedure' then 'Observation'
			 when domain_id='Measurement/Observation' then 'Observation'
			 when domain_id='Measurement/Procedure' then 'Measurement'
			 else domain_id
		end domain_id
		from ( --ICD9CM have direct "Maps to" mapping
			select concept_code, listagg(domain_id,'/') within group (order by domain_id) domain_id from (
				SELECT distinct c1.concept_code, c2.domain_id
				FROM concept_relationship_stage r, concept_stage c1, concept c2
				WHERE c1.concept_code=r.concept_code_1 AND c2.concept_code=r.concept_code_2
				AND c1.vocabulary_id=r.vocabulary_id_1 AND c2.vocabulary_id=r.vocabulary_id_2
				AND r.vocabulary_id_1='ICD9CM' AND r.vocabulary_id_2='SNOMED'
				AND r.relationship_id='Maps to'
				AND r.invalid_reason is null
			)
			group by concept_code
		)
	) d;

--create 2d temporary table with ALL ICD9CM domains
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
                        where c1.vocabulary_id='ICD9CM'
            )
            group by concept_code,prev_domain, next_domain
    );

-- INDEX was set as UNIQUE to prevent concept_code duplication
CREATE UNIQUE INDEX idx_ICD9CM_domain ON ICD9CM_domain (concept_code) NOLOGGING;

--11. simplify the list by removing Observations
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

--13. Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
COMMIT;

--14. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;	

--15. Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;		 

--16. Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

--17. Clean up
DROP TABLE ICD9CM_domain PURGE;
DROP TABLE filled_domain PURGE;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		