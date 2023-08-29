CREATE OR REPLACE FUNCTION vocabulary_pack.ProcessManualSynonyms ()
RETURNS VOID AS
$BODY$
	/*
	Inserts a manual synonyms from concept_synonym_manual into the concept_synonym_stage
	*/
DECLARE
	z INT4;
	iSchemaName TEXT;
BEGIN
	SELECT LOWER(MAX(v.dev_schema_name)), COUNT(DISTINCT v.dev_schema_name)
	INTO iSchemaName, z
	FROM vocabulary v
	WHERE v.latest_update IS NOT NULL;

	IF z>1 THEN
		RAISE EXCEPTION 'More than one dev_schema found';
	END IF;

	IF CURRENT_SCHEMA = 'devv5' THEN
		TRUNCATE TABLE concept_synonym_manual;
		EXECUTE FORMAT ($$
			INSERT INTO concept_synonym_manual
			SELECT csm.*
			FROM %I.concept_synonym_manual csm
			JOIN vocabulary v ON v.vocabulary_id = csm.synonym_vocabulary_id
			WHERE v.latest_update IS NOT NULL
		$$, iSchemaName);
	END IF;

	--checking concept_synonym_manual for errors
	PERFORM vocabulary_pack.CheckManualSynonyms();

	--add new records for synonyms
	INSERT INTO concept_synonym_stage (
		synonym_name,
		synonym_concept_code,
		synonym_vocabulary_id,
		language_concept_id
		)
	SELECT csm.*
	FROM concept_synonym_manual csm
	JOIN vocabulary v ON v.vocabulary_id = csm.synonym_vocabulary_id
	WHERE v.latest_update IS NOT NULL
	ON CONFLICT DO NOTHING;
END;
$BODY$
LANGUAGE 'plpgsql';