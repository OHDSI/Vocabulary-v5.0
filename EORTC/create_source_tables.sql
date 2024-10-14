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
* Authors: Vlad Korsik, Maria Rohozhkina, Aliaksei Katyshou
* Date: 2024
**************************************************************************/

DROP TABLE IF EXISTS sources.eortc_questionnaires;
CREATE TABLE sources.eortc_questionnaires (
    id serial4 NOT NULL,
    createdate TIMESTAMP NULL,
    updatedate TIMESTAMP NULL,
    "name" TEXT NULL,
    code TEXT NULL,
    "type" TEXT NULL,
    state TEXT NULL,
    phase INT4 NULL,
    gender TEXT NULL,
    chemical TEXT NULL,
    description TEXT NULL,
    additionalinfo TEXT NULL,
    contact TEXT NULL,
    iscustom BOOL NULL,
    authorid INT4 NULL,
    author TEXT NULL,
    questionsstartposition INT4 NULL,
    vocabulary_date DATE NULL,
    vocabulary_version VARCHAR(200) NULL,
    CONSTRAINT pk_eortc_questionnaires PRIMARY KEY (id)
);

DROP TABLE sources.eortc_questions;
CREATE TABLE sources.eortc_questions (
    id serial4 NOT NULL,
    createdate TIMESTAMP NULL,
    updatedate TIMESTAMP NULL,
    itemid INT4 NULL,
    "position" INT4 NULL,
    wording TEXT NULL,
    "comment" TEXT NULL,
    relatedquestions _int4 NULL,
    questionnaire_id INT4 NULL,
    CONSTRAINT pk_eortc_questions PRIMARY KEY (id)
);

ALTER TABLE sources.eortc_questions 
ADD CONSTRAINT fk_eortc_questions_questionnaire_id
FOREIGN KEY (questionnaire_id) REFERENCES sources.eortc_questionnaires(id);

DROP TABLE sources.eortc_question_items;
CREATE TABLE sources.eortc_question_items (
    id serial4 NOT NULL,
    code TEXT NULL,
    codeprefix TEXT NULL,
    "type" TEXT NULL,
    description TEXT NULL,
    direction TEXT NULL,
    underlyingissue TEXT NULL,
    additionalinfo TEXT NULL,
    conceptdefinition TEXT NULL,
    createdate TIMESTAMP NULL,
    updatedate TIMESTAMP NULL,
    question_id INT4 NULL,
    CONSTRAINT pk_eortc_question_items PRIMARY KEY (id)
);

ALTER TABLE sources.eortc_question_items 
ADD CONSTRAINT fk_eortc_question_items_question_id 
FOREIGN KEY (question_id) REFERENCES sources.eortc_questions(id);

DROP TABLE sources.eortc_languages;
CREATE TABLE sources.eortc_languages (
    code TEXT NOT NULL,
    "name" TEXT NULL,
    CONSTRAINT pk_eortc_languages PRIMARY KEY (code)
);

DROP TABLE sources.eortc_recommended_wordings;
CREATE TABLE sources.eortc_recommended_wordings (
    id serial4 NOT NULL,
    item INT4 NULL,
    "language" TEXT NULL,
    wording TEXT NULL,
    createdate TIMESTAMP NULL,
    updatedate TIMESTAMP NULL,
    language_code TEXT NULL,
    CONSTRAINT pk_eortc_recommended_wordings PRIMARY KEY (id)
);

ALTER TABLE sources.eortc_recommended_wordings 
ADD CONSTRAINT fk_eortc_recommended_wordings_item
FOREIGN KEY (item) REFERENCES sources.eortc_question_items(id);
