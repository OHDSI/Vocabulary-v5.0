CREATE OR REPLACE FUNCTION admin_pack.VirtualLogIn (
	pUserLogin TEXT,
	pUserPassWord TEXT
)
RETURNS VOID AS
$BODY$
	/*
	Virtual user authorization (start virtual session)
	For more security, the session includes the current schema name and the user's IP address
	NB: A virtual session lives as long as a real one

	Usage:
	SELECT admin_pack.VirtualLogIn ('login','password');
	*/
DECLARE
	iUserCredential RECORD;
	iSessionID TEXT;
BEGIN
	SELECT *
	INTO iUserCredential
	FROM virtual_user vu
	WHERE vu.user_login = pUserLogin
		AND vu.user_password = devv5.CRYPT(pUserPassWord, vu.user_password);

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Incorrect login or/and password';
	END IF;

	IF NOT (iUserCredential.valid_start_date <= CURRENT_DATE AND iUserCredential.valid_end_date > CURRENT_DATE) OR iUserCredential.is_blocked THEN
		RAISE EXCEPTION 'User is blocked';
	END IF;

	--start session
	iSessionID:=GEN_RANDOM_UUID()::TEXT;

	UPDATE virtual_user vu
	SET session_id = devv5.CRYPT(CONCAT (
				SESSION_USER,
				INET_CLIENT_ADDR()::TEXT,
				iSessionID,
				vu.user_login,
				vu.user_password
				), devv5.GEN_SALT('bf'))
	WHERE vu.user_id = iUserCredential.user_id;

	PERFORM SET_CONFIG('virtual_auth.session_id', iSessionID, FALSE);
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = admin_pack, pg_temp;