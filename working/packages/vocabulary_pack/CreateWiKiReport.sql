CREATE OR REPLACE FUNCTION vocabulary_pack.CreateWiKiReport ()
RETURNS TEXT AS
$BODY$
/*
	This procedure creates report for the WiKi
*/
DECLARE
	crlf CONSTANT TEXT := '<br>';
	crlf_comma CONSTANT TEXT := ', <br>';
	crlf_semicolon CONSTANT TEXT := '; <br>';
	cRet TEXT = '';
	cResult RECORD;
BEGIN

	FOR cResult IN 
	(
		SELECT vocabs.vocabulary_id AS section_title,
			--'<b>' || vocabs.vocabulary_id || '</b><br>' || 
			standards.cnt_standards AS vocabulary_id,
			domains.cnt_domains,
			classes.cnt_classes,
			relationships.cnt_relationships
		FROM (
			SELECT v.vocabulary_id
			FROM prodv5.vocabulary v
			WHERE EXISTS (
					SELECT 1
					FROM prodv5.concept c
					WHERE c.vocabulary_id = v.vocabulary_id
					)
			) vocabs
		--New output format: Maps to (97) [SNOMED (90), RxNorm(7)]
		JOIN LATERAL(SELECT s2.vocabulary_id, STRING_AGG(s2.grouped_relationships, crlf_semicolon ORDER BY s2.grouped_relationships) AS cnt_relationships FROM (
				SELECT s1.vocabulary_id,
					s1.total_cnt || ' [' || STRING_AGG(s1.cnt_relationships, ', ' ORDER BY s1.cnt_relationships) || ']' AS grouped_relationships
				FROM (
					SELECT s0.vocabulary_id,
						s0.relationship_id || '  (' || TO_CHAR(SUM(s0.cnt) OVER (
								PARTITION BY s0.vocabulary_id,
								s0.relationship_id
								), 'FM9,999,999,999') || ')' AS total_cnt,
						STRING_AGG(s0.vocab_cnt, ', ' ORDER BY s0.relationship_id) AS cnt_relationships
					FROM (
						SELECT c1.vocabulary_id,
							cr.relationship_id,
							c2.vocabulary_id || ' (' || TO_CHAR(COUNT(*), 'FM9,999,999,999') || ')' AS vocab_cnt,
							COUNT(*) AS cnt
						FROM prodv5.concept c1
						JOIN prodv5.concept_relationship cr ON cr.concept_id_1 = c1.concept_id
							AND cr.invalid_reason IS NULL
						JOIN prodv5.concept c2 ON c2.concept_id = cr.concept_id_2
						WHERE c1.invalid_reason IS NULL
						GROUP BY c1.vocabulary_id,
							cr.relationship_id,
							c2.vocabulary_id
						) AS s0
					GROUP BY s0.vocabulary_id,
						s0.relationship_id,
						s0.cnt
					) AS s1
				GROUP BY s1.vocabulary_id,
					s1.total_cnt
				) AS s2 GROUP BY s2.vocabulary_id) relationships ON relationships.vocabulary_id = vocabs.vocabulary_id
		JOIN LATERAL(SELECT s0.vocabulary_id, STRING_AGG(s0.cnt, crlf_comma ORDER BY s0.domain_id) AS cnt_domains FROM (
				SELECT c.vocabulary_id,
					c.domain_id,
					c.domain_id || ' (' || TO_CHAR(COUNT(*), 'FM9,999,999,999') || ')' AS cnt
				FROM prodv5.concept c
				WHERE c.invalid_reason IS NULL
				GROUP BY c.vocabulary_id,
					c.domain_id
				) AS s0 GROUP BY s0.vocabulary_id) domains ON domains.vocabulary_id = vocabs.vocabulary_id
		JOIN LATERAL(SELECT s0.vocabulary_id, STRING_AGG(s0.cnt, crlf_comma ORDER BY s0.concept_class_id) AS cnt_classes FROM (
				SELECT c.vocabulary_id,
					c.concept_class_id,
					c.concept_class_id || ' (' || TO_CHAR(COUNT(*), 'FM9,999,999,999') || ')' AS cnt
				FROM prodv5.concept c
				WHERE c.invalid_reason IS NULL
				GROUP BY c.vocabulary_id,
					c.concept_class_id
				) AS s0 GROUP BY s0.vocabulary_id) classes ON classes.vocabulary_id = vocabs.vocabulary_id
		JOIN LATERAL(SELECT s0.vocabulary_id, STRING_AGG(s0.cnt, crlf_comma ORDER BY s0.standard_concept) AS cnt_standards FROM (
				SELECT c.vocabulary_id,
					c.standard_concept,
					CASE c.standard_concept
						WHEN 'S'
							THEN 'Standard'
						WHEN 'C'
							THEN 'Classification'
						ELSE 'non-Standard'
						END || ' (' || TO_CHAR(COUNT(*), 'FM9,999,999,999') || ')' cnt
				FROM prodv5.concept c
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
		cRet:=cRet||'<tr><th>Standard_concept</th><th>Count of domains</th><th>Count of concept classes</th><th>Count of relationships</th></tr>';
		cRet:=cRet||'<tr>';
		cRet:=cRet||'<td valign="top">'||cResult.vocabulary_id||'</td>';
		cRet:=cRet||'<td valign="top">'||cResult.cnt_domains||'</td>';
		cRet:=cRet||'<td valign="top">'||cResult.cnt_classes||'</td>';
		cRet:=cRet||'<td valign="top">'||cResult.cnt_relationships||'</td>';
		cRet:=cRet||'</tr>';
		cRet:=cRet||'</table>';
	END LOOP;

	RETURN cRet||crlf;
END;
$BODY$
LANGUAGE 'plpgsql' STABLE;

REVOKE EXECUTE ON FUNCTION vocabulary_pack.CreateWiKiReport FROM PUBLIC;