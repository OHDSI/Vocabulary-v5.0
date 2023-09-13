CREATE OR REPLACE FUNCTION admin_pack.ChangeOwnPassword (
	pOldPassWord TEXT,
	pNewPassWord TEXT
	)
RETURNS VOID AS
$BODY$
	/*
	Change own password

	Example:
	DO $_$
	BEGIN
		PERFORM admin_pack.ChangeOwnPassword(
			pOldPassWord  =>'current_password',
			pNewPassWord  =>'new_password'
		);
	END $_$;
	*/
DECLARE
	iUserID CONSTANT INT4:=GetUserID();
BEGIN
	pOldPassWord:=NULLIF(pOldPassWord,'');
	pNewPassWord:=NULLIF(pNewPassWord,'');

	IF pOldPassWord IS NULL THEN
		RAISE EXCEPTION 'Please provide the old password';
	END IF;

	IF pNewPassWord IS NULL THEN
		RAISE EXCEPTION 'New password cannot be empty';
	END IF;

	IF pOldPassWord = pNewPassWord THEN
		RAISE EXCEPTION 'The old and new passwords are the same';
	END IF;

	PERFORM CheckPasswordStrength(pNewPassWord);

	UPDATE virtual_user vu
	SET user_password = devv5.CRYPT(pNewPassWord, devv5.GEN_SALT('bf')),
		modified = CLOCK_TIMESTAMP(),
		modified_by = iUserID,
		session_id = NULL
	WHERE vu.user_id = iUserID
		AND vu.user_password = devv5.CRYPT(pOldPassWord, vu.user_password);

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Incorrect old password';
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = admin_pack, pg_temp;