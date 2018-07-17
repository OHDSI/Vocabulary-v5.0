Update of CPT4

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- UMLS in SOURCES schema
- Working directory CPT4

1. Run load_stage.sql (The pVocabularyDate will be automatically retrieved from the UMLS [SOURCES.MRSMAP.vocabulary_date])
2. Run generic_update.sql (from working directory)

 