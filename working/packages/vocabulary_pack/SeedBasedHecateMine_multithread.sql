/*
================================================================================
SeedBasedHecateMine_multithread.sql
================================================================================
Purpose
-------
Multithreaded Hecate batch loader with retry support.
Based on single_function_hekate.sql, but lives in its own deploy script.

Objects created
---------------
- vocabulary_pack.SeedBasedHecateMine_multithread(...)
      PL/Python: parallel Hecate HTTP calls (one seed per worker thread).
      Returns jsonb: {"results":[...], "failed":[...], "succeeded":[...]}

- hecate_ensure_similar_output_table(...)
      Helper created in the active search_path schema; creates the requested
      output table if it does not exist.

- hecate_populate_similar_results_mt(...)
      Main entry point. TEMP pending table + parallel batches + retries.
      Created in the active search_path schema unless search_path points to
      vocabulary_pack during deployment.
      Same I/O contract as hecate_populate_similar_results, plus:
      p_thread_count, p_max_retries.
      Default: /search + standard_concept=S (real semantic scores like the website).

Behaviour
---------
1. Seeds already present in output table are skipped.
2. Remaining seeds go into TEMP TABLE hecate_mt_pending_seeds.
3. Parallel batch processes pending seeds (one seed per thread).
4. Successful seeds are inserted into output and removed from pending.
5. Failed seeds stay in pending; up to p_max_retries additional rounds are run.
6. TEMP pending table is dropped automatically at transaction end.

Prerequisites
-------------
- SET search_path TO vocabulary_pack, your_target_schema, devv5, public;
- CREATE EXTENSION plpython3u;
- Outbound HTTPS access to https://hecate.pantheon-hds.com/api.
================================================================================
*/

-- -----------------------------------------------------------------------------
-- Section MT.01: Parallel Hecate batch (HTTP in threads, no plpy in workers)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION vocabulary_pack.SeedBasedHecateMine_multithread(
    p_seed_ids               integer[],
    p_thread_count           integer DEFAULT 1,
    p_top_x                  integer DEFAULT 10,
    p_min_similarity_score   numeric DEFAULT NULL,
    p_vocabulary_id          text    DEFAULT NULL,
    p_exclude_vocabulary_id  text    DEFAULT NULL,
    p_domain_id              text    DEFAULT NULL,
    p_concept_class_id       text    DEFAULT NULL,
    p_use_search_standard    boolean DEFAULT false,
    p_standard_concept       text    DEFAULT 'S',
    p_include_seed           boolean DEFAULT false,
    p_hecate_base_url        text    DEFAULT 'https://hecate.pantheon-hds.com/api',
    p_timeout_seconds        integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpython3u
AS $$
import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

SEARCH_STANDARD_MAX_LIMIT = 100
SEARCH_MAX_LIMIT = 150


def _format_validity(invalid_reason, valid_start_date, valid_end_date):
    if invalid_reason and str(invalid_reason).lower() not in ("none", ""):
        return str(invalid_reason)
    if valid_start_date or valid_end_date:
        return "%s – %s" % (valid_start_date or "?", valid_end_date or "?")
    return "Valid"


def _call_hecate_api(query, limit, use_search_standard, standard_concept,
                     vocabulary_id, exclude_vocabulary_id, domain_id,
                     concept_class_id, hecate_base_url, timeout_seconds):
    endpoint = "/search_standard" if use_search_standard else "/search"

    params = {
        "q": str(query),
        "limit": int(limit),
        "standard_concept": standard_concept,
        "vocabulary_id": vocabulary_id,
        "exclude_vocabulary_id": exclude_vocabulary_id,
        "domain_id": domain_id,
        "concept_class_id": concept_class_id,
    }
    params = {k: v for k, v in params.items() if v is not None and str(v) != ""}

    url = hecate_base_url.rstrip("/") + endpoint + "?" + urlencode(params)
    req = Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "postgres-plpython-hecate-onco-mt/1.0",
        },
    )

    with urlopen(req, timeout=int(timeout_seconds)) as response:
        content = response.read().decode("utf-8")

    data = json.loads(content)
    if not isinstance(data, list):
        raise RuntimeError("Unexpected Hecate response shape: expected list")
    return data


