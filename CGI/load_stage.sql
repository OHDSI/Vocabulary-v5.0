/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* Authors: Varvara Savitskaya, Vlad Korsik
* Date: 2022
**************************************************************************/

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CGI',
	pVocabularyDate			=> current_date,
	pVocabularyVersion		=> 'CGI'||TO_CHAR(CURRENT_DATE,'YYYYMMDD'),
	pVocabularyDevSchema	=> 'dev_cgi',
	pAppendVocabulary		=> FALSE
);
END $_$;


truncate concept_stage;
truncate concept_relationship_stage;
truncate concept_synonym_stage;

drop table cgi_source;
create table cgi_source as (
select distinct gdna as concept_name, 'CGI' as vocabulary_id,  regexp_split_to_table(gdna,'__') as concept_code,regexp_split_to_table(gdna,'__') as hgvs,gene,protein
from genomic_cgi_source
where gdna != ''
and protein != '.');

--insert into concept_stage
insert into concept_stage
with s as (SELECT DISTINCT
       COALESCE(c.concept_id, NULL::int)  as concept_id,
       trim(substr(n.concept_name,1,255)) AS concept_name,
       'Measurement' AS domain_id,
       n.vocabulary_id AS vocabulary_id,
       'Variant' AS concept_class_id,
       NULL AS standard_concept,
  trim(substr(n.concept_code,1,50)) AS concept_code,
      COALESCE(c.valid_start_date, v.latest_update)   as valid_start_date, -- defines valid_start_date  based on previous vocabulary run
       COALESCE(c.valid_end_date,TO_DATE('20991231', 'yyyymmdd'))  as valid_end_date, -- defines valid_end_date  based on previous vocabulary run
gene,
protein
FROM cgi_source n
JOIN vocabulary v ON v.vocabulary_id = 'CGI'
LEFT JOIN concept c ON c.concept_code =
                      --  n.concept_code
                       concat(gene, ':', regexp_replace(protein, 'p.', '')) -- Should be dropped after Fall2022 release and replaced with n.concept_code
    	AND c.vocabulary_id = 'CGI')

SELECT distinct
       s.concept_id,
       s.concept_name,
       s.domain_id,
       s.vocabulary_id,
       s.concept_class_id,
       s.standard_concept,
       s.concept_code,
       s.valid_start_date,
       s.valid_end_date ,
      CASE WHEN s.concept_code is null then 'D' else null end as invalid_reason
from s
FULL OUTER JOIN concept c ON c.concept_code =
                             --  n.concept_code -- already existing CGI concepts (subsequent run)
                             concat(gene, ':', regexp_replace(protein, 'p.', '')) -- already existing CGI concepts (гd for Fall2022 run)
	and c.vocabulary_id = 'CGI'
where s.concept_code is not null

;


-- insert synonyms
with tab as (
    SELECT *,
           regexp_replace((regexp_match(reference, 'NM_.\d.+\(p\..+\)\s|NM_.\d.+\(p\..+\)(?<!__PMID)|NM_.\d.+\(p\..+\)$'))[1],
                          'AND .+__Clinvar:|__PMID.+__Clinvar:|__PMID', ' @ ', 'gi') as hgvs_array,
           trim(substr(regexp_split_to_table(gdna,'__'),1,50))         as concept_code
    FROM genomic_cgi_source
    where reference ilike '%Clinvar%'
      and protein != '.'
)
,
ref_hgvs  as (
SELECT
       gene,
       gdna,
       protein,
       transcript,
       info,
       context,
       cancer_acronym,
       source,
       reference,
       coalesce(hgvs_array,(regexp_match(split_part(reference, ' AND ',1),'NM_.\d.+\s|NM_.\d.+$'))[1]) as hgvs,
       concept_code
FROM tab)
,
hgvs_synonyms as (
SELECT
    'ref' as flag,
      'CGI' AS synonym_vocabulary_id,
4180186 as language_concept_id,
       trim(regexp_split_to_table(hgvs,' @ ')) as synonym_name,
       concept_code as synonym_concept_code
FROM ref_hgvs
UNION ALL

SELECT
    'gdna' as flag,
    'CGI' AS synonym_vocabulary_id,
    4180186 as language_concept_id,
            trim(regexp_split_to_table(gdna,'__'))  as synonym_name,
             trim(substr(regexp_split_to_table(gdna,'__'),1,50))           as synonym_concept_code

FROM  genomic_cgi_source
      where protein != '.'

UNION ALL

SELECT
    'protein' as flag,
    'CGI' AS synonym_vocabulary_id,
    4180186 as language_concept_id,
       trim(concat(gene,':',protein)) as synonym_name,
             trim(substr(regexp_split_to_table(gdna,'__'),1,50))           as synonym_concept_code

FROM  genomic_cgi_source
          where protein != '.'

    )
    ,
synonyms as (
    SELECT distinct flag,synonym_vocabulary_id, language_concept_id, synonym_name, synonym_concept_code
    FROM hgvs_synonyms
    where flag IN ('protein', 'gdna')
       or (flag = 'ref' and synonym_name ilike 'NM%')
)
INSERT INTO concept_synonym_stage(synonym_vocabulary_id, language_concept_id, synonym_name, synonym_concept_code)
SELECT distinct synonym_vocabulary_id, language_concept_id, synonym_name, synonym_concept_code
FROM synonyms s
JOIN concept_stage cs
ON cs.concept_code=s.synonym_concept_code
and s.synonym_name<>cs.concept_name
;
