INSERT INTO concept_manual
select t2.concept_name,
       t2.domain_id,
       t2.vocabulary_id,
       t2.concept_class_id,
       t2.standard_concept,
       t2.concept_code,
       t2.valid_start_date,
       TO_DATE('2099-12-31', 'YYYY-MM-DD') AS valid_end_date,
       'D' as invalid_reason
from devv5.concept t1
     join devv5.concept_ancestor ca on t1.concept_id = ca.ancestor_concept_id
                                    and t1.concept_id in (40963890, 36074314, 40827674, 40864917, 40857357, 41328994)
     join devv5.concept t2 on ca.descendant_concept_id = t2.concept_id
                            and t2.concept_class_id in ('Clinical Drug Comp',
                                                        'Branded Drug Comp',
                                                        'Clinical Drug',
                                                        'Branded Drug',
                                                        'Branded Drug Box',
                                                        'Marketed Product',
                                                        'Quant Branded Box',
                                                        'Quant Branded Drug')
UNION

select t2.concept_name,
       t2.domain_id,
       t2.vocabulary_id,
       t2.concept_class_id,
       t2.standard_concept,
       t2.concept_code,
       t2.valid_start_date,
       TO_DATE('2099-12-31', 'YYYY-MM-DD') AS valid_end_date,
       'D' as invalid_reason
from devv5.concept t1
     join devv5.concept_ancestor ca on t1.concept_id = ca.descendant_concept_id
                                    and t1.concept_id in (40963890, 36074314, 40827674, 40864917, 40857357, 41328994)
     join devv5.concept t2 on ca.ancestor_concept_id = t2.concept_id
                            and t2.concept_class_id in ('Clinical Drug Comp',
                                                        'Branded Drug Comp',
                                                        'Clinical Drug',
                                                        'Branded Drug',
                                                        'Branded Drug Box',
                                                        'Marketed Product',
                                                        'Quant Branded Box',
                                                        'Quant Branded Drug')

;