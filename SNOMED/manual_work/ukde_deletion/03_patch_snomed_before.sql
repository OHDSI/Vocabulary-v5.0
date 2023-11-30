/*
 * Apply this script to a clean schema to get stage tables that could be applied
 * as a patch before running SNOMED's load_stage.sql.
 */

/*
    Contents:
    1. Route manual mapping
    2. Replacement relationships for UKDE concepts
       to dm+d (in 04_patch_snomed_after.sql)
    3. White-out of SNOMED concepts (in 05_patch_snomed_whiteout.sql)
 */

--1. TODO
-- Unless new information comes in, I assume this is
-- handled in concept_relationship_manual
;
