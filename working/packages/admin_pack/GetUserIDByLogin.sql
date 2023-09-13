CREATE OR REPLACE FUNCTION admin_pack.GetUserIDByLogin (
	pUserLogin TEXT
	)
RETURNS INT4 AS
$BODY$
	/*
	Get user ID by user login
	SELECT admin_pack.GetUserIDByLogin('dev_jdoe');
	*/
DECLARE
	iUserID INT4;
BEGIN
	pUserLogin:=NULLIF(TRIM(pUserLogin),'');

	IF pUserLogin IS NULL THEN
		RAISE EXCEPTION 'Please provide user login';
	END IF;

	SELECT vu.user_id
	INTO iUserID
	FROM virtual_user vu
	WHERE vu.user_login = pUserLogin;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'User with login=% not found', pUserLogin;
	END IF;

	RETURN iUserID;
END;
$BODY$
LANGUAGE 'plpgsql' STABLE STRICT SECURITY DEFINER
SET search_path = admin_pack, pg_temp;