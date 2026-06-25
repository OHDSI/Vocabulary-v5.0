/*
================================================================================
4 - SeedBasedHecateMine_multithread run.sql
================================================================================

Purpose
-------
Run Hecate semantic mining for the oncology seed table created in step 3.

Prerequisites
-------------
- Deploy working/packages/vocabulary_pack/SeedBasedHecateMine_multithread.sql.
- Run from dev_cancer_modifier, or set search_path so seeding_table resolves
  to dev_cancer_modifier.seeding_table.
- Ensure plpython3u and outbound HTTPS access to Hecate are available.

Created objects
---------------
- hecate_mined_snomed
- hecate_mined_LOINC
- hecate_mined_NAACCR
================================================================================
*/

-- -----------------------------------------------------------------------------
-- Section 04.01: Mine SNOMED candidates from oncology seeds
-- -----------------------------------------------------------------------------
SELECT *
FROM vocabulary_pack.hecate_populate_similar_results_mt(
    p_output_table         => 'hecate_mined_snomed',
    p_input_table          => 'seeding_table',
    p_vocabulary_id        => 'SNOMED',
    p_domain_id            => 'Condition,Measurement,Observation,Meas Value',
    p_concept_class_id     => 'Doc Type of Service,Lab Test,Disorder,Observable Entity,Context-dependent,Answer,Staging / Scales,Clinical Finding,Qualifier Value,Procedure,Clinical Observation,NAACCR Value,NAACCR Variable',
    p_top_x                => 10,
    p_min_similarity_score => 0.75,
    p_thread_count         => 20,
    p_max_retries          => 1
);

-- -----------------------------------------------------------------------------
-- Section 04.02: Mine LOINC candidates from oncology seeds
-- -----------------------------------------------------------------------------
SELECT *
FROM vocabulary_pack.hecate_populate_similar_results_mt(
    p_output_table         => 'hecate_mined_LOINC',
    p_input_table          => 'seeding_table',
    p_vocabulary_id        => 'LOINC',
    p_domain_id            => 'Procedure,Measurement,Observation,Meas Value',
    p_concept_class_id     => 'Doc Type of Service,Lab Test,Disorder,Observable Entity,Context-dependent,Answer,Staging / Scales,Clinical Finding,Qualifier Value,Procedure,Clinical Observation,NAACCR Value,NAACCR Variable',
    p_top_x                => 10,
    p_min_similarity_score => 0.75,
    p_thread_count         => 20,
    p_max_retries          => 1
);

-- -----------------------------------------------------------------------------
-- Section 04.03: Mine NAACCR candidates from oncology seeds
-- -----------------------------------------------------------------------------
SELECT *
FROM vocabulary_pack.hecate_populate_similar_results_mt(
    p_output_table         => 'hecate_mined_NAACCR',
    p_input_table          => 'seeding_table',
    p_vocabulary_id        => 'NAACCR',
    p_domain_id            => 'Measurement,Procedure,Meas Value',
    p_concept_class_id     => 'Doc Type of Service,Lab Test,Disorder,Observable Entity,Context-dependent,Answer,Staging / Scales,Clinical Finding,Qualifier Value,Procedure,Clinical Observation,NAACCR Value,NAACCR Variable,NAACCR Procedure',
    p_top_x                => 10,
    p_min_similarity_score => 0.75,
    p_thread_count         => 20,
    p_max_retries          => 1
);
