
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
* Authors:  Dmitry Dymshyts, Denys Kaduk,Timur Vakhitov, Christian Reich
* Date: 2019
**************************************************************************/

-- 1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'MedDRA',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.hlt_pref_comp LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.hlt_pref_comp LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_MEDDRA'
);
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Insert into concept_stage
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	domain_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT soc_name AS concept_name,
	'MedDRA' AS vocabulary_id,
	NULL AS domain_id,
	'SOC' AS concept_class_id,
	'C' AS standard_concept,
	soc_code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MedDRA'
		),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM SOURCES.soc_term

UNION ALL

SELECT hlgt_name AS concept_name,
	'MedDRA' AS vocabulary_id,
	NULL AS domain_id,
	'HLGT' AS concept_class_id,
	'C' AS standard_concept,
	hlgt_code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MedDRA'
		),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM SOURCES.hlgt_pref_term

UNION ALL

SELECT hlt_name AS concept_name,
	'MedDRA' AS vocabulary_id,
	NULL AS domain_id,
	'HLT' AS concept_class_id,
	'C' AS standard_concept,
	hlt_code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MedDRA'
		),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM SOURCES.hlt_pref_term

UNION ALL

SELECT pt_name AS concept_name,
	'MedDRA' AS vocabulary_id,
	NULL AS domain_id,
	'PT' AS concept_class_id,
	'C' AS standard_concept,
	pt_code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MedDRA'
		),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM SOURCES.pref_term

UNION ALL

SELECT llt_name AS concept_name,
	'MedDRA' AS vocabulary_id,
	NULL AS domain_id,
	'LLT' AS concept_class_id,
	'C' AS standard_concept,
	llt_code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MedDRA'
		),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM SOURCES.low_level_term
WHERE llt_currency = 'Y'
	AND llt_code <> pt_code;

--4. Update domain_id
drop table t_domains
;
create table t_domains as
--LLT level 
 select   llt_code as concept_code,
case 
--pt level
when pt_name ~* 'monitoring|centesis|imaging|screen' then 'Procedure'
 
--hlt level
when hlt_name ~* 'exposures|Physical examination procedures and organ system status' then 'Observation'
when hlt_name ~* 'histopathology|imaging|procedure' then 'Procedure'
when hlt_name = 'Acquired gene mutations and other alterations' then 'Measurement'
--hlgt level
when hlgt_name = 'Therapeutic and nontherapeutic effects (excl toxicity)'  then 'Observation'
--soc level
when soc_name ~ 'disorders|Infections|Neoplasms|Injury, poisoning and procedural complications|Pregnancy, puerperium and perinatal conditions' then  'Condition'
when soc_name ~ 'Surgical and medical procedures' then 'Procedure'
when soc_name in ('Product issues', 'Social circumstances') then 'Observation'
when soc_name = 'Investigations' then 'Measurement'

else 'Undefined' end
 as domain_id

 from SOURCES.md_hierarchy h 
join SOURCES.low_level_term l on l.pt_code = h.pt_code and llt_currency ='Y' 
where primary_soc_fg='Y'

union

-- pt level
  select   pt_code as concept_code,
case 
--pt level
when pt_name ~* 'monitoring|centesis|imaging|screen' then 'Procedure'
 
--hlt level
when hlt_name ~* 'exposures|Physical examination procedures and organ system status' then 'Observation'
when hlt_name ~* 'histopathology|imaging|procedure' then 'Procedure'
when hlt_name = 'Acquired gene mutations and other alterations' then 'Measurement'

--hlgt level
when hlgt_name = 'Therapeutic and nontherapeutic effects (excl toxicity)' then 'Observation'
--soc level
when soc_name ~ 'disorders|Infections|Neoplasms|Injury, poisoning and procedural complications|Pregnancy, puerperium and perinatal conditions' then  'Condition'
when soc_name ~ 'Surgical and medical procedures' then 'Procedure'
when soc_name in ('Product issues', 'Social circumstances') then 'Observation'
when soc_name = 'Investigations' then 'Measurement'

else 'Undefined' end
 as domain_id

 from SOURCES.md_hierarchy h
where primary_soc_fg='Y'

union 
--hlt level
  select  hlt_code as concept_code, 
case 

--hlt level
when hlt_name ~* 'exposures|Physical examination procedures and organ system status' then 'Observation'
when hlt_name ~* 'histopathology|imaging|procedure' then 'Procedure'
when hlt_name = 'Acquired gene mutations and other alterations' then 'Measurement'

