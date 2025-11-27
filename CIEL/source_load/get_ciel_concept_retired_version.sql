-- DROP FUNCTION sources.get_ciel_concept_retired_version(text);

CREATE OR REPLACE FUNCTION sources.get_ciel_concept_retired_version(p_concept_id text)
 RETURNS TABLE(out_concept_id text, retired_since_version text, retired_since_on timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
DECLARE
  urlq   text;
  arr    jsonb;
  v_version text;
  v_when    timestamptz;
BEGIN
  urlq := format(
    'https://api.openconceptlab.org/orgs/CIEL/sources/CIEL/concepts/%s/versions/',
    p_concept_id
  );

  arr := sources.http_json(urlq);

  IF arr IS NULL OR jsonb_typeof(arr) <> 'array' THEN
    RAISE EXCEPTION 'No versions returned for concept %', p_concept_id;
  END IF;

  -- Find oldest version where retired = true
  WITH parsed AS (
    SELECT
      obj,
      COALESCE(obj->>'latest_source_version', obj->>'version') AS version,
      COALESCE(
        (obj->>'updated_on')::timestamptz,
        (obj->>'version_updated_on')::timestamptz,
        (obj->>'created_on')::timestamptz
      ) AS ts,
      COALESCE((obj->>'retired')::boolean, false) AS retired
    FROM jsonb_array_elements(arr) AS e(obj)
  ),
  retired_rows AS (
    SELECT version, ts
    FROM parsed
    WHERE retired = true
    ORDER BY ts NULLS LAST      -- oldest
    LIMIT 1
  )
  SELECT version, ts
  INTO v_version, v_when
  FROM retired_rows;

  -- if no version for retired = true 
  IF v_version IS NULL THEN
    RETURN;
  END IF;

  -- INSERT + UPDATE (avoid ON CONFLICT → deadlock)
  BEGIN
    INSERT INTO sources.ciel_concept_retired_history
      (concept_id, retired_since_version, retired_since_on, raw, pulled_at)
    VALUES
      (p_concept_id, v_version, v_when, arr, now());
  EXCEPTION
    WHEN unique_violation THEN
      UPDATE sources.ciel_concept_retired_history h
      SET retired_since_version = v_version,
          retired_since_on      = v_when,
          raw                   = arr,
          pulled_at             = now()
      WHERE h.concept_id = p_concept_id;
  END;

  out_concept_id        := p_concept_id;
  retired_since_version := v_version;
  retired_since_on      := v_when;
  RETURN NEXT;
END $function$;

CREATE OR REPLACE FUNCTION sources.populate_retired_history_for_all()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT id
    FROM sources.ciel_concepts c
    WHERE retired = true
      AND NOT EXISTS (
        SELECT 1
        FROM sources.ciel_concept_retired_history h
        WHERE h.concept_id = c.id
      )
  LOOP
    PERFORM sources.get_ciel_concept_retired_version(r.id);
  END LOOP;
END $function$;