### Manual content processing:
1.Extract the following csv file into the concept_manual table:

File is generated using the query:

`SELECT concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_manual
ORDER BY vocabulary_id, concept_code, invalid_reason, valid_start_date, valid_end_date, concept_name`

2.Extract the following csv file into the concept_synonym_manual table:

`SELECT synonym_name,
       synonym_concept_code,
       synonym_vocabulary_id,
       language_concept_id
FROM concept_synonym_manual
ORDER BY synonym_vocabulary_id, synonym_concept_code, language_concept_id, synonym_name`

3.Extract the following csv file into the concept_relationship_manual table: https://docs.google.com/spreadsheets/d/1THz5xZAkmdqUSAGct9z8Jh6f00_FSt49J89p55rRhDo/edit#gid=0
To build the relationships from Rx Ings to HemOnc use the script cloning all the relevant links from HemOnc components -> HemOnc Others
-- 1st check all possible relationships from
    SELECT distinct cr.relationship_id -
FROM devv5.concept c
    join devv5.concept_relationship cr
        ON c.concept_id=cr.concept_id_1 and c.concept_class_id='Ingredient' and c.vocabulary_id='RxNorm'
join devv5.concept cc on cr.concept_id_2=cc.concept_id and cc.vocabulary_id='HemOnc'
where cr.invalid_reason is null
;
--2nd create clones for all relevant relationships
SELECT distinct 'RxE Ingredient' as concept_code_1,cc.concept_code  as concept_code_2, 'RxNorm Extension' as vocabulary_id_1,cc.vocabulary_id as vocabulary_id_2,
                CASE when cr.relationship_id='Antineoplastic of' then 'Rx antineopl of'  ELSE cr.relationship_id end as relationship_id,
  CURRENT_DATE as valid_start_date,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                    cc.invalid_reason,
                    c.concept_name as component_name,
    cc.concept_name as regimen_name
FROM devv5.concept c
 join devv5.concept_relationship cr
ON c.concept_id=cr.concept_id_1 and  c.concept_code='3590' and c.vocabulary_id='HemOnc'
join devv5.concept cc on cr.concept_id_2=cc.concept_id and cc.vocabulary_id='HemOnc'
where cr.invalid_reason is null
AND cr.relationship_id NOT IN
(
'Has accepted use',
'Has brand name',
'Has FDA indication',
'May have route'
    )
    ORDER BY concept_code_1,relationship_id,concept_code_2
;
`SELECT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_relationship_manual
ORDER BY vocabulary_id_1, vocabulary_id_2, relationship_id, concept_code_1, concept_code_2, invalid_reason, valid_start_date, valid_end_date
;`
