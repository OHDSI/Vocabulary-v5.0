-- Condition
/*with excluded_vocabs as (
SELECT vocabulary_id from vocabulary
       where vocabulary_id in ('Nebraska Lexicon', 'NAACCR')
) */
SELECT DISTINCT concat(c.vocabulary_id, ' - ',  cc.vocabulary_id) as vocab_concat,
                concat(c.concept_class_id, ' - ', cc.concept_class_id) as cc_concat,
                count(DISTINCT c.concept_id) as count
       FROM devv5.concept c
join devv5.concept cc on lower(c.concept_name) = lower(cc.concept_name)
WHERE c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and cc.domain_id = 'Observation'
and c.domain_id = 'Condition'
--and c.vocabulary_id not in (SELECT vocabulary_id from excluded_vocabs)
--and cc.vocabulary_id not in (SELECT vocabulary_id from excluded_vocabs)
and c.concept_name not like '%...%'
GROUP BY c.vocabulary_id, cc.vocabulary_id, c.concept_class_id, cc.concept_class_id
order by vocab_concat, count desc, cc_concat;

--- to look at the concept precisely
select distinct
       c.concept_name,
       c.concept_id,
    c.concept_code,
    c.domain_id,
    c.concept_class_id,
    c.standard_concept,
    c.valid_start_date,
    c.valid_end_date,
    c.vocabulary_id
from devv5.concept c, devv5.concept cc
where lower(c.concept_name) = lower(cc.concept_name)
and c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.domain_id = cc.domain_id
and c.domain_id = 'Condition'
and c.vocabulary_id in ('SNOMED', 'OMOP Extension')
and cc.vocabulary_id in ('SNOMED', 'OMOP Extension')
and c.concept_name not like '%...%'
ORDER BY c.concept_name, c.concept_class_id, c.vocabulary_id;


-- Observation
/*with excluded_vocabs as (
SELECT vocabulary_id from vocabulary
       where vocabulary_id in ('Nebraska Lexicon', 'NAACCR')
)*/
SELECT DISTINCT concat(c.vocabulary_id, ' - ',  cc.vocabulary_id) as vocab_concat,
                concat(c.concept_class_id, ' - ', cc.concept_class_id) as cc_concat,
                count(DISTINCT c.concept_id) as count
       FROM devv5.concept c
join devv5.concept cc on lower(c.concept_name) = lower(cc.concept_name)
WHERE c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.domain_id = cc.domain_id
and c.domain_id = 'Observation'
--and c.vocabulary_id not in (SELECT vocabulary_id from excluded_vocabs)
--and cc.vocabulary_id not in (SELECT vocabulary_id from excluded_vocabs)
and c.concept_name not like '%...'
--and c.concept_class_id --not in ('Answer', 'Value', 'Question', 'Survey', 'CPT4 Modifier', 'HCPCS Modifier')
--and cc.concept_class_id not in ('Answer', 'Value', 'Question', 'Survey','CPT4 Modifier', 'HCPCS Modifier')
GROUP BY c.vocabulary_id, cc.vocabulary_id, c.concept_class_id, cc.concept_class_id
order by vocab_concat, count desc;

--Procedure
with excluded_vocabs as (
SELECT vocabulary_id from vocabulary
       where vocabulary_id in ('Nebraska Lexicon', 'NAACCR')
)
SELECT DISTINCT concat(c.vocabulary_id, ' - ',  cc.vocabulary_id) as vocab_concat,
                concat(c.concept_class_id, ' - ', cc.concept_class_id) as cc_concat,
                count(DISTINCT c.concept_id) as count
       FROM devv5.concept c
