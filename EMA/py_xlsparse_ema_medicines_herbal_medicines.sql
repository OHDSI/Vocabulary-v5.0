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

DROP FUNCTION sources.py_xlsparse_ema_medicines_herbal_medicines(varchar);

CREATE OR REPLACE FUNCTION sources.py_xlsparse_ema_medicines_herbal_medicines(xls_path character varying)
 RETURNS TABLE(latin_name text, combination text, english_common_name text, botanical_name text, therapeutic_area text, status text, outcome_of_european_assessment text, additional_information text, date_added_to_inventory date, date_added_to_priority_list date, first_published_date date, last_updated_date date, herbal_medicine_url text, download_ts timestamp without time zone)
AS $BODY$
from openpyxl import load_workbook
from datetime import datetime

wb = load_workbook(xls_path, data_only=True)
sheet = wb.worksheets[0]

res = []

def parse_date(date_value):
    if date_value is None:
        return None
    if isinstance(date_value, str):
        try:
            return datetime.strptime(date_value, '%d/%m/%Y').date()
        except ValueError:
            return None
    return date_value

for row in sheet.iter_rows(min_row=10):
    LATIN_NAME = row[0].value if row[0].value else None
    COMBINATION = row[1].value if row[1].value else None
    ENGLISH_COMMON_NAME = row[2].value if row[2].value else None
    BOTANICAL_NAME = row[3].value if row[3].value else None
    THERAPEUTIC_AREA = row[4].value if row[4].value else None
    STATUS = row[5].value if row[5].value else None
    OUTCOME_OF_EUROPEAN_ASSESSMENT = row[6].value if row[6].value else None
    ADDITIONAL_INFORMATION = row[7].value if row[7].value else None
    DATE_ADDED_TO_INVENTORY = parse_date(row[8].value)
    DATE_ADDED_TO_PRIORITY_LIST = parse_date(row[9].value)
    FIRST_PUBLISHED_DATE = parse_date(row[10].value)
    LAST_UPDATED_DATE = parse_date(row[11].value)
    HERBAL_MEDICINE_URL = row[12].value if row[12].value else None
    DOWNLOAD_TS = datetime.now()

    res.append((
        LATIN_NAME, COMBINATION, ENGLISH_COMMON_NAME, BOTANICAL_NAME, THERAPEUTIC_AREA,
        STATUS, OUTCOME_OF_EUROPEAN_ASSESSMENT, ADDITIONAL_INFORMATION, DATE_ADDED_TO_INVENTORY,
        DATE_ADDED_TO_PRIORITY_LIST, FIRST_PUBLISHED_DATE, LAST_UPDATED_DATE, HERBAL_MEDICINE_URL,
        DOWNLOAD_TS
    ))

return res
$BODY$
LANGUAGE plpython3u STRICT;
