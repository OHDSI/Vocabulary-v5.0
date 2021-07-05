------ SOURCE Processing ------
-- extract position for canonical variant from hgvs expressions  
drop table if exists genom;
create table genom as
with snp as (
-- ClinVar 
  select distinct f_name as concept_name, 'ClinVar' as vocabulary_id, cast(alleleid as varchar(6)) as concept_code, genesymbol as gene,  hgvs
  from sources.clinvar
  join sources.clinvar_ext on f_name = clin_name
  where hgvs ~ '^NM|^NP|^NC|^LRG|^NG|^NR'
 
  
-- civic
union
  select distinct variant as concept_name, 'CIViC' as vocabulary_id, cast(variant_id as varchar(5)) as concept_code, gene, ( regexp_matches(hgvs_expressions, '[^, ]+', 'g'))[1] as hgvs
  from sources.civic_variantsummaries
  where hgvs_expressions ~ '[\w_]+(\.\d+)?:[cCgGoOmMnNrRpP]\.'


-- NCI
union
  select concept_name, vocabulary_id, concept_code, ( regexp_matches(display_name, '(\w+) '))[1] as gene, ( regexp_matches(display_name, '\w+ (.+)'))[1] as hgvs from (
    select definition as concept_name, 'NCIt' as vocabulary_id, code as concept_code, display_name
    from sources.nci_thesaurus 
    where coalesce(concept_status, '') not in ('Retired_Concept', 'Obsolete_Concept') and semantic_type in ('Cell or Molecular Dysfunction')
      and display_name ~ '[\w_]+(\.\d+)?:[cCgGoOmMnNrRpP]\.'
  ) a
  
-- CAP
union  
  select concept_name, vocabulary_id, concept_code, gene, gene||':'||hgvs_half as hgvs from (
    select concept_name, vocabulary_id, concept_code, coalesce(m1, m2) as gene, ( regexp_matches(concept_name, '[cCpP]\.[\w\_\+\-\*>=]+', 'g'))[1] as hgvs_half from (
     select vl.concept_name, vl.vocabulary_id, vl.concept_code, 
        ( regexp_matches(vl.concept_name, '^\w{3,8}'))[1] as m1, ( regexp_matches(vr.concept_name, '^\w{3,8}'))[1] as m2
      from concept vl 
      left join (
        select concept_id_1, concept_name
        from concept_relationship r join devv5.concept on concept_id=r.concept_id_2
        where r.invalid_reason is null and r.relationship_id='CAP value of'  
      ) vr on vr.concept_id_1=vl.concept_id  
      where vl.vocabulary_id= 'CAP' -- and lower(vr.concept_name) like '%mutatat%' 
      and vl.concept_name ~ '([cCgGoOmMnNrRpP])\.([\w\_\+\-\*>=]+)'
    ) a
  ) b
  


union 
select concept_name, 'CAP' vocabulary_id, concept_name as concept_code, substring(concept_name, '^(\w+\-?\w+?)\:')gene, concept_name as hgvs from dev_dkaduk.CAP_variant

-- LOINC
union
  select concept_name, vocabulary_id, concept_code, m[1] as gene, m[1]||':'||m[2] as hgvs from ( 
    select concept_name, vocabulary_id, concept_code,  regexp_matches(concept_name, '(\w{3,8}) gene ([cCgGoOmMnNrRpP]\.[\w\_\+\-\*>=]+)') as m from devv5.concept where vocabulary_id='LOINC'
  ) a

-- CGI vocab
union
(
select distinct individual_mutation as concept_name, 'CGI' as vocabulary_id,  individual_mutation as concept_code, ( regexp_matches(biomarker, '(\w+) '))[1] as gene, gdna as hgvs
from sources.cgi_genomic
where gdna != '' 
union 
select distinct individual_mutation as concept_name, 'CGI' as vocabulary_id,  individual_mutation as concept_code, ( regexp_matches(biomarker, '(\w+) '))[1] as gene, ( regexp_matches(biomarker, '(\w+) '))[1]||':'||cdna as hgvs
from sources.cgi_genomic
where cdna != '' 
)

-- JAX vocab
union 
(
select distinct gene_symbol||':'||variant  as concept_name, 'JAX' as  vocabulary_id, gene_variant_id, gene_symbol as gene, g_dna
from sources.jax_variant 
union 
select distinct gene_symbol||':'||variant  as concept_name, 'JAX' as  vocabulary_id, gene_variant_id, gene_symbol as gene, gene_symbol||':'||c_dna
from sources.jax_variant 
union 
select distinct gene_symbol||':'||variant as concept_name, 'JAX' as  vocabulary_id, gene_variant_id, gene_symbol as gene, gene_symbol||':'||protein
from sources.jax_variant 
)

-- file from Korean's
union
(
select concept_name, 'OncoPanel' as vocabulary_id, concept_code, target_gene1_id as gene, reference_sequence||':'||hgvs_c as hgvs
from sources.korean_varaints
union
select concept_name, 'OncoPanel' as vocabulary_id, concept_code, target_gene1_id as gene, reference_sequence||':'||hgvs_p as hgvs
from sources.korean_varaints
where hgvs_p != 'NULL'
)

union
(
select hugo_symbol||':'||variant as concept_name, 'OncoKB' as vocabulary_id, hugo_symbol||':'||variant as concept_code, hugo_symbol as gene, hugo_symbol||':p.'||variant as hgvs
from sources.oncokb
)

),


