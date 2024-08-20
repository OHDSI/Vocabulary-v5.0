CREATE OR REPLACE FUNCTION vocabulary_pack.StartRelease ()
RETURNS VOID AS
$BODY$
	/*
	The function starts the vocabulary release procedure:
	1. Building a new, fresh ancestor (concept_ancestor table)
	2. Dump of base tables in csv/zip for uploading to Athena
	3. Creating a release report, automatically publishing it in OHDSI/Vocabulary-v5.0/releases
	4. Creating a local copy of the base tables in the prodv5 schema (for internal usage e.g. for qa_tests.get_summary function)
	5. Updating the latest_release_date field for vocabularies that were released
	6. Sending administrative emails about release status
	*/
DECLARE
	iCRLF VARCHAR(4) := '<br>';
	iEmail CONSTANT VARCHAR(1000) := (SELECT var_value FROM devv5.config$ WHERE var_name='vocabulary_release_iEmail');
	iRet TEXT;
	iVocabsArr TEXT[];
BEGIN
	PERFORM vocabulary_pack.pConceptAncestor();
	UPDATE vocabulary SET vocabulary_version = 'v5.0 '||TO_CHAR(CURRENT_DATE,'DD-MON-YY') WHERE vocabulary_id = 'None';
	PERFORM vocabulary_pack.pCreateBaseDump();

	SELECT ARRAY_AGG(DISTINCT c_devv5.vocabulary_id)
	INTO iVocabsArr
	FROM devv5.concept c_devv5
	LEFT JOIN prodv5.concept c_prod USING (concept_id)
	WHERE ROW(c_prod.*) IS DISTINCT FROM ROW(c_devv5.*);

	PERFORM vocabulary_pack.CreateReleaseReport();
	PERFORM vocabulary_pack.CreateLocalPROD();

	iRet:= 'Release completed';

	IF iVocabsArr IS NOT NULL THEN
		iRet:= iRet || iCRLF || 'Affected vocabularies: ' ||  ARRAY_TO_STRING(iVocabsArr,', ');
		--store latest_release_date
		UPDATE vocabulary
		SET vocabulary_params = COALESCE(vocabulary_params, JSONB_BUILD_OBJECT()) || JSONB_BUILD_OBJECT('latest_release_date', TO_CHAR(CURRENT_DATE,'YYYYMMDD'))
		WHERE vocabulary_id = ANY (iVocabsArr);
	END IF;

	PERFORM devv5.SendMailHTML (iEmail, 'Release status [OK]', iRet);

	EXCEPTION WHEN OTHERS THEN
		GET STACKED DIAGNOSTICS iRet = PG_EXCEPTION_CONTEXT;
		iRet:='ERROR: '||SQLERRM||iCRLF||'CONTEXT: '||REGEXP_REPLACE(iRet, '[\r\n]+', iCRLF, 'g');
		iRet:= LEFT ('Release completed with errors:'||iCRLF||'<b>'||iRet||'</b>', 5000);
		PERFORM devv5.SendMailHTML (iEmail, 'Release status [ERROR]', iRet);
END;
$BODY$
LANGUAGE 'plpgsql'
SET client_min_messages = error;