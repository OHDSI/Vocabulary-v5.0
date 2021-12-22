--working schema dev_mind -- dev_ind schema should be created actually

create table nci_drb_rxn as
 with nci_drb as (
 select * from sources.mrconso db 
  where db.sab='DRUGBANK' and db.tty ='IN' and suppress ='N'
  union all 
   select distinct db.* from sources.mrconso db 
   join dev_mkallfelz.ncit_pharmsub a on a.concept_id = db.code
  where db.sab='NCI' and db.tty ='PT' and suppress ='N'
  ),
  inv_cnt as (
  select * from (
  select *, count (1) over (partition by cui) as cnt  from nci_drb
  ) a 
order by str 
)
select a.cui, a.sab, a.tty, a.code, a.str, cnt,
b.tty as rx_tty, b.code as rx_code,  b.str as rx_str
from inv_cnt  a
left join sources.mrconso b on a.cui = b.cui and b.sab ='RXNORM' AND b.suppress ='N' and b.tty in ('PIN', 'IN')
 ;
--concept present in NCIt file but absent in the MRCONSO added to the nci_drb_rxn table with an attempt of mapping them to RxNorm
insert into nci_drb_rxn
select distinct null, 'NCI', 'PT', a.concept_id, pt, null::bigint, null, c.concept_code, c.concept_name from dev_mkallfelz.ncit_pharmsub  a
left join devv5.concept c on lower (c.concept_name) = lower (sy) and c.vocabulary_id ='RxNorm' 
where a.concept_id not in
(
select code from nci_drb_rxn)
;
--normalize ncit_antineopl, making separate entries for each synonym
create table ncit_antineopl as
select distinct * from ( -- somehow the source table has duplicates of synonyms
select code,preferred_name,definition,semantic_type, regexp_split_to_table (synonyms, ' \|\| ') as synonym_name from dev_mkallfelz.ncit_antineopl 
) a
