CREATE OR REPLACE FUNCTION audit.GetLogSummary ()
RETURNS TABLE (
	log_id INT4,
	tx_time TIMESTAMPTZ,
	script_name TEXT,
	affected_vocabs TEXT,
	tx_id INT4
) AS
$BODY$
	SELECT MIN(log_id) log_id,
		tx_time,
		script_name,
		string_agg(affected_vocabs, ', ' ORDER BY affected_vocabs) || ' [' || UPPER(dev_schema_name) || ']' affected_vocabs,
		MIN(tx_id) tx_id
	FROM (
		SELECT s1.tx_time,
			s1.statement_time,
			s1.script_name,
			s1.tx_id,
			s1.log_id,
			s1.affected_vocabs,
			s1.dev_schema_name,
			SUM(s1.breakfield) OVER (
				ORDER BY s1.log_id
				) virtual_group
		FROM (
			SELECT s0.tx_time,
				s0.statement_time,
				s0.script_name,
				s0.tx_id,
				s0.log_id,
				s0.affected_vocabs,
				s0.dev_schema_name,
				CASE 
					WHEN (s0.prev_script_name IS DISTINCT FROM s0.script_name) OR s0.prev_tx_id <> s0.tx_id OR s0.breakfield_setlatestupdate
						THEN 1
					ELSE 0
					END breakfield
			FROM (
				SELECT log_id,
					tx_id,
					tx_time,
					statement_time,
					script_name,
					CASE 
						WHEN t.new_row ? 'dev_schema_name'
							THEN (t.new_row ->> 'vocabulary_id')
						END affected_vocabs,
					(t.new_row ->> 'dev_schema_name') dev_schema_name,
					LAG(t.script_name) OVER (
						ORDER BY t.log_id
						) prev_script_name,
					LAG(t.tx_id) OVER (
						ORDER BY t.log_id
						) prev_tx_id,
					(
						t.new_row ? 'dev_schema_name'
						AND (t.new_row ->> 'dev_schema_name') IS NULL
						) breakfield_setlatestupdate
				FROM (
					SELECT log_id,
						tx_time,
						statement_time,
						new_row,
						COALESCE(script_name, '[Manual]: ' || query) script_name,
						tx_id
					FROM audit.logged_actions
					) t
				) s0
			) s1
		) s2
	WHERE NOT (
			affected_vocabs IS NOT NULL
			AND dev_schema_name IS NULL
			)
	GROUP BY tx_time,
		script_name,
		statement_time,
		dev_schema_name,
		virtual_group;
$BODY$ LANGUAGE 'sql' STABLE;