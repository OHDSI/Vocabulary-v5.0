CREATE OR REPLACE FUNCTION admin_pack.ModifyVocabularyAccess (
	pUserID INT4,
	pVocabulary_id TEXT,
	pValidStartDate DATE DEFAULT NULL,
	pValidEndDate DATE DEFAULT NULL,
	pIsBlocked BOOLEAN DEFAULT NULL
	)
RETURNS VOID AS
$BODY$
	/*
	Modify vocabulary access for specific user

	Example:
	DO $_$
	BEGIN
		PERFORM admin_pack.ModifyVocabularyAccess(
			pUserID          =>admin_pack.GetUserIDByLogin('dev_jdoe'), --user's virtual login
			pVocabulary_id   =>'CPT4', --vocabulary_id for which access is being changed
			pValidStartDate  =>NULL, --by default we don't want to change it (but there may be a situation when you want to correct the start date)
			pValidEndDate    =>NULL, --by default we don't want to change it (but there may be a situation when you want to correct the end date)
			pIsBlocked       =>TRUE --block access
		);
	END $_$;
	
	Shorter version:
	DO $_$
	BEGIN
		PERFORM admin_pack.ModifyVocabularyAccess(
			pUserID          =>admin_pack.GetUserIDByLogin('dev_jdoe'), --user's virtual login
			pVocabulary_id   =>'CPT4', --vocabulary_id for which access is being changed
			pIsBlocked       =>TRUE --block access
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

	UPDATE virtual_user_vocabulary vuv
	SET modified = CLOCK_TIMESTAMP(),
		modified_by = iUserID,
		valid_start_date = COALESCE(pValidStartDate, vuv.valid_start_date),
		valid_end_date = COALESCE(pValidEndDate, vuv.valid_end_date),
		is_blocked = COALESCE(pIsBlocked, vuv.is_blocked)
	WHERE vuv.user_id = pUserID
		AND vuv.vocabulary_concept_id = iVocabularyConceptID;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Access to vocabulary=% not granted to user=%', pVocabulary_id, pUserID;
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = admin_pack, pg_temp;