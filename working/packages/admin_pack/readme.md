### Package for administrative tasks and logging of manual work

The package is a new system for working with manual concepts (as well as mappings and synonyms), now all concepts are stored in one table, which is common to all vocabularies.
This allows you to work with them from any schema and generally simplifies development.
Also, a key feature of the system is the implementation of the so-called "virtual authorization", which allows you to uniquely identify the author of the change and the possibility of assigning personal privileges.

### How it works

Manual tables are now stored in devv5 and are "basic" like concept, concept_relationship etc, the FastRecreateSchema script now copies them to the specified schema when it runs (with the current state being cleared beforehand)
Names of "basic" manual tables:  
devv5.base_concept_manual  
devv5.base_concept_relationship_manual  
devv5.base_concept_synonym_manual  

The names of manual tables in dev-schemas have not changed, work with them is carried out as usual

Change control in manual tables is built into the generic_update. If there are changes, it will request virtual authorization, for this you will need to call the script:
```sql
SELECT admin_pack.VirtualLogIn('login','password');
```
After successful authorization, a virtual session is created, which is tied to the name of the current dev-schema and your IP address, and which lives as long as your real session with the postgres. In other words, if your connection is interrupted, the generic_update will request authorization again.
Next, the necessary privileges are checked, for example, the privilege to work with manual mappings, access to vocabularies, etc.
If all checks are passed, changes in manual tables will be accepted and written to a special log with the time and username of the user who created the new record (or changed the existing one). After moving the vocabulary to devv5, this information will go into the base manual tables.

### Installation

```sql
CREATE EXTENSION pgcrypto;
CREATE EXTENSION tablefunc;
```
Run admin_pack_ddl.sql (follow the instructions inside)

### User's guide
Do your job as always, then when you're ready to run the generic_update, do a virtual authorization  
```sql
SELECT admin_pack.VirtualLogIn ('login','password');
```
and then you can continue  

### Manager's guide

First log in with your username and password
```sql
SELECT admin_pack.VirtualLogIn ('login','password');
```

Creating an active virtual user (MANAGE_USER privilege required)
```sql
	DO $_$
	BEGIN
		PERFORM admin_pack.CreateVirtualUser(
			pUserLogin       =>'dev_jdoe', --it is better to create a login that matches the real login in the database (if applicable)
			pUserName        =>'John Doe', --full name
			pUserDescription =>'Vocabulary Team', --medical, customer, some comment, etc
			pPassWord        =>'password', --any strong password (has nothing to do with the real database password)
			pEmail           =>'jdoe@e-mail.com', --you can specify the user's e-mail (can be omitted)
			pValidStartDate  =>NULL, --can be omitted, default CURRENT_DATE
			pValidEndDate    =>NULL, --can be omitted, default 2099-12-31
			pIsBlocked       =>FALSE --you can create a blocked user, can be useful if you want to create a user in advance and then just unset the block flag via ModifyVirtualUser(), can be omitted, default FALSE
		);
	END $_$;
```
	login characters:
	1. consist of [A-z0-9._-]
	2. minimum length is 5

	password strength:
	1. at least one uppercase letter [A-Z]
	2. at least one lowercase letter [a-z]
	3. at least one special case letter: !`"'№%;:?&*()_+=~/\<>,.[]{}^$#-
	4. at least one digit [0-9]
	5. minimum length is 10

Creating an active virtual user with privileges (MANAGE_USER privilege required)
```sql
	DO $_$
	DECLARE
	iUserID INT4;
	BEGIN
		SELECT admin_pack.CreateVirtualUser(
			pUserLogin       =>'dev_jdoe',
			pUserName        =>'John Doe',
			pUserDescription =>'Vocabulary Team',
			pPassWord        =>'password'
		) INTO iUserID;

		--grant MANAGE_SPECIFIC_VOCABULARY to dev_jdoe (can work only with specified vocabulary)
		PERFORM admin_pack.GrantPrivilege(
			pUserID          =>iUserID,
			pPrivilegeID     =>admin_pack.GetPrivilegeIDByName('MANAGE_SPECIFIC_VOCABULARY'),
			pValidStartDate  =>NULL, --access will be granted from the specified day, default CURRENT_DATE (can be omitted)
			pValidEndDate    =>NULL, --access will be granted until the specified expiration date, default 2099-12-31 (can be omitted)
			pIsBlocked       =>FALSE --you can create a blocked access, can be useful if you want to grant access in advance and then just unset the block flag via ModifyUserPrivilege(), can be omitted, default FALSE
		);

		--grant access only to CPT4 to dev_jdoe
		PERFORM admin_pack.GrantVocabularyAccess(
			pUserID          =>iUserID,
			pVocabulary_id   =>'CPT4', --vocabulary_id
			pValidStartDate  =>NULL, --access to the vocabulary will be granted from the specified day, default CURRENT_DATE (can be omitted)
			pValidEndDate    =>NULL, --access to the vocabulary will be granted until the specified expiration date, default 2099-12-31 (can be omitted)
			pIsBlocked       =>FALSE --you can create a blocked access, can be useful if you want to grant access in advance and then just unset the block flag via ModifyVocabularyAccess(), can be omitted, default FALSE
		);
	END $_$;
```
or you can use separate SELECTs
```sql
		SELECT admin_pack.CreateVirtualUser(
			pUserLogin       =>'dev_jdoe',
			pUserName        =>'John Doe',
			pUserDescription =>'Vocabulary Team',
			pPassWord        =>'password'
		);

		SELECT admin_pack.GrantPrivilege(
			pUserID          =>admin_pack.GetUserIDByLogin('dev_jdoe'),
			pPrivilegeID     =>admin_pack.GetPrivilegeIDByName('MANAGE_ANY_VOCABULARY')
		);

		SELECT admin_pack.GrantVocabularyAccess(
			pUserID          =>admin_pack.GetUserIDByLogin('dev_jdoe'),
			pVocabulary_id   =>'CPT4' --vocabulary_id
		);
```

View user privileges (MANAGE_USER privilege required)  
For more info please read the comments inside the body of the function
```sql
	SELECT *
	FROM admin_pack.GetUserPrivileges()
	ORDER BY is_user_active DESC,
		user_login,
		is_privilege_alive DESC,
		is_privilege_active DESC,
		privilege_name;
```

View detailed logs by user id (VIEW_LOGS privilege required)
```sql
	SELECT log_id,
		table_name,
		tx_time AT TIME ZONE 'MSK' AS tx_time,
		op_time AT TIME ZONE 'MSK' AS op_time,
		tg_operation,
		tg_result,
		script_name,
		tx_id
	FROM admin_pack.GetLogByUserID(admin_pack.GetUserIDByLogin('dev_jdoe'))
	ORDER BY log_id DESC
	LIMIT 100;
```
### Admin's guide
Create new privilege (MANAGE_PRIVILEGE privilege required)
```sql
	DO $_$
	BEGIN
		PERFORM admin_pack.CreatePrivilege(
			pPrivilegeName         =>'NEW_PRIVILEGE', --name
			pPrivilegeDescription  =>'Privilege for doing some tasks' --description
		);
	END $_$;
```

### TO DO
ModifyVocabularyAccess  
ModifyVirtualUser  
ModifyUserPrivilege  
ModifyPrivilege  

```sql
SELECT * FROM devv5.v_base_concept_manual LIMIT 100;
SELECT * FROM devv5.v_base_concept_relationship_manual LIMIT 100;
SELECT * FROM devv5.v_base_concept_synonym_manual LIMIT 100;
```