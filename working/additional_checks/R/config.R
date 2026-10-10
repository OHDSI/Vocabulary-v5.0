# config.R — Shared configuration for all vocabulary update scripts
#
# Source this file at the start of each script by adding:
#   source("R/config.R")
# Or run it once from run_all.R before sourcing individual scripts.

library(DatabaseConnector)

# ── Vocabulary schemas ─────────────────────────────────────────────────────────
oldVocSchema  <- "vocabulary_old"        # previous OHDSI vocabulary release
newVocSchema  <- "vocabulary_new"   # new vocabulary with merged custom STCM
scratchSchema <- "scratch_username"    # personal scratch schema for intermediate tables
resultSchema  <- "result_schema"    # schema holding achilles_result_concept_count

# ── Folder layout ─────────────────────────────────────────────────────────────
# SQL sources
sqlDir <- "sql"

# Per-run outputs: output/<newVocSchema with dots replaced by underscores>/
outputDir <- file.path("output", gsub("\\.", "_", newVocSchema))
dir.create(outputDir, showWarnings = FALSE, recursive = TRUE)

# ── Atlas base URL ─────────────────────────────────────────────────────────────
baseUrl <- "https://your-atlas-host/WebAPI/"

# ── CDM schema (for Alathea stats tab) ─────────────────────────────────────────
# Requires access to patient-level data. Set to NULL to skip the stats tab.
cdmSchema <- yourDataSetSchema  # set to e.g. 'cdm_schema.cdm_table' to enable stats tab

# ── LLM (ellmer / Azure OpenAI) ──────────────────────────────────────────────
# First-time setup (run once in the R console):
#   keyring::key_set("genai_o3_endpoint")    # full deployment endpoint URL
#   keyring::key_set("genai_api_gpt4_key")   # API key
model <- "o3"   # Azure OpenAI deployment name

# ── Database connection ────────────────────────────────────────────────────────
# Credentials are stored in keyring — no passwords in source code.
# First-time setup (run once in the R console):
#   keyring::key_set("databricks", "connection_string")
#   keyring::key_set("databricks", "token")
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms             = "spark",
  connectionString = keyring::key_get("databricks", "connection_string"),
  user             = "token",
  password         = keyring::key_get("databricks", "token")
)

# refresh_stcm.R uses the name connectionDetailsVocab.
# If your vocabulary database is on a different server, create a separate entry here.
connectionDetailsVocab <- connectionDetails
