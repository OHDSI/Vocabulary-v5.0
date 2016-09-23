Update of EphMRA ATC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory EphMRA ATC.

1. Run create_source_tables.sql
2. Load file ATC_Glossary.csv into ATC_Glossary table. Use the control files of the same name.
3. Run load_stage.sql (with updated pVocabularyDate = latest update of vocabulary)
4. Run generic_update.sql (from working directory)

 