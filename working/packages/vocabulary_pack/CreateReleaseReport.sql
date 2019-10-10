CREATE OR REPLACE FUNCTION vocabulary_pack.CreateReleaseReport (
)
RETURNS void AS
$body$
/*
	This procedure creates the release reports
*/
declare
	crlf VARCHAR(4) := '<br>';
	email CONSTANT VARCHAR(1000) := (SELECT var_value FROM devv5.config$ WHERE var_name='service_email');
	cGitToken CONSTANT VARCHAR(100) := (SELECT var_value FROM devv5.config$ WHERE var_name='git_credentials')::json->>'git_token';
	cGitRepository CONSTANT VARCHAR(100) := (SELECT var_value FROM devv5.config$ WHERE var_name='git_credentials')::json->>'git_repository';
	cGitReleaseTag CONSTANT VARCHAR(100) := (SELECT 'v'||TO_CHAR(CURRENT_DATE,'yyyymmdd')||'_'||EXTRACT(epoch FROM NOW()::TIMESTAMP(0))::VARCHAR);
	EMPTY_RESULT BOOLEAN := TRUE;
	cRet TEXT;
	cFullRet TEXT;
	cTitle TEXT;
	cResult RECORD;
	cRet_git TEXT;
	cFooter CONSTANT VARCHAR(1000) := E'\r\n\***\r\nIf you have any questions, please try to find the answers on http://forums.ohdsi.org. If you can\'t find it, please ask here: http://forums.ohdsi.org/t/vocabulary-release-questions/6650';
	cEmptyResultText CONSTANT VARCHAR(1000) :=E'\r\nthere were no changes here\r\n';
