CREATE OR REPLACE FUNCTION skype_pack.FormatTableData (pTEXT TEXT, pDelimiter TEXT DEFAULT E'\t', pCRLF TEXT DEFAULT E'\r\n')
RETURNS TEXT AS
$BODY$
	/*
	Skype doesn't support table formatting ({code} + TABs) properly, so this function forces the formatting to be whitespace and right aligned
	SELECT skype_pack.FormatTableData('Some text', E'\t', E'\r\n');
	*/
	WITH rows_parsing
	AS (
		SELECT *
		FROM REGEXP_SPLIT_TO_TABLE(pTEXT, pCRLF) WITH ORDINALITY AS i(row, row_id)
		),
	columns_parsing
	AS (
		SELECT s0.*,
			MAX(LENGTH(column_value)) OVER (PARTITION BY column_id) AS max_column_length
		FROM (
			SELECT l.row AS column_value,
				l.column_id,
				r.row_id
			FROM rows_parsing r
			CROSS JOIN LATERAL(SELECT * FROM REGEXP_SPLIT_TO_TABLE(r.row, pDelimiter) WITH ORDINALITY AS i(row, column_id)) l
			) s0
		),
	columns_aggregation
	AS (
		SELECT STRING_AGG(LPAD(column_value, max_column_length), '  ' ORDER BY column_id) AS row_value,
			row_id
		FROM columns_parsing
		GROUP BY row_id
		)
	--rows aggregation
	SELECT STRING_AGG(row_value, pCRLF ORDER BY row_id)
	FROM columns_aggregation;
$BODY$
LANGUAGE 'sql' IMMUTABLE
SET search_path = skype_pack, pg_temp;