### Manual work for Cancer Modifier refresh

Cancer Modifier is maintained through the standard OHDSI manual tables. Approved manual content is loaded into `concept_manual`, `concept_relationship_manual` and, if needed, `concept_synonym_manual` in `dev_cancer_modifier`, then applied by `Cancer Modifier/load_stage.sql` through `vocabulary_pack.ProcessManualConcepts`, `vocabulary_pack.ProcessManualSynonyms` and `vocabulary_pack.ProcessManualRelationships`.

The manual workflow has two possible inputs:
- Existing curated Cancer Modifier manual files.
- Optional oncology mining output from [`Mining concepts for Mapping`](Mining%20concepts%20for%20Mapping/readme.md), reviewed through the CDE handoff.
- The Step 1 and 3 of the process are expected to be executed by Integration Team, however clean version of manual tables are also considered as proper inputs for load stage run.

#### STEP 1 of the refresh: upload existing manual tables
Directory with manual files either class-specific or class-agnostic delta is https://drive.google.com/drive/u/3/folders/11T6VNxgPALmaxyeKgJN65F4WIjfISfvj

In the majority of refresh cases since summer 2026, please consider using the class-agnostic delta refresh: https://drive.google.com/drive/u/3/folders/1PHIk5eyTrWPut0Jto2w90J8PT6Mck2MR.

1.1. Update `concept_manual` into the working schema. (see the `populate_manual_tables_with_refresh_content.sql`)
Extract the required  flat file with delta content into the `concept_manual_refresh` table.
Delta may contain newly-added valid concepts or apply adjustments to existing corpus. Make sure that deprecation/de-standartization is explicitly declared if desired.
 
1.2. Update `concept_relationship_manual` into the working schema. (see the `populate_manual_tables_with_refresh_content.sql`)
1.2. Upload `concept_relationship_manual_refresh` into the working schema if a curated relationship file is available. Make sure that deprecation/de-standartization is explicitly declared if desired.

1.2. Update `concept_synonym_manual` into the working schema. (see the `populate_manual_tables_with_refresh_content.sql`)
1.2. Upload `concept_synonym_manual_refresh` into the working schema if a synonym file is available. 

##### csv format:
- delimiter: ','
- encoding: 'UTF8'
- header: ON
- decimal symbol: '.'
- quote escape: with backslash \
- quote always: FALSE
- NULL string: empty

#### STEP 2 of the refresh: prepare additional oncology mapping candidates (for vocabulary developers /mapping curators only)

2.1. If new oncology candidates are needed, run the mining workflow described in [`Mining concepts for Mapping/readme.md`](Mining%20concepts%20for%20Mapping/readme.md).

2.2. Use the clean step 6 script from that folder to create CDE-ready review tables. The preferred review output has one row per proposed mapping or review decision, not one row per `source_concept_id`. A source concept can therefore have multiple rows, each with its own `decision`, `to_destandardize`, `create_standard` and `comment` flags.

2.3. Export the curation tables to the working group spreadsheet and complete curator review there.

#### STEP 3 of the refresh: convert approved CDE rows to manual tables 

3.1. Load the reviewed spreadsheet rows into `dev_cancer_modifier.cancer_modifier_cde`.

3.2. Check that approved new Cancer Modifier were loaded as concepts to `concept_manual` first. This step establishes the Cancer Modifier concept codes that can be used as mapping targets in the same refresh.

3.3. Execute script `populate_manual_tables_with_CDE_content.sql`. This script is aimed to configure the codes to be destandardized, codes to be created as well as apply relevant mappings.

##### csv format:
- delimiter: ','
- encoding: 'UTF8'
- header: ON
- decimal symbol: '.'
- quote escape: with backslash \
- quote always: FALSE
- NULL string: empty

This order is intentional: `load_stage.sql` processes manual concepts before manual relationships, so newly created Cancer Modifier concepts are available before mappings to those concepts are incorporated.
