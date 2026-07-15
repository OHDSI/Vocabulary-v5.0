# MONDO

MONDO is loaded as an OHDSI Vocabulary 5.0 source vocabulary from the MONDO ontology JSON distribution. The ETL creates MONDO concepts, synonyms, hierarchy relationships, replacement relationships, and reviewed mappings through the standard vocabulary stage tables.

## Load Steps

1. Create sources tables.
2. Register the vocabulary with `VOCABULARY_PACK.AddNewVocabulary` if MONDO is not present in the target vocabulary schema.
3. Create set of `download_mondo_sources` functions and associated-triggers and download the MONDO source files into `dev_mondo.mondo_json` and `dev_mondo.mondo_sssom_maps`.
4. Run `load_stage.sql` in the OHDSI vocabulary working schema till step 7 to create the linked Mondo content. 
5. Perform Manual work (done by vocabualry-steward so only _manual artifacts will be used by Core Vocabulary team)
6. Approve mappings either by human review, or pragmatical-validation or AI-reasoning.
6. Check that manual table is populated with content produced during previous step (to be shared with Core Team as flat files inputs) Continue the load stage (starting form step 7)
7. Run the standard OHDSI Standardized Vocabularies generic update process
8. Execute `concept_relationship_metadata.sql` AFTER generic (use the content provided by steward) in order to populate relationship_metadata 


