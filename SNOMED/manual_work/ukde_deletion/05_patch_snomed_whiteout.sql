/*
 * Apply this script to a schema after running SNOMED's release. Needs
 * retired_concepts table from the previous step.
 */

--3.1. White out the concepts
UPDATE concept c
SET
    concept_code = CASE c.domain_id
        WHEN 'Route' THEN c.concept_code
        ELSE gen_random_uuid() :: text
    END,
    concept_name = CASE c.domain_id
        WHEN 'Route' THEN c.concept_name || ' (retired module, do not use)'
        ELSE 'Concept belonged to retired SNOMED CT module, do not use'
    END,
    valid_end_date = LEAST(
        c.valid_end_date,
        TO_DATE('20220128', 'yyyymmdd')
    ),
    standard_concept = NULL,
    invalid_reason = COALESCE(c.invalid_reason, 'D')
FROM retired_concepts rc
WHERE
    c.concept_id = rc.concept_id
;
--3.2. Delete synonyms
DELETE FROM concept_synonym
WHERE concept_id IN (
    SELECT concept_id
    FROM retired_concepts
);
--DROP TABLE IF EXISTS retired_concepts CASCADE;
DROP TABLE IF EXISTS patch_date CASCADE;
DROP TABLE IF EXISTS vmpps, vmps, ampps, amps, licensed_route, comb_content_v, comb_content_a, virtual_product_ingredient,
    vtms, ont_drug_form, drug_form, ap_ingredient, ingredient_substances, combination_pack_ind, combination_prod_ind,
    unit_of_measure, forms, supplier, fake_supp, df_indicator, dmd2atc, dmd2bnf;
