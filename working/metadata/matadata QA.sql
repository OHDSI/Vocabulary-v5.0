--1. Concept metadata QA:
--1.1. Check the overall result:
SELECT *
FROM concept_metadata;

--1.2. Loss of concepts compared to prev release
SELECT *
from devv5.concept_metadata cm
join concept c using (concept_id)
where  not exists (
    SELECT 1
    from dev_voc_metadata.concept_metadata cmt
    where cmt.concept_id=cm.concept_id
)
;

--1.3. Assess new IDs compared to prev release
SELECT *
from dev_voc_metadata.concept_metadata cm
join concept c
on c.concept_id=cm.concept_id
where  not exists (
    SELECT 1
    from devv5.concept_metadata cmt
    where cmt.concept_id=cm.concept_id
)
;

--2. Concept relationship metadata QA
--2.1. Check the overall result:
SELECT *
FROM concept_relationship_metadata
ORDER BY concept_id_1,relationship_id,concept_id_2
;

--2.2. Loss of concepts compared to prev release
--- Predictable behavior as resulted from mapping propagation and entire mapping inactivation/invalidation
SELECT c.vocabulary_id,count(*) as row_cnt, count(DISTINCT c.concept_id) as id_cnt
from devv5.concept_relationship_metadata crm
JOIN devv5.concept c
on crm.concept_id_1=c.concept_id
where not exists (
    SELECT 1
    from dev_voc_metadata.concept_relationship_metadata crmt
    where crmt.concept_id_1=crm.concept_id_1
)
  and crm.relationship_id IN (
'Maps to',
'Maps to value'
)
GROUP BY c.vocabulary_id
;

--2.3. New CR-metadata elements
SELECT c.vocabulary_id,count(*) as row_cnt, count(DISTINCT c.concept_id) as id_cnt
from dev_voc_metadata.concept_relationship_metadata crm
JOIN devv5.concept c
on crm.concept_id_1=c.concept_id
where  not exists (
    SELECT 1
    from devv5.concept_relationship_metadata crmt
    where crmt.concept_id_1=crm.concept_id_1
      and crmt.relationship_id IN (
'Maps to',
'Maps to value'
)
)
  and crm.relationship_id IN (
'Maps to',
'Maps to value'
)
GROUP BY c.vocabulary_id
;