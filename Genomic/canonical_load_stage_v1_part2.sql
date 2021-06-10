

-- Incorporate HGNC vocabulary 
INSERT INTO concept_stage
SELECT DISTINCT NULL::INT,
       trim(symbol|| ' (' ||f_name|| ')'||' gene variant measurement') AS concept_name,
       'Measurement' AS domain_id,
       'OMOP Genomic' AS vocabulary_id,
       'Gene variant' AS concept_class_id,
       'S' AS standard_concept,
       -- TBD
       TRIM( regexp_REPLACE(hgnc_id,'HGNC:','')) as concept_code,
       TO_DATE( regexp_REPLACE(date_approved_reserved,'-','','g'),'yyyymmdd') AS valid_start_date,
       -- what use as valid_start_date (date_approved_reserved|date_modified)
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM dev_christian.protein_coding_gene
;

-- Synonyms for HGNC Variants 
insert into concept_synonym_stage  
select distinct * from (
select  DISTINCT NULL::INT as synonym_concept_id,
trim(alias_symbol_p) AS synonym_name,
TRIM( regexp_REPLACE(hgnc_id,'HGNC:','')) as synonym_concept_code,
'OMOP Genomic' AS synonym_vocabulary_id,
4180186 as language_concept_id
from  (select *,unnest(string_to_array(alias_symbol,'|')) as alias_symbol_p,unnest(string_to_array(alias_name,'|')) as alias_name_p,unnest(string_to_array(prev_symbol,'|')) as prev_symbol_p,unnest(string_to_array(prev_name,'|')) as prev_name_p from  dev_christian.protein_coding_gene
) a 
where alias_symbol_p is not null 
union
select  DISTINCT NULL::INT as synonym_concept_id,
trim(alias_name_p) AS synonym_name,
TRIM( regexp_REPLACE(hgnc_id,'HGNC:','')) as synonym_concept_code,
'OMOP Genomic' AS synonym_vocabulary_id,
4180186 as language_concept_id
from  (select *,unnest(string_to_array(alias_symbol,'|')) as alias_symbol_p,unnest(string_to_array(alias_name,'|')) as alias_name_p,unnest(string_to_array(prev_symbol,'|')) as prev_symbol_p,unnest(string_to_array(prev_name,'|')) as prev_name_p from  dev_christian.protein_coding_gene
) a 
where alias_name_p is not null 
union
select  DISTINCT NULL::INT as synonym_concept_id,
trim(prev_symbol_p) AS synonym_name,
TRIM( regexp_REPLACE(hgnc_id,'HGNC:','')) as synonym_concept_code,
'OMOP Genomic' AS synonym_vocabulary_id,
4180186 as language_concept_id
from  (select *,unnest(string_to_array(alias_symbol,'|')) as alias_symbol_p,unnest(string_to_array(alias_name,'|')) as alias_name_p,unnest(string_to_array(prev_symbol,'|')) as prev_symbol_p,unnest(string_to_array(prev_name,'|')) as prev_name_p from  dev_christian.protein_coding_gene
) a 
where prev_symbol_p is not null 
union
select  DISTINCT NULL::INT as synonym_concept_id,
trim(prev_name_p) AS synonym_name,
TRIM( regexp_REPLACE(hgnc_id,'HGNC:','')) as synonym_concept_code,
'OMOP Genomic' AS synonym_vocabulary_id,
4180186 as language_concept_id
from  (select *,unnest(string_to_array(alias_symbol,'|')) as alias_symbol_p,unnest(string_to_array(alias_name,'|')) as alias_name_p,unnest(string_to_array(prev_symbol,'|')) as prev_symbol_p,unnest(string_to_array(prev_name,'|')) as prev_name_p from  dev_christian.protein_coding_gene
) a 
where prev_name_p is not null 
)a
;


-- cheking of HGNC synonyms
/*select * from concept_stage 
join concept_synonym_stage on synonym_concept_code = concept_code
where concept_name like '%EGFR%' or  concept_name like '%ALK%'
order by concept_name
limit 1000;*/


