CREATE OR REPLACE FUNCTION admin_pack.GetUserPrivileges ()
RETURNS TABLE (
	user_login TEXT,
	user_name TEXT,
	user_description TEXT,
	is_user_active BOOLEAN,
	privilege_name TEXT,
	privilege_description TEXT,
	is_privilege_active BOOLEAN,
	is_privilege_alive BOOLEAN,
	active_granted_vocabularies TEXT
) AS
$BODY$
	/*
	Shows all users with their privileges
	Some explanations:
		is_user_active - can the user login now (the current date is within the user's valid date range and the user is not blocked)?
		is_privilege_active - can the user use this privilege now (the current date is within the privilege's valid date range and the privilege is not blocked)?
		is_privilege_alive - the privilege can be blocked by itself (globally) and then it doesn't matter if it is assigned to someone or not - it will not work

	Example:
	SELECT *
	FROM admin_pack.GetUserPrivileges()
	ORDER BY is_user_active DESC,
		user_login,
		is_privilege_alive DESC,
		is_privilege_active DESC,
		privilege_name;
	*/
DECLARE
	iUserID CONSTANT INT4:=GetUserID();
	ALL_PRIVILEGES CONSTANT RECORD:=GetAllPrivileges();
BEGIN
	IF NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_USER) THEN
		RAISE EXCEPTION 'Insufficient privileges';
	END IF;

	RETURN QUERY
	SELECT s0.user_login,
		s0.user_name,
		s0.user_description,
		s0.is_user_active,
		s0.privilege_name,
		s0.privilege_description,
		s0.is_privilege_active,
		s0.is_privilege_alive,
		STRING_AGG(s0.vocabulary_id, ', ' ORDER BY s0.vocabulary_id) FILTER(WHERE s0.is_vocabulary_access_active) AS active_granted_vocabularies
	FROM (
		SELECT vu.user_login,
			vu.user_name,
			vu.user_description,
			(
				vu.valid_start_date <= CURRENT_DATE
				AND vu.valid_end_date > CURRENT_DATE
				AND NOT vu.is_blocked
				) AS is_user_active,
			vp.privilege_name,
			vp.privilege_description,
			(
				vup.valid_start_date <= CURRENT_DATE
				AND vup.valid_end_date > CURRENT_DATE
				AND NOT vup.is_blocked
				) AS is_privilege_active,
			NOT vp.is_blocked AS is_privilege_alive,
			v.vocabulary_id,
			(
				vuv.valid_start_date <= CURRENT_DATE
				AND vuv.valid_end_date > CURRENT_DATE
				AND NOT vuv.is_blocked
				) AS is_vocabulary_access_active
		FROM virtual_user vu
		LEFT JOIN virtual_user_vocabulary vuv USING (user_id)
		LEFT JOIN devv5.vocabulary v USING (vocabulary_concept_id)
		LEFT JOIN virtual_user_privilege vup USING (user_id)
		LEFT JOIN virtual_privilege vp USING (privilege_id)
		WHERE vu.user_id <> 1 --exclude SYSTEM user
		) s0
	GROUP BY s0.user_login,
		s0.user_name,
		s0.user_description,
		s0.is_user_active,
		s0.privilege_name,
		s0.privilege_description,
		s0.is_privilege_active,
		s0.is_privilege_alive;
END;
$BODY$
LANGUAGE 'plpgsql' STABLE SECURITY DEFINER
SET search_path = admin_pack, pg_temp;