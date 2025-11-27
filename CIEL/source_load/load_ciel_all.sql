
CREATE OR REPLACE FUNCTION sources.load_ciel_all(
  p_token          text,              -- OCL token
  p_source_version text DEFAULT NULL, -- e.g. 'v2025-10-19' or NULL for latest
  p_clear          boolean DEFAULT true
)
RETURNS TABLE(
  step           text,
  rows_processed bigint,
  started_at     timestamptz,
  finished_at    timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_started_at timestamptz := now();
  v_finished  timestamptz;

  v_versions_upserted bigint;
  v_concepts_upserted bigint;
  v_names_upserted    bigint;
  v_mappings_upserted bigint;
BEGIN
  -- 0. Optional TRUNCATE
  IF p_clear THEN
    TRUNCATE sources.ciel_concepts,
             sources.ciel_concept_names,
             sources.ciel_concept_retired_history,
             sources.ciel_source_versions,
             sources.ciel_mappings;
  END IF;

  -- 1. Token for HTTP
  PERFORM set_config('ocl.token', p_token, false);

  -- 2. Source versions
  SELECT versions_upserted, started_at, finished_at
  INTO v_versions_upserted, v_started_at, v_finished
  FROM sources.load_ciel_source_versions(200, 0.1);

  step           := 'source_versions';
  rows_processed := v_versions_upserted;
  started_at     := v_started_at;
  finished_at    := v_finished;
  RETURN NEXT;

  -- 3. Concepts + Normalized names
  SELECT concepts_upserted, names_upserted, started_at, finished_at
  INTO v_concepts_upserted, v_names_upserted, v_started_at, v_finished
  FROM sources.load_ciel_concepts('full', NULL, 1000, 0.2, p_source_version);

  step           := 'concepts';
  rows_processed := v_concepts_upserted;
  started_at     := v_started_at;
  finished_at    := v_finished;
  RETURN NEXT;

  step           := 'names';
  rows_processed := v_names_upserted;
  started_at     := v_started_at;
  finished_at    := v_finished;
  RETURN NEXT;

  -- 4. Add latest_source_version to concepts
  IF p_source_version IS NOT NULL THEN
    UPDATE sources.ciel_concepts
    SET latest_source_version = p_source_version;
  ELSE
    WITH latest_ver AS (
      SELECT version
      FROM sources.ciel_source_versions
      ORDER BY created_on DESC
      LIMIT 1
    )
    UPDATE sources.ciel_concepts c
    SET latest_source_version = v.version
    FROM latest_ver v;
  END IF;

  step           := 'update_latest_source_version';
  rows_processed := (SELECT count(*) FROM sources.ciel_concepts);
  started_at     := now();
  finished_at    := now();
  RETURN NEXT;

  -- 5. History for retired concepts
  PERFORM sources.populate_retired_history_for_all();

  step           := 'populate_retired_history_for_all';
  rows_processed := (SELECT count(*) FROM sources.ciel_concept_retired_history);
  started_at     := now();
  finished_at    := now();
  RETURN NEXT;

  -- 6. Mappings
  SELECT mappings_upserted, started_at, finished_at
  INTO v_mappings_upserted, v_started_at, v_finished
  FROM sources.load_ciel_mappings('full', NULL, 1000, 0.2, p_source_version);

  step           := 'mappings';
  rows_processed := v_mappings_upserted;
  started_at     := v_started_at;
  finished_at    := v_finished;
  RETURN NEXT;

  RETURN;
END $$;