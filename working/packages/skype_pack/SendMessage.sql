CREATE OR REPLACE FUNCTION skype_pack.SendMessage (pSkypeUserID TEXT, pMessage TEXT, pSkypeChatID TEXT DEFAULT NULL, pNewLine BOOLEAN DEFAULT FALSE, pQueryLogID INT4 DEFAULT NULL, pFormat BOOLEAN DEFAULT FALSE)
RETURNS VOID AS
$BODY$
	/*
	Send message to specified user
	pSkypeUserID - skype.account
	pMessage - your message
	pSkypeChatID skype chat id (or skype.account for private chat)
	pNewLine - start the message on a new line or not
	pQueryLogID - log id from the skype_pack.skype_query_log (don't fill for regular messages)
	pFormat - format the message if it contains *, ~ {code} and _ (very limited support)

	Example:
	DO $_$
	BEGIN
		PERFORM skype_pack.SendMessage('skype.account', 'Test message');
	END $_$;
	*/
DECLARE
	iSkypeConfigPath CONSTANT TEXT:=(SELECT var_value FROM devv5.config$ WHERE var_name='skype_config_path');
	iRet TEXT;
	iCRLFSQL CONSTANT VARCHAR(4):=E'\r\n';
BEGIN
	pSkypeUserID:=NULLIF(pSkypeUserID,'');
	pSkypeChatID:=NULLIF(pSkypeChatID,'');
	pMessage:=NULLIF(pMessage,'');

	--if chatID is not specified - use private chat
	pSkypeChatID:=COALESCE(pSkypeChatID, '8:'||pSkypeUserID);

	PERFORM py_SendMessage(iSkypeConfigPath, pSkypeUserID, pSkypeChatID, pMessage, pNewLine, pFormat);

	EXCEPTION WHEN OTHERS THEN
		GET STACKED DIAGNOSTICS iRet = PG_EXCEPTION_CONTEXT;
		iRet:=SQLERRM||iCRLFSQL||'CONTEXT: '||iRet;

		PERFORM WriteErrorLog (iRet, 'SendMessage', pQueryLogID);
		RAISE NOTICE '%', iRet;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = skype_pack, pg_temp;

REVOKE EXECUTE ON FUNCTION skype_pack.SendMessage FROM PUBLIC;
GRANT EXECUTE ON FUNCTION skype_pack.SendMessage TO role_read_only;