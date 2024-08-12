Update of CDISC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Schema NCI metathesaurus (UMLS-based NCI release: meta_ used as a prefix for canonical UMLS Tables)
- Schema UMLS
- Schema dev_cdisc
- Working directory CDISC.

1. Run FastRecreate to set-up proper content version
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> true, include_deprecated_rels=> true, include_synonyms=> true);
   ```
2. Update the concept_class_lookup table for cases when new semantic attributes appear (https://docs.google.com/spreadsheets/d/1LeBg7hWEg-XoLp8TsyMUMW4bsXlYqCh0LpJIFqm9ajY/edit?gid=0#gid=0)
```sql
SELECT DISTINCT st.sty as attribute,
       NULL::varchar as concept_class_id,
       domain_id::varchar
FROM  sources.meta_mrconso s
JOIN  sources.meta_mrsty st 
   ON s.cui = st.cui
WHERE s.sab='CDISC'
   ```
3. Perform manual mappings based on Pre-selected priorities, upload the result into cdisc_mapped (cdisc_refresh.sql)
4. Run load_stage.sql
5. Run generic_update:
   ```sql
   DO $_$
   BEGIN
       PERFORM devv5.GenericUpdate();
   END $_$;
   ```
6. Run basic tables check (should retrieve NULL):
   ```sql
    SELECT * FROM qa_tests.get_checks();
7. cdisc_mapped (pre-manual table created outside the LS) and cdisc_automapped (pre-stage table created inside the LS) tables' content to be used for MetaData Vocabulary processing