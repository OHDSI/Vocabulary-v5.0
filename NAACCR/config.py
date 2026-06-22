"""
Central configuration — loads everything from .env.
Import this module at the top of every other script.
"""

import os
from dotenv import load_dotenv

# Load .env from the same directory as this file
_here = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(_here, ".env"))

# ── Database ──────────────────────────────────────────────────────────────────
DB_HOST     = os.environ["DB_HOST"]
DB_PORT     = int(os.environ.get("DB_PORT", 5432))
DB_NAME     = os.environ["DB_NAME"]
DB_USER     = os.environ["DB_USER"]
DB_PASSWORD = os.environ["DB_PASSWORD"]

# Schema that holds the official OMOP vocabularies (read-only for us)
DB_SOURCE_SCHEMA   = os.environ.get("DB_SOURCE_SCHEMA", "prodv5")
# Schema where we can write concept_stage / concept_relationship_stage
DB_WORK_SCHEMA     = os.environ.get("DB_WORK_SCHEMA", "dev_christian")
# Schema where raw source fetch tables live (naaccr_items, naaccr_eod_values, etc.)
# Defaults to "sources"; override in .env while waiting for permissions
DB_SOURCES_SCHEMA  = os.environ.get("DB_SOURCES_SCHEMA", "sources")

def get_db_conn():
    """Return a new psycopg2 connection."""
    import psycopg2
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
        user=DB_USER, password=DB_PASSWORD
    )

# ── SEER / NAACCR API ─────────────────────────────────────────────────────────
SEER_API_KEY    = os.environ["SEER_API_KEY"]
SEER_API_BASE   = "https://api.seer.cancer.gov/rest"
NAACCR_VERSION  = os.environ.get("NAACCR_VERSION", "26")

# ── Staging algorithm versions ────────────────────────────────────────────────
EOD_VERSION = os.environ.get("EOD_VERSION", "3.3")
TNM_VERSION = os.environ.get("TNM_VERSION", "2.1")

# GitHub release base URL for staging ZIP files
STAGING_GITHUB_RELEASE = (
    "https://github.com/imsweb/staging-client-java/releases/download/v11.9.2"
)

# ── OMOP vocabulary constants ─────────────────────────────────────────────────
VOCABULARY_ID = "NAACCR"

# concept_class_id values used in this vocabulary
CLASS_VARIABLE        = "NAACCR Variable"
CLASS_VALUE           = "NAACCR Value"
CLASS_SCHEMA          = "NAACCR Schema"
CLASS_PROC_SCHEMA     = "NAACCR Proc Schema"
CLASS_PROCEDURE       = "NAACCR Procedure"
CLASS_PERM_RANGE      = "Permissible Range"

# Download cache directory (gitignored)
DOWNLOAD_DIR = os.path.join(_here, "downloads")
os.makedirs(DOWNLOAD_DIR, exist_ok=True)
