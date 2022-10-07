--Update  of CGI needed to preserve IDs for cases where Gene-Protein is fully equivalent to gdna alteration (1 protein level affect- 1 DNA alteration)
--Leftover codes will be deprecated
UPDATE concept c
SET concept_code = s.concept_code,
    valid_start_date= CASE WHEN s.valid_start_date<TO_DATE('20180216', 'yyyymmdd') then s.valid_start_date else TO_DATE('20180216', 'yyyymmdd') end

FROM (
with tab as (SELECT b.concept_id,trim(substr(regexp_split_to_table(gdna,'__'),1,50)) as concept_code,valid_start_date
FROM dev_cgi.genomic_cgi_source a
JOIN concept b
 ON   concat(a.gene, ':', regexp_replace(a.protein, 'p.', '')) = b.concept_code
and b.vocabulary_id='CGI')
    SELECT concept_id, concept_code,valid_start_date
from tab
    where concept_id IN (SELECT concept_id from tab group by 1 having count(distinct concept_code)=1)
                          ) as s
where c.concept_id=s.concept_id
and c.vocabulary_id='CGI'
;

--Set correct validity for 37 concepts
UPDATE concept c
SET
    valid_end_date= current_date,
    invalid_reason ='D'
where  c.vocabulary_id='CGI'
and concept_code  not like '%:g.%'
;
