Update of CDT

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- UMLS in SOURCES schema
- Working directory CDT

1. Run load_stage.sql (The pVocabularyDate will be automatically retrieved from the UMLS [SOURCES.MRSMAP.vocabulary_date])
2. Run generic_update: devv5.GenericUpdate();