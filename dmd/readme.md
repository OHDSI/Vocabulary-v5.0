Update of dm+d

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory dmd
- Updated and released versions of RxNorm, RxNorm Extension and SNOMED vocabularies

1. Run create_source_tables.sql

2. Register to [NHSBSA](https://isd.digital.nhs.uk/trud/users/authenticated/filters/0/home) if you have not already, sign in and request the **latest version** of dm+d data.

* Click on the **Subscribe** option associated with the dm+d data release. This subscription is necessary to enable the download functionality for the vocabulary files.

4. Once subscribed, fill `vocabulary_access` table in development schema with your credentials to give an access to file download.

5. Run [`vocabulary_download.get_dmd()`](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_download/get_dmd.sql) in development schema to load all required source files, including dm+d XML files into OMOP-compliant source tables in the dedicated source schema. Files are stored in ZIP archives.

6. Run [`vocabulary_download.bash_functions_dmd()`](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_download/bash_functions_dmd.sql) to unpack all ZIP archives and get respective XMLs.

7. Once the dm+d XML files are acquired and their content is accessible within a database, PostgreSQL's built-in XML processing functions, particularly `xpath()`, allow us to target and retrieve data based on the hierarchical paths within each XML file. The provided PostgreSQL code snippet demonstrates how to extract data from the `f_vtm2.xml` file:

        --vtms: Virtual Therapeutic Moiety
        CREATE TABLE vtms AS
        SELECT
            unnest(xpath('/VTM/NM/text()', i.xmlfield))::VARCHAR AS NM,
            unnest(xpath('/VTM/VTMID/text()', i.xmlfield))::VARCHAR AS VTMID,
            unnest(xpath('/VTM/VTMIDPREV/text()', i.xmlfield))::VARCHAR AS VTMIDPREV,
            to_date(unnest(xpath('/VTM/VTMIDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') AS VTMIDDT,
            unnest(xpath('/VTM/INVALID/text()', i.xmlfield))::VARCHAR AS INVALID
        FROM (
            SELECT unnest(xpath('/VIRTUAL_THERAPEUTIC_MOIETIES/VTM', i.xmlfield)) AS xmlfield
            FROM sources.f_vtm2 i
        ) AS i;

This example illustrates the general approach to extracting data from the dm+d XML source files. Similar techniques applied to process the other XML files based on their specific structures.

For **each of the eight XML** files, a specific extraction process is defined to pull out the necessary attributes and elements corresponding to the respective dm+d entities. All queries could be found in `load_stage.sql``add link here` and do not require any changes.

8. Run [`additional_DDL.sql`](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/dmd/additional_DDL.sql) to create the auxiliary drug staging tables (DRUG_CONCEPT_STAGE, DS_STAGE, INTERNAL_RELATIONSHIP_STAGE, RELATIONSHIP_TO_CONCEPT, PC_STAGE) required for processing dm+d data.

9. Run 
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> true, include_deprecated_rels=> true, include_synonyms=> true);
   ```

10. Run load_stage.sql

11. Run automated and manual checks before the next step.

12. Run
```sql
   DO $_$
   BEGIN
       PERFORM vocabulary_pack.BuildRxE();
   END $_$;
   ```
13. Run postprocessing.sql

14. Run generic_update:
   ```sql
   DO $_$
   BEGIN
       PERFORM devv5.GenericUpdate();
   END $_$;
   ```
15. Run basic tables check (should retrieve NULL):
   ```sql
    SELECT * FROM qa_tests.get_checks();
```
16. Run scripts to get summary, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_summary('concept','dev_test9');
    SELECT DISTINCT * FROM qa_tests.get_summary('concept_relationship','dev_test9');
    ```
17. Run scripts to collect statistics, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_domain_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts();
    SELECT DISTINCT * FROM qa_tests.get_standard_concept_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts_standard_concept_status();
    SELECT DISTINCT * FROM qa_tests.get_changes_concept_mapping();
    ```
For the more precise update process and vocabulary specification, look at the documentation folder.