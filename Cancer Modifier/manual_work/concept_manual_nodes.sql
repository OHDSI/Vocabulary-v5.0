--Tables preparation
CREATE TABLE concept_manual_nodes as
SELECT * FROM concept_relationship_manual_staging;
--https://docs.google.com/spreadsheets/d/1Ylat8lnTy1ow5pc1jqZVih5EBUNhw38CBL-Kpeb-DT4/edit#gid=0
--TRUNCATE concept_manual_nodes;

CREATE TABLE concept_relationship_manual_nodes
AS
SELECT * FROM concept_relationship_manual;
--https://docs.google.com/spreadsheets/d/14imc12r2vtLFAQsXzn1YBT28Vh2J2wefxEY-rYwyMG8/edit#gid=0
--TRUNCATE concept_relationship_manual_nodes;

--Set up OMOPgenrated codes
DROP SEQUENCE IF EXISTS omop_seq;
DO $$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(REPLACE(concept_code, 'OMOP','')::int4)+1 INTO ex FROM (
		SELECT concept_code FROM concept WHERE concept_code LIKE 'OMOP%'  AND concept_code NOT LIKE '% %' -- Last valid value of the OMOP123-type codes
			) AS s0;
	DROP SEQUENCE IF EXISTS omop_seq;
	EXECUTE 'CREATE SEQUENCE omop_seq INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END$$;


--Nodes retrieval
WITH tab as (
SELECT distinct c.concept_name as parent_node,c.concept_code as parent_code,c.vocabulary_id as parent_vocab,cr.relationship_id,cc.concept_name as child_node,cc.concept_code as child_code,cc.vocabulary_id as child_vocab,
                cr2.relationship_id  as rel2,cc2.concept_name as child_node2,cc2.concept_code as child_code2,cc2.vocabulary_id as child_vocab2
FROM devv5.concept c
JOIN devv5.concept_ancestor ca
ON c.concept_id=ca.descendant_concept_id
and ca.ancestor_concept_id=4241958	--	Structure of lymph node
and c.vocabulary_id='SNOMED'
and c.domain_id='Spec Anatomic Site'
and c.standard_concept='S'
and c.concept_name ilike '%group%'
JOIN devv5.concept_relationship  cr
ON cr.concept_id_1=c.concept_id
and cr.relationship_id='Subsumes'
and cr.invalid_reason is null
left JOIN devv5.concept cc
ON cr.concept_id_2=cc.concept_id
and cc.vocabulary_id='SNOMED'
and cc.domain_id='Spec Anatomic Site'
and cc.standard_concept='S'
left JOIN devv5.concept_relationship  cr2
ON cr2.concept_id_1=cc.concept_id
and cr2.relationship_id='Subsumes'
and cr2.invalid_reason is null
left JOIN devv5.concept cc2
ON cr2.concept_id_2=cc2.concept_id
and cc2.vocabulary_id='SNOMED'
and cc2.domain_id='Spec Anatomic Site'
and cc2.standard_concept='S'
where cc.concept_id<>c.concept_id
    )

, tab2 as (
SELECT  distinct
       parent_node,
       parent_code,
       parent_vocab,
       relationship_id,
       child_node,
       child_code,
       child_vocab
FROM tab

union all

SELECT  distinct
                 child_node,
                 child_code,
                 child_vocab,
                 rel2,
                 child_node2,
                 child_code2,
                 child_vocab2
FROM tab)
,
anatomic_lymph_node_hierarchy as (
SELECT distinct * FROM tab2
where child_code is not null )
,
anatomic_nodal_concepts as (
    SELECT distinct *
    from (SELECT parent_node,
                 parent_code,
                 parent_vocab
          FROM anatomic_lymph_node_hierarchy
          UNION ALL
          SELECT child_node,
                 child_code,
                 child_vocab
          FROM anatomic_lymph_node_hierarchy) a
)
, attributive_nodes as (
SELECT 'Regional spread to ' || lower(trim(regexp_replace(parent_node,'Structure of | group | group$',' ','gi'))) as parent_name,
       parent_code,
       parent_vocab
FROM anatomic_nodal_concepts

UNION ALL

SELECT 'Distant spread to ' || lower(trim(regexp_replace(parent_node,'Structure of | group | group$',' ','gi'))) as parent_name,
       parent_code,
       parent_vocab
FROM anatomic_nodal_concepts

UNION ALL

SELECT 'Spread to ' || lower(trim(regexp_replace(parent_node,'Structure of | group | group$',' ','gi'))) as parent_name,
       parent_code,
       parent_vocab
FROM anatomic_nodal_concepts)

