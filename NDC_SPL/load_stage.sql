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
update vocabulary set latest_update=to_date('20160318','yyyymmdd'), vocabulary_version='NDC 20160318' where vocabulary_id='NDC'; commit;
update vocabulary set latest_update=to_date('20160318','yyyymmdd'), vocabulary_version='NDC 20160318' where vocabulary_id='SPL'; commit;

--2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
ALTER SESSION SET SKIP_UNUSABLE_INDEXES = TRUE; --disables error reporting of indexes and index partitions marked UNUSABLE
ALTER INDEX idx_cs_concept_code UNUSABLE;
ALTER INDEX idx_cs_concept_id UNUSABLE;
ALTER INDEX idx_concept_code_1 UNUSABLE;
ALTER INDEX idx_concept_code_2 UNUSABLE;


--get aggregated dose
CREATE OR REPLACE FUNCTION GetAggrDose (active_numerator_strength in varchar2, active_ingred_unit in varchar2) return varchar2 as
z varchar2(4000);
BEGIN
    select  listagg(a_n_s||a_i_u, ' / ') WITHIN GROUP (order by lpad(a_n_s||a_i_u,50)) into z from 
    (
        select distinct regexp_substr(active_numerator_strength,'[^; ]+', 1, level) a_n_s, 
		regexp_substr(active_ingred_unit,'[^; ]+', 1, level) a_i_u  from dual
        connect by regexp_substr(active_numerator_strength, '[^; ]+', 1, level) is not null
    );
    return z;
END;
/
--get unique dose
CREATE OR REPLACE FUNCTION GetDistinctDose (active_numerator_strength in varchar2, active_ingred_unit in varchar2, p in number) return varchar2 as
z varchar2(4000);
BEGIN
	if p=1 then --distinct active_numerator_strength values
		select  listagg(a_n_s, '; ') WITHIN GROUP (order by lpad(a_n_s,50)) into z from 
		(
			select distinct regexp_substr(active_numerator_strength,'[^; ]+', 1, level) a_n_s, 
			regexp_substr(active_ingred_unit,'[^; ]+', 1, level) a_i_u  from dual
			connect by regexp_substr(active_numerator_strength, '[^; ]+', 1, level) is not null
		);
	else --distinct active_ingred_unit values (but order by active_numerator_strength!)
		select  listagg(a_i_u, '; ') WITHIN GROUP (order by lpad(a_n_s,50)) into z from 
		(
			select distinct regexp_substr(active_numerator_strength,'[^; ]+', 1, level) a_n_s, 
			regexp_substr(active_ingred_unit,'[^; ]+', 1, level) a_i_u  from dual
			connect by regexp_substr(active_numerator_strength, '[^; ]+', 1, level) is not null
		);	
	end if;
    return z;
END;
/

