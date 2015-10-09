--1. Update latest_update field to new date 
BEGIN
   EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN latest_update';
EXCEPTION WHEN OTHERS THEN NULL;
END;
ALTER TABLE vocabulary ADD latest_update DATE;
update vocabulary set latest_update=to_date('20150914','yyyymmdd'), vocabulary_version='NDC 20150914' where vocabulary_id='NDC'; commit;
update vocabulary set latest_update=to_date('20150914','yyyymmdd'), vocabulary_version='NDC 20150914' where vocabulary_id='SPL'; commit;

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


--3 NEW! Create temporary table for SPL concepts from XML sources
create table spl_ext nologging as
    select xml_name, coalesce(concept_name,to_char(concept_name_clob))||' - '||coalesce(concept_name_p2,to_char(concept_name_clob_p2)) as concept_name, concept_code, valid_start_date, displayname, replaced_spl,
    low_value, high_value from (
        select xml_name, trim(upper(trim(concept_name_part))||' '||upper(trim(concept_name_suffix))) as concept_name, trim(upper(trim(concept_name_clob_part))||' '||upper(trim(concept_name_clob_suffix))) as concept_name_clob, 
        trim(lower(trim(concept_name_part2))||' '||lower(trim(formcode))) as concept_name_p2, trim(lower(trim(concept_name_clob_part2))||' '||lower(trim(formcode_clob))) as concept_name_clob_p2, concept_code,
        to_date(substr(valid_start_date,1,6) || case when to_number(substr(valid_start_date,-2,2))>31 then '31' else substr(valid_start_date,-2,2) end, 'YYYYMMDD') as valid_start_date, 
        upper(trim(regexp_replace(displayname, '[[:space:]]+',' '))) as displayname, replaced_spl, 
        trim (';' from low_value1||';'||low_value2) low_value,
        trim (';' from high_value1||';'||high_value2) high_value
        from (
            select t.xml_name, 
            extractvalue(t.xmlfield,'/document/component/structuredBody/component[1]/section/subject[1]/manufacturedProduct/*/name/text()','xmlns="urn:hl7-org:v3"') as concept_name_part,
            extractvalue(t.xmlfield,'/document/component/structuredBody/component[1]/section/subject[1]/manufacturedProduct/*/name/suffix','xmlns="urn:hl7-org:v3"') as concept_name_suffix,
            extractvalue(t.xmlfield,'/document/component/structuredBody/component[1]/section/subject[1]/manufacturedProduct/*/asEntityWithGeneric/genericMedicine/name/text()','xmlns="urn:hl7-org:v3"') as concept_name_part2,
            extractvalue(t.xmlfield,'/document/component/structuredBody/component[1]/section/subject[1]/manufacturedProduct/*/formCode/@displayName/text()','xmlns="urn:hl7-org:v3"') as formcode,
            t.xmlfield.extract('/document/component/structuredBody/component/section/subject/manufacturedProduct/*/name/text()','xmlns="urn:hl7-org:v3"').getClobVal() as concept_name_clob_part,
            t.xmlfield.extract('/document/component/structuredBody/component/section/subject/manufacturedProduct/*/name/suffix/text()','xmlns="urn:hl7-org:v3"').getClobVal() as concept_name_clob_suffix,
            t.xmlfield.extract('/document/component/structuredBody/component/section/subject/manufacturedProduct/*/asEntityWithGeneric/genericMedicine/name/text()','xmlns="urn:hl7-org:v3"').getClobVal() as concept_name_clob_part2,
            t.xmlfield.extract('/document/component/structuredBody/component/section/subject/manufacturedProduct/*/formCode/@displayName','xmlns="urn:hl7-org:v3"').getClobVal() as formcode_clob,
            t.xmlfield.extract('/document/setId/@root','xmlns="urn:hl7-org:v3"').getStringVal() as concept_code,
            t.xmlfield.extract('/document/effectiveTime/@value','xmlns="urn:hl7-org:v3"').getStringVal() as valid_start_date,
            t.xmlfield.extract('/document/code/@displayName','xmlns="urn:hl7-org:v3"').getStringVal() as displayname,
            xmlcast(xmlquery(( 'declare default element namespace "urn:hl7-org:v3"; (::) string-join(//child::text(),";")' ) passing 
                extract(t.xmlfield, '/document/relatedDocument/relatedDocument/setId/@root', 'xmlns="urn:hl7-org:v3"') returning content) as varchar2(4000)) as replaced_spl,
            xmlcast(xmlquery(( 'declare default element namespace "urn:hl7-org:v3"; (::) string-join(distinct-values(//child::text()),";")' ) passing 
                extract(t.xmlfield, '/document/component/structuredBody/component/section/subject/manufacturedProduct/subjectOf/marketingAct/effectiveTime/low/@value', 'xmlns="urn:hl7-org:v3"') returning content) as varchar2(4000)) as low_value1,
            xmlcast(xmlquery(( 'declare default element namespace "urn:hl7-org:v3"; (::) string-join(distinct-values(//child::text()),";")' ) passing 
                extract(t.xmlfield, '/document/component/structuredBody/component/section/subject/manufacturedProduct/manufacturedProduct/asContent/subjectOf/marketingAct/effectiveTime/low/@value', 'xmlns="urn:hl7-org:v3"') returning content) as varchar2(4000)) as low_value2,                
            xmlcast(xmlquery(( 'declare default element namespace "urn:hl7-org:v3"; (::) string-join(distinct-values(//child::text()),";")' ) passing 
                extract(t.xmlfield, '/document/component/structuredBody/component/section/subject/manufacturedProduct/subjectOf/marketingAct/effectiveTime/high/@value', 'xmlns="urn:hl7-org:v3"') returning content) as varchar2(4000)) as high_value1,            
            xmlcast(xmlquery(( 'declare default element namespace "urn:hl7-org:v3"; (::) string-join(distinct-values(//child::text()),";")' ) passing 
                extract(t.xmlfield, '/document/component/structuredBody/component/section/subject/manufacturedProduct/manufacturedProduct/asContent/subjectOf/marketingAct/effectiveTime/high/@value', 'xmlns="urn:hl7-org:v3"') returning content) as varchar2(4000)) as high_value2
            from spl_ext_raw  t    
    )
);

