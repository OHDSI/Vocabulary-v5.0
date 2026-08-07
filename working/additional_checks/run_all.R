# run_all.R — Vocabulary refresh pipeline orchestrator
#
# Runs all four steps in order. Read the notes below before executing;
# Step 1 requires a manual mapping review before it can finish.
#
# You can also source individual scripts directly — each calls source("R/config.R")
# at the top, so they work standalone as well.

source("R/config.R")   # load shared config once; individual scripts re-source safely

# ── Step 1: Refresh source_to_concept_map ─────────────────────────────────────
# Automatic updates run first. The script then opens STCM_to_map.csv for manual
# mapping. Fill in STCM_manual.csv, then continue (or re-run this step).
message("=== Step 1: Refresh STCM ===")
source("R/refresh_stcm.R")

# ── Step 2: Overall OHDSI vocabulary quality checks ───────────────────────────# PostgreSQL users: replace the source() below with:
#   source("R/postgresql/collect_checks_postgres.R")message("=== Step 2: Vocabulary quality checks ===")
source("R/collect_checks.R")

# ── Step 3: Phenotype impact ───────────────────────────────────────────────────
# Edit Cohorts2026.csv with the latest JnJ cohort IDs before running.
# Authenticate against Atlas WebAPI (requires interactive Windows session).
ROhdsiWebApi::authorizeWebApi(baseUrl = baseUrl, authMethod = "windows")
message("=== Step 3: Phenotype changes ===")
source("R/phenotypeChanges.R")

# ── Step 4: ICD mapping differences (LLM review) ──────────────────────────────
message("=== Step 4: ICD mapping diff (LLM) ===")
source("R/check_map_dif.R")

message("=== Pipeline complete ===")
