CREATE OR REPLACE FUNCTION audit.GetLogByID (iConceptID INT4 DEFAULT NULL, iTransactionID INT4 DEFAULT NULL)
RETURNS TABLE (
	log_id INT4,
	table_name TEXT,
	tx_time TIMESTAMPTZ,
	op_time TIMESTAMPTZ,
	tg_operation TEXT,
	tg_result TEXT,
	script_name TEXT,
	tx_id INT4
) AS
$BODY$
	SELECT a.log_id,
		a.table_name,
		a.tx_time,
		a.op_time,
		CASE a.tg_operation
			WHEN 'I'
				THEN 'INSERT'
			WHEN 'D'
				THEN 'DELETE'
			WHEN 'U'
				THEN 'UPDATE'
			WHEN 'T'
				THEN 'TRUNCATE'
			END tg_operation,
		CASE a.tg_operation
			WHEN 'I'
				THEN a.new_row::TEXT
			WHEN 'D'
				THEN a.old_row::TEXT
			WHEN 'U'
				THEN CONCAT(l1.upd_diff,l2.row_id)
			END tg_result,
		COALESCE(a.script_name, '[Manual]: ' || a.query) script_name,
		a.tx_id
	FROM audit.logged_actions a
	--get difference for UPDATE
	CROSS JOIN LATERAL(
		SELECT STRING_AGG(oldrow.key || '=' || QUOTE_NULLABLE(oldrow.value) || ' -> ' || QUOTE_NULLABLE(newrow.value), '; ') upd_diff
		FROM (SELECT * FROM jsonb_each_text(a.old_row)) oldrow
		JOIN (SELECT * FROM jsonb_each_text(a.new_row)) newrow USING (key)
			WHERE oldrow.value IS DISTINCT FROM newrow.value
			AND a.tg_operation = 'U'
		) l1
	--get concept_ids/vocabulary_name
	CROSS JOIN LATERAL(
		SELECT ' [' || STRING_AGG(newrow.key || '=' || newrow.value, '; ') || ']' row_id
		FROM jsonb_each_text(a.new_row) newrow
			WHERE (
				(
					(newrow.key LIKE '%concept_id%' AND a.table_name <> 'vocabulary')
					OR
					(newrow.key = 'vocabulary_id' AND a.table_name = 'vocabulary') --get vocabulary_id instead of vocabulary_concept_id for better readability
				)
				OR newrow.key = 'vocabulary_id_v5' --'vocabulary_conversion' doesn't have a concept_id field
				)
			AND newrow.key <> 'language_concept_id' --exclude this field if 'concept_synonym'
			AND a.tg_operation = 'U'
		) l2
	WHERE iConceptID IN (
			(a.old_row ->> 'concept_id')::INT4,
			(a.new_row ->> 'concept_id')::INT4,
			(a.old_row ->> 'concept_id_1')::INT4,
			(a.new_row ->> 'concept_id_1')::INT4,
			(a.old_row ->> 'relationship_concept_id')::INT4,
			(a.new_row ->> 'relationship_concept_id')::INT4,
			(a.old_row ->> 'vocabulary_concept_id')::INT4,
			(a.new_row ->> 'vocabulary_concept_id')::INT4,
			(a.old_row ->> 'concept_class_concept_id')::INT4,
			(a.new_row ->> 'concept_class_concept_id')::INT4,
			(a.old_row ->> 'domain_concept_id')::INT4,
			(a.new_row ->> 'domain_concept_id')::INT4,
			(a.old_row ->> 'drug_concept_id')::INT4,
			(a.new_row ->> 'drug_concept_id')::INT4,
			(a.old_row ->> 'pack_concept_id')::INT4,
			(a.new_row ->> 'pack_concept_id')::INT4
			)
		OR a.tx_id = iTransactionID;
$BODY$ LANGUAGE 'sql' IMMUTABLE;