--1. Create a table for logs
CREATE TABLE admin_pack.logged_actions (
	log_id INT4 GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	table_name TEXT NOT NULL,
	tg_operation TEXT NOT NULL CHECK (tg_operation IN ('I','D','U','T')), --I=insert, D=delete, U=update, T=truncate
	sess_user TEXT NOT NULL, --session user (dev-schema)
	tx_time TIMESTAMPTZ NOT NULL, --current transaction timestamp
	user_id INT4 NOT NULL, --who perform the operation,
	whom_user_id INT4, --for whom the operation is performed
	privilege_id INT4, --if a privilege has been created or changed
	vocabulary_concept_id INT4, --if a privilege for vocabulary has been created or changed
	old_row JSONB,
	new_row JSONB,
	client_ip INET,
	client_app_name TEXT,
	script_name TEXT, --function stack
	tx_id INT4 NOT NULL --current transaction ID
	);

--2. Create trigger function for all admin tables
CREATE OR REPLACE FUNCTION admin_pack.f_tg_log() RETURNS TRIGGER AS
$BODY$
DECLARE
	iOldRow JSONB;
	iNewRow JSONB;
	iOperation TEXT:=LEFT(TG_OP,1);
	iStack TEXT;
BEGIN
	GET DIAGNOSTICS iStack = PG_CONTEXT;

	IF TG_OP='UPDATE' THEN
		--hiding all sensitive information, even if they are a hash
		iOldRow:=JSONB_SET(TO_JSONB(OLD),'{session_id}','"<hidden>"',FALSE);
		iNewRow:=JSONB_SET(TO_JSONB(NEW),'{session_id}','"<hidden>"',FALSE);
		IF iOldRow ->> 'user_password' <> iNewRow ->> 'user_password' THEN
			iOldRow:=JSONB_SET(iOldRow,'{user_password}','"<old_password_hash>"',FALSE);
			iNewRow:=JSONB_SET(iNewRow,'{user_password}','"<new_password_hash>"',FALSE);
		ELSE
			iOldRow:=JSONB_SET(iOldRow,'{user_password}','"<hidden>"',FALSE);
			iNewRow:=JSONB_SET(iNewRow,'{user_password}','"<hidden>"',FALSE);
		END IF;
		
	ELSIF TG_OP='INSERT' THEN
		iNewRow:=JSONB_SET(TO_JSONB(NEW),'{user_password}','"<hidden>"',FALSE);
		iNewRow:=JSONB_SET(iNewRow,'{session_id}','"<hidden>"',FALSE);
	ELSIF TG_OP='DELETE' THEN --should never happen, but let's put it in the log anyway
		iOldRow:=JSONB_SET(TO_JSONB(OLD),'{user_password}','"<hidden>"',FALSE);
		iOldRow:=JSONB_SET(iOldRow,'{session_id}','"<hidden>"',FALSE);
	END IF;

	--exclude unnecessary fields in logs
	--in fact the tx_time field performs this functionality
	iOldRow:=iOldRow-'created'-'modified';
	iNewRow:=iNewRow-'created'-'modified';

	INSERT INTO logged_actions
	VALUES (
		DEFAULT,
		TG_TABLE_NAME::TEXT,
		iOperation,
		SESSION_USER,
		TRANSACTION_TIMESTAMP(),
		COALESCE((iNewRow ->> 'modified_by'),(iNewRow ->> 'created_by'))::INT4,
		COALESCE((iNewRow ->> 'user_id'),(iOldRow ->> 'user_id'))::INT4,
		COALESCE((iNewRow ->> 'privilege_id'),(iOldRow ->> 'privilege_id'))::INT4,
		COALESCE((iNewRow ->> 'vocabulary_concept_id'),(iOldRow ->> 'vocabulary_concept_id'))::INT4,
		iOldRow-'created_by'-'modified_by'-'user_id'-'privilege_id'-'vocabulary_concept_id', --now we remove unnecessary data, now they are stored in separate fields
		iNewRow-'created_by'-'modified_by'-'user_id'-'privilege_id'-'vocabulary_concept_id', --now we remove unnecessary data, now they are stored in separate fields
		INET_CLIENT_ADDR(),
		CURRENT_SETTING('application_name'),
		audit.GetFunctionStack(iStack),
		TXID_CURRENT()
	);

	RETURN NULL;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET search_path = admin_pack, pg_temp;

--3. Create triggers for all admin tables
DO $$
DECLARE
	iTables TEXT[]:=ARRAY['virtual_user','virtual_privilege','virtual_user_privilege','virtual_user_vocabulary'];
	t TEXT;
