CREATE OR REPLACE FUNCTION admin_pack.CheckLoginCharacters (
	pUserLogin TEXT
	)
RETURNS VOID AS
$BODY$
	/*
	Check login characters:
	1. consist of [a-zA-Z0-9_.-]
	2. minimum length is 5
	*/
BEGIN
	IF pUserLogin !~ '^[[:alnum:]._-]{5,}$' THEN
		RAISE EXCEPTION 'User login must be at least 5 characters in length and consist of [a-zA-Z0-9_.-]';
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql' STRICT IMMUTABLE;