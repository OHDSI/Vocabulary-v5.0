CREATE OR REPLACE FUNCTION vocabulary_pack.CreateOHDSIReport (
)
RETURNS void AS
$body$
/*
	This procedure creates reports on the OHDSI website
*/
declare
	crlf VARCHAR(4) := '<br>';
	email CONSTANT VARCHAR(1000) := (SELECT var_value FROM devv5.config$ WHERE var_name='service_email');
	cDocID CONSTANT VARCHAR(100) := (SELECT var_value FROM devv5.config$ WHERE var_name='ohdsi_credentials')::json->>'doc_id';
	cOHDSILogin CONSTANT VARCHAR(100) := (SELECT var_value FROM devv5.config$ WHERE var_name='ohdsi_credentials')::json->>'ohdsi_login';
	cOHDSIPassword CONSTANT VARCHAR(100) := (SELECT var_value FROM devv5.config$ WHERE var_name='ohdsi_credentials')::json->>'ohdsi_password';
	cRet TEXT = '';
	cTOC TEXT = '';
	cFullRet TEXT;
	cTitle TEXT;
	cResult RECORD;
	cRet_ohdsi TEXT;
begin
	cTitle:=E'\r\n == Vocabulary Statistics ==\r\n';

	FOR cResult IN 
	(
		select vocabs.vocabulary_id as section_title,
		'**'||vocabs.vocabulary_id||'** \\ '||standards.cnt_standards as vocabulary_id, 
		domains.cnt_domains,
		classes.cnt_classes,
		relationships.cnt_relationships
		from
		(select v.vocabulary_id from vocabulary v where exists (select 1 from concept c where c.vocabulary_id=v.vocabulary_id)) vocabs

		join lateral (
			select s0.vocabulary_id, string_agg(s0.cnt,' \\ ' order by s0.relationship_id) as cnt_relationships from
			(
				select c.vocabulary_id, cr.relationship_id, cr.relationship_id||' ('||to_char(count(*), 'FM9,999,999,999')||')' cnt from concept c
				join concept_relationship cr on cr.concept_id_1=c.concept_id and cr.invalid_reason is null
				where c.invalid_reason is null
				group by c.vocabulary_id,cr.relationship_id
			) as s0 group by s0.vocabulary_id
		) relationships on relationships.vocabulary_id=vocabs.vocabulary_id

		join lateral (
			select s0.vocabulary_id, string_agg(s0.cnt,' \\ ' order by s0.domain_id) as cnt_domains from
			(
				select c.vocabulary_id, c.domain_id, c.domain_id||' ('||to_char(count(*), 'FM9,999,999,999')||')' cnt from concept c
				where c.invalid_reason is null
				group by c.vocabulary_id,c.domain_id
			) as s0 group by s0.vocabulary_id
		) domains on domains.vocabulary_id=vocabs.vocabulary_id

		join lateral (
			select s0.vocabulary_id, string_agg(s0.cnt,' \\ ' order by s0.concept_class_id) as cnt_classes from
			(
				select c.vocabulary_id, c.concept_class_id, c.concept_class_id||' ('||to_char(count(*), 'FM9,999,999,999')||')' cnt from concept c
				where c.invalid_reason is null
				group by c.vocabulary_id,c.concept_class_id
			) as s0 group by s0.vocabulary_id
		) classes on classes.vocabulary_id=vocabs.vocabulary_id

		join lateral (
			select s0.vocabulary_id, string_agg(s0.cnt,' \\ ' order by s0.standard_concept) as cnt_standards from
			(
				select c.vocabulary_id, c.standard_concept, case c.standard_concept when 'S' then 'Stand' when 'C' then 'Class' else 'Non-stand' end||' ('||to_char(count(*), 'FM9,999,999,999')||')' cnt from concept c
				where c.invalid_reason is null
				group by c.vocabulary_id,c.standard_concept
			) as s0 group by s0.vocabulary_id
		) standards on standards.vocabulary_id=vocabs.vocabulary_id
		--where vocabs.vocabulary_id='SNOMED'
		order by vocabs.vocabulary_id
		--limit 100
	) LOOP
		IF cRet<>'' THEN cRet:=cRet||E'\r\n'; cTOC:=cTOC||E'\r\n'; END IF;
		cRet:=cRet||' ===== '||cResult.section_title||E' =====\r\n';
		cRet:=cRet||E'^ Vocabulary ^ Count of domains ^ Count of classes ^ Count of relationships ^\r\n';
		cRet:=cRet||'| '||cResult.vocabulary_id;
		cRet:=cRet||' | '||cResult.cnt_domains;
		cRet:=cRet||' | '||cResult.cnt_classes;
		cRet:=cRet||' | '||cResult.cnt_relationships||E' |\r\n';
	END LOOP;
	cRet:=cRet||E'\r\n';

	cFullRet:=cTitle||cRet;

	SELECT vocabulary_pack.py_ohdsi_wiki (cDocID, cFullRet, cOHDSILogin, cOHDSIPassword) into cRet_ohdsi;
	IF cRet_ohdsi <> 'OK' THEN
		cRet := SUBSTR ('OHDSI report completed with errors:'||crlf||'<b>'||cRet_ohdsi||'</b>', 1, 5000);
		perform devv5.SendMailHTML (email, 'OHDSI report status [OHDSI Wiki POST ERROR]', cRet);
	END IF;

	EXCEPTION
	WHEN OTHERS
	THEN
	GET STACKED DIAGNOSTICS cRet = PG_EXCEPTION_CONTEXT;
		cRet:='ERROR: '||SQLERRM||crlf||'CONTEXT: '||regexp_replace(cRet, '\r|\n|\r\n', crlf, 'g');
		cRet := SUBSTR ('OHDSI report completed with errors:'||crlf||'<b>'||cRet||'</b>', 1, 5000);
		perform devv5.SendMailHTML (email, 'OHDSI report status [CreateOHDSIReport ERROR]', cRet);
end;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;