--parse ncit_antineopl , got it from https://evs.nci.nih.gov/ftp1/NCI_Thesaurus/Drug_or_Substance/Antineoplastic_Agent.txt
drop table ncit_antineopl
;
create table ncit_antineopl as
select distinct * from ( -- somehow the source table has duplicates of synonyms
select code,preferred_name,definition,semantic_type, regexp_split_to_table (synonyms, ' \|\| ') as synonym_name from dev_mkallfelz.ncit_antineopl 
) a
;
drop table if exists nci_drb_syn
;
--add synonyms from UMLS !!! review this logic!!
create table nci_drb_syn as (
--DRUGBANK and NCI taken from mrconso

 select db.cui, db.sab, db.code, db.str from sources.mrconso db 
  where db.sab='DRUGBANK' and suppress ='N'
  union all 
   select distinct db.cui, db.sab, db.code, db.str 
    from sources.mrconso db 
   --get NCI drugs - NCI has a lot of other domains
   join dev_mkallfelz.ncit_pharmsub a on a.concept_id = db.code
  where db.sab='NCI' and suppress ='N'
  )
 ;
--concept present in NCIt file but absent in the MRCONSO added to the nci_drb_rxn table with an attempt of mapping them to RxNorm by matching of names since NCI doesn't have CUI in this case
insert into nci_drb_syn
select distinct null, 'NCI', a.concept_id, sy  from dev_mkallfelz.ncit_pharmsub  a
where ( a.concept_id, sy) not in
(
select code, str from nci_drb_syn)

;
drop table if exists nci_drb
;
create table nci_drb as
--DRUGBANK and NCI taken from mrconso
 select cui, sab, tty, code, str from sources.mrconso db 
  where db.sab='DRUGBANK' and db.tty ='IN' and suppress ='N'
  union all 
   select distinct cui, 'NCI', 'PT', a.concept_id, pt from dev_mkallfelz.ncit_pharmsub a
   left join sources.mrconso db on a.concept_id = db.code and db.sab='NCI' and db.tty ='PT' and suppress ='N'
 ;
--we can try to map not only new concepts but all of them using synonyms
--add parent_child relat, fill antineopl_code if it belongs to the antineopls category
drop table if exists inv_syn
;
create table inv_syn as
select a.*, t.parent_code, c.code as antineopl_code, s.str as synonym_name 
from nci_drb a
--get the hierarchy indicators
left join (select code, regexp_split_to_table (parents,'\|') as parent_code from sources.genomic_nci_thesaurus ) t on  a.code =t.code
--get the antineoplastic drugs
left join ncit_antineopl c on a.code = c.code
--get synonyms !!! nci_drb_syn - to review the logic of this table!
left join nci_drb_syn s on s.sab = a.sab and a.code = s.code
;
drop table if exists inv_rx_map
;
--add mappings to RxNorm (E) 
--so basically this table now should have everything -- all mappings and synonyms
create table inv_rx_map as
select distinct a.*, coalesce (b.code, rx1.concept_code, rx2.concept_code) as concept_code_2, coalesce (b.str, rx1.concept_name, rx2.concept_name) as concept_name_2,
 coalesce (case when b.sab='RXNORM' then 'RxNorm' else null end ,rx1.vocabulary_id, rx2.vocabulary_id) as vocabulary_id_2
from inv_syn a
left join sources.mrconso b on a.cui = b.cui and b.sab ='RXNORM' AND b.suppress ='N' and b.tty in ('PIN', 'IN')
left join rx_names rx1 on lower (rx1.concept_name) = lower (a.str) -- str corresponds to the preffered name
left join rx_names rx2 on lower (rx2.concept_name) = lower (a.synonym_name) -- synonym_name
;
drop table if exists inv_master
;
--assing concatenated codes (that will be used in concept_stage) to our table
create table inv_master as
with cui_to_code as (
select replace (string_agg (code, '-') over (partition by cui order by code), 'C', 'NCITC')  as concept_code, code
 from (select distinct cui, code from inv_rx_map where cui is not null ) a
union
--you can't aggregate is CUI is null
select replace (code, 'C', 'NCITC') as concept_code , code
from inv_rx_map where cui is null
)
select concept_code, a.* from inv_rx_map a
join cui_to_code b on a.code = b.code
;
select count(distinct concept_code) from 
inv_master
;
select * from inv_master limit 1
