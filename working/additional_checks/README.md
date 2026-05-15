# Vocabulary Update

## Setup

1. Edit **`R/config.R`** to set the correct vocabulary schema versions and scratch schema for the new release.
2. Credentials are read from `keyring`. First-time setup (run once in the R console):
   ```r
   keyring::key_set("databricks", "connection_string")
   keyring::key_set("databricks", "token")
   ```

## Database dialect

The default pipeline targets **Databricks / Spark**. If your vocabulary database runs on **PostgreSQL**, replace Step 2 with the PostgreSQL variant:

```r
# instead of source("R/collect_checks.R")
source("R/postgresql/collect_checks_postgres.R")
```

The PostgreSQL variant is identical in logic and output — it only differs in connection setup and two SQL aggregation functions that Spark handles natively (`sort_array` / `collect_set` → `string_agg`). All other SQL files are reused as-is via DatabaseConnector's automatic dialect translation.

First-time keyring setup for PostgreSQL (run once in the R console):
```r
keyring::key_set("postgres_vocab", "host")
keyring::key_set("postgres_vocab", "port")       # e.g. 5432
keyring::key_set("postgres_vocab", "database")
keyring::key_set("postgres_vocab", "user")
keyring::key_set("postgres_vocab", "password")
```

## Pipeline

Run all four steps in order by sourcing **`run_all.R`**:
```r
source("run_all.R")
```
Or execute each script individually — every script sources `config.R` on its own.

### Step 1 — `R/refresh_stcm.R`
Refreshes `source_to_concept_map`. Automatic updates run first; the script then opens
`STCM_to_map.csv` for manual review. Fill in `STCM_manual.csv`, then re-run from the
upload step onward. Ends with checks to confirm STCM was updated correctly.

### Step 2 — `R/collect_checks.R`
Checks overall OHDSI vocabulary quality (missing mappings, duplicates, drug hierarchy issues).
Outputs `vocab_checks.xlsx`. See [`vocab_checks_description.md`](vocab_checks_description.md) for a description of every check.

> Other custom vocabulary changes (custom concepts, HCPCS reuse) live in the `v___jnj` schema
> and are merged into the `_omop` schema separately.

### Step 3 — `R/phenotypeChanges.R`
Shows how vocabulary changes affect JnJ phenotypes. Before running, populate
`Cohorts2026.csv` with the latest cohort IDs from the JnJ Phenotype Library.

### Step 4 — `R/check_map_dif.R`
Uses an LLM (Azure OpenAI `o3` via ellmer) to evaluate ICD mapping differences between
the old and new vocabulary. Outputs `mapping_output.csv`.

## Other SQL files

| File | Purpose |
|------|---------|
| `compare_Atc_Rxnorm_hierarchy.sql` | Ad-hoc comparison of ATC/RxNorm drug hierarchies |
| `lost_leg_of_mapping.sql` | Identifies mapping chains that lost an intermediate step |
| `drug_map_dif.sql` | Called by `collect_checks.R` to find drug mapping deltas |
| `stcm_refresh_part_1/2/3.sql` | Called by `refresh_stcm.R` |
| `mapping_changed.sql` | Called by `check_map_dif.R` |
