--1. Prepare the schema
CREATE SCHEMA ai_pack AUTHORIZATION devv5;
ALTER DEFAULT PRIVILEGES FOR USER devv5 IN SCHEMA ai_pack GRANT SELECT ON TABLES TO role_read_only;
GRANT USAGE ON SCHEMA ai_pack TO role_read_only;

--2. Create a log table
CREATE TABLE ai_pack.chatgpt_log (
	log_id INT4 GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	query TEXT NOT NULL,
	params JSONB NOT NULL,
	created TIMESTAMPTZ NOT NULL,
	created_by TEXT NOT NULL,
	reply TEXT,
	usage_tokens JSONB
	);

--3. Put file chatgpt.py to /data/postgres/chatgpt/chatgpt.py, set openai.api_key and install openai (pip3 install openai)

--4. Run *.sql-files

--5. Create a view to easily view logs (optional)
CREATE OR REPLACE VIEW ai_pack.v_chatgpt_log AS
SELECT log_id,
	query,
	params ->> 'pModelEngine' AS model_engine,
	(params ->> 'pMaxTokens')::INT4 AS max_tokens,
	(params ->> 'pTemperature')::NUMERIC AS temperature,
	(params ->> 'pTopProbability')::NUMERIC AS top_probability,
	(params ->> 'pPresencePenalty')::NUMERIC AS presence_penalty,
	(params ->> 'pFrequencyPenalty')::NUMERIC AS frequency_penalty,
	created,
	created_by,
	reply,
	(usage_tokens ->> 'total_tokens')::INT4 AS total_tokens,
	(usage_tokens ->> 'prompt_tokens')::INT4 AS prompt_tokens,
	(usage_tokens ->> 'completion_tokens')::INT4 AS completion_tokens
FROM ai_pack.chatgpt_log;
