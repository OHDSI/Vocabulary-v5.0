Find more information in the [HemOnc cookbook here](https://docs.google.com/document/d/19fqNqPS2oDbB5mwsoN4Zm3WSU0YOKGyfi5qZUyZLhgg/edit?usp=sharing).
Refresh of HemOnc:

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory HemOnc

1. Upload the source tables
2. Make sure that manual tables are populated with most recent content (see the https://github.com/OHDSI/Vocabulary-v5.0/blob/master/HemOnc/manual_work/readme_manual_tables.md)
3. Run FastRecreate:
```sql
   SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> true, include_deprecated_rels=> true, include_synonyms=> true);
```
4. Implement manual changes
5. Run load_stage.sql
6.  Run generic_update:
```sql
    DO $_$
    BEGIN
        PERFORM devv5.GenericUpdate();
    END $_$;
```
7.  Run basic tables check (should retrieve NULL):
```sql
    SELECT * FROM qa_tests.get_checks();
```
8. Run scripts to get summary, and interpret the results:
```sql
    SELECT * FROM qa_tests.get_summary('concept');
    SELECT * FROM qa_tests.get_summary('concept_relationship');
```
9. Run scripts to collect statistics, and interpret the results:
```sql
    SELECT * FROM qa_tests.get_domain_changes();
    SELECT * FROM qa_tests.get_newly_concepts();
    SELECT * FROM qa_tests.get_standard_concept_changes();
    SELECT * FROM qa_tests.get_newly_concepts_standard_concept_status();
    SELECT * FROM qa_tests.get_changes_concept_mapping();
```
10. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql), and interpret the results.

If no problems, enjoy!
