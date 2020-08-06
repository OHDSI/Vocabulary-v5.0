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
* Authors: Alexander Davydov, Oleg Zhuk
* Date: 2020
**************************************************************************/

CREATE TABLE schema
(
    schema_id int,
    name varchar(50),
    descript varchar(255),
    notes varchar(1000)
);

CREATE TABLE encoding
(
    encoding_id int,
    title varchar(255),
    availability int,
    coded_as int,
    structure int,
    num_members varchar(1000),
    descript varchar(1000)
);

CREATE TABLE category
(
    category_id int,
    title varchar(255),
    availability varchar(255),
    group_type varchar(255),
    descript varchar(5000),
    notes varchar(5000)
);

CREATE TABLE ehierint
(
  encoding_id int,
  code_id	int,
  parent_id int,
  value int,
  meaning varchar(255),
  selectable int,
  showcase_order int
);

CREATE TABLE ehierstring
(
  encoding_id int,
  code_id	int,
  parent_id int,
  value varchar(255),
  meaning varchar(255),
  selectable int,
  showcase_order int
);

CREATE TABLE esimpstring
(
  encoding_id int,
  value	varchar(50),
  meaning varchar(255),
  showcase_order varchar(255)
);

CREATE TABLE esimpreal
(
encoding_id int,
value varchar(20),
meaning varchar(255),
showcase_order int
);

CREATE TABLE esimpint
(
encoding_id int,
value varchar(20),
meaning varchar(255),
showcase_order int
);

CREATE TABLE esimpdate
(
encoding_id int,
value varchar(20),
meaning varchar(255),
showcase_order int
);

CREATE TABLE field
(
    field_id int,
    title varchar(255),
    availability int,
    stability int,
    private int,
    value_type int,
    base_type int,
    item_type int,
    strata varchar(255),
    instanced int,
    arrayed int,
    sexed int,
    units varchar(255),
    main_category int,
    encoding_id int,
    instance_id int,
    instance_min varchar(255),
    instance_max varchar(255),
    array_min varchar(255),
    array_max varchar(255),
    notes varchar(5000),
    debut varchar(255),
    version varchar(255),
    num_participants int,
    item_count int,
    showcase_order varchar(50)
);

CREATE TABLE fieldsum
(
    field_id int,
    title varchar(2550),
    item_type int
);

CREATE TABLE instances
(
instance_id int,
descript varchar(3000),
num_members int
);

CREATE TABLE insvalue
(
    instance_id	int,
    index int,
    title varchar(255),
    descript varchar(1000)
);

CREATE TABLE recommended
(
    category_id	int,
    field_id int
);

CREATE TABLE returns
(
    archive_id int,
    application_id int,
    title text,
    availability int,
    personal int,
    notes text
);

CREATE TABLE coding_showcase
(
    coding int,
    value varchar(50),
    meaning varchar(1000)
);

CREATE TABLE catbrowse
(
    parent_id int,
    child_id int,
    showcase_order int
);