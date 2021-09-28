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
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			  => 'ATC',
	pVocabularyDate		  	=> (SELECT vocabulary_date FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyVersion	  => (SELECT vocabulary_version FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_ATC'
);
END $_$;

-- truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

-- add all ATC codes to staging tables using the function which processes the concept_manual table
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

-- add manually created relationships using the function which processes the concept_relationship_manual table 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

-- add manually created synonyms using the function processing the concept_synonym_manual
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualSynonyms();
END $_$;

-- add 1) 'SNOMED - ATC eq' relationships between SNOMED Drugs and Higher ATC Classes (excl. 5th) 
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
-- crosslinks between SNOMED Drug Class AND ATC Classes (not ATC 5th)
SELECT DISTINCT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'SNOMED' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	'SNOMED - ATC eq' AS relationship_id,
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
-- 2) 'Is a' relationships between ATC Classes using mrconso (internal ATC hierarchy)
SELECT uppr.concept_code AS concept_code_1,
	lowr.concept_code AS concept_code_2,
	'ATC' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	'Is a' AS relationship_id,
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

-- add 'ATC - RxNorm' relationships between ATC Classes and RxN/RxE Drug Products using class_to_drug table 
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
FROM class_to_drug cs -- manually curated table with ATC Class to Rx Drug Product links
JOIN concept_manual k ON k.concept_code = cs.class_code AND k.invalid_reason IS NULL
  JOIN concept c ON c.concept_id = cs.concept_id
WHERE NOT EXISTS (SELECT 1
                  FROM concept_relationship_stage crs
                  WHERE crs.concept_code_1 = cs.class_code
                  AND   crs.vocabulary_id_1 = 'ATC'
                  AND   crs.concept_code_2 = c.concept_code
                  AND   crs.vocabulary_id_2 = c.vocabulary_id
                  AND   crs.relationship_id = 'ATC - RxNorm'  --  and crs.invalid_reason is null
                 )
AND   c.concept_class_id != 'Ingredient'; -- 107533

-- add 'ATC - RxNorm pr lat' relationships indicating Primary unambiguous links between ATC Classes and RxN/RxE Drug Products (using input tables and dev_combo populated during previous Steps)
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
  JOIN relationship_to_concept rtc ON lower (irs.concept_code_2) = lower (rtc.concept_code_1)
  JOIN concept c
    ON concept_id_2 = c.concept_id
   AND c.concept_class_id = 'Ingredient'
  JOIN concept_manual k
    ON k.concept_code = SUBSTRING (irs.concept_code_1,'\w+')
   AND k.invalid_reason IS NULL
WHERE NOT EXISTS (SELECT 1
                  FROM dev_combo t
                  WHERE LOWER(t.concept_name) = LOWER(rtc.concept_code_1)
                  AND   t.class_code = SUBSTRING(irs.concept_code_1,'\w+')))
SELECT * FROM t1 cs
WHERE NOT EXISTS (SELECT 1
                  FROM concept_relationship_stage crs
                  WHERE crs.concept_code_1 = cs.concept_code_1
                  AND   crs.vocabulary_id_1 = 'ATC'
                  AND   crs.concept_code_2 = cs.concept_code_2
                  AND   crs.vocabulary_id_2 = cs.vocabulary_id_2
                  AND   crs.relationship_id = 'ATC - RxNorm pr lat' -- and crs.invalid_reason is null
                  ); -- 3292

-- add 'ATC - RxNorm pr lat', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up' for ATC Combo Classes using dev_combo
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
select distinct class_code, class_name, concept_id, rnk from dev_combo where rnk in (1,2,3)),
t2 as (
SELECT  a.class_code AS concept_code_1, 
       c.concept_code AS concept_code_2, 
       'ATC' AS vocabulary_id_1,
       c.vocabulary_id AS vocabulary_id_2,
case rnk when 1 then 'ATC - RxNorm pr lat'      
when 2 then 'ATC - RxNorm sec lat'
when 3 then 'ATC - RxNorm pr up'
--when 4 then 'ATC - RxNorm sec up' 
end AS relationship_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','YYYYMMDD') AS valid_end_date,
       NULL AS invalid_reason
FROM t1 a
JOIN concept c on c.concept_id = a.concept_id 
JOIN concept_manual k ON k.concept_code = a.class_code AND k.invalid_reason IS NULL
AND c.standard_concept = 'S')
SELECT DISTINCT * FROM t2 cs
WHERE NOT EXISTS (SELECT 1
                  FROM concept_relationship_stage crs
                  WHERE crs.concept_code_1 = cs.concept_code_1
                  AND   crs.vocabulary_id_1 = 'ATC'
                  AND   crs.concept_code_2 = cs.concept_code_2
                  AND   crs.vocabulary_id_2 = cs.vocabulary_id_2
                  AND   crs.relationship_id = cs.relationship_id --   and crs.invalid_reason is null
                );  -- 3670

