-- DROP FUNCTION sources.load_ciel_concepts(text, timestamptz, int4, numeric, text);

CREATE OR REPLACE FUNCTION sources.load_ciel_concepts(
  p_mode text DEFAULT 'full'::text, 
  p_updated_since timestamp with time zone DEFAULT NULL::timestamp with time zone, 
  p_limit integer DEFAULT 500, 
  p_sleep_seconds numeric DEFAULT 0.2, 
  p_source_version text DEFAULT NULL::text)
 RETURNS TABLE(concepts_upserted bigint, names_upserted bigint, started_at timestamp with time zone, finished_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_started_at timestamptz := now();
  v_finished_at timestamptz;

  v_mode text := lower(coalesce(p_mode, 'full'));
  base_concepts text := 'https://api.openconceptlab.org/orgs/CIEL/sources/CIEL/concepts/';

  page int;
  urlq text;
  arr  jsonb;
  arr_len int;

  c_cnt bigint := 0;
  n_cnt bigint := 0;
  _add  bigint := 0;

  since_ts  timestamptz;
  since_txt text;
begin
 -- if version is pinned -> use versioned path; else HEAD
  IF p_source_version IS NOT NULL THEN
    base_concepts := format(
      'https://api.openconceptlab.org/orgs/CIEL/sources/CIEL/%s/concepts/',
      p_source_version
    );
    p_mode := 'full';
  ELSE
    base_concepts := 'https://api.openconceptlab.org/orgs/CIEL/sources/CIEL/concepts/';
  END IF;

  IF v_mode NOT IN ('full','delta') THEN
    RAISE EXCEPTION 'Mode must be full or delta';
  END IF;

  IF v_mode = 'delta' THEN
    since_ts := COALESCE(
      p_updated_since,
      COALESCE((SELECT max(updated_on) FROM sources.ciel_concepts), '1970-01-01'::timestamptz)
    );
    since_txt := to_char(since_ts AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS');
  END IF;

  page := 1;
  LOOP
    IF v_mode = 'full' THEN
      urlq := format('%s?limit=%s&page=%s&verbose=true&includeRetired=1',
                     base_concepts, p_limit, page);
    ELSE
      urlq := format('%s?limit=%s&page=%s&verbose=true&includeRetired=1&updatedSince=%s',
                     base_concepts, p_limit, page, replace(since_txt,' ','%20'));
    END IF;

    arr := sources.http_json(urlq);
    EXIT WHEN arr IS NULL OR jsonb_typeof(arr) <> 'array';
    arr_len := jsonb_array_length(arr);
    EXIT WHEN arr_len = 0;

    -- Upsert concepts (all fields)
    WITH up_concepts AS (
      INSERT INTO sources.ciel_concepts AS t
        (id, uuid, external_id, concept_class, datatype, retired,
         source, owner, owner_type, owner_url, url,
         display_name, display_locale,
         version, version_url, versions_url,
         versioned_object_id, versioned_object_url, is_latest_version,
         update_comment, type,
         created_on, created_by, updated_on, updated_by,
         public_can_view, latest_source_version,
         checksums, attributes, extras, names, descriptions, property,
         raw, pulled_at)
      SELECT
        x->>'id',
        x->>'uuid',
        x->>'external_id',
        x->>'concept_class',
        x->>'datatype',
        COALESCE((x->>'retired')::boolean, false),
        x->>'source',
        x->>'owner',
        x->>'owner_type',
        x->>'owner_url',
        x->>'url',
        x->>'display_name',
        x->>'display_locale',
        x->>'version',
        x->>'version_url',
        x->>'versions_url',
        NULLIF(x->>'versioned_object_id','')::bigint,
        x->>'versioned_object_url',
        COALESCE((x->>'is_latest_version')::boolean, NULL),
        x->>'update_comment',
        x->>'type',
        (x->>'created_on')::timestamptz,
        x->>'created_by',
        (x->>'updated_on')::timestamptz,
        x->>'updated_by',
        COALESCE((x->>'public_can_view')::boolean, NULL),
        x->>'latest_source_version',
        x->'checksums',
        x->'attributes',
        x->'extras',
        x->'names',
        x->'descriptions',
        x->'property',
        x AS raw,
        now()
      FROM jsonb_array_elements(arr) AS x
      ON CONFLICT (id) DO UPDATE
        SET uuid                 = EXCLUDED.uuid,
            external_id          = EXCLUDED.external_id,
            concept_class        = EXCLUDED.concept_class,
            datatype             = EXCLUDED.datatype,
            retired              = EXCLUDED.retired,
            source               = EXCLUDED.source,
            owner                = EXCLUDED.owner,
            owner_type           = EXCLUDED.owner_type,
            owner_url            = EXCLUDED.owner_url,
            url                  = EXCLUDED.url,
            display_name         = EXCLUDED.display_name,
            display_locale       = EXCLUDED.display_locale,
            version              = EXCLUDED.version,
            version_url          = EXCLUDED.version_url,
            versions_url         = EXCLUDED.versions_url,
            versioned_object_id  = COALESCE(EXCLUDED.versioned_object_id, t.versioned_object_id),
            versioned_object_url = EXCLUDED.versioned_object_url,
            is_latest_version    = EXCLUDED.is_latest_version,
            update_comment       = EXCLUDED.update_comment,
            type                 = EXCLUDED.type,
            created_on           = COALESCE(EXCLUDED.created_on, t.created_on),
            created_by           = COALESCE(EXCLUDED.created_by, t.created_by),
            updated_on           = EXCLUDED.updated_on,
            updated_by           = EXCLUDED.updated_by,
            public_can_view      = EXCLUDED.public_can_view,
            latest_source_version= EXCLUDED.latest_source_version,
            checksums            = EXCLUDED.checksums,
            attributes           = EXCLUDED.attributes,
            extras               = EXCLUDED.extras,
            names                = EXCLUDED.names,
            descriptions         = EXCLUDED.descriptions,
            property             = EXCLUDED.property,
            raw                  = EXCLUDED.raw,
            pulled_at            = now()
      RETURNING 1
    )
    SELECT COUNT(*) INTO _add FROM up_concepts;
    c_cnt := c_cnt + COALESCE(_add, 0);

    -- Normalize names (synonyms), de-duplicated to PK (concept_id, locale, name)
    WITH flat AS (
      SELECT
        (x->>'id') AS concept_id,
        nm->>'uuid' AS uuid,
        nm->>'name' AS name,
        nm->>'external_id' AS external_id,
        nm->>'type' AS type,
        nm->>'locale' AS locale,
        COALESCE((nm->>'locale_preferred')::boolean,false) AS locale_preferred,
        nm->>'name_type' AS name_type,
        COALESCE((nm->>'case_sensitive')::boolean,false) AS case_sensitive,
        nm->>'checksum' AS checksum,
        nm AS raw
      FROM jsonb_array_elements(arr) AS x
      LEFT JOIN LATERAL jsonb_array_elements(COALESCE(x->'names','[]'::jsonb)) AS nm ON TRUE
      WHERE (nm->>'name') IS NOT NULL
    ),
    dedup AS (
      SELECT *
      FROM (
        SELECT *,
               row_number() OVER (
                 PARTITION BY concept_id, locale, name
                 ORDER BY locale_preferred DESC,
                          (CASE WHEN name_type='FULLY_SPECIFIED' THEN 1 ELSE 0 END) DESC,
                          (CASE WHEN uuid IS NOT NULL THEN 1 ELSE 0 END) DESC
               ) AS rn
        FROM flat
      ) q
      WHERE rn = 1
    ),
    up_names AS (
      INSERT INTO sources.ciel_concept_names AS n
        (concept_id, uuid, name, external_id, type, locale, locale_preferred,
         name_type, case_sensitive, checksum, raw, pulled_at)
      SELECT
        concept_id, uuid, name, external_id, type, locale, locale_preferred,
        name_type, case_sensitive, checksum, raw, now()
      FROM dedup
      ON CONFLICT (concept_id, locale, name) DO UPDATE
        SET uuid             = EXCLUDED.uuid,
            external_id      = EXCLUDED.external_id,
            type             = EXCLUDED.type,
            locale_preferred = EXCLUDED.locale_preferred,
            name_type        = EXCLUDED.name_type,
            case_sensitive   = EXCLUDED.case_sensitive,
            checksum         = EXCLUDED.checksum,
            raw              = EXCLUDED.raw,
            pulled_at        = now()
      RETURNING 1
    )
    SELECT COUNT(*) INTO _add FROM up_names;
    n_cnt := n_cnt + COALESCE(_add, 0);

    page := page + 1;
    PERFORM pg_sleep(p_sleep_seconds);
  END LOOP;

  v_finished_at := now();
  concepts_upserted := c_cnt;
  names_upserted    := n_cnt;
  started_at        := v_started_at;
  finished_at       := v_finished_at;
  RETURN;
END $function$;