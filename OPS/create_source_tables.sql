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
* Authors: Eduard Korchmar, Michael Kallfelz
* Date: 20179-2021
**************************************************************************/

DROP TABLE IF EXISTS dev_ops.ops_src_agg CASCADE;

CREATE TABLE dev_ops.ops_src_agg
(
   code        varchar,
   label_de    varchar,
   superclass  varchar,
   modifiedby  varchar,
   year        integer
);

DROP TABLE IF EXISTS dev_ops.ops_mod_src CASCADE;

CREATE TABLE dev_ops.ops_mod_src
(
   modifier    varchar,
   code        varchar,
   label_de    varchar,
   superclass  varchar,
   year        integer
);
