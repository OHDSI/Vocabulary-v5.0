/**************************************************************************
    this script collects ATC - RxNorm connections FROM different sources
**************************************************************************/

    /* Sources for building table

       1. dm+d - https://github.com/OHDSI/Vocabulary-v5.0/blob/master/dmd/load_stage.sql#L445
       2. BDPM - https://github.com/OHDSI/Vocabulary-v5.0/tree/master/BDPM + Manual table, that contains ATC codes, builded on data from official site https://base-donnees-publique.medicaments.gouv.fr/telechargement.php
       3. GRR - https://github.com/OHDSI/Vocabulary-v5.0/tree/master/GRR
       4. UMLS - https://github.com/OHDSI/Vocabulary-v5.0/tree/master/UMLS
       5. VANDF -https://github.com/OHDSI/Vocabulary-v5.0/tree/master/VANDF
       6. JMDC - https://github.com/OHDSI/Vocabulary-v5.0/tree/master/JMDC
       7. Z-index - proprietary source
       8. Norske Drug  - Manual table, that was builded from https://www.legemiddelsok.no/ and it's processing in BuildRXE.
       9. KDC - Manual table.

     */

-- DROP TABLE IF EXISTS dmd2atc;
-- CREATE TABLE IF NOT EXISTS dmd2atc AS
-- SELECT unnest(xpath('/VMP/VPID/text()', i.xmlfield))::VARCHAR VPID,
-- 	unnest(xpath('/VMP/ATC/text()', i.xmlfield))::VARCHAR ATC
-- FROM (
-- 	SELECT unnest(xpath('/BNF_DETAILS/VMPS/VMP', i.xmlfield)) xmlfield
-- 	FROM sources.dmdbonus i
-- 	) AS i;

