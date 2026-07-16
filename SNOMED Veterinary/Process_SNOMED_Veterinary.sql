\echo 'Starting devv5.FastRecreateSchema'

SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> true, include_deprecated_rels=> true, include_synonyms=> true);

\echo 'Starting load_stage'

\i load_stage.sql

\echo 'Starting devv5.GenericUpdate'

Select devv5.GenericUpdate();

\echo 'Post GenericUpdate'

\i post_generic_update_fixes.sql

\echo 'Deleting non-SNOMED Veterinary concepts and relationships in manual files'

\i update_manual_files.sql

\echo 'qa_tests.get_checks'

SELECT * FROM qa_tests.get_checks(); 

\echo 'Setting output to get_summary_concept_devv5.txt'

\o get_summary_concept_devv5.txt 

\echo 'qa_tests.get_summary'

SELECT DISTINCT * FROM qa_tests.get_summary('concept', 'devv5'); 

\o 

\echo 'Setting output get_summary_concept_relationship_devv5.txt'

\o get_summary_concept_relationship_devv5.txt 

\echo 'qa_tests.get_summary'

SELECT DISTINCT * FROM qa_tests.get_summary('concept_relationship', 'devv5'); 

\o 

\echo 'Setting output qa_tests_get_domain_changes.txt'

\o qa_tests_get_domain_changes.txt 

\echo 'qa_tests.get_domain_changes'

SELECT DISTINCT * FROM qa_tests.get_domain_changes('devv5'); 

\o 

\echo 'Setting output qa_tests_get_newly_concepts.txt'

\o qa_tests_get_newly_concepts.txt 

\echo 'qa_tests.get_newly_concepts'

SELECT DISTINCT * FROM qa_tests.get_newly_concepts('devv5'); 

\o 

\echo 'Setting output qa_tests_get_standard_concept_changes.txt'

\o qa_tests_get_standard_concept_changes.txt 

\echo 'qa_tests.get_standard_concept_changes'

SELECT DISTINCT * FROM qa_tests.get_standard_concept_changes('devv5'); 

\o 

\echo 'Setting output qa_tests_get_newly_concepts_standard_concept_status.txt' 

\o qa_tests_get_newly_concepts_standard_concept_status.txt 

\echo 'qa_tests.get_newly_concepts_standard_concept_status'

SELECT DISTINCT * FROM qa_tests.get_newly_concepts_standard_concept_status('devv5'); 

\o 

\echo 'Setting output qa_tests_get_changes_concept_mapping.txt'

\o qa_tests_get_changes_concept_mapping.txt 

\echo 'qa_tests.get_changes_concept_mapping'

SELECT DISTINCT * FROM qa_tests.get_changes_concept_mapping('devv5'); 

\o 

\echo 'Setting output manual_checks_after_generic_update.txt'

\o manual_checks_after_generic_update.txt

\echo ' manual_checks_after_generic_update.'

\i manual_checks_after_generic_update.sql  

\o 
\echo 'Extract vet synonyms for SNOMED core'

\i Extract_vet_synonyms_to_SNOMED_core.sql 
