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

    if dry_run:
        # Just build + compare, write nothing
        new, updated, same, retiring, relationships = compare.run(verbose=True)
        print(f"\n[run] DRY RUN — nothing written to DB.")
        print(f"  New:      {len(new):>6}")
        print(f"  Updated:  {len(updated):>6}")
        print(f"  Same:     {len(same):>6}")
        print(f"  Retiring: {len(retiring):>6}")
        print(f"  Rels:     {len(relationships):>6}")
        return

    # Full run: build, compare, write
    output.run(verbose=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="NAACCR vocabulary update tool")
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show diff counts without writing to DB"
    )
    args = parser.parse_args()
    main(dry_run=args.dry_run)