--4 NEW! Load upgraded SPL concepts
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

--5 NEW! Load main SPL concepts into concept_stage
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
		SELECT 1 FROM CONCEPT_STAGE cs_int WHERE s.concept_code=cs_int.concept_code
	);	
COMMIT;	

--6 Load other SPL into concept_stage (from 'product')
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
				(select distinct CASE WHEN lower(proprietaryname) <> lower(nonproprietaryname) 
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
		SELECT 1 FROM CONCEPT_STAGE cs_int WHERE s.concept_code=cs_int.concept_code
	);

COMMIT;

--7 NEW! Add upgrade SPL relationships
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
	'U' as invalid_reason
	from (
		select distinct first_value(s.concept_code) over (partition by l.replaced_spl order by s.valid_start_date, s.concept_code rows between unbounded preceding and unbounded following) spl_code, 
		first_value(s.valid_start_date) over (partition by l.replaced_spl order by s.valid_start_date, s.concept_code rows between unbounded preceding and unbounded following) spl_date,
		l.replaced_spl  from spl_ext s,
		lateral (select regexp_substr(s.replaced_spl,'[^;]+', 1, level) replaced_spl from dual connect by regexp_substr(s.replaced_spl, '[^;]+', 1, level) is not null) l
		where s.replaced_spl is not null -- if there is an SPL codes ( l ) that is mentioned in another record as replaced_spl (path /document/relatedDocument/relatedDocument/setId/@root)
	);

COMMIT;

--8 Load NDC into temporary table from 'product'
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

--9 Add NDC to MAIN_NDC from rxnconso
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
             ON c.sab = 'RXNORM' AND c.rxaui = s.rxaui AND c.rxcui = s.rxcui
          JOIN vocabulary v ON v.vocabulary_id = 'NDC'
    WHERE s.sab = 'RXNORM' AND s.atn = 'NDC';
COMMIT;

