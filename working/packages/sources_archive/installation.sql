--create a schema for archive
CREATE SCHEMA sources_archive AUTHORIZATION devv5;
ALTER DEFAULT PRIVILEGES FOR USER devv5 IN SCHEMA sources_archive GRANT SELECT ON TABLES TO role_read_only;
GRANT USAGE ON SCHEMA sources_archive TO role_read_only;

--create a table with conversion between vocabulary and its 'main' table with vocabulary_date and vocabulary_version fields
CREATE TABLE sources_archive.archive_conversion (
	vocabulary_id TEXT PRIMARY KEY,
	vocabulary_main_table TEXT, --the smallest table for ShowVocabularyDates function
	vocabulary_latest_date DATE, --the last version in archive
	vocabulary_parameter_name TEXT UNIQUE NOT NULL,
	vocabulary_active_tables TEXT[], --all tables in the vocabulary
	vocabulary_missing_tables TEXT[], --if the table has disappeared from the vocabulary, it is included in this list. this allows us to safely drop it from the archive later
	vocabulary_max_keep_versions INT2 --number of versions to archive
	);

--create a function for retrieving all available vocabulary versions
--if necessary, you can specify a specific table
CREATE OR REPLACE FUNCTION sources_archive.ShowVocabularyDates (pVocabulary_id TEXT, pTableName TEXT DEFAULT NULL)
RETURNS TABLE (
	vocabulary_date DATE
) AS
$BODY$
DECLARE
	iTable CONSTANT TEXT:=(SELECT ac.vocabulary_main_table FROM sources_archive.archive_conversion ac WHERE ac.vocabulary_id=pVocabulary_id);
BEGIN
	IF iTable IS NULL THEN
		RAISE EXCEPTION $$Vocabulary_id='%' not found in the sources_archive.archive_conversion table$$, pVocabulary_id
			USING HINT = 'Check if your vocabulary exists: SELECT vocabulary_id FROM sources_archive.archive_conversion ORDER BY 1';
	END IF;

	RETURN QUERY EXECUTE FORMAT ($$
		WITH RECURSIVE sa_cte
		AS (
			(
				SELECT source_version
				FROM sources_archive.%1$I
				ORDER BY source_version
				LIMIT 1
				)
			UNION ALL
			SELECT l.source_version
			FROM sa_cte c
			CROSS JOIN LATERAL(
				SELECT s.source_version
				FROM sources_archive.%1$I s
				WHERE s.source_version > c.source_version
				ORDER BY s.source_version
				LIMIT 1
				) l
			)
		SELECT source_version
		FROM sa_cte
	$$, COALESCE(pTableName, iTable));
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER STABLE PARALLEL SAFE;

--create a function to get the selected date for vocabulary from session parameter (e.g. archive.rxnorm_version=YYYYMMDD) (or use max available date)
CREATE OR REPLACE FUNCTION sources_archive.GetVocabularyDate (
	pVocabulary_id TEXT
)
RETURNS DATE AS
$BODY$
	SELECT COALESCE(TO_DATE(NULLIF(CURRENT_SETTING(ac.vocabulary_parameter_name, TRUE),''), 'YYYYMMDD'), ac.vocabulary_latest_date)
	FROM sources_archive.archive_conversion ac
	WHERE ac.vocabulary_id = pVocabulary_id;
$BODY$
LANGUAGE 'sql' STABLE STRICT PARALLEL SAFE;

--create a function to adding fresh data to archive
CREATE OR REPLACE FUNCTION sources_archive.AddVocabularyToArchive (pVocabulary_id TEXT, pVocabulary_tables TEXT[], pVocabulary_date DATE, pVocabulary_parameter_name TEXT, pVocabulary_max_keep_versions INT4)
RETURNS VOID AS
$BODY$
DECLARE
	iTable_name TEXT;
	iIndex TEXT;
	iVersionFound BOOLEAN;
