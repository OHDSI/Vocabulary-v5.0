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
* Date: 2022
**************************************************************************/
--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ATC',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_ATC'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Add all ATC codes to staging tables using the function which processes the concept_manual table
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

ANALYZE concept_stage;

--4. Add manually created relationships using the function which processes the concept_relationship_manual table 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--5. Add manually created synonyms using the function processing the concept_synonym_manual
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualSynonyms();
END $_$;

--6. Fill the concept_relationship_stage
-- add 1) 'SNOMED - ATC eq' relationships between SNOMED Drugs and Higher ATC Classes (excl. 5th) 
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
-- crosslinks between SNOMED Drug Class AND ATC Classes (not ATC 5th)
SELECT DISTINCT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'SNOMED' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	'SNOMED - ATC eq' AS relationship_id,
	d.valid_start_date AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept d
JOIN sources.rxnconso r ON r.code = d.concept_code
	AND r.sab = 'SNOMEDCT_US'
	AND r.code <> 'NOCODE'
JOIN sources.rxnconso r2 ON r2.rxcui = r.rxcui
	AND r2.sab = 'ATC'
	AND r2.code <> 'NOCODE'
JOIN concept_stage e ON e.concept_code = r2.code
	AND e.concept_class_id <> 'ATC 5th' -- Ingredients only to RxNorm
	AND e.vocabulary_id = 'ATC'
WHERE d.vocabulary_id = 'SNOMED'
	AND d.invalid_reason IS NULL

UNION ALL

-- 2) 'Is a' relationships between ATC Classes using mrconso (internal ATC hierarchy)
SELECT uppr.concept_code AS concept_code_1,
	lowr.concept_code AS concept_code_2,
	'ATC' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept_stage uppr
JOIN concept_stage lowr ON lowr.vocabulary_id = 'ATC'
	AND lowr.invalid_reason IS NULL -- to exclude deprecated or updated codes from the hierarchy
JOIN vocabulary v ON v.vocabulary_id = 'ATC'
WHERE uppr.invalid_reason IS NULL
	AND uppr.vocabulary_id = 'ATC'
	AND (
		(
			LENGTH(uppr.concept_code) IN (
				4,
				5
				)
			AND lowr.concept_code = SUBSTR(uppr.concept_code, 1, LENGTH(uppr.concept_code) - 1)
			)
		OR (
			LENGTH(uppr.concept_code) IN (
				3,
				7
				)
			AND lowr.concept_code = SUBSTR(uppr.concept_code, 1, LENGTH(uppr.concept_code) - 2)
			)
		);-- 6495

--6.1 add 'ATC - RxNorm' relationships between ATC Classes and RxN/RxE Drug Products using class_to_drug table 
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT ctd.class_code AS concept_code_1,
	c.concept_code AS concept_code_2,
	'ATC' AS vocabulary_id_1,
	c.vocabulary_id AS vocabulary_id_2,
	'ATC - RxNorm' AS relationship_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM sources.class_to_drug ctd -- manually curated table with ATC Class to Rx Drug Product links
JOIN concept c ON c.concept_id = ctd.concept_id
	AND c.concept_class_id <> 'Ingredient'
WHERE EXISTS (
		SELECT 1
		FROM concept_stage cs_int
		WHERE cs_int.concept_code = ctd.class_code
			AND cs_int.invalid_reason IS NULL
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = ctd.class_code
			AND crs_int.vocabulary_id_1 = 'ATC'
			AND crs_int.concept_code_2 = c.concept_code
			AND crs_int.vocabulary_id_2 = c.vocabulary_id
			AND crs_int.relationship_id = 'ATC - RxNorm'
		);-- 115047

--6.2 add 'ATC - RxNorm pr lat' relationships indicating Primary unambiguous links between ATC Classes and RxN/RxE Drug Products (using input tables and dev_combo populated during previous Steps)
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT SUBSTRING(irs.concept_code_1, '\w+') AS concept_code_1,
	c.concept_code AS concept_code_2,
	'ATC' AS vocabulary_id_1,
	c.vocabulary_id AS vocabulary_id_2,
	'ATC - RxNorm pr lat' AS relationship_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM internal_relationship_stage irs
JOIN relationship_to_concept rtc ON lower(irs.concept_code_2) = lower(rtc.concept_code_1)
JOIN concept c ON concept_id_2 = c.concept_id
	AND c.concept_class_id = 'Ingredient'
JOIN concept_stage k ON k.concept_code = SUBSTRING(irs.concept_code_1, '\w+')
	AND k.invalid_reason IS NULL
