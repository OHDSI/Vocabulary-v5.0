CREATE OR REPLACE FUNCTION skype_pack.AddTask (pTaskCommand TEXT, pTaskProcedureName TEXT, pTaskDescription TEXT, pTaskType TEXT DEFAULT NULL)
RETURNS VOID AS
$BODY$
	/*
	DO $_$
	BEGIN
		PERFORM skype_pack.AddTask(
		pTaskCommand			=> 'show idle',
		pTaskProcedureName		=> 'task_ShowIdleInTransaction',
		pTaskDescription		=> 'Shows clients in ''idle in transaction'' status',
		pTaskType				=> NULL --'instant' (bot should answer immediately) or NULL (task for queue)
		);
	END $_$;
	*/
BEGIN
	pTaskCommand:=NULLIF(LOWER(TRIM(pTaskCommand)),'');
	pTaskProcedureName:=NULLIF(pTaskProcedureName,'');
	pTaskDescription:=NULLIF(TRIM(pTaskDescription),'');
	pTaskType:=NULLIF(TRIM(pTaskType),'');

	IF pTaskCommand IS NULL THEN
		RAISE EXCEPTION 'Сommand cannot be empty!';
	END IF;
	IF pTaskProcedureName IS NULL THEN
		RAISE EXCEPTION 'Procedure name cannot be empty!';
	END IF;
	IF pTaskDescription IS NULL THEN
		RAISE EXCEPTION 'Description cannot be empty!';
	END IF;
	IF COALESCE(pTaskType,'instant')<>'instant' THEN
		RAISE EXCEPTION 'Please set a proper task type';
	END IF;

	--the simplest way to check if a function exists
	pTaskProcedureName:=pTaskProcedureName::REGPROC::TEXT;

	IF LEFT(pTaskProcedureName, 5)<>'task_' THEN
		RAISE EXCEPTION $q$The procedure name must have the prefix 'task_'$q$;
	END IF;

	INSERT INTO task
	VALUES (
		DEFAULT,
		pTaskCommand,
		pTaskProcedureName,
		pTaskDescription,
		pTaskType
	)
	ON CONFLICT DO NOTHING;

	IF NOT FOUND THEN
		RAISE EXCEPTION $q$Command '%' already exists$q$, pTaskCommand;
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = skype_pack, pg_temp;

REVOKE EXECUTE ON FUNCTION skype_pack.AddTask FROM PUBLIC;