INSERT INTO concept_manual_nodes (concept_code,concept_name,domain_id,concept_class_id,standard_concept,invalid_reason,valid_start_date,valid_end_date,vocabulary_id)
SELECT
        'OMOP' || nextval('omop_seq')  AS concept_code,
       parent_name as concept_name_1,
       'Measurement' as domain_id,
       'Nodes' as concept_class_id,
       'S' as standard_concept,
       NULL as invaild_reason,
       CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
       'Cancer Modifier' as vocabulary_id
FROM attributive_nodes
JOIN devv5.concept on parent_code=concept_code and vocabulary_id='SNOMED';

--Has finding site
WITH tab as (
SELECT distinct c.concept_name as parent_node,c.concept_code as parent_code,c.vocabulary_id as parent_vocab,cr.relationship_id,cc.concept_name as child_node,cc.concept_code as child_code,cc.vocabulary_id as child_vocab,
                cr2.relationship_id  as rel2,cc2.concept_name as child_node2,cc2.concept_code as child_code2,cc2.vocabulary_id as child_vocab2
FROM devv5.concept c
JOIN devv5.concept_ancestor ca
ON c.concept_id=ca.descendant_concept_id
and ca.ancestor_concept_id=4241958	--	Structure of lymph node
and c.vocabulary_id='SNOMED'
and c.domain_id='Spec Anatomic Site'
and c.standard_concept='S'
and c.concept_name ilike '%group%'
JOIN devv5.concept_relationship  cr
ON cr.concept_id_1=c.concept_id
and cr.relationship_id='Subsumes'
and cr.invalid_reason is null
left JOIN devv5.concept cc
ON cr.concept_id_2=cc.concept_id
and cc.vocabulary_id='SNOMED'
and cc.domain_id='Spec Anatomic Site'
and cc.standard_concept='S'
left JOIN devv5.concept_relationship  cr2
ON cr2.concept_id_1=cc.concept_id
and cr2.relationship_id='Subsumes'
and cr2.invalid_reason is null
left JOIN devv5.concept cc2
ON cr2.concept_id_2=cc2.concept_id
and cc2.vocabulary_id='SNOMED'
and cc2.domain_id='Spec Anatomic Site'
and cc2.standard_concept='S'
where cc.concept_id<>c.concept_id
    )

, tab2 as (
SELECT  distinct
       parent_node,
       parent_code,
       parent_vocab,
       relationship_id,
       child_node,
       child_code,
       child_vocab
FROM tab

union all

SELECT  distinct
                 child_node,
                 child_code,
                 child_vocab,
                 rel2,
                 child_node2,
                 child_code2,
                 child_vocab2
FROM tab)
,
anatomic_lymph_node_hierarchy as (
SELECT distinct * FROM tab2
where child_code is not null )
,
anatomic_nodal_concepts as (
    SELECT distinct *
    from (SELECT parent_node,
                 parent_code,
                 parent_vocab
          FROM anatomic_lymph_node_hierarchy
          UNION ALL
          SELECT child_node,
                 child_code,
                 child_vocab
          FROM anatomic_lymph_node_hierarchy) a
)
, attributive_nodes as (
SELECT 'Spread to ' || lower(trim(regexp_replace(parent_node,'Structure of | group | group$',' ','gi'))) as parent_name,
       parent_code,
       parent_vocab
FROM anatomic_nodal_concepts)

INSERT INTO concept_relationship_manual_nodes (concept_code_1, relationship_id, vocabulary_id_1, invalid_reason, valid_start_date, valid_end_date, concept_code_2,vocabulary_id_2)
SELECT --cmn.concept_name,
       cmn.concept_code as concept_code_1,
        'Has finding site' as relationship_id,
       cmn.vocabulary_id as vocabulary_id_1,
       NULL as invalid_reason,
       CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
       c.concept_code as concept_code_2,
       --c.concept_name,
       c.vocabulary_id as vocabulary_id_2
FROM attributive_nodes a
JOIN devv5.concept c on parent_code=c.concept_code and c.vocabulary_id='SNOMED'
and a.parent_name ilike 'Spread to%'
JOIN concept_manual_nodes cmn
on cmn.concept_name=a.parent_name
;


