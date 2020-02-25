
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
* Authors: Timur Vakhitov, Eduard Korchmar, Dmitry Dymshyts
* Date: 2020
**************************************************************************/

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ICD10CN',
	pVocabularyDate			=> TO_DATE('20160101', 'yyyymmdd'),
	pVocabularyVersion		=> '2016 Release',
	pVocabularyDevSchema	=> 'DEV_ICD10CN'
);
END $_$;
/*
TODO:
-Mapping of granular codes
-Mapping of missing Histologies
-Correcting translations
*/
;
truncate concept_stage, concept_relationship_stage,concept_synonym_stage
;
drop table if exists code_clean
;
-- --1.Create list of distinct cleaned codes without brackets from icd10cn_concept
create table code_clean as
select 
	concept_code,
	regexp_replace
		(
			trim (both '()' from replace (concept_code, '*', '')),
			'\(.*$',
			''
		) as concept_code_clean
from sources.icd10cn_concept
where concept_code != 'Metadata'
;
drop table if exists name_source
;
--2. Gather list of names to avoid usage of automatically translated chinese names where possible
create table name_source as
select distinct
--Clean ICD10 names
	o.concept_code_clean,
	'ICD10' as source,
	x.concept_name,
	'S' as preferred,
	4180186 as language_concept_id -- English
from sources.icd10cn_concept c
join code_clean o on
	o.concept_code = c.concept_code
join devv5.concept x on
	x.vocabulary_id = 'ICD10' and
	replace (o.concept_code_clean,'.x00','') = x.concept_code

	union all

select distinct
--Clean ICD10 names for concepts with 00 in end (generic equivalency)
	o.concept_code_clean,
	'ICD10' as source,
	x.concept_name,
	'S' as preferred,
	4180186 as language_concept_id -- English
from sources.icd10cn_concept c
join code_clean o on
	o.concept_code = c.concept_code
join devv5.concept x on
	x.vocabulary_id = 'ICD10' and
	o.concept_code_clean = x.concept_code || '00'

	union all

select distinct
--ICDO3 names: 
/*
	ICD10CN codes modify ICDO3 codes with 5th digit added to morphology.
	If the 5th digit equals 0, than code means the same as ICDO code.
*/
	o.concept_code_clean,
	'ICD03',
	x.concept_name,
	'S' as preferred,
	4180186 as language_concept_id -- English
from sources.icd10cn_concept c
join code_clean o on
	o.concept_code = c.concept_code
join devv5.concept x on
	x.vocabulary_id = 'ICDO3' and
	x.concept_class_id = 'ICDO Histology' and
	o.concept_code_clean ~ '^M\d{4}0\/\d$' and --ICD10CN Morphology codes that may match ICDO codes
--Same Behaviour code
	right (x.concept_code, 1) = right (o.concept_code_clean,1) and
--Same Morphology code
	left (x.concept_code, 4) = left (trim (leading 'M' from o.concept_code_clean), 4)

	union all

--Preserve original names as synonyms
select distinct
	o.concept_code_clean,
	'ICD10CN',
	c.concept_name,
	null,
	4182948 -- Chinese
from sources.icd10cn_concept c
join code_clean o on
	o.concept_code = c.concept_code
;
--If there are no other sources, save Google translation as source
insert into name_source
select distinct
--Pick preferred english synonym
	o.concept_code_clean,
	'Google Translate',
	first_value	(c.english_concept_name) over
		(
			partition by o.concept_code_clean
			order by length (c.english_concept_name) asc
		)
	|| ' (machine translation)',
	'S' as preferred,
	4180186 as language_concept_id -- English
from sources.icd10cn_concept c
join code_clean o on
	o.concept_code = c.concept_code
where
	o.concept_code_clean not in
		(
			select concept_code_clean
			from name_source
			where language_concept_id = 4180186
		)
;
--3. Fill concept_stage with cleaned codes and English names
insert into concept_stage
	(concept_name,domain_id,vocabulary_id,concept_class_id,concept_code,valid_start_date,valid_end_date)
select distinct
	n.concept_name,
	'Undefined',
	'ICD10CN',
	case
		when o.concept_code_clean ~ '[A-Z]\d{2}\.' then 'ICD10 code'
		when o.concept_code_clean ~ '^[A-Z]\d{2}$' then 'ICD10 Hierarchy'
		when o.concept_code_clean ~ '^M\d{5}\/\d$' then 'ICD10 Histology'
		when o.concept_code_clean ~ '-' then 'ICD10 Hierarchy'
		else null --Not supposed to be encountered
	end,
	o.concept_code_clean,
	TO_DATE('20160101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd')
