-- DROP FUNCTION sources.load_ciel_mappings(text, timestamptz, int4, numeric, text);

CREATE OR REPLACE FUNCTION sources.load_ciel_mappings(
    p_mode text DEFAULT 'full'::text, 
    p_updated_since timestamp with time zone DEFAULT NULL::timestamp with time zone, 
    p_limit integer DEFAULT 500, 
    p_sleep_seconds numeric DEFAULT 0.2, 
    p_source_version text DEFAULT NULL::text)
 RETURNS TABLE(mappings_upserted bigint, started_at timestamp with time zone, finished_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_started_at timestamptz := now();
  v_finished_at timestamptz;

  v_mode text := lower(coalesce(p_mode,'full'));
  base_mappings text := 'https://api.openconceptlab.org/orgs/CIEL/sources/CIEL/mappings/';

  page int;
  urlq text;
  arr  jsonb;
  arr_len int;

  m_cnt bigint := 0;
  _add  bigint := 0;

  since_ts  timestamptz;
  since_txt text;
begin
	
  IF p_source_version IS NOT NULL THEN
    base_mappings := format(
      'https://api.openconceptlab.org/orgs/CIEL/sources/CIEL/%s/mappings/',
      p_source_version
    );
    p_mode := 'full';
  ELSE
    base_mappings := 'https://api.openconceptlab.org/orgs/CIEL/sources/CIEL/mappings/';
  END IF;
 
  IF v_mode NOT IN ('full','delta') THEN
    RAISE EXCEPTION 'Mode must be full or delta';
  END IF;

  IF v_mode = 'delta' THEN
    since_ts := COALESCE(
      p_updated_since,
      COALESCE((SELECT max(updated_on) FROM sources.ciel_mappings), '1970-01-01'::timestamptz)
    );
    since_txt := to_char(since_ts AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS');
  END IF;

  page := 1;
  LOOP
    IF v_mode = 'full' THEN
      urlq := format('%s?limit=%s&page=%s&verbose=true&includeRetired=1',
                     base_mappings, p_limit, page);
    ELSE
      urlq := format('%s?limit=%s&page=%s&verbose=true&includeRetired=1&updatedSince=%s',
                     base_mappings, p_limit, page, replace(since_txt,' ','%20'));
    END IF;

    arr := sources.http_json(urlq);
    EXIT WHEN arr IS NULL OR jsonb_typeof(arr) <> 'array';
    arr_len := jsonb_array_length(arr);
    EXIT WHEN arr_len = 0;

    WITH up_map AS (
      INSERT INTO sources.ciel_mappings AS m
        (url, id, uuid, external_id, version, version_url,
         versioned_object_id, versioned_object_url, is_latest_version,
         update_comment, type, sort_weight,
         map_type, retired, source, owner, owner_type,
         from_concept_code, from_concept_name, from_concept_name_resolved, from_concept_url,
         to_concept_code, to_concept_name, to_concept_url,
         from_source_owner, from_source_owner_type, from_source_url, from_source_name, from_source_version,
         to_source_owner, to_source_owner_type, to_source_url, to_source_name, to_source_version,
         latest_source_version,
         created_on, created_by, updated_on, updated_by,
         version_created_on, version_updated_on, version_updated_by,
         public_can_view,
         checksums, attributes, extras, raw, pulled_at)
      SELECT
        x->>'url',
        x->>'id',
        x->>'uuid',
        x->>'external_id',
        x->>'version',
        x->>'version_url',
        NULLIF(x->>'versioned_object_id','')::bigint,
        x->>'versioned_object_url',
        COALESCE((x->>'is_latest_version')::boolean, NULL),
        x->>'update_comment',
        x->>'type',
        NULLIF(x->>'sort_weight','')::numeric,
        x->>'map_type',
        COALESCE((x->>'retired')::boolean, false),
        x->>'source',
        x->>'owner',
        x->>'owner_type',
        x->>'from_concept_code',
        x->>'from_concept_name',
        x->>'from_concept_name_resolved',
        x->>'from_concept_url',
        x->>'to_concept_code',
        x->>'to_concept_name',
        x->>'to_concept_url',
        x->>'from_source_owner',
        x->>'from_source_owner_type',
        x->>'from_source_url',
        x->>'from_source_name',
        x->>'from_source_version',
        x->>'to_source_owner',
        x->>'to_source_owner_type',
        x->>'to_source_url',
        x->>'to_source_name',
        x->>'to_source_version',
        x->>'latest_source_version',
        (x->>'created_on')::timestamptz,
        x->>'created_by',
        (x->>'updated_on')::timestamptz,
        x->>'updated_by',
        (x->>'version_created_on')::timestamptz,
        (x->>'version_updated_on')::timestamptz,
        x->>'version_updated_by',
        COALESCE((x->>'public_can_view')::boolean, NULL),
        x->'checksums',
        x->'attributes',
        x->'extras',
        x AS raw,
        now()
      FROM jsonb_array_elements(arr) AS x
      ON CONFLICT (url) DO UPDATE
        SET id                     = EXCLUDED.id,
            uuid                   = EXCLUDED.uuid,
            external_id            = EXCLUDED.external_id,
            version                = EXCLUDED.version,
            version_url            = EXCLUDED.version_url,
            versioned_object_id    = COALESCE(EXCLUDED.versioned_object_id, m.versioned_object_id),
            versioned_object_url   = EXCLUDED.versioned_object_url,
            is_latest_version      = EXCLUDED.is_latest_version,
            update_comment         = EXCLUDED.update_comment,
            type                   = EXCLUDED.type,
            sort_weight            = EXCLUDED.sort_weight,
            map_type               = EXCLUDED.map_type,
            retired                = EXCLUDED.retired,
            source                 = EXCLUDED.source,
            owner                  = EXCLUDED.owner,
            owner_type             = EXCLUDED.owner_type,
            from_concept_code      = EXCLUDED.from_concept_code,
            from_concept_name      = EXCLUDED.from_concept_name,
            from_concept_name_resolved = EXCLUDED.from_concept_name_resolved,
            from_concept_url       = EXCLUDED.from_concept_url,
            to_concept_code        = EXCLUDED.to_concept_code,
            to_concept_name        = EXCLUDED.to_concept_name,
            to_concept_url         = EXCLUDED.to_concept_url,
            from_source_owner      = EXCLUDED.from_source_owner,
            from_source_owner_type = EXCLUDED.from_source_owner_type,
            from_source_url        = EXCLUDED.from_source_url,
            from_source_name       = EXCLUDED.from_source_name,
            from_source_version    = EXCLUDED.from_source_version,
            to_source_owner        = EXCLUDED.to_source_owner,
            to_source_owner_type   = EXCLUDED.to_source_owner_type,
            to_source_url          = EXCLUDED.to_source_url,
            to_source_name         = EXCLUDED.to_source_name,
            to_source_version      = EXCLUDED.to_source_version,
            latest_source_version  = EXCLUDED.latest_source_version,
            created_on             = COALESCE(EXCLUDED.created_on, m.created_on),
            created_by             = COALESCE(EXCLUDED.created_by, m.created_by),
            updated_on             = EXCLUDED.updated_on,
            updated_by             = EXCLUDED.updated_by,
            version_created_on     = COALESCE(EXCLUDED.version_created_on, m.version_created_on),
            version_updated_on     = EXCLUDED.version_updated_on,
            version_updated_by     = EXCLUDED.version_updated_by,
            public_can_view        = EXCLUDED.public_can_view,
            checksums              = EXCLUDED.checksums,
            attributes             = EXCLUDED.attributes,
            extras                 = EXCLUDED.extras,
            raw                    = EXCLUDED.raw,
            pulled_at              = now()
      RETURNING 1
    )
    SELECT COUNT(*) INTO _add FROM up_map;
    m_cnt := m_cnt + COALESCE(_add, 0);

    page := page + 1;
    PERFORM pg_sleep(p_sleep_seconds);
  END LOOP;

  v_finished_at := now();
  mappings_upserted := m_cnt;
  started_at        := v_started_at;
  finished_at       := v_finished_at;
  RETURN;
END $function$;