def _lookup_one_seed(concept_id, cfg):
    top_x = cfg["top_x"]
    min_score = cfg["min_score"]
    use_search_standard = cfg["use_search_standard"]
    include_seed = cfg["include_seed"]

    api_limit_cap = SEARCH_STANDARD_MAX_LIMIT if use_search_standard else SEARCH_MAX_LIMIT
    api_limit = api_limit_cap if min_score is not None else min(top_x, api_limit_cap)

    groups = _call_hecate_api(
        concept_id,
        api_limit,
        use_search_standard,
        cfg["standard_concept"] if not use_search_standard else None,
        cfg["vocabulary_id"],
        cfg["exclude_vocabulary_id"],
        cfg["domain_id"],
        cfg["concept_class_id"],
        cfg["hecate_base_url"],
        cfg["timeout_seconds"],
    )

    candidates = []
    match_rank = 0

    for group in groups or []:
        concepts = group.get("concepts") or []
        group_score = group.get("score")

        for concept in concepts:
            candidate_id = concept.get("concept_id")
            if candidate_id is None:
                continue

            if not include_seed and int(candidate_id) == int(concept_id):
                continue

            match_rank += 1
            candidates.append({
                "match_rank": match_rank,
                "score": group_score,
                "concept_id": int(candidate_id),
                "concept_name": concept.get("concept_name") or "",
                "domain_id": concept.get("domain_id") or "",
                "vocabulary_id": concept.get("vocabulary_id") or "",
                "concept_class_id": concept.get("concept_class_id") or "",
                "standard_concept": concept.get("standard_concept"),
                "concept_code": concept.get("concept_code") or "",
                "invalid_reason": concept.get("invalid_reason"),
                "valid_start_date": concept.get("valid_start_date"),
                "valid_end_date": concept.get("valid_end_date"),
                "record_count": int(concept.get("record_count") or 0),
            })

    if min_score is not None:
        candidates = [
            row for row in candidates
            if row["score"] is not None and float(row["score"]) > min_score
        ]

    best_by_id = {}
    for row in candidates:
        existing = best_by_id.get(row["concept_id"])
        if existing is None:
            best_by_id[row["concept_id"]] = row
            continue

        existing_score = float(existing["score"]) if existing["score"] is not None else -1.0
        row_score = float(row["score"]) if row["score"] is not None else -1.0
        if row_score > existing_score or (
            row_score == existing_score and row["match_rank"] < existing["match_rank"]
        ):
            best_by_id[row["concept_id"]] = row

    deduped = sorted(
        best_by_id.values(),
        key=lambda row: (
            -(float(row["score"]) if row["score"] is not None else -1.0),
            row["match_rank"],
        ),
    )

    rows = []
    for row in deduped[:top_x]:
        rows.append({
            "seed_concept_id": int(concept_id),
            "id": row["concept_id"],
            "code": row["concept_code"],
            "name": row["concept_name"],
            "class": row["concept_class_id"],
            "domain": row["domain_id"],
            "validity": _format_validity(
                row["invalid_reason"],
                row["valid_start_date"],
                row["valid_end_date"],
            ),
            "concept": row["standard_concept"] or "",
            "vocabulary": row["vocabulary_id"],
            "score": row["score"],
            "records": row["record_count"],
        })

    return rows


if p_seed_ids is None or len(p_seed_ids) == 0:
    return json.dumps({"results": [], "failed": [], "succeeded": []})

if p_thread_count is None or int(p_thread_count) < 1:
    plpy.error("p_thread_count must be >= 1")

if p_top_x is None or int(p_top_x) < 1:
    plpy.error("p_top_x must be >= 1")

if p_timeout_seconds is None or int(p_timeout_seconds) < 1:
    plpy.error("p_timeout_seconds must be >= 1")

seed_ids = sorted({int(x) for x in p_seed_ids if x is not None})
thread_count = min(int(p_thread_count), len(seed_ids))

min_score = None
if p_min_similarity_score is not None:
    min_score = float(p_min_similarity_score)

