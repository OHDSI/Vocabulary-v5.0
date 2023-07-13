CREATE OR REPLACE FUNCTION admin_pack.GetUserID ()
RETURNS INT4 AS
$BODY$
	/*
	Get user id by session

	SELECT admin_pack.GetUserID();
	*/
DECLARE
	iSessionID CONSTANT TEXT:=CURRENT_SETTING('virtual_auth.session_id', TRUE);
	iUserCredential RECORD;
BEGIN
	IF SESSION_USER='devv5' THEN
		--Under devv5 we can work without authorization (as SYSTEM user)
		RETURN 1;
	END IF;

	SELECT *
	INTO iUserCredential
	FROM virtual_user vu
	WHERE vu.session_id = devv5.CRYPT(CONCAT (
				/*
				For greater security, the session depends, among other things, on the IP address, the current user login and password
				Therefore, if any of this changes - the session will be invalidated
				*/
				SESSION_USER,
				INET_CLIENT_ADDR()::TEXT,
				iSessionID,
				vu.user_login,
				vu.user_password
				), vu.session_id);

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Session not found, please do a virtual login first';
	END IF;

	IF NOT (CURRENT_DATE >= iUserCredential.valid_start_date AND CURRENT_DATE < iUserCredential.valid_end_date) OR iUserCredential.is_blocked THEN
		RAISE EXCEPTION 'User is blocked';
	END IF;

	RETURN iUserCredential.user_id;
END;
$BODY$
LANGUAGE 'plpgsql' STABLE SECURITY DEFINER
SET search_path = admin_pack, pg_temp;