--1. Create temporary table to store source data to ATC relationships
DROP TABLE IF EXISTS class_atc_rxn_huge_temp;
CREATE TABLE class_ATC_RXN_huge_temp AS   -- without ancestor
    SELECT
            source,
            c.concept_id as concept_id,
            c.concept_name,
            c.concept_class_id,
            atc.class_code,
            atc.class_name
    FROM

            (SELECT
                *
            FROM
                    ------dm+d------
            (
                WITH base as (SELECT t1.concept_id,
                       t1.concept_name,
                       t3.class_code,
                       t3.class_name
                FROM
                    (
                        SELECT *
                        FROM devv5.concept
                        WHERE concept_code in (SELECT vpid
                        FROM dev_atc.dmd2atc
                        WHERE length(atc) = 7)
                        AND vocabulary_id = 'dm+d') t1
                    JOIN
                    (   SELECT *
                        FROM dev_atc.dmd2atc -- TODO: can be transferred to sources
                        WHERE length(atc) = 7) t2 on concept_code = vpid
                    JOIN
                        sources.atc_codes t3 on t2.atc = t3.class_code)
            SELECT
                t1.concept_id_2::int as concept_id,
                base.class_code as class_code,
                'dmd' as source
            FROM devv5.concept_relationship t1
                     JOIN base on t1.concept_id_1 = base.concept_id
                     JOIN devv5.concept t2 on t1.concept_id_2 = t2.concept_id
            WHERE t1.relationship_id = 'Maps to'
                     AND t2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
            ) t1

            UNION


                    ------BDPM------
             (SELECT t4.concept_id,
                     t2.atc_code,
                     'BDPM' as source
              FROM sources.bdpm_packaging t1
                       JOIN dev_atc.bdpm_atc_codes t2 on t1.drug_code = t2.id::VARCHAR --TODO: In future, scraper could be transferred to sources
                       JOIN devv5.concept t3 on t1.din_7::VARCHAR = t3.concept_code AND t3.vocabulary_id = 'BDPM'
                       JOIN devv5.concept_relationship cr
                            on cr.concept_id_1 = t3.concept_id AND cr.relationship_id = 'Maps to'
                       JOIN devv5.concept t4 on cr.concept_id_2 = t4.concept_id AND t4.invalid_reason is Null AND
                                                t4.stANDard_concept = 'S')

            UNION


                    ------GRR-------
            (with base_up as(
            with base as(SELECT
                    CASE
                     WHEN product_launch_date IS NULL THEN CAST(fcc AS VARCHAR)
                     ELSE fcc || '_' || TO_CHAR(TO_DATE(product_launch_date,'dd.mm.yyyy'),'mmddyyyy')
                   END AS concept_code,
                   therapy_name,
                   who_atc5_code
            FROM dev_grr.source_data
            WHERE (length(who_atc5_code) = 7 AND who_atc5_code != '???????' AND who_atc5_code not like '%..'))

            SELECT  t1.concept_id,
                    t1.concept_code,
                    t1.concept_name,
                   t2.therapy_name,
                   t2.who_atc5_code as who_atc5_code
            FROM devv5.concept t1
            JOIN base t2 on t1.concept_code = t2.concept_code
            WHERE t1.vocabulary_id = 'GRR')
            SELECT
                t1.concept_id_2::int as concept_id,
                base_up.who_atc5_code as class_code,
                'grr' as source
            FROM
                devv5.concept_relationship t1
                JOIN base_up on t1.concept_id_1 = base_up.concept_id
                JOIN concept t2 on t1.concept_id_2 = t2.concept_id
            WHERE
                t1.relationship_id = 'Maps to'
                AND t2.vocabulary_id in ('RxNorm', 'RxNorm Extension'))

            UNION
            
            
                    ------UMLS------
            (SELECT
                t3.concept_id::int as concept_id,
                t1.code as class_code,
                'umls' as source --||t4.sab as source
            FROM
                   sources.rxnrel main
                   JOIN sources.rxnconso t1 on main.rxcui1=t1.rxcui
                   JOIN sources.rxnconso t2 on main.rxcui2=t2.rxcui
                   JOIN devv5.concept t3 on t2.code = t3.concept_code
                   --JOIN sources.rxnconso t4 on t4.rxcui = t2.rxcui AND t4.sab != t2.sab
            WHERE t1.sab = 'ATC'
            AND length(t1.code) = 7
            AND t2.sab = 'RXNORM'
            AND t3.vocabulary_id = 'RxNorm')

            UNION


                    ------VANDF------
            (
                SELECT
                       t5.concept_id::int,
                       t2.code,
                       'VANDF' as source
                FROM sources.rxnrel t1
                     JOIN sources.rxnconso t2 on t1.rxcui1 = t2.rxcui
                     JOIN sources.rxnconso t3 on t1.rxcui2 = t3.rxcui
                     JOIN devv5.concept t4 on t3.code = t4.concept_code AND t4.vocabulary_id = 'VANDF'
                     JOIN devv5.concept_relationship cr on cr.concept_id_1 = t4.concept_id AND cr.relationship_id = 'Maps to'
                     JOIN devv5.concept t5 on cr.concept_id_2 = t5.concept_id
                WHERE t2.sab = 'ATC'
                  AND length(t2.code) = 7
                  AND t3.sab = 'VANDF'

            )

            UNION


                    ------JMDC------
            (
            SELECT
                   c.concept_id,
                   t2.who_atc_code,
                   'jmdc' as source
            FROM devv5.concept t1
                JOIN dev_jmdc.jmdc t2 on t1.concept_code = t2.jmdc_drug_code
                JOIN devv5.concept_relationship cr on cr.concept_id_1 = t1.concept_id
                JOIN devv5.concept c on cr.concept_id_2 = c.concept_id

            WHERE t1.concept_code in (SELECT jmdc_drug_code
                                      FROM dev_jmdc.jmdc
                                      WHERE length(who_atc_code) = 7)
            AND t1.vocabulary_id = 'JMDC'
            AND length(t2.who_atc_code) = 7
            AND cr.relationship_id = 'Maps to'
            AND c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
             )


--The following sources are excluded FROM the data collection due to multiple mistakenly assigned ATC codes

--             UNION
--
--                 (
--                     SELECT
--                         distinct t3.code::int, t1.code,
--                                  'Other' as sources
--                         --t1.str,
--                         --t3.str
--                     FROM sources.rxnrel rel
--                          JOIN sources.rxnconso t1 on rel.rxcui1 = t1.rxcui
--                          JOIN sources.rxnconso t2 on rel.rxcui2 = t2.rxcui AND t2.sab in ('DRUGBANK','USP','MTHSPL','MMX','MMSL','GS','NDDF','SNOMEDCT_US')
--                          JOIN sources.rxnrel rel2 on rel2.rxcui1 = t2.rxcui
--                          JOIN sources.rxnconso t3 on rel2.rxcui2 = t3.rxcui
--                     WHERE
--                         t1.sab = 'ATC'
--                         AND length (t1.code) = 7
--                         AND t3.sab = 'RXNORM'
--
--              )

            UNION


                    ------Z-index------
                (
--                     SELECT concept_id, class_code, 'z-index' as source
--                         FROM dev_atc.z_index

                    SELECT targetid, atc, 'z-index' as source
                      FROM dev_atc.zindex_full      --TODO: Proprietary data

                    )

            UNION


                    ------Norske Drug Bank------   --TODO: Manual table
            (
                SELECT rx_ids,
                       atc_code,
                       'Norway' as source
                FROM dev_atc.norske_result
            )

            UNION


                    ------KDC------
                (
                    SELECT
                        t3.concept_id,
                        atc.concept_code_2,
                        'KDC'
                    FROM
                        dev_atc.kdc_atc atc
                                JOIN devv5.concept t1 on atc.concept_code = t1.concept_code AND t1.vocabulary_id = 'KDC'
                                JOIN devv5.concept t2 on atc.concept_code_2 = t2.concept_code AND t2.vocabulary_id = 'ATC'
                                JOIN devv5.concept_relationship cr on t1.concept_id = cr.concept_id_1 AND cr.relationship_id = 'Maps to'
                                JOIN devv5.concept t3 on cr.concept_id_2 = t3.concept_id AND t3.vocabulary_id in ('RxNorm', 'RxNorm Extension')
             )

            UNION


                    ------DPD------
            (

                SELECT
                        c2.concept_id,
                        dpd.tc_atc_number,
                        'dpd' as source
                FROM    devv5.concept c1 JOIN sources.dpd_drug_all t1
                                                on c1.concept_code = (t1.drug_identification_number::INT)::VARCHAR AND t1.drug_identification_number ~ '^\d+$'
                                         JOIN sources.dpd_therapeutic_class_all dpd
                                                on t1.drug_code = dpd.drug_code
                                         JOIN devv5.concept_relationship cr
                                                on cr.concept_id_1 = c1.concept_id
                                         JOIN devv5.concept c2
                                                on cr.concept_id_2 = c2.concept_id

                WHERE length(tc_atc_number)=7
                    AND c1.vocabulary_id = 'DPD'
                    AND cr.relationship_id = 'Maps to'
                    AND c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
             )


            ) t2
                JOIN devv5.concept c on t2.concept_id = c.concept_id
                JOIN sources.atc_codes atc on t2.class_code = atc.class_code  --ATC must be loaded to the sources schema
            WHERE c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                   AND c.concept_class_id
                                            --not in     --Do not use certain forms
