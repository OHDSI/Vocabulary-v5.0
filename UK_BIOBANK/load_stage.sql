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
        CASE WHEN title ~* 'assay|sampl|meas|ultrasound|MRI|pressure|ECG|tomography|densit|Freesurfer|DXA|Autorefraction|antigens|sample|imaging'
            THEN 'Measurement' ELSE 'Observation' END AS domain_id,
       'uk_biobank',
       'Biobank Category',
       'C',
       concat('c', cat.category_id),
       current_date,  --to_date(last_update,'yyyymmdd'),
       to_date('20991231','yyyymmdd')

FROM sources.uk_biobank_category cat
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
           AND domain_id = 'Measurement') OR f.main_category IN (148, 1307, 9081, 17518, 18518, 51428, 100078, 100079, 100080, 100081, 100082, 100083, 100084, 100085, 100086, 100087,
                                                                100, 102, 103, 105, 106, 107, 108, 109, 110, 111, 112, 124, 125, 126, 128, 131, 133, 134, 135, 149, 190, 191, 192, 193, 194, 195, 196, 197, 1101,1102, 100003) THEN 'Measurement' ELSE 'Observation' END AS domain_id,
        'uk_biobank',
        CASE WHEN
            f.main_category IN (148, 1307, 9081, 17518, 18518, 51428, 100078, 100079, 100080, 100081, 100082, 100083, 100084, 100085, 100086, 100087) THEN 'Lab Test'
            WHEN f.encoding_id != 0 AND f.main_category NOT IN (148, 1307, 9081, 17518, 18518, 51428, 100078, 100079, 100080, 100081, 100082, 100083, 100084, 100085, 100086, 100087,
                                                               101, 104, 100006, 100007, 100008, 100009, 100010, 100011, 100012, 100013, 100014, 100015, 100016, 100017, 100018, 100019, 100020,
                                                                100049, 100099) THEN 'Survey'
            ELSE 'Clinical Observation' END,
        CASE WHEN f.encoding_id != 0 AND f.main_category NOT IN (148, 1307, 9081, 17518, 18518, 51428, 100078, 100079, 100080, 100081, 100082, 100083, 100084, 100085, 100086, 100087)
            THEN 'S' ELSE NULL END,
        field_id,
       debut,
       to_date('20991231','yyyymmdd')
FROM sources.uk_biobank_field f
WHERE f.main_category NOT IN (SELECT child_id FROM sources.uk_biobank_catbrowse WHERE parent_id IN (100091, 2000, 1712))
AND f.main_category NOT IN (SELECT child_id FROM sources.uk_biobank_catbrowse WHERE parent_id IN (100314))
AND f.main_category NOT IN (100091, 43, 44, 45, 46, 47, 48, 49, 50, 2000, 1712, 3000, 3001, 100092, 100093,
                           1017, 100314, 181, 182, 100035, 100313, 100314, 100315, 100316, 100317, 100319, 199001,
                           347
                           )
AND f.item_type != 20
;

--Some codes got mistaken concept_class or domain due to biobank classification
UPDATE concept_stage
    SET domain_id = 'Observation',
        concept_class_id = 'Clinical Observation',
        standard_concept = 'S'
WHERE concept_name ~* ('assay date')
;

UPDATE concept_stage
    SET domain_id = 'Observation',
        concept_class_id = 'Survey',
        standard_concept = 'S'
WHERE concept_name ~* ('reason') AND concept_class_id != 'Lab Test';

UPDATE concept_stage
    SET domain_id = 'Observation',
        concept_class_id = 'Clinical Observation',
        standard_concept = NULL
WHERE concept_name ~* ('reason')
AND concept_class_id = 'Lab Test';

--TODO: Insert HES dictionary

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
FROM sources.uk_biobank_field
WHERE notes IS NOT NULL
AND notes != ''
AND (notes != title OR notes != concat(title, '.'))
AND notes not ilike 'ACE touchscreen question%'
AND notes not ilike 'Question asked%'
AND notes != '.'

AND field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'uk_biobank')
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

AND field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'uk_biobank')
;

