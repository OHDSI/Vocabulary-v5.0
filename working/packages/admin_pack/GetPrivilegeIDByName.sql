CREATE OR REPLACE FUNCTION admin_pack.GetPrivilegeIDByName (
	pPrivilegeName TEXT
	)
RETURNS INT4 AS
$BODY$
	/*
	Get privilege ID by privilege name
	SELECT admin_pack.GetPrivilegeIDByName('MANAGE_SPECIFIC_VOCABULARY');
	*/
DECLARE
	iPrivilegeID INT4;
BEGIN
	pPrivilegeName:=UPPER(NULLIF(TRIM(pPrivilegeName),''));

	IF pPrivilegeName IS NULL THEN
		RAISE EXCEPTION 'Please provide privilege name';
	END IF;

	SELECT vp.privilege_id
	INTO iPrivilegeID
	FROM virtual_privilege vp
	WHERE vp.privilege_name = pPrivilegeName;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Privilege with name=% not found', pPrivilegeName;
	END IF;

	RETURN iPrivilegeID;
END;
$BODY$
LANGUAGE 'plpgsql' STABLE STRICT SECURITY DEFINER
SET search_path = admin_pack, pg_temp;