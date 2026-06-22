# NAACCR → OMOP Metastasis Mapping — Task Briefing

## What we are doing

We are mapping coded values from the **NAACCR cancer registry** (North American Association of Central Cancer Registries) into the **OMOP CDM vocabulary**. Specifically, we are filling a working table called `christian.naaccr_mapping` that will ultimately feed into `concept_relationship_manual`.

Each row in the mapping table represents one NAACCR coded value that needs to be translated into OMOP standard concepts. For metastasis-related codes, each row needs four things filled in:

| Column | Meaning |
|--------|---------|
| `maps_to_concept_name` | The OMOP Cancer Modifier concept for what kind of metastasis this is (e.g. "Metastasis to liver", "Malignant pleural effusion") |
| `polarity` | **Positive** (metastasis present), **Negative** (no metastasis), or **Equivocal** (uncertain/molecular only) |
| `size_cm` | If the code encodes a size, the numeric value in cm (midpoint for ranges) |
| `SKIP_reason` | If this row should NOT be mapped as a metastasis, explain why (e.g. "extension not metastasis", "M-stage annotation only", "lymph node — do separately", "grade/stage — do separately") |

## The two CSV files attached

1. **cowork_metastasis.csv** — 4,546 rows of NAACCR metastasis-candidate values to be mapped. Columns:
   - `item` — NAACCR item number
   - `i_name` — NAACCR variable name
   - `value` — the coded value
   - `v_name` — the value label/description (this is what you use to make the decision)
   - `cur_maps_to_id/name/class` — a concept already assigned in a prior pass (may be wrong — review it)
   - `cur_polarity_id/name` — polarity already assigned (may be wrong or missing)
   - `cur_value_as_number/unit` — size already assigned if any
   - **`NEW_maps_to_concept_name`** — ← YOU FILL THIS IN (or leave blank to keep cur, or put SKIP)
   - **`NEW_polarity`** — ← YOU FILL THIS IN (Positive / Negative / Equivocal / blank to keep cur)
   - **`NEW_size_cm`** — ← YOU FILL THIS IN if size is encoded
   - **`SKIP_reason`** — ← YOU FILL THIS IN if this row should be skipped

2. **cowork_met_concepts.csv** — the 529 valid OMOP Cancer Modifier Metastasis concepts with their `concept_id` and `concept_name`. Use `concept_name` as the value for `NEW_maps_to_concept_name`.

## Rules already agreed

### What IS a metastasis here
- Distant spread of cancer to another organ or site
- Malignant effusions (pleural, pericardial, ascites)
- Circulating tumor cells (treat as Equivocal)

### What is NOT a metastasis — put reason in SKIP_reason
- **Extensions** (contiguous spread to adjacent structures) — "do later"
- **Lymph node involvement** (LN, lymph, nodes in v_name) — "lymph node — do separately"
- **M-stage annotations only** — values whose v_name consists solely of "Stated as M1a/M1b/M1c with no other information on distant metastasis" → these are TNM M-stage codes that will be mapped separately as staging. Skip them.
- **Grades and scores** (Gleason, Nottingham, nuclear grade) — "grade — do separately"
- **Stages** (AJCC T/N/M stage values) — "stage — do separately"
- **Registry/admin/unknown/not applicable codes** — "admin"
- CS Mets Eval (item 2860) — skip entirely ("evaluation code, not finding")

### Polarity logic
- Value describes absence of metastasis → **Negative**
- Value describes confirmed metastasis → **Positive**
- Value describes "molecular only", "circulating tumor cells", "isolated tumor cells" → **Equivocal**

### Size logic
- If a code encodes a numeric size (e.g. a range like "3-8 cm"), put the **midpoint** in `NEW_size_cm`
- Verbal size ranges in NAACCR item 2910 "Size of Largest Metastasis":
  - 991 = less than 3 cm → 1.5 cm
  - 992 = 3–8 cm → 5.5 cm  
  - 993 = greater than 8 cm → 8 cm (minimum, no upper bound)
  - 980 = ≥980 mm → 98 cm

### When multiple metastatic sites are mentioned in one code
Pick the **most specific** concept. For example, if the code says "CNS metastasis, carcinomatosis, distant mets NOS", map to "Metastasis to central nervous system" rather than generic "Metastasis". If there are truly multiple distinct sites (e.g. bone AND liver), use generic "Metastasis" as the best single concept.

### The "Stated as M1b" subtlety
Many CS Mets at DX (item 2850) codes say things like:  
`"Distant metastasis to lung only || Stated as M1a with no other information"`  
The FIRST part is the actual finding — map to "Metastasis to lung", Positive.  
The "Stated as M..." part is just a TNM cross-reference — ignore it, do NOT skip the row.  
Only skip if the ENTIRE v_name is just the M-stage statement with nothing else.

## Concept selection tips

- Generic fallback: **"Metastasis"** (concept_id 36769180) — use when site is NOS or multiple
- Pleural effusion: **"Malignant pleural effusion"** (concept_id 36770024)
- Ascites: **"Malignant ascites"** (concept_id 36770524)
- Bone: **"Metastasis to bone"** (36769301)
- Liver: **"Metastasis to liver"** (36770544)
- Lung: **"Metastasis to lung"** (36770283)
- CNS: **"Metastasis to central nervous system"** (35226096)
- Peritoneum: **"Metastasis to peritoneum"** (35226253)
- Skin: **"Metastasis to skin"** (35225673)
- Spinal cord: **"Metastasis to spinal cord"** (35225743)
- See cowork_met_concepts.csv for all 529 options.

## What to do with the `cur_` columns

- If `cur_concept_class` = **Staging/Grading** or **Histopattern** → that's wrong, put SKIP_reason = "grade — do separately" or correct the concept
- If `cur_concept_class` = **Metastasis** and the v_name looks right → leave NEW columns blank (we'll keep the current mapping, just add polarity)
- If `cur_concept_class` = **Metastasis** but the v_name is an extension or M-stage-only → put SKIP_reason

## Output

Please return the filled CSV. For rows you don't change, leave NEW columns blank. Only fill in NEW columns where you are making a correction or addition. Add a note in SKIP_reason for anything you're skipping so we can review it.