--10 NEW! Add additional NDC with fresh dates and active mapping to RxCUI (source: http://rxnav.nlm.nih.gov/REST/ndcstatus?history=1&ndc=xxx) [part 1 of 3]
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
            From ndc_info_done ndc        
            where ndc.activeRxcui=(
                select ndc_int.activeRxcui from ndc_info_done ndc_int, concept c_int
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
);
COMMIT;

--11 NEW! Create temporary table for NDC who have't activerxcui (same source). Take dates from coalesce(NDC API, big XML (SPL), MAIN_NDC, concept, default dates)
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
        ndc_info_done n
        left join MAIN_NDC mn on mn.concept_code=n.concept_code and mn.vocabulary_id='NDC'
        left join concept c on c.concept_code=n.concept_code and c.vocabulary_id='NDC'        
        left join SPL2NDC_MAPPINGS s on n.concept_code=s.ndc_code
        left join spl_ext spl on spl.concept_code=s.concept_code
        where n.activerxcui is null
    ) n,
    lateral (select min(CheckNDCDate(regexp_substr(n.low_value,'[^;]+', 1, level), coalesce(n.c_st_date1, n.c_st_date2, to_date('19700101','YYYYMMDD')))) ndc_valid_start_date from dual connect by regexp_substr(n.low_value, '[^;]+', 1, level) is not null) l,
    lateral (select max(CheckNDCDate(regexp_substr(n.high_value,'[^;]+', 1, level),coalesce(n.c_end_date1, n.c_end_date2, to_date('20991231','YYYYMMDD')))) ndc_valid_end_date from dual connect by regexp_substr(n.high_value, '[^;]+', 1, level) is not null) h
 group by concept_code, startdate, enddate, c_name1,c_name2;

--12 NEW! Add additional NDC with fresh dates from previous temporary table (ADDITIONALNDCINFO) [part 2 of 3]
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
     FROM ADDITIONALNDCINFO;
COMMIT;	 

--13 NEW! Create temporary table for NDC mappings to RxNorm (source: http://rxnav.nlm.nih.gov/REST/rxcui/xxx/allndcs?history=1)
CREATE TABLE RXNORM2NDC_MAPPINGS NOLOGGING AS    
select concept_code, ndc_code, startDate, endDate, invalid_reason, coalesce(c_name1,c_name2,last_rxnorm_name) concept_name from (
    select distinct mp.concept_code, mn.concept_name c_name1,c.concept_name c_name2,
    last_value(rxnorm.concept_name) over (partition by mp.ndc_code order by rxnorm.valid_start_date, rxnorm.concept_id rows between unbounded preceding and unbounded following) last_rxnorm_name,
    mp.startDate, mp.ndc_code,
    case when mp.endDate=mp.max_end_date then to_date ('20991231', 'yyyymmdd') else mp.endDate end endDate,
    case when mp.endDate=mp.max_end_date then null else 'D' end invalid_reason
    from (    
        select concept_code, ndc_code, startDate, endDate, max(endDate) over() max_end_date from (
            SELECT /*+ no_merge */ r.concept_code,
            EXTRACTVALUE (VALUE (t), 'ndcTime/ndc') ndc_code,
            TO_DATE(EXTRACTVALUE (VALUE (t), 'ndcTime/startDate'),'YYYYMM') startDate,
            TO_DATE(EXTRACTVALUE (VALUE (t), 'ndcTime/endDate'),'YYYYMM') endDate
            FROM NDC_EXT_RAW r, TABLE (XMLSEQUENCE (r.ndc_xml.EXTRACT ('rxnormdata/ndcConcept/ndcTime'))) t
        )
    ) mp
    left join MAIN_NDC mn on mn.concept_code=mp.ndc_code and mn.vocabulary_id='NDC' --first search name in old sources
    left join concept c on c.concept_code=mp.ndc_code and c.vocabulary_id='NDC' --search name in concept
    left join concept rxnorm on rxnorm.concept_code=mp.concept_code and rxnorm.vocabulary_id='RxNorm' --take name from RxNorm
);

--14 NEW! Add additional NDC with fresh dates from previous temporary table (RXNORM2NDC_MAPPINGS) [part 3 of 3]
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
     FROM RXNORM2NDC_MAPPINGS m
     WHERE NOT EXISTS
             (SELECT 1
                FROM concept_stage cs_int
               WHERE     cs_int.concept_code = m.ndc_code
                     AND cs_int.vocabulary_id = 'NDC');
COMMIT;	 

--15 NEW! Add all other NDC from 'product'
INSERT /*+ APPEND */ INTO  CONCEPT_STAGE
   SELECT *
     FROM MAIN_NDC m
    WHERE NOT EXISTS
             (SELECT 1
                FROM concept_stage cs_int
               WHERE     cs_int.concept_code = m.concept_code
                     AND cs_int.vocabulary_id = 'NDC');
COMMIT;					 

--16 NEW! Add mapping from SPL to RxNorm through RxNorm API (source: http://rxnav.nlm.nih.gov/REST/rxcui/xxx/property?propName=SPL_SET_ID)
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
     FROM RXNORM2SPL_done
    WHERE spl_code IS NOT NULL;
COMMIT;

--17 Add mapping from SPL to RxNorm through rxnconso
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

--18 Add mapping from NDC to RxNorm from rxnconso
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
                  JOIN rxnconso r ON r.rxcui = c.rxcui and r.sab='RXNORM'
                  JOIN vocabulary v ON v.vocabulary_id = 'NDC');
COMMIT;		
			
--19 Add additional mapping for NDC codes 
--The 9-digit NDC codes that have no mapping can be mapped to the same concept of the 11-digit NDC codes, if all 11-digit NDC codes agree on the same destination Concept
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;

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

--20 NEW! MERGE concepts from fresh sources (RXNORM2NDC_MAPPINGS)
MERGE INTO concept_relationship_stage crs
     USING (SELECT * FROM RXNORM2NDC_MAPPINGS) m
        ON (    crs.concept_code_1 = m.ndc_code
            AND crs.concept_code_2 = m.concept_code
            AND crs.relationship_id = 'Maps to'
            AND crs.vocabulary_id_1 = 'NDC'
            AND crs.vocabulary_id_2 = 'RxNorm')
WHEN MATCHED
THEN
   UPDATE SET
      crs.valid_start_date = m.startdate,
      crs.valid_end_date = m.enddate,
      crs.invalid_reason = m.invalid_reason
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
               m.enddate,
               m.invalid_reason);
