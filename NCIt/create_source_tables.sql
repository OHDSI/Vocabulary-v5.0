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


DROP TABLE IF EXISTS dev_nci.ajcc8_permissible_chapter_to_morphocode;
--upload from csv
CREATE TABLE dev_nci.ajcc8_permissible_chapter_to_morphocode
(
    ChapterCode	varchar(255),
    ChapterDescription	 	varchar(255),
    MorphoCode	varchar(255),
    MorphoDescription varchar(255)
)
WITH OIDS
;

--upload from csv
DROP TABLE IF EXISTS dev_nci.ajcc8_permissible_chapter_to_topocode;
CREATE TABLE dev_nci.ajcc8_permissible_chapter_to_topocode
(
    ChapterCode	varchar(255),
    ChapterDescription	 	varchar(255),
    TopoCode	varchar(255),
    TopoDescription varchar(255)
)
WITH OIDS
;
