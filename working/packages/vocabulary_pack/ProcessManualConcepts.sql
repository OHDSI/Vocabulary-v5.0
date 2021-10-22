CREATE OR REPLACE FUNCTION vocabulary_pack.ProcessManualConcepts ()
RETURNS void AS
$BODY$
/*
 Inserts a manual concepts from concept_manual into the concept_stage
*/
DECLARE
	z int4;
	cSchemaName VARCHAR(100);
BEGIN
	--checking table concept_manual for errors
	IF CURRENT_SCHEMA <> 'devv5' THEN
		PERFORM vocabulary_pack.CheckManualConcepts();
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
			AND pg_t.tablename = 'concept_manual';

		IF z = 0 THEN
			RAISE EXCEPTION '% not found', cSchemaName || '.concept_manual';
		END IF;

		TRUNCATE TABLE concept_manual;
		EXECUTE 'INSERT INTO concept_manual SELECT * FROM ' || cSchemaName || '.concept_manual';

		PERFORM vocabulary_pack.CheckManualConcepts();
	END IF;

	--update existing records
	UPDATE concept_stage cs
	SET concept_name = COALESCE(cm.concept_name, cs.concept_name),
		domain_id = COALESCE(cm.domain_id, cs.domain_id),
		concept_class_id = COALESCE(cm.concept_class_id, cs.concept_class_id),
		standard_concept = CASE 
			WHEN cm.standard_concept = 'X' --don't change the original standard_concept if standard_concept in the cm is 'X'
				THEN cs.standard_concept
			ELSE cm.standard_concept
			END,
		valid_start_date = COALESCE(cm.valid_start_date, cs.valid_start_date),
		valid_end_date = COALESCE(cm.valid_end_date, cs.valid_end_date),
		invalid_reason = CASE 
			WHEN cm.invalid_reason = 'X' --don't change the original invalid_reason if invalid_reason in the cm is 'X'
				THEN cs.invalid_reason
			ELSE cm.invalid_reason
			END
	FROM concept_manual cm
	WHERE cm.concept_code = cs.concept_code
		AND cm.vocabulary_id = cs.vocabulary_id;

	--add new records
	INSERT INTO concept_stage (
		concept_name,
		domain_id,
		vocabulary_id,
		concept_class_id,
		standard_concept,
		concept_code,
		valid_start_date,
		valid_end_date,
		invalid_reason
		)
	SELECT concept_name,
		domain_id,
		vocabulary_id,
		concept_class_id,
		standard_concept,
		concept_code,
		valid_start_date,
		valid_end_date,
		invalid_reason
	FROM concept_manual cm
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_stage cs_int
			WHERE cs_int.concept_code = cm.concept_code
				AND cs_int.vocabulary_id = cm.vocabulary_id
			);
END;
$BODY$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER;