--1 basic tables integrity checks (should return NULL)
select * from QA_TESTS.GET_CHECKS();

--the queries below return counts of differently changed concepts, relationships or ancestor rows, you need to interpret these results for each case individually

--2. get_summary - changes in tables between dev-schema (current) and devv5/prodv5/any other schema
--supported tables: concept, concept_relationship, concept_ancestor

--2.1. summary (table to check, schema to compare)
select * from qa_tests.get_summary (table_name=>'concept',pCompareWith=>'devv5');

--2.2. summary (table to check, schema to compare)
select * from qa_tests.get_summary (table_name=>'concept_relationship',pCompareWith=>'devv5');

--2.3. summary (table to check, schema to compare) 
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
