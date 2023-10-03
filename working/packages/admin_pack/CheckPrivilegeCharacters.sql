CREATE OR REPLACE FUNCTION admin_pack.CheckPrivilegeCharacters (
	pPrivilegeName TEXT
	)
RETURNS VOID AS
$BODY$
	/*
	Check privilege characters:
	1. consist of [A-Z0-9_]
	2. minimum length is 5
	*/
BEGIN
	IF pPrivilegeName !~ '^[A-Z0-9_]{5,}$' THEN
		RAISE EXCEPTION 'Privilege name must be at least 5 characters in length and consist of [A-Z0-9_]';
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql' STRICT IMMUTABLE;