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
* Authors: Medical Team
* Date: 2022
**************************************************************************/
DROP TABLE GENOMIC_CGI_SOURCE;
CREATE TABLE GENOMIC_CGI_SOURCE
(
    gene           VARCHAR(255),
    gdna           VARCHAR(255),
    protein        VARCHAR(255),
    transcript     VARCHAR(255),
    info           TEXT,
    context        VARCHAR(255),
    cancer_acronym VARCHAR(255),
    source         VARCHAR(255),
    reference      TEXT
);
