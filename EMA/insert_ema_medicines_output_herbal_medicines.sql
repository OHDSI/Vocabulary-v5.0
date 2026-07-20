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

DROP FUNCTION sources.insert_ema_medicines_output_herbal_medicines(TEXT);

CREATE OR REPLACE FUNCTION sources.insert_ema_medicines_output_herbal_medicines(file_path TEXT)
RETURNS void AS $BODY$
BEGIN
    INSERT INTO sources.ema_medicines_output_herbal_medicines_en
    SELECT
        TRIM(src.latin_name),
        TRIM(src.combination),
        TRIM(src.english_common_name),
        TRIM(src.botanical_name),
        TRIM(src.therapeutic_area),
        TRIM(src.status),
        TRIM(src.outcome_of_european_assessment),
        TRIM(src.additional_information),
        src.date_added_to_inventory,
        src.date_added_to_priority_list,
        src.first_published_date,
        src.last_updated_date, 
        TRIM(src.herbal_medicine_url),
        src.download_ts
    FROM sources.py_xlsparse_ema_medicines_herbal_medicines(file_path) AS src
    WHERE NOT EXISTS (
        SELECT 1
        FROM sources.ema_medicines_output_herbal_medicines_en AS tgt
        WHERE
            tgt.latin_name = TRIM(src.latin_name) AND
            tgt.combination = TRIM(src.combination) AND
            tgt.english_common_name = TRIM(src.english_common_name) AND
            tgt.botanical_name = TRIM(src.botanical_name) AND
            tgt.therapeutic_area = TRIM(src.therapeutic_area) AND
            tgt.status = TRIM(src.status) AND
            tgt.outcome_of_european_assessment = TRIM(src.outcome_of_european_assessment) AND
            tgt.additional_information = TRIM(src.additional_information) AND
            tgt.date_added_to_inventory = src.date_added_to_inventory AND
            tgt.date_added_to_priority_list = src.date_added_to_priority_list AND
            tgt.first_published_date = src.first_published_date AND
            tgt.last_updated_date = src.last_updated_date AND
            tgt.herbal_medicine_url = TRIM(src.herbal_medicine_url)
    );
END;
$BODY$ 
LANGUAGE plpgsql;