CREATE OR REPLACE FUNCTION admin_pack.GrantPrivilege (
	pUserID INT4,
	pPrivilegeID INT4,
	pValidStartDate DATE DEFAULT CURRENT_DATE,
	pValidEndDate DATE DEFAULT TO_DATE('20991231', 'YYYYMMDD'),
	pIsBlocked BOOLEAN DEFAULT FALSE
	)
RETURNS VOID AS
$BODY$
	/*
	Grant privilege to specific user

	Example:
	DO $_$
	BEGIN
		PERFORM admin_pack.GrantPrivilege(
			pUserID          =>admin_pack.GetUserIDByLogin('dev_jdoe'), --user's virtual login
			pPrivilegeID     =>admin_pack.GetPrivilegeIDByName('MANAGE_ANY_VOCABULARY'),
			pValidStartDate  =>NULL, --access will be granted from the specified day, default CURRENT_DATE
			pValidEndDate    =>NULL, --access will be granted until the specified expiration date, default 2099-12-31
			pIsBlocked       =>FALSE --you can create a blocked access, can be useful if you want to grant access in advance and then just unset the block flag via ModifyUserPrivilege()
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

	INSERT INTO virtual_user_privilege
	VALUES (
		pUserID,
		pPrivilegeID,
		CLOCK_TIMESTAMP(),
		iUserID,
		NULL,
		NULL,
		COALESCE(pValidStartDate, CURRENT_DATE),
		COALESCE(pValidEndDate, TO_DATE('20991231', 'YYYYMMDD')),
		COALESCE(pIsBlocked, FALSE)
		)
	ON CONFLICT DO NOTHING;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Privilege already granted';
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = admin_pack, pg_temp;