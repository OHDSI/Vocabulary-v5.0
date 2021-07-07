/**************************************************************************
* Copyright 2016 Observational Health Data Sciences AND Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may NOT use this file except IN compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to IN writing, software
* distributed under the License is distributed ON an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* Authors: Anna Ostropolets, Polina Talapova, Timur Vakhitov
* Date: Jul 2021
**************************************************************************/
-- Update latest_UPDATE field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ATC',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyDevSchema	        => 'DEV_ATC'
);
END $_$;

-- Truncate all working tables AND remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

-- Add ATC codes using concept_manual (processed inside function below)
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--Add manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--5. Manual synonyms
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualSynonyms();
END $_$;

-- Add 1) crosslinks 'SNOMED - ATC eq' between SNOMED drugs and higher ATC classes (not 5th) and 2) internal 'Is a' relationships using mrconso
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
-- crosslinks between SNOMED Drug Class AND ATC Classes (not ATC 5th)
SELECT DISTINCT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'SNOMED - ATC eq' AS relationship_id,
	'SNOMED' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	d.valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept d
JOIN sources.rxnconso r ON r.code = d.concept_code
	AND r.sab = 'SNOMEDCT_US'
	AND r.code != 'NOCODE'
JOIN sources.rxnconso r2 ON r.rxcui = r2.rxcui
	AND r2.sab = 'ATC'
	AND r2.code != 'NOCODE'
JOIN concept_manual e ON r2.code = e.concept_code
	AND e.concept_class_id != 'ATC 5th' -- Ingredients only to RxNorm
	AND e.vocabulary_id = 'ACT'
WHERE d.vocabulary_id = 'SNOMED'
	AND d.invalid_reason IS NULL
UNION ALL
-- Hierarchy inside ATC
SELECT uppr.concept_code AS concept_code_1,
	lowr.concept_code AS concept_code_2,
	'Is a' AS relationship_id,
	'ATC' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	v.latest_UPDATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage uppr,
	concept_stage lowr,
	vocabulary v
WHERE uppr.invalid_reason is null AND lowr.invalid_reason is null -- to exclude deprecated or updated from the hierarchy
AND (
(LENGTH(uppr.concept_code) IN (4,5) AND lowr.concept_code = SUBSTR(uppr.concept_code,1,LENGTH(uppr.concept_code) - 1)) 
OR (LENGTH(uppr.concept_code) IN (3,7) AND lowr.concept_code = SUBSTR(uppr.concept_code,1,LENGTH(uppr.concept_code) - 2))
)
	AND uppr.vocabulary_id = 'ATC'
	AND lowr.vocabulary_id = 'ATC'
	AND v.vocabulary_id = 'ATC'; --6493

-- Add new 'ATC - RxNorm' links between ATC classes and RxN/RxE using class_to_drug table 
INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
SELECT DISTINCT cs.class_code AS concept_code_1,
       c.concept_code AS concept_code_2,
       'ATC' AS vocabulary_id_1,
       c.vocabulary_id AS vocabulary_id_2,
       'ATC - RxNorm' AS relationship_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM class_to_drug cs
--manual source table
  JOIN concept c ON c.concept_id = cs.concept_id
WHERE NOT EXISTS (SELECT 1
                  FROM concept_relationship_stage crs
                  WHERE crs.concept_code_1 = cs.class_code
                  AND   crs.vocabulary_id_1 = 'ATC'
                  AND   crs.concept_code_2 = c.concept_code
                  AND   crs.vocabulary_id_2 = c.vocabulary_id
                  AND   crs.relationship_id = 'ATC - RxNorm')
AND   c.concept_class_id != 'Ingredient'
AND   (cs.class_code,c.concept_code) NOT IN (SELECT concept_code_1,
                                               concept_code_2
                                        FROM concept_relationship_stage);

