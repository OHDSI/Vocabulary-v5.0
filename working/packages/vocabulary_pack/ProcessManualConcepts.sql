CREATE OR REPLACE FUNCTION vocabulary_pack.ProcessManualConcepts ()
RETURNS VOID AS
$BODY$
	/*
	Inserts a manual concepts from concept_manual into the concept_stage
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
		TRUNCATE TABLE concept_manual;
		EXECUTE FORMAT ($$
			INSERT INTO concept_manual
			SELECT *
			FROM %I.concept_manual
		$$, iSchemaName);
	END IF;

	--checking concept_manual for errors
	PERFORM vocabulary_pack.CheckManualConcepts();
	
	/*does not work, because the NOT NULL constraint is checked before checking for conflicts https://postgrespro.com/list/thread-id/2518470
	--add new records, update existing
	INSERT INTO concept_stage AS cs (
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
	SELECT cm.*
	FROM concept_manual cm
	JOIN vocabulary v ON v.vocabulary_id = cm.vocabulary_id
	WHERE v.latest_update IS NOT NULL
	ON CONFLICT ON CONSTRAINT idx_pk_cs
	DO UPDATE
	SET concept_name = COALESCE(excluded.concept_name, cs.concept_name),
		domain_id = COALESCE(excluded.domain_id, cs.domain_id),
		concept_class_id = COALESCE(excluded.concept_class_id, cs.concept_class_id),
		standard_concept = CASE
			WHEN excluded.standard_concept = 'X' --don't change the original standard_concept if standard_concept in the cm is 'X'
				THEN cs.standard_concept
			ELSE excluded.standard_concept
			END,
		valid_start_date = COALESCE(excluded.valid_start_date, cs.valid_start_date),
		valid_end_date = COALESCE(excluded.valid_end_date, cs.valid_end_date),
		invalid_reason = CASE 
			WHEN excluded.invalid_reason = 'X' --don't change the original invalid_reason if invalid_reason in the cm is 'X'
				THEN cs.invalid_reason
			ELSE excluded.invalid_reason
			END
	WHERE ROW (cs.concept_name, cs.domain_id, cs.concept_class_id, cs.standard_concept, cs.valid_start_date, cs.valid_end_date, cs.invalid_reason)
	IS DISTINCT FROM
	ROW (excluded.concept_name, excluded.domain_id, excluded.concept_class_id, excluded.standard_concept, excluded.valid_start_date, excluded.valid_end_date, excluded.invalid_reason);
	*/
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
	JOIN vocabulary v ON v.vocabulary_id = cm.vocabulary_id
	WHERE v.latest_update IS NOT NULL
		AND cm.concept_code = cs.concept_code
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
	SELECT cm.*
	FROM concept_manual cm
	JOIN vocabulary v ON v.vocabulary_id = cm.vocabulary_id
	WHERE v.latest_update IS NOT NULL
		AND NOT EXISTS (
				SELECT 1
				FROM concept_stage cs_int
				WHERE cs_int.concept_code = cm.concept_code
					AND cs_int.vocabulary_id = cm.vocabulary_id
				);
END;
$BODY$
LANGUAGE 'plpgsql';