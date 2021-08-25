CREATE OR REPLACE FUNCTION devv5.MoveToDevV5()
RETURNS void AS
$BODY$
/*
 Moving contents of stage-tables to the devv5
 1. Run SetLatestUpdate (...)
 2. Run devv5.MoveToDevV5, e.g.
 DO $_$
 BEGIN
   PERFORM devv5.MoveToDevV5();
 END $_$;
 3. Run get_checks: select * from qa_tests.get_checks();
*/
DECLARE
	z int2;
	cSchemaName VARCHAR(100);
BEGIN

	SELECT COUNT(*)
	INTO z
	FROM information_schema.columns
	WHERE table_schema=CURRENT_SCHEMA() AND table_name='vocabulary' AND column_name='dev_schema_name';

	IF z = 0 THEN
		RAISE EXCEPTION 'No dev_schema found. Forgot to execute SetLatestUpdate?';
	END IF;

	SELECT LOWER(MAX(dev_schema_name)), COUNT(DISTINCT dev_schema_name)
	INTO cSchemaName, z
	FROM vocabulary WHERE latest_update IS NOT NULL;

	IF z > 1 THEN
		RAISE EXCEPTION 'More than one dev_schema found';
	END IF;

	--Truncate all working tables
	TRUNCATE devv5.concept_stage, devv5.concept_relationship_stage, devv5.concept_synonym_stage, devv5.pack_content_stage, devv5.drug_strength_stage, devv5.concept_relationship_manual;

	--Filling
	EXECUTE 'INSERT INTO devv5.concept_relationship_manual SELECT * FROM ' || cSchemaName || '.concept_relationship_manual';
	EXECUTE 'INSERT INTO devv5.concept_stage SELECT * FROM ' || cSchemaName || '.concept_stage';
	EXECUTE 'INSERT INTO devv5.concept_relationship_stage SELECT * FROM ' || cSchemaName || '.concept_relationship_stage';
	EXECUTE 'INSERT INTO devv5.concept_synonym_stage SELECT * FROM ' || cSchemaName || '.concept_synonym_stage';
	EXECUTE 'INSERT INTO devv5.pack_content_stage SELECT * FROM ' || cSchemaName || '.pack_content_stage';
	EXECUTE 'INSERT INTO devv5.drug_strength_stage SELECT * FROM ' || cSchemaName || '.drug_strength_stage';

	--Execute generic_update and clearing crm
	PERFORM devv5.GenericUpdate();
	TRUNCATE devv5.concept_relationship_manual;
END;
$BODY$
LANGUAGE 'plpgsql'
SECURITY INVOKER
SET client_min_messages = error;