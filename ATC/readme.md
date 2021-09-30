### ATC Refresh Process ###

#### Prerequisites: ####
* Basic knowledge of the [ATC vocabulary as a part of OMOP CDM](https://www.ohdsi.org/web/wiki/doku.php?id=documentation:vocabulary:atc)
* Schema DEVV5 with copies of tables concept, concept_relationship and concept_synonym from PRODV5, fully indexed
* SNOMED, RxNorm and RxNorm Extension must be loaded first with the full release cycle.
* Working directory, e.g. *dev_atc*.

#### I - Manual work ####
1. Create a backup of the **class_drugs_scraper** table
2. There are 2 options:
**Scenario A** - addendum of new ATC codes
Insert them manually into the **class_drugs_scraper** table, populating the following fields: class_code (varchar), class_name (varchar), ddd (varchar), u (varchar), adm_r (varchar), note (varchar), valid_start_date (date), valid_end_date (date), change_type (varchar). The query example:
```sql
INSERT INTO class_drugs_scraper
SELECT id,
       atc_code AS class_code,
       atc_name AS class_name,
       ddd,
       u,
       adm_r,
       note,
       TO_DATE('2021-01-01','YYYYMMDD') AS valid_start_date,
       TO_DATE('20991231','YYYYMMDD') AS valid_end_date,
       'A' AS change_type
FROM atc_addendum_MMYY;
```
**Scenario B** - changes of the existing ATC codes 
Insert them as new entities into the class_drugs_scraper table assigning them unique ids and preserving old versions of ATC codes.
3. Using class_drugs_scraper, add new codes with OMOPized names and their row variants to the concept_manual and concept_synonym_manual tables respectively.

#### II - Machinery ####
1. Run load_input.sql, which populates the **input tables** of *drug_concept_stage, internal_relationship_stage, relationship_to_concept* and ATC-specific *dev_combo*.
2. Run load_interim.sql, which prepares the **class_to_drug** table containing links bwetween ATC Drug Classes and RxN/RxE Drug Products 
3. Run load_stage.sql which populates the **staging tables** of *concept_stage, concept_relationship_stage*, and *concept_synonym_stage*
4. Run generic_update.sql
5. Perform post-processing:
```sql
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.pConceptAncestor(IS_SMALL=>TRUE);
END $_$;
```
1. Run load_stage.sql
2. Run generic_update:
```sql
SELECT devv5.genericupdate();
```sql
