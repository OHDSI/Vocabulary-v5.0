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
* Authors: Timur Vakhitov
* Date: 2021
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.F_LOOKUP2,SOURCES.F_INGREDIENT2,SOURCES.F_VTM2,SOURCES.F_VMP2,SOURCES.F_AMP2,SOURCES.F_VMPP2,SOURCES.F_AMPP2,SOURCES.DMDBONUS,SOURCES.F_HISTORY;
CREATE TABLE SOURCES.F_LOOKUP2 (xmlfield XML, vocabulary_date DATE, vocabulary_version VARCHAR (200));
CREATE TABLE SOURCES.F_INGREDIENT2 (xmlfield XML);
CREATE TABLE SOURCES.F_VTM2 (xmlfield XML);
CREATE TABLE SOURCES.F_VMP2 (xmlfield XML);
CREATE TABLE SOURCES.F_VMPP2 (xmlfield XML);
CREATE TABLE SOURCES.F_AMP2 (xmlfield XML);
CREATE TABLE SOURCES.F_AMPP2 (xmlfield XML);
CREATE TABLE SOURCES.DMDBONUS (xmlfield XML);
CREATE TABLE SOURCES.F_HISTORY (xmlfield XML);