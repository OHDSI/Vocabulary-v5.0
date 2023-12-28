# Script for retirement of existing SNOMED CT United Kingdom Drug Extension content
## Background
See the [forum post](https://forums.ohdsi.org/t/announcing-the-retirement-of-snomed-ct-uk-drug-extension/20487).

## Pre-requisites
* GenericUpdate version that supports pMode specification
* A clean schema with current versions of dm+d and Gemscript
* Any `SNOMED/load_stage.sql` version that excludes UKDE modules
## Execution order
1. Run `01_patch_dmd.sql`
2. Run `GenericUpdate('DELTA')`
3. Run `01A_patch_dmd_after.sql`
4. Run `02_patch_gemscript.sql`
5. Run `GenericUpdate('DELTA').`
6. Run `03_patch_snomed_before.sql`
7. Run `SNOMED/load_stage.sql`
8. Run `04_patch_snomed_after.sql`
9. Run `GenericUpdate()`
10. Run `05_patch_snomed_whiteout.sql`
11. Run normal QA routines and `specific_qa/test_ukde_deletion_result.sql`
