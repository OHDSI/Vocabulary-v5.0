/**************************************************************************
* Copyright 2020 Observational Health Data Sciences and Informatics (OHDSI)
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

-- 1. Vocabulary update routine
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'OncoTree',
	pVocabularyDate			=> TO_DATE ('20201001', 'yyyymmdd'), -- http://oncotree.mskcc.org/
	pVocabularyVersion		=> 'OncoTree version 2020_10_01',
	pVocabularyDevSchema	=> 'DEV_ONCOTREE'
);
END $_$
;
--2. Initial cleanup
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
	(-- need to get the right dates for the first release
		select latest_update
		from vocabulary
		where vocabulary_id = 'OncoTree'
	) as valid_start_date,
	to_date ('20991231','yyyymmdd')
from oncotree o
left join concept c on
	c.vocabulary_id = 'OncoTree' and
	c.concept_code = o.descendant_code
where o.ancestor_code is not null
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
from oncotree
where ancestor_code != 'TISSUE'
;
--5. Process manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;
;
--7. Vocabulary pack procedures
--7.1. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--7.2, Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--7.3. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--7.4. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;