cfg = {
    "top_x": int(p_top_x),
    "min_score": min_score,
    "use_search_standard": bool(p_use_search_standard),
    "standard_concept": p_standard_concept,
    "include_seed": bool(p_include_seed),
    "vocabulary_id": p_vocabulary_id,
    "exclude_vocabulary_id": p_exclude_vocabulary_id,
    "domain_id": p_domain_id,
    "concept_class_id": p_concept_class_id,
    "hecate_base_url": p_hecate_base_url or "https://hecate.pantheon-hds.com/api",
    "timeout_seconds": int(p_timeout_seconds),
}


def _worker(concept_id):
    try:
        rows = _lookup_one_seed(concept_id, cfg)
        return {"ok": True, "concept_id": int(concept_id), "rows": rows}
    except HTTPError as exc:
        err_body = exc.read().decode("utf-8", errors="replace")
        return {
            "ok": False,
            "concept_id": int(concept_id),
            "error": "HTTP %s: %s" % (exc.code, err_body[:500]),
        }
    except URLError as exc:
        return {
            "ok": False,
            "concept_id": int(concept_id),
            "error": "Connection error: %s" % str(exc),
        }
    except Exception as exc:
        return {
            "ok": False,
            "concept_id": int(concept_id),
            "error": str(exc),
        }


results = []
failed = []
succeeded = []

with ThreadPoolExecutor(max_workers=thread_count) as executor:
    futures = [executor.submit(_worker, concept_id) for concept_id in seed_ids]
    for future in as_completed(futures):
        outcome = future.result()
        if outcome["ok"]:
            succeeded.append(outcome["concept_id"])
            results.extend(outcome["rows"])
        else:
            failed.append({
                "concept_id": outcome["concept_id"],
                "error": outcome["error"],
            })

return json.dumps({"results": results, "failed": failed, "succeeded": succeeded})
$$;


-- -----------------------------------------------------------------------------
-- Section MT.01b: Ensure output table exists in the requested schema
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION hecate_ensure_similar_output_table(
    p_output_table text
)
RETURNS regclass
LANGUAGE plpgsql
AS $$
DECLARE
    v_output_nspname text;
    v_output_relname text;
    v_qualified_output text;
    v_output_table regclass;
BEGIN
    IF p_output_table IS NULL OR btrim(p_output_table) = '' THEN
        RAISE EXCEPTION 'p_output_table cannot be null or empty';
    END IF;

    IF position('.' in btrim(p_output_table)) > 0 THEN
        v_output_nspname := split_part(btrim(p_output_table), '.', 1);
        v_output_relname := split_part(btrim(p_output_table), '.', 2);

        IF v_output_nspname = '' OR v_output_relname = '' THEN
            RAISE EXCEPTION 'invalid qualified p_output_table: %', p_output_table;
        END IF;

        EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', v_output_nspname);
    ELSE
        v_output_nspname := current_schema();
        v_output_relname := btrim(p_output_table);

        IF v_output_nspname IS NULL OR btrim(v_output_nspname) = '' THEN
            RAISE EXCEPTION 'current_schema() is empty; SET search_path before calling';
        END IF;

        IF v_output_relname = '' THEN
            RAISE EXCEPTION 'invalid p_output_table: %', p_output_table;
        END IF;
    END IF;

    v_qualified_output := format('%I.%I', v_output_nspname, v_output_relname);

    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %s (
            seed_concept_id integer NOT NULL,
            id integer NOT NULL,
            code text,
            name text,
            "class" text,
            domain text,
            validity text,
            concept text,
            vocabulary text,
            score numeric,
            records bigint,
            loaded_at timestamptz NOT NULL DEFAULT now()
        )',
        v_qualified_output
    );

    v_output_table := to_regclass(v_qualified_output);

    IF v_output_table IS NULL THEN
        RAISE EXCEPTION 'failed to resolve output table % after CREATE', v_qualified_output;
    END IF;

    RETURN v_output_table;
END;
$$;


