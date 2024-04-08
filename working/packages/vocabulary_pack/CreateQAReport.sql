CREATE OR REPLACE FUNCTION devv5.report_qa_ddl ()
RETURNS void AS
$BODY$
DECLARE
	cResult RECORD;
	cRet TEXT;
	cTitle TEXT;
	cEmail TEXT:= (SELECT var_value FROM devv5.config$ WHERE var_name='report_qa_ddl');
BEGIN
	cTitle:='<b>QA DDL</b><br>';
	cRet:='<style>table, th, td {border: 1px solid black;border-collapse: collapse;}</style><table>';
	--column names
	cRet:=cRet||'<tr><th><b>Error text</b></th><th><b>Schema name</b></th><th><b>Table name</b></th><th><b>Object name</b></th><th><b>Description</b></th><th><b>How to fix</b></th></tr>';
	FOR cResult IN 
	(
		SELECT q.error_text,
			q.schema_name,
			q.table_name,
			q.object_name,
			q.descr,
			q.how_to_fix,
			sa.owner_email
		FROM devv5.qa_ddl() q
		LEFT JOIN devv5.schema_actions sa USING (schema_name)
		ORDER BY q.error_text,
			q.schema_name,
			q.table_name
	) LOOP
		--row
		cRet:=cRet||'<tr>';
		cRet:=CONCAT(cRet,'<td>',cResult.error_text,'</td>');
		cRet:=CONCAT(cRet,'<td>',cResult.schema_name,'</td>');
		cRet:=CONCAT(cRet,'<td>',cResult.table_name,'</td>');
		cRet:=CONCAT(cRet,'<td>',cResult.object_name,'</td>');
		cRet:=CONCAT(cRet,'<td>',cResult.descr,'</td>');
		cRet:=CONCAT(cRet,'<td>',cResult.how_to_fix,'</td>');
		--end row
		cRet:=cRet||'</tr>';

		IF cResult.owner_email IS NOT NULL AND STRPOS(','||cEmail||',',','||cResult.owner_email||',') = 0 THEN
			cEmail:=cEmail||','||cResult.owner_email;
		END IF;
	END LOOP;
	cRet:=cRet||'</table>'||'<br>Tip: select * from devv5.qa_ddl(); to check changes';

	IF FOUND THEN
		PERFORM devv5.SendMailHTML (cEmail, 'QA DDL', cTitle||cRet);
	END IF;
END;
$BODY$
LANGUAGE 'plpgsql';

REVOKE EXECUTE ON FUNCTION devv5.report_qa_ddl FROM PUBLIC, role_read_only;
