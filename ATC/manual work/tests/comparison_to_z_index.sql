---- information from z-index
SELECT  t3.concept_id,
        t3.concept_code,
        t3.concept_name,
        t2.concept_id,
        t2.concept_name,
        t2.concept_class_id
FROM dev_atc.zindex_full t1
     JOIN devv5.concept t2 on t1.targetid = t2.concept_id and t2.concept_class_id = 'Clinical Drug Form'
     JOIN devv5.concept t3 on t1.atc = t3.concept_code AND t3.vocabulary_id = 'ATC';

---- information from devv5.concept_relationship

select c1.concept_id,
        c1.concept_code,
        c1.concept_name,
        c2.concept_id,
        c2.concept_name,
        c2.concept_class_id
from devv5.concept_relationship cr
     join devv5.concept c1 on cr.concept_id_1 = c1.concept_id and cr.relationship_id = 'ATC - RxNorm'
                                                                  and c1.invalid_reason is NULL
                                                                  and cr.invalid_reason is NULL
                                                                  and c1.vocabulary_id = 'ATC'
     join devv5.concept c2 on cr.concept_id_2 = c2.concept_id and c2.invalid_reason is NULL
                                                              and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension');


--- Codes from Z-Index that do not exist in our system
WITH our_connections as (select c1.concept_id as ATC_id,
                                c1.concept_code as ATC_code,
                                c1.concept_name as ATC_name,
                                c2.concept_id RX_id,
                                c2.concept_name as RX_name,
                                c2.concept_class_id as RX_class
                        from devv5.concept_relationship cr
                             join devv5.concept c1 on cr.concept_id_1 = c1.concept_id and cr.relationship_id = 'ATC - RxNorm'
                                                                                          and c1.invalid_reason is NULL
                                                                                          and cr.invalid_reason is NULL
                                                                                          and c1.vocabulary_id = 'ATC'
                             join devv5.concept c2 on cr.concept_id_2 = c2.concept_id and c2.invalid_reason is NULL
                                                                                      and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension'))


SELECT DISTINCT
        t2.concept_id,
        t2.concept_name,
        t2.concept_class_id,
        string_agg(DISTINCT t3.concept_code, ', ') as z_index_assign,
        string_agg(DISTINCT t4.ATC_CODE, ', ') as our_assign
FROM dev_atc.zindex_full t1
     JOIN devv5.concept t2 on t1.targetid = t2.concept_id and t2.concept_class_id = 'Clinical Drug Form'
     JOIN devv5.concept t3 on t1.atc = t3.concept_code AND t3.vocabulary_id = 'ATC'
     left JOIN OUR_CONNECTIONS t4 on t1.targetid = t4.RX_ID
WHERE (t3.concept_code, t2.concept_id) not in (select
                                                        c1.concept_code,
                                                        c2.concept_id
                                                from devv5.concept_relationship cr
                                                     join devv5.concept c1 on cr.concept_id_1 = c1.concept_id and cr.relationship_id = 'ATC - RxNorm'
                                                                                                                  and c1.invalid_reason is NULL
                                                                                                                  and cr.invalid_reason is NULL
                                                                                                                  and c1.vocabulary_id = 'ATC'
                                                     join devv5.concept c2 on cr.concept_id_2 = c2.concept_id and c2.invalid_reason is NULL
                                                                                                              and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension'))
AND length (t3.concept_code) = 7
GROUP BY t2.concept_id, t2.concept_name, t2.concept_class_id
ORDER BY t2.concept_id;


----- see 1 to many in previous release, dev_dev, and compare to current state devv5.
create table multiply_rxnorm_per_1_atc as
with old_multiply as (select
        c1.concept_code,
        string_agg(DISTINCT c2.concept_name, CHR(10) ORDER BY c2.concept_name) as connected_forms,
        count(DISTINCT c2.concept_id) as cnt_old
from dev_dev.concept_relationship cr
     join dev_dev.concept c1 on cr.concept_id_1 = c1.concept_id and cr.relationship_id = 'ATC - RxNorm'
                                                                  and c1.invalid_reason is NULL
                                                                  and cr.invalid_reason is NULL
                                                                  and c1.vocabulary_id = 'ATC'
     join dev_dev.concept c2 on cr.concept_id_2 = c2.concept_id and c2.invalid_reason is NULL
                                                              and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                              and c2.concept_class_id = 'Clinical Drug Form'
GROUP BY c1.concept_code HAVING count(DISTINCT c2.concept_id)>1),
    new_multuply as (select
                            c1.concept_code,
                            string_agg(DISTINCT c2.concept_name, CHR(10) ORDER BY c2.concept_name) as connected_forms,
                            count(DISTINCT c2.concept_id) as cnt_new
                    from devv5.concept_relationship cr
                         join devv5.concept c1 on cr.concept_id_1 = c1.concept_id and cr.relationship_id = 'ATC - RxNorm'
                                                                                      and c1.invalid_reason is NULL
                                                                                      and cr.invalid_reason is NULL
                                                                                      and c1.vocabulary_id = 'ATC'
                         join devv5.concept c2 on cr.concept_id_2 = c2.concept_id and c2.invalid_reason is NULL
                                                                                  and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                                  and c2.concept_class_id = 'Clinical Drug Form'
                    GROUP BY c1.concept_code HAVING count(DISTINCT c2.concept_id)>1)
SELECT t2.concept_code,
       t2.connected_forms as connected_forms_old,
       t2.CNT_OLD,
       t1.cnt_new - t2.cnt_old as cnt_differnce,
       t1.cnt_new,
       t1.CONNECTED_FORMS as connected_forms_new
FROM
    NEW_MULTUPLY t1
    JOIN OLD_MULTIPLY t2 on t1.concept_code = t2.concept_code;

select *
from dev_atatur.multiply_rxnorm_per_1_atc;


----- number of different ATC codes per one rxnorm_id
create table rxnorm_w_multiply_atc as
with old_rxn_atc as (select
        c2.concept_id,
        c2.concept_name,
        string_agg(DISTINCT c1.concept_code, CHR(10) ORDER BY c1.concept_code) as connected_ATC_old,
        count(DISTINCT c1.concept_code) as cnt_old
from dev_dev.concept_relationship cr
     join dev_dev.concept c1 on cr.concept_id_1 = c1.concept_id and cr.relationship_id = 'ATC - RxNorm'
                                                                  and c1.invalid_reason is NULL
                                                                  and cr.invalid_reason is NULL
                                                                  and c1.vocabulary_id = 'ATC'
     join dev_dev.concept c2 on cr.concept_id_2 = c2.concept_id and c2.invalid_reason is NULL
                                                              and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                              and c2.concept_class_id = 'Clinical Drug Form'
GROUP BY c2.concept_id,
         c2.concept_name HAVING count(DISTINCT c1.concept_code)>1),
    new_rxn_atc as (select
                            c2.concept_id,
                            c2.concept_name,
                            string_agg(DISTINCT c1.concept_code, CHR(10) ORDER BY c1.concept_code) as connected_ATC_new,
                            count(DISTINCT c1.concept_code) as cnt_new
                    from devv5.concept_relationship cr
                         join devv5.concept c1 on cr.concept_id_1 = c1.concept_id and cr.relationship_id = 'ATC - RxNorm'
                                                                                      and c1.invalid_reason is NULL
                                                                                      and cr.invalid_reason is NULL
                                                                                      and c1.vocabulary_id = 'ATC'
                         join devv5.concept c2 on cr.concept_id_2 = c2.concept_id and c2.invalid_reason is NULL
                                                                                  and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
                                                                                  and c2.concept_class_id = 'Clinical Drug Form'
                    GROUP BY c2.concept_id,
                             c2.concept_name HAVING count(DISTINCT c1.concept_code)>1)
SELECT t1.concept_id,
       t1.concept_name,
       t1.CNT_NEW,
       t1.CNT_NEW - t2.CNT_OLD as cnt_diff,
       t2.CNT_OLD,
       t1.CONNECTED_ATC_NEW,
       t2.CONNECTED_ATC_OLD
FROM NEW_RXN_ATC t1
     join OLD_RXN_ATC t2 on t1.concept_id=t2.concept_id;


select sum(cnt_diff)
from rxnorm_w_multiply_atc
where cnt_diff != 0 ;