COMMIT;			   

--21 Add mapping from deprecated to fresh concepts
INSERT  /*+ APPEND */  INTO concept_relationship_stage (
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
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
    ) int_rel WHERE NOT EXISTS -- only new mapping we don't already have
    (select 1 from concept_relationship_stage r where
        int_rel.root=r.concept_code_1
        and int_rel.concept_code_2=r.concept_code_2
        and int_rel.root_vocabulary_id=r.vocabulary_id_1
        and int_rel.vocabulary_id_2=r.vocabulary_id_2
        and r.relationship_id='Maps to'
    );
COMMIT;

--22 Redirect all relationships 'Maps to' to those concepts that are connected through "Contains"
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT r.concept_code_1 AS concept_code_1,
          c2.concept_code AS concept_code_2,
          'NDC' AS vocabulary_id_1,
          'RxNorm' AS vocabulary_id_2,
          'Maps to' AS relationship_id,
          r.valid_start_date AS valid_start_date,
          r.valid_end_date AS valid_end_date,
          r.invalid_reason
     FROM concept_relationship_stage r,
          concept c,
          concept_relationship r1,
          concept c1,
          concept c2
    WHERE     r.vocabulary_id_1 = 'NDC'
          AND r.vocabulary_id_2 = 'RxNorm'
          AND c.concept_code = r.concept_code_2
          AND c.vocabulary_id = r.vocabulary_id_2
          AND c.concept_class_id IN ('Clinical Pack', 'Branded Pack')
          AND c.invalid_reason IS NULL
          AND c.standard_concept IS NULL
          AND r.relationship_id = 'Maps to'
          AND r.invalid_reason IS NULL
          AND r.concept_code_2 = c1.concept_code
          AND r.vocabulary_id_2 = c1.vocabulary_id
          AND c1.concept_id = r1.concept_id_1
          AND r1.relationship_id = 'Contains'
          AND r1.concept_id_2 = c2.concept_id
          AND r1.invalid_reason IS NULL
          AND NOT EXISTS -- only new mapping we don't already have
                 (SELECT 1
                    FROM concept_relationship_stage r_int
                   WHERE     r_int.concept_code_1 = r.concept_code_1
                         AND r_int.concept_code_2 = c2.concept_code
                         AND r_int.vocabulary_id_1 = 'NDC'
                         AND r_int.vocabulary_id_2 = 'RxNorm'
                         AND r_int.relationship_id = 'Maps to');
COMMIT;		  