-- Add 'ATC - RxNorm pr lat' relationships indicating Primary unambiguous links between an ATC class and RxN/RxE drug using input tables and ambiguous_class_ingredient_tst
INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
with t1 as (
SELECT DISTINCT SUBSTRING(irs.concept_code_1,'\w+') AS concept_code_1,
       c.concept_code AS concept_code_2,
       'ATC' AS vocabulary_id_1,
       c.vocabulary_id AS vocabulary_id_2,
       'ATC - RxNorm pr lat' AS relationship_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','YYYYMMDD') AS valid_end_date,
       NULL AS invalid_reason
FROM internal_relationship_stage irs
  JOIN relationship_to_concept rtc ON irs.concept_code_2 = rtc.concept_code_1
  JOIN concept c
    ON concept_id_2 = c.concept_id
   AND c.concept_class_id = 'Ingredient'
WHERE 
  NOT EXISTS (SELECT 1
FROM dev_combo t
WHERE lower(t.concept_name) = lower(rtc.concept_code_1)
AND   t.class_code = SUBSTRING(irs.concept_code_1,'\w+')
AND   t.rnk in (2,3,4)
))
select * from t1 
where (concept_code_1, concept_code_2) NOT IN (SELECT concept_code_1,
                                               concept_code_2
                                        FROM concept_relationship_stage);

-- Add more  'ATC - RxNorm pr lat' relationships indicating Primary unambiguous links between an ATC class and RxN/RxE drug using rtc and ambiguous_class_ingredient_tst
INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
SELECT DISTINCT class_code AS concept_code_1,
       c.concept_code AS concept_code_2,
       'ATC' AS vocabulary_id_1,
       c.vocabulary_id AS vocabulary_id_2,
       'ATC - RxNorm pr lat' AS relationship_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','YYYYMMDD') AS valid_end_date,
       NULL AS invalid_reason
FROM dev_combo a
  JOIN relationship_to_concept rtc
    ON lower(a.concept_name) = lower(rtc.concept_code_1)
   AND rnk = 1
  JOIN concept c
    ON concept_id_2 = c.concept_id
   AND c.concept_class_id = 'Ingredient'
WHERE 
 (class_code,concept_code,'ATC - RxNorm pr lat') NOT IN (SELECT concept_code_1,
       concept_code_2,
       relationship_id
FROM concept_relationship_stage) AND class_name != 'combinations'
; -- 1

--select * from concept_relationship_stage where concept_code_1 = 'N02AA59';

-- add  'ATC - RxNorm sec lat'  relationships indicating Secondary unambiguous links between an ATC class and RxN/RxE drug using rtc and ambiguous_class_ingredient_tst
INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
SELECT DISTINCT class_code AS concept_code_1,
       c.concept_code AS concept_code_2,
       'ATC' AS vocabulary_id_1,
       c.vocabulary_id AS vocabulary_id_2,
       'ATC - RxNorm sec lat' AS relationship_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','YYYYMMDD') AS valid_end_date,
       NULL AS invalid_reason
FROM dev_combo a
  JOIN relationship_to_concept rtc
    ON lower(a.concept_name) = lower(rtc.concept_code_1)
   AND rnk = 2
  JOIN concept c
    ON concept_id_2 = c.concept_id
   AND c.concept_class_id = 'Ingredient'
