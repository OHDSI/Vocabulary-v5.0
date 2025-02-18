Update of ICD_CDE

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- UMLS in SOURCES schema
- SNOMED must be loaded first
- Working directory ICD_CDE

1. Run 
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>true, include_deprecated_rels=>true, include_synonyms=>true);
```
In every schema: 
- dev_icd10
- dev_icd10cm
- dev_icd10cn
- dev_icd10gm
- dev_kcd7
- dev_cim10
- dev_icd9cm

2. Backup the icd_cde_source table in the dev_icd10 schema.
3. Set ‘for_review’ field = null for every record
4. Run load_stage for every Vocabulary to be included in the CDE in the respective schemas (dev_icd10, dev_icd10cm, dev_icd10cn, dev_icd10gm, dev_kcd7, dev_cim10, dev_icd9cm). As a result, _stage tables in the respective schemas are updated.
5. Run ‘External_mapping_sources.sql’ script to gather data on external sources mapping changes
6. Run the 'mapping_refresh' script for every Vocabulary to be included into the CDE  in the respective schemas. As a result, tables with the naming pattern vocab_refresh (eg. icd10_refresh, icd10cm_refresh, etc.) are updated.
7. Run point 4 in 'icd_cde_source.sql' to insert changes for every vocabulary.
8. 'icd_community_contribution' table with community contribution data
9. Run point 5 in 'icd_cde_source.sql' to insert Community contribution
10. Run point 6 in 'icd_cde_source.sql' to trigger the review for changes of mappings from external sources
11. Run points 7-10 in 'icd_cde_source.sql' to check the inserted data (NULL-checks, simple SELECTs and if all the concepts are included in the environment).
12. Run point 11 in 'icd_cde_source.sql' for grouping
13. Run points 12, and 13 'icd_cde_source.sql' for grouping checks in 'icd_cde_source.sql' (one concept is in one group only and unique group names).
14. In point 14 'icd_cde_source.sql' adjust the conditions for review during every refresh and run them. This step can be changed from release to release.
15. Assemble the _manual table (icd_cde_manual) in point 15 of 'icd_cde_source.sql'.
16. Perform and review manual work here. The file must be reuploaded every time. It works as a delta for the vocabulary refresh. The rules of the flag populations are described here.
17. Upload the results in the icd_cde_mapped table and run updates from points 16 and 17 in 'icd_cde_source.sql'. They will update multiple fields (metadata fields, decisions, decision_date, etc.).
18. Run point 18 in 'icd_cde_source.sql' to fill the icd_cde_proc. All concept_relationship_manual fields are updated from this table.
19. Run ‘icd_cde_proc_checks’ to detect wrong mappings and check if all the community contributions were included.
20. For each vocabulary run process of update (described in readme.md for every vocabulary in corresponding folder). If any mistakes were detected in ‘Checks_after_generic’
    repeat steps 16 – 21
21. After all the updated vocabularies are in devv5, backup icd_cde_source one more time. Run point 19 from icd_cde_source.sql to update the icd_cde_source table on the icd_cde_mapped table.