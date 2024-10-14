Update of EORTC QLQ Vocabulary

Prerequisites:
- Vocabulary Server infrastructure
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory EORTC

1. Run the vocabulary_download.get_eortc (automated scraping was set-up with twice a year schedule or scraping can be performed on-demand basis)
   1. The Item Library Web-Site (itemlibrary.eortc.org) version dated Spring-2024 was used for initial scraper set-up;
   2. The Credentials are linked to OHDSI Vocabulary Account (permission from EORTC team was received via e-mail)
3. Run 
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>true, include_deprecated_rels=>true, include_synonyms=>true);
```
4. Run *load_stage.sql*
4. Run *generic_update.sql*
    ```sql
    SELECT devv5.genericupdate();
    ```
   *NB! EORTC QLQ  is treated as a full source vocabulary*
5. Run basic tables check (should retrieve NULL):
```sql
SELECT * FROM qa_tests.get_checks();
```
Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql), and interpret the results.

6. Run scripts to get summary, and interpret the results:
```sql
SELECT * FROM qa_tests.get_summary('concept');
SELECT * FROM qa_tests.get_summary('concept_relationship');
```
7. Run scripts to collect statistics, and interpret the results:
```sql
SELECT * FROM qa_tests.get_domain_changes();
SELECT * FROM qa_tests.get_newly_concepts();
SELECT * FROM qa_tests.get_standard_concept_changes();
SELECT * FROM qa_tests.get_newly_concepts_standard_concept_status();
SELECT * FROM qa_tests.get_changes_concept_mapping();
```
8. Run checks from vocabulary specific *manual_work* folder
9. If no problems, enjoy!
