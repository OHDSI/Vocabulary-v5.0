CREATE OR REPLACE FUNCTION skype_pack.task_InstantReply (pTaskCommand TEXT, pSkypeUserID TEXT, pSkypeChatID TEXT, pLogID INT4)
RETURNS VOID AS
$BODY$
	/*
	Autoreply for simple commands (help, ping etc)
	*/
DECLARE
	iRet TEXT;
	iNewLine BOOLEAN = FALSE;
	iCRLFSQL CONSTANT VARCHAR(4):=E'\r\n';
BEGIN
	SELECT a_text
	INTO iRet
	FROM autoreply a
	WHERE q_text = pTaskCommand;

	IF NOT FOUND THEN
		RETURN;
	END IF;

	IF pTaskCommand = 'help' THEN
		SELECT STRING_AGG ('*'||task_command||'* - {code}'||task_description||'{code}', iCRLFSQL ORDER BY task_command)
		INTO iRet
		FROM task;

		iNewLine = TRUE;
	END IF;

	PERFORM SendMessage(pSkypeUserID, iRet, pSkypeChatID, iNewLine, pLogID, TRUE);
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = skype_pack, pg_temp;

DO $_$
BEGIN
	PERFORM skype_pack.AddInstantReply(
	pTaskCommand			=> 'help',
	pTaskDescription		=> 'Get short help for all available commands',
	pReply					=> '-' --the answer will be generated automatically inside task_InstantReply function
	);

	PERFORM skype_pack.AddInstantReply(
	pTaskCommand			=> 'ping',
	pTaskDescription		=> 'Checks the bot''s availability, it must respond ''pong''',
	pReply					=> 'pong!'
	);

	PERFORM skype_pack.AddInstantReply(
	pTaskCommand			=> 'about',
	pTaskDescription		=> 'Get the github link',
	pReply					=> 'https://github.com/OHDSI/Vocabulary-v5.0/tree/skype_pack/working/packages/skype_pack'
	);
END $_$;