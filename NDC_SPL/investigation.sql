DROP TABLE IF EXISTS umls_ndc_rxnorm_mappings;
CREATE TABLE umls_ndc_rxnorm_mappings as
with codes as

    (
        SELECT
    atv AS original_ndc,

    replace(
        CASE
            -- Case when 'atv' does not contain '-'
            WHEN strpos(atv, '-') = 0 THEN
                CASE
                    WHEN length(atv) = 11 THEN atv
                    WHEN length(atv) = 12 THEN substring(atv FROM 2 FOR 11)
                    ELSE NULL
                END
            ELSE
                CASE
                    WHEN length(split_part(atv, '-', 1)) = 5 AND length(split_part(atv, '-', 2)) = 3 THEN
                        concat(
                            split_part(atv, '-', 1), '-',
                            '0', split_part(atv, '-', 2), '-',
                            split_part(atv, '-', 3)
                        )
                    WHEN length(split_part(atv, '-', 1)) = 4 AND length(split_part(atv, '-', 2)) = 4 THEN
                        concat(
                            '0', split_part(atv, '-', 1), '-',
                            split_part(atv, '-', 2), '-',
                            split_part(atv, '-', 3)
                        )
                    WHEN
                        length(split_part(atv, '-', 1)) = 5 AND length(split_part(atv, '-', 2)) = 4 AND length(split_part(atv, '-', 3)) = 1 THEN
                        concat(
                            split_part(atv, '-', 1), '-',
                            split_part(atv, '-', 2), '-',
                            '0', split_part(atv, '-', 3)
                        )
                    ELSE
                        atv
                END
        END,
        '-', ''
    ) AS concept_code,
    sab,
    rxaui,
    rxcui
FROM
    sources.rxnsat
WHERE
    atn = 'NDC'
   -- and suppress = 'N'
    )
select t1.sab,
       t1.ORIGINAL_NDC,
       t1.CONCEPT_CODE as ndc_code,
       t2.str as ndc_code_name,
       t3.concept_code as rxnorm_concept_code,
       t3.concept_name as rxnorm_concept
from CODES t1
join sources.rxnconso t2 on t1.rxaui=t2.rxaui --and t2.suppress = 'N'
join devv5.concept t3 on t1.rxcui = t3.concept_code and t3.invalid_reason is null and t3.vocabulary_id = 'RxNorm';

DROP TABLE if EXISTS umls_ndc_codes;
CREATE TABLE umls_ndc_codes as
with codes as

    (
        SELECT
    atv AS original_ndc,

    replace(
        CASE
            -- Case when 'atv' does not contain '-'
            WHEN strpos(atv, '-') = 0 THEN
                CASE
                    WHEN length(atv) = 11 THEN atv
                    WHEN length(atv) = 12 THEN substring(atv FROM 2 FOR 11)
                    ELSE NULL
                END
            ELSE
                CASE
                    WHEN length(split_part(atv, '-', 1)) = 5 AND length(split_part(atv, '-', 2)) = 3 THEN
                        concat(
                            split_part(atv, '-', 1), '-',
                            '0', split_part(atv, '-', 2), '-',
                            split_part(atv, '-', 3)
                        )
                    WHEN length(split_part(atv, '-', 1)) = 4 AND length(split_part(atv, '-', 2)) = 4 THEN
                        concat(
                            '0', split_part(atv, '-', 1), '-',
                            split_part(atv, '-', 2), '-',
                            split_part(atv, '-', 3)
                        )
                    WHEN
                        length(split_part(atv, '-', 1)) = 5 AND length(split_part(atv, '-', 2)) = 4 AND length(split_part(atv, '-', 3)) = 1 THEN
                        concat(
                            split_part(atv, '-', 1), '-',
                            split_part(atv, '-', 2), '-',
                            '0', split_part(atv, '-', 3)
                        )
                    ELSE
                        atv
                END
        END,
        '-', ''
    ) AS concept_code,
    sab,
    rxaui,
    rxcui
FROM
    sources.rxnsat
WHERE
    atn = 'NDC'
   -- and suppress = 'N'
    )
select t1.CONCEPT_CODE as ndc_code
from CODES t1;

---- New NDC codes, that could be added
select DISTINCT *
from umls_ndc_codes
where ndc_code not in (select concept_code from devv5.concept where vocabulary_id = 'NDC' and concept_class_id = '11-digit NDC');

--- Codes in devv5 that are unique (predominantly FDA codes)
select *
from devv5.concept
where vocabulary_id = 'NDC'
and concept_class_id = '11-digit NDC'
and concept_code not in (select * from umls_ndc_codes);

--- New codes where we could be obtain mappings using UMLS
SELECT DISTINCT ndc_code, rxnorm_concept_code
FROM umls_ndc_rxnorm_mappings
where ndc_code  not in (select concept_code
                                from concept
                                WHERE vocabulary_id = 'NDC')
    AND SUBSTRING(ndc_code FROM 1 FOR 10) not in (select concept_code
                                from concept
                                WHERE vocabulary_id = 'NDC');

---- Mappings that are unique in devv5
select c1.concept_id,
       c1.concept_code,
       c1.concept_name,
       c2.concept_id,
       c2.concept_name
from devv5.concept_relationship cr
join devv5.concept c1 on cr.concept_id_1 =  c1.concept_id and vocabulary_id = 'NDC' and c1. concept_class_id = '11-digit NDC'
join devv5.concept c2 on cr.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
where (c1.concept_code, c2.concept_code) not in (select ndc_code, rxnorm_concept_code from umls_ndc_rxnorm_mappings);

--- Mappings that are unique for UMLS
select DISTINCT ndc_code, rxnorm_concept_code
from umls_ndc_rxnorm_mappings
where (ndc_code, rxnorm_concept_code) not IN
(
    select
       c1.concept_code,
       c2.concept_code
from devv5.concept_relationship cr
join devv5.concept c1 on cr.concept_id_1 =  c1.concept_id and vocabulary_id = 'NDC' and c1. concept_class_id = '11-digit NDC'
join devv5.concept c2 on cr.concept_id_2 = c2.concept_id and c2.vocabulary_id in ('RxNorm', 'RxNorm Extension')
    );


--- NDC codes that could be found from Tanya's list.
select DISTINCT ndc_code
from umls_ndc_rxnorm_mappings WHERE ndc_code in
(SELECT replace (ndc_init, '-','')
FROM dev_atatur.not_found_ndc);