--  add 'ATC - RxNorm sec up' relationships for Primary lateral in combination 
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
WITH t1 AS -- the list of the main Ingredients
(SELECT class_code,
       class_name,
       concept_id
FROM ing_pr_lat_sec_up WHERE rnk = 1
UNION ALL
SELECT class_code,
class_name, concept_id FROM ing_pr_up_sec_up WHERE rnk = 3
UNION ALL
SELECT class_code,
class_name, concept_id FROM ing_pr_up_combo WHERE rnk = 3
UNION ALL
SELECT class_code,
class_name, concept_id FROM ing_pr_lat_combo WHERE rnk = 1
UNION ALL
SELECT class_code,
class_name, concept_id FROM Ing_pr_lat_combo_excl WHERE rnk = 1
UNION ALL
SELECT class_code,
class_name, concept_id FROM ing_pr_up_sec_up_excl WHERE rnk = 3
),
t2 as (
SELECT DISTINCT c.class_code AS concept_code_1,
       cc.concept_code AS concept_code_2,
       'ATC' AS vocabulary_id_1,
       cc.vocabulary_id AS vocabulary_id_2,
       'ATC - RxNorm sec up' AS relationship_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','YYYYMMDD') AS valid_end_date,
       NULL AS invalid_reason
FROM class_to_drug c
  JOIN concept_ancestor ON descendant_concept_id = c.concept_id
  JOIN concept cc
    ON cc.concept_id = ancestor_concept_id
   AND cc.standard_concept = 'S'
   AND cc.concept_class_id = 'Ingredient'
   AND cc.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
  JOIN concept_manual k
    ON k.concept_code = c.class_code
   AND k.invalid_reason IS NULL
   AND k.concept_code IN (SELECT class_code FROM dev_combo)
WHERE (c.class_code,cc.concept_id) NOT IN (SELECT class_code, concept_id FROM t1)-- exclude main Ingredients 
)
SELECT  * FROM t2 cs
WHERE NOT EXISTS (SELECT 1
                  FROM concept_relationship_stage crs
                  WHERE crs.concept_code_1 = cs.concept_code_1
                  AND   crs.vocabulary_id_1 = 'ATC'
                  AND   crs.concept_code_2 = cs.concept_code_2
                  AND   crs.vocabulary_id_2 = cs.vocabulary_id_2
                  AND   crs.relationship_id = 'ATC - RxNorm sec up'
		  AND crs.invalid_reason = cs.invalid_reason
           ); -- 23477

-- deprecate links between ATC classes and dead RxN/RxE
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
AND   cr.invalid_reason IS NULL)
SELECT * FROM t1 cs
WHERE NOT EXISTS (SELECT 1
                  FROM concept_relationship_stage crs
                  WHERE crs.concept_code_1 = cs.concept_code_1
                  AND   crs.vocabulary_id_1 = 'ATC'
                  AND   crs.concept_code_2 = cs.concept_code_2
                  AND   crs.vocabulary_id_2 = cs.vocabulary_id_2
                  AND   crs.relationship_id = cs.relationship_id
                  and crs.invalid_reason = cs.invalid_reason); -- 8365

-- Deprecate accessory links for invalid codes
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
WITH t1 AS
 (
SELECT 
       c.concept_code AS concept_code_1,
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
  JOIN Concept_manual k on k.concept_code = c.concept_code 
  and k.invalid_reason is not null
--AND cc.standard_concept is null -- non-standard
WHERE c.vocabulary_id = 'ATC'
AND   cr.invalid_reason IS NULL)
SELECT * FROM t1 cs
WHERE NOT EXISTS (SELECT 1
                  FROM concept_relationship_stage crs
                  WHERE crs.concept_code_1 = cs.concept_code_1
                  AND   crs.vocabulary_id_1 = 'ATC'
                  AND   crs.concept_code_2 = cs.concept_code_2
                  AND   crs.vocabulary_id_2 = cs.vocabulary_id_2
                  AND   crs.relationship_id = cs.relationship_id
                  AND crs.invalid_reason = cs.invalid_reason 
                  );  -- 1215

