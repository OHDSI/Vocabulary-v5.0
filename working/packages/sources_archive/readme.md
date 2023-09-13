# Package for storing archives of source tables
### How to install
1. Run installation.sql in devv5
2. Put AddVocabularyToArchive function call in a load_input_tables.sql script for each vocabulary to be archived. This call should be the very last item after the source tables have been fully loaded  
Example:
```SQL
PERFORM sources_archive.AddVocabularyToArchive(
	'RxNorm', --name of the vocabulary
	ARRAY['rxnatomarchive','rxnconso','rxnrel','rxnsat'], --tables to archive
	COALESCE(pVocabularyDate,current_date), --latest update
	'archive.rxnorm_version', --parameter name
	10 --retention period (number of versions)
);
```

### How it works
The idea is to use the mechanism of [RLS policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html), when the data in the tables that the client sees depends on external parameters, while there is no need to rewrite sql queries

### Usage
1. Connect to the required dev-schema
2. Run FastRecreateSchema as usual
3. Get load_stage.sql content and replace all "sources." prefixes to "sources_archive." (e.g. with notepad++)
4. Reset all external params
```SQL
DO $$
BEGIN
	PERFORM sources_archive.ResetArchiveParams();
END $$;
```
5. Set the required version for each source table (vocabulary)
```SQL
DO $$
BEGIN
	PERFORM sources_archive.SetArchiveParams(
		'RxNorm',
		TO_DATE('20230103','yyyymmdd')
	);
END $$;
```

NOTE: you can combine multiple calls to SetArchiveParams for each vocabulary that is used in the ls-script  
NOTE: if no version is set for the vocabulary, then the latest one is used (in fact, as if the request goes to "sources." )  
NOTE: **Parameters (versions) for vocabularies are saved during your current session in which you run SetArchiveParams. Therefore, if the connection is interrupted, you need to repeat setting the parameters.** It is a good practice to set parameters before every execution of the load_stage.

If you don't know which vocabulary a given source table belongs to, you can check it with ShowArchiveDetails
```SQL
SELECT * FROM sources_archive.ShowArchiveDetails() WHERE table_name = 'rxnatomarchive';
```
NOTE: you can immediately see all the versions that are available for this table in the archive

***For reference*** you can use the GetTablesFromLS function with the full URL of the load_stage.sql RAW content
```SQL
SELECT * FROM sources_archive.GetTablesFromLS('https://raw.githubusercontent.com/OHDSI/Vocabulary-v5.0/master/RxNorm/load_stage.sql');
```

6. Make sure all parameters for all required sources are set correctly
```SQL
SELECT * FROM sources_archive.ShowArchiveParams();
```
7. Run modified load_stage.sql
8. Run GenericUpdate, qa-tests etc as usual
9. If everything is ok, the stage-tables are ready to be moved to devv5 (SetLatestUpdate+devv5.MoveToDevV5())  
NOTE: don't forget to change date/version in SetLatestUpdate to hardcoded values

### Restrictions
1. If the vocabulary needs to be renamed, then you need to replace its name in the archive_conversion table, and manually reassign the policy to all tables related to it (remove the old one, assign a new one with a new vocabulary name in the argument)
2. Parameters (versions) for vocabularies are saved during your current session in which you run SetArchiveParams. Therefore, if the connection is interrupted, you need to repeat setting the parameters
