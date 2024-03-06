### ATC Refresh Process ###

#### Prerequisites: ####
* Basic knowledge of the [ATC vocabulary as a part of OMOP CDM](https://www.ohdsi.org/web/wiki/doku.php?id=documentation:vocabulary:atc)
* Schema DEVV5 with copies of tables concept, concept_relationship and concept_synonym from PRODV5, fully indexed
* SNOMED, RxNorm and RxNorm Extension must be loaded first with the full release cycle
* Working directory, e.g. *dev_atc*

#### I - Manual work ####
1. Prepare the working environment using the content of *manual_work* folder
2. Create a backup of the **class_drugs_scraper** and **class_to_drug** tables
```sql
CREATE TABLE class_drugs_scraper_mmyy AS SELECT * FROM class_drugs_scraper;
CREATE TABLE sources_class_to_drug_old AS SELECT * FROM sources.class_to_drug; -- note, that postfix '_old' is obligatory to add, because it is used in further steps
```
3. There are 3 options:
**Scenario A** - addendum of new ATC codes
- Insert them manually into the **class_drugs_scraper** table, populating the following fields: class_code (varchar), class_name (varchar), ddd (varchar), u (varchar), adm_r (varchar), note (varchar), valid_start_date (date), valid_end_date (date), change_type (varchar). The query example:
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
- Insert them as new entities into the **class_drugs_scraper** table assigning them unique *ids* and preserving old versions of ATC codes
**Scenario C** - use Scenario A together with Scenario B if both the addendum and changes are required

4. Using the **class_drugs_scraper** table, add new codes with _OMOPized names_ and their *original versions* to the **concept_manual** and **concept_synonym_manual** tables respectively

#### II - Machinery ####
5. Run *load_input.sql*, which populates the **input tables** of **drug_concept_stage, internal_relationship_stage, relationship_to_concept** and ATC-specific **dev_combo**
6. Run *load_interim.sql*, which prepares the **class_to_drug** table containing links bwetween ATC Drug Classes and RxN/RxE Drug Products
7. Run the procedure which overwrites the new version of class_to_drug instead old one in the schema of 'sources'
```sql
SELECT * FROM vocabulary_pack.CreateTablesCopiesATC ();
```
8. Run *load_stage.sql* which populates the **staging tables** of **concept_stage, concept_relationship_stage**, and **concept_synonym_stage**
9. Run *generic_update.sql*
```sql
SELECT devv5.genericupdate();
```
10. Perform **post-processing**:
```sql
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.pConceptAncestor(IS_SMALL=>TRUE);
END $_$;
```
11. enjoy!