begin
	cTitle:=E'\r\n# Domain changes\r\n';
	cRet:=E'<table>\r\n';
	--column names
	cRet:=cRet||E'<tr><th><b>vocabulary_id</b></th><th><b>old_domain_id</b></th><th><b>new_domain_id</b></th><th><b>count</b></th></tr>\r\n';
	FOR cResult IN 
	(
		SELECT *
		FROM qa_tests.get_domain_changes() t
		ORDER BY t.vocabulary_id,
			t.old_domain_id,
			t.new_domain_id
	) LOOP
		--row
		cRet:=cRet||'<tr>';
		cRet:=cRet||'<td>'||cResult.vocabulary_id||'</td>';
		cRet:=cRet||'<td>'||CONCAT(cResult.old_domain_id,'</td>');
		cRet:=cRet||'<td>'||CONCAT(cResult.new_domain_id,'</td>');
		cRet:=cRet||'<td>'||cResult.cnt||'</td>';
		--end row
		cRet:=cRet||E'</tr>\r\n';
		EMPTY_RESULT:=FALSE;
	END LOOP;
	cRet:=cRet||E'</table>\r\n';
	
	IF EMPTY_RESULT THEN
		cFullRet:=cTitle||cEmptyResultText;
	ELSE
		cFullRet:=cTitle||cRet;
	END IF;
	
	EMPTY_RESULT:=TRUE;
	cTitle:=E'\r\n# Newly added concepts grouped by Vocabulary_id and Domain\r\n';
	cRet:=E'<table>\r\n';
	--column names
	cRet:=cRet||E'<tr><th><b>vocabulary_id</b></th><th><b>domain_id</b></th><th><b>count</b></th></tr>\r\n';
	FOR cResult IN 
	(
		SELECT *
		FROM qa_tests.get_newly_concepts() t
		ORDER BY t.vocabulary_id,
			t.domain_id
	) LOOP
		--row
		cRet:=cRet||'<tr>';
		cRet:=cRet||'<td>'||cResult.vocabulary_id||'</td>';
		cRet:=cRet||'<td>'||CONCAT(cResult.domain_id,'</td>');
		cRet:=cRet||'<td>'||cResult.cnt||'</td>';
		--end row
		cRet:=cRet||E'</tr>\r\n';
		EMPTY_RESULT:=FALSE;
	END LOOP;
	cRet:=cRet||E'</table>\r\n';
	
	IF EMPTY_RESULT THEN
		cFullRet:=cFullRet||cTitle||cEmptyResultText;
	ELSE
		cFullRet:=cFullRet||cTitle||cRet;
	END IF;
	
	EMPTY_RESULT:=TRUE;
	cTitle:=E'\r\n# Standard concept changes\r\n';
	cRet:=E'<table>\r\n';
	--column names
	cRet:=cRet||E'<tr><th><b>vocabulary_id</b></th><th><b>old_standard_concept</b></th><th><b>new_standard_concept</b></th><th><b>count</b></th></tr>\r\n';
	FOR cResult IN 
	(
		SELECT *
		FROM qa_tests.get_standard_concept_changes() t
		ORDER BY t.vocabulary_id,
			t.cnt DESC
	) LOOP
		--row
		cRet:=cRet||'<tr>';
		cRet:=cRet||'<td>'||cResult.vocabulary_id||'</td>';
		cRet:=cRet||'<td>'||CONCAT(cResult.old_standard_concept,'</td>');
		cRet:=cRet||'<td>'||CONCAT(cResult.new_standard_concept,'</td>');
		cRet:=cRet||'<td>'||cResult.cnt||'</td>';
		--end row
		cRet:=cRet||E'</tr>\r\n';
		EMPTY_RESULT:=FALSE;
	END LOOP;
	cRet:=cRet||E'</table>\r\n';
	
	IF EMPTY_RESULT THEN
		cFullRet:=cFullRet||cTitle||cEmptyResultText;
	ELSE
		cFullRet:=cFullRet||cTitle||cRet;
	END IF;
	
	EMPTY_RESULT=TRUE;
	cTitle:=E'\r\n# Newly added concepts and their standard concept status\r\n';
	cRet:=E'<table>\r\n';
	--column names
	cRet:=cRet||E'<tr><th><b>vocabulary_id</b></th><th><b>new_standard_concept</b></th><th><b>count</b></th></tr>\r\n';
	FOR cResult IN 
	(
		SELECT *
		FROM qa_tests.get_newly_concepts_standard_concept_status() t
		ORDER BY t.vocabulary_id,
			t.cnt
	) LOOP
		--row
		cRet:=cRet||'<tr>';
		cRet:=cRet||'<td>'||cResult.vocabulary_id||'</td>';
		cRet:=cRet||'<td>'||CONCAT(cResult.new_standard_concept,'</td>');
		cRet:=cRet||'<td>'||cResult.cnt||'</td>';
		--end row
		cRet:=cRet||E'</tr>\r\n';
		EMPTY_RESULT:=FALSE;
	END LOOP;
	cRet:=cRet||E'</table>\r\n';
	
	IF EMPTY_RESULT THEN
		cFullRet:=cFullRet||cTitle||cEmptyResultText;
	ELSE
		cFullRet:=cFullRet||cTitle||cRet;
	END IF;
	
	EMPTY_RESULT=TRUE;
	cTitle:=E'\r\n# Changes of concept mapping status grouped by target domain\r\n';
	cRet:=E'<table>\r\n';
	--column names
	cRet:=cRet||E'<tr><th><b>vocabulary_id</b></th><th><b>Old target Domain/Status</b></th><th><b>New target Domain/Status</b></th><th><b>count</b></th></tr>\r\n';
	FOR cResult IN 
	(
		SELECT *
		FROM qa_tests.get_changes_concept_mapping() t
		ORDER BY t.vocabulary_id,
			t.old_mapped_domains,
			t.new_mapped_domains
	) LOOP
		--row
		cRet:=cRet||'<tr>';
		cRet:=cRet||'<td>'||cResult.vocabulary_id||'</td>';
		cRet:=cRet||'<td>'||CONCAT(cResult.old_mapped_domains,'</td>');
		cRet:=cRet||'<td>'||CONCAT(cResult.new_mapped_domains,'</td>');
		cRet:=cRet||'<td>'||cResult.cnt||'</td>';
		--end row
		cRet:=cRet||E'</tr>\r\n';
		EMPTY_RESULT:=FALSE;
	END LOOP;
	cRet:=cRet||E'</table>\r\n';
	
	IF EMPTY_RESULT THEN
		cFullRet:=cFullRet||cTitle||cEmptyResultText;
	ELSE
		cFullRet:=cFullRet||cTitle||cRet;
	END IF;
	
	EMPTY_RESULT=TRUE;
	cTitle:=E'\r\n# New vocabularies added\r\n';
	cRet:=E'<table>\r\n';
	--column names
	cRet:=cRet||E'<tr><th><b>vocabulary_id</b></th>\r\n';
	FOR cResult IN 
	(
		SELECT vocabulary_id
		FROM concept

		EXCEPT

		SELECT vocabulary_id
		FROM prodv5.concept
		ORDER BY vocabulary_id
	) LOOP
		--row
		cRet:=cRet||'<tr>';
		cRet:=cRet||'<td>'||cResult.vocabulary_id||'</td>';
		--end row
		cRet:=cRet||E'</tr>\r\n';
		EMPTY_RESULT:=FALSE;
	END LOOP;
	cRet:=cRet||E'</table>\r\n';
	
	IF EMPTY_RESULT THEN
		cFullRet:=cFullRet||cTitle||cEmptyResultText;
	ELSE
		cFullRet:=cFullRet||cTitle||cRet;
	END IF;
	
	cFullRet:=cFullRet||cFooter;
	
	SELECT vocabulary_pack.py_git_release (cGitRepository,'Release notes v'||TO_CHAR(CURRENT_DATE,'yyyymmdd'), cFullRet, cGitReleaseTag, cGitToken) into cRet_git;
	IF NOT cRet_git ~ '^[\d]+$' THEN
		cRet := SUBSTR ('Report completed with errors:'||crlf||'<b>'||cRet_git||'</b>', 1, 5000);
		perform devv5.SendMailHTML (email, 'Release status [Reports POST ERROR]', cRet);
	END IF;
	
	EXCEPTION
	WHEN OTHERS
	THEN
	GET STACKED DIAGNOSTICS cRet = PG_EXCEPTION_CONTEXT;
		cRet:='ERROR: '||SQLERRM||crlf||'CONTEXT: '||regexp_replace(cRet, '\r|\n|\r\n', crlf, 'g');
		cRet := SUBSTR ('Report completed with errors:'||crlf||'<b>'||cRet||'</b>', 1, 5000);
		perform devv5.SendMailHTML (email, 'Release status [Reports ERROR]', cRet);
end;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;