WHERE NOT EXISTS (
		SELECT 1
		FROM dev_combo t
		WHERE LOWER(t.concept_name) = LOWER(rtc.concept_code_1)
			AND t.class_code = SUBSTRING(irs.concept_code_1, '\w+')
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = SUBSTRING(irs.concept_code_1, '\w+')
			AND crs_int.vocabulary_id_1 = 'ATC'
			AND crs_int.concept_code_2 = c.concept_code
			AND crs_int.vocabulary_id_2 = c.vocabulary_id
			AND crs_int.relationship_id = 'ATC - RxNorm pr lat'
		);-- 3292


--6.3 add 'ATC - RxNorm pr lat', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up' for ATC Combo Classes using dev_combo
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT *
FROM (
	SELECT dc.class_code AS concept_code_1,
		c.concept_code AS concept_code_2,
		'ATC' AS vocabulary_id_1,
		c.vocabulary_id AS vocabulary_id_2,
		CASE rnk WHEN 1 THEN 'ATC - RxNorm pr lat' WHEN 2 THEN 'ATC - RxNorm sec lat' WHEN 3 THEN 'ATC - RxNorm pr up' END AS relationship_id,
		CURRENT_DATE AS valid_start_date,
		TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
	FROM dev_combo dc
	JOIN concept c ON c.concept_id = dc.concept_id
		AND c.standard_concept = 'S'
	JOIN concept_stage k ON k.concept_code = dc.class_code
		AND k.invalid_reason IS NULL
	WHERE dc.rnk IN (
			1,
			2,
			3
			)
	) s0
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = s0.concept_code_1
			AND crs_int.vocabulary_id_1 = 'ATC'
			AND crs_int.concept_code_2 = s0.concept_code_2
			AND crs_int.vocabulary_id_2 = s0.vocabulary_id_2
			AND crs_int.relationship_id = s0.relationship_id
		);-- 3670

--6.4  add 'ATC - RxNorm sec up' relationships for Primary lateral in combination 
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT k.concept_code AS concept_code_1,
	cc.concept_code AS concept_code_2,
	'ATC' AS vocabulary_id_1,
	cc.vocabulary_id AS vocabulary_id_2,
	'ATC - RxNorm sec up' AS relationship_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM sources.class_to_drug c
JOIN concept_ancestor ca ON ca.descendant_concept_id = c.concept_id
JOIN concept cc ON cc.concept_id = ca.ancestor_concept_id
	AND cc.standard_concept = 'S'
	AND cc.concept_class_id = 'Ingredient'
	AND cc.vocabulary_id LIKE 'RxNorm%'
JOIN concept_stage k ON k.concept_code = c.class_code
	AND k.invalid_reason IS NULL
-- exclude main Ingredients 
LEFT JOIN ing_pr_lat_sec_up i1 ON i1.rnk = 1
	AND i1.class_code = c.class_code
	AND i1.concept_id = cc.concept_id
LEFT JOIN ing_pr_up_sec_up i2 ON i2.rnk = 3
	AND i2.class_code = c.class_code
	AND i2.concept_id = cc.concept_id
LEFT JOIN ing_pr_up_combo i3 ON i3.rnk = 3
	AND i3.class_code = c.class_code
	AND i3.concept_id = cc.concept_id
LEFT JOIN ing_pr_lat_combo i4 ON i4.rnk = 1
	AND i4.class_code = c.class_code
	AND i4.concept_id = cc.concept_id
LEFT JOIN ing_pr_lat_combo_excl i5 ON i5.rnk = 1
	AND i5.class_code = c.class_code
	AND i5.concept_id = cc.concept_id
LEFT JOIN ing_pr_up_sec_up_excl i6 ON i6.rnk = 3
	AND i6.class_code = c.class_code
	AND i6.concept_id = cc.concept_id
WHERE EXISTS (
		SELECT 1
		FROM dev_combo dc_int
		WHERE dc_int.class_code = k.concept_code
		)
	AND i1.class_code IS NULL
	AND i2.class_code IS NULL
	AND i3.class_code IS NULL
	AND i4.class_code IS NULL
	AND i5.class_code IS NULL
	AND i6.class_code IS NULL
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = k.concept_code
			AND crs_int.vocabulary_id_1 = 'ATC'
			AND crs_int.concept_code_2 = cc.concept_code
			AND crs_int.vocabulary_id_2 = cc.vocabulary_id
			AND crs_int.relationship_id = 'ATC - RxNorm sec up'
		);-- 23313

--6.5 deprecate links between ATC classes and dead RxN/RxE
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
JOIN concept c ON c.concept_id = cr.concept_id_1
	AND c.vocabulary_id = 'ATC'
JOIN concept cc ON cc.concept_id = cr.concept_id_2
	AND cc.vocabulary_id LIKE 'RxNorm%'
	AND cc.standard_concept IS NULL -- non-standard
