CREATE OR REPLACE FUNCTION devv5.qa_ddl ()
RETURNS TABLE (
	error_text TEXT,
	schema_name TEXT,
	table_name TEXT,
	object_name TEXT,
	descr TEXT,
	how_to_fix TEXT
) AS
$BODY$
/*
The function returns all the inconsistencies in the DDL of the specified tables

SELECT * FROM devv5.qa_ddl();

Login as %schema_name% and run %how_to_fix% script

If you are confident in your actions (and you have superuser privileges), you can fix all bugs automatically:

DO $_$
DECLARE
A RECORD;
BEGIN
	FOR A IN (SELECT * FROM devv5.qa_ddl()) LOOP
		EXECUTE 'SET LOCAL SESSION AUTHORIZATION '||A.schema_name;
		EXECUTE A.how_to_fix;
		RESET SESSION AUTHORIZATION;
	END LOOP;
END $_$;
*/
BEGIN
	RETURN QUERY
	WITH tables
	AS (
		SELECT UNNEST(ARRAY [
			/*basic tables*/
			'concept_ancestor', 'concept', 'concept_relationship', 'concept_synonym', 'drug_strength', 'pack_content',
			/*vocabulary directories*/
			'relationship', 'vocabulary', 'vocabulary_conversion', 'concept_class', 'domain',
			/*stage tables*/
			'concept_stage', 'concept_relationship_stage','concept_synonym_stage', 'drug_strength_stage','pack_content_stage',
			/*manul tables*/
			'concept_manual','concept_relationship_manual','concept_synonym_manual']
			) AS tablename,
		'devv5' AS schemaname
		),
	--these indexes are used only in main schema
	exclude_indexes
	AS (
		SELECT UNNEST(ARRAY ['idx_drug_strength_id_1','idx_drug_strength_id_2','vocabulary_conversion_pkey']) AS indexname
		),
	dev_schemas
	AS (
		SELECT sch.schema_name
		FROM information_schema.schemata sch
		WHERE (
				sch.schema_name LIKE 'dev\_%'
				OR sch.schema_name IN (
					'dalex',
					'ddymshyts'
					)
				)
			--and sch.schema_name not in ('dev_guest')
		),
	--these constraints are used only in main schema
	exclude_constraints
	AS (
		SELECT UNNEST(ARRAY ['fpk_crm_vocabulary_1','fpk_crm_vocabulary_2','fpk_crm_relationship_id','vocabulary_conversion_pkey']) AS constraintname
		)
	SELECT 'Missing index' AS error,
		d_s.schema_name::TEXT AS schema_name,
		t.tablename AS table_name,
		i_main.indexname::TEXT AS object_name,
		NULL AS descr,
		REPLACE(i_main.indexdef || ';', ' ON ' || i_main.schemaname || '.', ' ON ' || d_s.schema_name || '.') AS how_to_fix
	FROM tables t
	JOIN pg_indexes i_main ON i_main.schemaname = t.schemaname
		AND i_main.tablename = t.tablename
	CROSS JOIN dev_schemas d_s
	WHERE EXISTS (
			SELECT 1
			FROM pg_tables dev
			WHERE dev.tablename = t.tablename
				AND dev.schemaname = d_s.schema_name
			)
		AND NOT EXISTS (
			SELECT 1
			FROM pg_indexes dev
			WHERE dev.tablename = t.tablename
				AND dev.schemaname = d_s.schema_name
				AND dev.indexname = i_main.indexname
			)
		AND i_main.indexname NOT IN (
			SELECT *
			FROM exclude_indexes
			)
		--exclude indexes by PK, FK, CHECK, UNIQUE constraints
		AND NOT EXISTS (
			SELECT 1
			FROM pg_constraint dev
			WHERE dev.conrelid = (t.schemaname || '.' || t.tablename)::regclass
				AND dev.conname = i_main.indexname
			)

	UNION ALL

	SELECT 'Wrong column constraint NULL/NOT NULL',
		d_s.schema_name,
		t.tablename,
		dev.column_name,
		'has is_nullable ''' || dev.is_nullable || ''' but should be ''' || c_main.is_nullable || '''',
		CASE 
			WHEN c_main.is_nullable = 'NO' THEN
				'ALTER TABLE ' || d_s.schema_name || '.' || t.tablename || ' ALTER COLUMN ' || dev.column_name || ' SET NOT NULL;'
			ELSE
				'ALTER TABLE ' || d_s.schema_name || '.' || t.tablename || ' ALTER COLUMN ' || dev.column_name || ' DROP NOT NULL;'
			END
	FROM tables t
	JOIN information_schema.columns c_main ON c_main.table_schema = t.schemaname
		AND c_main.table_name = t.tablename
	CROSS JOIN dev_schemas d_s
	JOIN information_schema.columns dev ON dev.table_name = t.tablename
		AND dev.table_schema = d_s.schema_name
		AND dev.column_name = c_main.column_name
	WHERE dev.is_nullable <> c_main.is_nullable

	UNION ALL

	SELECT 'Wrong column data type',
		d_s.schema_name,
		t.tablename,
		dev.column_name,
		'has data_type ''' || dev.data_type || ''' but should be ''' || c_main.data_type || '''',
		'ALTER TABLE ' || d_s.schema_name || '.' || t.tablename || ' ALTER COLUMN ' || dev.column_name || ' TYPE ' || c_main.data_type || ' USING ' || dev.column_name || '::' || c_main.data_type || ';'
	FROM tables t
	JOIN information_schema.columns c_main ON c_main.table_schema = t.schemaname
		AND c_main.table_name = t.tablename
	CROSS JOIN dev_schemas d_s
	JOIN information_schema.columns dev ON dev.table_name = t.tablename
		AND dev.table_schema = d_s.schema_name
		AND dev.column_name = c_main.column_name
	WHERE dev.data_type <> c_main.data_type

	UNION ALL

	SELECT 'Wrong constraint (PK, FK, CHECK, UNIQUE etc)',
		d_s.schema_name,
		t.tablename,
		r_main.conname,
		'Need to create ' || pg_get_constraintdef(r_main.oid, true),
		'ALTER TABLE ' || d_s.schema_name || '.' || t.tablename || ' ADD CONSTRAINT ' || r_main.conname || ' ' || pg_get_constraintdef(r_main.oid, true)
	FROM tables t
	JOIN pg_constraint r_main ON r_main.conrelid = (t.schemaname || '.' || t.tablename)::regclass
	CROSS JOIN dev_schemas d_s
	WHERE EXISTS (
			SELECT 1
			FROM pg_tables dev
			WHERE dev.tablename = t.tablename
				AND dev.schemaname = d_s.schema_name
			)
		AND NOT EXISTS (
			SELECT 1
			FROM pg_constraint dev
			WHERE dev.conrelid = (d_s.schema_name || '.' || t.tablename)::regclass
				AND dev.conname = r_main.conname
			)
		AND r_main.conname NOT IN (
			SELECT *
			FROM exclude_constraints
			);
END;
$BODY$
LANGUAGE 'plpgsql' STABLE SECURITY DEFINER;