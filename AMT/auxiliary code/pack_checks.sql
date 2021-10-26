-- check pack uniqueness, pack_code duplicates are possible in source,
-- but not allowed in pc_stage.
SELECT pack_code, concept_code, count(*)
FROM pc_0_initial
GROUP BY (pack_code, concept_code)
HAVING count(*) > 1;


-- AMPERSAND_SEP CHECKS

-- should be empty
-- check for packs from pc_0_initial that aren't in pc_1_ampersand_sep
SELECT *
FROM pc_0_initial pc0
WHERE pc0.pack_name LIKE '%(&)%'
  AND pack_code NOT IN (
                       SELECT DISTINCT pack_code
                       FROM pc_1_ampersand_sep
                       );


-- should be empty
-- get ampersand_sep packs that didn't find their way to pc_2
SELECT *
FROM pc_1_ampersand_sep pc1
WHERE pc1.pack_code NOT IN (
                           SELECT pack_code
                           FROM pc_2_ampersand_sep_amount
                           );


-- different count of constituents in pc_1_ampersand and pc_2_ampersand for same packs
-- may return some drugs. In case pack contains several identical drugs.
-- make sure that it is the case
SELECT DISTINCT pack_code, pack_name, concept_name, concept_code, pack_comp, amount, source
FROM pc_2_ampersand_sep_amount
WHERE pack_code IN (
                   SELECT pc.pack_code
                   FROM pc_2_ampersand_sep_amount pc
                   GROUP BY pc.pack_code
                   HAVING count(pc.pack_code) <> (
                                                 SELECT count(pack_code)
                                                 FROM (
                                                      SELECT DISTINCT pc1.pack_code,
                                                                      pc1.concept_code
                                                      FROM pc_1_ampersand_sep pc1
                                                      ) t
                                                 WHERE pack_code = pc.pack_code
                                                 )
                   )
  AND pack_code NOT IN (
                       SELECT pack_code
                       FROM pc_identical_drugs
                       )
  AND pack_code NOT IN (
                       SELECT pack_code
                       FROM pc_wrong
                       );


-- should be empty
-- amount is NULL in pc_2_ampersand
SELECT *
FROM pc_2_ampersand_sep_amount
WHERE amount IS NULL;



-- COMMA_SEP CHECKS

-- should be empty
-- check for packs from pc_0_initial that aren't in pc_1_comma_sep
SELECT *
FROM pc_0_initial
WHERE pack_code NOT IN (
                       SELECT pack_code
                       FROM pc_1_ampersand_sep
                       )
  AND pack_code NOT IN (
                       SELECT pack_code
                       FROM pc_1_comma_sep
                       );


SELECT *
FROM pc_2_comma_sep_amount
WHERE pack_code IN (
                   SELECT pack_code
                   FROM pc_2_comma_sep_amount pc2_1
                   GROUP BY(pack_code)
                   HAVING count(*) <> (
                                      SELECT count(pack_code)
                                      FROM (
                                           SELECT DISTINCT pack_code, concept_code
                                           FROM pc_2_comma_sep_amount
                                           ) t
                                      WHERE pc2_1.pack_code = t.pack_code
                                      )
                   );


-- Do not proceed until the following query returns empty result.
-- If not - add corresponding amounts for constituents into pc_2_comma_sep_amount_insertion manually (query is located above)
-- get constituents from pc_1_comma_sep which have the same max intersection count for several pack_components.
WITH tab AS (
            SELECT pack_code, concept_code, max(intersection) AS intersection
            FROM comma_sep_intersection_check
            GROUP BY pack_code, concept_code
            )
SELECT ic.pack_code, ic.pack_name, ic.concept_name, ic.concept_code, ic.intersection
FROM tab t
JOIN comma_sep_intersection_check ic
    ON t.pack_code = ic.pack_code
        AND t.concept_code = ic.concept_code
        AND t.intersection = ic.intersection
GROUP BY ic.pack_code, ic.pack_name, ic.concept_name, ic.concept_code, ic.intersection
HAVING count(*) > 1;


SELECT *
from comma_sep_intersection_check;




-- should be empty
-- pc_1_comma_sep that didn't find their way to pc_2;
SELECT DISTINCT pc1.pack_code,
                pc1.pack_name,
                pc1.concept_name,
                pc1.concept_code,
                pc1.pack_comp
FROM pc_1_comma_sep pc1
WHERE pc1.pack_code NOT IN (
                           SELECT pack_code
                           FROM pc_2_comma_sep_amount
                           );



-- get packs where some of the constituent drugs have not been matched
/*count of constituents in pc_2_comma_sep_amount differs from count of constituents in pc_1_comma_sep*/
SELECT *
FROM pc_2_comma_sep_amount
WHERE pack_code IN (
                   SELECT pc.pack_code
                   FROM pc_2_comma_sep_amount pc
                   GROUP BY pc.pack_code
                   HAVING count(pc.pack_code) <> (
                                                 SELECT count(pack_code)
                                                 FROM (
                                                      SELECT DISTINCT pc1.pack_code,
                                                                      pc1.concept_code
                                                      FROM pc_1_comma_sep pc1
                                                      ) t
                                                 WHERE pack_code = pc.pack_code
                                                 )
                   );


-- get pc2_ampersand_sep for review
/*SELECT pack_code, concept_code, pack_name, concept_name, pack_comp, amount, source
FROM pc_2_ampersand_sep_amount
ORDER BY pack_code;*/


-- get pc2_comma_sep for review
/*SELECT pack_code, concept_code, pack_name, concept_name, pack_comp, amount
FROM pc_2_comma_sep_amount
ORDER BY pack_code;*/



SELECT *
FROM pc_identical_drugs;


SELECT *
FROM drug_concept_stage dcs
WHERE dcs.concept_class_id = 'Brand Name';

SELECT *
FROM concept_stage_sn
where concept_class_id ='Trade Product';