--3 Load upgraded SPL concepts
INSERT /*+ APPEND */ INTO CONCEPT_STAGE (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
    select spl_name as concept_name,
    case when displayname in ('COSMETIC') then 'Observation' 
        when displayname in ('MEDICAL DEVICE','OTC MEDICAL DEVICE LABEL','PRESCRIPTION MEDICAL DEVICE LABEL', 'MEDICAL FOOD', 'DIETARY SUPPLEMENT') then 'Device'
        else 'Drug'
    end as domain_id,
    'SPL' as vocabulary_id,
    case when displayname in ('BULK INGREDIENT') then 'Ingredient'
        when displayname in ('CELLULAR THERAPY', 'LICENSED MINIMALLY MANIPULATED CELLS LABEL') then 'Cellular Therapy'
        when displayname in ('COSMETIC') then 'Cosmetic'
        when displayname in ('DIETARY SUPPLEMENT') then 'Supplement'
        when displayname in ('HUMAN OTC DRUG LABEL') then 'OTC Drug'
        when displayname in ('MEDICAL DEVICE','OTC MEDICAL DEVICE LABEL','PRESCRIPTION MEDICAL DEVICE LABEL') then 'Device'
        when displayname in ('MEDICAL FOOD') then 'Food'
        when displayname in ('NON-STANDARDIZED ALLERGENIC LABEL') then 'Non-Stand Allergenic'
        when displayname in ('OTC ANIMAL DRUG LABEL') then 'Animal Drug'
        when displayname in ('PLASMA DERIVATIVE') then 'Plasma Derivative'
        when displayname in ('STANDARDIZED ALLERGENIC') then 'Standard Allergenic'
        when displayname in ('VACCINE LABEL') then 'Vaccine'
        else 'Prescription Drug'
    end as concept_class_id,
    'C' as standard_concept,
    replaced_spl as concept_code,
    to_date('19700101','YYYYMMDD') as valid_start_date,
    spl_date-1 as valid_end_date,
    'U' as invalid_reason
	from (
		select distinct first_value(coalesce(s2.concept_name, c.concept_name)) over (partition by l.replaced_spl order by s.valid_start_date, s.concept_code rows between unbounded preceding and unbounded following) spl_name,
		first_value(s.displayname) over (partition by l.replaced_spl order by s.valid_start_date, s.concept_code rows between unbounded preceding and unbounded following) displayname,
		first_value(s.valid_start_date) over (partition by l.replaced_spl order by s.valid_start_date rows between unbounded preceding and unbounded following) spl_date,
		l.replaced_spl  from spl_ext s, concept c, spl_ext s2,
		lateral (select regexp_substr(s.replaced_spl,'[^;]+', 1, level) replaced_spl from dual connect by regexp_substr(s.replaced_spl, '[^;]+', 1, level) is not null) l
		where s.replaced_spl is not null -- if there is an SPL codes ( l ) that is mentioned in another record as replaced_spl (path /document/relatedDocument/relatedDocument/setId/@root)
		and l.replaced_spl=c.concept_code(+)
		and c.vocabulary_id(+)='SPL'
		and l.replaced_spl=s2.concept_code(+)
	)
	where spl_name is not null and displayname not in ('IDENTIFICATION OF CBER-REGULATED GENERIC DRUG FACILITY','INDEXING - PHARMACOLOGIC CLASS','INDEXING - SUBSTANCE', 'WHOLESALE DRUG DISTRIBUTORS AND THIRD-PARTY LOGISTICS FACILITY REPORT');
COMMIT;

--4 Load main SPL concepts into concept_stage
INSERT /*+ APPEND */ INTO CONCEPT_STAGE (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
    select 
    substr(concept_name,1,255) concept_name,
    case when displayname in ('COSMETIC', 'MEDICAL FOOD') then 'Observation' 
        when displayname in ('MEDICAL DEVICE','OTC MEDICAL DEVICE LABEL','PRESCRIPTION MEDICAL DEVICE LABEL') then 'Device'
        else 'Drug'
    end as domain_id,
    'SPL' as vocabulary_id,
    case when displayname in ('BULK INGREDIENT') then 'Ingredient'
        when displayname in ('CELLULAR THERAPY') then 'Cellular Therapy'
        when displayname in ('COSMETIC') then 'Cosmetic'
        when displayname in ('DIETARY SUPPLEMENT') then 'Supplement'
        when displayname in ('HUMAN OTC DRUG LABEL') then 'OTC Drug'
        when displayname in ('LICENSED MINIMALLY MANIPULATED CELLS LABEL') then 'Cellular Therapy'
        when displayname in ('MEDICAL DEVICE','OTC MEDICAL DEVICE LABEL','PRESCRIPTION MEDICAL DEVICE LABEL') then 'Device'
        when displayname in ('MEDICAL FOOD') then 'Food'
        when displayname in ('NON-STANDARDIZED ALLERGENIC LABEL') then 'Non-Stand Allergenic'
        when displayname in ('OTC ANIMAL DRUG LABEL') then 'Animal Drug'
        when displayname in ('PLASMA DERIVATIVE') then 'Plasma Derivative'
        when displayname in ('STANDARDIZED ALLERGENIC') then 'Standard Allergenic'
        when displayname in ('VACCINE LABEL') then 'Vaccine'
        else 'Prescription Drug'
    end as concept_class_id,
    'C' as standard_concept,
    concept_code,
    valid_start_date,
    to_date('20991231','YYYYMMDD') as valid_end_date,
    null as invalid_reason
    from spl_ext s where displayname not in ('IDENTIFICATION OF CBER-REGULATED GENERIC DRUG FACILITY','INDEXING - PHARMACOLOGIC CLASS','INDEXING - SUBSTANCE', 'WHOLESALE DRUG DISTRIBUTORS AND THIRD-PARTY LOGISTICS FACILITY REPORT')
	AND NOT EXISTS (
		SELECT 1 FROM CONCEPT_STAGE cs_int WHERE lower(s.concept_code)=lower(cs_int.concept_code)
	);	
COMMIT;	

--5 Load other SPL into concept_stage (from 'product')
INSERT /*+ APPEND */ INTO CONCEPT_STAGE (concept_id,
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
	CASE -- add [brandname] if proprietaryname exists and not identical to nonproprietaryname
		WHEN brand_name IS NULL THEN SUBSTR (TRIM(concept_name), 1, 255)
		ELSE SUBSTR (TRIM(concept_name) || ' [' || brand_name || ']', 1, 255)
	END AS concept_name,
	'Drug' AS domain_id,
	'SPL' AS vocabulary_id,
	concept_class_id,
	'C' AS standard_concept,
	concept_code,
	COALESCE (valid_start_date, latest_update) AS valid_start_date,
	TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
	from --get unique and aggregated data from source
	(           
		select concept_code, concept_class_id, MULTI_NONPROPRIETARYNAME,
		case when MULTI_NONPROPRIETARYNAME is null then 
			substr(nonproprietaryname,1,100)||case when length(nonproprietaryname)>100 then '...' end||NULLIF(' '||substr(aggr_dose,1,100),' ')||' '||substr(routename,1,100)||' '||substr(dosageformname,1,100)
		else
			'Multiple formulations: '||substr(nonproprietaryname,1,100)||case when length(nonproprietaryname)>100 then '...' end||NULLIF(' '||substr(aggr_dose,1,100),' ')||' '||substr(routename,1,100)||' '||substr(dosageformname,1,100)
		end as concept_name,
		SUBSTR(brand_name,1,255) as brand_name,
		valid_start_date
		from (
			with t as 
			(
				select concept_code, concept_class_id, valid_start_date,
				GetAggrDose(active_numerator_strength,active_ingred_unit) aggr_dose from (
					select distinct concept_code, concept_class_id,             
					LISTAGG (active_numerator_strength,'; ')WITHIN GROUP (ORDER BY active_numerator_strength||active_ingred_unit) OVER (partition by concept_code) AS active_numerator_strength,
					LISTAGG (active_ingred_unit,'; ')WITHIN GROUP (ORDER BY active_numerator_strength||active_ingred_unit) OVER (partition by concept_code) AS active_ingred_unit,
					valid_start_date from (
						select concept_code, concept_class_id, active_numerator_strength, active_ingred_unit,
						min(valid_start_date) OVER (partition by concept_code) as valid_start_date
						from (
						select 
							   GetDistinctDose (active_numerator_strength,active_ingred_unit,1) as active_numerator_strength,
							   GetDistinctDose (active_numerator_strength,active_ingred_unit,2) as active_ingred_unit,
							   SUBSTR (productid, INSTR (productid, '_') + 1) AS concept_code,
							   CASE producttypename
								  WHEN 'VACCINE' THEN 'Vaccine'
								  WHEN 'STANDARDIZED ALLERGENIC' THEN 'Standard Allergenic'
								  WHEN 'HUMAN PRESCRIPTION DRUG' THEN 'Prescription Drug'
								  WHEN 'HUMAN OTC DRUG' THEN 'OTC Drug'
								  WHEN 'PLASMA DERIVATIVE' THEN 'Plasma Derivative'
								  WHEN 'NON-STANDARDIZED ALLERGENIC' THEN 'Non-Stand Allergenic'
								  WHEN 'CELLULAR THERAPY' THEN 'Cellular Therapy'
							   END
								  AS concept_class_id,
							   startmarketingdate AS valid_start_date
						  FROM product
						) group by concept_code, concept_class_id, active_numerator_strength, active_ingred_unit, valid_start_date
					)
				)
			),
			prod as 
			(select SUBSTR (productid, INSTR (productid, '_') + 1) AS concept_code, 
				DOSAGEFORMNAME, ROUTENAME, proprietaryname, nonproprietaryname, proprietarynamesuffix,
				active_numerator_strength, active_ingred_unit
				from product
			)
			 
			select t1.*,  
			--aggregated unique DOSAGEFORMNAME
			(select listagg(DOSAGEFORMNAME,', ') within group (order by DOSAGEFORMNAME) from (select distinct P.DOSAGEFORMNAME from prod p where p.concept_code=t1.concept_code)) as DOSAGEFORMNAME, 
			--aggregated unique ROUTENAME
			(select listagg(ROUTENAME,', ') within group (order by ROUTENAME) from (select distinct P.ROUTENAME from prod p where p.concept_code=t1.concept_code)) as ROUTENAME,
			--aggregated unique NONPROPRIETARYNAME
			(select listagg(NONPROPRIETARYNAME,', ') within group (order by NONPROPRIETARYNAME) from (select distinct lower(P.NONPROPRIETARYNAME) NONPROPRIETARYNAME from prod p where p.concept_code=t1.concept_code)  where rownum<15) as NONPROPRIETARYNAME,
			--multiple formulations flag
			(select count(lower(P.NONPROPRIETARYNAME)) from prod p where p.concept_code=t1.concept_code having count(distinct lower(P.NONPROPRIETARYNAME))>1) as MULTI_NONPROPRIETARYNAME,
			(
				select listagg(brand_name,', ') within group (order by brand_name) from 
				(select distinct CASE WHEN (lower(proprietaryname) <> lower(nonproprietaryname) OR nonproprietaryname is null)
								 THEN LOWER(TRIM(proprietaryname || ' ' || proprietarynamesuffix))
								 ELSE NULL
								 END AS brand_name 
				from prod p where p.concept_code=t1.concept_code
				) where rownum<50 --brand_name may be too long for concatenation
			) as brand_name
			from t t1
		)
	) s, vocabulary v
	WHERE v.vocabulary_id = 'SPL'
	AND NOT EXISTS (
		SELECT 1 FROM CONCEPT_STAGE cs_int WHERE lower(s.concept_code)=lower(cs_int.concept_code)
	);

COMMIT;

--6 Add upgrade SPL relationships
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
                                        
	select spl_code as concept_code_1,
	replaced_spl as concept_code_2,
	'SPL' as vocabulary_id_1,
	'SPL' as vocabulary_id_2,
	'Concept replaced by' as relationship_id,
	spl_date-1 as valid_start_date,
	to_date('20991231','YYYYMMDD') as valid_end_date,
	NULL as invalid_reason
	from (
		select distinct first_value(s.concept_code) over (partition by l.replaced_spl order by s.valid_start_date, s.concept_code rows between unbounded preceding and unbounded following) spl_code, 
		first_value(s.valid_start_date) over (partition by l.replaced_spl order by s.valid_start_date, s.concept_code rows between unbounded preceding and unbounded following) spl_date,
		l.replaced_spl  from spl_ext s,
		lateral (select regexp_substr(s.replaced_spl,'[^;]+', 1, level) replaced_spl from dual connect by regexp_substr(s.replaced_spl, '[^;]+', 1, level) is not null) l
		where s.replaced_spl is not null -- if there is an SPL codes ( l ) that is mentioned in another record as replaced_spl (path /document/relatedDocument/relatedDocument/setId/@root)
	);

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
                               cs.invalid_reason
                          FROM concept_relationship_stage crs, concept_stage cs
                         WHERE     crs.relationship_id IN ('Concept replaced by',
                                                           'Concept same_as to',
                                                           'Concept alt_to to',
                                                           'Concept poss_eq to',
                                                           'Concept was_a to')
                               AND crs.invalid_reason IS NULL
                               AND crs.concept_code_2 = cs.concept_code
                               AND crs.vocabulary_id_2 = cs.vocabulary_id
                               AND crs.vocabulary_id_1 = crs.vocabulary_id_2
                               AND crs.concept_code_1 <> crs.concept_code_2)
                SELECT u.concept_code_1,
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

--14 Load NDC into temporary table from 'product'
CREATE TABLE MAIN_NDC NOLOGGING AS SELECT * FROM CONCEPT_STAGE WHERE 1=0;

INSERT /*+ APPEND */ INTO MAIN_NDC 			   
    SELECT NULL AS concept_id,
    CASE -- add [brandname] if proprietaryname exists and not identical to nonproprietaryname
        WHEN brand_name IS NULL THEN SUBSTR (TRIM(concept_name), 1, 255)
        ELSE SUBSTR (TRIM(concept_name) || ' [' || brand_name || ']', 1, 255)
    END AS concept_name,
    'Drug' AS domain_id,
    'NDC' AS vocabulary_id,
    '9-digit NDC' AS concept_class_id,
    NULL AS standard_concept,
    concept_code,
    COALESCE (valid_start_date, latest_update) AS valid_start_date,
    TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
    NULL AS invalid_reason
    from --get unique and aggregated data from source
    (           
        select concept_code,
        case when MULTI_NONPROPRIETARYNAME is null then 
            substr(nonproprietaryname,1,100)||case when length(nonproprietaryname)>100 then '...' end||NULLIF(' '||substr(aggr_dose,1,100),' ')||' '||substr(routename,1,100)||' '||substr(dosageformname,1,100)
        else
            'Multiple formulations: '||substr(nonproprietaryname,1,100)||case when length(nonproprietaryname)>100 then '...' end||NULLIF(' '||substr(aggr_dose,1,100),' ')||' '||substr(routename,1,100)||' '||substr(dosageformname,1,100)
        end as concept_name,
        SUBSTR(brand_name,1,255) as brand_name,
        valid_start_date
        from (
            with t as 
            (
                select concept_code, valid_start_date,
                GetAggrDose(active_numerator_strength,active_ingred_unit) aggr_dose from (
                    select distinct concept_code,             
                    LISTAGG (active_numerator_strength,'; ')WITHIN GROUP (ORDER BY active_numerator_strength||active_ingred_unit) OVER (partition by concept_code) AS active_numerator_strength,
                    LISTAGG (active_ingred_unit,'; ')WITHIN GROUP (ORDER BY active_numerator_strength||active_ingred_unit) OVER (partition by concept_code) AS active_ingred_unit,
                    valid_start_date from (
                        select concept_code, active_numerator_strength, active_ingred_unit,
                        min(valid_start_date) OVER (partition by concept_code) as valid_start_date
                        from (
                        select 
                               GetDistinctDose (active_numerator_strength,active_ingred_unit,1) as active_numerator_strength,
                               GetDistinctDose (active_numerator_strength,active_ingred_unit,2) as active_ingred_unit,
                               CASE WHEN INSTR (productndc, '-') = 5
                               THEN '0' || SUBSTR (productndc,1,INSTR (productndc, '-') - 1)
                               ELSE SUBSTR (productndc, 1, INSTR (productndc, '-') - 1)
                               END|| CASE WHEN LENGTH ( SUBSTR (productndc, INSTR (productndc, '-'))) = 4
                               THEN '0' || SUBSTR(productndc, INSTR (productndc, '-') + 1)
                               ELSE SUBSTR (productndc,INSTR (productndc, '-') + 1)
                               END AS concept_code,
                               startmarketingdate AS valid_start_date
                          FROM product
                        ) group by concept_code, active_numerator_strength, active_ingred_unit, valid_start_date
                    )
                )
            ),
            prod as 
            (select CASE WHEN INSTR (productndc, '-') = 5
                    THEN '0' || SUBSTR (productndc,1,INSTR (productndc, '-') - 1)
                    ELSE SUBSTR (productndc, 1, INSTR (productndc, '-') - 1)
                    END|| CASE WHEN LENGTH ( SUBSTR (productndc, INSTR (productndc, '-'))) = 4
                    THEN '0' || SUBSTR(productndc, INSTR (productndc, '-') + 1)
                    ELSE SUBSTR (productndc,INSTR (productndc, '-') + 1)
                    END AS concept_code, 
                DOSAGEFORMNAME, ROUTENAME, proprietaryname, nonproprietaryname, proprietarynamesuffix,
                active_numerator_strength, active_ingred_unit
                from product
            )
             
            select t1.*,  
			--aggregated unique DOSAGEFORMNAME
            (select listagg(DOSAGEFORMNAME,', ') within group (order by DOSAGEFORMNAME) from (select distinct P.DOSAGEFORMNAME from prod p where p.concept_code=t1.concept_code)) as DOSAGEFORMNAME, 
            --aggregated unique ROUTENAME
			(select listagg(ROUTENAME,', ') within group (order by ROUTENAME) from (select distinct P.ROUTENAME from prod p where p.concept_code=t1.concept_code)) as ROUTENAME,
            --aggregated unique NONPROPRIETARYNAME
			(select listagg(NONPROPRIETARYNAME,', ') within group (order by NONPROPRIETARYNAME) from (select distinct lower(P.NONPROPRIETARYNAME) NONPROPRIETARYNAME from prod p where p.concept_code=t1.concept_code)  where rownum<15) as NONPROPRIETARYNAME,
			--multiple formulations flag
			(select count(lower(P.NONPROPRIETARYNAME)) from prod p where p.concept_code=t1.concept_code having count(distinct lower(P.NONPROPRIETARYNAME))>1) as MULTI_NONPROPRIETARYNAME,
            (
                select listagg(brand_name,', ') within group (order by brand_name) from 
                (select distinct CASE WHEN (lower(proprietaryname) <> lower(nonproprietaryname) OR nonproprietaryname is null)
                                 THEN LOWER(TRIM(proprietaryname || ' ' || proprietarynamesuffix))
                                 ELSE NULL
                                 END AS brand_name 
                from prod p where p.concept_code=t1.concept_code
                ) where rownum<50 --brand_name may be too long for concatenation
            ) as brand_name
            from t t1
        )
    ), vocabulary v
    WHERE v.vocabulary_id = 'NDC';

COMMIT;

--15 Add NDC to MAIN_NDC from rxnconso
INSERT /*+ APPEND */ INTO MAIN_NDC (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT DISTINCT NULL AS concept_id,
                   SUBSTR (c.str, 1, 255) AS concept_name,
                   'Drug' AS domain_id,
                   'NDC' AS vocabulary_id,
                   '11-digit NDC' AS concept_class_id,
                   NULL AS standard_concept,
                   s.atv AS concept_code,
                   latest_update AS valid_start_date,
                   TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
                   NULL AS invalid_reason
     FROM rxnsat s
          JOIN rxnconso c
             ON c.sab = 'RXNORM' AND c.rxaui = s.rxaui AND c.rxcui = s.rxcui AND c.suppress = 'N'
          JOIN vocabulary v ON v.vocabulary_id = 'NDC'
    WHERE s.sab = 'RXNORM' AND s.atn = 'NDC';
COMMIT;

--16 Add additional NDC with fresh dates and active mapping to RxCUI (source: http://rxnav.nlm.nih.gov/REST/ndcstatus?history=1&ndc=xxx) [part 1 of 3]
INSERT /*+ APPEND */ INTO concept_stage (
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)

    select SUBSTR(concept_name,1,255) as concept_name, 
    'Drug' as domain_id,
    'NDC' as vocabulary_id,
    '11-digit NDC' AS concept_class_id,
    NULL AS standard_concept,
    concept_code,
    startDate as valid_start_date,
    endDate as valid_end_date,
    invalid_reason
from (
    select n.concept_code, n.startDate, n.endDate, n.INVALID_REASON, coalesce(mn.concept_name,c.concept_name,max(spl.concept_name)) concept_name from (
      select ndc.concept_code, startDate,
            case when status='Active' then to_date ('20991231', 'yyyymmdd') else endDate end endDate,
            case when status='Active' then null else 'D' end INVALID_REASON        
            From ndc_history ndc        
            where ndc.activeRxcui=(
                select ndc_int.activeRxcui from ndc_history ndc_int, concept c_int
                where c_int.vocabulary_id='RxNorm'
                and ndc_int.activeRxcui=c_int.concept_code
                and ndc_int.concept_code=ndc.concept_code
                order by c_int.invalid_reason NULLS FIRST, c_int.valid_start_date desc,
                case c_int.concept_class_id when 'Branded Pack' then 1 when 'Quant Branded Drug' then 2 when 'Branded Drug' then 3
                when 'Clinical Pack' then 4 when 'Quant Clinical Drug' then 5 when 'Clinical Drug' then 6 else 7 end, c_int.concept_id
                FETCH FIRST 1 ROW ONLY
            )
    ) n
    left join MAIN_NDC mn on mn.concept_code=n.concept_code and mn.vocabulary_id='NDC' --first search name in old sources
    left join concept c on c.concept_code=n.concept_code and c.vocabulary_id='NDC' --search name in concept
    left join SPL2NDC_MAPPINGS s on n.concept_code=s.ndc_code --take name from SPL
    left join spl_ext spl on spl.concept_code=s.concept_code
    group by n.concept_code, n.startDate, n.endDate, n.INVALID_REASON, mn.concept_name, c.concept_name
) where concept_name is not null;
COMMIT;

--17 Create temporary table for NDC who have't activerxcui (same source). Take dates from coalesce(NDC API, big XML (SPL), MAIN_NDC, concept, default dates)
CREATE TABLE ADDITIONALNDCINFO nologging AS
    WITH FUNCTION CheckNDCDate (pDate IN VARCHAR2, pDateDefault IN DATE)
            RETURN DATE
         IS
            iDate   DATE;
         BEGIN
            RETURN COALESCE (TO_DATE (pDate, 'YYYYMMDD'), pDateDefault);
         EXCEPTION
            WHEN OTHERS
            THEN
               RETURN pDateDefault;
         END;
    select concept_code, coalesce(startdate,min(l.ndc_valid_start_date)) valid_start_date, coalesce(enddate,max(h.ndc_valid_end_date)) valid_end_date, substr(coalesce(c_name1,c_name2,max(spl_name)),1,255) concept_name from (
        select /*+ no_merge */ n.concept_code, n.startdate, n.enddate, spl.low_value, spl.high_value, mn.concept_name c_name1, c.concept_name c_name2, spl.concept_name spl_name, 
        mn.valid_start_date c_st_date1, mn.valid_end_date c_end_date1,c.valid_start_date c_st_date2, c.valid_end_date c_end_date2
        From 
        ndc_history n
        left join MAIN_NDC mn on mn.concept_code=n.concept_code and mn.vocabulary_id='NDC'
        left join concept c on c.concept_code=n.concept_code and c.vocabulary_id='NDC'        
        left join SPL2NDC_MAPPINGS s on n.concept_code=s.ndc_code
        left join spl_ext spl on spl.concept_code=s.concept_code
        where n.activerxcui is null
    ) n,
    lateral (select min(CheckNDCDate(regexp_substr(n.low_value,'[^;]+', 1, level), coalesce(n.c_st_date1, n.c_st_date2, to_date('19700101','YYYYMMDD')))) ndc_valid_start_date from dual connect by regexp_substr(n.low_value, '[^;]+', 1, level) is not null) l,
    lateral (select max(CheckNDCDate(regexp_substr(n.high_value,'[^;]+', 1, level),coalesce(n.c_end_date1, n.c_end_date2, to_date('20991231','YYYYMMDD')))) ndc_valid_end_date from dual connect by regexp_substr(n.high_value, '[^;]+', 1, level) is not null) h
 group by concept_code, startdate, enddate, c_name1,c_name2;

--18 Add additional NDC with fresh dates from previous temporary table (ADDITIONALNDCINFO) [part 2 of 3]
 INSERT /*+ APPEND */ INTO concept_stage (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT concept_name,
          'Drug' AS domain_id,
          'NDC' AS vocabulary_id,
          LENGTH (concept_code) || '-digit NDC' AS concept_class_id,
          NULL AS standard_concept,
          concept_code,
          valid_start_date,
          valid_end_date,
          CASE
             WHEN valid_end_date = TO_DATE ('20991231', 'yyyymmdd') THEN NULL
             ELSE 'D'
          END
             AS invalid_reason
     FROM ADDITIONALNDCINFO WHERE CONCEPT_NAME IS NOT NULL;
COMMIT;	 

--19 Create temporary table for NDC mappings to RxNorm (source: http://rxnav.nlm.nih.gov/REST/rxcui/xxx/allndcs?history=1)
CREATE TABLE RXNORM2NDC_MAPPINGS_EXT NOLOGGING AS    
select concept_code, ndc_code, startDate, endDate, invalid_reason, coalesce(c_name1,c_name2,last_rxnorm_name) concept_name from (
    select distinct mp.concept_code, mn.concept_name c_name1,c.concept_name c_name2,
    last_value(rxnorm.concept_name) over (partition by mp.ndc_code order by rxnorm.valid_start_date, rxnorm.concept_id rows between unbounded preceding and unbounded following) last_rxnorm_name,
    mp.startDate, mp.ndc_code,
    case when mp.endDate=mp.max_end_date then to_date ('20991231', 'yyyymmdd') else mp.endDate end endDate,
    case when mp.endDate=mp.max_end_date then null else 'D' end invalid_reason
    from (    
        select concept_code, ndc_code, startDate, endDate, max(endDate) over() max_end_date from rxnorm2ndc_mappings
    ) mp
    left join MAIN_NDC mn on mn.concept_code=mp.ndc_code and mn.vocabulary_id='NDC' --first search name in old sources
    left join concept c on c.concept_code=mp.ndc_code and c.vocabulary_id='NDC' --search name in concept
    left join concept rxnorm on rxnorm.concept_code=mp.concept_code and rxnorm.vocabulary_id='RxNorm' --take name from RxNorm
);

--20 Add additional NDC with fresh dates from previous temporary table (RXNORM2NDC_MAPPINGS_EXT) [part 3 of 3]
INSERT /*+ APPEND */ INTO  CONCEPT_STAGE (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT distinct concept_name,
          'Drug' AS domain_id,
          'NDC' AS vocabulary_id,
          '11-digit NDC' AS concept_class_id,
          NULL AS standard_concept,
          ndc_code AS concept_code,
          first_value(startDate) over (partition by ndc_code order by startDate rows between unbounded preceding and unbounded following) as valid_start_date,
          last_value(endDate) over (partition by ndc_code order by endDate rows between unbounded preceding and unbounded following) as valid_end_date,
          last_value(invalid_reason) over (partition by ndc_code order by endDate rows between unbounded preceding and unbounded following) as invalid_reason
     FROM RXNORM2NDC_MAPPINGS_EXT m
     WHERE NOT EXISTS
             (SELECT 1
                FROM concept_stage cs_int
               WHERE     cs_int.concept_code = m.ndc_code
                     AND cs_int.vocabulary_id = 'NDC');
COMMIT;	 

--21 Add all other NDC from 'product'
INSERT /*+ APPEND */ INTO  CONCEPT_STAGE
   SELECT *
     FROM MAIN_NDC m
    WHERE NOT EXISTS
             (SELECT 1
                FROM concept_stage cs_int
               WHERE     cs_int.concept_code = m.concept_code
                     AND cs_int.vocabulary_id = 'NDC');
COMMIT;			 

--15 Add mapping from SPL to RxNorm through RxNorm API (source: http://rxnav.nlm.nih.gov/REST/rxcui/xxx/property?propName=SPL_SET_ID)
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT spl_code AS concept_code_1,
          concept_code AS concept_code_2,
          'SPL' AS vocabulary_id_1,
          'RxNorm' AS vocabulary_id_2,
          'SPL - RxNorm' AS relationship_id,
          TO_DATE ('19700101', 'YYYYMMDD') AS valid_start_date,
          TO_DATE ('20991231', 'YYYYMMDD') AS valid_end_date,
          NULL AS invalid_reason
     FROM rxnorm2spl_mappings rm
    WHERE spl_code IS NOT NULL
	AND NOT EXISTS (SELECT 1 FROM concept c WHERE c.concept_code=rm.concept_code AND c.vocabulary_id='RxNorm' AND c.concept_class_id='Ingredient');
COMMIT;

--22 Add mapping from SPL to RxNorm through rxnsat
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT a.atv AS concept_code_1,
                   b.code AS concept_code_2,
                   'SPL' AS vocabulary_id_1,
                   'RxNorm' AS vocabulary_id_2,
                   'SPL - RxNorm' AS relationship_id,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
                   NULL AS invalid_reason
     FROM rxnsat a
          JOIN rxnsat b ON a.rxcui = b.rxcui
          JOIN vocabulary v ON v.vocabulary_id = 'SPL'
    WHERE     a.sab = 'MTHSPL'
          AND a.atn = 'SPL_SET_ID'
          AND b.sab = 'RXNORM'
          AND b.atn = 'RXN_HUMAN_DRUG'
		  AND NOT EXISTS (
			SELECT 1 FROM concept_relationship_stage crs_int
			WHERE crs_int.concept_code_1=a.atv
			AND crs_int.concept_code_2=b.code
			AND crs_int.relationship_id='SPL - RxNorm'
			AND crs_int.vocabulary_id_1='SPL'
			AND crs_int.vocabulary_id_2='RxNorm'
		  );
COMMIT;

--23 Add mapping from NDC to RxNorm from rxnconso
INSERT /*+ APPEND */ INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT s.atv AS concept_code_1,        
                   c.rxcui AS concept_code_2,  
                   'NDC' AS vocabulary_id_1,
                   'RxNorm' AS vocabulary_id_2,
                   'Maps to' AS relationship_id,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
                   NULL AS invalid_reason
     FROM rxnsat s
          JOIN rxnconso c
             ON c.sab = 'RXNORM' AND c.rxaui = s.rxaui AND c.rxcui = s.rxcui AND c.suppress = 'N'
          JOIN vocabulary v ON v.vocabulary_id = 'NDC'
    WHERE s.sab = 'RXNORM' AND s.atn = 'NDC';
COMMIT;		

INSERT /*+ APPEND */ INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT first_half || second_half AS concept_code_1,
          concept_code_2,
          'NDC' AS vocabulary_id_1,
          'RxNorm' AS vocabulary_id_2,
          'Maps to' AS relationship_id,
          valid_start_date,
          TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
          NULL AS invalid_reason
     FROM (SELECT DISTINCT
                  CASE
                     WHEN INSTR (productndc, '-') = 5
                     THEN
                           '0'
                        || SUBSTR (productndc,
                                   1,
                                   INSTR (productndc, '-') - 1)
                     ELSE
                        SUBSTR (productndc, 1, INSTR (productndc, '-') - 1)
                  END
                     AS first_half,
                  CASE
                     WHEN LENGTH (
                             SUBSTR (productndc, INSTR (productndc, '-'))) =
                             4
                     THEN
                           '0'
                        || SUBSTR (productndc, INSTR (productndc, '-') + 1)
                     ELSE
                        SUBSTR (productndc, INSTR (productndc, '-') + 1)
                  END
                     AS second_half,
                  v.latest_update AS valid_start_date,
                  r.rxcui AS concept_code_2             -- RxNorm concept_code
             FROM product p
                  JOIN rxnconso c
                     ON c.code = p.productndc AND c.sab = 'MTHSPL' AND c.suppress = 'N'
                  JOIN rxnconso r ON r.rxcui = c.rxcui and r.sab='RXNORM' AND r.suppress = 'N'
                  JOIN vocabulary v ON v.vocabulary_id = 'NDC');
COMMIT;		
			
--24 Add additional mapping for NDC codes 
--The 9-digit NDC codes that have no mapping can be mapped to the same concept of the 11-digit NDC codes, if all 11-digit NDC codes agree on the same destination Concept
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_stage', estimate_percent  => null, cascade  => true);
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_relationship_stage', estimate_percent  => null, cascade  => true);

INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
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
          valid_start_date,
          valid_end_date,
          invalid_reason
     FROM (SELECT concept_code_1,
                  concept_code_2,
                  vocabulary_id_1,
                  vocabulary_id_2,
                  relationship_id,
                  valid_start_date,
                  valid_end_date,
                  invalid_reason,
                  COUNT (DISTINCT concept_code_2) OVER (partition by concept_code_1) cnt
             FROM (WITH t_map
                        AS (SELECT c.concept_code AS concept_code_9
                              FROM CONCEPT_STAGE c, CONCEPT_STAGE c1
                             WHERE     c.vocabulary_id = 'NDC'
                                   AND c.concept_class_id = '9-digit NDC'
                                   AND c1.concept_code LIKE
                                          c.concept_code || '%'
                                   AND c1.vocabulary_id = 'NDC'
                                   AND c1.concept_class_id = '11-digit NDC'
                                   AND NOT EXISTS
                                          (SELECT 1
                                             FROM concept_relationship_stage r_int
                                            WHERE     r_int.concept_code_1 =
                                                         c.concept_code
                                                  AND r_int.vocabulary_id_1 =
                                                         c.vocabulary_id))
                     SELECT t.concept_code_9 AS concept_code_1,
                            r.concept_code_2 AS concept_code_2,
                            r.vocabulary_id_1 AS vocabulary_id_1,
                            r.vocabulary_id_2 AS vocabulary_id_2,
                            r.relationship_id AS relationship_id,
                            r.valid_start_date AS valid_start_date,
                            r.valid_end_date AS valid_end_date,
                            r.invalid_reason AS invalid_reason
                       FROM concept_relationship_stage r, t_map t
                      WHERE     r.concept_code_1 LIKE t.concept_code_9 || '%'
                            AND r.vocabulary_id_1 = 'NDC'
                            AND r.relationship_id = 'Maps to'
                            AND r.vocabulary_id_2 = 'RxNorm'
                   GROUP BY t.concept_code_9,
                            r.concept_code_2,
                            r.vocabulary_id_1,
                            r.vocabulary_id_2,
                            r.relationship_id,
                            r.valid_start_date,
                            r.valid_end_date,
                            r.invalid_reason))
    WHERE cnt = 1;
COMMIT;

--25 MERGE concepts from fresh sources (RXNORM2NDC_MAPPINGS_EXT). Add/merge only fresh mappings
MERGE INTO concept_relationship_stage crs
     USING (
        select distinct ndc_code, 
        last_value(concept_code) over(partition by ndc_code order by invalid_reason nulls last, startDate rows between unbounded preceding and unbounded following) as concept_code, 
        last_value(startDate) over(partition by ndc_code order by invalid_reason nulls last, startDate rows between unbounded preceding and unbounded following) as startDate,
        last_value(invalid_reason) over(partition by ndc_code order by invalid_reason nulls last, startDate rows between unbounded preceding and unbounded following) as invalid_reason
        from RXNORM2NDC_MAPPINGS_EXT
     ) m
        ON (    crs.concept_code_1 = m.ndc_code
            AND crs.concept_code_2 = m.concept_code
            AND crs.relationship_id = 'Maps to'
            AND crs.vocabulary_id_1 = 'NDC'
            AND crs.vocabulary_id_2 = 'RxNorm')
WHEN MATCHED
THEN
   UPDATE SET
      crs.valid_start_date = m.startdate,
      crs.valid_end_date = TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
      crs.invalid_reason = m.invalid_reason
   WHERE m.invalid_reason IS NULL
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
       VALUES (m.ndc_code,
               m.concept_code,
               'NDC',
               'RxNorm',
               'Maps to',
               m.startdate,
               TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
               NULL);
COMMIT;  


--26 Add manual source
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT *
     FROM manual_concept_relationship m_r
    WHERE NOT EXISTS
             (SELECT 1
                FROM concept_relationship_stage r_int
               WHERE     r_int.concept_code_1 = m_r.concept_code_1
                     AND r_int.concept_code_2 = m_r.concept_code_2
                     AND r_int.vocabulary_id_1 = 'NDC'
                     AND r_int.vocabulary_id_2 = 'RxNorm'
                     AND r_int.relationship_id = m_r.relationship_id);
COMMIT;

--27 delete duplicate mappings to packs
delete from concept_relationship_stage r where
r.relationship_id='Maps to' and r.invalid_reason is null
and r.vocabulary_id_1='NDC'
and r.vocabulary_id_2='RxNorm'
and concept_code_1 in (
    --get all duplicate NDC mappings to packs
    select concept_code_1 from concept_relationship_stage r_int
    where r_int.relationship_id='Maps to' and r_int.invalid_reason is null
    and r_int.vocabulary_id_1='NDC'
    and r_int.vocabulary_id_2='RxNorm'
    group by concept_code_1 having count(*)>1
)
and concept_code_2 not in (
    --exclude 'true' mappings [Branded->Clinical]
    select c_int.concept_code from concept_relationship_stage r_int, concept c_int 
    where r_int.relationship_id='Maps to' and r_int.invalid_reason is null
    and r_int.vocabulary_id_1=r.vocabulary_id_1
    and r_int.vocabulary_id_2=r.vocabulary_id_2
    and c_int.concept_code=r_int.concept_code_2
    and c_int.vocabulary_id=r_int.vocabulary_id_2
    and r_int.concept_code_1=r.concept_code_1
    order by c_int.invalid_reason NULLS FIRST,
    case c_int.concept_class_id when 'Branded Pack' then 1 when 'Clinical Pack' then 2 when 'Quant Branded Drug' then 3
    when 'Quant Clinical Drug' then 4 when 'Branded Drug' then 5 when 'Clinical Drug' then 6 else 7 end, 
    c_int.valid_start_date desc, c_int.concept_id
    fetch first 1 row only
);
COMMIT;

--28 Delete duplicate mappings (one concept has multiply target concepts)
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

--29 Delete self-connected mappings ("A 'Concept replaced by' B" and "B 'Concept replaced by' A")
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

--30 Deprecate concepts if we have no active replacement record in the concept_relationship_stage
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

--31 Deprecate replacement records if target concept was depreceted 
MERGE INTO concept_relationship_stage r
     USING (WITH upgraded_concepts
                    AS (SELECT crs.concept_code_1,
                               crs.vocabulary_id_1,
                               crs.concept_code_2,
                               crs.vocabulary_id_2,
                               crs.relationship_id,
                               cs.invalid_reason
                          FROM concept_relationship_stage crs, concept_stage cs
                         WHERE     crs.relationship_id IN ('Concept replaced by',
                                                           'Concept same_as to',
                                                           'Concept alt_to to',
                                                           'Concept poss_eq to',
                                                           'Concept was_a to')
                               AND crs.invalid_reason IS NULL
                               AND crs.concept_code_2 = cs.concept_code
                               AND crs.vocabulary_id_2 = cs.vocabulary_id
                               AND crs.vocabulary_id_1 = crs.vocabulary_id_2
                               AND crs.concept_code_1 <> crs.concept_code_2)
                SELECT u.concept_code_1,
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

--32 Deprecate concepts if we have no active replacement record in the concept_relationship_stage (yes, again)
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

--33 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
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

--34 Add mapping from deprecated to fresh concepts
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

--35 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE lower(c.concept_code)=lower(cs.concept_code) AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;
	
--36 Clean up
DROP FUNCTION GetAggrDose;
DROP FUNCTION GetDistinctDose;
DROP TABLE MAIN_NDC PURGE;
DROP TABLE ADDITIONALNDCINFO PURGE;
DROP TABLE RXNORM2NDC_MAPPINGS_EXT PURGE;
	
--37 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;	

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script