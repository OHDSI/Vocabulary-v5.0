"""
test_relationships.py

Validates that the relationship list produced by build_concepts.build()
is internally consistent with the concept list.

Rules
-----
R1  For each 2-part Value (item@code):
        exactly 1 "Has Answer" relationship where it is concept_code_2

R2  For each 3-part Value (schema@item@code):
        exactly 1 "Has Answer" relationship where it is concept_code_2
        exactly 1 "Schema to Value" relationship where it is concept_code_2

R3  For each plain Variable (item_number, no @) that has at least one
    2-part Value in the concept set:
        at least 1 "Has Answer" relationship where it is concept_code_1

R4  For each compound Variable (schema@item):
        exactly 1 "Schema to Variable" relationship where it is concept_code_2
        if it has at least one 3-part Value in the concept set:
            at least 1 "Has Answer" relationship where it is concept_code_1

Note: Variables with no coded permissible values (free-text, date, continuous
numeric) are excluded from R3/R4 Has Answer checks — they legitimately have
no answers.
"""

import sys
from collections import defaultdict
from build_concepts import build


def run(verbose=True):
    concepts, rels = build(verbose=False)

    # Index relationships by endpoint and type
    # has_answer_sources[code]  = number of Has Answer rels where code is concept_code_1
    # has_answer_targets[code]  = number of Has Answer rels where code is concept_code_2
    # stv_targets[code]         = number of Schema to Value rels where code is concept_code_2
    # stva_targets[code]        = number of Schema to Variable rels where code is concept_code_2

    has_answer_sources = defaultdict(int)
    has_answer_targets = defaultdict(int)
    stv_targets        = defaultdict(int)
    stva_targets       = defaultdict(int)

    for r in rels:
        rid = r['relationship_id']
        c1  = r['concept_code_1']
        c2  = r['concept_code_2']
        if rid == 'Has Answer':
            has_answer_sources[c1] += 1
            has_answer_targets[c2] += 1
        elif rid == 'Schema to Value':
            stv_targets[c2] += 1
        elif rid == 'Schema to Variable':
            stva_targets[c2] += 1

    # Pre-compute which Variables actually have values (for R3/R4 conditional checks)
    vars_with_2part = {c['concept_code'].split('@')[0]
                       for c in concepts.values()
                       if c['concept_class_id'] == 'NAACCR Value'
                       and c['concept_code'].count('@') == 1}
    vars_with_3part = {c['concept_code'].rsplit('@', 1)[0]
                       for c in concepts.values()
                       if c['concept_class_id'] == 'NAACCR Value'
                       and c['concept_code'].count('@') == 2}

    errors = []

    for code, c in concepts.items():
        cls = c['concept_class_id']

        if cls != 'NAACCR Value' and cls != 'NAACCR Variable':
            continue

        parts = code.count('@')

        # ── R1: 2-part Value ─────────────────────────────────────────────────
        if cls == 'NAACCR Value' and parts == 1:
            n = has_answer_targets[code]
            if n != 1:
                errors.append(
                    f"R1  2-part Value {code!r} has {n} 'Has Answer' targets (expected 1)")

        # ── R2: 3-part Value ─────────────────────────────────────────────────
        elif cls == 'NAACCR Value' and parts == 2:
            n_ha  = has_answer_targets[code]
            n_stv = stv_targets[code]
            if n_ha != 1:
                errors.append(
                    f"R2  3-part Value {code!r} has {n_ha} 'Has Answer' targets (expected 1)")
            if n_stv != 1:
                errors.append(
                    f"R2  3-part Value {code!r} has {n_stv} 'Schema to Value' targets (expected 1)")

        # ── R3: plain Variable (only if it has 2-part values) ────────────────
        elif cls == 'NAACCR Variable' and parts == 0:
            if code in vars_with_2part:
                n = has_answer_sources[code]
                if n < 1:
                    errors.append(
                        f"R3  plain Variable {code!r} has {n} 'Has Answer' sources (expected >= 1)")

        # ── R4: compound Variable ─────────────────────────────────────────────
        elif cls == 'NAACCR Variable' and parts == 1:
            n_stva = stva_targets[code]
            if n_stva != 1:
                errors.append(
                    f"R4  compound Variable {code!r} has {n_stva} 'Schema to Variable' targets (expected 1)")
            if code in vars_with_3part:
                n_ha = has_answer_sources[code]
                if n_ha < 1:
                    errors.append(
                        f"R4  compound Variable {code!r} has {n_ha} 'Has Answer' sources (expected >= 1)")

    # ── Summary ───────────────────────────────────────────────────────────────
    two_part      = sum(1 for c in concepts.values()
                        if c['concept_class_id'] == 'NAACCR Value'     and c['concept_code'].count('@') == 1)
    three_part    = sum(1 for c in concepts.values()
                        if c['concept_class_id'] == 'NAACCR Value'     and c['concept_code'].count('@') == 2)
    plain_vars    = sum(1 for c in concepts.values()
                        if c['concept_class_id'] == 'NAACCR Variable'  and '@' not in c['concept_code'])
    compound_vars = sum(1 for c in concepts.values()
                        if c['concept_class_id'] == 'NAACCR Variable'  and '@' in c['concept_code'])

    if verbose:
        print(f"Concepts checked:")
        print(f"  Plain Variables (R3):    {plain_vars:>7}")
        print(f"  Compound Variables (R4): {compound_vars:>7}")
        print(f"  2-part Values (R1):      {two_part:>7}")
        print(f"  3-part Values (R2):      {three_part:>7}")
        print()
        if errors:
            print(f"FAILURES ({len(errors)}):")
            for e in errors[:50]:
                print(f"  {e}")
            if len(errors) > 50:
                print(f"  ... and {len(errors) - 50} more")
        else:
            print("All relationship checks PASSED.")

    return errors


if __name__ == "__main__":
    errors = run(verbose=True)
    sys.exit(1 if errors else 0)
