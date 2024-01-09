# Script for retirement of existing SNOMED CT United Kingdom Drug Extension content
## Background
See the [forum post](https://forums.ohdsi.org/t/announcing-the-retirement-of-snomed-ct-uk-drug-extension/20487).

## Pre-requisites
* GenericUpdate version that supports pMode specification
* A clean schema with current versions of dm+d and Gemscript
* Any `SNOMED/load_stage.sql` version that excludes UKDE modules
## Execution order
1. Only in devv5: Run `00_patch_dmd.sql`
2. Update patch date in step '--0.3' of 01_patch_dmd.sql
3. Run `01_patch_dmd.sql`
4. Run `GenericUpdate('DELTA')`
5. Run `02_patch_gemscript.sql`
6. Run `GenericUpdate('DELTA').`
7. Run `03_patch_snomed_before.sql`
8. Run `SNOMED/load_stage.sql`
9. Run `04_patch_snomed_after.sql`
10. Run `GenericUpdate()`
11. Run `05_patch_snomed_whiteout.sql`
12. Run normal QA routines and `specific_qa/test_ukde_deletion_result.sql`
