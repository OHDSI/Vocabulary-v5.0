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
* Authors: Vlad Korsik, Aliaksey Katyshou
* Date: 2022
**************************************************************************/
DROP TABLE IF EXISTS sources.ema_medicines_output_medicines_enL;

CREATE TABLE sources.ema_medicines_output_medicines_en (
    category                                            TEXT,
    name_of_medicine                                    TEXT,
    ema_product_number                                  TEXT,
    medicine_status                                     TEXT,
    opinion_status                                      TEXT,
    latest_procedure_affecting_product_information      TEXT,
    international_non_proprietary_name                  TEXT,
    active_substance                                    TEXT,
    therapeutic_area                                    TEXT,
    species_veterinary                                  TEXT,
    patient_safety                                      TEXT,
    atc_code_human                                      TEXT,
    atcvet_code_veterinary                              TEXT,
    pharmacotherapeutic_group_human                     TEXT,
    pharmacotherapeutic_group_veterinary                TEXT,
    therapeutic_indication                              TEXT,
    accelerated_assessment                              TEXT,
    additional_monitoring                               TEXT,
    advanced_therapy                                    TEXT,
    biosimilar                                          TEXT,
    conditional_approval                                TEXT,
    exceptional_circumstances                           TEXT,
    generic_or_hybrid                                   TEXT,
    orphan_medicine                                     TEXT,
    prime_priority_medicine                             TEXT,
    marketing_authorisation_developer_applicant_holder  TEXT,
    european_commission_decision_date                   DATE,
    start_of_rolling_review_date                        DATE,
    start_of_evaluation_date                            DATE,
    opinion_adopted_date                                DATE,
    withdrawal_of_application_date                      DATE,
    marketing_authorisation_date                        DATE,
    refusal_of_marketing_authorisation_date             DATE,
    withdrawal_expiry_revocation_lapse_of_marketing_authorisation_date DATE,
    suspension_of_marketing_authorisation_date          DATE,
    revision_number                                     INTEGER,
    first_published_date                                DATE,
    last_updated_date                                   DATE,
    medicine_url                                        TEXT,
    download_ts                                         TIMESTAMP
);

DROP TABLE IF EXISTS sources.ema_medicines_output_post_authorisation_en;

CREATE TABLE sources.ema_medicines_output_post_authorisation_en
(
    category                                           TEXT,
    name_of_medicine                                   TEXT,
    ema_product_number                                 TEXT,
    active_substance                                   TEXT,
    international_non_proprietary_name                 TEXT,
    therapeutic_area                                   TEXT,
    atc_code_human                                     TEXT,
    atcvet_code_veterinary                             TEXT,
    species_veterinary                                 TEXT,
    accelerated_assessment                             TEXT,
    additional_monitoring                              TEXT,
    advanced_therapy                                   TEXT,
    biosimilar                                         TEXT,
    conditional_approval                               TEXT,
    exceptional_circumstances                          TEXT,
    generic_or_hybrid                                  TEXT,
    orphan_medicine                                    TEXT,
    prime_priority_medicine                            TEXT,
    marketing_authorisation_developer_applicant_holder TEXT,
    post_authorisation_procedure_status                TEXT,
    post_authorisation_opinion_status                  TEXT,
    post_authorisation_opinion_date                    DATE,
    withdrawal_of_application_date                     DATE,
    marketing_authorisation_date                       DATE,
    first_published_date                               DATE,
    last_updated_date                                  DATE,
    medicine_post_authorisation_procedure_url          TEXT,
    download_ts                                        TIMESTAMP
);

DROP TABLE IF EXISTS sources.ema_medicines_output_orphan_designations_en;

CREATE TABLE sources.ema_medicines_output_orphan_designations_en (
    medicine_name               TEXT,
    related_ema_product_number  TEXT,
    active_substance            TEXT,
    date_of_designation_refusal DATE,
    intended_use                TEXT,
    eu_designation_number       TEXT,
    status                      TEXT,
    first_published_date        DATE,
    last_updated_date           DATE,
    orphan_designation_url      TEXT,
    download_ts                 TIMESTAMP
);

DROP TABLE IF EXISTS sources.ema_medicines_output_herbal_medicines_en;

CREATE TABLE sources.ema_medicines_output_herbal_medicines_en (
    latin_name                      TEXT , -- Latin name of the herbal medicine
    combination                     TEXT  , -- Indicates if it is a combination ('Yes' or 'No')
    english_common_name             TEXT, -- English common name of the herbal medicine
    botanical_name                  TEXT, -- Botanical name of the herbal medicine
    therapeutic_area                TEXT, -- Therapeutic area of the herbal medicine
    status                          TEXT, -- Status of the herbal medicine
    outcome_of_european_assessment  TEXT, -- Outcome of the European assessment
    additional_information          TEXT, -- Additional information about the herbal medicine
    date_added_to_inventory         DATE, -- Date the herbal medicine was added to the inventory
    date_added_to_priority_list     DATE, -- Date the herbal medicine was added to the priority list
    first_published_date            DATE, -- Date the herbal medicine was first published
    last_updated_date               DATE, -- Date the herbal medicine was last updated
    herbal_medicine_url             TEXT, -- URL for more information about the herbal medicine
    download_ts                     TIMESTAMP
);