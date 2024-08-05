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
* Authors: Anton Tatur
*
* Date: 2024
**************************************************************************/

--1. Update a 'latest_update' field to a new date
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


--3. Populate concept_stage
INSERT INTO concept_stage
            (
             concept_id,
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
SELECT
        t1.concept_id,
        CASE
            WHEN t1.adm_r is NULL then trim(t1.name)
            ELSE trim(t1.name || '; ' || t1.adm_r)
        END as concept_name,
        domain_id,
        vocabulary_id,
        concept_class_id,
        standard_concept,
        concept_code,
        valid_start_date,
        valid_end_date,
        invalid_reason
FROM
            (
                select
                    DISTINCT NULL::int as concept_id,
                    CASE
                        WHEN active = 'NA' or active = 'C' THEN t1.class_name
                        ELSE '[' || active || '] ' || t1.class_name
                    END AS name,
                    t2.new as adm_r,
                    'Drug' as domain_id,
                    'ATC' as vocabulary_id,
                    CASE
                        WHEN length(t1.class_code) = 1 then 'ATC 1st'
                        WHEN length(t1.class_code) = 3 then 'ATC 2nd'
                        WHEN length(t1.class_code) = 4 then 'ATC 3rd'
                        WHEN length(t1.class_code) = 5 then 'ATC 4th'
                        WHEN length(t1.class_code) = 7 then 'ATC 5th'
                    END AS concept_class_id,
                    'C' as standard_concept,
                    t1.class_code as concept_code,
                    CASE
                        WHEN active = 'NA' AND t1.class_code not in (
                                                                    SELECT distinct replaced_by
                                                                    FROM sources.atc_codes           --all codes except those for which we know actual dates
                                                                    WHERE replaced_by != 'NA'        --get standard 1970-2099 values.
                                                                    )
                        THEN TO_DATE('1970-01-01', 'YYYY-MM-DD')
                        ELSE start_date
                    END AS valid_start_date,
                    revision_date as valid_end_date,
                    CASE
                        WHEN active = 'NA' THEN NULL
                        ELSE active
                    END AS invalid_reason
                FROM sources.atc_codes t1
                left join dev_atc.new_adm_r t2 on t1.class_code = t2.class_code
                WHERE t1.active != 'C'
            ) t1;


--3. Populate concept_synonym_stage
INSERT INTO concept_synonym_stage
            (
            synonym_concept_id,
            synonym_name,
            synonym_concept_code,
            synonym_vocabulary_id,
            language_concept_id
            )
SELECT
        DISTINCT NULL::int as synonym_concept_id,
        CASE
            WHEN t1.synonym_name is null then trim(t2.class_name)
            ELSE trim(t1.synonym_name)
        END AS synonym_name,
        t1.synonym_concept_code,
        'ATC' as synonym_vocabulary_id,
        4180186 as language_concept_id
FROM
    (
          SELECT class_code as synonym_concept_code,
                 class_name || ' ' || ddd || ' ' || u || ' ' || product as synonym_name
          FROM
              (
                SELECT
                       class_code,
                       class_name,
                       CASE when ddd = 'NA' THEN NULL ELSE ddd END AS ddd,
                       CASE when u = 'NA' THEN NULL ELSE u END     AS u,
                       CASE
                           WHEN adm_r = 'NA' THEN NULL
                           WHEN adm_r = 'Inhal.powder' THEN 'Inhal.Powder'
                           WHEN adm_r = 'TD' THEN 'Transdrmal Product'
                           WHEN adm_r = 'Instill.solution' THEN 'Instill.Sol'
                           WHEN adm_r = '"""Inhal.powder"""' THEN 'Inhal.Powder'
                           WHEN adm_r = 'ointment' THEN 'Ointmen'
                           WHEN adm_r = 'O' THEN 'Oral Product'
                           WHEN adm_r = 'Inhal.aerosol' THEN 'Inhal.Aerosol'
                           WHEN adm_r = 'Chewing gum' THEN 'Chewing Gum'
                           WHEN adm_r = 'V' THEN 'Vaginal Product'
                           WHEN adm_r = 'lamella' THEN 'Lamella'
                           WHEN adm_r = 'oral aerosol' THEN 'Oral Aerosol'
                           WHEN adm_r = 's.c. implant' THEN 'S.C. Implant'
                           WHEN adm_r = 'Inhal. powder' THEN 'Inhal.Powder'
                           WHEN adm_r = 'urethral' THEN 'Urethral'
                           WHEN adm_r = 'N' THEN 'Nasal Product'
                           WHEN adm_r = '"O,P"' THEN 'Oral, Parentheral Product'
                           WHEN adm_r = 'P' THEN 'Parenteral Product'
                           WHEN adm_r = 'Inhal.solution' THEN 'Inhal.Solution'
                           WHEN adm_r = 'SL' THEN 'Sublingual Product'
                           WHEN adm_r = 'Inhal' THEN 'Inhal'
                           WHEN adm_r = 'intravesical' THEN 'Intravesical'
                           WHEN adm_r = 'R' THEN 'Rectal Product'
                           WHEN adm_r = 'implant' THEN 'Implan'
                           END                                     AS product
                FROM
                    sources.atc_codes
                WHERE
                    length(class_code) = 7
              ) t1

        UNION

              (SELECT
                   class_code as synonym_concept_code,
                   class_name as synonym_name
              FROM sources.atc_codes
              WHERE length(class_code) = 7)

        ) t1

        JOIN sources.atc_codes t2
        on t1.synonym_concept_code = t2.class_code;


--concept_relationship_stage population

--4. Insert ATC - Ingredient relationships
INSERT INTO concept_relationship_stage
    (
	concept_id_1,
    concept_id_2,
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
	)
SELECT
        NULL::INT as concept_id_1,
        NULL::INT as concept_id_2,
        class_code as concept_code_1,
        t2.concept_code as concept_code_2,
        'ATC' as vocabulary_id_1,
        t2.vocabulary_id as vocabulary_id_2,
        relationship_id,
        CURRENT_DATE as valid_start_date,
        TO_DATE('2099-12-31', 'YYYY-MM-DD') as valid_end_date,
        NULL as invalid_reason
FROM
     (
        SELECT
            class_code,
            class_name,
            relationship_id,
            unnest(string_to_array(ids, ', ')) as concept_code_2
        FROM
            dev_atc.new_atc_codes_ings_for_manual
     ) t1
      JOIN devv5.concept t2
          ON t1.concept_code_2::int = t2.concept_id AND t2.vocabulary_id in ('RxNorm', 'RxNorm Extension');


--5. Insert Maps to relationships
INSERT INTO concept_relationship_stage
    (
	concept_id_1,
    concept_id_2,
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
	)
SELECT
        DISTINCT NULL::INT as concept_id_1,
        NULL::INT as concept_id_2,
        class_code as concept_code_1,
        t2.concept_code as concept_code_2,
        'ATC' as vocabulary_id_1,
        t2.vocabulary_id as vocabulary_id_2,
        'Maps to' as relationship_id,
        CURRENT_DATE as valid_start_date,
        TO_DATE('2099-12-31', 'YYYY-MM-DD') as valid_end_date,
        NULL as invalid_reason
FROM
    (
        SELECT
            class_code,
            class_name,
            relationship_id,
            unnest(string_to_array(ids, ', ')) as concept_code_2
        FROM new_atc_codes_ings_for_manual
        WHERE relationship_id in ('ATC - RxNorm pr lat', 'ATC - RxNorm sec lat')
      ) t1
      JOIN devv5.concept t2
          ON t1.concept_code_2::int = t2.concept_id AND t2.vocabulary_id in ('RxNorm', 'RxNorm Extension');


--6. Insert ATC - RxNorm relationships
DROP TABLE IF EXISTS  new_unique_atc_codes_rxnorm;
CREATE UNLOGGED TABLE new_unique_atc_codes_rxnorm AS
SELECT DISTINCT class_code, ids
FROM new_atc_codes_rxnorm
WHERE length(class_code) = 7
AND concept_class_id = 'Clinical Drug Form';

INSERT INTO concept_relationship_stage
    (
	concept_id_1,
    concept_id_2,
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
	)
SELECT
        NULL::INT as concept_id_1,
        NULL::INT as concept_id_2,
        class_code as concept_code_1,
        t2.concept_code as concept_code_2,
        'ATC' as vocabulary_id_1,
        t2.vocabulary_id as vocabulary_id_2,
        'ATC - RxNorm' as relationship_id,
        CURRENT_DATE as valid_start_date,
        TO_DATE('2099-12-31', 'YYYY-MM-DD') as valid_end_date,
        NULL as invalid_reason
FROM new_unique_atc_codes_rxnorm t1
    JOIN devv5.concept t2 ON t1.ids::int = t2.concept_id AND t2.vocabulary_id in ('RxNorm', 'RxNorm Extension');

--7. Insert replacement relationships
INSERT INTO concept_relationship_stage
    (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date
    )
SELECT
        class_code as concept_code_1,
        replaced_by as concept_code_2,
        'ATC' as vocabulary_id_1,
        'ATC' as vocabulary_id_2,
        'Concept replaced by' as relationship_id,
        revision_date as valid_start_date,
        TO_DATE('2099-12-31', 'YYYY-MM-DD') as valid_end_date
FROM
    sources.atc_codes
WHERE
    active = 'U';


--8. Insert ATC - SNOMED and internal relationships
INSERT INTO concept_relationship_stage
    (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date
	)
SELECT
    DISTINCT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'SNOMED' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	'SNOMED - ATC eq' AS relationship_id,
	d.valid_start_date AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM devv5.concept d
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

-- 'Is a' relationships between ATC Classes using mrconso (internal ATC hierarchy)
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
		);


