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
* Authors: Dmitry Dymshyts and Timur Vakhitov
* Date: 2017
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.ISBT_PRODUCT_DESC;
CREATE TABLE SOURCES.ISBT_PRODUCT_DESC
(
   PRODDESCRIPCODE     VARCHAR(10),
   CLASSIDENTIFIER     VARCHAR(5),
   MODIFIERIDENTIFIER  VARCHAR(5),
   PRODDESCRIP0        VARCHAR(4000),
   CODEDATE            DATE,
   PRODDESCRIP1        VARCHAR(4000),
   RETIREDATE          DATE,
   PRODUCTFORMULA      VARCHAR(4000)
);

DROP TABLE IF EXISTS SOURCES.ISBT_CLASSES;
CREATE TABLE SOURCES.ISBT_CLASSES
(
   CLASSIDENTIFIER     VARCHAR(5),
   CLASSNAME           VARCHAR(4000),
   STRUCTUREDNAME      VARCHAR(4000),
   RETIREDATE          VARCHAR(20),
   SUBCATEGORY         INT4
);

DROP TABLE IF EXISTS SOURCES.ISBT_MODIFIERS;
CREATE TABLE SOURCES.ISBT_MODIFIERS
(
   MODIFIERIDENTIFIER  VARCHAR(5),
   MODIFIERNAME        VARCHAR(4000),
   RETIREDATE          VARCHAR(20)
);

DROP TABLE IF EXISTS SOURCES.ISBT_ATTRIBUTE_VALUES;
CREATE TABLE SOURCES.ISBT_ATTRIBUTE_VALUES
(
   UNIQUEATTRFORM      VARCHAR(8),
   ATTRGRP             VARCHAR(5),
   ATTRIBUTETEXT       VARCHAR(4000),
   CORECONDITION       VARCHAR(5),
   ISDEFAULT           VARCHAR(5),
   RETIREDATE          VARCHAR(20)
);

DROP TABLE IF EXISTS SOURCES.ISBT_ATTRIBUTE_GROUPS;
CREATE TABLE SOURCES.ISBT_ATTRIBUTE_GROUPS
(
   GROUPIDENTIFIER     VARCHAR(5),
   GROUPNAME           VARCHAR(4000),
   RETIREDATE          VARCHAR(20),
   CATEGORY            INT4
);

DROP TABLE IF EXISTS SOURCES.ISBT_CATEGORIES;
CREATE TABLE SOURCES.ISBT_CATEGORIES
(
   CATNO               INT4,
   CATEGORY            VARCHAR(4000)
);

DROP TABLE IF EXISTS SOURCES.ISBT_MODIFIER_CATEGORY_MAP;
CREATE TABLE SOURCES.ISBT_MODIFIER_CATEGORY_MAP
(
   MODIFIER            VARCHAR(5),
   CATEGORY            VARCHAR(4000)
);

DROP TABLE IF EXISTS SOURCES.ISBT_VERSION;
CREATE TABLE SOURCES.ISBT_VERSION
(
   VOCABULARY_VERSION  VARCHAR(50),
   VOCABULARY_DATE     DATE
);