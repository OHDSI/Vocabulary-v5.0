/*
select devv5.fastrecreateschema()
--;
--new vocabulary
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'OMOP Invest Drug',
	pVocabulary_name		=> 'OMOP Investigational Drugs',
	pVocabulary_reference	=> 'https://go.drugbank.com/drugs, https://evs.nci.nih.gov/ftp1/NCI_Thesaurus/Drug_or_Substance/Antineoplastic_Agent.txt',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;
*/
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
--to do: to add RxE to the mapping approach
insert into concept_relationship_stage
select distinct null::int, null::int, concept_code, concept_code_2, 'OMOP Invest Drug', vocabulary_id_2, 'Maps to', to_date ('20220208', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null
 from inv_master where length (concept_code) <= 50
 and concept_code_2 is not null
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
left join inv_master m on m.concept_code = a.concept_code and m.parent_code is not null
where m.concept_code is null
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
select distinct null::int, null::int, a.concept_code_2,'L01' ,'RxNorm Extension', 'ATC', 'Is a', to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null from concept_relationship_stage a
join inv_master m on a.concept_code_1 = m.concept_code and m.antineopl_code is not null --NCI code
where a.vocabulary_id_2 ='RxNorm Extension' and relationship_id ='Maps to' -- Investigational drugs mapped to RxE we have to build the hiearchy for
;
--4.3 built internal hierarchy given by NCIt
insert into concept_relationship_stage
select distinct null::int, null::int, c.concept_code, a.concept_code ,c.vocabulary_id, a.vocabulary_id, 'Is a', to_date ('19700101', 'yyyyMMdd'), to_date ('20991231', 'yyyyMMdd'), null 
from concept_stage a
join inv_master m1 on a.concept_code = m1.concept_code
join inv_master m2 on m1.parent_code = m2.code
join concept_stage c on c.concept_code = m2.concept_code
;
select devv5.genericupdate()
;
--1 basic tables integrity checks (should return NULL)
select * from QA_TESTS.GET_CHECKS();

--the queries below return counts of differently changed concepts, relationships or ancestor rows, you need to interpret these results for each case individually

--2. get_summary - changes in tables between dev-schema (current) and devv5/prodv5/any other schema
--supported tables: concept, concept_relationship, concept_ancestor

--2.1. first clean cache
select * from qa_tests.purge_cache();

--2.2. summary (table to check, schema to compare)
select * from qa_tests.get_summary (table_name=>'concept',pCompareWith=>'devv5');

--2.3. summary (table to check, schema to compare)
select * from qa_tests.get_summary (table_name=>'concept_relationship',pCompareWith=>'devv5');

--2.4. summary (table to check, schema to compare) 
/* run only in cases when ancestor was included in fast recreate and manual concept_ancestor was run
select * from qa_tests.get_summary (table_name=>'concept_ancestor',pCompareWith=>'devv5');
*/

--3. Statistics QA checks
--changes in tables between dev-schema (current) and devv5/prodv5/any other schema (set pCompareWith = 'prodv5 or to source dev schema if you run these queries in devv5)

--3.1. Domain changes
select * from qa_tests.get_domain_changes(pCompareWith=>'devv5');

--3.2. Newly added concepts grouped by vocabulary_id and domain
select * from qa_tests.get_newly_concepts(pCompareWith=>'devv5');

--3.3. Standard concept changes
select * from qa_tests.get_standard_concept_changes(pCompareWith=>'devv5');

--3.4. Newly added concepts and their standard concept status
select * from qa_tests.get_newly_concepts_standard_concept_status(pCompareWith=>'devv5');

--3.5. Changes of concept mapping status grouped by target domain
select * from qa_tests.get_changes_concept_mapping(pCompareWith=>'devv5');
