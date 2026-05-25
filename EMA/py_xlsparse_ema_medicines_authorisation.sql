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

DROP FUNCTION sources.py_xlsparse_ema_medicines_authorisation(varchar);

CREATE OR REPLACE FUNCTION sources.py_xlsparse_ema_medicines_authorisation(xls_path character varying)
 RETURNS TABLE(category text, name_of_medicine text, ema_product_number text, active_substance text, international_non_proprietary_name text, therapeutic_area text, atc_code_human text, atcvet_code_veterinary text, species_veterinary text, accelerated_assessment text, additional_monitoring text, advanced_therapy text, biosimilar text, conditional_approval text, exceptional_circumstances text, generic_or_hybrid text, orphan_medicine text, prime_priority_medicine text, marketing_authorisation_developer_applicant_holder text, post_authorisation_procedure_status text, post_authorisation_opinion_status text, post_authorisation_opinion_date date, withdrawal_of_application_date date, marketing_authorisation_date date, first_published_date date, last_updated_date date, medicine_post_authorisation_procedure_url text, download_ts timestamp without time zone)
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
    CATEGORY = row[0].value if row[0].value else None
    NAME_OF_MEDICINE = row[1].value if row[1].value else None
    EMA_PRODUCT_NUMBER = row[2].value if row[2].value else None
    ACTIVE_SUBSTANCE = row[3].value if row[3].value else None
    INTERNATIONAL_NON_PROPRIETARY_NAME = row[4].value if row[4].value else None
    THERAPEUTIC_AREA = row[5].value if row[5].value else None
    ATC_CODE_HUMAN = row[6].value if row[6].value else None
    ATCVET_CODE_VETERINARY = row[7].value if row[7].value else None
    SPECIES_VETERINARY = row[8].value if row[8].value else None
    ACCELERATED_ASSESSMENT = row[9].value if row[9].value else None
    ADDITIONAL_MONITORING = row[10].value if row[10].value else None
    ADVANCED_THERAPY = row[11].value if row[11].value else None
    BIOSIMILAR = row[12].value if row[12].value else None
    CONDITIONAL_APPROVAL = row[13].value if row[13].value else None
    EXCEPTIONAL_CIRCUMSTANCES = row[14].value if row[14].value else None
    GENERIC_OR_HYBRID = row[15].value if row[15].value else None
    ORPHAN_MEDICINE = row[16].value if row[16].value else None
    PRIME_PRIORITY_MEDICINE = row[17].value if row[17].value else None
    MARKETING_AUTHORISATION_DEVELOPER_APPLICANT_HOLDER = row[18].value if row[18].value else None
    POST_AUTHORISATION_PROCEDURE_STATUS = row[19].value if row[19].value else None
    POST_AUTHORISATION_OPINION_STATUS = row[20].value if row[20].value else None
    POST_AUTHORISATION_OPINION_DATE = parse_date(row[21].value)
    WITHDRAWAL_OF_APPLICATION_DATE = parse_date(row[22].value)
    MARKETING_AUTHORISATION_DATE = parse_date(row[23].value)
    FIRST_PUBLISHED_DATE = parse_date(row[24].value)
    LAST_UPDATED_DATE = parse_date(row[25].value)
    MEDICINE_POST_AUTHORISATION_PROCEDURE_URL = row[26].value if row[26].value else None
    DOWNLOAD_TS = datetime.now()

    res.append((
        CATEGORY, NAME_OF_MEDICINE, EMA_PRODUCT_NUMBER, ACTIVE_SUBSTANCE, INTERNATIONAL_NON_PROPRIETARY_NAME,
        THERAPEUTIC_AREA, ATC_CODE_HUMAN, ATCVET_CODE_VETERINARY, SPECIES_VETERINARY, ACCELERATED_ASSESSMENT,
        ADDITIONAL_MONITORING, ADVANCED_THERAPY, BIOSIMILAR, CONDITIONAL_APPROVAL, EXCEPTIONAL_CIRCUMSTANCES,
        GENERIC_OR_HYBRID, ORPHAN_MEDICINE, PRIME_PRIORITY_MEDICINE, MARKETING_AUTHORISATION_DEVELOPER_APPLICANT_HOLDER,
        POST_AUTHORISATION_PROCEDURE_STATUS, POST_AUTHORISATION_OPINION_STATUS, POST_AUTHORISATION_OPINION_DATE,
        WITHDRAWAL_OF_APPLICATION_DATE, MARKETING_AUTHORISATION_DATE, FIRST_PUBLISHED_DATE, LAST_UPDATED_DATE,
        MEDICINE_POST_AUTHORISATION_PROCEDURE_URL, DOWNLOAD_TS
    ))

return res
$BODY$
LANGUAGE plpython3u STRICT;
