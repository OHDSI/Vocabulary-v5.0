select CURRENT_USER;
show search_path;


--01. Create_DEV_from_DevV5_DDL
--https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/Create_DEV_from_DevV5_DDL.sql



--02. Fast recreate
--Use this script to recreate main tables (concept, concept_relationship, concept_synonym etc) without dropping your schema
--devv5 - static variable;

--02.1. Recreate with default settings (copy from devv5, w/o ancestor, deprecated relationships and synonyms (faster)
--SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5');

--02.2. Same as above, but table concept_ancestor is included
--SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>true);

--02.3 Full recreate, all tables are included
--SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>true, include_deprecated_rels=>true, include_synonyms=>true);

--02.4 Full recreate, concept_ancestor is excluded
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>false, include_deprecated_rels=>true, include_synonyms=>true);

--02.5 Preserve old concept_ancestor, but it will be ignored if the include_concept_ancestor is set to true
--SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', drop_concept_ancestor=>false);



--03.
--PASTE the load_stage here



--04. SQL script checklist:
--1. Check non-English symbols in strings, especially 'с'
--2. Check in console that every query does something (otherwise, there will be 'completed in'/'0 rows' message)
--3. Check every IN () statement has WHERE IS NOT NULL limitation
--4. Confirm that every IN statement retrieve something
--5. OR statement inside AND statement



--05. schema DDL check
select * from devv5.qa_ddl();



--06. DRUG input tables checks
--06.1. Errors
--RUN https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/input_QA_integratable_E.sql --All queries should retrieve NULL

--06.2. Warnings
--RUN https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/input_QA_integratable_W.sql --All non-NULL results should be reviewed

--06.3. Old checks
--RUN all queries from Vocabulary-v5.0/working/drug_stage_tables_QA.sql --All queries should retrieve NULL
--RUN all queries from Vocabulary-v5.0/working/Drug_stage_QA_optional.sql --All queries should retrieve NULL, but see comment inside



--07. Stage tables checks (should retrieve NULL)
--07.1. check_stage_tables function
SELECT * FROM qa_tests.check_stage_tables ();

--07.2. New Vocabulary QA
--RUN all queries from Vocabulary-v5.0/working/CreateNewVocabulary_QA.sql --All queries should retrieve NULL

--07.3. Vocabulary-specific manual checks of the stage tables / load stage script can be found in the manual_work directory in each vocabulary, e.g. https://github.com/OHDSI/Vocabulary-v5.0/blob/master/SNOMED/manual_work/specific_qa/load_stage%20checks.sql


--08. GenericUpdate; devv5 - static variable
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;



--09. Basic tables checks

--09.1. QA checks (should retrieve NULL)
select * from QA_TESTS.GET_CHECKS();

--09.2. DRUG basic tables checks
--RUN all queries from Vocabulary-v5.working/Basic_tables_QA.sql --All queries should retrieve NULL when consider ONLY new concepts




--10. Manual checks after generic
--10.1. RUN and review the results: https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql

--10.2. Vocabulary-specific manual checks can be found in the manual_work directory in each vocabulary, e.g. https://github.com/OHDSI/Vocabulary-v5.0/blob/master/SNOMED/manual_work/specific_qa/manual_checks_after_generic.sql



--11. a) manual ConceptAncestor (needed vocabularies are to be specified)
/* DO $_$
 BEGIN
    PERFORM vocabulary_pack.pManualConceptAncestor(
    pVocabularies => 'SNOMED,LOINC'
 );
 END $_$;*/


--11. b) full ConceptAncestor
/*DO $_$
BEGIN
	PERFORM vocabulary_pack.pConceptAncestor();
END $_$;*/


--12. get_summary - changes in tables between dev-schema (current) and devv5/prodv5/any other schema
--supported tables: concept, concept_relationship, concept_ancestor

--12.1. summary (table to check, schema to compare)
select vocabulary_id_1,
       standard_concept,
       concept_class_id,
       invalid_reason,
       concept_delta,
       concept_delta_percentage
from qa_tests.get_summary (table_name=>'concept',pCompareWith=>'devv5');

--12.2. summary (table to check, schema to compare)
select vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       invalid_reason,
       concept_delta,
       concept_delta_percentage
from qa_tests.get_summary (table_name=>'concept_relationship',pCompareWith=>'devv5');

--12.3. summary (table to check, schema to compare)
--you would not need it normally because we run concept_ancestor constructor only on the release to Athena step
--select * from qa_tests.get_summary (table_name=>'concept_ancestor',pCompareWith=>'devv5');



--13. Statistics QA checks
--changes in tables between dev-schema (current) and devv5/prodv5/any other schema

--13.1. Domain changes
select * from qa_tests.get_domain_changes(pCompareWith=>'devv5');

--13.2. Newly added concepts grouped by vocabulary_id and domain
select * from qa_tests.get_newly_concepts(pCompareWith=>'devv5');

--13.3. Standard concept changes
select * from qa_tests.get_standard_concept_changes(pCompareWith=>'devv5');

--13.4. Newly added concepts and their standard concept status
select * from qa_tests.get_newly_concepts_standard_concept_status(pCompareWith=>'devv5');

--13.5. Changes of concept mapping status grouped by target domain
select * from qa_tests.get_changes_concept_mapping(pCompareWith=>'devv5');