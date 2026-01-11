INSERT INTO concept_manual
select t2.concept_name,
       t2.domain_id,
       t2.vocabulary_id,
       t2.concept_class_id,
       t2.standard_concept,
       t2.concept_code,
       t2.valid_start_date,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD')  AS valid_end_date,
       'D' as invalid_reason
from devv5.concept t1
     join devv5.concept_ancestor ca on t1.concept_id = ca.ancestor_concept_id
                                    and t1.concept_id in (41332121, 41328809, 41337516, 40989652, 41239597, 41051817, 41336863, 41327509,40963890, 36074314, 40827674, 40864917, 40857357, 41328994, 41049409, 35774854, 35749646, 35766266)
     join devv5.concept t2 on ca.descendant_concept_id = t2.concept_id
                            and t2.concept_class_id in ('Clinical Drug Comp',
                                                        'Branded Drug Comp',
                                                        'Clinical Drug',
                                                        'Branded Drug',
                                                        'Branded Drug Box',
                                                        'Marketed Product',
                                                        'Quant Branded Box',
                                                        'Quant Branded Drug',
                                                        'Branded Drug Form',
                                                       'Quant Clinical Drug',
                                                       'Quant Clinical Box',
                                                       'Clinical Drug Box')
                            and t2.vocabulary_id = 'RxNorm Extension'
UNION

select t2.concept_name,
       t2.domain_id,
       t2.vocabulary_id,
       t2.concept_class_id,
       t2.standard_concept,
       t2.concept_code,
       t2.valid_start_date,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD')  AS valid_end_date,
       'D' as invalid_reason
from devv5.concept t1
     join devv5.concept_ancestor ca on t1.concept_id = ca.descendant_concept_id
                                    and t1.concept_id in (41332121, 41328809, 41337516, 40989652, 41239597, 41051817, 41336863, 41327509,40963890, 36074314, 40827674, 40864917, 40857357, 41328994, 41049409, 35774854, 35749646, 35766266)
     join devv5.concept t2 on ca.ancestor_concept_id = t2.concept_id
                            and t2.concept_class_id in ('Clinical Drug Comp',
                                                        'Branded Drug Comp',
                                                        'Clinical Drug',
                                                        'Branded Drug',
                                                        'Branded Drug Box',
                                                        'Marketed Product',
                                                        'Quant Branded Box',
                                                        'Quant Branded Drug',
                                                        'Branded Drug Form',
                                                       'Quant Clinical Drug',
                                                       'Quant Clinical Box',
                                                       'Clinical Drug Box')
                                            and t2.vocabulary_id = 'RxNorm Extension'
;


