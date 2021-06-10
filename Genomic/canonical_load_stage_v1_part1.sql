-- extract position for canonical variant from hgvs expressions  
drop table if exists dev_dkaduk.g;
create table dev_dkaduk.g as
with snp as (
-- ClinVar 
  select distinct f_name as concept_name, 'ClinVar' as vocabulary_id, cast(alleleid as varchar(6)) as concept_code, genesymbol as gene,  hgvs
  from dev_christian.variant_summary 
  join clinvar_clean on f_name = clin_name
  where hgvs ~ '^NM|^NP|^NC|^LRG|^NG|^NR'
 
  
-- civic
union
  select distinct variant as concept_name, 'CIViC' as vocabulary_id, cast(variant_id as varchar(5)) as concept_code, gene, ( regexp_matches(hgvs_expressions, '[^, ]+', 'g'))[1] as hgvs
  from dev_christian.civic_variantsummaries
  where hgvs_expressions ~ '[\w_]+(\.\d+)?:[cCgGoOmMnNrRpP]\.'


-- NCI
union
  select concept_name, vocabulary_id, concept_code, ( regexp_matches(display_name, '(\w+) '))[1] as gene, ( regexp_matches(display_name, '\w+ (.+)'))[1] as hgvs from (
    select definition as concept_name, 'NCIt' as vocabulary_id, code as concept_code, display_name
    from ddymshyts.nci_thesaurus 
    where coalesce(concept_status, '') not in ('Retired_Concept', 'Obsolete_Concept') and semantic_type in ('Cell or Molecular Dysfunction')
      and display_name ~ '[\w_]+(\.\d+)?:[cCgGoOmMnNrRpP]\.'
  ) a
  
-- CAP
union  
  select concept_name, vocabulary_id, concept_code, gene, gene||':'||hgvs_half as hgvs from (
    select concept_name, vocabulary_id, concept_code, coalesce(m1, m2) as gene, ( regexp_matches(concept_name, '[cCpP]\.[\w\_\+\-\*>=]+', 'g'))[1] as hgvs_half from (
     select vl.concept_name, vl.vocabulary_id, vl.concept_code, 
        ( regexp_matches(vl.concept_name, '^\w{3,8}'))[1] as m1, ( regexp_matches(vr.concept_name, '^\w{3,8}'))[1] as m2
      from devv5.concept vl 
      left join (
        select concept_id_1, concept_name
        from devv5.concept_relationship r join devv5.concept on concept_id=r.concept_id_2
        where r.invalid_reason is null and r.relationship_id='CAP value of'  
      ) vr on vr.concept_id_1=vl.concept_id  
      where vl.vocabulary_id= 'CAP' -- and lower(vr.concept_name) like '%mutatat%' 
      and vl.concept_name ~ '([cCgGoOmMnNrRpP])\.([\w\_\+\-\*>=]+)'
    ) a
  ) b
  


union 
select concept_name, 'CAP' vocabulary_id, concept_name as concept_code, substring(concept_name, '^(\w+\-?\w+?)\:')gene, concept_name as hgvs from CAP_variant

-- LOINC
union
  select concept_name, vocabulary_id, concept_code, m[1] as gene, m[1]||':'||m[2] as hgvs from ( 
    select concept_name, vocabulary_id, concept_code,  regexp_matches(concept_name, '(\w{3,8}) gene ([cCgGoOmMnNrRpP]\.[\w\_\+\-\*>=]+)') as m from concept where vocabulary_id='LOINC'
  ) a

-- CGI vocab
union
(
select distinct individual_mutation as concept_name, 'CGI' as vocabulary_id,  individual_mutation as concept_code, ( regexp_matches(biomarker, '(\w+) '))[1] as gene, gdna as hgvs
from cgi_genomic
where gdna != '' 
union 
select distinct individual_mutation as concept_name, 'CGI' as vocabulary_id,  individual_mutation as concept_code, ( regexp_matches(biomarker, '(\w+) '))[1] as gene, ( regexp_matches(biomarker, '(\w+) '))[1]||':'||cdna as hgvs
from cgi_genomic
where cdna != '' 
)

-- JAX vocab
union 
(
select distinct variant as concept_name, 'JAX' as  vocabulary_id, gene_variant_id, gene_symbol as gene, g_dna
from jax_variant 
union 
select distinct variant as concept_name, 'JAX' as  vocabulary_id, gene_variant_id, gene_symbol as gene, gene_symbol||':'||c_dna
from jax_variant 
union 
select distinct variant as concept_name, 'JAX' as  vocabulary_id, gene_variant_id, gene_symbol as gene, gene_symbol||':'||protein
from jax_variant 
)

-- file from Korean's
union
(
select concept_name, 'OncoPanel' as vocabulary_id, concept_code, target_gene1_id as gene, reference_sequence||':'||hgvs_c as hgvs
from ajou_var_vs_code
union
select concept_name, 'OncoPanel' as vocabulary_id, concept_code, target_gene1_id as gene, reference_sequence||':'||hgvs_p as hgvs
from ajou_var_vs_code
where hgvs_p != 'NULL'
)

union
(
select hugo_symbol||':'||variant as concept_name, 'OncoKB' as vocabulary_id, hugo_symbol||':'||variant as concept_code, hugo_symbol as gene, hugo_symbol||':p.'||variant as hgvs
from oncokb
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

update g set variant = replace (variant,'=',substring(variant, '^\w\w\w')),var_name = replace (var_name,'=',substring(var_name, '^\w\w\w')) where variant like '%=%';

-- one letter instead of three letter AA
update dev_dkaduk.g set variant=replace(variant, 'Ala', 'A'),var_name=replace(var_name, 'Ala', 'Ala ')where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Asx', 'B'),var_name=replace(var_name, 'Asx', 'Asx') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Cys', 'C'),var_name=replace(var_name, 'Cys', 'Cys ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Asp', 'D'),var_name=replace(var_name, 'Asp', 'Asp ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Glu', 'E'),var_name=replace(var_name, 'Glu', 'Glu ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Phe', 'F'),var_name=replace(var_name, 'Phe', 'Phe ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Gly', 'G'),var_name=replace(var_name, 'Gly', 'Gly ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'His', 'H'),var_name=replace(var_name, 'His', 'His ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Ile', 'I'),var_name=replace(var_name, 'Ile', 'Ile ') where seqtype='p';
update dev_dkaduk.g set variant=replace(variant, 'Lys', 'K'),var_name=replace(var_name, 'Lys', 'Lys ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Leu', 'L'),var_name=replace(var_name, 'Leu', 'Leu ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Met', 'M'),var_name=replace(var_name, 'Met', 'Met ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Asn', 'N'),var_name=replace(var_name, 'Asn', 'Asn ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Pro', 'P'),var_name=replace(var_name, 'Pro', 'Pro ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Gln', 'Q'),var_name=replace(var_name, 'Gln', 'Gln ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Arg', 'R'),var_name=replace(var_name, 'Arg', 'Arg ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Ser', 'S'),var_name=replace(var_name, 'Ser', 'Ser ') where seqtype='p';   
update dev_dkaduk.g set variant=replace(variant, 'Thr', 'T'),var_name=replace(var_name, 'Thr', 'Thr ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Sec', 'U'),var_name=replace(var_name, 'Sec', 'Sec ') where seqtype='p';
update dev_dkaduk.g set variant=replace(variant, 'Val', 'V'),var_name=replace(var_name, 'Val', 'Val ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Trp', 'W'),var_name=replace(var_name, 'Trp', 'Trp ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Xaa', 'X'),var_name=replace(var_name, 'Xaa', 'Xaa ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Tyr', 'Y'),var_name=replace(var_name, 'Tyr', 'Tyr ') where seqtype='p'; 
update dev_dkaduk.g set variant=replace(variant, 'Glx', 'Z'),var_name=replace(var_name, 'Glx', 'Glx ')  where seqtype='p';
update dev_dkaduk.g set variant=replace(variant, 'Ter', '*'),var_name=replace(var_name, 'Ter', 'Ter ') where seqtype='p'; 


-- update for proper naming protein variatns
drop table if exists g_adj;
create table g_adj as 
select distinct concept_code,vocabulary_id,gene,refseq,seqtype,variant
from g
where seqtype = 'p'and  vocabulary_id in ('NCIt','CAP','LOINC','JAX','OncoKB') and var_name = variant
; 

update dev_dkaduk.g set var_name= replace(var_name, 'A', 'Ala ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'B', 'Asx') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'C', 'Cys ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'D', 'Asp ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'G', 'Gly ')where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'E', 'Glu ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'P', 'Pro ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'F', 'Phe ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update dev_dkaduk.g set var_name= replace(var_name, 'H', 'His ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'I', 'Ile ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'L', 'Leu ')where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'K', 'Lys ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);
update dev_dkaduk.g set var_name= replace(var_name, 'M', 'Met ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update dev_dkaduk.g set var_name= replace(var_name, 'N', 'Asn ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'Q', 'Gln ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'R', 'Arg ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update dev_dkaduk.g set var_name= replace(var_name, 'S', 'Ser ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'T', 'Thr ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update dev_dkaduk.g set var_name= replace(var_name, 'U', 'Sec ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'V', 'Val ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update dev_dkaduk.g set var_name= replace(var_name, 'W', 'Trp ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'X', 'Xaa ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update dev_dkaduk.g set var_name= replace(var_name, 'Y', 'Tyr ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, 'Z', 'Glx ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update dev_dkaduk.g set var_name= replace(var_name, '*', 'Ter ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  

update dev_dkaduk.g set var_name= replace(var_name, '*', 'Ter ') where var_name ~ '\*$' ;

-- Change indel to substitution
update dev_dkaduk.g set variant= replace(variant, 'del([GATCU][GATCU]?[GATCU]?[GATCU]?[GATCU]?[GATCU]?)ins', E'\\1>') where variant like '%del_%ins%'
;


-- intersection of vocabularies
drop table canonical_variant;
create table canonical_variant as 
select gene, seqtype, variant, 
  string_agg(distinct vocabulary_id, ', ' order by vocabulary_id) as vocabs,
  string_agg(distinct refseq||version, ', ' order by refseq||version) as refseqs
from g
group by gene, seqtype, variant
;

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


create table omop_variants as 
select *, 'OMOP' || NEXTVAL('omop_seq') AS concept_code from (
select distinct gene, variant
from g 
where (concept_code,vocabulary_id) in ( 
select distinct concept_code,vocabulary_id
from dev_dkaduk.canonical_variant 
join g using(gene,seqtype,variant)
where vocabs not in ('ClinVar','JAX')
)
)a
;

