/*****
Pass-Fail checks
*******/

-- new ATC should not have fewer concepts compared to old ATC
DROP TABLE IF EXISTS atc_checks;
CREATE TEMP TABLE atc_checks
AS
WITH a AS (SELECT COUNT(*) AS old_cnt, 'ATC count' AS check_group
           FROM devv5.concept c1
           WHERE c1.vocabulary_id = 'ATC'),
     b AS (SELECT COUNT(*) AS new_cnt, 'ATC count' AS check_group
           FROM dev_atc.concept c1
           WHERE c1.vocabulary_id = 'ATC')
SELECT *, CASE WHEN new_cnt >= old_cnt THEN 'P' ELSE 'F' END AS result
FROM a
         JOIN b USING (check_group);

-- new ATC should not have fewer mappings compared to old ATC
WITH a AS (SELECT COUNT(*) AS old_cnt, 'ATC-ingredient Maps to count' AS check_group
           FROM devv5.concept c1
                    JOIN devv5.concept_relationship cr1 ON c1.concept_id = cr1.concept_id_1
               AND c1.vocabulary_id = 'ATC' AND c1.concept_class_id = 'ATC 5th'
               AND cr1.invalid_reason IS NULL
               AND cr1.relationship_id = 'Maps to'),
     b AS (SELECT COUNT(*) AS new_cnt, 'ATC-ingredient Maps to count' AS check_group
           FROM dev_atc.concept c1
                    JOIN dev_atc.concept_relationship cr1 ON c1.concept_id = cr1.concept_id_1
               AND c1.vocabulary_id = 'ATC' AND c1.concept_class_id = 'ATC 5th'
               AND cr1.invalid_reason IS NULL
               AND cr1.relationship_id = 'Maps to')
INSERT
INTO atc_checks
SELECT *, CASE WHEN new_cnt >= old_cnt THEN 'P' ELSE 'F' END AS result
FROM a
         JOIN b USING (check_group);

-- There should be no links that are both valid and invalid
--TODO: Always true (constraint)
INSERT INTO atc_checks
SELECT check_group, NULL, cnt, CASE WHEN cnt = 0 THEN 'P' ELSE 'F' END AS result
FROM (SELECT COUNT(*) AS cnt, 'Valid and invalid link count' AS check_group
      FROM dev_atc.concept_relationship cr
               JOIN dev_atc.concept c ON c.concept_id = cr.concept_id_1 AND c.concept_class_id = 'ATC 5th'
               JOIN dev_atc.concept_relationship cr2 ON cr2.concept_id_1 = cr.concept_id_1
          AND cr2.relationship_id = cr.relationship_id
          AND cr2.concept_id_2 = cr.concept_id_2 AND cr.invalid_reason IS NULL AND cr2.invalid_reason IS NOT NULL) a;

