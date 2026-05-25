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
* 
* Authors: Aliaksey Katyshou
* Date: 2025
**************************************************************************/

DROP FUNCTION sources.insert_ema_medicines_output_orphan_designations_en(TEXT);

CREATE OR REPLACE FUNCTION sources.insert_ema_medicines_output_orphan_designations_en(file_path TEXT)
RETURNS void AS $BODY$
BEGIN
    INSERT INTO sources.ema_medicines_output_orphan_designations_en 
    SELECT
        TRIM(src.medicine_name),
        TRIM(src.related_ema_product_number),
        TRIM(src.active_substance),
        src.date_of_designation_refusal,
        TRIM(src.intended_use),
        TRIM(src.eu_designation_number),
        TRIM(src.status),
        src.first_published_date,
        src.last_updated_date,
        TRIM(src.orphan_designation_url),
        src.download_ts
    FROM sources.py_xlsparse_ema_medicines_orphan_designations(file_path) src
    WHERE NOT EXISTS (
        SELECT 1
        FROM sources.ema_medicines_output_orphan_designations_en tgt
        WHERE
            tgt.medicine_name = TRIM(src.medicine_name) AND
            tgt.related_ema_product_number = TRIM(src.related_ema_product_number) AND
            tgt.active_substance = TRIM(src.active_substance) AND
            tgt.date_of_designation_refusal = src.date_of_designation_refusal AND
            tgt.intended_use = TRIM(src.intended_use) AND
            tgt.eu_designation_number = TRIM(src.eu_designation_number) AND
            tgt.status = TRIM(src.status) AND
            tgt.first_published_date = src.first_published_date AND
            tgt.last_updated_date = src.last_updated_date AND
            tgt.orphan_designation_url = TRIM(src.orphan_designation_url)
    );
END;
$BODY$ 
LANGUAGE plpgsql;