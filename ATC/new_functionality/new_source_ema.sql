select DISTINCT t1.concept_id,
       t2.atc_code_human,
       'ema' AS source
from devv5.concept t1
     JOIN sources.ema_medicines_output_post_authorisation_en t2 on lower(t1.concept_name) = lower(t2.name_of_medicine)
                                                                and t1.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                and t1.concept_class_id = 'Brand Name'
                                                                and t1.invalid_reason is NULL
where t2.atc_code_human is not null;