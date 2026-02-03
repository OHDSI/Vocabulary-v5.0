/*
Description:
This function creates a new user and associated schema. It is also possible to fill it with data.
Only specific users can execute this function and only under his personal schema.

Parameters:
pSchemaName - name of the schema (with dev_ prefix)
pPassWord - password, use 123 for standard schemas, and a strong password for personal
pOwnerName - the person in charge of the schema
pOwnerEmail - owner's e-mail
pComment - small comment (schema purpose - for some project, personal etc)
pFillWithData - fill in or not with data (default value: FALSE). When TRUE, the schema will be filled with the base tables, empty ancestor and synonym tables, and with fresh relationships only
additional params when pFillWithData is TRUE:
pInclude_concept_ancestor - fill in, including the concept_ancestor table (default value: FALSE)
pInclude_deprecated_rels - fill in with full relationships (fresh + deprecated) (default value: FALSE)
pInclude_synonyms - fill in, including the concept_synonym table (default value: FALSE)

Examples:
1. create a new empty personal schema
DO $_$
BEGIN
	PERFORM devv5.CreateNewSchema(
		pSchemaName=>	'dev_test2',
		pPassWord=>		'123',
		pOwnerName=>	'Neo',
		pOwnerEmail=>	'neo@matrix.com',
		pComment=>		'personal schema'
	);
END $_$;

2. create a new schema filled with default data
DO $_$
BEGIN
	PERFORM devv5.CreateNewSchema(
		pSchemaName=>	'dev_coolproject',
		pPassWord=>		'123',
		pOwnerName=>	'Neo',
		pOwnerEmail=>	'neo@matrix.com',
		pComment=>		'schema for cool project',
		pFillWithData=>	TRUE
	);
END $_$;

3. create a new fully filled schema
DO $_$
BEGIN
	PERFORM devv5.CreateNewSchema(
		pSchemaName=>	'dev_coolproject',
		pPassWord=>		'123',
		pOwnerName=>	'Neo',
		pOwnerEmail=>	'neo@matrix.com',
		pComment=>		'schema for another cool project',
		pFillWithData=>	TRUE,
		pInclude_concept_ancestor=>TRUE,
		pInclude_deprecated_rels=>TRUE,
		pInclude_synonyms=>TRUE
	);
END $_$;

Installation:
CREATE TABLE devv5.schema_actions (
	log_id INT4 GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	schema_name TEXT NOT NULL,
	schema_operation TEXT NOT NULL CHECK (schema_operation IN ('C')), --C=creation
	user_name TEXT NOT NULL, --user who performed the operation
	op_time TIMESTAMPTZ NOT NULL, --operation timestamp
	owner_name TEXT,
	owner_email TEXT,
	operation_comment TEXT
	);

Get the roles that have the right to run the function:
SELECT STRING_AGG(COALESCE(NULLIF(s0.acl_arr [1], ''), 'PUBLIC'), ', ' ORDER BY s0.acl_arr [1]) AS granted_role_name
--s0.acl_arr[2] AS rights, s0.acl_arr[3] grantor, s0.proname
FROM (
	SELECT REGEXP_MATCHES(UNNEST(p.proacl)::TEXT, '^(.*?)=(.+?)/(.+)$') acl_arr,
		p.proname
	FROM pg_proc p
	JOIN pg_namespace n ON n.oid = p.pronamespace
		AND n.nspname = 'devv5'
	WHERE p.proname = LOWER('CreateNewSchema')
	) s0
WHERE s0.acl_arr [2] LIKE '%X%' --EXECUTE
	AND COALESCE(s0.acl_arr [1], 'PUBLIC') <> 'devv5' --exclude owner
GROUP BY s0.proname;

*/

CREATE OR REPLACE FUNCTION devv5.CreateNewSchema (
  pSchemaName schema_actions.schema_name%TYPE,
  pPassWord TEXT,
  pOwnerName schema_actions.owner_name%TYPE DEFAULT NULL,
  pOwnerEmail schema_actions.owner_email%TYPE DEFAULT NULL,
  pComment schema_actions.operation_comment%TYPE DEFAULT NULL,
  pFillWithData BOOLEAN DEFAULT FALSE,
  --passing params for FillNewDevSchema()
  pInclude_concept_ancestor BOOLEAN DEFAULT FALSE,
  pInclude_deprecated_rels BOOLEAN DEFAULT FALSE,
  pInclude_synonyms BOOLEAN DEFAULT FALSE
)
RETURNS void AS
$BODY$
DECLARE
  iDefaultRole TEXT:='role_read_only';
  iTbl TEXT;
  crlf TEXT:='<br>';
  iAlertEmail TEXT:=(SELECT var_value FROM devv5.config$ WHERE var_name='schema_manipulation_email');
  iEmailBody TEXT;
