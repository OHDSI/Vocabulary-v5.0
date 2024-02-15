CREATE OR REPLACE FUNCTION devv5.MoveToDevV5()
RETURNS VOID AS
$BODY$
	/*
	 Moving contents of stage-tables to the devv5
	 1. Log in under devv5
	 2. Run SetLatestUpdate (...)
	 3. Run devv5.MoveToDevV5, e.g.
	 DO $_$
	 BEGIN
	   PERFORM devv5.MoveToDevV5();
	 END $_$;
	 4. Run get_checks as always: SELECT * FROM qa_tests.get_checks();
	*/
DECLARE
	z INT8;
	iSchemaName TEXT;
BEGIN
	IF SESSION_USER <> 'devv5' THEN
		RAISE EXCEPTION 'This script can only be run in devv5';
	END IF;

	PERFORM FROM information_schema.columns c
	WHERE c.table_schema = SESSION_USER
		AND c.table_name = 'vocabulary'
		AND c.column_name = 'dev_schema_name';

	IF NOT FOUND THEN
		RAISE EXCEPTION 'No dev_schema found. Forgot to execute SetLatestUpdate?';
	END IF;

	SELECT LOWER(MAX(v.dev_schema_name)),
		COUNT(DISTINCT v.dev_schema_name)
	INTO iSchemaName,
		z
	FROM vocabulary v
	WHERE v.latest_update IS NOT NULL;

	IF z > 1 THEN
		RAISE EXCEPTION 'More than one dev_schema found';
	END IF;

	TRUNCATE concept_stage, concept_relationship_stage, concept_synonym_stage, pack_content_stage, drug_strength_stage, concept_relationship_manual, concept_manual, concept_synonym_manual;

	--Fill from dev_schema
	EXECUTE FORMAT ($$
		INSERT INTO concept_relationship_manual
		SELECT crm.*
		FROM %1$I.concept_relationship_manual crm
		JOIN vocabulary v1 ON v1.vocabulary_id = crm.vocabulary_id_1
		JOIN vocabulary v2 ON v2.vocabulary_id = crm.vocabulary_id_2
		WHERE COALESCE(v1.latest_update, v2.latest_update) IS NOT NULL;

		INSERT INTO concept_manual
		SELECT cm.*
		FROM %1$I.concept_manual cm
		JOIN vocabulary v ON v.vocabulary_id = cm.vocabulary_id
		WHERE v.latest_update IS NOT NULL;

		INSERT INTO concept_synonym_manual
		SELECT csm.*
		FROM %1$I.concept_synonym_manual csm
		JOIN vocabulary v ON v.vocabulary_id = csm.synonym_vocabulary_id
		WHERE v.latest_update IS NOT NULL;

		INSERT INTO concept_stage TABLE %1$I.concept_stage;
		INSERT INTO concept_relationship_stage TABLE %1$I.concept_relationship_stage;
		INSERT INTO concept_synonym_stage TABLE %1$I.concept_synonym_stage;
		INSERT INTO pack_content_stage TABLE %1$I.pack_content_stage;
		INSERT INTO drug_strength_stage TABLE %1$I.drug_strength_stage;
	$$, iSchemaName);

	ANALYZE concept_stage, concept_relationship_stage, concept_synonym_stage, pack_content_stage, drug_strength_stage, concept_relationship_manual, concept_manual, concept_synonym_manual;

	PERFORM GenericUpdate();
	TRUNCATE concept_relationship_manual, concept_manual, concept_synonym_manual;
END;
$BODY$
LANGUAGE 'plpgsql';