matched_snp as (
  select concept_name, vocabulary_id, concept_code, gene, hgvs,
     regexp_matches(hgvs, '([\w_]+)(\.\d+)?:([cCgGoOmMnNrRpP])\.([\w\_\+\-\*>=]+)') as m
  from snp 
),
parsed as (
  select concept_name, vocabulary_id, concept_code, hgvs, gene, m[1] as refseq, m[2] as version, lower(m[3]) as seqtype, m[4] as variant
  from matched_snp
  --where m[4] not like '%=%'
)
select concept_name, vocabulary_id, concept_code, gene, refseq, version, seqtype, variant, trim(variant) as var_name from parsed

;

update genom set variant = replace (variant,'=',substring(variant, '^\w\w\w')),var_name = replace (var_name,'=',substring(var_name, '^\w\w\w')) where variant like '%=%';

-- one letter instead of three letter AA
update genom set variant=replace(variant, 'Ala', 'A'),var_name=replace(var_name, 'Ala', 'Ala ')where seqtype='p'; 
update genom set variant=replace(variant, 'Asx', 'B'),var_name=replace(var_name, 'Asx', 'Asx') where seqtype='p'; 
update genom set variant=replace(variant, 'Cys', 'C'),var_name=replace(var_name, 'Cys', 'Cys ') where seqtype='p'; 
update genom set variant=replace(variant, 'Asp', 'D'),var_name=replace(var_name, 'Asp', 'Asp ') where seqtype='p'; 
update genom set variant=replace(variant, 'Glu', 'E'),var_name=replace(var_name, 'Glu', 'Glu ') where seqtype='p'; 
update genom set variant=replace(variant, 'Phe', 'F'),var_name=replace(var_name, 'Phe', 'Phe ') where seqtype='p'; 
update genom set variant=replace(variant, 'Gly', 'G'),var_name=replace(var_name, 'Gly', 'Gly ') where seqtype='p'; 
update genom set variant=replace(variant, 'His', 'H'),var_name=replace(var_name, 'His', 'His ') where seqtype='p'; 
update genom set variant=replace(variant, 'Ile', 'I'),var_name=replace(var_name, 'Ile', 'Ile ') where seqtype='p';
update genom set variant=replace(variant, 'Lys', 'K'),var_name=replace(var_name, 'Lys', 'Lys ') where seqtype='p'; 
update genom set variant=replace(variant, 'Leu', 'L'),var_name=replace(var_name, 'Leu', 'Leu ') where seqtype='p'; 
update genom set variant=replace(variant, 'Met', 'M'),var_name=replace(var_name, 'Met', 'Met ') where seqtype='p'; 
update genom set variant=replace(variant, 'Asn', 'N'),var_name=replace(var_name, 'Asn', 'Asn ') where seqtype='p'; 
update genom set variant=replace(variant, 'Pro', 'P'),var_name=replace(var_name, 'Pro', 'Pro ') where seqtype='p'; 
update genom set variant=replace(variant, 'Gln', 'Q'),var_name=replace(var_name, 'Gln', 'Gln ') where seqtype='p'; 
update genom set variant=replace(variant, 'Arg', 'R'),var_name=replace(var_name, 'Arg', 'Arg ') where seqtype='p'; 
update genom set variant=replace(variant, 'Ser', 'S'),var_name=replace(var_name, 'Ser', 'Ser ') where seqtype='p';   
update genom set variant=replace(variant, 'Thr', 'T'),var_name=replace(var_name, 'Thr', 'Thr ') where seqtype='p'; 
update genom set variant=replace(variant, 'Sec', 'U'),var_name=replace(var_name, 'Sec', 'Sec ') where seqtype='p';
update genom set variant=replace(variant, 'Val', 'V'),var_name=replace(var_name, 'Val', 'Val ') where seqtype='p'; 
update genom set variant=replace(variant, 'Trp', 'W'),var_name=replace(var_name, 'Trp', 'Trp ') where seqtype='p'; 
update genom set variant=replace(variant, 'Xaa', 'X'),var_name=replace(var_name, 'Xaa', 'Xaa ') where seqtype='p'; 
update genom set variant=replace(variant, 'Tyr', 'Y'),var_name=replace(var_name, 'Tyr', 'Tyr ') where seqtype='p'; 
update genom set variant=replace(variant, 'Glx', 'Z'),var_name=replace(var_name, 'Glx', 'Glx ')  where seqtype='p';
update genom set variant=replace(variant, 'Ter', '*'),var_name=replace(var_name, 'Ter', 'Ter ') where seqtype='p'; 


