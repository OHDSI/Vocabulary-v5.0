Update of HemOnc

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory HemOnc

1. Upload the source tables
2. Make sure that manual tables are populated with most recent content (see the https://github.com/OHDSI/Vocabulary-v5.0/blob/master/HemOnc/manual_work/readme_manual_tables.md)
3. Run load_stage.sql
4. Run generic_update: devv5.GenericUpdate();
5. Run basic tables check (should retrieve NULL)
6. Run manual_checks_after_generic.sql, and interpret the results.
7. Run scripts to get summary, and interpret the results.
8. Run scripts to collect statistics, and interpret the results.
If no problems, enjoy!
