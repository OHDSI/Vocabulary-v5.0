Update of HPO Semantic Mappings by its steward

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- UMLS in SOURCES schema
- Working directory HPO


**1. Run scripts from create_automated_mapping_tables in order to prepare mapping candidates environment**

**2. Update Mapping Candidates Sources**
* Run OHDSI HECATE in Python environment using /api/search_standard (refer to https://hecate.pantheon-hds.com/openapi/#/) (use HPO_ID as source_code,HPO_NAME as source_code_description as well as HPO_NAME as search_name/query parameter)
  * Import HECATE Content via prefferd mechanism (COPY, bulk import etc)
* Check for updates of External Mapping Content
  1. if source is updated:
     2. w/o syntax/structure changes- simply upload to corresponding tables 
        1. check content (e.g. null values, new patterns in fields) changes 
           1. If content is intact (no new patterns seen) - keep as is 
           2. If content is altered - adjust mapping pipeline a.k.a. insert statements  (`hpo_mapping_pipeline.sql`)
     3. w/ syntax/structure changes 
        1. adjust DDLs (HPO->manual work->Mapping Related Work->create_automated_mapping_tables.sql) and Insertion scripts (`hpo_mapping_pipeline.sql`), 
  2. if source is NOT updated
     1. Upload the previous version of the source 

**3. Create the function InitiateHPOMappingPipeline stored at `hpo_mapping_pipeline.sql` ** 

**4. Run  - it as a part of load stage as Semantic mapping update (step 7)** 
* Isolate the portion for manual review (isolation heuristic may vary depending on release plans)
* Populate the hpo_mapped table with content to be processed at the time of the release (`manual_mapping_incorporation.sql`) (fow steward only)
**5. Continue the load stage (Core Vocabulary team should use only fully equipped manual tables inputs, not hte pipeline)** 
