/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
**************************************************************************/

-- ============================================================================
-- FUNCTION: dev_mondo.download_mondo_json_simple()
-- Description: Downloads MONDO data in JSON format from the official repository
--              and loads it into the dev_mondo.mondo_json table
-- Returns: Success message or error
-- Language: plpython3u
-- ============================================================================

CREATE OR REPLACE FUNCTION dev_mondo.download_mondo_json_simple()
RETURNS TEXT
LANGUAGE plpython3u
AS $function$
import urllib.request
import json
import ssl

try:
    # MONDO JSON download URL
    url = 'https://purl.obolibrary.org/obo/mondo.json'

    # Create a context that disables SSL certificate verification.
    # This avoids certificate verification failures in restricted environments.
    context = ssl._create_unverified_context()

    # Download JSON data with the custom SSL context.
    with urllib.request.urlopen(url, context=context) as response:
        json_data = response.read().decode('utf-8')

    # Validate that the response is valid JSON.
    data = json.loads(json_data)

    # Prepare and execute the insert into the source table.
    # Use json.dumps(data) so PostgreSQL receives a valid jsonb string.
    plan = plpy.prepare(
        "INSERT INTO dev_mondo.mondo_json (source_json, ts, download_url) VALUES ($1, CURRENT_DATE, $2)",
        ["jsonb", "text"]
    )
    plpy.execute(plan, [json.dumps(data), url])

    return "MONDO JSON data downloaded and inserted successfully (SSL check bypassed)"

except Exception as e:
    # Raise the detailed error in PostgreSQL logs.
    plpy.error(f"Failed to download MONDO data: {str(e)}")
$function$;





-- ============================================================================
-- FUNCTION: dev_mondo.download_mondo_sssom_maps_simple()
-- Description: Downloads MONDO SSSOM TSV mappings from GitHub and loads them
--              into dev_mondo.mondo_sssom_maps
-- Returns: Success message or error
-- Language: plpython3u
-- ============================================================================

CREATE OR REPLACE FUNCTION dev_mondo.download_mondo_sssom_maps_simple()
RETURNS TEXT
LANGUAGE plpython3u
AS $function$
import csv
import io
import ssl
import urllib.request

try:
    url = 'https://raw.githubusercontent.com/monarch-initiative/mondo/master/src/ontology/mappings/mondo.sssom.tsv'

    context = ssl._create_unverified_context()
    with urllib.request.urlopen(url, context=context) as response:
        tsv_data = response.read().decode('utf-8-sig')

    lines = tsv_data.splitlines()
    header_index = None
    for idx, line in enumerate(lines):
        if line.startswith('subject_id\t'):
            header_index = idx
            break

    if header_index is None:
        plpy.error('Failed to find SSSOM TSV header in downloaded MONDO mappings')

    reader = csv.DictReader(io.StringIO('\n'.join(lines[header_index:])), delimiter='\t')
    required_columns = [
        'subject_id',
        'subject_label',
        'predicate_id',
        'object_id',
        'object_label',
        'mapping_justification'
    ]

    missing_columns = [column for column in required_columns if column not in reader.fieldnames]
    if missing_columns:
        plpy.error('Downloaded MONDO SSSOM TSV is missing columns: ' + ', '.join(missing_columns))

    rows = [
        [row.get(column) for column in required_columns]
        for row in reader
    ]

    plpy.execute('TRUNCATE TABLE dev_mondo.mondo_sssom_maps')

    plan = plpy.prepare(
        """
        INSERT INTO dev_mondo.mondo_sssom_maps (
            subject_id,
            subject_label,
            predicate_id,
            object_id,
            object_label,
            mapping_justification
        )
        VALUES ($1, $2, $3, $4, $5, $6)
        """,
        ["text", "text", "text", "text", "text", "text"]
    )

    for row in rows:
        plpy.execute(plan, row)

    return f"MONDO SSSOM mappings downloaded successfully from {url}; inserted {len(rows)} rows"

except Exception as e:
    plpy.error(f"Failed to download MONDO SSSOM mappings: {str(e)}")
$function$;


--Helper function and Trigger to be executed to populate the version of MONDO in its source table
CREATE OR REPLACE FUNCTION extract_mondo_version()
RETURNS TRIGGER AS $$
DECLARE
    version_text   text;
    extracted_date text;
BEGIN
    /*
      Primary source:
      $.**.meta.version
      Example:
      http://purl.obolibrary.org/obo/mondo/releases/2026-02-03/mondo.owl
    */
    version_text := jsonb_path_query_first(
        NEW.source_json,
        '$.**.meta.version'
    ) #>> '{}';

    -- Fallback: if the structure changes slightly, search any key named "version".
    IF version_text IS NULL THEN
        version_text := jsonb_path_query_first(
            NEW.source_json,
            '$.**.version'
        ) #>> '{}';
    END IF;

    IF version_text IS NOT NULL THEN
        -- Extract YYYY-MM-DD from the version URL or version string.
        extracted_date := substring(version_text from '\d{4}-\d{2}-\d{2}');
        IF extracted_date IS NOT NULL THEN
            NEW.version := to_date(extracted_date, 'YYYY-MM-DD');
        ELSE
            NEW.version := NULL;
        END IF;
    ELSE
        NEW.version := NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS trg_mondo_version_extraction ON mondo_json;

CREATE TRIGGER trg_mondo_version_extraction
BEFORE INSERT OR UPDATE OF source_json ON mondo_json
FOR EACH ROW
EXECUTE FUNCTION extract_mondo_version();


-- ============================================================================
-- STEP: Populate MONDO JSON table with most recent content
-- Description: Executes the download function to fetch and store the latest
--              MONDO JSON distribution
-- ============================================================================
DO $_$
BEGIN
PERFORM dev_mondo.download_mondo_json_simple();
END $_$;

-- ============================================================================
-- STEP: Populate MONDO sssom mapping table with most recent content
-- Description: Executes the download function to fetch and store the latest
--              MONDO JSON distribution
-- ============================================================================

DO $_$
BEGIN
PERFORM dev_mondo.download_mondo_sssom_maps_simple();
END $_$;
