Update of CDT

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Schema UMLS
- Working directory CDT

1. Run load_stage.sql (with updated pVocabularyDate = latest update of UMLS)
2. Run generic_update.sql (from working directory)

 