--6: Insert answers to concept_stage
--TODO: Exclude also 1200?
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
       CASE WHEN encoding_id IN (SELECT encoding_id FROM sources.uk_biobank_field WHERE field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'uk_biobank' AND standard_concept = 'S')) THEN 'S'
           ELSE NULL END,
       concat(encoding_id::varchar, '|', value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
FROM sources.uk_biobank_esimpstring

--Only those encodings that we need
WHERE encoding_id IN (SELECT encoding_id FROM sources.uk_biobank_field WHERE field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'uk_biobank'))
AND encoding_id NOT IN (1836, 196, 197, 198, 199)
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
       CASE WHEN encoding_id IN (SELECT encoding_id FROM sources.uk_biobank_field WHERE field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'uk_biobank' AND standard_concept = 'S')) THEN 'S'
           ELSE NULL END,
       concat(encoding_id::varchar, '|', value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
FROM sources.uk_biobank_esimpint
WHERE encoding_id IN (SELECT encoding_id FROM sources.uk_biobank_field WHERE field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'uk_biobank'))
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
       CASE WHEN encoding_id IN (SELECT encoding_id FROM sources.uk_biobank_field WHERE field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'uk_biobank' AND standard_concept = 'S')) THEN 'S'
           ELSE NULL END,
       concat(encoding_id::varchar, '|', value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
FROM sources.uk_biobank_esimpdate
WHERE encoding_id IN (SELECT encoding_id FROM sources.uk_biobank_field WHERE field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'uk_biobank'))
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
       CASE WHEN encoding_id IN (SELECT encoding_id FROM sources.uk_biobank_field WHERE field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'uk_biobank' AND standard_concept = 'S')) THEN 'S'
           ELSE NULL END,
       concat(encoding_id::varchar, '|', value),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
FROM sources.uk_biobank_esimpreal
WHERE encoding_id IN (SELECT encoding_id FROM sources.uk_biobank_field WHERE field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'uk_biobank'))
;


--TODO: Not including them: Health-related outcomes, a lot of OPCS3 codes
/*
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
AND encoding_id IN (SELECT encoding_id FROM sources.uk_biobank_field WHERE field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'uk_biobank'))
;
 */

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
CASE WHEN encoding_id IN (SELECT encoding_id FROM sources.uk_biobank_field WHERE field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'uk_biobank' AND standard_concept = 'S'))
    AND selectable = 1 THEN 'S'
           ELSE NULL END,
       concat(encoding_id::varchar, '|', code_id),
       to_date('19700101','yyyymmdd'),
       to_date('20991231','yyyymmdd')
FROM ehierint
WHERE encoding_id NOT IN (19 /*ICD10*/, 87 /*ICD9 or ICD9CM?*/, 240 /*OPCS4*/)
AND encoding_id IN (SELECT encoding_id FROM sources.uk_biobank_field WHERE field_id::varchar IN (SELECT concept_code FROM concept_stage WHERE vocabulary_id = 'uk_biobank'))
;


--7: Building hierarchy for questions
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
FROM sources.uk_biobank_catbrowse cb;

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
JOIN sources.uk_biobank_field f
ON f.main_category::varchar = regexp_replace(cs.concept_code, 'c', '')
WHERE vocabulary_id = 'uk_biobank'
AND concept_class_id = 'Biobank Category';


--TODO: Not needed probably
--Hierarchy between answers
/*
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
FROM sources.uk_biobank_ehierint ei
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
 */


--TODO: Done till this point
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
FROM concept_stage cs
LEFT JOIN sources.uk_biobank_esimpdate ed
ON cs.concept_code = ed.encoding_id


WHERE f.encoding_id NOT IN (0, 19 /*ICD10*/, 87 /*ICD9 or ICD9CM?*/, 240 /*OPCS4*/, 1836 /*Partial mapping ICD9 to ICD10*/)
AND (ed.value IS NOT NULL
    OR ei.value IS NOT NULL
    OR er.value IS NOT NULL
    OR es.value IS NOT NULL
    OR (ehi.code_id IS NOT NULL AND ehi.selectable != 0)
    OR (ehs.code_id IS NOT NULL AND ehs.selectable != 0))
;