This is a "universal" load_stage script for cases when it is not possible to run a full load_stage, but you need to make a few hotfixes (for example, urgently change the mapping or the name of the concept)
Usage:  
1. Log in under the required schema dev_xyz
2. Run
```sql
DO $$
BEGIN
	PERFORM devv5.FastRecreateSchema(include_synonyms=>true,include_deprecated_rels=>true,main_schema_name=>'devv5');
END $$;
```
3. Fill in manual tables based on the proposed changes
4. Run the universal load_stage by filling the pVocabs variable with a list of vocabularies (separated by commas) and replacing the schema name in the pSchemaName variable with the current value (p1)
5. Run generic_update and other QA functions as needed

Description:  
The script completely copies the vocabulary(s) from the base tables to the stage tables and applies the changes from the manual tables. Latest_update does not change (the old value from devv5.vocabulary_conversion remains).