-- add mirroring 'Maps to' for 'ATC - RxNorm pr lat' for monocomponent ATC Classes, which do not have doubling Standard ingredients (1-to-many mappings are permissive only for ATC Combo Classes)
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
WITH t1 AS
(
  SELECT *
  FROM concept_relationship_stage
  WHERE relationship_id = 'ATC - RxNorm pr lat'
  AND   invalid_reason IS NULL
),
t2 AS (
SELECT DISTINCT a.concept_code_1, --k.concept_name,
       a.concept_code_2,-- d.concept_name,
       a.vocabulary_id_1,
       a.vocabulary_id_2,
       'Maps to' as relationship_id,
       a.valid_start_date,
       a.valid_end_date,
       a.invalid_reason
FROM (SELECT *,
            COUNT(concept_code_1) OVER (PARTITION BY concept_code_1) AS cnt
     FROM t1) a
  JOIN concept_manual k
    ON k.concept_code = a.concept_code_1
   AND k.invalid_reason IS NULL
  JOIN concept d
    ON d.concept_code = a.concept_code_2
   AND d.vocabulary_id = a.vocabulary_id_2
   AND d.standard_concept = 'S'
WHERE cnt = 1 -- can be just one
)
SELECT * FROM t2 cs
WHERE NOT EXISTS (SELECT 1
                  FROM concept_relationship_stage crs
                  WHERE crs.concept_code_1 = cs.concept_code_1
                  AND   crs.vocabulary_id_1 = 'ATC'
                  AND   crs.concept_code_2 = cs.concept_code_2
                  AND   crs.vocabulary_id_2 = cs.vocabulary_id_2
                  AND   crs.relationship_id = cs.relationship_id --   and crs.invalid_reason is null
                ); -- 4374
                    
-- add mirroring 'Maps to' of  'ATC - RxNorm sec lat' relationships for ATC Combo Classes (1-to-1)
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
WITH T1 AS
(
  SELECT class_code,
         class_name,
         a.concept_id,
         c.concept_code,
         a.concept_name,
         c.vocabulary_id
  FROM dev_combo a
    JOIN concept c ON c.concept_id = a.concept_id
  WHERE rnk = 2
),
t2 as (
SELECT DISTINCT class_code as concept_code_1,
 -- class_name,
       concept_code as concept_code_2,
   --  concept_name,
       'ATC' as vocabulary_id_1,
       vocabulary_id as vocabulary_id_2,
       'Maps to' as relationship_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','YYYYMMDD') AS valid_end_date,
       NULL AS invalid_reason
FROM t1
WHERE class_code IN (SELECT class_code
                     FROM t1
                     GROUP BY class_code
                     HAVING COUNT(1) = 1)
                     )
SELECT * FROM t2 cs
WHERE NOT EXISTS (SELECT 1
                  FROM concept_relationship_stage crs
                  WHERE crs.concept_code_1 = cs.concept_code_1
                  AND   crs.vocabulary_id_1 = 'ATC'
                  AND   crs.concept_code_2 = cs.concept_code_2
                  AND   crs.vocabulary_id_2 = cs.vocabulary_id_2
                  AND   crs.relationship_id = 'Maps to' -- and crs.invalid_reason is null
                  ); -- 209

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
WITH T1 AS
(
  SELECT class_code,
         class_name,
         a.concept_id,
         c.concept_code,
         a.concept_name,
         c.vocabulary_id
  FROM dev_combo a
    JOIN concept c ON c.concept_id = a.concept_id
  WHERE rnk = 2
),
t2 as (
SELECT DISTINCT class_code as concept_code_1,
  --   class_name,
       concept_code as concept_code_2,
   --  concept_name,
       'ATC' as vocabulary_id_1,
       vocabulary_id as vocabulary_id_2,
       'Maps to' as relationship_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','YYYYMMDD') AS valid_end_date,
       NULL AS invalid_reason
FROM t1 a
WHERE class_code IN (SELECT class_code
                     FROM t1
                     GROUP BY class_code
                     HAVING COUNT(1) <= 3) -- Combo Classes with COUNT(1) > 3 were added from concept_relationship_manual 
and not exists (select 1 from atc_one_to_many_excl b where b.atc_code = a.class_code and a.concept_id = b.concept_id)
)
SELECT * FROM t2 cs
WHERE NOT EXISTS (SELECT 1
                  FROM concept_relationship_stage crs
                  WHERE crs.concept_code_1 = cs.concept_code_1
                  AND   crs.vocabulary_id_1 = 'ATC'
                  AND   crs.concept_code_2 = cs.concept_code_2
                  AND   crs.vocabulary_id_2 = cs.vocabulary_id_2
                  AND   crs.relationship_id = 'Maps to' --  and crs.invalid_reason is null
                 )
