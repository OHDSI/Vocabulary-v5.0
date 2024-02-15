CREATE OR REPLACE FUNCTION vocabulary_pack.ProcessManualRelationships ()
RETURNS VOID AS
$BODY$
	/*
	Inserts a manual relationships from concept_relationship_manual into the concept_relationship_stage
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
		TRUNCATE TABLE concept_relationship_manual;
		EXECUTE FORMAT ($$
			INSERT INTO concept_relationship_manual
			SELECT crm.*
			FROM %I.concept_relationship_manual crm
			JOIN vocabulary v1 ON v1.vocabulary_id = crm.vocabulary_id_1
			JOIN vocabulary v2 ON v2.vocabulary_id = crm.vocabulary_id_2
			WHERE COALESCE(v1.latest_update, v2.latest_update) IS NOT NULL
		$$, iSchemaName);
	END IF;

	--checking concept_relationship_manual for errors
	PERFORM vocabulary_pack.CheckManualRelationships();

	--add new records, update existing
	INSERT INTO concept_relationship_stage AS crs (
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
		)
	SELECT crm.*
	FROM concept_relationship_manual crm
	JOIN vocabulary v1 ON v1.vocabulary_id = crm.vocabulary_id_1
	JOIN vocabulary v2 ON v2.vocabulary_id = crm.vocabulary_id_2
	WHERE COALESCE(v1.latest_update, v2.latest_update) IS NOT NULL
	ON CONFLICT ON CONSTRAINT idx_pk_crs
	DO UPDATE
	SET valid_start_date = excluded.valid_start_date,
		valid_end_date = excluded.valid_end_date,
		invalid_reason = excluded.invalid_reason
	WHERE ROW (crs.valid_start_date, crs.valid_end_date, crs.invalid_reason)
	IS DISTINCT FROM
	ROW (excluded.valid_start_date, excluded.valid_end_date, excluded.invalid_reason);

END;
$BODY$
LANGUAGE 'plpgsql';