--Hierarchy reconstruction
WITH tab as (
SELECT distinct c.concept_name as parent_node,c.concept_code as parent_code,c.vocabulary_id as parent_vocab,cr.relationship_id,cc.concept_name as child_node,cc.concept_code as child_code,cc.vocabulary_id as child_vocab,
                cr2.relationship_id  as rel2,cc2.concept_name as child_node2,cc2.concept_code as child_code2,cc2.vocabulary_id as child_vocab2
FROM devv5.concept c
JOIN devv5.concept_ancestor ca
ON c.concept_id=ca.descendant_concept_id
and ca.ancestor_concept_id=4241958	--	Structure of lymph node
and c.vocabulary_id='SNOMED'
and c.domain_id='Spec Anatomic Site'
and c.standard_concept='S'
and c.concept_name ilike '%group%'
JOIN devv5.concept_relationship  cr
ON cr.concept_id_1=c.concept_id
and cr.relationship_id='Subsumes'
and cr.invalid_reason is null
left JOIN devv5.concept cc
ON cr.concept_id_2=cc.concept_id
and cc.vocabulary_id='SNOMED'
and cc.domain_id='Spec Anatomic Site'
and cc.standard_concept='S'
left JOIN devv5.concept_relationship  cr2
ON cr2.concept_id_1=cc.concept_id
and cr2.relationship_id='Subsumes'
and cr2.invalid_reason is null
left JOIN devv5.concept cc2
ON cr2.concept_id_2=cc2.concept_id
and cc2.vocabulary_id='SNOMED'
and cc2.domain_id='Spec Anatomic Site'
and cc2.standard_concept='S'
where cc.concept_id<>c.concept_id
    )

, tab2 as (
SELECT  distinct
       parent_node,
       parent_code,
       parent_vocab,
       relationship_id,
       child_node,
       child_code,
       child_vocab
FROM tab

union all

SELECT  distinct
                 child_node,
                 child_code,
                 child_vocab,
                 rel2,
                 child_node2,
                 child_code2,
                 child_vocab2
FROM tab)
,
anatomic_lymph_node_hierarchy as (
SELECT distinct * FROM tab2
where child_code is not null )
,
anatomic_nodal_concepts as (
    SELECT distinct *
    from (SELECT parent_node,
                 parent_code,
                 parent_vocab
          FROM anatomic_lymph_node_hierarchy
          UNION ALL
          SELECT child_node,
                 child_code,
                 child_vocab
          FROM anatomic_lymph_node_hierarchy) a
)
, attributive_nodes as (
SELECT 'Spread to ' || lower(trim(regexp_replace(parent_node,'Structure of | group | group$',' ','gi'))) as parent_name,
       parent_code,
       parent_vocab
FROM anatomic_nodal_concepts)

INSERT INTO concept_relationship_manual_nodes (concept_code_1, relationship_id, vocabulary_id_1, invalid_reason, valid_start_date, valid_end_date, concept_code_2,vocabulary_id_2)
SELECT distinct
                cmn.concept_code as concept_code_1,
                a.relationship_id,
                cmn.vocabulary_id as vocabulary_id_1,
                NULL as invalid_reason,
                CURRENT_DATE AS valid_start_date,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                cmn2.concept_code as concept_code_2,
                cmn2.vocabulary_id as vocabulary_id_2

FROM concept_relationship_manual_nodes cmrn
JOIN  anatomic_lymph_node_hierarchy a
on a.parent_code=cmrn.concept_code_2
and cmrn.vocabulary_id_2='SNOMED'
    JOIN concept_manual_nodes cmn
    on cmn.concept_code=cmrn.concept_code_1
JOIN  concept_relationship_manual_nodes cmrn2
on a.child_code=cmrn2.concept_code_2
and cmrn2.vocabulary_id_2='SNOMED'
    JOIN concept_manual_nodes cmn2
    on cmn2.concept_code=cmrn2.concept_code_1
;

--Distant nad Regiona spread hierarchy
INSERT INTO concept_relationship_manual_nodes (concept_code_1, relationship_id, vocabulary_id_1, invalid_reason, valid_start_date, valid_end_date, concept_code_2,vocabulary_id_2)
SELECT distinct
                a.concept_code as concept_code_1,
              'Subsumes' as relationship_id,
                a.vocabulary_id as vocabulary_id_1,
                NULL as invalid_reason,
                CURRENT_DATE AS valid_start_date,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                aa.concept_code as concept_code_2,
                aa.vocabulary_id as vocabulary_id_2
