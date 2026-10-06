-- DROP FUNCTION sources.load_ciel_source_versions(int4, numeric);

CREATE OR REPLACE FUNCTION sources.load_ciel_source_versions(
    p_limit integer DEFAULT 200, 
    p_sleep_seconds numeric DEFAULT 0.1)
 RETURNS TABLE(versions_upserted bigint, started_at timestamp with time zone, finished_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_started_at timestamptz := now();
  v_finished_at timestamptz;
  base_versions text := 'https://api.openconceptlab.org/orgs/CIEL/sources/CIEL/versions/';
  page int := 1;
  urlq text;
  arr jsonb;
  arr_len int;
  _add bigint := 0;
  v_cnt bigint := 0;
BEGIN
  LOOP
    urlq := format('%s?limit=%s&page=%s', base_versions, p_limit, page);
    arr := sources.http_json(urlq);

    EXIT WHEN arr IS NULL OR jsonb_typeof(arr) <> 'array';
    arr_len := jsonb_array_length(arr);
    EXIT WHEN arr_len = 0;

    WITH up AS (
      INSERT INTO sources.ciel_source_versions AS t
        (version, id, uuid, url, version_url, is_latest_version, update_comment, type,
         source, owner, owner_type, owner_url, description,
         released_on, created_on, created_by, updated_on, updated_by,
         public_can_view, latest_source_version,
         checksums, attributes, extras, raw, pulled_at)
      SELECT
        x->>'version',
        x->>'id',
        x->>'uuid',
        x->>'url',
        x->>'version_url',
        (x->>'is_latest_version')::boolean,
        x->>'update_comment',
        x->>'type',
        x->>'source',
        x->>'owner',
        x->>'owner_type',
        x->>'owner_url',
        x->>'description',
        (x->>'released_on')::timestamptz,
        (x->>'created_at')::timestamptz,
        x->>'created_by',
        (x->>'updated_at')::timestamptz,
        x->>'updated_by',
        (x->>'public_can_view')::boolean,
        x->>'latest_source_version',
        x->'checksums',
        x->'attributes',
        x->'extras',
        x AS raw,
        now()
      FROM jsonb_array_elements(arr) AS x
      WHERE x ? 'version'  -- ensure there is a version key
      ON CONFLICT (version) DO UPDATE
        SET id                   = EXCLUDED.id,
            uuid                 = EXCLUDED.uuid,
            url                  = EXCLUDED.url,
            version_url          = EXCLUDED.version_url,
            is_latest_version    = EXCLUDED.is_latest_version,
            update_comment       = EXCLUDED.update_comment,
            type                 = EXCLUDED.type,
            source               = EXCLUDED.source,
            owner                = EXCLUDED.owner,
            owner_type           = EXCLUDED.owner_type,
            owner_url            = EXCLUDED.owner_url,
            description          = EXCLUDED.description,
            released_on          = COALESCE(EXCLUDED.released_on, t.released_on),
            created_on           = COALESCE(EXCLUDED.created_on, t.created_on),
            created_by           = COALESCE(EXCLUDED.created_by, t.created_by),
            updated_on           = EXCLUDED.updated_on,
            updated_by           = EXCLUDED.updated_by,
            public_can_view      = EXCLUDED.public_can_view,
            latest_source_version= EXCLUDED.latest_source_version,
            checksums            = EXCLUDED.checksums,
            attributes           = EXCLUDED.attributes,
            extras               = EXCLUDED.extras,
            raw                  = EXCLUDED.raw,
            pulled_at            = now()
      RETURNING 1
    )
    SELECT COUNT(*) INTO _add FROM up;

    v_cnt := v_cnt + COALESCE(_add, 0);
    page := page + 1;
    PERFORM pg_sleep(p_sleep_seconds);
  END LOOP;

  v_finished_at := now();
  versions_upserted := v_cnt;
  started_at := v_started_at;
  finished_at := v_finished_at;
  RETURN;
END $function$;