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
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>false, include_deprecated_rels=>true, include_synonyms=>true);

--1. Update a 'latest_update' field to a new date
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.SetLatestUpdate(
                pVocabularyName => 'ATC',
                pVocabularyDate => (SELECT vocabulary_date FROM sources.atc_codes LIMIT 1),
                pVocabularyVersion => (SELECT vocabulary_version FROM sources.atc_codes LIMIT 1),
                pVocabularyDevSchema => 'DEV_ATC'
                );
    END
$_$;


--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

----collect ATC-RxNorm connections from sources
select dev_atc.collect_atc_rxnorm_from_sources();
----apply all manual changes
SELECT dev_atc.update_atc_relationships();

--3. Populate concept_stage
INSERT INTO concept_stage
            (concept_id,
             concept_name,
             domain_id,
             vocabulary_id,
             concept_class_id,
             standard_concept,
             concept_code,
             valid_start_date,
             valid_end_date,
             invalid_reason)
SELECT t1.concept_id,
       CASE
           WHEN t1.adm_r IS NULL THEN TRIM(t1.name)
           ELSE TRIM(t1.name || '; ' || t1.adm_r)
           END           AS concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       CASE
           WHEN LEFT(t1.name, 3) NOT IN ('[U]', '[D]') THEN 'C'
           ELSE NULL END AS standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM (
        WITH CTE AS ---Subquery to add 4th lvl class name before uninformative 5th class names combinations, various, various combinations
               (SELECT atc_1.class_code AS class_code,
                       LOWER(atc_2.class_name) || ' - ' || atc_1.class_name AS combo_name
                FROM sources.atc_codes atc_1
                         JOIN sources.atc_codes atc_2 ON LEFT(atc_1.class_code, 5) = atc_2.class_code AND LOWER(atc_1.class_name) IN ('combinations', 'various', 'various combinations')
                                                                                                      AND LENGTH(atc_1.class_code) = 7),
            CTE_2 as (
                        select
                                DISTINCT class_code,
                                class_name,
                                CASE

                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'A01AB' THEN 'local oral'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'A01AC' THEN 'local oral'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'A01AD' THEN 'local oral'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'A06AG' THEN 'rectal'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'A10AE' THEN 'parenteral'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'B03AA' THEN 'oral'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'B03AB' THEN 'oral'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'B03AC' THEN 'parenteral'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'B05BA' THEN 'parenteral'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'B05XX' THEN 'parenteral'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'C05AX' THEN 'ointment'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'C05BA' THEN 'ointment'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'C05BB' THEN 'parenteral'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'D01AE' THEN 'ointment'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'D02BA' THEN 'ointment'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'D04AA' THEN 'ointment'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'D04AB' THEN 'ointment'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'D05AD' THEN 'ointment'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'D05AX' THEN 'ointment'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'D06AX' THEN 'ointment'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'D10AD' THEN 'ointment'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'D10AX' THEN 'ointment'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'D10BX' THEN 'oral'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'D11AE' THEN 'ointment'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'G02BA' THEN 'implant'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'G02BB' THEN 'vaginal'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'G02CC' THEN 'vaginal'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'M02AA' THEN 'ointment'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'M02AX' THEN 'ointment'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'N01AA' THEN 'inhalant'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'N01AB' THEN 'inhalant'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'R01AX' THEN 'nasal'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'R03BX' THEN 'inhalant'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'V03AN' THEN 'inhalant'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'V09EA' THEN 'inhalant'
                                    WHEN LENGTH(class_code) = 7 AND LEFT(class_code, 5) = 'V09EB' THEN 'parenteral'

                                    WHEN adm_r = 'Chewing gum' THEN 'chewing gum'
                                    WHEN adm_r IN ('Inhal', 'Inhal. powder', 'Inhal.aerosol', 'Inhal.powder', 'Inhal.solution') THEN 'inhalant'
                                    WHEN adm_r = 'Instill.solution' THEN 'instillation solution'
                                    WHEN adm_r = 'N' THEN 'nasal'
                                    WHEN adm_r = 'O' THEN 'oral'
                                    WHEN adm_r IN ('O,P', '"O,P"') THEN 'oral, parenteral'
                                    WHEN adm_r = 'P' THEN 'parenteral'
                                    WHEN adm_r = 'R' THEN 'rectal'
                                    WHEN adm_r = 'SL' THEN 'sublingual'
                                    WHEN adm_r = 'TD' THEN 'transdermal'
                                    WHEN adm_r = 'V' THEN 'vaginal'
                                    WHEN adm_r IN ('implant', 's.c. implant', 'urethral') THEN 'implant'
                                    WHEN adm_r = 'intravesical' THEN 'intravesical'
                                    WHEN adm_r = 'lamella' THEN 'lamella'
                                    WHEN adm_r = 'ointment' THEN 'ointment'
                                    WHEN adm_r = 'oral aerosol' THEN 'local oral'
                                    ELSE NULL
                                END as adm_r
                            from sources.atc_codes
                        ),
            CTE_3 as (
                SELECT class_code,
                       string_agg(distinct adm_r,', ') as adm_r
                FROM CTE_2
                GROUP BY class_code
            )
      SELECT DISTINCT NULL::INT AS concept_id,
                      CASE
                          WHEN (active = 'NA' OR active = 'C') AND t1.class_name NOT IN ('combinations', 'various', 'various combinations')
                              THEN t1.class_name --- If not D and U and not in list ('combinations', 'various', 'various combinations')
                          WHEN (active = 'NA' OR active = 'C') AND t1.class_name IN ('combinations', 'various', 'various combinations')
                              THEN t3.combo_name --- If name in ('combinations', 'various', 'various combinations')
                          WHEN (active = 'D' OR active = 'U') AND t1.class_name IN ('combinations', 'various', 'various combinations')
                              THEN '[' || active || '] ' || t3.combo_name --- If D or U and name in ('combinations', 'various', 'various combinations')
                          ELSE '[' || active || '] ' || t1.class_name
                          END AS name,
                      t2.adm_r AS adm_r,
                      'Drug' AS domain_id,
                      'ATC' AS vocabulary_id,
                      CASE
                          WHEN LENGTH(t1.class_code) = 1 THEN 'ATC 1st'
                          WHEN LENGTH(t1.class_code) = 3 THEN 'ATC 2nd'
                          WHEN LENGTH(t1.class_code) = 4 THEN 'ATC 3rd'
                          WHEN LENGTH(t1.class_code) = 5 THEN 'ATC 4th'
                          WHEN LENGTH(t1.class_code) = 7 THEN 'ATC 5th'
                          END AS concept_class_id,
                      'C' AS stc,
                      t1.class_code AS concept_code,
                      CASE
                          WHEN active = 'NA' AND t1.class_code NOT IN (SELECT DISTINCT replaced_by
                                                                       FROM sources.atc_codes --all codes except those for which we know actual dates
                                                                       WHERE replaced_by != 'NA') --get standard 1970-2099 values
                              THEN TO_DATE('1970-01-01', 'YYYY-MM-DD')
                          ELSE start_date
                          END AS valid_start_date,
                      revision_date AS valid_end_date,
                      CASE
                          WHEN active = 'NA' THEN NULL
                          ELSE active
                          END AS invalid_reason
      FROM sources.atc_codes t1
               LEFT JOIN CTE_3 t2 ON t1.class_code = t2.class_code
               LEFT JOIN CTE t3 ON t1.class_code = t3.class_code
      WHERE t1.active != 'C') t1;

