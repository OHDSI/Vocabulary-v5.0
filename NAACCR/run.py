"""
run.py  —  Main entry point for the NAACCR vocabulary update tool.

Steps:
  1. Fetch all source data (NAACCR API, EOD ZIP, TNM ZIP)
  2. Assemble into OMOP concept rows
  3. Compare against existing ProdV5 vocabulary
  4. Write new concepts + relationships into the manual stage tables

Usage:
  python run.py           # full run (fetches + writes to DB)
  python run.py --dry-run # shows diff counts, writes nothing
"""

import argparse
import sys

import build_concepts
import compare
import config
import output


def main(dry_run=False):
    print("=" * 60)
    print("NAACCR Vocabulary Update Tool")
    print("=" * 60)

    # Step 1 + 2: Fetch and assemble
    new_concepts, new_relationships = build_concepts.build(verbose=True)

    # Step 3: Compare against DB
    print("\n[run] Loading existing concepts from DB...")
    existing = compare.load_existing()
    to_add, to_retire, to_update = compare.diff(new_concepts, existing, verbose=True)

    if to_retire:
        print(f"\n[run] WARNING: {len(to_retire)} concepts in DB not found in sources.")
        print("  First 10 retired concept codes:")
        for code in to_retire[:10]:
            c = existing[code]
            print(f"    {code:50} [{c['concept_class_id']}]")
        print("  (Retirement requires manual review — not auto-applied.)")

    if to_update:
        print(f"\n[run] {len(to_update)} concepts have changed names:")
        for u in to_update[:10]:
            print(f"    {u['concept_code'][:45]}")
            print(f"      OLD: {u['old_name'][:70]}")
            print(f"      NEW: {u['new_name'][:70]}")
        if len(to_update) > 10:
            print(f"    ... and {len(to_update) - 10} more.")

    if dry_run:
        print("\n[run] DRY RUN — nothing written to DB.")
        return

    if not to_add:
        print("\n[run] Nothing to add. Vocabulary is up to date.")
        return

    # Step 4: Write to DB
    print(f"\n[run] Writing {len(to_add)} new concepts to DB...")
    conn = config.get_db_conn()
    try:
        output.ensure_tables(conn)
        output.write_concepts(conn, to_add, verbose=True)

        # Filter relationships: only include ones where both codes are new
        # (existing relationships are already in ProdV5)
        new_code_set = {c["concept_code"] for c in to_add}
        rels_to_add = [
            r for r in new_relationships
            if r["concept_code_1"] in new_code_set or r["concept_code_2"] in new_code_set
        ]
        print(f"[run] Writing {len(rels_to_add)} relationships...")
        output.write_relationships(conn, rels_to_add, verbose=True)
    finally:
        conn.close()

    print("\n[run] Done.")
    print(f"  Review christian.concept_stage_manual ({len(to_add)} rows)")
    print(f"  Then run the load_stage script to promote into ProdV5.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="NAACCR vocabulary update tool")
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show diff counts without writing to DB"
    )
    args = parser.parse_args()
    main(dry_run=args.dry_run)
