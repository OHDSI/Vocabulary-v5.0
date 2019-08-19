--fix typo https://github.com/OHDSI/Vocabulary-v5.0/issues/159#issuecomment-519958606
update concept set concept_name='microgram per kilogram per minute' where concept_id=9688;
update concept_synonym set concept_synonym_name='microgram per kilogram per minute' where concept_id=9688;
