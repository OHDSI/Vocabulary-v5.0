CREATE OR REPLACE FUNCTION admin_pack.CreateVirtualUser (
	pUserLogin TEXT,
	pUserName TEXT,
	pUserDescription TEXT,
	pPassWord TEXT,
	pEmail TEXT DEFAULT NULL,
	pValidStartDate DATE DEFAULT CURRENT_DATE,
	pValidEndDate DATE DEFAULT TO_DATE('20991231', 'YYYYMMDD'),
	pIsBlocked BOOLEAN DEFAULT FALSE
	)
RETURNS INT4 AS
$BODY$
	/*
	Virtual user registration

	Examples:
	1. Creating an active user
	DO $_$
	BEGIN
		PERFORM admin_pack.CreateVirtualUser(
			pUserLogin       =>'dev_jdoe', --it is better to create a login that matches the real login in the database (if applicable)
			pUserName        =>'John Doe', --full name
			pUserDescription =>'Vocabulary Team', --medical, customer, some comment, etc
			pPassWord        =>'password', --any strong password (has nothing to do with the real database password)
			pEmail           =>'jdoe@e-mail.com', --you can specify the user's e-mail (default NULL)
			pValidStartDate  =>NULL, --default CURRENT_DATE
			pValidEndDate    =>NULL, --default 2099-12-31
			pIsBlocked       =>FALSE --you can create a blocked user, can be useful if you want to create a user in advance and then just unset the block flag via ModifyVirtualUser()
		);
	END $_$;

	2. Creating a user with a specific time interval of activity
	DO $_$
	BEGIN
		PERFORM admin_pack.CreateVirtualUser(
			pUserLogin       =>'dev_jdoe',
			pUserName        =>'John Doe',
			pUserDescription =>'Vocabulary Team',
			pPassWord        =>'password',
			pEmail           =>'jdoe@e-mail.com',
			pValidStartDate  =>TO_DATE('20240101', 'YYYYMMDD'),
			pValidEndDate    =>TO_DATE('20240201', 'YYYYMMDD'),
			pIsBlocked       =>FALSE
		);
	END $_$;
	*/
DECLARE
	iUserID CONSTANT INT4:=GetUserID();
	ALL_PRIVILEGES CONSTANT RECORD:=GetAllPrivileges();
	iNewUserID INT4;
BEGIN
	pUserLogin:=NULLIF(TRIM(pUserLogin),'');
	pPassWord:=NULLIF(pPassWord,'');
	pUserName:=NULLIF(TRIM(pUserName),'');
	pUserDescription:=NULLIF(TRIM(pUserDescription),'');
	pEmail:=NULLIF(TRIM(pEmail),'');

	IF NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_USER) THEN
		RAISE EXCEPTION 'Insufficient privileges';
	END IF;

	IF pUserLogin IS NULL OR pPassWord IS NULL THEN
		RAISE EXCEPTION 'User or/and password cannot be empty';
	END IF;

	PERFORM CheckLoginCharacters(pUserLogin);
	PERFORM CheckPasswordStrength(pPassWord);
	PERFORM CheckEmailCharacters(pEmail);

	IF pUserName IS NULL THEN
		RAISE EXCEPTION 'Please provide username';
	END IF;

	INSERT INTO virtual_user
	VALUES (
		DEFAULT,
		pUserLogin,
		pUserName,
		pUserDescription,
		devv5.CRYPT(pPassWord, devv5.GEN_SALT('bf')),
		pEmail,
		CLOCK_TIMESTAMP(),
		iUserID,
		NULL,
		NULL,
		COALESCE(pValidStartDate, CURRENT_DATE),
		COALESCE(pValidEndDate, TO_DATE('20991231', 'YYYYMMDD')),
		COALESCE(pIsBlocked, FALSE)
		)
	ON CONFLICT DO NOTHING
	RETURNING virtual_user.user_id
	INTO iNewUserID;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'User already exists';
	END IF;

	RETURN iNewUserID;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = admin_pack, pg_temp;