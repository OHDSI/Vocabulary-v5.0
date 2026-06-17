"""
output.py

Writes the results of compare.run() to:
  christian.concept_manual
  christian.concept_relationship_manual

ProcessManualConcepts.sql (on the OHDSI vocab server) reads concept_manual,
matches on concept_code + vocabulary_id, and merges into concept_stage.
generic_update.sql then assigns concept_ids and finalises the load.

Behaviour
---------
- Truncates both target tables, then inserts fresh.
- All four buckets (new, updated, same, retiring) are written to
  concept_manual.  Retiring concepts get valid_end_date = today
  and invalid_reason = 'D'.
- Relationships are written to concept_relationship_manual.
- valid_start_date defaults to 1970-01-01 when not supplied by source.
- valid_end_date  defaults to 2099-12-31 when not supplied.
"""

import os
import datetime
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv

import config
from compare import run as compare_run

TODAY      = datetime.date.today().isoformat()
DATE_START = '1970-01-01'
DATE_END   = '2099-12-31'


# ── DB connection ─────────────────────────────────────────────────────────────

def _connect():
    load_dotenv()
    return psycopg2.connect(
        host=os.getenv('DB_HOST'), port=os.getenv('DB_PORT'),
        dbname=os.getenv('DB_NAME'), user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'))


def _coerce_date(val, default):
    if val is None:
        return default
    s = str(val)
    return default if s in ('None', '') else s


# ── Write concept_manual ────────────────────────────────────────────────

def _write_concepts(cur, all_concepts, retiring_codes, verbose=True):
    ws = config.DB_WORK_SCHEMA
    cur.execute(f"TRUNCATE TABLE {ws}.concept_manual")

    sql = f"""
        INSERT INTO {ws}.concept_manual (
            concept_name, domain_id, vocabulary_id, concept_class_id,
            standard_concept, concept_code,
            valid_start_date, valid_end_date, invalid_reason
        ) VALUES %s
    """

    # Validate before bulk insert — find any concept_code > 50 chars
    over50 = [(c['concept_code'], len(c['concept_code'])) for c in all_concepts
              if len(c['concept_code']) > 50]
    if over50:
        print(f"[output] WARNING: {len(over50)} concept_codes exceed 50 chars — dropping:")
        for code, n in over50[:10]:
            print(f"  ({n}) {code!r}")
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
        print(f"[output] Wrote {len(rows)} rows to {ws}.concept_manual")
    return len(rows)


# ── Write concept_relationship_manual ───────────────────────────────────

def _write_relationships(cur, relationships, verbose=True):
    ws = config.DB_WORK_SCHEMA
    cur.execute(f"TRUNCATE TABLE {ws}.concept_relationship_manual")

    sql = f"""
        INSERT INTO {ws}.concept_relationship_manual (
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
        for r in relationships
    ]
    psycopg2.extras.execute_values(cur, sql, rows, page_size=1000)
    if verbose:
        print(f"[output] Wrote {len(rows)} rows to "
              f"{ws}.concept_relationship_manual")
    return len(rows)


# ── Main ──────────────────────────────────────────────────────────────────────

def run(verbose=True):
    if verbose:
        print("[output] Running compare...")
    new, updated, same, retiring, relationships = compare_run(verbose=verbose)

    all_concepts  = new + updated + same + retiring
    retiring_codes = {r['concept_code'] for r in retiring}

    # Drop any relationship where concept_code_1 doesn't exist in the full
    # concept set.  This catches "Concept replaced by" pairs generated for
    # zero-padded codes (e.g. 1502@08) whose single-digit predecessor (1502@8)
    # was never in the DB and therefore isn't in retiring_codes.
    known_codes = {c['concept_code'] for c in all_concepts}
    before = len(relationships)
    relationships = [r for r in relationships if r['concept_code_1'] in known_codes]
    if verbose and len(relationships) != before:
        print(f"[output] Dropped {before - len(relationships)} rels with unknown concept_code_1")

    conn = _connect()
    cur  = conn.cursor()
    try:
        n_concepts = _write_concepts(cur, all_concepts, retiring_codes, verbose)
        n_rels     = _write_relationships(cur, relationships, verbose)
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
