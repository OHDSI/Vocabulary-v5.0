"""
fetch.py  —  Populate the source fetch tables in DB_SOURCES_SCHEMA.

Calls load_to_db() on each source module in sequence, writing raw data from
all five upstream providers into the naaccr_* tables.  Each loader truncates
its tables before inserting, so this is always a full reload.

Usage:
    python fetch.py
"""

import config
from sources import naaccr_api, naaccr_html, eod, tnm, surgery


def run(verbose=True):
    conn = config.get_db_conn()
    try:
        naaccr_api.load_to_db(conn, verbose=verbose)
        naaccr_html.load_to_db(conn, verbose=verbose)
        eod.load_to_db(conn, verbose=verbose)
        tnm.load_to_db(conn, verbose=verbose)
        surgery.load_to_db(conn, verbose=verbose)
        conn.commit()
        if verbose:
            print(f"\n[fetch] All sources loaded into {config.DB_SOURCES_SCHEMA}.")
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    run(verbose=True)
