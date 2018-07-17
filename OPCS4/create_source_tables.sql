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
* Authors: Timur Vakhitov, Christian Reich
* Date: 2017
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.OPCS;
CREATE TABLE SOURCES.OPCS
(
    CUI                  VARCHAR (50),
    TERM                 VARCHAR (150),
    VOCABULARY_DATE      DATE,
    VOCABULARY_VERSION   VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.OPCSSCTMAP;
CREATE TABLE SOURCES.OPCSSCTMAP
(
    SCUI     VARCHAR (5),
    STUI     VARCHAR (1),
    TCUI     VARCHAR (18),
    TTUI     VARCHAR (1),
    MAPTYP   VARCHAR (1),
    ASSURED  VARCHAR (1)
);