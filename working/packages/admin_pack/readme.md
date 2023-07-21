### Package for administrative tasks and logging of manual work

The package is a new system for working with manual concepts (as well as mappings and synonyms). Currently, concepts are stored in one table, which is shared by all vocabularies.
This approach allows users to work with them from any schema and simplifies development.
Also, a key feature of the system is the implementation of the so-called "virtual authorization" which allows users to uniquely identify the author of the change and the possibility of assigning personal privileges.

### How it works

Manual tables are stored in devv5 and considered "basic" like the concept, concept_relationship, etc. The FastRecreateSchema script now copies them to the specified schema when it runs (with the current state being overwritten)
Names of "basic" manual tables: 
```sql
devv5.base_concept_manual
devv5.base_concept_relationship_manual
devv5.base_concept_synonym_manual
```

The names of manual tables in dev schemas have not been changed, and work with them is carried out as usual.

Control of the changes in manual tables is built into the generic_update. If user doesn't change any manual concepts / relationships, no autorization is required for generic_update.
If there are changes, generic_update will request virtual authorization. For authorization you will need to call the script:
```sql
SELECT admin_pack.VirtualLogIn('login','password');
```
After successful authorization, a virtual session is created, which is bound to the name of the current dev-schema and your IP address, and which lives as long as your postgres session. In other words, if your connection is interrupted, the generic_update will request authorization again.

Next, the necessary privileges are checked, for example, the privilege to work with manual mappings, access to vocabularies, etc.
If all checks are passed, changes in manual tables will be accepted and written to a log table with the time and username of the user who created the new record (or changed the existing one). After moving the vocabulary to devv5, this information will migrate into the base manual tables.

There is no need for a logout. Users can switch schemas and virtually log in every time before the genericupdate. Users can disconnect from the database to stop their session.

List of existing privileges and their description:

| Priviledge                 | Description                                                                                                                                        |
|----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| MANAGE_ANY_VOCABULARY      | Granted to OHDSI Vocbulary team members to manage any content in any vocabulary                                                                    |
| MANAGE_SPECIFIC_VOCABULARY | Group of priviledges (eg. MANAGE_SNOMED, MANAGE_ICD10), granted to OHDSI collaborators to manage content within specific vocabulary                |
| MANAGE_VOCABULARY_PACK     | Group of priviledges (eg. MANAGE_OPEN_VOCABULARIES), granted to OHDSI collaborators to manage content within the predefined group of vocabularies  |