--3. Populate concept_synonym_stage
INSERT INTO concept_synonym_stage
(synonym_concept_id,
 synonym_name,
 synonym_concept_code,
 synonym_vocabulary_id,
 language_concept_id)
SELECT DISTINCT NULL::INT AS synonym_concept_id,
                CASE
                    WHEN t1.synonym_name IS NULL THEN TRIM(t2.class_name)
                    ELSE TRIM(t1.synonym_name)
                    END AS synonym_name,
                t1.synonym_concept_code,
                'ATC' AS synonym_vocabulary_id,
                4180186 AS language_concept_id
FROM (SELECT class_code AS synonym_concept_code,
             class_name || ' ' || ddd || ' ' || u || ' ' || product AS synonym_name
      FROM (SELECT class_code,
                   class_name,
                   CASE WHEN ddd = 'NA' THEN NULL ELSE ddd END AS ddd,
                   CASE WHEN u = 'NA' THEN NULL ELSE u END AS u,
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
                       WHEN adm_r = 'implant' THEN 'Implant'
                       END AS product
            FROM sources.atc_codes
            WHERE LENGTH(class_code) = 7) t1

      UNION

      (SELECT class_code AS synonym_concept_code,
              class_name AS synonym_name
       FROM sources.atc_codes
       WHERE LENGTH(class_code) = 7)) t1
         JOIN sources.atc_codes t2 ON t1.synonym_concept_code = t2.class_code;

