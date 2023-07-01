Update of HemOnc

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory HemOnc

1. Upload the source tables
2. Make sure that manual tables are populated with most recent content (see the https://github.com/OHDSI/Vocabulary-v5.0/blob/master/HemOnc/manual_work/readme_manual_tables.md)
3. Run load_stage.sql
4.  Run generic_update:
```sql
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;
```
5.  Run basic tables check (should retrieve NULL):
```sql
SELECT * FROM qa_tests.get_checks();
```

6. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql), and interpret the results.
7. Run scripts to get summary, and interpret the results:
```sql
SELECT * FROM qa_tests.get_summary('concept');
```
```sql
SELECT * FROM qa_tests.get_summary('concept_relationship');
```
8. Run scripts to collect statistics, and interpret the results:
```sql
SELECT * FROM qa_tests.get_domain_changes();
```
```sql
SELECT * FROM qa_tests.get_newly_concepts();
```
```sql
SELECT * FROM qa_tests.get_standard_concept_changes();
```
```sql
SELECT * FROM qa_tests.get_newly_concepts_standard_concept_status();
```
```sql
SELECT * FROM qa_tests.get_changes_concept_mapping();
```

If no problems, enjoy!
