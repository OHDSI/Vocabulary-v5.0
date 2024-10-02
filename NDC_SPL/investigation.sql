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
    ) AS ndc_code,
    sab,
    rxaui,
    rxcui,
    code,
    suppress
FROM
    sources.rxnsat
WHERE
    atn = 'NDC'
   -- and suppress = 'N'
    )
select *
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



---- Why are we loosing other source codes from API

--- alien code - 44911038301
--- rxnorm code - 70700012487
select '44911038301', l1.status, l2.activeRxcui, l3.startDate, l4.endDate
              from (
                  select h.http_content,
                  l.xml_element
                  from vocabulary_download.py_http_get(url=>'https://rxnav.nlm.nih.gov/REST/ndcstatus?history=1&ndc=44911038301',allow_redirects=>true) h
                left join lateral (select unnest(xpath('/rxnormdata/ndcStatus/ndcHistory', h.http_content::xml)) as xml_element) l on true
              ) as s
              left join lateral (select unnest(xpath('/rxnormdata/ndcStatus/status/text()', s.http_content::xml))::varchar status) l1 on true
              left join lateral (select unnest(xpath('/ndcHistory/activeRxcui/text()', xml_element))::varchar activeRxcui) l2 on true
              left join lateral (select to_date(unnest(xpath('/ndcHistory/startDate/text()', xml_element))::varchar,'YYYYMM') startDate) l3 on true
              left join lateral (select to_date(unnest(xpath('/ndcHistory/endDate/text()', xml_element))::varchar,'YYYYMM') endDate) l4 on true;


---- Not all ALIEN codes in sources
select *
from sources.spl2ndc_mappings
where ndc_code = '50349017710';
select *
from apigrabber.rxnorm2ndc_mappings
where ndc_code = '50349017710';
SELECT *
from devv5.concept
WHERE vocabulary_id = 'NDC'
and concept_code = '50349017710';


select distinct atn
from sources.rxnsat;

--- rxlist в Load_stage NDC
--- количество реюзнутых кодов (все у кого 2 и более NDC history)
--- пул концептов, которых нету в сорсах, но есть в базовых таблицах


--- 02/10/2024
---

SELECT
    concept_code,
    count(concept_id)
FROM devv5.concept
where vocabulary_id = 'NDC'
GROUP BY concept_code having count(concept_id) > 1;

-- 21220020001
select distinct ndc_code as code
from umls_ndc_codes
where length(ndc_code)=11
and sab = 'RXNORM';
where ndc_code = '21220020001';

select *
from rxnorm_w_history_async;


SELECT  ----25086
    "NDC Code",
    "NDC History",
    LENGTH("NDC History") - LENGTH(REPLACE("NDC History", ',', '')) AS number_of_remappings
FROM
    rxnorm_w_history_async
WHERE
    "NDC History" LIKE '%,%';

SELECT -------25086
    "NDC Code",
    "NDC History",
    LENGTH("NDC History") - LENGTH(REPLACE("NDC History", ',', '')) AS number_of_remappings
FROM
    rxnorm_w_history_async
WHERE
    "NDC History" LIKE '%,%'
AND "NDC Code" in (SELECT
                        concept_code
                    FROM devv5.concept
                    where vocabulary_id = 'NDC');


WITH ndc_history_split AS (
    SELECT
        "NDC Code",
        regexp_split_to_table("NDC History", ',') AS ndc_history_part
    FROM
        rxnorm_w_history_async
    WHERE
        "NDC History" LIKE '%,%'
    AND "NDC Code" IN (SELECT concept_code
                       FROM devv5.concept
                       WHERE vocabulary_id = 'NDC')
),
rxnorm_mapping AS (
    SELECT
        "NDC Code",
        split_part(ndc_history_part, ':', 3) AS rxnorm_concept_code
    FROM
        ndc_history_split
)
SELECT
    r."NDC Code",
    string_agg(r.rxnorm_concept_code, '|||'),
    string_agg(c.concept_name, '|||')
FROM
    rxnorm_mapping r
LEFT JOIN
    devv5.concept c
    ON r.rxnorm_concept_code = c.concept_code
WHERE
    c.vocabulary_id = 'RxNorm'
GROUP BY r."NDC Code";