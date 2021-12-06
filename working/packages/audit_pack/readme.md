# Package for logging of the base tables in devv5 with the ability to restore to any point in time in any dev-schema
### How to install
1. Run in devv5 all \*.sql, first audit.sql, then all the others
2. Done!

The main goal is to create a complete and detailed history of changes/additions in the base tables.
Supported tables are:
* concept
* concept_class
* concept_relationship
* concept_synonym
* domain
* drug_strength
* pack_content
* relationship
* vocabulary
* vocabulary_conversion

Trigger-based script writes all inserts, updates, deletes to the audit.logged_actions table, with the name of the script(s) that made this change.
Old version of row (for update/delete) contains json-based value with all fields of affected table, similarly for new row (insert).
NOTE: if the update made did not actually change the row, for example, "update concept set concept_name = 'aaa' where concept_name = 'aaa', then it will not be written.
Also the table contains additional fields that can help in debugging, e.g. tx_time (transaction start time), tx_id (transaction ID) etc.

There are several functions for easier viewing - `GetLogSummary`, `GetLogByID` and `RestoreBasicTables` for recovery.

# Examples

To view a short aggregated history of base tables changes, type
```SQL
SELECT log_id,
	tx_time AT TIME ZONE 'MSK' AS tx_time,
	script_name,
	affected_vocabs,
	tx_id
FROM audit.GetLogSummary()
ORDER BY log_id DESC
LIMIT 10;
```

Will only show the important steps that were taken in the base tables.

Pay attention to the construction "AT TIME ZONE 'MSK'", it allows you to display the time in the Moscow time zone, otherwise the server time will be displayed.

Some explanations:
* log_id - minimum identifier value for this operation (needed for `RestoreBasicTables`)
* script_name - is a field that contains the name of the script that made the change, for example GenericUpdate. If the script was called as part of another script, it will also be shown, for example, "UpdateAllVocabularies -> GenericUpdate".
NOTE: If the change was made manually, for example "update concept set concept_name = '1' where concept_id = 1", then the corresponding query will be shown marked "Manual".
* affected_vocabs - the vocabularies that were specified in `SetLatestUpdate`, with the schema name (e.g. NDC, SPL [DEV_NDC]).

If you want to see the history of a specific concept, type
```SQL
SELECT log_id,
	table_name,
	tx_time AT TIME ZONE 'MSK' AS tx_time,
	op_time AT TIME ZONE 'MSK' AS op_time,
	tg_operation,
	tg_result,
	script_name,
	tx_id
FROM audit.GetLogByID (iConceptID=>1800731)
ORDER BY log_id DESC
LIMIT 100;
```

At the moment in this example we will see 3 rows that the first time the concept appeared on August 30th (along with a synonym), and then on September 12th, it has a relationship to RxNorm.

Some explanations:
* op_time - actual time when the row was changed
* tg_result - this field will display a new row if it was an INSERT, an old row if it was a DELETE, and the difference if there was an UPDATE. In square brackets will be shown the key to quickly find a row in the corresponding table

NOTE: as `iConceptID` you can use the field concept_id (`concept`, `concept_synonym`), concept_id_1 (`concept_relationship`), relationship_concept_id (`relationship`), vocabulary_concept_id (`vocabulary`), concept_class_concept_id (`concept_class`), domain_concept_id (`domain`), drug_concept_id (`drug_strength`), pack_concept_id (`pack_content`).

If you want to see the history of a specific transaction, type
```SQL
SELECT log_id,
	table_name,
	tx_time AT TIME ZONE 'MSK' AS tx_time,
	op_time AT TIME ZONE 'MSK' AS op_time,
	tg_operation,
	tg_result,
	script_name,
	tx_id
FROM audit.GetLogByID (iTransactionID=>37877090)
ORDER BY log_id DESC
LIMIT 100;
```

Will show all changes to the base tables made during this transaction.

---

Through detailed logs, it is possible to use them to restore dev-schema (and even directly devv5) at any convenient time. For example, if you want to restore the dev-schema to the moment before the latest update, the following steps are needed:
1. Connect to the required dev-schema
2. Run
```SQL
DO $$
BEGIN
	PERFORM devv5.FastRecreateSchema(include_deprecated_rels=>true,include_synonyms=>true);
END $$;
```
3. Get the corresponding log_id from `GetLogSummary`

![audit package](https://i.imgur.com/1LA51xK.png)

4. Substitute it into `RestoreBasicTables` and run
```SQL
DO $$
BEGIN
	PERFORM audit.RestoreBasicTables(iLogID=>XXXXX);
END $$;
```

After some time the dev-schema will be restored (including event from selected log_id).

If you want to see which vocabularies have been updated since the last release, type 
```SQL
SELECT MAX(tx_time) AS tx_time,
	s0.affected_vocabs
FROM (
	SELECT log_id,
		tx_time AT TIME ZONE 'MSK' AS tx_time,
		affected_vocabs,
		MAX(log_id) FILTER(WHERE script_name = 'StartRelease') OVER () latest_release_id
	FROM audit.GetLogSummary()
	) s0
WHERE s0.log_id > s0.latest_release_id
	AND s0.affected_vocabs IS NOT NULL
GROUP BY s0.affected_vocabs
ORDER BY 1 DESC;
```

---

## Keep in mind
- The concept_ancestor table is not supported by this package and won't be affected in any way.
- If you plan using the concept_ancestor table in any of the dev schemas you're working in, rebuild it on updated basic tables using the respective [function](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/pConceptAncestor.sql).
- If you will not use the concept_ancestor table, keep it trancated or even drop it in order to avoid unexpected results of its querying.
