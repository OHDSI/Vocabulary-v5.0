--- 1. Step
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>FALSE, include_deprecated_rels=>TRUE, include_synonyms=>TRUE);
select * from devv5.qa_ddl();
SELECT * FROM qa_tests.check_stage_tables ();

---- 2. Step
---- update_manual_tables.sql
---- load_input.sql
---- load_stage.sql

---- 3. Step
SELECT admin_pack.VirtualLogIn(:login, :password);
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;
select * from QA_TESTS.GET_CHECKS();

---- 4. Step
---- class_to_drug.sql

---- 5. Step
DO $_$
BEGIN
	PERFORM dev_atc.pConceptAncestor();
END $_$;