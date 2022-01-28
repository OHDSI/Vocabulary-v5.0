--preparation step, create the table that will have everything we need, then distribute this table to stage tables
drop table if exists nci_drb
;
create table nci_drb as
--DRUGBANK and NCI taken from mrconso
 select cui, sab, tty, code, str from sources.mrconso db 
  where db.sab='DRUGBANK' and db.tty ='IN' and suppress ='N'
  union all 
   select distinct cui, sab, tty, code, str from sources.mrconso db 
   --use dev_mkallfelz.ncit_pharmsub to get NCI drugs - NCI has a lot of other domains
   join dev_mkallfelz.ncit_pharmsub a on a.concept_id = db.code 
  where db.sab='NCI' and db.tty ='PT' and suppress ='N'
 ;
--concept present in NCIt file but absent in the MRCONSO added to the nci_drb_rxn table with an attempt of mapping them to RxNorm by matching of names since NCI doesn't have CUI in this case
insert into nci_drb
select distinct null, 'NCI', 'PT', a.concept_id, pt
from dev_mkallfelz.ncit_pharmsub  a
where a.concept_id not in
(
select code from nci_drb_rxn)
;
--we can try to map not only new concepts but all of them using synonyms
--add parent_child relat, fill antineopl_code if it belongs to the antineopls category
drop table if exists inv_syn
;
create table inv_syn as
select a.*, t.parents as parent_code, t.code as child_code, c.code as antineopl_code, s.str as synonym_name 
from nci_drb a
--get the hierarchy indicators
left join sources.genomic_nci_thesaurus t on parents = a.code 
--get the antineoplastic drugs
left join ncit_antineopl c on a.code = c.code
--get synonyms
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
--filling stage tables
--1. fill the concept stage
truncate table concept_stage
;

--1.1  let drugbank be a primary name since it should have a better coverage
with cui_to_code as (
select cui, replace (string_agg  (code, '-' order by code), 'C', 'NCITC')  as concept_code
 from (select distinct cui, code from inv_rx_map ) a
 group by cui
)
,
cui_to_name as (
select distinct cui, first_value (str) over (partition by cui order by sab--Drugbank, then NCIt
, str) as concept_name
 from inv_rx_map 
 )
insert into concept_stage
select distinct
null::int, concept_name, 'Drug', 'OMOP Invest Drug', 'Ingredient', null,  concept_code, to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null
 from cui_to_code a
join cui_to_name using (cui)
 where length (a.concept_code ) <= 50
;
--some concepts don't have common CUI while they are similar, let's concatenate their codes as it was done for concepts sharing the same NCI code
drop table if exists dupl_concepts 
;
create table dupl_concepts as 
select concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,
string_agg (concept_code, '-' order by concept_code) as concept_code,
valid_start_date,valid_end_date,invalid_reason from (
select concept_id,initcap (concept_name) as concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,
concept_code
,valid_start_date,valid_end_date,invalid_reason from (
select *, count(1) over (partition by lower (concept_name )) as cnt from concept_stage 
) a where cnt >1
) b 
group by  concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,valid_start_date,valid_end_date,invalid_reason
;
delete from concept_stage where concept_code in (select concept_code_init from dupl_concepts)
;
insert into concept_stage select distinct concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason from dupl_concepts
;
stopped here, need to adopt new logic with universal table
--2. concept_synonym_stage
truncate table concept_synonym_stage
;
--take the synonyms from the UMLS and Michael's file
with cui_to_code as (
select cui, replace (string_agg  (code, '-' order by code), 'C', 'NCITC')  as concept_code
 from nci_drb_syn
group by cui
)
,
cui_to_name as (
select cui,  str as concept_name
 from nci_drb_syn 
)
insert into concept_synonym_stage
select 
null::int, concept_name,  concept_code, 'OMOP Invest Drug', 4180186 -- English language
 from cui_to_code 
join cui_to_name using (cui)
where length (concept_code) <= 50 and (concept_code, lower (concept_name)) not in (
select concept_code, lower (concept_name) from concept_stage)
;
--3. concept_relationship_stage
truncate table concept_relationship_stage
;
--3.1 add the mappings to RxNorm
--to do: to add RxE to the mapping approach
insert into concept_relationship_stage
select * from (
select null::int, null::int,  replace (string_agg  (code, '-' order by code), 'C', 'NCITC') as concept_code_1, rx_code as concept_code_2, 'OMOP Invest Drug', vocabulary_id_2, 'Maps to',  to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null
 from nci_drb_rxn 
where rx_code is not null
group by rx_code, vocabulary_id_2
) a where length (a.concept_code_1 ) <= 50
;

--3.2 add the mappings to RxE
insert into concept_relationship_stage
select  null::int, null::int, a.concept_code, 
'OMOP' || NEXTVAL('omop_seq')  as concept_code_2 ,
'OMOP Invest Drug','RxNorm Extension', 'Maps to',  to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null
 from concept_stage a 
 --don't have mapping to RxNorm(E)
left join concept_relationship_stage r on a.concept_code = r.concept_code_1 and relationship_id ='Maps to'
--RxE concepts shouldn't be created out of parent concepts 
left join sources.genomic_nci_thesaurus b on substring (a.concept_code, 'C\d+') = b.parents
where r.concept_code_1 is null and b.parents is null
;
--3.3 add these RxE concepts to the concept_stage table
--somehow got a lot of duplicates here
insert into concept_stage
select 
null::int, a.concept_name, 'Drug', 'RxNorm Extension', 'Ingredient', 'S',  r.concept_code_2, to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null
 from concept_stage a 
join concept_relationship_stage r on a.concept_code = r.concept_code_1 and relationship_id ='Maps to'
--and RxNorm extension concept shouldn't exist already as a part of a routine RxE build
left join concept c on c.concept_code = r.concept_code_2 and c.vocabulary_id = 'RxNorm Extension'
where r.vocabulary_id_2 = 'RxNorm Extension' 
-- to do -- to add the way to distinguish from the real RxE
;
--4. hierarchy
--4.1 build hierarchical relationships to the ATC 'L01' concept using the ncit_antineopl 
insert into concept_relationship_stage
select distinct null::int, null::int, a.concept_code_2,'L01' ,'RxNorm Extension', 'ATC', 'Is a', to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null from concept_relationship_stage a
join ncit_antineopl b on substring (a.concept_code_1, 'C\d+') = b.code --NCI code
where a.vocabulary_id_2 ='RxNorm Extension' and relationship_id ='Maps to' -- Investigational drugs mapped to RxE we have to build the hiearchy for
;
--4.2  build hierarchical relationships to the HemOnc '46112' (Antineoplastics by class effect) concept using the ncit_antineopl 
insert into concept_relationship_stage
select distinct null::int, null::int, a.concept_code_2,'46112' ,'RxNorm Extension', 'HemOnc', 'Is a', to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null from concept_relationship_stage a
join ncit_antineopl b on substring (a.concept_code_1, 'C\d+') = b.code --NCI code
where a.vocabulary_id_2 ='RxNorm Extension' and relationship_id ='Maps to' -- Investigational drugs mapped to RxE we have to build the hiearchy for
;
--4.3 built internal hierarchy given by NCIt
insert into concept_relationship_stage
select distinct null::int, null::int, c.concept_code, a.concept_code ,c.vocabulary_id, a.vocabulary_id, 'Is a', to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null 
from concept_stage a
join sources.genomic_nci_thesaurus b on substring (a.concept_code, 'C\d+') = b.parents
join concept_stage c on substring (c.concept_code, 'C\d+') = b.code
;

