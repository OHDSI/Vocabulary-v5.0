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
* Authors: Alexander Davydov, Oleg Zhuk
* Date: 2020
**************************************************************************/

--TODO: Add concept_class_id to the concept and concept_class tables (functions)
--TODO: Add vocabulary_id to the concept and vocabulary tables (functions)
--TODO: CHeck how good the answers and hierarchy are

--TODO: Check for the answers if there are some that should be made non-standard and be excluded from 'Has answer' relationship

--0 Temp code (to be removed)
/*
INSERT INTO concept_stage(concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
VALUES ( 2000000001,
        'UK Biobank',
        'Metadata',
        'uk_biobank',
        'Vocabulary',
        NULL,
        'OMOP generated',
        to_date ('2007-03-21' ,'yyyy-mm-dd'),
        to_date('20991231','yyyymmdd'),
        NULL
        );

INSERT INTO vocabulary(vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id, latest_update, dev_schema_name)
VALUES ('uk_biobank',
        'UK Biobank',
        'https://www.ukbiobank.ac.uk/',
        'Version 0.0.1',
        2000000001,
        current_date,
        'dev_ukbiobank'
        );
 */


--1. Update a 'latest_update' field to a new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'uk_biobank',
	pVocabularyDate			=> TO_DATE ('2007-03-21' ,'yyyy-mm-dd'),   --From UK Biobank: Protocol for a large-scale prospective epidemiological resource (main phase) https://www.ukbiobank.ac.uk/wp-content/uploads/2011/11/UK-Biobank-Protocol.pdf?phpMyAdmin=trmKQlYdjjnQIgJ%2CfAzikMhEnx6
	pVocabularyVersion		=> 'Version 0.0.1',    --TODO: Name the very first version
	pVocabularyDevSchema	=> 'dev_ukbiobank'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;


--3: Insert categories to concept_stage
INSERT INTO concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date
)

SELECT trim(title),
        CASE WHEN title ~* 'assay|sampl|meas|ultrasound|MRI|pressure|ECG|tomography|densit|Freesurfer|DXA|Autorefraction|antigens' THEN 'Measurement' ELSE 'Observation' END AS domain_id,
       'uk_biobank',
       'Biobank Category',
       'C',
       concat('c', cat.category_id),
       current_date,  --to_date(last_update,'yyyymmdd'),
       to_date('20991231','yyyymmdd')

FROM category cat
WHERE category_id != 0;

--4: Insert questions to concept_stage
INSERT INTO concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date
)

SELECT trim(title),
       CASE WHEN f.main_category::varchar IN (SELECT regexp_replace(concept_code, 'c', '') FROM concept_stage WHERE vocabulary_id = 'uk_biobank' AND concept_class_id = 'Biobank Category'
           AND domain_id = 'Measurement') THEN 'Measurement' ELSE 'Observation' END AS domain_id,
        'uk_biobank',
        'Clinical Observation',
        'S',
        field_id,
       to_date(debut, 'dd.mm.yyyy'),     --Should we take debut (pros: like reuse NDC?), version (more actual info) or just 1970?
       to_date('20991231','yyyymmdd')
FROM field f;

--5: Insert questions to concept_synonym_stage
--TODO: Find out what to do with synonyms (questions)

--6: Insert answers to concept_stage
INSERT INTO concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date
)

SELECT trim(meaning),
       'Meas Value',
       'uk_biobank',
       'Answer',
       'S',
       concat(encoding_id::varchar, '|', value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
FROM esimpstring;


INSERT INTO concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date
)

SELECT trim(meaning),
       'Meas Value',
       'uk_biobank',
       'Answer',
       'S',
       concat(encoding_id::varchar, '|', value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
FROM esimpint;


INSERT INTO concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date
)

SELECT trim(meaning),
       'Meas Value',
       'uk_biobank',
       'Answer',
       'S',
       concat(encoding_id::varchar, '|', value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
FROM esimpdate;


INSERT INTO concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date
)

SELECT trim(meaning),
       'Meas Value',
       'uk_biobank',
       'Answer',
       'S',
       concat(encoding_id::varchar, '|', value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
FROM esimpreal;

INSERT INTO concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date
)

SELECT trim(regexp_replace(meaning, '^\d*\.?\d* ', '')),
       'Meas Value',
       'uk_biobank',
       'Answer',
       CASE WHEN selectable = 1 THEN 'S' END,
       concat(encoding_id::varchar, '|', code_id),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
FROM ehierstring
WHERE encoding_id NOT IN (19 /*ICD10*/, 87 /*ICD9 or ICD9CM?*/, 240 /*OPCS4*/)
;

INSERT INTO concept_stage
(
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date
)

SELECT trim(regexp_replace(meaning, '^\d*\.?\d* ', '')),
       'Meas Value',
       'uk_biobank',
       'Answer',
       CASE WHEN selectable = 1 THEN 'S' END,
       concat(encoding_id::varchar, '|', code_id),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
FROM ehierint
WHERE encoding_id NOT IN (19 /*ICD10*/, 87 /*ICD9 or ICD9CM?*/, 240 /*OPCS4*/)
;