FROM concept_manual_nodes a
JOIN concept_manual_nodes aa
on aa.concept_name ilike '%' || a.concept_name
where aa.concept_name ilike 'Distant%'
and aa.concept_name<>a.concept_name

UNION ALL

SELECT   a.concept_code as concept_code_1,
              'Subsumes' as relationship_id,
                a.vocabulary_id as vocabulary_id_1,
                NULL as invalid_reason,
                CURRENT_DATE AS valid_start_date,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                aa.concept_code as concept_code_2,
                aa.vocabulary_id as vocabulary_id_2
FROM concept_manual_nodes a
JOIN concept_manual_nodes aa
on aa.concept_name ilike '%' || a.concept_name
where aa.concept_name ilike 'Regional%'
and aa.concept_name<>a.concept_name
;
--Axis for distant spread from Metastasis concept class
INSERT INTO concept_relationship_manual_nodes (concept_code_1, relationship_id, vocabulary_id_1, invalid_reason, valid_start_date, valid_end_date, concept_code_2,vocabulary_id_2)
SELECT distinct
                aa.concept_code as concept_code_1,
              'Is a' as relationship_id,
                aa.vocabulary_id as vocabulary_id_1,
                NULL as invalid_reason,
                CURRENT_DATE AS valid_start_date,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                c.concept_code as concept_code_2,
                c.vocabulary_id as vocabulary_id_2
FROM concept_manual_nodes aa
JOIN devv5.concept  c
on c.concept_id = 36769180	--	Metastasis
where aa.concept_name='Distant spread to lymph node'
;

--Axis for distant spread creation
INSERT INTO concept_relationship_manual_nodes (concept_code_1, relationship_id, vocabulary_id_1, invalid_reason, valid_start_date, valid_end_date, concept_code_2,vocabulary_id_2)
SELECT distinct
                aa.concept_code as concept_code_1,
              'Is a' as relationship_id,
                aa.vocabulary_id as vocabulary_id_1,
                NULL as invalid_reason,
                CURRENT_DATE AS valid_start_date,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                c.concept_code as concept_code_2,
                c.vocabulary_id as vocabulary_id_2
FROM concept_manual_nodes aa
JOIN concept_manual_nodes  c
on c.concept_name = 'Distant spread to lymph node'
where aa.concept_name!='Distant spread to lymph node'
and aa.concept_name ilike 'Distant%'
;

--Axis for regional spread creation
INSERT INTO concept_relationship_manual_nodes (concept_code_1, relationship_id, vocabulary_id_1, invalid_reason, valid_start_date, valid_end_date, concept_code_2,vocabulary_id_2)
SELECT distinct
                aa.concept_code as concept_code_1,
              'Is a' as relationship_id,
                aa.vocabulary_id as vocabulary_id_1,
                NULL as invalid_reason,
                CURRENT_DATE AS valid_start_date,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                c.concept_code as concept_code_2,
                c.vocabulary_id as vocabulary_id_2
FROM concept_manual_nodes aa
JOIN concept_manual_nodes  c
on c.concept_name = 'Regional spread to lymph node'
where aa.concept_name!='Regional spread to lymph node'
and aa.concept_name ilike 'Regional%'
;


-- Use for mapping of existing CM codes
SELECT distinct
null as concept_id,concept_code,concept_name,standard_concept,invalid_reason,concept_class_id, domain_id,vocabulary_id
FROM concept_manual_nodes
order by concept_name desc
;

--For mapping
SELECT distinct concept_code,concept_name,vocabulary_id
FROM devv5.concept c
WHERE c.vocabulary_id='Cancer Modifier'
and concept_class_id='Nodes'
;

SELECT distinct
null as concept_id,concept_code,concept_name,standard_concept,invalid_reason,concept_class_id, domain_id,vocabulary_id
FROM concept_manual_nodes
where concept_code  in (SELECT concept_code_2 from concept_relationship_manual_nodes where relationship_id='Subsumes' )
--and concept_name ilike 'Spread%'
order by concept_name desc
;

SELECT distinct c.concept_name,r.relationship_id,coalesce(cc.concept_name,ccc.concept_name)
from concept_relationship_manual_nodes r
    left join concept_manual_nodes c on r.concept_code_1 = c.concept_code
    left join concept_manual_nodes cc on r.concept_code_2 = cc.concept_code
  left   join concept  ccc on r.concept_code_2 = ccc.concept_code and ccc.vocabulary_id='Cancer Modifier'

where r.relationship_id in ('Subsumes','Is a')
;
SELECT *
from concept_relationship_manual_nodes r