BEGIN
	--check vocabulary spelling
	PERFORM FROM devv5.vocabulary v
	WHERE v.vocabulary_id = pVocabulary_id
		OR pVocabulary_id IN (
			'UMLS',
			'META'
			)
	LIMIT 1;

	IF NOT FOUND THEN
		RAISE EXCEPTION $$vocabulary_id='%' not found$$, pVocabulary_id
			USING HINT = 'Check the vocabulary exists: SELECT * FROM devv5.vocabulary WHERE vocabulary_id=%vocabulary_id% ORDER BY 1';
	END IF;

	--adjust the case of table names
	SELECT ARRAY_AGG(t)
	INTO pVocabulary_tables
	FROM (
		SELECT LOWER(UNNEST(pVocabulary_tables)) t
		) s0;

	--first add the vocabulary to the conversion table
	--with 'ON CONFLICT' clause we can easily manipulate the main table and change it if required
	INSERT INTO sources_archive.archive_conversion AS ac (
		vocabulary_id,
		vocabulary_main_table,
		vocabulary_latest_date,
		vocabulary_parameter_name,
		vocabulary_max_keep_versions
		)
	VALUES (
		pVocabulary_id,
		pVocabulary_tables[1], --exact calculation at the end of the script, now just use the first table in the list, because it is needed for the ShowVocabularyDates function to work correctly
		pVocabulary_date,
		pVocabulary_parameter_name,
		pVocabulary_max_keep_versions
		)
	ON CONFLICT(vocabulary_id)
	DO UPDATE
		SET vocabulary_latest_date = pVocabulary_date,
			vocabulary_parameter_name = pVocabulary_parameter_name,
			vocabulary_max_keep_versions = pVocabulary_max_keep_versions
	WHERE ac.* IS DISTINCT FROM excluded.*;

	--iterate through tables array, create archive tables, turn on RLS
	FOREACH iTable_name IN ARRAY pVocabulary_tables LOOP

		--check if a table already exists
		PERFORM FROM pg_tables pt
		WHERE pt.schemaname = 'sources_archive'
			AND pt.tablename = iTable_name;

		IF NOT FOUND THEN
			EXECUTE FORMAT ($$
				CREATE TABLE sources_archive.%1$I (LIKE sources.%1$I, source_version DATE);
				CREATE POLICY policy_%1$I ON sources_archive.%1$I FOR SELECT USING (source_version=sources_archive.GetVocabularyDate(%2$L));
				ALTER TABLE sources_archive.%1$I ENABLE ROW LEVEL SECURITY;
			$$, iTable_name, pVocabulary_id);
		ELSE
			--if the table already exists, check the source version, probably we already have this data
			EXECUTE FORMAT ($$
				SELECT TRUE FROM sources_archive.%I WHERE source_version = %L LIMIT 1
			$$, iTable_name, pVocabulary_date) INTO iVersionFound;

			CONTINUE WHEN iVersionFound;
		END IF;

		--drop current indexes for faster load
		FOR iIndex IN (
			SELECT pi.indexname::TEXT
			FROM pg_indexes pi
			WHERE pi.schemaname = 'sources_archive'
				AND pi.tablename = iTable_name
		) LOOP
			EXECUTE FORMAT ($$
				DROP INDEX sources_archive.%I
			$$, iIndex);
		END LOOP;

		--load the data
		EXECUTE FORMAT ($$
			INSERT INTO sources_archive.%1$I
			SELECT *, %2$L FROM sources.%1$I
		$$, iTable_name, pVocabulary_date);

		--copy (restore) indexes from the original table
		FOR iIndex IN (
			SELECT pi.indexdef
			FROM pg_indexes pi
			WHERE pi.schemaname = 'sources'
				AND pi.tablename = iTable_name
		) LOOP
			EXECUTE REPLACE(REPLACE(iIndex,' ON sources.',' ON sources_archive.'),'CREATE UNIQUE INDEX ','CREATE INDEX ');
		END LOOP;

		--add additional index for source_version
		EXECUTE FORMAT ($$
			CREATE INDEX ON sources_archive.%I (source_version)
		$$, iTable_name);

		--delete old versions
		EXECUTE FORMAT ($$
			DELETE
			FROM sources_archive.%1$I sa
			USING (
					SELECT vocabulary_date FROM sources_archive.ShowVocabularyDates(%2$L, %1$L)
					ORDER BY vocabulary_date DESC OFFSET %3$L
					) v
			WHERE sa.source_version = v.vocabulary_date
		$$, iTable_name, pVocabulary_id, pVocabulary_max_keep_versions);

		--collect statistics
		EXECUTE FORMAT ($$
			ANALYZE sources_archive.%I
		$$, iTable_name);
	END LOOP;

	--store all active tables affected by the current vocabulary and all missing
	UPDATE sources_archive.archive_conversion ac
	SET vocabulary_active_tables = pVocabulary_tables,
		vocabulary_missing_tables = s1.new_vocabulary_missing_tables
	FROM (
		--form an up-to-date list of missing tables, taking into account the fact that tables can return to the active state
		SELECT l.new_vocabulary_missing_tables
		FROM sources_archive.archive_conversion ac_int
		CROSS JOIN LATERAL (
			SELECT ARRAY_AGG(s0.t) AS new_vocabulary_missing_tables FROM (
				(
					(
						SELECT UNNEST(ac_int.vocabulary_active_tables) t
						
						EXCEPT
						
						SELECT UNNEST(pVocabulary_tables)
						)
					
					UNION ALL
					
					SELECT UNNEST(ac_int.vocabulary_missing_tables)
					)
				
				EXCEPT
				
				SELECT UNNEST(pVocabulary_tables)
				) s0
			) l
		WHERE ac_int.vocabulary_id = pVocabulary_id
		) s1
	WHERE ac.vocabulary_id = pVocabulary_id;

	--get smallest table based on approximate row count
	--this will have a positive impact on the performance of the ShowVocabularyDates function
	--NB: we need to do this at the end, because tables can come and go and we need to choose the smallest from the "oldest" tables (the table with the maximum number of archived versions)
	UPDATE sources_archive.archive_conversion ac
	SET vocabulary_main_table = s0.smallest_table
	FROM (
		SELECT pc.relname::TEXT AS smallest_table
		FROM pg_class pc
		WHERE pc.oid IN (
				SELECT ('sources.' || t)::REGCLASS
				FROM UNNEST(pVocabulary_tables) t
				)
		ORDER BY (SELECT COUNT(*) FROM sources_archive.ShowVocabularyDates(pVocabulary_id, pc.relname::TEXT)) DESC, pc.reltuples LIMIT 1
	) s0
	WHERE ac.vocabulary_id = pVocabulary_id;
