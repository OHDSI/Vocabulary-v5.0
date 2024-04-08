CREATE OR REPLACE FUNCTION skype_pack.WriteErrorLog (pErrorText TEXT, pModuleID TEXT, pQueryLogID INT4 DEFAULT NULL)
RETURNS VOID AS
$BODY$
	/*
	Logs writer with storing id from the query table, useful for debugging issues
	*/
DECLARE
	iLogID INT4;
BEGIN
	INSERT INTO skype_error_log
	VALUES (
		DEFAULT ,
		CLOCK_TIMESTAMP(),
		pQueryLogID,
		pModuleID,
		pErrorText
	);
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = skype_pack, pg_temp;

REVOKE EXECUTE ON FUNCTION skype_pack.WriteErrorLog FROM PUBLIC;