WHERE cr.invalid_reason IS NULL
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = c.concept_code
			AND crs_int.vocabulary_id_1 = c.vocabulary_id
			AND crs_int.concept_code_2 = cc.concept_code
			AND crs_int.vocabulary_id_2 = cc.vocabulary_id
			AND crs_int.relationship_id = cr.relationship_id
		);-- 8365

--6.6 deprecate accessory links for invalid codes
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
JOIN concept c ON c.concept_id = cr.concept_id_1
	AND c.vocabulary_id = 'ATC'
JOIN concept cc ON cc.concept_id = cr.concept_id_2
JOIN concept_stage k ON k.concept_code = c.concept_code
	AND k.invalid_reason IS NOT NULL
WHERE cr.invalid_reason IS NULL
	AND c.concept_code <> 'H01BA06' -- deprecated argipressin
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = c.concept_code
			AND crs_int.vocabulary_id_1 = c.vocabulary_id
			AND crs_int.concept_code_2 = cc.concept_code
			AND crs_int.vocabulary_id_2 = cc.vocabulary_id
			AND crs_int.relationship_id = cr.relationship_id
		);-- 1213

--6.7 add mirroring 'Maps to' for 'ATC - RxNorm pr lat' for monocomponent ATC Classes, which do not have doubling Standard ingredients (1-to-many mappings are permissive only for ATC Combo Classes)
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT s0.concept_code_1,
	s0.concept_code_2,
	s0.vocabulary_id_1,
	s0.vocabulary_id_2,
	s0.relationship_id,
	s0.valid_start_date,
	s0.valid_end_date
FROM (
	SELECT crs.concept_code_1, --k.concept_name,
		crs.concept_code_2, --d.concept_name,
		crs.vocabulary_id_1,
		crs.vocabulary_id_2,
		'Maps to' AS relationship_id,
		crs.valid_start_date,
		crs.valid_end_date,
		COUNT(crs.concept_code_2) OVER (PARTITION BY crs.concept_code_1) AS cnt
	FROM concept_relationship_stage crs
	JOIN concept_stage k ON k.concept_code = crs.concept_code_1
		AND k.vocabulary_id = crs.vocabulary_id_1
		AND k.invalid_reason IS NULL
	JOIN concept d ON d.concept_code = crs.concept_code_2
		AND d.vocabulary_id = crs.vocabulary_id_2
		AND d.standard_concept = 'S'
	WHERE crs.relationship_id = 'ATC - RxNorm pr lat'
		AND crs.invalid_reason IS NULL
	) s0
WHERE s0.cnt = 1 -- can be just one
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = s0.concept_code_1
			AND crs_int.vocabulary_id_1 = s0.vocabulary_id_1
			AND crs_int.concept_code_2 = s0.concept_code_2
			AND crs_int.vocabulary_id_2 = s0.vocabulary_id_2
			AND crs_int.relationship_id = 'Maps to'
		);-- 4374

--6.8 add mirroring 'Maps to' of  'ATC - RxNorm sec lat' relationships for ATC Combo Classes (1-to-1)
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT s0.concept_code_1,
	s0.concept_code_2,
	s0.vocabulary_id_1,
	s0.vocabulary_id_2,
	s0.relationship_id,
	s0.valid_start_date,
	s0.valid_end_date
FROM (
	SELECT a.class_code AS concept_code_1,
		c.concept_code AS concept_code_2,
		'ATC' AS vocabulary_id_1,
		c.vocabulary_id AS vocabulary_id_2,
		'Maps to' AS relationship_id,
		CURRENT_DATE AS valid_start_date,
		TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
		COUNT(*) OVER (PARTITION BY a.class_code) AS cnt
	FROM dev_combo a
	JOIN concept c ON c.concept_id = a.concept_id
	WHERE a.rnk = 2
	) s0
WHERE s0.cnt = 1
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = s0.concept_code_1
			AND crs_int.vocabulary_id_1 = 'ATC'
			AND crs_int.concept_code_2 = s0.concept_code_2
			AND crs_int.vocabulary_id_2 = s0.vocabulary_id_2
			AND crs_int.relationship_id = s0.relationship_id
		);-- 209

--6.9
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT s0.concept_code_1,
	s0.concept_code_2,
	s0.vocabulary_id_1,
	s0.vocabulary_id_2,
	s0.relationship_id,
	s0.valid_start_date,
	s0.valid_end_date