from sources.icd10cn_concept c
join code_clean o on
	o.concept_code = c.concept_code
join name_source n on
	o.concept_code_clean = n.concept_code_clean and
	n.preferred = 'S'
;
--4. Fill table concept_synonym_stage with chinese and English names
insert into concept_synonym_stage
	(synonym_name,synonym_concept_code,synonym_vocabulary_id,language_concept_id)
select
	n.concept_name,
	n.concept_code_clean,
	'ICD10CN',
	n.language_concept_id
from name_source n
;
--5. Fill concept_relationship_stage
-- Preserve ICD10CN internal hierarchy (even if concepts are non-standard)
insert into concept_relationship_stage
	(concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	o1.concept_code_clean,
	o2.concept_code_clean,
	'ICD10CN',
	'ICD10CN',
	'Is a',
	TO_DATE('20160101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd')
from sources.icd10cn_concept_relationship r

join sources.icd10cn_concept c1 on
	r.concept_id_1 = c1.concept_id
join code_clean o1 on
	o1.concept_code = c1.concept_code

join sources.icd10cn_concept c2 on
	r.concept_id_2 = c2.concept_id
join code_clean o2 on
	o2.concept_code = c2.concept_code

where
	r.relationship_id = 'Is a' and
	o1.concept_code_clean != o2.concept_code_clean
;
drop table if exists icd_parents
;
--Find parents among ICD10 and ICDO3 to inherit mapping relationships from
create table icd_parents as
--ICDO3: parents share first 4 digits of morphology and last digit of behaviour
select
	c.concept_code, x2.concept_id
from concept_stage c
join devv5.concept x on --Find right Histology code to translate to Condition
	x.vocabulary_id = 'ICDO3' and
	x.concept_class_id = 'ICDO Histology' and
	c.concept_class_id = 'ICD10 Histology' and
--Same Behaviour code
	right (x.concept_code, 1) = right (c.concept_code,1) and
--Same Morphology code beginning
	left (x.concept_code, 4) = left (trim (leading 'M' from c.concept_code), 4)
join devv5.concept x2 on --Translate to ICDO Condition code to get correct mappings
	x2.vocabulary_id = 'ICDO3' and
	x2.concept_class_id = 'ICDO Condition' and
	x2.concept_code = x.concept_code || '-NULL'

--Commented since we allow fuzzy match uphill for this iteration
-- where substring (c.concept_code from 6 for 1) = '0' --Exact match to ICDO is MXXXX0/X

	union all

select distinct
	c.concept_code,
	first_value (x.concept_id) over
	(
		partition by c.concept_code
		order by length (x.concept_code) desc --Longest matching code for best results
	) as concept_id
from concept_stage c
join devv5.concept x on
	 c.concept_code !~ '-' and
	 c.concept_class_id in ('ICD10 code', 'ICD10 Hierarchy') and
	 x.vocabulary_id = 'ICD10' and
	 ( --Allow fuzzy match uphill for this iteration
	 	c.concept_code like x.concept_code || '%'
	 )
;
--Inherit mappings from targets now
insert into concept_relationship_stage
	(concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date)
select distinct
	i.concept_code,
	c.concept_code,
	'ICD10CN',
	c.vocabulary_id,
	'Maps to',
	TO_DATE('20160101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd')
from icd_parents i
join devv5.concept_relationship r on
	r.invalid_reason is null and
	r.concept_id_1 = i.concept_id and
	r.relationship_id = 'Maps to'
join devv5.concept c on
	c.concept_id = r.concept_id_2
;
--6. Update Domains 
--ICD10 Histologies are always Condition
update concept_stage
set domain_id = 'Condition'
where concept_class_id = 'ICD10 Histology' 
;
--From mapping target
UPDATE concept_stage cs
SET domain_id = i.domain_id
FROM
(
	SELECT DISTINCT cs1.concept_code,
		first_value(c2.domain_id) OVER (
			PARTITION BY cs1.concept_code ORDER BY CASE c2.domain_id
					WHEN 'Condition'
						THEN 1
					WHEN 'Observation'
						THEN 2
					WHEN 'Procedure'
						THEN 3
					WHEN 'Measurement'
						THEN 4
					WHEN 'Device'
						THEN 5
					ELSE 6
					END
			) AS domain_id
	FROM concept_relationship_stage crs
	JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_1
		AND cs1.vocabulary_id = crs.vocabulary_id_1
	JOIN concept c2 ON c2.concept_code = crs.concept_code_2
		AND c2.vocabulary_id = crs.vocabulary_id_2
	WHERE crs.relationship_id = 'Maps to'
		AND crs.invalid_reason IS NULL
) i
WHERE 
	i.concept_code = cs.concept_code and
	cs.domain_id = 'Undefined'
;
--From descendants - for cathegories and groupers
UPDATE concept_stage cs
SET domain_id = i.domain_id
FROM
(
	select
		c1.concept_code,
		first_value (c2.domain_id) OVER 
			(
				PARTITION BY c1.concept_code 
				ORDER BY 
					CASE c2.domain_id
						WHEN 'Condition'
							THEN 1
						WHEN 'Observation'
							THEN 2
						WHEN 'Procedure'
							THEN 3
						WHEN 'Measurement'
							THEN 4
						WHEN 'Device'
							THEN 5
						ELSE 6
					END
			) AS domain_id
	from concept_stage c1 
	join concept_relationship_stage r on
		r.relationship_id = 'Is a' and
		r.concept_code_2 = c1.concept_code
	join concept_stage c2 on
		c2.concept_code = r.concept_code_1
	where c1.domain_id = 'Undefined'
	group by c1.concept_code, c2.domain_id
) i
WHERE 
	i.concept_code = cs.concept_code and
	cs.domain_id = 'Undefined'
;
--Only highest level of hierarchy has Domain still not defined at this point
update concept_stage
set domain_id = 'Observation'
where domain_id = 'Undefined'
;
--7. Add "subsumes" relationship between concepts where the concept_code is like of another
-- Although 'Is a' relations exist, it is done to differentiate between "true" source-provided hierarchy and convenient "jump" links we build now 
CREATE INDEX IF NOT EXISTS trgm_idx ON concept_stage USING GIN (concept_code devv5.gin_trgm_ops); --For LIKE patterns
ANALYZE concept_stage;
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
SELECT c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	c1.vocabulary_id AS vocabulary_id_1,
	c1.vocabulary_id AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	TO_DATE('20160101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage c1,
	concept_stage c2
WHERE c2.concept_code LIKE c1.concept_code || '%'
	AND c1.concept_code <> c2.concept_code
	and 'ICD10 Histology' not in (c1.concept_class_id, c2.concept_class_id) 
	and c1.concept_code !~ '-'
	and c2.concept_code !~ '-'
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage r_int
		WHERE r_int.concept_code_1 = c1.concept_code
			AND r_int.concept_code_2 = c2.concept_code
			AND r_int.relationship_id = 'Subsumes'
		);
--Build same for Hierarchy intervals
drop table if exists intervals
;
create table intervals as
	(
		select distinct
			c.concept_code,
			left (c.concept_code, 3) as start_code,
			right (c.concept_code, 3) as end_code
		from concept_stage c
		where c.concept_code ~ '-'
	)
;
--Intervals that are parts of other intervals
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	'ICD10CN' AS vocabulary_id_1,
	'ICD10CN' AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	TO_DATE('20160101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM intervals c1,
	intervals c2
WHERE 
	c1.start_code <= c2.start_code and
	c1.end_code >= c2.end_code and
	c1.concept_code <> c2.concept_code
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage r_int
		WHERE r_int.concept_code_1 = c1.concept_code
			AND r_int.concept_code_2 = c2.concept_code
			AND r_int.relationship_id = 'Subsumes'
		)
;
--All ICD10 codes as part of intervals
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT
	c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	'ICD10CN' AS vocabulary_id_1,
	'ICD10CN' AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	TO_DATE('20160101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
from intervals c1
join concept_stage c2 on
	left (c2.concept_code, 3) between c1.start_code and c1.end_code
	and c2.concept_class_id != 'ICD10 Histology'
	and c2.concept_code !~ '-'
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage r_int
		WHERE r_int.concept_code_1 = c1.concept_code
			AND r_int.concept_code_2 = c2.concept_code
			AND r_int.relationship_id = 'Subsumes'
		)
;
DROP INDEX trgm_idx;

--8. Cleanup temporary tables
drop table if exists
	code_clean, name_source, icd_parents, intervals