END;
$BODY$
LANGUAGE 'plpgsql' STRICT;

--show currently installed params
CREATE OR REPLACE FUNCTION sources_archive.ShowArchiveParams ()
RETURNS TABLE (
	vocabulary_id TEXT,
	vocabulary_version_value DATE
) AS
$BODY$
	SELECT vocabulary_id,
		TO_DATE(NULLIF(CURRENT_SETTING(vocabulary_parameter_name, TRUE), ''), 'YYYYMMDD')
	FROM sources_archive.archive_conversion
	WHERE NULLIF(CURRENT_SETTING(vocabulary_parameter_name, TRUE), '') IS NOT NULL;
$BODY$
LANGUAGE 'sql' STABLE PARALLEL SAFE;

--reset all params
CREATE OR REPLACE FUNCTION sources_archive.ResetArchiveParams ()
RETURNS VOID AS
$BODY$
BEGIN
	PERFORM SET_CONFIG(vocabulary_parameter_name, '', FALSE)
	FROM sources_archive.archive_conversion;
END;
$BODY$
LANGUAGE 'plpgsql';

--set params
CREATE OR REPLACE FUNCTION sources_archive.SetArchiveParams (pVocabulary_id TEXT, pVocabulary_version DATE)
RETURNS VOID AS
$BODY$
BEGIN
	PERFORM SET_CONFIG(ac.vocabulary_parameter_name, TO_CHAR(pVocabulary_version, 'YYYYMMDD'), FALSE)
	FROM sources_archive.archive_conversion ac
	WHERE ac.vocabulary_id = pVocabulary_id
		AND EXISTS (
			SELECT 1
			FROM sources_archive.ShowVocabularyDates(pVocabulary_id) vd
			WHERE vd.vocabulary_date = pVocabulary_version
			);

	IF NOT FOUND THEN
		RAISE EXCEPTION $$vocabulary_version='%' for vocabulary_id='%' not found$$, TO_CHAR(pVocabulary_version,'YYYYMMDD'), pVocabulary_id
			USING HINT = 'Check the version exists: SELECT vocabulary_date FROM sources_archive.ShowVocabularyDates(%vocabulary_id%) ORDER BY 1 or SELECT * FROM sources_archive.ShowArchiveDetails() ORDER BY 1';
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql' STRICT;

--show detailed stat
CREATE OR REPLACE FUNCTION sources_archive.ShowArchiveDetails ()
RETURNS TABLE (
	vocabulary_id TEXT,
	vocabulary_max_keep_versions INT2,
	table_name TEXT,
	table_status TEXT,
	source_versions TEXT
) AS
$BODY$
	SELECT s0.vocabulary_id,
		s0.vocabulary_max_keep_versions,
		s0.table_name,
		s0.table_status,
		l.source_versions
	FROM (
		SELECT ac.vocabulary_id,
			ac.vocabulary_max_keep_versions,
			UNNEST(ac.vocabulary_active_tables) table_name,
			'ACTIVE' table_status
		FROM sources_archive.archive_conversion ac
		
		UNION ALL
		
		SELECT ac.vocabulary_id,
			ac.vocabulary_max_keep_versions,
			UNNEST(ac.vocabulary_missing_tables) table_name,
			'DEPRECATED' table_status
		FROM sources_archive.archive_conversion ac
		) s0
	CROSS JOIN LATERAL(SELECT STRING_AGG(TO_CHAR(vd.vocabulary_date, 'YYYYMMDD'), ',' ORDER BY vd.vocabulary_date DESC) source_versions FROM sources_archive.ShowVocabularyDates(s0.vocabulary_id, s0.table_name) vd) l

$BODY$
LANGUAGE 'sql' STABLE PARALLEL SAFE;

CREATE OR REPLACE FUNCTION sources_archive.GetTablesFromLS(pLSURL TEXT)
RETURNS	TABLE (
	vocabulary_id TEXT,
	table_name TEXT
) AS
$BODY$
	SELECT l.vocabulary_id,
		s0.ls_table
	FROM (
		SELECT DISTINCT LOWER(UNNEST(REGEXP_MATCHES(u.http_content, '\msources\.(.+?)\M', 'gi'))) ls_table
		FROM vocabulary_download.PY_HTTP_GET(url => pLSURL) u
		) s0
	LEFT JOIN LATERAL(SELECT ad.vocabulary_id FROM sources_archive.ShowArchiveDetails() ad WHERE ad.table_name = s0.ls_table) l ON TRUE;
$BODY$
LANGUAGE 'sql' STRICT STABLE;