--hlgt level
when hlgt_name = 'Therapeutic and nontherapeutic effects (excl toxicity)' then 'Observation'
--soc level
when soc_name ~ 'disorders|Infections|Neoplasms|Injury, poisoning and procedural complications|Pregnancy, puerperium and perinatal conditions' then  'Condition'
when soc_name ~ 'Surgical and medical procedures' then 'Procedure'
when soc_name in ('Product issues', 'Social circumstances') then 'Observation'
when soc_name = 'Investigations' then 'Measurement'

else 'Undefined' end
 as domain_id

 from SOURCES.md_hierarchy h
where primary_soc_fg='Y'

union 
--hlgt level
  select  hlgt_code as concept_code, 
case 
--hlgt level
when hlgt_name = 'Therapeutic and nontherapeutic effects (excl toxicity)' then 'Observation'
--soc level
when soc_name ~ 'disorders|Infections|Neoplasms|Injury, poisoning and procedural complications|Pregnancy, puerperium and perinatal conditions' then  'Condition'
when soc_name ~ 'Surgical and medical procedures' then 'Procedure'
when soc_name in ('Product issues', 'Social circumstances') then 'Observation'
when soc_name = 'Investigations' then 'Measurement'

else 'Undefined' end
 as domain_id

 from SOURCES.md_hierarchy h

where primary_soc_fg='Y'
 
union 
--soc level
  select  soc_code as concept_code, 
case 
--soc level
when soc_name ~ 'disorders|Infections|Neoplasms|Injury, poisoning and procedural complications|Pregnancy, puerperium and perinatal conditions' then  'Condition'
when soc_name ~ 'Surgical and medical procedures' then 'Procedure'
when soc_name in ('Product issues', 'Social circumstances') then 'Observation'
when soc_name = 'Investigations' then 'Measurement'

else 'Undefined' end
 as domain_id

 from SOURCES.md_hierarchy h

where primary_soc_fg='Y'

			;
UPDATE concept_stage cs
SET domain_id = t.domain_id
FROM t_domains t
WHERE cs.concept_code = t.concept_code::VARCHAR
;

--discovered that there are concepts missing from t_domains because their primary_soc_fg = 'N'
--empirically discovered that their domain = 'Condition'

UPDATE concept_stage cs
SET domain_id = 'Condition'
where domain_id is null
;

--5. Create internal hierarchical relationships
INSERT INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT soc_code AS concept_code_1,
          hlgt_code AS concept_code_2,
          'MedDRA' AS vocabulary_id_1,
          'MedDRA' AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM SOURCES.soc_hlgt_comp
   UNION ALL
   SELECT hlgt_code AS concept_code_1,
          hlt_code AS concept_code_2,
          'MedDRA' AS vocabulary_id_1,
          'MedDRA' AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM SOURCES.hlgt_hlt_comp
   UNION ALL
   SELECT hlt_code AS concept_code_1,
          pt_code AS concept_code_2,
          'MedDRA' AS vocabulary_id_1,
          'MedDRA' AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM SOURCES.hlt_pref_comp
   UNION ALL
   SELECT pt_code AS concept_code_1,
          llt_code AS concept_code_2,
          'MedDRA' AS vocabulary_id_1,
          'MedDRA' AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'MedDRA'),
          TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
          NULL
     FROM SOURCES.low_level_term
    WHERE llt_currency = 'Y' AND llt_code <> pt_code;

--6. Copy existing relationships
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
SELECT DISTINCT c1.concept_code AS concept_code_1, --use distinct for SMQ: one concept_code but different concept_ids
	c2.concept_code AS concept_code_2,
	c1.vocabulary_id AS vocabulary_id_1,
	c2.vocabulary_id AS vocabulary_id_2,
	r.relationship_id AS relationship_id,
	r.valid_start_date AS valid_start_date,
	r.valid_end_date AS valid_end_date,
	r.invalid_reason AS invalid_reason
FROM concept_relationship r,
	concept c1,
	concept c2
WHERE c1.concept_id = r.concept_id_1
	AND c2.concept_id = r.concept_id_2
	AND r.relationship_id IN (
		'MedDRA - SNOMED eq',
		'MedDRA - SMQ',
		'MedDRA - ICD9CM'
		);

--7. Create a relationship file for the Medical Coder
/*
SELECT c.concept_code,
	c.concept_name,
	c.domain_id,
	c.concept_class_id,
	c1.concept_code concept_code_snomed
FROM concept_stage c
LEFT JOIN concept_relationship_stage r ON c.concept_code = r.concept_code_1
	AND r.relationship_id = 'MedDRA - SNOMED eq'
LEFT JOIN concept c1 ON c1.concept_code = r.concept_code_2
	AND c1.vocabulary_id = 'SNOMED';
*/

--8. Append result to concept_relationship_stage table
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--9. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--10. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--11. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--12. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script

