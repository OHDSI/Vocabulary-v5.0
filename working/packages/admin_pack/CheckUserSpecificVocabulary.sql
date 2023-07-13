CREATE OR REPLACE FUNCTION admin_pack.CheckUserSpecificVocabulary (
	pVocabulary_id TEXT
	)
RETURNS BOOLEAN AS
$BODY$
	/*
	Check if user has access to maintain a specific vocabulary
	Returns TRUE if the user has permissions to the vocabulary, or if the vocabulary is new (not exists in devv5.vocabulary)
	*/
DECLARE
	iUserID CONSTANT INT4:=GetUserID();
BEGIN
	RETURN EXISTS (
		SELECT 1
		FROM virtual_user_vocabulary vuv
		JOIN devv5.vocabulary v USING (vocabulary_concept_id)
		WHERE vuv.user_id = iUserID
			AND vuv.valid_start_date <= CURRENT_DATE
			AND vuv.valid_end_date > CURRENT_DATE
			AND NOT vuv.is_blocked
			AND v.vocabulary_id = pVocabulary_id

		UNION ALL

		SELECT 1
		WHERE NOT EXISTS (
				SELECT 1
				FROM devv5.vocabulary v
				WHERE v.vocabulary_id = pVocabulary_id
				)
	);
END;
$BODY$
LANGUAGE 'plpgsql' STABLE SECURITY DEFINER
SET search_path = admin_pack, pg_temp;