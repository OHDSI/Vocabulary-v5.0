# HemOnc Refresh 

---


## Context

Additional information:

- [HemOnc cookbook](https://docs.google.com/document/d/19fqNqPS2oDbB5mwsoN4Zm3WSU0YOKGyfi5qZUyZLhgg/edit?usp=sharing).
- [The OHDSI HemOnc Wiki](https://github.com/OHDSI/Vocabulary-v5.0/wiki/Vocab.-HemOnc)
- [Local community dev environement walkthrough](https://github.com/OHDSI/Vocabulary-v5.0/tree/local_environment/working/local_environment)

### Relevant notes

- There are two separate and required input pathways 
	-  1 - Official releases: published by HemOnc and hosted on the [dataverse.Harvard](https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/FPO4HB) platform
. These tables need to be created (script provided) and ingested into the 'sources' schema. In each release, there are only three files that are relevant and need to be uploaded:
		- concept_stage
		- concept_relationship_stage
		- concept_syonynm_stage
	
	- 2 - A pair of "manual" tables for ad hoc adjustments to relationships and synonyms, currently maintained in a pair of google docs. These tables should be ingested in the 'dev_hemonc' schema. See [readme](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/HemOnc/manual_work/readme_manual_tables.md) for more details. The two tables:
		- concept_relationship_manual -> [here](https://docs.google.com/spreadsheets/d/17C887UjOZxPPJ0_H58AUU7mFuEq2wVD_EHQLpW2vth8/edit?usp=sharing)
		- concept_synonym_manual   -> [here](https://docs.google.com/spreadsheets/d/17C887UjOZxPPJ0_H58AUU7mFuEq2wVD_EHQLpW2vth8/edit?usp=sharing)
		
- Only a small subset of HemOnc is currently (2025) integrated from HemOnc into the OHDSI standard vocabularies 
	- The bulk of what is integrated are the domains are Regimen, Components, sublcasses of each, relationships between them and a focus on relationships to standard drug concepts, notably RxNorm
	- While condition and procedure mappings exist, much more rarely (~1%), they are they byproduct of the manual mapping effort and subsequent integration of the manual tables during the build process
	- Similarly, given the scope of concepts from the source is being filtered down, so too are the relationships that are included


---


## Setup

### Database
- The development environment requires Postgres:
	- PostgreSQL or higher
	- a "development" build with 'plsh' installed (along with a handful of other extensions)

### Build Schemas

The build environment requires 7 separate schemas to be present and populated in order to execute 

A General walkthrough on this process can be found here: https://github.com/OHDSI/Vocabulary-v5.0/tree/local_environment/working/local_environment

1) 'sources' - Solely used for storing staging files from source. Pipeline hardcoded to expect it here 
	- step 1: create schema
	- step 2: run DDL https://github.com/OHDSI/Vocabulary-v5.0/blob/master/HemOnc/create_source_tables.sql 
	- step 3: upload the three source files into the newly created tables 

2) 'devv5' - The source of truth of the most recent vocabulary release. Used to compare against and contains the main load and update functions 
	- *Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.*
	- Step 1: Run DDL https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/DevV5_DDL.sql
	- Step 2: Create schema functions (provided in walkthrough above)
	- Step 3: Upload vocabularies
	- Step 4: Index 
3) 'dev_hemonc' - This is your working directory. After execution the results are compared against devv5 to create a delta for QA
	- Step 1: Create a copy of the tables and data from 'devv5'. Functions excluded 
	- Step 2: Run DDL for [manual tables](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/HemOnc/manual_work/readme_manual_tables.md) . Only concept_relationship_manual & concept_synonym_manual are needed from : https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/DevV5_DDL.sql#L160 for HemOnc
	- Step 3: Download (from google docs) and Import 'manual' tables into newly created tables WITHIN 'dev_hemonc'

- The remaining 4 schema are purely functional, essentially containers for various scripts. 
	- 'qa_tests'
	- 'admin_pack'
	- 'vocabulary_pack'
	- 'vocabulary_download'

There is plenty of documentation on how to instantiate these on [the local dev environement walkthrough](https://github.com/OHDSI/Vocabulary-v5.0/tree/local_environment/working/local_environment). Additionally, should issues arise, the source code of this functionality can be found within [Vocabulary-v5.0/working/packages/...](https://github.com/OHDSI/Vocabulary-v5.0/tree/local_environment/working/packages) in their respective folders. 






## Execution


1. Run load_stage.sql
	-  "*The script load_stage performs an ETL from the original format to the OMOP CDM. Each vocabulary has their own load_stage.*"
	- HemOnc load_stage is found here: https://github.com/OHDSI/Vocabulary-v5.0/blob/master/HemOnc/load_stage.sql
	- This is complex step with many pieces. If you are having an issue, it is likely here. It is recommended to step through and understand what this script is doing should issues be encountered.
	- For example, this merges in the source data as as well as the manual data, derives and instantiates drug relationships, renames and collapses relationships, and so on. 



2.  Run generic_update:
```sql
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;
```
3.  Run basic tables check (should retrieve NULL):
```sql
SELECT * FROM qa_tests.get_checks();
```

4. Run scripts to get summary, and interpret the results:
```sql
SELECT * FROM qa_tests.get_summary('concept');
```
```sql
SELECT * FROM qa_tests.get_summary('concept_relationship');
```
5. Run scripts to collect statistics, and interpret the results:
```sql
SELECT * FROM qa_tests.get_domain_changes();
```
```sql
SELECT * FROM qa_tests.get_newly_concepts();
```
```sql
SELECT * FROM qa_tests.get_standard_concept_changes();
```
```sql
SELECT * FROM qa_tests.get_newly_concepts_standard_concept_status();
```
```sql
SELECT * FROM qa_tests.get_changes_concept_mapping();
```
6. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql), and interpret the results.

If no problems, enjoy! 
