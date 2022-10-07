/**************************************************************************
* Copyright 2016 Observational Health Data Sciences AND Informatics (OHDSI)
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
* Authors: Varvara Savitskaya, Vlad Korsik, Alexander Davydov
* Date: Fall-2022
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
    BEGIN
        PERFORM VOCABULARY_PACK.SetLatestUpdate(
                pVocabularyName => 'CGI',
                pVocabularyDate => TO_DATE('20180216', 'yyyymmdd'),
                pVocabularyVersion => 'CGI' || '20180216', -- should be hardcoded when API will not provide reproducible way for Updates
                pVocabularyDevSchema => 'dev_cgi'
            );
    END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Create temporary table
DROP TABLE if exists cgi_source;
CREATE TABLE cgi_source as (
   SELECT DISTINCT regexp_split_to_table(gdna, '__') as concept_name,
                    'CGI'                             as vocabulary_id,
                    regexp_split_to_table(gdna, '__') as concept_code,
                    regexp_split_to_table(gdna, '__') as hgvs,
                    gene,
                    protein,
                    gdna
    from dev_cgi.genomic_cgi_source
    WHERE gdna != ''
      AND protein != '.'
    );

-- 4 Fill the concept_stage
INSERT INTO concept_stage (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date)
select                  vocabulary_pack.CutConceptName(n.concept_name)                     AS concept_name,
                           'Measurement'                                               AS domain_id,
                           n.vocabulary_id                                             AS vocabulary_id,
                           'Variant'                                                   AS concept_class_id,
                           NULL                                                        AS standard_concept,
                           trim(substr(n.concept_code, 1, 50))                         AS concept_code,
                           v.latest_update           as valid_start_date,
                           TO_DATE('20991231', 'yyyymmdd') as valid_end_date
           FROM cgi_source n
                    JOIN vocabulary v ON v.vocabulary_id = 'CGI'
;


-- 5 Fill the concept_synonym_stage
with tab as (
    select *,
           regexp_replace(
                   (regexp_match(reference, 'NM_.\d.+\(p\..+\)\s|NM_.\d.+\(p\..+\)(?<!__PMID)|NM_.\d.+\(p\..+\)$'))[1],
                   'AND .+__Clinvar:|__PMID.+__Clinvar:|__PMID', ' @ ', 'gi') as hgvs_array,
           trim(substr(regexp_split_to_table(gdna, '__'), 1, 50))             as concept_code
    FROM dev_cgi.genomic_cgi_source
    WHERE reference ilike '%Clinvar%'
      AND protein != '.'
)
        ,
     ref_hgvs as (
         select gene,
                gdna,
                protein,
                transcript,
                info,
                context,
                cancer_acronym,
                source,
                reference,
                coalesce(hgvs_array,
                         (regexp_match(split_part(reference, ' AND ', 1), 'NM_.\d.+\s|NM_.\d.+$'))[1]) as hgvs,
                concept_code
         FROM tab)
        ,
     hgvs_synonyms as (
         select 'ref'                                    as flag,
                'CGI'                                    AS synonym_vocabulary_id,
                4180186                                  as language_concept_id,
                trim(regexp_split_to_table(hgvs, ' @ ')) as synonym_name,
                concept_code                             as synonym_concept_code
         FROM ref_hgvs
         UNION ALL

         select 'gdna'                                  as flag,
                'CGI'                                   AS synonym_vocabulary_id,
                4180186                                 as language_concept_id,
                trim(regexp_split_to_table(gdna, '__')) as synonym_name,
                concept_code                            as synonym_concept_code

         FROM cgi_source
         WHERE protein != '.'

         UNION ALL

         select 'protein'                        as flag,
                'CGI'                            AS synonym_vocabulary_id,
                4180186                          as language_concept_id,
                trim(concat(gene, ':', protein)) as synonym_name,
                concept_code                     as synonym_concept_code

         FROM cgi_source
         WHERE protein != '.'
     )
        ,
     synonyms as (
        SELECT DISTINCT flag, synonym_vocabulary_id, language_concept_id, synonym_name, synonym_concept_code
         FROM hgvs_synonyms
         WHERE flag IN ('protein', 'gdna')
            or (flag = 'ref' AND synonym_name ilike 'NM%')
     )

INSERT INTO concept_synonym_stage(synonym_concept_id, synonym_vocabulary_id, language_concept_id, synonym_name,
                           synonym_concept_code)

select  cs.concept_id, synonym_vocabulary_id, language_concept_id, synonym_name, synonym_concept_code
FROM synonyms s
         JOIN concept_stage cs
              ON cs.concept_code = s.synonym_concept_code
                  AND s.synonym_name <> cs.concept_name
;

--6. Add manual concepts or changes
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--7 Clean up
DROP TABLE cgi_source;

-- At the end, the three tables concept_stage, concept_relationship_stage AND concept_synonym_stage should be ready to be fed into the generic_update.sql script