CREATE OR REPLACE FUNCTION admin_pack.ModifyPrivilege (
	pPrivilegeID INT4,
	pPrivilegeName TEXT,
	pPrivilegeDescription TEXT,
	pIsBlocked BOOLEAN
	)
RETURNS VOID AS
$BODY$
	/*
	Modify specific privilege

	Example:
	DO $_$
	BEGIN
		PERFORM admin_pack.ModifyPrivilege(
			pPrivilegeID           => admin_pack.GetPrivilegeIDByName('MANAGE_PRIVILEGE'),
			pPrivilegeName         => NULL, --or 'NEW_PRIVILEGE_NAME' <--be careful changing this value, you have to change all functions dependent on this name
			pPrivilegeDescription  => NULL, --or 'New privilege description'
			pIsBlocked             => FALSE --or TRUE if you want to block privilege
		);
	END $_$;
	*/
DECLARE
	iUserID CONSTANT INT4:=GetUserID();
	ALL_PRIVILEGES CONSTANT RECORD:=GetAllPrivileges();
BEGIN
	pPrivilegeName:=UPPER(NULLIF(TRIM(pPrivilegeName),''));
	pPrivilegeDescription:=NULLIF(TRIM(pPrivilegeDescription),'');

	IF NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_PRIVILEGE) THEN
		RAISE EXCEPTION 'Insufficient privileges';
	END IF;

	PERFORM CheckPrivilegeCharacters(pPrivilegeName);

	UPDATE virtual_privilege vp
	SET privilege_name = COALESCE(pPrivilegeName, vp.privilege_name),
		privilege_description = COALESCE(pPrivilegeDescription, vp.privilege_description),
		modified = CLOCK_TIMESTAMP(),
		modified_by = iUserID,
		is_blocked = COALESCE(pIsBlocked, vp.is_blocked)
	WHERE vp.privilege_id = pPrivilegeID;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'PrivilegeID=% not found', pPrivilegeID;
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = admin_pack, pg_temp;