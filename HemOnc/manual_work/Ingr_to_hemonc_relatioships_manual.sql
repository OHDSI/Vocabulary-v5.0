--one-off use .sql
-- In order to preserve inetervocabulary structure  working with newly created RxIngredients (mostly -  reclassified Precise Ingredients) we have to build reliable links from de-novo Rxs to HemOnc
--The approach is to build the relationships from Rx Ings to HemOnc use the script cloning all the relevant links from HemOnc components to HemOnc Others

-- 1st check all valid relationships from Rx Ingredient to HemOnc concepts in existing dev schema
SELECT distinct cr.relationship_id
FROM devv5.concept c
         join devv5.concept_relationship cr
              ON c.concept_id = cr.concept_id_1 and c.concept_class_id = 'Ingredient' and c.vocabulary_id = 'RxNorm'
         join devv5.concept cc
             on cr.concept_id_2 = cc.concept_id and cc.vocabulary_id = 'HemOnc'
where cr.invalid_reason is null
;

-- If needed - restrict not relevant links in script below
--2nd create clones for all relevant relationships
SELECT distinct 'RxE Ingredient'                                                                                  as concept_code_1,
                cc.concept_code                                                                                       as concept_code_2,
                'RxNorm Extension'                                                                                    as vocabulary_id_1,
                cc.vocabulary_id                                                                                      as vocabulary_id_2,
                CASE
                    when cr.relationship_id = 'Antineoplastic of' then 'Rx antineopl of'
                    ELSE cr.relationship_id end                                                                       as relationship_id,
                CURRENT_DATE                                                                                          as valid_start_date,
                TO_DATE('20991231', 'yyyymmdd')                                                                       AS valid_end_date,
                cc.invalid_reason,
                c.concept_name                                                                                        as component_name,
                cc.concept_name                                                                                       as regimen_name
FROM devv5.concept c
         join devv5.concept_relationship cr
              ON c.concept_id = cr.concept_id_1 and c.concept_code = '3590' and c.vocabulary_id = 'HemOnc'
         join devv5.concept cc on cr.concept_id_2 = cc.concept_id and cc.vocabulary_id = 'HemOnc'
where cr.invalid_reason is null
  AND cr.relationship_id NOT IN
      (
       'Has accepted use',
       'Has brand name',
       'Has FDA indication',
       'May have route'
          )
ORDER BY concept_code_1, relationship_id, concept_code_2
;