BEGIN
	FOREACH t IN ARRAY iTables LOOP
		EXECUTE FORMAT('
		CREATE OR REPLACE TRIGGER tg_audit_u
		AFTER UPDATE ON admin_pack.%1$I
		FOR EACH ROW
		--do not put in the log if only the session has changed
		--also skip changes to the modified/modified_by field, because it can change without actually changing the data
		--NOTE: converting to JSONB only to safely remove the session_id/modified/modified_by fields if applicable
		WHEN (TO_JSONB(OLD)-''session_id''-''modified''-''modified_by'' IS DISTINCT FROM TO_JSONB(NEW)-''session_id''-''modified''-''modified_by'')
		EXECUTE PROCEDURE admin_pack.f_tg_log();

		CREATE OR REPLACE TRIGGER tg_audit_id
		AFTER INSERT OR DELETE ON admin_pack.%1$I
		FOR EACH ROW
		EXECUTE PROCEDURE admin_pack.f_tg_log();

		CREATE OR REPLACE TRIGGER tg_audit_t
		AFTER TRUNCATE ON admin_pack.%1$I
		FOR EACH STATEMENT
		EXECUTE PROCEDURE admin_pack.f_tg_log();',t);
	END LOOP;
END $$;

--4. Create indexes
CREATE INDEX idx_audit_user_id ON admin_pack.logged_actions (user_id);
CREATE INDEX idx_audit_whom_user_id ON admin_pack.logged_actions (whom_user_id);
CREATE INDEX idx_audit_tx_time ON admin_pack.logged_actions USING BRIN (tx_time);
CREATE INDEX idx_audit_tx_id ON admin_pack.logged_actions USING BRIN (tx_id);

--5. Function for viewing logs
CREATE OR REPLACE FUNCTION admin_pack.GetLogByUserID (
	pUserID INT4
	)
RETURNS TABLE (
	log_id INT4,
	table_name TEXT,
	tx_time TIMESTAMPTZ,
	tg_operation TEXT,
	user_login TEXT,
	whom_user_login TEXT,
	privilege_name TEXT,
	vocabulary_id TEXT,
	tg_result TEXT,
	script_name TEXT,
	tx_id INT4
) AS
$BODY$
	/*
	Get detailed logs by user id

	SELECT log_id,
		table_name,
		tx_time AT TIME ZONE 'MSK' AS tx_time,
		tg_operation,
		user_login,
		whom_user_login,
		privilege_name,
		vocabulary_id,
		tg_result,
		script_name,
		tx_id
	FROM admin_pack.GetLogByUserID(admin_pack.GetUserIDByLogin('dev_jdoe'))
	ORDER BY log_id DESC
	LIMIT 100;
	*/
DECLARE
	iUserID CONSTANT INT4:=GetUserID();
	ALL_PRIVILEGES CONSTANT RECORD:=GetAllPrivileges();
BEGIN
	IF NOT CheckUserPrivilege(ALL_PRIVILEGES.VIEW_LOGS) THEN
		RAISE EXCEPTION 'Insufficient privileges';
	END IF;

	RETURN QUERY
	SELECT a.log_id,
		a.table_name,
		a.tx_time,
		CASE a.tg_operation
			WHEN 'I'
				THEN 'INSERT'
			WHEN 'D'
				THEN 'DELETE'
			WHEN 'U'
				THEN 'UPDATE'
			WHEN 'T'
				THEN 'TRUNCATE'
			END tg_operation,
		vu.user_login,
		vu_whom.user_login,
		vp.privilege_name,
		v.vocabulary_id::TEXT,
		CASE a.tg_operation
			WHEN 'I'
				THEN a.new_row::TEXT
			WHEN 'D'
				THEN a.old_row::TEXT
			WHEN 'U'
				THEN l.upd_diff
			END tg_result,
		COALESCE(a.script_name, '[Manual]') script_name,
		a.tx_id
	FROM logged_actions a
	--get difference for UPDATE
	CROSS JOIN LATERAL(
		SELECT STRING_AGG(oldrow.key || '=' || QUOTE_NULLABLE(oldrow.value) || ' -> ' || QUOTE_NULLABLE(newrow.value), '; ') upd_diff
		FROM (SELECT * FROM JSONB_EACH_TEXT(a.old_row)) oldrow
		JOIN (SELECT * FROM JSONB_EACH_TEXT(a.new_row)) newrow USING (key)
		WHERE oldrow.value IS DISTINCT FROM newrow.value
			AND a.tg_operation = 'U'
		) l
	LEFT JOIN virtual_user vu USING (user_id)
	LEFT JOIN virtual_user vu_whom ON vu_whom.user_id = a.whom_user_id
	LEFT JOIN virtual_privilege vp USING (privilege_id)
	LEFT JOIN devv5.vocabulary v USING (vocabulary_concept_id)
	WHERE pUserID IN (
			a.user_id,
			a.whom_user_id
			);
END;
$BODY$
LANGUAGE 'plpgsql' STABLE STRICT SECURITY DEFINER
SET search_path = admin_pack, pg_temp;
