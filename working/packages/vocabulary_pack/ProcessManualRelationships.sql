CREATE OR REPLACE FUNCTION vocabulary_pack.ProcessManualRelationships ()
RETURNS void AS
$BODY$
/*
 Inserts a manual relationships from concept_relationship_manual into the concept_relationship_stage
*/
DECLARE
	z int4;
	cSchemaName VARCHAR(100);
BEGIN
	--Checking table concept_relationship_manual for errors
	IF CURRENT_SCHEMA <> 'devv5' THEN
		PERFORM vocabulary_pack.CheckManualRelationships();
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
			AND pg_t.tablename = 'concept_relationship_manual';

		IF z = 0 THEN
			RAISE EXCEPTION 'ProcessManualRelationships: % not found', cSchemaName || '.concept_relationship_manual';
		END IF;

		TRUNCATE TABLE concept_relationship_manual;
		EXECUTE 'INSERT INTO concept_relationship_manual SELECT * FROM ' || cSchemaName || '.concept_relationship_manual';

		PERFORM vocabulary_pack.CheckManualRelationships();
	END IF;

	--add new records
	INSERT INTO concept_relationship_stage (
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
		)
	SELECT *
	FROM concept_relationship_manual crm
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_relationship_stage crs_int
			WHERE crs_int.concept_code_1 = crm.concept_code_1
				AND crs_int.concept_code_2 = crm.concept_code_2
				AND crs_int.vocabulary_id_1 = crm.vocabulary_id_1
				AND crs_int.vocabulary_id_2 = crm.vocabulary_id_2
				AND crs_int.relationship_id = crm.relationship_id
			);

	--update existing
	UPDATE concept_relationship_stage crs
	SET valid_start_date = crm.valid_start_date,
		valid_end_date = crm.valid_end_date,
		invalid_reason = crm.invalid_reason
	FROM concept_relationship_manual crm
	WHERE crs.concept_code_1 = crm.concept_code_1
		AND crs.concept_code_2 = crm.concept_code_2
		AND crs.vocabulary_id_1 = crm.vocabulary_id_1
		AND crs.vocabulary_id_2 = crm.vocabulary_id_2
		AND crs.relationship_id = crm.relationship_id
		AND (
			crs.valid_start_date <> crm.valid_start_date
			OR crs.valid_end_date <> crm.valid_end_date
			OR COALESCE(crs.invalid_reason, 'X') <> COALESCE(crm.invalid_reason, 'X')
			);
END;
$BODY$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER;