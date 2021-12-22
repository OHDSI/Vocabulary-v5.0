--1. fill the concept stage
--1.1. those having the RxNorm equivalent get the RxNorm name (rx_str)
truncate table concept_stage
;
insert into concept_stage
select * from (
select null::int, rx_str, 'Drug', 'OMOP Invest Drug', 'Ingredient', null, replace (string_agg  (code, '-' order by code), 'C', 'NCITC') as concept_code, to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null
 from nci_drb_rxn 
where rx_str is not null
group by rx_str
) a where length (a.concept_code ) <= 50
;
--1.2 those that don't have RxNorm name, let's drugbank be a primary name since it should have a better coverage
with cui_to_code as (
select cui, replace (string_agg  (code, '-' order by code), 'C', 'NCITC')  as concept_code
 from nci_drb_rxn 
where rx_str is null
group by cui
)
,
cui_to_name as (
select distinct cui, first_value (str) over (partition by cui order by sab--Drugbank, then NCIt
, str) as concept_name
 from nci_drb_rxn 
where rx_str is null
)
insert into concept_stage
select 
null::int, concept_name, 'Drug', 'OMOP Invest Drug', 'Ingredient', null,  concept_code, to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null
 from cui_to_code 
join cui_to_name using (cui)
;
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
left join concept_relationship_stage r on a.concept_code = r.concept_code_1 and relationship_id ='Maps to'
where r.concept_code_1 is null
;
--3.3 add these RxE concepts to the concept_stage table
--somehow got a lot of duplicates here
insert into concept_stage
select 
null::int, a.concept_name, 'Drug', 'RxNorm Extension', 'Ingredient', 'S',  r.concept_code_2, to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null
 from concept_stage a 
join concept_relationship_stage r on a.concept_code = r.concept_code_1 and relationship_id ='Maps to'
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
