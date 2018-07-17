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

DROP TABLE IF EXISTS SOURCES.FY_TABLE_5;
CREATE TABLE SOURCES.FY_TABLE_5
(
    DRG_CODE         VARCHAR (3),
    filler_column1   VARCHAR (4000),
    filler_column2   VARCHAR (4000),
    filler_column3   VARCHAR (4000),
    filler_column4   VARCHAR (4000),
    DRG_NAME         VARCHAR (4000),
    filler_column5   VARCHAR (4000),
    filler_column6   VARCHAR (4000),
    filler_column7   VARCHAR (4000),
    filler_column8   VARCHAR (4000),
    filler_column9   VARCHAR (4000),
    VOCABULARY_DATE  DATE
);