---9. Insert all valid connections to ATC from devv5.concept_relationship (except Ings connections,
-- because their full list in table dev_atc.new_atc_codes_ings_for_manual), which are not in stage table
INSERT INTO concept_relationship_stage
    (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date
	)
SELECT c1.concept_code,
       c2.concept_code,
       c1.vocabulary_id,
       c2.vocabulary_id,
       relationship_id,
       cr.valid_start_date,
       cr.valid_end_date
FROM devv5.concept_relationship cr
     JOIN devv5.concept c1 on cr.concept_id_1 = c1.concept_id and c1.vocabulary_id = 'ATC' and c1.invalid_reason is NULL
     JOIN devv5.concept c2 on cr.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension') and c1.invalid_reason is NULL
WHERE cr.relationship_id like 'ATC%'
AND cr.invalid_reason IS NULL
AND cr.relationship_id NOT IN ('ATC - RxNorm pr lat', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up', 'ATC - RxNorm sec up')
AND (c1.concept_code,cr.relationship_id, c2.concept_code) NOT IN (select t1.atc_code,   --- Concept not in manually reviewed list of existent codes
                                                                           'ATC - RxNorm' as relationship,
                                                                           t2.concept_code
                                                                  from dev_atc.existent_atc_rxnorm_to_drop t1
                                                                         join devv5.concept t2 on t1.concept_id = t2.concept_id
                                                                  where to_drop = 'D')
AND (c1.concept_code,cr.relationship_id, c2.concept_code) NOT IN (SELECT t1.concept_code_atc,   ---- Not in manually reviwed drop-list of source codes
                                                                           'ATC - RxNorm' as relationship,
                                                                            t2.concept_code
                                                                    FROM dev_atc.atc_rxnorm_to_drop_in_sources t1
                                                                         join devv5.concept t2 on t1.concept_id_rx = t2.concept_id
                                                                    WHERE drop = 'D')
AND (c1.concept_code,cr.relationship_id, c2.concept_code) NOT IN (SELECT concept_code_1,  --- Not already in concept_relationship_stage
                                                                           relationship_id,
                                                                           concept_code_2
                                                                    FROM dev_atc.concept_relationship_stage
                                                                    WHERE invalid_reason is NULL
                                                                    AND  relationship_id like 'ATC%'
                                                                    AND relationship_id NOT IN ('ATC - RxNorm pr lat', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up', 'ATC - RxNorm sec up'));

-- 10. Deprecate ATC - RxNorm connections that were deprecated previously, but came again from sources (~420 connections)
UPDATE concept_relationship_stage
SET invalid_reason = 'D',
    valid_end_date = CURRENT_DATE
WHERE (concept_code_1, relationship_id, concept_code_2) IN
                                                        (SELECT c1.concept_code,
                                                               cr.relationship_id,
                                                               c2.concept_code
                                                        FROM devv5.concept_relationship cr
                                                             join devv5.concept c1 on cr.concept_id_1 = c1.concept_id and c1.vocabulary_id = 'ATC'
                                                             join devv5.concept c2 on cr.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                        WHERE relationship_id like 'ATC%'
                                                        AND relationship_id NOT IN ('ATC - RxNorm pr lat', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up', 'ATC - RxNorm sec up')
                                                        AND cr.invalid_reason = 'D')
AND invalid_reason is NULL;


--11. Process manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;


ANALYZE concept_relationship_stage;

--12. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--13. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--14. Add mapping (to value) from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

--15. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--16. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DELETEAmbiguousMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script