--concept_relationship_stage population

--4a. Insert ATC - Ingredient relationships (except ATC - RxNorm sec up)
INSERT INTO concept_relationship_stage
            (concept_id_1,
             concept_id_2,
             concept_code_1,
             concept_code_2,
             vocabulary_id_1,
             vocabulary_id_2,
             relationship_id,
             valid_start_date,
             valid_end_date,
             invalid_reason)
SELECT NULL::INT AS concept_id_1,
       NULL::INT AS concept_id_2,
       class_code AS concept_code_1,
       t2.concept_code AS concept_code_2,
       'ATC' AS vocabulary_id_1,
       t2.vocabulary_id AS vocabulary_id_2,
       relationship_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('2099-12-31', 'YYYY-MM-DD') AS valid_end_date,
       NULL AS invalid_reason
FROM (SELECT DISTINCT class_code,
             class_name,
             relationship_id,
             UNNEST(STRING_TO_ARRAY(ids, ', ')) AS concept_code_2
      FROM dev_atc.new_atc_codes_ings_for_manual
      WHERE relationship_id != 'ATC - RxNorm sec up') t1
         JOIN devv5.concept t2 ON t1.concept_code_2::INT = t2.concept_id AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension');

--4b. Insert ATC - RxNorm sec up relationships (auto-collection based on ATC - RxNorm connections)
    INSERT INTO concept_relationship_stage
                (concept_id_1,
                 concept_id_2,
                 concept_code_1,
                 concept_code_2,
                 vocabulary_id_1,
                 vocabulary_id_2,
                 relationship_id,
                 valid_start_date,
                 valid_end_date,
                 invalid_reason)
    WITH all_ids_except_secups as
    (
        WITH sec_up_conns as
        (
            select *
            from dev_atc.new_atc_codes_ings_for_manual
            where relationship_id = 'ATC - RxNorm sec up'
        )
        SELECT class_code,
               string_agg(ids, ',') as ids
        FROM dev_atc.new_atc_codes_ings_for_manual
        where class_code in (select class_code from sec_up_conns)
          and relationship_id != 'ATC - RxNorm sec up'
        GROUP BY class_code
    ),
    main_query as
    (
        select t1.class_code,
               string_agg(DISTINCT c.concept_id::text, ',') as all_ids_on_markt,
               t2.ids as except_secups
        from dev_atc.new_unique_atc_codes_rxnorm t1
             join devv5.concept_ancestor ca on ca.descendant_concept_id = t1.ids
             join devv5.concept c on ca.ancestor_concept_id = c.concept_id
                                    and c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                    and c.concept_class_id in ('Ingredient', 'Precise Ingredient')
             join all_ids_except_secups t2 on t1.class_code = t2.class_code
        group by t1.class_code, t2.ids
    ),
        ONLY_SEC_UPS as (
                        SELECT class_code,
                               (SELECT string_agg(id::text, ',')
                                FROM (SELECT unnest(string_to_array(all_ids_on_markt, ',')::bigint[]) as id
                                      EXCEPT
                                      SELECT unnest(string_to_array(except_secups, ',')::bigint[]) as id
                                     ) t
                               ) as result_ids_only_secups
                        FROM main_query),
        class_code_secup_id as (
                                SELECT
                                    class_code,
                                    unnest(string_to_array(result_ids_only_secups, ','))::INT as ids
                                FROM ONLY_SEC_UPS)
        SELECT
            NULL::INT AS concept_id_1,
           NULL::INT AS concept_id_2,
           t1.class_code AS concept_code_1,
           t2.concept_code AS concept_code_2,
           'ATC' AS vocabulary_id_1,
           t2.vocabulary_id AS vocabulary_id_2,
           'ATC - RxNorm sec up',
           CURRENT_DATE AS valid_start_date,
           TO_DATE('2099-12-31', 'YYYY-MM-DD') AS valid_end_date,
           NULL AS invalid_reason
        FROM CLASS_CODE_SECUP_ID t1 join concept t2 on t1.ids = t2.concept_id
                                                    and t2.invalid_reason is NULL
                                                    and t2.standard_concept = 'S';

