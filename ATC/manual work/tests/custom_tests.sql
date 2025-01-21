/*****
Pass-Fail checks from Anna
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
SELECT
      'Rx mono drug assigned to ATC combo' AS group,
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
WHERE
    r.concept_class_id = 'Clinical Drug Form'
    and
    r.concept_id NOT IN (
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


-- --This part should be run to obtain table for manual review. This part collects all possible Dose Forms for every ATC adm.r
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

---- Here is manual curated list of adm.r - dose Forms from previous query.
DROP TABLE IF EXISTS root_forms_for_check;
CREATE TABLE root_forms_for_check AS
SELECT coalesce,
       STRING_AGG(concept_name, ',')
FROM dev_atc.all_adm_r_filter  ---- created above, consists of different Dose Forms for every adm.route.
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

--- New concepts list
SELECT *
FROM dev_atc.concept t1
WHERE t1.vocabulary_id = 'ATC'
and
    t1.concept_code not in (select concept_code from devv5.concept where vocabulary_id = 'ATC');

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

----------- Count of connections per 1 RxNorm Code (total 32782 rxnorm codes 20.01.25)
--- new
SELECT
    t1.concept_id,
    t1.concept_name,
    count(DISTINCT t3.concept_code)
FROM concept t1
     join concept_relationship t2 on t1.concept_id = t2.concept_id_2 and t1.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                     and t1.concept_class_id = 'Clinical Drug Form'
                                                                     and t1.invalid_reason is NULL
                                                                     and t2.relationship_id = 'ATC - RxNorm'
                                                                     and t2.invalid_reason is NULL
     join concept t3 on t2.concept_id_1 = t3.concept_id and t3.vocabulary_id = 'ATC'
                                                        and t3.invalid_reason is NULL
GROUP BY t1.concept_id, t1.concept_name
order by count(DISTINCT t3.concept_code) desc;

--- old (total 32256 20.01.25)
SELECT
    t1.concept_id,
    t1.concept_name,
    count(DISTINCT t3.concept_code)
FROM devv5.concept t1
     join devv5.concept_relationship t2 on t1.concept_id = t2.concept_id_2 and t1.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                     and t1.concept_class_id = 'Clinical Drug Form'
                                                                     and t1.invalid_reason is NULL
                                                                     and t2.relationship_id = 'ATC - RxNorm'
                                                                     and t2.invalid_reason is NULL
     join devv5.concept t3 on t2.concept_id_1 = t3.concept_id and t3.vocabulary_id = 'ATC'
                                                        and t3.invalid_reason is NULL
GROUP BY t1.concept_id, t1.concept_name
order by count(DISTINCT t3.concept_code) desc;


--- New connections appeared after Update

SELECT
        *
FROM concept t1
     join concept_relationship t2 on t1.concept_id = t2.concept_id_2 and t1.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                     and t1.concept_class_id = 'Clinical Drug Form'
                                                                     and t1.invalid_reason is NULL
                                                                     and t2.relationship_id = 'ATC - RxNorm'
                                                                     and t2.invalid_reason is NULL
     join concept t3 on t2.concept_id_1 = t3.concept_id and t3.vocabulary_id = 'ATC'
                                                        and t3.invalid_reason is NULL
WHERE (t3.concept_id, t2.relationship_id, t1.concept_id) not in (SELECT
                                                                        t3.concept_id, t2.relationship_id, t1.concept_id
                                                                FROM devv5.concept t1
                                                                     join devv5.concept_relationship t2 on t1.concept_id = t2.concept_id_2 and t1.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                                                                                     and t1.concept_class_id = 'Clinical Drug Form'
                                                                                                                                     and t1.invalid_reason is NULL
                                                                                                                                     and t2.relationship_id = 'ATC - RxNorm'
                                                                                                                                     and t2.invalid_reason is NULL
                                                                     join devv5.concept t3 on t2.concept_id_1 = t3.concept_id and t3.vocabulary_id = 'ATC'
                                                                                                                        and t3.invalid_reason is NULL
                                                                        );



--- Count of ATC - RxNorm - ATC (old)
SELECT *  ---1096298
FROM devv5.concept_relationship cr
        JOIN devv5.concept c1 on cr.concept_id_1 = c1.concept_id
                              AND c1.vocabulary_id = 'ATC'
                              AND c1.invalid_reason is NULL
                              AND cr.invalid_reason is NULL
                              AND cr.relationship_id = 'ATC - RxNorm'
        JOIN devv5.concept c2 on cr.concept_id_2 = c2.concept_id
                              AND c2.invalid_reason is NULL
                              AND c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                              AND c2.concept_class_id = 'Clinical Drug Form'
        JOIN devv5.concept_relationship cr2 on c2.concept_id = cr2.concept_id_1
                                            AND cr2.invalid_reason is NULL
                                            AND cr2.relationship_id = 'RxNorm - ATC'
        JOIN devv5.concept c3 on cr2.concept_id_2 = c3.concept_id
                              AND c3.vocabulary_id = 'ATC'
                              AND c3.invalid_reason is NULL;

--- Count of ATC - RxNorm - ATC (new)
SELECT *  ---1123316
FROM dev_dev.concept_relationship cr
        JOIN dev_dev.concept c1 on cr.concept_id_1 = c1.concept_id
                              AND c1.vocabulary_id = 'ATC'
                              AND c1.invalid_reason is NULL
                              AND cr.invalid_reason is NULL
                              AND cr.relationship_id = 'ATC - RxNorm'
        JOIN dev_dev.concept c2 on cr.concept_id_2 = c2.concept_id
                              AND c2.invalid_reason is NULL
                              AND c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                              AND c2.concept_class_id = 'Clinical Drug Form'
        JOIN dev_dev.concept_relationship cr2 on c2.concept_id = cr2.concept_id_1
                                            AND cr2.invalid_reason is NULL
                                            AND cr2.relationship_id = 'RxNorm - ATC'
        JOIN dev_dev.concept c3 on cr2.concept_id_2 = c3.concept_id
                              AND c3.vocabulary_id = 'ATC'
                              AND c3.invalid_reason is NULL;


--- ATC - RxNorm - ATC new demo for H02AB06
SELECT *
FROM devv5.concept_relationship cr
        JOIN devv5.concept c1 on cr.concept_id_1 = c1.concept_id
                              AND c1.vocabulary_id = 'ATC'
                              AND c1.invalid_reason is NULL
                              AND cr.invalid_reason is NULL
                              AND cr.relationship_id = 'ATC - RxNorm'
                              AND c1.concept_id = 21602734
        JOIN devv5.concept c2 on cr.concept_id_2 = c2.concept_id
                              AND c2.invalid_reason is NULL
                              AND c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                              AND c2.concept_class_id = 'Clinical Drug Form'
                              AND c2.concept_id = 35149489
        JOIN devv5.concept_relationship cr2 on c2.concept_id = cr2.concept_id_1
                                            AND cr2.invalid_reason is NULL
                                            AND cr2.relationship_id = 'RxNorm - ATC'
        JOIN devv5.concept c3 on cr2.concept_id_2 = c3.concept_id
                              AND c3.vocabulary_id = 'ATC'
                              AND c3.invalid_reason is NULL;



---- Mono to Combo


WITH CTE_2 AS (WITH CTE AS (SELECT c1.concept_code,
                                   c1.concept_name,
                                   c2.concept_name        AS secondary,
                                   COUNT(c3.concept_name) AS n_ings
                            FROM dev_atatur.concept_relationship cr
                                     JOIN dev_atatur.concept c1 ON cr.concept_id_1 = c1.concept_id
                                AND c1.vocabulary_id = 'ATC' AND c1.concept_class_id = 'ATC 5th'
                                AND c1.invalid_reason IS NULL
                                AND cr.invalid_reason IS NULL
                                AND cr.relationship_id = 'ATC - RxNorm'
                                     JOIN dev_atatur.concept c2 ON cr.concept_id_2 = c2.concept_id
                                AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                AND c2.concept_class_id = 'Clinical Drug Form'
                                AND c2.invalid_reason IS NULL
                                     JOIN dev_atatur.concept_relationship cr2 ON cr.concept_id_2 = cr2.concept_id_1
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
               ORDER BY concept_code)
SELECT *
               FROM CTE_3
               WHERE concept_name LIKE '%combinations%'
                 AND one_ing > 0
               UNION
               SELECT *
               FROM CTE_3
               WHERE concept_name LIKE '% and %'
                 AND one_ing > 0 -- excludes things where form is not specified (doesn't have ';' ) b/c haven't figured out better regexp;
;
----- Check accordance of adm_r and Dose Form

SELECT DISTINCT atc_concept_id,
                atc_concept_code,
                atc_concept_name,
                root,
                NULL AS drop,
                rxnorm_form,
                rxnorm_concept_id,
                rxnorm_concept_name
FROM dev_atatur.temp_check_results_only_yes
WHERE rxnorm_form != 'Pack'
ORDER BY root, rxnorm_form;

--- Check what new connections appeared after update for specific ATC codes.
select *
from devv5.concept_relationship cr
        join devv5.concept c1 on cr.concept_id_1 = c1.concept_id
                                and cr.relationship_id = 'ATC - RxNorm'
                                and cr.invalid_reason is NULL
                                and c1.vocabulary_id = 'ATC'
                                and c1.concept_code = (:concept_code_to_find)
        join devv5.concept c2 on cr.concept_id_2 = c2.concept_id
                                and c2.concept_class_id = 'Clinical Drug Form'
                                and c2.invalid_reason is NULL
where (cr.concept_id_1, cr.concept_id_2) not in (select cr.concept_id_1, cr.concept_id_2
                                                    from dev_dev.concept_relationship cr
                                                            join dev_dev.concept c1 on cr.concept_id_1 = c1.concept_id
                                                                                    and cr.relationship_id = 'ATC - RxNorm'
                                                                                    and cr.invalid_reason is NULL
                                                                                    and c1.vocabulary_id = 'ATC'
                                                                                    and c1.concept_code = (:concept_code_to_find)
                                                            join dev_dev.concept c2 on cr.concept_id_2 = c2.concept_id
                                                                                    and c2.concept_class_id = 'Clinical Drug Form');

---- Multi-ing RxNorm's that have 2 ATC codes
SELECT
       c2.concept_id,
       c2.concept_name,
       count(DISTINCT c1.concept_code),
       string_agg(DISTINCT c1.concept_code, ',') as ATC
---       string_agg(c1.concept_code || ' - ' || c1.concept_name, ', ') as ATC
FROM dev_atatur.concept_relationship cr
        JOIN dev_atatur.concept c1 on cr.concept_id_1 = c1.concept_id
                              AND c1.vocabulary_id = 'ATC'
                              AND c1.invalid_reason is NULL
                              AND cr.invalid_reason is NULL
                              AND cr.relationship_id = 'ATC - RxNorm'
        JOIN dev_atatur.concept c2 on cr.concept_id_2 = c2.concept_id
                              AND c2.invalid_reason is NULL
                              AND c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                              AND c2.concept_class_id = 'Clinical Drug Form'
        JOIN dev_atatur.concept_relationship cr2 on c2.concept_id = cr2.concept_id_1
                                                 and cr2.invalid_reason is NULL
                                                 and cr2.relationship_id = 'RxNorm has ing'
GROUP BY c2.concept_id, c2.concept_name having count(DISTINCT c1.concept_code) = 2
                                           and count(DISTINCT cr2.concept_id_2) = 2
                                           AND COUNT(DISTINCT LEFT(c1.concept_code, 5)) = 1;


------- Multiing mapped to 1 mono ATC code, but at the same lvl exists combo code;
    WITH CTE as (SELECT c2.concept_id,
                    c2.concept_name,
                    STRING_AGG(DISTINCT c1.concept_code, ',') AS ATC
             FROM dev_atatur.concept_relationship cr
                      JOIN dev_atatur.concept c1 ON cr.concept_id_1 = c1.concept_id
                 AND c1.vocabulary_id = 'ATC'
                 AND c1.invalid_reason IS NULL
                 AND cr.invalid_reason IS NULL
                 AND cr.relationship_id = 'ATC - RxNorm'
                      JOIN dev_atatur.concept c2 ON cr.concept_id_2 = c2.concept_id
                 AND c2.invalid_reason IS NULL
                 AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                 AND c2.concept_class_id = 'Clinical Drug Form'
                      JOIN dev_atatur.concept_relationship cr2 ON c2.concept_id = cr2.concept_id_1
                 AND cr2.invalid_reason IS NULL
                 AND cr2.relationship_id = 'RxNorm has ing'
             GROUP BY c2.concept_id, c2.concept_name
             HAVING COUNT(cr2.concept_id_2) > 1),
     expanded as (
                        SELECT
                            concept_id,
                            concept_name,
                            unnest(STRING_TO_ARRAY(atc, ',')) as atc
                        FROM CTE
                        ),
    comb as (select
                    left(class_code,5) as up_level,
                    class_code as down_level
                from sources.atc_codes
                where length(class_code) = 7
                and class_name ~ 'comb|var'),
    connected as (
                    SELECT t1.*,
                           t2.DOWN_LEVEL as code_with_combo
                    FROM EXPANDED t1
                        JOIN comb t2 on left(t1.atc,5) = t2.UP_LEVEL),
    grouped as (
                SELECt concept_id,
                       concept_name,
                       atc,
                       string_to_array(string_agg(CODE_WITH_COMBO, ','), ',') concat
                FROM CONNECTED
                GROUP BY concept_id, concept_name, atc),
    filtered as (SELECT *
                 FROM GROUPED
                 WHERE atc != ANY (CONCAT)),
    ext as (
                SELECT
                    concept_id,
                    concept_name,
                    atc,
                    1 as existent_mapping
                FROM FILTERED

                UNION

                SELECT
                    concept_id,
                    concept_name,
                    UNNEST(concat),
                    0 as existent_mapping
                FROM FILTERED)

    SELECT
            DISTINCT ed.concept_id,
            ed.concept_name,
            ed.EXISTENT_MAPPING,
            LEFT(ed.ATC, 1) as "1st level code",
            ac1.class_name AS "1st level name",
            LEFT(ed.ATC, 3) as "2nd level code",
            ac2.class_name AS "2nd level name",
            LEFT(ed.ATC, 4) as "3rd level code",
            ac3.class_name AS "3rd level name",
            LEFT(ed.ATC, 5) as "4th level code",
            ac4.class_name AS "4th level name",
            ed.ATC as "5th level code",
            ac5.class_name AS "5th level name"
    FROM ext ed
    LEFT JOIN sources.atc_codes ac1 ON LEFT(ed.ATC, 1) = ac1.class_code
    LEFT JOIN sources.atc_codes ac2 ON LEFT(ed.ATC, 3) = ac2.class_code
    LEFT JOIN sources.atc_codes ac3 ON LEFT(ed.ATC, 4) = ac3.class_code
    LEFT JOIN sources.atc_codes ac4 ON LEFT(ed.ATC, 5) = ac4.class_code
    LEFT JOIN sources.atc_codes ac5 ON ed.ATC = ac5.class_code

order by concept_id, EXISTENT_MAPPING DESC;



---- Multiing mapped on two ATC codes inside the same 4th lvl, one of which has 'comb' or 'var' in it's name.
WITH expanded_data as(
WITH grouped_data AS (
    SELECT
           c2.concept_id,
           c2.concept_name,
           COUNT(DISTINCT c1.concept_code) AS code_count,
           STRING_AGG(DISTINCT c1.concept_code, ',') AS ATC
    FROM dev_atatur.concept_relationship cr
            JOIN dev_atatur.concept c1 ON cr.concept_id_1 = c1.concept_id
                                  AND c1.vocabulary_id = 'ATC'
                                  AND c1.invalid_reason IS NULL
                                  AND cr.invalid_reason IS NULL
                                  AND cr.relationship_id = 'ATC - RxNorm'
            JOIN dev_atatur.concept c2 ON cr.concept_id_2 = c2.concept_id
                                  AND c2.invalid_reason IS NULL
                                  AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                                  AND c2.concept_class_id = 'Clinical Drug Form'
            JOIN dev_atatur.concept_relationship cr2 ON c2.concept_id = cr2.concept_id_1
                                                     AND cr2.invalid_reason IS NULL
                                                     AND cr2.relationship_id = 'RxNorm has ing'
    GROUP BY c2.concept_id, c2.concept_name
    HAVING
        COUNT(DISTINCT c1.concept_code) > 1
        --AND COUNT(DISTINCT cr2.concept_id_2) = 2
        AND COUNT(DISTINCT LEFT(c1.concept_code, 5)) = 1
        AND EXISTS (
            SELECT 1
            FROM sources.atc_codes sub_ac
            WHERE sub_ac.class_code = ANY(STRING_TO_ARRAY(STRING_AGG(DISTINCT c1.concept_code, ','), ','))
              AND (sub_ac.class_name ILIKE '%combination%' OR sub_ac.class_name ILIKE '%various%')
        )
)
SELECT
    concept_id,
    concept_name,
    code_count,
    UNNEST(STRING_TO_ARRAY(ATC, ',')) AS ATC
FROM grouped_data)
SELECT
    DISTINCT ed.concept_id,
    ed.concept_name,
    --ed.code_count,
    LEFT(ed.ATC, 1) as "1st level code",
    ac1.class_name AS "1st level name",
    LEFT(ed.ATC, 3) as "2nd level code",
    ac2.class_name AS "2nd level name",
    LEFT(ed.ATC, 4) as "3rd level code",
    ac3.class_name AS "3rd level name",
    LEFT(ed.ATC, 5) as "4th level code",
    ac4.class_name AS "4th level name",
    ed.ATC as "5th level code",
    ac5.class_name AS "5th level name"
FROM expanded_data ed
LEFT JOIN sources.atc_codes ac1 ON LEFT(ed.ATC, 1) = ac1.class_code
LEFT JOIN sources.atc_codes ac2 ON LEFT(ed.ATC, 3) = ac2.class_code
LEFT JOIN sources.atc_codes ac3 ON LEFT(ed.ATC, 4) = ac3.class_code
LEFT JOIN sources.atc_codes ac4 ON LEFT(ed.ATC, 5) = ac4.class_code
LEFT JOIN sources.atc_codes ac5 ON ed.ATC = ac5.class_code
order by concept_id;

---- Check where mapped ings using ATC - RxNorm pr lat
WITH CTE as (SELECT DISTINCT c2.concept_id,
       c2.concept_name,
       c1.concept_code
FROM devv5.concept_relationship cr
     join devv5.concept c1 on cr.concept_id_1 = c1.concept_id
                            and c1.vocabulary_id = 'ATC'
                            and c1.invalid_reason is NULL
                            and cr.invalid_reason is NULL
                            and cr.relationship_id = 'ATC - RxNorm pr lat'
     join devv5.concept c2 on cr.concept_id_2 = c2.concept_id
                            and c2.invalid_reason is NULL
                            and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')),
    comb as (
            select
                    left(class_code,5) as up_level,
                    class_code as down_level,
                    class_name
                from sources.atc_codes
                where length(class_code) = 7
                and class_name ~ 'comb|various')

SELECT
    concept_id,
    concept_name,
--     LEFT(ed.concept_code, 1) as "1st level code",
--     ac1.class_name AS "1st level name",
--     LEFT(ed.concept_code, 3) as "2nd level code",
--     ac2.class_name AS "2nd level name",
--     LEFT(ed.concept_code, 4) as "3rd level code",
--     ac3.class_name AS "3rd level name",
--     LEFT(ed.concept_code, 5) as "4th level code",
--     ac4.class_name AS "4th level name",
    string_to_array(string_agg(ed.concept_code, ','),',') as mapped_to_codes,
    string_agg(ac5.class_name, ',') as mapped_to_names,
     CASE
           WHEN ARRAY(SELECT UNNEST(string_to_array(string_agg(DISTINCT t6.DOWN_LEVEL, ','), ',')) EXCEPT SELECT UNNEST(string_to_array(string_agg(ed.concept_code, ','),','))) = '{}'::text[]
           THEN 1
           ELSE 0
       END AS all_elements_match,

    string_to_array(string_agg(DISTINCT t6.DOWN_LEVEL, ','), ',') as comb_codes,
    string_agg(t6.class_name, ',') as comb_names
FROM CTE ed
        LEFT JOIN sources.atc_codes ac1 ON LEFT(ed.concept_code, 1) = ac1.class_code
        LEFT JOIN sources.atc_codes ac2 ON LEFT(ed.concept_code, 3) = ac2.class_code
        LEFT JOIN sources.atc_codes ac3 ON LEFT(ed.concept_code, 4) = ac3.class_code
        LEFT JOIN sources.atc_codes ac4 ON LEFT(ed.concept_code, 5) = ac4.class_code
        LEFT JOIN sources.atc_codes ac5 ON ed.concept_code = ac5.class_code
        LEFT JOIN COMB t6 ON LEFT(ed.concept_code, 5) = t6.UP_LEVEL
WHERE DOWN_LEVEL is NOT null
GROUP BY concept_id, concept_name
ORDER BY concept_id;


-----------------------

-----------------------
--- Check what new connections appeared after update for specific ATC codes from Marcel.
select c1.concept_code,
       c1.concept_name,
       c2.concept_id,
       c2.concept_name
from dev_atc.concept_relationship cr
        join dev_atc.concept c1 on cr.concept_id_1 = c1.concept_id
                                and cr.relationship_id = 'ATC - RxNorm'
                                and cr.invalid_reason is NULL
                                and c1.vocabulary_id = 'ATC'
                                and c1.concept_code in ('B01AC06','N02BA01', 'G03FA11', 'G03AA07', 'A06AD10', 'R03BA05', 'G03CA01', 'N02BA15',
                                                        'M01AE18', 'R02AX02', 'C05AA01', 'R03BA09', 'J07BN01', 'D07AB11', 'D07AC16', 'C05AA12',
                                                        'J07BX03', 'R03AK06', 'D01AC20', 'D07XA01', 'D09AA02', 'R03BA07', 'S03AA30', 'N02AJ09',
                                                        'A07XA03', 'A12AA20', 'A11CC55', 'C07AB11', 'V04CX02', 'S02AA30', 'N02BE51', 'C05AA05',
                                                        'R01AD12', 'N02AA59', 'R01AB06', 'N02BF02', 'N03AX16', 'S03AA08', 'G01AF04', 'S03CA01',
                                                        'R01AD08', 'V04CA01', 'A10AD05', 'A10AD02', 'L02AB02', 'S02CA03', 'B03BA51', 'N02BA01',
                                                        'G03AA08', 'G03AB03', 'R03BA09', 'A06AD10', 'A06AD65', 'R01AD12', 'R03BA05', 'N02BA15',
                                                        'L02AA03', 'G03CA01', 'S01BA05', 'M01AE18', 'R02AX02', 'D07AB30', 'D07XB30', 'R01AD08',
                                                        'S01CB03', 'A07AE02', 'S01BA02', 'A01AC03', 'D07AB11', 'D07AC16', 'C05AA01', 'J07BX03',
                                                        'A07EA01', 'R01AD11', 'A01AC01', 'C05AA12', 'R01AD02')
        join dev_atc.concept c2 on cr.concept_id_2 = c2.concept_id
                                and c2.concept_class_id = 'Clinical Drug Form'
                                and c2.invalid_reason is NULL
where (cr.concept_id_1, cr.concept_id_2) not in (select cr.concept_id_1, cr.concept_id_2
                                                    from dev_dev.concept_relationship cr
                                                            join dev_dev.concept c1 on cr.concept_id_1 = c1.concept_id
                                                                                    and cr.relationship_id = 'ATC - RxNorm'
                                                                                    and cr.invalid_reason is NULL
                                                                                    and c1.vocabulary_id = 'ATC'
                                                                                    and c1.concept_code IN ('B01AC06','N02BA01', 'G03FA11', 'G03AA07', 'A06AD10', 'R03BA05', 'G03CA01', 'N02BA15',
                                                                                                            'M01AE18', 'R02AX02', 'C05AA01', 'R03BA09', 'J07BN01', 'D07AB11', 'D07AC16', 'C05AA12',
                                                                                                            'J07BX03', 'R03AK06', 'D01AC20', 'D07XA01', 'D09AA02', 'R03BA07', 'S03AA30', 'N02AJ09',
                                                                                                            'A07XA03', 'A12AA20', 'A11CC55', 'C07AB11', 'V04CX02', 'S02AA30', 'N02BE51', 'C05AA05',
                                                                                                            'R01AD12', 'N02AA59', 'R01AB06', 'N02BF02', 'N03AX16', 'S03AA08', 'G01AF04', 'S03CA01',
                                                                                                            'R01AD08', 'V04CA01', 'A10AD05', 'A10AD02', 'L02AB02', 'S02CA03', 'B03BA51', 'N02BA01',
                                                                                                            'G03AA08', 'G03AB03', 'R03BA09', 'A06AD10', 'A06AD65', 'R01AD12', 'R03BA05', 'N02BA15',
                                                                                                            'L02AA03', 'G03CA01', 'S01BA05', 'M01AE18', 'R02AX02', 'D07AB30', 'D07XB30', 'R01AD08',
                                                                                                            'S01CB03', 'A07AE02', 'S01BA02', 'A01AC03', 'D07AB11', 'D07AC16', 'C05AA01', 'J07BX03',
                                                                                                            'A07EA01', 'R01AD11', 'A01AC01', 'C05AA12', 'R01AD02')
                                                            join dev_dev.concept c2 on cr.concept_id_2 = c2.concept_id
                                                                                    and c2.concept_class_id = 'Clinical Drug Form');



SELECT t2.concept_code,
       t2.concept_name,
       t3.concept_id,
       t3.concept_name
FROM devv5.concept_ancestor t1
        JOIN devv5.concept t2 on t1.ancestor_concept_id = t2.concept_id
                                    and t1.ancestor_concept_id in  (21600541,21600544,21600552)
        JOIN devv5.concept t3 on t1.descendant_concept_id = t3.concept_id
                                    and t3.concept_class_id = 'Clinical Drug Form'
                                    and t3.concept_id = 588466;


------ RxN API
CREATE TABLE rxnav_api_test as
(
WITH CTE AS (
WITH CTE AS (
    SELECT
        c2.concept_id,
        STRING_AGG(DISTINCT c1.concept_code, ',') AS ATC
    FROM dev_atatur.concept_relationship cr
    JOIN dev_atatur.concept c1
        ON cr.concept_id_1 = c1.concept_id
        AND c1.vocabulary_id = 'ATC'
        AND c1.invalid_reason IS NULL
        AND cr.invalid_reason IS NULL
        AND cr.relationship_id = 'ATC - RxNorm'
    JOIN dev_atatur.concept c2
        ON cr.concept_id_2 = c2.concept_id
        AND c2.invalid_reason IS NULL
        AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
        AND c2.concept_class_id = 'Clinical Drug Form'
    GROUP BY c2.concept_id
)
SELECT t1.*,
       t2.ATC AS existent_atc
FROM dev_atatur.rxn_api_cui_to_atc4 t1
LEFT JOIN CTE t2
    ON t1.concept_id = t2.concept_id
WHERE
    -- Include rows where t2.ATC is NULL
    t2.ATC IS NULL
    -- Or rows where t2.ATC contains a comma
    OR t2.ATC LIKE '%,%'
    -- Or rows where the first five characters of t1.atc do not match the first five of t2.ATC
    OR t1.atc != LEFT(t2.ATC, 5)
ORDER BY atc)
SELECT concept_id,
       concept_code,
       concept_name,
       atc as RxNavApi,
       unnest(string_to_array(EXISTENT_ATC,',')) as existent_atc
FROM CTE )

UNION

(WITH CTE AS (
WITH CTE AS (
    SELECT
        c2.concept_id,
        STRING_AGG(DISTINCT c1.concept_code, ',') AS ATC
    FROM dev_atatur.concept_relationship cr
    JOIN dev_atatur.concept c1
        ON cr.concept_id_1 = c1.concept_id
        AND c1.vocabulary_id = 'ATC'
        AND c1.invalid_reason IS NULL
        AND cr.invalid_reason IS NULL
        AND cr.relationship_id = 'ATC - RxNorm'
    JOIN dev_atatur.concept c2
        ON cr.concept_id_2 = c2.concept_id
        AND c2.invalid_reason IS NULL
        AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
        AND c2.concept_class_id = 'Clinical Drug Form'
    GROUP BY c2.concept_id
)
SELECT t1.*,
       t2.ATC AS existent_atc
FROM dev_atatur.rxn_api_cui_to_atc4 t1
LEFT JOIN CTE t2
    ON t1.concept_id = t2.concept_id
WHERE
    -- Include rows where t2.ATC is NULL
    t2.ATC IS NULL
    -- Or rows where t2.ATC contains a comma
    OR t2.ATC LIKE '%,%'
    -- Or rows where the first five characters of t1.atc do not match the first five of t2.ATC
    OR t1.atc != LEFT(t2.ATC, 5)
ORDER BY atc)

SELECT *
FROM CTE
WHERE EXISTENT_ATC IS NULL)

;

SELECT * FROM rxnav_api_test;


----- ALL RXN with more then 5 ATC codes
WITH CTE as (select c1.concept_id as rxn_c_id,
       c1.concept_code as rxn_c_c,
       c1.concept_name as rxn_c_n,
       count (c1.concept_id) as rxn_cnt,
       string_agg(c2.concept_id::TEXT, '|') as atc_c_id,
       string_agg(c2.concept_code, '|') as atc_c_c,
       string_agg(c2.concept_name, '|') as atc_c_n
from devv5.concept_relationship cr
     join devv5.concept c1 on cr.concept_id_2 = c1.concept_id
                     and cr.relationship_id = 'ATC - RxNorm'
                     and c1.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                     and c1.invalid_reason is NULL
                     and cr.invalid_reason is NULL
     join devv5.concept c2 on cr.concept_id_1 = c2.concept_id
                     and c2.vocabulary_id = 'ATC'
                     and c2.invalid_reason is NULL
GROUP BY c1.concept_id, c1.concept_code, c1.concept_name having count (c1.concept_id) > 5),
CTE2 as (
SELECT RXN_C_ID,
       RXN_C_C,
       RXN_C_N,
       rxn_cnt,
       unnest(string_to_array(ATC_C_ID,'|')) as ATC_C_ID,
       unnest(string_to_array(ATC_C_C,'|')) as ATC_C_C_5th,
       unnest(string_to_array(ATC_C_N,'|')) as ATC_C_N_5th
FROM CTE)
SELECT t1.*,
       t2.concept_code as ATC_C_C_4th,
       t2.concept_name as ATC_C_N_4th,
       t3.concept_code as ATC_C_C_3rd,
       t3.concept_name as ATC_C_N_3rd,
       t4.concept_code as ATC_C_C_2nd,
       t4.concept_name as ATC_C_N_2nd,
       t5.concept_code as ATC_C_C_1st,
       t5.concept_name as ATC_C_N_1st
FROM CTE2 as t1
        join devv5.concept t2 on left(t1.ATC_C_C_5TH, 5) = t2.concept_code
                     and t2.vocabulary_id = 'ATC' and t2.invalid_reason is NULL
        join devv5.concept t3 on left(t1.ATC_C_C_5TH, 4) = t3.concept_code
                             and t3.vocabulary_id = 'ATC' and t3.invalid_reason is NULL
        join devv5.concept t4 on left(t1.ATC_C_C_5TH, 3) = t4.concept_code
                             and t4.vocabulary_id = 'ATC' and t4.invalid_reason is NULL
        join devv5.concept t5 on left(t1.ATC_C_C_5TH, 1) = t5.concept_code
                             and t5.vocabulary_id = 'ATC' and t5.invalid_reason is NULL
order by rxn_cnt desc,
         RXN_C_ID asc,
         ATC_C_C_5TH asc;




---------- New rxnorm concepts without ATC connections (dev_dev - devv5)
----- ings connections (ATC - RxNorm pr lat, pr up e.t.c.)
SELECT t1.concept_id as id_rx,
       t1.concept_code as code_rx,
       t1.concept_name as name_rx
FROM devv5.concept t1
where t1.vocabulary_id = 'RxNorm'
      and invalid_reason is NULL
      and t1.concept_class_id = 'Ingredient'
      and NOT EXISTS(SELECT 1
                     FROM dev_dev.concept t2
                     WHERE
                         t2.vocabulary_id = 'RxNorm'
                         and t2.concept_class_id = 'Ingredient'
                         and t1.concept_id = t2.concept_id
                         and t2.invalid_reason is NULL);
----- clinical drug forms connections (ATC - RxNorm)
SELECT t1.concept_id as id_rx,
       t1.concept_code as code_rx,
       t1.concept_name as name_rx
FROM devv5.concept t1
where t1.vocabulary_id = 'RxNorm'
      and invalid_reason is NULL
      and t1.concept_class_id = 'Clinical Drug Form'
      and NOT EXISTS(SELECT 1
                     FROM dev_dev.concept t2
                     WHERE
                         t2.vocabulary_id = 'RxNorm'
                         and t2.concept_class_id = 'Clinical Drug Form'
                         and t1.concept_id = t2.concept_id
                         and t2.invalid_reason is NULL);




----- List of all cases where MonoDrugs binded to Combination Classes
SELECT
    t2.concept_code,
    t2.concept_name,
    t4.concept_id,
    t4.concept_name,
    count (t3.concept_id_2) as n_ings
FROM dev_atc.concept_relationship t1
     join dev_atc.concept t2 on t1.concept_id_1 = t2.concept_id and t1.relationship_id = 'ATC - RxNorm'
                                                                and t2.vocabulary_id = 'ATC'
                                                                and t1.invalid_reason is NULL
                                                                and t2.invalid_reason is NULL
                                                                and (t2.concept_name LIKE '%combinations%' or t2.concept_name LIKE '% and %')
    join dev_atc.concept t4 on t1.concept_id_2 = t4.concept_id and t4.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                and t4.invalid_reason is NULL
    join dev_atc.concept_relationship t3 on t1.concept_id_2 = t3.concept_id_1 and t3.relationship_id = 'RxNorm has ing'
                                                                                and t3.invalid_reason is NULL
GROUP BY t2.concept_code, t2.concept_name, t4.concept_id, t4.concept_name having count (t3.concept_id_2) = 1;




------ Compare number of connections per 1 rxnorm code from in dev_atc:
------ concept_relationship 2.11
(WITH CTE AS (
    SELECT
        t1.concept_id,
        t1.concept_name,
        COUNT(DISTINCT t3.concept_code) AS cnt
    FROM dev_atc.concept t1
    JOIN dev_atc.concept_relationship t2
        ON t1.concept_id = t2.concept_id_2
       AND t1.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
       AND t1.concept_class_id = 'Clinical Drug Form'
       AND t1.invalid_reason IS NULL
       AND t2.relationship_id = 'ATC - RxNorm'
       AND t2.invalid_reason IS NULL
    JOIN dev_atc.concept t3
        ON t2.concept_id_1 = t3.concept_id
       AND t3.vocabulary_id = 'ATC'
       AND t3.invalid_reason IS NULL
    GROUP BY t1.concept_id, t1.concept_name
    ORDER BY COUNT(DISTINCT t3.concept_code) DESC
)
SELECT
    'concept_relationship_dev_atc' as src,
    SUM(cnt) / COUNT(*) AS avg_atc_p_rxn,
    MAX(cnt) AS max,
    MIN(cnt) AS min,
    100.0 * SUM(CASE WHEN cnt = 1 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_eq_1,
    100.0 * SUM(CASE WHEN cnt > 2 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_gt_2,
    100.0 * SUM(CASE WHEN cnt > 5 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_gt_5,
    100.0 * SUM(CASE WHEN cnt > 10 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_gt_10
FROM CTE)

UNION
--- ancestor - 1.62
(WITH CTE as (SELECT t3.concept_id,
       t3.concept_name,
       count (t1.concept_code) as cnt
FROM dev_atc.concept t1
     join dev_atc.concept_ancestor t2 on t1.concept_id = t2.ancestor_concept_id
                                         and t1.vocabulary_id = 'ATC'
                                         and t1.invalid_reason is NULL
                                         and length(t1.concept_code) = 7
     join dev_atc.concept t3 on t2.descendant_concept_id = t3.concept_id
                                        and t3.vocabulary_id in ('RxNorm','RxNorm Extension')
                                        and t3.invalid_reason is NULL
                                        and t3.concept_class_id = 'Clinical Drug Form'
GROUP BY t3.concept_id, t3.concept_name
ORDER BY count (t1.concept_code) desc)
SELECT
    'concept_ancestor_dev_atc' as src,
    SUM(cnt) / COUNT(*) AS avg_atc_p_rxn,
    MAX(cnt) AS max,
    MIN(cnt) AS min,
    100.0 * SUM(CASE WHEN cnt = 1 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_eq_1,
    100.0 * SUM(CASE WHEN cnt > 2 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_gt_2,
    100.0 * SUM(CASE WHEN cnt > 5 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_gt_5,
    100.0 * SUM(CASE WHEN cnt > 10 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_gt_10
FROM CTE t1)

UNION
---- devv5

(WITH CTE AS (
    SELECT
        t1.concept_id,
        t1.concept_name,
        COUNT(DISTINCT t3.concept_code) AS cnt
    FROM devv5.concept t1
    JOIN devv5.concept_relationship t2
        ON t1.concept_id = t2.concept_id_2
       AND t1.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
       AND t1.concept_class_id = 'Clinical Drug Form'
       AND t1.invalid_reason IS NULL
       AND t2.relationship_id = 'ATC - RxNorm'
       AND t2.invalid_reason IS NULL
    JOIN devv5.concept t3
        ON t2.concept_id_1 = t3.concept_id
       AND t3.vocabulary_id = 'ATC'
       AND t3.invalid_reason IS NULL
    GROUP BY t1.concept_id, t1.concept_name
    ORDER BY COUNT(DISTINCT t3.concept_code) DESC
)
SELECT
    'concept_relationship_devv5' as src,
    SUM(cnt) / COUNT(*) AS avg_atc_p_rxn,
    MAX(cnt) AS max,
    MIN(cnt) AS min,
    100.0 * SUM(CASE WHEN cnt = 1 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_eq_1,
    100.0 * SUM(CASE WHEN cnt > 2 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_gt_2,
    100.0 * SUM(CASE WHEN cnt > 5 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_gt_5,
    100.0 * SUM(CASE WHEN cnt > 10 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_gt_10
FROM CTE)

UNION
--- ancestor - 1.62
(WITH CTE as (SELECT t3.concept_id,
       t3.concept_name,
       count (t1.concept_code) as cnt
FROM devv5.concept t1
     join devv5.concept_ancestor t2 on t1.concept_id = t2.ancestor_concept_id
                                         and t1.vocabulary_id = 'ATC'
                                         and t1.invalid_reason is NULL
                                         and length(t1.concept_code) = 7
     join devv5.concept t3 on t2.descendant_concept_id = t3.concept_id
                                        and t3.vocabulary_id in ('RxNorm','RxNorm Extension')
                                        and t3.invalid_reason is NULL
                                        and t3.concept_class_id = 'Clinical Drug Form'
GROUP BY t3.concept_id, t3.concept_name
ORDER BY count (t1.concept_code) desc)
SELECT
    'concept_ancestor_devv5' as src,
    SUM(cnt) / COUNT(*) AS avg_atc_p_rxn,
    MAX(cnt) AS max,
    MIN(cnt) AS min,
    100.0 * SUM(CASE WHEN cnt = 1 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_eq_1,
    100.0 * SUM(CASE WHEN cnt > 2 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_gt_2,
    100.0 * SUM(CASE WHEN cnt > 5 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_gt_5,
    100.0 * SUM(CASE WHEN cnt > 10 THEN 1 ELSE 0 END) / COUNT(*) AS percent_cnt_gt_10
FROM CTE t1);