--- There should be no links that are are both pr/sec or lat/up
INSERT INTO atc_checks
SELECT check_group, NULL, cnt, CASE WHEN cnt = 0 THEN 'P' ELSE 'F' END AS result
FROM (SELECT COUNT(*) AS cnt, 'Ingredients assigned different links' AS check_group
      FROM dev_atc.concept_relationship cr
               JOIN dev_atc.concept c ON c.concept_id = cr.concept_id_1 AND c.concept_class_id = 'ATC 5th'
               JOIN dev_atc.concept_relationship cr2 ON cr2.concept_id_1 = cr.concept_id_1
          AND cr2.relationship_id != cr.relationship_id
          AND cr.relationship_id IN
              ('ATC - RxNorm sec up', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up', 'ATC - RxNorm pr lat')
          AND cr2.relationship_id IN
              ('ATC - RxNorm sec up', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up', 'ATC - RxNorm pr lat')
          AND cr2.concept_id_2 = cr.concept_id_2 AND cr.invalid_reason IS NULL AND cr2.invalid_reason IS NULL) a;

-- No RxNorm drugs that have 1 ingredient should not be assigned combo ATC code
WITH CTE_2 AS (WITH CTE AS (SELECT c1.concept_code,
                                   c1.concept_name,
                                   c2.concept_name        AS secondary,
                                   COUNT(c3.concept_name) AS n_ings
                            FROM dev_atc.concept_relationship cr
                                     JOIN dev_atc.concept c1 ON cr.concept_id_1 = c1.concept_id
                                AND c1.vocabulary_id = 'ATC' AND c1.concept_class_id = 'ATC 5th'
                                AND c1.invalid_reason IS NULL
                                AND cr.invalid_reason IS NULL
                                AND cr.relationship_id = 'ATC - RxNorm'
                                     JOIN dev_atc.concept c2 ON cr.concept_id_2 = c2.concept_id
                                AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                AND c2.concept_class_id = 'Clinical Drug Form'
                                AND c2.invalid_reason IS NULL
                                     JOIN dev_atc.concept_relationship cr2 ON cr.concept_id_2 = cr2.concept_id_1
                                AND cr2.relationship_id = 'RxNorm has ing'
                                     JOIN devv5.concept c3 ON cr2.concept_id_2 = c3.concept_id
                            GROUP BY c1.concept_code, c1.concept_name, c2.concept_name)

               SELECT concept_code,
                      concept_name,
                      CASE
                          WHEN n_ings = 1 THEN 1
                          ELSE 0 END AS one_ing,
                      CASE
                          WHEN n_ings > 1 THEN 1
                          ELSE 0 END AS multi_ing
               FROM CTE),
     CTE_3 AS (SELECT concept_code,
                      concept_name,
                      SUM(one_ing)   AS one_ing,
                      SUM(multi_ing) AS multi_ing
               FROM CTE_2
               GROUP BY concept_code, concept_name
               ORDER BY concept_code),
     cte_4 AS (SELECT *
               FROM CTE_3
               WHERE concept_name LIKE '%combinations%'
                 AND one_ing > 0
               UNION
               SELECT *
               FROM CTE_3
               WHERE concept_name LIKE '% and %'
                 AND one_ing > 0 -- excludes things where form is not specified (doesn't have ';' ) b/c haven't figured out better regexp
     )
INSERT
INTO atc_checks
SELECT 'Rx mono drug assigned to ATC combo' AS group,
       NULL,
       COUNT(concept_code),
       CASE WHEN COUNT(concept_code) = 0 THEN 'P' ELSE 'F' END
FROM cte_4
;

-- custom check for corticosteroids
WITH rxnorm AS (
-- get corticosteroid ingredients from ATC and then their kids that are injectable
    SELECT c2.*
    FROM dev_atc.concept_ancestor ca
             JOIN dev_atc.concept c ON c.concept_id = ca.descendant_concept_id AND c.concept_class_id = 'Ingredient'
        AND ancestor_concept_id IN (21602723)
             JOIN dev_atc.concept_ancestor ca2 ON c.concept_id = ca2.ancestor_concept_id
             JOIN dev_atc.concept c2 ON c2.concept_id = ca2.descendant_concept_id
        AND c2.concept_name ~ 'Injec' --and c2.vocabulary_id = 'RxNorm'
)
INSERT
INTO atc_checks
SELECT 'missing corticosteroids in descendants', NULL, COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'P' ELSE 'F' END
FROM rxnorm r
WHERE r.concept_id NOT IN (
    -- get systemic cordicosteroids through ATC
    SELECT c.concept_id AS atc_id
    FROM dev_atc.concept_ancestor ca
             JOIN dev_atc.concept c ON c.concept_id = ca.descendant_concept_id
    WHERE ancestor_concept_id IN (21602745, 21602723));

SELECT *
FROM atc_checks;

/*****
Checks that require examination
*******/

-- BLOCK: New codes and relationships

-- Examine new ATC - RxNorm relationship per each ATC code

WITH CTE_old AS (SELECT c1.concept_code,
                        c1.concept_name,
                        c2.concept_id   AS id_old,
                        c2.concept_name AS name_old
                 --                        string_agg(c2.concept_id::VARCHAR, ' |') as ids_old,
--                        string_agg(c2.concept_name, ' |') as names_old,
--                        count(*) as count_old
                 FROM devv5.concept_relationship cr
                          JOIN devv5.concept c1 ON cr.concept_id_1 = c1.concept_id AND c1.vocabulary_id = 'ATC'
                     AND c1.concept_class_id = 'ATC 5th'
                          JOIN devv5.concept c2
                               ON cr.concept_id_2 = c2.concept_id AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                   AND cr.relationship_id = 'ATC - RxNorm'),
     CTE_new AS (SELECT c1.concept_code,
                        c1.concept_name,
                        c2.concept_id   AS id_new,
                        c2.concept_name AS name_new
                 --                        string_agg(c2.concept_id::VARCHAR, ' |') as ids_new,
--                        string_agg(c2.concept_name, ' |') as names_new,
--                        count(*) as count_new
                 FROM dev_atc.concept_relationship cr
                          JOIN dev_atc.concept c1 ON cr.concept_id_1 = c1.concept_id AND c1.vocabulary_id = 'ATC'
                     AND c1.concept_class_id = 'ATC 5th'
                          JOIN dev_atc.concept c2
                               ON cr.concept_id_2 = c2.concept_id AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                   AND cr.relationship_id = 'ATC - RxNorm')

SELECT new.concept_code,
       new.concept_name,
       STRING_AGG(new.id_new::VARCHAR, ' |') AS ids_new,
       STRING_AGG(new.name_new, ' |')        AS names_new,
       COUNT(*)                              AS new_count
FROM CTE_new new
         LEFT JOIN CTE_old AS old ON new.concept_code = old.concept_code
    AND new.id_new = old.id_old
WHERE old.concept_code IS NULL
   OR old.id_old IS NULL
GROUP BY new.concept_code, new.concept_name;

-- Examine new ATC - ingredient relationships (includes new ATC codes)

WITH CTE_old AS (SELECT c1.concept_code,
                        c1.concept_name,
                        cr.relationship_id,
                        c2.concept_id   AS id_old,
                        c2.concept_name AS name_old
                 FROM devv5.concept_relationship cr
                          JOIN devv5.concept c1 ON cr.concept_id_1 = c1.concept_id AND c1.vocabulary_id = 'ATC'
                     AND c1.concept_class_id = 'ATC 5th'
                          JOIN devv5.concept c2
                               ON cr.concept_id_2 = c2.concept_id AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                   AND cr.relationship_id IN ('ATC - RxNorm pr lat',
                                                              'ATC - RxNorm sec lat',
                                                              'ATC - RxNorm pr up',
                                                              'ATC - RxNorm sec up')),
     CTE_new AS (SELECT c1.concept_code,
                        c1.concept_name,
                        cr.relationship_id,
                        c2.concept_id   AS id_new,
                        c2.concept_name AS name_new
                 FROM dev_atc.concept_relationship cr
                          JOIN dev_atc.concept c1 ON cr.concept_id_1 = c1.concept_id AND c1.vocabulary_id = 'ATC'
                     AND c1.concept_class_id = 'ATC 5th'
                          JOIN dev_atc.concept c2
                               ON cr.concept_id_2 = c2.concept_id AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                   AND cr.relationship_id IN ('ATC - RxNorm pr lat',
                                                              'ATC - RxNorm sec lat',
                                                              'ATC - RxNorm pr up',
                                                              'ATC - RxNorm sec up'))
SELECT new.concept_code,
       new.concept_name,
       new.relationship_id,
       STRING_AGG(new.id_new::VARCHAR, ' |') AS ids_new,
       STRING_AGG(new.name_new, ' |')        AS names_new,
       COUNT(*)                              AS new_count
FROM CTE_new new
         LEFT JOIN CTE_old old ON new.concept_code = old.concept_code
    AND new.id_new = old.id_old
    AND new.relationship_id = old.relationship_id
WHERE old.concept_code IS NULL
   OR old.id_old IS NULL
GROUP BY new.concept_code, new.concept_name, new.relationship_id;

--- Number of one and multi-component drugs per ATC code

WITH CTE_2 AS (WITH CTE AS (SELECT c1.concept_code,
                                   c1.concept_name,
                                   c2.concept_name        AS secondary,
                                   COUNT(c3.concept_name) AS n_ings
                            FROM dev_atc.concept_relationship cr
                                     JOIN dev_atc.concept c1 ON cr.concept_id_1 = c1.concept_id
                                AND c1.vocabulary_id = 'ATC'
                                AND c1.concept_class_id = 'ATC 5th'
                                AND c1.invalid_reason IS NULL
                                AND cr.invalid_reason IS NULL
                                AND cr.relationship_id = 'ATC - RxNorm'
                                     JOIN dev_atc.concept c2 ON cr.concept_id_2 = c2.concept_id
                                AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                AND c2.concept_class_id = 'Clinical Drug Form'
                                AND c2.invalid_reason IS NULL
                                     JOIN dev_atc.concept_relationship cr2 ON cr.concept_id_2 = cr2.concept_id_1
                                AND cr2.relationship_id = 'RxNorm has ing'
                                     JOIN dev_atc.concept c3 ON cr2.concept_id_2 = c3.concept_id
                            GROUP BY c1.concept_code, c1.concept_name, c2.concept_name)

               SELECT concept_code,
                      concept_name,
                      CASE
                          WHEN n_ings = 1 THEN 1
                          ELSE 0 END AS one_ing,
                      CASE
                          WHEN n_ings > 1 THEN 1
                          ELSE 0 END AS multi_ing
               FROM CTE)

SELECT concept_code,
       concept_name,
       SUM(one_ing)   AS one_ing,
       SUM(multi_ing) AS multi_ing
FROM CTE_2
GROUP BY concept_code, concept_name
ORDER BY concept_code;


---------- Check of accordance of ATC_Code - Dose Forms

-- DROP TABLE IF EXISTS root_forms_for_check;
-- create table root_forms_for_check as   ---- Take actual roots from current dev_atc.concept
-- select
--     trim(t5.new) as coalesce,
--     string_agg(distinct t3.concept_name, ',')
-- from
--     dev_atc.concept t1
--     join dev_atc.concept_relationship cr on t1.concept_id = cr.concept_id_1 and t1.invalid_reason is null
--                                                                           and cr.invalid_reason is null
--                                                                           and cr.relationship_id = 'ATC - RxNorm'
--                                                                           and t1.concept_class_id = 'ATC 5th'
--     join dev_atc.new_adm_r t5 on t1.concept_code = t5.class_code
--     join dev_atc.concept t2 on cr.concept_id_2 = t2.concept_id and t2.invalid_reason is null
--                                                              and t2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
--                                                              and t2.concept_class_id = 'Clinical Drug Form'
--     join dev_atc.concept_relationship cr2 on cr2.concept_id_1 = t2.concept_id and cr2.invalid_reason is Null
--                                                                             and cr2.relationship_id = 'RxNorm has dose form'
--     join dev_atc.concept t3 on cr2.concept_id_2 = t3.concept_id and t3.invalid_reason is NULL
--
-- group by  t5.new;
--
-- select *
--     from dev_atc.root_forms_for_check;

---- Here is manual curated list of adm.r - Dose Forms from previous query.
DROP TABLE IF EXISTS root_forms_for_check;
CREATE TABLE root_forms_for_check AS
SELECT coalesce,
       STRING_AGG(concept_name, ',')
FROM dev_atc.all_adm_r_filter
GROUP BY coalesce
;

DROP TABLE IF EXISTS temp_check;
CREATE TABLE temp_check AS
SELECT c1.concept_id                             AS atc_concept_id,
       c1.concept_code                           AS atc_concept_code,
       c1.concept_name                           AS atc_concept_name,
       TRIM(SPLIT_PART(c1.concept_name, ';', 2)) AS root,
       c3.concept_name                           AS rxnorm_form,
       c2.concept_id                             AS rxnorm_concept_id,
       c2.concept_name                           AS rxnorm_concept_name,
       string_agg
FROM dev_atc.concept_relationship t1
         JOIN dev_atc.concept c1 ON t1.concept_id_1 = c1.concept_id
    AND c1.concept_class_id = 'ATC 5th'
    AND c1.vocabulary_id = 'ATC'
    AND c1.invalid_reason IS NULL
    AND t1.invalid_reason IS NULL
         JOIN dev_atc.concept c2
              ON t1.concept_id_2 = c2.concept_id AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                  --and c2.concept_class_id = 'Clinical Drug Form'
                  AND t1.relationship_id = 'ATC - RxNorm'
                  AND t1.invalid_reason IS NULL
                  AND c2.invalid_reason IS NULL
         JOIN dev_atc.root_forms_for_check t2 ON TRIM(SPLIT_PART(c1.concept_name, ';', 2)) = TRIM(t2.coalesce)
         JOIN dev_atc.concept_relationship cr
              ON t1.concept_id_2 = cr.concept_id_1 AND cr.relationship_id = 'RxNorm has dose form'
         JOIN dev_atc.concept c3
              ON c3.concept_id = cr.concept_id_2 AND c3.vocabulary_id IN ('RxNorm', 'RxNorm Extension');

DROP TABLE IF EXISTS temp_check_results;
CREATE TABLE temp_check_results AS
SELECT atc_concept_id,
       atc_concept_code,
       atc_concept_name,
       root,
       rxnorm_form,
       rxnorm_concept_id,
       rxnorm_concept_name,
       string_agg,
       CASE
           WHEN rxnorm_form ILIKE ANY (STRING_TO_ARRAY(string_agg, ',')) THEN 'NO'
           ELSE 'YES'
           END AS for_check
FROM dev_atc.temp_check;

DROP TABLE IF EXISTS temp_check_results_only_yes;
CREATE TABLE temp_check_results_only_yes AS
SELECT DISTINCT atc_concept_id,
                atc_concept_code,
                atc_concept_name,
                root,
                rxnorm_form,
                rxnorm_concept_name,
                rxnorm_concept_id
FROM dev_atc.temp_check_results
WHERE for_check = 'YES';

SELECT DISTINCT atc_concept_id,
                atc_concept_code,
                atc_concept_name,
                root,
                NULL AS drop,
                rxnorm_form,
                rxnorm_concept_id,
                rxnorm_concept_name
FROM dev_atc.temp_check_results_only_yes
WHERE rxnorm_form != 'Pack'
ORDER BY root, rxnorm_form;


-- BLOCK: Lost or deprecated codes and relationships

-- Examine ATC - RxNorm relationships that are getting deprecated

WITH CTE_old AS (SELECT c1.concept_code,
                        c1.concept_name,
                        c2.concept_id   AS id_old,
                        c2.concept_name AS name_old
                 --                        string_agg(c2.concept_id::VARCHAR, ' |') as ids_old,
--                        string_agg(c2.concept_name, ' |') as names_old,
--                        count(*) as count_old
                 FROM devv5.concept_relationship cr
                          JOIN devv5.concept c1 ON cr.concept_id_1 = c1.concept_id AND c1.vocabulary_id = 'ATC'
                     AND c1.concept_class_id = 'ATC 5th'
                          JOIN devv5.concept c2
                               ON cr.concept_id_2 = c2.concept_id AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                   AND cr.relationship_id = 'ATC - RxNorm'),
     CTE_new AS (SELECT c1.concept_code,
                        c1.concept_name,
                        c2.concept_id   AS id_new,
                        c2.concept_name AS name_new
                 --                        string_agg(c2.concept_id::VARCHAR, ' |') as ids_new,
--                        string_agg(c2.concept_name, ' |') as names_new,
--                        count(*) as count_new
                 FROM dev_atc.concept_relationship cr
                          JOIN dev_atc.concept c1 ON cr.concept_id_1 = c1.concept_id AND c1.vocabulary_id = 'ATC'
                     AND c1.concept_class_id = 'ATC 5th'
                          JOIN dev_atc.concept c2
                               ON cr.concept_id_2 = c2.concept_id AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                   AND cr.relationship_id = 'ATC - RxNorm')

SELECT old.concept_code,
       old.concept_name,
       STRING_AGG(old.id_old::VARCHAR, ' |') AS ids_old,
       STRING_AGG(old.name_old, ' |')        AS names_old,
       COUNT(*)                              AS old_count
FROM CTE_old old
         LEFT JOIN CTE_new new ON old.concept_code = new.concept_code
    AND old.id_old = new.id_new
WHERE new.concept_code IS NULL
   OR new.id_new IS NULL
GROUP BY old.concept_code, old.concept_name;


-- Examine ATC - RxNorm relationships that are getting deprecated, detailed view

SELECT c1.concept_id,
       c1.concept_code,
       c1.concept_name,
       old.relationship_id,
       c2.concept_code,
       c2.concept_id,
       c2.concept_name,
       c2.concept_code,
       old.invalid_reason AS old_invalid_reason,
       new.invalid_reason AS new_invalid_reason
FROM devv5.concept_relationship AS old
         JOIN dev_atc.concept_relationship AS new
              ON
                  old.concept_id_1 = new.concept_id_1
                      AND old.concept_id_2 = new.concept_id_2
                      AND old.relationship_id = new.relationship_id
         JOIN dev_atc.concept c1
              ON old.concept_id_1 = c1.concept_id AND c1.vocabulary_id = 'ATC' AND c1.invalid_reason IS NULL
         JOIN dev_atc.concept c2
              ON old.concept_id_2 = c2.concept_id AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension') AND
                 c2.invalid_reason IS NULL
WHERE old.relationship_id IN ('ATC - RxNorm')
  AND old.invalid_reason IS DISTINCT FROM new.invalid_reason;


-- Examine old ATC - ingredient relationships that are getting deprecated
SELECT c1.concept_id,
       c1.concept_name,
       old.relationship_id,
       c2.concept_code,
       c2.concept_id,
       c2.concept_name,
       c2.concept_code,
       old.invalid_reason AS old_invalid_reason,
       new.invalid_reason AS new_invalid_reason
FROM devv5.concept_relationship AS old
         JOIN dev_atc.concept_relationship AS new
              ON
                  old.concept_id_1 = new.concept_id_1
                      AND old.concept_id_2 = new.concept_id_2
                      AND old.relationship_id = new.relationship_id
         JOIN devv5.concept c1
              ON old.concept_id_1 = c1.concept_id AND c1.vocabulary_id = 'ATC' AND c1.invalid_reason IS NULL
         JOIN devv5.concept c2
              ON old.concept_id_2 = c2.concept_id AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension') AND
                 c2.invalid_reason IS NULL
WHERE
    old.relationship_id IN ('ATC - RxNorm pr lat', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up', 'ATC - RxNorm sec up')
  AND old.invalid_reason IS DISTINCT FROM new.invalid_reason;


-- BLOCK: other changes

-- Change of concept_names
SELECT c1.concept_code,
       c1.concept_name AS new_name,
       c2.concept_name AS old_name
FROM dev_atc.concept c1
         LEFT JOIN devv5.concept c2
                   ON c1.concept_id = c2.concept_id AND c1.vocabulary_id = 'ATC' AND c1.concept_class_id = 'ATC 5th'
WHERE c1.concept_name IS DISTINCT FROM c2.concept_name;


--- Change of synonyms
SELECT c.concept_id,
       c.concept_code,
       cs1.concept_synonym_name AS new_synonym,
       cs2.concept_synonym_name AS old_synonym
FROM dev_atc.concept c
         JOIN dev_atc.concept_synonym cs1
              ON c.concept_id = cs1.concept_id AND c.vocabulary_id = 'ATC' AND concept_class_id = 'ATC 5th'
         JOIN devv5.concept_synonym cs2 ON c.concept_id = cs2.concept_id
WHERE LOWER(cs1.concept_synonym_name) IS DISTINCT FROM LOWER(cs2.concept_synonym_name);


-- Compare of counts different concept_class_id's connected to ATC
SELECT t1.dev_atc_cr,
       t1.dev_atc_atccid,
       t1.dev_atc_cid,
       t1.dev_atc_count,
       t2.devv5_count,
       t2.devv5_cid,
       t2.dev_atc_atccid,
       t2.devv5_cr
FROM (SELECT cr.relationship_id  AS dev_atc_cr,
             c1.concept_class_id AS dev_atc_atccid,
             c2.concept_class_id AS dev_atc_cid,
             COUNT(*)            AS dev_atc_count
      FROM dev_atc.concept_relationship cr
               JOIN dev_atc.concept c1 ON cr.concept_id_1 = c1.concept_id
          AND cr.invalid_reason IS NULL
          AND c1.invalid_reason IS NULL
          AND c1.vocabulary_id = 'ATC'
               JOIN dev_atc.concept c2 ON cr.concept_id_2 = c2.concept_id
          AND cr.invalid_reason IS NULL
          AND c2.invalid_reason IS NULL
          AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
      GROUP BY cr.relationship_id, c1.concept_class_id, c2.concept_class_id) t1

         FULL JOIN

     (SELECT cr.relationship_id  AS devv5_cr,
             c1.concept_class_id AS dev_atc_atccid,
             c2.concept_class_id AS devv5_cid,
             COUNT(*)            AS devv5_count
      FROM devv5.concept_relationship cr
               JOIN devv5.concept c1 ON cr.concept_id_1 = c1.concept_id
          AND cr.invalid_reason IS NULL
          AND c1.invalid_reason IS NULL
          AND c1.vocabulary_id = 'ATC'
               JOIN devv5.concept c2 ON cr.concept_id_2 = c2.concept_id
          AND cr.invalid_reason IS NULL
          AND c2.invalid_reason IS NULL
          AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
      GROUP BY cr.relationship_id, c1.concept_class_id, c2.concept_class_id) t2
     ON t1.dev_atc_cr = t2.devv5_cr
         AND t1.dev_atc_atccid = t2.dev_atc_atccid
         AND t1.dev_atc_cid = t2.devv5_cid

ORDER BY t1.dev_atc_cr, t1.dev_atc_cid;


--- Home many combo drugs come to ATC mono codes

SELECT concept_code,
       COUNT(concept_id)
FROM (SELECT c1.concept_code,
             c1.concept_name,
             c2.concept_id,
             c2.concept_name
      FROM dev_atc.concept_relationship cr
               JOIN dev_atc.concept c1 ON cr.concept_id_1 = c1.concept_id
          AND c1.vocabulary_id = 'ATC'
          AND c1.invalid_reason IS NULL
          AND cr.invalid_reason IS NULL
          AND cr.relationship_id = 'ATC - RxNorm'
          AND c1.concept_code IN (SELECT concept_code
                                  FROM dev_atc.concept
                                  WHERE vocabulary_id = 'ATC'
                                    AND concept_class_id = 'ATC 5th'
                                    AND concept_name !~* '(and|comb|various|comp)')
               JOIN dev_atc.concept c2 ON cr.concept_id_2 = c2.concept_id
          AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
          AND c2.invalid_reason IS NULL
               JOIN dev_atc.concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id
          AND cr2.invalid_reason IS NULL
          AND cr2.relationship_id = 'RxNorm has ing'
      GROUP BY c1.concept_code, c1.concept_name, c2.concept_id, c2.concept_name
      HAVING COUNT(cr2.concept_id_2) > 1) t1
GROUP BY concept_code
ORDER BY count DESC;


-- How manu GCS in clinical drug forms, that bineded to 'D07AB30', 'D07XB30'
WITH CTE_1 AS (SELECT c1.concept_id                    AS concept_id_atc,
                      c1.concept_code                  AS concept_code_atc,
                      c1.concept_name                  AS concept_name_atc,
                      cr.relationship_id               AS relationship_id,
                      c2.concept_id                    AS concept_id_rx,
                      c2.concept_name                  AS concept_name_rx,
                      c2.concept_class_id              AS concept_class_rx,
                      STRING_AGG(c3.concept_name, ',') AS ings
               FROM concept_relationship cr
                        JOIN
                    concept c1 ON cr.concept_id_1 = c1.concept_id
                        AND c1.vocabulary_id = 'ATC'
                        AND c1.invalid_reason IS NULL
                        AND cr.invalid_reason IS NULL
                        AND cr.relationship_id = 'ATC - RxNorm'
                        AND c1.concept_code IN ('D07AB30', 'D07XB30')
                        JOIN
                    concept c2 ON cr.concept_id_2 = c2.concept_id
                        AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                        AND c2.invalid_reason IS NULL
                        JOIN
                    concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id
                        AND cr2.invalid_reason IS NULL
                        AND c2.invalid_reason IS NULL
                        AND cr2.relationship_id = 'RxNorm has ing'
                        JOIN
                    concept c3 ON cr2.concept_id_2 = c3.concept_id
               GROUP BY c1.concept_id, c1.concept_code, c1.concept_name, cr.relationship_id, c2.concept_id,
                        c2.concept_name, c2.concept_class_id),
     gcs_list AS (SELECT UNNEST(ARRAY [
         'betamethasone',
         'cortisone',
         'dexamethasone',
         'fludrocortisone',
         'fluocortolone',
         'hydrocortisone',
         'methylprednisolone',
         'prednisolone',
         'prednisone',
         'prednylidene',
         'triamcinolone',
         'beclomethasone',
         'budesonide',
         'deflazacort',
         'desonide',
         'diflucortolone',
         'fluocinonide',
         'fluorometholone',
         'fluticasone',
         'halcinonide',
         'mometasone',
         'paramethasone',
         'rimexolone',
         'clobetasone',
         'fluocinolone',
         'flumethasone',
         'alclometasone',
         'diflorasone',
         'desoximetasone',
         'fluprednisolone',
         'medrysone',
         'tixocortol',
         'ciclesonide',
         'loteprednol'
         ]) AS gcs_name)
SELECT t.concept_id_atc,
       t.concept_code_atc,
       t.concept_name_atc,
       t.concept_id_rx,
       t.concept_name_rx,
       t.ings,
       COUNT(DISTINCT gcs_name) AS gcs_count
FROM CTE_1 t
         CROSS JOIN
     gcs_list
WHERE EXISTS (SELECT 1
              FROM UNNEST(STRING_TO_ARRAY(t.ings, ',')) AS ingredient
              WHERE ingredient = gcs_name)
GROUP BY t.concept_id_atc,
         t.concept_code_atc,
         t.concept_name_atc,
         t.concept_id_rx,
         t.concept_name_rx,
         t.ings;
