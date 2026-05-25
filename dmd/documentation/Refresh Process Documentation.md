# Refresh Process Documentation

This document outlines the standardized procedure for refreshing the dm+d vocabulary integration within the OHDSI Standardized Vocabularies, ensuring synchronization with the latest versions of RxNorm, RxNorm Extension, CVX, SNOMED CT and dm+d as distributed via the NHSBSA TRUD3 portal.

## Prerequisites:
* Development schema with copies of tables concept, concept_relationship and concept_synonym from production schema, fully indexed.

**Note!** If you do not have such schemas, follow the steps described at `Schema Creation.md``add link here`.

* Working directory dmd
* NHS TRUD Account
* **8** dm+d data files requested from [NHSBSA TRUD3](https://isd.digital.nhs.uk/trud/users/authenticated/filters/0/home) website.
* [Latest versions](https://athena.ohdsi.org/vocabulary/list) of the next vocabulary:
  
|Vocabulary|
|---|
|dm+d|
|RxNorm|
|RxNorm Extension|
|SNOMED CT|
|CVX|
|UCUM|

## Update algorithm:

1. Run [`create_source_tables.sql`](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/dmd/create_source_tables.sql)

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

9. Run [`latest_update.sql`](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/SetLatestUpdate.sql) in **working schema** for the affected vocabulary (dm+d, RxNorm Extension) to apply the latest vocabulary metadata updates.

10. Run `load_stage.sql``add link here` to populate the staging tables with preprocessed dm+d content. For a detailed explanation of this process, refer to the Load Stage Logic Documentation `add link here`.

**Note!** The load_stage.sql `add link here` contains commented-out queries that identify concepts requiring manual mapping. These concepts are typically those that cannot be accurately mapped automatically. The following tables are generated for manual mapping:

|Table Name|Description|Row Number in load_stage.sql`add link here`|
|---|---|---|
|tomap_vmps_ds_man|VMPS that missed drug strength for manual mapping|2323| 
|tomap_ingreds_man|Ingredients to map|3562|
|tomap_units_man|Units for manual mapping|3610|
|tomap_forms_man|Drug Forms for manual mapping|3653|
|tofind_brands_man|Branded Drugs for manual mapping|3999|
|tomap_bn_man|Brand Names for manual mapping|4209|
|tomap_supplier_man_mapping |Suppliers for manual mapping|4332|

For those concepts, perform manual mapping using spreadsheet software such as Google Excel or other suitable text/data editors.

Upon completion of manual mapping for the identified concepts, the resultant mapping tables must be uploaded to the `concept_relationship_manual` table. This step is critical and must be completed **before any subsequent post-processing** operations are performed.

11. Run automated and manual checks before the next step.

    a. automated:

    * [`drug_stage_tables_QA.sql`](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/drug_stage_tables_QA.sql)

    * [`input_QA_integratable_E.sql`](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/input_QA_integratable_E.sql)

    * [`input_QA_integratable_W.sql`](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/input_QA_integratable_W.sql)

    b. manual:

    * [add link here]

12. Run [`build_RxE.sql`](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/packages/vocabulary_pack/BuildRxE.sql) to construct the RxNorm Extension content filling gaps where RxNorm lacks coverage for UK-specific medicinal products.

13. Run [`postprocessing.sql`](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/dmd/postprocessing.sql) to deprecate outdated mappings, prioritize mappings to SNOMED CT for devices, reconstruct valid `Maps to` relationships from updated sources, restore essential mappings for deprecated VMP and clean and deduplicate all staging tables.  

14. Run [`generic_update()`](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/generic_update.sql) to execute the core OMOP vocabulary update routine, which finalizes the integration by refreshing concept, concept_relationship, and concept_synonym with the newly processed dm+d content.

15. Run [`manual_checks_after_generic_update.sql`](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic_update.sql)

16. Look [`qa_tests`](https://github.com/OHDSI/Vocabulary-v5.0/tree/master/working/packages/QA_TESTS) to look through the difference in vocabularies