FROM (
	SELECT a.class_code AS concept_code_1,
		c.concept_code AS concept_code_2,
		'ATC' AS vocabulary_id_1,
		c.vocabulary_id AS vocabulary_id_2,
		'Maps to' AS relationship_id,
		CURRENT_DATE AS valid_start_date,
		TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
		COUNT(*) OVER (PARTITION BY a.class_code) AS cnt,
		c.concept_id
	FROM dev_combo a
	JOIN concept c ON c.concept_id = a.concept_id
	WHERE a.rnk = 2
	) s0
LEFT JOIN atc_one_to_many_excl atme ON atme.atc_code = s0.concept_code_1
	AND atme.concept_id = s0.concept_id
WHERE atme.atc_code IS NULL
	AND s0.cnt <= 3 -- Combo Classes with COUNT(*) > 3 were added from concept_relationship_manual 
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = s0.concept_code_1
			AND crs_int.vocabulary_id_1 = 'ATC'
			AND crs_int.concept_code_2 = s0.concept_code_2
			AND crs_int.vocabulary_id_2 = s0.vocabulary_id_2
			AND crs_int.relationship_id = s0.relationship_id
		)
	AND concept_code_1 NOT IN (
		'P01BF05',
		'J07AG52',
		'J07BD51'
		);-- artenimol and piperaquine|hemophilus influenzae B, combinations with pertussis and toxoids; systemic|measles, combinations with mumps, live attenuated; systemic -- 193

--7. Add synonyms to concept_synonym stage for each of the rxcui/code combinations
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT cs.concept_code AS synonym_concept_code,
	vocabulary_pack.CutConceptSynonymName(r.str) AS synonym_name,
	cs.vocabulary_id AS synonym_vocabulary_id,
	4180186 AS language_concept_id
FROM concept_stage cs
JOIN sources.rxnconso r ON r.code = cs.concept_code
	AND r.code <> 'NOCODE'
	AND r.lat = 'ENG'
	AND r.sab = 'ATC'
	AND r.tty IN (
		'PT',
		'IN'
		);-- 6440

ANALYZE concept_relationship_stage;

--8. Perform mapping replacement using function below
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--9. Add mappings from deprecated to fresh codes
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--10. Deprecate 'Maps to' mappings to deprecated AND updated codes
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO(); 
END $_$;

--11. Remove ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DELETEAmbiguousMAPSTO();
END $_$;

--12. Build reverse relationships in order to take the next step
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
SELECT crs.concept_code_2,
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
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = crs.concept_code_2
			AND crs_int.vocabulary_id_1 = crs.vocabulary_id_2
			AND crs_int.concept_code_2 = crs.concept_code_1
			AND crs_int.vocabulary_id_2 = crs.vocabulary_id_1
			AND crs_int.relationship_id = r.reverse_relationship_id
		);

ANALYZE concept_relationship_stage;

--13. Deprecate all relationships from the concept_relationship table which do not exist in the concept_relationship_stage
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
SELECT a.concept_code,
	b.concept_code,
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
		'Concept replaces',
		'Drug has drug class',
		'Drug class of drug',
		'Subsumes',
		'Is a',
		'ATC - SNOMED eq',
		'SNOMED - ATC eq',
		'VA Class to ATC eq',
		'ATC to VA Class eq',
		'ATC to NDFRT eq',
		'NDFRT to ATC eq'
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
		);-- 5418

--14. Remove suspicious replacement mapping for OLD codes
DELETE
FROM concept_relationship_stage
WHERE concept_code_1 IN (
		'C10AA55',
		'J05AE06',
		'C10AA52',
		'C10AA53',
		'C10AA51',
		'N02AX52',
		'H01BA06'
		)
	AND concept_code_2 IN (
		'17767',
		'85762',
		'7393',
		'1191',
		'161',
		'11149'
		)
	AND invalid_reason IS NULL;-- 7

--15. Clean up
DROP TABLE rx_combo,
	rx_all_combo,
	atc_all_combo,
	tmp_irs_dcs,
	atc_all_mono,
	ing_pr_lat_sec_lat,
	ing_pr_lat_sec_up,
	ing_pr_lat_combo,
	ing_pr_lat_combo_excl,
	ing_pr_up_combo,
	ing_pr_up_sec_up,
	ing_pr_up_sec_up_excl,
	class_to_drug_new,
	t1,
	t2,
	t3,
	t4,
	full_combo,
	ing_pr_lat_combo_to_drug,
	ing_pr_lat_sec_up_combo_to_drug,
	ing_pr_lat_combo_excl_to_drug,
	ing_pr_sec_up_combo_to_drug,
	ing_pr_sec_up_combo_excl_to_drug,
	full_combo_with_form,
	no_atc_1,
	no_atc_1_with_form,
	no_atc_full_combo,
	wrong_df,
	combo_pull,
	dev_combo;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script