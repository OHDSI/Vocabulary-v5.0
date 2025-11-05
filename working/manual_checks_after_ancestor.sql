--

WITH prev_state AS (SELECT descendant_concept_id,
                           c2.concept_name                         AS descendant_name,
                           c2.concept_class_id                     AS descendant_class,
                           c2.vocabulary_id                        AS descendant_vocabulary,
                           COUNT(DISTINCT ancestor_concept_id)     AS anc_cnt,
                           ARRAY_AGG(DISTINCT ancestor_concept_id) AS anc_agg
                    FROM dev_qaathena.concept_ancestor ca
                             JOIN dev_qaathena.concept c ON c.concept_id = ca.ancestor_concept_id
                             JOIN dev_qaathena.concept c2 ON c2.concept_id = ca.descendant_concept_id
                     WHERE descendant_concept_id IN (SELECT DISTINCT c.concept_id
                                                     FROM audit.logged_propagated_maps_to a
                                                              JOIN devv5.concept c
                                                                   ON (a.concept_code_2, a.vocabulary_id_2) =
                                                                      (c.concept_code, c.vocabulary_id))
                      AND c.concept_class_id = 'Ingredient'
                    GROUP BY descendant_concept_id, c2.concept_name, c2.concept_class_id, c2.vocabulary_id)
        ,
     new_state AS (SELECT descendant_concept_id,
                          c2.concept_name                         AS descendant_name,
                          c2.concept_class_id                     AS descendant_class,
                          c2.vocabulary_id                        AS descendant_vocabulary,
                          COUNT(DISTINCT ancestor_concept_id)     AS anc_cnt,
                          ARRAY_AGG(DISTINCT ancestor_concept_id) AS anc_agg
                   FROM devv5.concept_ancestor ca
                            JOIN dev_qaathena.concept c ON c.concept_id = ca.ancestor_concept_id
                            JOIN dev_qaathena.concept c2 ON c2.concept_id = ca.descendant_concept_id
                  /* WHERE descendant_concept_id IN (SELECT DISTINCT c.concept_id
                                                   FROM audit.logged_propagated_maps_to a
                                                            JOIN devv5.concept c
                                                                 ON (a.concept_code_2, a.vocabulary_id_2) =
                                                                    (c.concept_code, c.vocabulary_id))*/
                     AND c.concept_class_id = 'Ingredient'
                   GROUP BY descendant_concept_id, c2.concept_name, c2.concept_class_id, c2.vocabulary_id)
   --     ,
    -- precalc AS (
     SELECT CASE
                            WHEN a.anc_cnt < b.anc_cnt THEN 'New release decrease # of Ingredients'
                            WHEN a.anc_cnt = b.anc_cnt THEN 'New release does not affect # of Ingredients'
                            ELSE 'New release increase # of Ingredients' END AS direction_of_changes,
                        a.descendant_concept_id,
                        a.descendant_name,
                        a.descendant_class,
                        a.descendant_vocabulary,
                        a.anc_cnt                                            AS new_anc_cnt,
                        a.anc_agg                                            AS new_anc_agg,
                        b.anc_cnt                                            AS prev_anc_cnt,
                        b.anc_agg                                            AS prev_anc_agg
                 FROM new_state a
                          JOIN prev_state b
                               USING (descendant_concept_id);)
SELECT CASE
           WHEN ROUND(
                        (
                            (SELECT (COUNT(DISTINCT a.descendant_concept_id)):: numeric AS cnt
                             FROM precalc a
                             WHERE a.direction_of_changes != 'New release does not affect # of Ingredients') /
                            (SELECT (COUNT(DISTINCT b.descendant_concept_id)):: numeric AS cnt
                             FROM precalc b)) * 100, 2) < 5.0 THEN 'PASS' || ' (' || ROUND(
                        (
                            (SELECT (COUNT(DISTINCT a.descendant_concept_id)):: numeric AS cnt
                             FROM precalc a
                             WHERE a.direction_of_changes != 'New release does not affect # of Ingredients') /
                            (SELECT (COUNT(DISTINCT b.descendant_concept_id)):: numeric AS cnt
                             FROM precalc b)) * 100, 2) || '%)'
           ELSE 'FAIL' || ' (' || ROUND(
                        (
                            (SELECT (COUNT(DISTINCT a.descendant_concept_id)):: numeric AS cnt
                             FROM precalc a
                             WHERE a.direction_of_changes != 'New release does not affect # of Ingredients') /
                            (SELECT (COUNT(DISTINCT b.descendant_concept_id)):: numeric AS cnt
                             FROM precalc b)) * 100, 2) || '%)' END AS complience_check,
    '5%' as cutoff
;
