--1. Update latest_update field to new date 
ALTER TABLE vocabulary ADD latest_update DATE;
update vocabulary set latest_update=to_date('20150129','yyyymmdd') where vocabulary_id='NDC'; commit;
update vocabulary set latest_update=to_date('20150129','yyyymmdd') where vocabulary_id='SPL'; commit;

--2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
ALTER SESSION SET SKIP_UNUSABLE_INDEXES = TRUE; --disables error reporting of indexes and index partitions marked UNUSABLE
ALTER INDEX idx_cs_concept_code UNUSABLE;
ALTER INDEX idx_cs_concept_id UNUSABLE;
ALTER INDEX idx_concept_code_1 UNUSABLE;
ALTER INDEX idx_concept_code_2 UNUSABLE;


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

--3. Load SPL into concept_stage
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
	NULL AS standard_concept,
	concept_code,
	COALESCE (valid_start_date, latest_update) AS valid_start_date,
	TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
	from 
	(           
		select concept_code, concept_class_id,
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
			(select listagg(DOSAGEFORMNAME,', ') within group (order by DOSAGEFORMNAME) from (select distinct P.DOSAGEFORMNAME from prod p where p.concept_code=t1.concept_code)) as DOSAGEFORMNAME, 
			(select listagg(ROUTENAME,', ') within group (order by ROUTENAME) from (select distinct P.ROUTENAME from prod p where p.concept_code=t1.concept_code)) as ROUTENAME,
			(select listagg(NONPROPRIETARYNAME,', ') within group (order by NONPROPRIETARYNAME) from (select distinct lower(P.NONPROPRIETARYNAME) NONPROPRIETARYNAME from prod p where p.concept_code=t1.concept_code)  where rownum<15) as NONPROPRIETARYNAME,
			(select count(lower(P.NONPROPRIETARYNAME)) from prod p where p.concept_code=t1.concept_code having count(distinct lower(P.NONPROPRIETARYNAME))>1) as MULTI_NONPROPRIETARYNAME,
			(
				select listagg(brand_name,', ') within group (order by brand_name) from 
				(select distinct CASE WHEN lower(proprietaryname) <> lower(nonproprietaryname) 
								 THEN LOWER(TRIM(proprietaryname || ' ' || proprietarynamesuffix))
								 ELSE NULL
								 END AS brand_name 
				from prod p where p.concept_code=t1.concept_code
				) where rownum<50 --brand_name may be too long for concatenation
			) as brand_name
			from t t1
		)
	), vocabulary v
	WHERE v.vocabulary_id = 'SPL';

COMMIT;

--4. Load NDC into concept_stage
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
    'NDC' AS vocabulary_id,
    '9-digit NDC' AS concept_class_id,
    NULL AS standard_concept,
    concept_code,
    COALESCE (valid_start_date, latest_update) AS valid_start_date,
    TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
    NULL AS invalid_reason
    from 
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
            (select listagg(DOSAGEFORMNAME,', ') within group (order by DOSAGEFORMNAME) from (select distinct P.DOSAGEFORMNAME from prod p where p.concept_code=t1.concept_code)) as DOSAGEFORMNAME, 
            (select listagg(ROUTENAME,', ') within group (order by ROUTENAME) from (select distinct P.ROUTENAME from prod p where p.concept_code=t1.concept_code)) as ROUTENAME,
            (select listagg(NONPROPRIETARYNAME,', ') within group (order by NONPROPRIETARYNAME) from (select distinct lower(P.NONPROPRIETARYNAME) NONPROPRIETARYNAME from prod p where p.concept_code=t1.concept_code)  where rownum<15) as NONPROPRIETARYNAME,
			(select count(lower(P.NONPROPRIETARYNAME)) from prod p where p.concept_code=t1.concept_code having count(distinct lower(P.NONPROPRIETARYNAME))>1) as MULTI_NONPROPRIETARYNAME,
            (
                select listagg(brand_name,', ') within group (order by brand_name) from 
                (select distinct CASE WHEN lower(proprietaryname) <> lower(nonproprietaryname) 
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

--5. Add NDC to concept_stage from rxnconso
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
             ON c.sab = 'RXNORM' AND c.rxaui = s.rxaui AND c.rxcui = s.rxcui
          JOIN vocabulary v ON v.vocabulary_id = 'NDC'
    WHERE s.sab = 'RXNORM' AND s.atn = 'NDC';
COMMIT;

--6. Add mapping from SPL to RxNorm through rxnconso
INSERT /*+ APPEND */ INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT
          TRIM (SUBSTR (productid, INSTR (productid, '_') + 1))
             AS concept_code_1,                       -- SPL set ID parsed out
          r.rxcui AS concept_code_2,                    -- RxNorm concept_code
          'SPL' AS vocabulary_id_1,
          'RxNorm' AS vocabulary_id_2,
          'SPL - RxNorm' AS relationship_id,
          v.latest_update AS valid_start_date,
          TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
          NULL AS invalid_reason
     FROM product p
          JOIN rxnconso c ON c.code = p.productndc AND c.sab = 'MTHSPL'
          JOIN rxnconso r ON r.rxcui = c.rxcui
          JOIN vocabulary v ON v.vocabulary_id = 'SPL';
COMMIT;	

--7. Add mapping from NDC to RxNorm from rxnconso
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
             ON c.sab = 'RXNORM' AND c.rxaui = s.rxaui AND c.rxcui = s.rxcui
          JOIN vocabulary v ON v.vocabulary_id = 'NDC'
    WHERE s.sab = 'RXNORM' AND s.atn = 'NDC';
COMMIT;		

--8. Add mapping from NDCto RxNorm from rxnconso
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
                     ON c.code = p.productndc AND c.sab = 'MTHSPL'
                  JOIN rxnconso r ON r.rxcui = c.rxcui
                  JOIN vocabulary v ON v.vocabulary_id = 'NDC');
COMMIT;		

--9. Make sure all records are symmetrical and turn if necessary
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT crs.concept_code_2,
          crs.concept_code_1,
          crs.vocabulary_id_2,
          crs.vocabulary_id_1,
          r.reverse_relationship_id,
          crs.valid_start_date,
          crs.valid_end_date,
          crs.invalid_reason
     FROM concept_relationship_stage crs
          JOIN relationship r ON r.relationship_id = crs.relationship_id
    WHERE NOT EXISTS
             (                                           -- the inverse record
              SELECT 1
                FROM concept_relationship_stage i
               WHERE     crs.concept_code_1 = i.concept_code_2
                     AND crs.concept_code_2 = i.concept_code_1
                     AND crs.vocabulary_id_1 = i.vocabulary_id_2
                     AND crs.vocabulary_id_2 = i.vocabulary_id_1
                     AND r.reverse_relationship_id = i.relationship_id);
COMMIT;					 

--10. Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;
	
--11. Clean up
DROP FUNCTION GetAggrDose;
DROP FUNCTION GetDistinctDose;
	
--12. Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;	

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script