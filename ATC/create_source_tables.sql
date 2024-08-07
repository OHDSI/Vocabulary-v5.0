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
* Authors: Aliaksei Katyshou
* Date: 2024
**************************************************************************/

DROP TABLE IF EXISTS sources.atc_codes;

CREATE TABLE IF NOT EXISTS sources.atc_codes (
    class_code      VARCHAR(7),
    class_name      VARCHAR(255),
    ddd             VARCHAR(10),
    u               VARCHAR(20),
    adm_r           VARCHAR(20),
    note            VARCHAR(255),
    start_date      DATE,
    revision_date   DATE,
    active          VARCHAR(2),
    replaced_by     VARCHAR(7),
    _atc_ver        VARCHAR(20)
);