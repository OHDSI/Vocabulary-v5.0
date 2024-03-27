CREATE ROLE role_skypebot;
CREATE SCHEMA skype_pack AUTHORIZATION devv5;
GRANT USAGE ON SCHEMA skype_pack TO role_skypebot, role_read_only;
CREATE USER skypebot WITH PASSWORD 'your_password' IN ROLE role_skypebot;

CREATE TABLE skype_pack.skype_query_log (
	log_id INT4 GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	query_time TIMESTAMPTZ NOT NULL,
	skype_userid TEXT NOT NULL,
	skype_username TEXT NOT NULL,
	skype_chatid TEXT NOT NULL,
	skype_query TEXT NOT NULL,
	skype_raw_query TEXT NOT NULL
);

CREATE TABLE skype_pack.skype_error_log (
	log_id INT4 GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	error_time TIMESTAMPTZ NOT NULL,
	query_log_id INT4,
	module_id TEXT NOT NULL, --'SendMessage','RunQueue' etc
	error_text TEXT NOT NULL
);

CREATE TABLE skype_pack.skype_allowed_users (
	skype_userid TEXT NOT NULL UNIQUE
);

GRANT SELECT ON skype_pack.skype_allowed_users TO role_skypebot;
INSERT INTO skype_pack.skype_allowed_users VALUES ('primary.contact');

CREATE TABLE skype_pack.task (
	task_id INT4 GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	task_command TEXT NOT NULL,
	task_procedure TEXT NOT NULL,
	task_description TEXT NOT NULL,
	task_type TEXT CHECK (task_type IN ('instant')) --instant (bot should answer immediately) or null (task for queue)
);
CREATE UNIQUE INDEX idx_task_command ON skype_pack.task(task_command);

CREATE TABLE skype_pack.task_queue (
	task_queue_id INT4 GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	task_id INT4 REFERENCES skype_pack.task(task_id),
	log_id INT4 REFERENCES skype_pack.skype_query_log(log_id)
);

CREATE TABLE skype_pack.autoreply (
	q_text TEXT PRIMARY KEY REFERENCES skype_pack.task(task_command),
	a_text TEXT NOT NULL
);
