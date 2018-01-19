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

CREATE TABLE ISBT_PRODUCT_DESC
(
   PRODDESCRIPCODE     VARCHAR2(10),
   CLASSIDENTIFIER     VARCHAR2(5),
   MODIFIERIDENTIFIER  VARCHAR2(5),
   PRODDESCRIP0        VARCHAR2(4000),
   CODEDATE            DATE,
   PRODDESCRIP1        VARCHAR2(4000),
   RETIREDATE          DATE,
   PRODUCTFORMULA      VARCHAR2(4000)
);

CREATE TABLE ISBT_CLASSES
(
   CLASSIDENTIFIER     VARCHAR2(5),
   CLASSNAME           VARCHAR2(4000),
   STRUCTUREDNAME      VARCHAR2(4000),
   RETIREDATE          VARCHAR2(20),
   SUBCATEGORY         NUMBER
);

CREATE TABLE ISBT_MODIFIERS
(
   MODIFIERIDENTIFIER  VARCHAR2(5),
   MODIFIERNAME        VARCHAR2(4000),
   RETIREDATE          VARCHAR2(20)
);

CREATE TABLE ISBT_ATTRIBUTE_VALUES
(
   UNIQUEATTRFORM      VARCHAR2(8),
   ATTRGRP             VARCHAR2(5),
   ATTRIBUTETEXT       VARCHAR2(4000),
   CORECONDITION       VARCHAR2(5),
   ISDEFAULT           VARCHAR2(5),
   RETIREDATE          VARCHAR2(20)
);

CREATE TABLE ISBT_ATTRIBUTE_GROUPS
(
   GROUPIDENTIFIER     VARCHAR2(5),
   GROUPNAME           VARCHAR2(4000),
   RETIREDATE          VARCHAR2(20),
   CATEGORY            NUMBER
);

CREATE TABLE ISBT_CATEGORIES
(
   CATNO               NUMBER,
   CATEGORY            VARCHAR2(4000)
);

CREATE TABLE ISBT_MODIFIER_CATEGORY_MAP
(
   MODIFIER            VARCHAR2(5),
   CATEGORY            VARCHAR2(4000)
);