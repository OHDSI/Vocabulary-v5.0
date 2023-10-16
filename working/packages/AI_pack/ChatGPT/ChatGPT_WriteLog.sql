CREATE OR REPLACE FUNCTION ai_pack.ChatGPT_WriteLog (
	pChatQuery TEXT,
	pInputParams JSONB,
	pReply TEXT,
	pUsageTokens JSONB
)
RETURNS INT4 AS
$BODY$
DECLARE
	iQuery TEXT;
BEGIN
	iQuery:=FORMAT ('INSERT INTO ai_pack.chatgpt_log VALUES (DEFAULT, %L, %L, CLOCK_TIMESTAMP(), SESSION_USER, %L, %L) RETURNING log_id', pChatQuery, pInputParams, pReply, pUsageTokens);
	RETURN (SELECT log_id FROM devv5.PG_BACKGROUND_RESULT(devv5.PG_BACKGROUND_LAUNCH (iQuery)) AS (log_id INT4));
END;
$BODY$
LANGUAGE 'plpgsql';