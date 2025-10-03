--  This script collects comparative numbers on the categories of the non-standard concepts, grouped by vocabularies and their status, between two latest releases.
--- Used to generate the report on mapping_coverage: https://github.com/OHDSI/Vocabulary-v5.0/wiki/Quality-Management-System-reports

    /*
-- steps to update concept_metadata table reflecting flags
-- create a space to work with
create temp table ns_space
    as
select * from prodv5.concept c
       where (c.standard_concept is null and c.invalid_reason is null)
            and c.concept_id not in (select concept_id from prodv5.concept_metadata)
            and not exists (select 1
                            from prodv5.concept_relationship cr
                            where cr.relationship_id = 'Maps to'
                              and cr.concept_id_1 = c.concept_id
                              and cr.invalid_reason is null)
;

-- create a local copy for update
create temp table concept_metadata
    as
select * from prodv5.concept_metadata;

-- make category names explicit (once)
update concept_metadata
set concept_category = case
                  when concept_category = 'M' then 'Metadata'
                  when concept_category = 'A' then 'Attribute'
                  when concept_category = 'J' then 'Out-of-scope' 
                  else concept_category
    end;


-- out-of-scope
insert into concept_metadata
select concept_id, 'Out-of-scope' as concept_category, NULL as reuse_status
from ns_space
where
    (vocabulary_id = 'PCORNet' and concept_class_id in ('Procedure Code Type', 'Undefined', 'DRG Type', 'Diagnosis Code Type'))
  and concept_id not in (select concept_id from concept_metadata)
;

insert into concept_metadata
select concept_id, 'Out-of-scope' as concept_category, NULL as reuse_status
from ns_space
where (lower(concept_name) like 'not %'
   or lower(concept_name) like 'unknown%'
   or lower(concept_name) like 'unavailable%'
   or lower(concept_name) like '%declined%'
   or concept_name in ('n/a', 'no', 'not'))
and concept_id not in (select concept_id from concept_metadata)
-- for subsequent review, add llm
-- or lower(concept_name) like '%miscellaneous%'
-- or lower(concept_name) like 'no %'
-- or lower(concept_name) like '% not %'
-- or lower(concept_name) like '% no %'
;

-- attributes and supporting concepts, non-standard by design
insert into concept_metadata
select concept_id, 'Attribute' as concept_category, NULL as reuse_status
from ns_space
    where
    ((vocabulary_id = 'LOINC' and concept_class_id in ('LOINC Component', 'LOINC Method', 'LOINC System',
                                                         'LOINC Scale', 'LOINC Property', 'LOINC Time'))
       or
    (vocabulary_id = 'NDFRT' and concept_class_id in ('Physiologic Effect', 'Pharmacologic Class', 'Therapeutic Class'))
       or
    (vocabulary_id = 'SNOMED' and concept_class_id in ('Admin Concept', 'Record Artifact'))
       or
    (vocabulary_id = 'Nebraska Lexicon' and concept_class_id in ('Admin Concept', 'Record Artifact'))
       or
    (vocabulary_id = 'Cancer Modifier' and concept_class_id in ('Morph Abnormality', 'Qualifier Value'))
       or
    (vocabulary_id = 'HemOnc' and concept_class_id in ('Route'))
       or
    (vocabulary_id = 'OPCS4' and concept_class_id in ('Attribute'))
       or
    (vocabulary_id like 'RxNorm%' and concept_class_id in ('Brand Name', 'Dose Form', 'Precise Ingredient', 'Multiple Ingredients'))
    )
    and concept_id not in (select concept_id from concept_metadata)
;

-- classificational in nature, keep this as a temporary category
insert into concept_metadata
select concept_id, 'Classification' as concept_category, NULL as reuse_status
 from ns_space
    where
    ((vocabulary_id = 'CCAM' and concept_class_id in ('Proc Group', 'Proc Hierarchy'))
       or
    (vocabulary_id in ('ICD10', 'ICD10CM', 'ICD9CM', 'KCD7', 'CIM10', 'ICD10GM', 'ICD10CN') and concept_class_id in ('ICD10 Hierarchy'))
       or
    (vocabulary_id = 'NDFRT' and concept_class_id in ('Mechanism of Action'))
       or
    (vocabulary_id = 'VA Class' and concept_class_id in ('VA Class')))
      and concept_id not in (select concept_id from concept_metadata)
   ;

-- adding explicit category mappable
insert into concept_metadata
select concept_id, 'Mappable', NULL as reuse_status
from ns_space
where
 vocabulary_id in ('NDC', 'CIEL', 'CDISC', 'NAACCR', -- for now classified as mappable but require further investigation
 'ICD10', 'ICD10CM', 'ICD9CM', 'KCD7', 'CIM10', 'ICD10GM', 'ICD10CN', 'Read', 'EDI', 'SNOMED Veterinary',-- assume mappable
 'MeSH', -- non-standard by design because headings', 'but doesn't really fit our categories
 'CAP', -- looks like question-answer pairs for cancer
 'ICD9ProcCN',
 'AMIS', 'AMT', 'BDPM', 'CGI', 'CIM10', 'SUS',  'CO-CONNECT', 'CO-CONNECT TWINS', 'CO-CONNECT MIABIS',
 'CTD', 'DA_France', 'dm+d', 'DPD', 'EDI', 'EORTC QLQ', 'GCN_SEQNO', 'Gemscript', 'GGR', 'GRR', 'GPI', 'JAX', 'JMDC', 'KDC',
 'LPD_Australia', 'LPD_Belgium', 'MedDRA', 'Multilex', 'Multum', 'NCCD', 'NCIt', 'OMOP Invest Drug',
 'COSMIC', 'OncoKB', 'OncoTree', 'CGI', 'CIViC', 'ClinVar', 'ICDO3',
 'OPS', 'OXMIS', 'PPI', 'SPL', 'UB04 Point of Origin', 'UB04 Pt dis status', 'UB04 Typ bill', 'VANDF', 'UK Biobank',
 'HCPCS', 'HES Specialty'
 )
  and concept_id not in (select concept_id from concept_metadata)
 ;

insert into concept_metadata
select concept_id, 'Mappable', NULL as reuse_status
from ns_space
where
    ((vocabulary_id = 'CCAM' and concept_class_id in ('Procedure'))
   or
     (vocabulary_id = 'SNOMED' and concept_class_id in ('Substance', 'Pharma/Biol Product'))
   or
    (vocabulary_id in ('HemOnc') and concept_class_id in ('Component', 'Procedure', 'Condition'))
   or
    (vocabulary_id = 'NDFRT' and concept_class_id in ('Pharma Preparation', 'VA Product'))
   or
    (vocabulary_id = 'OPCS4' and concept_class_id not in ('OPCS4 Attribute'))
   or
    (vocabulary_id = 'Nebraska Lexicon' and concept_class_id not in ('Admin Concept', 'Record Artifact'))
    )   and concept_id not in (select concept_id from concept_metadata)
;

-- make sure there are no duplicates with different categories
select concept_id, count(*), 'Different categories' as error
from concept_metadata
    group by concept_id having count(1)>1
;
*/