--5. Insert Maps to relationships
INSERT INTO concept_relationship_stage
            (concept_id_1,
             concept_id_2,
             concept_code_1,
             concept_code_2,
             vocabulary_id_1,
             vocabulary_id_2,
             relationship_id,
             valid_start_date,
             valid_end_date,
             invalid_reason)
SELECT DISTINCT NULL::INT AS concept_id_1,
                NULL::INT AS concept_id_2,
                class_code AS concept_code_1,
                t2.concept_code AS concept_code_2,
                'ATC' AS vocabulary_id_1,
                t2.vocabulary_id AS vocabulary_id_2,
                'Maps to' AS relationship_id,
                CURRENT_DATE AS valid_start_date,
                TO_DATE('2099-12-31', 'YYYY-MM-DD') AS valid_end_date,
                NULL AS invalid_reason
FROM (SELECT class_code,
             class_name,
             relationship_id,
             UNNEST(STRING_TO_ARRAY(ids, ', ')) AS concept_code_2
      FROM dev_atc.new_atc_codes_ings_for_manual
      WHERE relationship_id IN ('ATC - RxNorm pr lat', 'ATC - RxNorm sec lat')) t1
         JOIN devv5.concept t2 ON t1.concept_code_2::INT = t2.concept_id AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
WHERE (class_code, t2.concept_code) NOT IN (SELECT source_code_atc, source_code_rx
                                            FROM dev_atc.drop_maps_to);

--6. Insert ATC - RxNorm relationships
DROP TABLE IF EXISTS new_unique_atc_codes_rxnorm;
CREATE UNLOGGED TABLE new_unique_atc_codes_rxnorm AS
SELECT DISTINCT class_code, ids
FROM dev_atc.new_atc_codes_rxnorm
WHERE LENGTH(class_code) = 7
  AND concept_class_id = 'Clinical Drug Form';

INSERT INTO concept_relationship_stage
            (concept_id_1,
             concept_id_2,
             concept_code_1,
             concept_code_2,
             vocabulary_id_1,
             vocabulary_id_2,
             relationship_id,
             valid_start_date,
             valid_end_date,
             invalid_reason)
SELECT NULL::INT AS concept_id_1,
       NULL::INT AS concept_id_2,
       class_code AS concept_code_1,
       t2.concept_code AS concept_code_2,
       'ATC' AS vocabulary_id_1,
       t2.vocabulary_id AS vocabulary_id_2,
       'ATC - RxNorm' AS relationship_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('2099-12-31', 'YYYY-MM-DD') AS valid_end_date,
       NULL AS invalid_reason
FROM new_unique_atc_codes_rxnorm t1
         JOIN devv5.concept t2 ON t1.ids::INT = t2.concept_id AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension');

--7. Insert replacement relationships
INSERT INTO concept_relationship_stage
            (concept_code_1,
             concept_code_2,
             vocabulary_id_1,
             vocabulary_id_2,
             relationship_id,
             valid_start_date,
             valid_end_date)
SELECT class_code AS concept_code_1,
       replaced_by AS concept_code_2,
       'ATC' AS vocabulary_id_1,
       'ATC' AS vocabulary_id_2,
       'Concept replaced by' AS relationship_id,
       revision_date AS valid_start_date,
       TO_DATE('2099-12-31', 'YYYY-MM-DD') AS valid_end_date
