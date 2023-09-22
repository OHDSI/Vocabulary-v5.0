--1. Prepare the schema
DROP SCHEMA IF EXISTS ai_pack CASCADE;
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
	reply TEXT
	);

--3. Put file chatgpt.py to /data/postgres/chatgpt/chatgpt.py, set openai.api_key and install openai (pip3 install openai)

--4. Run *.sql-files