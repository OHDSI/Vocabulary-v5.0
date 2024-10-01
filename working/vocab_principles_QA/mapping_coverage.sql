-- Rule: every non-S concept should be mapped to Standard, or mapped to 0
-- Distribution of concepts by vocabulary and domains which are non-standard without valid mapping
SELECT c.concept_class_id,
       c.domain_id,
       c.vocabulary_id,
       COUNT(*) AS concept_count
FROM concept AS c
WHERE c.standard_concept IS NULL
  AND c.invalid_reason IS NULL
AND NOT EXISTS (SELECT 1
                  FROM concept_relationship cr
                  where cr.concept_id_1=c.concept_id
                  and cr.relationship_id='Maps to'
                  and cr.invalid_reason is NULL
                )
GROUP BY c.concept_class_id,
         c.vocabulary_id,
         c.domain_id
ORDER BY concept_count DESC,
         c.domain_id,
         c.vocabulary_id,
         c.concept_class_id;

-- Concepts in selected vocabulary and domain which are non-standard without valid mapping
SELECT *
FROM
    devv5.concept AS c
WHERE
    NOT EXISTS (
        SELECT 1
        FROM
            devv5.concept_relationship AS cr
        INNER JOIN
            devv5.concept AS cc
        ON cr.concept_id_2 = cc.concept_id
        WHERE
            cr.relationship_id LIKE 'Maps to%'
            AND cr.invalid_reason IS NULL
            AND c.concept_id = cr.concept_id_1
            AND c.concept_id != cr.concept_id_2
            AND c.vocabulary_id != cc.vocabulary_id
    )
    AND c.standard_concept IS NULL
    AND c.invalid_reason IS NULL
    AND c.domain_id IN (:your_domain)
    AND c.vocabulary_id IN (:your_vocabulary)
;


-- Patrick’s version of QC check:
--insert into vocabqc (check_type, check_result, check_count)
select 'orphan concepts: no valid non-standard concepts have niether a map to >=1 standard nor map to 0 (No matching concept)' as check_type,
  case when num_concepts = 0 then 'Pass' else 'Fail' end as check_result,
  num_concepts as check_count
from
(
  select count(distinct t1.concept_id) as num_concepts
  from
  (
    select c1.concept_id, c1.concept_name, c1.vocabulary_id, c1.domain_id
    from
    concept c1
    left join
    (
      select distinct c1.concept_id
      from concept c1
      inner join concept_relationship cr1
      on c1.concept_id = cr1.concept_id_1
      and cr1.relationship_id = 'Maps to'
      inner join concept c2
      on cr1.concept_id_2 = c2.concept_id
      where c1.standard_concept is null
        and c1.invalid_reason is null
      and (c2.standard_concept = 'S' or c2.concept_id = 0)
    ) mapped
    on c1.concept_id = mapped.concept_id
    where c1.standard_concept is null
    and mapped.concept_id is null
    and c1.invalid_reason is null

  ) t1

) t2
;

SELECT c.concept_class_id,
       c.domain_id,
       c.vocabulary_id,
       COUNT(*)


 AS concept_count
FROM concept AS c
WHERE c.standard_concept IS NULL
  AND c.invalid_reason IS NULL
AND NOT EXISTS (SELECT 1
                  FROM concept_relationship cr
                  where cr.concept_id_1=c.concept_id
                  and cr.relationship_id='Maps to'
                  and cr.invalid_reason is NULL
                )
GROUP BY c.concept_class_id,
         c.vocabulary_id,
         c.domain_id
ORDER BY concept_count DESC,
         c.domain_id,
         c.vocabulary_id,
         c.concept_class_id;