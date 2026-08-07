# Vocabulary Checks — `collect_checks.R`

All checks run against `newVocSchema` (the new vocabulary) and, where relevant,
compare against `oldVocSchema` (the previous release). Results are written to
`output/<release>/vocab_checks.xlsx`, one tab per check.

---

## Release-specific checks

### `missingInlexzo`
**Purpose:** Confirms that gemcitabine intravesical (brand name Inlexzo) is present
in the new vocabulary and that all relevant source vocabularies have a mapping to it.

**Why it matters:** Inlexzo received FDA approval and may be absent from a vocabulary
release for some time. If it is missing from RxNorm, HCPCS, NDC, CPT4, or ICD10PCS,
drug utilisation analyses will silently miss it.

**What it reports:** Drug vocabularies (HCPCS, NDC, RxNorm, CPT4, ICD10PCS) that
either (1) do not contain the concept at all, or (2) do not have a *Maps to* relationship
pointing to it when the RxNorm concept is already available.

---

## Missing-mapping checks

### `ICD_jnj_mis_map`
**Purpose:** ICD diagnosis vocabularies used at JnJ that have no *Maps to* standard concept.

**Scope:** ICD9CM, ICD10 (international), and ICD10CM (effective from Oct 2015).
Excludes chapter-level codes and administrative codes ("Emergency use", "Invalid ICD10").

**Why it matters:** Unmapped codes silently drop out of condition analyses.
This is scoped to vocabularies actually present in JnJ source data to keep the
review list manageable.

---

### `ICD_all_mis_map`
**Purpose:** Same as above but covers the full set of ICD vocabularies in OMOP,
including ICD10GM (Germany), CIM10 (France), ICD10CN (China), KCD7 (Korea), and
ICDO3 (oncology — precoordinated conditions only).

**Why it matters:** Used when assessing vocabulary quality from a global OHDSI
perspective, not just JnJ.

---

### `Prc_jnj_mis_map`
**Purpose:** Procedure vocabularies used at JnJ (ICD10PCS, ICD9Proc, HCPCS, CPT4) that
have no *Maps to* standard concept.

Excludes hierarchy/class nodes and concepts containing "not" in their name
(typically "procedure not elsewhere classified" catch-alls that are intentionally
left unmapped).

---

### `Prc_all_mis_map`
**Purpose:** Same as above but extends the scope to global procedure vocabularies:
adds OPS (Germany), CCAM (France), OPCS4 (UK).

---

### `Prc_JnJDrug_no_map`
**Purpose:** Procedure codes (HCPCS, CPT4, ICD10PCS, ICD9Proc) that potentially describe a
drug administration but do NOT have a *Maps to* relationship pointing to a Drug
domain concept — restricted to JnJ brand names and ingredients
(from the `bnui` lookup table in `scratchSchema`).

**Detection method:** Concept name contains a known JnJ brand name or active
ingredient AND the name matches drug administration patterns (dose units, route
keywords).

**Why it matters:** Drug administration codes are a primary source for drug exposure
in claims data. A missing mapping means drug use goes uncaptured in CDM analyses.
Restricting to JnJ products keeps the review set small.

---

### `Prc_Drug_no_map`
**Purpose:** Broader version of the above — all procedure codes whose name contains
a known RxNorm Ingredient or Brand Name (≥ 5 characters) and that match
administration/dosing patterns, but lack a Drug domain mapping.

**Why it matters:** Catches drug-procedure mappings missed by the JnJ-specific
filter. Tends to produce a large result set; primarily useful for understanding
overall vocabulary coverage.

---

## Delta checks (new release vs. previous release)

### `Prc_Delta_Drug_no_map`
**Purpose:** Same logic as `Prc_Drug_no_map` but restricted to procedure concepts
that are **new in the current release** (absent from `oldVocSchema`).

**Why it matters:** New procedure codes for drug administrations need immediate
mapping. Reviewing only the delta keeps the set tractable even when the full
`Prc_Drug_no_map` list is too large to review.

---

### `JnJDrug_map_change`
**Purpose:** JnJ drug-related procedure codes (filtered via `bnui` and
`achilles_result_concept_count` — minimum 100 patient records) whose *Maps to*
target changed between the old and new vocabulary.

**What it reports:** For each affected code: old and new aggregated target concept
codes/names/relationship types, and patient record count.

**Why it matters:** A mapping change for a high-frequency drug code can silently
alter cohort membership, drug utilisation counts, or safety signal detection.
These were reviewed by Sciforce in the past; the delta focus avoids re-reviewing
stable mappings.

---

### `lost_leg_of_mapping`
**Purpose:** Source codes (ICD10, ICD10CM, CPT4, HCPCS, NDC, ICD9CM, ICD9Proc,
ICD10PCS, ICDO3, JMDC) where at least one *Maps to* target existed in the old
vocabulary but some targets were lost or gained in the new one — and at least one
target was **kept** (i.e. partial mapping change, not a complete remap).

**What it reports:** Each row is one old/new target pair with status KEPT, LOST,
or ADDED. For LOST targets, shows any replacement path available in the new
vocabulary via *Maps to* or *Concept replaced by*.

**Why it matters:** A "lost leg" means a multi-target mapping became narrower.
If the lost target was clinically important the phenotype may now under-count.

---

### `atc_rxnorm_lost`
**Purpose:** ATC ↔ RxNorm direct and self-links (min_levels_of_separation 0 or 1)
present in the old vocabulary hierarchy but absent from the new one.

**Why it matters:** Changes to the ATC/RxNorm hierarchy can break drug class
membership. A lost link between an ATC class and an RxNorm ingredient removes
all descendants of that ingredient from the ATC class in any hierarchy-based query.

---

### `atc_rxnorm_added`
**Purpose:** Inverse of the above — ATC ↔ RxNorm edges that are **new** in the
current release.

**Why it matters:** New edges expand drug class membership. Worth reviewing to
confirm new inclusions are clinically appropriate and do not unexpectedly inflate
cohort sizes.

---

## Vocabulary health summary

### `VocabReport`
**Purpose:** Counts of structural issues in both the old and new vocabulary,
side by side, to confirm the new release does not regress.

| Metric | Description |
|--------|-------------|
| `Name_duplicate` | Standard concepts sharing the same name within the same domain. Duplicates can cause ambiguity in text-search-based mapping. |
| `no children and no parent codes` | Standard or Classification concepts with no parent and no children in `concept_ancestor`. Isolated nodes indicate hierarchy gaps. |
| `concept has no Ingredient as a parent` | Standard Drug domain concepts with no Ingredient ancestor. Without an Ingredient ancestor a drug concept is unreachable via class-roll-up queries. |

A count that is **higher** in the new vocabulary than the old warrants investigation
before promoting the release.
