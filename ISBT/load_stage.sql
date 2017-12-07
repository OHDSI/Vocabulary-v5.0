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
BEGIN
	DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName		=> 'ISBT',
										  pVocabularyDate		=> TO_DATE ('20171110', 'yyyymmdd'),
										  pVocabularyVersion	=> '7.9.0',
										  pVocabularyDevSchema	=> 'DEV_ISBT');
	DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName		=> 'ISBT Attributes',
										  pVocabularyDate		=> TO_DATE ('20171110', 'yyyymmdd'),
										  pVocabularyVersion	=> '7.9.0',
										  pVocabularyDevSchema	=> 'DEV_ISBT',
										  pAppendVocabulary		=> TRUE);
END;
COMMIT;

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
	TO_DATE(codedate, 'DD-MON-YYYY') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM isbt_product_desc
UNION ALL
-- Classes
SELECT classname AS concept_name,
	'Device' AS domain_id,
	'ISBT Attributes' AS vocabulary_id,
	'ISBT Class' concept_class_id,
	'C' AS standard_concept,
	classidentifier AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM isbt_classes
UNION ALL
--Modifiers
SELECT COALESCE(modifiername,'-') AS concept_name,
	'Observation' AS domain_id,
	'ISBT Attributes' AS vocabulary_id,
	'ISBT Modifier' concept_class_id,
	'C' AS standard_concept,
	modifieridentifier AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM isbt_modifiers
UNION ALL
--Attribute values
SELECT attributetext AS concept_name,
	'Observation' AS domain_id,
	'ISBT Attributes' AS vocabulary_id,
	'ISBT Attrib value' concept_class_id,
	'C' AS standard_concept,
	uniqueattrform AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM isbt_attribute_values
UNION ALL
--Attribute groups
SELECT groupname AS concept_name,
	'Observation' AS domain_id,
	'ISBT Attributes' AS vocabulary_id,
	'ISBT Attrib group' concept_class_id,
	'C' AS standard_concept,
	groupidentifier AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM isbt_attribute_groups
UNION ALL
--Categories
SELECT category AS concept_name,
	'Observation' AS domain_id,
	'ISBT Attributes' AS vocabulary_id,
	'ISBT Category' concept_class_id,
	'C' AS standard_concept,
	TO_CHAR(catno) AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM isbt_categories;

COMMIT;

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
	l.concept_code_2,
	'ISBT' AS vocabulary_id_1,
	'ISBT Attributes' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM isbt_product_desc,
	LATERAL(SELECT regexp_substr(productformula, '[^-]+', 1, LEVEL) AS concept_code_2 FROM dual connect BY regexp_substr(productformula, '[^-]+', 1, LEVEL) IS NOT NULL) l
UNION ALL
--Level 2
SELECT modifier AS concept_code_1,
	TO_CHAR(category) AS concept_code_2,
	'ISBT Attributes' AS vocabulary_id_1,
	'ISBT Attributes' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM isbt_modifier_category_map
UNION ALL
SELECT uniqueattrform AS concept_code_1,
	attrgrp AS concept_code_2,
	'ISBT Attributes' AS vocabulary_id_1,
	'ISBT Attributes' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM isbt_attribute_values
UNION ALL
--Level 3
SELECT groupidentifier AS concept_code_1,
	TO_CHAR(category) AS concept_code_2,
	'ISBT Attributes' AS vocabulary_id_1,
	'ISBT Attributes' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM isbt_attribute_groups;

COMMIT;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script