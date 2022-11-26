1. Download all ClaML files from https://www.dimdi.de/dynamic/de/klassifikationen/downloads/?dir=ops/ **for all years**
2. Use Python processing script (OPS_convert.py) to extract source files and fill in the source tables. Append resulting tables to ops_src_agg and modifiers_append with version year as last field.
3. Run FULL FastRecreate: SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> false, include_deprecated_rels=> true, include_synonyms=> true);
4. Run load_stage.sql; supply automated translations as needed in concept_manual.
5. Run check_stage_tables function (should retrieve NULL): SELECT * FROM qa_tests.check_stage_tables();
6. Run generic_update: DO $$ BEGIN PERFORM devv5.GenericUpdate(); END $$;
7. Run basic tables check (should retrieve NULL): SELECT * FROM qa_tests.get_checks();
8. Perform manual work described in the readme.md file in the 'manual_work' folder.

Repeat steps 6-11. 

9. Clear cache: SELECT * FROM qa_tests.purge_cache();
10. Run scripts to get summary, and interpret the results: SELECT DISTINCT * FROM qa_tests.get_summary('concept'); SELECT DISTINCT * FROM qa_tests.get_summary('concept_relationship');
11. Run scripts to collect statistics, and interpret the results: SELECT DISTINCT * FROM qa_tests.get_domain_changes(); SELECT DISTINCT * FROM qa_tests.get_newly_concepts(); SELECT DISTINCT * FROM qa_tests.get_standard_concept_changes(); SELECT DISTINCT * FROM qa_tests.get_newly_concepts_standard_concept_status(); SELECT DISTINCT * FROM qa_tests.get_changes_concept_mapping();
12. Run manual_checks_after_generic.sql, and interpret the results. 
13. Run project_specific_manual_checks_after_generic.sql, and interpret the results. 
14. If no problems, enjoy!

Manual tables directory permalink:
https://drive.google.com/drive/u/1/folders/1P2dJ9PDMDuu03K-EqzAR8QgmLj72kEB0

TODO:
Update scripts to depend on basic tables to extract dates, so that we need only ClaML files for current year.