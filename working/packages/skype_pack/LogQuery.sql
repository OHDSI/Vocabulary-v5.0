CREATE OR REPLACE FUNCTION skype_pack.LogQuery (pSkypeUserID TEXT, pSkypeUserName TEXT, pSkypeChatID TEXT, pQuery TEXT, pRAWQuery TEXT)
RETURNS VOID AS
$BODY$
	/*
	Query logs...
	*/
DECLARE
	iLogID INT4;
	iTaskID INT4;
	iTaskProcedure TEXT;
	iTaskType TEXT;
BEGIN
	pSkypeUserID:=NULLIF(pSkypeUserID,'');
	pSkypeUserName:=NULLIF(pSkypeUserName,'');
	pSkypeChatID:=NULLIF(pSkypeChatID,'');
	pQuery:=NULLIF(pQuery,'');
	pRAWQuery:=NULLIF(pRAWQuery,'');
	
	INSERT INTO skype_query_log
	VALUES (
		DEFAULT,
		CLOCK_TIMESTAMP(),
		pSkypeUserID,
		pSkypeUserName,
		pSkypeChatID,
		pQuery,
		pRAWQuery
	)
	RETURNING log_id INTO iLogID;

	PERFORM FROM skype_allowed_users WHERE skype_userid = pSkypeUserID;
	IF NOT FOUND THEN
		RETURN;
	END IF;

	SELECT task_id,
		task_procedure,
		task_type
	INTO iTaskID,
		iTaskProcedure,
		iTaskType
	FROM task
	WHERE task_command = LOWER(pQuery);

	IF NOT FOUND THEN
		RETURN;
	END IF;

	--instant tasks (autoreply)
	IF iTaskType = 'instant' THEN
		EXECUTE FORMAT ('SELECT %I($1, $2, $3, $4);', iTaskProcedure)
			USING LOWER(pQuery), pSkypeUserID, pSkypeChatID, iLogID;
		RETURN;
	END IF;

	--put task to queue
	INSERT INTO task_queue (
		task_id,
		log_id
		)
	SELECT iTaskID,
		iLogID
	WHERE NOT EXISTS (
			--one queued task per user
			SELECT 1
			FROM task_queue tq_int
			JOIN skype_query_log ql_int USING (log_id)
			WHERE ql_int.skype_userid = pSkypeUserID
			);

	IF NOT FOUND THEN
		PERFORM SendMessage(pSkypeUserID, 'You still have unfinished tasks', pSkypeChatID);
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = skype_pack, pg_temp;

REVOKE EXECUTE ON FUNCTION skype_pack.LogQuery FROM PUBLIC;
GRANT EXECUTE ON FUNCTION skype_pack.LogQuery TO role_skypebot;