-- put source variants into concept stage  
insert into concept_stage
SELECT DISTINCT NULL::INT,
       trim(substr(concept_name,1,255)) AS concept_name,
       'Measurement' AS domain_id,
       vocabulary_id AS vocabulary_id,
       'Variant' AS concept_class_id,
       NULL AS standard_concept,
       concept_code AS concept_code,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM g
where (concept_code,vocabulary_id) in ( 
select distinct concept_code,vocabulary_id 
from dev_dkaduk.canonical_variant 
join g using(gene,seqtype,variant)
where vocabs not in ('ClinVar','JAX')
)
and vocabulary_id not in ('OncoPanel','CAP','LOINC')
and seqtype != 'n' 
and length(concept_code) <= 50
;


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
/*
truncate concept_stage_manual;
--create table concept_stage_manual as 
insert into concept_stage_manual
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
select * FROM CAP_hgvs 
union  
select * FROM CAP_add
union  
select * FROM snomed_vs_icdo
) r 
left join concept c on r.concept_name = c.concepT_name
and vocabulary_id = 'OMOP Extension'
;
*/

insert into concept_stage
select * from concept_stage_manual;

-- insert to concept stage canonical variants as OMOP Extension vocab
insert into concept_stage
select * from(
SELECT DISTINCT NULL::INT,
-- create proper name for canonical variants
TRIM(symbol||
case 
when seqtype = 'p' then ' protein:'
when seqtype = 'c' then ' transcript:'
else ' on genome '||assembly||' on chromosome '||substring(f_location,'^(\w\d?)\w')
end||' '||
case 

-- DELETIONS
  when variant ~ 'del' then 'Deletion '||'in position '||
    case 
    when seqtype = 'p' and variant ~ 'ins' 
      then ''||substring(var_name,'(^\w+\s\d+)\_')||' to '||substring(var_name,'\_(\w+\s\d+)del')||' and insertion of '||substring(var_name,'ins(\w+\s?\w+?\s?\w+?)')
    when seqtype = 'p' and variant ~ '\ddel' and variant !~ '\_' 
      then substring(var_name,'^\w+\s?\w+?\s?\d+')    
    when seqtype = 'p' 
      then ''||substring(var_name,'(\w+\s?\w+?\s\d+)\_')||' to '||substring(var_name,'\_(\w+\s\w+?\s?\d+)del')
    when variant ~ '\_\d+delins' 
      then ''||substring(variant,'(\d+\+?\-?\d*?)\_')||' to '||substring(variant,'\_(\*?\-?\d+\+?\-?\d*?)')||' and insertion of '||substring(var_name,'ins(\w+)$')
    when variant ~ '\d+delins' 
      then substring(variant,'(\d+\+?\-?\d*?)')||' and insertion of '||substring(var_name,'ins(\w+)$')    
    when variant ~ '\_\d+del\w*\>?ins\w+' 
      then ''||substring(variant,'(\d+\+?\-?\d*?)\_')||' to '||substring(variant,'\_(\*?\-?\d+\+?\-?\d*?)')||' of '||substring(var_name,'del(\w+)\>?ins')||' and insertion of '||substring(var_name,'\>?ins(\w+)$')
    when variant ~ 'del\w*ins\w+' 
      then substring(variant,'(\d+\+?\-?\d*?)')||' of '||substring(var_name,'del(\w+)ins')||' and insertion of '||substring(var_name,'ins(\w+)$')
    when variant ~ '\d+\+?\-?\d*?\_\*?\-?\d+\+?\-?\d*?del\D+' 
      then ''||substring(variant,'(\d+\+?\-?\d*?)\_')||' to '||substring(variant,'\_(\*?\-?\d+\+?\-?\d*?)')||' of '||substring(var_name,'del(\w+)$')                                              
    when variant ~ '\d+\_\d+' 
      then ''||substring(variant,'(\d+\+?\-?\d*?)\_')||' to '||substring(variant,'\_(\*?\-?\d+\+?\-?\d*?)')
    else substring(variant,'(\d+\+?\-?\d*?)del')
    end
    
-- INSERTIONS
  when   variant ~ 'ins' then  'Insertion '||'in position '|| 
    case 
    when seqtype = 'p' 
      then ''||substring(var_name,'(^\w+\s\d+)\_')||' to '||substring(var_name,'\_(\w+\s\d+)ins')||' and insertion of '||substring(var_name,'ins(\w+\s?(\w+\s)?(\w+\s)?(\w+\s)?(\w+\s)?(\w+\s)?)$')
    when variant ~ '\d$'
     then ''||substring(variant,'(\*?\-?\d+\+?\-?\d*?)\_')||' to '||substring(variant,'\*?\-?\d+\+?\-?\d*?\_(\*?\-?\d+\+?\-?\d*?)')
    when variant ~ '\_' 
      then ''||substring(variant,'(\*?\-?\d+\+?\-?\d*?)\_')||' to '||substring(variant,'\*?\-?\d+\+?\-?\d*?\_(\*?\-?\d+\+?\-?\d*?)')||' of '||substring(var_name,'ins(\w+)$')
    else substring(variant,'(\*?\-?\d+\+?\-?\d*?)ins')||' of '||substring(var_name,'ins(\w+)$')
  end
  
-- DUPLICATION    
  when variant ~ 'dup' then  'Duplication '||'in position '|| 
    case 
    when seqtype = 'p' and variant ~ '\_' then  ''||substring(var_name, '^\w+\s')||substring(variant,'(\*?\-?\d+\+?\-?\d*?)\_')||' to '||substring(var_name, '\_(\w+\s)')||substring(variant,'(\*?\-?\d+\+?\-?\d*?)dup')
when variant ~ '\_' and variant ~ 'dup$' then ''||substring(variant,'(\*?\-?\d+\+?\-?\d*?)\_')||' to '||substring(variant,'\*?\-?\d+\+?\-?\d*?\_(\*?\-?\d+\+?\-?\d*?)')    
when variant ~ '\_' then ''||substring(variant,'(\*?\-?\d+\+?\-?\d*?)\_')||' to '||substring(variant,'\*?\-?\d+\+?\-?\d*?\_(\*?\-?\d+\+?\-?\d*?)')||' of '||substring(var_name,'dup(\w+)$')
  
    when variant ~ '(\*?\-?\d+\+?\-?\d*?)dup\w+' then substring(variant,'(\*?\-?\d+\+?\-?\d*?)dup')||' of '||substring(var_name,'dup(\w+)$')
    else substring(variant,'(\*?\-?\d+\+?\-?\d*?)dup')
    end
    
-- Substitution g and c
  when variant ~ '\>' then  'Substitution'|| case when seqtype = 'c' then ' ' else ' ' end||'in position '||
    case 
    when variant ~ '\d+\_\d+' then  ''||substring(variant,'(\d+\+?\-?\d*?)\_')||' to '||substring(variant,'\_(\*?\-?\d+\+?\-?\d*?)')||' '||substring(var_name,'(\w+)\>')||' replaced by '||substring(var_name,'\>(\w+)')
    else substring(variant,'(\[?\+?\*?\-?\d+\-?\+?\d*?(kb)?)\w')||' of '||substring(var_name,'(\D+)\>')||' replaced by '||substring(var_name,'\>(\w+)')
    end

--  Proteins   
  when seqtype = 'p' then  'Substitution '||'in position '||  
    case 
    when seqtype = 'p' and variant ~ '\dfs$' then substring(variant,'(\d+)')||' '||substring(var_name,'(^\w+\s)\d')||'replaced and a stop codon'
    when seqtype = 'p' and variant ~ '\d\wfs\*?$' then substring(variant,'(\d+)')||' '||substring(var_name,'(^\w+\s)\d')||'replaced by '||substring(var_name,'\d+(\w+\s)')||'and a stop codon'
    when seqtype = 'p' and variant ~ '\dfs\*' and variant !~ 'fs$' then 'after the '||substring(var_name,'(^\w+)\s\d')||' in position '||substring(variant,'(\d+)')||', a frameshift mutation results in the insertion of '||substring(variant,'fs\*(\d+)$')::integer-1||' non-canonic amino acids followed by a stop codon'
    when seqtype = 'p' and variant ~ '\Dfs\*' and variant !~ 'fs$' then 'after the '||substring(var_name,'(^\w+)\s\d')||' in position '||substring(variant,'(\d+)')||' to '||substring(var_name,'\d+(\w+\s)')||', a frameshift mutation results in the insertion of '||substring(variant,'fs\*(\d+)$')::integer-1||' non-canonic amino acids followed by a stop codon' 
    else substring(variant,'(\d+)')||' '||substring(var_name,'(^\w+\s?\w+?\s)\d')||'replaced by '||substring(var_name,'\d+(\w+\s?\w+?\s?\w+?\s)$')  
    end

-- mess variants?
else var_name  
end||' measurement') AS concept_name,--var_name,
       'Measurement' AS domain_id,
       'OMOP Genomic' AS vocabulary_id,
       CASE
         WHEN seqtype = 'p' THEN 'Protein Variant'
         WHEN seqtype = 'c' THEN 'RNA Variant'
         WHEN seqtype = 'g' THEN 'DNA Variant'
         --WHEN seqtype = 'm' THEN 'Mitochondrial Variant' 
       END AS concept_class_id,
       'S' AS standard_concept,
       omop.concept_code as concept_code,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM canonical_refseq a
join omop_variants omop using(gene,variant)
join dev_christian.protein_coding_gene ON symbol = a.gene
left join 
  (
  select distinct assembly, chromosomeaccession from dev_christian.variant_summary
  union
  select distinct reference_build,substring(hgvs,'\w+\_\d+\.\d+') from ( 
  select civic_start, reference_build,(regexp_matches(hgvs_expressions, '[^, ]+', 'g'))[1] as hgvs
  from dev_christian.civic_variantsummaries
  ) ref 
  where hgvs like '%'||civic_start||'%'
  ) ref_build on chromosomeaccession = refseq||version
) r 
-- filter strange variant
where concept_name is not null 
;