AND concept_code_1 not in ('P01BF05', 'J07AG52', 'J07BD51') -- artenimol and piperaquine|hemophilus influenzae B, combinations with pertussis and toxoids; systemic|measles, combinations with mumps, live attenuated; systemic
; -- 193
    
-- Add synonyms to concept_synonym stage for each of the rxcui/code combinations
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
		AND r.tty IN ('PT','IN'); 

-- perform mapping replacement using function below
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

-- Add mapping FROM deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

-- Deprecate 'Maps to' mappings to deprecated AND upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO(); 
END $_$;

-- DELETE ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DELETEAmbiguousMAPSTO();
END $_$;

--16. Build reverse relationship. This is necessary for next point
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
SELECT DISTINCT crs.concept_code_2,
	crs.concept_code_1,
	crs.vocabulary_id_2,
	crs.vocabulary_id_1,
	r.reverse_relationship_id,
	crs.valid_start_date,
	crs.valid_end_date,
	crs.invalid_reason
FROM concept_relationship_stage crs
JOIN relationship r ON r.relationship_id = crs.relationship_id
WHERE NOT EXISTS (
		-- the inverse record
		SELECT 1
		FROM concept_relationship_stage i
		WHERE crs.concept_code_1 = i.concept_code_2
			AND crs.concept_code_2 = i.concept_code_1
			AND crs.vocabulary_id_1 = i.vocabulary_id_2
			AND crs.vocabulary_id_2 = i.vocabulary_id_1
			AND r.reverse_relationship_id = i.relationship_id
		);

--17. Deprecate all relationships in concept_relationship that do not exist in concept_relationship_stage
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
SELECT DISTINCT
 a.concept_code, --a.concept_name, 
	b.concept_code, --b.concept_name,
	a.vocabulary_id,
	b.vocabulary_id,
	relationship_id,
	r.valid_start_date,
	CURRENT_DATE,
	'D'
FROM concept a
JOIN concept_relationship r ON a.concept_id = concept_id_1
	AND r.invalid_reason IS NULL
	AND r.relationship_id NOT IN (
		'Concept replaced by',
		'Concept replaces','Drug has drug class', 'Drug class of drug', 'Subsumes', 
	'Is a', 'ATC - SNOMED eq', 'SNOMED - ATC eq', 'VA Class to ATC eq', 'ATC to VA Class eq', 'ATC to NDFRT eq', 'NDFRT to ATC eq'
		)
JOIN concept b ON b.concept_id = concept_id_2
WHERE 'ATC' IN (
		a.vocabulary_id,
		b.vocabulary_id
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = a.concept_code
			AND crs_int.concept_code_2 = b.concept_code
			AND crs_int.vocabulary_id_1 = a.vocabulary_id
			AND crs_int.vocabulary_id_2 = b.vocabulary_id
			AND crs_int.relationship_id = r.relationship_id
		); -- 5418
		
-- remove suspicious replacement mapping for OLD codes
DELETE FROM concept_relationship_stage
WHERE concept_code_1 IN ('C10AA55','J05AE06','C10AA52','C10AA53','C10AA51','N02AX52', 'H01BA06')
AND   concept_code_2 IN ('17767','85762','7393','1191','161', '11149')
AND   invalid_reason IS NULL; -- 6

--delete duplicate (to do: define its origin)
DELETE
FROM concept_relationship_stage
WHERE ctid NOT IN (SELECT MIN(ctid)
                   FROM concept_relationship_stage
  
                   GROUP BY concept_code_1,
                            concept_code_2,
                            relationship_id,
                            invalid_reason
                            )
  and  concept_code_1 = 'H01BA06';-- 1
