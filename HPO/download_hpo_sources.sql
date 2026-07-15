-- FUNCTION: dev_hpo.download_hpo_json_simple()
-- Description: Downloads HPO data in JSON format from the official repository
--              and loads it into the dev_hpo.hpo_json table
-- Returns: Success message or error
-- Language: plpython3u
-- ============================================================================

CREATE OR REPLACE FUNCTION dev_hpo.download_hpo_json_simple()
RETURNS TEXT
LANGUAGE plpython3u
AS $function$
import urllib.request
import json
import ssl

try:
    # Official HPO JSON distribution URL
    url = 'https://purl.obolibrary.org/obo/hp.json'

    # Download JSON with standard SSL verification first.
    # If local CA bundle is missing, retry once without certificate verification.
    try:
        with urllib.request.urlopen(url) as response:
            json_data = response.read().decode('utf-8')
    except Exception as e:
        if 'CERTIFICATE_VERIFY_FAILED' in str(e):
            plpy.notice("SSL verification failed, retrying download with unverified SSL context")
            unverified_ctx = ssl._create_unverified_context()
            with urllib.request.urlopen(url, context=unverified_ctx) as response:
                json_data = response.read().decode('utf-8')
        else:
            raise

    # Parse to validate it's proper JSON format
    data = json.loads(json_data)

    # Prepare and execute insert statement to store HPO JSON data
    plan = plpy.prepare(
        "INSERT INTO dev_hpo.hpo_json (source_json, ts, download_url) VALUES ($1, CURRENT_DATE, $2)",
        ["jsonb", "text"]
    )
    plpy.execute(plan, [json.dumps(data), url])

    return "HPO JSON data downloaded and inserted successfully"

except Exception as e:
    # Log error with descriptive message
    plpy.error(f"Failed to download HPO data: {str(e)}")
$function$;

-- ============================================================================
-- TRIGGER FUNCTION: extract_hpo_version()
-- Description: Automatically extracts version date from HPO JSON and populates
--              the version column
-- ============================================================================

-- Drop existing trigger and function if they exist
DROP TRIGGER IF EXISTS trg_hpo_version_extraction ON dev_hpo.hpo_json;
DROP FUNCTION IF EXISTS extract_hpo_version();

-- Create improved version extraction function
CREATE OR REPLACE FUNCTION extract_hpo_version()
RETURNS TRIGGER AS $$
DECLARE
    version_text TEXT;
    extracted_date TEXT;
BEGIN
    -- Log the extraction process for debugging
    RAISE NOTICE 'Extracting version from JSON for record %', NEW.id;

    -- Extract version text using JSON path from the HPO JSON structure
    version_text := jsonb_path_query_first(
        NEW.source_json,
        '$.**.basicPropertyValues[*] ? (@.pred == "http://www.w3.org/2002/07/owl#versionInfo").val'
    ) #>> '{}';

    RAISE NOTICE 'Extracted version text: %', version_text;

    -- Extract date portion using regex pattern (YYYY-MM-DD format)
    IF version_text IS NOT NULL THEN
        extracted_date := SUBSTRING(version_text FROM '\d{4}-\d{2}-\d{2}');
        RAISE NOTICE 'Extracted date: %', extracted_date;

        -- Convert extracted date string to DATE type and assign to version column
        IF extracted_date IS NOT NULL THEN
            NEW.version := TO_DATE(extracted_date, 'YYYY-MM-DD');
            RAISE NOTICE 'Setting version to: %', NEW.version;
        ELSE
            NEW.version := NULL;
            RAISE NOTICE 'No date pattern found in version text';
        END IF;
    ELSE
        NEW.version := NULL;
        RAISE NOTICE 'No version information found in JSON';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGER: trg_hpo_version_extraction_1
-- Description: Fires before INSERT or UPDATE to automatically extract version
-- ============================================================================

CREATE TRIGGER trg_hpo_version_extraction_1
    BEFORE INSERT OR UPDATE OF source_json ON dev_hpo.hpo_json
    FOR EACH ROW
    EXECUTE FUNCTION extract_hpo_version();






-- ============================================================================
-- FUNCTION: load_genes_data()
-- Description: Loads gene-to-phenotype associations from HPO release file
-- Returns: Success message with row count or error message
-- Language: plpgsql
-- ============================================================================

CREATE OR REPLACE FUNCTION dev_hpo.load_genes_data(
    p_version text,
    p_batch_size integer DEFAULT 2000,
    p_progress_every_batches integer DEFAULT 1,
    p_timeout_seconds integer DEFAULT 120
)
RETURNS text
LANGUAGE plpython3u
AS $$
import urllib.request
import csv
import io
import re
import ssl