select *--string_agg(distinct cs.concept_code,',')
from concept_stage cs
join omop_variants using(concept_code)
join g using (gene,variant)
where g.concept_code in (
select g.concept_code from concept_stage 
join omop_variants using(concept_code)
join g using (gene,variant)
where var_name = 'Thr 790Met '
)
and cs.concept_name like '%EGFR%'
limit 10000
;

select * from concept_synonym_stage
where synonym_concept_code in ('OMOP5266576','OMOP5266948','OMOP5267132','OMOP5267878')



-- insert synonyms such as HGNC for all canonical variants
insert into concept_synonym_stage
select * 
from (
select  
DISTINCT NULL::INT as synonym_concept_id,
g.refseq||g.version||':'||g.seqtype|| '.' ||g.variant AS synonym_name,
cs.concept_code as synonym_concept_code,
cs.vocabulary_id AS synonym_vocabulary_id,
4180186 as language_concept_id
from omop_variants a 
join concept_stage cs on cs.concept_code = a.concept_code
join g using(gene,variant)
) r
where synonym_name is not null
;







-- add realtionship from gene to protein variants
--insert into concept_relationship_stage
SELECT distinct 
       NULL::integer as concept_id_1, 
       NULL::integer as concept_id_2, 
       cs.concept_code AS concept_code_1,
       cs1.concept_code AS concept_code_2,
       cs.vocabulary_id AS vocabulary_id_1,
       cs1.vocabulary_id AS vocabulary_id_2,
       'Subsumes' AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM dev_christian.protein_coding_gene
  JOIN concept_stage cs
    ON TRIM ( REPLACE (hgnc_id,'HGNC:','')) = concept_code
   AND cs.vocabulary_id = 'OMOP Genomic'
  JOIN omop_variants g ON symbol = g.gene
  JOIN concept_stage cs1 ON cs1.concept_code = g.refseq||g.version|| ':' ||seqtype|| '.' ||variant
