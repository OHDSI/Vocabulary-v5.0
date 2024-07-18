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
* Date: 2024
**************************************************************************/

DROP TABLE IF EXISTS DEV_EORTC.EORTC_QUESTIONNAIRES ;
CREATE TABLE DEV_EORTC.EORTC_QUESTIONNAIRES 
(
additionalinfo	text,
author	text,
authorid	integer,
chemical	text,
code	text,
contact	text,
createdate	timestamp without time zone,
description	text,
gender	text,
id	integer,
iscustom	boolean,
name	text,
phase	integer,
questionsstartposition	integer,
state	text,
type	text,
updatedate	timestamp without time zone
);

DROP TABLE IF EXISTS DEV_EORTC.eortc_question_items ;
CREATE TABLE DEV_EORTC.eortc_question_items
(
id	integer,
question_id	integer,
additionalinfo	text,
code	text,
codeprefix	text,
conceptdefinition	text,
description	text,
direction	text,
type	text,
underlyingissue	text,
createdate	timestamp without time zone,
updatedate	timestamp without time zone
);

DROP TABLE IF EXISTS DEV_EORTC.eortc_languages ;
CREATE TABLE DEV_EORTC.eortc_languages
(
code	text,
name	text
);

DROP TABLE IF EXISTS DEV_EORTC.eortc_questions;
CREATE TABLE DEV_EORTC.eortc_questions
(
comment	text,
createdate	timestamp without time zone,
id	integer,
itemid	integer,
position	integer,
questionnaire_id	integer,
relatedquestions	integer[],
updatedate	timestamp without time zone,
wording	text
);

DROP TABLE IF EXISTS DEV_EORTC.eortc_recommended_wordings ;
CREATE TABLE DEV_EORTC.eortc_recommended_wordings
(
createdate	timestamp without time zone,
id	integer,
item	integer,
language	text,
language_code	text,
updatedate	timestamp without time zone,
wording	text
);
