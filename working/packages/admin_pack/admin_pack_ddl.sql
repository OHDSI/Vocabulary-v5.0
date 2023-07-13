--1. Prepare the schema
DROP SCHEMA IF EXISTS admin_pack CASCADE;
CREATE SCHEMA admin_pack AUTHORIZATION devv5;
GRANT USAGE ON SCHEMA admin_pack TO role_read_only;

--2. Create a table for users
CREATE TABLE admin_pack.virtual_user (
	user_id INT4 GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	user_login TEXT NOT NULL UNIQUE,
	user_name TEXT NOT NULL,
	user_description TEXT,
	user_password TEXT NOT NULL,
	user_email TEXT,
	created TIMESTAMPTZ NOT NULL,
	created_by INT4 NOT NULL REFERENCES admin_pack.virtual_user(user_id),
	modified TIMESTAMPTZ,
	modified_by INT4 REFERENCES admin_pack.virtual_user(user_id),
	valid_start_date DATE NOT NULL,
	valid_end_date DATE NOT NULL,
	is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
	session_id TEXT
	);

--3. Privilege dictionary
CREATE TABLE admin_pack.virtual_privilege (
	privilege_id INT4 GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	privilege_name TEXT NOT NULL UNIQUE,
	privilege_description TEXT NOT NULL,
	created TIMESTAMPTZ NOT NULL,
	created_by INT4 NOT NULL REFERENCES admin_pack.virtual_user(user_id),
	modified TIMESTAMPTZ,
	modified_by INT4 REFERENCES admin_pack.virtual_user(user_id),
	is_blocked BOOLEAN NOT NULL DEFAULT FALSE
	);

--4. Store user privileges
CREATE TABLE admin_pack.virtual_user_privilege (
	user_id INT4 REFERENCES admin_pack.virtual_user(user_id),
	privilege_id INT4 REFERENCES admin_pack.virtual_privilege(privilege_id),
	created TIMESTAMPTZ NOT NULL,
	created_by INT4 NOT NULL REFERENCES admin_pack.virtual_user(user_id),
	modified TIMESTAMPTZ,
	modified_by INT4 REFERENCES admin_pack.virtual_user(user_id),
	valid_start_date DATE NOT NULL,
	valid_end_date DATE NOT NULL,
	is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
	PRIMARY KEY (user_id, privilege_id) --to simplify the logic, only one user-privilege pair can exist in this table
	);

--5. Store user<->vocabulary pairs
CREATE TABLE admin_pack.virtual_user_vocabulary (
	user_id INT4 REFERENCES admin_pack.virtual_user(user_id),
	vocabulary_concept_id INT4,-- REFERENCES devv5.vocabulary(vocabulary_concept_id), <- not unique key
	created TIMESTAMPTZ NOT NULL,
	created_by INT4 NOT NULL REFERENCES admin_pack.virtual_user(user_id),
	modified TIMESTAMPTZ,
	modified_by INT4 REFERENCES admin_pack.virtual_user(user_id),
	valid_start_date DATE NOT NULL,
	valid_end_date DATE NOT NULL,
	is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
	PRIMARY KEY (user_id, vocabulary_concept_id)
	);

--6. Create initial user for system tasks and initial privilege
INSERT INTO admin_pack.virtual_user
VALUES (
	DEFAULT,
	'SYSTEM',
	'SYSTEM',
	'Dummy user',
	'dummy_password_value',
	NULL,
	CLOCK_TIMESTAMP(),
	1,
	NULL,
	NULL,
	CURRENT_DATE,
	CURRENT_DATE,
	TRUE
	);

INSERT INTO admin_pack.virtual_privilege
VALUES (
	DEFAULT,
	'MANAGE_PRIVILEGE',
	'Can create/modify privileges',
	CLOCK_TIMESTAMP(),
	1,
	NULL,
	NULL
	);

/*--7. Run these *.sql:
	1. GetUserID
	2. CheckUserPrivilege
	3. GetAllPrivileges
	4. CreateVirtualUser
	5. CreatePrivilege
	6. GrantPrivilege
	7. GetUserIDByLogin
	8. GetPrivilegeIDByName
	9. CheckEmailCharacters
	10. CheckLoginCharacters
	11. CheckPasswordStrength
	12. CheckPrivilegeCharacters
	13. audit
*/

--8. Create minimal privileges
DO $_$
BEGIN
	PERFORM admin_pack.CreatePrivilege(
		pPrivilegeName         =>'MANAGE_USER',
		pPrivilegeDescription  =>'Can create/modify virtual users and their privileges'
	);
	PERFORM admin_pack.CreatePrivilege(
		pPrivilegeName         =>'MANAGE_ANY_VOCABULARY',
		pPrivilegeDescription  =>'Can manage any vocabulary'
	);
	PERFORM admin_pack.CreatePrivilege(
		pPrivilegeName         =>'MANAGE_SPECIFIC_VOCABULARY',
		pPrivilegeDescription  =>'Can only manage vocabularies specified in virtual_user_vocabulary or if the vocabulary is new'
	);
	PERFORM admin_pack.CreatePrivilege(
		pPrivilegeName         =>'VIEW_LOGS',
		pPrivilegeDescription  =>'Can view logs'
	);
END $_$;

--9. Create your own (admin) user
DO $_$
BEGIN
	PERFORM admin_pack.CreateVirtualUser(
		pUserLogin       =>'admin',
		pUserName        =>'Timur',
		pUserDescription =>'Tech admin',
		pPassWord        =>'pass#W00rd'
	);
END $_$;

--10. Assign privileges to our user
DO $_$
BEGIN
	PERFORM admin_pack.GrantPrivilege(
		pUserID          =>admin_pack.GetUserIDByLogin('admin'),
		pPrivilegeID     =>admin_pack.GetPrivilegeIDByName('MANAGE_USER')
	);
	PERFORM admin_pack.GrantPrivilege(
		pUserID          =>admin_pack.GetUserIDByLogin('admin'),
		pPrivilegeID     =>admin_pack.GetPrivilegeIDByName('MANAGE_ANY_VOCABULARY')
	);
	PERFORM admin_pack.GrantPrivilege(
		pUserID          =>admin_pack.GetUserIDByLogin('admin'),
		pPrivilegeID     =>admin_pack.GetPrivilegeIDByName('MANAGE_PRIVILEGE')
	);
	PERFORM admin_pack.GrantPrivilege(
		pUserID          =>admin_pack.GetUserIDByLogin('admin'),
		pPrivilegeID     =>admin_pack.GetPrivilegeIDByName('VIEW_LOGS')
	);
END $_$;


/*--11. Run all other sql
1. prepare_manual_tables
2. ChangeOwnPassword
3. CheckUserSpecificVocabulary
4. GetPrimaryRelationshipID
5. GetUserPrivileges
6. GrantVocabularyAccess
7. LogManualChanges
8. ModifyPrivilege
9. ModifyUserPrivilege
10. ModifyVirtualUser
11. ModifyVocabularyAccess
12. UpdateManualConceptID
13. VirtualLogIn
*/

--12. Run all modified sql-scripts: generic_update, fast_recreate_schema etc