WHERE g.seqtype = 'p';




-- 
insert into concept_relationship_stage
select distinct 
       NULL::integer as concept_id_1, 
       NULL::integer as concept_id_2, 
       cs1.concept_code AS concept_code_1,
       cs.concept_code AS concept_code_2,
       cs1.vocabulary_id AS vocabulary_id_1,
       cs.vocabulary_id AS vocabulary_id_2,
       'Subsumes' AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason 
from concept_stage cs
join (
select * FROM CAP_hgvs 
union  
select * FROM CAP_add
union  
select * FROM snomed_vs_icdo
) r   using(concept_name)
join dev_christian.protein_coding_gene ON symbol = substring (concept_name, '^\w+') or symbol = substring (concept_name, '^\w+\-(\w+)')
  JOIN concept_stage cs1
    ON TRIM ( REPLACE (hgnc_id,'HGNC:','')) = cs1.concept_code
   AND cs1.vocabulary_id = 'HGNC'
;











-- add realtionship from protein variants to transcript variants
insert into concept_relationship_stage
SELECT DISTINCT NULL::INTEGER AS concept_id_1,
       NULL::INTEGER AS concept_id_2,
       cs2.concept_code AS concept_code_1,
       cs1.concept_code AS concept_code_2,
       cs2.vocabulary_id AS vocabulary_id_1,
       cs1.vocabulary_id AS vocabulary_id_2,
       'Translates to' AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM g_ref g1
  JOIN concept_stage cs1
    ON cs1.concept_code = g1.refseq||g1.version|| ':' ||g1.seqtype|| '.' ||g1.variant
   AND g1.seqtype = 'p'
  JOIN g_ref g2 ON g1.concept_code = g2.concept_code and g1.vocabulary_id = g2.vocabulary_id
  JOIN concept_stage cs2 ON cs2.concept_code = g2.refseq||g2.version|| ':' ||g2.seqtype|| '.' ||g2.variant
