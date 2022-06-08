with tab as (
    SELECT concept_code
    FROM dev_meddra.concept  WHERE vocabulary_id='MedDRA' and invalid_reason IS NULL
    )
, ancestry as (
    SELECT
           a.concept_code,
           string_agg ( cc.concept_class_id ||  ': ' || cc.concept_name,'=>' order by min_levels_of_separation asc) as ancestry
FROM tab AS a
JOIN devv5.concept c
on a.concept_code=c.concept_code
and c.vocabulary_id='MedDRA'
LEFT JOIN devv5.concept_ancestor ca
on c.concept_id=ca.descendant_concept_id
and ca.min_levels_of_separation>0
LEFT JOIN devv5.concept cc
on ca.ancestor_concept_id=cc.concept_id
and cc.vocabulary_id='MedDRA'
GROUP BY a.concept_code
)

SELECT

      s.concept_code,
      ancestry,
      regexp_replace( string_agg( distinct concat(  ccc.concept_name , 'SOC: '||cc.concept_name,'=>'),'>'),'^\=>|\=$|=>$','','gi')  as short_ancestry
FROM ancestry s
JOIN devv5.concept c
on s.concept_code=c.concept_code
and c.vocabulary_id='MedDRA'
LEFT JOIN devv5.concept_ancestor ca
on ca.descendant_concept_id=c.concept_id
LEFT JOIN devv5.concept cc
on ca.ancestor_concept_id=cc.concept_id
and cc.concept_class_id in ('SOC')
LEFT JOIN devv5.concept ccc
on ca.ancestor_concept_id=ccc.concept_id
and min_levels_of_separation in (1)
GROUP BY s.concept_code, s.ancestry
;
