CREATE OR REPLACE FUNCTION admin_pack.CreatePrivilege (
	pPrivilegeName TEXT,
	pPrivilegeDescription TEXT
	)
RETURNS INT4 AS
$BODY$
	/*
	Create new privilege

	Example:
	DO $_$
	BEGIN
		PERFORM admin_pack.CreatePrivilege(
			pPrivilegeName         =>'NEW_PRIVILEGE', --name
			pPrivilegeDescription  =>'Privilege for doing some tasks' --description
		);
	END $_$;
	*/
DECLARE
	iUserID CONSTANT INT4:=GetUserID();
	ALL_PRIVILEGES CONSTANT RECORD:=GetAllPrivileges();
	iNewPrivileID INT4;
BEGIN
	pPrivilegeName:=UPPER(NULLIF(TRIM(pPrivilegeName),''));
	pPrivilegeDescription:=NULLIF(TRIM(pPrivilegeDescription),'');

	IF NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_PRIVILEGE) THEN
		RAISE EXCEPTION 'Insufficient privileges';
	END IF;

	IF pPrivilegeName IS NULL OR pPrivilegeDescription IS NULL THEN
		RAISE EXCEPTION 'Privilege name/description cannot be empty';
	END IF;

	PERFORM CheckPrivilegeCharacters(pPrivilegeName);

	INSERT INTO virtual_privilege
	VALUES (
		DEFAULT,
		pPrivilegeName,
		pPrivilegeDescription,
		CLOCK_TIMESTAMP(),
		iUserID,
		NULL,
		NULL,
		FALSE
		)
	ON CONFLICT DO NOTHING
	RETURNING virtual_privilege.privilege_id
	INTO iNewPrivileID;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Privilege already exists';
	END IF;

	RETURN iNewPrivileID;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = admin_pack, pg_temp;