-- update for proper naming protein variatns
drop table if exists g_adj;
create table g_adj as 
select distinct concept_code,vocabulary_id,gene,refseq,seqtype,variant
from genom
where seqtype = 'p'and  vocabulary_id in ('NCIt','CAP','LOINC','JAX','OncoKB') and var_name = variant
; 

update genom set var_name= replace(var_name, 'A', 'Ala ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'B', 'Asx') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'C', 'Cys ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'D', 'Asp ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'G', 'Gly ')where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'E', 'Glu ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'P', 'Pro ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'F', 'Phe ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update genom set var_name= replace(var_name, 'H', 'His ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'I', 'Ile ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'L', 'Leu ')where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'K', 'Lys ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);
update genom set var_name= replace(var_name, 'M', 'Met ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update genom set var_name= replace(var_name, 'N', 'Asn ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'Q', 'Gln ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'R', 'Arg ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update genom set var_name= replace(var_name, 'S', 'Ser ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'T', 'Thr ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update genom set var_name= replace(var_name, 'U', 'Sec ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'V', 'Val ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update genom set var_name= replace(var_name, 'W', 'Trp ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'X', 'Xaa ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update genom set var_name= replace(var_name, 'Y', 'Tyr ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, 'Z', 'Glx ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update genom set var_name= replace(var_name, '*', 'Ter ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  

update genom set var_name= replace(var_name, '*', 'Ter ') where var_name ~ '\*$' ;

-- Change indel to substitution
update genom set variant= replace(variant, 'del([GATCU][GATCU]?[GATCU]?[GATCU]?[GATCU]?[GATCU]?)ins', E'\\1>') where variant like '%del_%ins%'
;


-- intersection of vocabularies
drop table if exists canonical_variant;
create table canonical_variant as 
select gene, seqtype, variant, 
  string_agg(distinct vocabulary_id, ', ' order by vocabulary_id) as vocabs,
  string_agg(distinct refseq||version, ', ' order by refseq||version) as refseqs
from genom
group by gene, seqtype, variant
;

--create sequence for canonical variants
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

--add OMOP codes to canonical variants
drop table if exists omop_variants;
create table omop_variants as 
select *, 'OMOP' || NEXTVAL('omop_seq') AS concept_code from (
select distinct gene,seqtype,variant
from genom 
where (concept_code,vocabulary_id) in ( 
select distinct concept_code,vocabulary_id
from canonical_variant 
join genom using(gene,seqtype,variant)
where vocabs not in ('ClinVar','JAX')
)
)a
;

drop table if exists g_can;
create table g_can as 
select concept_name,vocabulary_id,g.concept_code,gene,refseq,version,seqtype,variant,var_name, ov.concept_code as omop_can_code
from genom g 
join omop_variants ov using(gene,seqtype, variant)
;




-- Incorporate HGNC vocabulary 
INSERT INTO concept_stage
SELECT DISTINCT NULL::INT,
       trim(symbol|| ' (' ||f_name|| ')'||' gene variant measurement') AS concept_name,
       'Measurement' AS domain_id,
       'OMOP Genomic' AS vocabulary_id,
       'Genetic Variation' AS concept_class_id,
       'S' AS standard_concept,
       -- TBD
       TRIM( regexp_REPLACE(hgnc_id,'HGNC:','')) as concept_code,
       TO_DATE( regexp_REPLACE(date_approved_reserved,'-','','g'),'yyyymmdd') AS valid_start_date,
       -- what use as valid_start_date (date_approved_reserved|date_modified)
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM sources.hgnc
;

-- Synonyms for HGNC Variants 
insert into concept_synonym_stage  
select distinct * from (
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
union
select  DISTINCT NULL::INT as synonym_concept_id,
trim(symbol) AS synonym_name,
TRIM( regexp_REPLACE(hgnc_id,'HGNC:','')) as synonym_concept_code,
'OMOP Genomic' AS synonym_vocabulary_id,
4180186 as language_concept_id
from   sources.hgnc 
)a
;



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
FROM genom
where (concept_code,vocabulary_id) in ( 
select distinct concept_code,vocabulary_id 
from canonical_variant 
join genom using(gene,seqtype,variant)
where vocabs not in ('ClinVar','JAX')
)
and vocabulary_id not in ('OncoPanel','CAP','LOINC')
and seqtype != 'n' 
and length(concept_code) <= 50
;



insert into concept_stage
select * from concept_stage_manual;

-- insert to concept stage canonical variants as OMOP Extension vocab
insert into concept_stage
select distinct * from(
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
       a.omop_can_code as concept_code,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM g_can a 
join sources.hgnc ON symbol = a.gene
left join 
  (
  select distinct assembly, chromosomeaccession from sources.clinvar
  union
  select distinct reference_build,substring(hgvs,'\w+\_\d+\.\d+') from ( 
  select civic_start, reference_build,(regexp_matches(hgvs_expressions, '[^, ]+', 'g'))[1] as hgvs
  from sources.civic_variantsummaries
  ) ref 
  where hgvs like '%'||civic_start||'%'
  ) ref_build on chromosomeaccession = refseq||version
) r 
-- filter strange variant
where concept_name is not null 
;

delete from concept_stage 
where concept_code in (
select concept_code from concept_stage 
group by concept_code,vocabulary_id
having count(concept_name) >1 
)
and concept_name like '%GRCh38%';


-- insert synonyms such as HGNC for all canonical variants
insert into concept_synonym_stage
select * 
from (
select  
DISTINCT NULL::INT as synonym_concept_id,
a.refseq||a.version||':'||a.seqtype|| '.' ||a.variant AS synonym_name,
cs.concept_code as synonym_concept_code,
cs.vocabulary_id AS synonym_vocabulary_id,
4180186 as language_concept_id
from g_can a 
join concept_stage cs on cs.concept_code = a.omop_can_code
) r
where synonym_name is not null
;







-- add realtionship from gene to genomic variants
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
   AND cs.vocabulary_id = 'OMOP Genomic'
  JOIN g_can g ON symbol = g.gene
  JOIN concept_stage cs1 ON cs1.concept_code = g.omop_can_code
WHERE g.seqtype = 'g'
;

-- add realtionship from genomic variants to transcript variants
insert into concept_relationship_stage
SELECT DISTINCT NULL::INTEGER AS concept_id_1,
       NULL::INTEGER AS concept_id_2,
       cs1.concept_code AS concept_code_1,
       cs2.concept_code AS concept_code_2,
       cs1.vocabulary_id AS vocabulary_id_1,
       cs2.vocabulary_id AS vocabulary_id_2,
       'Is transcribed to' AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM g_can g1
  JOIN concept_stage cs1
    ON cs1.concept_code = g1.omop_can_code
  join g_can g2
    on g2.concept_code = g1.concept_code
     JOIN concept_stage cs2
    ON cs2.concept_code = g2.omop_can_code
WHERE g2.seqtype = 'c'
AND g1.seqtype = 'g'
;


-- add realtionship from transcript variants to protein variants
insert into concept_relationship_stage
SELECT DISTINCT NULL::INTEGER AS concept_id_1,
       NULL::INTEGER AS concept_id_2,
       cs1.concept_code AS concept_code_1,
       cs2.concept_code AS concept_code_2,
       cs1.vocabulary_id AS vocabulary_id_1,
       cs2.vocabulary_id AS vocabulary_id_2,
       'Is translated to' AS relationship_id,
       CURRENT_DATE -1 AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM g_can g1
  JOIN concept_stage cs1
    ON cs1.concept_code = g1.omop_can_code
    AND g1.seqtype = 'c'
  join g_can g2
    on g2.concept_code = g1.concept_code
     JOIN concept_stage cs2
    ON cs2.concept_code = g2.omop_can_code
WHERE g2.seqtype = 'p';


INSERT INTO concept_relationship_stage
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
    ON TRIM (REPLACE (hgnc_id,'HGNC:','')) = concept_code
   AND cs.vocabulary_id = 'OMOP Genomic'
  JOIN g_can g ON symbol = g.gene
  JOIN concept_stage cs1 ON cs1.concept_code = g.omop_can_code
WHERE g.seqtype = 'c'
AND   g.omop_can_code NOT IN (SELECT concept_code_2
                              FROM concept_relationship_stage crs
                                JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_1 and cs1.vocabulary_id = crs.vocabulary_id_1
                                join concept_stage cs2 ON cs2.concept_code = crs.concept_code_2 and cs2.vocabulary_id = crs.vocabulary_id_2
                              WHERE cs1.concept_class_id = 'DNA Variant' and cs2.concept_class_id = 'RNA Variant' ) 
;


INSERT INTO concept_relationship_stage
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
    ON TRIM (REPLACE (hgnc_id,'HGNC:','')) = concept_code
   AND cs.vocabulary_id = 'OMOP Genomic'
  JOIN g_can g ON symbol = g.gene
  JOIN concept_stage cs1 ON cs1.concept_code = g.omop_can_code
WHERE g.seqtype = 'p'
AND   g.omop_can_code NOT IN (SELECT concept_code_2
                              FROM concept_relationship_stage crs
                                JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_1 and cs1.vocabulary_id = crs.vocabulary_id_1
                                join concept_stage cs2 ON cs2.concept_code = crs.concept_code_2 and cs2.vocabulary_id = crs.vocabulary_id_2
                              WHERE cs1.concept_class_id = 'RNA Variant' and cs2.concept_class_id = 'Protein Variant' ) 
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
from g_can g
join concept_stage cs on cs.concept_code = g.concept_code and cs.vocabulary_id = g.vocabulary_id
join concept_stage cs1 on cs1.concept_code = g.omop_can_code
;


--4. Create concept_relationship_stage only from manual source
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--5. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