FROM sources.atc_codes
WHERE active = 'U';

--8. Insert ATC - SNOMED and internal relationships
INSERT INTO concept_relationship_stage
            (concept_code_1,
             concept_code_2,
             vocabulary_id_1,
             vocabulary_id_2,
             relationship_id,
             valid_start_date,
             valid_end_date)
SELECT DISTINCT d.concept_code AS concept_code_1,
                e.concept_code AS concept_code_2,
                'SNOMED' AS vocabulary_id_1,
                'ATC' AS vocabulary_id_2,
                'SNOMED - ATC eq' AS relationship_id,
                d.valid_start_date AS valid_start_date,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM devv5.concept d
         JOIN sources.rxnconso r ON r.code = d.concept_code AND r.sab = 'SNOMEDCT_US'
                                                            AND r.code <> 'NOCODE'
         JOIN sources.rxnconso r2 ON r2.rxcui = r.rxcui AND r2.sab = 'ATC'
                                                        AND r2.code <> 'NOCODE'
         JOIN concept_stage e ON e.concept_code = r2.code AND e.concept_class_id <> 'ATC 5th' -- Ingredients only to RxNorm
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
         JOIN concept_stage lowr ON lowr.vocabulary_id = 'ATC' AND lowr.invalid_reason IS NULL -- to exclude deprecated or updated codes from the hierarchy
         JOIN vocabulary v ON v.vocabulary_id = 'ATC'
WHERE uppr.invalid_reason IS NULL
  AND uppr.vocabulary_id = 'ATC'
  AND (
        (
        LENGTH(uppr.concept_code) IN (4,5)
            AND lowr.concept_code = SUBSTR(uppr.concept_code, 1, LENGTH(uppr.concept_code) - 1)
        )
        OR
        (
        LENGTH(uppr.concept_code) IN (3,7)
            AND lowr.concept_code = SUBSTR(uppr.concept_code, 1, LENGTH(uppr.concept_code) - 2)
        )
    );


---9. Insert all valid connections to ATC from devv5.concept_relationship (except Ings connections,
-- because their full list in table dev_atc.new_atc_codes_ings_for_manual), which are not in stage table
INSERT INTO concept_relationship_stage
            (concept_code_1,
             concept_code_2,
             vocabulary_id_1,
             vocabulary_id_2,
             relationship_id,
             valid_start_date,
             valid_end_date)
SELECT c1.concept_code,
       c2.concept_code,
       c1.vocabulary_id,
       c2.vocabulary_id,
       relationship_id,
       cr.valid_start_date,
       cr.valid_end_date
FROM devv5.concept_relationship cr
         JOIN devv5.concept c1 ON cr.concept_id_1 = c1.concept_id AND c1.vocabulary_id = 'ATC'
                                                                  AND c1.invalid_reason IS NULL
         JOIN devv5.concept c2 ON cr.concept_id_2 = c2.concept_id AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                                                  AND c1.invalid_reason IS NULL
