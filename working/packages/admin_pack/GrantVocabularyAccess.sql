CREATE OR REPLACE FUNCTION admin_pack.GrantVocabularyAccess (
	pUserID INT4,
	pVocabulary_id TEXT,
	pValidStartDate DATE DEFAULT CURRENT_DATE,
	pValidEndDate DATE DEFAULT TO_DATE('20991231', 'YYYYMMDD'),
	pIsBlocked BOOLEAN DEFAULT FALSE
	)
RETURNS VOID AS
$BODY$
	/*
	Grant vocabulary access to specific user. Useful if the user only needs to work with certain vocabularies in manual tables

	Example:
	DO $_$
	BEGIN
		PERFORM admin_pack.GrantVocabularyAccess(
			pUserID          =>admin_pack.GetUserIDByLogin('dev_jdoe'), --user's virtual login
			pVocabulary_id   =>'CPT4', --vocabulary_id
			pValidStartDate  =>NULL, --access to the vocabulary will be granted from the specified day, default CURRENT_DATE
			pValidEndDate    =>NULL, --access to the vocabulary will be granted until the specified expiration date, default 2099-12-31
			pIsBlocked       =>FALSE --you can create a blocked access, can be useful if you want to grant access in advance and then just unset the block flag via ModifyVocabularyAccess()
		);
	END $_$;
	*/
DECLARE
	iUserID CONSTANT INT4:=GetUserID();
	ALL_PRIVILEGES CONSTANT RECORD:=GetAllPrivileges();
	iVocabularyConceptID INT4;
BEGIN
	IF NOT CheckUserPrivilege(ALL_PRIVILEGES.MANAGE_USER) THEN
		RAISE EXCEPTION 'Insufficient privileges';
	END IF;

	IF pValidEndDate > TO_DATE('20991231', 'YYYYMMDD') THEN
		pValidEndDate:=TO_DATE('20991231', 'YYYYMMDD');
	END IF;

	IF pValidStartDate >= pValidEndDate THEN
		RAISE EXCEPTION 'Start date for accessing the vocabulary must be less than the end date %', TO_CHAR(pValidEndDate,'YYYY-MM-DD');
	END IF;

	PERFORM FROM virtual_user vu WHERE vu.user_id = pUserID;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'UserID=% not found', pUserID;
	END IF;

	SELECT v.vocabulary_concept_id
	INTO iVocabularyConceptID
	FROM devv5.vocabulary v
	WHERE v.vocabulary_id = pVocabulary_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'VocabularyID=% not found', pVocabulary_id;
	END IF;

	INSERT INTO virtual_user_vocabulary
	VALUES (
		pUserID,
		iVocabularyConceptID,
		CLOCK_TIMESTAMP(),
		iUserID,
		NULL,
		NULL,
		COALESCE(pValidStartDate, CURRENT_DATE),
		COALESCE(pValidEndDate, TO_DATE('20991231', 'YYYYMMDD')),
		COALESCE(pIsBlocked, FALSE)
		)
	ON CONFLICT DO NOTHING;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Access to this vocabulary already granted';
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = admin_pack, pg_temp;