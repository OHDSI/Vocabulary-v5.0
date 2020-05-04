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
* Date: 2020
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.CAP_ALLXMLFILELIST;
CREATE TABLE SOURCES.CAP_ALLXMLFILELIST
(
    XML_PATH            VARCHAR(100)
);

DROP TABLE IF EXISTS SOURCES.CAP_XML_RAW;
CREATE TABLE SOURCES.CAP_XML_RAW(
    XMLFIELD            TEXT,
    VOCABULARY_DATE     DATE,
    VOCABULARY_VERSION  VARCHAR (200)
);