WHERE g2.seqtype = 'c';


-- add realtionship from transcript variants to genomic variants
insert into concept_relationship_stage
SELECT DISTINCT NULL::INTEGER AS concept_id_1,
       NULL::INTEGER AS concept_id_2,
       cs2.concept_code AS concept_code_1,
       cs1.concept_code AS concept_code_2,
       cs2.vocabulary_id AS vocabulary_id_1,
       cs1.vocabulary_id AS vocabulary_id_2,
       'Transcribes to' AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM g_ref g1
  JOIN concept_stage cs1
    ON cs1.concept_code = g1.refseq||g1.version|| ':' ||g1.seqtype|| '.' ||g1.variant
   AND g1.seqtype = 'c'
  JOIN g_ref g2 ON g1.concept_code = g2.concept_code and g1.vocabulary_id = g2.vocabulary_id
  JOIN concept_stage cs2 ON cs2.concept_code = g2.refseq||g2.version|| ':' ||g2.seqtype|| '.' ||g2.variant
WHERE g2.seqtype = 'g';



insert into concept_relationship_stage
select DISTINCT NULL::INTEGER AS concept_id_1,
       NULL::INTEGER AS concept_id_2,
       cs2.concept_code AS concept_code_1,
       cs.concept_code AS concept_code_2,
       cs2.vocabulary_id AS vocabulary_id_1,
       cs.vocabulary_id AS vocabulary_id_2,
       'Transcribes to' AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason 
from g_ref g1 
join concept_stage cs on  g1.refseq||g1.version|| ':' ||g1.seqtype|| '.' ||g1.variant = cs.concepT_code 
and g1.seqtype = 'c'
JOIN g_ref g2 ON g1.concept_code = g2.concept_code
  JOIN concept_stage cs2 ON cs2.concept_code = g2.refseq||g2.version|| ':' ||g2.seqtype|| '.' ||g2.variant
and g2.seqtype = 'g'
where cs.concept_Code not in (select concept_code_2 from concept_relationship_stage)
and g1.concept_code not in (select concept_code from g_ref where seqtype = 'p')
; 


