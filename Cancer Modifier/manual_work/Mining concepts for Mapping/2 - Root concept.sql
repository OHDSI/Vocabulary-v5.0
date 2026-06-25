/*
================================================================================
01__create_root_oncology_seed_list.sql
================================================================================

Purpose
-------
Create a small maintainable table of root oncology concepts used to define the
initial seed scope.

================================================================================
*/
-- -----------------------------------------------------------------------------
-- Recreate root seed table
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS dev_cancer_modifier.onco_seed_roots;

CREATE UNLOGGED TABLE dev_cancer_modifier.onco_seed_roots
(
    seed_concept_id integer PRIMARY KEY,
    seed_comment    text
);

-- -----------------------------------------------------------------------------
--  Insert root oncology seed concepts
-- -----------------------------------------------------------------------------
INSERT INTO dev_cancer_modifier.onco_seed_roots(seed_concept_id, seed_comment)
VALUES (4300140, 'Tumor stage finding | SNOMED 385356007'),
       (37163866, 'American Joint Committee on Cancer allowable value | SNOMED 1222584008'),
       (1449377, 'Union for International Cancer Control allowable value | SNOMED 1352503003'),
       (37168578, 'Level of neoplasm response to antineoplastic neoadjuvant therapy | SNOMED 1285138006'),
       (4216788, 'Tumor finding | SNOMED 395557000'),
       (3008495, 'Stage group.pathology Cancer | LOINC 21902-2'),
       (3006575, 'Distant metastases.clinical [Class] Cancer | LOINC 21907-1'),
       (3013189, 'Regional lymph nodes.pathology [Class] Cancer | LOINC 21900-6'),
       (3022698, 'Stage group.clinical Cancer | LOINC 21908-9'),
       (4161054, 'Finding of histologic grading differentiation AND/OR behavior | SNOMED 373369003'),
       (40769844, 'Disease stage | LOINC 67213-9'),
       (4111627, 'Tumor staging | SNOMED Staging / Scales'),
       (3007727, 'Regional lymph nodes.clinical [Class] Cancer| LOINC Clinical Observation'),
       (3008841, 'Primary tumor.clinical [Class] Cancer| LOINC Clinical Observation'),
       (35918889, 'TNM Path T| NAACCR NAACCR Variable'),
       (35918791, 'TNM Path N| NAACCR NAACCR Variable'),
       (35918319, 'TNM Path M| NAACCR NAACCR Variable'),
       (35918746, 'TNM Clin N| NAACCR NAACCR Variable'),
       (35918562, 'TNM Clin T| NAACCR NAACCR Variable'),
       (35918383, 'TNM Clin M| NAACCR NAACCR Variable'),
       (35918597, 'TNM Clin Stage Group| NAACCR NAACCR Variable'),
       (35918286, 'TNM Path Stage Group| NAACCR NAACCR Variable'),
       (35918542, 'Grade Clinical| NAACCR NAACCR Variable'),
       (35918640, 'Grade Pathological| NAACCR NAACCR Variable'),
       (35918328, 'Grade| NAACCR NAACCR Variable'),
       (35918515, 'Gleason Score Pathological| NAACCR NAACCR Variable'),
       (35918815, 'CS Mets at DX| NAACCR NAACCR Variable'),
       (35918661, 'EOD Regional Nodes| NAACCR NAACCR Variable'),
       (35918871, 'Gleason Patterns Pathological| NAACCR NAACCR Variable'),
       (432851, 'Metastatic malignant neoplasm| SNOMED Disorder'),
       (4175557, 'FAB type values| SNOMED Qualifier Value'),
        (4308014, 'ECOG performance status| SNOMED Observable Entity'),
        (4169154, 'Karnofsky performance status| SNOMED Staging / Scales'),
        (36303744, 'Karnofsky Performance Status [Interpretation]| LOINC Clinical Observation'),
        (36305384, 'ECOG Performance Status score| LOINC Clinical Observation')



;

-- -----------------------------------------------------------------------------
-- Analyze and preview root seeds
-- -----------------------------------------------------------------------------
ANALYZE dev_cancer_modifier.onco_seed_roots;

