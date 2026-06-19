# T1DX Vocabulary Build Runbook

## Source loading
The source vocabulary content is maintained in the OHDSI Vocabulary Google Drive as manually curated input tables. These tables serve as the source files for generating the corresponding vocabulary stage records. The detailed loading procedure, including file preparation and execution steps, is documented in [manual_work/README.md](manual_work/README.md).

## Environment prerequisites
- A main development vocabulary schema (e.g. `devv5`) with:
  - Fresh copies of `concept`, `concept_relationship`, `concept_synonym` and `concept_ancestor` from production.
  - All standard indexes and constraints in place.
- T1DX source data loaded into the local development schema (e.g. `dev_t1dx`):
  - `concept_manual`
  - `concept_relationship_manual`
  - `concept_synonym_manual`
- Vocabulary utilities and QA functions available:
  - `vocabulary_pack.*`
  - `qa_tests.*`

## Action sequence
1. **Reset local dev schema using main dev schema (e.g.`devv5`)**:  
   ```sql
   SELECT devv5.FastRecreateSchema(
     include_concept_ancestor => TRUE,
     include_deprecated_rels  => TRUE,
     include_synonyms         => TRUE
   );
   ```

2. **Prepare the T1DX manual layer**: 
   Follow the instructions in [manual_work/README.md](manual_work/README.md) to download, import, QA, and populate the T1DX manual tables.

3. **Run [T1DX/load_stage.sql](load_stage.sql)**:

   This rebuilds `concept_stage`, `concept_synonym_stage`, and `concept_relationship_stage` for T1DX.

4. **Run [generic update](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/generic_update.sql)**:
   ```sql
   SELECT devv5.genericupdate();
   ```
This moves staged T1DX content into the `concept` and `concept_relationship` tables in your local dev schema.

5. **Perform QA after generic run**
   Compare the build results with the same source schema that was used for FastRecreateSchema() (e.g., devv5 in the example below). Always pass this schema explicitly to the differential QA functions, because their default comparison schema is `prodv5`.
   ```sql
   SELECT qa_tests.get_checks();
   SELECT * FROM qa_tests.get_summary('concept','devv5');
   SELECT * FROM qa_tests.get_summary('concept_relationship','devv5');
   SELECT * FROM qa_tests.get_domain_changes(pCompareWith => 'devv5');
   SELECT * FROM qa_tests.get_newly_concepts(pCompareWith => 'devv5');
   SELECT * FROM qa_tests.get_standard_concept_changes(pCompareWith => 'devv5');
   SELECT * FROM qa_tests.get_newly_concepts_standard_concept_status(pCompareWith => 'devv5');
   SELECT * FROM qa_tests.get_changes_concept_mapping(pCompareWith => 'devv5');
   ```
Address any blocking issues before promoting dev to production.

6. **Run manual concept ancestor build**:
   ```sql
   DO $_$
   	BEGIN
   		PERFORM vocabulary_pack.pManualConceptAncestor(pVocabularies=>'T1DX');
   	END $_$;
   ```
This populates the `concept_ancestor` table in your local dev schema.

7. **Run [T1DX/metadata.sql](metadata.sql)**

8. **Promote to production**

   Once all is done, the vocabulary is built.

> You can read more about the T1DX build logic here: [link](https://docs.google.com/document/d/1101_CdYe2b-aM89Oen_oU_-63V3yalRZ75XjOlEsN-w/edit?usp=sharing).