WHERE cr.relationship_id LIKE 'ATC%'
  AND cr.invalid_reason IS NULL
  AND cr.relationship_id NOT IN
      ('ATC - RxNorm pr lat', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up', 'ATC - RxNorm sec up')
  AND (c1.concept_code, cr.relationship_id, c2.concept_code) NOT IN
      (SELECT t1.atc_code, --- Concept not in manually reviewed list of existent codes
              'ATC - RxNorm' AS relationship,
              t2.concept_code
       FROM dev_atc.existent_atc_rxnorm_to_drop t1
                JOIN devv5.concept t2 ON t1.concept_id = t2.concept_id AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
       WHERE to_drop = 'D')
  AND (c1.concept_code, cr.relationship_id, c2.concept_code) NOT IN
      (SELECT DISTINCT t1.concept_code_atc, ---- Not in manually reviwed drop-list of source codes
                       'ATC - RxNorm' AS relationship,
                       t2.concept_code
       FROM dev_atc.atc_rxnorm_to_drop_in_sources t1
                JOIN devv5.concept t2 ON t1.concept_id_rx::INT = t2.concept_id AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
       WHERE drop = 'D')
  AND (c1.concept_code, cr.relationship_id, c2.concept_code) NOT IN
      (SELECT concept_code_1, --- Not already in concept_relationship_stage
              relationship_id,
              concept_code_2
       FROM concept_relationship_stage
       WHERE invalid_reason IS NULL
         AND relationship_id LIKE 'ATC%'
         AND relationship_id NOT IN
             ('ATC - RxNorm pr lat', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up', 'ATC - RxNorm sec up'));

-- 10. Deprecate ATC - RxNorm connections that were deprecated previously, but came again from sources (~420 connections)
UPDATE concept_relationship_stage
SET invalid_reason = 'D',
    valid_end_date = CURRENT_DATE
WHERE (concept_code_1, relationship_id, concept_code_2) IN
      (SELECT c1.concept_code,
              cr.relationship_id,
              c2.concept_code
       FROM devv5.concept_relationship cr
                JOIN devv5.concept c1 ON cr.concept_id_1 = c1.concept_id AND c1.vocabulary_id = 'ATC'
                JOIN devv5.concept c2 ON cr.concept_id_2 = c2.concept_id AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
       WHERE relationship_id LIKE 'ATC%'
         AND relationship_id NOT IN
             ('ATC - RxNorm pr lat', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up', 'ATC - RxNorm sec up')
         AND cr.invalid_reason = 'D')
  AND invalid_reason IS NULL;

-- 11. COVID-19 Manual mapping. Kill all ATC - RxNorm that came from sources (because they are not representative
-- while they are on Clinical Drug Form level)
UPDATE concept_relationship_stage
SET invalid_reason = 'D',
    valid_end_date = CURRENT_DATE
WHERE (concept_code_1, concept_code_2) IN
      (SELECT concept_code_atc,
              c1.concept_code AS concept_code_rxnorm
       FROM dev_atc.covid19_atc_rxnorm_manual cov
                JOIN devv5.concept c1 ON cov.concept_id = c1.concept_id AND c1.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                                                        AND cov.to_drop = 'D');
--- and add manually mapped (on clinical Drugs)
INSERT INTO concept_relationship_stage
            (concept_code_1,
             concept_code_2,
             vocabulary_id_1,
             vocabulary_id_2,
             relationship_id,
             valid_start_date,
             valid_end_date)
SELECT concept_code_atc AS concept_code_1,
       c1.concept_code AS concept_code_2,
       'ATC' AS vocabulary_id_1,
       c1.vocabulary_id AS vocabulary_id_2,
       'ATC - RxNorm' AS relationship_id,
       TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
       TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM dev_atc.covid19_atc_rxnorm_manual cov
         JOIN devv5.concept c1 ON cov.concept_id = c1.concept_id AND c1.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                                                 AND cov.to_drop IS NULL
ON CONFLICT DO NOTHING;

--12. Process manual relationships
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.ProcessManualRelationships();
    END
$_$;


ANALYZE concept_relationship_stage;

--13. Working with replacement mappings
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.CheckReplacementMappings();
    END
$_$;


--14. Add mapping from deprecated to fresh concepts
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
    END
$_$;

--15. Add mapping (to value) from deprecated to fresh concepts
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
    END
$_$;

--16. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
    END
$_$;

--17. Delete ambiguous 'Maps to' mappings
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.DELETEAmbiguousMAPSTO();
    END
$_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script


select admin_pack.VirtualLogIn('dev_atatur', 'wheoIFrevy!212');

DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;

-----compile class_to_drug table
SELECT dev_atc.build_class_to_drug();

DO $_$
BEGIN
    PERFORM VOCABULARY_PACK.pConceptAncestor(is_small=>TRUE);
END $_$;

select vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       invalid_reason,
       concept_delta,
       concept_delta_percentage
from qa_tests.get_summary (table_name=>'concept_ancestor',pCompareWith=>'prodv5');