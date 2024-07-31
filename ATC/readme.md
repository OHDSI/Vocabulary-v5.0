### ATC Refresh Process ###

#### Prerequisites: ####

- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- SNOMED, RxNorm,  RxNorm Extension, ATC sources must be loaded first with the full release cycle.
- Working directory dev_atc.

1. Prepare the working environment using the content of *manual_work* folder
2. Run *load_input.sql* that populates the table with ATC - RxNorm connections from different sources, that do not need
manual control (dmd, grr, umls, vandf, jmdc, dpd) and sources, that need some manual preparations bpdm (don't have ATC codes in source files,
need to be grabbed separately), z-index (manual table), Norway drug bank https://www.legemiddelsok.no/ (doesn't have connection to RxN, RxNE, need to be
boilered). And for sure not all ATC - RxNorm conditions have a good quality and
the manual review is needed. For these reasons we are using the table atc_rxnorm_to_drop_in_sources, that contains all wrong connections,
that came from sources. The manual tables should be prepared separately and uploaded into DB.
3. Run *load_stage.sql* which populates the **staging tables** of **concept_stage, concept_relationship_stage**, and **concept_synonym_stage**
4. Run *generic_update.sql*
    ```sql
    SELECT devv5.genericupdate();
    ```
5.  Perform **post-processing**:
    ```sql
    DO $_$
    BEGIN
        PERFORM VOCABULARY_PACK.pConceptAncestor(IS_SMALL=>TRUE);
    END $_$;
    ```
6. Upgrading process is finished