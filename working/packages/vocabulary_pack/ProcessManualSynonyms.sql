CREATE OR REPLACE FUNCTION vocabulary_pack.ProcessManualSynonyms ()
RETURNS void AS
$BODY$
/*
 Inserts a manual synonyms from concept_synonym_manual into the concept_synonym_stage
*/
DECLARE
	z int4;
	cSchemaName VARCHAR(100);
BEGIN
	--checking table concept_synonym_manual for errors
	IF CURRENT_SCHEMA <> 'devv5' THEN
		PERFORM vocabulary_pack.CheckManualSynonyms();
	END IF;

	SELECT LOWER(MAX(dev_schema_name)), COUNT(DISTINCT dev_schema_name)
	INTO cSchemaName, z
	FROM vocabulary
	WHERE latest_update IS NOT NULL;

	IF z > 1 THEN
		RAISE EXCEPTION 'more than one dev_schema found';
	END IF;

	IF CURRENT_SCHEMA = 'devv5' THEN
		SELECT COUNT(*) INTO z
		FROM pg_tables pg_t
		WHERE pg_t.schemaname = cSchemaName
			AND pg_t.tablename = 'concept_synonym_manual';

		IF z = 0 THEN
			RAISE EXCEPTION '% not found', cSchemaName || '.concept_synonym_manual';
		END IF;

		TRUNCATE TABLE concept_synonym_manual;
		EXECUTE 'INSERT INTO concept_synonym_manual SELECT * FROM ' || cSchemaName || '.concept_synonym_manual';

		PERFORM vocabulary_pack.CheckManualSynonyms();
	END IF;

	--add new records for synonyms
	INSERT INTO concept_synonym_stage (
		synonym_name,
		synonym_concept_code,
		synonym_vocabulary_id,
		language_concept_id
		)
	SELECT synonym_name,
		synonym_concept_code,
		synonym_vocabulary_id,
		language_concept_id
	FROM concept_synonym_manual;
END;
$BODY$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER;