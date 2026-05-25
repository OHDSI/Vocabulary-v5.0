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

DROP FUNCTION sources.py_xlsparse_ema_medicines(varchar);

CREATE OR REPLACE FUNCTION sources.py_xlsparse_ema_medicines(xls_path character varying)
 RETURNS TABLE(category text, name_of_medicine text, ema_product_number text, medicine_status text, opinion_status text, latest_procedure_affecting_product_information text, international_non_proprietary_name text, active_substance text, therapeutic_area text, species_veterinary text, patient_safety text, atc_code_human text, atcvet_code_veterinary text, pharmacotherapeutic_group_human text, pharmacotherapeutic_group_veterinary text, therapeutic_indication text, accelerated_assessment text, additional_monitoring text, advanced_therapy text, biosimilar text, conditional_approval text, exceptional_circumstances text, generic_or_hybrid text, orphan_medicine text, prime_priority_medicine text, marketing_authorisation_developer_applicant_holder text, european_commission_decision_date date, start_of_rolling_review_date date, start_of_evaluation_date date, opinion_adopted_date date, withdrawal_of_application_date date, marketing_authorisation_date date, refusal_of_marketing_authorisation_date date, withdrawal_expiry_revocation_lapse_of_marketing_authorisation_d date, suspension_of_marketing_authorisation_date date, revision_number integer, first_published_date date, last_updated_date date, medicine_url text, download_ts timestamp without time zone)
AS $BODY$
from openpyxl import load_workbook
from datetime import datetime


wb = load_workbook(xls_path, data_only=True)
sheet = wb.worksheets[0]

res = []

for row in sheet.iter_rows(min_row=10):
    CATEGORY = row[0].value if row[0].value else None
    NAME_OF_MEDICINE = row[1].value if row[1].value else None
    EMA_PRODUCT_NUMBER = row[2].value if row[2].value else None
    MEDICINE_STATUS = row[3].value if row[3].value else None
    OPINION_STATUS = row[4].value if row[4].value else None
    LATEST_PROCEDURE_AFFECTING_PRODUCT_INFORMATION = row[5].value if row[5].value else None
    INTERNATIONAL_NON_PROPRIETARY_NAME = row[6].value if row[6].value else None
    ACTIVE_SUBSTANCE = row[7].value if row[7].value else None
    THERAPEUTIC_AREA = row[8].value if row[8].value else None
    SPECIES_VETERINARY = row[9].value if row[9].value else None
    PATIENT_SAFETY = row[10].value if row[10].value else None
    ATC_CODE_HUMAN = row[11].value if row[11].value else None
    ATCVET_CODE_VETERINARY = row[12].value if row[12].value else None
    PHARMACOTHERAPEUTIC_GROUP_HUMAN = row[13].value if row[13].value else None
    PHARMACOTHERAPEUTIC_GROUP_VETERINARY = row[14].value if row[14].value else None
    THERAPEUTIC_INDICATION = row[15].value if row[15].value else None
    ACCELERATED_ASSESSMENT = row[16].value if row[16].value else None
    ADDITIONAL_MONITORING = row[17].value if row[17].value else None
    ADVANCED_THERAPY = row[18].value if row[18].value else None
    BIOSIMILAR = row[19].value if row[19].value else None
    CONDITIONAL_APPROVAL = row[20].value if row[20].value else None
    EXCEPTIONAL_CIRCUMSTANCES = row[21].value if row[21].value else None
    GENERIC_OR_HYBRID = row[22].value if row[22].value else None
    ORPHAN_MEDICINE = row[23].value if row[23].value else None
    PRIME_PRIORITY_MEDICINE = row[24].value if row[24].value else None
    MARKETING_AUTHORISATION_DEVELOPER_APPLICANT_HOLDER = row[25].value if row[25].value else None
    EUROPEAN_COMMISSION_DECISION_DATE = row[26].value if row[26].value else None
    START_OF_ROLLING_REVIEW_DATE = row[27].value if row[27].value else None
    START_OF_EVALUATION_DATE = row[28].value if row[28].value else None
    OPINION_ADOPTED_DATE = row[29].value if row[29].value else None
    WITHDRAWAL_OF_APPLICATION_DATE = row[30].value if row[30].value else None
    MARKETING_AUTHORISATION_DATE = row[31].value if row[31].value else None
    REFUSAL_OF_MARKETING_AUTHORISATION_DATE = row[32].value if row[32].value else None
    WITHDRAWAL_EXPIRY_REVOCATION_LAPSE_OF_MARKETING_AUTHORISATION_DATE = row[33].value if row[33].value else None
    SUSPENSION_OF_MARKETING_AUTHORISATION_DATE = row[34].value if row[34].value else None
    REVISION_NUMBER = row[35].value if row[35].value else None
    FIRST_PUBLISHED_DATE = row[36].value if row[36].value else None
    LAST_UPDATED_DATE = row[37].value if row[37].value else None
    MEDICINE_URL = row[38].value if row[38].value else None
    DOWNLOAD_TS = datetime.now()

    res.append((
        CATEGORY, NAME_OF_MEDICINE, EMA_PRODUCT_NUMBER, MEDICINE_STATUS, OPINION_STATUS,
        LATEST_PROCEDURE_AFFECTING_PRODUCT_INFORMATION, INTERNATIONAL_NON_PROPRIETARY_NAME,
        ACTIVE_SUBSTANCE, THERAPEUTIC_AREA, SPECIES_VETERINARY, PATIENT_SAFETY, ATC_CODE_HUMAN,
        ATCVET_CODE_VETERINARY, PHARMACOTHERAPEUTIC_GROUP_HUMAN, PHARMACOTHERAPEUTIC_GROUP_VETERINARY,
        THERAPEUTIC_INDICATION, ACCELERATED_ASSESSMENT, ADDITIONAL_MONITORING, ADVANCED_THERAPY,
        BIOSIMILAR, CONDITIONAL_APPROVAL, EXCEPTIONAL_CIRCUMSTANCES, GENERIC_OR_HYBRID,
        ORPHAN_MEDICINE, PRIME_PRIORITY_MEDICINE, MARKETING_AUTHORISATION_DEVELOPER_APPLICANT_HOLDER,
        EUROPEAN_COMMISSION_DECISION_DATE, START_OF_ROLLING_REVIEW_DATE, START_OF_EVALUATION_DATE,
        OPINION_ADOPTED_DATE, WITHDRAWAL_OF_APPLICATION_DATE, MARKETING_AUTHORISATION_DATE,
        REFUSAL_OF_MARKETING_AUTHORISATION_DATE, WITHDRAWAL_EXPIRY_REVOCATION_LAPSE_OF_MARKETING_AUTHORISATION_DATE,
        SUSPENSION_OF_MARKETING_AUTHORISATION_DATE, REVISION_NUMBER, FIRST_PUBLISHED_DATE,
        LAST_UPDATED_DATE, MEDICINE_URL, DOWNLOAD_TS
    ))

return res
$BODY$
LANGUAGE plpython3u STRICT;
