### ATC Refresh Process ###

#### Prerequisites: ####

- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- SNOMED, RxNorm,  RxNorm Extension, ATC sources must be loaded first with the full release cycle.
- Working directory dev_atc.
1. Run 
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> true, include_deprecated_rels=> true, include_synonyms=> true);
   ``` 
2. Prepare the working environment using the content of *manual_work* folder
3. Run *load_input.sql* that populates a temporary table with ATC - RxNorm relationships from various sources, including the group of sourced processed fully automatically: dmd, grr, vandf, jmdc, dpd, sources, that require some manual corrections: bpdm, Z-index, Norway Drug Bank and KDC. The whole list of the sources with the descriptions is available from the [ATC documentation](https://github.com/OHDSI/Vocabulary-v5.0/wiki/Vocab.-ATC). The ATC - RxNorm relationships, collected from the above-mentioned sources, are subject to the semi-automatic review. The results of the review are incorporated into the atc_rxnorm_to_drop_in_sources table (manual_work folder). 
4. Run *update_manual_tables.sql* to modify concept_manual and concept_relationships_manual tables.
5. Run *load_stage.sql*
6. Run *generic_update.sql*
    ```sql
    SELECT devv5.GenericUpdate();
    ```
7. Run 
    ```sql
   DO $_$
   BEGIN
       PERFORM build_class_to_drug();
   END $_$;
    ```
8. Perform *post-processing*, which builds hierarchical relationships:

    ```sql
    DO $_$
    BEGIN
        PERFORM VOCABULARY_PACK.pConceptAncestor();
    END $_$;
    ```
   
9. Enjoy the results!