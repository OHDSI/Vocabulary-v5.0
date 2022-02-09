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

--get latest update
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=>'OMOP Invest Drug',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'OMOP Invest Drug '||TO_CHAR(CURRENT_DATE,'YYYYMMDD'),
	pVocabularyDevSchema	=> 'DEV_invdrug'
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'RxNorm Extension',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'RxNorm Extension '||CURRENT_DATE,
	pVocabularyDevSchema	=> 'DEV_DMD',
	pAppendVocabulary		=> TRUE
);
END $_$;

-- Create sequence that starts after existing OMOPxxx-style concept codes
	DO $$
	DECLARE
		ex INTEGER;
	BEGIN
		SELECT MAX(REPLACE(concept_code, 'OMOP','')::int4)+1 INTO ex FROM (
			SELECT concept_code FROM concept WHERE concept_code LIKE 'OMOP%'  AND concept_code NOT LIKE '% %' -- Last valid value of the OMOP123-type codes
		) AS s0;
		DROP SEQUENCE IF EXISTS omop_seq;
		EXECUTE 'CREATE SEQUENCE omop_seq INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
	END$$;
	
--1. fill the concept stage
truncate table concept_stage
;
--1.1  let drugbank be a primary name since it should have a better coverage, it has not only antineoplastics as NCIt
insert into concept_stage
select distinct
null::int, first_value (str) over (partition by concept_code order by sab, str) as concept_name, 'Drug', 'OMOP Invest Drug', 'Ingredient', null,  concept_code, to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null
 from (select distinct trim (str) as str, sab, concept_code from inv_master) a
 where length (a.concept_code ) <= 50
;
--2. concept_synonym_stage
truncate table concept_synonym_stage
;
--take the synonyms from inv_master
insert into concept_synonym_stage
select distinct
null::int, trim (synonym_name),  concept_code, 'OMOP Invest Drug', 4180186 -- English language
 from inv_master 
where length (concept_code) <= 50 
--doesn't make sense to create a separate synonym entity if it differs by registry only
and (concept_code, lower (synonym_name)) not in (
select concept_code, lower (concept_name) from concept_stage)
;
--3. concept_relationship_stage
truncate table concept_relationship_stage
;
--3.1 add the mappings to RxNorm or RxE
insert into concept_relationship_stage
select distinct null::int, null::int, concept_code, concept_code_2, 'OMOP Invest Drug', vocabulary_id_2, 'Maps to', to_date ('20220208', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null
 from inv_master where length (concept_code) <= 50
 and concept_code_2 is not null
;
--3.2 add the mappings to RxE
insert into concept_relationship_stage
select distinct null::int, null::int, a.concept_code, 
'OMOP' || NEXTVAL('omop_seq')  as concept_code_2 ,
'OMOP Invest Drug','RxNorm Extension', 'Maps to',  to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null
 from concept_stage a 
 --don't have mapping to RxNorm(E)
left join concept_relationship_stage r on a.concept_code = r.concept_code_1 and relationship_id ='Maps to'
--RxE concepts shouldn't be created out of parent concepts 
join inv_master m on m.concept_code = a.concept_code 
left join inv_master m2 on m.code = m2.parent_code
where m2.concept_code is null
and r.concept_code_1 is null
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
and c.concept_code is null
;
--4. hierarchy
--4.1 build hierarchical relationships from new RxEs to the ATC 'L01' concept using the ncit_antineopl 
insert into concept_relationship_stage
select distinct null::int, null::int, a.concept_code_2,'L01' ,'RxNorm Extension', 'ATC', 'Is a', to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null
 from concept_relationship_stage a
join inv_master m on a.concept_code_1 = m.concept_code and m.antineopl_code is not null --NCI code
where a.vocabulary_id_2 ='RxNorm Extension' and relationship_id ='Maps to' -- Investigational drugs mapped to RxE we have to build the hiearchy for
;
--4.3 built internal hierarchy given by NCIt
insert into concept_relationship_stage
select distinct null::int, null::int, a.concept_code, c.concept_code ,a.vocabulary_id, c.vocabulary_id, 'Is a', to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null 
from concept_stage a
join inv_master m1 on a.concept_code = m1.concept_code
join inv_master m2 on m1.parent_code = m2.code
join concept_stage c on c.concept_code = m2.concept_code
;
