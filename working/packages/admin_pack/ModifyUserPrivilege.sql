CREATE OR REPLACE FUNCTION admin_pack.ModifyUserPrivilege (
	pUserID INT4,
	pPrivilegeID INT4,
	pValidStartDate DATE DEFAULT NULL,
	pValidEndDate DATE DEFAULT NULL,
	pIsBlocked BOOLEAN DEFAULT NULL
	)
RETURNS VOID AS
$BODY$
	/*
	Modify privilege for specific user

	Example:
	DO $_$
	BEGIN
		PERFORM admin_pack.ModifyUserPrivilege(
			pUserID          =>admin_pack.GetUserIDByLogin('dev_jdoe'), --user's virtual login
			pPrivilegeID     =>admin_pack.GetPrivilegeIDByName('MANAGE_USER'),
			pValidStartDate  =>NULL, --set NULL if you don't want to change the start date
			pValidEndDate    =>NULL, --set NULL if you don't want to change the end date
			pIsBlocked       =>TRUE --block privilege for the specified user
		);
	END $_$;

	Shorter version:
	DO $_$
	BEGIN
		PERFORM admin_pack.ModifyUserPrivilege(
			pUserID          =>admin_pack.GetUserIDByLogin('dev_jdoe'), --user's virtual login
			pPrivilegeID     =>admin_pack.GetPrivilegeIDByName('MANAGE_USER'),
			pIsBlocked       =>TRUE --block privilege for the specified user
		);
	END $_$;
	*/
DECLARE
	iUserID CONSTANT INT4:=GetUserID();
	ALL_PRIVILEGES CONSTANT RECORD:=GetAllPrivileges();
BEGIN
	IF NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_USER) THEN
		RAISE EXCEPTION 'Insufficient privileges';
	END IF;

	IF pValidEndDate > TO_DATE('20991231', 'YYYYMMDD') THEN
		pValidEndDate:=TO_DATE('20991231', 'YYYYMMDD');
	END IF;

	IF pValidStartDate >= pValidEndDate THEN
		RAISE EXCEPTION 'Start date for the privilege must be less than the end date %', TO_CHAR(pValidEndDate,'YYYY-MM-DD');
	END IF;

	PERFORM FROM virtual_user vu WHERE vu.user_id = pUserID;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'UserID=% not found', pUserID;
	END IF;

	PERFORM FROM virtual_privilege vp WHERE vp.privilege_id = pPrivilegeID AND NOT vp.is_blocked;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'PrivilegeID=% not found or blocked', pPrivilegeID;
	END IF;

	UPDATE virtual_user_privilege vup
	SET modified = CLOCK_TIMESTAMP(),
		modified_by = iUserID,
		valid_start_date = COALESCE(pValidStartDate, vup.valid_start_date),
		valid_end_date = COALESCE(pValidEndDate, vup.valid_end_date),
		is_blocked = COALESCE(pIsBlocked, vup.is_blocked)
	WHERE vup.user_id = pUserID
		AND vup.privilege_id = pPrivilegeID;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Privilege=% not granted to user=%', pPrivilegeID, pUserID;
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = admin_pack, pg_temp;