-- -----------------------------------------------------------------------------
-- Section MT.02: Multithreaded orchestrator with pending temp table + retries
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION hecate_populate_similar_results_mt(
    p_output_table           text,
    p_concept_id             integer DEFAULT NULL,
    p_input_table            text    DEFAULT NULL,
    p_input_concept_id_column text   DEFAULT NULL,
    p_vocabulary_id          text    DEFAULT NULL,
    p_domain_id              text    DEFAULT NULL,
    p_exclude_vocabulary_id  text    DEFAULT NULL,
    p_concept_class_id       text    DEFAULT NULL,
    p_top_x                  integer DEFAULT 10,
    p_min_similarity_score   numeric DEFAULT NULL,
    p_use_search_standard    boolean DEFAULT false,
    p_standard_concept       text    DEFAULT 'S',
    p_include_seed           boolean DEFAULT false,
    p_hecate_base_url        text    DEFAULT 'https://hecate.pantheon-hds.com/api',
    p_timeout_seconds        integer DEFAULT 10,
    p_thread_count           integer DEFAULT 1,
    p_max_retries            integer DEFAULT 1,
    p_continue_on_error      boolean DEFAULT true
)
RETURNS TABLE (
    output_table         text,
    seed_count           integer,
    skipped_seed_count   integer,
    result_row_count     integer,
    error_seed_count     integer,
    pending_seed_count   integer,
    retry_rounds_run     integer,
    thread_count         integer,
    started_at           timestamptz,
    finished_at          timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_started_at timestamptz := clock_timestamp();
    v_finished_at timestamptz;

    v_seed_count integer := 0;
    v_skipped_seed_count integer := 0;
    v_result_row_count integer := 0;
    v_error_seed_count integer := 0;
    v_pending_seed_count integer := 0;
    v_retry_rounds_run integer := 0;
    v_row_count integer := 0;

    v_output_table regclass;
    v_input_table regclass;

    v_output_relname text;
    v_index_name text;

    v_input_id_column text;

    v_pending_ids integer[];
    v_batch jsonb;
    v_retry_round integer := 0;

    v_seed_exists boolean;

    v_sqlstate text;
    v_message text;
BEGIN
    -- -------------------------------------------------------------------------
    -- Section MT.02.01: Validate parameters
    -- -------------------------------------------------------------------------
    IF p_output_table IS NULL OR btrim(p_output_table) = '' THEN
        RAISE EXCEPTION 'p_output_table cannot be null or empty';
    END IF;

    IF (p_concept_id IS NULL AND p_input_table IS NULL)
       OR (p_concept_id IS NOT NULL AND p_input_table IS NOT NULL) THEN
        RAISE EXCEPTION 'provide exactly one of p_concept_id or p_input_table';
    END IF;

    IF p_top_x IS NULL OR p_top_x < 1 THEN
        RAISE EXCEPTION 'p_top_x must be >= 1';
    END IF;

    IF p_timeout_seconds IS NULL OR p_timeout_seconds < 1 THEN
        RAISE EXCEPTION 'p_timeout_seconds must be >= 1';
    END IF;

    IF p_thread_count IS NULL OR p_thread_count < 1 THEN
        RAISE EXCEPTION 'p_thread_count must be >= 1';
    END IF;

    IF p_max_retries IS NULL OR p_max_retries < 0 THEN
        RAISE EXCEPTION 'p_max_retries must be >= 0';
    END IF;

    -- -------------------------------------------------------------------------
    -- Section MT.02.02: Ensure output table exists at p_output_table
    -- -------------------------------------------------------------------------
    v_output_table := hecate_ensure_similar_output_table(p_output_table);

    SELECT c.relname
    INTO v_output_relname
    FROM pg_class c
    WHERE c.oid = v_output_table;

    -- -------------------------------------------------------------------------
    -- Section MT.02.03: TEMP pending table for unprocessed seed_ids
    -- -------------------------------------------------------------------------
    DROP TABLE IF EXISTS hecate_mt_pending_seeds;

    CREATE TEMP TABLE hecate_mt_pending_seeds (
        concept_id integer PRIMARY KEY,
        last_error text,
        attempt_count integer NOT NULL DEFAULT 0
    ) ON COMMIT DROP;

    IF p_concept_id IS NOT NULL THEN
        EXECUTE format(
            'SELECT EXISTS (
                SELECT 1
                FROM %s o
                WHERE o.seed_concept_id = $1
                LIMIT 1
            )',
            v_output_table
        )
        INTO v_seed_exists
        USING p_concept_id;

        IF v_seed_exists THEN
            v_skipped_seed_count := 1;
        ELSE
            INSERT INTO hecate_mt_pending_seeds (concept_id)
            VALUES (p_concept_id);
        END IF;
    ELSE
        v_input_table := p_input_table::regclass;

        IF p_input_concept_id_column IS NOT NULL AND btrim(p_input_concept_id_column) <> '' THEN
            v_input_id_column := btrim(p_input_concept_id_column);
        ELSE
            SELECT a.attname
            INTO v_input_id_column
            FROM pg_attribute a
            WHERE a.attrelid = v_input_table
              AND a.attnum > 0
              AND NOT a.attisdropped
              AND a.attname = ANY (ARRAY['seed_concept_id', 'concept_id'])
            ORDER BY CASE a.attname
                WHEN 'seed_concept_id' THEN 1
                WHEN 'concept_id' THEN 2
            END
            LIMIT 1;
        END IF;

        IF v_input_id_column IS NULL THEN
            RAISE EXCEPTION
                'input table % must contain seed_concept_id or concept_id (or set p_input_concept_id_column)',
                v_input_table;
        END IF;

        IF NOT EXISTS (
            SELECT 1
            FROM pg_attribute a
            WHERE a.attrelid = v_input_table
              AND a.attnum > 0
              AND NOT a.attisdropped
              AND a.attname = v_input_id_column
        ) THEN
            RAISE EXCEPTION
                'input table % does not contain column %',
                v_input_table,
                v_input_id_column;
        END IF;

        EXECUTE format(
            'WITH seeds AS (
                SELECT DISTINCT %1$I::integer AS concept_id
                FROM %2$s
                WHERE %1$I IS NOT NULL
            )
            SELECT
                count(*) FILTER (
                    WHERE EXISTS (
                        SELECT 1
                        FROM %3$s o
                        WHERE o.seed_concept_id = s.concept_id
                    )
                )::integer AS skipped_count,
                coalesce(
                    array_agg(s.concept_id ORDER BY s.concept_id) FILTER (
                        WHERE NOT EXISTS (
                            SELECT 1
                            FROM %3$s o
                            WHERE o.seed_concept_id = s.concept_id
                        )
                    ),
                    ARRAY[]::integer[]
                ) AS pending_ids
             FROM seeds s',
            v_input_id_column,
            v_input_table,
            v_output_table
        )
        INTO v_skipped_seed_count, v_pending_ids;

        IF v_pending_ids IS NOT NULL AND array_length(v_pending_ids, 1) > 0 THEN
            INSERT INTO hecate_mt_pending_seeds (concept_id)
            SELECT unnest(v_pending_ids);
        END IF;
    END IF;

    -- -------------------------------------------------------------------------
    -- Section MT.02.04: Parallel batches + retries via pending temp table
    -- -------------------------------------------------------------------------
    <<retry_loop>>
    LOOP
        SELECT coalesce(array_agg(concept_id ORDER BY concept_id), ARRAY[]::integer[])
        INTO v_pending_ids
        FROM hecate_mt_pending_seeds;

        EXIT retry_loop WHEN coalesce(array_length(v_pending_ids, 1), 0) = 0;

        BEGIN
            v_batch := SeedBasedHecateMine_multithread(
                p_seed_ids               => v_pending_ids,
                p_thread_count           => p_thread_count,
                p_top_x                  => p_top_x,
                p_min_similarity_score   => p_min_similarity_score,
                p_vocabulary_id          => p_vocabulary_id,
                p_exclude_vocabulary_id  => p_exclude_vocabulary_id,
                p_domain_id              => p_domain_id,
                p_concept_class_id       => p_concept_class_id,
                p_use_search_standard    => p_use_search_standard,
                p_standard_concept       => p_standard_concept,
                p_include_seed           => p_include_seed,
                p_hecate_base_url        => p_hecate_base_url,
                p_timeout_seconds        => p_timeout_seconds
            );
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS
                v_sqlstate = RETURNED_SQLSTATE,
                v_message = MESSAGE_TEXT;

            UPDATE hecate_mt_pending_seeds p
            SET
                attempt_count = p.attempt_count + 1,
                last_error = format('[%s] %s', v_sqlstate, v_message);

            IF NOT p_continue_on_error THEN
                RAISE;
            END IF;

            EXIT retry_loop WHEN v_retry_round >= p_max_retries;
            v_retry_round := v_retry_round + 1;
            v_retry_rounds_run := v_retry_rounds_run + 1;
            CONTINUE retry_loop;
        END;

        IF jsonb_array_length(coalesce(v_batch -> 'results', '[]'::jsonb)) > 0 THEN
            EXECUTE format(
                'INSERT INTO %s (
                    seed_concept_id,
                    id,
                    code,
                    name,
                    "class",
                    domain,
                    validity,
                    concept,
                    vocabulary,
                    score,
                    records
                )
                SELECT
                    x.seed_concept_id,
                    x.id,
                    x.code,
                    x.name,
                    x."class",
                    x.domain,
                    x.validity,
                    x.concept,
                    x.vocabulary,
                    x.score,
                    x.records
                FROM jsonb_to_recordset($1) AS x(
                    seed_concept_id integer,
                    id integer,
                    code text,
                    name text,
                    "class" text,
                    domain text,
                    validity text,
                    concept text,
                    vocabulary text,
                    score numeric,
                    records bigint
                )',
                v_output_table
            )
            USING v_batch -> 'results';

            GET DIAGNOSTICS v_row_count = ROW_COUNT;
            v_result_row_count := v_result_row_count + coalesce(v_row_count, 0);
        END IF;

        DELETE FROM hecate_mt_pending_seeds p
        WHERE p.concept_id IN (
            SELECT (item)::integer
            FROM jsonb_array_elements_text(coalesce(v_batch -> 'succeeded', '[]'::jsonb)) AS item
        );

        UPDATE hecate_mt_pending_seeds p
        SET
            attempt_count = p.attempt_count + 1,
            last_error = f.error
        FROM jsonb_to_recordset(coalesce(v_batch -> 'failed', '[]'::jsonb)) AS f(
            concept_id integer,
            error text
        )
        WHERE p.concept_id = f.concept_id;

        v_seed_count := v_seed_count + coalesce(
            jsonb_array_length(coalesce(v_batch -> 'succeeded', '[]'::jsonb)),
            0
        );

        EXIT retry_loop WHEN NOT EXISTS (SELECT 1 FROM hecate_mt_pending_seeds);

        v_retry_round := v_retry_round + 1;
        v_retry_rounds_run := v_retry_rounds_run + 1;
        EXIT retry_loop WHEN v_retry_round > p_max_retries;
    END LOOP retry_loop;

    SELECT count(*)::integer
    INTO v_pending_seed_count
    FROM hecate_mt_pending_seeds;

    v_error_seed_count := v_pending_seed_count;

    IF v_pending_seed_count > 0 THEN
        RAISE WARNING
            'hecate_populate_similar_results_mt: % seed(s) remain in hecate_mt_pending_seeds after retries',
            v_pending_seed_count;
    END IF;

    -- -------------------------------------------------------------------------
    -- Section MT.02.05: Index / analyze output table
    -- -------------------------------------------------------------------------
    v_index_name := left(v_output_relname || '_seed_score_idx', 63);

    EXECUTE format(
        'CREATE INDEX IF NOT EXISTS %I ON %s (seed_concept_id, score DESC NULLS LAST)',
        v_index_name,
        v_output_table
    );

    EXECUTE format('ANALYZE %s', v_output_table);

    v_finished_at := clock_timestamp();

    RETURN QUERY
    SELECT
        v_output_table::text,
        v_seed_count,
        v_skipped_seed_count,
        v_result_row_count,
        v_error_seed_count,
        v_pending_seed_count,
        v_retry_rounds_run,
        p_thread_count,
        v_started_at,
        v_finished_at;
END;
$$;


-- -----------------------------------------------------------------------------
-- Optional  tests
-- -----------------------------------------------------------------------------
-- SELECT *
-- FROM hecate_populate_similar_results_mt(
--     p_output_table         => 'hecate_similar_demo',
--     p_input_table          => 'seed_table',
--     p_vocabulary_id        => 'SNOMED,LOINC',
--     p_domain_id            => 'Condition,Measurement,Observation,Meas Value',
--     p_top_x                => 10,
--     p_min_similarity_score => 0.75,
--     p_thread_count         => 4,
--     p_max_retries          => 1
-- );
--
-- SELECT * FROM hecate_mt_pending_seeds;  -- non-empty only if retries exhausted