WHERE 
 (class_code,concept_code) NOT IN (SELECT concept_code_1,
       concept_code_2
FROM concept_relationship_stage) 
AND (class_code,
     concept_code) NOT IN (SELECT concept_code_1,concept_code_2 FROM concept_relationship_stage); -- 381 (171 (9817 (2755)_ )
    
-- add  'ATC - RxNorm pr up' relationships meaning Primary ambiguous links between an ATC class and RxN/RxE drug using rtc and ambiguous_class_ingredient_tst
INSERT INTO concept_relationship_stage
  (concept_code_1,
   concept_code_2,
   vocabulary_id_1,
   vocabulary_id_2,
   relationship_id,
   valid_start_date,
   valid_end_date,
   invalid_reason
   )
SELECT DISTINCT class_code AS concept_code_1,
       c.concept_code AS concept_code_2,
       'ATC' AS vocabulary_id_1,
       c.vocabulary_id AS vocabulary_id_2,
       'ATC - RxNorm pr up' AS relationship_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','YYYYMMDD') AS valid_end_date,
       NULL AS invalid_reason
FROM dev_combo a
  JOIN relationship_to_concept rtc
    ON lower (a.concept_name) = lower (rtc.concept_code_1)
   AND rnk = 3
  JOIN concept c
    ON concept_id_2 = c.concept_id
   AND c.concept_class_id = 'Ingredient'
WHERE (class_code,concept_code) NOT IN (SELECT concept_code_1,
                                               concept_code_2
                                        FROM concept_relationship_stage); -- 3382

-- add 'ATC - RxNorm sec up' relationships indicating Secondary ambiguous links between ATC classes and RxN/RxE drugs using rtc and ambiguous_class_ingredient_tst
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
SELECT DISTINCT class_code AS concept_code_1,
       c.concept_code AS concept_code_2,
       'ATC' AS vocabulary_id_1,
       c.vocabulary_id AS vocabulary_id_2,
       'ATC - RxNorm sec up' AS relationship_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','YYYYMMDD') AS valid_end_date,
       NULL AS invalid_reason
FROM dev_combo a
  JOIN relationship_to_concept rtc ON lower(a.concept_name) = lower(rtc.concept_code_1)
  JOIN concept c
    ON concept_id_2 = c.concept_id
   AND c.concept_class_id = 'Ingredient'
WHERE 
a.rnk = 4
AND   (class_code,concept_code) NOT IN (SELECT concept_code_1,
                                               concept_code_2
                                        FROM concept_relationship_stage); -- 7881

--  add 'ATC - RxNorm sec up' relationships for 'x, combinations' 
INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
WITH main_ing AS
(
  SELECT class_code,class_name,
         concept_id_2
  FROM class_to_drug c
    JOIN internal_relationship_stage i ON c.class_code = SUBSTRING (i.concept_code_1,'\w+')
    JOIN relationship_to_concept rtc ON rtc.concept_code_1 = i.concept_code_2
  WHERE (class_name ~ '(, combinations)'
  AND NOT class_name ~ '\ywith|and thiazides|and other diuretics')
  OR class_name ~ '(in combination with other drugs)'  -- gives errors INC07BB52 AND C07CB53 if removed
) 
SELECT DISTINCT class_code AS concept_code_1,
       cc.concept_code AS concept_code_2,
       'ATC' AS vocabulary_id_1,
       cc.vocabulary_id AS vocabulary_id_2,
       'ATC - RxNorm sec up' AS relationship_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','YYYYMMDD') AS valid_end_date,
       NULL AS invalid_reason
FROM class_to_drug c
  JOIN devv5.concept_ancestor ON descendant_concept_id = c.concept_id
  JOIN concept cc
    ON cc.concept_id = ancestor_concept_id
   AND cc.standard_concept = 'S'
   AND cc.concept_class_id = 'Ingredient'
   AND cc.vocabulary_id LIKE 'Rx%'
WHERE  (c.class_code,cc.concept_id) NOT IN (SELECT class_code, concept_id_2 FROM main_ing)
AND   (class_code,cc.concept_code) NOT IN (SELECT concept_code_1,
                                                  concept_code_2
                                           FROM concept_relationship_stage)
AND ((class_name ~ '(, combinations)'  AND NOT class_name ~ '\ywith|and thiazides|and other diuretics')
OR class_name ~ '(in combination with other drugs)')
;-- 336

-- deprecate links between ATC classes and dead RxN/RxE (should we kill links from updated ATC to RxN/RxE?)
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
SELECT c.concept_code AS concept_code_1,
       cc.concept_code AS concept_code_2,
       c.vocabulary_id AS vocabulary_id_1,
       cc.vocabulary_id AS vocabulary_id_2,
       relationship_id AS relationship_id,
       cr.valid_start_date AS valid_start_date,
       CURRENT_DATE AS valid_end_date,
       'D' AS invalid_reason
FROM concept_relationship cr
  JOIN concept c ON concept_id_1 = c.concept_id
  JOIN concept cc ON concept_id_2 = cc.concept_id
AND cc.standard_concept is null -- non-standard
WHERE c.vocabulary_id = 'ATC'
AND   cc.vocabulary_id LIKE 'RxNorm%'
AND   relationship_id ~ 'ATC - RxNorm' -- to cover all types of ATC links
AND   cr.invalid_reason IS NULL
AND   (c.concept_code,relationship_id,cc.concept_code) NOT IN (
SELECT concept_code_1,
       relationship_id,
       concept_code_2
FROM concept_relationship_stage)                                                               
; -- 4994 (245) => 239 => 254

-- add 'Maps to' for 'ATC - RxNorm pr lat' for monocomponent ATC classes which do not have doubling Standard ingredients (1-to-many mapping is permissive only for real combo ATC classes)
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
SELECT DISTINCT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       'Maps to',
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM (
SELECT *, count(concept_code_2) OVER (PARTITION BY concept_code_1) AS cnt
FROM concept_relationship_stage
WHERE relationship_id IN ('ATC - RxNorm pr lat')
and invalid_reason IS NULL
 -- exclude Maps to CVX
  ) a
WHERE cnt = 1-- can be just one  , old version  - cnt<25
and (concept_code_1,  'Maps to')
      NOT IN (SELECT concept_code_1, relationship_id FROM concept_relationship_stage); -- 4608

-- more than one
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
with t1 as (
SELECT distinct a.*, count(concept_code_2) OVER (PARTITION BY concept_code_1) AS cnt
FROM concept_relationship_stage a
JOIN atc_one_to_many_excl b on b.atc_code = a.concept_code_1
JOIN concept c on c.concept_code = a.concept_code_2 and c.vocabulary_id = a.vocabulary_id_2 and c.standard_concept = 'S'
and b.concept_code <> a.concept_code_2
WHERE a.relationship_id IN ('ATC - RxNorm pr lat')
and a.invalid_reason IS NULL)
      select DISTINCT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       'Maps to',
       valid_start_date,
       valid_end_date,
       invalid_reason from t1 where concept_code_1 in (select concept_code_1 from t1 group by concept_code_1 having count (1)=1)
       and (concept_code_1,  'Maps to') NOT IN (SELECT concept_code_1, relationship_id FROM concept_relationship_stage)
        ; -- 66	

-- add 'Maps to' to Standard Ingredients for polycomponent ATC classes having 'ATC - RxNorm sec lat' 
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
	with t1 as (
SELECT *, count(concept_code_2) OVER (PARTITION BY concept_code_1) AS cnt
FROM concept_relationship_stage
WHERE relationship_id IN('ATC - RxNorm sec lat') -- 'Maps to', 'Drug class of drug',
and invalid_reason IS NULL
)
select distinct  a.concept_code_1,
--b.class_name,
       a.concept_code_2,
 --      c.concept_name,
       a.vocabulary_id_1,
       a.vocabulary_id_2,
       'Maps to',
       a.valid_start_date,
       a.valid_end_date,
       a.invalid_reason  from t1 a 
join class_drugs_scraper  b on a.concept_code_1 = b.class_code
join concept c on c.concept_code = a.concept_code_2 and c.vocabulary_id = a.vocabulary_id_2
where class_name !~ 'thiazides|agents|combinations'
and cnt<10
and (b.class_code, c.concept_id) not in (select atc_code, concept_id from atc_one_to_many_excl)
and concept_code_2 not in ('OMOP995053','142141','4100', '117466')
AND (concept_code_1||concept_code_2) not in ('G03FA10'||'4083')
and (concept_code_1, vocabulary_id_1, 'Maps to', concept_code_2,vocabulary_id_2)
      NOT IN (SELECT concept_code_1, vocabulary_id_1, relationship_id, concept_code_2,vocabulary_id_2 FROM concept_relationship_stage);-- 448

-- Add synonyms to concept_synonym stage for each of the rxcui/code combinations in atc_tmp_table (can we concept_synonym manual?)
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT dv.concept_code AS synonym_concept_code,
	SUBSTR(r.str, 1, 1000) AS synonym_name,
	dv.vocabulary_id AS synonym_vocabulary_id,
	4180186 AS language_concept_id
FROM concept_manual dv
JOIN sources.rxnconso r ON dv.concept_code = r.code
	AND r.code != 'NOCODE'
	AND r.lat = 'ENG'
		AND r.sab = 'ATC'
		AND r.tty IN (
			'PT',
			'IN'
			)
	; -- 7105 (6440) -- to compare with old script using except

-- perform mapping replacement using function below  (only to Standard concepts?)
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

-- Add mapping FROM deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

-- Deprecate 'Maps to' mappings to deprecated AND upgraded concepts (the step of such deprecation can be deleted) but what should we do with ancestor?
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

-- DELETE ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DELETEAmbiguousMAPSTO();
END $_$;