join devv5.concept cc on lower(c.concept_name) = lower(cc.concept_name)
WHERE c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.domain_id = cc.domain_id
and c.domain_id = 'Procedure'
and c.vocabulary_id not in (SELECT vocabulary_id from excluded_vocabs)
and cc.vocabulary_id not in (SELECT vocabulary_id from excluded_vocabs)
and c.concept_name not like '%...%'
and c.concept_class_id != 'ICD10PCS Hierarchy'
and cc.concept_class_id != 'ICD10PCS Hierarchy'
GROUP BY c.vocabulary_id, cc.vocabulary_id, c.concept_class_id, cc.concept_class_id
order by vocab_concat, count desc, cc_concat;

--Measurement
/*with excluded_vocabs as (
SELECT vocabulary_id from vocabulary
       where vocabulary_id in ('Nebraska Lexicon', 'NAACCR')
) */
SELECT DISTINCT concat(c.vocabulary_id, ' - ',  cc.vocabulary_id) as vocab_concat,
                concat(c.concept_class_id, ' - ', cc.concept_class_id) as cc_concat,
                count(DISTINCT c.concept_id) as count
       FROM devv5.concept c
join devv5.concept cc on lower(c.concept_name) = lower(cc.concept_name)
WHERE c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.domain_id = cc.domain_id
and c.domain_id = 'Measurement'
--and c.vocabulary_id not in (SELECT vocabulary_id from excluded_vocabs)
--and cc.vocabulary_id not in (SELECT vocabulary_id from excluded_vocabs)
and c.concept_name not like '%...%'
GROUP BY c.vocabulary_id, cc.vocabulary_id, c.concept_class_id, cc.concept_class_id
order by vocab_concat, count desc, cc_concat;

 --Survey concepts
/*with excluded_vocabs as (
SELECT vocabulary_id from vocabulary
       where vocabulary_id in ('Nebraska Lexicon', 'NAACCR')
) */
SELECT DISTINCT concat(c.vocabulary_id, ' - ',  cc.vocabulary_id) as vocab_concat,
                concat(c.concept_class_id, ' - ', cc.concept_class_id) as cc_concat,
                count(DISTINCT c.concept_id) as count
       FROM devv5.concept c
join devv5.concept cc on lower(c.concept_name) = lower(cc.concept_name)
WHERE c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.domain_id = cc.domain_id
and c.domain_id = 'Observation'
--and c.vocabulary_id not in (SELECT vocabulary_id from excluded_vocabs)
--and cc.vocabulary_id not in (SELECT vocabulary_id from excluded_vocabs)
and c.concept_name not like '%...%'
and c.concept_class_id  in ('Answer', 'Clinical Observation', 'Module', 'Qualifier Value', 'Question source', 'Topic', 'Value', 'Question', 'Survey')and cc.concept_class_id  in ('Answer', 'Clinical Observation', 'Module', 'Qualifier Value', 'Question source', 'Topic', 'Value', 'Question', 'Survey')
GROUP BY c.vocabulary_id, cc.vocabulary_id, c.concept_class_id, cc.concept_class_id
order by vocab_concat, count desc, cc_concat;

--Modifiers
SELECT DISTINCT concat(c.vocabulary_id, ' - ',  cc.vocabulary_id) as vocab_concat, concat(c.concept_class_id, ' - ', cc.concept_class_id) as cc_concat, count(DISTINCT c.concept_id) as count
       FROM devv5.concept c
join devv5.concept cc on lower(c.concept_name) = lower(cc.concept_name)
WHERE c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.domain_id = cc.domain_id
and c.domain_id = 'Observation'
and c.concept_name not like '%...%'
and c.concept_class_id  like '%Modifier'
and cc.concept_class_id like '%Modifier'
GROUP BY c.vocabulary_id, cc.vocabulary_id, c.concept_class_id, cc.concept_class_id
order by vocab_concat, count desc, cc_concat;

--Device
SELECT DISTINCT concat(c.vocabulary_id, ' - ',  cc.vocabulary_id) as vocab_concat,
                concat(c.concept_class_id, ' - ', cc.concept_class_id) as cc_concat,
                count(DISTINCT c.concept_id) as count
       FROM devv5.concept c
