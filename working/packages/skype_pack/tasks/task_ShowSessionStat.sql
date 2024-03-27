CREATE OR REPLACE FUNCTION skype_pack.task_ShowSessionStat (pTaskCommand TEXT, pSkypeUserID TEXT, pSkypeChatID TEXT, pLogID INT4)
RETURNS VOID AS
$BODY$
	/*
	Shows clients in 'idle in transaction' status
	*/
DECLARE
	iRet TEXT;
	iHeader TEXT;
	iTitle TEXT;
	iData TEXT;
	iCRLF CONSTANT VARCHAR(4):=E'\r\n';
	iDelimiter CONSTANT VARCHAR(1):=E'\t';
BEGIN
	iTitle:='Sessions in ''idle in transaction'' status:' || iCRLF;
	SELECT STRING_AGG (columns, iDelimiter)
	INTO iHeader
	FROM UNNEST(ARRAY['pid', 'username', 'transaction_start', 'duration']) AS columns; 

	SELECT STRING_AGG(CONCAT (
				pid,
				iDelimiter,
				usename,
				iDelimiter,
				TO_CHAR(xact_start, 'DD-MON-YYYY HH24:MI:SS'),
				iDelimiter,
				TO_CHAR(DATE_TRUNC('second', CURRENT_TIMESTAMP - xact_start), 'HH24:MI:SS'),
				iDelimiter
				--,LEFT(query, 50)
				), iCRLF ORDER BY xact_start)
	INTO iData
	FROM pg_stat_activity
	WHERE state = 'idle in transaction';

	IF iData IS NULL THEN
		iRet:=iTitle || '(there is no idle transactions)';
	ELSE
		iRet:=iTitle || '{code}' || FormatTableData(iHeader || iCRLF || iData) || '{code}';
	END IF;

	iTitle:='Sessions in ''active'' status:' || iCRLF;
	SELECT STRING_AGG (columns, iDelimiter)
	INTO iHeader
	FROM UNNEST(ARRAY['pid', 'leader_pid', 'username', 'transaction_start', 'duration']) AS columns; 

	SELECT STRING_AGG(CONCAT (
				pid,
				iDelimiter,
				leader_pid,
				iDelimiter,
				usename,
				iDelimiter,
				TO_CHAR(xact_start, 'DD-MON-YYYY HH24:MI:SS'),
				iDelimiter,
				TO_CHAR(DATE_TRUNC('second', CURRENT_TIMESTAMP - xact_start), 'HH24:MI:SS'),
				iDelimiter
				--,LEFT(query, 50)
				), iCRLF ORDER BY xact_start, leader_pid NULLS FIRST, pid)
	INTO iData
	FROM pg_stat_activity
	WHERE state = 'active'
	AND pid <> pg_backend_pid();

	IF iData IS NULL THEN
		iRet:=iRet || REPEAT (iCRLF, 2) || iTitle || '(there is no active transactions)';
	ELSE
		iRet:=iRet || REPEAT (iCRLF, 2) || iTitle || '{code}' || FormatTableData(iHeader || iCRLF || iData) || '{code}';
	END IF;

	iTitle:='Count of sessions in ''idle'' status: ';
	SELECT STRING_AGG (columns, iDelimiter)
	INTO iHeader
	FROM UNNEST(ARRAY['pid', 'leader_pid', 'username', 'transaction_start', 'duration']) AS columns; 

	SELECT COUNT(*)
	INTO iData
	FROM pg_stat_activity
	WHERE state = 'idle';

	iRet:=iRet || REPEAT (iCRLF, 2) || iTitle || iData;

	PERFORM SendMessage(pSkypeUserID, iRet, pSkypeChatID, TRUE, pLogID, TRUE);
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = skype_pack, pg_temp;

REVOKE EXECUTE ON FUNCTION skype_pack.task_ShowSessionStat FROM PUBLIC;

DO $_$
BEGIN
	PERFORM skype_pack.AddTask(
	pTaskCommand			=> 'show sessions',
	pTaskProcedureName		=> 'task_ShowSessionStat',
	pTaskDescription		=> 'Shows stat by sessions',
	pTaskType				=> 'instant'
	);
END $_$;