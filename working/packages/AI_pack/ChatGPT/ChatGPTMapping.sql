CREATE OR REPLACE FUNCTION ai_pack.ChatGPTMapping (
	pSrcTableName TEXT,
	pModelEngine TEXT DEFAULT 'gpt-4',
	pMaxTokens INT4 DEFAULT 1024,
	pTemperature NUMERIC DEFAULT 0.5,
	pTopProbability NUMERIC DEFAULT 1,
	pFrequencyPenalty NUMERIC DEFAULT 0,
	pPresencePenalty NUMERIC DEFAULT 0
)
RETURNS VOID AS
$BODY$
DECLARE
	iRet INT8;
BEGIN
	EXECUTE FORMAT ($$
		SELECT source_code_description,
			potential_target_concept_id
		FROM %1$I
		GROUP BY source_code_description,
			potential_target_concept_id
		HAVING COUNT(*) > 1
		LIMIT 1
	$$, pSrcTableName);

	GET DIAGNOSTICS iRet = ROW_COUNT;

	IF iRet>0 THEN
		RAISE EXCEPTION 'Please remove duplicates:
			DELETE FROM % t1 WHERE EXISTS (SELECT 1 FROM % t2 WHERE t2.source_code_description = t1.source_code_description AND t2.potential_target_concept_id = t1.potential_target_concept_id AND t2.ctid > t1.ctid)', pSrcTableName, pSrcTableName;
	END IF;

	EXECUTE FORMAT ($$
		UPDATE %1$I t
		SET chatgptreply = s2.gpt_reply,
			target_concept_id = s2.matched_target_concept_id
		FROM (
			SELECT s1.source_code_description,
				s1.gpt_reply,
				UNNEST(REGEXP_MATCHES(s1.gpt_reply, '{cid=(\d+)}','g'))::INT4 matched_target_concept_id
			FROM (
				SELECT s0.source_code_description,
					ai_pack.ChatGPT(s0.query, %2$L, %3$L, %4$L, %5$L, %6$L, %7$L) gpt_reply
				FROM (
					SELECT source_code_description,
						t.question || '"' || t.source_code_description || '": ' || STRING_AGG('"' || c.concept_name || ' {cid=' || t.potential_target_concept_id::TEXT || '}"', ',' ORDER BY c.concept_name) query
					FROM %1$I t
					JOIN devv5.concept c ON c.concept_id = t.potential_target_concept_id
					GROUP BY t.question,
						t.source_code_description
					) s0
				) s1
			) s2
		WHERE t.source_code_description = s2.source_code_description
			AND t.potential_target_concept_id = s2.matched_target_concept_id

	$$, pSrcTableName, pModelEngine, pMaxTokens, pTemperature, pTopProbability, pFrequencyPenalty, pPresencePenalty);

END;
$BODY$
LANGUAGE 'plpgsql';