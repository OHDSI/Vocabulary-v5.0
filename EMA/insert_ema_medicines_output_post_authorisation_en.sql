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

DROP FUNCTION sources.insert_ema_medicines_output_post_authorisation_en(TEXT);

CREATE OR REPLACE FUNCTION sources.insert_ema_medicines_output_post_authorisation_en(file_path TEXT)
RETURNS void AS $BODY$
BEGIN
    INSERT INTO sources.ema_medicines_output_post_authorisation_en
    SELECT 
        TRIM(t.category),
        TRIM(t.name_of_medicine),
        TRIM(t.ema_product_number),
        TRIM(t.active_substance),
        TRIM(t.international_non_proprietary_name),
        TRIM(t.therapeutic_area),
        TRIM(t.atc_code_human),
        TRIM(t.atcvet_code_veterinary),
        TRIM(t.species_veterinary),
        TRIM(t.accelerated_assessment),
        TRIM(t.additional_monitoring),
        TRIM(t.advanced_therapy),
        TRIM(t.biosimilar),
        TRIM(t.conditional_approval),
        TRIM(t.exceptional_circumstances),
        TRIM(t.generic_or_hybrid),
        TRIM(t.orphan_medicine),
        TRIM(t.prime_priority_medicine),
        TRIM(t.marketing_authorisation_developer_applicant_holder),
        TRIM(t.post_authorisation_procedure_status),
        TRIM(t.post_authorisation_opinion_status),
        t.post_authorisation_opinion_date,
        t.withdrawal_of_application_date,
        t.marketing_authorisation_date,
        t.first_published_date,
        t.last_updated_date,
        TRIM(t.medicine_post_authorisation_procedure_url),
        t.download_ts
    FROM sources.py_xlsparse_ema_medicines_authorisation(file_path) t
    WHERE NOT EXISTS (
        SELECT 1
        FROM sources.ema_medicines_output_post_authorisation_en tgt
        WHERE
            tgt.category = TRIM(t.category) AND
            tgt.name_of_medicine = TRIM(t.name_of_medicine) AND
            tgt.ema_product_number = TRIM(t.ema_product_number) AND
            tgt.active_substance = TRIM(t.active_substance) AND
            tgt.international_non_proprietary_name = TRIM(t.international_non_proprietary_name) AND
            tgt.therapeutic_area = TRIM(t.therapeutic_area) AND
            tgt.atc_code_human = TRIM(t.atc_code_human) AND
            tgt.atcvet_code_veterinary = TRIM(t.atcvet_code_veterinary) AND
            tgt.species_veterinary = TRIM(t.species_veterinary) AND
            tgt.accelerated_assessment = TRIM(t.accelerated_assessment) AND
            tgt.additional_monitoring = TRIM(t.additional_monitoring) AND
            tgt.advanced_therapy = TRIM(t.advanced_therapy) AND
            tgt.biosimilar = TRIM(t.biosimilar) AND
            tgt.conditional_approval = TRIM(t.conditional_approval) AND
            tgt.exceptional_circumstances = TRIM(t.exceptional_circumstances) AND
            tgt.generic_or_hybrid = TRIM(t.generic_or_hybrid) AND
            tgt.orphan_medicine = TRIM(t.orphan_medicine) AND
            tgt.prime_priority_medicine = TRIM(t.prime_priority_medicine) AND
            tgt.marketing_authorisation_developer_applicant_holder = TRIM(t.marketing_authorisation_developer_applicant_holder) AND
            tgt.post_authorisation_procedure_status = TRIM(t.post_authorisation_procedure_status) AND
            tgt.post_authorisation_opinion_status = TRIM(t.post_authorisation_opinion_status) AND
            tgt.post_authorisation_opinion_date = t.post_authorisation_opinion_date AND
            tgt.withdrawal_of_application_date = t.withdrawal_of_application_date AND
            tgt.marketing_authorisation_date = t.marketing_authorisation_date AND
            tgt.first_published_date = t.first_published_date AND
            tgt.last_updated_date = t.last_updated_date AND
            tgt.medicine_post_authorisation_procedure_url = TRIM(t.medicine_post_authorisation_procedure_url)
    );
END;
$BODY$ 
LANGUAGE plpgsql;   