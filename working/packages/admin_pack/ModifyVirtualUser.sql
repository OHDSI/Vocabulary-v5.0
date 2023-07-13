CREATE OR REPLACE FUNCTION admin_pack.ModifyVirtualUser (
	pUserID INT4,
	pUserLogin TEXT DEFAULT NULL,
	pUserName TEXT DEFAULT NULL,
	pUserDescription TEXT DEFAULT NULL,
	pPassWord TEXT DEFAULT NULL,
	pEmail TEXT DEFAULT NULL,
	pValidStartDate DATE DEFAULT NULL,
	pValidEndDate DATE DEFAULT NULL,
	pIsBlocked BOOLEAN DEFAULT NULL
	)
RETURNS VOID AS
$BODY$
	/*
	Modify specific user

	Example:
	DO $_$
	BEGIN
		PERFORM admin_pack.ModifyVirtualUser(
			pUserID           =>admin_pack.GetUserIDByLogin('dev_jdoe'), --user's virtual login
			pUserLogin        =>NULL, --set NULL if you don't want to change the user's login
			pUserName         =>NULL, --set NULL if you don't want to change the user's name
			pUserDescription  =>NULL, --set NULL if you don't want to change the user's description
			pPassWord         =>NULL, --set NULL if you don't want to change the user's password
			pEmail            =>NULL, --set NULL if you don't want to change the user's e-mail
			pValidStartDate   =>NULL, --set NULL if you don't want to change the start date
			pValidEndDate     =>NULL, --set NULL if you don't want to change the end date
			pIsBlocked        =>TRUE --just block specified user
		);
	END $_$;
	
	Shorter version:
	DO $_$
	BEGIN
		PERFORM admin_pack.ModifyVirtualUser(
			pUserID           =>admin_pack.GetUserIDByLogin('dev_jdoe'), --user's virtual login
			pIsBlocked        =>TRUE --just block specified user
		);
	END $_$;
	*/
DECLARE
	iUserID CONSTANT INT4:=GetUserID();
	ALL_PRIVILEGES CONSTANT RECORD:=GetAllPrivileges();
BEGIN
	pUserLogin:=NULLIF(TRIM(pUserLogin),'');
	pPassWord:=NULLIF(pPassWord,'');
	pUserName:=NULLIF(TRIM(pUserName),'');
	pUserDescription:=NULLIF(TRIM(pUserDescription),'');
	pEmail:=NULLIF(TRIM(pEmail),'');

	IF NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_USER) THEN
		RAISE EXCEPTION 'Insufficient privileges';
	END IF;

	PERFORM CheckLoginCharacters(pUserLogin);
	PERFORM CheckPasswordStrength(pPassWord);
	PERFORM CheckEmailCharacters(pEmail);

	IF pValidEndDate > TO_DATE('20991231', 'YYYYMMDD') THEN
		pValidEndDate:=TO_DATE('20991231', 'YYYYMMDD');
	END IF;

	IF pValidStartDate >= pValidEndDate THEN
		RAISE EXCEPTION 'Start date for the privilege must be less than the end date %', TO_CHAR(pValidEndDate,'YYYY-MM-DD');
	END IF;

	IF pUserID = 1 THEN
		RAISE EXCEPTION 'You cannot change the SYSTEM user';
	END IF;

	UPDATE virtual_user vu
	SET user_login = COALESCE(pUserLogin, vu.user_login),
		user_name = COALESCE(pUserName, vu.user_name),
		user_description = COALESCE(pUserDescription, vu.user_description),
		user_password = COALESCE(devv5.CRYPT(pPassWord, devv5.GEN_SALT('bf')), vu.user_password),
		user_email = COALESCE(pEmail, vu.user_email),
		modified = CLOCK_TIMESTAMP(),
		modified_by = iUserID,
		valid_start_date = COALESCE(pValidStartDate, vu.valid_start_date),
		valid_end_date = COALESCE(pValidEndDate, vu.valid_end_date),
		is_blocked = COALESCE(pIsBlocked, vu.is_blocked)
	WHERE vu.user_id = pUserID;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'UserID=% not found', pUserID;
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = admin_pack, pg_temp;