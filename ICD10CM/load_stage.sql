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

-- 1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ICD10CM',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.icd10cm LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.icd10cm LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_ICD10CM'
);
END $_$;


DROP TABLE IF EXISTS sn_attr_test;
CREATE UNLOGGED TABLE sn_attr_test (n text);

SELECT table_schema
FROM information_schema.tables
WHERE table_name = 'sn_attr_test';

ANALYZE sn_attr_test;