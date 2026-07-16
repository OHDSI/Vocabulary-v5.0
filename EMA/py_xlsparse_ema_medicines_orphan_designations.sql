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

DROP FUNCTION sources.py_xlsparse_ema_medicines_orphan_designations(varchar);

CREATE OR REPLACE FUNCTION sources.py_xlsparse_ema_medicines_orphan_designations(xls_path character varying)
 RETURNS TABLE(medicine_name text, related_ema_product_number text, active_substance text, date_of_designation_refusal date, intended_use text, eu_designation_number text, status text, first_published_date date, last_updated_date date, orphan_designation_url text, download_ts timestamp without time zone)
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
    MEDICINE_NAME = row[0].value if row[0].value else None
    RELATED_EMA_PRODUCT_NUMBER = row[1].value if row[1].value else None
    ACTIVE_SUBSTANCE = row[2].value if row[2].value else None
    DATE_OF_DESIGNATION_REFUSAL = parse_date(row[3].value)
    INTENDED_USE = row[4].value if row[4].value else None
    EU_DESIGNATION_NUMBER = row[5].value if row[5].value else None
    STATUS = row[6].value if row[6].value else None
    FIRST_PUBLISHED_DATE = parse_date(row[7].value)
    LAST_UPDATED_DATE = parse_date(row[8].value)
    ORPHAN_DESIGNATION_URL = row[9].value if row[9].value else None
    DOWNLOAD_TS = datetime.now()

    res.append((
        MEDICINE_NAME, RELATED_EMA_PRODUCT_NUMBER, ACTIVE_SUBSTANCE, DATE_OF_DESIGNATION_REFUSAL,
        INTENDED_USE, EU_DESIGNATION_NUMBER, STATUS, FIRST_PUBLISHED_DATE, LAST_UPDATED_DATE,
        ORPHAN_DESIGNATION_URL, DOWNLOAD_TS
    ))

return res
$BODY$
LANGUAGE plpython3u STRICT;
