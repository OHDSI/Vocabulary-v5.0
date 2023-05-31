CREATE OR REPLACE FUNCTION admin_pack.CheckUserPrivilege (
	pPrivilegeID INT4
	)
RETURNS BOOLEAN AS
$BODY$
	/*
	This function checks privileges
	Returns TRUE if the user currently has the privilege (and it is not blocked), otherwise FALSE
	*/
DECLARE
	iUserID CONSTANT INT4:=GetUserID();
BEGIN
	RETURN EXISTS (
		SELECT 1
		FROM virtual_user_privilege vup
		JOIN virtual_privilege vp USING (privilege_id)
		WHERE vup.user_id = iUserID
			AND vup.privilege_id = pPrivilegeID
			AND vup.valid_start_date <= CURRENT_DATE
			AND vup.valid_end_date > CURRENT_DATE
			AND NOT vup.is_blocked
			AND NOT vp.is_blocked
	);
END;
$BODY$
LANGUAGE 'plpgsql' STABLE SECURITY DEFINER
SET search_path = admin_pack, pg_temp;