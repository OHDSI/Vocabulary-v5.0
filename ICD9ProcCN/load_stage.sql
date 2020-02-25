/**************************************************************************
* Copyright 2016 Observational Health Data Sciences AND Informatics (OHDSI)
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
* Authors: Medical team
* Date: 2020
**************************************************************************/

--1. UPDATE latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ICD9ProcCN',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.icd9proccn_concept LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.icd9proccn_concept LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_ICD9PROCCN'
);
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;
;
--3. Create concept_stage
insert into concept_stage
	(concept_name,domain_id,vocabulary_id,concept_class_id,concept_code,valid_start_date,valid_end_date)
select distinct
	coalesce 
		(
			x2.concept_name,
			x.concept_name,
			c.english_concept_name || ' (automated translation)'
		) as concept_name,
		'Procedure',
		'ICD9ProcCN',
		case c.concept_class_id
			when '六位数扩展码主要编码' then '6-dig billing code'
			when '六位数扩展码附加编码' then '6-dig billing code'
			when '四位数细目编码' then '4-dig billing code'
			when '三位数亚目编码' then '3-dig nonbill code'
			when '二位数类目编码' then '2-dig nonbill code'
			when '章编码' then 'ICD9Proc Hierarchy'
		else 'Undefined'
		end as concept_class_id,
		c.concept_code,
		TO_DATE('19700101', 'YYYYMMDD'),
		TO_DATE('20991231', 'YYYYMMDD')
from sources.icd9proccn_concept c
left join concept x on
	(x.concept_code, x.vocabulary_id) = (c.concept_code, 'ICD9Proc')
left join concept x2 on -- Generic equivalency, 6-dig code = 4-dig code + 00
	(rpad (x2.concept_code,5,'x') || '00', x2.vocabulary_id) = (c.concept_code, 'ICD9Proc')
where c.concept_code != 'Metadata'
;
--4. Create concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT i.concept_code,
	i.concept_name AS synonym_name,
	'ICD9ProcCN' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
FROM concept_stage i

UNION ALL

SELECT i.concept_code,
	i.concept_name AS synonym_name,
	'ICD9ProcCN' AS synonym_vocabulary_id,
	4182948 AS language_concept_id -- Chinese
FROM sources.icd9proccn_concept i
;
--5. Ingest internal hierarchy from source
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT distinct
	c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	'ICD9ProcCN' AS vocabulary_id_1,
	'ICD9ProcCN' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
from sources.icd9proccn_concept_relationship r
join sources.icd9proccn_concept c1 on c1.concept_id = r.concept_id_1
join sources.icd9proccn_concept c2 on c2.concept_id = r.concept_id_2
where 
	r.relationship_id = 'Is a'
;
--6. Map to standard procedures over ICD9Proc
CREATE INDEX IF NOT EXISTS trgm_idx ON concept_stage USING GIN (concept_code devv5.gin_trgm_ops); --for LIKE patterns
ANALYZE concept_stage
;
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
with icd_parents as
(
	select distinct
		c.concept_code,
		first_value (x.concept_id) over
		(
			partition by c.concept_code
			order by length (x.concept_code) desc --longest matching code for best results
		) as concept_id
	from concept_stage c
	join devv5.concept x on
		 c.concept_code !~ '-' and
		 c.concept_class_id != 'ICD9Proc Hierarchy' and
		 x.vocabulary_id = 'ICD9Proc' and
		 ( --allow fuzzy match uphill for this iteration
		 	c.concept_code like x.concept_code || '%' 
		 )
)
select
	i.concept_code,
	c.concept_code,
	'ICD9ProcCN',
	c.vocabulary_id,
	'Maps to',
	TO_DATE('19700101', 'YYYYMMDD'),
	TO_DATE('20991231', 'YYYYMMDD')
from icd_parents i
join concept_relationship r on
	r.relationship_id = 'Maps to' and
	r.concept_id_1 = i.concept_id
join concept c on
	c.concept_id = r.concept_id_2
;
drop index trgm_idx