--                                             ('Ingredient', 'Precise Ingredient',
--                                              'BrANDed Drug Component', 'Clinical Drug Component', 'Dose Form', 'BrAND',
--                                              'Drug', 'Dose Form Group', 'Clinical Dose Group',
--                                              'Clinical Drug Comp', 'BrANDed Drug Comp', 'BrANDed Dose Group',
--                                              'BrANDed Drug Box', 'Multiple Ingredients', 'BrANDed Pack', 'BrANDed Drug Form', 'BrANDed Pack Box',
--                                             'BrANDed Drug', 'Multiple Ingredients', 'BrAND Name','Quant BrANDed Box','Quant BrANDed Drug')

                                                     not in ('BrAND Name',
                                                    'BrANDed Drug Comp',
                                                   'BrANDed Drug Component',
                                                    'Clinical Dose Group',
                                                    'Clinical Drug Comp',
                                                   'Clinical Drug Component',
                                                    'Dose Form',
                                                   'Dose Form Group',
                                                    'Ingredient',
                                                    'Multiple Ingredients',
                                                    'Precise Ingredient')


            order by class_code;


--2. Build custom ancestor table
DROP TABLE IF EXISTS class_ATC_RXN_huge_ancestor_temp;
CREATE TABLE class_ATC_RXN_huge_ancestor_temp as
SELECT concept_id, concept_name, ids, names, concept_class_id
FROM
(SELECT
                         c.concept_id,
                         c.concept_name,
                         c2.concept_id AS ids,
                         c2.concept_name AS names,
                         c2.concept_class_id
            FROM devv5.concept_ancestor ca
                JOIN devv5.concept c on descendant_concept_id = c.concept_id
                JOIN devv5.concept c2 on ancestor_concept_id =  c2.concept_id
            WHERE
                    c2.concept_class_id
--                                         not in
--                                             ('Ingredient', 'Precise Ingredient',
--                                              'BrANDed Drug Component', 'Clinical Drug Component', 'Dose Form', 'BrAND',
--                                              'Drug', 'Dose Form Group', 'Clinical Dose Group',
--                                              'Clinical Drug Comp', 'BrANDed Drug Comp', 'BrANDed Dose Group',
--                                              'BrANDed Drug Box', 'Multiple Ingredients', 'BrANDed Pack', 'BrANDed Drug Form', 'BrANDed Pack Box',
--                                              'BrANDed Drug', 'Multiple Ingredients', 'BrAND Name','Quant BrANDed Box','Quant BrANDed Drug')
                                        not in ('Brand Name',
                                                    'Brand Drug Comp',
                                                   'Brand Drug Component',
                                                    'Clinical Dose Group',
                                                    'Clinical Drug Comp',
                                                   'Clinical Drug Component',
                                                    'Dose Form',
                                                   'Dose Form Group',
                                                    'Ingredient',
                                                    'Multiple Ingredients',
                                                    'Precise Ingredient')


                    AND c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                    AND c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')) t1

UNION

(
SELECT
                         c.concept_id as concept_id,
                         c.concept_name,
                         c2.concept_id AS ids,
                         c2.concept_name AS names,
                         c2.concept_class_id
            FROM devv5.concept_ancestor ca
                JOIN devv5.concept c on ca.ancestor_concept_id = c.concept_id
                JOIN devv5.concept c2 on ca.descendant_concept_id =  c2.concept_id
            WHERE
                    c2.concept_class_id
--                                             not in
--                                             ('Ingredient', 'Precise Ingredient',
--                                              'Brand Drug Component', 'Clinical Drug Component', 'Dose Form', 'Brand',
--                                              'Drug', 'Dose Form Group', 'Clinical Dose Group',
--                                              'Clinical Drug Comp', 'Brand Drug Comp', 'Brand Dose Group',
--                                              'Brand Drug Box', 'Multiple Ingredients', 'Brand Pack', 'Brand Drug Form', 'Brand Pack Box',
--                                             'Brand Drug', 'Multiple Ingredients', 'Brand Name','Quant Brand Box','Quant Brand Drug')
                                                not in ('Brand Name',
                                                    'Brand Drug Comp',
                                                   'Brand Drug Component',
                                                    'Clinical Dose Group',
                                                    'Clinical Drug Comp',
                                                   'Clinical Drug Component',
                                                    'Dose Form',
                                                   'Dose Form Group',
                                                    'Ingredient',
                                                    'Multiple Ingredients',
                                                    'Precise Ingredient')

                    AND c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                    AND c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
            );



--- TODO try to turn off this part

--3. Add RxNorm is a relationships
INSERT INTO class_ATC_RXN_huge_temp
SELECT
    'RxNorm_is_a' as source,
    t2.concept_id as concept_id,
    t2.concept_name as concept_name,
    t2.concept_class_id as concept_class_id,
    t1.class_code as class_code,
    t1.class_name as class_name
FROM
    dev_atc.class_ATC_RXN_huge_temp t1
    JOIN devv5.concept_relationship cr ON t1.concept_id = cr.concept_id_1 AND cr.relationship_id = 'RxNorm is a'
    JOIN devv5.concept t2 ON cr.concept_id_2 = t2.concept_id AND t2.invalid_reason IS NULL
                                                             AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
;


--4. Build new ATC - RxNorm links
DROP TABLE IF EXISTS class_ATC_RXN_huge;
CREATE TABLE class_ATC_RXN_huge as

SELECT DISTINCT *
FROM
    (
        SELECT
               t2.class_code,
               t2.class_name,
               'ATC - RxNorm' as relationship_id,
               t1.concept_class_id,
               ids,
               names,
               source
        FROM
            class_ATC_RXN_huge_temp t2
        JOIN
            class_ATC_RXN_huge_ancestor_temp t1

            on t2.concept_id = t1.concept_id) full_table
UNION

        (SELECT     --Prevents losing certain codes
                class_code,
                class_name,
                'ATC - RxNorm' as relationship_id,
                concept_class_id,
                concept_id,
                concept_name,
                source
        FROM class_ATC_RXN_huge_temp);


--5. Add RxNorm is a relationships
INSERT INTO class_ATC_RXN_huge
SELECT
    t1.class_code as class_code,
    t1.class_name as class_name,
    t1.relationship_id as relationship_id,
    t2.concept_class_id as concept_class_id,
    t2.concept_id as ids,
    t2.concept_name as names,
    'RxNorm_is_a' as source
FROM dev_atc.class_ATC_RXN_huge t1
JOIN devv5.concept_relationship cr ON t1.ids = cr.concept_id_1
    AND cr.relationship_id = 'RxNorm is a'
JOIN devv5.concept t2 ON cr.concept_id_2 = t2.concept_id
    AND t2.invalid_reason IS NULL
    AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension');


--6. Deduplication AND creating final version of the table
--TODO: Can't we combine steps 3 - 6 in one step? Seems redundant
DROP TABLE IF EXISTS class_ATC_RXN_huge_fin;
CREATE TABLE class_ATC_RXN_huge_fin as
SELECT distinct *
FROM
    (
        SELECT
               t2.class_code,
               t2.class_name,
               t2.relationship_id,
               t1.concept_class_id,
               t1.ids,
               t1.names,
               source
        FROM
            class_ATC_RXN_huge t2
        JOIN
            class_ATC_RXN_huge_ancestor_temp t1
              on t2.ids = t1.concept_id
              AND t2.names = t1.concept_name) full_table

UNION

(SELECT * FROM class_ATC_RXN_huge)
;


--7. Add RxNorm is a relationships
INSERT INTO dev_atc.class_ATC_RXN_huge_fin (
    class_code,
    class_name,
    relationship_id,
    concept_class_id,
    ids,
    names,
    source
)
SELECT
    t1.class_code,
    t1.class_name,
    t1.relationship_id,
    t2.concept_class_id,
    cr.concept_id_2::INT as ids,
    t2.concept_name as names,
    'RxNorm_is_a' as source
FROM dev_atc.class_ATC_RXN_huge_fin t1
JOIN devv5.concept_relationship cr ON t1.ids = cr.concept_id_1
    AND t1.concept_class_id in ('Clinical Drug', 'Clinical Drug Form', 'Quant Clinical Drug')

    AND cr.relationship_id = 'RxNorm is a'
JOIN devv5.concept t2 ON cr.concept_id_2 = t2.concept_id
    AND t2.invalid_reason IS NULL
    AND t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension');


--8. Create final version of the table
DROP TABLE IF EXISTS dev_atc.class_ATC_RXN_huge_fin__;
CREATE TABLE dev_atc.class_ATC_RXN_huge_fin__ as
SELECT DISTINCT *
    FROM dev_atc.class_ATC_RXN_huge_fin;


--9. Taking step aside AND adding relationships to all related forms through Dose Form Groups
--Eg. Adding relationships to Oral Capsules if relationships to Oral Tablets exist
--DROP TABLE IF EXISTS  step_aside_source;
-- CREATE TABLE step_aside_source as
--     SELECT DISTINCT t1.concept_id,
--                                             t1.concept_name,
--                                             array_agg(t5.concept_id ORDER BY t5.concept_name)   AS array_ing_id,
--                                             array_agg(t5.concept_name ORDER BY t5.concept_name) AS array_ing,
--                                             t2.concept_id                                       AS dose_form_id,
--                                             t2.concept_name                                     AS dose_form_name,
--                                             t3.concept_id                                       AS dose_form_group_id,
--                                             t3.concept_name                                     AS dose_form_group_name,
--                                             t4.concept_id                                       AS potential_dose_form_id,
--                                             t4.concept_name                                     AS potential_dose_form_name
--                             FROM devv5.concept t1
--                                      --Dose Form
--                                      JOIN devv5.concept_relationship cr
--                                           on cr.concept_id_1 = t1.concept_id AND
--                                              t1.concept_class_id = 'Clinical Drug Form' AND
--                                              cr.relationship_id = 'RxNorm has dose form' AND cr.invalid_reason IS NULL
--                                      JOIN devv5.concept t2
--                                           on cr.concept_id_2 = t2.concept_id AND t2.invalid_reason is null AND
--                                              t2.concept_class_id in ('Dose Form')
--                                 --Dose Form Group
--                                      JOIN devv5.concept_relationship cr2 on cr2.concept_id_1 = t2.concept_id AND
--                                                                             cr2.relationship_id = 'RxNorm is a' AND
--                                                                             cr2.invalid_reason is null
--                                      JOIN devv5.concept t3
--                                           on cr2.concept_id_2 = t3.concept_id AND t3.invalid_reason is null AND
--                                              t3.concept_class_id = 'Dose Form Group'
--                                 --all potential forms in the group
--                                      JOIN devv5.concept_relationship cr3 on cr3.concept_id_1 = t3.concept_id AND
--                                                                             cr3.relationship_id =
--                                                                             'RxNorm inverse is a' AND
--                                                                             cr3.invalid_reason is null
--                                      JOIN devv5.concept t4
--                                           on cr3.concept_id_2 = t4.concept_id AND t4.invalid_reason is null AND
--                                              t4.concept_class_id = 'Dose Form'
--
--                                 --Ingredients
--                                      JOIN devv5.concept_relationship cr4
--                                           on cr4.concept_id_1 = t1.concept_id AND
--                                              t1.concept_class_id = 'Clinical Drug Form' AND
--                                              cr4.relationship_id = 'RxNorm has ing' AND cr4.invalid_reason IS NULL
--                                      JOIN devv5.concept t5
--                                           on cr4.concept_id_2 = t5.concept_id AND t5.invalid_reason is null AND
--                                              t5.concept_class_id = 'Ingredient'
--
--                             WHERE t1.concept_id in (SELECT distinct ids
--                                                     FROM dev_atc.class_ATC_RXN_huge_fin__    --Source table
--                                                     WHERE concept_class_id = 'Clinical Drug Form')
--                               --filter out not useful dose form groups
--                               AND t3.concept_id NOT IN (
--                                 36217216 --Pill
--                                 )
--
--                             GROUP BY t1.concept_id, t1.concept_name, t2.concept_id, t2.concept_name, t3.concept_id,
--                                      t3.concept_name, t4.concept_id, t4.concept_name;

--     DROP TABLE IF EXISTS  step_aside_target;
--     CREATE TABLE step_aside_target as
--     SELECT distinct t1.concept_id,
--                                             t1.concept_name,
--                                             array_agg(t5.concept_id ORDER BY t5.concept_name)   AS array_ing_id,
--                                             array_agg(t5.concept_name ORDER BY t5.concept_name) AS array_ing,
--                                             t2.concept_id                                       AS dose_form_id,
--                                             t2.concept_name                                     AS dose_form_name
--                             FROM devv5.concept t1
--                                      --Dose Form
--                                      JOIN devv5.concept_relationship cr
--                                           on cr.concept_id_1 = t1.concept_id AND
--                                              t1.concept_class_id = 'Clinical Drug Form' AND
--                                              cr.relationship_id = 'RxNorm has dose form' AND cr.invalid_reason IS NULL
--                                      JOIN devv5.concept t2
--                                           on cr.concept_id_2 = t2.concept_id AND t2.invalid_reason is null AND
--                                              t2.concept_class_id in ('Dose Form')
--
--                                 --Ingredients
--                                      JOIN devv5.concept_relationship cr4
--                                           on cr4.concept_id_1 = t1.concept_id AND
--                                              t1.concept_class_id = 'Clinical Drug Form' AND
--                                              cr4.relationship_id = 'RxNorm has ing' AND cr4.invalid_reason IS NULL
--                                      JOIN devv5.concept t5
--                                           on cr4.concept_id_2 = t5.concept_id AND t5.invalid_reason is null AND
--                                              t5.concept_class_id = 'Ingredient'
--
--                             GROUP BY t1.concept_id, t1.concept_name, t2.concept_id, t2.concept_name;
--
drop table if exists atc_step_aside_final;
create table atc_step_aside_final as
SELECT
    s.concept_id as source_concept_id,
    s.concept_name as source_concept_name,
    t.concept_id as target_concept_id,
    t.concept_name as target_concept_name
FROM step_aside_source s
      JOIN step_aside_target t
      on s.array_ing = t.array_ing AND t.dose_form_id != s.dose_form_id AND s.concept_id != t.concept_id
      AND t.dose_form_id = s.potential_dose_form_id
order by s.concept_id;

--10. Resulting table

DROP TABLE IF EXISTS new_atc_codes_rxnorm;
CREATE TABLE new_atc_codes_rxnorm as
SELECT *
FROM
(SELECT t1.class_code,
       t1.class_name,
       t1.relationship_id,
       t1.concept_class_id,
       t2.target_concept_id as ids,
       t2.target_concept_name as names,
       t1.source || ' - aside' as source
FROM dev_atc.class_ATC_RXN_huge_fin__ t1
     JOIN atc_step_aside_final t2 on t1.ids = t2.source_concept_id AND t1.concept_class_id = 'Clinical Drug Form'

     WHERE (t1.class_code, t2.target_concept_id) NOT IN --- remove all 'bad' mappings according manual check
                                  (
                                   SELECT concept_code_atc,
                                          concept_id_rx
                                   FROM dev_atc.atc_rxnorm_to_drop_in_sources
                                   WHERE drop = 'D')

) t1

UNION

    (
     SELECT
         *
     FROM dev_atc.class_ATC_RXN_huge_fin__
     WHERE (class_code, ids) NOT IN  --- remove all 'bad' mappings according manual check
                                  (
                                   SELECT concept_code_atc,
                                          concept_id_rx
                                   FROM dev_atc.atc_rxnorm_to_drop_in_sources
                                   WHERE drop = 'D')
     )
;

-------------------------------------------------------------

--11. Clean up the temporary tables
DROP TABLE IF EXISTS class_ATC_RXN_huge_fin__;
--DROP TABLE IF EXISTS step_aside_source;
--DROP TABLE IF EXISTS step_aside_target;
DROP TABLE IF EXISTS atc_step_aside_final;
DROP TABLE IF EXISTS class_ATC_RXN_huge_fin__;
DROP TABLE IF EXISTS class_ATC_RXN_huge_fin;
DROP TABLE IF EXISTS class_ATC_RXN_huge_temp;
DROP TABLE IF EXISTS class_ATC_RXN_huge_ancestor_temp;
DROP TABLE IF EXISTS class_ATC_RXN_huge;
