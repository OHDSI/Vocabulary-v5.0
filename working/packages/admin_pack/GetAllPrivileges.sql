CREATE OR REPLACE FUNCTION admin_pack.GetAllPrivileges ()
RETURNS RECORD AS
$BODY$
	/*
	This function "pivotes" the virtual_privilege table, so rows become columns
	Very handy for use in "select ... from ... where col1 = const.value" statements

	Example usage:
	DO $$
	DECLARE
		ALL_PRIVILEGES RECORD;
	BEGIN
		ALL_PRIVILEGES:=admin_pack.GetAllPrivileges();
		RAISE NOTICE '%', ALL_PRIVILEGES.%PRIVILEGE_NAME%;
	END $$;
	*/
DECLARE
	iUserID CONSTANT INT4:=GetUserID(); --just checking the session
	iRet RECORD;
BEGIN
	--here we do not check the validity of the privileges (is_blocked), because we always need the full set to use columns as parameters in other functions
	--but privilege validity is always checked in CheckUserPrivilege
	EXECUTE FORMAT ($$
		SELECT * FROM devv5.CROSSTAB ('SELECT NULL, privilege_name, privilege_id FROM virtual_privilege ORDER BY privilege_id') AS t (dummy_value TEXT, %s)
	$$, (SELECT STRING_AGG(privilege_name || ' INT4', ',' ORDER BY privilege_id) FROM virtual_privilege))
	INTO iRet;

	RETURN iRet;
END;
$BODY$
LANGUAGE 'plpgsql' STABLE SECURITY DEFINER
SET search_path = admin_pack, pg_temp;