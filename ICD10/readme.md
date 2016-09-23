Update of ICD10

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Schema UMLS
- Working directory ICD10.

1. Run load_stage.sql (with updated pVocabularyDate = latest update date)
2. Run generic_update.sql (from working directory)

 