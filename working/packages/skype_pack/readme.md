# Small bot for Skype, can be used to deliver messages from sql-scripts and execute prepared tasks

### Disclaimer
The package is based on an unofficial python library [SkPy](https://github.com/Terrance/SkPy). It uses the Skype HTTP API, therefore the bot cannot be guaranteed to work, some messages may disappear or be delayed, so use it at your own risk

### How to install
1. Prepare python modules: pip install skpy psycopg2-binary screen psutil
2. Run in devv5 all \*.sql, first skype_ddl.sql (replace 'primary.contact' with your actual skype contact!), then all the others
3. Run all task_\*.sql from the 'tasks' folder
4. Create a folder 'skypebot' in your server and add path to config$ table:
```SQL
INSERT INTO devv5.config$
VALUES (
	'skype_config_path',
	'/path/to/skypebot',
	NULL
	);
```
5. Put the config.py file in the skypebot folder, edit according to your settings
6. Add yourself ('primary.contact') to bot's userlist
7. Run skypebotdaemon.py in the screen: screen -S skypebotdaemon -d -m python /path/to/skypebot/skypebotdaemon.py
8. Done!

To communicate with the bot, use personal or group chat with a mention of the bot

Attention! **Your skype account must be added to the list of allowed contacts (skype_pack.skype_allowed_users table) and the bot must be in your contact list**

# Tests
* Just write 'ping' to bot: @VocabularyBot ping
* Available commands can be obtained with the help command: @VocabularyBot help

# Usage in scripts
Just add the function call where you need it, e.g.
```SQL
DO $_$
BEGIN
	PERFORM devv5.FastRecreateSchema();
	PERFORM skype_pack.SendMessage('skype.account', 'The fast in ' || CURRENT_SCHEMA || ' is complete');
END $_$;
```

# Formatting support
The bot can format your message (with pFormat=>TRUE parameter):
* \*message\* - mark 'message' as **bold**
* \_message\_ - mark 'message' as *italic*
* \~message\~ - mark 'message' as ~~strikethrough~~
* {code}message{code} - mark 'message' as ```monospace```

Note: there is a very limited support for formatting, you can't nest tags inside others, e.g. {code}\*test\*{code} - it won't work
```SQL
DO $_$
BEGIN
	PERFORM skype_pack.SendMessage('skype.account', 'Test *message*', pFormat=>TRUE);
END $_$;
```

# Admin's guide
1. To add a new user: INSERT INTO skype_pack.skype_allowed_users VALUES ('someskype.account');
2. To add a new task, first create the corresponding task_\*function, then call skype_pack.AddTask
```SQL
CREATE OR REPLACE FUNCTION skype_pack.task_Test (pTaskCommand TEXT, pSkypeUserID TEXT, pSkypeChatID TEXT, pLogID INT4)
RETURNS VOID AS
$BODY$
	/*
	Test task
	*/
BEGIN
	PERFORM SendMessage(pSkypeUserID, 'your task has been started (waiting 10 seconds)', pSkypeChatID, FALSE, pLogID);

	PERFORM pg_sleep(10);

	PERFORM SendMessage(pSkypeUserID, 'your task has been finished', pSkypeChatID, FALSE, pLogID);
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = skype_pack, pg_temp;

REVOKE EXECUTE ON FUNCTION skype_pack.task_Test FROM PUBLIC;

DO $_$
BEGIN
	PERFORM skype_pack.AddTask(
	pTaskCommand			=> 'test', --case insensitive, so you can write 'test', 'Test', 'TEST' etc to the bot
	pTaskProcedureName		=> 'task_Test',
	pTaskDescription		=> 'Test task, just example',
	pTaskType			=> NULL --'instant' (bot should answer immediately) or NULL (task for queue)
	);
END $_$;
```

Note: 'task for queue' means a task that will be queued and executed by a background process. This allows to accept any number of tasks, but only one task will be executed at a time

3. To add a new instant reply (autoreply), call skype_pack.AddInstantReply
```SQL
DO $_$
BEGIN
	PERFORM skype_pack.AddInstantReply(
	pTaskCommand			=> 'hi',
	pTaskDescription		=> 'Just smile!',
	pReply				=> 'hello!'
	);
END $_$;
```
Note: Unlike 'instant' tasks, there is no need to create a procedure; the question-answer pair is simply stored in a special table (skype_pack.autoreply)