BEGIN
  pSchemaName:=LOWER(pSchemaName);
  IF pSchemaName<>QUOTE_IDENT(pSchemaName) THEN
    RAISE EXCEPTION 'Incorrect schema name: %<>%', pSchemaName, QUOTE_IDENT(pSchemaName);
  END IF;
  IF LEFT(pSchemaName,4)<>'dev_' THEN
    RAISE EXCEPTION 'Incorrect schema name: no dev_ prefix';
  END IF;
  IF pSchemaName IS NULL THEN
    RAISE EXCEPTION 'Incorrect schema name: NULL';
  END IF;
  IF pPassWord IS NULL THEN
    RAISE EXCEPTION 'Incorrect password: NULL';
  END IF;
  IF (pOwnerEmail IS NOT NULL AND pOwnerEmail !~ '^[[:alnum:]._-]+@[[:alnum:].-]+\.[[:alpha:]]+$') OR pOwnerEmail='neo@matrix.com' THEN --the simplest check for email
    RAISE EXCEPTION 'Incorrect e-mail';
  END IF;

  EXECUTE FORMAT ('
    CREATE USER %1$I WITH PASSWORD %2$L IN ROLE %3$s;
    CREATE SCHEMA AUTHORIZATION %1$I;
    ALTER DEFAULT PRIVILEGES FOR USER %1$I IN SCHEMA %1$I GRANT SELECT ON TABLES TO %3$s;
    GRANT USAGE ON SCHEMA %1$I TO %3$s;
  ', pSchemaName, pPassWord, iDefaultRole);

  INSERT INTO schema_actions
  VALUES (
    DEFAULT,
    pSchemaName,
    'C',
    SESSION_USER,
    CLOCK_TIMESTAMP(),
    pOwnerName,
    pOwnerEmail,
    pComment
  );

  IF pFillWithData THEN
    perform set_config('search_path', pSchemaName, TRUE); --'SET LOCAL search_path TO pSchemaName' will not work;
    PERFORM devv5.FillNewDevSchema(
      include_concept_ancestor=>pInclude_concept_ancestor,
      include_deprecated_rels=>pInclude_deprecated_rels,
      include_synonyms=>pInclude_synonyms
    );
    --change owner back and give SELECT permissions to default read role
    FOR iTbl IN (SELECT t.tablename FROM pg_tables t WHERE t.schemaname=pSchemaName) LOOP
      EXECUTE FORMAT ('
      ALTER TABLE %1$s OWNER TO %2$I;
      GRANT SELECT ON %1$s TO %3$s;
      ', iTbl, pSchemaName, iDefaultRole);
    END LOOP;
    RESET search_path;
  END IF;

  iEmailBody:=FORMAT('
    <b>Schema owner</b>: %s%s
    <b>Comment</b>: %s
    <b>Filled with data</b>: %s
    <b>Credentials</b>: %s

    <b>Note</b>: For personal schema, it is recommended to change the password after first login
    ',
    COALESCE(devv5.py_htmlescape(pOwnerName),'<i>(not specified)</i>'),
    ' &lt;'||pOwnerEmail||'&gt;',
    devv5.py_htmlescape(pComment),
    CASE WHEN pFillWithData THEN 'yes' ELSE 'no' END,
    pSchemaName||':'||devv5.py_htmlescape(pPassWord)
  );

  iEmailBody:=REGEXP_REPLACE(iEmailBody,'[\n\r]+', crlf, 'g');

  IF pOwnerEmail IS NOT NULL THEN
    iAlertEmail:=iAlertEmail||','||pOwnerEmail;
  END IF;

  PERFORM devv5.SendMailHTML (
    iAlertEmail,
    'A new schema '||pSchemaName||' has been created by '||SESSION_USER,
    iEmailBody
  );
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET client_min_messages = error
SET search_path = devv5, pg_temp;

/*
Post-installation:
REVOKE EXECUTE ON FUNCTION devv5.CreateNewSchema FROM PUBLIC, role_read_only;
GRANT EXECUTE ON FUNCTION devv5.CreateNewSchema TO ...;
*/