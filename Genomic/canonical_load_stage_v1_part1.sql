-- extract position for canonical variant from hgvs expressions  
drop table if exists g;
create table g as
with snp as (
-- ClinVar 
  select distinct f_name as concept_name, 'ClinVar' as vocabulary_id, cast(alleleid as varchar(6)) as concept_code, genesymbol as gene,  hgvs
  from variant_summary 
  join clinvar_clean on f_name = clin_name
  where hgvs ~ '^NM|^NP|^NC|^LRG|^NG|^NR'
 
  
-- civic
union
  select distinct variant as concept_name, 'CIViC' as vocabulary_id, cast(variant_id as varchar(5)) as concept_code, gene, ( regexp_matches(hgvs_expressions, '[^, ]+', 'g'))[1] as hgvs
  from civic_variantsummaries
  where hgvs_expressions ~ '[\w_]+(\.\d+)?:[cCgGoOmMnNrRpP]\.'


-- NCI
union
  select concept_name, vocabulary_id, concept_code, ( regexp_matches(display_name, '(\w+) '))[1] as gene, ( regexp_matches(display_name, '\w+ (.+)'))[1] as hgvs from (
    select definition as concept_name, 'NCIt' as vocabulary_id, code as concept_code, display_name
    from nci_thesaurus 
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
update g set variant=replace(variant, 'Ala', 'A'),var_name=replace(var_name, 'Ala', 'Ala ')where seqtype='p'; 
update g set variant=replace(variant, 'Asx', 'B'),var_name=replace(var_name, 'Asx', 'Asx') where seqtype='p'; 
update g set variant=replace(variant, 'Cys', 'C'),var_name=replace(var_name, 'Cys', 'Cys ') where seqtype='p'; 
update g set variant=replace(variant, 'Asp', 'D'),var_name=replace(var_name, 'Asp', 'Asp ') where seqtype='p'; 
update g set variant=replace(variant, 'Glu', 'E'),var_name=replace(var_name, 'Glu', 'Glu ') where seqtype='p'; 
update g set variant=replace(variant, 'Phe', 'F'),var_name=replace(var_name, 'Phe', 'Phe ') where seqtype='p'; 
update g set variant=replace(variant, 'Gly', 'G'),var_name=replace(var_name, 'Gly', 'Gly ') where seqtype='p'; 
update g set variant=replace(variant, 'His', 'H'),var_name=replace(var_name, 'His', 'His ') where seqtype='p'; 
update g set variant=replace(variant, 'Ile', 'I'),var_name=replace(var_name, 'Ile', 'Ile ') where seqtype='p';
update g set variant=replace(variant, 'Lys', 'K'),var_name=replace(var_name, 'Lys', 'Lys ') where seqtype='p'; 
update g set variant=replace(variant, 'Leu', 'L'),var_name=replace(var_name, 'Leu', 'Leu ') where seqtype='p'; 
update g set variant=replace(variant, 'Met', 'M'),var_name=replace(var_name, 'Met', 'Met ') where seqtype='p'; 
update g set variant=replace(variant, 'Asn', 'N'),var_name=replace(var_name, 'Asn', 'Asn ') where seqtype='p'; 
update g set variant=replace(variant, 'Pro', 'P'),var_name=replace(var_name, 'Pro', 'Pro ') where seqtype='p'; 
update g set variant=replace(variant, 'Gln', 'Q'),var_name=replace(var_name, 'Gln', 'Gln ') where seqtype='p'; 
update g set variant=replace(variant, 'Arg', 'R'),var_name=replace(var_name, 'Arg', 'Arg ') where seqtype='p'; 
update g set variant=replace(variant, 'Ser', 'S'),var_name=replace(var_name, 'Ser', 'Ser ') where seqtype='p';   
update g set variant=replace(variant, 'Thr', 'T'),var_name=replace(var_name, 'Thr', 'Thr ') where seqtype='p'; 
update g set variant=replace(variant, 'Sec', 'U'),var_name=replace(var_name, 'Sec', 'Sec ') where seqtype='p';
update g set variant=replace(variant, 'Val', 'V'),var_name=replace(var_name, 'Val', 'Val ') where seqtype='p'; 
update g set variant=replace(variant, 'Trp', 'W'),var_name=replace(var_name, 'Trp', 'Trp ') where seqtype='p'; 
update g set variant=replace(variant, 'Xaa', 'X'),var_name=replace(var_name, 'Xaa', 'Xaa ') where seqtype='p'; 
update g set variant=replace(variant, 'Tyr', 'Y'),var_name=replace(var_name, 'Tyr', 'Tyr ') where seqtype='p'; 
update g set variant=replace(variant, 'Glx', 'Z'),var_name=replace(var_name, 'Glx', 'Glx ')  where seqtype='p';
update g set variant=replace(variant, 'Ter', '*'),var_name=replace(var_name, 'Ter', 'Ter ') where seqtype='p'; 


-- update for proper naming protein variatns
drop table if exists g_adj;
create table g_adj as 
select distinct concept_code,vocabulary_id,gene,refseq,seqtype,variant
from g
where seqtype = 'p'and  vocabulary_id in ('NCIt','CAP','LOINC','JAX','OncoKB') and var_name = variant
; 

update g set var_name= replace(var_name, 'A', 'Ala ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'B', 'Asx') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'C', 'Cys ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'D', 'Asp ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'G', 'Gly ')where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'E', 'Glu ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'P', 'Pro ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'F', 'Phe ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update g set var_name= replace(var_name, 'H', 'His ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'I', 'Ile ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'L', 'Leu ')where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'K', 'Lys ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);
update g set var_name= replace(var_name, 'M', 'Met ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update g set var_name= replace(var_name, 'N', 'Asn ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'Q', 'Gln ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'R', 'Arg ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update g set var_name= replace(var_name, 'S', 'Ser ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'T', 'Thr ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update g set var_name= replace(var_name, 'U', 'Sec ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'V', 'Val ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update g set var_name= replace(var_name, 'W', 'Trp ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'X', 'Xaa ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  
update g set var_name= replace(var_name, 'Y', 'Tyr ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, 'Z', 'Glx ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj); 
update g set var_name= replace(var_name, '*', 'Ter ') where (concept_code,vocabulary_id,gene,refseq,seqtype,variant) in (select concept_code,vocabulary_id,gene,refseq,seqtype,variant from g_adj);  

update g set var_name= replace(var_name, '*', 'Ter ') where var_name ~ '\*$' ;

-- Change indel to substitution
update g set variant= replace(variant, 'del([GATCU][GATCU]?[GATCU]?[GATCU]?[GATCU]?[GATCU]?)ins', E'\\1>') where variant like '%del_%ins%'
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



--collecting list refseq of variant that we have 
drop table if exists g_ref;
create table g_ref as 
with all_var as(
select *
from g 
where (concept_code,vocabulary_id) in ( 
select distinct concept_code,vocabulary_id
from canonical_variant 
join g using(gene,seqtype,variant)
where vocabs not in ('ClinVar','JAX')
)
),

exist_refseq as (
select a.concept_name,a.vocabulary_id, a.concept_code, gene, variant, a.var_name, seqtype, b.refseq as refseq, b.version as version
from all_var a 
join all_var b using(gene,variant,seqtype)
where a.vocabulary_id != b.vocabulary_id
and a.refseq !~ '^NM\_|^NC\_|^NP\_'
and b.refseq ~ '^NM\_|^NC\_|^NP\_'
)

select concept_name,vocabulary_id, concept_code, gene, variant,var_name, seqtype, refseq as refseq, version as version
from all_var
where refseq ~ '^NM\_|^NC\_|^NP\_'
union
select *
from exist_refseq
;



-- count variants for each refseq
drop table if exists all_var;
create table all_var as 
with a as(
select concept_code, vocabulary_id,gene, seqtype,count(distinct variant) as var_count
from g_ref
group by concept_code, vocabulary_id,gene, seqtype
),
-- count refseq for each seqtype
b as (
select concept_code, vocabulary_id,gene, seqtype,variant, count(distinct refseq) as refseq_count
from g_ref 
group by concept_code, vocabulary_id,gene, seqtype,variant
),
-- count versions of refseq for each variant
c as (
select * , '.'||max(replace(version,'.','')::int) over (partition by gene,variant,refseq,seqtype) as lat_new_code, max(vocab_count) over (partition by gene,variant,refseq,seqtype)  as max_vocab_count
from (
select distinct gene, refseq, version, seqtype, variant, count ( distinct vocabulary_id) as vocab_count, string_agg(distinct vocabulary_id,'|') as vocabs
from g_ref
group by gene, refseq, version, seqtype, variant
) r
)
select distinct concept_name, concept_code,vocabulary_id, c.gene,  refseq,version,seqtype,variant,var_name, var_count,refseq_count,vocab_count,vocabs,max_vocab_count,max(refseq) over (partition by g_ref.variant,g_ref.gene,g_ref.seqtype,g_ref.concept_code) as max_refseq
from g_ref
join a using(concept_code, vocabulary_id,gene, seqtype)
join b using(concept_code, vocabulary_id,gene, seqtype,variant)
join c using(refseq, seqtype, variant,version)
;


--pick canonical genomic variant
drop table if exists genom_canonical;
create table  genom_canonical as 
select distinct gene,refseq,version,seqtype,variant,var_name
from all_var 
where refseq_count = 1
and seqtype = 'g'
;

--pick canonical transcript variant
drop table if exists trans_canonical;
create table  trans_canonical as 
with trans_1 as (
select distinct a.gene,a.refseq,a.version,a.seqtype,a.variant,a.var_name
from all_var a 
join all_var b using (concept_name, concept_code, vocabulary_id,gene, seqtype,variant)
where a.refseq_count > 1
and a.max_vocab_count > b.vocab_count
and a.seqtype = 'c'
and a.version = substring(concept_name,'\d(\.\d\d?)\(')
), 

trans_2 as (
select distinct gene,refseq,version,seqtype,variant,var_name
from all_var
where (concept_code,vocabulary_id) not in 
(
select concept_code,vocabulary_id 
from all_var
join trans_1 using(gene,refseq,version,seqtype,variant)
)
and seqtype = 'c'
and (version = substring(concept_name,'\d(\.\d\d?)\(') or  version = substring(concept_name,'\d(\.\d\d?)\:'))
and (refseq = substring(concept_name,'(NM\_\d+)\.\d\d?\(') or refseq = substring(concept_name,'(NM\_\d+)\.\d\d?\:'))
),

trans_3 as (
select distinct a.gene,a.refseq,a.version,a.seqtype,a.variant,a.var_name
from all_var a 
join all_var b using (concept_name, concept_code, vocabulary_id,gene, seqtype,variant)
where a.refseq_count > 1
and a.max_vocab_count > b.vocab_count
and a.seqtype = 'c'
and (concept_code,vocabulary_id) not in 
(
select concept_code,vocabulary_id 
from all_var
where (gene,refseq,version,seqtype,variant) in 
(
select gene,refseq,version,seqtype,variant
from trans_1
union 
select gene,refseq,version,seqtype,variant
from trans_2
)
)
),

trans_4 as (
select gene,refseq,version,seqtype,variant ,var_name
from all_var
where (concept_code,vocabulary_id) not in 
(
select concept_code,vocabulary_id 
from all_var
where (gene,refseq,version,seqtype,variant) in (
select gene,refseq,version,seqtype,variant
from trans_1
union 
select gene,refseq,version,seqtype,variant
from trans_2
union 
select gene,refseq,version,seqtype,variant
from trans_3
)
)
and seqtype = 'c'
and refseq_count > 1
and refseq = max_refseq
)



select gene,refseq,version,seqtype,variant,var_name
from trans_1
union 
select gene,refseq,version,seqtype,variant,var_name
from trans_2
union 
select gene,refseq,version,seqtype,variant,var_name
from trans_3
union 
select gene,refseq,version,seqtype,variant,var_name
from trans_4
union
select gene,refseq,version,seqtype,variant,var_name
from all_var
where (concept_code,vocabulary_id) not in 
(
select concept_code,vocabulary_id 
from all_var
where (gene,refseq,version,seqtype,variant) in (
select gene,refseq,version,seqtype,variant
from trans_1
union 
select gene,refseq,version,seqtype,variant
from trans_2
union 
select gene,refseq,version,seqtype,variant
from trans_3
union 
select gene,refseq,version,seqtype,variant
from trans_4
)
)
and seqtype = 'c'
and refseq like 'NM%'
;

-- pick canonical protein variant
drop table if exists prot_canonical;
create table  prot_canonical as 
with prot_1 as (
select distinct a.gene,a.refseq,a.version,a.seqtype,a.variant, a.var_name
from all_var a 
join all_var b using (concept_name, concept_code, vocabulary_id,gene, seqtype,variant)
where a.refseq_count > 1
and a.max_vocab_count > b.vocab_count
and a.seqtype = 'p'
and a.refseq like 'NP%'
), 

prot_2 as (
select distinct gene,refseq,version,seqtype,variant,var_name
from all_var
where (concept_code,vocabulary_id) not in 
(
select concept_code,vocabulary_id 
from all_var
join prot_1 using(gene,refseq,version,seqtype,variant)
)
and seqtype = 'p'
and refseq_count > 1
and refseq = max_refseq
and refseq like 'NP%'
)


select gene,refseq,version,seqtype,variant,var_name
from prot_1
union 
select gene,refseq,version,seqtype,variant,var_name
from prot_2
union
select gene,refseq,version,seqtype,variant,var_name
from all_var
where (concept_code,vocabulary_id) not in 
(
select concept_code,vocabulary_id 
from all_var
where (gene,refseq,version,seqtype,variant) in (
select gene,refseq,version,seqtype,variant
from prot_1
union 
select gene,refseq,version,seqtype,variant
from prot_2
)
)
and seqtype = 'p'
and refseq like 'NP%'
;

--create one table with canonical refseq
drop table if exists canonical_refseq;
create table canonical_refseq as 
select * from prot_canonical
union
select * from trans_canonical
union
select * from genom_canonical
;