if p_version is None or not re.fullmatch(r"v\d{4}-\d{2}-\d{2}", p_version.strip()):
    return "Error: p_version must match vYYYY-MM-DD (example: v2025-11-24)"

version = p_version.strip()
batch_size = int(p_batch_size) if p_batch_size and p_batch_size > 0 else 2000
progress_every_batches = int(p_progress_every_batches) if p_progress_every_batches and p_progress_every_batches > 0 else 1
timeout = int(p_timeout_seconds)

url = f"https://github.com/obophenotype/human-phenotype-ontology/releases/download/{version}/genes_to_phenotype.txt"
plpy.notice(f"Starting load from {url} (multi-row insert, batch_size={batch_size})")

# download
try:
    with urllib.request.urlopen(url, timeout=timeout) as resp:
        data = resp.read()
except Exception as e:
    if "CERTIFICATE_VERIFY_FAILED" in str(e):
        plpy.notice("SSL verify failed, retrying GitHub download without certificate verification")
        try:
            unverified_ctx = ssl._create_unverified_context()
            with urllib.request.urlopen(url, timeout=timeout, context=unverified_ctx) as resp:
                data = resp.read()
        except Exception as e2:
            return f"Error downloading from GitHub after SSL fallback: {e2}"
    else:
        return f"Error downloading from GitHub: {e}"

# decode
try:
    text = data.decode("utf-8")
except UnicodeDecodeError:
    text = data.decode("latin-1")

plpy.execute("TRUNCATE TABLE dev_hpo.genes_to_hpo_phenotype")

reader = csv.reader(io.StringIO(text), delimiter="\t")
next(reader, None)  # header

state = {"inserted": 0, "batches_done": 0}
skipped = 0

def sql_literal(val):
    # Safely quote SQL literals (prevents SQL injection / quoting bugs)
    if val is None:
        return "NULL"
    return plpy.quote_literal(val)

def flush(values_batch):
    if not values_batch:
        return
    sql = (
        "INSERT INTO dev_hpo.genes_to_hpo_phenotype "
        "(ncbi_gene_id, gene_symbol, hpo_id, hpo_name, frequency, disease_id) VALUES "
        + ", ".join(values_batch)
    )
    plpy.execute(sql)
    state["inserted"] += len(values_batch)
    state["batches_done"] += 1
    if state["batches_done"] % progress_every_batches == 0:
        plpy.notice(f"Inserted so far: {state['inserted']} (batches={state['batches_done']})")

values_batch = []

for row in reader:
    if not row or all(c.strip() == "" for c in row):
        continue
    if len(row) != 6:
        skipped += 1
        continue

    # ncbi_gene_id: int or NULL
    gid_raw = row[0].strip()
    if gid_raw == "":
        gid_sql = "NULL"
    else:
        try:
            int(gid_raw)
            gid_sql = gid_raw  # safe as integer literal
        except ValueError:
            skipped += 1
            continue

    tup = "(" + ", ".join([
        gid_sql,
        sql_literal(row[1].strip() or None),
        sql_literal(row[2].strip() or None),
        sql_literal(row[3].strip() or None),
        sql_literal(row[4].strip() or None),
        sql_literal(row[5].strip() or None),
    ]) + ")"

    values_batch.append(tup)

    if len(values_batch) >= batch_size:
        flush(values_batch)
        values_batch = []

# final batch
flush(values_batch)

return (
    f"Completed. Inserted={state['inserted']}, Skipped={skipped}, "
    f"Version={version}, Batches={state['batches_done']}, BatchSize={batch_size}"
)
$$;







-- ============================================================================
-- STEP : Populate HPO JSON table with most recent content
-- Description: Executes the download function to fetch and store the latest
--              HPO JSON distribution
-- ============================================================================
DO $_$
BEGIN
PERFORM dev_hpo.download_hpo_json_simple();
END $_$;

-- ============================================================================
-- STEP : Load gene-to-phenotype associations
-- Description: Executes the load function to import associations between genes
--              and HPO phenotypes from the remote file
-- ============================================================================

DO
$_$
    BEGIN
        PERFORM dev_hpo.load_genes_data('v' || a.version::varchar, 5000, 2)
        FROM dev_hpo.hpo_json a
        ORDER BY version::date DESC
        LIMIT 1;
    END
$_$;

