/*
 * Apply this script to a clean schema to get stage tables that could be applied
 * as a patch before running SNOMED's load_stage.sql.
 */

/*
    Contents:
    1. Route manual mapping
    2. Replacement relationships for UKDE concepts to dm+d
    3. Reassigned
 */

--1. TODO: incorporate manual mapping table
;
