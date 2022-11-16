CREATE OR REPLACE FUNCTION vocabulary_pack.CreateWiKiReport ()
RETURNS void AS
$BODY$
/*
	This procedure creates report on the WiKi
*/
DECLARE
	crlf VARCHAR(4) := '<br>';
	email CONSTANT VARCHAR(1000) := (SELECT var_value FROM devv5.config$ WHERE var_name='service_email');
	cGitLogin CONSTANT TEXT:= (SELECT var_value FROM devv5.config$ WHERE var_name='git_credentials')::json->>'git_login';
	cGitPassword CONSTANT TEXT:= (SELECT var_value FROM devv5.config$ WHERE var_name='git_credentials')::json->>'git_password';
	cGitWiKiURL CONSTANT TEXT := (SELECT var_value FROM devv5.config$ WHERE var_name='git_credentials')::json->>'git_wiki_url';
	cWiKiCommitText CONSTANT TEXT:= (SELECT 'v'||TO_CHAR(CURRENT_DATE,'yyyymmdd')||'_'||EXTRACT(epoch FROM NOW()::TIMESTAMP(0))::VARCHAR);
	cRet TEXT = '';
	cFullRet TEXT;
	cTitle TEXT;
	cResult RECORD;
	cRet_wiki TEXT;
BEGIN
	cTitle:='<h1>Vocabulary Statistics '||LEFT(cWiKiCommitText,9)||'</h1>'||crlf;

	FOR cResult IN 
	(
		SELECT vocabs.vocabulary_id AS section_title,
			'<b>' || vocabs.vocabulary_id || '</b><br>' || standards.cnt_standards AS vocabulary_id,
			domains.cnt_domains,
			classes.cnt_classes,
			relationships.cnt_relationships
		FROM (
			SELECT v.vocabulary_id
			FROM vocabulary v
			WHERE EXISTS (
					SELECT 1
					FROM concept c
					WHERE c.vocabulary_id = v.vocabulary_id
					)
			) vocabs
		JOIN LATERAL(SELECT s0.vocabulary_id, STRING_AGG(s0.cnt, crlf ORDER BY s0.relationship_id) AS cnt_relationships FROM (
				SELECT c.vocabulary_id,
					cr.relationship_id,
					cr.relationship_id || ' (' || TO_CHAR(COUNT(*), 'FM9,999,999,999') || ')' AS cnt
				FROM concept c
				JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
					AND cr.invalid_reason IS NULL
				WHERE c.invalid_reason IS NULL
				GROUP BY c.vocabulary_id,
					cr.relationship_id
				) AS s0 GROUP BY s0.vocabulary_id) relationships ON relationships.vocabulary_id = vocabs.vocabulary_id
		JOIN LATERAL(SELECT s0.vocabulary_id, STRING_AGG(s0.cnt, crlf ORDER BY s0.domain_id) AS cnt_domains FROM (
				SELECT c.vocabulary_id,
					c.domain_id,
					c.domain_id || ' (' || TO_CHAR(COUNT(*), 'FM9,999,999,999') || ')' AS cnt
				FROM concept c
				WHERE c.invalid_reason IS NULL
				GROUP BY c.vocabulary_id,
					c.domain_id
				) AS s0 GROUP BY s0.vocabulary_id) domains ON domains.vocabulary_id = vocabs.vocabulary_id
		JOIN LATERAL(SELECT s0.vocabulary_id, STRING_AGG(s0.cnt, crlf ORDER BY s0.concept_class_id) AS cnt_classes FROM (
				SELECT c.vocabulary_id,
					c.concept_class_id,
					c.concept_class_id || ' (' || TO_CHAR(COUNT(*), 'FM9,999,999,999') || ')' AS cnt
				FROM concept c
				WHERE c.invalid_reason IS NULL
				GROUP BY c.vocabulary_id,
					c.concept_class_id
				) AS s0 GROUP BY s0.vocabulary_id) classes ON classes.vocabulary_id = vocabs.vocabulary_id
		JOIN LATERAL(SELECT s0.vocabulary_id, STRING_AGG(s0.cnt, crlf ORDER BY s0.standard_concept) AS cnt_standards FROM (
				SELECT c.vocabulary_id,
					c.standard_concept,
					CASE c.standard_concept
						WHEN 'S'
							THEN 'Stand'
						WHEN 'C'
							THEN 'Class'
						ELSE 'Non-stand'
						END || ' (' || TO_CHAR(COUNT(*), 'FM9,999,999,999') || ')' cnt
				FROM concept c
				WHERE c.invalid_reason IS NULL
				GROUP BY c.vocabulary_id,
					c.standard_concept
				) AS s0 GROUP BY s0.vocabulary_id) standards ON standards.vocabulary_id = vocabs.vocabulary_id
		--WHERE vocabs.vocabulary_id = 'SNOMED'
		ORDER BY vocabs.vocabulary_id
		--LIMIT 100
	) LOOP
		IF cRet<>'' THEN cRet:=cRet||crlf; END IF;
		cRet:=cRet||'<h3>'||cResult.section_title||'</h3>';
		cRet:=cRet||'<table>';
		cRet:=cRet||'<tr><th>Vocabulary</th><th>Count of domains</th><th>Count of classes</th><th>Count of relationships</th></tr>';
		cRet:=cRet||'<tr>';
		cRet:=cRet||'<td valign="top">'||cResult.vocabulary_id||'</td>';
		cRet:=cRet||'<td valign="top">'||cResult.cnt_domains||'</td>';
		cRet:=cRet||'<td valign="top">'||cResult.cnt_classes||'</td>';
		cRet:=cRet||'<td valign="top">'||cResult.cnt_relationships||'</td>';
		cRet:=cRet||'</tr>';
		cRet:=cRet||'</table>';
	END LOOP;
	cRet:=cRet||crlf;

	cFullRet:=cTitle||cRet;

	SELECT vocabulary_pack.py_git_wiki(cGitWiKiURL,cWiKiCommitText,cFullRet,cGitLogin,cGitPassword) INTO cRet_wiki;
	IF cRet_wiki <> 'OK' THEN
		cRet := SUBSTR ('WiKi report completed with errors:'||crlf||'<b>'||cRet_wiki||'</b>', 1, 5000);
		perform devv5.SendMailHTML (email, 'WiKi report status [Wiki POST ERROR]', cRet);
	END IF;

	EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS cRet = PG_EXCEPTION_CONTEXT;
		cRet:='ERROR: '||SQLERRM||crlf||'CONTEXT: '||cRet;
		cRet := SUBSTR ('WiKi report completed with errors:'||crlf||'<b>'||cRet||'</b>', 1, 5000);
		perform devv5.SendMailHTML (email, 'WiKi report status [CreateWiKiReport ERROR]', cRet);
END;
$BODY$
LANGUAGE 'plpgsql';