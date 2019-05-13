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
		SELECT new.vocabulary_id,
			old.domain_id AS old_domain_id,
			new.domain_id AS new_domain_id,
			count(*) AS cnt
		FROM concept new
		JOIN prodv5.concept old ON old.concept_id = new.concept_id
			AND new.domain_id <> old.domain_id
		GROUP BY new.vocabulary_id,
			old.domain_id,
			new.domain_id
		ORDER BY new.vocabulary_id,
			old.domain_id,
			new.domain_id
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
		SELECT new.vocabulary_id,
			new.domain_id,
			count(*) AS cnt
		FROM concept new
		LEFT JOIN prodv5.concept old ON old.concept_id = new.concept_id
		WHERE old.concept_id IS NULL
			AND new.domain_id <> 'Metadata'
		GROUP BY new.vocabulary_id,
			new.domain_id
		ORDER BY new.vocabulary_id,
			new.domain_id
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
		SELECT vocabulary_id,
			CASE 
				WHEN i.old_standard_concept = 'S'
					THEN 'Standard'
				WHEN i.old_standard_concept = 'C'
					THEN 'Classification'
				WHEN i.old_standard_concept IS NULL
					AND i.old_relationship_id = 'Maps to'
					THEN 'Non-standard with mapping'
				ELSE 'Non-standard without mapping'
				END AS old_standard_concept,
			CASE 
				WHEN i.new_standard_concept = 'S'
					THEN 'Standard'
				WHEN i.new_standard_concept = 'C'
					THEN 'Classification'
				WHEN i.new_standard_concept IS NULL
					AND i.new_relationship_id = 'Maps to'
					THEN 'Non-standard with mapping'
				ELSE 'Non-standard without mapping'
				END AS new_standard_concept,
			i.cnt
		FROM (
			SELECT new.vocabulary_id,
				old.standard_concept AS old_standard_concept,
				r_old.relationship_id AS old_relationship_id,
				new.standard_concept AS new_standard_concept,
				r.relationship_id AS new_relationship_id,
				count(*) AS cnt
			FROM concept new
			JOIN prodv5.concept old ON old.concept_id = new.concept_id
				AND COALESCE(old.standard_concept, 'X') <> COALESCE(new.standard_concept, 'X')
			LEFT JOIN prodv5.concept_relationship r_old ON r_old.concept_id_1 = new.concept_id
				AND r_old.relationship_id = 'Maps to'
				AND r_old.invalid_reason IS NULL
				AND r_old.concept_id_1 <> r_old.concept_id_2
			LEFT JOIN concept_relationship r ON r.concept_id_1 = new.concept_id
				AND r.relationship_id = 'Maps to'
				AND r.invalid_reason IS NULL
				AND r.concept_id_1 <> r.concept_id_2
			GROUP BY new.vocabulary_id,
				new.standard_concept,
				old.standard_concept,
				r_old.relationship_id,
				r.relationship_id
			) AS i
		ORDER BY i.vocabulary_id,
			i.cnt DESC
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
		SELECT new.vocabulary_id,
			CASE 
				WHEN new.standard_concept = 'S'
					THEN 'Standard'
				WHEN new.standard_concept = 'C'
					THEN 'Classification'
				WHEN new.standard_concept IS NULL
					AND r.relationship_id = 'Maps to'
					THEN 'Non-standard with mapping'
				ELSE 'Non-standard without mapping'
				END AS new_standard_concept,
			count(*) AS cnt
		FROM concept new
		LEFT JOIN prodv5.concept old ON old.concept_id = new.concept_id
		LEFT JOIN concept_relationship r ON r.concept_id_1 = new.concept_id
			AND relationship_id = 'Maps to'
			AND r.invalid_reason IS NULL
			AND r.concept_id_1 <> r.concept_id_2
		WHERE old.concept_id IS NULL
		GROUP BY new.vocabulary_id,
			new.standard_concept,
			r.relationship_id
		ORDER BY vocabulary_id,
			cnt
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
		perform devv5.SendMailHTML (email, 'Release status [Wiki POST ERROR]', cRet);
	END IF;
	
	EXCEPTION
	WHEN OTHERS
	THEN
	GET STACKED DIAGNOSTICS cRet = PG_EXCEPTION_CONTEXT;
		cRet:='ERROR: '||SQLERRM||crlf||'CONTEXT: '||regexp_replace(cRet, '\r|\n|\r\n', crlf, 'g');
		cRet := SUBSTR ('Report completed with errors:'||crlf||'<b>'||cRet||'</b>', 1, 5000);
		perform devv5.SendMailHTML (email, 'Release status [Create Reports ERROR]', cRet);
end;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;