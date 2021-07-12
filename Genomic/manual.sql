/*
DO $$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(REPLACE(concept_code, 'OMOP','')::int4)+1 INTO ex FROM (
		SELECT concept_code FROM concept WHERE concept_code LIKE 'OMOP%'  AND concept_code NOT LIKE '% %' -- Last valid value of the OMOP123-type codes
		UNION ALL
		SELECT concept_code FROM drug_concept_stage WHERE concept_code LIKE 'OMOP%' AND concept_code NOT LIKE '% %' -- Last valid value of the OMOP123-type codes
	) AS s0;
	DROP SEQUENCE IF EXISTS omop_seq;
	EXECUTE 'CREATE SEQUENCE omop_seq INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END$$
;
*/

-- Additional Biomarkers from diff sources into maunal

truncate concept_stage_manual;
create table concept_stage_manual as 
--insert into concept_stage_manual
SELECT DISTINCT NULL::INT as concepT_id ,
       substr(r.concept_name,1,255)||' measurement' AS concept_name,
       'Measurement' AS domain_id,
       'OMOP Genomic' AS vocabulary_id,
       case 
       when r.concept_name ~ 'somy|Fusion|Rearrangement|Karyotype|Microsatellite|Gene|Histone|t\(' then 'DNA Variant'
       when r.concept_name ~ 'Protein Expression' THEN 'Protein Variant'
       when r.concept_name ~ 'Mutation|Amplification'  THEN 'RNA Variant'
        else null end
 AS concept_class_id,
       'S' AS standard_concept,
       coalesce (concept_code, 'OMOP' || NEXTVAL('omop_seq')) AS concept_code,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
from (
select * FROM dev_dkaduk.CAP_hgvs 
union  
select * FROM dev_dkaduk.CAP_add
union  
select * FROM dev_dkaduk.snomed_vs_icdo
) r 
left join concept c on r.concept_name = c.concepT_name
and vocabulary_id = 'OMOP Extension'
;




truncate concept_relationship_manual;
insert into concept_relationship_manual
select distinct 
       cs1.concept_code AS concept_code_1,
       cs.concept_code AS concept_code_2,
       cs1.vocabulary_id AS vocabulary_id_1,
       cs.vocabulary_id AS vocabulary_id_2,
       case when cs.concept_name ilike '%gene mutation%' then 'Mapped from' else 'Subsumes' end AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
from concept_stage_manual cs
join dev_christian.protein_coding_gene ON symbol = substring (concept_name, '^\w+') or symbol = substring (concept_name, '^\w+\-(\w+)')
  JOIN concept_stage cs1
    ON TRIM ( REPLACE (hgnc_id,'HGNC:','')) = cs1.concept_code
   AND cs1.vocabulary_id = 'OMOP Genomic'
;

/*create table crm_review as 
select cs.concept_name as targ_name,crm.*,csm.concept_name as source_name
from concept_stage_manual csm
left join concept_relationship_manual crm on csm.concept_code = crm.concept_code_2 and csm.vocabulary_id = crm.vocabulary_id_2
left join concept_stage cs on cs.concept_code = crm.concept_code_1 and cs.vocabulary_id = crm.vocabulary_id_2;
*/

insert into concept_relationship_manual
select distinct 
       csm1.concept_code AS concept_code_1,
       csm.concept_code AS concept_code_2,
       csm1.vocabulary_id AS vocabulary_id_1,
       csm.vocabulary_id AS vocabulary_id_2,
       relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason 
from dev_dkaduk.crm_review
join concept_stage_manual csm on source_name = csm.concept_name
join concept_stage_manual csm1 on csm1.concept_code = concept_code_1
;

update concept_stage_manual
set standard_concept = NULL
where concepT_code in (
select concepT_code_2 
from concept_relationship_manual
where relationship_id = 'Mapped from'
);

insert into concept_relationship_manual
select distinct  
       c.concept_code AS concept_code_1,
       csm.concept_code AS concept_code_2,
       c.vocabulary_id AS vocabulary_id_1,
       csm.vocabulary_id AS vocabulary_id_2,
       'Has variant' AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason 
from concept_stage_manual csm
join dev_dkaduk.snomed_vs_icdo_mapping on trim(csm.concept_name) = trim(variant_name||' measurement') and csm.standard_concept = 'S'
join devv5.concept c on icdo_id = c.concept_id
union

select distinct  
       c.concept_code AS concept_code_1,
       cs.concept_code AS concept_code_2,
       c.vocabulary_id AS vocabulary_id_1,
       cs.vocabulary_id AS vocabulary_id_2,
       'Has variant' AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason 
from concept_stage_manual csm
join dev_dkaduk.snomed_vs_icdo_mapping on trim(csm.concept_name) = trim(variant_name||' measurement') and csm.standard_concept is null
join concept_relationship_manual crm on  csm.concept_code = crm.concept_code_2 and csm.vocabulary_id = crm.vocabulary_id_2
join concept_stage cs on cs.concept_code = crm.concept_code_1 and cs.vocabulary_id = crm.vocabulary_id_1 and relationship_id = 'Mapped from'
join devv5.concept c on icdo_id = c.concept_id
;

insert into concept_relationship_manual
select concept_code_2,
concept_code_1,
vocabulary_id_2,
vocabulary_id_1,
'Maps to',
valid_start_date,
valid_end_date,
invalid_reason
from concept_relationship_manual 
where relationship_id = 'Mapped from';

delete from concept_relationship_manual 
where relationship_id = 'Mapped from';
