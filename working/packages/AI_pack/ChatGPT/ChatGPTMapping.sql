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
	iQuery TEXT;
	iAIQuestions RECORD;
	iAIReply RECORD;
	iProcessedCounter INT4:=0;
	iProcessedPct INT2:=0;
BEGIN
	--check for duplicates
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
			DELETE FROM % t1 WHERE EXISTS (SELECT 1 FROM % t2 WHERE t2.source_code_description = t1.source_code_description AND t2.potential_target_concept_id = t1.potential_target_concept_id AND t2.ctid > t1.ctid);', pSrcTableName, pSrcTableName;
	END IF;

	--checking for non-existent potential_target_concept_id
	EXECUTE FORMAT ($$
		SELECT 1
		FROM %1$I t
		LEFT JOIN concept c ON c.concept_id = t.potential_target_concept_id
		WHERE c.concept_id IS NULL
		LIMIT 1
	$$, pSrcTableName);

	GET DIAGNOSTICS iRet = ROW_COUNT;

	IF iRet>0 THEN
		RAISE EXCEPTION 'Please check potential_target_concept_id (does not exist in the concept table):
			SELECT t.* FROM % t
			LEFT JOIN concept c ON c.concept_id = t.potential_target_concept_id
			WHERE c.concept_id IS NULL;', pSrcTableName;
	END IF;

	--within each source_code_description there must be the same question
	EXECUTE FORMAT ($$
		SELECT 1
		FROM %1$I
		GROUP BY source_code_description
		HAVING COUNT(DISTINCT question) > 1
		LIMIT 1
	$$, pSrcTableName);

	GET DIAGNOSTICS iRet = ROW_COUNT;

	IF iRet>0 THEN
		RAISE EXCEPTION 'Please check the questions (within each source_code_description there must be the same question):
			SELECT source_code_description,
				COUNT(DISTINCT question)
			FROM %
			GROUP BY source_code_description
			HAVING COUNT(DISTINCT question) > 1;', pSrcTableName;
	END IF;

	--iterate through questions
	FOR iAIQuestions IN EXECUTE FORMAT ($$
		SELECT t.source_code_description,
			ARRAY_AGG(potential_target_concept_id) ptcid,
			t.question || '"' || t.source_code_description || '": ' || STRING_AGG('"' || c.concept_name || ' {cid=' || t.potential_target_concept_id::TEXT || '}"', ',' ORDER BY c.concept_name) query,
			COUNT (*) OVER () query_cnt
		FROM %1$I t
		JOIN concept c ON c.concept_id = t.potential_target_concept_id
		WHERE t.source_code_description IN (
				--if another potential_target_concept_id is added to an already existing concept that chatgpt passed through, then we rerun the entire set
				SELECT t_int.source_code_description
				FROM %1$I t_int
				WHERE NULLIF(t_int.log_id, 0) IS NULL
				)
		GROUP BY t.question,
			t.source_code_description
		$$, pSrcTableName)
	LOOP
		--call ChatGPT
		SELECT ai.* INTO iAIReply FROM ai_pack.ChatGPT(iAIQuestions.query, pModelEngine, pMaxTokens, pTemperature, pTopProbability, pFrequencyPenalty, pPresencePenalty) ai;

		--write the result to the source table in a separate transaction
		iQuery:=FORMAT ($$
			UPDATE %1$I t
			SET chatgptreply = %2$L,
				target_concept_id = ai.matched_target_concept_id,
				log_id = %3$L
			FROM (
				SELECT ptc.potential_target_concept_id,
					l.matched_target_concept_id
				FROM UNNEST(%4$L::INT4[]) AS ptc(potential_target_concept_id)
				LEFT JOIN LATERAL (SELECT UNNEST(REGEXP_MATCHES(%2$L, '{cid=(\d+)}','g'))::INT4 matched_target_concept_id) l ON l.matched_target_concept_id=ptc.potential_target_concept_id
			) ai
			WHERE t.source_code_description = %5$L
				AND t.potential_target_concept_id = ai.potential_target_concept_id
		$$, pSrcTableName, iAIReply.chatgpt_reply, iAIReply.log_id, iAIQuestions.ptcid, iAIQuestions.source_code_description);

		PERFORM FROM devv5.PG_BACKGROUND_RESULT(devv5.PG_BACKGROUND_LAUNCH (iQuery)) AS (result TEXT);
		
		--show processing progress
		SELECT * INTO iProcessedCounter, iProcessedPct FROM devv5.ShowProcessingProgress (iProcessedCounter, iAIQuestions.query_cnt, 'queries', iProcessedPct);
	END LOOP;

	RAISE NOTICE '100%% of queries were processed';
END;
$BODY$
LANGUAGE 'plpgsql' COST 1000;