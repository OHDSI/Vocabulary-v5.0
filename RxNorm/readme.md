Update of RxNorm, NDFRT, VA Product, VA Class and ATC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- SNOMED must be loaded first
- Working directory RxNorm.

1. Run create_source_tables.sql
2. Download RxNorm_full_MMDDYYYY.zip from http://www.nlm.nih.gov/research/umls/rxnorm/docs/rxnormfiles.html
3. Extract and load into the tables from the folder rrf. Use the control files of the same name
RXNATOMARCHIVE
RXNCONSO
RXNCUI
RXNCUICHANGES
RXNDOC
RXNREL
RXNSAB
RXNSAT
RXNSTY 

4. Run load_stage.sql
5. Run generic_update.sql (from working directory)

 