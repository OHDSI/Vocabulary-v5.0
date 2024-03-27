CREATE OR REPLACE FUNCTION skype_pack.AddInstantReply (pTaskCommand TEXT, pTaskDescription TEXT, pReply TEXT)
RETURNS VOID AS
$BODY$
	/*
	Add instant reply
	DO $_$
	BEGIN
		PERFORM skype_pack.AddInstantReply(
		pTaskCommand			=> 'ping',
		pTaskDescription		=> 'Checks the bot''s availability, it must respond ''pong''',
		pReply					=> 'pong!'
		);
	END $_$;
	*/
BEGIN
	pTaskCommand:=NULLIF(LOWER(TRIM(pTaskCommand)),'');
	pTaskDescription:=NULLIF(TRIM(pTaskDescription),'');
	pReply:=NULLIF(TRIM(pReply),'');

	IF pTaskCommand IS NULL THEN
		RAISE EXCEPTION 'Сommand cannot be empty!';
	END IF;

	IF pTaskDescription IS NULL THEN
		RAISE EXCEPTION 'Description cannot be empty!';
	END IF;

	IF pReply IS NULL THEN
		RAISE EXCEPTION 'Reply cannot be empty!';
	END IF;

	PERFORM skype_pack.AddTask(
		pTaskCommand			=> pTaskCommand,
		pTaskProcedureName		=> 'task_InstantReply',
		pTaskDescription		=> pTaskDescription,
		pTaskType				=> 'instant'
	);

	INSERT INTO autoreply
	VALUES (
		pTaskCommand,
		pReply
	);
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = skype_pack, pg_temp;

REVOKE EXECUTE ON FUNCTION skype_pack.AddInstantReply FROM PUBLIC;