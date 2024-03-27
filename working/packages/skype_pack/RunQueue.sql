CREATE OR REPLACE FUNCTION skype_pack.RunQueue ()
RETURNS VOID AS
$BODY$
	/*
	Run queued task one-by-one
	*/
DECLARE
	iLogID INT4;
	iTaskQueueID INT4;
	iTaskProcedure TEXT;
	iSkypeUserID TEXT;
	iSkypeChatID TEXT;
	iRet TEXT;
	iCRLFSQL CONSTANT VARCHAR(4):=E'\r\n';
BEGIN
	IF NOT PG_TRY_ADVISORY_XACT_LOCK(HASHTEXT('RunQueue')) THEN
		RETURN;
	END IF;

	SELECT t.task_procedure,
		q.task_queue_id,
		q.log_id,
		ql.skype_userid,
		ql.skype_chatid
	INTO iTaskProcedure,
		iTaskQueueID,
		iLogID,
		iSkypeUserID,
		iSkypeChatID
	FROM task t
	JOIN task_queue q USING (task_id)
	JOIN skype_query_log ql USING (log_id)
	ORDER BY q.task_queue_id DESC
	LIMIT 1;

	IF NOT FOUND THEN
		RETURN;
	END IF;

	BEGIN
		EXECUTE FORMAT ('SELECT %I($1, $2, $3);', iTaskProcedure)
			USING iSkypeUserID, iSkypeChatID, iLogID;

		EXCEPTION WHEN OTHERS THEN
			GET STACKED DIAGNOSTICS iRet = PG_EXCEPTION_CONTEXT;
			iRet:=SQLERRM || iCRLFSQL || 'CONTEXT: ' || iRet;

			PERFORM WriteErrorLog (iRet, 'RunQueue', iLogID);
			PERFORM SendMessage(iSkypeUserID, 'Something went wrong with your task, see logs for details [query_log_id=' || iLogID || ']', iSkypeChatID, FALSE, iLogID);
	END;

	DELETE FROM task_queue WHERE task_queue_id = iTaskQueueID;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = skype_pack, pg_temp;

REVOKE EXECUTE ON FUNCTION skype_pack.RunQueue FROM PUBLIC;
GRANT EXECUTE ON FUNCTION skype_pack.RunQueue TO role_skypebot;