--7: Turn some answers to Non-Standard ones
--TODO: Deduplication of answers

--8: Building hierarchy for questions
--Hierarchy between Classification concepts
INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)

SELECT concat('c', parent_id),
       concat('c', child_id),
       'uk_biobank',
       'uk_biobank',
       'Subsumes',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM catbrowse cb;

--Hierarchy between classification concepts and questions
INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)

SELECT cs.concept_code AS concept_code_1,
       f.field_id AS concept_code_2,
       'uk_biobank',
       'uk_biobank',
       'Subsumes',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM concept_stage cs
JOIN field f
ON f.main_category::varchar = regexp_replace(cs.concept_code, 'c', '')
WHERE vocabulary_id = 'uk_biobank'
AND concept_class_id = 'Biobank Category';

--Hierarchy between answers
INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)

SELECT concat(encoding_id, '|', parent_id) AS concept_code_1,
       concat(encoding_id, '|', code_id) AS concept_code_2,
       'uk_biobank',
       'uk_biobank',
       'Subsumes',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM ehierint ei
WHERE parent_id != 0;


INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)

SELECT concat(encoding_id, '|', parent_id) AS concept_code_1,
       concat(encoding_id, '|', code_id) AS concept_code_2,
       'uk_biobank',
       'uk_biobank',
       'Subsumes',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM ehierstring es
WHERE parent_id != 0
AND concat(encoding_id, '|', code_id) IN (SELECT concept_code FROM concept_stage WHERE concept_class_id = 'Answer')
;

--9: Building 'Has answer' relationships
--TODO: Test and debug (if required) 'Has Answer' relationships for ehierstring and ehierint
INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)

SELECT DISTINCT f.field_id AS concept_code_1,
       CASE WHEN concat(ed.encoding_id::varchar, '|', ed.value) != '|' THEN concat(ed.encoding_id::varchar, '|', ed.value)
           WHEN concat(ei.encoding_id::varchar, '|', ei.value) != '|' THEN concat(ei.encoding_id::varchar, '|', ei.value)
               WHEN concat(er.encoding_id::varchar, '|', er.value) != '|' THEN concat(er.encoding_id::varchar, '|', er.value)
                   WHEN concat(es.encoding_id::varchar, '|', es.value) != '|' THEN concat(es.encoding_id::varchar, '|', es.value)
                        WHEN concat(ehi.encoding_id::varchar, '|', ehi.code_id) != '|' AND ehi.selectable != 0 THEN concat(ehi.encoding_id::varchar, '|', ehi.code_id)
                            WHEN concat(ehs.encoding_id::varchar, '|', ehs.code_id) != '|' AND ehs.selectable != 0 THEN concat(ehs.encoding_id::varchar, '|', ehs.code_id)
       END AS concept_code_2,
       'uk_biobank',
       'uk_biobank',
       'Has Answer',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM field f
LEFT JOIN esimpdate ed
ON f.encoding_id = ed.encoding_id
LEFT JOIN esimpint ei
ON f.encoding_id = ei.encoding_id
LEFT JOIN esimpreal er
ON f.encoding_id = er.encoding_id
LEFT JOIN esimpstring es
ON f.encoding_id = es.encoding_id
LEFT JOIN ehierint ehi
ON f.encoding_id = ehi.encoding_id
LEFT JOIN ehierstring ehs
ON f.encoding_id = ehs.encoding_id

WHERE f.encoding_id NOT IN (0, 19 /*ICD10*/, 87 /*ICD9 or ICD9CM?*/, 240 /*OPCS4*/)
AND (ed.value IS NOT NULL
    OR ei.value IS NOT NULL
    OR er.value IS NOT NULL
    OR es.value IS NOT NULL
    OR ehi.code_id IS NOT NULL
    OR ehs.code_id IS NOT NULL)
;

--TODO: Check if working (experiencing problem with connections)
INSERT INTO concept_relationship_stage
(
  concept_code_1,
  concept_code_2,
  vocabulary_id_1,
  vocabulary_id_2,
  relationship_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)

SELECT f.field_id AS concept_code_1,
       coalesce(c10.concept_code, c9.concept_code, c4.concept_code) AS concept_code_2,
       'uk_biobank',
       coalesce(c10.vocabulary_id, c9.vocabulary_id, c4.vocabulary_id),
       'Has answer',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM field f
JOIN ehierstring ehs
    ON f.encoding_id = ehs.encoding_id
LEFT JOIN devv5.concept c10
    ON regexp_replace(c10.concept_code, '.', '') = regexp_replace(ehs.value, '.', '') AND c10.vocabulary_id = 'ICD10'
LEFT JOIN devv5.concept c9
    ON regexp_replace(c9.concept_code, '.', '') = regexp_replace(ehs.value, '.', '') AND c9.vocabulary_id = 'ICD9CM'
LEFT JOIN devv5.concept c4
    ON regexp_replace(c4.concept_code, '.', '') = regexp_replace(ehs.value, '.', '') AND c4.vocabulary_id = 'OPCS4'

WHERE ehs.selectable = 0
AND f.encoding_id IN (19, 87, 240)
;


DELETE FROM concept_relationship_stage
WHERE concept_code_2 IS NULL;