join devv5.concept cc on lower(c.concept_name) = lower(cc.concept_name)
WHERE c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.domain_id = cc.domain_id
and c.domain_id = 'Device'
and c.concept_name not like '%...%'
GROUP BY c.vocabulary_id, cc.vocabulary_id, c.concept_class_id, cc.concept_class_id
order by vocab_concat, count desc, cc_concat;


--Other domains
SELECT DISTINCT concat(c.vocabulary_id, ' - ',  cc.vocabulary_id) as vocab_concat,
                concat(c.concept_class_id, ' - ', cc.concept_class_id) as cc_concat,
               concat(c.domain_id, ' - ', cc.domain_id) as domain_concat,
                count(DISTINCT c.concept_id) as count
       FROM devv5.concept c
join devv5.concept cc on lower(c.concept_name) = lower(cc.concept_name)
WHERE c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.domain_id = cc.domain_id
and c.concept_name not like '%...%'
and c.domain_id not in ('Drug', 'Condition', 'Observation', 'Measurement', 'Procedure', 'Meas Value', 'Device')
GROUP BY c.vocabulary_id, cc.vocabulary_id, c.domain_id, cc.domain_id, c.concept_class_id, cc.concept_class_id
order by vocab_concat, count desc, cc_concat;

-- Drug
SELECT DISTINCT concat(c.vocabulary_id, ' - ',  cc.vocabulary_id),
                --concat(c.concept_class_id, ' - ', cc.concept_class_id),
                count(DISTINCT c.concept_id)
       FROM devv5.concept c
join devv5.concept cc on lower(c.concept_name) = lower(cc.concept_name)
WHERE c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.domain_id = cc.domain_id
and c.domain_id = 'Drug'
and c.concept_name not like '%...%'
GROUP BY c.vocabulary_id, cc.vocabulary_id/*, c.concept_class_id, cc.concept_class_id*/;

-- Metadata
SELECT DISTINCT concat(c.vocabulary_id, ' - ',  cc.vocabulary_id) as vocab_concat,
                concat(c.concept_class_id, ' - ', cc.concept_class_id) as cc_concat,
                count(DISTINCT c.concept_id) as count
       FROM devv5.concept c
join devv5.concept cc on lower(c.concept_name) = lower(cc.concept_name)
WHERE c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.domain_id = cc.domain_id
and c.domain_id = 'Metadata'
and c.concept_name not like '%...%'
 GROUP BY c.vocabulary_id, cc.vocabulary_id, c.concept_class_id, cc.concept_class_id
order by vocab_concat, count desc, cc_concat;


-- Across different domains
with excluded_vocabs as (
SELECT vocabulary_id from vocabulary
       where vocabulary_id in ('Nebraska Lexicon', 'NAACCR')
)
select DISTINCT concat (c.domain_id, ' - ', cc.domain_id) as domain_concat,
--concat(c.vocabulary_id, ' - ',  cc.vocabulary_id) as vocab_concat,
                --concat(c.concept_class_id, ' - ', cc.concept_class_id) as cc_concat,
                count(DISTINCT c.concept_id) as count
       FROM devv5.concept c
join devv5.concept cc on lower(c.concept_name) = lower(cc.concept_name)
WHERE c.concept_id != cc.concept_id
and c.standard_concept = 'S'
and cc.standard_concept = 'S'
and c.domain_id != cc.domain_id
--and c.domain_id = 'Drug'
and c.concept_name not like '%...%'
and c.vocabulary_id not in (SELECT vocabulary_id from excluded_vocabs)
and cc.vocabulary_id not in (SELECT vocabulary_id from excluded_vocabs)
 GROUP BY c.domain_id, cc.domain_id--c.vocabulary_id, cc.vocabulary_id, c.concept_class_id, cc.concept_class_id
order by domain_concat, count desc--, cc_concat;