insert into concept_relationship_stage
SELECT distinct 
       NULL::integer as concept_id_1, 
       NULL::integer as concept_id_2, 
       cs.concept_code AS concept_code_1,
       cs1.concept_code AS concept_code_2,
       cs.vocabulary_id AS vocabulary_id_1,
       cs1.vocabulary_id AS vocabulary_id_2,
       'Subsumes' AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM dev_christian.protein_coding_gene
  JOIN concept_stage cs
    ON TRIM ( REPLACE (hgnc_id,'HGNC:','')) = concept_code
   AND cs.vocabulary_id = 'HGNC'    
join g_ref g1 on symbol = g1.gene 
join concept_stage cs1 on  g1.refseq||g1.version|| ':' ||g1.seqtype|| '.' ||g1.variant = cs1.concepT_code 
and g1.seqtype = 'c'
where cs1.concept_Code not in (select concept_code_2 from concept_relationship_stage)
and cs1.concept_Code in (select concept_code_1 from concept_relationship_stage)
;



insert into concept_relationship_stage
SELECT distinct 
       NULL::integer as concept_id_1, 
       NULL::integer as concept_id_2, 
       cs.concept_code AS concept_code_1,
       cs1.concept_code AS concept_code_2,
       cs.vocabulary_id AS vocabulary_id_1,
       cs1.vocabulary_id AS vocabulary_id_2,
       'Subsumes' AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM dev_christian.protein_coding_gene
  JOIN concept_stage cs
    ON TRIM ( REPLACE (hgnc_id,'HGNC:','')) = concept_code
   AND cs.vocabulary_id = 'HGNC'    
join g_ref g1 on symbol = g1.gene 
join concept_stage cs1 on  g1.refseq||g1.version|| ':' ||g1.seqtype|| '.' ||g1.variant = cs1.concepT_code 
and g1.seqtype = 'g'
where cs1.concept_Code not in (select concept_code_2 from concept_relationship_stage)
and g1.concept_code not in (select concept_code from g_ref where seqtype = 'p' union select concept_code from g_ref where seqtype = 'c')
;


-- add mapping from source to canonical variants
insert into concept_relationship_stage
select DISTINCT NULL::INTEGER AS concept_id_1,
       NULL::INTEGER AS concept_id_2,
       cs.concept_code AS concept_code_1,
       cs1.concept_code AS concept_code_2,
       cs.vocabulary_id AS vocabulary_id_1,
       cs1.vocabulary_id AS vocabulary_id_2,
       case when cs.vocabulary_id = 'LOINC' then 'Has variant' else 'Maps to' end AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
from g_ref g
join concept_stage cs on cs.concept_code = g.concept_code and cs.vocabulary_id = g.vocabulary_id
join concept_stage cs1 on cs1.concept_code = g.refseq||g.version|| ':' ||g.seqtype|| '.' ||g.variant
;



insert into concept_relationship_stage
select distinct 
       NULL::integer as concept_id_1, 
       NULL::integer as concept_id_2, 
       c.concept_code AS concept_code_1,
       cs.concept_code AS concept_code_2,
       c.vocabulary_id AS vocabulary_id_1,
       cs.vocabulary_id AS vocabulary_id_2,
       'Has variant' AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason 
from concept_stage cs
join (
select * FROM CAP_hgvs 
union  
select * FROM CAP_add
union  
select * FROM snomed_vs_icdo
) r   using(concept_name)
join snomed_vs_icdo_mapping on cs.concept_name = variant_name
join devv5.concept c on icdo_id = c.concept_id
;


insert into concept_stage 
select concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,null as standard_concept,concept_code,valid_start_date,current_date as valid_end_date,'D' as invalid_reason 
from concept 
where vocabulary_id = 'OMOP Extension'
and concept_class_id like '%Variant'
and concept_code not in (select concept_code from concept_stage);


insert into concept_relationship_stage 
select 
cs.concept_id,
cc.concept_id,
cs.concept_code,
cc.concept_code,
cs.vocabulary_id,
cc.vocabulary_id,
cr.relationship_id,
cr.valid_start_date,
current_date,
'D'
from concept_stage cs
join concept_relationship cr on cr.concept_id_1 = cs.concept_id and cs.invalid_reason = 'D' and cr.invalid_reason is null
join concept cc on cc.concept_id = cr.concept_id_2
;