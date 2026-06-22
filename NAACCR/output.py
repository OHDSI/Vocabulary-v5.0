"""
output.py

Writes the results of compare.run() to:
  {work_schema}.concept_stage
  {work_schema}.concept_relationship_stage

The OHDSI vocabulary pipeline reads concept_stage and concept_relationship_stage,
assigns concept_ids, and loads into the main vocabulary tables.

Behaviour
---------
- Truncates both target tables, then inserts fresh.
- All four buckets (new, updated, same, retiring) are written to concept_stage.
  Retiring concepts get valid_end_date = today and invalid_reason = 'D'.
- Relationships are deduplicated before writing.
- Orphaned values (values whose parent Variable is not in the concept set)
  are dropped with a warning.
- valid_start_date defaults to 1970-01-01 when not supplied by source.
- valid_end_date  defaults to 2099-12-31 when not supplied.
"""

import datetime
import psycopg2
import psycopg2.extras

import config
from compare import run as compare_run

TODAY      = datetime.date.today().isoformat()
DATE_START = '1970-01-01'
DATE_END   = '2099-12-31'


def _coerce_date(val, default):
    if val is None:
        return default
    s = str(val)
    return default if s in ('None', '') else s


# ── Write concept_stage ───────────────────────────────────────────────────────

def _write_concepts(cur, all_concepts, retiring_codes, verbose=True):
    ws = config.DB_WORK_SCHEMA
    cur.execute(f"TRUNCATE TABLE {ws}.concept_stage")

    sql = f"""
        INSERT INTO {ws}.concept_stage (
            concept_name, domain_id, vocabulary_id, concept_class_id,
            standard_concept, concept_code,
            valid_start_date, valid_end_date, invalid_reason
        ) VALUES %s
    """

    # Drop concept_codes over 50 chars
    over50 = [c for c in all_concepts if len(c['concept_code']) > 50]
    if over50:
        if verbose:
            print(f"[output] WARNING: dropping {len(over50)} concept_codes > 50 chars")
        all_concepts = [c for c in all_concepts if len(c['concept_code']) <= 50]

    rows = []
    for c in all_concepts:
        code = c['concept_code']
        if code in retiring_codes:
            vsd = _coerce_date(c.get('valid_start_date'), DATE_START)
            ved = TODAY
            ir  = 'D'
            sc  = None
        else:
            vsd = _coerce_date(c.get('valid_start_date'), DATE_START)
            ved = _coerce_date(c.get('valid_end_date'),   DATE_END)
            ir  = c.get('invalid_reason')
            sc  = c.get('standard_concept')

        rows.append((
            c['concept_name'], c['domain_id'], c['vocabulary_id'],
            c['concept_class_id'], sc, code, vsd, ved, ir,
        ))

    psycopg2.extras.execute_values(cur, sql, rows, page_size=1000)
    if verbose:
        print(f"[output] Wrote {len(rows)} rows to {ws}.concept_stage")
    return len(rows)


# ── Write concept_relationship_stage ─────────────────────────────────────────

def _write_relationships(cur, relationships, known_codes, verbose=True):
    ws = config.DB_WORK_SCHEMA
    cur.execute(f"TRUNCATE TABLE {ws}.concept_relationship_stage")

    # Drop relationships where either code is unknown
    before = len(relationships)
    relationships = [
        r for r in relationships
        if r['concept_code_1'] in known_codes and r['concept_code_2'] in known_codes
    ]
    if verbose and len(relationships) != before:
        print(f"[output] Dropped {before - len(relationships)} rels with unknown codes")

    # Deduplicate: same (code1, code2, relationship_id) triple
    seen = set()
    deduped = []
    for r in relationships:
        key = (r['concept_code_1'], r['concept_code_2'], r['relationship_id'])
        if key not in seen:
            seen.add(key)
            deduped.append(r)
    if verbose and len(deduped) != len(relationships):
        print(f"[output] Deduplicated {len(relationships) - len(deduped)} duplicate rels")

    sql = f"""
        INSERT INTO {ws}.concept_relationship_stage (
            concept_code_1, concept_code_2,
            vocabulary_id_1, vocabulary_id_2,
            relationship_id,
            valid_start_date, valid_end_date, invalid_reason
        ) VALUES %s
    """

    rows = [
        (r['concept_code_1'], r['concept_code_2'],
         config.VOCABULARY_ID, config.VOCABULARY_ID,
         r['relationship_id'],
         DATE_START, DATE_END, None)
        for r in deduped
    ]
    psycopg2.extras.execute_values(cur, sql, rows, page_size=1000)
    if verbose:
        print(f"[output] Wrote {len(rows)} rows to {ws}.concept_relationship_stage")
    return len(rows)


# ── Ensure tables exist ───────────────────────────────────────────────────────

def ensure_tables(conn):
    ws = config.DB_WORK_SCHEMA
    cur = conn.cursor()
    cur.execute(f"""
        CREATE TABLE IF NOT EXISTS {ws}.concept_stage (
            concept_name        VARCHAR(255),
            domain_id           VARCHAR(20),
            vocabulary_id       VARCHAR(20),
            concept_class_id    VARCHAR(20),
            standard_concept    VARCHAR(1),
            concept_code        VARCHAR(50),
            valid_start_date    DATE,
            valid_end_date      DATE,
            invalid_reason      VARCHAR(1)
        )""")
    cur.execute(f"""
        CREATE TABLE IF NOT EXISTS {ws}.concept_relationship_stage (
            concept_code_1      VARCHAR(50),
            concept_code_2      VARCHAR(50),
            vocabulary_id_1     VARCHAR(20),
            vocabulary_id_2     VARCHAR(20),
            relationship_id     VARCHAR(20),
            valid_start_date    DATE,
            valid_end_date      DATE,
            invalid_reason      VARCHAR(1)
        )""")
    conn.commit()


# ── Main ──────────────────────────────────────────────────────────────────────

def run(verbose=True):
    if verbose:
        print("[output] Running compare...")
    new, updated, same, retiring, relationships = compare_run(verbose=verbose)

    all_concepts   = new + updated + same + retiring
    retiring_codes = {r['concept_code'] for r in retiring}
    known_codes    = {c['concept_code'] for c in all_concepts}

    conn = config.get_db_conn()
    cur  = conn.cursor()
    try:
        ensure_tables(conn)
        n_concepts = _write_concepts(cur, all_concepts, retiring_codes, verbose)
        n_rels     = _write_relationships(cur, relationships, known_codes, verbose)
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    if verbose:
        print(f"\n[output] Done.")
        print(f"  New:      {len(new):>6}")
        print(f"  Updated:  {len(updated):>6}")
        print(f"  Same:     {len(same):>6}")
        print(f"  Retiring: {len(retiring):>6}")
        print(f"  Rels:     {n_rels:>6}")

    return n_concepts, n_rels


if __name__ == "__main__":
    run(verbose=True)
