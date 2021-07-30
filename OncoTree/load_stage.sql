/**************************************************************************
* Copyright 2021 Observational Health Data Sciences and Informatics (OHDSI)
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
* Authors: Timur Vakhitov, Dmitry Dymshyts, Eduard Korchmar
* Date: 2021
**************************************************************************/

--1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'OncoTree',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.oncotree_tree LIMIT 1), 
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.oncotree_tree LIMIT 1), 
	pVocabularyDevSchema	=> 'DEV_ONCOTREE'
);
END $_$
;
--2. Truncate all working tables
truncate table concept_stage, concept_relationship_stage, concept_synonym_stage, drug_strength_stage, pack_content_stage
;
--3. Fill concept_stage with concepts
insert into concept_stage (concept_name,domain_id,vocabulary_id,concept_class_id,concept_code,valid_start_date,valid_end_date)
select
	o.descendant_name,
	'Condition',
	'OncoTree',
	'Condition',
	o.descendant_code,
/*	(
		select latest_update
		from vocabulary
		where vocabulary_id = 'OncoTree'
	) */ -- remove comments in the next release when we get the actual dates, while there's totally new release we treat all concepts as created sometimes in a past ('19700101')
		to_date ('19700101','yyyymmdd')
as valid_start_date,
	to_date ('20991231','yyyymmdd')
from sources.oncotree_tree o
;
--4. Put internal hierarchy in concept_relationship_stage
insert into concept_relationship_stage (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select
	descendant_code,
	ancestor_code,
	'OncoTree',
	'OncoTree',
	'Is a',
	to_date ('19700101','yyyymmdd'),
	to_date ('20991231','yyyymmdd')
from sources.oncotree_tree 
where ancestor_code is not null
;
--5. Process manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;
;
--6. Vocabulary pack procedures
--6.1, Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--6.2. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;