-- 1. Collect numbers across the last two releases
with recent_release as(
    select case
               when c.vocabulary_id in
                    ('AMIS', 'BDPM', 'CGI', 'DPD', 'EphMRA ATC', 'ETC', 'GCN_SEQNO', 'GPI', 'Indication', 'ISBT',
                     'ISBT Attribute',
                     'KNHIS', 'Korean Revenue Code', 'MMI', 'Multilex', 'Multum', 'NDFRT', 'NFC', 'OncoKB',
                     'OncoTree', 'OSM', 'OXMIS',
                     'PCORNet', 'SUS', 'SAP', 'SMQ', 'Visit Type', 'AMT', 'APC', 'CAP', 'CCAM', 'CTD'
                         -- those that were refreshed in the past 4 years but for which we need stewards
                      'CDT', 'DRG', 'Gemscript', 'GGR', 'GRR', 'ICD9ProcCN', 'JAX', 'MeSH', 'NCCD', 'NUCC',
                     'OPCS4', 'OPS', 'SOPT',
                     'UB04 Point of Origin', 'UB04 Pt dis status', 'UB04 Typ bill', 'VA Class'
                        )
                   then 'Abandoned'
               when c.vocabulary_id in
                    ('CIEL', 'EDI', 'EORTC QLQ', 'HemOnc', 'ICDO3', 'JMDC', 'KCD7', 'KDC', 'SNOMED Veterinary',
                     'Nebraska Lexicon',
                     'NCIt', 'NAACCR', 'PPI', 'Cancer Modifier', 'CDISC', 'CIViC', 'ClinVar', 'CO-CONNECT',
                     'CO-CONNECT MIABIS',
                     'CO-CONNECT TWINS', 'COSMIC', 'DA_France', 'dm+d', 'LPD_Australia', 'LPD_Belgium',
                     'OMOP Genomic', 'PPI'
                        )
                   then 'Steward'
               when c.vocabulary_id in
                    ('CPT4', 'HCPCS', 'SNOMED', 'MedDRA', 'ICD10CM', 'ICD9CM', 'ICD10', 'ICD10CN', 'ICD10GM',
                     'CIM10', 'KCD7', 'Mesh', 'UK Biobank', 'ICD9Proc', 'VANDF', 'OMOP Invest Drug', 'Read',
                     'RxNorm',
                     'RxNorm Extension', 'CVX', 'NDC', 'SPL', 'ATC', 'LOINC', 'ICD10PCS', 'Gender', 'Race',
                     'UCUM',
                     'CMS Place of Service', 'Medicare Specialty', 'HES Specialty'
                        ) then 'Roadmap'
               else null end as vocab_status,
           concept_category,
           count(*) as count
    from prodv5.concept c
             left join prodv5.concept_metadata m using (concept_id)
    where (c.standard_concept is null or c.standard_concept = 'C')
      and not exists (select 1
                      from prodv5.concept_relationship cr
                      where cr.relationship_id = 'Maps to'
                        and cr.concept_id_1 = c.concept_id
                        and cr.invalid_reason is null)
    group by vocab_status, concept_category
    order by 1,2,3),

     previous_release as (
         select case
                    when c.vocabulary_id in
                         ('AMIS', 'BDPM', 'CGI', 'DPD', 'EphMRA ATC', 'ETC', 'GCN_SEQNO', 'GPI', 'Indication', 'ISBT',
                          'ISBT Attribute',
                          'KNHIS', 'Korean Revenue Code', 'MMI', 'Multilex', 'Multum', 'NDFRT', 'NFC', 'OncoKB',
                          'OncoTree', 'OSM', 'OXMIS',
                          'PCORNet', 'SUS', 'SAP', 'SMQ', 'Visit Type', 'AMT', 'APC', 'CAP', 'CCAM', 'CTD'
                              -- those that were refreshed in the past 4 years but for which we need stewards
                           'CDT', 'DRG', 'Gemscript', 'GGR', 'GRR', 'ICD9ProcCN', 'JAX', 'MeSH', 'NCCD', 'NUCC',
                          'OPCS4', 'OPS', 'SOPT',
                          'UB04 Point of Origin', 'UB04 Pt dis status', 'UB04 Typ bill', 'VA Class'
                             )
                        then 'Abandoned'
                    when c.vocabulary_id in
                         ('CIEL', 'EDI', 'EORTC QLQ', 'HemOnc', 'ICDO3', 'JMDC', 'KCD7', 'KDC', 'SNOMED Veterinary',
                          'Nebraska Lexicon',
                          'NCIt', 'NAACCR', 'PPI', 'Cancer Modifier', 'CDISC', 'CIViC', 'ClinVar', 'CO-CONNECT',
                          'CO-CONNECT MIABIS',
                          'CO-CONNECT TWINS', 'COSMIC', 'DA_France', 'dm+d', 'LPD_Australia', 'LPD_Belgium',
                          'OMOP Genomic', 'PPI'
                             )
                        then 'Steward'
                    when c.vocabulary_id in
                         ('CPT4', 'HCPCS', 'SNOMED', 'MedDRA', 'ICD10CM', 'ICD9CM', 'ICD10', 'ICD10CN', 'ICD10GM',
                          'CIM10', 'KCD7', 'Mesh', 'UK Biobank', 'ICD9Proc', 'VANDF', 'OMOP Invest Drug', 'Read',
                          'RxNorm',
                          'RxNorm Extension', 'CVX', 'NDC', 'SPL', 'ATC', 'LOINC', 'ICD10PCS', 'Gender', 'Race',
                          'UCUM',
                          'CMS Place of Service', 'Medicare Specialty', 'HES Specialty'
                             ) then 'Roadmap'
                    else null end as vocab_status,
                concept_category,
                count(*) as count
         from dev_qaathena.concept c
                  left join prodv5.concept_metadata m using (concept_id)
         where (c.standard_concept is null)
           and not exists (select 1
                           from dev_qaathena.concept_relationship cr
                           where cr.relationship_id = 'Maps to'
                             and cr.concept_id_1 = c.concept_id
                             and cr.invalid_reason is null)
         group by vocab_status,
                  concept_category
         order by 1,2,3
     )

select a.vocab_status, a.concept_category,
       f.count as previous_cnt, a.count as recent_cnt
from recent_release a
         join previous_release f using (vocab_status, concept_category);



-- 2. Investigational scripts:
-- 2.1. Rule: every non-S concept should be mapped to Standard, or mapped to 0
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

-- 2.2. Concepts in selected vocabulary and domain which are non-standard without valid mapping
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


-- 2.3. Patrick’s version of QC check:
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