--23 Re-map Quantified Drugs and Packs
--Rename all relationship_id between anything and Concepts where vocabulary_id='RxNorm' and concept_class_id in ('Quant Clinical Drug', 'Quant Branded Drug', 'Clinical Pack', 'Branded Pack') and standard_concept is null from 'Maps to' to 'Original maps to'
UPDATE concept_relationship_stage
   SET relationship_id = 'Original maps to'
 WHERE ROWID IN (SELECT r.ROWID
                   FROM concept_relationship_stage r, concept c
                  WHERE     r.vocabulary_id_1 = 'NDC'
                        AND r.vocabulary_id_2 = 'RxNorm'
                        AND c.concept_code = r.concept_code_2
                        AND c.vocabulary_id = r.vocabulary_id_2
                        AND c.concept_class_id IN ('Quant Clinical Drug',
                                                   'Quant Branded Drug',
                                                   'Clinical Pack',
                                                   'Branded Pack')
                        AND c.standard_concept IS NULL
                        AND r.relationship_id = 'Maps to');
COMMIT;				 

--24 Add "Quantified form of" mappings
--24.1 for new concepts
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT r_ndc.concept_code_1 AS concept_code_1,
          c_rxnorm2.concept_code AS concept_code_2,
          'NDC' AS vocabulary_id_1,
          'RxNorm' AS vocabulary_id_2,
          'Quantified form of' AS relationship_id,
          last_value(r_ndc.valid_start_date) over (partition by r_ndc.concept_code_1, c_rxnorm2.concept_code order by r_ndc.valid_start_date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS valid_start_date,
          last_value(r_ndc.valid_end_date) over (partition by r_ndc.concept_code_1, c_rxnorm2.concept_code order by r_ndc.valid_start_date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS valid_end_date,		  
          r_ndc.invalid_reason             
from concept_relationship_stage r_ndc, concept c_rxnorm, concept_relationship r_rxnorm, concept c_rxnorm2
where r_ndc.relationship_id='Original maps to'
and r_ndc.concept_code_2=c_rxnorm.concept_code
and r_ndc.vocabulary_id_2=c_rxnorm.vocabulary_id
and r_ndc.vocabulary_id_1='NDC'
and r_ndc.vocabulary_id_2='RxNorm'
and r_rxnorm.concept_id_1=c_rxnorm.concept_id
and r_rxnorm.relationship_id in ('Quantified form of','Contains')
and r_rxnorm.invalid_reason is null
and r_rxnorm.concept_id_2=c_rxnorm2.concept_id;
COMMIT;

--24.2 for existing (old) concepts
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT c_ndc.concept_code AS concept_code_1,
          c_rxnorm.concept_code AS concept_code_2,
          'NDC' AS vocabulary_id_1,
          'RxNorm' AS vocabulary_id_2,
          'Quantified form of' AS relationship_id,
          last_value(r_ndc.valid_start_date) over (partition by c_ndc.concept_code, c_rxnorm.concept_code order by r_ndc.valid_start_date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS valid_start_date,
          last_value(r_ndc.valid_end_date) over (partition by c_ndc.concept_code, c_rxnorm.concept_code order by r_ndc.valid_start_date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS valid_end_date,
          r_ndc.invalid_reason             
from concept_relationship r_ndc, concept_relationship r_rxnorm, concept c_ndc, concept c_rxnorm
where r_ndc.relationship_id='Original maps to'
and r_ndc.invalid_reason is null
and r_rxnorm.concept_id_1=r_ndc.concept_id_2
and r_rxnorm.relationship_id in ('Quantified form of','Contains')
and r_rxnorm.invalid_reason is null
and r_ndc.concept_id_1=c_ndc.concept_id
and r_rxnorm.concept_id_2=c_rxnorm.concept_id
and c_ndc.vocabulary_id='NDC'
and c_rxnorm.vocabulary_id='RxNorm'
and not exists (
    select 1 from concept_relationship_stage r_int
    where r_int.concept_code_1=c_ndc.concept_code
    and r_int.concept_code_2=c_rxnorm.concept_code
    and r_int.vocabulary_id_1='NDC'
    and r_int.vocabulary_id_2='RxNorm'
    and r_int.relationship_id='Quantified form of'
);
COMMIT;

--25. Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;
	
--26. Clean up
DROP FUNCTION GetAggrDose;
DROP FUNCTION GetDistinctDose;
DROP TABLE SPL_EXT PURGE;
DROP TABLE MAIN_NDC PURGE;
DROP TABLE ADDITIONALNDCINFO PURGE;
DROP TABLE RXNORM2NDC_MAPPINGS PURGE;
	
--27. Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;	

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script