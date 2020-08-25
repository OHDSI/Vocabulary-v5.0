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
* Date: August 2020
**************************************************************************/

--0 Adding required concept_class and vocabulary
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Biobank Category',
    pConcept_class_name     =>'Biobank Category'
);
  PERFORM vocabulary_pack.AddNewVocabulary(
      pvocabulary_id => 'UK Biobank',
      pvocabulary_name =>  'UK Biobank',
      pvocabulary_reference => 'https://www.ukbiobank.ac.uk/',
      pvocabulary_version => 'Version 0.0.1',
      pOMOP_req => NULL ,
      pClick_default => NULL,
      pAvailable => NULL,
      pURL => NULL,
      pClick_disabled => NULL
      );
END $_$;

--1. Update a 'latest_update' field to a new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'UK Biobank',
	pVocabularyDate			=> TO_DATE ('2007-03-21' ,'yyyy-mm-dd'),   --From UK Biobank: Protocol for a large-scale prospective epidemiological resource (main phase) https://www.ukbiobank.ac.uk/wp-content/uploads/2011/11/UK-Biobank-Protocol.pdf?phpMyAdmin=trmKQlYdjjnQIgJ%2CfAzikMhEnx6
	pVocabularyVersion		=> 'Version 0.0.1',
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
       to_date(debut, 'dd.mm.yyyy'),     --TODO: Should we take debut (pros: possible reuse like NDC?), version (more actual info) or just 1970?
       to_date('20991231','yyyymmdd')
FROM field f;

--5: Insert questions to concept_synonym_stage
INSERT INTO concept_synonym_stage
(synonym_concept_id,
 synonym_name,
 synonym_concept_code,
 synonym_vocabulary_id,
 language_concept_id)

SELECT NULL,
       vocabulary_pack.CutConceptSynonymName(trim(regexp_replace(regexp_replace(notes, '<.*>|(You can select more than one answer)', ' ', 'g'), '\s{2,}|\.$', '', 'g'))) AS synonym_name,
       field_id AS synonym_concept_code,
       'uk_biobank',
       4180186
FROM field
WHERE notes IS NOT NULL
AND notes != ''
AND (notes != title OR notes != concat(title, '.'))
AND notes not ilike 'ACE touchscreen question%'
AND notes not ilike 'Question asked%'
AND notes != '.'

;


INSERT INTO concept_synonym_stage
(synonym_concept_id,
 synonym_name,
 synonym_concept_code,
 synonym_vocabulary_id,
 language_concept_id)

SELECT NULL,
       vocabulary_pack.CutConceptSynonymName(substring(notes, '"(.*)"')) AS synonym_name,
       field_id AS synonym_concept_code,
       'uk_biobank',
       4180186
FROM field
WHERE notes IS NOT NULL
AND notes != ''
AND (notes != title OR notes != concat(title, '.'))
AND (notes ilike 'ACE touchscreen question%' OR notes ilike 'Question asked%')
AND notes != '.'
;

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
FROM esimpstring

WHERE encoding_id != 1836 --Partial mapping from ICD9 to ICD10
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

--7: Turn some answers to Non-Standard ones (Deduplication)
WITH ans_dedup AS (SELECT concept_name,
                          concept_code,
                          row_number() OVER (PARTITION BY concept_name ORDER BY concept_code) AS is_standard
                   FROM concept_stage
                   WHERE concept_class_id = 'Answer'
                     AND concept_name IN (SELECT concept_name
                                          FROM concept_stage
                                          WHERE concept_class_id = 'Answer'
                                          GROUP BY concept_name
                                          HAVING count(concept_name) > 1)
)
UPDATE concept_stage cs
SET standard_concept = NULL
FROM ans_dedup
WHERE cs.concept_code = ans_dedup.concept_code
    AND ans_dedup.is_standard != 1;

--Non-standard answers are mapped to standard
WITH ans_dedup AS (SELECT concept_name,
                          concept_code,
                          row_number() OVER (PARTITION BY concept_name ORDER BY concept_code) AS is_standard
                   FROM concept_stage
                   WHERE concept_class_id = 'Answer'
                     AND concept_name IN (SELECT concept_name
                                          FROM concept_stage
                                          WHERE concept_class_id = 'Answer'
                                          GROUP BY concept_name
                                          HAVING count(concept_name) > 1))

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

SELECT a1.concept_code,
       a2.concept_code,
       'uk_biobank',
       'uk_biobank',
       'Maps to',
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd'),
       NULL
FROM ans_dedup a1
JOIN ans_dedup a2
ON a1.concept_name = a2.concept_name
WHERE a2.is_standard = 1
    AND a1.is_standard != 1; --these relationships will be built later


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

WHERE f.encoding_id NOT IN (0, 19 /*ICD10*/, 87 /*ICD9 or ICD9CM?*/, 240 /*OPCS4*/, 1836 /*Partial mapping ICD9 to ICD10*/)
AND (ed.value IS NOT NULL
    OR ei.value IS NOT NULL
    OR er.value IS NOT NULL
    OR es.value IS NOT NULL
    OR (ehi.code_id IS NOT NULL AND ehi.selectable != 0)
    OR (ehs.code_id IS NOT NULL AND ehs.selectable != 0))
;