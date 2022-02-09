--do we have nice synonyms in RxNorm?
drop table if exists rx_names
;
create table rx_names as (
select c.concept_code, c.vocabulary_id , cs.concept_synonym_name as concept_name from devv5.concept_synonym cs 
join concept c on cs.concept_id = c.concept_id 
where c.vocabulary_id in ('RxNorm', 'RxNorm Extension') and c.concept_class_id in ('Ingredient' , 'Precise Ingredient')
union 
select c.concept_code, c.vocabulary_id , c.concept_name  from concept c
where c.vocabulary_id in ('RxNorm', 'RxNorm Extension') and c.concept_class_id ='Ingredient' and c.concept_class_id in ('Ingredient' , 'Precise Ingredient') -- non stated whether it's standard or not as we will Map them in the future steps
)
;
--parse ncit_antineopl , got it from https://evs.nci.nih.gov/ftp1/NCI_Thesaurus/Drug_or_Substance/Antineoplastic_Agent.txt
drop table if exists ncit_antineopl
;
create table ncit_antineopl as
select distinct * from ( -- somehow the source table has duplicates of synonyms
select code,preferred_name,definition,semantic_type, regexp_split_to_table (synonyms, ' \|\| ') as synonym_name from dev_mkallfelz.ncit_antineopl 
) a
;
drop table if exists nci_drb_syn
;
--add synonyms from UMLS and NCIt
create table nci_drb_syn as (
--DRUGBANK and NCI taken from mrconso
 select  db.sab, db.code, db.str from sources.mrconso db 
  where db.sab='DRUGBANK' and suppress ='N'
  union all 
   select distinct 'NCI', a.concept_id, sy from dev_mkallfelz.ncit_pharmsub a
  )
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
with map as (
select distinct a.*, coalesce (b.code, rx1.concept_code, rx2.concept_code) as concept_code_2, coalesce (b.str, rx1.concept_name, rx2.concept_name) as concept_name_2,
 coalesce (case when b.sab='RXNORM' then 'RxNorm' else null end ,rx1.vocabulary_id, rx2.vocabulary_id) as vocabulary_id_2
from inv_syn a
left join sources.mrconso b on a.cui = b.cui and b.sab ='RXNORM' AND b.suppress ='N' and b.tty in ('PIN', 'IN')
left join rx_names rx1 on lower (rx1.concept_name) = lower (a.str) -- str corresponds to the source preffered name
left join rx_names rx2 on lower (rx2.concept_name) = lower (a.synonym_name) -- synonym_name
)
--adding replacement mappings for updated RxNorms or being non-standard by other reasons
select cui,sab,tty,code,str,parent_code,antineopl_code,synonym_name,b.concept_code as concept_code_2,b.concept_name as concept_name_2,b.vocabulary_id as vocabulary_id_2 
from map a
left join concept c on a.concept_code_2 = c.concept_code and a.vocabulary_id_2 = c.vocabulary_id
left join concept_relationship r on r.concept_id_1 = c.concept_id and relationship_id ='Maps to' and r.invalid_reason is null
left join concept b on b.concept_id = r.concept_id_2
;
drop table if exists inv_master
;
--assing concatenated codes (that will be used in concept_stage) to our table
create table inv_master as
with cui_to_code as (
select replace (string_agg (code, '-') over (partition by cui order by code), 'C', 'NCITC')  as concept_code, code
 from (select distinct cui, code from inv_rx_map where cui is not null ) a
union
--you can't aggregate if CUI is null
select replace (code, 'C', 'NCITC') as concept_code , code
from inv_rx_map where cui is null
)
select concept_code, a.* from inv_rx_map a
join cui_to_code b on a.code = b.code
;
--manual step (occurrs only due to problem with existing RxE that same drugs have different concepts)
delete from  inv_master where concept_code ='NCITC171815' and concept_code_2 ='OMOP4873903' 
;
