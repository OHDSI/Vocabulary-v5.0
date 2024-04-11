CREATE OR REPLACE FUNCTION vocabulary_pack.MergeTables (pTables TEXT[])
RETURNS TEXT AS
$BODY$
	/*
	The function creates a dynamic query (union all) to join tables with different structures (by field name), see more EVOC-1824
	NOTE: schema specification is REQUIRED even if the table is in the local schema

	Example:
	SELECT * FROM vocabulary_pack.MergeTables(ARRAY ['dev_iqvia.iqvia_us_emr_stcm','dev_bi.bi_mdv_custom_mapping']);
	*/
DECLARE
	iAllColumns TEXT[];
	iTableName TEXT;
	iSQL TEXT;
	iOutputSQL TEXT;
BEGIN
	SELECT ARRAY_AGG(DISTINCT c.column_name ORDER BY c.column_name)
	INTO iAllColumns
	FROM information_schema.columns c
	WHERE (c.table_schema || '.' || c.table_name) ILIKE ANY (pTables);

	FOREACH iTableName IN ARRAY pTables LOOP
		IF STRPOS(iTableName, '.')=0 THEN
			RAISE EXCEPTION 'Schema specification is required!';
		END IF;

		iTableName=LOWER(iTableName);
		
		PERFORM FROM information_schema.columns c WHERE (c.table_schema || '.' || c.table_name) = iTableName;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'Table % not found', iTableName;
		END IF;

		EXECUTE FORMAT ($$
		WITH cols
		AS (
			SELECT *
			FROM UNNEST(%1$L::TEXT[]) WITH ORDINALITY AS x(column_name, id)
			)
		SELECT 'SELECT ' || STRING_AGG(COALESCE(c.column_name, 'NULL AS ' || cols.column_name), ', ' ORDER BY cols.id) || ' FROM ' || %2$L
		FROM cols
		LEFT JOIN information_schema.columns c ON c.column_name = cols.column_name
			AND (c.table_schema || '.' || c.table_name) = %2$L
		$$, iAllColumns, iTableName)
		INTO iSQL;

		iOutputSQL:=CONCAT(iOutputSQL,iSQL,' UNION ALL ');
	END LOOP;

	RETURN LEFT(iOutputSQL,-11);
END;
$BODY$
LANGUAGE 'plpgsql' STABLE;