Besides privileges to manage vocabularies, users also differ in their access to the vocabularies as in [Athena](https://athena.ohdsi.org/search-terms/terms). License restricted vocabularies are open only to users with license (checked by OHDSI Vocabulary team). 

After the GenericUpdate run in local schema, manual tables from schemas are merged with "basic" tables in devv5 by OHDSI Vocabulary team.

### Installation

```sql
CREATE EXTENSION pgcrypto;
CREATE EXTENSION tablefunc;
--Run admin_pack_ddl.sql (follow the instructions inside)
```

### User's guide
Work as always, then when you're ready to run the generic_update, perform a virtual authorization  
```sql
SELECT admin_pack.VirtualLogIn ('login','password');
```
and then you can continue

Changing password (virtual session will be invalidated)
```sql
SELECT admin_pack.ChangeOwnPassword ('old_password','new_password');
```

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
		pVocabulary_id   =>'CPT4',
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

Modify specific user (MANAGE_USER privilege required)
```sql
DO $_$
BEGIN
	PERFORM admin_pack.ModifyVirtualUser(
		pUserID           =>admin_pack.GetUserIDByLogin('dev_jdoe'), --user's virtual login
		pUserLogin        =>NULL, --set NULL if you don't want to change the user's login
		pUserName         =>NULL, --set NULL if you don't want to change the user's name
		pUserDescription  =>NULL, --set NULL if you don't want to change the user's description
		pPassWord         =>NULL, --set NULL if you don't want to change the user's password
		pEmail            =>NULL, --set NULL if you don't want to change the user's e-mail
		pValidStartDate   =>NULL, --set NULL if you don't want to change the start date
		pValidEndDate     =>NULL, --set NULL if you don't want to change the end date
		pIsBlocked        =>TRUE --just block the specified user
	);
END $_$;
```
Shorter version
```sql
DO $_$
BEGIN
	PERFORM admin_pack.ModifyVirtualUser(
		pUserID           =>admin_pack.GetUserIDByLogin('dev_jdoe'), --user's virtual login
		pIsBlocked        =>TRUE --just block the specified user
	);
END $_$;
```

Modify privilege for specific user (MANAGE_USER privilege required)
```sql
DO $_$
BEGIN
	PERFORM admin_pack.ModifyUserPrivilege(
		pUserID          =>admin_pack.GetUserIDByLogin('dev_jdoe'), --user's virtual login
		pPrivilegeID     =>admin_pack.GetPrivilegeIDByName('MANAGE_USER'),
		pValidStartDate  =>NULL, --set NULL if you don't want to change the start date
		pValidEndDate    =>NULL, --set NULL if you don't want to change the end date
		pIsBlocked       =>TRUE --block privilege for the specified user
	);
END $_$;
```
Shorter version
```sql
DO $_$
BEGIN
	PERFORM admin_pack.ModifyUserPrivilege(
		pUserID          =>admin_pack.GetUserIDByLogin('dev_jdoe'), --user's virtual login
		pPrivilegeID     =>admin_pack.GetPrivilegeIDByName('MANAGE_USER'),
		pIsBlocked       =>TRUE --block privilege for the specified user
	);
END $_$;
```

Modify vocabulary access for specific user (MANAGE_USER privilege required)
```sql
DO $_$
BEGIN
	PERFORM admin_pack.ModifyVocabularyAccess(
		pUserID          =>admin_pack.GetUserIDByLogin('dev_jdoe'), --user's virtual login
		pVocabulary_id   =>'CPT4', --vocabulary_id for which access is being changed
		pValidStartDate  =>NULL, --by default we don't want to change it (but there may be a situation when you want to correct the start date)
		pValidEndDate    =>NULL, --by default we don't want to change it (but there may be a situation when you want to correct the end date)
		pIsBlocked       =>TRUE --block access
	);
END $_$;
```
Shorter version
```sql
DO $_$
BEGIN
	PERFORM admin_pack.ModifyVocabularyAccess(
		pUserID          =>admin_pack.GetUserIDByLogin('dev_jdoe'), --user's virtual login
		pVocabulary_id   =>'CPT4', --vocabulary_id for which access is being changed
		pIsBlocked       =>TRUE --block access
	);
END $_$;
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
Privileges are managed by OHDSI Vocabulary. 

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

Modify specific privilege (MANAGE_PRIVILEGE privilege required)
```sql
DO $_$
BEGIN
	PERFORM admin_pack.ModifyPrivilege(
		pPrivilegeID           => admin_pack.GetPrivilegeIDByName('MANAGE_PRIVILEGE'),
		pPrivilegeName         => NULL, --or 'NEW_PRIVILEGE_NAME' <--be careful changing this value, you have to change all functions dependent on this name
		pPrivilegeDescription  => NULL, --or 'New privilege description'
		pIsBlocked             => FALSE --or TRUE if you want to block privilege
	);
END $_$;
```

### View information about manual concepts and relationships with author and editor (free access, no privilege required)
```sql
SELECT * FROM devv5.v_base_concept_manual LIMIT 100;
SELECT * FROM devv5.v_base_concept_relationship_manual LIMIT 100;
SELECT * FROM devv5.v_base_concept_synonym_manual LIMIT 100;
```


## FAQ
### Merge conflict
In cases when two users insert conflicting mappings in manual tables, only one resulting relationship will be present in "basic" manual tables. The resulting relationship depends on which relationship has been inserted last. As a result, in the Log table, one row per each change (one insert, one update) will be present. Such conflict may affect chaining of mappings in AddFreshMapsToValue.

### Direction of the relationships
To maintain correct functioning of logging of changes in manual tables, there is only one direction for each relationship that can be used. The relationships are defined in ProcessManualRelationships function.
```sql
select devv5.GetPrimaryRelationshipID(r.relationship_id) correct_rel, r.relationship_id from devv5.relationship r;
```