CREATE OR REPLACE FUNCTION vocabulary_pack.pManualConceptAncestor (
    pVocabularies TEXT, 
    pIncludeNonStandard BOOLEAN DEFAULT FALSE,
    pIncludeInvalidReason BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS
$BODY$
	/*
	The function allows to build a concept ancestor using selected vocabularies (pVocabularies - comma separated vocabulary_id)
	Example:
	DO $_$
	BEGIN
		PERFORM vocabulary_pack.pManualConceptAncestor(pVocabularies=>'CVX,SNOMED,RxNorm');
	END $_$;
	*/
DECLARE
	crlf TEXT:= '<br>';
	iSmallCA_emails TEXT:=(SELECT var_value FROM devv5.config$ WHERE var_name='concept_ancestor_email');
	cRet TEXT;
	cRet2 TEXT;
	cStartTime TIMESTAMP:=CLOCK_TIMESTAMP();
	cWorkTime NUMERIC;
BEGIN
	PERFORM vocabulary_pack.ConceptAncestorCore(pVocabularies, FALSE, pIncludeNonStandard, pIncludeInvalidReason);

	cWorkTime:=ROUND((EXTRACT(EPOCH FROM CLOCK_TIMESTAMP()-cStartTime)/60)::NUMERIC,1);
	PERFORM devv5.SendMailHTML (
        iSmallCA_emails, 
        'Manual concept ancestor in '||UPPER(CURRENT_SCHEMA)||' [ok]', 
        'Manual concept ancestor in '||UPPER(CURRENT_SCHEMA)||' completed'||crlf||
        CASE WHEN pIncludeNonStandard THEN 'incliding non-standard concepts' ELSE '' END||crlf||
        CASE WHEN pIncludeInvalidReason THEN 'including invalid reason ' ELSE '' END||crlf||
        'Execution time: '||cWorkTime||' min'
        
    );

	EXCEPTION WHEN OTHERS THEN
		GET STACKED DIAGNOSTICS cRet = PG_EXCEPTION_CONTEXT, cRet2 = PG_EXCEPTION_DETAIL;
		cRet:='ERROR: '||SQLERRM||crlf||'DETAIL: '||cRet2||crlf||'CONTEXT: '||REGEXP_REPLACE(cRet, '\r|\n|\r\n', crlf, 'g');
		cRet := SUBSTR ('Manual concept ancestor completed with errors:'||crlf||'<b>'||cRet||'</b>', 1, 10000);
		PERFORM devv5.SendMailHTML (iSmallCA_emails, 'Manual concept ancestor in '||UPPER(CURRENT_SCHEMA)||' [error]', cRet);
END;
$BODY$
LANGUAGE 'plpgsql'
SET client_min_messages = error;