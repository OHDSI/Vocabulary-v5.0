CREATE OR REPLACE FUNCTION admin_pack.CheckPasswordStrength (
	pPassWord TEXT
	)
RETURNS VOID AS
$BODY$
	/*
	Check password strength:
	1. at least one uppercase letter [A-Z]
	2. at least one lowercase letter [a-z]
	3. at least one special case letter: !`"'№%;:?&*()_+=~/\<>,.[]{}^$#-
	4. at least one digit [0-9]
	5. minimum length is 10
	*/
BEGIN
	IF pPassWord !~ '^(?=.*[A-Z])(?=.*[a-z])(?=.*[!`"''№%;:?&*()_+=~/\<>,.\[\]{}^$#-])(?=.*[0-9]).{10,}$' THEN
		RAISE EXCEPTION 'Password must be at least 10 characters in length, contain at least one uppercase letter, lowercase letter, digit and special character: !`"''№%%;:?&*()_+=~/\<>,.\[\]{}^$#-';
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql' STRICT IMMUTABLE;