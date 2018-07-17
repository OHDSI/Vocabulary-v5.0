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

--1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ISBT',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.isbt_version LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.isbt_version LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_ISBT'
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ISBT Attribute',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.isbt_version LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.isbt_version LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_ISBT',
	pAppendVocabulary		=> TRUE
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Load concepts into concept_stage
-- ProductDesciptionCodes
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT proddescrip0 AS concept_name,
	'Device' AS domain_id,
	'ISBT' AS vocabulary_id,
	'ISBT Product' concept_class_id,
	'S' AS standard_concept,
	proddescripcode AS concept_code,
	codedate AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.isbt_product_desc
UNION ALL
-- Classes
SELECT classname AS concept_name,
	'Device' AS domain_id,
	'ISBT Attribute' AS vocabulary_id,
	'ISBT Class' concept_class_id,
	'C' AS standard_concept,
	classidentifier AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.isbt_classes
UNION ALL
--Modifiers
SELECT COALESCE(NULLIF(modifiername, ''), '-') AS concept_name,
	'Observation' AS domain_id,
	'ISBT Attribute' AS vocabulary_id,
	'ISBT Modifier' concept_class_id,
	'C' AS standard_concept,
	modifieridentifier AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.isbt_modifiers
UNION ALL
--Attribute values
SELECT attributetext AS concept_name,
	'Observation' AS domain_id,
	'ISBT Attribute' AS vocabulary_id,
	'ISBT Attrib value' concept_class_id,
	'C' AS standard_concept,
	uniqueattrform AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.isbt_attribute_values
UNION ALL
--Attribute groups
SELECT groupname AS concept_name,
	'Observation' AS domain_id,
	'ISBT Attribute' AS vocabulary_id,
	'ISBT Attrib group' concept_class_id,
	'C' AS standard_concept,
	groupidentifier AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.isbt_attribute_groups
UNION ALL
--Categories
SELECT category AS concept_name,
	'Observation' AS domain_id,
	'ISBT Attribute' AS vocabulary_id,
	'ISBT Category' concept_class_id,
	'C' AS standard_concept,
	catno::text AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.isbt_categories;

--4. Load concept_relationship_stage
--Level 1
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT proddescripcode AS concept_code_1,
	UNNEST(regexp_matches(productformula, '[^-]+', 'g')) as concept_code_2,
	'ISBT' AS vocabulary_id_1,
	'ISBT Attribute' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.isbt_product_desc
UNION ALL
--Level 2
SELECT modifier AS concept_code_1,
	category::text AS concept_code_2,
	'ISBT Attribute' AS vocabulary_id_1,
	'ISBT Attribute' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.isbt_modifier_category_map
UNION ALL
SELECT uniqueattrform AS concept_code_1,
	attrgrp AS concept_code_2,
	'ISBT Attribute' AS vocabulary_id_1,
	'ISBT Attribute' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.isbt_attribute_values
UNION ALL
--Level 3
SELECT groupidentifier AS concept_code_1,
	category::text AS concept_code_2,
	'ISBT Attribute' AS vocabulary_id_1,
	'ISBT Attribute' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.isbt_attribute_groups;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script